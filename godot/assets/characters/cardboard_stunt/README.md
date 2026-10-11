# 段ボールスタントマン / CHEAP SHOT 01

導入した3D制作スキルを使った、オリジナルの小さな制作例。
大きな頭・非対称の束髪・紺の作業服・テープ補修した段ボール防具・赤い手袋とブーツ。
顔は固定表情、手はミトン。段ボールは薄い前後板・側板・肩の支持部に分けている。

## 成果物

- `cardboard_stunt.glb`：Y上、+Z正面、約2m。8,576三角形、90メッシュ、11マテリアル。
- `build_model.py`：形状・関節・配色・アニメーションを編集できる生成元。PythonとPillowを使用。
- `geometry_report.json`：生成した各メッシュの三角形数、境界辺、非多様体辺、最小面積。
- `capture_study.py`：常駐Godotセッションで全方向・全96コマを保存する撮影手順。
- `preview/`：Godotで実際に描画した完成候補と動き。
- `res://cardboard_stunt_lab.tscn`：GLBを読み込み、合図アニメーションを再生する独立した展示シーン。

ルートから起動：

```powershell
& ./tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot res://cardboard_stunt_lab.tscn
```

Spaceで再生・停止、左右キーでキャラクター回転、Rで初期ビュー。
タイトル文字はOSのフォントを使用する（Yu Gothic / Noto Sans CJK JP / Arial）。

再生成・非表示撮影：

```powershell
python godot/assets/characters/cardboard_stunt/build_model.py
python godot/assets/characters/cardboard_stunt/capture_study.py
```

撮影先は `artifacts/cardboard-stunt/`。展示のGPU描画にWindowsの常駐セッションを使用する。
GLBは外部テクスチャを必要とせず、胸の印字画像を内部に持つ。

## スキルの適用と確認範囲

- **model-stylized-characters**：全体比率、大・中・小の形、顔の奥行き、多方向での組み立て確認。
- **model-stylized-hair**：前髪・左右の側頭部・後頭部の別々の流れ、厚みのある閉じた束、埋めた根元と下地。
- **model-stylized-materials**：紙の板厚・支持部・切断面の芯・テープ・ゴムと布の粗さ。細かい紙繊維は省略。
- **retopologize-game-characters**：出力三角形と縮退面・非多様体辺の確認。元モデルからのリトポではなく新規メッシュ設計。
- **animate-3d-characters**：準備→右腕を上げる→手首で合図→戻って収める、4秒24fpsの短い演技。

Godot 4.7.2でGLBそのものを再読み込み、正面・左右・背面・上面・斜めの描画を確認。
全96コマを確認し、両足の接地点の移動は0m。胸当ての服のはみ出しと髪の下地の隙間を修正した。
ループ端は同じ関節角度と静止区間を持つ。

今回のモデルは各パーツを関節ノードへ親子付けした人形方式。
スキニング・指・表情の変形、歩行、布の物理シミュレーションは含まない。
メッシュごとの描画が多いため、本編の大人数用途へ採用する際は用途に合わせた結合・リグ化が必要。
検証した動きはこの合図クリップに限る。

外部のキャラクターモデル・素材画像は使わず、形状と印字は生成元から作成。
手順の出典はユーザー提供 `Codex_3D_Character_Skills_20261010.zip` の5スキル。
Blenderは接続されていなかったため、この制作例には使用していない。
