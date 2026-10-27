import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {ROLES,STAT_NAMES,SKILLS,STAGES,newPlayer} from '../site/career-rules.mjs';
const source=name=>readFileSync(new URL('../site/'+name,import.meta.url),'utf8');
const storage=new Map();
const window={navigator:{language:'ko-KR'},localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)}};
const context=vm.createContext({window});
for(const name of ['locales.js','wardrobe-locales.js','i18n.js','info-locales.js'])vm.runInContext(source(name),context);
const I=window.CourtI18n,keys=new Set();
for(const row of window.CourtMessages){assert.equal(row.length,4);assert.ok(!keys.has(row[0]),'Duplicate key: '+row[0]);keys.add(row[0]);for(const value of row.slice(1)){assert.equal(typeof value,'string');assert.ok(value.trim());assert.doesNotMatch(value,/[가-힣]/,'Untranslated: '+row[0]);}}
const labels=[...Object.values(ROLES).flatMap(r=>[r.name,r.tag]),...Object.values(STAT_NAMES),...Object.values(SKILLS).flatMap(s=>[s.name,s.description]),...STAGES.map(s=>s.name)];
const dynamic=[
 '블록 성공! · 우리 공','블록 성공! · 상대 공',
 'v0.9.0 · AI 1대1·3대3 육성 · 계정과 선수 기록은 서버에 저장됩니다.',
 '코트 준비 중 42%','공격 제한 15초','내 슛 3/7 성공 · 한 판 더 도전해 보세요.',
 '다음 레벨 25 / 100 XP','센터 · 204cm / 103kg · Lv.1','COURT 03 · 센터 Lv.3',
 '리바운드 기술 훈련 1포인트','✓ 클리어 · 다시 도전 / 100 XP','드리브 인 도전 시작'.replace('드리브','드라이브'),
 '승리! +100 XP · Lv.2 · 스탯 6P / 기술 2P','CROSS · 속임 → 바운스 → 반대 손',
 'v0.7.1 · AI 1대1 육성 · 계정과 선수 기록은 서버에 저장됩니다.',
 '보상 저장 대기 · 서버 요청을 완료하지 못했습니다.','동작: 달리기 → 크로스오버'
 ,'8코트 클리어 후 구매','의상 상점 · 300 코인','구매하기 · 2250 코인','승리! +100 XP · Lv.2 · 스탯 6P / 기술 2P · +120 코인'
];
for(const language of ['en','ja','zh-CN']){
 I.setLanguage(language);
 for(const label of [...labels,...dynamic])assert.doesNotMatch(I.text(label),/[가-힣]/,`${language}: ${label}`);
 assert.equal(I.text('court_player_01'),'court_player_01');
 assert.ok(I.text('한글선수 · 센터 · Lv.2 / 3코트 클리어').startsWith('한글선수'),'Player name changed');
 for(const marker of ['GET INTO YOUR RHYTHM','COURT NOTES'])assert.doesNotMatch(I.infoHTML(marker),/[가-힣]/);
 assert.equal(storage.get('court-rush.language.v1'),language);
}
assert.equal(I.normalize('zh-TW'),'zh-CN');assert.equal(I.normalize('ja-JP'),'ja');assert.equal(I.normalize('fr'),null);
const before=newPlayer('center','센터');const snapshot=JSON.stringify(before);I.setLanguage('en');I.setLanguage('ja');I.setLanguage('ko');assert.equal(JSON.stringify(before),snapshot);
assert.equal(I.text('소리 켬 ♪'),'소리 켬 ♪');
for(const name of ['../supabase/functions/court-rush/index.ts','../site/career-rules.mjs']){
 const code=readFileSync(new URL(name,import.meta.url),'utf8');
 for(const match of code.matchAll(/(?:fail|reject)\('([^']+)'/g))for(const language of ['en','ja','zh-CN'])assert.doesNotMatch(I.text(match[1],language),/[가-힣]/,'Untranslated server error: '+match[1]);
}
// Cover authored static text on all shipped pages, including privacy and research tools.
for(const name of ['index.html','privacy.html','character-lab.html','motion-lab.html']){
 const html=source(name).replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1>/g,'');
 const pieces=[...html.matchAll(/>([^<>]+)</g)].map(m=>m[1].trim()).filter(t=>/[가-힣]/.test(t));
 for(const language of ['en','ja','zh-CN'])for(const piece of pieces)assert.doesNotMatch(I.text(piece,language),/[가-힣]/,`${name}/${language}: ${piece}`);
}
console.log(`LOCALIZATION: ${keys.size} source labels × 3 translations; runtime stats/rewards, all four pages, help, errors, preference and player-data invariants passed`);
