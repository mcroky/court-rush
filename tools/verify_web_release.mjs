import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const build=resolve(root,process.argv[3]||'build/web');
const files=['index.html','style.css','app.js','motion-lab.html','motion-lab.js','character-lab.html','character-lab.js','career.css','career.js','career-config.js','language.css','locales.js','i18n.js','info-locales.js','privacy.html','updates.json','career-rules.mjs','wardrobe.css','wardrobe-locales.js','wardrobe-catalog.mjs'];
const normalize=value=>value.replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
files.push('online-config.js','online.js','online.css','online-locales.js');
for(const name of files){
 let source=normalize(execFileSync('git',['show',`HEAD:site/${name}`],{cwd:root,encoding:'utf8'}));
 if(name==='career-rules.mjs')source=source.replaceAll('./wardrobe-catalog.mjs','./wardrobe-catalog.js');
 const built=normalize(readFileSync(resolve(build,name.endsWith('.mjs')?name.replace('.mjs','.js'):name),'utf8'));
 if(source!==built)throw Error(`Release blocked: build/web/${name} differs from committed source. Rebuild the reviewed commit first.`);
}
console.log(`RELEASE_FILES: ${files.length} shell files match committed source`);
if(process.argv[2]&&!readFileSync(resolve(build,'index.html'),'utf8').includes(`v${process.argv[2]}`))throw Error('Release version does not match the built shell');
