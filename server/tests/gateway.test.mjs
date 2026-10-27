import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { randomBytes } from 'node:crypto';
import WebSocket from 'ws';
import { Gateway } from '../gateway/server.mjs';
import { parseInput, PROTOCOL } from '../gateway/protocol.mjs';
import { Worker } from '../gateway/worker.mjs';
import { resolve } from 'node:path';

const neutral = () => ({ x: 0, z: 0, shoot: false, shoot_pressed: false, cross: false, spin: false, twostep: false, behind: false, hesi: false, steal: false, guard: false });
class TestAccounts {
  tickets = new Map(); results = [];
  issue(id) { const ticket = randomBytes(32).toString('hex'); this.tickets.set(ticket, { id, nickname: 'Player ' + id, appearance: {}, ticketId: id }); return ticket; }
  async redeem(ticket) { const user = this.tickets.get(ticket); if (!user) throw Error('invalid'); this.tickets.delete(ticket); return user; }
  async register() {}
  async finish(room, epoch, result) { this.results.push({ id: room.id, epoch, result }); }
  async check() { return { invalid: [] }; }
}
class TestWorker extends EventEmitter {
  ready = true; get lastHealth() { return Date.now(); } commands = [];
  send(message) { this.commands.push(message); return true; }
}
async function client(port, ticket) {
  const ws = new WebSocket('ws://127.0.0.1:' + port + '/play'); const messages = [];
  ws.on('message', data => messages.push(JSON.parse(String(data))));
  await new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); });
  const send = m => ws.send(JSON.stringify({ protocolVersion: PROTOCOL, ...m }));
  send({ type: 'authenticate', ticket });
  const next = async (type, timeout = 5000) => {
    const start = Date.now();
    while (Date.now() - start < timeout) { const index = messages.findIndex(m => m.type === type); if (index >= 0) return messages.splice(index, 1)[0]; await new Promise(resolve => setTimeout(resolve, 10)); }
    throw Error('Timeout waiting for ' + type + ': ' + messages.map(m => m.type + ':' + (m.code || '')).join(','));
  };
  await next('authenticated'); return { ws, send, next, messages };
}
test('input cannot select another player, teleport or replay a sequence', () => {
  const parsed = parseInput({ ...neutral(), seq: 1, x: 1, z: 1, slot: 9, position: [999, 0, 0] }, -1);
  assert.equal(parsed.slot, undefined); assert.equal(parsed.position, undefined); assert.ok(Math.hypot(parsed.x, parsed.z) <= 1);
  assert.throws(() => parseInput({ ...neutral(), seq: 1, x: Infinity }, -1));
  assert.throws(() => parseInput({ ...neutral(), seq: 1 }, 1));
});
test('queue cancellation and two tabs never reserve the same account twice', async t => {
  const auth = new TestAccounts(), worker = new TestWorker(), gateway = new Gateway({ auth, worker });
  const port = await gateway.listen(); t.after(() => gateway.close());
  const a = await client(port, auth.issue('a')), duplicate = await client(port, auth.issue('a'));
  a.send({ type: 'queue.join', mode: 'duel' }); await a.next('queue.status');
  duplicate.send({ type: 'queue.join', mode: 'duel' }); assert.equal((await duplicate.next('error')).code, 'already_participating');
  a.send({ type: 'queue.cancel' }); await a.next('queue.cancelled'); assert.equal(gateway.queue.length, 0); assert.equal(gateway.owners.size, 0);
  assert.equal(worker.commands.length, 0);
});
test('cancel while registration is pending cannot start a cancelled match', async t => {
  const auth = new TestAccounts(); let registered; auth.register = () => new Promise(resolve => { registered = resolve; });
  const worker = new TestWorker(), gateway = new Gateway({ auth, worker });
  const port = await gateway.listen(); t.after(() => gateway.close());
  const a = await client(port, auth.issue('a')), b = await client(port, auth.issue('b'));
  a.send({ type: 'queue.join', mode: 'duel' }); b.send({ type: 'queue.join', mode: 'duel' });
  while (!registered) await new Promise(resolve => setTimeout(resolve, 10));
  a.send({ type: 'queue.cancel' }); await a.next('queue.cancelled'); registered();
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.ok(!worker.commands.some(m => m.type === 'create')); assert.equal(gateway.queue.length, 1); assert.equal(gateway.queue[0].user.id, 'b');
});
test('actual Godot worker connects two humans, produces rigs and applies slot-one input', { skip: !process.env.GODOT_BIN, timeout: 30000 }, async t => {
  const root = resolve(import.meta.dirname, '../..');
  const worker = new Worker({ binary: process.env.GODOT_BIN, root, port: 32109 });
  const auth = new TestAccounts(), gateway = new Gateway({ auth, worker, countdownMs: 30, resultMs: 100 });
  t.after(() => { gateway.close(); worker.close(); });
  const port = await gateway.listen(); worker.start();
  const start = Date.now(); while (!worker.ready && Date.now() - start < 10000) await new Promise(resolve => setTimeout(resolve, 30));
  assert.ok(worker.ready, 'worker ready');
  const a = await client(port, auth.issue('a')), b = await client(port, auth.issue('b'));
  a.send({ type: 'queue.join', mode: 'duel' }); b.send({ type: 'queue.join', mode: 'duel' });
  const foundA = await a.next('match.found'), foundB = await b.next('match.found');
  assert.equal(foundA.matchId, foundB.matchId); assert.notEqual(foundA.slot, foundB.slot);
  assert.equal(foundA.state.players[1].boneCount, 45); assert.equal(Buffer.from(foundA.state.players[1].pose, 'base64').length, 630); assert.equal(foundA.participants[0].id, undefined);
  const envelope = { matchId: foundA.matchId, serverEpoch: foundA.serverEpoch };
  a.send({ ...envelope, type: 'match.ready' }); b.send({ ...envelope, type: 'match.ready' });
  await a.next('match.started'); await b.next('match.started');
  const before = foundB.state.players[1].position[0];
  for (let i = 0; i < 20; i++) { b.send({ ...envelope, type: 'input', ...neutral(), x: 1, seq: i }); await new Promise(resolve => setTimeout(resolve, 34)); }
  let latest; for (const message of b.messages) if (message.type === 'snapshot') latest = message;
  assert.ok(latest.state.players[1].position[0] > before + .5, 'slot one moves over actual socket');
  assert.ok(latest.state.seconds < 90); assert.ok(latest.state.acks[1] >= 0);
  b.ws.terminate();
  while(gateway.room.members[1].connection)await new Promise(resolve=>setTimeout(resolve,10));
  const recovered=await client(port,auth.issue('b'));
  const resumed=await recovered.next('match.found');
  assert.equal(resumed.resumed,true);assert.equal(resumed.slot,1);assert.equal(resumed.matchId,foundA.matchId);
  recovered.send({...envelope,type:'input',...neutral(),z:1,seq:0});
  let acknowledged=false;const recoverStart=Date.now();
  while(Date.now()-recoverStart<2000&&!acknowledged){const state=(await recovered.next('snapshot')).state;acknowledged=state.acks[1]===0;}
  assert.ok(acknowledged,'reconnection discards old input sequences');
  a.send({ ...envelope, type: 'match.leave' });
  const resultA = await a.next('match.ended'), resultB = await recovered.next('match.ended');
  assert.deepEqual(resultA.result, resultB.result); assert.equal(resultB.result.winner, 1); assert.equal(resultB.result.saved, true);
});
