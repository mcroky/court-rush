export class AccountAPI {
  constructor({ url, key, serverKey, serverId }) {
    this.url = url; this.key = key; this.serverKey = serverKey; this.serverId = serverId;
  }
  async call(action, body) {
    const response = await fetch(this.url + '/functions/v1/court-rush', {
      method: 'POST', signal: AbortSignal.timeout(10000),
      headers: { 'Content-Type': 'application/json', apikey: this.key, 'x-court-server-key': this.serverKey },
      body: JSON.stringify({ action, serverId: this.serverId, ...body }),
    });
    if (!response.ok) throw Error(response.status === 401 || response.status === 403 ? 'authentication_failed' : 'account_unavailable');
    return response.json();
  }
  redeem(ticket, requestId, epoch) { return this.call('online-redeem', { ticket, requestId, epoch }); }
  register(room, epoch) { return this.call('online-register', { matchId: room.id, epoch, players: room.members.map(m => ({ userId: m.user.id, ticketId: m.user.ticketId })) }); }
  async finish(room, epoch, result) {
    for(let attempt=0;attempt<3;attempt++){
      try{return await this.call('online-finish', { matchId: room.id, epoch, result });}
      catch(error){if(attempt===2||error.message==='authentication_failed')throw error;await new Promise(resolve=>setTimeout(resolve,500*(attempt+1)));}
    }
  }
  check(members, epoch) { return this.call('online-check-sessions', { epoch, participants: members.map(m => ({ userId: m.user.id, ticketId: m.user.ticketId })) }); }
}
