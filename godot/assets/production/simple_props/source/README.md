# 簡略版モデル3点：許容する細かさを決めるための試作

名称と文章だけから、組み込み画像生成ツールで新しい資料を生成。元モデルの画像は入力していない。プロンプトは `prompts.json`、資料は各 `*_reference.png`。

| 段階 | モデル | 残した要素 | 意図して省いた要素 |
|---|---|---|---|
| A：輪郭中心 | 街灯 | 台座、柱、四角い灯具、屋根 | ガラスの透過・反射、電球、配線、装飾金具 |
| B：特徴まで | 振り子時計 | アーチ、12目盛りと針、振り子 | 木目、文字、窓ガラス、内部機構、裏面の金具 |
| C：用途が読める部品まで | 自動販売機 | 商品2段、選択ボタン、支払い部、浅い取出口 | 商品ロゴ、細かな説明、冷却機構、裏面の通気穴 |

全点、画像テクスチャなし・単色PBR材質・基本1段の面取り。傷や小さなねじは作らない。前回の宝箱／冷蔵庫（各約2万三角形）ほどの作り込みを行わず、ゲームで読める特徴を優先する。段階は異なる物体間の比較で、面数だけで品質の可否は判定しない。許容ラインはユーザーの見た目の評価で決める。

既存の種類名・配置・寸法指定・重さ・当たり判定の構成を維持し、`production_scrap.gd` の参照ファイル3個を `_simple.glb` に差し替えている。旧モデルは残す。発注カタログの写真も3個更新する。

## 再生成

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/simple_props/source/build_assets.py
```

前回の `refined_props/source/build_assets.py` の形状・出力ヘルパーを再利用し、このスクリプトで面取りを1段に置き換える。Blender 5.2.2 LTS。GLBは `../../scrap/` に、編集用blendは `artifacts/simple-props-20261017/` に出力。実測値は `build_manifest.json`。

表示確認用シーンは `res://tools/refined_props_review.tscn`。`show_pair("scrap_lamp")` などで左が旧版、右が今回版。`show_simple_lineup()` で今回の3個を並べる。`save_catalog` と `audit_props` は種類名の配列を第1引数として受け取る。確認画像と実行時監査結果は `artifacts/simple-props-20261017/`。

外部素材なし。資料から特徴を絞って本プロジェクト用に形状とコードを制作。資料フォルダは `.gdignore` により実行用のインポートから除外する。
