extends Node
var menu: Node
var role := ""
var _failed := false
var _done := false
var _host_state: Dictionary = {}

func _ready() -> void:
	name = "StartMenuTest"
	_run.call_deferred()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _check(ok: bool, label: String) -> void:
	print("START_MENU_CHECK ",label," ","OK" if ok else "FAIL")
	_failed = _failed or not ok

@rpc("any_peer","call_remote","reliable")
func _ask_host(ok: bool) -> void:
	if role not in ["host","host-disconnect"]:
		return
	_failed = not ok
	var game: Node = menu.game_node
	var locals := 0
	for player: Node in game.players.values():
		locals += int(player.is_local)
	_reply.rpc_id(multiplayer.get_remote_sender_id(),{"count":game.players.size(),"locals":locals,"host_local":game.players[1].is_local,"office":game.local_player().position.x > 60,"phase":game.production.phase,"path":str(game.get_path())})
	_done = true

@rpc("authority","call_remote","reliable")
func _reply(data: Dictionary) -> void:
	_host_state = data

func _run() -> void:
	await _wait(0.2)
	_check(menu.game_node == null,"menu does not create a solo game before selection")
	if role == "shot":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://tests/shots")
		image.save_png("res://tests/shots/start-menu.png")
		get_tree().quit()
		return
	if role == "failure":
		menu.address_input.text = "127.0.0.1"
		menu.join_button.pressed.emit()
		var waiting := 0.0
		while menu.join_button.disabled and waiting < 20.0:
			await _wait(0.05)
			waiting += 0.05
		_check(menu.game_node == null and not menu.join_button.disabled and Net.mode == "solo" and multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"connection failure resets offline and enables retry")
		if _failed:
			get_tree().quit(1)
			return
		menu.solo_button.pressed.emit()
		while menu.game_node == null or not menu.game_node.startup_complete or menu._transition.active:
			await _wait(0.05)
		_check(menu.game_node != null and menu.game_node.players.size() == 1 and menu.game_node.local_player().is_local,"solo works after failed connection")
		print("FAILURE STARTMENUTEST_FAIL" if _failed else "FAILURE STARTMENUTEST_OK")
		get_tree().quit(1 if _failed else 0)
		return
	if role in ["host","host-disconnect"]:
		menu.host_button.pressed.emit()
		while menu.game_node == null or not menu.game_node.startup_complete or menu._transition.active:
			await _wait(0.05)
		_check(menu.game_node != null and Net.mode == "host","host button opens company")
		var elapsed := 0.0
		while not _done and elapsed < 25.0:
			await _wait(0.2)
			elapsed += 0.2
		_check(_done,"client completed menu connection")
		if role == "host-disconnect":
			await _wait(0.3)
			menu.return_to_menu()
			await _wait(0.5)
			_check(menu.game_node == null and menu._canvas.visible and Net.mode == "solo", "host can close company and return")
		await _wait(1.0)
		print("HOST STARTMENUTEST_FAIL" if _failed else "HOST STARTMENUTEST_OK")
		get_tree().quit(1 if _failed else 0)
		return
	menu.address_input.text = "invalid address"
	menu.join_button.pressed.emit()
	_check(menu.game_node == null and not menu.join_button.disabled and Net.mode == "solo","invalid input keeps retry screen offline")
	menu.address_input.text = "127.0.0.1"
	menu.join_button.pressed.emit()
	var elapsed := 0.0
	while (menu.game_node == null or menu.game_node.players.size() < 2) and elapsed < 20.0:
		await _wait(0.2)
		elapsed += 0.2
	if menu.game_node == null or menu.game_node.players.size() < 2:
		_check(false,"join button connects")
		get_tree().quit(1)
		return
	await _wait(0.7)
	var game: Node = menu.game_node
	_check(game.startup_complete and get_tree().multiplayer_poll, "joining resumes network only after game is ready")
	var locals := 0
	for player: Node in game.players.values():
		locals += int(player.is_local)
	_check(Net.my_id() != 1 and game.local_player().is_local and not game.players[1].is_local and locals == 1,"client identity has exactly one local player")
	_check(game.production.phase == 0 and game.production.wallet == 600 and game.local_player().position.x > 60 and game.players[1].position.x > 60,"both crew spawn in office")
	if role == "client-disconnect":
		Sfx.play_music("music_confession",0.0)
		Sfx.play("explosion")
	_ask_host.rpc_id(1,not _failed)
	elapsed = 0.0
	while _host_state.is_empty() and elapsed < 4.0:
		await _wait(0.05)
		elapsed += 0.05
	_check(_host_state.get("count") == 2 and _host_state.get("locals") == 1 and _host_state.get("host_local",false) and _host_state.get("office",false) and _host_state.get("phase") == 0 and _host_state.get("path") == str(game.get_path()),"host roster and Game node path match")
	if role == "client-disconnect":
		var old_game: Node = game
		elapsed = 0.0
		while menu.game_node != null and elapsed < 5.0:
			await _wait(0.1)
			elapsed += 0.1
		_check(not is_instance_valid(old_game) and menu.game_node == null and menu._canvas.visible and not menu.solo_button.disabled and Net.mode == "solo" and multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"host disconnect restores retry menu after Game freed")
		_check(Sfx.current_music() == "" and Sfx._oneshots.is_empty() and Net.get_signal_connection_list("peer_left").is_empty() and Net.get_signal_connection_list("joined_host").size() == 1,"old audio and Game signal connections removed")
		menu.solo_button.pressed.emit()
		while menu.game_node == null or not menu.game_node.startup_complete or menu._transition.active:
			await _wait(0.05)
		var next_game: Node = menu.game_node
		_check(next_game.name == "Game" and str(next_game.get_path()) == "/root/StartMenu/Game" and next_game.players.size() == 1 and next_game.players[1].is_local and next_game.local_player().is_local,"solo retry keeps stable Game path and one local player")
		_check(Net.get_signal_connection_list("peer_left").size() == 1 and Net.get_signal_connection_list("joined_host").size() == 2,"new Game has one fresh signal subscription")
		_check(menu.host_addresses().all(func(address: String): return address.is_valid_ip_address() and not address.contains(":") and not address.begins_with("127.") and not address.begins_with("169.254.")),"host address helper filters local IPv4")
	print("CLIENT STARTMENUTEST_FAIL" if _failed else "CLIENT STARTMENUTEST_OK")
	get_tree().quit(1 if _failed else 0)
