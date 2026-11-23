---
name: uvi-se
description: Use when creating or revising game sound effects with the locally installed UVI Player, Prisma, or UVI Starter, or when rendering registered UVI voices from code. Applies to Claude and Codex in this Windows project.
---

# UVIでSEを作る

このPCではUVI PlayerのVST3をPythonから直接鳴らせる。共通ツールは `tools/uvi_direct/uvi.cmd`、説明は `tools/uvi_direct/README.md`。プロジェクト直下から実行する。

## 音色を探す

```powershell
.\tools\uvi_direct\uvi.cmd voices
.\tools\uvi_direct\uvi.cmd voices --tag impact
```

`registered: true` の音色を選ぶ。`voices` は候補カタログとこのPCでユーザーが追加登録した音色をまとめて表示する。候補が載っていても `registered: false` ならまだ使えない。衝撃・ロボット・金属・風切り・SF・ドラム・低音・プラック・シンセなど、依頼に合う登録済み音色から選ぶ。複数種類を求められたら、音程やリズムだけでなく音色の違いも使う。

音色の状態ファイルは **`%LOCALAPPDATA%\UVI-Code-Voices\<ID>.vstpreset`**、追加カタログは同フォルダの`voices.local.json`。同じPC・WindowsユーザーでClaudeとCodexが共用し、worktreeにも依存しない。必要なら環境変数 `UVI_VOICE_DIR` で保存先を変更できる。これらのstate・追加カタログ・出力音声はGitへ追加しない。

## コードで鳴らす

スコアはJSONの配列。`note`はMIDI番号（中央ド=60）、`start`と`duration`は秒、`velocity`は1〜127。`channel`は省略時1。たとえば短い2音：

```json
[
  {"note": 60, "start": 0, "duration": 0.09, "velocity": 96},
  {"note": 67, "start": 0.08, "duration": 0.14, "velocity": 108}
]
```

```powershell
.\tools\uvi_direct\uvi.cmd render --voice robot --score output\my_se\score.json --output output\my_se\robot.wav --tail 1.2 --peak-db -6
```

同じ音色で候補をまとめて作る：

```powershell
.\tools\uvi_direct\uvi.cmd batch --voice impact --scores output\my_se\a.json output\my_se\b.json --output-dir output\my_se\variants
```

音色準備に初回の待ち時間があるため、同じ音色の候補は1回の`batch`にまとめる。違う音色なら`--voice`を変える。WAVは48kHz/16bit/stereoが既定。無音はエラーになり、音量と処理時間は隣のJSONへ保存される。

## 新しい音色の登録

ユーザーは次の2つのバッチを使える。

1. `tools/uvi_direct/01_open_voice_editor.cmd` で音色登録用のUVI画面を開く。
2. その画面で音色を選び、Loading Programが消えるまで待つ。画面下の鍵盤で試聴でき、Windowsの既定の音声出力へ再生される。
3. `tools/uvi_direct/02_register_current_voice.cmd` を実行する。

音色名・bankを現在のプラグイン設定から読み取り、自動でIDを割り当てて保存する。画面は保存時に閉じて自動で開き直り、次の音色も同じ方法で登録できる。演奏は不要。対象は`01_open_voice_editor.cmd`から開いた画面。終了するときはそのUVI画面を閉じる。

同じプリセットの再登録は設定を更新する。既知の音色は`robot`などの共通IDを保ち、新しい音色は名前から作ったIDで`voices.local.json`に追加される。バッチの保存結果に表示されるIDを使い、名前からIDを推測しない。共有カタログの手編集は不要。

コマンドからは`uvi.cmd studio`と`uvi.cmd capture`が同じ操作。`capture`は起動中の登録用画面にのみ保存を要求し、未起動なら案内エラーを返す。過去の手動手順を使う必要がある場合は`register --voices <ID> ...`も残っている。

## 制作と確認

- まず短い試聴音を作り、用途に合う立ち上がり・長さ・余韻に整える。無音、クリッピング、音切れを確認する。
- 初回の音色登録以外はコード経由の直接出力を使える。スピーカー録音や画面鍵盤クリックを毎回やり直す必要はない。
- VST3のロード・画面表示・設定取得はメインスレッドで呼ぶ。登録画面の試聴処理は専用スレッドで行い、保存前に必ず停止する。WindowsではVST3バンドル内部の実体をロードする。`uvi.cmd`がPythonとローカル依存パッケージを探す。
- 自動命名はUVI Player 5.0.0の保存形式で確認している。認識できない形式や複数パートの状態は登録せずエラーを返す。その場合は単一の音色を選んだ状態かを確認する。
- iLokログインや管理者許可が必要な場合は本人へ引き継ぐ。既存の登録状態は通常そのまま使える。
- UVI由来の単独SEの製品同梱は利用条件を確認する。試聴依頼だけでゲームへの組み込みや素材公開まで進めない。
