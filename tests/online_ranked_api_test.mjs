// Real accounts/Edge/DB/WSS/Godot. All fixtures are task-created QA users only.
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import WebSocket from '../server/node_modules/ws/index.js';
import {attributes} from '../site/career-rules.mjs';
import {AccountAPI} from '../server/gateway/auth.mjs';
const env=Object.fromEntries(readFileSync(new URL('../server/.env.rank-qa',import.meta.url),'utf8').trim().split(/\r?\n/).map(l=>{const i=l.indexOf('=');return [l.slice(0,i),l.slice(i+1)];}));
const base=process.env.CR_TEST_SERVER_URL||'http://127.0.0.1:8792',serverId=env.CR_SERVER_ID,url=env.CR_SUPABASE_URL,key=env.CR_SUPABASE_KEY;
const accounts=new AccountAPI({url,key,serverKey:env.CR_ONLINE_SERVER_KEY,serverId});
const path=new URL('../artifacts/rank-test-users.json',import.meta.url),users=[];let checks=0;
const check=(ok,label)=>{assert.ok(ok,label);console.log('PASS',label);checks++;};
async function api(action,body={},session){const r=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(session?{Authorization:'Bearer '+session.access_token}:{})},body:JSON.stringify({action,...body})});const data=await r.json();return {status:r.status,data};}
async function expect(action,body,session){const r=await api(action,body,session);assert.equal(r.status,200,action+': '+JSON.stringify(r.data));return r.data;}
const ticket=user=>expect('online-ticket',{serverId,mode:'duel',protocolVersion:1,rulesVersion:'duel-career-v2',athlete:{speed:999,height:999},rating:99999},user.session);
async function client(user){
 const grant=await ticket(user),socket=new WebSocket(base.replace(/^http/,'ws')+'/play'),messages=[];
 socket.on('message',d=>messages.push(JSON.parse(String(d))));await new Promise((resolve,reject)=>{socket.once('open',resolve);socket.once('error',reject);});
 const send=m=>socket.send(JSON.stringify({protocolVersion:1,...m}));
 const next=async(type,timeout=20000)=>{const end=Date.now()+timeout;while(Date.now()<end){const i=messages.findIndex(m=>m.type===type);if(i>=0)return messages.splice(i,1)[0];const err=messages.find(m=>m.type==='error'||m.type==='room.error');if(err)throw Error(err.code);await new Promise(r=>setTimeout(r,15));}throw Error('Timeout '+type);};
 send({type:'authenticate',ticket:grant.ticket});await next('authenticated');return {socket,messages,send,next};
}
async function play(kind='auto',loser=0){
 const [a,b]=await Promise.all(users.map(client));
 try{
  if(kind==='auto'){a.send({type:'queue.join',mode:'duel'});b.send({type:'queue.join',mode:'duel'});}
  else{a.send({type:'room.create',title:'QA '+kind,private:kind==='private'});const lobby=(await a.next('room.state')).lobby;b.send(kind==='private'?{type:'room.join',code:lobby.code}:{type:'room.join',lobbyId:lobby.id});await b.next('room.state');
   if(kind==='public'){const itemId=users[0].player.wardrobe.equipped.jersey==='sunset_jersey'?'court_teal':'sunset_jersey';users[0].player=(await expect('equip',{itemId},users[0].session)).player;}
   a.send({type:'room.ready',lobbyId:lobby.id,ready:true});b.send({type:'room.ready',lobbyId:lobby.id,ready:true});}
  const [fa,fb]=await Promise.all([a.next('match.found'),b.next('match.found')]);
  for(const p of fa.participants){const expected=users[p.nickname==='랭킹검증0'?0:1].player;assert.deepEqual(p.athlete,attributes(expected));assert.deepEqual(p.appearance,expected.wardrobe.equipped);}
  check(fa.state.players[fa.slot].role===users[0].player.role&&fa.state.players[fb.slot].role===users[1].player.role,'server uses saved roles/attributes and ignores forged ticket athlete');
  const frame={matchId:fa.matchId,serverEpoch:fa.serverEpoch};a.send({...frame,type:'match.ready'});b.send({...frame,type:'match.ready'});await Promise.all([a.next('match.started'),b.next('match.started')]);
  [a,b][loser].send({...frame,type:'match.leave'});const [ea,eb]=await Promise.all([a.next('match.ended'),b.next('match.ended')]);
  assert.deepEqual(ea.result,eb.result);check(ea.result.saved,'both clients receive the committed result');
  return {result:ea.result,frame,slots:[fa.slot,fb.slot]};
 }finally{a.socket.close();b.socket.close();}
}
async function synthetic(reason,winner,ranked=true){
 const epoch=(await(await fetch(base+'/readyz')).json()).serverEpoch;
 const roster=[];for(const user of users){const grant=await ticket(user);roster.push(await accounts.redeem(grant.ticket,randomUUID(),epoch));}
 const room={id:randomUUID(),ranked,members:roster.map(user=>({user}))};await accounts.register(room,epoch);
 const input={reason,winner,score:[0,0],seconds:reason==='draw'?0:90};return {room,epoch,input};
}
try{
 const prior=existsSync(path)?JSON.parse(readFileSync(path,'utf8')):null;
 for(let i=0;i<2;i++){
  const username=prior?.[i].username||'qa_rank_'+randomBytes(4).toString('hex'),password=prior?.[i].password||'QA!'+randomBytes(16).toString('hex');
  const auth=await expect(prior?'login':'signup',{username,password});const user={username,password,session:auth.session};users.push(user);
  user.player=(await expect(prior?'profile':'create',prior?{}:{nickname:'랭킹검증'+i,role:i?'center':'guard'},user.session)).player;
  if(!prior){for(let j=0;j<3;j++)user.player=(await expect('train',{kind:'stat',key:i?'defense':'speed'},user.session)).player;user.player=(await expect('train',{kind:'skill',key:i?'rebound':'cross'},user.session)).player;if(i===0){await expect('buy',{itemId:'sunset_jersey'},user.session);user.player=(await expect('equip',{itemId:'sunset_jersey'},user.session)).player;}}
 }
 writeFileSync(path,JSON.stringify(users),{mode:0o600});
 if(process.argv.includes('--prepare')){console.log('Prepared two task QA accounts');process.exit(0);}
 const initial=await expect('online-ranking',{},users[0].session);check(initial.mine.rating===1000&&initial.mine.games===0,'unplayed account starts at 1000 without a public rank');
 const first=await play('public',0);check(first.result.ranked&&first.result.rankings.find(r=>r.slot===first.slots[0]).rating===984&&first.result.rankings.find(r=>r.slot===first.slots[1]).rating===1016,'equal-rating forfeit settles -16/+16');
 const duplicate=await accounts.call('online-finish',{epoch:first.frame.serverEpoch,matchId:first.frame.matchId,result:{reason:'forfeit',winner:first.slots[0],score:[0,0],seconds:90}});
 const {saved,...stored}=first.result;assert.deepEqual(duplicate.result,stored);check((await expect('online-ranking',{},users[0].session)).mine.games===1,'retry with reversed winner cannot count or alter the result');
 const second=await play('auto',1);check(second.result.rankings.find(r=>r.slot===second.slots[0]).delta===17,'lower-rated player gains more points against a stronger opponent');
 const before=await Promise.all(users.map(u=>expect('online-ranking',{},u.session)));
 const practice=await play('private',0);check(practice.result.ranked===false,'private room is explicitly unranked');
 for(let i=0;i<2;i++)assert.deepEqual((await expect('online-ranking',{},users[i].session)).mine,before[i].mine);
 check(true,'private practice leaves official games/wins/losses/Elo unchanged');
 const draw=await synthetic('draw',null);const replies=await Promise.all(Array.from({length:4},()=>accounts.finish(draw.room,draw.epoch,draw.input)));
 check(replies.every(r=>JSON.stringify(r.result)===JSON.stringify(replies[0].result)),'concurrent finish retries share one atomic settlement');
 check((await expect('online-ranking',{},users[0].session)).mine.draws===1,'draw records are counted once');
 const bad=await synthetic('score',0);let rejected=false;try{await accounts.finish(bad.room,bad.epoch,bad.input);}catch{rejected=true;}check(rejected,'inconsistent score/winner is rejected transactionally');await accounts.finish(bad.room,bad.epoch,{...bad.input,reason:'aborted',winner:null});
 check((await expect('online-ranking',{},users[0].session)).mine.games===3,'aborted matches do not affect standings');
 const board=await expect('online-ranking',{userId:'00000000-0000-0000-0000-000000000000'},users[0].session);check(board.players.every(p=>!p.user_id&&!p.id)&&board.mine.games===3,'ranking API exposes nicknames/records and fixes mine to authenticated user');
 const direct=await fetch(url+'/rest/v1/cr_online_ratings',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+users[0].session.access_token,'Content-Type':'application/json'},body:JSON.stringify({rating:99999})});check([401,403].includes(direct.status),'browser cannot write rating table');
 for(const user of users){const p=(await expect('profile',{},user.session)).player;check(p.xp===user.player.xp&&p.wardrobe.coins===user.player.wardrobe.coins,'rating does not silently award growth currency or alter player training');}
 console.log('ONLINE_RANKED_API_TEST checks='+checks);
}finally{
 if(!process.argv.includes('--keep')&&!process.argv.includes('--prepare'))for(const u of users)await expect('delete',{password:u.password},u.session);
}
