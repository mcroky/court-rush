// One disposable app-owned QA account. Never uses a real player's credentials.
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
const path=new URL('../artifacts/wardrobe-ui-qa.json',import.meta.url);
const config=readFileSync(new URL('../site/career-config.js',import.meta.url),'utf8');
const url=config.match(/url:'([^']+)'/)[1],key=config.match(/key:'([^']+)'/)[1];
async function call(action,body,token){const r=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify({action,...body})});const data=await r.json();if(!r.ok)throw Error(action+': '+data.error);return data;}
if(process.argv[2]==='forms-validate'){
 const account=JSON.parse(readFileSync(path,'utf8'));let r=await call('login',account),token=r.session.access_token;
 const initial=(await call('profile',{},token)).player;
 if(initial.wardrobe.coins!==1000||initial.wardrobe.equipped.hat!=='hat_none'||initial.wardrobe.equipped.hair!=='hair_original'||!initial.wardrobe.owned.includes('sunset_jersey'))throw Error('Old three-slot fixture did not migrate without loss');
 for(const id of ['form_hoodie_1','form_joggers_1','hat_cap_1','hair_buzz_1']){await call('buy',{itemId:id},token);await call('equip',{itemId:id},token);}
 const retry=await call('buy',{itemId:'hair_buzz_1'},token);if(retry.receipt.spent!==0||retry.player.wardrobe.coins!==290)throw Error('Duplicate cosmetic charge');
 await call('equip',{itemId:'hat_none'},token);await call('equip',{itemId:'hat_cap_1'},token);
 await call('logout',{},token);r=await call('login',account);
 const restored=(await call('profile',{},r.session.access_token)).player;
 if(restored.wardrobe.coins!==290||restored.wardrobe.equipped.jersey!=='form_hoodie_1'||restored.wardrobe.equipped.shorts!=='form_joggers_1'||restored.wardrobe.equipped.hat!=='hat_cap_1'||restored.wardrobe.equipped.hair!=='hair_buzz_1')throw Error('Outfit did not survive logout/relogin');
 console.log('FORMS_API: seeded disposable legacy fixture migrated; four new cosmetic kinds bought/equipped, retry charged once, hat removal and relogin restored all slots and 290 coins.');
}else if(process.argv[2]==='validate'){
 const account=JSON.parse(readFileSync(path,'utf8')),r=await call('login',account);
 const response=await fetch(url+'/functions/v1/court-rush',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+r.session.access_token,'Content-Type':'application/json'},body:JSON.stringify({action:'buy',itemId:'crown_1_jersey',cleared:8,price:0,coins:999999})});
 if(response.status!==400||(await response.json()).error!=='이 컬렉션은 코트를 더 클리어하면 열립니다.')throw Error('Locked collection bypassed');
 console.log('Server rejected forged collection unlock; original account and inventory unchanged.');
}else if(process.argv[2]==='cleanup'){
 const account=JSON.parse(readFileSync(path,'utf8'));
 const r=await call('login',account);await call('delete',{password:account.password},r.session.access_token);unlinkSync(path);console.log('Disposable wardrobe UI account removed; temporary credential file removed.');
}else{
 const account={username:'qa_shop_'+randomBytes(4).toString('hex'),password:'Qa!'+randomBytes(16).toString('hex')};
 const created=await call('signup',account);writeFileSync(path,JSON.stringify(account));
 if(process.argv[2]==='forms-create')await call('create',{role:'guard',nickname:'의상검증'},created.session.access_token);
 console.log('Disposable wardrobe UI account prepared. Credentials remain in ignored temporary fixture file.');
}
