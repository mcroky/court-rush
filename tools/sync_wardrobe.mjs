import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
const catalog=JSON.parse(readFileSync(new URL('assets/data/wardrobe.json',root),'utf8'));
const module='// Generated from assets/data/wardrobe.json by tools/sync_wardrobe.mjs.\nexport const WARDROBE_CATALOG = '+JSON.stringify(catalog,null,2)+';\n';
for(const path of ['site/wardrobe-catalog.mjs','supabase/functions/court-rush/wardrobe-catalog.mjs'])writeFileSync(new URL(path,root),module);
const labels=[...(catalog.collections||[]),...catalog.items].filter(i=>i.names).map(i=>i.names);
writeFileSync(new URL('site/wardrobe-locales.js',root),'// Generated wardrobe translations. Load after locales.js.\nwindow.CourtMessages.push(...'+JSON.stringify(labels)+');\n');
console.log('Wardrobe catalog synchronized: '+catalog.items.length+' items');
