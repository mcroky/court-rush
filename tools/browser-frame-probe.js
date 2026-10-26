/* Development-only frame probe, enabled by ?frame-probe=1. Reads no player records. */
if(new URLSearchParams(location.search).get('frame-probe')==='1'){
 const panel=document.createElement('pre');panel.id='frame-probe';panel.style.cssText='position:fixed;left:8px;bottom:8px;z-index:99999;background:#081b22ed;color:#b9ffce;padding:9px;font:11px monospace;pointer-events:none;max-width:95vw;white-space:pre-wrap';
 const frames=[];let last=0,warmup=90,mode='',count=0;
 const reset=()=>{frames.length=0;last=0;warmup=90;count=0;};
 document.addEventListener('fullscreenchange',()=>{(document.fullscreenElement||document.body).appendChild(panel);reset();});
 document.body.appendChild(panel);
 function tick(now){
  const nextMode=(document.body.classList.contains('team-mode')?'team':'other')+(document.fullscreenElement?'-fullscreen':'-window');
  if(mode!==nextMode){mode=nextMode;reset();}
  const playing=document.body.classList.contains('in-play')&&document.getElementById('pause-overlay').classList.contains('hidden')&&document.getElementById('result-overlay').classList.contains('hidden');
  if(document.visibilityState==='hidden'||!playing){reset();panel.textContent=JSON.stringify({mode,paused:true,samples:0});requestAnimationFrame(tick);return;}
  if(last&&warmup===0){frames.push(now-last);if(frames.length>900)frames.shift();count++;} else if(warmup>0)warmup--;
  last=now;
  if(count%30===0||warmup>0){const ordered=[...frames].sort((a,b)=>a-b);const pick=p=>ordered[Math.min(ordered.length-1,Math.floor(ordered.length*p))]||0;const canvas=document.getElementById('canvas');const rect=canvas.getBoundingClientRect();panel.textContent=JSON.stringify({mode,engine:JSON.parse(panel.dataset.engineProfile||"null"),samples:frames.length,warmup,meanMs:frames.reduce((a,b)=>a+b,0)/Math.max(1,frames.length),p50Ms:pick(.5),p95Ms:pick(.95),p99Ms:pick(.99),over33:frames.filter(t=>t>33.5).length,canvas:[canvas.width,canvas.height],css:[Math.round(rect.width),Math.round(rect.height)],dpr:devicePixelRatio},null,1);}
  requestAnimationFrame(tick);
 } requestAnimationFrame(tick);
}
