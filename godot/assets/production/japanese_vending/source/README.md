# 写真の日本型飲料自販機へ修正

ユーザー提供の `C:/Programer___Amano/遊び場/OpenCode遊び場/images (1).jpe` を形状・配置の資料として使用。今回は実物写真から直接モデリングしており、画像生成は行っていない。旧モデルや不採用の画像生成資料からはデザインを引き継がない。

## 再現する範囲

- 青い縦長の筐体と前扉の継ぎ目。
- 白枠の広い商品窓、3段24本の缶・ペットボトル、各商品の下の楕円ボタン。
- 右側の緑の状態表示と硬貨投入口、下段の紙幣口・返却レバー・説明カード。
- 左の赤い広告面、下部の横長の受取口とフラップ、黄色い釣銭返却口、最下部の通気口。

作り込みは承認されたティーポット・旅行鞄を目安に、輪郭・厚み・接合・大きな機能部品を優先。実在の商品名・広告・会社ロゴは汎用の図形と文字に置き換える。ガラスの光学表現、細かな価格表示や包装の印刷、傷、裏面の機械は省略。背面は写真に写っていないため、平らな筐体として補完した。

`production_scrap.gd` の `scrap_vending` の参照だけを `S059_vending_machine_jp.glb` に変更。種類、配置、タグ、長辺1.5m、9kgを維持。旧GLBは残す。箱の当たり判定は既存ローダーが新しい外寸から生成。処理券は下段の空いている面へ配置。

## 再生成・表示確認

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/japanese_vending/source/build_assets.py
```

Blender 5.2.2 LTSの独立したプロセスで作成する。`fresh_props` と `refined_props` の形状・GLB出力ヘルパーを再利用する。材質ごとにまとめ、画像テクスチャは使わない。実測値は `build_manifest.json`。

`res://tools/refined_props_review.tscn` の `show_detail("scrap_vending")` で新モデル、`show_pair("scrap_vending")` で旧モデルとの比較。`audit_props(["scrap_vending"])` で寸法・重さ・箱の当たり判定・処理券・有限頂点を確認する。`save_catalog(["scrap_vending"])` でこの1点の発注写真を更新。編集用blend・正面背面PNG・監査結果は `artifacts/japanese-vending-20261017/`。資料フォルダは `.gdignore` で実行用のインポートから除外する。
