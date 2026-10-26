// Original authored clothing and headwear. Additive IDs, no existing price changes.
import {readFileSync,writeFileSync} from 'node:fs';
const path=new URL('../assets/data/wardrobe.json',import.meta.url),c=JSON.parse(readFileSync(path,'utf8'));
const add=item=>{const old=c.items.find(i=>i.id===item.id);if(old){if(old.price!==item.price)throw Error('Price change: '+item.id);Object.assign(old,item);}else c.items.push(item);};
const collection=(id,names)=>{const old=c.collections.find(i=>i.id===id),entry={id,name:names[0],names,unlock:0};if(old)Object.assign(old,entry);else c.collections.push(entry);};
collection('street_forms',['스트리트 실루엣','Street Silhouettes','ストリートシルエット','街头剪影']);
collection('headwear',['헤드웨어 클럽','Headwear Club','ヘッドウェアクラブ','帽饰俱乐部']);
collection('barber',['코트 바버숍','Court Barbershop','コートバーバーショップ','球场理发店']);
for(const item of c.items)if(!item.form)item.form={jersey:'jersey',shorts:'shorts',shoes:'hightop'}[item.slot]||'none';
const palettes=[
 [['블랙','Black','ブラック','黑色'],'303b44','586779','e9ddbd'],
 [['애시','Ash','アッシュ','灰色'],'9ba4a4','273f44','eee9d4'],
 [['포레스트','Forest','フォレスト','森林'],'2b6859','1c3435','dec7a1'],
 [['버건디','Burgundy','バーガンディ','酒红'],'783c53','3d2e42','dec39c']
];
for(const [form,slot,title,price,unlock] of [
 ['tee','jersey',['크루넥 반팔','Crewneck Tee','クルーネックTシャツ','圆领短袖'],130,0],
 ['hoodie','jersey',['코트 후드티','Court Hoodie','コートパーカー','球场连帽衫'],260,0],
 ['varsity','jersey',['바시티 재킷','Varsity Jacket','バーシティジャケット','棒球夹克'],380,1],
 ['joggers','shorts',['테크 조거','Tech Joggers','テックジョガー','机能束脚裤'],180,0],
 ['cargo','shorts',['카고 팬츠','Cargo Pants','カーゴパンツ','工装长裤'],240,0]
])palettes.forEach(([color,base,panel,accent],index)=>{const names=title.map((t,lang)=>`${t} · ${color[lang]}`);add({id:`form_${form}_${index+1}`,slot,name:names[0],names,collection:'street_forms',form,unlock:unlock+index,tier:index>1?3:2,price:price+index*50,base,panel,accent,pattern:0});});
const neutral=(id,slot,name,names,form,base)=>add({id,slot,name,names,collection:slot==='hat'?'headwear':'barber',form,unlock:0,tier:1,price:0,base,panel:base,accent:'dec7a1',pattern:0});
neutral('hat_none','hat','모자 없음',['모자 없음','No Hat','帽子なし','不戴帽子'],'none','303b44');
neutral('hair_original','hair','기본 스윕 헤어',['기본 스윕 헤어','Original Sweep','オリジナルスイープ','经典侧扫发型'],'original','20282b');
c.defaults.hat='hat_none';c.defaults.hair='hair_original';
for(const [form,title,price] of [
 ['cap',['플랫 캡','Flat Cap','フラットキャップ','平檐棒球帽'],110],
 ['cap_back',['백워드 캡','Backward Cap','バックワードキャップ','反戴棒球帽'],150],
 ['beanie',['리브 비니','Ribbed Beanie','リブビーニー','罗纹针织帽'],140],
 ['bucket',['버킷햇','Bucket Hat','バケットハット','渔夫帽'],180]
])palettes.slice(0,3).forEach(([color,base,panel,accent],index)=>{const names=title.map((t,lang)=>`${t} · ${color[lang]}`);add({id:`hat_${form}_${index+1}`,slot:'hat',name:names[0],names,collection:'headwear',form,unlock:index,tier:2,price:price+index*40,base,panel,accent,pattern:0});});
for(const [form,title,price,unlock] of [
 ['buzz',['페이드 버즈컷','Fade Buzz Cut','フェードバズカット','渐层寸头'],160,0],
 ['curly',['텍스처 컬리','Textured Curls','テクスチャカール','纹理卷发'],220,1],
 ['locs',['미디엄 드레드','Medium Locs','ミディアムドレッド','中长脏辫'],300,2],
 ['sidepart',['클래식 사이드파트','Classic Side Part','クラシックサイドパート','经典侧分'],180,0],
 ['ponytail',['로우 포니테일','Low Ponytail','ローポニーテール','低马尾'],240,1]
])[[['블랙','Black','ブラック','黑色'],'24282f'],[['브라운','Brown','ブラウン','棕色'],'604333']].forEach(([color,base],index)=>{const names=title.map((t,lang)=>`${t} · ${color[lang]}`);add({id:`hair_${form}_${index+1}`,slot:'hair',name:names[0],names,collection:'barber',form,unlock,tier:2,price:price+index*30,base,panel:base,accent:'d0a361',pattern:0});});
writeFileSync(path,JSON.stringify(c,null,2)+'\n');console.log('Authored forms catalog:',c.items.length,'items; five slots');
