// Shared immutable PvE objectives. Saved IDs never depend on translated labels.
export const CHALLENGES={
 free_throw:{name:'자유투 도전',tag:'FREE THROW',description:'자유투 라인에서 10번의 슛. D를 눌렀다 초록 구간에 놓으세요.',rounds:10,seconds:120,targets:[4,5,6,7,8,9]},
 rebound:{name:'리바운드왕 도전',tag:'REBOUND KING',description:'림에 맞고 나온 공을 D로 공중 캐치. W로 박스아웃하세요. 바닥에서 주운 공은 기록에 포함되지 않습니다.',rounds:8,seconds:100,targets:[3,4,5,6,7,8]},
 three:{name:'3점슛왕 도전',tag:'THREE POINT KING',description:'다섯 지점에서 두 번씩, 총 10번의 3점슛에 도전하세요.',rounds:10,seconds:120,targets:[3,4,5,6,7,8]},
 steal:{name:'스틸왕 도전',tag:'STEAL KING',description:'8번의 수비 기회. 움직이는 상대의 공 쪽으로 접근해 S로 스틸하세요.',rounds:8,seconds:100,targets:[2,3,4,5,6,7]},
 two_one:{name:'2대1 도전',tag:'ONE VS TWO',description:'내 선수 혼자 AI 두 명을 상대합니다. 패스 길을 막고 돌파로 공간을 만드세요. 11점 또는 90초 승부.',rounds:0,seconds:90,targets:[1,1,1,1,1,1]}
};
export function challengeSetup(kind,tier){
 const c=Object.hasOwn(CHALLENGES,kind)?CHALLENGES[kind]:null;
 if(!c||!Number.isInteger(tier)||tier<1||tier>6)throw Object.assign(Error('도전 종목과 단계를 확인하세요.'),{status:400});
 return {kind,tier,name:c.name,tag:c.tag,description:c.description,rounds:c.rounds,seconds:c.seconds,target:c.targets[tier-1],xp:100+tier*30,coins:70+tier*15};
}
export function challengeRecord(player,kind){return player?.challengeRecord?.[kind]||{cleared:0,best:0,games:0};}

