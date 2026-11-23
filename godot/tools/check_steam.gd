extends SceneTree
## Steamを起動してから実行する、導入確認用。通常のゲーム起動には介入しない。
## Godot --headless --path godot --script res://tools/check_steam.gd

func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	if not Engine.has_singleton("Steam"):
		print("STEAM_CHECK_FAIL GodotSteamが読み込まれていません")
		quit(1)
		return
	var steam: Object = Engine.get_singleton("Steam")
	var result: Dictionary = steam.call("steamInitEx", 480, false)
	if int(result.get("status", -1)) != 0:
		print("STEAM_CHECK_FAIL ", result.get("verbal", "Steamの初期化に失敗しました"))
		quit(1)
		return
	steam.call("run_callbacks")
	if not bool(steam.call("loggedOn")):
		print("STEAM_CHECK_FAIL Steamにログインしてください")
		steam.call("steamShutdown")
		quit(1)
		return
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		print("STEAM_CHECK_FAIL SteamMultiplayerPeerが読み込まれていません")
		steam.call("steamShutdown")
		quit(1)
		return
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var host_error: int = peer.call("create_host", 0)
	if host_error != OK:
		print("STEAM_CHECK_FAIL Steamのホスト作成: ", error_string(host_error))
		steam.call("steamShutdown")
		quit(1)
		return
	peer.close()
	print("STEAM_CHECK_OK GodotSteamの読み込み・Steam接続・テスト用App ID 480・通信ホスト作成")
	steam.call("steamShutdown")
	quit(0)
