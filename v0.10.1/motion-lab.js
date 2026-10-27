window.crMotionInput={mode:'run',paused:false,slow:false,side:false,replay:0};
const lab=window.crMotionInput;
for(const button of document.querySelectorAll('[data-mode]'))button.addEventListener('click',()=>{
 lab.mode=button.dataset.mode;
 lab.replay++;
 for(const item of document.querySelectorAll('[data-mode]'))item.setAttribute('aria-pressed',String(item===button));
 document.getElementById('left-detail').textContent=lab.mode==='land'?'대기 · 비교할 기존 착지 클립 없음':'게임에서 쓰는 달리기 / 대기';
});
for(const key of ['slow','side','pause'])document.getElementById(key).addEventListener('click',()=>{
 const field=key==='pause'?'paused':key;
 lab[field]=!lab[field];
 document.getElementById(key).setAttribute('aria-pressed',String(lab[field]));
 if(key==='pause')document.getElementById(key).textContent=lab.paused?'계속 보기':'정지';
});
document.addEventListener('visibilitychange',()=>{if(document.hidden){lab.paused=true;document.getElementById('pause').setAttribute('aria-pressed','true');document.getElementById('pause').textContent='계속 보기';}});
(async()=>{
 const status=document.getElementById('status');
 try{
  const canvas=document.getElementById('canvas');
  const size=()=>{const rect=canvas.getBoundingClientRect();canvas.width=Math.round(rect.width*devicePixelRatio);canvas.height=Math.round(rect.height*devicePixelRatio);};size();window.addEventListener('resize',size);
  const engine=new Engine({...window.UF_ENGINE_CONFIG,args:['--','--motion-lab'],canvas,canvasResizePolicy:0,focusCanvas:false});
  await engine.startGame({onProgress:(current,total)=>{if(total)status.textContent=`모션 준비 중 ${Math.round(current/total*100)}%`;}});
  document.title=window.CourtI18n?.text('코트러시 · 모션 방식 비교') || '코트러시 · 모션 방식 비교';
  status.textContent='MOTION COMPARISON · 실험 장면';
  for(const button of document.querySelectorAll('button'))button.disabled=false;
 }catch(error){status.textContent='모션을 불러오지 못했습니다. '+error.message;console.error(error);}
})();
