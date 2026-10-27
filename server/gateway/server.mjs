import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { WebSocketServer, WebSocket } from 'ws';
import { PROTOCOL, RULES, parseInput, publicParticipant } from './protocol.mjs';

export class Gateway {
  epoch = randomUUID(); connections = new Set(); queue = []; owners = new Map(); room = null;
  draining = false; totalBytes = 0; lastSessionCheck = 0; checkingSessions = false;
  constructor({ auth, worker, origins = ['https://mcroky.github.io', 'http://127.0.0.1:8791'], countdownMs = 3000, readyMs = 15000, reconnectMs = 20000, resultMs = 3000 }) {
    Object.assign(this, { auth, worker, origins: new Set(origins), countdownMs, readyMs, reconnectMs, resultMs });
    this.server = createServer((req, res) => this.http(req, res));
    this.ws = new WebSocketServer({ noServer: true, maxPayload: 8192, perMessageDeflate: false });
    this.server.on('upgrade', (req, socket, head) => {
      if (req.url !== '/play' || req.headers.origin && !this.origins.has(req.headers.origin) || this.connections.size >= 64 || this.draining) {
        socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
      }
      this.ws.handleUpgrade(req, socket, head, ws => this.connect(ws));
    });
    worker.on('message', message => this.workerMessage(message));
    worker.on('fault', () => { this.draining = true; this.abort('server_unavailable'); });
    this.timer = setInterval(() => this.maintenance(), 500); this.timer.unref();
  }
  healthy() { return this.worker.ready && Date.now() - this.worker.lastHealth < 5000; }
  http(req, res) {
    const origin = req.headers.origin;
    if (origin && !this.origins.has(origin)) { res.writeHead(403).end(); return; }
    const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', ...(origin ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' } : {}) };
    if (req.method !== 'GET' || !['/healthz', '/readyz'].includes(req.url)) { res.writeHead(404, headers).end('{}'); return; }
    const ready = this.healthy() && !this.draining;
    res.writeHead(req.url === '/healthz' || ready ? 200 : 503, headers).end(JSON.stringify({ ready, protocolVersion: PROTOCOL, rulesVersion: RULES, serverEpoch: this.epoch, capacity: 1, busy: Boolean(this.room), queue: this.queue.length }));
  }
  connect(socket) {
    const c = { socket, user: null, status: 'authenticating', joined: Date.now(), lastPong: Date.now(), lastPing: 0, lastSeq: -1, lastActivity: Date.now(), windowAt: Date.now(), messages: 0, busy: false, closed: false };
    this.connections.add(c);
    socket.on('pong', () => { c.lastPong = Date.now(); });
    socket.on('message', (data, binary) => {
      if (binary) { socket.close(1003, 'text_required'); return; }
      const now = Date.now(); if (now - c.windowAt >= 1000) { c.windowAt = now; c.messages = 0; }
      if (++c.messages > 120) { socket.close(1008, 'rate_limit'); return; }
      let message; try { message = JSON.parse(String(data)); } catch { socket.close(1008, 'invalid_json'); return; }
      if (!message || typeof message !== 'object' || Array.isArray(message) || message.protocolVersion !== PROTOCOL) { socket.close(1008, 'protocol_mismatch'); return; }
      this.message(c, message).catch(() => this.send(c, { type: 'error', code: 'account_unavailable' }));
    });
    socket.on('close', () => this.disconnected(c));
    socket.on('error', () => {});
  }
  send(c, message) {
    if (c.closed || c.socket.readyState !== WebSocket.OPEN) return;
    if (c.socket.bufferedAmount > 512000) { c.socket.terminate(); return; }
    const data = JSON.stringify({ protocolVersion: PROTOCOL, serverEpoch: this.epoch, ...message });
    this.totalBytes += Buffer.byteLength(data); c.socket.send(data);
  }
  broadcast(room, message) { for (const m of room.members) if (m.connection) this.send(m.connection, { matchId: room.id, ...message }); }
  async message(c, m) {
    if (m.type === 'ping') { this.send(c, { type: 'pong', sent: Number.isFinite(m.sent) ? m.sent : 0 }); return; }
    if (m.type === 'authenticate') {
      if (c.user || c.busy || typeof m.ticket !== 'string' || !/^[a-f0-9]{64}$/.test(m.ticket) || !this.healthy()) { this.send(c, { type: 'error', code: 'authentication_failed' }); return; }
      c.busy = true;
      let user; try { user = await this.auth.redeem(m.ticket, randomUUID(), this.epoch); }
      catch { this.send(c, { type: 'error', code: 'authentication_failed' }); c.socket.close(1008); return; }
      finally { c.busy = false; }
      if (c.closed) return;
      const owned = this.owners.get(user.id);
      if (owned && (owned.connection || !this.room?.members.includes(owned))) { this.send(c, { type: 'error', code: 'already_participating' }); c.socket.close(1008); return; }
      c.user = user; c.status = 'idle';
      this.send(c, { type: 'authenticated', rulesVersion: RULES, resuming: Boolean(owned) });
      if (owned) {
        owned.user = user; owned.connection = c; owned.disconnectedAt = 0; c.status = 'playing'; c.lastSeq = -1;
        this.worker.send({type:'reset_input',roomId:this.room.id,slot:this.room.members.indexOf(owned)});
        this.send(c, { type: 'match.found', matchId: this.room.id, slot: this.room.members.indexOf(owned), participants: this.room.members.map((p, i) => publicParticipant(p.user, i)), state: this.room.snapshot, resumed: true });
        this.broadcast(this.room, { type: 'reconnect.status', connected: this.room.members.map(p => Boolean(p.connection)) });
      }
      return;
    }
    if (!c.user) { this.send(c, { type: 'error', code: 'authentication_required' }); return; }
    if (m.type === 'queue.join') {
      if (m.mode !== 'duel' || !this.healthy() || this.draining) { this.send(c, { type: 'error', code: 'unavailable' }); return; }
      if (this.owners.has(c.user.id)) { this.send(c, { type: 'error', code: c.status === 'queued' ? 'already_queued' : 'already_participating' }); return; }
      const member = { user: c.user, connection: c, joined: Date.now(), disconnectedAt: 0 };
      this.owners.set(c.user.id, member); this.queue.push(member); c.status = 'queued';
      this.queueStatus(); this.tryMatch(); return;
    }
    if (m.type === 'queue.cancel') {
      if (c.status === 'queued') this.removeQueued(c);
      else if (this.room?.members.some(p => p.connection === c) && !['playing', 'finishing'].includes(this.room.phase)) this.cancelReservation(c);
      this.send(c, { type: 'queue.cancelled', playing: c.status === 'playing' }); return;
    }
    const room = this.room;
    if (!room || m.matchId !== room.id || m.serverEpoch !== this.epoch) { this.send(c, { type: 'error', code: 'stale_match' }); return; }
    const slot = room.members.findIndex(p => p.connection === c);
    if (slot < 0) return;
    if (m.type === 'match.ready') {
      if (room.phase === 'loading') {
        room.ready.add(slot);
        if (room.ready.size === 2) {
          clearTimeout(room.timeout); room.phase = 'countdown';
          this.broadcast(room, { type: 'countdown', milliseconds: this.countdownMs });
          room.timeout = setTimeout(() => {
            if (this.room !== room) return;
            if (room.members.some(p => !p.connection)) { this.cancelReservation(); return; }
            room.phase = 'playing'; room.startedAt = Date.now();
            for (const member of room.members) { member.connection.status = 'playing'; member.connection.lastActivity = Date.now(); }
            this.worker.send({ type: 'start', roomId: room.id }); this.broadcast(room, { type: 'match.started' });
          }, this.countdownMs);
        }
      }
    } else if (m.type === 'input' && room.phase === 'playing') {
      let input; try { input = parseInput(m, c.lastSeq); } catch { this.send(c, { type: 'error', code: 'invalid_input' }); return; }
      c.lastSeq = input.seq;
      if (Math.hypot(input.x, input.z) > .15 || ['shoot_pressed', 'cross', 'spin', 'twostep', 'behind', 'hesi', 'steal'].some(k => input[k] && !c.previousInput?.[k])) c.lastActivity = Date.now();
      c.previousInput = input;
      this.worker.send({ type: 'input', roomId: room.id, slot, input });
    } else if (m.type === 'match.leave') {
      if (room.phase === 'playing') this.finish(room, 'forfeit', 1 - slot);
      else this.cancelReservation(c);
    }
  }
  removeQueued(c) {
    this.queue = this.queue.filter(p => p.connection !== c);
    this.owners.delete(c.user.id); c.status = 'idle'; this.queueStatus();
  }
  queueStatus() { this.queue.forEach((p, i) => this.send(p.connection, { type: 'queue.status', position: i + 1, waiting: this.queue.length, busy: Boolean(this.room) })); }
  async tryMatch() {
    if (this.room || this.queue.length < 2 || this.draining || !this.healthy()) return;
    const room = this.room = { id: randomUUID(), members: this.queue.splice(0, 2), phase: 'registering', ready: new Set(), snapshot: null, timeout: null, createdAt: Date.now(), winner: null };
    room.members.forEach(p => { p.connection.status = 'reserved'; }); this.queueStatus();
    room.registration = this.auth.register(room, this.epoch);
    try { await room.registration; }
    catch { if (this.room === room) this.abort('account_unavailable'); return; }
    if (this.room !== room) return;
    room.phase = 'creating'; room.timeout = setTimeout(() => this.abort('worker_timeout'), 15000);
    if (!this.worker.send({ type: 'create', roomId: room.id, appearances: room.members.map(p => p.user.appearance) })) this.abort('worker_unavailable');
  }
  workerMessage(message) {
    if(message.type==='health'){
      this.metrics={tickP95us:message.tickP95us||0,tickP99us:message.tickP99us||0,workerStaticBytes:message.memoryBytes||0};
      if(Date.now()-(this.lastMetricsLog||0)>30000){this.lastMetricsLog=Date.now();console.log(JSON.stringify({event:'online_health',...this.metrics,nodeRSS:process.memoryUsage().rss,rooms:this.room?1:0,queued:this.queue.length,sentBytes:this.totalBytes}));}
      return;
    }
    if (message.type === 'overload') { this.abort('server_overload'); return; }
    const room = this.room;
    if (!room || message.roomId !== room.id) return;
    if (message.type === 'created') {
      clearTimeout(room.timeout); room.phase = 'loading'; room.snapshot = message.state;
      room.members.forEach((p, slot) => this.send(p.connection, { type: 'match.found', matchId: room.id, slot, participants: room.members.map((q, i) => publicParticipant(q.user, i)), state: message.state }));
      room.timeout = setTimeout(() => this.cancelReservation(), this.readyMs);
    } else if (message.type === 'snapshot' && room.phase === 'playing') {
      room.snapshot = message.state;
      this.broadcast(room, { type: 'snapshot', state: message.state });
      if (message.state.phase === 'ended') this.finish(room, message.state.outcome || 'score', message.state.score[0] === message.state.score[1] ? null : message.state.score[0] > message.state.score[1] ? 0 : 1);
    }
  }
  disconnected(c) {
    c.closed = true; this.connections.delete(c);
    if (!c.user) return;
    if (c.status === 'queued') { this.removeQueued(c); return; }
    const room = this.room, member = room?.members.find(p => p.connection === c);
    if (!member) return;
    member.connection = null; member.disconnectedAt = Date.now();
    if (room.phase !== 'playing' && room.phase !== 'finishing') this.cancelReservation(c);
    else this.broadcast(room, { type: 'reconnect.status', connected: room.members.map(p => Boolean(p.connection)) });
  }
  cancelReservation(leaving) {
    const room = this.room; if (!room || ['playing', 'finishing'].includes(room.phase)) return;
    clearTimeout(room.timeout); this.worker.send({ type: 'destroy', roomId: room.id }); this.room = null;
    for (const member of room.members) {
      this.owners.delete(member.user.id);
      const c = member.connection;
      if (!c || c === leaving || c.closed) { if (c) c.status = 'idle'; continue; }
      c.status = 'queued'; this.owners.set(c.user.id, member); this.queue.unshift(member);
      this.send(c, { type: 'match.cancelled', matchId: room.id });
    }
    void Promise.resolve(room.registration).then(()=>this.auth.finish(room, this.epoch, { reason: 'cancelled', winner: null, score: [0, 0], seconds: 90 })).catch(() => {});
    this.queueStatus(); this.tryMatch();
  }
  async finish(room, reason, winner = null) {
    if (this.room !== room || room.phase === 'finishing') return;
    room.phase = 'finishing'; clearTimeout(room.timeout);
    this.worker.send({ type: 'end', roomId: room.id, reason });
    const result = { reason, winner, score: room.snapshot?.score || [0, 0], seconds: room.snapshot?.seconds ?? 90 };
    let saved = false;
    try { await Promise.race([this.auth.finish(room, this.epoch, result).then(() => { saved = true; }), new Promise(resolve => setTimeout(resolve, this.resultMs))]); } catch {}
    if (this.room !== room) return;
    this.broadcast(room, { type: 'match.ended', result: { ...result, saved } });
    this.worker.send({ type: 'destroy', roomId: room.id }); this.room = null;
    for (const p of room.members) { this.owners.delete(p.user.id); if (p.connection) p.connection.status = 'idle'; }
    this.queueStatus(); this.tryMatch();
  }
  abort(code) {
    const room = this.room; if (!room) return;
    this.broadcast(room, { type: 'error', code }); void this.finish(room, 'aborted');
  }
  maintenance() {
    const now = Date.now();
    for (const c of this.connections) {
      if (!c.user && now - c.joined > 5000 || now - c.lastPong > 25000) { c.socket.terminate(); continue; }
      if (now - c.lastPing > 10000) { c.lastPing = now; c.socket.ping(); }
    }
    const room = this.room;
    if (room?.phase === 'playing') {
      if (!this.healthy()) { this.abort('server_unavailable'); return; }
      const missing = room.members.map(p => !p.connection || p.connection.closed);
      if (missing.every(Boolean)) { this.abort('all_disconnected'); return; }
      for (let i = 0; i < 2; i++) {
        const member = room.members[i];
        if (!member.connection && now - member.disconnectedAt > this.reconnectMs || member.connection && now - member.connection.lastActivity > 60000) { void this.finish(room, 'forfeit', 1 - i); return; }
        if (member.connection && now - member.connection.lastActivity > 45000 && !member.warned) { member.warned = true; this.send(member.connection, { type: 'idle.warning' }); }
      }
    }
    const members = [...this.owners.values()];
    if (members.length && now - this.lastSessionCheck > 30000 && !this.checkingSessions) {
      this.lastSessionCheck = now; this.checkingSessions = true;
      this.auth.check(members, this.epoch).then(result => {
        for (const id of result.invalid || []) {
          const member = this.owners.get(id); if (!member?.connection) continue;
          this.send(member.connection, { type: 'error', code: 'session_expired' }); member.connection.socket.close(1008, 'session_expired');
        }
      }).catch(() => {}).finally(() => { this.checkingSessions = false; });
    }
  }
  async listen(port = 0, host = '127.0.0.1') { await new Promise(resolve => this.server.listen(port, host, resolve)); return this.server.address().port; }
  async close() { this.draining = true; clearInterval(this.timer); if (this.room) clearTimeout(this.room.timeout); for (const c of this.connections) c.socket.terminate(); this.ws.close(); this.server.close(); }
}
