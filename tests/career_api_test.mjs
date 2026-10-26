// Creates only its own random QA accounts and removes them through the app API.
// No real player's records or credentials are read or modified.
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const config=readFileSync(new URL('../site/career-config.js',import.meta.url),'utf8');
const url=config.match(/url:'([^']+)'/)[1],key=config.match(/key:'([^']+)'/)[1];
const suffix=randomBytes(4).toString('hex'),users=[];let checks=0;
async function call(action,body={},session=null){const response=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(session?{Authorization:'Bearer '+session.access_token}:{})},body:JSON.stringify({action,...body})});return {status:response.status,data:await response.json()};}
function ok(condition,label){assert.ok(condition,label);checks++;console.log('PASS',label);}
async function expect(action,body,session,status=200){const r=await call(action,body,session);assert.equal(r.status,status,action+': '+JSON.stringify(r.data));return r.data;}
try{
 ok((await call('profile')).status===401,'unauthenticated profile denied');
 for(let i=0;i<2;i++){
  const username='qa_cr_'+suffix+'_'+i,password='Qa!'+randomBytes(16).toString('hex');
  const r=await expect('signup',{username,password});users.push({username,password,session:r.session,code:r.recoveryCode});
  ok(r.recoveryCode.length===32&&!r.email,'ID signup returns a recovery code without email input');
 }
 const [a,b]=users;
 const logged=await expect('login',{username:a.username.toUpperCase(),password:a.password});a.session=logged.session;
 ok(logged.username===a.username,'ID normalization and password login');
 const wrong=await call('login',{username:a.username,password:'wrong_password_123'});
 const absent=await call('login',{username:'qa_absent_'+suffix,password:'wrong_password_123'});
 ok(wrong.status===401&&absent.status===401&&wrong.data.error===absent.data.error,'login error does not disclose account existence');
 for(const token of [null,a.session]){
  const r=await fetch(url+'/rest/v1/cr_accounts?select=*',{headers:{apikey:key,...(token?{Authorization:'Bearer '+token.access_token}:{})}});
  ok(r.status===401||r.status===403,'Auth mapping table cannot be read by browser roles');
 }
 const p=(await expect('create',{role:'guard',nickname:'검증선수'},a.session)).player;
 ok(p.role==='guard'&&p.statPoints===3,'server creates a guarded progression profile');
 ok(p.wardrobe.coins===300&&p.wardrobe.owned.length===5,'new player receives starter coins and five default items');
 const purchase=await expect('buy',{itemId:'sunset_jersey',price:0,coins:999999,user_id:'forged'},a.session);
 ok(purchase.player.wardrobe.coins===180&&purchase.receipt.spent===120,'server ignores forged price, currency and owner');
 const duplicateBuy=await expect('buy',{itemId:'sunset_jersey'},a.session);
 ok(duplicateBuy.receipt.spent===0&&duplicateBuy.player.wardrobe.coins===180,'purchase retry does not charge twice');
 await expect('equip',{itemId:'ice_shoes'},a.session,400);
 await expect('buy',{itemId:'volt_jersey'},a.session,400);
 await expect('buy',{itemId:'not_for_sale'},a.session,400);
 await expect('buy',{itemId:'sunset_jersey'},null,401);
 const shopping=await Promise.all([call('buy',{itemId:'slate_shorts'},a.session),call('buy',{itemId:'slate_shorts'},a.session)]);
 ok(shopping.some(r=>r.status===200)&&shopping.every(r=>[200,409].includes(r.status)),'concurrent shopping resolves safely');
 await expect('buy',{itemId:'slate_shorts'},a.session);
 await expect('equip',{itemId:'sunset_jersey'},a.session);await expect('equip',{itemId:'slate_shorts'},a.session);
 const outfit=(await expect('profile',{},a.session)).player;
 ok(outfit.wardrobe.coins===90&&outfit.wardrobe.owned.length===7&&outfit.wardrobe.equipped.jersey==='sunset_jersey','inventory and wallet persisted without duplicate charges');
 await expect('create',{role:'center',nickname:'두번째선수'},a.session,409);
 for(let i=0;i<3;i++)await expect('train',{kind:'stat',key:'speed'},a.session);
 await expect('train',{kind:'stat',key:'speed'},a.session,400);
 const empty=(await expect('profile',{},a.session)).player;
 ok(empty.statPoints===0&&empty.stats.speed===3,'no point overspend');
 await expect('start',{stage:2,requestId:randomUUID()},a.session,400);
 const id=randomUUID(),ticket=await expect('start',{stage:1,requestId:id},a.session);
 ok(ticket.athlete.height===178&&ticket.opponent.athlete.height===178,'match snapshot includes physical position data');
 ok(ticket.athlete.appearance.jersey==='sunset_jersey'&&!ticket.opponent.athlete.appearance,'personal outfit enters game snapshot without dressing opponent');
 const duplicate=await expect('start',{stage:1,requestId:id},a.session);ok(duplicate.matchId===id,'start retry reuses ticket');
 const fast=await call('finish',{matchId:id,score:[11,0],seconds:89},a.session);ok(fast.status===400,'instant forged victory rejected');
 const foreign=await call('finish',{matchId:id,score:[11,0],seconds:70},b.session);ok(foreign.status>=400,'another account cannot claim a match');
 console.log('Waiting 18 seconds for the bounded PvE receipt fixture. This is API validation, not a gameplay victory.');
 await new Promise(resolve=>setTimeout(resolve,18000));
 const results=await Promise.all([call('finish',{matchId:id,score:[11,4],seconds:72},a.session),call('finish',{matchId:id,score:[11,4],seconds:72},a.session)]);
 results.forEach(r=>assert.equal(r.status,200,JSON.stringify(r.data)));
 const after=(await expect('profile',{},a.session)).player;
 ok(after.level===2&&after.wins===1&&after.cleared===1&&after.statPoints===3,'concurrent result retry rewards only once');
 ok(results.every(r=>r.data.reward.xp===100),'reward amount is fixed by server');
 ok(after.wardrobe.coins===210&&after.wardrobe.equipped.shorts==='slate_shorts','concurrent finish awards 120 coins only once and preserves outfit');
 await expect('buy',{itemId:'ice_shoes'},a.session);await expect('equip',{itemId:'ice_shoes'},a.session);
 await Promise.all(Array.from({length:7},()=>call('train',{kind:'stat',key:'handle'},a.session)));
 const trained=(await expect('profile',{},a.session)).player;
 ok(trained.statPoints>=0&&trained.stats.handle+trained.statPoints===3,'concurrent training cannot spend the same point twice');
 ok((await expect('profile',{},b.session)).player===null,'second account remains isolated');
 const old=a.session;await expect('logout',{},a.session);ok((await call('profile',{},old)).status===401,'logout invalidates the old server session');
 const nextPassword='New!'+randomBytes(16).toString('hex');
 const reset=await expect('recover',{username:a.username,password:nextPassword,recoveryCode:a.code});a.password=nextPassword;
 ok(reset.recoveryCode.length===32&&reset.recoveryCode!==a.code,'recovery changes password and rotates code without email');
 a.session=(await expect('login',{username:a.username,password:a.password})).session;
 const restored=(await expect('profile',{},a.session)).player;
 ok(restored.wardrobe.coins===50&&restored.wardrobe.equipped.shoes==='ice_shoes','clothes and balance survive logout, recovery and new session');
 ok((await call('profile',{},old)).status===401,'old session remains invalid after account recovery');
 console.log('CAREER_API checks='+checks+' passed');
}finally{
 for(const u of users){
  let token=u.session;let r=await call('delete',{password:u.password},token);
  if(r.status===401){const login=await call('login',{username:u.username,password:u.password});if(login.status===200)r=await call('delete',{password:u.password},login.data.session);}
  if(r.status!==200){console.error('QA cleanup required for '+u.username+' status='+r.status);process.exitCode=1;}else console.log('QA account removed:',u.username);
 }
}
