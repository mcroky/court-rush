(function(){
 const i18n=window.CourtI18n;
 const help={
 en:['Find your rhythm.',[
  'W+D or A+Shoot together: within 3.5 m, a hook shot; add a direction away from the hoop, or shoot farther out, for a fadeaway. Hold Shoot for at least 0.18 seconds. On touchscreens, hold the existing Drive and Shoot buttons together.',
  'Arrow keys / left stick: move in screen directions. D / Shoot: hold to gather, jump and release. Tap under 0.18 seconds for a pump fake.',
  'Release D during the green window (0.36–0.50 seconds) for a timing bonus. Distance and defensive pressure still affect the result.',
  'Drive within 3 m and press D for a layup. Nearer the rim (1.85 m) you can dunk; within 1.05 m, a standing dunk is possible. Check the D · DUNK cue. Behind the basket, you take a normal shot.',
  'After gathering with both hands, your dribble is over. Use the arrows to pivot and D to shoot. Use direction inputs for a planted pivot or jab step. After the dribble ends, A is a pivot fake, Z a turn fake, C an up-and-under, V a held-ball through-the-legs fake and X a pump fake. D still shoots; a short tap pump-fakes. Within 3 m after a fake, hold a direction toward the hoop plus Shoot for a step-through layup; neutral, sideways or away plus Shoot takes a standing shot. These moves never restart the dribble.',
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
  'W+D、またはA+シュートを同時押し：3.5m以内はフックシュート。ゴールと逆方向を加えるか、遠い位置ではフェイダウェイ。シュートは0.18秒以上押してください。タッチ操作も既存のドライブとシュートを同時に押します。',
  '矢印キー／左スティック：画面基準で移動。D／シュート長押し：ボールを集めて跳び、リリース。0.18秒未満の短押しでシュートフェイク。',
  '緑の区間（0.36〜0.50秒）でDを離すとタイミングボーナス。距離と守備の圧力により失敗することもあります。',
  '走って3m以内に入りDでレイアップ。さらに近い1.85m以内ではダンク、正面1.05m以内ならその場ダンクも可能です。D · DUNK表示を確認。ゴール裏では通常シュートです。',
  '両手で持つとドリブル終了。方向入力で軸足を保つピボット・ジャブステップ。Aピボット、Zターン、Cアップアンドアンダー、V股下の持球フェイク、Xポンプフェイク。Dシュート、短押しはフェイクです。フェイク後3m以内でゴール方向＋シュートは一歩踏み込むレイアップ、方向なし・横・逆方向＋シュートはその場シュートです。ドリブルは再開しません。',
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
  "假动作后3米内，朝篮筐方向＋投篮为跨步上篮；不按方向、侧向或背离方向＋投篮为原地投篮，不会重新运球。",
  '同时按W+D或A+投篮：3.5米内为勾手；加上背离篮筐的方向，或在更远处使用，则为后仰跳投。投篮键按住至少0.18秒。触屏使用现有突破与投篮按钮同时按住。',
  '方向键／左侧摇杆：按屏幕方向移动。按住 D／投篮：收球、起跳并出手；轻点不足 0.18 秒可做投篮假动作。',
  '在绿色区间（0.36–0.50 秒）松开 D 可获得时机加成，距离和防守压力仍会影响命中。',
  '跑动切入距篮筐 3 米内按 D 上篮；更近的 1.85 米内可扣篮，正前方 1.05 米内也可原地扣篮。请看 D · DUNK 提示，篮筐后方为普通投篮。',
  '双手收球后运球结束。方向输入为保留中枢脚的转身或试探步。A转身假动作、Z转体假动作、C上下假动作、V持球胯下假动作、X投篮假动作。D投篮，短按为假投；不会重新运球。',
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
 en:['Open up the stride.','v0.8.10 · Full-body running and dribble counter-swing',[
  "Airborne feet now travel with the advancing body before following the original running swing. Removed the extra short safety step, connected longer plants and larger arm swings, and preserved ball contact for the dribbling hand. The opposite arm follows the running clip. Stopping after a skill still returns to a standing stance.",
  "v0.8.9 · Running and recovery after dribble moves",
  "A longer reaching stride and higher heel recovery preserve more of the original running clip. Fixed crossed legs on the entry screen. After a dribble move, stopping now returns each foot to a standing stance; continuing to move keeps the run flowing.",
  "v0.8.8 · Running rhythm and shooting-arm recovery",
  "Matched the running clip to alternating foot contacts, removed the extra launch step and improved the first strides. After a wing three, the guide hand lowers first while the shooting arm holds its wrist follow-through, then recovers. Running shot gathers also bring the trailing foot in more smoothly.",
  "v0.8.7",
  "Held-ball fakes now take 0.30–0.50 seconds, with quicker recovery into the next fake, shot or pass and a short input buffer. Within 3 m after a fake, direction toward the hoop plus Shoot gives a step-through layup; neutral, sideways or away plus Shoot takes a standing shot. No new dribble; hook and fadeaway combinations remain.",
  "v0.8.6",
  "Larger ball and shoulder threats with readable holds and counters; shoe squeaks follow planted pivot and jab contacts. W+D or Drive+Shoot adds a close hook, or a fadeaway with input away from the hoop. Moving turnaround shots continue rotating in the air. Loose balls can be secured on body/hand contact from their first bounce.",
  "v0.8.5",
  'Removed the panel covering the court with defender-switch instructions, a duplicate switch button and current-player details. E, the contextual bottom touch switch and the selected-player ring remain. Controls are still available in Help.',
  'v0.8.4 · Turnaround shots & held-ball fakes:',
  'When shooting while moving away from the hoop or sideways, plant, load the pivot foot, turn the body and receive the other foot before lifting the ball. Refined the sudden release-time turn and the knee transition back into running.',
  'After the dribble ends, use direction inputs for a pivot or jab step. A: pivot fake; Z: turn fake; C: up-and-under; V: held-ball through-the-legs fake; X: pump fake. Keep the pivot foot and possession without restarting a dribble. D shoots; a short tap pump-fakes.',
  'The same moves work for the selected player in AI 3v3, with passing after a fake. Mobile buttons change with ball possession. Character Studio includes six close-up fake previews. Pausing cancels a queued turnaround shot and keeps the ball in hand.',
  'v0.8.3 · Shot recovery & team flow:',
  'Shots now align the face, torso and arms toward the hoop. Follow through with a wrist snap, lower the arms, land and push off into the next run.',
  'AI 3v3 adds a dedicated defender-switch button and the current player role and slot. E cycles all three defenders, including loose-ball play. Off-ball teammates cut, screen, roll and relocate, clearing the paint for a drive.',
  'W adds at most 10 cm of frontal contact. It adds no range against flank or rear drives, or while a defender recovers from a feint.',
  'Reduced court, ball and team-view rendering costs. Fullscreen stutter can still occur on some devices; further performance work remains.',
  'v0.8.2 · Running shots and arm alignment:',
  'Running pull-ups now recover one foot and close the other before takeoff. Fixed crossed legs after sideways or backward runs, carried the last closing step through quick shots, and connected the trailing-foot push-off to the jump.',
  'The guide arm now supports the ball in front of the face instead of flaring beside the head. Elbows stack below the palms, the hands follow the head during turns, and the upper body settles into the shot. Character Studio adds a Running pull-up loop.',
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
 ja:['腕から足先まで、大きく走る。','v0.8.10・全身の走りとドリブルの逆腕',[
  "浮いた足が体の前進に追いついてから元の走りの軌道をたどり、前足が後ろに残る動きを修正。短い補正ステップを除き、長い接地と大きな腕振りを接続しました。ドリブルする手はボールとの接触を保ち、逆の腕は走りのクリップに従います。技の後に止まれば立ち姿に戻ります。",
  "v0.8.9・走りとドリブル技の後の立ち姿",
  "前足を伸ばし、後ろのかかとを高く回収する元クリップの走りを活かしました。開始画面で脚が交差する問題を修正。ドリブル技の後に止まると片足ずつ立ち姿へ戻り、移動を続ければそのまま走ります。",
  "v0.8.8・走る足運びとシュート後の腕の回収",
  "走りのクリップと左右の接地を同じリズムにし、出だしで同じ足が再び浮く動作を修正。45度のスリー後はガイドの手を先に下げ、シュート側は手首のフォロースルーを保ってから回収します。走りからシュートへ後ろ足を寄せる動作も調整しました。",
  "v0.8.7",
  "持球フェイクを0.30〜0.50秒に短縮。回収中から次のフェイク・シュート・パスへつながり、短い先行入力も受け付けます。フェイク後3m以内でゴール方向＋シュートは踏み込むレイアップ、方向なし・横・逆方向＋シュートはその場シュート。再ドリブルせず、フックとフェイダウェイの組合せも維持します。",
  "v0.8.6",
  "ボールと肩を大きく動かすフェイク、見せる間と切り返し、軸足の接地に合わせた靴の摩擦音。W+Dまたはドライブ＋シュートでゴール下フック、逆方向入力でフェイダウェイ。移動中のターンシュートは空中まで回転が続き、最初のバウンドから体や手に触れたルーズボールを確保します。",
  "v0.8.5",
  'コートを覆っていた守備切替ボタン・操作説明・選手情報のパネルを削除しました。Eキー、画面下の状況別タッチ切替、操作選手の足元リングは維持。操作方法はヘルプで確認できます。',
  'v0.8.4・振り向きシュートと持球フェイク：',
  'リングと反対方向や横に走ってから打つとき、接地して軸足に荷重を移し、体を回して反対の足を受けてからボールを上げます。リリース直前に急旋回する動作と、走りへ戻る際の膝の跳ねを調整しました。',
  'ドリブル終了後は方向入力でピボット・ジャブステップ。Aピボット、Zターン、Cアップアンドアンダー、V股下の持球フェイク、Xポンプフェイク。軸足と持球を維持し、ドリブルは再開しません。Dでシュート、短押しでポンプフェイク。',
  'AI3対3の操作選手とフェイク後のパスにも対応。モバイルボタンは持球状態に合わせて切り替わり、スタジオに6種類の拡大プレビューを追加。中断時は予約シュートを取り消し、ボールを保持します。',
  'v0.8.3・シュート後の回復とチームの動き：',
  '顔・胴体・腕をリングへ向け、手首のフォロースルーから腕の回収、着地、次の走り出しまでつなぎました。',
  'AI3対3に守備切替ボタンと操作選手のポジション・順番表示を追加。Eで3人全員を切り替えられ、ルーズボール時も使用可能。味方はカット・スクリーン・ロール・再配置を続け、ドライブ時はゴール下を空けます。',
  'Wの追加接触は正面のみ最大10cm。横や後ろへの突破、フェイント後に体勢を戻す間は追加範囲がありません。',
  'コート・ボールとチーム画面の描画負荷を軽減。端末によって全画面の引っかかりは残るため、引き続き改善します。',
  'v0.8.2・移動シュートと腕の姿勢：',
  '横・後ろへ走ってからシュートすると脚が交差する不具合を修正。回収する足と引き寄せる足を順につなぎ、素早いリリースでも最後の一歩を踏み切り前に完了。後ろの足で押し出す動作も調整しました。',
  '補助の腕が頭の横に開かず、顔の前でボールを支えるように肘と前腕を整列。ターン中も手が頭の動きに追従し、上体の構えと肘の回収を調整。スタジオに「ランニングからシュート」を追加しました。',
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
 'zh-CN':['舒展手臂，迈开大步。','v0.8.10 · 全身跑动与运球时的反侧摆臂',[
  "腾空的脚先随身体前进，再衔接原始跑步轨迹，修复前腿落在身体后方的问题。移除多余的小补步，衔接更长的支撑与更大的摆臂。运球手保持接触篮球，另一只手跟随跑步动画。技能后停下仍会恢复正常站姿。",
  "v0.8.9 · 跑动与运球技能后的站姿恢复",
  "保留原始跑步动作中前脚伸出、后脚跟抬起回收的幅度。修复开始画面双腿交叉的问题。运球技能后停下时会逐脚恢复站姿；继续移动时则流畅衔接跑步。",
  "v0.8.8 · 跑动节奏与投篮手臂回收",
  "将跑步动画与左右脚落地节奏统一，修复起步时同一只脚再次抬起的问题。45度三分出手后，辅助手先下落，投篮手保持压腕随挥后再收回，同时改善跑动收球时后脚跟进的衔接。",
  "v0.8.7",
  "持球假动作缩短为0.30—0.50秒，回收阶段即可衔接下一次假动作、投篮或传球，并保留短暂提前输入。假动作后3米内，朝篮筐方向＋投篮为跨步上篮；不按方向、侧向或背离方向＋投篮为原地投篮。不重新运球，勾手及后仰组合保持不变。",
  "v0.8.6",
  "加大球和肩部的假动作，加入展示停顿及反向回收，并按轴心脚和试探步落地时机播放鞋底摩擦声。W+D或突破+投篮为近距离勾手，加背离篮筐方向为后仰。移动转身投篮继续在空中旋转；活球从第一次弹起就可在身体或手接触时拿到。",
  "v0.8.5",
  '移除了遮挡球场的防守切换按钮、操作说明和当前球员信息面板。保留E键、底部情境触屏切换按钮以及脚下选中光圈，操作方法仍可在帮助中查看。',
  'v0.8.4 · 转身投篮与持球假动作：',
  '背向篮筐或横向移动后投篮时，先落脚、将重心移到中枢脚、转动身体，再接住另一只脚并抬球。调整出手前突然转身和投篮后恢复跑动时的膝部跳动。',
  '停球后用方向输入转身或试探步。A转身假动作、Z转体假动作、C上下假动作、V持球胯下假动作、X投篮假动作。保持中枢脚和持球，不会重新运球。D投篮，短按为假投。',
  '支持AI3对3当前控制球员和假动作后传球。手机按钮随持球状态切换，角色工作室新增6种放大预览。暂停时取消待执行的转身投篮并保持持球。',
  'v0.8.3 · 投篮恢复与团队跑位：',
  '投篮时脸部、躯干和手臂朝向篮筐，衔接压腕随球、收臂、落地缓冲，再由支撑脚蹬地恢复跑动。',
  'AI3对3新增防守切换按钮和当前球员位置、序号。E可轮换三名防守球员，争抢空中球时也可切换。无球队友持续空切、掩护、顺下和重新站位，突破时让出篮下空间。',
  'W仅增加正面最多10厘米的接触范围。侧面、背后突破或防守者假动作后恢复重心时不增加范围。',
  '降低球场、篮球和团队画面的渲染开销。部分设备全屏仍可能卡顿，性能将继续改进。',
  'v0.8.2 · 急停跳投与手臂姿势：',
  '修复横向或向后跑动后投篮时双腿交叉的问题。依次收回摆动脚、并入另一只脚，快速出手时也会在起跳前衔接最后一步，并改善后脚蹬地离地的连接。',
  '辅助手臂改为在脸前托球，肘部位于手掌下方，避免前臂向头部侧面张开。转身时双手随头部移动，并调整上身准备及肘部回收。角色工作室新增急停跳投循环预览。',
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
  '目前成长模式为单人 AI 1 对 1 PvE。AI 3 对 3 是独立的无奖励模式。在线对战及移动商店发布为后续计划。服务器校验奖励及点数消费，但不验证每次游戏输入。'
 ]]
 };
 const latest_en=["Grow with your team.", "v0.9.0 · AI 3v3 career & mobile camera", "Start a career team match from My Player. Finish an 11-point or 3-minute game with two AI teammates to earn XP and coins, plus contribution rewards for directly controlled points, assists, rebounds, blocks and steals. Train the same stats and skills and buy clothing with the shared wallet. Regular team matches grant no growth rewards.", "Current career includes AI 1v1 and AI 3v3 PvE. Online competition and a mobile store release remain future work. Server checks cover reward duplication, point spending and result bounds; simulation runs on your device."];
 news["en"][2].unshift(latest_en[2],"Mobile camera zoom now changes continuously when moving far beyond the arc, replacing the old 7% steps.",news["en"][1]);news["en"][0]=latest_en[0];news["en"][1]=latest_en[1];news["en"][2][news["en"][2].length-1]=latest_en[3];
 help["en"][1][help["en"][1].length-2]="My Player offers 8 AI 1v1 courts and AI 3v3 career team matches, sharing XP, stat and skill training and wardrobe coins. Start career team play from My Player. Regular modes and practice grant no growth rewards. Q passes and E switches players in 3v3. Online competition is planned.";
 const latest_ja=["チームで走り、一緒に育つ。", "v0.9.0・AI3対3育成とモバイルカメラ", "マイ選手から育成チーム戦を開始。AI仲間2人と11点または3分で対戦し、完走すると経験値・コインと直接操作した得点・アシスト・リバウンド・ブロック・スティールの貢献報酬を獲得。同じ選手の能力・技術を育成し、共通の財布で衣装を購入できます。通常チーム戦には育成報酬がありません。", "現在の育成はAI1対1とAI3対3のPvE。オンライン対戦とモバイルストア公開は今後の予定です。サーバーは報酬重複・ポイント消費・結果の範囲を検査しますが、試合は端末で実行します。"];
 news["ja"][2].unshift(latest_ja[2],"モバイルで外側へ移動した際の7%刻みのズームをなくし、拡大・縮小を滑らかにつなぎました。",news["ja"][1]);news["ja"][0]=latest_ja[0];news["ja"][1]=latest_ja[1];news["ja"][2][news["ja"][2].length-1]=latest_ja[3];
 help["ja"][1][help["ja"][1].length-2]="マイ選手はAI1対1コート8段階とAI3対3育成チーム戦で経験値・能力・技術・衣装コインを共有。育成チーム戦はマイ選手から開始します。通常モードと練習には育成報酬がありません。3対3はQパス・E選手切替。オンライン対戦は今後の予定です。";
 const latest_zh_CN=["一起上场，一起成长。", "v0.9.0 · AI 3对3成长与手机镜头", "在我的球员页面开启成长团队赛。与两名AI队友完成11分或3分钟的比赛，可获得经验、金币以及直接操作的得分、助攻、篮板、盖帽、抢断贡献奖励。与1对1共用同一球员的属性、技能和衣橱金币。普通团队赛没有成长奖励。", "目前成长包括AI 1对1及AI 3对3 PvE。在线竞技及移动商店发布仍为后续计划。服务器检查重复奖励、点数消费及结果范围，但比赛在设备上模拟。"];
 news["zh-CN"][2].unshift(latest_zh_CN[2],"移动到远离三分线的位置时，手机镜头改为连续缩放，移除了原来的7%阶梯变化。",news["zh-CN"][1]);news["zh-CN"][0]=latest_zh_CN[0];news["zh-CN"][1]=latest_zh_CN[1];news["zh-CN"][2][news["zh-CN"][2].length-1]=latest_zh_CN[3];
 help["zh-CN"][1][help["zh-CN"][1].length-2]="我的球员提供8个AI 1对1球场及AI 3对3成长团队赛，共用经验、属性技能训练和衣橱金币。在我的球员页面开启成长团队赛。普通模式及练习无成长奖励。3对3中Q传球、E切换球员。在线竞技为后续计划。";
 const block_en=["Reach for the block.", "v0.9.1 · Responsive block jumps", "Quick defensive jump taps are kept until the game reads them. A small forward plant helps a frontal contest; the visible palm must still contact the ball to swat it down. Face the shooter between them and the rim as they raise the ball."];
 news["en"][2].unshift(block_en[2],news["en"][1]);news["en"][0]=block_en[0];news["en"][1]=block_en[1];
 const block_ja=["手のひらで止める。", "v0.9.1・ブロック入力と踏み込み", "短い守備ジャンプの入力をゲームが読み取るまで保持。正面では足で少し踏み込み、実際に手のひらがボールに触れたときに下へ叩きます。相手とゴールの間でボールを上げる瞬間にジャンプ。"];
 news["ja"][2].unshift(block_ja[2],news["ja"][1]);news["ja"][0]=block_ja[0];news["ja"][1]=block_ja[1];
 const block_zh_CN=["伸手完成盖帽。", "v0.9.1 · 盖帽输入与正面起跳", "短促的防守起跳输入会保留到游戏读取。正面防守时小幅踏步接近，手掌实际碰到球才向下扇出。站在对手与篮筐之间，在对方举球时起跳。"];
 news["zh-CN"][2].unshift(block_zh_CN[2],news["zh-CN"][1]);news["zh-CN"][0]=block_zh_CN[0];news["zh-CN"][1]=block_zh_CN[1];
 const block_feedback_en=["See the block.", "v0.9.2 · Block and possession feedback", "When someone immediately recovers a blocked ball, the game shows both the block and which team recovered it. Ball-to-body contact still allows an immediate pickup."];
 news["en"][2].unshift(block_feedback_en[2],news["en"][1]);news["en"][0]=block_feedback_en[0];news["en"][1]=block_feedback_en[1];
 const block_feedback_ja=["ブロック成功を見逃さない。", "v0.9.2・ブロックとボールの所有表示", "ブロック直後にボールを取られても、ブロック成功と確保したチームを一緒に表示。ボールが体に触れたらすぐ確保できるルールは維持します。"];
 news["ja"][2].unshift(block_feedback_ja[2],news["ja"][1]);news["ja"][0]=block_feedback_ja[0];news["ja"][1]=block_feedback_ja[1];
 const block_feedback_zh_CN=["让盖帽成功清晰可见。", "v0.9.2 · 盖帽与球权提示", "盖帽后球被立即拿到时，同时显示盖帽成功与获得球权的一方。球碰到身体即可拾取的规则保持不变。"];
 news["zh-CN"][2].unshift(block_feedback_zh_CN[2],news["zh-CN"][1]);news["zh-CN"][0]=block_feedback_zh_CN[0];news["zh-CN"][1]=block_feedback_zh_CN[1];
 const block_readable_en=["Block, then see possession.", "v0.9.3 · Readable block results", "Block success and the team recovering the ball are now displayed in the selected language, including on mobile. Quick defensive jump input and improved frontal reach remain included."];
 news["en"][2].unshift(block_readable_en[2],news["en"][1]);news["en"][0]=block_readable_en[0];news["en"][1]=block_readable_en[1];
 const block_readable_ja=["ブロックから球権まで、一目で。", "v0.9.3・見やすいブロック結果", "ブロック成功とボールを確保したチームを、モバイルでも選択言語で表示。素早い守備ジャンプ入力と正面の踏み込みも引き続き適用します。"];
 news["ja"][2].unshift(block_readable_ja[2],news["ja"][1]);news["ja"][0]=block_readable_ja[0];news["ja"][1]=block_readable_ja[1];
 const block_readable_zh_CN=["盖帽与球权，一眼看清。", "v0.9.3 · 清晰的盖帽结果", "盖帽成功及获得球权的一方会以所选语言显示，手机上也清晰可见。快速防守起跳输入和正面上步改进继续保留。"];
 news["zh-CN"][2].unshift(block_readable_zh_CN[2],news["zh-CN"][1]);news["zh-CN"][0]=block_readable_zh_CN[0];news["zh-CN"][1]=block_readable_zh_CN[1];
 news["en"][2].unshift("The block plant and arm extension start sooner, using the visible skeleton. A rising ball meeting a downward-facing palm now counts as a real block and continues into a swat and landing. Stay close and press D or Block as the opponent raises the ball.",news["en"][1]);news["en"][0]="React to the shot.";news["en"][1]="v0.9.4 · Reactive blocks in 1v1";
 news["ja"][2].unshift("踏み込みと腕の伸展を早め、表示リグで実際に接触判定。下向きの手のひらに上昇中のボールが当たれば、叩き落としから腕の回収と着地につながります。近くで相手がボールを上げる瞬間にDかブロックを押してください。",news["ja"][1]);news["ja"][0]="シュートを見て、ブロック。";news["ja"][1]="v0.9.4・1対1のブロック反応";
 news["zh-CN"][2].unshift("提前起跳蹬地和伸臂，并使用可见骨骼判断接触。上升的球碰到朝下的手掌时也可盖帽，接续下拍、收臂和落地。贴近对手，在其举球时按D或盖帽。",news["zh-CN"][1]);news["zh-CN"][0]="看准出手，起跳封盖。";news["zh-CN"][1]="v0.9.4 · 1对1盖帽反应";
 news["en"][2].unshift("A palm block now sends the ball strongly into an open flank. During the brief strike, touching bodies cannot immediately gather it again. Chase and contest it once it escapes. Applies to 1v1 and 3v3; ordinary rim rebounds remain immediately playable.",news["en"][1]);news["en"][0]="Swat it clear.";news["en"][1]="v0.9.5 · Block, then contest the loose ball";
 news["ja"][2].unshift("手のひらで弾いたボールを空いた横のスペースへ強く飛ばします。打撃直後は体に触れても即座に再取得せず、ボールが離れてから再び争奪します。1対1・3対3共通。通常のリムリバウンドはすぐに取れます。",news["ja"][1]);news["ja"][0]="はっきり弾き出すブロック。";news["ja"][1]="v0.9.5・ブロック後のルーズボール争い";
 news["zh-CN"][2].unshift("手掌盖帽会将球有力地拍向空出的侧面空间。击球瞬间，身体接触不会立即重新拿球；球离开后再争抢。1对1和3对3共同生效。普通打铁篮板仍可立即争抢。",news["zh-CN"][1]);news["zh-CN"][0]="盖帽，把球拍开。";news["zh-CN"][1]="v0.9.5 · 盖帽后争抢球权";
 news["en"][2].unshift("Blocks send the ball firmly away, with a brief escape period before anyone can gather it. The swat favors open court; if the defender sends it out, the shooting team keeps the check ball. Applies to 1v1 and 3v3.",news["en"][1]);news["en"][0]="Swat it clear.";news["en"][1]="v0.9.6 · Block into loose-ball play";
 news["ja"][2].unshift("ブロック直後はボールを強く弾き出し、少し離れてから再び争奪します。空いたコート内の方向を優先し、守備のブロックで外に出た場合は攻撃側のチェックボール。1対1・3対3共通です。",news["ja"][1]);news["ja"][0]="はっきり弾き出すブロック。";news["ja"][1]="v0.9.6・ブロック後のルーズボール争い";
 news["zh-CN"][2].unshift("盖帽会有力地将球拍开，短暂离开身体后才能重新争抢。优先拍向场内的空位；若防守方盖出界，由投篮方继续发球。1对1和3对3均适用。",news["zh-CN"][1]);news["zh-CN"][0]="盖帽，把球拍开。";news["zh-CN"][1]="v0.9.6 · 盖帽后争抢球权";
 news["en"][2].unshift("Players anticipate the bounce, slow down and gather the ball into the chest before resuming the dribble. An out-of-bounds whistle now leads to a visible jog back and ball return instead of teleporting everyone into the next possession. Applies to 1v1 and 3v3.",news["en"][1]);news["en"][0]="Chase it down.";news["en"][1]="v0.9.7 · Loose-ball chase and check ball";
 news["ja"][2].unshift("バウンドを予測して追い、減速して胸に抱え、ドリブルへつなぎます。アウト時は瞬間移動で次の攻撃に切り替えず、選手が位置に戻ってボールを受け取ってから再開します。1対1・3対3共通です。",news["ja"][1]);news["ja"][0]="弾いたボールを最後まで追う。";news["ja"][1]="v0.9.7・ルーズボール追走とチェックボール";
 news["zh-CN"][2].unshift("球员预判弹跳路线、减速并将球收至胸前，再衔接运球。出界后会跑回位置，接球后重新开始，不再瞬间切换到下一次持球画面。1对1与3对3均适用。",news["zh-CN"][1]);news["zh-CN"][0]="追到底，抢回球。";news["zh-CN"][1]="v0.9.7 · 争抢地板球与重新发球";
 news["en"][2].unshift("Find another player in Online 1v1. Keep your appearance with equal attributes and no growth rewards. The server runs the 90-second, first-to-11 match. Initial connections may take time to start the server. One match runs at a time; play continues while menus or other tabs are open.",news["en"][1]);news["en"][0]="Meet on the same court.";news["en"][1]="v0.9.8 · Online 1v1 auto matching";
 news["ja"][2].unshift("オンライン1対1で他のプレイヤーと自動対戦。外見を使い、能力は均等、育成報酬はありません。90秒・11点先取をサーバーが判定します。初回接続は準備に時間がかかる場合があります。1試合ずつ運用し、メニューや別タブを開いても試合は続きます。",news["ja"][1]);news["ja"][0]="同じコートで、オンライン1対1。";news["ja"][1]="v0.9.8・オンライン1対1自動マッチング";
 news["zh-CN"][2].unshift("在线1对1自动匹配其他玩家。使用现有外观，属性公平，无成长奖励。服务器判定90秒、先得11分的比赛。首次连接可能需要等待服务器启动。目前每次运行一场，打开菜单或其他标签页时比赛仍会继续。",news["zh-CN"][1]);news["zh-CN"][0]="同一球场，在线1对1。";news["zh-CN"][1]="v0.9.8 · 在线1对1自动匹配";
 news["en"][2].unshift("Play with your saved appearance, position, physique, trained attributes and skills. Create or join public rooms and both press Ready, join private practice with an 8-character code, or use auto matching. Public rooms and auto matching count separate online wins, losses, draws and Elo, starting at 1,000 with K=32. Private practice does not affect records or Elo. No extra XP or coins. One 90-second, first-to-11 match runs at a time.",news["en"][1]);news["en"][0]="Your player, your place on the court.";news["en"][1]="v0.10.0 · Rooms and online rankings";
 news["ja"][2].unshift("保存した外見・ポジション・体格・育成能力と技術で対戦。公開ルームの作成・一覧からの参加、両者の準備で開始。非公開練習は8文字コードで参加し、自動対戦も利用できます。公開・自動対戦は別の勝敗・引き分けとEloに反映、初期1,000点・K=32。非公開練習は戦績・点数に反映されません。追加経験値・コインなし。90秒・11点先取、1試合ずつ運用します。",news["ja"][1]);news["ja"][0]="育てた選手で、同じコートへ。";news["ja"][1]="v0.10.0・対戦ルームとオンラインランキング";
 news["zh-CN"][2].unshift("使用已保存的外观、位置、体格、成长属性及技能参赛。创建或从列表加入公开房，双方准备后开赛；私人练习通过8位代码进入，也保留自动匹配。公开房及自动匹配记录独立在线胜负、平局与Elo，初始1,000分、K=32。私人练习不计战绩或积分，无额外经验或金币。90秒、先得11分，目前每次运行一场。",news["zh-CN"][1]);news["zh-CN"][0]="带上培养的球员，一起上场。";news["zh-CN"][1]="v0.10.0 · 对战房与在线排名";
 news["en"][2].unshift("Choose a public room from the list and press Join. Public rooms do not create or display codes. Use codes only for private practice with friends; the code field is under Join a friend’s room by code. Public rooms and auto matching still count records and Elo; private practice does not.",news["en"][1]);news["en"][0]="Join public rooms straight from the list.";news["en"][1]="v0.10.1 · Public rooms and friend invites";
 news["ja"][2].unshift("公開ルームは一覧から選んで参加。コードの作成・表示はありません。友達との非公開練習のみコードを使い、入力欄は友達のルームにコードで参加を開くと表示されます。公開・自動対戦の戦績とElo、非公開練習の対象外ルールは維持します。",news["ja"][1]);news["ja"][0]="公開ルームは一覧から直接参加。";news["ja"][1]="v0.10.1・公開ルームと友達招待";
 news["zh-CN"][2].unshift("公开房直接从列表选择并加入，不创建或显示代码。仅与好友进行私人练习时使用代码，展开通过代码加入好友房间即可输入。公开房及自动匹配仍计战绩与Elo，私人练习不计入。",news["zh-CN"][1]);news["zh-CN"][0]="公开房直接从列表加入。";news["zh-CN"][1]="v0.10.1 · 公开房与好友邀请";
 news["en"][2].unshift("Reduced unnecessary bone snapshots, temporary arrays and hidden detail updates. Matching finger poses and transforms within the same frame are reused. Running, dribbling, foot plants, shots, blocks and rebounds keep the same update cadence and contact timing. System load can still cause stutter; this does not guarantee a fixed FPS on every device.",news["en"][1]);news["en"][0]="Same moves. Less repeated work.";news["en"][1]="v0.10.2 · 3v3 motion processing";
 news["ja"][2].unshift("不要な全身ボーンのコピー、一時配列、非表示の装飾更新を削減。同じ指の姿勢とフレーム内の変換を再利用します。走り・ドリブル・足の接地・シュート・ブロック・リバウンドの更新周期と接触タイミングを維持します。端末の負荷による停止は残る場合があります。",news["ja"][1]);news["ja"][0]="同じ動き、重複計算を軽く。";news["ja"][1]="v0.10.2・3対3のモーション処理最適化";
 news["zh-CN"][2].unshift("减少不必要的全身骨骼复制、临时数组及隐藏装饰更新，复用相同的手指姿势和帧内变换。跑动、运球、落脚、投篮、盖帽和篮板保持原有更新节奏与接触时机。系统负载仍可能造成卡顿，并不保证所有设备的固定帧率。",news["zh-CN"][1]);news["zh-CN"][0]="动作保持，减少重复计算。";news["zh-CN"][1]="v0.10.2 · 3对3动作处理优化";
 news["en"][2].unshift("Reduced recurring engine work on the Online 1v1 server while keeping 60Hz authoritative decisions and 20Hz state delivery. Contact poses, appearance, trained attributes and record/Elo settlement are unchanged. Packet arrival intervals and round-trip delay are measured to check online stutter.",news["en"][1]);news["en"][0]="Less overhead on the online court.";news["en"][1]="v0.10.3 · Online server processing";
 news["ja"][2].unshift("オンライン1対1サーバーの反復処理を削減。60Hz判定と20Hz状態配信、手とボールの接触・モーション・外見・育成能力・戦績/Eloを維持します。状態の到着間隔と往復遅延を測定して途切れを確認しています。",news["ja"][1]);news["ja"][0]="オンラインコートの処理負担を軽く。";news["ja"][1]="v0.10.3・オンラインサーバー処理";
 news["zh-CN"][2].unshift("减少在线1对1服务器的重复引擎处理，保持60Hz判定与20Hz状态传输。手与球接触、动作、外观、成长属性及战绩/Elo结算保持不变。测量状态到达间隔与往返延迟，检查在线卡顿。",news["zh-CN"][1]);news["zh-CN"][0]="减轻在线球场的处理负担。";news["zh-CN"][1]="v0.10.3 · 在线服务器处理";
 i18n.infoHTML=source=>{
  const lang=i18n.locale,isHelp=source.includes('GET INTO YOUR RHYTHM'),isNews=source.includes('COURT NOTES');
  if(lang==='ko'||!isHelp&&!isNews)return source;
  const data=isHelp?help[lang]:news[lang],items=isHelp?data[1]:data[2];
  const heading=isHelp?'CONTROLS / COURT RUSH':data[1];
  return `<span class="eyebrow">${heading}</span><h2>${data[0]}</h2><ul>${items.map(item=>`<li>${item}</li>`).join('')}</ul>`+(isNews?`<p><a href="privacy.html" target="_blank" rel="noopener">${i18n.text('계정·저장 안내 ↗')}</a></p><p>Godot Engine · MIT. Rig & base clips: GDQuest / Luciano Muñoz · CC BY 4.0. <a href="https://github.com/mcroky/court-rush/blob/main/CHANGELOG.md" target="_blank" rel="noopener">${{en:'Full release history (Korean)',ja:'過去の更新履歴（韓国語）','zh-CN':'完整更新记录（韩语）'}[lang]} ↗</a></p>`:'');
 };
})();
