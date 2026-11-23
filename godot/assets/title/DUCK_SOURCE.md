# ホームの搬送用アヒル

`P049_rubber_duck_refined.glb` は所有者の `assets/production/scrap/P049_rubber_duck.glb` を元にした派生モデル。
元の GLB は保存したまま。ホームの搬送演出だけが派生モデルを使用する。

- 頭・胴・尾の継ぎ目を接続し、元のシルエットを維持して低ポリゴン化。
- くちばしの上下と薄い口の線、鼻孔、目の小さなハイライトを追加。
- 羽を体に沿った薄い黄色の形に変更。
- 1,834 三角形。画像テクスチャなし、単色マテリアル。
- 編集用の `tools/models/title_duck/P049_rubber_duck_refined.blend` も保存。

再生成は `tools/refine_title_duck.py` を Blender のバックグラウンド実行で開く。
素材の利用条件は `assets/production/scrap/SOURCE.md` の所有者作成素材と同じ。
