// Authored collections: three coordinated colorways, three separately owned pieces.
// Re-running preserves all original IDs and never changes an existing purchase price.
import {readFileSync,writeFileSync} from 'node:fs';
const path=new URL('../assets/data/wardrobe.json',import.meta.url),catalog=JSON.parse(readFileSync(path,'utf8'));
const previousPrices=new Map(catalog.items.map(item=>[item.id,item.price]));
const collections=[
 ['local',['로컬 리그','Local League','ローカルリーグ','街区联赛'],0,180,1,4,[
  [['포레스트','Forest','フォレスト','森林'],'2c7055','f2dfb4','d99853'],[['버건디','Burgundy','バーガンディ','勃艮第'],'823e55','ead8b4','d8ac6a'],[['로열','Royal','ロイヤル','皇家蓝'],'3859a1','ece1bd','d9aa51']]],
 ['asphalt',['아스팔트 크루','Asphalt Crew','アスファルトクルー','沥青街队'],1,280,2,5,[
  [['차콜','Charcoal','チャコール','炭灰'],'343b48','d6c7ae','ee8751'],[['샌드','Sand','サンド','沙色'],'b89f7e','49473e','f5e5bb'],[['러스트','Rust','ラスト','锈红'],'ac583e','403b43','ecd5af']]],
 ['metro',['메트로 라인','Metro Line','メトロライン','都市线路'],2,420,2,2,[
  [['코발트','Cobalt','コバルト','钴蓝'],'244a9b','192d53','85d7ea'],[['레일','Rail','レール','轨道'],'63778a','273d50','f1d280'],[['체리','Cherry','チェリー','樱桃'],'b64668','542d58','f7d9c1']]],
 ['coast',['코스트 웨이브','Coast Wave','コーストウェーブ','海岸浪潮'],3,560,2,3,[
  [['라군','Lagoon','ラグーン','泻湖'],'43b3ac','246977','f7e5b7'],[['코랄','Coral','コーラル','珊瑚'],'e9856a','a5507b','fff0c8'],[['마린','Marine','マリン','海蓝'],'437cb6','84cdd0','f5e5b2']]],
 ['retro',['레트로 체커','Retro Checker','レトロチェッカー','复古棋盘'],4,760,3,6,[
  [['머스터드','Mustard','マスタード','芥末'],'c99b44','4b3d42','f5dfaa'],[['플럼','Plum','プラム','梅紫'],'795178','d3a789','f8e1b5'],[['민트','Mint','ミント','薄荷'],'75b49c','315961','f1e4bd']]],
 ['neon',['네온 나이트','Neon Night','ネオンナイト','霓虹之夜'],5,980,3,7,[
  [['라임','Lime','ライム','青柠'],'263343','a7df58','d5f58d'],[['바이올렛','Violet','バイオレット','紫罗兰'],'433761','bc86dc','e4c9ed'],[['사이버','Cyber','サイバー','赛博'],'283b51','49c8d9','dbefec']]],
 ['circuit',['서킷 러너','Circuit Runner','サーキットランナー','赛道疾驰'],6,1250,3,5,[
  [['레이싱','Racing','レーシング','竞速'],'b7463a','f0d5ad','2b4250'],[['옥탄','Octane','オクタン','辛烷'],'e89c42','33434d','f3deb1'],[['아크틱','Arctic','アークティック','极地'],'d4e6e5','3d7186','d95e4c']]],
 ['skyline',['스카이라인','Skyline','スカイライン','城市天际'],7,1580,4,8,[
  [['트와일라잇','Twilight','トワイライト','暮光'],'4b548b','b983b1','f6c797'],[['선라이즈','Sunrise','サンライズ','日出'],'db8359','b84e67','f3d9a9'],[['스톰','Storm','ストーム','风暴'],'526276','89a8b5','e6dcb8']]],
 ['crown',['크라운 클럽','Crown Club','クラウンクラブ','王冠俱乐部'],8,2100,4,1,[
  [['블랙 골드','Black Gold','ブラックゴールド','黑金'],'273139','a6824f','f5d188'],[['아이보리 골드','Ivory Gold','アイボリーゴールド','象牙金'],'e9dfbf','947044','4a3b39'],[['크림슨 골드','Crimson Gold','クリムゾンゴールド','绯红金'],'8d3546','c59a55','f2db9c']]]
];
const kinds=[['jersey',['저지','Jersey','ジャージ','球衣']],['shorts',['쇼츠','Shorts','ショーツ','短裤']],['shoes',['하이탑','High-Tops','ハイカット','高帮鞋']]];
const authored=new Set(collections.map(c=>c[0]));
catalog.items=catalog.items.filter(i=>!authored.has(i.collection)).map(i=>i.collection?i:{...i,collection:'original',unlock:0,tier:1});
catalog.collections=[...(catalog.collections||[]).filter(c=>!authored.has(c.id)),...collections.map(([id,names,unlock])=>({id,name:names[0],names,unlock}))];
for(const [id,title,unlock,cost,tier,pattern,palettes] of collections)for(let variant=0;variant<3;variant++){
 const [color,base,panel,accent]=palettes[variant];
 for(let slot=0;slot<3;slot++){
  const [kind,kindNames]=kinds[slot],names=title.map((name,lang)=>`${name} · ${color[lang]} ${kindNames[lang]}`);
  catalog.items.push({id:`${id}_${variant+1}_${kind}`,slot:kind,name:names[0],names,collection:id,variant:variant+1,unlock,tier,price:Math.round((cost+[0,-40,60][slot]+variant*45)/10)*10,base:slot===1?panel:base,panel:slot===1?base:panel,accent,pattern:slot===0?pattern:slot===1?[1,2,3,4,5,6,7,8,2][unlock]:[1,2,3,4,5,6,7,8,4][unlock]});
 }
}
for(const item of catalog.items)if(previousPrices.has(item.id)&&previousPrices.get(item.id)!==item.price)throw Error('Existing item prices are immutable; use a new item ID: '+item.id);
writeFileSync(path,JSON.stringify(catalog,null,2)+'\n');
console.log('Expanded wardrobe:',catalog.items.length,'items across',collections.length,'new collections');
