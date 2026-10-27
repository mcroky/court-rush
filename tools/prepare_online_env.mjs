// Creates deployment secrets only in the ignored server/.env; never prints the secret.
import { randomBytes, createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const root = resolve(import.meta.dirname, '..'), path = resolve(root, 'server/.env');
if (!existsSync(path)) {
  const config = readFileSync(resolve(root, 'site/career-config.js'), 'utf8');
  const url = config.match(/url:'([^']+)'/)[1], key = config.match(/key:'([^']+)'/)[1];
  const secret = randomBytes(32).toString('hex');
  writeFileSync(path, `CR_SUPABASE_URL=${url}\nCR_SUPABASE_KEY=${key}\nCR_ONLINE_SERVER_KEY=${secret}\nCR_SERVER_ID=court-rush-online-free\nCR_ALLOWED_ORIGINS=https://mcroky.github.io,http://127.0.0.1:8791\nGODOT_BIN=/app/godot\nCR_EXPORTED=1\n`, { mode: 0o600 });
}
const secret = readFileSync(path, 'utf8').match(/^CR_ONLINE_SERVER_KEY=(.+)$/m)[1];
console.log(JSON.stringify({ serverId: 'court-rush-online-free', keyHash: createHash('sha256').update(secret).digest('hex') }));
