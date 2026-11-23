extends SceneTree

var failed := false
var claps := 0
var recording := false

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("START_INTRO_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/" + path + ".png")

func run() -> void:
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	if OS.get_environment("CLAPPER_PREVIEW") == "1":
		while not menu._startup_resources.is_prepared:
			await process_frame
		capture(menu)
		menu.solo_button.pressed.emit()
		while recording:
			await process_frame
		quit()
		return
	root.get_node("Sfx").played.connect(func(sound: String, _position: Variant):
		if sound == "clap": claps += 1)
	# 準備が長引いてもタイトルを覆ったまま保持できることを再現する。
	menu._startup_resources.set_process(false)
	menu.solo_button.pressed.emit()
	check(menu._transition.active and menu._canvas.visible, "clapper wipe begins on the title immediately")
	check(menu.game_node == null, "start returns before preparation finishes")
	await create_timer(0.24).timeout
	await shot("start-wipe-enter")
	while not menu._transition.covered:
		await process_frame
	check(menu._canvas.visible and menu.game_node == null, "loading holds the board over the title")
	check(claps == 1, "board claps immediately at full coverage before loading")
	check(is_equal_approx(menu._transition.angle, menu._transition.SHUT), "full-screen bar reaches contact")
	check(menu._transition.is_fully_covering(), "closed board leaves no gap on screen")
	if DisplayServer.get_name() != "headless":
		# 実際の画面でも、下の端まで板で覆われている
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var edges_dark := true
		for x in 9:
			var px := int((image.get_width() - 1) * x / 8.0)
			edges_dark = edges_dark and image.get_pixel(px, image.get_height() - 2).get_luminance() < 0.2
		check(edges_dark, "drawn board reaches the bottom edge of the screen")
	check(menu._transition.bars_in_frame(), "striped bar remains inside the screen")
	await shot("start-wipe-cover")
	menu._startup_resources.set_process(true)
	var preparing_frames := 0
	while menu.game_node == null or not menu.game_node.startup_complete:
		await process_frame
		preparing_frames += 1
	check(preparing_frames > 3, "construction yields across frames")
	while menu._canvas.visible:
		await process_frame
	var game: Node = menu.game_node
	check(menu._transition.covered and menu._transition.active, "title changes to game under the same opaque board")
	check(game.hud.slate.mode == "", "no second HUD intro after scene switch")
	check(root.get_node("Sfx").get_stream("clap").resource_path == "res://assets/audio/clapper_wood.tres", "clapper uses processed free sample")
	while claps == 0:
		await process_frame
	await shot("start-wipe-clap")
	var saw_opening := false
	while menu._transition.active:
		if menu._transition._phase == "exit" and menu._transition._time >= menu._transition.EXIT_TIME * 0.4 and not saw_opening:
			saw_opening = true
			check(menu._transition.angle > menu._transition.SHUT + 0.04, "bar visibly opens while departing")
		await process_frame
	check(saw_opening, "departure includes a visible opening phase")
	check(claps == 1, "visible closing bar sounds exactly once")
	check(menu._transition.angle > 0.3, "departing bar reopens")
	check(not game.input_locked and not game.ui_blocking(), "finished wipe leaves gameplay responsive")
	check(not menu._transition.visible and not menu._transition.is_processing(), "idle transition stops drawing")
	await shot("start-wipe-game")
	game.open_menu("board")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	root.push_input(key, true)
	check(game.menu_open == "brief" and game.production.phase == 0, "job shortcut opens the briefing after reveal")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter, true)
	check(game.production.phase == 2, "accepting from the briefing starts the job")
	menu.return_to_menu()
	while menu._returning:
		await process_frame
	menu.solo_button.pressed.emit()
	check(menu._transition.active and menu._canvas.visible, "next entry also starts on title")
	await create_timer(0.12).timeout
	menu.return_to_menu()
	await create_timer(1.0).timeout
	check(claps == 1 and not menu._transition.active, "return before contact cancels pending clap and animation")
	check(menu.game_node == null and menu._canvas.visible and multiplayer_poll, "return restores home and network polling")
	# 動画用の再生は通常の速度で収録する。
	if OS.get_environment("CLAPPER_CAPTURE") == "1":
		capture(menu)
		menu.solo_button.pressed.emit()
		while menu.game_node == null or not menu.game_node.startup_complete or menu._transition.active:
			await process_frame
		while recording:
			await process_frame
	print("START_INTRO_TEST_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func capture(menu: Node) -> void:
	recording = true
	var directory := ProjectSettings.globalize_path("res://../artifacts/clapper-frames").simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest := FileAccess.open(directory + "/times.csv", FileAccess.WRITE)
	var start := Time.get_ticks_msec()
	var capture_time := 0.0
	var index := 0
	var finished_at := -1
	while capture_time < 15.0:
		await RenderingServer.frame_post_draw
		var elapsed := Time.get_ticks_msec() - start
		capture_time += root.get_process_delta_time()
		var image := root.get_texture().get_image()
		image.resize(1280, 720)
		image.save_jpg(directory + "/%04d.jpg" % index, 0.92)
		manifest.store_line("%04d,%.3f,%s" % [index, capture_time, str(menu._transition._sounded)])
		index += 1
		if not menu._transition.active and finished_at < 0:
			finished_at = elapsed
		if finished_at >= 0 and elapsed - finished_at > 300:
			break
	manifest.close()
	recording = false
