import {normalizePlayer} from './rules.mjs';
const uuid=(value:unknown)=>typeof value==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value);
const reject=(status=400):never=>{throw Object.assign(Error('온라인 경기 요청을 확인하세요.'),{status});};
function value<T>(r:{data:T,error:any}):T{if(r.error)reject(r.error.code==='42501'?403:409);return r.data;}
const hash=async(text:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))).map(n=>n.toString(16).padStart(2,'0')).join('');
const randomTicket=()=>Array.from(crypto.getRandomValues(new Uint8Array(32))).map(n=>n.toString(16).padStart(2,'0')).join('');

export async function issueOnlineTicket(admin:any,a:any,token:string,b:any){
 if(b.mode!=='duel'||b.protocolVersion!==1||b.rulesVersion!=='duel-standard-v1'||typeof b.serverId!=='string')reject();
 const server=value<any>(await admin.from('cr_online_servers').select('id,epoch,heartbeat_at').eq('id',b.serverId).eq('enabled',true).maybeSingle());
 if(!server?.epoch)reject(503);
 const row=value<any>(await admin.from('cr_players').select('data').eq('user_id',a.user_id).maybeSingle());
 if(!row)reject();
 const player=normalizePlayer(row.data),ticket=randomTicket();
 const claims=JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));
 value(await admin.from('cr_online_tickets').insert({ticket_hash:await hash(ticket),server_id:server.id,user_id:a.user_id,session_id:claims.session_id,profile:{nickname:player.nickname,appearance:player.wardrobe.equipped},expires_at:new Date(Date.now()+60000).toISOString()}));
 return {ticket,expiresIn:60,protocolVersion:1,rulesVersion:'duel-standard-v1',serverEpoch:server.epoch};
}

export async function handleOnlineServer(admin:any,req:Request,b:any){
 const secret=req.headers.get('x-court-server-key')||'';
 if(!/^[a-f0-9]{64}$/.test(secret)||typeof b.serverId!=='string'||!uuid(b.epoch))reject(401);
 const server=value<any>(await admin.from('cr_online_servers').select('id,epoch').eq('id',b.serverId).eq('key_hash',await hash(secret)).eq('enabled',true).maybeSingle());
 if(!server)reject(401);
 if(b.action==='online-boot')return {ok:value(await admin.rpc('cr_online_boot',{p_server:server.id,p_epoch:b.epoch}))};
 if(server.epoch!==b.epoch)reject(403);
 value(await admin.from('cr_online_servers').update({heartbeat_at:new Date().toISOString()}).eq('id',server.id).eq('epoch',b.epoch));
 if(b.action==='online-redeem'){
  if(typeof b.ticket!=='string'||!/^[a-f0-9]{64}$/.test(b.ticket)||!uuid(b.requestId))reject();
  return value(await admin.rpc('cr_online_redeem',{p_server:server.id,p_epoch:b.epoch,p_hash:await hash(b.ticket),p_request:b.requestId}));
 }
 if(b.action==='online-register'){
  if(!uuid(b.matchId)||!Array.isArray(b.players)||b.players.length!==2||b.players.some((p:any)=>!uuid(p.ticketId)))reject();
  return {ok:value(await admin.rpc('cr_online_register',{p_server:server.id,p_epoch:b.epoch,p_match:b.matchId,p_tickets:b.players.map((p:any)=>p.ticketId)}))};
 }
 if(b.action==='online-finish'){
  const r=b.result;
  if(!uuid(b.matchId)||!r||!['score','draw','forfeit','aborted','cancelled'].includes(r.reason)||![null,0,1].includes(r.winner)||!Array.isArray(r.score)||r.score.length!==2||r.score.some((n:any)=>!Number.isInteger(n)||n<0||n>13)||!Number.isFinite(r.seconds)||r.seconds<0||r.seconds>90)reject();
  return {result:value(await admin.rpc('cr_online_finish',{p_server:server.id,p_epoch:b.epoch,p_match:b.matchId,p_result:{reason:r.reason,winner:r.winner,score:r.score,seconds:r.seconds}}))};
 }
 if(b.action==='online-check-sessions'){
  if(!Array.isArray(b.participants)||b.participants.length>64||b.participants.some((p:any)=>!uuid(p.ticketId)||!uuid(p.userId)))reject();
  if(!b.participants.length)return {invalid:[]};
  const rows=value<any[]>(await admin.from('cr_online_tickets').select('id,user_id,session_id').in('id',b.participants.map((p:any)=>p.ticketId)).eq('server_id',server.id).eq('consumed_epoch',b.epoch));
  const invalid=[];
  for(const p of b.participants){const t=rows.find((row:any)=>row.id===p.ticketId&&row.user_id===p.userId);if(!t||!value(await admin.rpc('cr_session_valid',{p_user:t.user_id,p_session:t.session_id})))invalid.push(p.userId);}
  return {invalid};
 }
 reject();
}
