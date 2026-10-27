import { resolve } from 'node:path';
import { AccountAPI } from './auth.mjs';
import { Worker } from './worker.mjs';
import { Gateway } from './server.mjs';

const root = resolve(import.meta.dirname, '../..');
for (const name of ['CR_SUPABASE_URL', 'CR_SUPABASE_KEY', 'CR_ONLINE_SERVER_KEY', 'CR_SERVER_ID', 'GODOT_BIN']) {
  if (!process.env[name]) throw Error('Missing server configuration: ' + name);
}
const worker = new Worker({ binary: process.env.GODOT_BIN, root, port: Number(process.env.CR_WORKER_PORT || 32091), exported: process.env.CR_EXPORTED === '1' });
const auth = new AccountAPI({ url: process.env.CR_SUPABASE_URL, key: process.env.CR_SUPABASE_KEY, serverKey: process.env.CR_ONLINE_SERVER_KEY, serverId: process.env.CR_SERVER_ID });
const gateway = new Gateway({ auth, worker, origins: (process.env.CR_ALLOWED_ORIGINS || 'https://mcroky.github.io,http://127.0.0.1:8791,http://127.0.0.1:8793').split(',') });
await auth.call('online-boot', { epoch: gateway.epoch });
await gateway.listen(Number(process.env.PORT || 8792), '0.0.0.0');
worker.start();
console.log('Court Rush online gateway listening');
const stop = async () => { gateway.draining = true; gateway.abort('server_shutdown'); setTimeout(async () => { await gateway.close(); worker.close(); process.exit(0); }, 4000).unref(); };
process.on('SIGTERM', stop); process.on('SIGINT', stop);
