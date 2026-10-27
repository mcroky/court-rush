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
 const next=async(type,timeout=15000)=>{const start=Date.now();while(Date.now()-start<timeout){const i=messages.findIndex(m=>m.type===type);if(i>=0)return messages.splice(i,1)[0];const error=messages.find(m=>m.type==='error');if(error)throw Error('Socket error: '+error.code);await new Promise(r=>setTimeout(r,20));}throw Error('Timeout '+type);};
 send({type:'authenticate',ticket:ticket.ticket});await next('authenticated');return {socket,send,next,messages};
}
try{
 check((await api('online-ticket',{serverId,mode:'duel',protocolVersion:1,rulesVersion:'duel-standard-v1'})).status===401,'ticket requires existing account authentication');
 check((await api('online-boot',{serverId,epoch:crypto.randomUUID()})).status===401,'server actions reject browser/public credentials');
 const reuse=process.argv.includes('--reuse-browser')?JSON.parse(readFileSync(new URL('../artifacts/online-browser-users.json',import.meta.url),'utf8')):null;
 for(let i=0;i<2;i++){
  const username=reuse?.[i].username||'qa_net_'+randomBytes(4).toString('hex'),password=reuse?.[i].password||'QA!'+randomBytes(16).toString('hex');
  const account=await expect(reuse?'login':'signup',{username,password});const user={username,password,session:account.session};users.push(user);
  user.player=(await expect(reuse?'profile':'create',reuse?{}:{nickname:'온라인검증'+i,role:i?'center':'guard'},user.session)).player;
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
 let inputTimer,commands=0,receivedBytes=0;const matchStarted=Date.now();
 if(process.argv.includes('--full-match')){
  const started=Date.now();for(const c of [a,b])c.socket.on('message',d=>{receivedBytes+=d.length;});
  inputTimer=setInterval(()=>{const t=(Date.now()-started)/1000;for(const [slot,c] of [a,b].entries()){
   c.send({...envelope,type:'input',seq:commands++,x:Math.sin(t*.3+slot*3)*.6,z:Math.cos(t*.3+slot*3)*.6,shoot:false,shoot_pressed:false,cross:false,spin:false,twostep:false,behind:false,hesi:false,steal:false,guard:false});
   for(let i=c.messages.length-1,seen=false;i>=0;i--)if(c.messages[i].type==='snapshot'){if(seen)c.messages.splice(i,1);else seen=true;}
  }},33);
 }else a.send({...envelope,type:'match.leave'});
 let resultA,resultB;
 try{[resultA,resultB]=await Promise.all([a.next('match.ended',240000),b.next('match.ended',240000)]);}finally{clearInterval(inputTimer);}
 if(process.argv.includes('--full-match')){const elapsed=(Date.now()-matchStarted)/1000;check(resultA.result.reason==='draw'&&resultA.result.seconds===0,'real Render server completes regulation and bounded overtime without a leave command');check(elapsed>=149&&elapsed<170,'server clock matches real elapsed regulation and overtime');console.log('FULL_MATCH elapsedSeconds='+elapsed+' receivedBytes='+receivedBytes+' inputCommands='+commands);}
 check(JSON.stringify(resultA.result)===JSON.stringify(resultB.result)&&resultA.result.saved,'same result stored by the restricted server API');
 a.socket.close();b.socket.close();
 for(const user of users){const p=(await expect('profile',{},user.session)).player;check(p.xp===user.player.xp&&p.wardrobe.coins===user.player.wardrobe.coins,'online result does not change growth XP or coins');}
 console.log('ONLINE_API_TEST checks='+checks);
}finally{
 if(!process.argv.includes('--keep-browser')&&!process.argv.includes('--reuse-browser'))for(const user of users)await expect('delete',{password:user.password},user.session);
}
