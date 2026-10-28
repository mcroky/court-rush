(() => {
 'use strict';
 const $=id=>document.getElementById(id),input=window.ufInput,config=window.COURT_ONLINE_CONFIG,t=s=>window.CourtI18n?.text(s)||s;
 const local=['127.0.0.1','localhost'].includes(location.hostname),base=local?'http://127.0.0.1:8792':config.url,enabled=local||config.enabled;
 Object.assign(input,{onlineSeq:0,onlineState:'{}',onlineMatch:'{}',onlineAxes:'[1,0,0,1]',onlineInputs:'[]',onlineLocal:'{}'});
 let commandHistory=[];
 let status='idle',socket=null,authenticated=false,intent={type:'queue.join',mode:'duel'},generation=0,room=null,lastState=null,result=null,seq=0,lastShoot=input.shootSeq,epoch='',lastInput='',lastSend=0,reconnectUntil=0,retryTimer=null;
 const dialog=document.createElement('dialog');dialog.className='online-dialog';dialog.setAttribute('aria-labelledby','online-title');
 dialog.innerHTML='<h2 id="online-title">온라인 1대1</h2><p>내 선수 외형 · 육성 능력치 · 온라인 승패와 Elo</p><p id="online-status" role="status" aria-live="polite"></p><button id="online-find" class="primary">상대 찾기</button><button id="online-cancel">취소</button>';document.body.append(dialog);
 const panel=document.createElement('section');panel.className='online-panel';panel.innerHTML='<h3>온라인 1대1</h3><p>방 개설·입장 또는 자동 매칭 · 90초 · 11점 승부</p><button id="online-open" class="primary">온라인 1대1</button><p id="online-connection" role="status" aria-live="polite"></p><button id="online-leave" hidden>온라인 경기 떠나기</button>';document.querySelector('.mode-panel').append(panel);
 const names=[0,1].map(()=>{const name=document.createElement('span');name.className='online-player-name';name.setAttribute('translate','no');name.hidden=true;$('arena').append(name);return name;});
 const locked=new Map(),active=()=>['loading','countdown','playing','reconnecting','ended'].includes(status);
 function setStatus(next,message=''){
  panel.dataset.onlineStatus=next;window.dispatchEvent(new CustomEvent('court-online-status',{detail:{status:next}}));
  status=next;$('online-find').disabled=!['idle','error','ended','browsing'].includes(next)||!enabled;$('online-open').disabled=active()&&next!=='ended';$('online-find').textContent=t(next==='error'?'다시 시도':'상대 찾기');$('online-status').textContent=t(message);$('online-connection').textContent=active()?t(message):'';$('online-leave').hidden=!active();
  for(const b of document.querySelectorAll('[data-select],[data-start],#sidebar-play,#career-open,#career-menu,#wardrobe-open,#wardrobe-menu,#reset-button,#showroom-button')){if(active()&&next!=='ended'){if(!locked.has(b))locked.set(b,b.disabled);b.disabled=true;}else if(locked.has(b)){b.disabled=locked.get(b);locked.delete(b);}}
 }
 function send(m){if(socket?.readyState===WebSocket.OPEN)socket.send(JSON.stringify({protocolVersion:1,serverEpoch:epoch,...m}));}
 function snapshot(s){lastState=s;if(room)commandHistory=commandHistory.filter(c=>c.seq>(s.acks?.[room.slot]??-1));input.onlineState=JSON.stringify(s);input.onlineSeq++;}
 function stopView(){room=null;lastState=null;input.onlineLocal='{}';names.forEach(n=>n.hidden=true);window.CourtGame.endOnline();}
 function close(){authenticated=false;clearTimeout(retryTimer);generation++;const old=socket;socket=null;old?.close();}
 function fail(message){close();if(room)stopView();setStatus('error',message);if(!dialog.open)dialog.showModal();}
 function cancel(){send({type:'queue.cancel'});close();if(room)stopView();setStatus('idle');dialog.close();}
 async function prepare(token){
  setStatus('waking','온라인 서버를 준비하고 있어요.');const start=Date.now();let attempt=0;
  while(generation===token&&Date.now()-start<90000&&(!reconnectUntil||Date.now()<reconnectUntil)){try{const r=await fetch(base+'/readyz',{cache:'no-store',signal:AbortSignal.timeout(12000)});if(r.ok){const s=await r.json();if(s.ready&&s.protocolVersion===1&&s.rulesVersion===config.rulesVersion)return s;}}catch{}await new Promise(r=>setTimeout(r,Math.min(8000,2000*2**attempt++)+Math.random()*300));}
  throw Error('서버에 연결하지 못했습니다. 잠시 후 다시 시도하세요.');
 }
 async function connect(token,recovering=false){
  const ready=await prepare(token);if(token!==generation)return;
  if(recovering&&ready.serverEpoch!==epoch)throw Error('서버가 다시 시작되어 경기가 무효 처리되었습니다.');epoch=ready.serverEpoch;
  setStatus(recovering?'reconnecting':'authenticating',recovering?'연결을 복구하고 있어요.':'참가 자격을 확인하고 있어요.');
  const ticket=await window.CourtCareerOnline.ticket({serverId:local&&ready.serverId?ready.serverId:config.serverId,mode:'duel',protocolVersion:1,rulesVersion:config.rulesVersion});if(token!==generation)return;
  const ws=new WebSocket(base.replace(/^http/,'ws')+'/play');socket=ws;authenticated=false;const timeout=setTimeout(()=>ws.close(),8000);
  ws.onopen=()=>send({type:'authenticate',ticket:ticket.ticket});
  ws.onmessage=event=>{
   if(token!==generation)return;let m;try{m=JSON.parse(event.data);}catch{return;}if(m.protocolVersion!==1||m.serverEpoch!==epoch)return;
   panel.dataset.networkEvents=((panel.dataset.networkEvents||'').split(',').slice(-7).concat(m.type)).join(',');
   if(m.type.startsWith('room.')){window.CourtOnlineRooms?.packet(m);return;}if(m.type==='authenticated'){authenticated=true;clearTimeout(timeout);if(!recovering&&!m.resuming){if(intent.type.startsWith('room.'))setStatus('browsing','방을 선택하거나 새로 만들어 주세요.');send(intent);}else retryTimer=setTimeout(()=>fail('재접속 유예 시간이 끝났습니다.'),3000);}
   else if(m.type==='queue.status')setStatus('queued',m.busy?'진행 중인 경기가 끝나면 상대를 찾아요.':'상대를 찾고 있어요.');
   else if(m.type==='match.found'){
    clearTimeout(retryTimer);reconnectUntil=0;room=m;result=null;seq=0;commandHistory=[];input.onlineInputs='[]';lastInput='';lastShoot=input.shootSeq;snapshot(m.state);window.CourtGame.startOnline(m);setStatus(m.resumed?'playing':'loading',m.resumed?'경기에 다시 연결했습니다.':'상대와 코트를 준비하고 있어요.');dialog.close();
   }else if(m.type==='countdown')setStatus('countdown','잠시 후 경기가 시작됩니다.');
   else if(m.type==='match.started'){setStatus('playing','온라인 경기 중 · 메뉴를 열어도 경기는 계속됩니다.');lastInput='';sendInput(true);}
   else if(m.type==='snapshot'&&room?.matchId===m.matchId)snapshot(m.state);
   else if(['match.ended','match.saved'].includes(m.type)&&room?.matchId===m.matchId){result=m.result;setStatus('ended','경기가 끝났습니다.');if(lastState)snapshot({...lastState,tick:lastState.tick+1,time:lastState.time+1/60,phase:'ended',outcome:result.reason});if(result.saved)close();window.dispatchEvent(new CustomEvent('court-online-result',{detail:{matchId:room.matchId,slot:room.slot,result}}));}
   else if(m.type==='match.cancelled'){if(room)stopView();if(m.lobby)window.CourtOnlineRooms?.packet({type:'room.state',lobby:m.lobby});else setStatus('queued','상대가 나가 다시 매칭합니다.');if(!dialog.open)dialog.showModal();}
   else if(m.type==='reconnect.status')$('online-connection').textContent=t(m.connected.every(Boolean)?'온라인 경기 중 · 메뉴를 열어도 경기는 계속됩니다.':'상대의 재접속을 기다리고 있어요.');
   else if(m.type==='idle.warning')$('online-connection').textContent=t('입력이 없으면 경기가 종료됩니다.');
   else if(m.type==='error'&&!['already_queued','stale_match'].includes(m.code)){
    panel.dataset.errorCode=m.code;
    const errors={already_participating:'다른 탭에서 이미 온라인 경기에 참가 중입니다.',session_expired:'다시 로그인해 주세요.',authentication_failed:'참가 확인에 실패했습니다. 다시 로그인해 주세요.',server_overload:'서버가 혼잡해 경기가 무효 처리되었습니다.',server_unavailable:'서버 연결이 끊겨 경기가 무효 처리되었습니다.',all_disconnected:'모든 이용자의 연결이 끊겨 경기가 무효 처리되었습니다.'};fail(errors[m.code]||'온라인 연결을 완료하지 못했습니다. 다시 시도하세요.');
   }
  };
  ws.onclose=()=>{
   clearTimeout(timeout);if(token!==generation||status==='ended')return;
   if(room&&['playing','reconnecting'].includes(status)&&Date.now()<(reconnectUntil||Infinity)){if(status!=='reconnecting')reconnectUntil=Date.now()+20000;setStatus('reconnecting','연결을 복구하고 있어요.');retryTimer=setTimeout(()=>{if(token===generation)connect(token,true).catch(e=>fail(e.message));},700);}
   else fail(authenticated?'연결이 끊겼습니다. 다시 상대를 찾아 주세요.':'서버에 연결하지 못했습니다. 잠시 후 다시 시도하세요.');
  };
 }
 async function begin(command={type:'queue.join',mode:'duel'}){
  intent=command;
  if(authenticated&&socket?.readyState===WebSocket.OPEN){if(command.type==='queue.join')setStatus('queued','상대를 찾고 있어요.');send(command);return;}
  if(!enabled){setStatus('error','온라인 서버를 준비 중입니다.');return;}if(!window.CourtGame.getState()?.ready){setStatus('error','코트가 준비되는 동안 잠시 기다려 주세요.');return;}
  close();const token=generation;reconnectUntil=0;try{await connect(token);}catch(e){if(token===generation){if(e.accountDialog){close();dialog.close();setStatus('idle');}else fail(e.message);}}
 }
 function sendInput(force=false){
  const blocked=document.hidden||Boolean(document.querySelector('dialog[open]'));
  input.onlineLocal=JSON.stringify({enabled:Boolean(room&&status==='playing'&&!blocked),nextSeq:seq});
  if(!room||status!=='playing')return;let axes;try{axes=JSON.parse(input.onlineAxes);}catch{axes=[1,0,0,1];}
  const x=blocked?0:input.x*axes[0]+input.z*axes[2],z=blocked?0:input.x*axes[1]+input.z*axes[3],length=Math.max(1,Math.hypot(x,z)),command={x:x/length,z:z/length};
  for(const k of ['shoot','cross','spin','twostep','behind','hesi','steal','guard'])command[k]=!blocked&&Boolean(input[k]);
  command.shoot_pressed=!blocked&&input.shootSeq!==lastShoot&&input.shootSeq!==input.shootCancelSeq;lastShoot=input.shootSeq;
  const encoded=JSON.stringify(command),now=performance.now();if(!force&&encoded===lastInput&&now-lastSend<33)return;lastInput=encoded;lastSend=now;
  commandHistory.push({seq,x:command.x,z:command.z,action:blocked||['shoot','cross','spin','twostep','behind','hesi','steal','guard'].some(k=>command[k]),sent:now});commandHistory=commandHistory.slice(-16);
  input.onlineInputs=JSON.stringify(commandHistory.map(c=>({seq:c.seq,x:c.x,z:c.z,action:c.action,age:(now-c.sent)/1000+.016})));send({type:'input',matchId:room.matchId,seq:seq++,...command});
  input.onlineLocal=JSON.stringify({enabled:!blocked,nextSeq:seq});
 }
 $('online-open').onclick=()=>{if(!active()&&window.CourtGame.getState()?.started&&window.CourtGame.getState()?.phase!=='ended'&&!confirm(t('현재 경기를 마치고 온라인 매칭을 시작할까요?')))return;if(!dialog.open)dialog.showModal();setStatus(status,enabled?'상대 찾기를 누르면 서버를 준비합니다.':'온라인 서버를 준비 중입니다.');$('online-find').focus();window.CourtOnlineRooms?.open();};
 $('online-find').onclick=()=>begin();$('online-cancel').onclick=cancel;dialog.addEventListener('cancel',e=>{e.preventDefault();cancel();});
 $('online-leave').onclick=()=>{if(status!=='ended'&&!confirm(t('온라인 경기를 떠나면 기권 처리됩니다. 계속할까요?')))return;if(status==='playing')send({type:'match.leave',matchId:room.matchId});else{close();stopView();setStatus('idle');}};
 $('result-rematch').addEventListener('click',e=>{if(!room)return;e.preventDefault();e.stopImmediatePropagation();const roomEntry=room.entry?.kind==='room';close();stopView();setStatus('idle');dialog.showModal();if(roomEntry)window.CourtOnlineRooms?.open();else begin();},true);
 window.addEventListener('court-state',e=>{const s=e.detail;panel.dataset.prediction=s.onlinePrediction?'local':'server';names.forEach((name,i)=>{const p=s.onlineNames?.[i];name.hidden=!s.online||!p||p.x<0||p.x>1||p.y<0||p.y>1;if(!name.hidden){name.textContent=p.name;name.classList.toggle('self',p.self);name.style.left=(p.x*100)+'%';name.style.top=(p.y*100)+'%';}});if(s.online&&room&&status==='loading'){send({type:'match.ready',matchId:room.matchId});setStatus('countdown','상대의 준비를 기다리고 있어요.');}if(s.online){$('mode-badge').textContent='ONLINE 1V1';$('pause-button').disabled=true;if(result){$('result-title').textContent=t(result.reason==='aborted'?'경기 무효':result.winner===null?'무승부':result.winner===room.slot?'승리':'패배');$('result-detail').textContent=window.CourtOnlineRanking?.describe(result,room.slot)||t('전적과 랭킹 반영을 확인하고 있습니다.');}}else $('pause-button').disabled=false;});
 setInterval(()=>{if(socket?.readyState===WebSocket.OPEN)send({type:'ping',sent:Date.now()});},10000);setInterval(()=>sendInput(),33);
 window.CourtOnline={action:begin,roomStatus:setStatus,inputChanged:()=>sendInput(true),resetForLocal(){if(status==='ended'){close();room=null;lastState=null;setStatus('idle');}},get active(){return active();},get status(){return status;}};setStatus('idle');
})();
