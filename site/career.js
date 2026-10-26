import {ROLES,STAT_NAMES,SKILLS,STAGES,attributes,xpNeeded,WARDROBE_CATALOG as CATALOG,wardrobeOf} from './career-rules.js';
const $=id=>document.getElementById(id),config=window.COURT_CAREER_CONFIG;
const dialog=$('career-dialog'),content=$('career-content'),status=$('career-status');
const sessionKey='court-rush.session.v1',resultKey='court-rush.result.v1';
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let session=null,player=null,username='',persistent=false,busy=false,refreshing=null,pending=null,claiming=false,startRequest=null;
let shopping=false,shopSlot='jersey',selectedItem='court_teal',tryOn={...CATALOG.defaults},shopYaw=0,previewReady=false,shopCollection='all',shopOwned='all',shopForm='all';
const slots={jersey:'상의',shorts:'하의',shoes:'농구화',hat:'모자',hair:'헤어'};
const forms={jersey:{jersey:'농구 저지',tee:'반팔 티셔츠',hoodie:'후드티',varsity:'바시티 재킷'},shorts:{shorts:'농구 반바지',joggers:'조거 팬츠',cargo:'카고 팬츠'},shoes:{hightop:'하이탑'},hat:{none:'모자 없음',cap:'캡',cap_back:'뒤로 쓴 캡',beanie:'비니',bucket:'버킷햇'},hair:{original:'스윕 헤어',buzz:'버즈컷',curly:'컬리',locs:'드레드',sidepart:'사이드파트',ponytail:'포니테일'}};
function previewShop(){previewReady=Boolean(window.CourtGame?.wardrobe({appearance:tryOn,athlete:player?attributes(player):{},yaw:shopYaw}));}
function leaveShop(){if(!shopping)return;shopping=false;document.body.classList.remove('wardrobe-open');dialog.classList.remove('wardrobe-dialog');window.CourtGame?.closeWardrobe();window.CourtGame?.setAppearance(player?wardrobeOf(player).equipped:{});}
function openShop(){
 window.CourtGame?.pause();shopping=true;shopCollection='all';shopOwned='all';shopForm='all';tryOn={...(player?wardrobeOf(player).equipped:CATALOG.defaults)};shopYaw=0;selectedItem=tryOn[shopSlot];
 document.body.classList.add('wardrobe-open');dialog.classList.add('wardrobe-dialog');if(!dialog.open)dialog.showModal();renderShop();previewShop();
}
function shopItems(){
 const owned=player?wardrobeOf(player).owned:Object.values(CATALOG.defaults);
 return CATALOG.items.filter(i=>i.slot===shopSlot&&(shopForm==='all'||i.form===shopForm)&&(shopCollection==='all'||i.collection===shopCollection)&&(shopOwned==='all'||(shopOwned==='owned')===owned.includes(i.id))).sort((a,b)=>{const order=['hoodie','tee','varsity','joggers','cargo'];return (order.includes(a.form)?order.indexOf(a.form):99)-(order.includes(b.form)?order.indexOf(b.form):99);});
}
function filterShop(){const items=shopItems();if(items.length){selectedItem=items[0].id;tryOn[shopSlot]=selectedItem;}renderShop();previewShop();}
function renderShop(){
 const w=player?wardrobeOf(player):null,item=CATALOG.items.find(i=>i.id===selectedItem),owned=w?.owned.includes(item.id),equipped=w?.equipped[item.slot]===item.id;
 const locked=!owned&&(player?.cleared||0)<(item.unlock||0),items=shopItems();
 const collectionItems=CATALOG.items.filter(i=>shopCollection==='all'||i.collection===shopCollection),collected=collectionItems.filter(i=>(w?.owned||Object.values(CATALOG.defaults)).includes(i.id)).length;
 const tiers=['','코트 기본','스트리트','시그니처','챔피언'];
 frame(`<span class="eyebrow">COURT STORE / ${CATALOG.items.length} ITEMS / ${CATALOG.collections.length} COLLECTIONS</span>
 <div class="shop-heading"><h2>코트 위의 내 스타일.</h2><strong class="coin-wallet">◉ <span translate="no">${w?w.coins:'—'}</span> <span>코트 코인</span></strong></div>
 <p class="shop-intro">의상은 능력치를 바꾸지 않습니다. 코트 코인으로 구매하고, 부위별로 자유롭게 조합하세요.</p>
 <div class="shop-preview-controls"><button id="shop-turn-left" aria-label="캐릭터 왼쪽 회전">↶</button><span>실제 캐릭터 미리보기</span><button id="shop-turn-right" aria-label="캐릭터 오른쪽 회전">↷</button><button id="shop-restore">장착 의상으로</button></div>
 <div class="shop-filters"><label>컬렉션<select id="shop-collection" aria-label="컬렉션"><option value="all">전체 컬렉션</option><option value="original">코트 오리지널</option>${CATALOG.collections.map(c=>`<option value="${c.id}">${c.name}</option>`).join('')}</select></label><label>보유 상태<select id="shop-owned" aria-label="보유 상태"><option value="all">모든 의상</option><option value="owned">보유한 의상</option><option value="missing">아직 없는 의상</option></select></label><label>형태<select id="shop-form" aria-label="형태"><option value="all">모든 형태</option>${Object.entries(forms[shopSlot]).map(([key,label])=>`<option value="${key}">${label}</option>`).join('')}</select></label><div class="collection-progress"><span>수집 현황</span><b translate="no">${collected} / ${collectionItems.length}</b><progress max="${collectionItems.length}" value="${collected}"></progress></div></div>
 <nav class="career-tabs shop-tabs" aria-label="의상 분류">${Object.entries(slots).map(([key,label])=>`<button data-slot="${key}" aria-pressed="${shopSlot===key}">${label}</button>`).join('')}</nav>
 <div class="shop-grid">${items.map(i=>`<button class="shop-item tier-${i.tier}" data-item="${i.id}" aria-pressed="${selectedItem===i.id}" style="--garment:#${i.base};--panel:#${i.panel};--trim:#${i.accent}" aria-label="${i.name}"><span class="item-tier">${tiers[i.tier]}</span><span class="garment-thumb ${i.slot} form-${i.form} pattern-${i.pattern}" aria-hidden="true"><i></i></span><b>${i.name}</b><span>${w?.equipped[i.slot]===i.id?'장착 중':w?.owned.includes(i.id)?'보유 중':i.price===0?'기본 지급':`◉ ${i.price}`}</span>${(i.unlock||0)>(player?.cleared||0)?`<small class="shop-lock">${i.unlock}코트 클리어 후 구매</small>`:''}</button>`).join('')||'<p class="shop-empty">이 조건에 맞는 의상이 없습니다.</p>'}</div>
 ${items.length?`<section class="shop-selection"><div><b>${item.name}</b><small>미리 입어 보는 중 · 구매 전에도 확인할 수 있어요.</small>${item.variant?'<button id="shop-outfit">컬렉션 한 벌 입어보기</button>':''}</div><button id="shop-action" class="primary" ${equipped||(player&&locked)?'disabled':''}>${!player?'로그인하고 선수 만들기':equipped?'장착 중':owned?(item.id==='hat_none'?'모자 벗기':'장착하기'):locked?item.unlock+'코트 클리어 후 구매':`구매하기 · ${item.price} 코인`}</button></section>`:''}
 <p class="career-fine">첫 선수에게 300 코인 지급. 육성 1대1 첫 클리어 120~260 코인, 재도전 승리 45~80 코인, 패배 20 코인. 연습·일반 경기·3대3은 보상이 없습니다.</p><p class="career-fine">잠긴 컬렉션도 미리 입어볼 수 있습니다. 모든 의상은 정해진 가격으로 구매하며, 무작위 뽑기나 유료 결제는 없습니다.</p><button id="shop-player">${player?'선수 육성으로':'로그인 · 내 선수'}</button>${player?'<button id="shop-refresh">기록 새로고침</button>':''}`);
 $('shop-collection').value=shopCollection;$('shop-owned').value=shopOwned;$('shop-form').value=shopForm;
 $('shop-collection').onchange=e=>{if(busy)return;shopCollection=e.target.value;filterShop();};
 $('shop-form').onchange=e=>{if(busy)return;shopForm=e.target.value;filterShop();};
 $('shop-owned').onchange=e=>{if(busy)return;shopOwned=e.target.value;filterShop();};
 content.querySelectorAll('[data-slot]').forEach(b=>b.onclick=()=>{if(busy)return;shopSlot=b.dataset.slot;shopForm='all';if(!CATALOG.items.some(i=>i.slot===shopSlot&&(shopCollection==='all'||i.collection===shopCollection)))shopCollection='all';const list=shopItems();selectedItem=list.find(i=>i.id===tryOn[shopSlot])?.id||list[0]?.id||tryOn[shopSlot];if(list.length)tryOn[shopSlot]=selectedItem;renderShop();previewShop();content.querySelector(`[data-slot="${shopSlot}"]`).focus({preventScroll:true});});
 content.querySelectorAll('[data-item]').forEach(b=>b.onclick=()=>{if(busy)return;selectedItem=b.dataset.item;tryOn[shopSlot]=selectedItem;renderShop();previewShop();content.querySelector(`[data-item="${selectedItem}"]`).focus({preventScroll:true});});
 $('shop-turn-left').onclick=()=>{shopYaw-=Math.PI/4;previewShop();};$('shop-turn-right').onclick=()=>{shopYaw+=Math.PI/4;previewShop();};
 $('shop-restore').onclick=()=>{tryOn={...(player?wardrobeOf(player).equipped:CATALOG.defaults)};selectedItem=tryOn[shopSlot];shopCollection='all';shopOwned='all';shopForm='all';renderShop();previewShop();};
 if($('shop-outfit'))$('shop-outfit').onclick=()=>{for(const piece of CATALOG.items.filter(i=>i.collection===item.collection&&i.variant===item.variant))tryOn[piece.slot]=piece.id;previewShop();notice('한 벌을 미리 입었습니다. 구매와 장착은 부위별로 선택하세요.');};
 $('shop-player').onclick=()=>{if(!busy){leaveShop();open();}};
 if($('shop-refresh'))$('shop-refresh').onclick=()=>run(async()=>{player=(await api('profile')).player;panel();renderShop();notice('서버의 의상 기록을 불러왔습니다.');});
 if($('shop-action'))$('shop-action').onclick=()=>{if(!player){leaveShop();open();return;}run(async()=>{
  notice('의상 기록을 저장하고 있습니다…');
  try{const r=await api(owned?'equip':'buy',{itemId:item.id});player=r.player;panel();renderShop();notice(owned?'장착했습니다. 경기에도 적용됩니다.':'구매했습니다. 장착하기를 누르면 경기에도 적용됩니다.');}
  catch(e){if(e.status===409){player=(await api('profile')).player;panel();renderShop();}throw e;}
 });};
}
function notice(message,error=false){const el=$('career-message');if(el){el.textContent=message;el.classList.toggle('error',error);}}
function storageSave(){try{localStorage.removeItem(sessionKey);sessionStorage.removeItem(sessionKey);if(session)(persistent?localStorage:sessionStorage).setItem(sessionKey,JSON.stringify({session,username}));}catch{status.textContent='로그인은 이 창에서 유지됩니다. 브라우저 저장을 사용할 수 없습니다.';}}
function saveResult(){try{if(pending?.score)sessionStorage.setItem(resultKey,JSON.stringify(pending));else sessionStorage.removeItem(resultKey);}catch{}}
async function raw(action,body={},token=null){
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),20000);
 try{const response=await fetch(config.url+'/functions/v1/court-rush',{method:'POST',headers:{'Content-Type':'application/json','apikey':config.key,...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify({action,...body}),signal:controller.signal});
 let result;try{result=await response.json();}catch{throw Error('서버 응답을 읽지 못했습니다. 다시 시도하세요.');}
 if(!response.ok)throw Object.assign(Error(result.error||'서버 요청을 완료하지 못했습니다.'),{status:response.status});return result;
 }catch(e){if(e.name==='AbortError')throw Error('연결이 지연됩니다. 입력을 유지했으니 다시 시도하세요.');throw e;}finally{clearTimeout(timer);}
}
async function refresh(){
 if(!session)throw Error('먼저 로그인하세요.');
 if(!refreshing)refreshing=raw('refresh',{refreshToken:session.refresh_token}).then(r=>{session=r.session;storageSave();}).finally(()=>refreshing=null);
 await refreshing;
}
async function api(action,body={}){
 if(!session)throw Error('먼저 로그인하세요.');
 if(session.expires_at<Date.now()/1000+60)await refresh();
 try{return await raw(action,body,session.access_token);}catch(e){if(e.status!==401)throw e;await refresh();return raw(action,body,session.access_token);}
}
function panel(){
 window.CourtGame?.setAppearance(player?wardrobeOf(player).equipped:{});
 status.textContent=player?`${player.nickname} · ${ROLES[player.role].name} · Lv.${player.level} / ${player.cleared}코트 클리어`:session?`${username} · 첫 선수를 만들어 주세요`:'아이디로 시작하는 나만의 선수';
 $('career-open').textContent=player?'선수 육성 · 코트 도전 →':session?'첫 선수 만들기 →':'내 선수 키우기 →';
}
function open(view='login'){
 leaveShop();
 window.CourtGame?.pause();
 if(!dialog.open)dialog.showModal();
 if(session){if(player)renderPlayer();else renderCreation();}else renderAuth(view);
}
function frame(body){content.innerHTML=body+'<p id="career-message" role="status" aria-live="polite"></p>';}
function renderAuth(view='login'){
 const signup=view==='signup',recover=view==='recover';
 frame(`<span class="eyebrow">COURT RUSH / MY PLAYER</span><h2>${signup?'내 코트의 시작.':recover?'다시, 코트로.':'돌아온 걸 환영해요.'}</h2><p>이메일 없이 아이디와 비밀번호로 시작하세요. 선수와 성장 기록은 계정에 저장됩니다.</p><nav class="career-tabs"><button data-auth="login" aria-pressed="${view==='login'}">로그인</button><button data-auth="signup" aria-pressed="${signup}">회원가입</button><button data-auth="recover" aria-pressed="${recover}">계정 복구</button></nav><form id="career-auth"><label>아이디<input name="username" autocomplete="username" required minlength="4" maxlength="20" pattern="[A-Za-z0-9_]{4,20}" placeholder="영문·숫자·밑줄 4~20자"></label>${recover?'<label>가입 때 받은 복구 코드<input name="recoveryCode" required autocomplete="off" maxlength="48" placeholder="32자리 복구 코드"></label>':''}<label>${recover?'새 비밀번호':'비밀번호'}<input name="password" type="password" required minlength="12" maxlength="72" autocomplete="${signup||recover?'new-password':'current-password'}" placeholder="12자 이상"></label>${signup?'<label>비밀번호 확인<input name="confirm" type="password" required minlength="12" maxlength="72" autocomplete="new-password"></label>':''}${!recover?'<label class="career-check"><input name="remember" type="checkbox"> 이 기기에서 로그인 유지</label>':''}<button class="primary" type="submit">${signup?'가입하고 선수 만들기 →':recover?'비밀번호 재설정':'로그인 →'}</button><p class="career-fine">${signup?'가입 시 복구 코드를 한 번 제공합니다. 이메일을 수집하지 않아 이 코드가 없으면 비밀번호를 찾을 수 없습니다. ':''}<a href="privacy.html" target="_blank" rel="noopener">계정·저장 안내 ↗</a></p></form>`);
 content.querySelectorAll('[data-auth]').forEach(b=>b.onclick=()=>{if(!busy)renderAuth(b.dataset.auth);});
 $('career-auth').onsubmit=e=>{e.preventDefault();run(async()=>{
  const f=new FormData(e.target),pass=f.get('password');
  if(signup&&pass!==f.get('confirm'))throw Error('비밀번호 확인이 일치하지 않습니다.');
  const r=await raw(view,{username:f.get('username'),password:pass,...(recover?{recoveryCode:f.get('recoveryCode')}:{})});
  if(recover){renderCode(r.recoveryCode,()=>renderAuth('login'),'새 비밀번호로 로그인하세요. 이전 복구 코드는 만료됐습니다.');return;}
  session=r.session;username=r.username;player=r.player;persistent=f.get('remember')==='on';storageSave();panel();
  if(signup)renderCode(r.recoveryCode,renderCreation);else player?renderPlayer():renderCreation();
 });};
}
function renderCode(code,next,description='이 코드는 한 번만 표시됩니다. 안전한 곳에 보관하세요.'){
 frame(`<span class="eyebrow">KEEP YOUR RECOVERY CODE</span><h2>계정을 되찾을 열쇠.</h2><p>${description}</p><code class="recovery-code" translate="no">${escape(code.match(/.{1,4}/g).join('-'))}</code><p>이메일 인증은 없습니다. 비밀번호를 잊으면 아이디와 이 코드가 필요합니다. 비밀번호와 함께 안전한 곳에 따로 보관하세요.</p><button id="code-next" class="primary">복구 코드를 보관했어요 →</button>`);$('code-next').onclick=next;
}
function renderCreation(){
 frame(`<span class="eyebrow">ONE PLAYER. YOUR WAY.</span><h2>어떤 선수로 뛸까요?</h2><p>포지션은 선수의 기본 체격과 강점을 결정합니다. 만든 뒤에는 바꿀 수 없습니다.</p><form id="career-create"><label>선수 이름<input name="nickname" required minlength="2" maxlength="12" placeholder="2~12자"></label><div class="role-choices">${Object.entries(ROLES).map(([k,r],i)=>`<label class="role-choice"><input type="radio" name="role" value="${k}" ${i===0?'checked':''}><b>${r.name}</b><strong>${r.height}<small>cm</small></strong><span>${r.weight}kg · ${r.tag}</span><span>${Object.entries(r.base).map(([s,n])=>`${STAT_NAMES[s]} ${n}`).join(' / ')}</span></label>`).join('')}</div><button class="primary">이 선수로 시작하기 →</button></form>`);
 const manage=document.createElement('button');manage.textContent='계정 관리 · 로그아웃';manage.onclick=renderAccount;content.append(manage);
 $('career-create').onsubmit=e=>{e.preventDefault();run(async()=>{const f=new FormData(e.target);const r=await api('create',{role:f.get('role'),nickname:f.get('nickname')});player=r.player;panel();renderPlayer();});};
}
function renderPlayer(){
 const r=ROLES[player.role],a=attributes(player);
 frame(`<div class="career-heading"><div><span class="eyebrow">${escape(username)} / MY PLAYER</span><h2 translate="no">${escape(player.nickname)}</h2><p>${r.name} · ${r.height}cm / ${r.weight}kg · Lv.${player.level}</p></div><button id="career-account">계정 관리</button></div><div class="career-xp"><span>다음 레벨 ${player.xp} / ${xpNeeded(player.level)} XP</span><progress max="${xpNeeded(player.level)}" value="${player.xp}"></progress></div><div class="growth-columns"><section><h3>스탯 훈련 <small>${player.statPoints}P</small></h3>${Object.keys(STAT_NAMES).map(k=>`<div class="train-row"><span>${STAT_NAMES[k]}</span><strong>${a[k]} <small>+${player.stats[k]}</small></strong><button data-train="stat" data-key="${k}" ${player.statPoints<1||player.stats[k]>=20?'disabled':''} aria-label="${STAT_NAMES[k]} 훈련 1포인트">+1</button></div>`).join('')}</section><section><h3>기술 훈련 <small>${player.skillPoints}P</small></h3>${Object.entries(SKILLS).map(([k,s])=>`<div class="train-row"><span>${s.name}<small>${s.description}</small></span><strong>${player.skills[k]} / 5</strong><button data-train="skill" data-key="${k}" ${player.skillPoints<1||player.skills[k]>=5?'disabled':''} aria-label="${s.name} 기술 훈련 1포인트">+1</button></div>`).join('')}</section></div><h3>1대1 코트 도전</h3><p>11점 또는 90초 승부. 처음 깨는 코트는 더 많은 경험치를 줍니다. 연습·일반 1대1에는 성장 보상이 없습니다.</p><div class="career-stages">${STAGES.map((s,i)=>`<button data-stage="${i+1}" ${i>player.cleared?'disabled':''}><small>COURT ${String(i+1).padStart(2,'0')} · ${ROLES[s.role].name} Lv.${s.level}</small><b>${s.name}</b><span>${i<player.cleared?'✓ 클리어 · 다시 도전':i===player.cleared?'도전하기 →':'이전 코트부터 클리어'} / ${s.xp} XP</span></button>`).join('')}</div><p class="career-fine">내 선수는 서버에 자동 저장됩니다. 다른 기기에서도 같은 아이디로 이어갈 수 있습니다.</p>`);
 content.querySelectorAll('[data-train]').forEach(b=>b.onclick=()=>run(async()=>{const r=await api('train',{kind:b.dataset.train,key:b.dataset.key});player=r.player;panel();renderPlayer();notice('훈련을 저장했습니다. 다음 도전부터 적용됩니다.');}));
 content.querySelectorAll('[data-stage]').forEach(b=>b.onclick=()=>confirmStart(Number(b.dataset.stage)));
 $('career-account').onclick=renderAccount;
 const team=document.createElement('section');team.className='career-team';
 team.innerHTML='<h3>내 선수로 AI 3대3</h3><p>AI 동료 2명과 함께 11점 또는 3분. 완주 경험치·승리 보너스와 직접 조작한 득점·어시스트·리바운드·블록·스틸 기여 보상을 받습니다.</p><p>내 선수를 포함한 아군의 직접 조작 기록을 합산합니다. 중도 종료·참여 부족·일반 팀전에는 성장 보상이 없으며, 1대1 코트 해금은 별도입니다.</p><button id="career-team-start" class="primary">성장 팀전 시작 →</button>';
 content.querySelector('.growth-columns').after(team);$('career-team-start').onclick=()=>confirmStart('team');
 const shop=document.createElement('button');shop.id='career-shop';shop.className='primary';shop.textContent='의상 상점 · '+wardrobeOf(player).coins+' 코인';shop.onclick=openShop;content.querySelector('.career-heading').after(shop);
}
function confirmStart(stage){
 if(pending?.score){notice('저장 대기 중인 경기 보상을 먼저 받아 주세요.',true);claim();return;}
 const s=window.CourtGame?.getState();
 if(s?.started&&s.phase!=='ended'){
  frame(`<h2>새 코트로 들어갈까요?</h2><p>현재 경기는 종료되며 진행 중인 경기의 보상은 받을 수 없습니다.</p><button id="career-start-confirm" class="primary">${stage==='team'?'성장 팀전 시작 →':escape(STAGES[stage-1].name)+' 도전 시작'}</button><button id="career-start-cancel">돌아가기</button>`);
  $('career-start-confirm').onclick=()=>startStage(stage);$('career-start-cancel').onclick=renderPlayer;
 }else startStage(stage);
}
function startStage(stage){run(async()=>{
 if(!window.CourtGame?.getState()?.ready)throw Error('코트가 준비되는 동안 잠시 기다려 주세요.');
 if(!startRequest||startRequest.stage!==stage)startRequest={stage,id:crypto.randomUUID()};
 const data=await api('start',{...(stage==='team'?{mode:'team'}:{stage}),requestId:startRequest.id});startRequest=null;
 pending={matchId:data.matchId,stage,mode:stage==='team'?'team':'duel',username};saveResult();dialog.close();window.CourtGame.startCareer(data);
 });}
function renderAccount(){
 frame(`<span class="eyebrow">ACCOUNT / ${escape(username)}</span><h2>계정 관리</h2><p>이메일은 수집하지 않습니다. 비밀번호를 잊으면 가입 때 받은 복구 코드로 복구할 수 있습니다.</p><form id="account-form"><label>현재 비밀번호<input name="password" type="password" required autocomplete="current-password" minlength="12" maxlength="72"></label><div class="career-account-actions"><button name="operation" value="recovery">복구 코드 새로 받기</button><button name="operation" value="delete" class="danger">계정 영구 삭제</button></div><p>영구 삭제하면 선수와 모든 성장·경기 기록을 되돌릴 수 없습니다.</p></form><button id="career-back">선수로 돌아가기</button><button id="career-logout">로그아웃</button>`);
 $('career-back').onclick=()=>player?renderPlayer():renderCreation();
 $('career-logout').onclick=()=>run(async()=>{await api('logout');session=null;player=null;username='';persistent=false;storageSave();panel();renderAuth();});
 $('account-form').onsubmit=e=>{e.preventDefault();const pass=new FormData(e.target).get('password');if(e.submitter.value==='delete'){
  frame('<h2>계정을 영구 삭제할까요?</h2><p>선수, 훈련과 코트 기록을 모두 삭제합니다. 복구할 수 없습니다.</p><button id="delete-confirm" class="danger">모든 계정 기록 영구 삭제</button><button id="delete-cancel">취소</button>');
  $('delete-cancel').onclick=renderAccount;$('delete-confirm').onclick=()=>run(async()=>{await api('delete',{password:pass});session=null;player=null;username='';pending=null;saveResult();storageSave();panel();renderAuth();notice('계정과 성장 기록을 삭제했습니다.');});
 }else run(async()=>{const r=await api('recovery',{password:pass});renderCode(r.recoveryCode,()=>player?renderPlayer():renderCreation());});};
}
async function run(fn){if(busy)return;busy=true;content.setAttribute('aria-busy','true');const controls=[...content.querySelectorAll('button,select')].map(el=>[el,el.disabled]);for(const [el] of controls)el.disabled=true;try{await fn();}catch(e){notice(e.message,true);}finally{busy=false;for(const [el,disabled] of controls)if(content.contains(el))el.disabled=disabled;content.removeAttribute('aria-busy');}}
async function claim(){
 if(!pending?.score||claiming||!session||pending.username!==username)return;claiming=true;
 $('career-reward').textContent='경기 보상을 저장하고 있습니다…';
 try{const r=await api('finish',{matchId:pending.matchId,score:pending.score,seconds:pending.seconds,...(pending.mode==='team'?{stats:pending.stats}:{})});player=r.player;pending=null;saveResult();panel();if(shopping)renderShop();$('career-reward').textContent=`${r.reward.won?'승리!':'다음 코트에서 다시!'} +${r.reward.xp} XP · Lv.${player.level} · 스탯 ${player.statPoints}P / 기술 ${player.skillPoints}P${r.reward.coins?' · +'+r.reward.coins+' 코인':''}`;if(r.reward.mode==='team'){showTeamSummary(r.reward.stats,r.reward.eligible);}$('career-retry').hidden=true;}
 catch(e){$('career-reward').textContent='보상 저장 대기 · '+e.message;$('career-retry').hidden=false;}
 finally{claiming=false;}
}
function showTeamSummary(stats,eligible=true){
 const target=$('career-team-summary');if(!target||!stats)return;
 target.hidden=false;target.replaceChildren();
 for(const [key,label] of Object.entries({points:'득점',assists:'어시스트',rebounds:'리바운드',blocks:'블록',steals:'스틸'})){
  if(target.childNodes.length)target.append(document.createTextNode(' · '));
  const span=document.createElement('span');span.textContent=label+' ';const value=document.createElement('b');value.textContent=String(stats[key]||0);value.translate=false;span.append(value);target.append(span);
 }
 if(!eligible){const p=document.createElement('span');p.textContent='직접 조작 시간이 부족해 이번 경기는 성장 보상이 없습니다.';target.append(p);}
}
window.addEventListener('court-state',e=>{const s=e.detail;if(pending&&s.careerMatchId===pending.matchId&&s.phase==='ended'&&!pending.score){pending={...pending,score:s.score,seconds:s.seconds,...(pending.mode==='team'?{stats:s.careerStats}:{})};saveResult();if(pending.mode==='team')showTeamSummary(s.careerStats);claim();}});
$('result-rematch').addEventListener('click',e=>{const s=window.CourtGame?.getState();if(s?.careerMode==='team'&&s.careerMatchId){e.stopImmediatePropagation();if(session&&player)confirmStart('team');else open();}},true);
$('team-career-open').onclick=()=>open();
$('career-open').onclick=()=>open();$('career-menu').onclick=()=>open();$('entry-career').onclick=()=>open();$('career-result-open').onclick=()=>open();$('career-retry').onclick=claim;
$('wardrobe-menu').onclick=openShop;$('wardrobe-open').onclick=openShop;dialog.addEventListener('close',leaveShop);
window.addEventListener('court-state',()=>{if(shopping&&!previewReady)previewShop();});
$('career-close').onclick=()=>{if(!busy)dialog.close();};dialog.addEventListener('cancel',e=>{if(busy)e.preventDefault();});
panel();
try{const remembered=localStorage.getItem(sessionKey),saved=remembered||sessionStorage.getItem(sessionKey);if(saved){const parsed=JSON.parse(saved);if(typeof parsed.session?.access_token==='string'&&typeof parsed.session?.refresh_token==='string'&&Number.isFinite(parsed.session.expires_at)){session=parsed.session;username=parsed.username||'';persistent=Boolean(remembered);}}
 const result=JSON.parse(sessionStorage.getItem(resultKey)||'null');if(result&&typeof result.matchId==='string'&&Array.isArray(result.score))pending=result;
}catch{status.textContent='저장된 로그인 정보를 읽지 못했습니다. 다시 로그인하세요.';}
if(session)api('profile').then(r=>{username=r.username;player=r.player;panel();if(shopping){renderShop();previewShop();}if(pending?.score)claim();if(new URLSearchParams(location.search).get('account')==='manage')open();}).catch(e=>{session=null;storageSave();status.textContent='다시 로그인해 주세요. '+e.message;});
else if(new URLSearchParams(location.search).get('account')==='manage')open();
