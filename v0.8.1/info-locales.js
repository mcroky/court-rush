(function(){
 const i18n=window.CourtI18n;
 const help={
 en:['Find your rhythm.',[
  'Arrow keys / left stick: move in screen directions. D / Shoot: hold to gather, jump and release. Tap under 0.18 seconds for a pump fake.',
  'Release D during the green window (0.36–0.50 seconds) for a timing bonus. Distance and defensive pressure still affect the result.',
  'Drive within 3 m and press D for a layup. Nearer the rim (1.85 m) you can dunk; within 1.05 m, a standing dunk is possible. Check the D · DUNK cue. Behind the basket, you take a normal shot.',
  'After gathering with both hands, your dribble is over. Use the arrows to pivot and D to shoot. You cannot move or restart a dribble with A/Z/C/V/X.',
  'A: crossover. Z: spin. C: two-step drive while dribbling. V: behind-the-back change. X: hesitation. Combine each with a direction; let it finish before chaining the next move.',
  'On defense, D jumps for a block or rebound. Time the palm swat to the shot; chase the deflected ball. Approach a low loose ball to pick it up.',
  'S: step toward the ball and reach for a steal. Your hand must contact the ball; success is not guaranteed. Recover your arm if the attempt fails.',
  'Hold W for a low defensive stance and short lateral steps. After a shot, get between the opponent and rim and hold W to box out. Use D to catch the descending ball. An opponent who goes around you escapes the box-out.',
  '1v1: first to 11 or 90 seconds. If tied, the next score wins. After a defensive rebound or steal, clear the ball beyond the arc before attacking.',
  'Esc pauses or resumes. Switching tabs, opening information or changing language pauses the game. Close the menu and select Resume to continue.',
  'My Player has 8 AI courts with server-saved XP, stats and skills. Practice and regular 1v1 grant no growth rewards. This is solo PvE; online competition and 3v3 are planned.',
  'On a phone, landscape is recommended. Use the left stick and right action buttons. A small timing rail appears beside Shoot only while preparing a shot.'
 ]],
 ja:['まずは、自分のリズムを。',[
  '矢印キー／左スティック：画面基準で移動。D／シュート長押し：ボールを集めて跳び、リリース。0.18秒未満の短押しでシュートフェイク。',
  '緑の区間（0.36〜0.50秒）でDを離すとタイミングボーナス。距離と守備の圧力により失敗することもあります。',
  '走って3m以内に入りDでレイアップ。さらに近い1.85m以内ではダンク、正面1.05m以内ならその場ダンクも可能です。D · DUNK表示を確認。ゴール裏では通常シュートです。',
  '両手で持つとドリブル終了。矢印でピボットしDでシュートします。移動やA/Z/C/V/Xでの再ドリブルはできません。',
  'A：クロスオーバー、Z：スピン、C：ドリブル中のツーステップ、V：ビハインド、X：ヘジテーション。方向キーと組み合わせ、動作が終わってから次へつなぎます。',
  '守備中のD：ブロックまたはリバウンド。シュートに合わせて手のひらで叩き、弾いたボールを追います。低いルーズボールは近づくと拾えます。',
  'S：ボールに向かって短く踏み込み、手を伸ばしてスティール。実際の手の接触が必要で、必ず成功するわけではありません。失敗したら手を戻して守備へ。',
  'W長押し：低い姿勢で短いサイドステップ。シュート後は相手とリムの間に入り、Wでボックスアウト。落ちるボールをDでキャッチ。相手に回り込まれると解除されます。',
  '1対1は11点先取または90秒。同点なら次の得点で決着。守備リバウンド・スティールの後は外側のラインを出てから攻撃します。',
  'Escで停止・再開。タブ移動、案内表示、言語変更でも一時停止します。メニューを閉じて「再開」を押してください。',
  'マイ選手はAIコート8段階で経験値・能力・スキルを育成しサーバー保存。練習と通常の1対1に育成報酬はありません。育成はソロPvEです。AI3対3は報酬なしで遊べます（Qパス・E切替）。オンライン対戦は今後の予定です。',
  'スマートフォンは横向き推奨。左スティックと右のアクションボタンで操作。シュート準備中だけ、ボタン脇の小さなゲージを表示します。'
 ]],
 'zh-CN':['找到你的节奏。',[
  '方向键／左侧摇杆：按屏幕方向移动。按住 D／投篮：收球、起跳并出手；轻点不足 0.18 秒可做投篮假动作。',
  '在绿色区间（0.36–0.50 秒）松开 D 可获得时机加成，距离和防守压力仍会影响命中。',
  '跑动切入距篮筐 3 米内按 D 上篮；更近的 1.85 米内可扣篮，正前方 1.05 米内也可原地扣篮。请看 D · DUNK 提示，篮筐后方为普通投篮。',
  '双手收球后运球结束。方向键可转身调整，D 投篮；不可继续移动，也不能用 A/Z/C/V/X 再次运球。',
  'A：交叉变向，Z：转身运球，C：运球中的两步突破，V：背后换手，X：犹豫步。配合方向键，等动作结束后再衔接下一招。',
  '防守时 D 起跳盖帽或抢板。对准出手时机用手掌扇盖，再追弹出的球。靠近地面的低位球可直接拾取。',
  'S：向持球侧上步伸手抢断。手必须实际碰到球，并非每次都成功；失败后收手回防。',
  '按住 W 进入低姿防守，以短促横移跟防。投篮后站到对手与篮筐之间，按住 W 卡位，再按 D 接下落的球。对手绕到侧面后卡位解除。',
  '1 对 1 先得 11 分或限时 90 秒；平分时下一次得分决胜。防守篮板或抢断后，须先将球带出外线再进攻。',
  'Esc 暂停或继续。切换标签页、查看说明及更改语言时也会暂停。关闭菜单后选择继续游戏。',
  '“我的球员”包含 8 个 AI 球场，经验、属性与技能保存在服务器。练习及普通 1 对 1 不发成长奖励。目前为单人 PvE，AI 3 对 3 无奖励（Q传球、E切换）。在线对战留待后续。',
  '手机建议横屏。使用左侧摇杆和右侧动作按钮，仅在准备投篮时于投篮按钮旁显示细小计时条。'
 ]]
 };
 const news={
 en:['Push off. Land soft. Play your style.','v0.8.1 · Jump shots & clothing shapes',[
  'Jump shots now connect knee loading, forefoot push-off, airborne ankle extension and knee movement, then forefoot landing and impact absorption. Pump fakes keep the loaded pose without snapping upright.',
  '138 cosmetic items across five slots: tops, bottoms, shoes, hats and hair. New T-shirts, hoodies, varsity jackets, joggers and cargo pants use actual skinned shapes. Four hat shapes and six hair shapes including the original, hat-fit hair, shape filters and existing purchase records are supported.',
  'v0.8.0 · 94 clothing items: 32 jerseys, 31 shorts and 31 shoes. Buy and equip individual pieces with court coins. Nine new themes, court-clear unlocks, matching outfit previews, rotation and ownership filters. Clothing is cosmetic and saved with your account.',
  'Start with 300 coins. Career 1v1 first clears earn 120–260 coins, repeat wins 45–80 and losses 20. Practice, casual 1v1 and AI 3v3 give no rewards. AI 3v3 adds two teammates, Q passing and E defender switching. Refined sideways ball-carrying arm and wrist poses are also included.',
  'v0.7.6 · Fixed downward blocks rejected during upward takeoff, early-shot block selection while holding Guard, and the strike direction after a turn. Touch labels now distinguish Block from Rebound.',
  'v0.7.5 · Defense: short alternating side steps, planted transitions from pursuit into a low stance, and smoother arm and shoulder recovery. Height-aware support fixes foot sliding for shorter guards. Character Studio adds low stance, defensive slides and box-out previews.',
  'Fixed foot and knee snaps when stopping or entering blocks and rebounds. Reduced repeated torso and shoulder corrections, refined the rebound-to-dribble handoff and relaxed the free hand. Unchanged HUD text now skips redundant updates.',
  '27 original English voice calls react to baskets, dribble skills, blocks and airborne rebounds. Choose one of 3 original instrumental tracks or rotate them. Separate music, commentary and effects volumes; music dips during commentary. The mobile left stick sits higher for easier reach.',
  'Mobile now follows the player at a closer distance. The large shot panel is replaced by a small timing rail beside Shoot, shown only during shot preparation. A smaller scoreboard keeps the court clear.',
  'Choose Korean, English, Japanese or Simplified Chinese. Menus, career, account flows, match hints and help follow your selection, which is saved on this device.',
  'v0.7.0: ID/password accounts without email, recovery codes and account deletion; Guard 178 cm, Forward 190 cm and Center 204 cm; eight AI courts with saved XP and stat/skill training.',
  'Current career is solo AI 1v1 PvE. AI 3v3 is a separate mode without rewards. Online competition and a mobile store release are future work. The server checks rewards and point spending, but does not verify every gameplay input.'
 ]],
 ja:['踏み切って、自分らしく。','v0.8.1・ジャンプシュートと新しいウェア形状',[
  '膝で荷重を受け、前足部で踏み切り、空中で足首と膝を動かして、前足部から着地し衝撃を吸収するシュートへ調整。短いフェイクでも準備姿勢から急に跳ね上がらないようにしました。',
  'トップス・ボトムス・シューズ・帽子・ヘアの5部位で計138項目。Tシャツ・パーカー・バーシティジャケット・ジョガー・カーゴを実際のスキンメッシュで追加。帽子4形状、基本を含むヘア6形状、帽子用ヘア・形状フィルターと購入記録の引き継ぎに対応。',
  'v0.8.0 · トップス32・ショーツ31・シューズ31、計94点。コートコインで部位別に購入・着用。新規9テーマ、コート進行による解放、一式試着・回転・所持フィルターを追加。能力値には影響せずアカウントに保存されます。',
  '初期300コイン。育成1対1の初クリア120〜260、再勝利45〜80、敗北20。練習・通常1対1・AI3対3は報酬なし。AI仲間2人との3対3、Qパス・E守備切替、横から見た持球時の腕と手首の調整も公開します。',
  'v0.7.6 · 上昇中に腕を振り下ろしてもブロックが無効になる不具合、守備を押しながらのシュート直後の選択、方向転換後の打撃方向を修正。タッチ表示もブロックとリバウンドを区別します。',
  'v0.7.5 · 守備：左右の足を交互に運ぶ短いサイドステップ、追走から接地して低く構える動作、腕と肩の回収を調整。身長に合わせた脚の計算で、小柄なガードの足滑りも修正しました。キャラクタースタジオに低い守備・左右のステップ・ボックスアウトを追加しました。',
  '急停止・ブロック・リバウンドへの移行時に足や膝が跳ねる不具合を修正。胴体と肩の補正の重複を減らし、リバウンドからドリブルへ戻る手と反対の手の姿勢を調整しました。同じ試合表示の不要な更新も省きました。',
  '得点・ドリブル技・ブロック・空中リバウンドに英語実況27本を追加。オリジナルBGM3曲を選択または順番再生でき、音楽・実況・効果音の音量を個別に調節できます。実況中は音楽を下げます。モバイルの左スティックを上に移動しました。',
  'モバイルは選手に近い追従カメラへ。大きなシュートパネルを廃止し、準備中だけボタン脇の小さなゲージを表示。スコア表示も小さくしました。',
  '韓国語・英語・日本語・簡体字中国語を選択可能。メニュー・育成・アカウント・試合案内・操作説明に適用し、この端末に保存します。',
  'v0.7.0：メール不要のID登録・復旧コード・アカウント削除。ガード178cm、フォワード190cm、センター204cm。AIコート8段階と経験値・能力・スキルのサーバー保存。',
  '現在の育成はソロAI 1対1 PvEです。AI3対3は報酬なしの別モードです。オンライン対戦・モバイルストア公開は今後の予定。サーバーは報酬とポイント消費を検証しますが、すべての試合入力を検証するものではありません。'
 ]],
 'zh-CN':['自然起跳，穿出风格。','v0.8.1 · 投篮起跳与新服装款式',[
  '投篮衔接膝部蓄力、前脚掌蹬地、空中脚踝伸展与屈膝，再以前脚掌落地并吸收冲击。短按假投篮也会延续准备姿态，避免突然弹起。',
  '上衣、下装、鞋、帽子、发型五部位共138项。短袖、连帽衫、棒球夹克、束脚裤及工装裤使用实际蒙皮模型。新增4种帽型、含默认款的6种发型、戴帽适配发型及款式筛选，保留已有购买记录。',
  'v0.8.0 · 共94件：32件球衣、31条短裤、31双球鞋。使用球场金币分别购买装备。新增9个主题、球场通关解锁、整套试穿、旋转、拥有状态筛选和收集进度。服装不影响属性，记录保存在账号中。',
  '初始300金币。成长1对1首通120–260、重复胜利45–80、失败20。练习、普通1对1和AI3对3无奖励。同时发布两名AI队友的3对3、Q传球与E切换防守球员，并调整持球时侧面的手臂和手腕姿势。',
  'v0.7.6 · 修复起跳上升时向下挥掌接触球却被判无效、按住防守时投篮初期误选篮板，以及转向后的封盖方向。触屏按钮区分盖帽和篮板。',
  'v0.7.5 · 防守：调整双脚交替的小幅横移、追防后落脚进入低姿防守的衔接，以及手臂与肩部的回收。按身高计算腿部支撑，修复较矮后卫的脚底滑动。角色工作室新增低姿防守、横向滑步和卡位三种预览。',
  '修复急停、盖帽及篮板动作开始时脚和膝盖突然跳动的问题，减少躯干和肩部的重复修正，调整抢到篮板后恢复运球的手部衔接及另一只手的放松姿势。同时减少相同比赛文字的不必要刷新。',
  '新增27段原创英语解说，响应得分、运球技能、盖帽及空中篮板。3首原创背景音乐可单曲或轮换播放，音乐、解说及音效音量可分别调节，解说时音乐会降低。手机左摇杆已上移。',
  '手机镜头更近地跟随球员。移除大型投篮提示框，仅在收球准备时于投篮按钮旁显示细条，并缩小比分牌以留出视野。',
  '可选择韩语、英语、日语、简体中文。菜单、球员成长、账号流程、比赛提示及操作说明随之切换，选择保存在本设备。',
  'v0.7.0：无需邮箱的账号密码注册、恢复码及账号删除；178cm 后卫、190cm 前锋、204cm 中锋；8 个 AI 球场、经验及属性技能训练，进度保存在服务器。',
  '目前成长模式为单人 AI 1 对 1 PvE。在线对战、3 对 3 及移动商店发布为后续计划。服务器校验奖励及点数消费，但不验证每次游戏输入。'
 ]]
 };
 i18n.infoHTML=source=>{
  const lang=i18n.locale,isHelp=source.includes('GET INTO YOUR RHYTHM'),isNews=source.includes('COURT NOTES');
  if(lang==='ko'||!isHelp&&!isNews)return source;
  const data=isHelp?help[lang]:news[lang],items=isHelp?data[1]:data[2];
  const heading=isHelp?'CONTROLS / COURT RUSH':data[1];
  return `<span class="eyebrow">${heading}</span><h2>${data[0]}</h2><ul>${items.map(item=>`<li>${item}</li>`).join('')}</ul>`+(isNews?`<p><a href="privacy.html" target="_blank" rel="noopener">${i18n.text('계정·저장 안내 ↗')}</a></p><p>Godot Engine · MIT. Rig & base clips: GDQuest / Luciano Muñoz · CC BY 4.0. <a href="https://github.com/mcroky/court-rush/blob/main/CHANGELOG.md" target="_blank" rel="noopener">${{en:'Full release history (Korean)',ja:'過去の更新履歴（韓国語）','zh-CN':'完整更新记录（韩语）'}[lang]} ↗</a></p>`:'');
 };
})();
