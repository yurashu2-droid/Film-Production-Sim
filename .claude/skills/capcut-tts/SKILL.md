---
name: capcut-tts
description: Generate CapCut spoken dialogue or narration for this project using the shared user-level tool, including 快活な女の子 and Japanese male voices.
---

# 共通CapCutツールを使う

共通手順は `%USERPROFILE%\Tools\capcut-tts\skill\SKILL.md` を読む。ツール本体も同フォルダの`tts.cmd`で、別のゲームやプロジェクトから共用できる。台詞と生成音声はこのプロジェクトの`output/capcut_tts/`へ保存する。

共通版が未配置の別PCでは、このリポジトリの `tools/capcut_tts/install_shared.ps1` で配置し、依存不足なら`setup.ps1`も使う。リポジトリ内の`tools/capcut_tts/tts.cmd`は共通版があればそれを呼び、なければ同梱版で動く。
