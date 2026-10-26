import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {newPlayer,attributes,trainPlayer,rewardPlayer,normalizePlayer,wardrobeOf,buyClothing,equipClothing,WARDROBE_CATALOG as C} from '../site/career-rules.mjs';
const raw=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
assert.deepEqual(C,JSON.parse(raw('assets/data/wardrobe.json')));
assert.equal(raw('site/wardrobe-catalog.mjs'),raw('supabase/functions/court-rush/wardrobe-catalog.mjs'));
assert.equal(raw('site/career-rules.mjs'),raw('supabase/functions/court-rush/rules.mjs'));
assert.equal(new Set(C.items.map(i=>i.id)).size,C.items.length);
assert.equal(C.items.length,94);assert.equal(C.collections.length,9);
for(const collection of C.collections){const pieces=C.items.filter(i=>i.collection===collection.id);assert.equal(pieces.length,9);assert.equal(new Set(pieces.map(i=>i.pattern)).size>=1,true);for(let variant=1;variant<=3;variant++)assert.equal(pieces.filter(i=>i.variant===variant).length,3);}
for(const i of C.items){assert.ok(Object.hasOwn(C.defaults,i.slot));assert.ok(Number.isSafeInteger(i.price)&&i.price>=0);for(const channel of ['base','panel','accent'])assert.match(i[channel],/^[0-9a-f]{6}$/);}
const p=newPlayer('center','옷장선수'),legacy=structuredClone(p);delete legacy.wardrobe;
const migrated=normalizePlayer(legacy);assert.equal(migrated.version,1);assert.equal(migrated.wardrobe.coins,300);assert.equal(legacy.wardrobe,undefined);
assert.deepEqual(normalizePlayer(migrated),migrated);assert.throws(()=>wardrobeOf({...p,wardrobe:{...p.wardrobe,version:2}}));
const bought=buyClothing(p,'sunset_jersey');assert.equal(bought.player.wardrobe.coins,180);assert.equal(p.wardrobe.coins,300);assert.deepEqual(bought.player.wardrobe.equipped,C.defaults);
const retry=buyClothing(bought.player,'sunset_jersey');assert.deepEqual(retry.player,bought.player);assert.equal(retry.receipt.spent,0);
assert.throws(()=>equipClothing(p,'sunset_jersey'));assert.throws(()=>buyClothing(p,'__proto__'));assert.throws(()=>buyClothing(p,{id:'sunset_jersey',price:0}));
const rich={...p,wardrobe:{...p.wardrobe,coins:100000}};
for(const collection of C.collections){const piece=C.items.find(i=>i.collection===collection.id);if(piece.unlock>0)assert.throws(()=>buyClothing(rich,piece.id));const unlocked=buyClothing({...rich,cleared:piece.unlock},piece.id);assert.equal(unlocked.player.wardrobe.coins,100000-piece.price);}
const dressed=equipClothing(bought.player,'sunset_jersey');assert.equal(dressed.wardrobe.equipped.jersey,'sunset_jersey');assert.equal(dressed.wardrobe.equipped.shorts,'court_navy');
const {appearance:a,...nakedStats}=attributes(p),{appearance:b,...dressedStats}=attributes(dressed);assert.deepEqual(nakedStats,dressedStats);
assert.deepEqual(trainPlayer(dressed,'stat','speed').wardrobe,dressed.wardrobe);
const win=rewardPlayer(dressed,1,true);assert.equal(win.reward.coins,120);assert.equal(win.player.wardrobe.coins,300);assert.equal(win.player.wardrobe.equipped.jersey,'sunset_jersey');
assert.equal(rewardPlayer(win.player,1,true).reward.coins,45);assert.equal(rewardPlayer(dressed,1,false).reward.coins,20);
const poor={...p,wardrobe:{...p.wardrobe,coins:0}};assert.throws(()=>buyClothing(poor,'volt_jersey'));assert.equal(buyClothing(poor,'court_teal').receipt.spent,0);
const corrupt={...p,wardrobe:{...p.wardrobe,owned:['invented'],equipped:{jersey:'sunset_jersey',shorts:'court_teal',shoes:'invented'}}};assert.deepEqual(wardrobeOf(corrupt).equipped,C.defaults);
assert.match(raw('supabase/functions/court-rush/index.ts'),/eq\('user_id',a.user_id\)\.eq\('revision',row.revision\)/);
console.log('WARDROBE_RULES: catalog parity, migration, immutable purchases, idempotency, ownership, insufficient funds, slot validation, cosmetics-only, training and career coin rewards passed');
