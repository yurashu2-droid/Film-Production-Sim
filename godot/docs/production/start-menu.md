# 起動画面と接続の確認

通常起動は `res://start_menu.tscn`。メニューが生成するゲームは全経路で `/root/StartMenu/Game`（production_game.tscn）になる。ひとり・ホストはその場でゲームを生成。参加者はENet接続成立後にdeferredで生成し、ready完了後に本体のh_helloを1回送る。メニューの公開参照は `game_node`、`solo_button`、`host_button`、`join_button`、`address_input`、`status`。

IP入力不正は接続前に表示、接続失敗または12秒の待機超過はpeerをcloseしOfflineMultiplayerPeerとsoloへ戻す。ゲームを作る前なので、同画面から再試行・ひとりプレイが可能。ホスト切断時はGameを破棄し、Sfxを停止、通信をofflineへ戻してメニューを再表示する。Gameの破棄が完了するまで再試行ボタンを無効にし、次の生成も名前Gameを維持する。

`--host`/`--join`/`--legacy`/`--autotest`/`--nettest`/`--productionnettest`等の既存引数はメニューを飛ばす。接続処理はゲーム本体の既存_parse_argsに任せる。検証専用 `--menutest=...` だけはメニューを表示してボタン経路を使う。

```powershell
# ホストを先に開始し、別プロセスで参加者を開始。
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot res://start_menu.tscn -- --menutest=host
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot res://start_menu.tscn -- --menutest=client
# ホストを停止してから実行。未接続失敗→offline→ひとり再試行。
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot res://start_menu.tscn -- --menutest=failure
# 従来引数経路を一件確認。
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot res://start_menu.tscn --quit-after 30 -- --host --legacy
```

実行記録（2026-10-08、Godot 4.7.2）:

```text
HOST_EXIT=0 CLIENT_EXIT=0
START_MENU_CHECK menu does not create a solo game before selection OK
START_MENU_CHECK invalid input keeps retry screen offline OK
START_MENU_CHECK client identity has exactly one local player OK
START_MENU_CHECK both crew spawn in office OK
START_MENU_CHECK host roster and Game node path match OK
CLIENT STARTMENUTEST_OK
HOST STARTMENUTEST_OK
START_MENU_CHECK connection failure resets offline and enables retry OK
START_MENU_CHECK solo works after failed connection OK
FAILURE STARTMENUTEST_OK
CLI: HOST OK, EXIT=0
```

二人の実ENet検証は両側stderrなし。参加者はID1をlocal扱いせず、双方local人数1、事務所に双方spawn、財布600、Gameパス一致を確認した。描画起動 `--menutest=shot` で `godot/tests/shots/start-menu.png` を保存し、日本語のタイトル・3選択・入力欄・余白に切れや重なりがないことも確認した。


ホスト退出への対応:

- 公開 `return_to_menu(message: String = ...)` はホスト・ひとりでも会社を閉じる入口。起動画面なしのCLI経路から呼ぶと終了する。
- 通常UIの参加者は `multiplayer.server_disconnected` で同処理を呼ぶ。案内は「ホストの会社が閉じました。再参加するか、ひとりで撮影を続けよう。」。
- `host_addresses() -> Array[String]` は非loopback・非linklocalのIPv4候補を返す。複数NICやVPNがあれば複数候補になり、インターネット越しの到達可能性を判定する機能ではない。

検証は `--menutest=host-disconnect` / `--menutest=client-disconnect` を2プロセスで起動する。ホストの公開return_to_menuから切断し、参加者がメニューへ戻った後soloボタンを押す。

```text
HOST_EXIT=0 CLIENT_EXIT=0
START_MENU_CHECK host can close company and return OK
START_MENU_CHECK host disconnect restores retry menu after Game freed OK
START_MENU_CHECK old audio and Game signal connections removed OK
START_MENU_CHECK solo retry keeps stable Game path and one local player OK
START_MENU_CHECK new Game has one fresh signal subscription OK
START_MENU_CHECK host address helper filters local IPv4 OK
HOST STARTMENUTEST_OK
CLIENT STARTMENUTEST_OK
```

両側stderr空。音楽と単発音を再生した状態で切断し、停止と旧GameのNet signal解除を確認。再生成後はGameパスが変わらず、localはID1の1人だけ、新Gameのsignal登録は1組だけだった。この変更では全ネットワークsuiteを反復していない。
