import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const files=['index.html','style.css','app.js','motion-lab.html','motion-lab.js','character-lab.html','character-lab.js','career.css','career.js','career-config.js','language.css','locales.js','i18n.js','info-locales.js','privacy.html','updates.json','career-rules.mjs'];
const normalize=value=>value.replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
for(const name of files){
 const source=normalize(execFileSync('git',['show',`HEAD:site/${name}`],{cwd:root,encoding:'utf8'}));
 const built=normalize(readFileSync(resolve(root,'build/web',name==='career-rules.mjs'?'career-rules.js':name),'utf8'));
 if(source!==built)throw Error(`Release blocked: build/web/${name} differs from committed source. Rebuild the reviewed commit first.`);
}
console.log(`RELEASE_FILES: ${files.length} shell files match committed source`);
if(process.argv[2]&&!readFileSync(resolve(root,'build/web/index.html'),'utf8').includes(`v${process.argv[2]}`))throw Error('Release version does not match the built shell');
