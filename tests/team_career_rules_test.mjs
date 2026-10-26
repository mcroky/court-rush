import assert from 'node:assert/strict';
import {newPlayer,rewardTeamPlayer,validateTeamResult,teamOpponents} from '../site/career-rules.mjs';
const stats={points:6,assists:2,rebounds:3,blocks:1,steals:1,activeSeconds:60};
assert.deepEqual(validateTeamResult([11,7],80,stats,110),stats);
for(const patch of [{points:12},{assists:6},{activeSeconds:102},{steals:41},{blocks:-1},{rebounds:1.5},{points:NaN}])assert.throws(()=>validateTeamResult([11,7],80,{...stats,...patch},110));
for(const args of [[[4,4],0,stats,181],[[11,2],170,stats,181],[[10,7],1,stats,181],[[14,2],80,stats,110],[[11,7],80,stats,10]])assert.throws(()=>validateTeamResult(...args));
for(const role of ['guard','forward','center']){
 const p=newPlayer(role,'팀전선수'),before=structuredClone(p),result=rewardTeamPlayer(p,true,stats);
 assert.deepEqual(p,before);assert.equal(result.reward.xp,120);assert.equal(result.reward.coins,60);
 assert.equal(result.player.level,2);assert.equal(result.player.statPoints,6);assert.equal(result.player.skillPoints,2);
 assert.equal(result.player.cleared,0);assert.equal(result.player.wins,0);assert.equal(result.player.teamRecord.wins,1);
 assert.equal(result.player.wardrobe.coins,360);
 const loss=rewardTeamPlayer(p,false,stats);assert.equal(loss.reward.xp,85);assert.equal(loss.reward.coins,40);
 const idle=rewardTeamPlayer(p,true,{...stats,activeSeconds:0});assert.equal(idle.reward.xp,0);assert.equal(idle.reward.coins,0);assert.equal(idle.reward.eligible,false);
 const ai=teamOpponents(p);assert.equal(ai.length,3);assert.deepEqual(ai.map(a=>a.role),['guard','forward','center']);assert.ok(ai.every(a=>!a.appearance));
}
const empty={points:0,assists:0,rebounds:0,blocks:0,steals:0,activeSeconds:20};
const assist={...empty,assists:1},board={...empty,rebounds:1},score={...empty,points:2};
assert.ok(rewardTeamPlayer(newPlayer('guard','선수'),true,assist).reward.contribution>rewardTeamPlayer(newPlayer('center','선수'),true,assist).reward.contribution);
assert.ok(rewardTeamPlayer(newPlayer('center','선수'),true,board).reward.contribution>rewardTeamPlayer(newPlayer('guard','선수'),true,board).reward.contribution);
assert.ok(rewardTeamPlayer(newPlayer('forward','선수'),true,score).reward.contribution>rewardTeamPlayer(newPlayer('guard','선수'),true,score).reward.contribution);
console.log('TEAM_CAREER_RULES: win/loss, role contribution, bounds, inactivity, shared XP/coins, isolated court unlock and immutable profiles passed');
