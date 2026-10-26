---
name: capcut-tts
description: Generate spoken dialogue, narration, and text-to-speech with CapCut from any local Windows project. Includes 快活な女の子 and Japanese male voices, using the shared Python CLI.
---

# CapCutの音声を作る

ツール本体は `%USERPROFILE%\Tools\capcut-tts`。特定のゲーム・リポジトリに依存せず、Claude CodeとCodexで共用する。作業中のプロジェクトをカレントディレクトリに保ち、共通ツールを絶対パスで呼ぶ。ツールのフォルダへ移動しない。

PowerShellで声の一覧を確認：

```powershell
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" voices
```

日本語24声が候補。全言語は`voices --all`。表示名または一覧のIDを使う。確認済みの声は「快活な女の子」「女性AI」「narrator」「爽やかな少年」「頼れる兄貴」「落ち着いた叔父」「荒々しい男」。未検証の声も含むため、一覧掲載だけで生成成功を断定しない。

「快活な女の子」はPC版表示名「快活な娘」の別名。同じ`ICL_uranus_ja_female_yuanqi`を呼び、両方の名前で指定できる。

```powershell
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" speak --text "おはよう！今日も張り切っていこう！" --voice "快活な女の子" -o output\capcut_tts\lively.mp3
```

長い台詞・引用符のある文章は、作業中のプロジェクト内にUTF-8で保存して渡す。本文をシェルのコードとして組み立てない。

```powershell
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" speak --text-file output\capcut_tts\dialogue.txt --voice "頼れる兄貴" -o output\capcut_tts\dialogue.mp3
```

- 声の省略時は日本語narrator。速度は`--rate 1.2`など（通常1.0、範囲0.5～2.0）。
- 相対パスは呼び出し元のプロジェクトから解決する。台詞・音声は各プロジェクトの出力先へ置き、共通ツール内に作品の素材を混ぜない。
- 既存ファイルの置き換えは明示的に`--force`を使うか、別名で保存する。生成成功の表示と実ファイルを確認する。
- CapCutアプリの起動やGUI操作は不要。非公式クライアントから文章をCapCutへ送り、クラウドで生成する。確認済みの経路はログイン不要だが、サービス側の変更・利用制限で失敗することがある。
- Pythonと依存は同じWindowsユーザーの既存環境を使う。毎回作り直し・再インストールはしない。依存不足の場合のみ共通フォルダ内の`setup.ps1`を使う。
- インストール識別設定は`%LOCALAPPDATA%\CapCut-Code-TTS\device.json`を共用する。ブラウザの認証情報を読み取らず、拒否・回数制限を識別IDの変更で回避しない。
- 生成音声を公開・ゲーム同梱する場合はCapCut側の利用条件を確認する。ローカル設定や台詞・音声を勝手に公開しない。

詳細は `%USERPROFILE%\Tools\capcut-tts\README.md`。このスキルは人の声の読み上げ用。
