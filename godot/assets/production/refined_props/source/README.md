# 画像生成の新規資料から作った小道具・大道具（2026-10-17）

最初の試作は「宝箱」と「レトロ冷蔵庫」の2点。元のモデル画像を入力にせず、名称と文章だけで制作資料を画像生成した。採用した資料とプロンプトをこのフォルダに保存している。元モデル画像を使った初期案は採用していない。資料フォルダは `.gdignore` で実行用リソースから除外している。

## ゲームへの組み込み

- `scrap_chest`: `P029_treasure_chest_refined.glb`。最長辺0.7m、5kg。板組み、湾曲した蓋、金属の補強、輪の持ち手、背面の蝶番、貫通した鍵穴。
- `scrap_fridge`: `S044_retro_refrigerator_refined.glb`。高さ1.4m、9kg。えんじ色の2枚扉、パッキン、クロームの取っ手と蝶番、脚、背面の冷却管・コンプレッサー・電源コード。

`production_scrap.gd` の既存2項目のファイルだけを切り替える。種類名、生成順、重さ、正規化する寸法、タグ、配置は従来どおり。旧GLBは比較用に残す。

木目は文章から別途画像生成した `../walnut_albedo.png` をUVで割り当て、GLBへ埋め込んだ。金属、塗装、ゴムは形とPBRの色・金属度・粗さで区別している。材質ごとにまとめ、宝箱4メッシュ、冷蔵庫7メッシュにして出力する（処理券はゲーム側で追加）。

`DisposalTicketAnchor` は処理券を貼る場所。Godotでのローカル+Zが面の外向き。`dump_dressing.gd` はこの目印があれば指定面へ貼り、無い旧モデルは従来の自動配置を使う。鍵穴・取っ手を券で隠さないための指定。

## 再生成

Blender 5.2.2 LTSの新規バックグラウンドプロセスで実行する。開いているBlenderには接続しない。

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/refined_props/source/build_assets.py -- --no-renders
```

GLBは `godot/assets/production/scrap/`、編集可能な `.blend` はリポジトリ直下の `artifacts/prop-refresh-20261017/` へ出力する。`--no-renders` を省くとBlenderの正面・背面プレビューも生成する。`build_manifest.json` は実測の面数・範囲。

## 表示確認と写真の更新

```powershell
python tools/dev_session.py --name prop_refresh start --mode render --scene res://tools/refined_props_review.tscn
'{"op":"call","method":"show_pair","args":["scrap_chest",false]}' | python tools/dev_session.py --name prop_refresh request -
python tools/dev_session.py --name prop_refresh capture artifacts/prop-refresh-20261017/chest_pair_front.png
'{"op":"call","method":"audit_props"}' | python tools/dev_session.py --name prop_refresh request -
'{"op":"call","method":"save_catalog"}' | python tools/dev_session.py --name prop_refresh request -
```

`show_pair` は左が旧モデル・右が新モデル。`show_detail` は新モデル1点。第2引数で背面、`show_pair` の第3引数で暖色照明に切り替えられる。`audit_props` は寸法・重さ・当たり判定・処理券の位置・木目の埋め込み・有限な頂点を確認する。`save_catalog` はこの2点の発注画面用写真だけを撮り直す。

資料と木目は組み込みの画像生成ツールで作成し、外部のモデル・ブランド素材は使っていない。形状と再生成コードは本プロジェクト用に作成したもの。
