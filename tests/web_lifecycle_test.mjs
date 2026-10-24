import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=readFileSync(new URL('../site/app.js',import.meta.url),'utf8');
function fixture(raw=null,failWrite=false){
  const nodes=new Map(),events=new Map(),docEvents=new Map(),writes=[];
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
    nodes.set(id,n);return n;
  };
  node('canvas').tagName='CANVAS';
  node('practice-option').dataset.select='practice';node('duel-option').dataset.select='duel';
  node('shoot-touch').dataset.control='shoot';
  document={hidden:false,body:{classList:classes()},activeElement:null,
    getElementById:node,addEventListener:(n,cb)=>docEvents.set(n,cb),
    querySelectorAll:q=>q==='[data-select]'?[node('practice-option'),node('duel-option')]:q==='[data-control]'?[node('shoot-touch')]:[]};
  const storage=new Map(raw===null?[]:[['unfree-settings-v1',raw]]);
  const window={addEventListener:(name,cb)=>events.set(name,cb)};
  const ctx=vm.createContext({window,document,console:{error:()=>{}},matchMedia:()=>({matches:false}),localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>{if(failWrite)throw Error('quota');writes.push(v);storage.set(k,v)}}});
  vm.runInContext(source,ctx);
  const run=s=>vm.runInContext(s,ctx);
  const playing=()=>run("ready=true;state={started:true,paused:false,phase:'live',mode:'practice'}");
  const key=(type,code,repeat=false)=>events.get(type)({code,repeat,target:node('canvas'),preventDefault(){}});
  return {node,events,docEvents,document,window,storage,writes,run,playing,key};
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
console.log('WEB_LIFECYCLE: focus/visibility, persistent pause, repeat keys, touch cancel, manual resume, corrupt/unwritable settings passed');
