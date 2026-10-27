// Separate local QA server identity: never boot or replace the production epoch.
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {randomBytes,createHash} from 'node:crypto';
const path=new URL('../server/.env.rank-qa',import.meta.url);
if(!existsSync(path)){
 const source=readFileSync(new URL('../site/career-config.js',import.meta.url),'utf8');
 const url=source.match(/url:'([^']+)'/)[1],key=source.match(/key:'([^']+)'/)[1];
 writeFileSync(path,`CR_SUPABASE_URL=${url}\nCR_SUPABASE_KEY=${key}\nCR_ONLINE_SERVER_KEY=${randomBytes(32).toString('hex')}\nCR_SERVER_ID=court-rush-ranking-qa\nCR_ALLOWED_ORIGINS=http://127.0.0.1:8791\nPORT=8792\nCR_WORKER_PORT=32122\nCR_EXPORTED=0\n`,{mode:0o600});
}
const secret=readFileSync(path,'utf8').match(/^CR_ONLINE_SERVER_KEY=(.+)$/m)[1];
console.log(JSON.stringify({serverId:'court-rush-ranking-qa',keyHash:createHash('sha256').update(secret).digest('hex')}));
