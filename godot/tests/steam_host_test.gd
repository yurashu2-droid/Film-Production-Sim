extends SceneTree
## Opt-in integration test: needs a running, online Steam client, App ID 480.
var failed := false
var net: Node
var menu: Node

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("STEAM_HOST_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func wait_until_ready(seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if menu.game_node != null and menu.game_node.startup_complete and not menu._transition.active:
			return true
		if not menu._busy: return false
		await process_frame
	return false

func _run() -> void:
	net = root.get_node("Net")
	menu = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await capture("steam-menu")
	check(menu.connection_choice.selected == 0, "Steam is the default online transport")
	menu.host_button.pressed.emit()
	var ready := await wait_until_ready(60.0)
	check(ready, "online company completes game startup")
	check(net.mode == "host" and net.transport == "steam", "Steam host active")
	check(net.steam_session.lobby_id > 0, "real Steam lobby exists")
	check(root.multiplayer.multiplayer_peer.get_class() == "SteamMultiplayerPeer", "native Steam transport assigned")
	if ready:
		var game: Node = menu.game_node
		check(game.players.size() == 1 and game.players[1].is_local, "host has one local crew member")
		var room: Node = game.get_node_or_null("OnlineRoom")
		check(room != null and room.panel.visible and room.room_label.text.contains(str(net.steam_session.lobby_id)), "room number is shown in gameplay")
		if room != null:
			check(root.get_visible_rect().encloses(room.panel.get_global_rect()), "room number panel is inside the viewport")
		var api := Engine.get_singleton("Steam")
		check(api.getLobbyMemberLimit(net.steam_session.lobby_id) == 4 and api.getLobbyData(net.steam_session.lobby_id, "film_game") == "FilmProductionCrew", "real lobby publishes game identity and four player limit")
		print("STEAM_HOST_ROOM ", net.steam_session.lobby_id)
		await capture("steam-company")
	menu.return_to_menu()
	var deadline := Time.get_ticks_msec() + 5000
	while menu._returning and Time.get_ticks_msec() < deadline: await process_frame
	check(menu.game_node == null and net.steam_session.lobby_id == 0 and net.mode == "solo" and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "closing company leaves lobby and restores menu")
	print("STEAM_HOST_TEST_FAIL" if failed else "STEAM_HOST_TEST_OK")
	quit(1 if failed else 0)

func capture(name: String) -> void:
	var directory := OS.get_environment("STEAM_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
