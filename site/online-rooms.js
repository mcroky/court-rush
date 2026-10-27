(() => {
 'use strict';
 const $=id=>document.getElementById(id),t=s=>window.CourtI18n?.text(s)||s;
 const dialog=document.querySelector('.online-dialog'),section=document.createElement('section');section.className='online-rooms';
 section.innerHTML='<div id="room-browser"><h3>대전방</h3><p>공개방·자동 매칭은 정식 전적과 Elo에 반영됩니다. 비공개 연습방은 반영되지 않습니다.</p><button id="room-refresh">대기방 새로고침</button><p id="room-empty" role="status"></p><div id="room-list"></div><h3>방 만들기</h3><label>방 이름<input id="room-title" maxlength="24" placeholder="함께 뛰어요"></label><label>경기 종류<select id="room-kind"><option value="public">공개 대전 · 승패와 Elo 반영</option><option value="private">비공개 연습 · 승패와 Elo 미반영</option></select></label><button id="room-create">방 만들기</button><h3>코드로 입장</h3><label>방 코드<input id="room-join-code" maxlength="8" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="8자리 방 코드"></label><button id="room-join">코드로 입장</button><p class="online-separator">또는 자동 매칭</p></div><div id="room-lobby" hidden><h3 id="room-lobby-title" translate="no"></h3><p id="room-policy"></p><p><span>방 코드</span> <code id="room-code" translate="no" tabindex="0"></code></p><ol id="room-members"></ol><button id="room-ready" class="primary">준비 완료</button><button id="room-leave">방 나가기</button></div>';
 dialog.insertBefore(section,$('online-find'));let lobby=null,rooms=[];
 const action=m=>window.CourtOnline.action(m);
 function drawRooms(){
  const list=$('room-list');list.replaceChildren();$('room-empty').textContent=rooms.length?'':t('열린 공개방이 없습니다. 새 방을 만들어 보세요.');
  for(const r of rooms){const row=document.createElement('div');row.className='room-row';const label=document.createElement('span');label.setAttribute('translate','no');label.textContent=`${r.title} · ${r.host} (${r.players}/2)`;const join=document.createElement('button');join.textContent=t(r.queued?'코트 대기 중':'입장');join.disabled=r.players>=2||r.queued;join.onclick=()=>action({type:'room.join',lobbyId:r.id});row.append(label,join);list.append(row);}
 }
 function drawLobby(){
  $('room-browser').hidden=Boolean(lobby);$('room-lobby').hidden=!lobby;$('online-find').hidden=Boolean(lobby);
  if(!lobby)return;
  $('room-lobby-title').textContent=lobby.title;$('room-code').textContent=lobby.code;
  $('room-policy').textContent=t(lobby.private?'비공개 연습 · 승패와 Elo 미반영':'공개 대전 · 승패와 Elo 반영');
  $('room-members').replaceChildren();for(const m of lobby.members){const li=document.createElement('li'),name=document.createElement('span');name.setAttribute('translate','no');name.textContent=m.nickname;li.append(name,document.createTextNode(' · '+t(m.ready?'준비 완료':'준비 전')));$('room-members').append(li);}
  if(lobby.members.length<2){const li=document.createElement('li');li.textContent=t('상대의 입장을 기다리고 있어요.');$('room-members').append(li);}
  $('room-ready').textContent=t(lobby.members[lobby.slot]?.ready?'준비 취소':'준비 완료');
 }
 $('room-refresh').onclick=()=>action({type:'room.list'});
 $('room-create').onclick=()=>action({type:'room.create',title:$('room-title').value.trim()||t('함께 뛰어요'),private:$('room-kind').value==='private'});
 $('room-join').onclick=()=>action({type:'room.join',code:$('room-join-code').value.trim().toUpperCase()});
 $('room-ready').onclick=()=>{if(lobby)action({type:'room.ready',lobbyId:lobby.id,ready:!lobby.members[lobby.slot]?.ready});};
 $('room-leave').onclick=()=>{if(lobby)action({type:'room.leave',lobbyId:lobby.id});};
 window.addEventListener('court-online-status',e=>{
  if(['idle','error','ended'].includes(e.detail.status)){lobby=null;drawLobby();}
  const blocked=!['idle','error','ended','browsing'].includes(e.detail.status);
  for(const id of ['room-create','room-join','room-refresh'])$(id).disabled=blocked;
 });
 window.addEventListener('court-language-change',()=>{drawRooms();drawLobby();});
 window.CourtOnlineRooms={open(){lobby=null;drawLobby();action({type:'room.list'});},packet(m){
  if(m.type==='room.list'){rooms=m.rooms;drawRooms();}
  else if(m.type==='room.state'){lobby=m.lobby;drawLobby();window.CourtOnline.roomStatus(lobby.queued?'room-queued':'lobby',lobby.queued?'두 사람의 차례를 기다리고 있어요.':'둘 다 준비를 누르면 경기가 시작됩니다.');}
  else if(m.type==='room.left'||m.type==='room.closed'){lobby=null;drawLobby();window.CourtOnline.roomStatus('browsing',m.type==='room.closed'?'대기 시간이 끝나 방이 닫혔습니다.':'방을 선택하거나 새로 만들어 주세요.');action({type:'room.list'});}
  else if(m.type==='room.error'){
   const messages={room_unavailable:'입장할 수 없는 방입니다. 목록과 코드를 확인하세요.',already_participating:'다른 대기나 경기에 이미 참가 중입니다.',room_limit:'열린 방이 많습니다. 잠시 후 다시 시도하세요.',room_rate_limit:'요청이 많습니다. 잠시 후 다시 시도하세요.',invalid_room:'방 이름과 경기 종류를 확인하세요.',unavailable:'서버에 연결하지 못했습니다. 잠시 후 다시 시도하세요.'};
   $('online-status').textContent=t(messages[m.code]||'입장할 수 없는 방입니다. 목록과 코드를 확인하세요.');
  }
 }};
 setInterval(()=>{if(dialog.open&&!lobby&&window.CourtOnline.status==='browsing')action({type:'room.list'});},5000);
})();
