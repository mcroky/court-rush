import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { randomBytes } from 'node:crypto';
import WebSocket from 'ws';
import { Gateway } from '../gateway/server.mjs';
import { parseInput, PROTOCOL,RULES } from '../gateway/protocol.mjs';
import {newPlayer,attributes} from '../../site/career-rules.mjs';
import { Worker } from '../gateway/worker.mjs';
import { resolve } from 'node:path';

const neutral = () => ({ x: 0, z: 0, shoot: false, shoot_pressed: false, cross: false, spin: false, twostep: false, behind: false, hesi: false, steal: false, guard: false });
class TestAccounts {
  tickets = new Map(); results = [];
  issue(id) { const ticket = randomBytes(32).toString('hex'); this.tickets.set(ticket, { id, nickname: 'Player ' + id, appearance: {}, ticketId: id,athlete:attributes(newPlayer(id==='b'?'center':'guard','Player')),rulesVersion:RULES }); return ticket; }
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
  assert.equal(foundA.state.players[1].boneCount, 45); assert.equal(Buffer.from(foundA.state.players[1].pose, 'base64').length, 630); assert.equal(foundA.participants[0].id, undefined);assert.equal(foundA.participants[1].athlete.role,'center');assert.equal(foundA.state.players[1].role,'center');
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

test('private rooms hide codes, fix the pair, require both ready and never enter ranked matching',async t=>{
 const auth=new TestAccounts(),worker=new TestWorker(),g=new Gateway({auth,worker});const port=await g.listen();t.after(()=>g.close());
 const a=await client(port,auth.issue('a')),b=await client(port,auth.issue('b')),c=await client(port,auth.issue('c'));
 a.send({type:'room.create',title:'Private <court>',private:true});const lobby=(await a.next('room.state')).lobby;
 assert.match(lobby.code,/^[A-F0-9]{8}$/);c.send({type:'room.list'});assert.equal((await c.next('room.list')).rooms.length,0);
 c.send({type:'room.join',lobbyId:lobby.id});assert.equal((await c.next('room.error')).code,'room_unavailable');
 b.send({type:'room.join',code:lobby.code});const joined=(await b.next('room.state')).lobby;assert.equal(joined.members.length,2);
 a.send({type:'room.ready',lobbyId:lobby.id,ready:true});await new Promise(r=>setTimeout(r,20));assert.equal(g.room,null,'one ready is insufficient');
 b.send({type:'room.ready',lobbyId:lobby.id,ready:true});await new Promise(r=>setTimeout(r,20));
 assert.equal(g.room.ranked,false);assert.deepEqual(g.room.members.map(m=>m.user.id),['a','b']);assert.equal(g.owners.get('c'),undefined);
 assert.equal(worker.commands.filter(m=>m.type==='create').length,1);
});

test('bounded headless polling preserves sixty authority ticks and twenty snapshots per second', {skip:!process.env.GODOT_BIN,timeout:15000},async t=>{
 const worker=new Worker({binary:process.env.GODOT_BIN,root:resolve(import.meta.dirname,'../..'),port:32112});t.after(()=>worker.close());
 let created=false,last=null,snapshots=0,started=0;let fault=null;
 worker.on('fault',code=>{fault=code;});
 worker.on('message',m=>{
  if(m.type==='ready')worker.send({type:'create',roomId:'clock-check',appearances:[{},{}]});
  if(m.type==='created'){created=true;started=performance.now();worker.send({type:'start',roomId:'clock-check'});}
  if(m.type==='snapshot'){last=m.state;snapshots++;}
 });worker.start();
 const deadline=Date.now()+10000;while((!last||last.tick<126)&&Date.now()<deadline&&!fault)await new Promise(r=>setTimeout(r,10));
 assert.equal(fault,null);assert.ok(created&&last,'worker starts and emits snapshots');
 const seconds=(performance.now()-started)/1000;
 assert.ok(last.tick/seconds>55&&last.tick/seconds<65,'authority remains 60Hz after changing engine polling');
 assert.ok(snapshots/seconds>18&&snapshots/seconds<22,'snapshot cadence remains 20Hz');
 assert.ok(Math.abs(last.time-last.tick/60)<.001,'simulation time still uses exact 1/60 steps');
});

test('public room list never leaks invitation codes and leaving resets ready state',async t=>{
 const auth=new TestAccounts(),worker=new TestWorker(),g=new Gateway({auth,worker});const port=await g.listen();t.after(()=>g.close());
 const a=await client(port,auth.issue('a')),b=await client(port,auth.issue('b'));
 a.send({type:'room.create',title:'Public court',private:false});const lobby=(await a.next('room.state')).lobby;assert.equal(lobby.code,undefined,'public rooms use list entry without invitation codes');
 b.send({type:'room.list'});const listed=(await b.next('room.list')).rooms[0];assert.equal(listed.id,lobby.id);assert.equal(listed.code,undefined);
 a.send({type:'room.ready',lobbyId:lobby.id,ready:true});b.send({type:'room.join',lobbyId:lobby.id});await b.next('room.state');
 a.send({type:'room.leave',lobbyId:lobby.id});await a.next('room.left');
 const remaining=g.lobbies.get(lobby.id);assert.equal(remaining.members.length,1);assert.equal(remaining.members[0].user.id,'b');assert.equal(remaining.members[0].ready,false);
});

test('a ready room waits as an intact pair while the single court is occupied',async t=>{
 const auth=new TestAccounts(),worker=new TestWorker(),g=new Gateway({auth,worker});const port=await g.listen();t.after(()=>g.close());
 const a=await client(port,auth.issue('a')),b=await client(port,auth.issue('b')),c=await client(port,auth.issue('c')),d=await client(port,auth.issue('d'));
 a.send({type:'queue.join',mode:'duel'});b.send({type:'queue.join',mode:'duel'});await new Promise(r=>setTimeout(r,30));const first=g.room;
 c.send({type:'room.create',title:'Next pair',private:false});const lobby=(await c.next('room.state')).lobby;
 d.send({type:'room.join',lobbyId:lobby.id});await d.next('room.state');c.send({type:'room.ready',lobbyId:lobby.id,ready:true});d.send({type:'room.ready',lobbyId:lobby.id,ready:true});
 await new Promise(r=>setTimeout(r,20));assert.equal(g.room,first);assert.equal(g.pairs.length,1);
 g.cancelReservation(first.members[0].connection);await new Promise(r=>setTimeout(r,20));
 assert.deepEqual(g.room.members.map(m=>m.user.id),['c','d']);assert.equal(g.room.ranked,true);assert.equal(g.queue[0].user.id,'b');
});

test('delayed result saving reports pending then sends only the committed ranking',async t=>{
 const auth=new TestAccounts();auth.finish=async(room,epoch,result)=>{await new Promise(r=>setTimeout(r,50));return {result:{...result,ranked:true,rankings:[{slot:0,rating:984,delta:-16}]}};};
 const worker=new TestWorker(),g=new Gateway({auth,worker,countdownMs:1,resultMs:1});const port=await g.listen();t.after(()=>g.close());
 const a=await client(port,auth.issue('a')),b=await client(port,auth.issue('b'));a.send({type:'queue.join',mode:'duel'});b.send({type:'queue.join',mode:'duel'});await new Promise(r=>setTimeout(r,20));
 worker.emit('message',{type:'created',roomId:g.room.id,state:{tick:0,time:0,score:[0,0],seconds:90}});
 const found=await a.next('match.found');await b.next('match.found');const envelope={matchId:found.matchId,serverEpoch:found.serverEpoch};a.send({...envelope,type:'match.ready'});b.send({...envelope,type:'match.ready'});await a.next('match.started');
 a.send({...envelope,type:'match.leave',rating:999999});assert.equal((await a.next('match.ended')).result.saved,false);
 const settled=(await a.next('match.saved')).result;assert.equal(settled.saved,true);assert.equal(settled.rankings[0].rating,984);
});
