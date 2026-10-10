extends SceneTree

var failed := false
var claps := 0

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("START_INTRO_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func run() -> void:
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	root.get_node("Sfx").played.connect(func(sound: String, _position: Variant):
		if sound == "clap": claps += 1)
	menu.solo_button.pressed.emit()
	var game: Node = menu.game_node
	check(game != null, "game starts immediately")
	check(game.hud.slate.mode == "intro", "entry displays clapperboard")
	check(game.ui_blocking(), "entry blocks gameplay briefly")
	check(claps == 0, "sound waits for closing bar")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	root.push_input(key, true)
	check(game.production.phase == 0, "entry blocks job shortcut")
	await create_timer(0.5).timeout
	check(claps == 1, "closing bar sounds once")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/start-clapper-20261011.png")
	await create_timer(0.6).timeout
	check(game.hud.slate.mode == "", "entry finishes automatically")
	check(not game.ui_blocking(), "gameplay resumes")
	check(claps == 1, "no repeated clap")
	menu.return_to_menu()
	await create_timer(0.1).timeout
	menu.solo_button.pressed.emit()
	check(menu.game_node.hud.slate.mode == "intro", "next entry also displays clapperboard")
	menu.return_to_menu()
	await create_timer(0.6).timeout
	check(claps == 1, "return before closing cancels sound")
	check(menu.game_node == null and menu._canvas.visible, "return restores home")
	print("START_INTRO_TEST_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
