extends SceneTree
var game: Node
var failed := false

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("CAMERA_OPERATION_CHECK ",label," ","OK" if ok else "FAIL")

func operate() -> void:
	var event := InputEventAction.new()
	event.action = "operate"
	event.pressed = true
	root.push_input(event,true)

func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete: await process_frame
	game.h_accept_job(0)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	var camera: Node = game.camera_switcher.cameras[1]
	game.host_unload(camera)
	camera.restore([Vector3(110,0.03,12),Quaternion.IDENTITY,true,0.0,0.0,52.0])
	var player: Node = game.local_player()
	player.global_position = Vector3(111,0.1,14)
	await frames(4)
	player.target = camera
	var start: Vector3 = player.global_position
	operate()
	check(player.operating == camera.pid,"F enters camera B")
	await frames(3)
	check(player.global_position.is_equal_approx(start),"entering camera leaves player in place")
	var facing: float = player.aim_yaw
	var body: float = player.vis.rotation.y
	game.h_aim(camera.pid,0.9,0.25,1.0)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(8)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("jump")
	check(player.global_position.is_equal_approx(start) and player.velocity == Vector3.ZERO,"pan and WASD do not move player")
	check(is_equal_approx(player.aim_yaw,facing) and is_equal_approx(player.vis.rotation.y,body),"pan does not turn the player's body or saved walking view")
	check(camera.dolly == Vector3.ZERO and is_equal_approx(camera.cam_yaw,0.9) and is_equal_approx(camera.fov,49.0),"only camera aim and zoom change")
	check(camera.has_method("monitor_texture") and camera.monitor_texture() == camera.view.get_texture(),"camera LCD uses its live viewport")
	await frames(2)
	check(game.hud.viewfinder.texture == camera.view.get_texture(),"camera B finder uses B rather than on-air A")
	check("operator_cam" in player and player.operator_cam.current and not game.hud.viewfinder.visible,"operation view focuses on camera rather than player")
	check(game.hud.monitor.texture == camera.monitor_texture(),"operator preview and camera LCD show the same image")
	game.camera_switcher.select(game.camera_switcher.cameras[2].pid)
	await frames(2)
	check(game.hud.monitor.texture == camera.monitor_texture() and game.program_camera() != camera,"on-air cuts do not replace camera B's composition view")
	operate()
	check(player.operating == 0,"F exits camera")
	await frames(2)
	check(player.cam.current,"leaving restores walking camera")
	Input.action_press("move_forward")
	await frames(8)
	Input.action_release("move_forward")
	check(player.global_position.distance_to(start) > 0.1,"walking resumes from the original spot")
	print("CAMERA_OPERATION_TEST_FAIL" if failed else "CAMERA_OPERATION_TEST_OK")
	# 鳴っている音を止めてから、数コマ待って終える（すぐ終えると、使い終わっていない音が残る）
	var sfx := root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	game.queue_free()
	for i in 8:
		await process_frame
	quit(1 if failed else 0)
