// Real Godot worker, production 60Hz/20Hz. No account data or fake HTTP responses.
import {Worker} from '../gateway/worker.mjs';
import {resolve} from 'node:path';
import {writeFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
const worker=new Worker({binary:process.env.GODOT_BIN,root:resolve(import.meta.dirname,'../..'),port:32110});
const duration=Number(process.env.CR_SOAK_SECONDS||900)*1000,start=Date.now();
let room='',seq=0,bytes=0,snapshots=0,matches=0,health=[],failed=false,ready=false,latest=null;
function create(){room=randomUUID();worker.send({type:'create',roomId:room,appearances:[{},{}]});}
worker.on('fault',code=>{console.error('SOAK_FAULT',code);failed=true;});
worker.on('message',m=>{
 if(m.type==='ready'){ready=true;create();}
 if(m.type==='created'){matches++;worker.send({type:'start',roomId:room});}
 if(m.type==='health'&&m.tickP95us)health.push({at:Date.now()-start,p95:m.tickP95us,p99:m.tickP99us,memory:m.memoryBytes});
 if(m.type==='overload'){failed=true;console.error('SOAK_OVERLOAD');}
 if(m.type==='snapshot'){
  latest=m.state;snapshots++;bytes+=Buffer.byteLength(JSON.stringify(m.state));
  if(m.state.phase==='ended'){worker.send({type:'destroy',roomId:room});setTimeout(create,100);}
 }
});
worker.start();
const timer=setInterval(()=>{
 if(!ready||!latest)return;const second=(Date.now()-start)/1000;
 for(let slot=0;slot<2;slot++)worker.send({type:'input',roomId:room,slot,input:{seq:seq++,x:Math.sin(second*.4+slot*3),z:Math.cos(second*.4+slot*3),shoot:second%3<.65,shoot_pressed:false,cross:second%7<.2,spin:false,twostep:false,behind:false,hesi:false,steal:second%4<.2,guard:slot===1}});
},33);
setTimeout(()=>{
 clearInterval(timer);worker.close();const p95=health.map(x=>x.p95).sort((a,b)=>a-b);
 const report={durationSeconds:(Date.now()-start)/1000,matches,snapshots,averageSnapshotBytes:Math.round(bytes/Math.max(1,snapshots)),worstWindowP95us:p95.at(-1),typicalWindowP95us:p95[Math.floor(p95.length*.95)],firstMemory:health[0]?.memory,lastMemory:health.at(-1)?.memory,nodeRSS:process.memoryUsage().rss,failed,health};
 writeFileSync(resolve(import.meta.dirname,'../../artifacts/online-soak.json'),JSON.stringify(report,null,2));console.log('SOAK_RESULT',JSON.stringify({...report,health:undefined}));process.exit(failed?1:0);
},duration);
