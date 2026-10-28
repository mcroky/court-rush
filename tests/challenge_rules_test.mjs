import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {STAGES,newPlayer,opponentAthlete,challengeTicket,validateChallengeResult,rewardChallenge,rewardPlayer} from '../site/career-rules.mjs';
import {CHALLENGES,challengeSetup,challengeRecord} from '../site/challenge-rules.mjs';
assert.equal(STAGES.length,24);assert.equal(Object.keys(CHALLENGES).length,5);
assert.deepEqual(challengeRecord(null,'three'),{cleared:0,best:0,games:0});
const legacy=newPlayer('center','테스트');legacy.cleared=8;
assert.equal(rewardPlayer(legacy,9,true).player.cleared,9);
assert.throws(()=>rewardPlayer(legacy,10,true));
for(let i=9;i<=24;i++){
 assert.ok(STAGES[i-1].pressure>(STAGES[i-2].pressure||1));
 assert.ok(STAGES[i-1].xp>STAGES[i-2].xp);
 assert.ok(Object.values(opponentAthlete(i)).every(v=>typeof v!=='number'||Number.isFinite(v)));
}
for(const kind of Object.keys(CHALLENGES)){
 let p=newPlayer('guard','테스트');const original=JSON.stringify(p);
 assert.throws(()=>challengeTicket(p,kind,2));
 for(let tier=1;tier<=6;tier++){
  const ticket=challengeTicket(p,kind,tier),c=ticket.challenge;
  const score=kind==='two_one'?[11,4]:[c.target,c.target];
  const result=validateChallengeResult(c,score,0,{value:c.target,rounds:c.rounds},c.seconds);
  const won=rewardChallenge(p,c,result);assert.ok(won.reward.firstClear);assert.equal(won.player.cleared,0);
  assert.equal(won.player.challengeRecord[kind].cleared,tier);
  const repeat=rewardChallenge(won.player,c,result);assert.ok(repeat.reward.xp<won.reward.xp);assert.equal(repeat.reward.firstClear,false);
  p=won.player;
 }
 assert.equal(p.challengeRecord[kind].games,6);assert.ok(p.wardrobe.coins>300);
 const c=challengeSetup(kind,1);
 assert.throws(()=>validateChallengeResult(c,[11,0],c.seconds-1,{value:99,rounds:99},1));
 assert.equal(JSON.parse(original).level,1);
}
assert.throws(()=>challengeSetup('__proto__',1));assert.throws(()=>challengeSetup('three',7));
assert.equal(readFileSync('site/career-rules.mjs','utf8'),readFileSync('supabase/functions/court-rush/rules.mjs','utf8'));
console.log('CHALLENGE_RULES: 24 courts, 30 event tiers, independent unlocks, legacy saves, rewards and invalid receipts passed');
