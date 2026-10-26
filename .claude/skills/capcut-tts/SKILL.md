---
name: capcut-tts
description: Use when generating spoken dialogue, narration, or text-to-speech with CapCut in this Windows project, including the voice 快活な女の子 (快活な娘). Uses the shared local Python CLI.
---

# CapCutの音声をコードで作る

このPCでは非公式CapCut TTSクライアントを設定済み。ClaudeとCodexは同じ `tools/capcut_tts/tts.cmd` を使える。CapCutアプリの起動・GUI操作・UVIの音色登録は不要。以下はリポジトリ直下のPowerShellから実行する。

## 声を選ぶ

```powershell
.\tools\capcut_tts\tts.cmd voices
```

一覧の表示名またはvoice IDを使う。日本語20声が候補にあり、全言語を見る場合は`voices --all`。一覧への掲載だけでは生成可能と断定しない。2026-10-26に実際の生成を確認した声は「女性AI」「narrator」「快活な娘」。

**「快活な女の子」と「快活な娘」はこのツールで同じ声を呼ぶ名前。** PC版の表示名は「快活な娘」、voice IDは`ICL_uranus_ja_female_yuanqi`。ユーザーが「快活な女の子」を指定したら、その名前をそのまま`--voice`へ渡せる。別の声へ置き換える必要はない。

## 台詞を生成する

```powershell
.\tools\capcut_tts\tts.cmd speak --text "おはよう！今日も張り切って、撮影を始めよう！" --voice "快活な女の子" -o output\capcut_tts\lively.mp3
```

長い台詞や引用符を含む文章はUTF-8ファイルに書いて渡す。本文をシェルのコードとして組み立てない。

```powershell
.\tools\capcut_tts\tts.cmd speak --text-file output\capcut_tts\dialogue.txt --voice "快活な女の子" -o output\capcut_tts\dialogue.mp3
```

- `--voice`を省略すると日本語narrator。`--rate 1.2`で速さを調整できる（通常1.0、範囲0.5～2.0）。
- 既存出力は保護される。作り直すときだけ`--force`を付けるか、別名で保存する。
- 生成後は成功表示とMP3の存在を確認し、必要に応じて試聴する。台詞と音声は`output/`内に置き、Gitへ追加しない。

## 環境と制約

`tts.cmd`は同じWindowsユーザーのPythonと`%USERPROFILE%\.cache\codex-audio\capcut-deps`を使う。インストール識別設定は`%LOCALAPPDATA%\CapCut-Code-TTS\device.json`を共用する。毎回の再インストールは不要。依存が見つからない別PCでは `tools/capcut_tts/setup.ps1`を使う。

文章は生成のためCapCutへ送信される。確認済みの経路ではログイン不要。ブラウザやアプリから認証情報を抜き出さない。非公式APIのため、サービス側の変更・利用制限で失敗することがある。拒否や回数制限をID変更で回避しない。生成音声の公開・ゲーム同梱はCapCut側の利用条件を確認する。

詳細・セットアップ・関連テストは `tools/capcut_tts/README.md`。このツールは人の声の読み上げ用。UVIのSE生成には `.claude/skills/uvi-se/SKILL.md` を使う。
