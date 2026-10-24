import assert from 'node:assert/strict';
import {ROLES,STAGES,newPlayer,attributes,rewardPlayer,trainPlayer,xpNeeded,opponentAthlete} from '../site/career-rules.mjs';
for(const role of Object.keys(ROLES)){
 const first=newPlayer(role,'코트선수');const base=attributes(first);
 assert.equal(base.height,ROLES[role].height);assert.equal(first.statPoints,3);assert.equal(first.skillPoints,1);
 const trained=trainPlayer(first,'stat','speed');assert.equal(first.stats.speed,0);assert.equal(attributes(trained).speed,base.speed+1);assert.equal(trained.statPoints,2);
 const skill=trainPlayer(first,'skill','cross');assert.equal(skill.skills.cross,1);assert.equal(skill.skillPoints,0);assert.throws(()=>trainPlayer(skill,'skill','cross'));
 const won=rewardPlayer(first,1,true);assert.equal(won.player.level,2);assert.equal(won.player.statPoints,6);assert.equal(won.player.skillPoints,2);assert.equal(won.player.cleared,1);assert.equal(won.reward.xp,100);
 assert.equal(rewardPlayer(won.player,1,true).reward.xp,35);assert.equal(rewardPlayer(first,1,false).player.cleared,0);assert.throws(()=>rewardPlayer(first,2,true));
 let cap={...first,statPoints:100,skillPoints:100};for(let i=0;i<20;i++)cap=trainPlayer(cap,'stat','speed');assert.throws(()=>trainPlayer(cap,'stat','speed'));
 for(let i=0;i<5;i++)cap=trainPlayer(cap,'skill','shoot');assert.throws(()=>trainPlayer(cap,'skill','shoot'));
 assert.ok(attributes(cap).speed<=99);
}
assert.throws(()=>newPlayer('__proto__','선수'));assert.throws(()=>trainPlayer(newPlayer('guard','선수'),'stat','__proto__'));
for(let i=1;i<=STAGES.length;i++){assert.equal(opponentAthlete(i).role,STAGES[i-1].role);assert.ok(opponentAthlete(i).shoot<=99);}
assert.ok(xpNeeded(10)>xpNeeded(2));
console.log('CAREER_RULES: three positions, height, XP/first/repeat/loss, point spending, immutable originals, caps and stage gating passed');
