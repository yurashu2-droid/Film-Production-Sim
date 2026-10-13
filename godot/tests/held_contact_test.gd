extends SceneTree
# A carried prop touching the crew's feet must not become their moving support.
var game: Node
var failed := false

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func():
		print("HELD_CONTACT_TEST_TIMEOUT")
		quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("HELD_CONTACT_CHECK ", label, " ", "OK" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete: await process_frame
	game.production.set_physics_process(false)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	game.input_locked = false
	game.adhesive.clear()
	for body: Node in game.props.values(): body.set_absent(true)
	for actor: Node3D in game.actors:
		actor.set_physics_process(false)
		actor.global_position = Vector3(25, 0, 25)
	var player: Node = game.local_player()
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.01, 4)
	player.velocity = Vector3.ZERO
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0
	var box: Node = game.stage.spawn("applebox", Vector3(0, 0.02, 2.4))
	await frames(45)
	game.h_grab(box.pid)
	check(box.holder == player.peer_id, "fixture acquires the box")
	# Move the held box through the crew using the actual holding controller.
	player.hold_offset = Vector3(0, 0, 1.6)
	await frames(90)
	check(not game.holding_support(player, box), "box intersecting the feet is not a support")
	game.update_hold_collision(player)
	check(box.get_collision_exceptions().has(player), "foot overlap retains the holder collision exception")
	var before: Vector3 = player.global_position
	player.set_physics_process(true)
	game.input_locked = true
	var peak_drift := 0.0
	var peak_step := 0.0
	var last: Vector3 = before
	var contact_frames := 0
	for i in 120:
		await frames(1)
		peak_drift = maxf(peak_drift, player.global_position.distance_to(before))
		peak_step = maxf(peak_step, player.global_position.distance_to(last))
		last = player.global_position
		for j in player.get_slide_collision_count():
			if player.get_slide_collision(j).get_collider() == box: contact_frames += 1
	print("HELD_CONTACT_MEASURE foot_overlap drift_m=", peak_drift, " step_m=", peak_step, " contacts=", contact_frames)
	check(peak_drift < 0.03 and peak_step < 0.01 and contact_frames == 0, "held box cannot shake or push the stationary crew")
	game.host_release(box)
	check(not box.get_collision_exceptions().has(player) and not player.get_collision_exceptions().has(box), "release restores collisions on both bodies")
	player.set_physics_process(false)
	player.global_position = Vector3(0, 2, 4)
	box.restore([Vector3(0, 0.02, 4), Quaternion.IDENTITY, false])
	await frames(45)
	var top: float = (box.global_transform * AABB(box.center - box.half, box.half * 2.0)).end.y
	player.global_position = Vector3(0, top + 0.08, 4)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(30)
	check(player.is_on_floor() and game.holding_support(player, box), "standing on the box still counts as support")
	game.input_locked = false
	game.h_grab(box.pid)
	game.input_locked = true
	before = player.global_position
	await frames(90)
	check(not box.get_collision_exceptions().has(player), "grabbing own support preserves contact")
	check(player.global_position.distance_to(before) < 0.03, "grabbing own support keeps the crew stable")
	game.input_locked = false
	var initial_box_y: float = box.global_position.y
	var jump_count := 0
	var peak_rise := 0.0
	for attempt in 6:
		Input.action_press("jump")
		await frames(2)
		if player.velocity.y > 1.0: jump_count += 1
		Input.action_release("jump")
		for i in 73:
			await frames(1)
			peak_rise = maxf(peak_rise, player.global_position.y - before.y)
	print("HELD_CONTACT_MEASURE own_support_jumps count=", jump_count, " crew_rise_m=", peak_rise, " box_rise_m=", box.global_position.y - initial_box_y)
	check(jump_count == 0 and peak_rise < 0.03, "own held support cannot be used to jump upward repeatedly")
	game.host_release(box)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.velocity.y > 1.0, "released box is a valid jumping platform again")
	player.set_physics_process(false)
	player.global_position = Vector3(2, 0.01, 4)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(10)
	game.h_grab(box.pid)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.velocity.y > 1.0, "crew can jump from the world floor while carrying a prop")
	game.host_release(box)
	print("HELD_CONTACT_TEST_FAIL" if failed else "HELD_CONTACT_TEST_OK")
	current_scene = null
	game.queue_free()
	root.get_node("Sfx").silence_all()
	await frames(8)
	quit(1 if failed else 0)
