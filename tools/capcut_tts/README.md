# CapCutをコードから読み上げる

文章と声を指定してCapCutのクラウドで音声を生成し、MP3に保存する。非公式Pythonクライアント [jutlyne/capcut-tts](https://github.com/jutlyne/capcut-tts) の確認済みリビジョンを使う。UI操作や常駐サーバーは不要。このPCではセットアップ済み。

リポジトリ直下のPowerShellから実行：

```powershell
# 日本語の声一覧（通信なし）
.\tools\capcut_tts\tts.cmd voices

# 声の名前、または一覧に出たIDを指定する
.\tools\capcut_tts\tts.cmd speak --text "よし、撮影を始めよう！" --voice "女性AI" -o output\capcut_tts\director.mp3

# UTF-8の台詞ファイルから生成。声の省略時は日本語narrator。
.\tools\capcut_tts\tts.cmd speak --text-file output\dialogue.txt -o output\capcut_tts\dialogue.mp3
```

`--rate 1.2`で速度を指定できる（1.0が通常、受付範囲0.5～2.0）。既存ファイルは保護し、上書きするときだけ`--force`を付ける。生成失敗時に既存の音声を壊さない。`voices --all`で他の言語も一覧表示できる。

## 確認できたこと・制約

- 2026-10-26、このPCで日本語narratorと女性AIの生成に成功。MP3のデコードと非無音も確認した。女性AIの試聴は`output/capcut_tts/filming_test.mp3`（4.632秒）。
- 同梱カタログは日本語19声だが、全19声の生成を検証したわけではない。CapCutの画面と名前・一覧が一致する保証もない。
- この確認ではログインやアカウントのパスワードは不要だった。文章は生成のためCapCutへ送られる。ブラウザやCapCutアプリから認証情報を読み取らない。
- インストール識別用の設定は`%LOCALAPPDATA%\CapCut-Code-TTS\device.json`。同じ設定を継続利用する。拒否・回数制限時にIDを変えて再試行する仕組みはない。
- 非公式APIのため、将来の変更やサービス側の制限で使えなくなる場合がある。有料音声や契約で許可されない音声へのアクセスは保証しない。
- クライアントのコードはMIT。生成した声の利用・ゲーム同梱条件はCapCut側の条件を確認する。MP3・台詞・ローカル設定をGitへ追加しない。

## 別PCでのセットアップ

Python 3.10以上とGitを入れ、PowerShellで`tools\capcut_tts\setup.ps1`を実行する。依存は`%USERPROFILE%\.cache\codex-audio\capcut-deps`へ分離して入れる。CapCutクライアントはコミット`150e49bee79462f83f527498535cd39ad5c74dcb`に固定している。

## 関連チェック

```powershell
python -m unittest discover -s tools/capcut_tts -p test_cli.py
```

保存時の失敗・入力検証・声の解決を確認する。テストでCapCutへの生成要求は送らない。
