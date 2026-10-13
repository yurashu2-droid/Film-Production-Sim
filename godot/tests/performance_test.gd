extends SceneTree
var failed := false

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PERFORMANCE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(8)
	check(game.get("performance") != null, "gameplay performance controls exist")
	if game.get("performance") == null:
		quit(1)
		return
	var control: Node = game.performance
	var player: Node = game.local_player()
	check(InputMap.has_action("crouch"), "Ctrl crouch action is assigned")
	key(KEY_H)
	check(control.opened and game.ui_blocking(), "H opens selection and blocks movement")
	key(KEY_1)
	check(game.production.phase == 0, "selection modal blocks job/cue number keys")
	if game.production.phase != 0:
		quit(1)
		return
	key(KEY_H)
	check(not control.opened and not game.ui_blocking(), "H closes selection")
	for tag: String in game.PLAYER_CASTS:
		player.set_cast(tag)
		control.refresh_actions()
		check(control.actions.size() > 5 and player.vis.has(control.selected_animation), tag + " has usable original clips")
	player.set_cast("04")
	control.refresh_actions()
	key(KEY_Z)
	await frames(2)
	check(player.vis.current == control.selected_animation and player.performance_active(), "Z plays selected acting clip across physics frames")
	Input.action_press("move_forward")
	await frames(3)
	Input.action_release("move_forward")
	check(not player.performance_active(), "movement cancels acting immediately")
	player.velocity = Vector3.ZERO
	await frames(25)
	Input.action_press("crouch")
	await frames(3)
	check(player.vis.current == "crouch_idle", "Ctrl uses original crouch pose")
	Input.action_release("crouch")
	await frames(2)
	game.set_character_menu(true)
	key(KEY_Z)
	key(KEY_X)
	check(not player.performance_active() and control.fx_root.get_child_count() == 0, "character picker blocks shortcuts")
	game.set_character_menu(false)
	control.selected_effect = "petals"
	game.state = game.S.TAKE
	control.set_open(true)
	key(KEY_T)
	check(game.state == game.S.TAKE, "selection modal does not cut the take")
	control.set_open(false)
	var camera: Camera3D = player.cam
	var ray_from: Vector3 = camera.global_position
	var expected_target: Vector3 = ray_from-camera.global_basis.z*12.0
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_from,expected_target,1|2|4|16))
	if not hit.is_empty():
		expected_target = hit.position
	key(KEY_X)
	check(control.fx_root.get_child_count() == 1 and game._rec_events.size() == 1 and game._rec_events[0][1] == "stage_fx", "X spawns a world effect and records it for replay")
	if not game._rec_events.is_empty():
		check((game._rec_events[0][2][3] as Vector3).distance_to(expected_target) < 0.01,"effect aims at camera crosshair rather than a parallel player ray")
	key(KEY_X)
	check(control.fx_root.get_child_count() == 1, "effect cooldown prevents spam")
	game.h_stage_fx("not-in-catalog")
	check(control.fx_root.get_child_count() == 1, "host rejects unknown effect IDs")
	game.ev("state", [game.S.RESULT])
	await frames(2)
	check(control.fx_root.get_child_count() == 0, "result transition clears live effects")
	for id: String in control.EFFECTS:
		control.show_effect([1,id,Vector3(72,1,0),Vector3(75,1,0),Vector3(75,0,0),Vector3.FORWARD])
		check(control.fx_root.get_child_count() == 1, "catalog spawns " + id)
		control.clear_effects()
		await frames(2)
	for id: String in ["fire","smoke"]:
		control.show_effect([1,id,Vector3.ZERO,Vector3.RIGHT,Vector3(72,0,0),Vector3.FORWARD])
	await create_timer(5.0).timeout
	check(control.fx_root.get_child_count() == 0, "finite fire and smoke stop and clean up")
	print("PERFORMANCE_TEST_FAIL" if failed else "PERFORMANCE_TEST_OK")
	quit(1 if failed else 0)
