// Read-only checks against the deployed static files and anonymous Auth boundary.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const version=process.argv[2];
const build=resolve(import.meta.dirname,'..',process.argv[3]||'build/web');
assert.match(version||'',/^\d+\.\d+\.\d+$/);
const base='https://mcroky.github.io/court-rush/';
const assetBase=base+'v'+version+'/';
const normalize=s=>s.replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
async function get(url,options={}){const r=await fetch(url,{cache:'no-store',signal:AbortSignal.timeout(45000),...options});assert.equal(r.status,200,url+' status');return r;}
const entry=await get(base),html=await entry.text();
assert.equal(new URL(entry.url).pathname,'/court-rush/');
assert.ok(html.includes('<base href="./v'+version+'/">'),'Root has an older asset base');
assert.ok(html.includes('v'+version),'Root has an older visible version');
const notes=await (await get(base+'updates.json')).json();assert.equal(notes[0].version,version);
const names=['career.js','career-rules.js','wardrobe-catalog.js','wardrobe-locales.js','wardrobe.css','app.js','locales.js','i18n.js','info-locales.js','engine-config.js'];
names.push('online-config.js','online.js','online-rooms.js','online-ranking.js','online.css','online-locales.js');
await Promise.all(names.map(async name=>{
 const response=await get(assetBase+name),text=await response.text();
 assert.equal(normalize(text),normalize(readFileSync(resolve(build,name),'utf8')),'Stale public '+name);
 if(name.endsWith('.js'))assert.match(response.headers.get('content-type'),/javascript/);
}));
const catalogText=await (await get(assetBase+'wardrobe-catalog.js')).text();
const catalog=JSON.parse(catalogText.match(/export const WARDROBE_CATALOG = ([\s\S]+);\s*$/)[1]);
const localCatalog=JSON.parse(readFileSync(new URL('../assets/data/wardrobe.json',import.meta.url),'utf8'));
assert.equal(catalog.items.length,localCatalog.items.length);assert.equal(catalog.collections.length,localCatalog.collections.length);
const digest=buffer=>createHash('sha256').update(buffer).digest('hex');
const pck=Buffer.from(await (await get(assetBase+'game.pck')).arrayBuffer());
assert.equal(digest(pck),digest(readFileSync(resolve(build,'game.pck'))),'Stale public Godot pack');
const wasm=await get(assetBase+'game.wasm',{method:'HEAD'});assert.match(wasm.headers.get('content-type'),/wasm/);
const config=readFileSync(new URL('../site/career-config.js',import.meta.url),'utf8');
const endpoint=config.match(/url:'([^']+)'/)[1],key=config.match(/key:'([^']+)'/)[1];
const anonymous=await fetch(endpoint+'/functions/v1/court-rush',{method:'POST',headers:{Origin:'https://mcroky.github.io',apikey:key,'Content-Type':'application/json'},body:JSON.stringify({action:'profile'}),signal:AbortSignal.timeout(20000)});
assert.equal(anonymous.status,401);assert.equal(anonymous.headers.get('access-control-allow-origin'),'https://mcroky.github.io');
console.log(JSON.stringify({version,stableURL:base,items:catalog.items.length,collections:catalog.collections.length,matchedAssets:names.length,pckSHA256:digest(pck),anonymousProfile:anonymous.status,latestUpdate:notes[0].title},null,2));
