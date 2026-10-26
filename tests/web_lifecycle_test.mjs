import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=readFileSync(new URL('../site/app.js',import.meta.url),'utf8');
function fixture(raw=null,failWrite=false){
  const nodes=new Map(),events=new Map(),docEvents=new Map(),writes=[];
  let textWrites=0;
  const watchText=n=>{let value='';Object.defineProperty(n,'textContent',{get:()=>value,set:next=>{value=String(next);textWrites++;}});return n;};
  const classes=()=>{const s=new Set();return {add:x=>s.add(x),remove:x=>s.delete(x),contains:x=>s.has(x),toggle:(x,on)=>on?s.add(x):s.delete(x)}};
  let document;
  const node=id=>{
    if(nodes.has(id))return nodes.get(id);
    const handlers=new Map();
    const n={id,tagName:'BUTTON',style:{},classList:classes(),dataset:{},open:false,hidden:false,textContent:'',lastElementChild:{},
      addEventListener:(name,cb)=>{if(!handlers.has(name))handlers.set(name,[]);handlers.get(name).push(cb)},
      fire:(name,e={})=>(handlers.get(name)||[]).forEach(cb=>cb(e)),
      click:()=>n.fire('click'),setAttribute:()=>{},focus:()=>document.activeElement=n,
      showModal:()=>{n.open=true;node('close-dialog').focus()},close:()=>{n.open=false;n.fire('close')},
      setPointerCapture:()=>{},getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})};
    watchText(n);watchText(n.lastElementChild);nodes.set(id,n);return n;
  };
  node('canvas').tagName='CANVAS';
  node('practice-option').dataset.select='practice';node('duel-option').dataset.select='duel';node('team-option').dataset.select='team';
  node('shoot-touch').dataset.control='shoot';
  node('team-control').dataset.control='team';
  document={hidden:false,body:{classList:classes()},activeElement:null,
    getElementById:node,addEventListener:(n,cb)=>docEvents.set(n,cb),
    querySelectorAll:q=>q==='[data-select]'?[node('practice-option'),node('duel-option'),node('team-option')]:q==='[data-control]'?[node('shoot-touch'),node('team-control')]:[]};
  const storage=new Map(raw===null?[]:[['unfree-settings-v1',raw]]);
  const window={addEventListener:(name,cb)=>events.set(name,cb)};
  const ctx=vm.createContext({window,document,console:{error:()=>{}},matchMedia:()=>({matches:false}),localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>{if(failWrite)throw Error('quota');writes.push(v);storage.set(k,v)}}});
  vm.runInContext(source,ctx);
  const run=s=>vm.runInContext(s,ctx);
  const playing=()=>run("ready=true;state={started:true,paused:false,phase:'live',mode:'practice'}");
  const key=(type,code,repeat=false)=>events.get(type)({code,repeat,target:node('canvas'),preventDefault(){}});
  return {node,events,docEvents,document,window,storage,writes,run,playing,key,get textWrites(){return textWrites;}};
}
{
  const f=fixture();f.playing();f.key('keydown','KeyD');assert.equal(f.window.ufInput.shoot,true);
  f.events.get('blur')();assert.equal(f.window.ufInput.suspended,true);assert.equal(f.window.ufInput.shoot,false);
  f.node('motion-button').click();assert.equal(f.window.ufInput.command,'motion');assert.equal(f.window.ufInput.suspended,true,'settings overwrote pause');
  f.run('state.paused=true');f.node('resume-button').click();assert.equal(f.window.ufInput.command,'resume');assert.equal(f.window.ufInput.suspended,false);
  f.run('state.paused=false');
  f.key('keydown','KeyD',true);assert.equal(f.window.ufInput.shoot,false,'held key restarted after resume');
  f.key('keyup','KeyD');f.key('keydown','KeyD');assert.equal(f.window.ufInput.shoot,true);
}
{
  const f=fixture();f.playing();f.node('updates-button').click();assert.equal(f.node('info-dialog').open,true);
  const command=f.window.ufInput.commandId;f.run('state.paused=true');f.node('close-dialog').click();
  assert.equal(f.window.ufInput.suspended,true);assert.equal(f.window.ufInput.commandId,command,'closing info resumed game');
  assert.equal(f.document.activeElement.id,'resume-button');
}
{
  const f=fixture();f.playing();const event={pointerId:1,clientX:95,clientY:50,preventDefault(){},currentTarget:f.node('joystick')};
  f.node('shoot-touch').fire('pointerdown',event);f.node('joystick').fire('pointerdown',event);
  assert.equal(f.window.ufInput.shoot,true);assert.ok(f.window.ufInput.x>0);
  f.document.hidden=true;f.docEvents.get('visibilitychange')();f.node('joystick').fire('pointermove',event);
  f.node('shoot-touch').fire('pointerdown',event);assert.equal(f.window.ufInput.shoot,false);assert.equal(f.window.ufInput.x,0);
}
{
  const raw='{broken';const f=fixture(raw);assert.equal(f.writes.length,0);assert.equal(f.storage.get('unfree-settings-v1'),raw);
  assert.equal(f.node('settings-notice').hidden,false);f.node('motion-button').click();assert.equal(f.writes.length,1);
  const q=fixture(null,true);q.node('motion-button').click();assert.equal(q.window.ufInput.reduced,true);
  assert.ok(q.document.body.classList.contains('reduced-motion'));assert.match(q.node('settings-notice').textContent,/현재 창/);
}
{
  const f=fixture();f.run("ready=true;state={started:false,phase:'live'};start('practice')");f.events.get('blur')();
  assert.equal(f.window.ufInput.suspended,true,'blur before first game acknowledgement was lost');
}
{
 const f=fixture();
 const next={started:true,paused:false,phase:'live',mode:'practice',score:[0,0],seconds:90,owner:0,action:'idle',charge:0,finish:'shot',makes:0,attempts:0};
 const active=()=>f.node('shot-cue').classList.contains('active');
 f.window.ufUpdate(next);assert.equal(active(),false,'idle dribbling must not show a shot panel');
 f.window.ufUpdate({...next,action:'gather',charge:.65});assert.equal(active(),true,'preparing a shot must show the timing rail');assert.equal(f.node('release-fill').style.width,'65%');
 f.window.ufUpdate({...next,action:'shot',phase:'takeoff'});assert.equal(active(),false,'rail must clear after takeoff');
 f.window.ufUpdate({...next,action:'gather',owner:1});assert.equal(active(),false,'opponent must not trigger own shot rail');
 f.window.ufUpdate({...next,action:'gather',paused:true});assert.equal(active(),false,'pause must hide the rail');
}
{
 const f=fixture(JSON.stringify({sound:false,reduced:true}));
 let audio=JSON.parse(f.window.ufInput.audio);
 assert.equal(f.window.ufInput.sound,false);assert.equal(audio.music,true);assert.equal(audio.voice,true);assert.equal(audio.musicDb,-12,'old settings gain safe audio defaults');
 f.node('voice-button').click();assert.equal(JSON.parse(f.window.ufInput.audio).voice,false);
 f.node('music-track').value='1';f.node('music-track').fire('change');assert.equal(JSON.parse(f.window.ufInput.audio).track,1);
 f.node('music-next').click();audio=JSON.parse(f.window.ufInput.audio);assert.equal(audio.track,-1);assert.equal(audio.next,1);
 f.node('musicDb').value='-25';f.node('musicDb').fire('input');assert.equal(JSON.parse(f.window.ufInput.audio).musicDb,-25);
 f.playing();f.events.get('blur')();assert.equal(f.window.ufInput.audioSuspended,true);
 f.run('state.paused=true');f.node('resume-button').click();assert.equal(f.window.ufInput.audioSuspended,false);
 const malformed=fixture(JSON.stringify({sound:true,reduced:false,track:20,musicDb:'loud',voice:null}));
 audio=JSON.parse(malformed.window.ufInput.audio);assert.equal(audio.track,-1);assert.equal(audio.musicDb,-12);assert.equal(audio.voice,true);
}
{
 const f=fixture();const next={started:true,paused:false,phase:'live',mode:'practice',score:[0,0],seconds:90,owner:0,action:'idle',charge:0,finish:'shot',makes:0,attempts:0};
 f.window.ufUpdate(next);const before=f.textWrites;
 for(let i=0;i<100;i++)f.window.ufUpdate({...next});
 console.log('HUD_REPEAT_TEXT_WRITES',f.textWrites-before);
 assert.equal(f.textWrites-before,0,'Unchanged HUD must not recreate text nodes and retrigger localization');
 f.node('role-description').textContent='Guard · Fast movement';
 f.window.ufUpdate({...next});assert.equal(f.node('role-description').textContent,'Guard · Fast movement','HUD source cache must preserve translated text');
 f.window.ufUpdate({...next,score:[2,0]});assert.equal(f.node('score-you').textContent,'02','A changed score must still render immediately');
}
{
 const f=fixture();const next={started:true,paused:false,phase:'flight',mode:'practice',score:[0,0],seconds:90,owner:-1,action:'idle',charge:0,finish:'shot',makes:0,attempts:0};
 f.window.ufUpdate({...next,defenseAction:'block',reboundWindow:true});
 assert.equal(f.node('touch-shot-label').textContent,'블록','Touch label must follow the actual selected defensive jump');
 assert.equal(f.node('finish-label').textContent,'D · BLOCK','An early-flight block must not show a rebound cue');
 f.window.ufUpdate({...next,defenseAction:'rebound',reboundWindow:true});
 assert.equal(f.node('touch-shot-label').textContent,'리바운드');
 assert.equal(f.node('finish-label').textContent,'D · REBOUND');
}
{
 const f=fixture();
 f.run("ready=true;start('team');state={started:true,paused:false,phase:'live',mode:'team',possessionTeam:0};");
 assert.equal(f.window.ufInput.command,'team');
 f.key('keydown','KeyQ');assert.equal(f.window.ufInput.passBall,true);f.key('keyup','KeyQ');
 f.key('keydown','KeyE');assert.equal(f.window.ufInput.switchPlayer,true);f.key('keyup','KeyE');
 const event={pointerId:7,preventDefault(){}};
 f.node('team-control').fire('pointerdown',event);assert.equal(f.window.ufInput.passBall,true);assert.equal(f.window.ufInput.switchPlayer,false);
 f.node('team-control').fire('pointercancel');assert.equal(f.window.ufInput.passBall,false);
 f.run('state.possessionTeam=1');f.node('team-control').fire('pointerdown',event);
 assert.equal(f.window.ufInput.switchPlayer,true);assert.equal(f.window.ufInput.passBall,false);
 f.events.get('blur')();assert.equal(f.window.ufInput.switchPlayer,false,'Team touch must release on blur');
 const next={started:true,paused:false,phase:'ended',mode:'team',score:[11,6],seconds:80,owner:-1,action:'idle',charge:0,finish:'shot',makes:4,attempts:7,possessionTeam:0};
 f.window.ufUpdate(next);
 assert.equal(f.node('result-rematch').dataset.start,'team','Team rematch must not start a duel');
 assert.equal(f.node('mode-badge').textContent,'3 ON 3');assert.equal(f.node('result-detail').textContent,'AI 3대3 · 보상 없음');
 f.window.ufUpdate({...next,mode:'duel'});assert.equal(f.node('result-rematch').dataset.start,'duel');assert.equal(f.node('team-control').hidden,true);
}
console.log('WEB_LIFECYCLE: focus/visibility, pause, repeat keys, touch cancel, manual resume, shot-meter, audio, team Q/E, contextual touch and team rematch passed');
