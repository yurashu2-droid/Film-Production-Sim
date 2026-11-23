# 小型小道具8点の作り直し

既存の種類名と用途を保ち、実物写真から構造を読み取って制作した静的ゲーム用モデル。元のGLB・元モデルの画像は資料画像生成の入力にしていない。画像生成自体を使用していない。配布物の写真・ロゴ・テクスチャ・メッシュは取り込まず、このPythonで形状と単色PBR材質を制作している。

既存素材は `小道具大道具(仮)/film_crew_small_props_P001-P025_v01 (1).zip` の `README_ja.md` と `LICENSE.txt` も確認済み。既存100点が外部素材を含まない手続き生成の試作で、今回の8点の名称と用途が一致することを確認した。今回はその見た目の置き換え依頼のため、既存の試作メッシュは流用しない。

## 資料と構造上の判断

2026-10-17にWeb画像検索で下記の実物商品写真を参照。背面・内部の写真で確認できない部分は用途に合わせた推定形状で、商品の寸法を再現した複製ではない。小さな傷・細かな浮彫り・ブランド名は省略した。

| 種類 | 写真の出典 | 読み取った構造と今回の表現 |
|---|---|---|
| 開いた指輪ケース | [Allurepack: Ornate suede ring box](https://allurepack.com/products/ornate-ring-box) | 丸い角を持つ被覆ケース、実際に開いた蓋、厚い縁、2個のクッションと指輪の挿入溝。指輪は連続した金属バンド、台座、4本の爪、面で切られた石。蓋の厚みとヒンジを残した。 |
| ハートのチョコ箱 | [Mayfield Chocolates: Deluxe Red Heart Box](https://mayfieldchocolates.com.au/deluxe-red-heart-box-15-chocolates-67-50/) | 連続したハート形の浅い箱壁と縁、金のトレー、個別のひだ付き紙カップ。ハート・ドーム・角形のチョコを配置。外した蓋は右奥に接地させ、中身を隠さない。 |
| 香水ボトル | [Colors Glass: 25ml rectangular bottle with gold cap](https://www.colorsglass.com/product/en/25ml-Empty-high-quality-rectangular-shape-transparent-OEM-glass-perfume-bottle-with-pump-sprayer-gold-cap.html) | 角丸断面から肩を経て狭い首につながる連続したボトル、厚い足、首の金具、別体キャップ、紙ラベル。ゲームでの読みやすさと安定した描画を優先した不透明の曇りガラス表現で、物理透過は使わない。 |
| 手鏡 | [ギギliving: 真鍮のハンドミラー オーバル](https://www.gigiliving.com/SHOP/kan2848.html) | 縦長の鏡面、裏板、厚い鋳金の外枠、連続した巻き縁、首から持ち手までつながる先細り形状。裏は緑のエナメル。葉の浮彫りは輪郭が読める数だけ残す。鏡面は環境光を受ける金属面で、実写反射や動的ミラーではない。 |
| 開いた扇子 | [Chidori Vintage: Japanese Folding Fan 4D607](https://chidorivintage.com/products/japanese-folding-fan-vtg-sensu-bamboo-frame-white-plain-paper-4d607) | 20山の有限厚の蛇腹紙、要から紙面端までつながる竹骨、太い両端の親骨、金属の要。和紙の面を平らな扇形板にせず、山折りと谷折りを分けた。朱色は単純な大きい印刷帯。 |
| 小さな日傘 | [日吉屋: 番傘](https://shop.wagasa.com/collections/bangasa)、[辻倉: 色番傘 紅](https://www.kyoto-tsujikura.com/products/jyobangasa-001) | 張りのある浅い油紙のドーム、32本の連続した竹骨、下ろくろから骨へ接続する支え、上下の木製ハブ、まっすぐな漆塗りの柄。和傘として曲がった洋傘のハンドルを使わず、蛇の目の白い帯を1周だけ設ける。 |
| チューリップの花束 | [24Hrs City Florist: Perfect Pink Tulip](https://www.24hrscityflorist.com/perfect-pink-tulip.html)、[Polina Zimenkova / Unsplash](https://unsplash.com/photos/a-bouquet-of-pink-tulips-wrapped-in-brown-paper-xX3m0OHerFY) | 高さに変化を持たせた7輪。各花は6枚の厚みを持つ重なったカップ状花弁、下端まで続く茎、折れ目のある披針形の葉。2枚の広い包装紙が束ね位置で支えられ、上で重なって開く。ひもと小さなリボンで結ぶ。 |
| リボンの贈り物 | [Made-in-China: Folding gift box with silk ribbon](https://m.made-in-china.com/product/Factory-Direct-Folding-Gift-Boxes-with-High-Quality-Low-MOQ-Christmas-Gift-Wedding-in-Stock-Gift-Box-with-Silk-Ribbon-1938035482.html) | 紙貼りの箱、別体の被せ蓋と閉じ目、箱を連続して一周する2本の帯。リボンの輪と垂れは中空の幅広い布帯として作り、結び目で接続した。紐状の輪や独立した楕円で代用しない。 |

## ゲーム上の契約

`production_scrap.gd` はこの作業では編集していない。親の統合工程で `replacements.json` を利用する。既存ファイルは残す。

| kind | 正規化後の size / mass | 新しいGLB |
|---|---|---|
| scrap_ring_box | 0.45 / 0.5 | P002_ring_box_rebuilt.glb |
| scrap_heart_chocolates | 0.55 / 0.6 | P003_heart_chocolates_rebuilt.glb |
| scrap_perfume | 0.45 / 0.4 | P004_perfume_rebuilt.glb |
| scrap_hand_mirror | 0.6 / 0.5 | P005_hand_mirror_rebuilt.glb |
| scrap_folding_fan | 0.75 / 0.3 | P006_folding_fan_rebuilt.glb |
| scrap_parasol | 0.9 / 0.8 | P007_parasol_rebuilt.glb |
| scrap_tulip_bouquet | 0.7 / 0.5 | P008_tulip_bouquet_rebuilt.glb |
| scrap_ribbon_gift | 0.6 / 0.6 | P009_ribbon_gift_rebuilt.glb |

製作者のZ-up／正面-YをglTFでGodotのY-up／正面+Zへ変換。元サイズは小物用途に適した相対寸法として制作し、ゲームの既存正規化に任せる。GLBは材質ごとのバッチに結合。外部テクスチャ・透過・アニメーション・追加の衝突形状は持たない。

## 再生成と確認

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/rebuild_small_a/source/build_assets.py -- --preview
```

`fresh_props/source/build_assets.py` とその `refined_props` ヘルパーを使い、8点を独立した初期化済みBlenderシーンで書き出す。`build_manifest.json` は実測三角形数、バッチ数、座標範囲、有限座標チェック。編集用blendとGLBを再インポートした斜め前の確認PNGは、追跡しない `artifacts/rebuild-small-a/` に保存する。`--preview` を省くとPNGは生成しない。

確認の範囲: 全8点のエクスポート成功、有限な頂点座標、実GLBのBlender再インポート、材質付き斜め前の静止画を確認。Godotのインポート・実ゲーム照明・カタログ・衝突・配置・物理挙動・ユーザーの品質承認は親側で行うため、この段階では未確認。実物の光学・紙の変形・開閉機構の物理シミュレーションは行っていない。

## Current lower polygon build

User requested a simpler polygon style. Run Blender CLI `--background --factory-startup --python tools/build_lowpoly_props.py -- rebuild_small_a` from repository root. This caps cylinders at 16 sides, turned bodies at 24, small tubes at 6, ellipsoids at 16 by 8, and bevels at one segment. Preserve recognizable construction, silhouette and openings. Generic builder alone generates the denser source variant. Current triangle counts are in build_manifest.json.
