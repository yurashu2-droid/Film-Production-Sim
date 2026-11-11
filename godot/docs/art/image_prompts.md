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
