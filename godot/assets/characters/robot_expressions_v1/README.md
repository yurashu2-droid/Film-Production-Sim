# CastM02 表情素材 v1

通常・笑顔・驚き・困り・怒り・眠りの静止画候補。ゲームへの切り替え実装は含まない。
既存のGLB、元の顔アトラス、ゲームコードは上書きしていない。commit・pushは保留。

## 基準にした既存素材

- モデル: `res://assets/cast/castM02_game.glb`
- 画面ノード: `CAST_M02_RIG/Skeleton3D/castM02_game_screen`
- マテリアル: `castM02_screen`、emission energy multiplier = 1.0
- 元の顔: `res://assets/cast/castM02_game_castM02_screen.png`
- 元の制作コード: リポジトリ直下 `make_m02_screens.py`
- 元のアトラス: 8列×16行、1コマ128×112、論理ドット32×28。
- 顔メッシュのUV範囲: U=0〜0.125、V=0〜0.0625。通常顔を固定表示している。
- 元モデル説明: `codex_src/FilmCrew_20261006_R1/README_JA.txt`。平面ディスプレイ保持、表情はテクスチャ／マテリアル変更。

通常顔は元画像の左上セルをそのまま抽出。他5種は同じ論理グリッド、橙色、LEDの隙間とガンマ、左右非対称の目を基準に新規制作。
外部の生成画像や第三者スプライトは使用していない。

## 素材と確認画像

- `neutral.png` / `happy.png` / `surprised.png` / `worried.png` / `angry.png` / `sleep.png`: 128×112のRGB個別PNG。
- `native/`: 32×28の論理ドット。線幅・感情の読みやすさの確認用。
- `atlas_6.png`: 1列×6行の静止画アトラス。行順とサイズは `manifest.json`。
- `comparison_2d.png`: ラベル付き2D素材比較。
- `readability.png`: 128×112の原寸と32×28の論理ドット比較。
- `review.png`: 大きい顔と全身は既存GLBへの仮適用をGodotで描画。右下のみ2D素材原寸。
- `diagonal_review.png`: 同じモデル・同じ条件による斜めからの実描画。
- `renders/`: 無加工のGodotキャプチャ20枚。既存顔2枚、新表情6種×全身・正面顔・斜め顔。
- `render_inspection.json` / `review_checks.json` / `source_guard.json`: 描画条件と元素材のハッシュ不変の記録。

## 後で組み込む場合のUV

これは検証用設定であり、本編には適用していない。

個別PNGを既存スクリーンの `emission_texture` に割り当てる場合、元のUVを保ち `uv1_scale = Vector3(8, 16, 1)`、offset=0。
`atlas_6.png` なら scale=(8, 16/6, 1)、offset=(0, row/6, 0)。元のマテリアルと同じフィルタ（3: linear with mipmaps）を保持し、clampを用いる。
検証用シーンでは元マテリアルを複製して発光強度・ガラス・モデル形状を保持している。
元インポート設定は変更せず、PNGを `Image.load()` から読み込み、表示時のミップマップを生成する。PNG原寸と論理ドット確認はnearestで拡大する。

## 再制作・再描画

Python + Pillowで `build_assets.py`、`capture_preview.py`、`build_review.py` の順に実行。
`capture_preview.py` は `tools/dev_session.py` の独立セッション `robot_expressions_v1` を非表示で起動し、取得後にそのセッションだけ停止する。
専用の `preview.tscn` / `preview.gd` だけで仮適用する。本編のmain/player/props/UIには介入しない。
通常顔の元セル一致、共通パレット、画面余白は制作コードで確認。美術的な採用はユーザーの比較確認待ち。
通常顔の実描画は元のアトラス表示とのRGB差が最大1/255以内で、GPUの丸め範囲で一致。詳しい値は `review_checks.json`。
