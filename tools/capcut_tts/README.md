# CapCutをコードから読み上げる

文章と声を指定してCapCutのクラウドで音声を生成し、MP3に保存する。非公式Pythonクライアント [jutlyne/capcut-tts](https://github.com/jutlyne/capcut-tts) の確認済みリビジョンを使う。UI操作や常駐サーバーは不要。このPCではセットアップ済み。

## どのプロジェクトからも使う

実行用の本体は `%USERPROFILE%\Tools\capcut-tts\`。Claude Codeの共通スキルは`%USERPROFILE%\.claude\skills\capcut-tts\`、Codexの共通スキルは`%USERPROFILE%\.agents\skills\capcut-tts\`。両スキルは、本体内の`skill/`にある同じ手順書へのディレクトリジャンクションで、説明を二重管理しない。

作業中のプロジェクトのPowerShellから、共通コマンドを呼ぶ。出力先は呼び出したプロジェクトを基準に解決する。

```powershell
# 日本語の声一覧（通信なし）
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" voices

# 声の名前、または一覧に出たIDを指定する
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" speak --text "よし、撮影を始めよう！" --voice "女性AI" -o output\capcut_tts\director.mp3

# CapCut PC版での表示名「快活な娘」。「快活な女の子」も同じ声の別名として使える。
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" speak --text "おはよう！今日も張り切って、撮影を始めよう！" --voice "快活な女の子" -o output\capcut_tts\lively.mp3

# UTF-8の台詞ファイルから生成。声の省略時は日本語narrator。
& "$env:USERPROFILE\Tools\capcut-tts\tts.cmd" speak --text-file output\dialogue.txt -o output\capcut_tts\dialogue.mp3
```

`--rate 1.2`で速度を指定できる（1.0が通常、受付範囲0.5～2.0）。既存ファイルは保護し、上書きするときだけ`--force`を付ける。生成失敗時に既存の音声を壊さない。`voices --all`で他の言語も一覧表示できる。

このゲーム内の`tools/capcut_tts/tts.cmd`は、共通版があればそちらを呼ぶ。共通版のない別PCでは同梱版で動く。既存のコマンドも使い続けられる。

## 共通配置と更新

このPCでは配置済み。各プロジェクトで作り直したり、このゲームのフォルダを読みに来たりする必要はない。音声・台詞は各プロジェクトの`output/`に保存し、本体や共通スキルと分ける。Claude Code・Codexの既存セッションで共通スキルが見えない場合は、新しいセッションで読み込む。

保守用ソースはこのゲームのGit内に残してある。更新時はソースを変更して、`tools/capcut_tts/install_shared.ps1`を1回実行すると共通本体と共通手順書へ反映する。スキルのリンクは既存の別スキルを上書きしない。通常の音声生成時はこの更新操作は不要。

## 確認できたこと・制約

- 2026-10-26、このPCで日本語narratorと女性AIの生成に成功。MP3のデコードと非無音も確認した。女性AIの試聴は`output/capcut_tts/filming_test.mp3`（4.632秒）。
- 上流カタログの日本語19声に、このPCのCapCut 9.6の音声一覧から確認した5声を追加して24声。「快活な娘」は`ICL_uranus_ja_female_yuanqi`、resource IDは`7681166532600220936`。「快活な女の子」でも指定でき、実際の生成を確認済み。試聴ファイルは`output/capcut_tts/lively_girl_test.mp3`。
- 追加した男性4声も生成を確認済み：`爽やかな少年`、`頼れる兄貴`、`落ち着いた叔父`、`荒々しい男`。`--voice "頼れる兄貴"`のように表示名で呼べる。試聴は順に`output/capcut_tts/male_young.mp3`、`male_brother.mp3`、`male_uncle.mp3`、`male_rough.mp3`。
- 全24声の生成を検証したわけではない。CapCutの画面と名前・一覧が一致する保証もない。
- この確認ではログインやアカウントのパスワードは不要だった。文章は生成のためCapCutへ送られる。ブラウザやCapCutアプリから認証情報を読み取らない。
- インストール識別用の設定は`%LOCALAPPDATA%\CapCut-Code-TTS\device.json`。同じ設定を継続利用する。拒否・回数制限時にIDを変えて再試行する仕組みはない。
- 非公式APIのため、将来の変更やサービス側の制限で使えなくなる場合がある。有料音声や契約で許可されない音声へのアクセスは保証しない。
- クライアントのコードはMIT。生成した声の利用・ゲーム同梱条件はCapCut側の条件を確認する。MP3・台詞・ローカル設定をGitへ追加しない。

## 別PCでのセットアップ

Python 3.10以上とGitを入れ、このツールフォルダの`setup.ps1`で依存を準備し、`install_shared.ps1`で共通配置する。依存は`%USERPROFILE%\.cache\codex-audio\capcut-deps`へ分離して入れる。CapCutクライアントはコミット`150e49bee79462f83f527498535cd39ad5c74dcb`に固定している。

## 関連チェック

```powershell
python -m unittest discover -s "$env:USERPROFILE\Tools\capcut-tts" -p test_cli.py
```

保存時の失敗・入力検証・声の解決を確認する。テストでCapCutへの生成要求は送らない。
