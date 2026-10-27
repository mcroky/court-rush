(() => {
 'use strict';
 const $=id=>document.getElementById(id),t=s=>window.CourtI18n?.text(s)||s;
 const panel=document.querySelector('.online-panel');
 const summary=document.createElement('p');summary.id='online-standing';summary.setAttribute('role','status');panel.append(summary);
 const open=document.createElement('button');open.id='online-ranking-open';open.textContent='온라인 전적 · 랭킹';panel.append(open);
 const dialog=document.createElement('dialog');dialog.className='online-dialog ranking-dialog';dialog.setAttribute('aria-labelledby','ranking-title');
 dialog.innerHTML='<h2 id="ranking-title">온라인 랭킹</h2><p>1,000점 시작 · Elo K=32 · 비슷한 점수의 상대에게 승리하면 약 +16점</p><p id="ranking-mine"></p><p id="ranking-status" role="status" aria-live="polite"></p><div class="ranking-scroll"><table><caption class="sr-only">온라인 상위 50명</caption><thead><tr><th>순위</th><th>선수</th><th>Elo 점수</th><th>승</th><th>패</th><th>무</th></tr></thead><tbody id="ranking-rows"></tbody></table></div><button id="ranking-refresh">기록 새로고침</button><button id="ranking-close">닫기</button>';document.body.append(dialog);
 let data=null,pending=false,generation=0;
 const record=r=>`${t('Elo 점수')} ${r.rating.toLocaleString()} · ${t('승')} ${r.wins} / ${t('패')} ${r.losses} / ${t('무')} ${r.draws}`;
 function draw(){
  summary.textContent=data?record(data.mine):t('로그인하면 온라인 전적과 랭킹을 확인할 수 있습니다.');
  if(!data){$('ranking-mine').textContent='';$('ranking-rows').replaceChildren();return;}
  $('ranking-mine').textContent=`${t('내 전적')} · ${record(data.mine)} · ${data.mine.rank===null?t('아직 순위가 없습니다.'):`${t('순위')} ${data.mine.rank}`}`;
  const rows=$('ranking-rows');rows.replaceChildren();
  for(const p of data.players){
   const row=document.createElement('tr');if(p.self)row.className='ranking-self';
   for(const value of [p.rank,p.nickname,p.rating,p.wins,p.losses,p.draws]){const cell=document.createElement('td');cell.textContent=String(value);cell.setAttribute('translate','no');row.append(cell);}
   rows.append(row);
  }
  $('ranking-status').textContent=data.players.length?'':t('아직 완료된 온라인 대전이 없습니다.');
 }
 async function refresh(interactive=false){
  if(!window.CourtCareerOnline?.signedIn){data=null;draw();if(interactive)await window.CourtCareerOnline.ranking();return;}
  if(pending)return;pending=true;const token=generation;$('ranking-refresh').disabled=true;
  if(dialog.open)$('ranking-status').textContent=t('기록을 불러오고 있어요.');
  try{const next=await window.CourtCareerOnline.ranking();if(token!==generation)return;data=next;draw();}
  catch(e){if(token===generation&&dialog.open)$('ranking-status').textContent=t(e.message);}
  finally{pending=false;$('ranking-refresh').disabled=false;if(token!==generation&&window.CourtCareerOnline?.signedIn)queueMicrotask(()=>refresh());}
 }
 open.onclick=async()=>{
  if(!window.CourtCareerOnline?.signedIn){try{await refresh(true);}catch{}return;}
  window.CourtGame?.pause();if(!dialog.open)dialog.showModal();$('ranking-close').focus();draw();refresh();
 };
 $('ranking-close').onclick=()=>dialog.close();$('ranking-refresh').onclick=()=>refresh();
 window.addEventListener('court-account',e=>{generation++;if(!e.detail.signedIn){data=null;draw();}else refresh();});
 window.addEventListener('court-online-result',()=>refresh());
 window.addEventListener('court-language-change',draw);
 window.CourtOnlineRanking={refresh,open:()=>open.click(),describe(result,slot){
  if(!result.saved)return t('전적과 랭킹 반영을 확인하고 있습니다.');
  if(!result.ranked)return t('이 경기는 랭킹에 반영되지 않습니다.');
  const own=result.rankings?.find(r=>r.slot===slot);if(!own)return t('전적과 랭킹 반영을 확인하고 있습니다.');
  return `${t('Elo 점수')} ${own.rating.toLocaleString()} (${own.delta>=0?'+':''}${own.delta}) · ${t('승')} ${own.wins} / ${t('패')} ${own.losses} / ${t('무')} ${own.draws}`;
 }};
 draw();queueMicrotask(()=>refresh());
})();
