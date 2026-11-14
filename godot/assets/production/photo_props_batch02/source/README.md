# 写真参考による置き換え 第2組：トイレ・じょうろ・優勝カップ

承認された自販機・ティーポット・旅行鞄を品質の目安にした3点。実物を画像検索し、ブラウザーで写真を直接確認してから制作した。画像生成は使用していない。旧モデル画像はデザインの入力にせず、新旧比較にだけ使用する。

## 参考写真と再現する範囲

| 対象 | 写真の出典 | 作った特徴 |
|---|---|---|
| 撮影用トイレ | [LIXIL 部品ナビ BC-250S](https://buhinnavi.lixil.co.jp/toilet/tost-09?keyword=BC-250S) | 丸い便器と台座、閉じた別の便座・蓋、角の丸いタンクと別の蓋、蝶番、横の洗浄レバー |
| じょうろ | [Gemplers: Behrens Galvanized Steel Watering Can](https://gemplers.com/products/classic-steel-watering-can) | 薄い金属の胴体と肩、開いた給水口、上部の持ち手と赤いグリップ、後ろの取っ手、長い注ぎ口、穴模様の散水口、巻いた縁 |
| 優勝カップ | [Budgettrophy: Trophy cups](https://www.budgettrophy.com/en/trophies.html) | 中空の金色の杯と厚い縁、左右の曲線の持ち手、段の付いた支柱と足、黒い台座、銘板 |

写真は閲覧だけで、画像の同梱やテクスチャへの転用はしない。企業名・ブランド印刷は付けない。見えない裏面はゲーム用として補完している。

細かい傷・金属の亜鉛結晶模様・微細な印刷は省略。散水口の小穴は暗い小円で表現し、穴の内側を全て貫通させる加工は行わない。じょうろの給水口とカップの内側は実際のメッシュで開ける。トイレは便座・蓋を別形状で作るが、開閉の挙動は追加しない。

## ゲームへの組み込み

既存3項目のGLB参照だけを `_photo` に変更。種類名・配置・タグ・質量・寸法指定・袋から出る条件を維持。トイレ0.9m／4kg、じょうろ0.7m／0.8kg、カップ0.55m／0.8kg。旧GLBは残す。カタログ写真もこの3点だけ更新。

トイレは既存の `prop_shapes.gd` の3形状を維持し、タンク位置・上端・便器の前後寸法をそれに合わせる。じょうろとカップは既存の外形の箱の当たり判定。袋から出る2個には処理券を付けず、トイレはタンクの前面へ貼る。

## 再生成・表示確認

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/photo_props_batch02/source/build_assets.py
```

Blender 5.2.2 LTSの独立プロセスで実行。`fresh_props`／`refined_props` の既存ヘルパーを再利用する。出力は `../../scrap/` のGLB、編集可能なblendと確認PNGは `artifacts/photo-props-batch02-20261017/`。実測値は `build_manifest.json`。画像テクスチャを使わず、材質単位でバッチ化する。

`res://tools/refined_props_review.tscn` の `show_fresh_pair("scrap_toilet")` などで左が旧・右が新。同じ角度・照明・寸法指定で比較。`show_photo_prop` の第2引数trueで背面。`show_photo_lineup(["scrap_toilet","scrap_watering_can","scrap_trophy_cup"],0.93,1.85)` で3点並び。`audit_props`／`save_catalog` へ同じ種類の配列を渡す。

確認結果：3点の実行時監査はエラーなし。前後・比較・カタログ写真を目視し、金色のカップは暖色照明でも確認。`bash tools/run_some.sh collider_fit_test junk_bags_test` は2本とも通過。
