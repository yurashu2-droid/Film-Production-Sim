# UVI Playerをコードから鳴らす

インストール済みの **UVI Player VST3** をPythonから直接呼び出し、JSONで指定したMIDIノートをステレオWAVへ書き出すローカル制作ツールです。DAW、仮想MIDIケーブル、スピーカー録音は使いません。

## 音色を開いてバッチで登録する

1. このフォルダの **`01_open_voice_editor.cmd`** をダブルクリックする。初回の読み込み後、音色登録用のUVI画面が開く。
2. その画面で好きな音色を選び、**Loading Programが消えるまで待つ**。
3. **`02_register_current_voice.cmd`** をダブルクリックする。

現在の音色名とbankを自動で取得し、設定を保存して音色一覧に追加します。保存結果の`id`がClaudeやコードから呼ぶ名前です。ID入力やカタログの手編集は不要。実際に演奏する必要もありません。

保存時はUVI画面が一瞬閉じて開き直ります。次の音色を選び、同じ登録バッチを実行すれば続けて登録できます。終了するときはUVI画面を閉じます。同じプリセットの再登録は保存済み設定を更新します。**登録対象は`01_open_voice_editor.cmd`から開いたUVI画面です。**

コマンドで同じ操作を行う場合は `uvi.cmd studio` と `uvi.cmd capture`。登録画面が起動していない場合、登録バッチは案内エラーを表示します。認識できない状態や複数パートのマルチを誤った名前で保存せず、単一の音色を選ぶよう案内します。自動命名はUVI Player 5.0.0の保存形式で確認しています。

## Claude・Codex共通の音色一覧

```powershell
.\tools\uvi_direct\uvi.cmd voices
.\tools\uvi_direct\uvi.cmd voices --tag impact
```

登録した音色は **`%LOCALAPPDATA%\UVI-Code-Voices\<ID>.vstpreset`** に保存し、追加カタログは同フォルダの`voices.local.json`に記録します。同じPC・WindowsユーザーのClaudeとCodex、別のworktreeから共用できます。保存先を変更する場合は両者に同じ`UVI_VOICE_DIR`を設定してください。

`voices`には候補一覧と自動登録した音色が表示されます。**`registered: true` が、このPCで実際に使える音色です。** 候補が一覧にあるだけでは登録済みになりません。

```powershell
.\tools\uvi_direct\uvi.cmd render --voice robot --score tools\uvi_direct\pickup.example.json --output output\uvi_direct\robot.wav
```

`batch`でも`--state`の代わりに`--voice <ID>`を指定できます。Claude向けの入口はリポジトリ直下の`CLAUDE.md`、詳しい手順は`.claude/skills/uvi-se/SKILL.md`です。

## このPCで準備済み

- UVI Player 5.0.0 / Windows 64 bit、PrismaのiLok認証。
- Pedalboard 0.9.26。追加ダウンロードは約3.7MB。
- Python依存パッケージの保存先：`%USERPROFILE%\.cache\codex-audio\python-deps`。
- 保存済み音色：`output/uvi_direct/glock.vstpreset`（Prisma / Toy Blue Glockenspiel）。

`.vstpreset`、追加カタログ、生成音はローカル専用で、Gitには含めません。別のPCで使う場合はUVI Player・音色ライブラリ・iLok認証・Pythonと`requirements.txt`のパッケージが必要です。

以下のコマンドは**リポジトリ直下**からPowerShellで実行します。

## 保存済みの音色でSEを書き出す

```powershell
.\tools\uvi_direct\uvi.cmd render --state output\uvi_direct\glock.vstpreset --score tools\uvi_direct\pickup.example.json --output output\uvi_direct\pickup.wav
```

音程・発音時刻・長さ・強さはJSONで指定します。音程はMIDIノート番号（中央ドは60）、時刻と長さは秒、velocityは1〜127、channelは省略時1です。たとえば：

```json
[
  {"note": 84, "start": 0.0, "duration": 0.07, "velocity": 92},
  {"note": 91, "start": 0.095, "duration": 0.12, "velocity": 105}
]
```

既定の出力は48kHz・16bit PCM・ステレオ、ピーク-3dBFS。最後のノートオフから0.8秒の余韻を含みます。`--tail 1.5`、`--rate 44100`、`--peak-db -6`で変更できます。無音なら成功扱いせずエラーにします。

## 同じ音色で複数のSEをまとめて作る

```powershell
.\tools\uvi_direct\uvi.cmd batch --state output\uvi_direct\glock.vstpreset --scores tools\uvi_direct\pickup.example.json tools\uvi_direct\confirm.example.json --output-dir output\uvi_direct\batch
```

プラグインと音色を1回だけ読み込みます。出力名は各スコアのファイル名（拡張子を`.wav`に変更）。各WAVの隣に、レンダリング時間・音量・入力スコアなどを記録したJSONも保存します。

このPCでベル音色を実測した例：プラグイン読み込み約10.5秒、初回の約1秒のSE生成約12.1秒、同じインスタンスで2つ目の生成約2.2秒。音色やPCによって変わります。

## 音色を変更する（手動でstateを指定する場合）

```powershell
.\tools\uvi_direct\uvi.cmd edit --state output\uvi_direct\new_sound.vstpreset
```

本物のUVI Player画面が開きます。音色と加工を選び、読み込み完了後にウィンドウを閉じると設定が保存されます。以後はそのファイルを`--state`に渡せば画面操作なしで使えます。既存のstateを指定すると、その設定を開いて編集できます。

## Pythonから使う

このスクリプトと同じディレクトリをモジュール検索先に追加したうえで：

```python
from uvi_direct import DEFAULT_PLUGIN, load_instrument, load_score, render

instrument = load_instrument(DEFAULT_PLUGIN)
instrument.load_preset('output/uvi_direct/glock.vstpreset')
messages, end = load_score('tools/uvi_direct/pickup.example.json')
report = render(instrument, messages, end + 0.8, 48000, -3,
                'output/uvi_direct/from_python.wav')
```

同じ`instrument`で`render()`を繰り返せます。VST3はメインスレッドで操作してください。

## 留意点

- 初回のプラグイン読み込み・音色準備には時間がかかります。候補を作るときは`batch`で同じインスタンスを再利用してください。
- WindowsのVST3フォルダ全体ではなく、内部の`Contents/x86_64-win/UVI Player.vst3`を読み込みます。別の場所なら、サブコマンドの前に`--plugin <実体のパス>`を指定します。
- 手元で保存した信頼できるstateだけを読み込んでください。UVIライブラリやライセンスを埋め込んだり回避したりする機能はありません。
- 今回のWAVは試聴・制作確認用です。単独のSEの製品同梱については、UVIの利用条件を別途確認してください。

## 画面を使わない検証

```powershell
python -m unittest discover -s tools/uvi_direct -p test_capture.py
```

この検証はGUIやUVI本体を起動せず、自動命名・保存・一覧への反映・保存要求の受け渡しとメインスレッドでの状態取得を確認します。実機の画面上での選択操作や、別バージョンのUVIの動作まで保証するものではありません。

参照：
- https://spotify.github.io/pedalboard/reference/pedalboard.html
- https://manual.uvi.net/uvi-player/en/
- https://www.uvi.net/index.php/end-user-license-agreement
