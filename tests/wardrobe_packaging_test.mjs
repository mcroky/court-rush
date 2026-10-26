import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const text=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8').replace(/\r\n/g,'\n');
for(const name of ['index.html','career.js','wardrobe.css','wardrobe-locales.js','locales.js','i18n.js','privacy.html'])assert.equal(text('build/web/'+name),text('site/'+name),name+' is stale');
assert.equal(text('build/web/career-rules.js'),text('site/career-rules.mjs').replaceAll('./wardrobe-catalog.mjs','./wardrobe-catalog.js'));
assert.equal(text('build/web/wardrobe-catalog.js'),text('site/wardrobe-catalog.mjs'));
const html=text('build/web/index.html');assert.ok(html.indexOf('wardrobe-locales.js')<html.indexOf('src="i18n.js"'));
assert.match(html,/href="wardrobe.css"/);assert.match(text('export_presets.cfg'),/include_filter="assets\/data\/wardrobe.json"/);
console.log('WARDROBE_PACKAGING: catalog, translations, shader-data inclusion and current web shell match source');
