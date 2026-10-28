// Own disposable QA profile only; never reads or changes an existing player's data.
import {readFileSync,writeFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {CHALLENGES,challengeSetup} from '../site/challenge-rules.mjs';
const cfg=readFileSync('site/career-config.js','utf8'),url=cfg.match(/url:'([^']+)'/)[1],key=cfg.match(/key:'([^']+)'/)[1];
const username='qa_ch_'+randomBytes(4).toString('hex'),password='Qa!'+randomBytes(16).toString('hex');
let session,keep=false;
async function call(action,body={},auth=session){const r=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{Origin:'https://mcroky.github.io',apikey:key,'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth.access_token}:{})},body:JSON.stringify({action,...body})});return {status:r.status,data:await r.json()};}
async function expect(action,body={},status=200,auth=session){const r=await call(action,body,auth);assert.equal(r.status,status,action+': '+JSON.stringify(r.data));return r.data;}
try{
 const catalog=await expect('challenge-catalog');assert.equal(catalog.courts,24);assert.equal(Object.keys(catalog.challenges).length,5);
 await expect('start',{mode:'challenge',kind:'free_throw',tier:1,requestId:randomUUID()},401,null);
 const signed=await expect('signup',{username,password});session=signed.session;
 await expect('create',{role:'forward',nickname:'도전검증'});
 await expect('start',{mode:'challenge',kind:'three',tier:2,requestId:randomUUID()},400);
 await expect('start',{mode:'challenge',kind:'__proto__',tier:1,requestId:randomUUID()},400);
 const tickets=[];
 for(const kind of Object.keys(CHALLENGES)){
  const id=randomUUID(),data=await expect('start',{mode:'challenge',kind,tier:1,requestId:id});
  assert.equal(data.challenge.kind,kind);assert.equal(data.athlete.height,190);
  const retry=await expect('start',{mode:'challenge',kind,tier:1,requestId:id});assert.deepEqual(retry,data);
  await expect('finish',{matchId:id,score:[11,0],seconds:89,challengeResult:{value:100,rounds:100}},400);
  tickets.push(data);
 }
 await expect('start',{stage:1,requestId:randomUUID()});
 console.log('CHALLENGE_API: tickets, replay identity, unauthorized/locked/forged results passed; waiting 19 seconds for bounded receipt fixture.');
 await new Promise(r=>setTimeout(r,19000));
 let expectedCoins=300;
 for(const ticket of tickets){
  const c=ticket.challenge,body={matchId:ticket.matchId,score:c.kind==='two_one'?[11,3]:[c.target,c.target],seconds:c.seconds-20,challengeResult:{value:c.target,rounds:c.rounds}};
  const r=await expect('finish',body);expectedCoins+=c.coins;
  assert.equal(r.player.challengeRecord[c.kind].cleared,1);assert.equal(r.player.cleared,0);assert.equal(r.player.wardrobe.coins,expectedCoins);
  const duplicate=await expect('finish',body);assert.equal(duplicate.player.wardrobe.coins,expectedCoins);
  await expect('start',{mode:'challenge',kind:c.kind,tier:2,requestId:randomUUID()});
 }
 const after=await expect('profile');assert.equal(after.player.cleared,0);assert.equal(Object.keys(after.player.challengeRecord).length,5);
 console.log('CHALLENGE_API: five server reward receipts, first clear, duplicate claim, next-tier unlock, wallet and independent court record passed');
 if(process.argv.includes('--keep-ui')){keep=true;writeFileSync('artifacts/challenge-qa-login.json',JSON.stringify({username,password}));}
}finally{
 if(session&&!keep){const r=await call('delete',{password});assert.equal(r.status,200,'Disposable QA cleanup');console.log('Own disposable QA profile removed');}
}
