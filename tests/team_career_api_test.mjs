// Only creates disposable, randomly named Court Rush QA accounts.
import {readFileSync,writeFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const config=readFileSync(new URL('../site/career-config.js',import.meta.url),'utf8');
const url=config.match(/url:'([^']+)'/)[1],key=config.match(/key:'([^']+)'/)[1];
const suffix=randomBytes(4).toString('hex'),users=[];let checks=0,passed=false;
async function call(action,body={},session=null){const r=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(session?{Authorization:'Bearer '+session.access_token}:{})},body:JSON.stringify({action,...body})});return {status:r.status,data:await r.json()};}
async function expect(action,body={},session=null,status=200){const r=await call(action,body,session);assert.equal(r.status,status,action+': '+JSON.stringify(r.data));return r.data;}
function ok(value,label){assert.ok(value,label);checks++;console.log('PASS',label);}
try{
 await expect('start',{mode:'team',requestId:randomUUID()},null,401);
 for(let i=0;i<2;i++){
  const username='qa_team_'+suffix+'_'+i,password='Qa!'+randomBytes(16).toString('hex');
  const r=await expect('signup',{username,password});users.push({username,password,session:r.session});
  await expect('create',{role:i?'center':'guard',nickname:'팀전검증'},r.session);
 }
 const [a,b]=users,id=randomUUID(),ticket=await expect('start',{mode:'team',requestId:id},a.session);
 ok(ticket.mode==='team'&&ticket.athlete.height===178&&ticket.opponents.length===3,'team ticket has personal growth snapshot and three position opponents');
 await expect('train',{kind:'stat',key:'speed'},a.session);
 const retry=await expect('start',{mode:'team',requestId:id},a.session);
 ok(retry.matchId===id&&retry.athlete.speed===ticket.athlete.speed,'start retry preserves the original snapshot after training');
 await expect('start',{stage:1,requestId:id},a.session,400);
 const idleId=randomUUID();await expect('start',{mode:'team',requestId:idleId},a.session);
 const stats={points:6,assists:2,rebounds:3,blocks:1,steals:1,activeSeconds:20};
 await expect('finish',{matchId:id,score:[11,4],seconds:155,stats},a.session,400);
 await expect('finish',{matchId:id,score:[11,4],seconds:155,stats},b.session,404);
 const denied=await fetch(url+'/rest/v1/cr_matches?select=id,game_mode,setup',{headers:{apikey:key,Authorization:'Bearer '+a.session.access_token}});
 ok([401,403].includes(denied.status),'browser cannot read match snapshots or mint receipts directly');
 console.log('Waiting 27 seconds for bounded PvE receipt validation; this is not a played match.');
 await new Promise(r=>setTimeout(r,27000));
 for(const bad of [{points:99},{assists:9},{activeSeconds:99},{blocks:-1}])await expect('finish',{matchId:id,score:[11,4],seconds:155,stats:{...stats,...bad}},a.session,400);
 const body={matchId:id,score:[11,4],seconds:155,stats,xp:999999,coins:999999,user_id:'forged'};
 const results=await Promise.all([call('finish',body,a.session),call('finish',body,a.session)]);
 for(const r of results)assert.equal(r.status,200,JSON.stringify(r.data));
 const after=(await expect('profile',{},a.session)).player;
 ok(after.level===2&&after.teamRecord.games===1&&after.teamRecord.wins===1&&after.cleared===0&&after.wins===0,'team XP levels the existing player without clearing 1v1 courts');
 ok(after.statPoints===5&&after.skillPoints===2&&after.stats.speed===1,'existing training and new level points are preserved');
 ok(after.wardrobe.coins===360&&results.every(r=>r.data.reward.coins===60&&r.data.reward.xp===120),'concurrent finish awards the server-capped XP and coins exactly once');
 const idle=await expect('finish',{matchId:idleId,score:[11,4],seconds:155,stats:{...stats,activeSeconds:0}},a.session);
 ok(idle.reward.eligible===false&&idle.reward.xp===0&&idle.player.wardrobe.coins===360,'inactive completion cannot farm growth rewards');
 const oldTicket=await expect('start',{stage:1,requestId:randomUUID()},a.session);
 ok(oldTicket.stage===1&&oldTicket.opponent.athlete&&oldTicket.athlete.level===2,'legacy 1v1 start still works after team growth');
 console.log('TEAM_CAREER_API checks='+checks+' passed');passed=true;
 if(process.argv.includes('--keep-ui'))writeFileSync(new URL('../artifacts/team-career-qa-session.json',import.meta.url),JSON.stringify(a));
}finally{
 for(let i=0;i<users.length;i++){
  if(i===0&&passed&&process.argv.includes('--keep-ui'))continue;
  const u=users[i],r=await call('delete',{password:u.password},u.session);
  if(r.status!==200){console.error('Disposable QA cleanup required: '+u.username+' status='+r.status);process.exitCode=1;}else console.log('Disposable QA account removed');
 }
}
