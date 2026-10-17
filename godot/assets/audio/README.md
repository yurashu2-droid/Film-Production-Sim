# ゲームのSE

ネット上の無料素材を選び、ゲームに合わせて加工して使用する。作者・配布元・利用条件・加工内容は音ごとに残す。

## カチンコ

- 配布元：[Kenney / Impact Sounds 1.0](https://kenney.nl/assets/impact-sounds)
- 作者：Kenney
- ライセンス：CC0（同梱・加工可能）。配布元の License.txt は `godot/licenses/Kenney-Impact-Sounds.txt`。
- 元ファイル：`impactWood_light_001.ogg` と `impactWood_medium_001.ogg`
- 加工：モノラル22,050Hz化、軽い木の打撃を主音に中程度の打撃を4ms遅らせて重ねる。低域を控えめにし、0.22秒で余韻をフェードアウト。ピークは約−2.4dBFS。
- 出力：`clapper_wood.wav`（試聴用）、同じPCMを収めた `clapper_wood.tres`（Godot用）。インポートの有無に依存せず実行・書き出しできる。
- 使用箇所：開始演出、本番開始・カットのカチンコ。

## 物を扱う音（掴む・置く・どすん・積む・固定・門・段差）

- 配布元・作者・ライセンス：カチンコと同じ（Kenney / Impact Sounds 1.0、CC0）。
- 作り方：`godot/tools/build_sfx.gd` を実行すると、素材を読んで加工し、`godot/assets/audio/sfx/` に書き出す。
  素材の配布物は `tools/diagnostics/kenney_impact/` に展開して使う（リポジトリには入れない）。
  試聴用の wav は `tools/diagnostics/sfx_preview/` に出る。
- 共通の加工：モノラル44,100Hz、頭の無音を詰める、音量をそろえる、余韻をフェードアウト。
  どの音も素材の別テイクから3〜5種類作り、鳴らすたびに1つ選んで高さを±6%ずらす（`scripts/sfx.gd`）。

| 音 | 元ファイル（末尾の番号違いで別テイク） | 加工 |
|---|---|---|
| pickup 掴む | impactGeneric_light | 高さ1.18倍、180Hz以下を削る、0.17秒 |
| drop 置く | impactWood_medium ＋ impactSoft_medium | 木を主音に、柔らかい当たりを低く（0.8倍・900Hz以上を削る）重ねる |
| thump どすん | impactSoft_heavy ＋ impactWood_heavy ＋ impactPunch_heavy | それぞれ0.6〜0.78倍に下げ、高域を削って重ねる |
| load 荷台に積む | impactPlank_medium ＋ impactPlate_light | 板を主音に、鉄板の響きを小さく重ねる |
| fix 固定 | impactMetal_light ×2 | 1.5倍と1.85倍に上げ、85ms空けて2回鳴らす |
| unfix 固定を外す | impactTin_medium | 高さ1.1倍、300Hz以下を削る |
| gate 門 | impactMetal_heavy ＋ impactPlate_heavy ＋ impactTin_medium ×2 | 鉄を0.62倍に下げ、金網の震えを0.11秒・0.2秒遅らせて重ねる |
| bump 段差 | impactPunch_heavy ＋ impactPlate_medium ＋ impactPlank_medium ＋ impactTin_medium ＋ impactWood_light | 車体の底を打つ低い音に、荷台のがたつきを少しずつ遅らせて重ねる |

## まだ合成音のままの音

BGM。それ以外も、下の効果音ラボの音が無い環境では合成音で鳴る（爆発、怪獣の鳴き声、カウントダウンなど）。

## 効果音ラボの素材から作った音（公開リポジトリには入れない）

- 配布元：[効果音ラボ](https://soundeffect-lab.info/)（利用規約：https://soundeffect-lab.info/agreement/ 、2026-10-11 に確認）
- 利用条件の要点：無料・商用可・クレジット任意・加工可。アプリやゲームへの組み込みは可。
  ただし**素材そのものや加工したものの再配布は禁止**、AI学習用データとしての利用も禁止。
- そのため、素材（`tools/diagnostics/soundeffect_lab/`）も、加工後の音（`godot/assets/audio/sfx_local/`）も
  `.gitignore` で公開リポジトリから外している。別のPCで作業するときは、素材を配布元から取り直して
  `godot/tools/build_sfx.gd` を実行する。素材が無い環境では、上の Kenney の音か、コードの合成音で鳴る。
- ゲームを配布するときは、音を取り出して使うための物にしないこと（規約の「再配布」に当たる）。
- 共通の加工：モノラル44,100Hz、頭の無音を詰める、音量をそろえる、余韻をフェードアウト。
  完成された音なので、切る・重ねる・高さを少し変える程度にとどめている。

| 音 | 元ファイル | 加工 |
|---|---|---|
| explosion 爆発（2種） | bomb4 / bomb3 ＋ big-explosion1 | ドカーンを主音に、大爆発の低い余韻（900Hz以上を削る）を重ねる |
| explosion_fizzle 不発 | matchstick-failure1 ＋ pafu1 | しけったマッチに、気の抜けたラッパ（0.84倍）を0.12秒遅らせて重ねる |
| fuse 導火線（3種） | matchstick-failure1 | 頭の0.16秒の「シュッ」を、高さ 1.0／1.22／0.86倍で3つ。燃えている間、細かく鳴らしてパチパチに聞かせる（耳ではまだ確かめていない） |
| roar 怪獣の鳴き声（2種） | dragon-cry1 / dragon-cry2 ＋ monster-footstep1 | 鳴き声に、足音の低い響き（300Hz以上を削る）をうっすら重ねる |
| thump どすん（3種） | real-down1、stick-fall1、firewood-put1 | そのまま／0.88倍＋棒の落ちる音／薪を0.8倍 |
| drop 置く（3種） | brick1、bucket-put1、firewood-put2 | 余韻を整えるだけ |
| pickup 掴む（3種） | grap1 | 高さ 1.0／1.12／0.92倍 |
| load 荷台に積む（2種） | firewood-put1 / firewood-put2 ＋ iron-plate2 | 薪を置く音に、薄い鉄板の響きを小さく重ねる |
| fix 固定（2種）・unfix | decision31、decision50、decision44 | 頭の0.3秒を切り出す |
| gate 門 | gate-open1 ＋ iron-door-close1 | きしむ音のあと、1.5秒後に鉄の扉の音 |
| bump 段差（2種） | truck-carrier-door1 ＋ tool-box1 | 荷台扉の音を0.85倍にし、工具のがちゃつきを重ねる |
| engine 出発 | car-engine1 | 頭の3.4秒を切り出す |
| countdown・countdown_go | electronic-countdown1 | 1回ぶんの「プッ」と、最後の「ピー」を切り出す |
| success_fanfare 成功 | trumpet1 ＋ people-performance-cheer1 | ラッパのあとに歓声と拍手を重ねる |
| ui_ok・ui_fail・cue | decision34、cancel2、decision38 | 頭を切り出す |

## 体と物の動きの音（足音・着地・風切り）

- 鳴らし方：`godot/scripts/features/motion_sounds.gd`。各自の画面で、見えている動きから決めて鳴らす（通信は増やさない）。
  足音＝左右の足のどちらが低いかが入れ替わった瞬間（歩き・走り・しゃがみ歩き。車輪のロボット M02 は鳴らない）。
  着地＝0.3秒より長く宙にいて降りた時。風切り＝物の速さが0.15秒で4m/秒より上がって7m/秒を超えた時
  （14m/秒より速ければ whoosh、遅ければ whoosh_soft。回る速さは持っている物だけ数える）。確認は `tests/motion_sounds_test.gd`。
- 参考：ゲーム映像（一人称で棒を持って走り回る、12秒）の音を測った。足音＝0.03〜0.04秒の柔らかい低い当たり、走ると0.29秒おき。
  振り＝0.1秒の「ブンッ」（重心 580〜760Hz）。持った物ごと振り向く＝0.3秒の弱い低い風。足音・振り向きは、振りより約20dB小さい。
- 足音は、写実的なアスファルトの足音だと見た目（明るい・角ばった町）から浮いて聞こえたので、4通りを聞き比べて、やわらかい「トッ」に決めた（2026-10-15）。
  足音・着地・振り向きの風切りの音量は、参考どおり振りより20dB小さくすると小さすぎた（遊んでみての判断）。振りより10dBほど小さい大きさにしてある。

効果音ラボの素材から作った音（公開リポジトリには入れない。出力は `sfx_local/`）：

| 音 | 元ファイル | 加工 |
|---|---|---|
| step 足音（6種） | dash-tatami1 ＋ dash-school1 | 畳を走る音から1歩ずつ切り出し、3kHz以上を削る。上履きの当たり（400Hz以下を削る）を0.3倍で重ねる |
| land 着地（3種） | dash-tatami1 ＋ dash-school1 | 畳の重い2歩を0.03秒ずらして重ね（主音は0.9倍）、上履きの当たりを少し足す |
| whoosh 振る（4種） | sword-gesture2、whip-gesture1、punch-real-swing1 | 0.7〜0.8倍に下げ、200〜300Hz以下と0.9〜2.5kHz以上を削る。0.15秒で切る |
| whoosh_soft 振り向く（3種） | punch-real-swing1、kick-real-swing3 | 0.7〜1.15倍、300Hz以下と4kHz以上を削る。0.34秒で切る |

UVI（Prisma の「Whooshes」）から作った風切り（上の効果音ラボの whoosh・whoosh_soft を置き換える。公開リポジトリには入れない。出力は `sfx_local/`）：

- 利用条件：UVI の利用許諾は、商用の作品での使用は追加料金なしで可。音そのもの（加工した物も含む）の単体での再配布・販売は禁止。
  そのため素材も出力も公開しない（効果音ラボと同じ扱い）。ゲームの音として使えるかは、配布の前に UVI へ確かめる。
- 素材の作り方：`tools/uvi_direct/uvi.cmd`（`.claude/skills/uvi-se/SKILL.md`）で、登録した音色 `whoosh` の鍵 36〜96 を1音ずつ
  （長さ0.2秒・強さ120・余韻2.5秒・ピーク −3dB）`tools/diagnostics/uvi_whoosh/all_wav/k<鍵>.wav` に書き出す。
  そのフォルダがあれば `build_sfx.gd` が whoosh・whoosh_soft を作り直す。
- 選び方：鍵ごとに違う風切りが入っていて、多くは音程のある成分が強く、電子音に聞こえた（ユーザーの指摘、2026-10-17）。
  スペクトルの目立つ山の強さを測り、雑音らしい13鍵（38・47・48・49・52・53・54・57・58・64・66・73・77）だけから選んだ。
  聞き比べで「Whooshes らしさを残した」版が選ばれた。振り向きの鍵66は聞いて変だったので外した。

| 音 | 鍵 | 加工 |
|---|---|---|
| whoosh 振る（4種） | 38、48、54、53 | 2.5倍（53は3倍）に上げ、200〜300Hz以下と1.6〜8kHz以上を削る。いちばん大きい所の0.08秒後から0.1秒で消す |
| whoosh_soft 振り向く（2種） | 64、57 | 1倍・2倍。200〜300Hz以下を削る。いちばん大きい所の0.2秒後から0.2秒で消す |

素材が無い環境の代わり（公開してよい。`sfx/`）：step・land は Kenney Impact Sounds（CC0）の footstep_concrete（着地は impactSoft_medium を低く重ねる）。
whoosh・whoosh_soft は Kenney に無いので、`build_sfx.gd` が雑音を帯域で絞って作る。

## 全部のボタンの音（乗せる・押す）と、車輪のロボットの走る音

- 鳴らし方：ボタンは `scripts/sfx.gd` の `_watch_button`。画面に出たボタン全部に、マウスを乗せると ui_hover（−10dB）、
  押すと ui_press（−6dB）。自分で別の音を鳴らすボタンは `set_meta("own_sfx", true)`。
  ロボットは `features/motion_sounds.gd` の `_roll_sound`。走っている間くり返し鳴らし、速さで音量（全速で −10dB）と高さ（0.8〜1.15倍）を変える。
- 聞き比べで決めた（2026-10-17）：ボタンは8通りから「マウスとカメラのシャッター」。メニューの開け閉めは、前のスイッチ・決定音が浮いて聞こえたので、4通りから「台本をめくる・閉じる」。ロボットは「車輪＋モーター」で、モーターを車輪と同じ大きさに。

| 音 | 元ファイル | 加工 | 置き場 |
|---|---|---|---|
| ui_hover 乗せる | 効果音ラボ click1（マウスのクリック） | 6kHz以上を削り、0.08秒で切る | sfx_local |
| ui_press 押す | 効果音ラボ camera-shutter2（カメラのシャッター） | 9kHz以上を削り、0.14秒で切る | sfx_local |
| ui_hover・ui_press（代わり） | Kenney Interface Sounds（CC0）tick_002・toggle_001 | 余韻を整える | sfx |
| menu_open メニューを開く（Escape・各メニュー・台本） | 効果音ラボ page1（ページをめくる） | いちばん大きい所の前0.18秒〜後0.2秒を切り出し、0.03秒で立ち上げ、8kHz以上を削る。−8dBで鳴らす | sfx_local |
| menu_close メニューを閉じる | 効果音ラボ book-close1（本を閉じる） | 6kHz以上を削り、0.17秒で切る。−8dBで鳴らす | sfx_local |
| menu_open・menu_close（代わり） | Kenney Interface Sounds（CC0）select_005・back_003 | 前の ui_open・ui_back と同じ | sfx |
| robot_tire 車輪 | 効果音ラボ monorail-driving1 の10〜14秒 | 1.6倍に上げて小さな車輪に。150Hz以下・3.5kHz以上を削り、0.4秒重ねてくり返しの音に | sfx_local |
| robot_motor モーター | UVI robot（Digital Motion Robot Slide）を鍵60・2.5秒鳴らした音（`tools/diagnostics/uvi_misc/out_robot/robot_hold60.wav`）の0.3〜1.3秒 | 300Hz以下・5kHz以上を削り、0.3秒重ねてくり返しの音に | sfx_local |

## 画面の音（選ぶ・開く・戻る・決定・失敗）

- 配布元・作者：[Kenney / Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds)、Kenney。ライセンス：CC0（同梱・加工可能）。
- 考え方：画面の音は「短い・角が立たない・同じ仲間の音色」でそろえ、物音より小さく鳴らす。
  選ぶ＜開く＜決定 の順に長くし、戻る・失敗は低めにする。高さは鳴らすたびに変えない。
- 出力先：`godot/assets/audio/sfx/`（公開してよい）。

| 音 | 元ファイル | 加工 |
|---|---|---|
| ui_select 選ぶ（2種） | select_002、select_007 | 7kHz以上を削り、0.06秒で切る |
| ui_open 開く | select_005 | 余韻を0.22秒に整える |
| ui_back 戻る・閉じる | back_003 | 高さ0.9倍、0.1秒で切る |
| ui_ok 決定 | confirmation_001 | 余韻を整える |
| ui_fail 失敗・足りない | error_003 | 高さ0.85倍、余韻を整える |

## 撮影所の物でそろえた画面の音（効果音ラボ。公開リポジトリには入れない）

参考にしたゲーム（R.E.P.O. のメニュー）の音を調べると、常に低い環境音が鳴っていて、その上に
0.02〜0.08秒のごく短い機械的な音が小さく乗る作りだった。画面の音は同じ考え方でそろえる（環境音は試したが、要らないという判断で入れていない）。

| 音 | 元ファイル | 加工 |
|---|---|---|
| ui_select 選ぶ（2種） | decision44、decision50 | 頭の0.1秒。6kHz以上を削る |
| ui_open 開く | switch1 | そのまま、余韻を整える |
| ui_back 戻る | decision44 | 高さ0.72倍 |
| ui_ok 決定 | electricity-switch1 ＋ decision7 | スイッチのあとに「カシャッ」を0.035秒遅らせて重ねる |
| ui_fail 失敗 | cancel9 | 頭の0.28秒 |

これらが無い環境では、上の Kenney の画面の音で鳴る。
