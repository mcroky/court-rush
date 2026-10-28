/* The web shell owns accessible controls; Godot owns simulation and rendering. */
const $ = (id) => document.getElementById(id);
const canvas = $('canvas');
const input = window.ufInput = {appearance:'{}',wardrobe:'{}',x:0,z:0,shoot:false,shootSeq:0,shootCancelSeq:0,cross:false,spin:false,twostep:false,behind:false,hesi:false,steal:false,guard:false,passBall:false,switchPlayer:false,passSeq:0,switchSeq:0,controlReset:0,command:'',commandId:0,sound:true,reduced:false,suspended:false,pauseReason:'',audioSuspended:false};
function updateCameraLayout(){input.compactCamera=matchMedia('(pointer:coarse), (max-width:850px), (max-height:560px) and (orientation:landscape)').matches;document.body.classList.toggle('touch-layout',input.compactCamera);}
updateCameraLayout();window.addEventListener('resize',()=>{updateCameraLayout();if(input.compactCamera && document.body.classList.contains('in-play'))$('arena').scrollIntoView({block:'start',behavior:'instant'});});
let selectedMode = 'practice';
let state = null;
let resizeGameCanvas=()=>{};
function canvasSize(width,height,dpr,teamMode){
 const budget=teamMode?921600:2073600;
 const ratio=Math.min(dpr||1,1.5,Math.sqrt(budget/Math.max(1,width*height)));
 return {width:Math.max(1,Math.round(width*ratio)),height:Math.max(1,Math.round(height*ratio))};
}
let ready = false;
let manuallyChoosing = false;
const pressed = new Set();
const touches = new Set();
let stickX = 0, stickZ = 0;
let prefs = { sound: true, reduced: matchMedia('(prefers-reduced-motion: reduce)').matches, music:true, voice:true, track:-1, musicDb:-12, voiceDb:-1, sfxDb:0 };
let settingsNotice = '';
try {
  const raw = localStorage.getItem('unfree-settings-v1');
  if(raw !== null) {
    const saved = JSON.parse(raw);
    if(saved && typeof saved.sound === 'boolean' && typeof saved.reduced === 'boolean') {
      for(const key of ['sound','reduced','music','voice'])if(typeof saved[key]==='boolean')prefs[key]=saved[key];
      if(Number.isInteger(saved.track)&&saved.track>=-1&&saved.track<=2)prefs.track=saved.track;
      for(const key of ['musicDb','voiceDb','sfxDb'])if(Number.isFinite(saved[key])&&saved[key]>=-36&&saved[key]<=0)prefs[key]=saved[key];
    }
    else settingsNotice = '저장된 설정을 읽지 못해 기본 설정으로 실행합니다. 설정을 바꾸면 새로 저장합니다.';
  }
} catch { settingsNotice = '설정을 읽지 못했습니다. 현재 창에서는 기본 설정으로 실행합니다.'; }
input.sound = prefs.sound; input.reduced = prefs.reduced;
let musicNext=0;
function syncAudioPrefs(){input.audio=JSON.stringify({music:prefs.music,voice:prefs.voice,track:prefs.track,musicDb:prefs.musicDb,voiceDb:prefs.voiceDb,sfxDb:prefs.sfxDb,next:musicNext});}
syncAudioPrefs();
function unlockAudio(){input.audioSuspended=false;if(window.GodotAudio?.ctx?.state==='suspended')window.GodotAudio.ctx.resume().catch(()=>{});}

function command(name) { input.command = name; input.commandId++; }
function updateInput() {
  input.x = Math.max(-1, Math.min(1, Number(pressed.has('ArrowRight')) - Number(pressed.has('ArrowLeft')) + stickX));
  input.z = Math.max(-1, Math.min(1, Number(pressed.has('ArrowDown')) - Number(pressed.has('ArrowUp')) + stickZ));
  const shooting = pressed.has('KeyD') || touches.has('shoot');
  if(shooting && !input.shoot)input.shootSeq++;
  input.shoot = shooting;
  input.cross = pressed.has('KeyA') || touches.has('cross');
  input.spin = pressed.has('KeyZ') || touches.has('spin');
  input.twostep = pressed.has('KeyC') || touches.has('twostep');
  input.behind = pressed.has('KeyV') || touches.has('behind');
  input.hesi = pressed.has('KeyX') || touches.has('hesi');
  input.steal = pressed.has('KeyS') || touches.has('steal');
  input.guard = pressed.has('KeyW') || touches.has('guard');
  const canSwitch=state?.canSwitchDefender??(state?.possessionTeam===1);
  input.passBall = pressed.has('KeyQ') || (touches.has('team') && !canSwitch);
  input.switchPlayer = pressed.has('KeyE') || (touches.has('team') && canSwitch);
  window.CourtOnline?.inputChanged();
}
function clearInput() { input.controlReset++;pressed.clear(); touches.clear(); stickX=0; stickZ=0;stickPointer=null; $('stick').style.transform=''; updateInput(); }
function requestPause(reason='잠시 쉬었다가 직접 이어가세요.') {
  input.audioSuspended=true;
  clearInput();
  if(state?.online){input.suspended=false;return;}
  if((state?.started || document.body.classList.contains('in-play')) && state?.phase!=='ended') { input.suspended=true;input.pauseReason=reason; }
}
function resumeGame() {
  if($('info-dialog').open || manuallyChoosing || !state?.started || state.phase==='ended') return;
  clearInput();input.suspended=false;unlockAudio();command('resume');canvas.focus({preventScroll:true});
}
function start(mode) {
  if(!ready) return;
  if(window.CourtOnline?.active && window.CourtOnline.status!=='ended')return;
  window.CourtOnline?.resetForLocal();
  clearCareerResult();
  clearInput();input.suspended=false;unlockAudio();selectMode(mode); manuallyChoosing=false;
  document.body.classList.add('in-play');
  $('pause-overlay').classList.add('hidden'); $('result-overlay').classList.add('hidden');
  command(mode); canvas.focus({preventScroll:true});
  if(input.compactCamera)$('arena').scrollIntoView({block:'start',behavior:'instant'});
  // Browser AudioContexts must be resumed from a user gesture.
  if(window.GodotAudio?.ctx?.state === 'suspended') window.GodotAudio.ctx.resume().catch(()=>{});
}
function clearCareerResult(){
 $('career-reward').textContent='';$('career-retry').hidden=true;
 $('career-team-summary').hidden=true;$('career-team-summary').textContent='';
}
function selectMode(mode) {
  selectedMode=mode;
  $('team-mode-note').hidden=mode!=='team';
  for(const button of document.querySelectorAll('[data-select]')) {
    const active=button.dataset.select===mode;
    button.classList.toggle('selected',active); button.setAttribute('aria-pressed',String(active));
  }
  $('sidebar-play').innerHTML=(mode==='team'?'3대3 시작하기':mode==='duel'?'1대1 시작하기':'연습 시작하기')+' <span>→</span>';
}
for(const button of document.querySelectorAll('[data-start]')) button.addEventListener('click',()=>start(button.dataset.start));
for(const button of document.querySelectorAll('[data-select]')) button.addEventListener('click',()=>selectMode(button.dataset.select));
$('sidebar-play').addEventListener('click',()=>{
  if(state?.started && state.phase!=='ended') { requestPause(); showRestartDialog(); }
  else start(selectedMode);
});
function showRestartDialog() {
  infoSource='';
  $('dialog-content').innerHTML='<span class="eyebrow">A FRESH START</span><h2>새 경기로 시작할까요?</h2><p>진행 중인 경기의 점수는 초기화됩니다.</p><button class="primary" id="confirm-restart">선택한 모드 시작 →</button>';
  $('info-dialog').showModal();
  $('confirm-restart').addEventListener('click',()=>{$('info-dialog').close();start(selectedMode);});
}
$('pause-button').addEventListener('click',()=>{if(state?.paused)resumeGame();else requestPause();});
$('resume-button').addEventListener('click',resumeGame);
$('home-button').addEventListener('click',()=>{manuallyChoosing=true;document.body.classList.remove('in-play');$('pause-overlay').classList.add('hidden');});
$('reset-button').addEventListener('click',()=>{if(!ready)return;if(['duel','team'].includes(state?.mode) && state.started){selectedMode=state.mode;requestPause();showRestartDialog();}else{clearInput();command('reset');canvas.focus();}});
$('fullscreen-button').addEventListener('click',async()=>{
  try { if(document.fullscreenElement) await document.exitFullscreen(); else await $('arena').requestFullscreen(); }
  catch { $('fullscreen-button').title='이 브라우저에서는 전체 화면을 사용할 수 없습니다.'; }
});
function savePrefs(persist=true) {
  if(persist) {
    try { localStorage.setItem('unfree-settings-v1',JSON.stringify(prefs));settingsNotice=''; }
    catch { settingsNotice='설정을 저장하지 못했습니다. 변경은 현재 창에만 적용됩니다.'; }
  }
  $('sound-button').textContent=prefs.sound?'소리 켬 ♪':'소리 끔'; $('sound-button').setAttribute('aria-pressed',String(prefs.sound));
  $('motion-button').setAttribute('aria-pressed',String(prefs.reduced));
  document.body.classList.toggle('reduced-motion',prefs.reduced);
  $('settings-notice').textContent=settingsNotice;
  $('settings-notice').hidden=!settingsNotice;
  syncAudioPrefs();
  $('music-button').setAttribute('aria-pressed',String(prefs.music));
  $('music-button').textContent=prefs.music?'음악 켬':'음악 끔';
  $('voice-button').setAttribute('aria-pressed',String(prefs.voice));
  $('voice-button').textContent=prefs.voice?'영어 해설 켬':'영어 해설 끔';
  $('music-track').value=String(prefs.track);
  for(const key of ['musicDb','voiceDb','sfxDb']){$(key).value=String(prefs[key]);$(key+'-value').textContent=Math.round(100*Math.pow(10,prefs[key]/20))+'%';}
}
$('sound-button').addEventListener('click',()=>{prefs.sound=!prefs.sound;input.sound=prefs.sound;command('sound');savePrefs();});
$('motion-button').addEventListener('click',()=>{prefs.reduced=!prefs.reduced;input.reduced=prefs.reduced;command('motion');savePrefs();});
for(const [id,key] of [['music-button','music'],['voice-button','voice']])$(id).addEventListener('click',()=>{prefs[key]=!prefs[key];savePrefs();});
$('music-track').addEventListener('change',()=>{const value=Number($('music-track').value);if(Number.isInteger(value)&&value>=-1&&value<=2){prefs.track=value;savePrefs();}});
$('music-next').addEventListener('click',()=>{prefs.track=-1;musicNext++;savePrefs();});
for(const key of ['musicDb','voiceDb','sfxDb'])$(key).addEventListener('input',()=>{const value=Number($(key).value);if(Number.isFinite(value)){prefs[key]=Math.max(-36,Math.min(0,value));savePrefs();}});
savePrefs(false); selectMode('practice');

for(const id of ['showroom-button','showroom-back']) $(id).addEventListener('click',()=>{if(!ready)return;clearInput();command('showroom');canvas.focus({preventScroll:true});$('arena').scrollIntoView({block:'center',behavior:'instant'});});
$('showroom-detail').addEventListener('click',()=>{if(ready && state?.inspecting){clearInput();command('showroom-detail');}});
$('showroom-motion').addEventListener('click',()=>{if(ready && state?.inspecting){clearInput();command('showroom-motion');}});
const controls = new Set(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','KeyD','KeyA','KeyZ','KeyC','KeyV','KeyX','KeyS','KeyW','KeyQ','KeyE']);
window.addEventListener('keydown',(event)=>{
  if($('info-dialog').open || document.getElementById('career-dialog')?.open || /^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName))return;
  if(controls.has(event.code) && !state?.inspecting && state?.started && !state.paused && !input.suspended && state.phase!=='ended') {
    event.preventDefault();
    if(event.repeat && !pressed.has(event.code))return;
    if(!pressed.has(event.code)){if(event.code==='KeyE')input.switchSeq++;if(event.code==='KeyQ')input.passSeq++;}
    event.preventDefault();pressed.add(event.code);updateInput();
  }
  if(event.code==='Escape' && !event.repeat && (state?.started || state?.inspecting) && (state?.inspecting || state.phase!=='ended')) {
    event.preventDefault();clearInput();
    if(state?.inspecting)command('showroom');else if(state.paused)resumeGame();else requestPause();
  }
});
window.addEventListener('keyup',(event)=>{pressed.delete(event.code);updateInput();});
window.addEventListener('blur',()=>requestPause('창을 벗어나 경기를 멈췄습니다. 계속 플레이를 눌러 이어가세요.'));
window.addEventListener('focus',()=>{if(state?.online){clearInput();input.suspended=false;unlockAudio();}});
document.addEventListener('visibilitychange',()=>{if(document.hidden)requestPause('다른 탭으로 이동해 경기를 멈췄습니다. 계속 플레이를 눌러 이어가세요.');});
for(const button of document.querySelectorAll('[data-control]')) {
  let shootTouchSeq=0;
  button.addEventListener('pointerdown',(event)=>{event.preventDefault();if(!state?.started || state.paused || input.suspended || $('info-dialog').open || state.inspecting)return;button.setPointerCapture(event.pointerId);if(button.dataset.control==='team'){if(state.canSwitchDefender??state.possessionTeam===1)input.switchSeq++;else input.passSeq++;}const before=input.shootSeq;touches.add(button.dataset.control);updateInput();if(button.dataset.control==='shoot' && input.shootSeq!==before)shootTouchSeq=input.shootSeq;});
  const release=()=>{touches.delete(button.dataset.control);updateInput();};
  button.addEventListener('pointerup',()=>{release();shootTouchSeq=0;});
  const cancel=()=>{if(shootTouchSeq && shootTouchSeq===input.shootSeq)input.shootCancelSeq=shootTouchSeq;shootTouchSeq=0;release();};
  button.addEventListener('pointercancel',cancel);button.addEventListener('lostpointercapture',cancel);
}
let stickPointer=null;
function moveStick(event) {
  const rect=$('joystick').getBoundingClientRect();
  const radius=rect.width*.32;
  let x=(event.clientX-rect.left-rect.width/2)/radius, z=(event.clientY-rect.top-rect.height/2)/radius;
  const length=Math.hypot(x,z);if(length>1){x/=length;z/=length;}
  stickX=x;stickZ=z;$('stick').style.transform=`translate(${x*radius}px,${z*radius}px)`;updateInput();
}
$('joystick').addEventListener('pointerdown',(event)=>{event.preventDefault();if(!state?.started || state.paused || input.suspended || $('info-dialog').open || state.inspecting)return;stickPointer=event.pointerId;event.currentTarget.setPointerCapture(event.pointerId);moveStick(event);});
$('joystick').addEventListener('pointermove',(event)=>{if(event.pointerId===stickPointer)moveStick(event);});
for(const type of ['pointerup','pointercancel','lostpointercapture']) $('joystick').addEventListener(type,()=>{stickPointer=null;stickX=0;stickZ=0;$('stick').style.transform='';updateInput();});

for(const button of document.querySelectorAll('[data-drill]')) button.addEventListener('click',()=>{
  if(!ready || !state?.started || state.mode!=='practice') return;
  clearInput();command('drill-'+button.dataset.drill);canvas.focus({preventScroll:true});$('arena').scrollIntoView({block:'center',behavior:'instant'});
});
$('drill-slow').addEventListener('click',()=>{if(ready && state?.started && state.mode==='practice' && !state.inspecting){clearInput();command('drill-slow');canvas.focus({preventScroll:true});}});
for(const button of document.querySelectorAll('[data-position]')) button.addEventListener('click',()=>{if(ready && state?.canChangeRole){clearInput();command('position-'+button.dataset.position);canvas.focus({preventScroll:true});}});
let previousHeadline='';
// Keep canonical source text so the localization observer can own its rendered
// translation without every state tick replacing the same text nodes again.
const hudSources=new WeakMap();
function setHudText(node,value) {
  const source=String(value);
  if(hudSources.get(node)===source)return;
  hudSources.set(node,source);node.textContent=source;
}
window.ufUpdate = (next) => {
  const wasPaused=Boolean(state?.paused);
  const wasTeam=state?.mode==='team';
  state=next;
	if(next.profile){const probe=document.getElementById('frame-probe');if(probe)probe.dataset.engineProfile=JSON.stringify(next.profile);}
  const teamMode=next.mode==='team';
  document.body.classList.toggle('team-mode',teamMode);
  document.body.classList.toggle('held-ball',Boolean(next.held));
  for(const [action,normal,held] of [['cross','돌파','피벗'],['spin','턴','턴 페이크'],['twostep','투스텝','업앤언더'],['behind','비하인드','다리 사이'],['hesi','헤지','펌프']])setHudText($(`touch-${action}-label`),next.held?held:normal);
  if(wasTeam!==teamMode)resizeGameCanvas();
  $('team-control').hidden=!teamMode;
  $('team-control').disabled=!next.canSwitchDefender && next.possessionTeam===0 && (next.phase!=='live' || !['idle','fake','held_fake'].includes(next.action));
  setHudText($('team-control-label'),next.canSwitchDefender?'선수 전환':'패스');
  setHudText($('team-control-key'),next.canSwitchDefender?'E':'Q');
  $('result-rematch').dataset.start=teamMode?'team':'duel';
  setHudText($('shot-stat'),`${next.makes} / ${next.attempts}`);
  setHudText($('music-now'),next.musicTrack>=0?['ASPHALT GROOVE · BOOM BAP','FAST BREAK · FUNK','NEON COURT · ELECTRO'][next.musicTrack]:'경기 시작 후 재생');
  setHudText($('commentary-caption'),next.commentaryLine || '');
  $('commentary-caption').dataset.sequence=String(next.audioCalls || 0);
  for(const button of document.querySelectorAll('[data-position]')){button.disabled=!next.canChangeRole;button.setAttribute('aria-pressed',String(button.dataset.position===next.courtRole));}
  setHudText($('player-role-title'),{guard:'THE PLAYMAKER',forward:'THE SWINGMAN',center:'THE ANCHOR'}[next.courtRole] || 'THE PLAYMAKER');
  setHudText($('player-role-tagline'),{guard:'빠른 발. 대담한 첫걸음.',forward:'넓은 활동 범위. 공중 경합.',center:'골밑 자리부터 높은 공까지.'}[next.courtRole] || '빠른 발. 대담한 첫걸음.');
  setHudText($('role-description'),{guard:'가드 · 빠른 이동',forward:'포워드 · 이동과 공중 경합의 균형',center:'센터 · 높은 리바운드와 강한 박스아웃'}[next.courtRole] || '가드 · 빠른 이동');
  // Read-only diagnostics make reports reproducible without granting game authority to the UI.
  window.ufState=Object.freeze({...next});
  document.body.classList.toggle('inspecting',Boolean(next.inspecting));
  setHudText($('showroom-detail'),next.closeup?'전신 보기':'상체 확대');
  setHudText($('showroom-motion'),['동작: 대기 → 달리기','동작: 달리기 → 크로스오버','동작: 크로스오버 → 턴','동작: 턴 → 투스텝','동작: 투스텝 → 비하인드','동작: 비하인드 → 헤지테이션','동작: 헤지테이션 → 대기'][next.motionPreview || 0]);
  canvas.dataset.phase=next.phase;canvas.dataset.action=next.action;
  if(next.online)canvas.dataset.onlineProbe=JSON.stringify({tick:next.onlineTick,slot:next.onlineSlot,player:next.player,ball:next.ball,owner:next.owner});else delete canvas.dataset.onlineProbe;
  // Opt-in, read-only scene observations for reproducing live 1v1 defense.
  if(next.contactProbe){canvas.dataset.contactProbe=JSON.stringify(next.contactProbe);canvas.dataset.rivalAction=next.contactProbe.opponentAction;canvas.dataset.owner=String(next.contactProbe.owner);}
  $('drill-slow').disabled=next.inspecting || !next.started || next.mode!=='practice';
  $('drill-slow').setAttribute('aria-pressed',String(Boolean(next.slowPractice)));
  setHudText($('drill-slow'),next.slowPractice?'보통 속도로 연습':'느리게 연습');
  const finishName={shot:'JUMP SHOT',layup:'LAYUP',dunk:'DUNK',hook:'HOOK SHOT',fadeaway:'FADEAWAY'}[next.finish] || 'JUMP SHOT';
  const defensiveMove=next.defenseAction || (next.reboundWindow?'rebound':'');
  const passingPhase=teamMode && ['pass_windup','pass_flight'].includes(next.phase);
  for(const button of document.querySelectorAll('[data-control=shoot]'))button.disabled=passingPhase;
  setHudText($('touch-shot-label'),passingPhase?'패스 중':next.owner!==0?(defensiveMove==='rebound'?'리바운드':'블록'):next.finish==='dunk'?'덩크':next.finish==='layup'?'레이업':'슛 / 점프');
  setHudText($('finish-label'),passingPhase?'PASS · CATCH':defensiveMove==='rebound'?'D · REBOUND':defensiveMove==='block'?'D · BLOCK':'D · '+finishName);
  $('shot-cue').classList.toggle('active',next.started && !next.paused && next.owner===0 && !next.clear && next.action==='gather');
  $('shot-cue').classList.toggle('sweet',next.sweet);
  $('release-fill').style.width=`${Math.min(100,next.charge*100)}%`;
  setHudText($('release-hint'),passingPhase?'패스 후 받는 선수로 자동 전환됩니다.':defensiveMove==='rebound'?'W로 자리 지키기 · 내려오는 공을 D로 캐치':defensiveMove==='block'?'상대가 공을 올릴 때 D · 가까이서 손바닥으로 쳐내기':next.sweet?'지금 놓기! SWEET RELEASE':next.held && next.action==='idle'?'드리블 종료 · 방향키 피벗 / D 슛':next.finish==='dunk'?'덩크 거리 · 달리며 D로 바로 마무리':next.finish==='layup'?'레이업 거리 · 달리며 D로 이어서 도약':'초록 구간에서 D 놓기 · 유지하면 자동 슛');
  for(const button of document.querySelectorAll('[data-drill]')){button.disabled=next.inspecting || !next.started || next.mode!=='practice';button.setAttribute('aria-pressed',String(next.drill===button.dataset.drill));}
  setHudText($('score-you'),String(next.score[0]).padStart(2,'0'));
  setHudText($('score-rival'),next.mode==='practice'?'—':String(next.score[1]).padStart(2,'0'));
  setHudText($('clock'),next.mode==='practice'?'∞':next.phase==='ended'?'FINAL':next.seconds===0?(next.score[0]===next.score[1]?'OT':'0:00'):`${Math.floor(next.seconds/60)}:${String(next.seconds%60).padStart(2,'0')}`);
  setHudText($('mode-badge'),next.careerMode==='team'?'MY TEAM':next.careerStage?'COURT '+next.careerStage:next.mode==='practice'?'FREE COURT':teamMode?'3 ON 3':'1 ON 1');
  setHudText($('shot-clock'),next.mode==='practice'?'나만의 리듬으로':next.phase==='ended'?'경기 종료':`공격 제한 ${Math.max(0,next.shotClock)}초`);
  setHudText($('shot-stat'),`${next.makes} / ${next.attempts}`);
  setHudText($('accuracy'),next.attempts?`${Math.round(next.makes/next.attempts*100)}% FG`:'—');
  const possession=next.phase==='check'?'CHECK BALL · 자리로 복귀':next.phase==='ended'?'FINAL SCORE':next.secured?'SECURED · 공중 캐치 → 보호 → 착지':next.action==='cross'?'CROSS · 속임 → 바운스 → 반대 손':next.action==='rebound'?'REBOUND · 공을 향해 캐치':next.action==='block'?'BLOCK · 손바닥으로 쳐내기':next.boxout?'BOX OUT · W 유지 / D 리바운드':next.guard?'LOW GUARD · 낮은 수비':next.mode==='practice'?'FREE PRACTICE':next.clear?(next.owner===0?'외곽선 밖으로 공 빼기':'RIVAL CLEARING'):next.owner===0?'YOUR BALL · 내 공격':next.owner===1?'DEFENSE · 내 수비':teamMode && next.owner===2?'TEAM BALL · 동료 공격':'BALL IN THE AIR';
  setHudText($('possession').lastElementChild,possession);
  $('feedback').classList.toggle('visible',next.feedback && next.started && !next.paused && next.phase!=='ended');
  if(previousHeadline!==next.headline){setHudText($('feedback-title'),next.headline);setHudText($('feedback-detail'),next.detail);previousHeadline=next.headline;}
  $('pause-overlay').classList.toggle('hidden',!next.paused || !next.started || manuallyChoosing || next.phase==='ended');
  setHudText($('pause-reason'),next.pauseReason || '경기는 여기에서 기다릴게요. 계속 플레이를 눌러 이어가세요.');
  if(next.paused && !wasPaused && next.started && !manuallyChoosing && !$('info-dialog').open)$('resume-button').focus({preventScroll:true});
  $('result-overlay').classList.toggle('hidden',next.phase!=='ended');
  setHudText($('pause-button'),next.paused?'▶':'Ⅱ');
  $('pause-button').setAttribute('aria-label',next.paused?'경기 계속하기':'일시정지');
  if(next.phase==='ended') {
    setHudText($('result-title'),next.score[0]>next.score[1]?'YOU WIN.':'RUN IT BACK.');
    setHudText($('result-score'),`${next.score[0]} : ${next.score[1]}`);
    setHudText($('result-detail'),teamMode?(next.careerMatchId?'성장 팀전 · 직접 조작한 기여 기록':'AI 3대3 · 보상 없음'):`내 슛 ${next.makes}/${next.attempts} 성공 · 한 판 더 도전해 보세요.`);
  }
  if(typeof CustomEvent==='function')window.dispatchEvent?.(new CustomEvent('court-state',{detail:next}));
};

window.CourtGame={getState:()=>state,pause:()=>requestPause('선수 화면을 보는 동안 경기를 멈췄습니다.'),setAppearance(ids){input.appearance=JSON.stringify(ids||{});},wardrobe(data){if(!ready)return false;clearInput();input.wardrobe=JSON.stringify(data);command('wardrobe');return true;},closeWardrobe(){if(ready)command('wardrobe-close');},startCareer(data){
 if(!ready)return;
 clearCareerResult();
 clearInput();input.suspended=false;unlockAudio();input.career=JSON.stringify(data);manuallyChoosing=false;
 selectMode(data.mode==='team'?'team':'duel');document.body.classList.add('in-play');
 $('pause-overlay').classList.add('hidden');$('result-overlay').classList.add('hidden');
 command('career');canvas.focus({preventScroll:true});$('arena').scrollIntoView({block:'center',behavior:'instant'});
 if(window.GodotAudio?.ctx?.state==='suspended')window.GodotAudio.ctx.resume().catch(()=>{});
}};

let infoSource='';
window.addEventListener('court-language-change',()=>{requestPause('언어를 바꾸는 동안 경기를 멈췄습니다.');if($('info-dialog').open && infoSource)$('dialog-content').innerHTML=window.CourtI18n.infoHTML(infoSource);});
function showInfo(content) {
  infoSource=content;
  requestPause('안내를 확인하는 동안 경기를 멈췄습니다. 닫은 뒤 계속 플레이를 눌러 이어가세요.');
  $('dialog-content').innerHTML=window.CourtI18n?.infoHTML(content) || content;$('info-dialog').showModal();
}
$('updates-button').addEventListener('click',()=>showInfo('<span class="eyebrow">COURT NOTES / 2026.10.28</span><h2>조작은 편하게, 반복 계산은 가볍게.</h2><p>v0.10.6 · 온라인 표시·모바일 조작 개선</p><p>온라인 예측 중 내 선수의 중복 관절 계산과 입력 자료 해석을 줄였습니다. 기존 모션과 경기 판정은 유지합니다. 휴대폰 조이스틱은 높이를 유지한 채 오른쪽으로 16px 옮겼습니다.</p><h3>입력한 순간부터 움직이기.</h3><p>v0.10.5 · 온라인 조작 반응 개선</p><p>내 이동·드리블·슛 준비·수비 동작은 서버 응답을 기다리지 않고 기기에서 바로 시작하며, 확인된 위치로 부드럽게 보정합니다. 공 소유권·접촉·득점·승패와 Elo는 서버 판정을 따릅니다. 긴 통신 중단에서는 끊김이 남을 수 있습니다.</p><h3>온라인 경기 서버 부담 줄이기.</h3><p>v0.10.3 · 온라인 처리 최적화</p><p>온라인 1대1 서버가 같은 경기 판정을 처리하면서 반복 실행에 쓰는 자원을 줄였습니다. 실제 손과 공의 접촉·선수 모션·능력치·승패와 Elo는 유지하며, 상태가 도착하는 간격과 지연을 측정해 끊김을 점검합니다.</p><h3>같은 동작, 가벼운 모션 계산.</h3><p>v0.10.2 · 3대3 모션 처리 최적화</p><p>선수 6명의 모션에서 불필요한 전체 뼈 복사와 임시 배열 생성을 줄이고, 같은 손가락 자세와 프레임 안의 변환 계산을 재사용합니다. 달리기·드리블·발 디딤·슛·블록·리바운드는 같은 박자로 계속 계산하며 손·발 접촉과 동작 전환을 유지합니다. 시스템 부하에 따라 끊김이 남을 수 있으며 모든 기기에서 일정한 FPS를 보장하는 변경은 아닙니다.</p><h3>공개방은 목록에서 바로 입장.</h3><p>v0.10.1 · 공개방과 친구방 입장 구분</p><p>공개방은 목록에서 원하는 방의 입장을 누르면 됩니다. 코드는 만들거나 표시하지 않습니다. 친구끼리 할 때는 비공개 연습방을 만들고, 친구방 코드로 입장을 펼쳐 코드를 입력하세요. 공개방·자동 매칭은 전적과 Elo에 반영되고, 비공개 연습은 반영되지 않습니다.</p><h3>내 선수로, 함께 뛰고 순위를 올리기.</h3><p>v0.10.0 · 대전방과 온라인 랭킹</p><p>기존에 장착한 외형과 키운 포지션·체격·능력치·기술로 온라인 1대1에 참가하세요. 공개 대전방을 만들거나 목록에서 입장하고, 두 사람 모두 준비하면 경기가 시작됩니다. 비공개 연습방은 8자리 코드로 입장하며 자동 매칭도 유지합니다.</p><p>공개방과 자동 매칭은 별도 온라인 승패·무승부와 Elo 랭킹에 반영됩니다. 1,000점에서 시작하고 상대 점수에 따라 변동합니다. 비공개 연습은 전적·점수에 반영되지 않으며 온라인 경기의 추가 경험치·코인 보상은 없습니다. 90초·11점 승부, 현재 한 경기씩 운영합니다.</p><h3>v0.9.8 · 온라인 1대1 첫 공개.</h3><p>v0.9.8 · 자동 매칭 첫 공개</p><p>온라인 1대1에서 다른 이용자와 자동 매칭합니다. 기존 선수 외형을 사용하고 능력치는 균등하며 성장 보상은 없습니다. 90초·11점 승부, 서버가 공과 득점을 판정합니다. 첫 접속은 서버 준비 시간이 걸릴 수 있고 현재는 한 경기씩 운영합니다. 메뉴나 다른 탭을 열어도 경기는 계속됩니다.</p><h3>쳐낸 공을 끝까지 쫓아서.</h3><p>v0.9.7 · 블록 뒤 루즈볼 경합</p><p>손바닥에 맞은 공이 비어 있는 옆 공간으로 강하게 튀어나갑니다. 공이 튀는 경로를 예상해 쫓아가고, 몸을 낮춰 받아 가슴으로 모은 뒤 드리블로 연결합니다. 아웃되면 선수들이 자리로 돌아오고 공을 받아 체크볼을 재개하며 순간 재배치하지 않습니다. 1대1과 3대3 모두 적용했습니다.</p><h3>v0.9.4 · 보고 반응하는 블록.</h3><p>v0.9.4 · 1대1 블록 반응과 손끝 접촉</p><p>상대가 슛하는 것을 보고 뛰어도 손이 제때 올라가도록 도약과 팔 뻗기를 앞당겼습니다. 아래를 향한 손바닥에 올라오는 공이 실제 닿으면 블록이 되며, 내려치기와 팔 회수·착지로 이어집니다. 가까이 붙어 공을 들어 올리는 순간 D 또는 블록을 누르세요.</p><h3>v0.9.3 · 손끝으로 막고, 결과까지 확인.</h3><p>v0.9.3 · 블록 성공과 소유권을 한눈에</p><p>블록 직후 공을 누가 잡았는지 결과를 한국어와 선택한 언어로 바로 보여줍니다. 빠른 수비 점프 입력과 정면 디딤 개선도 함께 적용됩니다.</p><h3>v0.9.2 · 블록 성공을 확실하게.</h3><p>v0.9.2 · 블록과 공 소유권 표시</p><p>블록 직후 공이 상대나 내 팀에 닿아 바로 잡혀도 블록 성공과 공을 잡은 쪽을 함께 보여줍니다. 실제 공과 몸이 닿으면 바로 잡는 규칙을 유지합니다.</p><h3>v0.9.1 · 손끝까지 이어지는 블록.</h3><p>v0.9.1 · 블록 점프 입력과 정면 접근</p><p>짧게 누른 슛·점프 입력이 게임 프레임 사이에 놓치지 않도록 수비 점프 입력을 보존했습니다. 정면에서 블록할 때 디딘 발로 조금 더 접근하며, 손바닥과 공이 실제로 닿으면 아래로 쳐냅니다. 멀리 있거나 상대 몸을 뚫고 막는 판정은 허용하지 않습니다.</p><h3>v0.9.0 · 함께 뛰고, 함께 성장.</h3><p>v0.9.0 · AI 3대3 성장 팀전과 모바일 카메라</p><p>내 선수 화면에서 성장 팀전을 시작하세요. AI 동료와 11점 또는 3분 승부를 마치면 경험치와 코인을 받고, 직접 조작한 득점·어시스트·리바운드·블록·스틸 기여도 반영됩니다. 1대1과 같은 선수의 스탯·기술을 훈련하고 의상을 살 수 있습니다. 일반 팀전에는 보상이 없습니다.</p><p>모바일에서 먼 외곽으로 이동할 때 카메라의 7% 단계 줌을 없애고 확대·축소를 연속적으로 연결했습니다.</p><h3>v0.8.10 · 팔부터 발끝까지, 크게 달리기.</h3><p>v0.8.10 · 전신 달리기와 드리블 반대 팔</p><p>달리는 발이 몸의 전진을 따라간 뒤 원본 스윙을 이어가도록 바꿔 앞다리가 뒤처지던 현상을 고쳤습니다. 짧은 보정 스텝을 제거하고 긴 디딤과 큰 팔 스윙을 연결했습니다. 드리블하는 손은 공 접촉을 유지하며 반대 팔이 발 박자에 맞춰 크게 움직입니다. 스킬 후 멈추면 정상 대기 자세로 돌아갑니다.</p><h3>v0.8.9 · 보폭은 길게, 마무리는 제자리로.</h3><p>v0.8.9 · 달리기와 스킬 후 대기 자세</p><p>달릴 때 앞발을 뻗고 뒤꿈치를 접어 회수하도록 원본 클립의 보폭과 발 높이를 살렸습니다. 대기 화면의 다리 꼬임을 고치고, 드리블 스킬 후 멈추면 한 발씩 옮겨 정상적인 서 있는 자세로 돌아옵니다. 이동을 이어가면 멈추지 않고 달립니다.</p><h3>v0.8.8 · 같은 박자로 뛰고, 부드럽게 마무리.</h3><p><b>v0.8.8 · 달리기 발 교대와 슛 팔 회수</b></p><p>첫걸음 뒤 발을 바꿔 뛰던 달리기를 디딤과 같은 박자로 맞추고, 출발 때 같은 발이 다시 뜨던 동작을 보완했습니다. 45도 슛 릴리즈 뒤 반대 손은 먼저 내리고 슛한 팔은 손목 마무리를 유지한 뒤 회수합니다. 달리다 슛할 때 뒤쪽 발을 모으는 연결도 다듬었습니다.</p><p><b>v0.8.7 · 빠른 페이크와 방향별 마무리</b></p><p>제자리 페이크를 0.30~0.50초로 줄이고, 회수 중 다음 페이크·슛·패스를 연결합니다. 짧은 입력을 놓치지 않도록 보완했습니다. 페이크 후 골대 3m 이내에서 골대 방향+슛은 레이업, 방향 없음·옆·뒤 방향+슛은 제자리 슛. 재드리블 없이 이어지고 기존 훅슛·페이더웨이 조합도 유지합니다.</p><p><b>v0.8.6 · 크게 읽히는 페이크와 슛 조합</b></p><p>피벗·잽·펌프·업앤언더·턴의 공과 어깨 동작을 키우고, 발 디딤에 신발 마찰음을 맞췄습니다. W+D 또는 기존 돌파+슛 동시 입력으로 골밑 훅슛, 림 반대 방향을 더하면 페이더웨이. 이동 중 턴 슛은 지상 디딤에서 공중 회전으로 이어지며, 첫 바운드 중인 루즈볼도 몸이나 손에 닿으면 확보합니다.</p><p><b>v0.8.5 · 코트를 가리던 안내판 제거</b></p><p>경기 화면 위를 덮던 수비 전환 버튼·조작 설명·선수 정보 패널을 제거했습니다. E키와 하단의 상황별 터치 선수 전환, 발밑 선택 링은 유지합니다. 조작법은 기존 도움말에서 확인할 수 있습니다.</p><p><b>v0.8.4 · 돌아서 쏘기와 공 보유 페이크</b></p><p>림 반대나 옆으로 이동하며 슛할 때, 마지막 발을 딛고 축발로 몸을 돌린 뒤 반대 발을 받아 공을 올리도록 연결했습니다. 릴리즈 직전에 회전이 몰리던 동작과 슛 후 달리기 전환의 무릎 튐을 다듬었습니다.</p><p>드리블이 끝나면 방향키·스틱으로 피벗과 잽 스텝, A 피벗 페이크·Z 턴 페이크·C 업앤언더·V 다리 사이 공 페이크·X 펌프 페이크를 사용하세요. 축발과 공 보유를 유지하며 다시 드리블하지 않습니다. D로 슛하고 짧게 누르면 펌프 페이크입니다.</p><p>3대3의 선택 선수와 페이크 후 패스, 보유 상태에 맞춘 모바일 버튼, 캐릭터 스튜디오의6개 페이크 미리보기를 추가했습니다. 회전·페이크 중 화면을 벗어나면 예약된 슛을 취소하고 공을 든 채 기다립니다.</p><p><b>v0.8.3 · 슛 회복과 3대3 경기 흐름</b></p><p>슛 후 손목을 꺾고 팔을 내린 뒤, 착지한 발로 밀어 다시 달리도록 연결했습니다. 얼굴·몸통·팔의 슛 방향도 골대를 향하도록 정렬했습니다.</p><p>3대3 수비 전환 버튼과 현재 조작 선수 표시를 추가하고 E로 세 선수 모두 선택할 수 있게 했습니다. 공 없는 동료는 컷인·스크린·롤·재배치를 이어가며, 골밑으로 돌파하면 공간을 비워 줍니다.</p><p>W 낮은 수비는 정면 접촉만 최대10cm 늘어납니다. 옆·뒤로 재치거나 수비가 헛디딘 동안에는 추가 범위가 적용되지 않습니다.</p><p>코트·공의 렌더링과 팀전 화면 처리 비용을 줄였습니다. 전체화면의 끊김은 기기에 따라 아직 남아 있어 계속 개선합니다.</p><p><b>v0.8.2 · 이동 슛 디딤과 팔 자세</b></p><p>옆이나 뒤로 달리다 슛할 때 발이 교차하던 문제를 고쳤습니다. 회수 발과 닫는 발을 차례로 연결하고, 긴 보폭의 뒤쪽 발은 자연스럽게 밀고 떨어집니다. 빠른 슛에서도 마지막 발 동작이 도약 전에 이어집니다.</p><p>왼팔이 머리 옆으로 벌어지는 대신 얼굴 앞에서 공을 받치도록 팔꿈치와 전완을 정렬했습니다. 몸이 돌아갈 때 손도 함께 따라가며, 상체 정돈과 팔꿈치 회수 연결을 다듬었습니다. 캐릭터 스튜디오에서 달리다 슛을 정면·측면으로 반복 확인할 수 있습니다.</p><p><b>v0.8.1 · 슛 도약과 새로운 의상 형태</b></p><p>무릎으로 하중을 받고 앞꿈치로 밀어 도약한 뒤, 공중에서 발목을 펴고 착지 충격을 무릎으로 받도록 슛을 연결했습니다. 짧은 슛 페이크에서도 준비 자세가 튀지 않도록 다듬었습니다.</p><p>넓은 어깨판과 둥근 목둘레의 저지, 실제 소매·후드·주머니가 있는 반팔·후드티·바시티 재킷과 조거·카고 팬츠를 추가했습니다. 모자4형·기본 포함 헤어6형과 색상 선택을 더해 총138항목을5부위로 구매·장착합니다. 모자 착용용 헤어 조정과 형태 필터, 기존 구매 기록 보존을 적용했습니다.</p><p><b>v0.8.0 · 의상 상점과 94종 수집</b></p><p>상의32종·하의31종·농구화31종을 코트 코인으로 구매하고 부위별로 장착하세요. 9개 신규 테마의 한 벌 미리보기와 회전, 보유 필터·수집 현황, 코트 진행도별 해금을 추가했습니다. 의상은 능력치를 바꾸지 않으며 구매·장착 기록은 계정에 저장됩니다.</p><p>첫 선수와 기존 선수에게300 코인. 육성1대1 첫 클리어120~260·재승리45~80·패배20 코인을 지급합니다. 연습·일반1대1·AI3대3에는 보상이 없습니다. AI 동료2명과 함께하는3대3, Q 패스·E 수비 전환, 공 소지 팔과 손목의 측면 굽힘 보정도 이번 공개판에 포함했습니다.</p><p><b>v0.7.6 · 블록 판정 수정</b></p><p>도약 중 아래로 휘두른 손이 공에 닿아도 블록이 취소되던 문제를 수정했습니다. W 유지 중 슛 초반의 블록 선택과 방향 전환 직후의 타격 방향을 연결하고, 터치 버튼에 블록·리바운드를 구분해 표시합니다.</p><p><b>v0.7.5 · 수비 동작 개선</b></p><p>짧은 교대 옆걸음과 추격 후 발을 딛고 낮은 자세로 들어가는 연결, 팔·어깨를 회수하는 흐름을 다듬었습니다. 신장에 맞춘 다리 길이 계산으로 작은 가드의 발 끌림도 수정했습니다. 캐릭터 스튜디오에서 낮은 수비·좌우 수비·박스아웃 세 가지를 반복 확인할 수 있습니다.</p><p><b>v0.7.4 · 모션 전환 개선</b></p><p>급정지·블록·리바운드로 전환할 때 발과 무릎이 튀는 현상을 수정했습니다. 몸통·어깨 보정의 중복을 줄이고 리바운드 후 가슴에서 드리블로 이어지는 손과 달리는 반대 손의 자세를 다듬었습니다. 같은 경기 안내를 반복해서 다시 쓰지 않도록 화면 갱신도 최적화했습니다.</p><p>득점·덩크·드리블 기술·블록·공중 리바운드에 영어 해설 27개를 연결했습니다. 자체 제작 배경음악 3곡을 선택하거나 순환 재생하고 음악·해설·효과음 음량을 따로 조절할 수 있습니다. 모바일 왼쪽 조이스틱을 위로 올렸습니다.</p><p>모바일은 선수를 크게 보는 추적 카메라로 변경했습니다. 큰 슛 안내판 대신 슛 준비 중에만 버튼 옆 작은 게이지를 표시하고 점수판도 줄였습니다. 한국어·영어·일본어·간체 중국어를 선택하면 경기 안내·계정·육성 메뉴에 적용되며 이 기기에 저장됩니다.</p><p>공통 메뉴의 전자책 버튼에서 로키스튜디오 전자책 안내를 새 탭으로 열 수 있습니다.</p><p>웹 공통 메뉴·전체 화면 메뉴와 연구 화면에 더 좋은 앱을 위한 후원 안내를 추가했습니다. 새 탭에서 계좌를 확인·복사할 수 있습니다.</p><p><b>v0.7.2 · 모바일 카메라·작은 슛 게이지·4개 언어</b></p><ul><li>이메일 없이 아이디·비밀번호로 가입·로그인, 계정 복구 코드와 삭제</li><li>가드178cm·포워드190cm·센터204cm, 실제 체격과 포지션별 운동능력</li><li>AI 1대1 코트8단계, 승리 경험치와 스탯·기술 훈련, 계정별 서버 저장</li><li>달리는 슛 준비: 마지막 스텝에서 감속하며 공 모으기, 디딤→팔·몸통 펴기→릴리즈 연결</li><li>슛·레이업의 실제 발끝 밀기와 도약 발 기준 유지, 공·손의 순간 이동 보정</li><li>발 접촉 뒤 무릎으로 충격을 받고 상체·팔 회수, 착지 회복 중 미끄러운 추가 이동 수정</li><li>이동 방향을 먼저 보는 시선, 공중 리바운드·블록의 올려다보기와 확보 후 고개 회수</li><li>크로스오버의 몸통·어깨 비틀림을 화면 리그에 연결, 반대 손 캐치 뒤 첫 돌파까지 자세 유지</li><li>공을 보낸 팔의 낮은 팔꿈치와 팔뚝을 따르는 손목, 어깨 방향에 맞춘 반대 팔 박자</li><li>스튜디오 크로스오버에 손 전환→방향 전환→다시 달리기 반복 추가</li><li>실제 손 위치에서 크로스오버 진입·복귀, 보내는 팔→달리기 팔의 손목 연결</li><li>레이업: 양손 모으기→보조 손 분리→한 손 올리기→손끝 릴리즈·착지 회수</li><li>리바운드: 실제 양손 캐치→손가락으로 감싸기→가슴으로 당기기, 슛 준비 전환 보간</li><li>드리블 팔: 낮은 팔꿈치로 누르기→짧게 따라 내리기→회수→올라온 공 받기의 반복 연결</li><li>바운드와 같은 박자로 손목을 접고 펴기, 기존 방향 전환 반응 유지</li><li>공 보유 대기: 양옆에서 받쳐 들기 · 슛: 포켓→보조 손 분리→한 팔 릴리즈·손목 팔로스루</li><li>발끝 밀기·뒤꿈치 들기·발 회수로 드리블 달리기 접지감 개선</li><li>일반 방향 전환의 강제 정지·재가속 대기 제거, 급정지와 수비 헛디딤 회복은 분리</li><li>낮은 골반·전방 상체 기울기와 짧은 발 들기, 보이는 다리와 반대 팔의 같은 박자</li><li>공 크기에 맞춘 바닥 접촉과 손 간격, 누르기·자유 낙하·반발·받아 누르기 드리블</li><li>양쪽 경기 캐릭터를 스킨 리그로 전환. 달리기 전신 클립 + 드리블 손·접지 보정</li><li>보이는 손바닥으로 접촉 판정, 반대 팔은 달리기 클립 유지. 컷·헛디딤·추격 연결</li><li>다리 역꺾임·새 접지 순간 이동 수정. 실제 발 출발점→착지점 연결, 중복 이동 제한 제거</li><li>얼굴·쇄골·어깨와 저지/반바지 입체 주름 재제작. 스튜디오에 컷·급정지와 상체 확대 추가</li><li>경기 외형을 사람형 메시로 교체: 얼굴·머리카락·저지·반바지·농구화, 청록 07 / 주황 23. 같은 45본 리그와 손·발 접촉 유지</li><li>별도 모션 실험실: 기존 캐릭터와 스킨 메시·제작된 전신 클립 나란히 비교. 오른쪽은 최종 외형이 아닌 GDQuest 마네킹(CC BY 4.0)</li><li>속은 수비: 헛디딤 접지 → 무릎으로 받기 → 지지 발을 축으로 돌아서기 → 짧은 첫발 → 추격</li><li>돌아서는 동안 즉시 가속·블록 방지, 뒤처지면 공격수를 향한 옆걸음 대신 달려서 추격</li><li>FINISH LAB → 돌파·수비 회복. 좌우+A로 속이고 ↑로 돌파해 확인</li><li>블록의 머리 위 준비 → 몸통·어깨 회전 → 손바닥 내려치기 → 팔 회수 재구성</li><li>돌파에 속은 수비의 회복과 뒤쫓는 블록의 방향·거리·몸 가림 검사</li><li>실제 미스 슛의 림 접점과 높게 튀는 리바운드, 낙하를 기다리는 AI</li><li>시험용 G/F/C 선택 · 센터의 높이·박스아웃, 포워드의 이동 리바운드</li><li>림·박스아웃 경합 연습 추가. 이 연습의 상대 슛은 미스로 고정</li><li>블록: 손바닥 스윙과 같은 방향으로 공을 강하게 쳐내기. 접촉 직후 짧은 궤적 표시</li><li>30~45도 컷도 먼저 접지·하중 처리. 달리기 복귀 후에도 지지 다리 범위 안에서 이동</li><li>몸통과 같은 좌표에서 팔을 돌려 어깨·팔꿈치가 뒤처지는 현상 완화</li><li>FINISH LAB → 디딤·방향 전환. 느린 측면 시점에서 접지와 재출발 확인</li><li>낮은 달리기: 디딤·무릎 압축·뒤꿈치 밀기와 어깨·반대 팔을 같은 발 박자로 연결</li><li>방향 전환: 지지 발로 받기 → 가슴을 새 방향으로 넘기기 → 짧은 첫발 → 커지는 보폭</li><li>낮아진 몸통과 독립적으로 공을 아래로 누르는 손바닥 방향 유지</li><li>크로스오버를 6개 기준 자세로 재구성: 낮은 속임 → 강한 푸시 → 체중 이동 → 반대 손 캐치 → 돌파</li><li>현재 바운스에서 전환, 받는 손 접촉 후 손 교대, 첫 드리블과 달리기로 연결</li><li>크로스오버 연출 연습과 새 동작을 사용하는 확대 미리보기</li><li>달리는 반대 팔: 어깨 회전 → 팔꿈치 굽힘 → 팔뚝을 잇는 손목, 발 박자와 연결</li><li>드리블 손: 팔꿈치는 몸 가까이, 공 상단을 보는 손바닥과 손목·엄지 방향 조정</li><li>움직이는 위팔에 붙는 어깨 형태와 편하게 닿는 드리블 공 위치</li><li>코트러시 · COURT RUSH로 이름 변경</li><li>달리기 상체 회전·골반 반대 회전, 굽힌 팔꿈치와 교대 팔 흔들림</li><li>드리블: 손으로 밀기 → 손 회수 → 튀는 공 받기, 손목과 바운스 소리 박자 통일</li><li>블록 접촉 시 내려치는 팔의 속도를 이어가고, 리바운드는 하강 중 가슴으로 당겨 착지</li><li>블록: 팔을 들어 손바닥으로 내려치기 → 손목 꺾기 → 팔 회수, 실제 접촉 뒤 공을 아래로 쳐냄</li><li>리바운드: 양손으로 공중 캐치 → 머리 위 확보 → 가슴으로 당기기 → 무릎으로 착지</li><li>양손이 공에 모여야 캐치 판정, 느린 리바운드 시점에서 골대 구조물 가림 개선</li><li>S 스틸: 짧게 전진 → 공 쪽 한 손 뻗기 → 접촉 → 공 당기기 또는 손 회수</li><li>손이 공에 닿는 구간에서 스틸 판정, 성공한 공은 손을 따라 드리블로 연결</li><li>스틸 파고들기 연습과 느린 측면 시점 추가</li><li>방향 전환 뒤 첫 밀기 → 반대 발 받기 → 두 번째 밀기 → 커지는 세 번째 보폭</li><li>세 걸음의 접지 진행도에 맞춘 재가속, 현재 지지 발을 따르는 체중 이동</li><li>받아준 발도 앞꿈치를 고정하고 다음 보폭으로 밀어내도록 연결</li><li>달리기 정지·방향 전환: 제동 발 디딤 → 무릎 흡수 → 체중 이동 → 재출발</li><li>발 접촉 뒤 몸통 회전, 지지 발 고정과 앞꿈치 밀어내기</li><li>정지 뒤 서서히 펴지는 무릎과 제동/가속에 맞춘 팔 흔들림</li><li>첫 네 걸음에 걸쳐 보폭과 발 높이를 늘려 달리기로 연결</li><li>실제 발 교대에 맞춘 어깨·반대 팔 흔들림, 드리블하는 손은 유지</li><li>디딤·다리 교대에 맞춘 몸통 높낮이와 서서히 커지는 팔 흔들림</li><li>앞꿈치 고정 → 뒤꿈치 들기 → 지지 무릎 펴기, 바닥을 밀어내는 첫걸음</li><li>첫 두 걸음의 접지 박자에 맞춘 가속과 달리기 연결, 걸음 사이 제동 완화</li><li>착지 후 무릎으로 충격 흡수 → 지지 발로 밀기 → 반대 발 첫걸음 연결</li><li>착지 회복 중 좌우 이동·급반전·정지에도 골반 높이와 속도를 부드럽게 유지</li><li>캐치 순간 손이 공의 속도를 받아낸 뒤 팔꿈치를 접어 공 보호</li><li>실제 블록 접촉 시점에 맞춘 손목·팔꿈치 회수와 아래 방향 쳐내기</li><li>발끝 → 뒤꿈치 → 무릎 압축 → 회복, 양발 착지 시차와 지지 발 고정</li><li>창 전환·안내창에서 안전하게 경기 정지, 직접 계속 플레이로 재개</li><li>슛 준비 중 중단하면 공을 손에 유지, 복귀 뒤 키 반복·터치 잔류 입력 방지</li><li>효과 줄이기를 일시정지 중 연출과 UI에도 적용, 설정 저장 실패 안내</li><li>리바운드: 두 손 캐치 → 가슴으로 당기기 → 착지 후 드리블 연결</li><li>블록: 한 손으로 릴리즈 차단 → 손목으로 쳐내기 → 착지 회복</li><li>손·공 접촉 판정과 짧은 준비 도약, 리바운드·블록 반복 연습 추가</li><li>낮은 수비의 지지 발 고정과 짧은 옆걸음: 열기 → 착지 → 뒤따르는 발 회수</li><li>착지 박자에 맞춘 체중 이동, 급반전과 정지 시 발 끌림 개선</li><li>박스아웃의 등 접촉 방향, 체중 이동과 압박에 따른 버티기 자세 개선</li><li>W 낮은 수비: 상대를 보며 짧은 옆걸음, 낮은 발 들기, 부드러운 자세 전환</li><li>느린 박스아웃 연습에서 가까운 측면 시점 지원</li><li>W 박스아웃: 슛 이후 등으로 진입 차단 · AI 박스아웃·측면 탈출·리바운드 판정 연결</li><li>달리는 레이업의 속도 유지·발뒤꿈치 들기·발끝 밀기·상승 속도 연결 개선</li><li>느린 레이업 연습에서 동작을 가까이 확인</li><li>레이업 도약: 준비 자세 높이 유지 → 지지 다리 펴기 → 반대 무릎 상승</li><li>FINISH LAB에 느리게 연습 추가</li><li>비하인드 백: 미는 손→바운스→받는 손 순서 수정</li><li>레이업의 반대발 도약·무릎 올리기, 덩크의 팔 들어올림→림 누르기 분리</li><li>슛 릴리즈 전후 이동 연속성, 착지 접지 복구</li><li>1대1 수비의 헛디딤·관성·추적 복귀, 정면 접촉의 옆 방향 이동 개선</li><li>양발을 하나의 순서로 제어: 착지 후 반대 발 출발</li><li>Z 턴 · C 투스텝 · V 비하인드 백 · X 헤지테이션 · 터치 버튼 지원</li><li>달리는 골밑 D는 바로 레이업, 더 가까우면 덩크 · 이동을 이어가는 짧은 개더</li><li>캐릭터 어깨 연결, 바지 밑단, 코 형태와 팔 반동 보정</li><li>원근 카메라와 가장자리 추적, 청록색 스트리트 코트</li><li>크로스오버 중 뒷다리 늘어짐 수정 · 팔다리 길이 고정</li><li>캐릭터 확대 화면에 달리기·크로스오버 미리보기 추가</li><li>사진 질감 대신 손으로 그린 눈매·얼굴 명암·옷 주름 적용</li><li>지면에 디딘 발 고정, 무릎 역기구학과 상체 반동, 팔 동작 연결 개선</li><li>15×14m 반코트, 선수·공·림 크기와 코트 선 비율 수정</li><li>연속된 의상 실루엣, 각진 턱과 광대, 차분한 스트리트 의상과 얇은 윤곽선</li><li>캐릭터 가까이 보기: 실제 게임 모델 두 명을 확대해서 확인</li><li>손 전환 드리블, 슛 준비→도약→릴리즈→착지, 릴리즈 타이밍 보너스</li><li>골밑 레이업·진입 속도에 따른 덩크, 블록과 리바운드 연동</li><li>FINISH LAB에서 레이업·덩크 위치를 바로 연습</li><li>두 손으로 잡으면 드리블 종료: 피벗·슛만 가능, 재드리블 방지</li><li>자유 연습과 AI 1대1 · 90초 또는 11점 승부</li><li>드리블, 크로스오버, 슛 페이크, 슛, 블록, 스틸, 리바운드</li><li>키보드·터치 조작, 일시정지, 소리·효과 설정</li></ul><p>AI 1대1·3대3 육성 경기는 기기에서 실행됩니다. 온라인 1대1은 서버에 저장된 선수 외형·포지션·육성 능력치를 사용하며 Render 경기 서버가 판정합니다. 공개방과 자동 매칭의 승패·무승부·Elo 점수를 별도 온라인 전적으로 저장하고 순위를 표시합니다. 비공개 연습방은 정식 전적과 Elo에 반영되지 않습니다. 온라인 경기의 추가 경험치·코인 보상이나 유료 재화·현금 결제는 없습니다. <a href="privacy.html" target="_blank" rel="noopener">계정·저장 안내 ↗</a></p><p>Made with <a href="https://godotengine.org/license/" target="_blank" rel="noopener noreferrer">Godot Engine · MIT License ↗</a>. 코트·공·효과음은 이 프로젝트의 원본 제작물입니다. 경기의 리그와 기본 애니메이션은 <a href="https://github.com/gdquest-demos/godot-3d-mannequin" target="_blank" rel="noopener noreferrer">GDQuest and contributors</a> / Luciano Muñoz, CC BY 4.0입니다. 얼굴 텍스처는 내장 imagegen으로 생성·편집하고 사람형 외형·농구복은 자체 제작했으며 원본 리그에 스킨 바인딩했습니다. 클립 재생·접촉 보정을 적용했습니다.</p>'));
$('help-button').addEventListener('click',()=>showInfo('<span class="eyebrow">GET INTO YOUR RHYTHM</span><h2>먼저, 공과 친해지기.</h2><ul><li><b>방향키</b> 화면 기준으로 이동합니다.</li><li><b>D 유지</b> 슛 준비 후 자동으로 던집니다. 0.18초보다 짧게 톡 누르면 슛 페이크입니다. 0.36~0.50초의 초록 구간에서 놓으면 성공 확률 보너스가 있습니다. 수비와 거리에 따라 실패할 수 있습니다.</li><li><b>공을 두 손으로 잡은 뒤</b> 드리블이 끝납니다. 방향키/스틱으로 축발을 유지한 피벗·잽 스텝, A 피벗 페이크·Z 턴 페이크·C 업앤언더·V 다리 사이 공 페이크·X 펌프 페이크를 사용하세요. 골밑 3m 이내에서 골대 쪽 방향+슛은 한 발을 딛는 레이업, 방향을 놓거나 옆·뒤 방향+슛은 제자리 슛입니다. D를 짧게 누르면 펌프 페이크입니다. 다시 드리블하지 않습니다.</li><li><b>W+D 또는 돌파(A)+슛(D) 동시 입력</b> 림에서 3.5m 이내면 훅슛, 림 반대 방향을 함께 누르거나 더 멀리 있으면 페이더웨이. 슛 키를 0.18초 이상 눌러 공을 모으세요. 모바일도 기존 돌파+슛 버튼을 함께 누릅니다.</li><li><b>골밑 D</b> 달리며 진입하면 3m 이내에서 레이업, 1.85m 이내에서는 덩크가 나갑니다. 골대 바로 앞 1.05m 이내에서는 제자리 덩크도 가능합니다. 달리는 중 D를 누르면 공을 모아 바로 도약하며, 멈춰서 D를 짧게 누르면 페이크입니다. 화면의 D · DUNK 표시를 확인하세요. 골대 뒤에서는 일반 슛입니다.</li><li><b>A</b> 공을 반대 손으로 넘기며 크로스오버. 방향키와 조합해 수비를 벗어나세요.</li><li><b>Z</b> 바깥손 드리블을 유지하며 몸을 한 바퀴 돌려 돌파합니다.</li><li><b>C</b> 바깥쪽 → 안쪽 두 번의 방향 전환으로 돌파합니다. 공을 잡고 걷는 동작이 아니라 드리블 중 투스텝입니다. 기술이 끝나면 A·Z·C를 다시 눌러 연결하세요.</li><li><b>V</b> 비하인드 백: 공을 등 뒤로 넘겨 반대 손으로 돌파합니다.</li><li><b>X</b> 헤지테이션: 잠깐 속도를 늦췄다가 다시 치고 나갑니다.</li><li><b>수비 중 D</b> 상대와 림 사이에서 공을 올리는 타이밍에 D를 누르면 블록 점프, 떨어지는 공에는 리바운드 점프. 튀는 루즈볼이 몸이나 손에 닿으면 첫 바운드부터 잡습니다.</li><li><b>S</b> 짧게 전진하며 공 쪽 손을 뻗어 스틸합니다. 상대를 바라보고 공이 있는 쪽에 접근하세요. 실제 손이 공에 닿는 구간에서 판정하며 성공은 보장되지 않습니다. 성공하면 공을 당긴 뒤 드리블로 이어가고, 실패하면 손을 회수합니다. FINISH LAB의 스틸 파고들기에서 반복 연습할 수 있습니다.</li><li><b>W 유지</b> 공이 없을 때 무릎을 낮추고 상대를 보며 짧게 옆걸음합니다. 놓으면 보통 자세로 돌아갑니다. 슛이 올라간 뒤 상대보다 림 쪽에서 W를 유지하면 등을 대고 박스아웃합니다. 방향키로 위치를 지키고 D로 뛰어 리바운드하세요. 상대가 옆으로 빠지면 박스아웃이 풀립니다.</li><li>1대1은 11점 선취 또는 90초. 동점이면 다음 득점으로 승부합니다. 수비 리바운드·스틸 뒤에는 외곽선 밖으로 공을 빼야 합니다.</li><li><b>Esc</b> 일시정지. 다른 창·탭으로 이동하거나 안내창을 열면 멈춥니다. 안내창을 닫아도 자동 재개되지 않으며, 계속 플레이를 눌러 이어갑니다. 중단한 제자리 슛 준비는 공을 손에 둔 채 취소됩니다.</li></ul><p>휴대폰은 가로 화면을 권장합니다. 터치 스틱과 오른쪽 버튼으로 같은 동작을 사용할 수 있습니다.</p>'));
$('close-dialog').addEventListener('click',()=>$('info-dialog').close());
$('compact-updates').addEventListener('click',()=>{if(document.fullscreenElement)document.exitFullscreen().then(()=>$('updates-button').click());else $('updates-button').click();});
$('info-dialog').addEventListener('close',()=>{clearInput();if(state?.started && input.suspended && !manuallyChoosing)$('resume-button').focus({preventScroll:true});else if(state?.started)canvas.focus({preventScroll:true});});

async function boot() {
  try {
    if(!window.Engine || !window.UF_ENGINE_CONFIG)throw new Error('게임 파일을 읽지 못했습니다. 로컬 서버 주소로 열어 주세요.');
    const missing=Engine.getMissingFeatures({threads:false});
    if(missing.length)throw new Error('이 브라우저에서 필요한 기능을 사용할 수 없습니다: '+missing.join(', '));
    const resizeCanvas=()=>{const rect=$('arena').getBoundingClientRect();const size=canvasSize(rect.width,rect.height,devicePixelRatio,state?.mode==='team');if(canvas.width!==size.width)canvas.width=size.width;if(canvas.height!==size.height)canvas.height=size.height;};
    resizeGameCanvas=resizeCanvas;
    resizeCanvas();
    const observer=new ResizeObserver(resizeCanvas);observer.observe($('arena'));
    const engine=new Engine({...window.UF_ENGINE_CONFIG,args:new URLSearchParams(location.search).get('frame-probe')==='1'?['--','--frame-probe']:[],canvas,canvasResizePolicy:0,focusCanvas:false});
    await engine.startGame({onProgress:(current,total)=>{if(total){$('load-progress').style.width=`${Math.round(current/total*100)}%`;$('load-label').textContent=`코트 준비 중 ${Math.round(current/total*100)}%`;}}});
    ready=true;
    document.title=window.CourtI18n?.text('코트러시 — COURT RUSH · Court 01') || '코트러시 — COURT RUSH · Court 01';
    $('load-label').textContent='준비 완료. 코트에서 만나요.';$('load-progress').style.width='100%';
    for(const button of document.querySelectorAll('[data-start],#sidebar-play'))button.disabled=false;
    // Settings are read directly by the game on each frame; avoid overwriting commands.
  } catch(error) {
    $('load-label').textContent=error.message;$('load-progress').style.background='#ef8d72';
    console.error('Court could not start:',error);
  }
}
boot();

window.CourtGame.startOnline=data=>{
 if(!ready)throw Error('코트가 준비되는 동안 잠시 기다려 주세요.');
 clearCareerResult();clearInput();input.suspended=false;unlockAudio();manuallyChoosing=false;
 input.onlineMatch=JSON.stringify(data);document.body.classList.add('in-play');
 $('pause-overlay').classList.add('hidden');$('result-overlay').classList.add('hidden');
 command('online-begin');canvas.focus({preventScroll:true});
 if(input.compactCamera)$('arena').scrollIntoView({block:'start',behavior:'instant'});
};
window.CourtGame.endOnline=()=>{clearInput();input.suspended=false;command('online-end');};

