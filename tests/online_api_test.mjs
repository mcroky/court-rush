// Uses only fresh, disposable QA accounts. --keep-browser retains them for browser QA.
import {readFileSync,writeFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
import WebSocket from '../server/node_modules/ws/index.js';
const config=readFileSync(new URL('../site/career-config.js',import.meta.url),'utf8');
const url=config.match(/url:'([^']+)'/)[1],key=config.match(/key:'([^']+)'/)[1],users=[];
const serverId='court-rush-online-free',serverURL=process.env.CR_TEST_SERVER_URL||'http://127.0.0.1:8792';
let checks=0;
const check=(condition,label)=>{assert.ok(condition,label);checks++;console.log('PASS',label);};
async function api(action,body={},session=null){
 const response=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(session?{Authorization:'Bearer '+session.access_token}:{})},body:JSON.stringify({action,...body})});
 const data=await response.json();return {status:response.status,data};
}
async function expect(action,body={},session=null){const r=await api(action,body,session);assert.equal(r.status,200,action+': '+JSON.stringify(r.data));return r.data;}
async function connect(user){
 const ticket=await expect('online-ticket',{serverId,mode:'duel',protocolVersion:1,rulesVersion:'duel-standard-v1'},user.session);
 const socket=new WebSocket(serverURL.replace(/^http/,'ws')+'/play'),messages=[];
 socket.on('message',d=>messages.push(JSON.parse(String(d))));
 await new Promise((resolve,reject)=>{socket.once('open',resolve);socket.once('error',reject);});
 const send=m=>socket.send(JSON.stringify({protocolVersion:1,...m}));
 const next=async(type)=>{const start=Date.now();while(Date.now()-start<15000){const i=messages.findIndex(m=>m.type===type);if(i>=0)return messages.splice(i,1)[0];const error=messages.find(m=>m.type==='error');if(error)throw Error('Socket error: '+error.code);await new Promise(r=>setTimeout(r,20));}throw Error('Timeout '+type);};
 send({type:'authenticate',ticket:ticket.ticket});await next('authenticated');return {socket,send,next,messages};
}
try{
 check((await api('online-ticket',{serverId,mode:'duel',protocolVersion:1,rulesVersion:'duel-standard-v1'})).status===401,'ticket requires existing account authentication');
 check((await api('online-boot',{serverId,epoch:crypto.randomUUID()})).status===401,'server actions reject browser/public credentials');
 for(let i=0;i<2;i++){
  const username='qa_net_'+randomBytes(4).toString('hex'),password='QA!'+randomBytes(16).toString('hex');
  const account=await expect('signup',{username,password});const user={username,password,session:account.session};users.push(user);
  user.player=(await expect('create',{nickname:'온라인검증'+i,role:i?'center':'guard'},user.session)).player;
 }
 writeFileSync(new URL('../artifacts/online-test-users.json',import.meta.url),JSON.stringify(users),{mode:0o600});
 for(const table of ['cr_online_servers','cr_online_tickets','cr_online_matches','cr_online_participants']){
  const response=await fetch(url+'/rest/v1/'+table+'?select=*',{headers:{apikey:key,Authorization:'Bearer '+users[0].session.access_token}});
  check([401,403].includes(response.status),table+' cannot be read by browser');
 }
 const [a,b]=await Promise.all(users.map(connect));
 a.send({type:'queue.join',mode:'duel'});b.send({type:'queue.join',mode:'duel'});
 const [foundA,foundB]=await Promise.all([a.next('match.found'),b.next('match.found')]);
 check(foundA.matchId===foundB.matchId&&foundA.slot!==foundB.slot,'real accounts matched to separate authoritative slots');
 check(foundA.participants.every(p=>!p.id&&!p.userId&&!p.session),'roster does not disclose account/session identifiers');
 const envelope={matchId:foundA.matchId,serverEpoch:foundA.serverEpoch};
 a.send({...envelope,type:'match.ready'});b.send({...envelope,type:'match.ready'});await Promise.all([a.next('match.started'),b.next('match.started')]);
 a.send({...envelope,type:'match.leave'});
 const [resultA,resultB]=await Promise.all([a.next('match.ended'),b.next('match.ended')]);
 check(JSON.stringify(resultA.result)===JSON.stringify(resultB.result)&&resultA.result.saved,'same result stored by the restricted server API');
 a.socket.close();b.socket.close();
 for(const user of users){const p=(await expect('profile',{},user.session)).player;check(p.xp===user.player.xp&&p.wardrobe.coins===user.player.wardrobe.coins,'online result does not change growth XP or coins');}
 console.log('ONLINE_API_TEST checks='+checks);
}finally{
 if(!process.argv.includes('--keep-browser'))for(const user of users)await expect('delete',{password:user.password},user.session);
}
