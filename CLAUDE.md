# このプロジェクトで作業するClaudeへ

開発・検証・素材利用・Git反映の共通ルールは [AGENTS.md](AGENTS.md) を読む。

UVI Player・Prisma・UVI StarterでSEを作る、登録済み音色をコードで鳴らすときは、[UVI SEスキル](.claude/skills/uvi-se/SKILL.md) を読む。共通コマンドは `tools/uvi_direct/uvi.cmd`。音色一覧は `voices` サブコマンドで確認でき、保存済み音色はCodexと共用する。

ユーザーが「今の音色を登録」バッチで追加した音色も、`voices`に自動で反映される。`registered: true`のIDを`render --voice <ID>`または`batch --voice <ID>`へ渡す。使い方と2つの登録バッチはスキルに記載している。
