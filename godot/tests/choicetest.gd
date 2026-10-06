extends SceneTree
# Box lids and avatar selection: Godot --script res://tests/choicetest.gd
var game: Node
var failed := false
func _initialize() -> void:
	run.call_deferred()
	create_timer(20.0).timeout.connect(func(): quit(2))
func check(ok: bool, label: String) -> void:
	print("CHOICE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	check(game.has_method("h_select_cast") and game.has_method("h_toggle_carton"), "selection and carton actions exist")
	if failed:
		quit(1)
		return
	var me: Node = game.local_player()
	var identity: int = me.get_instance_id()
	var pos: Vector3 = me.position
	for i in game.PLAYER_CASTS.size():
		game.h_select_cast(i)
		check(me.vis.tag == game.PLAYER_CASTS[i] and me.get_instance_id() == identity and me.position == pos, "select " + me.vis.tag + " preserves player")
		check(me.vis.has("carry_idle") and me.vis.has("run_start") and me.vis.has("step_down"), "motions " + me.vis.tag)
	game.h_select_cast(-1)
	check(me.vis.tag == game.PLAYER_CASTS.back(), "invalid selection ignored")
	game.h_order_confirm()
	var carton: Node
	for p in game.props.values():
		if p.kind == "carton":
			carton = p
			break
	carton.set_fixed(true)
	carton.position = me.position + Vector3(-1, 0, 0)
	game.h_toggle_carton(carton.pid)
	await create_timer(0.5).timeout
	check(not carton.opened and carton.open_amount == 0.0 and not carton.lid.disabled, "close flaps and lid collision")
	var saved: Array = carton.get_state()
	game.h_toggle_carton(carton.pid)
	await create_timer(0.5).timeout
	check(carton.opened and carton.open_amount == 1.0 and carton.lid.disabled, "open flaps and hollow interior")
	carton.restore(saved)
	await physics_frame
	check(not carton.opened and carton.open_amount == 0.0, "restore includes lid state")
	carton.set_fixed(false)
	game.h_grab(carton.pid)
	check(me.held == carton.pid, "hold carton")
	game.h_select_cast(0)
	check(me.vis.tag == "M02" and me.held == carton.pid, "selection keeps held object")
	game.input_locked = false
	var input := InputEventAction.new()
	input.action = "operate"
	input.pressed = true
	me._unhandled_input(input)
	game.input_locked = true
	await create_timer(0.5).timeout
	check(carton.opened and me.held == carton.pid, "F opens held carton")
	game.act_release()
	await physics_frame
	carton.holder = 1234
	game.h_toggle_carton(carton.pid)
	check(carton.opened, "cannot toggle another player's carton")
	carton.holder = 0
	game.state = game.S.TAKE
	game.h_select_cast(1)
	check(me.vis.tag == "M02", "appearance stays fixed during recording")
	game.state = game.S.PREP
	var recorded: Dictionary = game.capture()
	game.h_select_cast(1)
	game._take_data = [{"frames": [[0.0, recorded], [0.1, recorded]], "events": [], "dur": 0.1}]
	game.state = game.S.RESULT
	game.h_replay(0)
	game._replay_step(0.05)
	check(me.vis.tag == "M02", "replay uses recorded character")
	game.h_stop_replay()
	check(me.vis.tag == "04", "replay restores current choice")
	game.state = game.S.PREP
	if DisplayServer.get_name() != "headless":
		game.set_character_menu(true)
		game.hud.character_picker.choose(2)
		await create_timer(0.5).timeout
		check(game.hud.character_picker.size.is_equal_approx(Vector2(root.size)), "picker covers viewport")
		await shot("character_picker")
		game.hud.character_picker.confirm()
		check(me.vis.tag == "09" and not game.character_open, "picker confirms appearance")
		# Inspect the actual rig from a dedicated close camera.
		carton = game.stage.spawn("carton", Vector3(0, 0.03, 6))
		carton.set_fixed(true)
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.position = Vector3(1.5, 1.8, 8)
		camera.look_at(carton.position + Vector3(0, 0.35, 0))
		camera.current = true
		await create_timer(0.3).timeout
		await shot("carton_open")
		carton.opened = false
		await create_timer(0.5).timeout
		await shot("carton_closed")
	print("CHOICETEST_FAIL" if failed else "CHOICETEST_OK")
	quit(1 if failed else 0)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://tests/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(label + ".png"))
