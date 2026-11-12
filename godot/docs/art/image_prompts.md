# 画像生成の指示文（構図のイメージ・テクスチャ）

画像を作れる道具（Codex・ChatGPT など）に渡す指示文。英語のほうが通りやすいので、英文を本文にしている。
作った画像は、構図は `godot/assets/concept/`、テクスチャは `godot/assets/textures/` に置く（Claude が読んで、ゲームに反映する）。
使う道具の利用条件（商用・改変の可否）を確かめてから使う。どの道具・どの指示で作ったかを、このファイルの下に書き足す。

## 絵柄の指定（毎回、文の最後に付ける）

> Stylized low-poly 3D game art, soft toon shading, warm late-afternoon light, muted pastel colors (cream, teal, rust red, mustard),
> clean chunky shapes, slightly cluttered and homemade, Japanese downtown (shitamachi) small-business atmosphere,
> no text except where requested, no people.

ゲームの今の色：しっくいのクリーム `#e6d9bb`・青緑 `#4e777c`・さび赤 `#8f5943`・木 `#94704a`・看板の赤 `#8f3b2e`。

## 全体構図（会社の敷地）

1. 上から斜めに見下ろした全体図
   > Isometric bird's-eye concept art of a tiny, poor film production company's lot in a Japanese industrial back street.
   > A small two-storey office whose front is a fake film-set facade (red signboard, clapperboard ornament on the roof, plywood and wooden braces visible from behind),
   > striped awnings over the shop front, a fenced scrap yard full of junk props (foam columns, arches, cardboard boxes, a fake tree),
   > a small gear corner with tripods and lights, a white kei truck parked on the street, a vending machine and bicycles.
   > Wide view, readable layout, game level design concept.
2. 事務所の正面（CMの背景になる画）
   > Front view concept of a small film company office: a two-storey fake facade with four windows (one lit),
   > a framed red signboard, lamps above it, striped awnings, a notice board, potted plants, a cardboard sign hung crookedly. Eye-level, 16:9.
3. 事務所の中（屋根なし・上から入るカメラ）
   > Top-down cutaway of a cramped film company office with no roof: a reception counter with a rotary phone and a peep box,
   > a big job notice board, film cans on shelves, movie posters, waiting chairs, a filing cabinet, cables taped to a wooden floor.

## テクスチャ（つなぎ目なし・正面から・影なし）

各文の頭に付ける：`Seamless tileable texture, flat front view, even lighting, no shadows, 1024x1024,`

| 置き場所（ファイル名） | 指示 |
| --- | --- |
| `plaster_wall.png` | cream painted plaster wall, subtle stains and hairline cracks, slightly dirty near the bottom |
| `wood_floor.png` | worn wooden floorboards, warm honey brown, scuffs and a few nail heads |
| `plywood.png` | raw plywood sheet with wood grain, pencil marks and a few stenciled numbers |
| `corrugated_metal.png` | weathered teal corrugated metal siding, rust streaks |
| `cardboard.png` | brown corrugated cardboard, tape marks, slight creases |
| `concrete_ground.png` | light grey concrete paving with joints, oil stains, faded paint lines |

看板の文字は生成に任せず、ゲームの中で文字を重ねる（生成の文字は崩れやすい）。

## 作った記録

（道具・日付・指示の番号・ファイル名・利用条件を、ここに書き足す）

- 2026-10-15　Codex CLI 0.157.0（画像生成）　構図 2（事務所の正面。看板は文字なし）→ `godot/assets/concept/office_front.png`（1672×941）
- 2026-10-15　Codex CLI 0.157.0（画像生成）　構図 2 をゲームの絵柄で（参考：今のゲームの正面・キャラクター・上の画）→ `godot/assets/concept/office_front_ingame.png`
- 2026-10-15　Codex CLI 0.157.0（gpt-6-sol・medium）　構図 1 を今の配置のまま（参考：今の敷地の俯瞰・ゲームの出来の良い所・Dear Passengers・PEAK の光と緑）→ `godot/assets/concept/lot_overview.png`（1672×941）

参考のゲーム画像（Steam ストアの公式スクリーンショット：Dear Passengers・R.E.P.O.・PEAK・Gamble With Your Friends）は、
生成の参考にだけ使い、リポジトリには入れない（`godot/tests/shots/codex_handoff/refs_games/`。公開しないフォルダ）。

### 全体構図から取り入れたこと（2026-10-15）

- 木・植え込み・つた・鉢植え：葉の形に抜いた板を丸い芯に重ねる（`scripts/foliage.gd`）。板の法線は茂みの中心から外向き
- 敷地の目地（2.5m ごと）とフェンス際の雑草、2.5m 角の敷石の色むら
- 水たまりは縁がくっきりした空色（暗い板だと穴に見える）
- 色調：明るい所を暖かく、暗い所を少し青く（`production_look.gd` の色の補正。太陽は撮影現場と共有なので触らない）

### 2026-11-12 せりふの帯の、話し手の顔（バズ山）

- 置き場所：`godot/assets/ui/portraits/buzzyama_<画風>_<表情>.png`（256px。画風は flat＝平たい塗り／duo＝白と青の2色刷り。表情は normal・happy・surprised・troubled・stern）
- もとの絵：`godot/assets/concept/portrait_styles_buzzyama.png`（画風の見本3つ）・`buzzyama_faces_flat.png`・`buzzyama_faces_duo.png`（表情5つを横に並べた絵。5等分して使う）
- 作り方：Codex（gpt-6-sol・medium）。参考に、ゲームのモデルを単体で撮った絵と、画風の見本を渡す。
  「5等分の正方形を横に並べる・枠なし・同じ向きと大きさ・表情だけ変える・字は入れない」と指定する。
- 使う所：`scripts/guide_speech.gd` の set_portrait（`ui/guide_portrait_style` で画風を選ぶ。既定は flat）

### 2026-11-12 バズ山の案・3回目（ゲームの絵柄に合わせる）
- 2回目（`buzzyama_designs2.png`）は「見た目がきもい。ゲームのデザインの感じに合わせて」（ユーザー）。描き込みの細かい写実寄りの絵は使わない
- 参考に付けた絵：ゲームのキャラ 7 人を並べて撮った絵（`assets/cast/cast*_game.glb` を横に並べただけ）
- 指示の要点：フェルトとぬいぐるみの人形・単純な太い形・白い玉の目に小さな黒目と眠そうなまぶた・細い手足・大きな靴・色は 3〜4 色・歯やしわは無し。丸い色めがねと大げさな髪型は残す
- できた絵：`godot/assets/concept/buzzyama_designs3.png`（1 黄色い毛糸のリーゼント／2 ビデオテープ頭／3 金の玉にひげ／4 きのこ頭の黒いタートル）

### 2026-11-12 バズ山の案・4回目（キャラの元絵を見本に）
- キャラの元絵は `codex_src/refs/`（01〜04・05〜08・09〜12・ロボットの 4 枚）。**キャラを描く時は、必ずこの元絵を `-i` で付ける**（3回目は付けずに、色が明るくにこにこした別の顔になった）
- 元絵の特徴：くすんだ色の羊毛フェルトと布・重いまぶた・への字の厚い口・無表情・ミトンの手・大きな靴・1 つの変な形でできた体・白い背景
- できた絵：`godot/assets/concept/buzzyama_designs4.png`（1 リーゼント／2 ビデオテープ頭／3 金の玉／4 おかっぱの長い人）
- 気づいた事：元絵より毛羽・縫い目・つぎはぎ・まゆ毛が多く出た。次は「clean smooth felt, few stitches, no patches, no eyebrows, no stray fibres」を足す

### 2026-11-12 バズ山の案・5回目（立ち絵の絵柄で、縛りなし）
- ユーザー：「立ち絵の方の絵柄で一旦色々。キャラクタースタイルの指定も一旦無しにして」。見本は `buzzyama_faces_flat.png`（太い黒線・平たい塗り・水色のふち・暗い背景）だけ
- できた絵：`buzzyama_ideas_a.png`（リーゼントの人・招き猫・きつね・金貨・テレビ頭・くじゃく・モアイ・たこ）、`buzzyama_ideas_b.png`（たぬき・メガホン頭・だるま・金歯のおじさん・おうむ・スマホ頭・へび・宇宙人）

### 2026-11-12 バズ山の案・6回目（たぬきを、物・人形として）
- ユーザー：「タヌキモチーフはいいが、ただの動物のキャラはほかに居ないので、整合性を取りたい」。ほかのキャラは、1 つの物や人形でできている（モップ・段ボール・蛇腹の首・カエルのぬいぐるみ）
- できた絵：`buzzyama_tanuki.png`（上：信楽焼の置物／たぬきの着ぐるみの人／ぬいぐるみ　下：茶釜／紙のお面／たぬきに見える髪とサングラスの人）

### 2026-11-12 キャラの決まり（元絵 01〜12 から読み取った。新しいキャラを描く前に読む）
- 人は居ない。ただの動物も居ない（ユーザー：「ただ動物のキャラはいない」「人もゲームに出てこない」）
- 体そのものが、1 つの身近な物・素材・変な形（モップ・段ボール箱・スポンジ・砥石のような板・ドーナツ・蛇腹の管・かたまり）。毛皮・肌色・鼻・耳は無い
- 顔は全員同じ作り：白い玉の目に小さな黒目と重いまぶた、平らかへの字の口。にやけ顔・歯・まゆ毛は無い
- 役は、かぶり物 1 つで見せる（王冠・コック帽・警官の帽子・ベレー帽）。ミトンの手、大きな靴
- 指示に足す文：clean smooth needle-felt, large quiet colour areas, very few stitches, no patches, no stray fibres

### 2026-11-12 バズ山の案・7回目（物に化けそこねた、たぬき）
- 考え：ほかのキャラと同じ「物の人形」。たぬきの印は、後ろに出たしま模様のしっぽと、頭の葉っぱだけ（分福茶釜）。丸い色めがね。金の布を使うのは、この人だけ
- できた絵：`buzzyama_disguise.png`（1 茶釜／2 金のトロフィー／3 とっくり＋かさ＋通い帳）

### 2026-11-12 バズ山の案・8回目（モアイ＋サングラス）
- ユーザー：5回目の絵のうち「モアイサングラスはキャラが立っていていい」。7回目の3案（茶釜・トロフィー・とっくり）は保留
- 残した所：長い石の頭・深いまゆの出っ張り・大きな鼻・四角い金のサングラス（目は見せない）・金の玉の首飾り・紫の布
- 直した所：人の肌の肩をやめ、体ごと石にした。キャラ11（うすい灰色の板）と似ないよう、厚く角ばった濃い石に
- できた絵：`buzzyama_moai.png`（人形。1 口を開けたにやけ顔／2 平らな口・ビデオテープ／3 胴あり・布を肩から）、`buzzyama_moai_faces.png`（立ち絵の絵柄で4つの顔。驚くとサングラスがずれて頭にひび）
- 見本：元絵 05-08・09-12、`buzzyama_moai_src.png`（5回目の絵からモアイだけ切り出し）、立ち絵は `buzzyama_faces_flat.png`

### 2026-11-12 バズ山の案・9回目（モアイの手足と、割れ方）
- ユーザー：「手足のスタイルとか変えてみたい。割れてるスタイルもありかな。いろんな要素」
- `buzzyama_moai_limbs.png`：1 手だけ浮く（腕・足なし）／2 浮き彫りの腕＋台座と台車／3 金の長い手足／4 届かない短い手と小さな足
- `buzzyama_moai_cracked.png`：5 中身が発泡スチロール＋ガムテープ（偽物の石）／6 金で継いだひび／7 口で上下に割れて浮く＋赤い石の帽子／8 こけ・欠けた鼻・割れたレンズ・鳥の巣
- 見本：`buzzyama_moai.png` と元絵 09-12。3 は指のある手とヒールになり、人に寄った

### 2026-11-12 バズ山の案・10回目（モアイ、細くないタイプ）
- ユーザー：「細くないタイプみたい」。8回目・9回目は腕と足が細い棒だった
- `buzzyama_moai_thick.png`：1 太い石の手足・腕組み／2 横に広くて低い岩／3 太鼓腹で座る／4 腕と肩が大きい力持ち
- 見本：`buzzyama_moai.png` と元絵 09-12（10・12 の太い手足を指した）

### 2026-11-12 バズ山の案・11回目（モアイ、手足の作りを変える）
- ユーザー：10回目に「シンプルにサイズ変えるだけだと微妙」。太さ・長さではなく、手足が何でできていて、どう組んであるかを変える
- `buzzyama_moai_build_a.png`：1 積んだ丸石／2 引き縄が腕・丸太で転がる／3 切り石のブロック／4 金のダウンの上下
- `buzzyama_moai_build_b.png`：5 紫の蛇腹／6 木箱に入って台車に乗る／7 彫り物の柱と羽の腕／8 みやげ物の貯金箱（頭に硬貨の口・値札）
- 見本：`buzzyama_moai_thick.png` と元絵（a は 09-12、b は 05-08）

### 2026-11-12 バズ山の案・12回目（モアイ、縄で歩かせた説から）
- ユーザー：「ロープで引っ張って歩いていたみたいなのをオマージュした見た目は？」（頭に縄を掛け、左右に揺らして立ったまま歩かせた、という説）
- 共通：足なし・底の丸い台・片側が浮いた傾き・まゆの下に縄を巻く
- `buzzyama_moai_walk.png`：1 浮いた石の手が自分の縄を引く／2 縄がそのまま腕（結び目のこぶし）／3 サングラスの小石たちが綱引きで引く／4 上の木の棒からつられた操り人形
- 見本：`buzzyama_moai_build_a.png` と元絵 09-12

### 2026-11-12 バズ山の設定画（モアイ＋縄＋小石）
- ユーザーが 12回目の 3（サングラスの小石が縄を引く）を選んだ
- `buzzyama_sheet.png`：1 前／2 横／3 後ろ（縄の結び目）／4 腕を開いてビデオテープ／5 小石（前・後ろ）
- 見本：`buzzyama_moai_pick.png`（12回目の絵から 3 だけ切り出し）と元絵 09-12
- 選んだ絵との違い：毛羽が強い・縄が黄色い三つ編みになった・頭に対して胴が長い。モデルを作る時は、12回目の絵の比率（頭が大きい・毛羽なし）に寄せる
- 描き直し（同日、ユーザー「先に絵を直す」）：1枚目は `buzzyama_sheet_v1.png` に残した。`buzzyama_sheet.png` は、なめらかな面・砂色のより縄・顔が背の半分以上、に直した版
  - 効いた書き方：選んだ絵を「正」、1枚目を「並べ方だけ正しい」として両方付け、違う所を SURFACE / ROPE / PROPORTIONS の3項目で名指しした
  - まだ違う所：胴がかなり短い・紫の布が斜めでなく腰の横帯・縄が二重巻き
