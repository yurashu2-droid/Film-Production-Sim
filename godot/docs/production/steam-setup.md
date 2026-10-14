# GodotSteamの導入

2026-10-14、公式配布のGodotSteam GDExtension 4.23.1を `addons/godotsteam/` に追加した。
Steamworks SDKは1.65。公式リリースの対応範囲はGodot 4.4以降で、このプロジェクトの4.7.2で確認する。
配布物にはWindows・Linux・macOS・Android ARM64用のライブラリと、MITライセンス文を含む。
拡張はGodotが読み込む。エディタ用の更新プラグインを有効にする必要はない。

- 配布元: https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.23.1
- ファイル: `godotsteam-4.23.1-gdextension-plugin-4.4.zip.tar.xz`
- ダウンロード時のSHA256: `37D53EDE5EDA11D2247D70C1AF91F95A4777AD2A419FC8A24DE1CC816D21CC0A`
- 初期化の説明: https://godotsteam.com/tutorials/initializing/
- 通信の説明: https://godotsteam.com/tutorials/multiplayer_peer/

## 導入確認

Steamを起動してログインした状態で、リポジトリ直下から実行する。
新しく取得した作業フォルダーでは、先に `--headless --path godot --import` で
Godotの初回インポートを済ませる。

```powershell
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tools/check_steam.gd
```

確認ツールはテスト用App ID 480（ValveのSpaceWar）で初期化し、ログイン状態と
SteamMultiplayerPeerのホスト作成を確認して閉じる。成功時は `STEAM_CHECK_OK` と終了コード0。
自分のゲーム用App IDがなくてもこの導入確認はできる。

## 導入時の範囲

今回は拡張の導入と、Steamの初期化・通信ホスト作成の確認まで。
通常のゲーム起動ではSteamを初期化しない。既存の会社を開く・IP入力で参加する経路はENetを使う。
Steamのフレンド招待から本作へ参加するには、ロビーの作成・参加をNetと起動画面へつなぐ作業が必要。
販売する版ではテスト用480を自分のApp IDへ替える。

その後、会社番号によるSteamオンライン接続をゲームへ追加した。現在の遊び方と確認範囲は [steam-online.md](steam-online.md) を参照。

## 今回の確認結果

Windows、Godot 4.7.2、ログイン済みSteamで `STEAM_CHECK_OK`・終了コード0。
Steamシングルトンの読み込み、App ID 480での初期化、ログイン状態、
SteamMultiplayerPeerの通信ホスト作成・終了を確認した。二人のSteam接続は未検証。
既存の起動画面の二人通信テストも、ホスト・参加者とも `STARTMENUTEST_OK`・終了コード0。

既存の自動テストでは、終了時にローカルSEのAudioStreamWAVが残るエラーと、
カンペ通信テストが既存の絵を受け取ったあとに進まなくなる問題を検出した。
どちらも同じソース・素材を使うGodotSteamなしの比較環境で再現しており、
今回の導入ではそのゲーム処理を変更していない。詳細ログはignoredの
`tools/diagnostics/godotsteam-*.log` に保存した。

Git Bashで `bash run_tests.sh` を一度実行した結果は、86件中62件成功、24件失敗
（うちタイムアウト4件）、描画専用9件は未実行、終了コード1。全体合格とはしていない。
ローカルSEの終了時エラーとカンペ通信の停止についてだけ拡張なしとの比較を行った。
残りの失敗原因はこの導入作業では確定していない。

失敗した項目:

- 終了時のリソースエラー: `handling-physics`、`held-contact`、`grab-feel`、
  `adhesive-net-host`、`camera-operation`、`production`、`production-net-client`、
  `daily`、`cast`、`standin`、`bomb`、`purchase`、`autotest-balcony`。
- チェック失敗: `handling-net-client`、`handling-net-host`、`cue-card`、
  `cast-talent-net-client`、`cast-talent-net-host`、`autotest`、`legacy-net-client`。
  `handling-net-client`では終了時のリソースエラーも発生した。
- タイムアウト: `cue-card-net-client`、`cue-card-net-host`、
  `monitor-net-client`、`monitor-net-host`。

全体ログは `tools/diagnostics/godotsteam-tests.log`、各テストのログは
`tools/diagnostics/test-runs/20261014T045540-1291/`。
