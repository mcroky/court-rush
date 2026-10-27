import { readFileSync, writeFileSync, copyFileSync, mkdirSync, statSync } from 'node:fs';
import { resolve, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
const root = resolve(import.meta.dirname, '..');
const output = resolve(root, process.argv[2] || 'build/web');
if(!output.startsWith(root+sep))throw Error('Build output must stay in the project');
mkdirSync(output, { recursive: true });
const exported = readFileSync(resolve(output, 'game.html'), 'utf8');
const match = exported.match(/const GODOT_CONFIG = (\{.*\});/);
if (!match) throw new Error('Godot export config not found. Export Web before running this script.');
const config = JSON.parse(match[1]);
for(const name of ['wardrobe.css','wardrobe-locales.js'])copyFileSync(resolve(root,'site',name),resolve(output,name));
for(const name of ['online-config.js','online.js','online.css','online-locales.js','online-ranking.js','online-rooms.js'])copyFileSync(resolve(root,'site',name),resolve(output,name));
writeFileSync(resolve(output, 'engine-config.js'), `window.UF_ENGINE_CONFIG = ${JSON.stringify(config)};\n`);
for (const name of ['index.html','style.css','app.js','motion-lab.html','motion-lab.js','character-lab.html','character-lab.js','career.css','career.js','career-config.js','language.css','locales.js','i18n.js','info-locales.js','privacy.html','updates.json']) copyFileSync(resolve(root,'site',name),resolve(output,name));
writeFileSync(resolve(output,'career-rules.js'),readFileSync(resolve(root,'site/career-rules.mjs'),'utf8').replaceAll('./wardrobe-catalog.mjs','./wardrobe-catalog.js'));
copyFileSync(resolve(root,'site/wardrobe-catalog.mjs'),resolve(output,'wardrobe-catalog.js'));
copyFileSync(resolve(root, 'icon.svg'), resolve(output, 'icon.svg'));
const total = ['game.wasm', 'game.pck', 'game.js'].reduce((sum, name) => sum + statSync(resolve(output, name)).size, 0);
console.log(`Web shell ready: ${output} (${(total/1024/1024).toFixed(1)} MiB engine + assets, uncompressed)`);
let compressed=0;
for(const name of ['game.wasm','game.pck','game.js']) {
  const gzip=gzipSync(readFileSync(resolve(output,name)),{level:9});
  writeFileSync(resolve(output,name+'.gz'),gzip);compressed+=gzip.length;
}
console.log(`Compressed engine + assets: ${(compressed/1024/1024).toFixed(1)} MiB`);
