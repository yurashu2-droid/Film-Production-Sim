# UVI Playerをコードから鳴らす

インストール済みの **UVI Player VST3** をPythonから直接呼び出し、JSONで指定したMIDIノートをステレオWAVへ書き出すローカル制作ツールです。DAW、仮想MIDIケーブル、スピーカー録音は使いません。

## このPCで準備済み

- UVI Player 5.0.0 / Windows 64 bit、PrismaのiLok認証。
- Pedalboard 0.9.26。追加ダウンロードは約3.7MB。
- Python依存パッケージの保存先：`%USERPROFILE%\.cache\codex-audio\python-deps`。
- 保存済み音色：`output/uvi_direct/glock.vstpreset`（Prisma / Toy Blue Glockenspiel）。

`.vstpreset`と生成音はローカル専用で、Gitには含めません。別のPCで使う場合はUVI Player・音色ライブラリ・iLok認証・Pythonと`requirements.txt`のパッケージが必要です。

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

## 音色を変更する

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

参照：
- https://spotify.github.io/pedalboard/reference/pedalboard.html
- https://manual.uvi.net/uvi-player/en/
- https://www.uvi.net/index.php/end-user-license-agreement
