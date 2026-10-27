import {createClient} from 'npm:@supabase/supabase-js@2.118.0';
import {issueOnlineTicket,handleOnlineServer,onlineRanking} from './online.ts';
import {ROLES,STAGES,newPlayer,attributes,opponentAthlete,trainPlayer,rewardPlayer,normalizePlayer,buyClothing,equipClothing,teamOpponents,validateTeamResult,rewardTeamPlayer} from './rules.mjs';

const url=Deno.env.get('SUPABASE_URL')!;
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
const options={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
const admin=createClient(url,service,options);
const allowed=new Set(['https://mcroky.github.io','http://127.0.0.1:8791','http://localhost:8791']);
const sha=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(x=>x.toString(16).padStart(2,'0')).join('');
const recovery=()=>Array.from(crypto.getRandomValues(new Uint8Array(16))).map(x=>x.toString(16).padStart(2,'0')).join('').toUpperCase();
function fail(message:string,status=400):never{throw Object.assign(Error(message),{status});}
function username(s:unknown){if(typeof s!=='string')fail('아이디를 확인하세요.');const id=s.toLowerCase().trim();if(!/^[a-z0-9_]{4,20}$/.test(id))fail('아이디는 영문·숫자·밑줄 4~20자입니다.');return id;}
function password(s:unknown){if(typeof s!=='string'||s.length<12||new TextEncoder().encode(s).length>72)fail('비밀번호는 12자 이상, UTF-8 72바이트 이하로 입력하세요.');return s;}
function checked<T>(r:{data:T,error:any}):T{if(r.error)throw r.error;return r.data;}
async function limit(key:string,n:number,seconds:number){const ok=checked(await admin.rpc('cr_rate_limit',{p_key:await sha(key),p_limit:n,p_seconds:seconds}));if(!ok)fail('요청이 많습니다. 잠시 후 다시 시도하세요.',429);}
async function accountById(id:string){return checked(await admin.from('cr_accounts').select('*').eq('username',id).maybeSingle());}
async function playerRow(id:string){return checked(await admin.from('cr_players').select('data,revision').eq('user_id',id).maybeSingle());}
async function authenticate(req:Request){
 const token=req.headers.get('authorization')?.replace(/^Bearer /,'');if(!token)fail('로그인이 필요합니다.',401);
 const {data,error}=await admin.auth.getUser(token);if(error||!data.user)fail('다시 로그인하세요.',401);
 let claims:any;try{claims=JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));}catch{fail('다시 로그인하세요.',401);}
 if(typeof claims.session_id!=='string'||!checked(await admin.rpc('cr_session_valid',{p_user:data.user.id,p_session:claims.session_id})))fail('로그인이 만료됐습니다.',401);
 const a=checked(await admin.from('cr_accounts').select('*').eq('user_id',data.user.id).maybeSingle());
 if(!a)fail('코트러시 계정이 아닙니다.',403);return {a,token};
}
async function verifyPassword(alias:string,pass:string){
 const c=createClient(url,anon,options);const {data,error}=await c.auth.signInWithPassword({email:alias,password:pass});
 if(error||!data.session)fail('아이디 또는 비밀번호를 확인하세요.',401);return data.session;
}
const sessionData=(s:any)=>({access_token:s.access_token,refresh_token:s.refresh_token,expires_at:s.expires_at});

Deno.serve(async(req:Request)=>{
 const origin=req.headers.get('origin')||'';
 const headers={'Access-Control-Allow-Origin':allowed.has(origin)?origin:'https://mcroky.github.io','Access-Control-Allow-Headers':'authorization, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin','Cache-Control':'no-store','Content-Type':'application/json'};
 const send=(data:any,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(origin&&!allowed.has(origin))return send({error:'허용되지 않은 요청입니다.'},403);
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return send({error:'POST만 지원합니다.'},405);
 try{
  if(Number(req.headers.get('content-length')||0)>12000)fail('요청이 너무 큽니다.',413);
  const text=await req.text();if(text.length>12000)fail('요청이 너무 큽니다.',413);
  let b:any;try{b=JSON.parse(text);}catch{fail('요청 형식을 확인하세요.');}
  const action=b.action;
  const ip=(req.headers.get('x-forwarded-for')||req.headers.get('cf-connecting-ip')||'unknown').split(',')[0].trim();
  await limit('api:'+ip,180,60);
  if(typeof action==='string'&&action.startsWith('online-')&&!['online-ticket','online-ranking'].includes(action))return send(await handleOnlineServer(admin,req,b));
  if(['signup','login','recover'].includes(action)){
   const id=username(b.username),pass=password(b.password);
   await limit(action+':ip:'+ip,action==='signup'?5:15,action==='signup'?3600:60);
   await limit(action+':id:'+id,action==='recover'?1:8,60);
   if(action==='signup'){
    if(await accountById(id))fail('가입할 수 없습니다. 다른 아이디를 사용하거나 로그인하세요.');
    const alias=crypto.randomUUID()+'@accounts.courtrush.invalid',code=recovery();
    const created=await admin.auth.admin.createUser({email:alias,password:pass,email_confirm:true,app_metadata:{application:'court-rush'}});
    if(created.error||!created.data.user)fail('가입을 완료하지 못했습니다. 잠시 후 다시 시도하세요.');
    const uid=created.data.user.id;
    const insert=await admin.from('cr_accounts').insert({user_id:uid,username:id,login_alias:alias,recovery_hash:await sha(code)});
    if(insert.error){await admin.auth.admin.deleteUser(uid);fail('가입을 완료하지 못했습니다. 다른 아이디를 사용하거나 로그인하세요.');}
    const s=await verifyPassword(alias,pass);return send({session:sessionData(s),username:id,player:null,recoveryCode:code});
   }
   const a=await accountById(id);
   if(action==='recover'){
    const code=typeof b.recoveryCode==='string'?b.recoveryCode.replace(/[-\s]/g,'').toUpperCase():'';
    const hash=await sha(code);let same=Boolean(a)&&code.length===32;
    if(a){let mismatch=0;for(let i=0;i<64;i++)mismatch|=hash.charCodeAt(i)^a.recovery_hash.charCodeAt(i);same=same&&mismatch===0;}
    if(!same)fail('아이디와 복구 코드를 확인하세요.',401);
    const next=recovery();checked(await admin.auth.admin.updateUserById(a.user_id,{password:pass}));
    const proof=await verifyPassword(a.login_alias,pass);checked(await admin.auth.admin.signOut(proof.access_token,'global'));
    checked(await admin.from('cr_accounts').update({recovery_hash:await sha(next)}).eq('user_id',a.user_id));
    return send({recoveryCode:next,message:'비밀번호를 변경했습니다. 다시 로그인하세요.'});
   }
   // Nonexistent accounts still take the Auth password-verification path.
   const s=await verifyPassword(a?.login_alias||crypto.randomUUID()+'@accounts.courtrush.invalid',pass);
   if(!a)fail('아이디 또는 비밀번호를 확인하세요.',401);
   const p=await playerRow(a.user_id);return send({session:sessionData(s),username:id,player:p?normalizePlayer(p.data):null});
  }
  if(action==='refresh'){
   if(typeof b.refreshToken!=='string'||b.refreshToken.length>2048)fail('다시 로그인하세요.',401);
   const c=createClient(url,anon,options);const r=await c.auth.refreshSession({refresh_token:b.refreshToken});
   if(r.error||!r.data.session)fail('다시 로그인하세요.',401);
   return send({session:sessionData(r.data.session)});
  }
  const {a,token}=await authenticate(req);
  if(action==='online-ranking'){await limit('online-ranking:'+a.user_id,30,60);return send(await onlineRanking(admin,a.user_id));}
  if(action==='online-ticket'){
   await limit('online-ticket:'+a.user_id,20,60);
   return send(await issueOnlineTicket(admin,a,token,b));
  }
  if(action==='logout'){checked(await admin.auth.admin.signOut(token,'global'));return send({ok:true});}
  if(action==='delete'){
   password(b.password);const proof=await verifyPassword(a.login_alias,b.password);
   checked(await admin.auth.admin.signOut(proof.access_token,'global'));
   checked(await admin.auth.admin.deleteUser(a.user_id));return send({ok:true});
  }
  if(action==='recovery'){
   password(b.password);await verifyPassword(a.login_alias,b.password);
   const code=recovery();checked(await admin.from('cr_accounts').update({recovery_hash:await sha(code)}).eq('user_id',a.user_id));return send({recoveryCode:code});
  }
  let row=await playerRow(a.user_id);
  if(action==='profile')return send({username:a.username,player:row?normalizePlayer(row.data):null});
  if(action==='create'){
   if(row)fail('이미 선수가 있습니다.',409);
   const player=newPlayer(b.role,b.nickname);checked(await admin.from('cr_players').insert({user_id:a.user_id,data:player}));return send({player});
  }
  if(!row)fail('먼저 선수를 만들어 주세요.');
  if(action==='buy'||action==='equip'){
   const result=action==='buy'?buyClothing(row.data,b.itemId):{player:equipClothing(row.data,b.itemId)};
   const changed=checked(await admin.from('cr_players').update({data:result.player,revision:row.revision+1,updated_at:new Date().toISOString()}).eq('user_id',a.user_id).eq('revision',row.revision).select('data'));
   if(!changed.length)fail('선수가 다른 창에서 변경됐습니다. 다시 불러와 주세요.',409);
   return send(result);
  }
  if(action==='train'){
   const player=trainPlayer(row.data,b.kind,b.key);
   const changed=checked(await admin.from('cr_players').update({data:player,revision:row.revision+1,updated_at:new Date().toISOString()}).eq('user_id',a.user_id).eq('revision',row.revision).select('data'));
   if(!changed.length)fail('선수가 다른 창에서 변경됐습니다. 다시 불러와 주세요.',409);return send({player});
  }
  if(action==='start'){
   if(b.mode!==undefined&&!['duel','team'].includes(b.mode))fail('경기 모드를 확인하세요.');
   const mode=b.mode||'duel';
   if(mode==='team'){
    if(!/^[0-9a-f-]{36}$/.test(b.requestId||''))fail('경기 요청을 확인하세요.');
    const prior=checked(await admin.from('cr_matches').select('*').eq('id',b.requestId).eq('user_id',a.user_id).maybeSingle());
    if(prior){if(prior.game_mode!=='team'||prior.finished_at)fail('새 경기를 시작해 주세요.');return send({matchId:prior.id,...prior.setup});}
    await limit('start:'+a.user_id,40,3600);
    const setup={mode:'team',athlete:attributes(row.data),opponents:teamOpponents(row.data)};
    checked(await admin.from('cr_matches').insert({id:b.requestId,user_id:a.user_id,stage:1,game_mode:'team',setup}));
    return send({matchId:b.requestId,...setup});
   }
   const stage=b.stage;
   if(!Number.isInteger(stage)||stage<1||stage>STAGES.length||stage>row.data.cleared+1)fail('아직 도전할 수 없는 코트입니다.');
   if(!/^[0-9a-f-]{36}$/.test(b.requestId||''))fail('경기 요청을 확인하세요.');
   const prior=checked(await admin.from('cr_matches').select('*').eq('id',b.requestId).eq('user_id',a.user_id).maybeSingle());
   if(prior){if(prior.game_mode!=='duel'||prior.stage!==stage||prior.finished_at)fail('새 경기를 시작해 주세요.');return send({matchId:prior.id,stage,athlete:attributes(row.data),opponent:{...STAGES[stage-1],athlete:opponentAthlete(stage)}});}
   await limit('start:'+a.user_id,40,3600);
   checked(await admin.from('cr_matches').insert({id:b.requestId,user_id:a.user_id,stage}));
   return send({matchId:b.requestId,stage,athlete:attributes(row.data),opponent:{...STAGES[stage-1],athlete:opponentAthlete(stage)}});
  }
  if(action==='finish'){
   if(typeof b.matchId!=='string'||!/^[0-9a-f-]{36}$/.test(b.matchId))fail('경기를 확인하세요.');
   const m=checked(await admin.from('cr_matches').select('*').eq('id',b.matchId).eq('user_id',a.user_id).maybeSingle());
   if(!m)fail('경기를 찾을 수 없습니다.',404);
   if(m.finished_at)return send({player:normalizePlayer(row.data),reward:m.result});
   if(m.game_mode==='team'){
    const elapsed=(Date.now()-Date.parse(m.started_at))/1000;
    const stats=validateTeamResult(b.score,b.seconds,b.stats,elapsed);
    const result=rewardTeamPlayer(row.data,b.score[0]>b.score[1],stats);
    const saved=await admin.rpc('cr_finish_match',{p_user:a.user_id,p_match:m.id,p_revision:row.revision,p_data:result.player,p_result:result.reward});
    if(saved.error?.code==='40001')fail('선수가 다른 창에서 변경됐습니다. 보상 받기를 다시 눌러 주세요.',409);
    return send(checked(saved));
   }
   if(!Array.isArray(b.score)||b.score.length!==2||b.score.some((n:any)=>!Number.isInteger(n)||n<0||n>13)||b.score[0]===b.score[1]||!Number.isFinite(b.seconds)||b.seconds<0||b.seconds>90)fail('경기 결과를 확인하세요.');
   const elapsed=(Date.now()-Date.parse(m.started_at))/1000;
   if(elapsed<15||elapsed>86400||(Math.max(...b.score)<11&&b.seconds>0)||elapsed+3<90-b.seconds)fail('경기 시간과 결과를 확인하세요.');
   const result=rewardPlayer(row.data,m.stage,b.score[0]>b.score[1]);
   const saved=await admin.rpc('cr_finish_match',{p_user:a.user_id,p_match:m.id,p_revision:row.revision,p_data:result.player,p_result:result.reward});
   if(saved.error?.code==='40001')fail('선수가 다른 창에서 변경됐습니다. 보상 받기를 다시 눌러 주세요.',409);
   return send(checked(saved));
  }
  fail('지원하지 않는 요청입니다.');
 }catch(e:any){
  // Never log request bodies, passwords, Auth aliases, tokens or recovery codes.
  return send({error:e.status?e.message:'처리를 완료하지 못했습니다. 잠시 후 다시 시도하세요.'},e.status||500);
 }
});
