window.crCharacterInput={mode:'idle',view:'full',slow:false,paused:false};
for(const field of ['mode','view'])for(const button of document.querySelectorAll(`[data-${field}]`))button.addEventListener('click',()=>{
 window.crCharacterInput[field]=button.dataset[field];
 for(const item of document.querySelectorAll(`[data-${field}]`))item.setAttribute('aria-pressed',String(item===button));
});
for(const id of ['slow','pause'])document.getElementById(id).addEventListener('click',()=>{
 const field=id==='pause'?'paused':id;
 window.crCharacterInput[field]=!window.crCharacterInput[field];
 document.getElementById(id).setAttribute('aria-pressed',String(window.crCharacterInput[field]));
 if(id==='pause')document.getElementById(id).textContent=window.crCharacterInput.paused?'계속 보기':'정지';
});
document.addEventListener('visibilitychange',()=>{if(document.hidden){window.crCharacterInput.paused=true;document.getElementById('pause').setAttribute('aria-pressed','true');document.getElementById('pause').textContent='계속 보기';}});
(async()=>{const status=document.getElementById('status');try{
 const canvas=document.getElementById('canvas');
 const resize=()=>{const rect=canvas.getBoundingClientRect();canvas.width=Math.round(rect.width*devicePixelRatio);canvas.height=Math.round(rect.height*devicePixelRatio);};resize();window.addEventListener('resize',resize);
 const engine=new Engine({...window.UF_ENGINE_CONFIG,args:['--','--character-lab'],canvas,canvasResizePolicy:0,focusCanvas:false});
 await engine.startGame({onProgress:(current,total)=>{if(total)status.textContent=`캐릭터 준비 중 ${Math.round(current/total*100)}%`;}});
 status.textContent='HUMAN CHARACTERS · v0.7.1';
 for(const button of document.querySelectorAll('button'))button.disabled=false;
}catch(error){status.textContent='캐릭터를 불러오지 못했습니다. '+error.message;console.error(error);}})();
