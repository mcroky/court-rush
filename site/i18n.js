(function(root){
 'use strict';
 const names={ko:'한국어',en:'English',ja:'日本語','zh-CN':'简体中文'},columns={en:1,ja:2,'zh-CN':3};
 const catalog=new Map((root.CourtMessages||[]).map(row=>[row[0],row]));
 const normalize=value=>/^zh/i.test(value)?'zh-CN':/^(ko|en|ja)(-|$)/i.test(value)?value.slice(0,2).toLowerCase():null;
 let locale='ko';
 try{locale=normalize(root.localStorage?.getItem('court-rush.language.v1'))||normalize(root.navigator?.language)||'ko';}catch{}
 function text(source,language=locale){
  if(typeof source!=='string'||language==='ko')return source;
  const value=source.trim(),row=catalog.get(value),column=columns[language];
  if(row&&column)return source.replace(value,row[column]);
  const replace=(pattern,fn)=>{const match=value.match(pattern);return match?source.replace(value,fn(match)):null;};
  let result;

  const choice=(en,ja,zh)=>({en,ja,'zh-CN':zh})[language];
  if((result=replace(/^목표 (\d+) \/ (\d+) · (\d+)초$/,m=>choice(`Goal ${m[1]} / ${m[2]} · ${m[3]}s`,`目標 ${m[1]} / ${m[2]}・${m[3]}秒`,`目标 ${m[1]} / ${m[2]} · ${m[3]}秒`)))!==null)return result;
  if((result=replace(/^(\d+)코트 클리어 후 구매$/,m=>choice(`Clear court ${m[1]} to purchase`,`コート${m[1]}クリア後に購入`,`通关球场 ${m[1]} 后可购买`)))!==null)return result;
  if((result=replace(/^(.+) · \+(\d+) 코인$/,m=>`${text(m[1],language)} · +${m[2]} ${choice('coins','コイン','金币')}`))!==null)return result;
  if((result=replace(/^(\d+) 코인$/,m=>`${m[1]} ${choice('coins','コイン','金币')}`))!==null)return result;
  if((result=replace(/^코트 준비 중 (\d+)%$/,m=>choice(`Loading court ${m[1]}%`,`コート準備中 ${m[1]}%`,`球场加载中 ${m[1]}%`)))!==null)return result;
  if((result=replace(/^(캐릭터|모션) 준비 중 (\d+)%$/,m=>choice(`Loading ${m[1]==='캐릭터'?'characters':'motion'} ${m[2]}%`,`${m[1]==='캐릭터'?'キャラクター':'モーション'}準備中 ${m[2]}%`,`${m[1]==='캐릭터'?'角色':'动作'}加载中 ${m[2]}%`)))!==null)return result;
  if((result=replace(/^(가드|포워드|센터) Lv\.(\d+)$/,m=>`${text(m[1],language)} Lv.${m[2]}`))!==null)return result;
  if((result=replace(/^이 브라우저에서 필요한 기능을 사용할 수 없습니다: (.+)$/,m=>choice(`Required browser features are unavailable: ${m[1]}`,`必要なブラウザー機能を利用できません：${m[1]}`,`浏览器缺少所需功能：${m[1]}`)))!==null)return result;
  if((result=replace(/^(캐릭터|모션)을 불러오지 못했습니다\. (.+)$/,m=>choice(`Could not load ${m[1]==='캐릭터'?'characters':'motion'}. ${m[2]}`,`${m[1]==='캐릭터'?'キャラクター':'モーション'}を読み込めません。${m[2]}`,`无法加载${m[1]==='캐릭터'?'角色':'动作'}。${m[2]}`)))!==null)return result;
  if((result=replace(/^공격 제한 (\d+)초$/,m=>choice(`Shot clock ${m[1]}s`,`攻撃残り ${m[1]}秒`,`进攻剩余 ${m[1]}秒`)))!==null)return result;
  if((result=replace(/^내 슛 (\d+)\/(\d+) 성공 · 한 판 더 도전해 보세요\.$/,m=>choice(`Your shots ${m[1]}/${m[2]} · Ready for another game?`,`シュート ${m[1]}/${m[2]}成功・もう一戦どうですか？`,`投篮 ${m[1]}/${m[2]} 命中 · 再挑战一局吧。`)))!==null)return result;
  if((result=replace(/^다음 레벨 (\d+) \/ (\d+) XP$/,m=>choice(`Next level ${m[1]} / ${m[2]} XP`,`次のレベル ${m[1]} / ${m[2]} XP`,`下一级 ${m[1]} / ${m[2]} XP`)))!==null)return result;
  if((result=replace(/^(.*?) · (가드|포워드|센터) · Lv\.(\d+) \/ (\d+)코트 클리어$/,m=>choice(`${m[1]} · ${text(m[2],language)} · Lv.${m[3]} / ${m[4]} courts cleared`,`${m[1]}・${text(m[2],language)}・Lv.${m[3]} / ${m[4]}コートクリア`,`${m[1]} · ${text(m[2],language)} · Lv.${m[3]} / 已通关 ${m[4]} 球场`)))!==null)return result;
  if((result=replace(/^(.*?) · 첫 선수를 만들어 주세요$/,m=>choice(`${m[1]} · Create your first player`,`${m[1]}・最初の選手を作成してください`,`${m[1]} · 请创建首位球员`)))!==null)return result;
  if((result=replace(/^(.+?)( 기술)? 훈련 1포인트$/,m=>choice(`Train ${text(m[1],language)} · 1 point`,`${text(m[1],language)}を強化・1ポイント`,`训练${text(m[1],language)} · 1 点`)))!==null)return result;
  if((result=replace(/^(.+) 도전 시작$/,m=>choice(`Start ${text(m[1],language)}`,`${text(m[1],language)}に挑戦`,`挑战${text(m[1],language)}`)))!==null)return result;
  if((result=replace(/^동작: (.+) → (.+)$/,m=>choice(`Motion: ${text(m[1],language)} → ${text(m[2],language)}`,`動作：${text(m[1],language)} → ${text(m[2],language)}`,`动作：${text(m[1],language)} → ${text(m[2],language)}`)))!==null)return result;
  if((result=replace(/^(승리!|다음 코트에서 다시!) \+(\d+) XP · Lv\.(\d+) · 스탯 (\d+)P \/ 기술 (\d+)P$/,m=>choice(`${text(m[1],language)} +${m[2]} XP · Lv.${m[3]} · Stats ${m[4]}P / Skills ${m[5]}P`,`${text(m[1],language)} +${m[2]} XP・Lv.${m[3]}・能力 ${m[4]}P / スキル ${m[5]}P`,`${text(m[1],language)} +${m[2]} XP · Lv.${m[3]} · 属性 ${m[4]}P / 技能 ${m[5]}P`)))!==null)return result;
  if((result=replace(/^v([\d.]+) · AI 1대1·3대3 육성 · 계정과 선수 기록은 서버에 저장됩니다\.$/,m=>choice(`v${m[1]} · AI 1v1 & 3v3 career · Account and player records are saved on the server.`,`v${m[1]}・AI 1対1・3対3育成・アカウントと選手記録はサーバー保存。`,`v${m[1]} · AI 1 对 1及3对3成长 · 账号及球员记录保存在服务器。`)))!==null)return result;
  if((result=replace(/^v([\d.]+) · AI 1대1 육성 · 계정과 선수 기록은 서버에 저장됩니다\.$/,m=>choice(`v${m[1]} · AI 1v1 career · Account and player records are saved on the server.`,`v${m[1]}・AI 1対1育成・アカウントと選手記録はサーバー保存。`,`v${m[1]} · AI 1 对 1 成长 · 账号及球员记录保存在服务器。`)))!==null)return result;
  if((result=replace(/^(.*) 새 탭에서 열기$/,m=>choice(`${text(m[1],language)} (new tab)`,`${text(m[1],language)}（新しいタブ）`,`${text(m[1],language)}（新标签页）`)))!==null)return result;
  if((result=replace(/^(X|Threads) 새 탭$/,m=>`${m[1]} (${choice('new tab','新しいタブ','新标签页')})`))!==null)return result;
  if((result=replace(/^(.+) · 11점 또는 90초 승부$/,m=>choice(`${text(m[1],language)} · 11 points or 90 seconds`,`${text(m[1],language)}・11点先取または90秒`,`${text(m[1],language)} · 11 分或 90 秒`)))!==null)return result;
  if((result=replace(/^(다시 로그인해 주세요\.) ([\s\S]+)$/,m=>`${text(m[1],language)} ${text(m[2],language)}`))!==null)return result;
  // Known labels can be composed without replacing arbitrary text inside player names.
  if(value.includes(' / '))return source.replace(value,value.split(' / ').map(part=>text(part,language)).join(' / '));
  if(value.includes(' · '))return source.replace(value,value.split(' · ').map(part=>text(part,language)).join(' · '));
  if((result=replace(/^(이동|핸들링|슈팅|골밑 마무리|수비|리바운드) (\d+)$/,m=>`${text(m[1],language)} ${m[2]}`))!==null)return result;
  return source;
 }
 const api=root.CourtI18n={text,names,normalize,get locale(){return locale;},setLanguage};
 function setLanguage(value){
  const next=normalize(value);if(!next||next===locale)return;
  locale=next;try{root.localStorage?.setItem('court-rush.language.v1',locale);}catch{}
  if(typeof document==='undefined')return;
  applyLanguage();root.dispatchEvent(new CustomEvent('court-language-change',{detail:{language:locale}}));
 }
 if(typeof document==='undefined')return;
 const sources=new WeakMap(),attributeSources=new WeakMap();
 const attributes=['aria-label','title','placeholder','alt'];
 const skip=element=>!element||element.closest('script,style,textarea,[translate="no"],[data-language]');
 function translateNode(node){
  if(node.nodeType===3){
   if(skip(node.parentElement))return;
   const last=sources.get(node),source=last&&node.data===last.rendered?last.source:node.data;
   const rendered=text(source);sources.set(node,{source,rendered});if(node.data!==rendered)node.data=rendered;
  }else if(node.nodeType===1&&!skip(node)){
   let saved=attributeSources.get(node);if(!saved){saved={};attributeSources.set(node,saved);}
   for(const key of attributes)if(node.hasAttribute(key)){
    const value=node.getAttribute(key),last=saved[key],source=last&&value===last.rendered?last.source:value,rendered=text(source);
    saved[key]={source,rendered};if(value!==rendered)node.setAttribute(key,rendered);
   }
   for(const child of node.childNodes)translateNode(child);
  }
 }
 const observer=new MutationObserver(records=>{
  observer.disconnect();
  const nodes=new Set(records.map(record=>record.target));
  for(const node of nodes)translateNode(node);
  observe();
 });
 function observe(){observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:attributes});}
 function applyLanguage(){
  observer.disconnect();document.documentElement.lang=locale;
  document.title=text(titleSource);translateNode(document.body);
  for(const select of document.querySelectorAll('[data-language]')){select.value=locale;select.setAttribute('aria-label',text('언어'));}
  observe();
 }
 const titleSource=document.title;
 for(const select of document.querySelectorAll('[data-language]')){
  for(const [value,label] of Object.entries(names)){const option=document.createElement('option');option.value=value;option.textContent=label;select.append(option);}
  select.addEventListener('change',()=>setLanguage(select.value));
 }
 applyLanguage();
})(typeof window==='undefined'?globalThis:window);
