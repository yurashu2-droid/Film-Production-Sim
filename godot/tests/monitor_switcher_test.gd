extends SceneTree
var game: Node
var failed := false
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		print("MONITOR_SWITCHER_CHECK ",label," FAIL")
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete: await process_frame
	await frames(3)
	check(game.has_method("program_camera") and "camera_switcher" in game, "multi-camera monitor is available")
	if not "camera_switcher" in game:
		print("MONITOR_SWITCHER_TEST_FAIL")
		quit(1)
		return
	var switcher: Node = game.camera_switcher
	check(switcher.cameras.size() == 3,"three real cameras")
	check(switcher.monitor.screen_size().is_equal_approx(Vector2(2.48,1.40)),"monitor image is four times wider and taller")
	game.h_accept_job(0)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	var player: Node = game.local_player()
	player.global_position = switcher.monitor.global_position + Vector3(2,0,0)
	switcher.request_control(1,true)
	check(switcher.operator_peer == 1,"nearby crew can become switch operator")
	switcher.request_cut(1,1)
	check(game.program_camera() == switcher.cameras[1] and game.film != game.program_camera(),"B is on air while A remains company camera")
	switcher.request_cut(1,99)
	check(game.program_camera() == switcher.cameras[1],"invalid camera leaves output unchanged")
	player.global_position += Vector3(20,0,0)
	switcher.request_cut(1,2)
	check(game.program_camera() == switcher.cameras[1],"distant crew cannot cut")
	player.global_position = switcher.monitor.global_position + Vector3(2,0,0)
	game.monitor_popup.set_open(true)
	game._begin_take()
	check(game.monitor_popup.opened and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"popup keeps cursor when take starts")
	await frames(6)
	switcher.request_cut(1,2)
	await frames(9)
	check(switcher.cameras[2].tally.visible and not game.film.tally.visible,"only on-air camera has recording tally")
	game._cut()
	check(not game.monitor_popup.opened and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"take end closes popup without capturing cursor")
	check(game._take_data[0].events.any(func(e): return e[1] == "camera_program" and e[2][0] == switcher.cameras[2].pid),"cut recorded into take")
	check(switcher.operator_peer == 0,"cut releases switch operator")
	game.h_replay(0)
	await frames(2)
	check(game.program_camera() == switcher.cameras[1],"replay starts on the camera used at beginning")
	await frames(9)
	check(game.program_camera() == switcher.cameras[2],"replay reproduces cut to C")
	game.h_stop_replay()
	check(game.program_camera() == switcher.cameras[2],"end replay restores live selection")
	print("MONITOR_SWITCHER_TEST_FAIL" if failed else "MONITOR_SWITCHER_TEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
