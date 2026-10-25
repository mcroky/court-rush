/* The web shell owns accessible controls; Godot owns simulation and rendering. */
const $ = (id) => document.getElementById(id);
const canvas = $('canvas');
const input = window.ufInput = {x:0,z:0,shoot:false,cross:false,spin:false,twostep:false,behind:false,hesi:false,steal:false,guard:false,command:'',commandId:0,sound:true,reduced:false,suspended:false,pauseReason:'',audioSuspended:false};
function updateCameraLayout(){input.compactCamera=matchMedia('(pointer:coarse), (max-width:850px), (max-height:560px) and (orientation:landscape)').matches;document.body.classList.toggle('touch-layout',input.compactCamera);}
updateCameraLayout();window.addEventListener('resize',updateCameraLayout);
let selectedMode = 'practice';
let state = null;
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
  input.shoot = pressed.has('KeyD') || touches.has('shoot');
  input.cross = pressed.has('KeyA') || touches.has('cross');
  input.spin = pressed.has('KeyZ') || touches.has('spin');
  input.twostep = pressed.has('KeyC') || touches.has('twostep');
  input.behind = pressed.has('KeyV') || touches.has('behind');
  input.hesi = pressed.has('KeyX') || touches.has('hesi');
  input.steal = pressed.has('KeyS') || touches.has('steal');
  input.guard = pressed.has('KeyW') || touches.has('guard');
}
function clearInput() { pressed.clear(); touches.clear(); stickX=0; stickZ=0;stickPointer=null; $('stick').style.transform=''; updateInput(); }
function requestPause(reason='잠시 쉬었다가 직접 이어가세요.') {
  input.audioSuspended=true;
  clearInput();
  if((state?.started || document.body.classList.contains('in-play')) && state?.phase!=='ended') { input.suspended=true;input.pauseReason=reason; }
}
function resumeGame() {
  if($('info-dialog').open || manuallyChoosing || !state?.started || state.phase==='ended') return;
  clearInput();input.suspended=false;unlockAudio();command('resume');canvas.focus({preventScroll:true});
}
function start(mode) {
  if(!ready) return;
  clearInput();input.suspended=false;unlockAudio();selectMode(mode); manuallyChoosing=false;
  document.body.classList.add('in-play');
  $('pause-overlay').classList.add('hidden'); $('result-overlay').classList.add('hidden');
  command(mode); canvas.focus({preventScroll:true});
  if(input.compactCamera)$('arena').scrollIntoView({block:'start',behavior:'instant'});
  // Browser AudioContexts must be resumed from a user gesture.
  if(window.GodotAudio?.ctx?.state === 'suspended') window.GodotAudio.ctx.resume().catch(()=>{});
}
function selectMode(mode) {
  selectedMode=mode;
  for(const button of document.querySelectorAll('[data-select]')) {
    const active=button.dataset.select===mode;
    button.classList.toggle('selected',active); button.setAttribute('aria-pressed',String(active));
  }
  $('sidebar-play').innerHTML=(mode==='duel'?'1대1 시작하기':'연습 시작하기')+' <span>→</span>';
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
$('reset-button').addEventListener('click',()=>{if(!ready)return;if(state?.mode==='duel' && state.started){selectedMode='duel';requestPause();showRestartDialog();}else{clearInput();command('reset');canvas.focus();}});
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
const controls = new Set(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','KeyD','KeyA','KeyZ','KeyC','KeyV','KeyX','KeyS','KeyW']);
window.addEventListener('keydown',(event)=>{
  if($('info-dialog').open || document.getElementById('career-dialog')?.open || /^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName))return;
  if(controls.has(event.code) && !state?.inspecting && state?.started && !state.paused && !input.suspended && state.phase!=='ended') {
    event.preventDefault();
    if(event.repeat && !pressed.has(event.code))return;
    event.preventDefault();pressed.add(event.code);updateInput();
  }
  if(event.code==='Escape' && !event.repeat && (state?.started || state?.inspecting) && (state?.inspecting || state.phase!=='ended')) {
    event.preventDefault();clearInput();
    if(state?.inspecting)command('showroom');else if(state.paused)resumeGame();else requestPause();
  }
});
window.addEventListener('keyup',(event)=>{pressed.delete(event.code);updateInput();});
window.addEventListener('blur',()=>requestPause('창을 벗어나 경기를 멈췄습니다. 계속 플레이를 눌러 이어가세요.'));
document.addEventListener('visibilitychange',()=>{if(document.hidden)requestPause('다른 탭으로 이동해 경기를 멈췄습니다. 계속 플레이를 눌러 이어가세요.');});
for(const button of document.querySelectorAll('[data-control]')) {
  button.addEventListener('pointerdown',(event)=>{event.preventDefault();if(!state?.started || state.paused || input.suspended || $('info-dialog').open || state.inspecting)return;button.setPointerCapture(event.pointerId);touches.add(button.dataset.control);updateInput();});
  const release=()=>{touches.delete(button.dataset.control);updateInput();};
  button.addEventListener('pointerup',release);button.addEventListener('pointercancel',release);button.addEventListener('lostpointercapture',release);
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
  state=next;
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
  $('drill-slow').disabled=next.inspecting || !next.started || next.mode!=='practice';
  $('drill-slow').setAttribute('aria-pressed',String(Boolean(next.slowPractice)));
  setHudText($('drill-slow'),next.slowPractice?'보통 속도로 연습':'느리게 연습');
  const finishName={shot:'JUMP SHOT',layup:'LAYUP',dunk:'DUNK'}[next.finish] || 'JUMP SHOT';
  setHudText($('touch-shot-label'),next.owner!==0?'블록 / 리바운드':next.finish==='dunk'?'덩크':next.finish==='layup'?'레이업':'슛 / 점프');
  setHudText($('finish-label'),next.reboundWindow?'D · REBOUND':'D · '+finishName);
  $('shot-cue').classList.toggle('active',next.started && !next.paused && next.owner===0 && !next.clear && next.action==='gather');
  $('shot-cue').classList.toggle('sweet',next.sweet);
  $('release-fill').style.width=`${Math.min(100,next.charge*100)}%`;
  setHudText($('release-hint'),next.reboundWindow?'W로 자리 지키기 · 내려오는 공을 D로 캐치':next.sweet?'지금 놓기! SWEET RELEASE':next.held && next.action==='idle'?'드리블 종료 · 방향키 피벗 / D 슛':next.finish==='dunk'?'덩크 거리 · 달리며 D로 바로 마무리':next.finish==='layup'?'레이업 거리 · 달리며 D로 이어서 도약':'초록 구간에서 D 놓기 · 유지하면 자동 슛');
  for(const button of document.querySelectorAll('[data-drill]')){button.disabled=next.inspecting || !next.started || next.mode!=='practice';button.setAttribute('aria-pressed',String(next.drill===button.dataset.drill));}
  setHudText($('score-you'),String(next.score[0]).padStart(2,'0'));
  setHudText($('score-rival'),next.mode==='practice'?'—':String(next.score[1]).padStart(2,'0'));
  setHudText($('clock'),next.mode==='practice'?'∞':next.phase==='ended'?'FINAL':next.seconds===0?(next.score[0]===next.score[1]?'OT':'0:00'):`${Math.floor(next.seconds/60)}:${String(next.seconds%60).padStart(2,'0')}`);
  setHudText($('mode-badge'),next.careerStage?'COURT '+next.careerStage:next.mode==='practice'?'FREE COURT':'1 ON 1');
  setHudText($('shot-clock'),next.mode==='practice'?'나만의 리듬으로':next.phase==='ended'?'경기 종료':`공격 제한 ${Math.max(0,next.shotClock)}초`);
  setHudText($('shot-stat'),`${next.makes} / ${next.attempts}`);
  setHudText($('accuracy'),next.attempts?`${Math.round(next.makes/next.attempts*100)}% FG`:'—');
  const possession=next.phase==='ended'?'FINAL SCORE':next.secured?'SECURED · 공중 캐치 → 보호 → 착지':next.action==='cross'?'CROSS · 속임 → 바운스 → 반대 손':next.action==='rebound'?'REBOUND · 공을 향해 캐치':next.action==='block'?'BLOCK · 손바닥으로 쳐내기':next.boxout?'BOX OUT · W 유지 / D 리바운드':next.guard?'LOW GUARD · 낮은 수비':next.mode==='practice'?'FREE PRACTICE':next.clear?(next.owner===0?'외곽선 밖으로 공 빼기':'RIVAL CLEARING'):next.owner===0?'YOUR BALL · 내 공격':next.owner===1?'DEFENSE · 내 수비':'BALL IN THE AIR';
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
    setHudText($('result-detail'),`내 슛 ${next.makes}/${next.attempts} 성공 · 한 판 더 도전해 보세요.`);
  }
  if(typeof CustomEvent==='function')window.dispatchEvent?.(new CustomEvent('court-state',{detail:next}));
};

window.CourtGame={getState:()=>state,pause:()=>requestPause('선수 화면을 보는 동안 경기를 멈췄습니다.'),startCareer(data){
 if(!ready)return;
 clearInput();input.suspended=false;unlockAudio();input.career=JSON.stringify(data);manuallyChoosing=false;
 selectMode('duel');document.body.classList.add('in-play');
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
$('updates-button').addEventListener('click',()=>showInfo('<span class="eyebrow">COURT NOTES / 2026.10.25</span><h2>동작과 동작 사이를 부드럽게.</h2><p><b>v0.7.4 · 모션 전환 개선</b></p><p>급정지·블록·리바운드로 전환할 때 발과 무릎이 튀는 현상을 수정했습니다. 몸통·어깨 보정의 중복을 줄이고 리바운드 후 가슴에서 드리블로 이어지는 손과 달리는 반대 손의 자세를 다듬었습니다. 같은 경기 안내를 반복해서 다시 쓰지 않도록 화면 갱신도 최적화했습니다.</p><p>득점·덩크·드리블 기술·블록·공중 리바운드에 영어 해설 27개를 연결했습니다. 자체 제작 배경음악 3곡을 선택하거나 순환 재생하고 음악·해설·효과음 음량을 따로 조절할 수 있습니다. 모바일 왼쪽 조이스틱을 위로 올렸습니다.</p><p>모바일은 선수를 크게 보는 추적 카메라로 변경했습니다. 큰 슛 안내판 대신 슛 준비 중에만 버튼 옆 작은 게이지를 표시하고 점수판도 줄였습니다. 한국어·영어·일본어·간체 중국어를 선택하면 경기 안내·계정·육성 메뉴에 적용되며 이 기기에 저장됩니다.</p><p>공통 메뉴의 전자책 버튼에서 로키스튜디오 전자책 안내를 새 탭으로 열 수 있습니다.</p><p>웹 공통 메뉴·전체 화면 메뉴와 연구 화면에 더 좋은 앱을 위한 후원 안내를 추가했습니다. 새 탭에서 계좌를 확인·복사할 수 있습니다.</p><p><b>v0.7.2 · 모바일 카메라·작은 슛 게이지·4개 언어</b></p><ul><li>이메일 없이 아이디·비밀번호로 가입·로그인, 계정 복구 코드와 삭제</li><li>가드178cm·포워드190cm·센터204cm, 실제 체격과 포지션별 운동능력</li><li>AI 1대1 코트8단계, 승리 경험치와 스탯·기술 훈련, 계정별 서버 저장</li><li>달리는 슛 준비: 마지막 스텝에서 감속하며 공 모으기, 디딤→팔·몸통 펴기→릴리즈 연결</li><li>슛·레이업의 실제 발끝 밀기와 도약 발 기준 유지, 공·손의 순간 이동 보정</li><li>발 접촉 뒤 무릎으로 충격을 받고 상체·팔 회수, 착지 회복 중 미끄러운 추가 이동 수정</li><li>이동 방향을 먼저 보는 시선, 공중 리바운드·블록의 올려다보기와 확보 후 고개 회수</li><li>크로스오버의 몸통·어깨 비틀림을 화면 리그에 연결, 반대 손 캐치 뒤 첫 돌파까지 자세 유지</li><li>공을 보낸 팔의 낮은 팔꿈치와 팔뚝을 따르는 손목, 어깨 방향에 맞춘 반대 팔 박자</li><li>스튜디오 크로스오버에 손 전환→방향 전환→다시 달리기 반복 추가</li><li>실제 손 위치에서 크로스오버 진입·복귀, 보내는 팔→달리기 팔의 손목 연결</li><li>레이업: 양손 모으기→보조 손 분리→한 손 올리기→손끝 릴리즈·착지 회수</li><li>리바운드: 실제 양손 캐치→손가락으로 감싸기→가슴으로 당기기, 슛 준비 전환 보간</li><li>드리블 팔: 낮은 팔꿈치로 누르기→짧게 따라 내리기→회수→올라온 공 받기의 반복 연결</li><li>바운드와 같은 박자로 손목을 접고 펴기, 기존 방향 전환 반응 유지</li><li>공 보유 대기: 양옆에서 받쳐 들기 · 슛: 포켓→보조 손 분리→한 팔 릴리즈·손목 팔로스루</li><li>발끝 밀기·뒤꿈치 들기·발 회수로 드리블 달리기 접지감 개선</li><li>일반 방향 전환의 강제 정지·재가속 대기 제거, 급정지와 수비 헛디딤 회복은 분리</li><li>낮은 골반·전방 상체 기울기와 짧은 발 들기, 보이는 다리와 반대 팔의 같은 박자</li><li>공 크기에 맞춘 바닥 접촉과 손 간격, 누르기·자유 낙하·반발·받아 누르기 드리블</li><li>양쪽 경기 캐릭터를 스킨 리그로 전환. 달리기 전신 클립 + 드리블 손·접지 보정</li><li>보이는 손바닥으로 접촉 판정, 반대 팔은 달리기 클립 유지. 컷·헛디딤·추격 연결</li><li>다리 역꺾임·새 접지 순간 이동 수정. 실제 발 출발점→착지점 연결, 중복 이동 제한 제거</li><li>얼굴·쇄골·어깨와 저지/반바지 입체 주름 재제작. 스튜디오에 컷·급정지와 상체 확대 추가</li><li>경기 외형을 사람형 메시로 교체: 얼굴·머리카락·저지·반바지·농구화, 청록 07 / 주황 23. 같은 45본 리그와 손·발 접촉 유지</li><li>별도 모션 실험실: 기존 캐릭터와 스킨 메시·제작된 전신 클립 나란히 비교. 오른쪽은 최종 외형이 아닌 GDQuest 마네킹(CC BY 4.0)</li><li>속은 수비: 헛디딤 접지 → 무릎으로 받기 → 지지 발을 축으로 돌아서기 → 짧은 첫발 → 추격</li><li>돌아서는 동안 즉시 가속·블록 방지, 뒤처지면 공격수를 향한 옆걸음 대신 달려서 추격</li><li>FINISH LAB → 돌파·수비 회복. 좌우+A로 속이고 ↑로 돌파해 확인</li><li>블록의 머리 위 준비 → 몸통·어깨 회전 → 손바닥 내려치기 → 팔 회수 재구성</li><li>돌파에 속은 수비의 회복과 뒤쫓는 블록의 방향·거리·몸 가림 검사</li><li>실제 미스 슛의 림 접점과 높게 튀는 리바운드, 낙하를 기다리는 AI</li><li>시험용 G/F/C 선택 · 센터의 높이·박스아웃, 포워드의 이동 리바운드</li><li>림·박스아웃 경합 연습 추가. 이 연습의 상대 슛은 미스로 고정</li><li>블록: 손바닥 스윙과 같은 방향으로 공을 강하게 쳐내기. 접촉 직후 짧은 궤적 표시</li><li>30~45도 컷도 먼저 접지·하중 처리. 달리기 복귀 후에도 지지 다리 범위 안에서 이동</li><li>몸통과 같은 좌표에서 팔을 돌려 어깨·팔꿈치가 뒤처지는 현상 완화</li><li>FINISH LAB → 디딤·방향 전환. 느린 측면 시점에서 접지와 재출발 확인</li><li>낮은 달리기: 디딤·무릎 압축·뒤꿈치 밀기와 어깨·반대 팔을 같은 발 박자로 연결</li><li>방향 전환: 지지 발로 받기 → 가슴을 새 방향으로 넘기기 → 짧은 첫발 → 커지는 보폭</li><li>낮아진 몸통과 독립적으로 공을 아래로 누르는 손바닥 방향 유지</li><li>크로스오버를 6개 기준 자세로 재구성: 낮은 속임 → 강한 푸시 → 체중 이동 → 반대 손 캐치 → 돌파</li><li>현재 바운스에서 전환, 받는 손 접촉 후 손 교대, 첫 드리블과 달리기로 연결</li><li>크로스오버 연출 연습과 새 동작을 사용하는 확대 미리보기</li><li>달리는 반대 팔: 어깨 회전 → 팔꿈치 굽힘 → 팔뚝을 잇는 손목, 발 박자와 연결</li><li>드리블 손: 팔꿈치는 몸 가까이, 공 상단을 보는 손바닥과 손목·엄지 방향 조정</li><li>움직이는 위팔에 붙는 어깨 형태와 편하게 닿는 드리블 공 위치</li><li>코트러시 · COURT RUSH로 이름 변경</li><li>달리기 상체 회전·골반 반대 회전, 굽힌 팔꿈치와 교대 팔 흔들림</li><li>드리블: 손으로 밀기 → 손 회수 → 튀는 공 받기, 손목과 바운스 소리 박자 통일</li><li>블록 접촉 시 내려치는 팔의 속도를 이어가고, 리바운드는 하강 중 가슴으로 당겨 착지</li><li>블록: 팔을 들어 손바닥으로 내려치기 → 손목 꺾기 → 팔 회수, 실제 접촉 뒤 공을 아래로 쳐냄</li><li>리바운드: 양손으로 공중 캐치 → 머리 위 확보 → 가슴으로 당기기 → 무릎으로 착지</li><li>양손이 공에 모여야 캐치 판정, 느린 리바운드 시점에서 골대 구조물 가림 개선</li><li>S 스틸: 짧게 전진 → 공 쪽 한 손 뻗기 → 접촉 → 공 당기기 또는 손 회수</li><li>손이 공에 닿는 구간에서 스틸 판정, 성공한 공은 손을 따라 드리블로 연결</li><li>스틸 파고들기 연습과 느린 측면 시점 추가</li><li>방향 전환 뒤 첫 밀기 → 반대 발 받기 → 두 번째 밀기 → 커지는 세 번째 보폭</li><li>세 걸음의 접지 진행도에 맞춘 재가속, 현재 지지 발을 따르는 체중 이동</li><li>받아준 발도 앞꿈치를 고정하고 다음 보폭으로 밀어내도록 연결</li><li>달리기 정지·방향 전환: 제동 발 디딤 → 무릎 흡수 → 체중 이동 → 재출발</li><li>발 접촉 뒤 몸통 회전, 지지 발 고정과 앞꿈치 밀어내기</li><li>정지 뒤 서서히 펴지는 무릎과 제동/가속에 맞춘 팔 흔들림</li><li>첫 네 걸음에 걸쳐 보폭과 발 높이를 늘려 달리기로 연결</li><li>실제 발 교대에 맞춘 어깨·반대 팔 흔들림, 드리블하는 손은 유지</li><li>디딤·다리 교대에 맞춘 몸통 높낮이와 서서히 커지는 팔 흔들림</li><li>앞꿈치 고정 → 뒤꿈치 들기 → 지지 무릎 펴기, 바닥을 밀어내는 첫걸음</li><li>첫 두 걸음의 접지 박자에 맞춘 가속과 달리기 연결, 걸음 사이 제동 완화</li><li>착지 후 무릎으로 충격 흡수 → 지지 발로 밀기 → 반대 발 첫걸음 연결</li><li>착지 회복 중 좌우 이동·급반전·정지에도 골반 높이와 속도를 부드럽게 유지</li><li>캐치 순간 손이 공의 속도를 받아낸 뒤 팔꿈치를 접어 공 보호</li><li>실제 블록 접촉 시점에 맞춘 손목·팔꿈치 회수와 아래 방향 쳐내기</li><li>발끝 → 뒤꿈치 → 무릎 압축 → 회복, 양발 착지 시차와 지지 발 고정</li><li>창 전환·안내창에서 안전하게 경기 정지, 직접 계속 플레이로 재개</li><li>슛 준비 중 중단하면 공을 손에 유지, 복귀 뒤 키 반복·터치 잔류 입력 방지</li><li>효과 줄이기를 일시정지 중 연출과 UI에도 적용, 설정 저장 실패 안내</li><li>리바운드: 두 손 캐치 → 가슴으로 당기기 → 착지 후 드리블 연결</li><li>블록: 한 손으로 릴리즈 차단 → 손목으로 쳐내기 → 착지 회복</li><li>손·공 접촉 판정과 짧은 준비 도약, 리바운드·블록 반복 연습 추가</li><li>낮은 수비의 지지 발 고정과 짧은 옆걸음: 열기 → 착지 → 뒤따르는 발 회수</li><li>착지 박자에 맞춘 체중 이동, 급반전과 정지 시 발 끌림 개선</li><li>박스아웃의 등 접촉 방향, 체중 이동과 압박에 따른 버티기 자세 개선</li><li>W 낮은 수비: 상대를 보며 짧은 옆걸음, 낮은 발 들기, 부드러운 자세 전환</li><li>느린 박스아웃 연습에서 가까운 측면 시점 지원</li><li>W 박스아웃: 슛 이후 등으로 진입 차단 · AI 박스아웃·측면 탈출·리바운드 판정 연결</li><li>달리는 레이업의 속도 유지·발뒤꿈치 들기·발끝 밀기·상승 속도 연결 개선</li><li>느린 레이업 연습에서 동작을 가까이 확인</li><li>레이업 도약: 준비 자세 높이 유지 → 지지 다리 펴기 → 반대 무릎 상승</li><li>FINISH LAB에 느리게 연습 추가</li><li>비하인드 백: 미는 손→바운스→받는 손 순서 수정</li><li>레이업의 반대발 도약·무릎 올리기, 덩크의 팔 들어올림→림 누르기 분리</li><li>슛 릴리즈 전후 이동 연속성, 착지 접지 복구</li><li>1대1 수비의 헛디딤·관성·추적 복귀, 정면 접촉의 옆 방향 이동 개선</li><li>양발을 하나의 순서로 제어: 착지 후 반대 발 출발</li><li>Z 턴 · C 투스텝 · V 비하인드 백 · X 헤지테이션 · 터치 버튼 지원</li><li>달리는 골밑 D는 바로 레이업, 더 가까우면 덩크 · 이동을 이어가는 짧은 개더</li><li>캐릭터 어깨 연결, 바지 밑단, 코 형태와 팔 반동 보정</li><li>원근 카메라와 가장자리 추적, 청록색 스트리트 코트</li><li>크로스오버 중 뒷다리 늘어짐 수정 · 팔다리 길이 고정</li><li>캐릭터 확대 화면에 달리기·크로스오버 미리보기 추가</li><li>사진 질감 대신 손으로 그린 눈매·얼굴 명암·옷 주름 적용</li><li>지면에 디딘 발 고정, 무릎 역기구학과 상체 반동, 팔 동작 연결 개선</li><li>15×14m 반코트, 선수·공·림 크기와 코트 선 비율 수정</li><li>연속된 의상 실루엣, 각진 턱과 광대, 차분한 스트리트 의상과 얇은 윤곽선</li><li>캐릭터 가까이 보기: 실제 게임 모델 두 명을 확대해서 확인</li><li>손 전환 드리블, 슛 준비→도약→릴리즈→착지, 릴리즈 타이밍 보너스</li><li>골밑 레이업·진입 속도에 따른 덩크, 블록과 리바운드 연동</li><li>FINISH LAB에서 레이업·덩크 위치를 바로 연습</li><li>두 손으로 잡으면 드리블 종료: 피벗·슛만 가능, 재드리블 방지</li><li>자유 연습과 AI 1대1 · 90초 또는 11점 승부</li><li>드리블, 크로스오버, 슛 페이크, 슛, 블록, 스틸, 리바운드</li><li>키보드·터치 조작, 일시정지, 소리·효과 설정</li></ul><p>현재 도전은 AI 1대1 PvE입니다. 내 선수와 코트 도전 기록은 계정에 저장하고 자유 연습·일반1대1에는 성장 보상이 없습니다. 온라인 대전·3대3은 후속 항목이며 서버가 모든 경기 입력을 검증하는 경쟁전으로 제공하지 않습니다. <a href="privacy.html" target="_blank" rel="noopener">계정·저장 안내 ↗</a></p><p>Made with <a href="https://godotengine.org/license/" target="_blank" rel="noopener noreferrer">Godot Engine · MIT License ↗</a>. 코트·공·효과음은 이 프로젝트의 원본 제작물입니다. 경기의 리그와 기본 애니메이션은 <a href="https://github.com/gdquest-demos/godot-3d-mannequin" target="_blank" rel="noopener noreferrer">GDQuest and contributors</a> / Luciano Muñoz, CC BY 4.0입니다. 얼굴 텍스처는 내장 imagegen으로 생성·편집하고 사람형 외형·농구복은 자체 제작했으며 원본 리그에 스킨 바인딩했습니다. 클립 재생·접촉 보정을 적용했습니다.</p>'));
$('help-button').addEventListener('click',()=>showInfo('<span class="eyebrow">GET INTO YOUR RHYTHM</span><h2>먼저, 공과 친해지기.</h2><ul><li><b>방향키</b> 화면 기준으로 이동합니다.</li><li><b>D 유지</b> 슛 준비 후 자동으로 던집니다. 0.18초보다 짧게 톡 누르면 슛 페이크입니다. 0.36~0.50초의 초록 구간에서 놓으면 성공 확률 보너스가 있습니다. 수비와 거리에 따라 실패할 수 있습니다.</li><li><b>공을 두 손으로 잡은 뒤</b> 드리블이 끝납니다. 방향키는 제자리 피벗, D는 슛입니다. 이동과 A·Z·C·V·X 기술로 다시 드리블할 수 없습니다.</li><li><b>골밑 D</b> 달리며 진입하면 3m 이내에서 레이업, 1.85m 이내에서는 덩크가 나갑니다. 골대 바로 앞 1.05m 이내에서는 제자리 덩크도 가능합니다. 달리는 중 D를 누르면 공을 모아 바로 도약하며, 멈춰서 D를 짧게 누르면 페이크입니다. 화면의 D · DUNK 표시를 확인하세요. 골대 뒤에서는 일반 슛입니다.</li><li><b>A</b> 공을 반대 손으로 넘기며 크로스오버. 방향키와 조합해 수비를 벗어나세요.</li><li><b>Z</b> 바깥손 드리블을 유지하며 몸을 한 바퀴 돌려 돌파합니다.</li><li><b>C</b> 바깥쪽 → 안쪽 두 번의 방향 전환으로 돌파합니다. 공을 잡고 걷는 동작이 아니라 드리블 중 투스텝입니다. 기술이 끝나면 A·Z·C를 다시 눌러 연결하세요.</li><li><b>V</b> 비하인드 백: 공을 등 뒤로 넘겨 반대 손으로 돌파합니다.</li><li><b>X</b> 헤지테이션: 잠깐 속도를 늦췄다가 다시 치고 나갑니다.</li><li><b>수비 중 D</b> 블록 또는 리바운드 점프. 떨어진 낮은 공은 가까이 가면 잡습니다.</li><li><b>S</b> 짧게 전진하며 공 쪽 손을 뻗어 스틸합니다. 상대를 바라보고 공이 있는 쪽에 접근하세요. 실제 손이 공에 닿는 구간에서 판정하며 성공은 보장되지 않습니다. 성공하면 공을 당긴 뒤 드리블로 이어가고, 실패하면 손을 회수합니다. FINISH LAB의 스틸 파고들기에서 반복 연습할 수 있습니다.</li><li><b>W 유지</b> 공이 없을 때 무릎을 낮추고 상대를 보며 짧게 옆걸음합니다. 놓으면 보통 자세로 돌아갑니다. 슛이 올라간 뒤 상대보다 림 쪽에서 W를 유지하면 등을 대고 박스아웃합니다. 방향키로 위치를 지키고 D로 뛰어 리바운드하세요. 상대가 옆으로 빠지면 박스아웃이 풀립니다.</li><li>1대1은 11점 선취 또는 90초. 동점이면 다음 득점으로 승부합니다. 수비 리바운드·스틸 뒤에는 외곽선 밖으로 공을 빼야 합니다.</li><li><b>Esc</b> 일시정지. 다른 창·탭으로 이동하거나 안내창을 열면 멈춥니다. 안내창을 닫아도 자동 재개되지 않으며, 계속 플레이를 눌러 이어갑니다. 중단한 제자리 슛 준비는 공을 손에 둔 채 취소됩니다.</li></ul><p>휴대폰은 가로 화면을 권장합니다. 터치 스틱과 오른쪽 버튼으로 같은 동작을 사용할 수 있습니다.</p>'));
$('close-dialog').addEventListener('click',()=>$('info-dialog').close());
$('compact-updates').addEventListener('click',()=>{if(document.fullscreenElement)document.exitFullscreen().then(()=>$('updates-button').click());else $('updates-button').click();});
$('info-dialog').addEventListener('close',()=>{clearInput();if(state?.started && input.suspended && !manuallyChoosing)$('resume-button').focus({preventScroll:true});else if(state?.started)canvas.focus({preventScroll:true});});

async function boot() {
  try {
    if(!window.Engine || !window.UF_ENGINE_CONFIG)throw new Error('게임 파일을 읽지 못했습니다. 로컬 서버 주소로 열어 주세요.');
    const missing=Engine.getMissingFeatures({threads:false});
    if(missing.length)throw new Error('이 브라우저에서 필요한 기능을 사용할 수 없습니다: '+missing.join(', '));
    const resizeCanvas=()=>{const rect=$('arena').getBoundingClientRect();const ratio=Math.min(devicePixelRatio||1,1.5);canvas.width=Math.round(rect.width*ratio);canvas.height=Math.round(rect.height*ratio);};
    resizeCanvas();
    const observer=new ResizeObserver(resizeCanvas);observer.observe($('arena'));
    const engine=new Engine({...window.UF_ENGINE_CONFIG,canvas,canvasResizePolicy:0,focusCanvas:false});
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

