# 引き継ぎ：赤黒パンク（Punk Ink VFX）と、VFX の作り方の資料

2026-10-12 時点。別のセッションが続きをやるための1枚。ここに書いた状態は、この日に確かめた物。
2026-10-13 に、長尺の一本（NO ESCAPE）を足した。その分は下の「長尺」の節。
同じ日に、戦車の見本のプロジェクト（旧 `punk_showcase/`）を `C:\Programer___Amano\レッドパンク\vfx_showcase\` へ移し、そこに Armored の登場シーンを作った（下の「レッドパンクの置き場所」）。
さらに、赤黒パンクとは別の絵柄の長尺（折り紙・紙工作。Origami VFX）を足した（下の「折り紙・紙工作」）。
そのあと、折り紙のパックを「和のVFX集」として売れる形にまとめた（配る形・商品ページの素材・下書き。下の同じ節）。
**二つのパックと、その確認用のファイルは、`.gitignore` で公開リポジトリから外してある**（載せるかどうかは作者が決める）。

## まず読む順

1. リポジトリ直下 `VFX_KNOWLEDGE.md`（要点・好み・手順・部品の辞書を1枚にまとめた物）
2. このフォルダの `STYLE-punk-ink.md`（赤黒パンクの絵柄の決まりと、指摘された失敗）、`STYLE-origami.md`（折り紙・紙工作の絵柄）
3. `godot/addons/punk_ink_vfx/README.md`（パッケージの使い方と収録一覧）

## フォルダと役割

| 場所 | 中身 | git |
|---|---|---|
| `godot/addons/punk_ink_vfx/` | **売り物候補のパッケージ本体**。`punk_fx.gd`（34種）、`ultimate/`（長尺の本編と部品）、`shaders/`（9つ＋共通関数）、`demo/`、`README.md` | git 対象外（`.gitignore`） |
| `godot/tests/punkpacktest.gd` | パッケージの自動確認（出る・片付く・一時停止・速さ・合図） | git 対象外（`.gitignore`） |
| `godot/tests/punk_xl_shots.gd` `.tscn` | 長尺をコマ送りで撮る道具（常駐の Godot から呼ぶ） | git 対象外（`.gitignore`） |
| `C:\Programer___Amano\レッドパンク\vfx_showcase\`（旧 `punk_showcase/`。このリポジトリの外） | レッドパンクの見本の別プロジェクト。戦車の見本（`showcase.gd`、`tank_showcase.mp4`）、長尺の動画 `no_escape_cut.mp4` `no_escape_wide.mp4`、Armored の登場シーン。中の `README.md` に案内 | **git に入っていない** |
| `godot/addons/origami_vfx/` | **別の絵柄のパッケージ**（折り紙・紙工作。22 種）。`origami_fx.gd`（土台と部品）、`basic/`（汎用 21 種）、`ultimate/`（長尺「折神降ろし」）、`origami_effect.gd` と `scenes/`（シーンに置く形）、`shaders/`、`demo/`、`README.md` | git 対象外（`.gitignore`） |
| `godot/tests/origamitest.gd`、`origami_shots.gd` `.tscn` | 折り紙のパッケージの自動確認と、コマ送りで撮る道具 | git 対象外（`.gitignore`） |
| `artifacts/origami_vfx_package/` | 折り紙のパックの配る形（単体のプロジェクトと zip）、商品ページの素材（`store/`）、文の下書き（`store/STORE_PAGE.md`） | git 対象外 |
| `tools/build_origami_package.py`、`tools/build_origami_media.py` | 上の二つを作り直す道具 | git 対象外（`tools/*`） |
| `artifacts/origami_descent/`、`artifacts/origami_basic/` | 商品化の前に作った動画（長尺、汎用 16 種）。新しい物は `origami_vfx_package/store/video/` | git 対象外 |
| `.claude/skills/godot-vfx/` | VFX の作り方の資料。下の表 | 一部未コミット |
| `VFX_KNOWLEDGE.md` | 上の資料をまとめた1枚。`python tools/build_vfx_knowledge.py` で作り直す | 未コミット |
| `godot/vfx/vfx_punk_*.gd`、`godot/vfx/shaders/punk*.gdshader` | パッケージ化する前の試作（2D の板の6種、棘の衝撃、3D 版の棘の地走り）。ラボの `punk_*` で見られる | 未コミット。**古い。直すならパッケージ側** |
| `godot/pixel_vfx/` | 別の売り物候補（ドット絵 × リアル）。`PX_KNOWLEDGE.md` に市場の見立てと採点 | 別セッション（Codex）も編集中 |

### `.claude/skills/godot-vfx/` の資料

| ファイル | 内容 |
|---|---|
| `SKILL.md` | 部品・使い方・はまりどころの辞書 |
| `PLAYBOOK.md` | 作る担当が従う手順。合格基準、消え方、確認方法、報告前の関門 |
| `TASTE.md` | ユーザーの好みの記録（私の記憶 `vfx-taste.md` の写し。片方を直したら、もう片方も直す） |
| `STYLE-punk-ink.md` | 赤黒パンクの絵柄 |
| `STYLE-origami.md` | 折り紙・紙工作の絵柄（材質の作り方、退場の表、画像を見て直した所） |
| `REVIEW-haiku.md` | Haiku 5.5 が作った演出のレビュー |
| `requests/water-01.md` | 修正依頼の見本（水の5種。冷気の水は未完） |

## パッケージの今の状態

- 34種（小10・中14・大9・長尺1）。`PunkFx.spawn(親, 地面の点, 種類, 大きさ, 配色, 速さ, 向き, 距離)`。合図は `cue(name)`。
- `punkpacktest` は通る（2026-10-13 に実行。34種と、長尺の合図5つの順）。見本のプロジェクト（`レッドパンク/vfx_showcase/addons/`）の写しは本体と同じ（2026-10-13 に写し直した）。
- 見た目は静止画のコマでしか確かめていない。動画は `tank_showcase.mp4` を作ったが、作った側は再生していない。
- ユーザーの最後の反応は、戦車の動画を出した所まで。**動画への感想はまだ聞いていない。**

### 直した後、画像で見ていない物

`slash`（皿に見えたので傾きを変えた）、`bite`（入れ歯に見えたので歯ぐきを墨にした）、`step`（土煙を大きくした）、`smoke`（塊を増やして遅くした）、小の落書き4つ（移植後）、`punk` 以外の配色3つ。

### 弱いと分かっている物

- `tower`：遠目で小さい。`dart`：棘より布の尾が目立つ。`rag3d`：一瞬で画面の外へ出る。
- 戦車の動画：着弾後の煙の黒い塊が大きい。砲弾が小さくて目立たない。最後の2秒が間延び。
- 戦車の素材に付いていた専用の砲撃・走行エフェクト（`レッドパンク/vfx_showcase/` の `vfx/`、`driving/`）は使っていない。

### 売る前に残っていること

ライセンスが未定（README にも未定と書いてある）。Forward+ 以外は未確認。商品ページ用の動画・GIF がない。
（折り紙のパックでは、この三つに手を付けた：レンダラーの対応と、動画・GIF を作る道具。赤黒パンクへ同じことをする時の手本は `tools/build_origami_*.py`。）

## 長尺：NO ESCAPE（2026-10-13）

依頼は「大・多の五倍装飾つけて長いの一つ究極クオリティで作って」。Pixel×Real 側には別セッションが同じ依頼で作った `px_apotheosis`（22秒・20系統）があるので、こちらは赤黒パンクで作った。**絵柄の選び方は私の判断で、ユーザーの確認はまだ。**

- 種類 `no_escape`（XL、22.4 秒、5幕、装飾およそ30系統）。本編 `ultimate/no_escape.gd`、部品 `ultimate/xl_parts.gd`。作り方と直した所は `STYLE-punk-ink.md` の「長尺（XL）」。
- 見本 `demo/no_escape_demo.tscn`（カメラ切り替え。`-- --take=wide` で引きのまま）。ラボは「赤黒パンク」の項目（id `pk_no_escape`）。
- 動画 `レッドパンク/vfx_showcase/no_escape_cut.mp4` と `no_escape_wide.mp4`（1600×900、約23秒）。作った側は、動画から抜いたコマを見た。通して再生はしていない。
- 既存の種類に触れた所：`punk3d` に縞の細かさ・帯の縁・`flash`、`punk3d_ink` に `world_w`、`punk` に `flash`、`punk_fx.gd` に `SCRIPTS`（種類ごとの専用スクリプト）と `VIEWS`。既存33種のうち `blast`・`portal`・`tornado` を撮って、以前と同じ絵なのを見た（見たのはこの3種だけ）。
- 見つけて直していない物：平たい帯（`path_tube` の sides=2）は表裏の法線が打ち消し合っている（`soft 0.45` で隠している）。長尺では `xl_parts.gd` の `flat_ribbon`（表裏を別の面で作る）を使った。既存の布（`rag3d`、`tornado` など）は元のまま。

## ユーザーから受けた指摘（繰り返さないこと）

- 同じ部品の組み合わせで数を増やすと、すぐ見抜かれる。**数より先に部品を増やす。**
- 3D 前提。2D の板は落書きの印と脇の飾りだけ。
- 大中小は大きさではなく、飾りの量と長さ。
- 走り・斬撃・当たり・煙・登場・ポータルなど、基本の演出を先に入れる。
- 消え方にこだわる。縮む・フェード・根元へ戻る・円が縮む、は不可（`PLAYBOOK.md` 0.5章）。
- 見ていない物を「確認した」と書かない。画像だけが送られてきたら、その画像を評価する。

## 動かし方

```bash
GD=./tools/godot/Godot_v4.7.2-stable_win64_console.exe
# 見本シーン（←→ 切り替え、P 配色、1/2/3 速さ）
$GD --path godot res://addons/punk_ink_vfx/demo/demo.tscn
# 1種類を8コマの画像に（godot/tests/shots/vfx_review/pk_<種類>.png）
$GD --path godot --fixed-fps 60 res://vfx_lab.tscn -- --shots --only=pk_portal --dist=12
# 自動確認
$GD --headless --path godot --script res://tests/punkpacktest.gd
# 長尺の見本（Space もう一度、C カメラ切り替えの入・切）。動画にするなら --write-movie out.avi --fixed-fps 30 を足す
$GD --path godot res://addons/punk_ink_vfx/demo/no_escape_demo.tscn
# 長尺をコマ送りで撮る（画面に出ない。コマ番号は 12 コマ/秒。カメラは wide / top / close / hero / sky / door など）
python tools/dev_session.py --name xl start --mode render --scene res://tests/punk_xl_shots.tscn
echo '{"op":"call","method":"shoot","args":[{"frames":[151,152,165,166],"cams":["wide"],"tag":"impact"}]}' | python tools/dev_session.py --name xl request -
python tools/dev_session.py --name xl stop
# 戦車の動画を撮り直す（AVI が出る。MP4 へは ffmpeg）
$GD --path "C:/Programer___Amano/レッドパンク/vfx_showcase" --write-movie out.avi --fixed-fps 30 --resolution 1280x720 res://showcase.tscn
# 折り紙の長尺：見本（Space もう一度、C カメラ切り替え）、自動確認、コマ送りの撮影（カメラは wide / hero / top / page / cut など。cut は見本のカメラ割り）
$GD --path godot res://addons/origami_vfx/demo/descent_demo.tscn
$GD --headless --path godot --script res://tests/origamitest.gd
python tools/dev_session.py --name og start --mode render --scene res://tests/origami_shots.tscn
echo '{"op":"call","method":"shoot","args":[{"frames":[184,185,188,192],"cams":["cut"],"look":"demo","tag":"hit"}]}' | python tools/dev_session.py --name og request -
python tools/dev_session.py --name og stop
```

パッケージを直したら、`レッドパンク/vfx_showcase/addons/punk_ink_vfx/` へ写し直す（別プロジェクトなので自動では揃わない）。

## レッドパンクの置き場所と、Armored の登場（2026-10-13）

ユーザーの言葉：「これは別のゲームで使いたい」「レッドパンクのキャラの登場シーンに使えそう」「キャラも入れて専用のモーションまで」。キャラクターは Armored を指定された。

- 置き場所は `C:\Programer___Amano\レッドパンク\vfx_showcase\`（ユーザーが「レッドパンク/ に移す」を選んだ）。同じ `レッドパンク/` の他のフォルダは、ユーザーと別セッションの作業場所なので触らない。
- 登場シーン：`entrance.tscn` / `entrance.gd`（約 24 秒）。NO ESCAPE の時刻に、Armored の動き（元のアクション2本＋手直し）を合わせている。動画 `armored_entrance_cut.mp4`。
- 役者：`character/armored/`（`armored.glb`＝骨 65 本・アクション2本、`armored.gd`、`armored_paint.gdshader`）。`レッドパンク/Armored_Skin/Armored_Motion_v12.blend` から書き出した（元のファイルは変えていない）。
  書き出しのスクリプトは `tools/export_armored.py`（Blender をバックグラウンドで実行。約 5 分）。
- そのためにパッケージへ足した物：`spawn` の 9 番目の引数（設定の辞書）、`seek(t)`、`add_quake(時刻, 強さ)`、`impact_state()`、`anchor("mace" / "can" / "block")`、設定 `"can_land": Node3D`。説明は `punk_ink_vfx/README.md`。
- 状態：静止画で見ただけ。背中のカットが多い、決めの絵で缶が足を隠す、決めの背景が何も無い、が残っている。ユーザーの感想はまだ。
- パッケージの元は、今もこのリポジトリの `godot/addons/punk_ink_vfx/`。`レッドパンク/` 側へ元を移すかどうかは、ユーザーに聞いたまま返事を待っている。

## 折り紙・紙工作：Origami VFX（2026-10-13）

依頼は「レッドパンクじゃない系統で、大・多の五倍装飾つけて長いの一つ究極クオリティで作って」。絵柄は制作側が選んだ。

- 種類 `descent`（折神降ろし。XL、23.7 秒、5幕、装飾およそ30系統）。使い方は `godot/addons/origami_vfx/README.md`、作り方と直した所は `STYLE-origami.md`。
- 次の依頼「汎用的なvfxも作って」で、同じ絵柄の汎用の演出を 16 種足した（小：step・hit・slash・pickup／中：dash・land・shot・bolt・burst・heal・guard・smoke・fire／大：portal・arrive・tornado）。
  本体は `basic/`。通しの動画を送ったあとの言葉が「いいね和のvfx集として販売できそうにして」（どこが良かったかは聞いていない。長尺への言葉は無い）。
- その依頼で、和の題材 5 種（fubuki・shuriken・ofuda・vanish・hanabi）を足し、売れる形にまとめた：見本 `demo/showroom.tscn`、シーンに置くノードと `scenes/`、
  配色を足す入口、三つのレンダラーへの対応、英日の README、配る形（zip）、商品ページの素材と文の下書き。場所と道具は `STYLE-origami.md` の「商品としての形」。
  **題・価格・ライセンス・売り場は決まっていない**（下書きは `artifacts/origami_vfx_package/store/STORE_PAGE.md` の 10 節）。
- 次の依頼「紙だけじゃなくて、合わせ技もいいし、和って感じの10:10:10くらい全部こだわって作って。紙と墨の組み合わせは一個ずつ必ず」で、和の題材を 30 種足した
  （小 10・中 10・大 10。本体は `wa/`。紙に加えて、墨・木・金・紐・竹・布）。全部で 52 種。**この 30 種への感想は、まだ聞いていない。**
  種類の一覧・作り・直した所・重さの落とし穴・まだ弱い所は、`STYLE-origami.md` の「和の題材 30 種」。
- ラボは「折り紙・紙工作」の項目（id `og_descent` と `og_<種類>`）。ラボはパックを有る時だけ読む（無ければ項目を出さない）。
  `run_tests.sh` の `punk` と `origami` は、フォルダが有る時だけ流れる。
- 自動確認 `origamitest` は、画面なしでは MultiMesh を読み戻せないので、「最後のコマに何も残らない」の全部の確認は `--headless` を外して流す：
  `$GD --path godot --position -32000,-32000 --script res://tests/origamitest.gd`（2026-10-13 に、両方の流し方で通った）。
- 汎用の演出を並べて撮る：`origami_shots.gd` の `gallery`（種類ごとに n コマ。カメラと人の目安は、見本 `demo/showroom.gd` の `CAMS` `DUMMY`）。
  同じ種類を別のカメラ・大きさで並べる時は、種類を `slash#1,slash#2` のように書いて、`cams` `scales` をその名前で渡す。
- 動画 `artifacts/origami_descent/origami_descent_cut.mp4` と `origami_descent_wide.mp4`（1600×900、約24秒）。作った側は、動画から抜いたコマを見た。通して再生はしていない。
- ほかの演出のファイルには触れていない（`vfx_lab.gd` への登録と、パックが無くても動くようにした所、`run_tests.sh` の数行、`vfx_lab_picker_test.gd` の確認 4 つ）。
- 作り直す：`python tools/build_origami_package.py`（約 3 分。配る形のまま自動確認まで流す）、`python tools/build_origami_media.py`（52 種で約 8 分。録画に 6 分）。
  種類を足したら、`tools/build_origami_package.py` の `CATALOG` に 1 行足して `--catalog`（`catalog.json`・README の表・種類ごとのシーン・置くノードの一覧が出来る）。

## 素材の出どころ（戦車の動画）

ユーザーのダウンロードフォルダから写した。`戦車/Inkpunk_Tank_VFX_Candidate_Godot_Source.zip`（戦車と動きの仕組み）、`Inkpunk_R3_InkStore_Editable_WIP.zip`（通りのステージ）。
戦車は建物と同じ高さだったので 0.55 倍で置いている。素材の利用条件は確かめていない。売り物のパッケージには入れていない。

## 新しい種類を足す手順

1. `punk_fx.gd` の `KINDS` に `"名前": ["S|M|L", 寿命]` を1行。
2. `func _build_名前()` を書く。部品は `_blade` `_puff` `_shard` `_crack` `_solid`＋`_key` `_chain` `_spike` `_ribbon` `_bolt` `_ball` `_board`。
3. `README.md` の表に1行、`punkpacktest.gd` の種類数を直す、`vfx_lab.gd` の `ITEMS` に `pk_名前` を足す。
4. 全体・動き・終わりの画像を見てから報告する。

関数名に `_set` `_get` を使わない（Godot 本体と衝突して、スクリプト全体が読めなくなる）。
