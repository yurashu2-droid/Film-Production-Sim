# 画像生成を使う7方式

VFX Lab の大項目「生成素材」に01〜07を追加。既存の墨金流渦は残した。
画像7枚をbuilt-in image_genで生成し、原画を変更せずここへコピーした。
生成時のプロンプトは [PROMPTS.json](PROMPTS.json)。各画像は完成エフェクトの貼り絵ではなく、別の実行データの入力になる。

|選択ID|画像|コードへ渡すデータ|運動と終わり|
|---|---|---|---|
|gen_silhouette|silhouette.png|輝度の行区間・密度から3D断面|圧力を上へ伝え、供給停止後は舌が昇りながら冷える|
|gen_curve|branch_lines.png|細線化と連結グラフから3D枝経路|枝ごとに伝播し、根から先へ供給が切れる|
|gen_emission|crack_emission.png|輝度の確率分布から実際の発生位置・強度|先行核と遅れた後流が曲がり、裂けて排出される|
|gen_mesh|petal_mask.png|マスク輪郭の三角形化・厚み|順に曲げて開花、破断・回転落下・着地する|
|gen_flow|streamlines.png|局所構造テンソルから接線・整合度|不等間隔の供給が流れ場を進み、巻き返して落水する|
|gen_erosion|lacquer_fractures.png|亀裂と輝度から領域分割・剥離順|曲面を領域ごとに剥がして落とし、地面へ戻す|
|gen_material|material_height.png|凹凸・正規化ノーマル・局所AO・粗さ|黒金の液流を変形・排出し、着地した溜まりが地面へ沈む|

## 材質の計算

`res://vfx/bake_ai_material.gd` は生成原画をheightとして解釈し、512²のmaterial_normal/ao/roughness.pngへ数値変換する。
ノーマルはheightの差分から正規化した接線空間ベクトル。AOは近隣heightとの差を使う局所凹凸の近似で、世界やメッシュの遮蔽を焼いたものではない。粗さはheightから設計した対応値で、測定値ではない。
`gen_material.gdshader` は照明ありで実際にNORMAL_MAP/AO/ROUGHNESSを使う。高度は頂点にも小さく反映し、中心線にも放出時刻の遅れを持つ曲がりを入れた。

## 再生・撮影

Godotエディタは不要。`vfx_lab.tscn -- --only=gen_silhouette` 等で再生。
`res://tests/shots/review_ai_methods.gd` で全体/動き/終端/前/横を撮影できる。`--record --duration=7.2` は216フレーム、30fps。
`tools/export_ai_methods.py` は最終フレームから番号付き動画7本と比較動画2本を作る。

## 評価範囲

生成画像の採用、実際のピクセル抽出、描画・停止・寿命と連続コマを確認する。動画の通常速度の再生を人間と同じ方法で鑑賞した評価ではない。7方式の比較用の実装で、ユーザーによる見た目の評価は未了。
材質原画は画像生成の陰影をheightへ解釈したもの。正確な物理計測のheightではない。曲線・流れ場の抽出も低解像度の近似。
