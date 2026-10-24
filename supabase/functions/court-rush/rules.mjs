function reject(message){throw Object.assign(Error(message),{status:400});}
export const STAT_NAMES={speed:'이동',handle:'핸들링',shoot:'슈팅',finish:'골밑 마무리',defense:'수비',rebound:'리바운드'};
export const ROLES={
 guard:{name:'가드',height:178,weight:76,tag:'빠른 첫발과 볼 핸들링',base:{speed:64,handle:68,shoot:60,finish:48,defense:47,rebound:33}},
 forward:{name:'포워드',height:190,weight:87,tag:'돌파와 마무리, 균형 있는 공수',base:{speed:56,handle:51,shoot:58,finish:65,defense:55,rebound:55}},
 center:{name:'센터',height:204,weight:103,tag:'골밑 몸싸움과 높은 리바운드',base:{speed:42,handle:33,shoot:39,finish:68,defense:68,rebound:75}}
};
export const SKILLS={cross:{name:'크로스오버',description:'돌파 뒤 재사용 대기 감소'},spin:{name:'턴 드리블',description:'턴 뒤 재사용 대기 감소'},shoot:{name:'점퍼',description:'점프슛 성공률 보너스'},finish:{name:'피니셔',description:'레이업·덩크 성공률 보너스'},steal:{name:'볼 호크',description:'접촉한 스틸 성공률 보너스'},rebound:{name:'리바운드',description:'리바운드 도약 높이 보너스'}};
export const STAGES=[
 {name:'첫 코트',role:'guard',level:1,xp:100}, {name:'드라이브 인',role:'forward',level:2,xp:120},
 {name:'페인트 지킴이',role:'center',level:3,xp:140}, {name:'퀵 핸들',role:'guard',level:4,xp:170},
 {name:'하이 플라이어',role:'forward',level:5,xp:200}, {name:'림의 주인',role:'center',level:6,xp:240},
 {name:'동네 에이스',role:'guard',level:8,xp:280}, {name:'코트 챔피언',role:'forward',level:10,xp:330}
];
export function xpNeeded(level){return 100+(level-1)*60;}
export function newPlayer(role,nickname){
 if(!Object.hasOwn(ROLES,role)||typeof nickname!=='string'||nickname.trim().length<2||nickname.trim().length>12)reject('포지션과 2~12자 선수 이름을 확인하세요.');
 return {version:1,nickname:nickname.trim(),role,level:1,xp:0,statPoints:3,skillPoints:1,cleared:0,wins:0,losses:0,stats:Object.fromEntries(Object.keys(STAT_NAMES).map(k=>[k,0])),skills:Object.fromEntries(Object.keys(SKILLS).map(k=>[k,0]))};
}
export function attributes(p){
 const r=ROLES[p.role];if(!r)reject('선수 데이터가 올바르지 않습니다.');
 return {...Object.fromEntries(Object.keys(STAT_NAMES).map(k=>[k,Math.min(99,r.base[k]+p.stats[k])])),height:r.height,weight:r.weight,role:p.role,skills:{...p.skills},training:{...p.stats},level:p.level};
}
export function opponentAthlete(stage){const s=STAGES[stage-1],p=newPlayer(s.role,s.name);p.level=s.level;for(const k of Object.keys(p.stats))p.stats[k]=Math.min(20,(s.level-1)*(k==='shoot'?2:1));return attributes(p);}
export function trainPlayer(original,kind,key){
 const p=structuredClone(original),stat=kind==='stat';
 if(!['stat','skill'].includes(kind)||!Object.hasOwn(stat?STAT_NAMES:SKILLS,key))reject('훈련 항목을 확인하세요.');
 const pool=stat?'statPoints':'skillPoints',group=stat?'stats':'skills',cap=stat?20:5;
 if(p[pool]<1)reject('성장 포인트가 부족합니다.');
 if(p[group][key]>=cap)reject('현재 훈련 상한에 도달했습니다.');
 p[pool]--;p[group][key]++;return p;
}
export function rewardPlayer(original,stage,won){
 if(!Number.isInteger(stage)||stage<1||stage>STAGES.length||stage>original.cleared+1)reject('아직 도전할 수 없는 코트입니다.');
 const p=structuredClone(original),first=won&&stage>p.cleared;
 const xp=won?(first?STAGES[stage-1].xp:Math.floor(STAGES[stage-1].xp*.35)):25;
 p.xp+=xp;p.wins+=Number(won);p.losses+=Number(!won);if(won)p.cleared=Math.max(p.cleared,stage);
 while(p.level<20&&p.xp>=xpNeeded(p.level)){p.xp-=xpNeeded(p.level);p.level++;p.statPoints+=3;p.skillPoints++;}
 if(p.level===20)p.xp=Math.min(p.xp,xpNeeded(20)-1);
 return {player:p,reward:{xp,firstClear:first,won,stage}};
}
