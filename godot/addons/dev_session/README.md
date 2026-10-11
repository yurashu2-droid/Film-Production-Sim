# Godot Dev Session

エディタを開かず、Godot を裏で常駐させて、コード更新・ゲーム操作・状態確認・画像保存を行う開発用アドオン。通常起動の autoload や設定を変更せず、専用ランナーを明示的に起動した場合だけ動く。Python 標準ライブラリのみを使用する。

## 起動と更新

リポジトリ直下で実行する。

```powershell
# 画面を一切作らない挙動確認
python tools/dev_session.py start --scene res://main.tscn

# 画像も確認したい場合: ウィンドウを隠して GPU で描画（Windows）
python tools/dev_session.py --name visual start --mode render --scene res://motion_lab.tscn

# 同じ start は既存のセッションを再利用する。status で PID を確認できる
python tools/dev_session.py --name visual status

# 変更した GDScript を状態を保って反映
python tools/dev_session.py --name visual reload res://scripts/player.gd

# スクリプトの保存を監視して自動反映。Ctrl+C は監視だけを終了する
python tools/dev_session.py --name visual watch

# シーン配置・初期化処理をやり直す（Godot 本体は再起動しない）
python tools/dev_session.py --name visual load res://motion_lab.tscn

# 物理フレームを60コマ進め、停止して画像を保存
python tools/dev_session.py --name visual step 60
python tools/dev_session.py --name visual capture artifacts/dev-session/check.png

# 自分のセッションだけを停止
python tools/dev_session.py --name visual stop
```

ロード直後と `step` 終了後は一時停止する。停止中もコード反映・状態確認・PNG 保存は可能。表示モードでも音は無効で、マウスを捕捉しない。停止中は画像要求があったときだけ描画する。ログ・接続情報は `godot/.godot/dev_session/<名前>.log` / `.json` に保存する。

停止中に送ったアクションの「押した瞬間」は、次の `step` または連続実行を始める最初の物理コマへ渡す。入力は `pressed: false` を送るまで保持する。コマ送り中などの応答待ちに `start` が時間切れになっても、別のワーカーは起動しない。

## 操作を組み合わせる

汎用操作は `request` に JSON を渡す。PowerShell の引用符問題を避けるには、標準入力から渡す。

```powershell
'{"op":"call","method":"start_trial"}' | python tools/dev_session.py --name visual request -
python tools/dev_session.py --name visual step 18
'{"op":"get","node":"P1","properties":["velocity","_run_start_elapsed"]}' | python tools/dev_session.py --name visual request -
python tools/dev_session.py --name visual capture artifacts/dev-session/push-off.png
```

Python から連続して実行することもできる。

```python
import sys
sys.path.insert(0, "tools")
from dev_session import Session

s = Session(name="visual")
s.start("render")
s.request({"op": "load", "scene": "res://motion_lab.tscn"})
s.request({"op": "call", "method": "start_trial"})
s.request({"op": "step", "frames": 18})
print(s.request({"op": "get", "node": "P1", "properties": ["velocity"]}))
s.request({"op": "capture", "path": "C:/path/to/check.png"})
```

| 操作 | フィールド | 内容 |
|---|---|---|
| `status` | なし | PID・シーン・停止状態・進めた物理フレーム数・実ウィンドウの表示状態 |
| `load` | `scene: res://…tscn` | シーンを再構築。入力を解除し、一時停止 |
| `tree` | `node`、`depth`（既定3） | ノード構成とスクリプトを読む |
| `get` | `node`、`properties: [名前,…]` | プロパティを読む |
| `set` | `node`、`property`、`value` | プロパティを変更。Vector3 は `[x,y,z]` で指定可能 |
| `call` | `node`、`method`、`args: […]` | メソッド呼び出し。終了後は元の停止状態へ戻す |
| `input` | `action`、`pressed`、`strength`（既定1） | `move_forward` / `run` などの InputMap アクションを押す・離す |
| `step` | `frames: 1〜3600` | 実際の物理処理を指定フレーム数進める |
| `pause` | `paused: true/false` | 停止・連続実行 |
| `reload` | `path: res://…gd` | コード更新。構文エラー時は前のコードへ戻す |
| `capture` | `path: 保存先.png` | render モードの画像を書き出す |
| `shutdown` | なし | 開発セッションを終了 |

`node` はシーンからの相対パス（既定 `.`）。`tree` に出る絶対パスも指定できる。TCP は `127.0.0.1` のみで待ち受け、CLI が生成するセッション用トークンで接続する。

## 反映できる範囲

- メソッドの内容などは `GDScript.reload(true)` で、実行中のインスタンスを保って更新する。
- 初期化済みの定数から作った物体・アニメーション、`_ready` の変更、継承などの構造変更は `load` で再構築して確認する。すべての変更を状態保持で差し替えられるわけではない。
- `watch` は `.gd` を監視する。シーンやインポート済みの画像/GLB は監視対象外。新しい素材は通常のインポート手順が必要。
- headless は描画のない実ロジック確認用。PNG は Windows の render モードを使う。
- 任意のゲームコードの例外は `.log` で確認する。ゲーム全体が無限ループした場合は、ホットリロードでの復旧対象外。
- 本アドオン自身の変更はセッションを停止・起動して反映する。

通常のゲーム操作とは別の開発専用経路である。配布時は `addons/dev_session/*` を export の除外対象にできる。

## 検証

```powershell
python -m unittest discover -s tools/tests -p test_dev_session.py
```

実エンジンで、同一 PID の再利用・入力・正確なコマ送り・コード更新と状態保持・構文エラーからの復帰・非表示ウィンドウの PNG 保存・停止を確認する。

参考: [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)、[Script.reload](https://docs.godotengine.org/en/stable/classes/class_script.html)、[SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)。エディタ中心の制作には [Godot MCP Toolkit](https://github.com/NPGameDev/godot-mcp-toolkit) という既存の選択肢もある。
