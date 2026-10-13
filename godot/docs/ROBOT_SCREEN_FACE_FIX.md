# CastM02の既存表情の接続

CastM02の顔は `castM02_game_castM02_screen.png` の16状態×8コマのLEDアトラス。
元のコマ数・FPS・ループ指定はリポジトリ直下の `game/castM02_screen.json` と `make_m02_screens.py` にある。
ゲーム用GLBには体の16クリップがあり、表情ボーン用の `M02_face_*` クリップはない。
画面のUVは左上の1コマに合わせてあるので、ゲーム側でUV offsetを送らないと通常顔のままになる。

これまで `cast_visual.gd` の `_setup_face()` は骨の表情クリップだけを探し、CastM02では終了していた。
M02専用の `robot_screen_face.gd` を接続して、元の画面コマをAnimationPlayerの離散キーで再生する。
16状態のFPS・ループを元データに合わせ、通常顔の8コマに含まれるまばたきも使う。
`shock` と `ok` はループせず最後のコマを保持する。

元マテリアルをインスタンスごとに複製し、その画面だけのUV offsetを動かす。元の発光テクスチャ、ガラス設定、モデル、体の骨アニメーションは変更しない。
既存の `set_face()`、演技メニュー、役者、録画・復元、受信状態の経路で利用できる。
離散コマなので状態を混ぜず先頭コマへ即時に切り替え、人間の表情ボーンの補間はそのまま使う。

本編で編集したのは `cast_visual.gd` の `_setup_face()` と `set_face()` のM02分岐のみ。
同ファイルのしゃがみ保持用carry差分は以前からの別作業であり、この修正には含めない。
main / player / prop / hud / production_hud、元GLBと元PNG、新作 `robot_expressions_v1` は変更していない。

## 専用確認

`Godot --headless --fixed-fps 60 --path godot --script res://tests/robot_screen_face_test.gd`

実ゲームのプレイヤーを使い、全16状態の8コマ・FPS・ループ／保持、まばたき、同状態の連続要求、複数ロボットの独立性、元の体クリップの保持、演技／録画／受信／NPCの接続、人間の表情、エンジンの通常更新を確認する。
固定ネットワークポートや全体テストは使わない。

`tools/capture_robot_screen_face.py` は独立した非表示セッション `robot_screen_face_fix` を使い、main.tscnの実プレイヤーを修正前後で描画し、そのセッションだけ停止する。
`tools/build_robot_screen_face_review.py` が比較PNGとGIFを作る。
無加工の実描画、比較、ログは `tools/diagnostics/robot_screen_face_fix/`。
tools配下は既存の.gitignoreで無視されるため、比較ツールを保存対象にする場合は明示的に選択する。

新作6PNGは非適用のまま残す。commit・pushは保留。
