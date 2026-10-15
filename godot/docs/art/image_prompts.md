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
