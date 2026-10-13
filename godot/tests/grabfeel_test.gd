extends SceneTree
# 持ったときの手ごたえを確かめる。
#   ・掴んだ点が、視線の先（掴んだときの位置関係のまま）を追う
#   ・上下を向いても物は傾かない。左右を向くと、物の向きも一緒に回る
#   ・掴んだ点を支点にして回る（Q/E で回しても、掴んだ点は動かない）
#   ・人が乗っている物は、持ち上げても回しても人を飛ばさない
#   godot --headless --path godot --fixed-fps 60 --script res://tests/grabfeel_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(80.0).timeout.connect(func() -> void:
		print("GRABFEEL_TEST_TIMEOUT")
		quit(2))
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("GRABFEEL_CHECK ", what, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func tilt_of(body: Node3D) -> float:
	return rad_to_deg(acos(clampf(body.global_basis.orthonormalized().y.dot(Vector3.UP), -1.0, 1.0)))


func yaw_of(body: Node3D) -> float:
	var f: Vector3 = body.global_basis.z
	return atan2(f.x, f.z)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	game.production.set_physics_process(false)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	game.input_locked = false
	for body: Node in game.props.values():
		body.set_absent(true)
	for actor: Node3D in game.actors:
		actor.set_physics_process(false)
		actor.global_position = Vector3(25, 0, 25)
	var me: Node = game.local_player()
	me.set_physics_process(false)
	me.global_position = Vector3(0, 0.05, 4)
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0

	# --- 1) 立てた板を、上のほうで掴む ---
	var board: Node = game.stage.spawn("flat", Vector3(0, 0.02, 1.8))
	await frames(40)
	var grip_local: Vector3 = board.center + Vector3(0, board.half.y * 0.6, 0)
	var before: Transform3D = board.global_transform
	game.h_grab(board.pid, grip_local)
	check(board.holder == me.peer_id, "grab acquires the board")
	await frames(20)
	check(board.global_position.distance_to(before.origin) < 0.03 and tilt_of(board) < 2.0, "grabbing alone does not move or tip the board")

	# 上を向く：掴んだ点は上がるが、板は傾かない
	var grip_before: Vector3 = board.global_transform * grip_local
	for i in 30:
		me.aim_pitch = lerpf(0.0, 0.35, (i + 1) / 30.0)
		await frames(1)
	await frames(50)
	var grip_up: Vector3 = board.global_transform * grip_local
	print("GRABFEEL look-up: grip rose %.2f m, tilt %.1f deg" % [grip_up.y - grip_before.y, tilt_of(board)])
	check(grip_up.y - grip_before.y > 0.4, "looking up lifts the grabbed point")
	check(tilt_of(board) < 4.0, "looking up does not tip the board (%.1f deg)" % tilt_of(board))

	# 左右を向く：掴んだ点が視線について回り、板の向きも同じだけ回る
	var yaw_before := yaw_of(board)
	for i in 40:
		me.aim_yaw = lerpf(0.0, 0.7, (i + 1) / 40.0)
		await frames(1)
	await frames(60)
	var turned := wrapf(yaw_of(board) - yaw_before, -PI, PI)
	var goal: Array = game.hold_target(me.peer_id, board)
	var gap: float = (board.global_transform * grip_local).distance_to(goal[5])
	print("GRABFEEL look-side: board turned %.2f rad (camera 0.70), grip gap %.3f m, tilt %.1f deg" % [turned, gap, tilt_of(board)])
	check(absf(turned - 0.7) < 0.08, "turning the camera turns the board by the same angle")
	check(gap < 0.06, "the grabbed point settles on its target")
	check(tilt_of(board) < 4.0, "turning does not tip the board")

	# Q/E で回す：掴んだ点は支点なので、ほとんど動かない
	var pivot: Vector3 = board.global_transform * grip_local
	for i in 30:
		me.hold_yaw = lerpf(0.0, 0.9, (i + 1) / 30.0)
		await frames(1)
	await frames(50)
	var pivot_shift: float = (board.global_transform * grip_local).distance_to(pivot)
	print("GRABFEEL rotate: pivot moved %.3f m, yaw now %.2f" % [pivot_shift, wrapf(yaw_of(board) - yaw_before, -PI, PI)])
	check(pivot_shift < 0.06, "rotating pivots about the grabbed point (%.3f m)" % pivot_shift)
	game.h_release()
	await frames(10)
	board.set_absent(true)

	# --- 2) 別の人が乗っている箱を掴んで、持ち上げよう・回そうとする ---
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0
	me.hold_yaw = 0.0
	game._roster.append([2, 3])
	game._apply_roster()
	var rider: Node = game.players[2]
	rider.is_local = true
	for kind: String in ["applebox", "balcony"]:
		var crate: Node = game.stage.spawn(kind, Vector3(0, 0.02, 1.4))
		await frames(60)
		var top: float = (crate.global_transform * AABB(crate.center - crate.half, crate.half * 2.0)).end.y
		rider.global_position = Vector3(crate.global_position.x, top + 0.1, crate.global_position.z)
		rider.velocity = Vector3.ZERO
		game.input_locked = true          # 乗っている人は入力なし（立っているだけ）
		await frames(40)
		check(rider.is_on_floor(), kind + ": crew stands on it")
		var stand: Vector3 = rider.global_position
		game.input_locked = false
		game.h_grab(crate.pid)
		game.input_locked = true
		var peak_speed := 0.0
		var peak_rise := 0.0
		var peak_platform := 0.0
		for i in 150:
			# 掴んだ人が、上を向きながら横にも振り、Q/E でも回す
			me.aim_pitch = minf(0.7, i * 0.03)
			me.aim_yaw = sin(i * 0.12) * 0.6
			me.hold_yaw = i * 0.03
			await frames(1)
			peak_speed = maxf(peak_speed, rider.velocity.length())
			peak_platform = maxf(peak_platform, rider.get_platform_velocity().length())
			peak_rise = maxf(peak_rise, rider.global_position.y - stand.y)
		print("GRABFEEL %s with crew on top: crew rose %.2f m, speed %.2f, platform %.2f m/s, drifted %.2f m, y=%.2f" % [kind, peak_rise, peak_speed, peak_platform, rider.global_position.distance_to(stand), rider.global_position.y])
		check(peak_rise < 0.35, kind + ": crew on top is not lifted or launched (rose %.2f m)" % peak_rise)
		check(peak_platform < 1.5 and peak_speed < 6.0, kind + ": crew is not flung by what they stand on")
		check(rider.global_position.y > -0.3, kind + ": crew does not fall through the floor")
		game.input_locked = false
		if crate.holder != 0:
			game.host_release(crate)
		me.aim_pitch = 0.0
		me.aim_yaw = 0.0
		me.hold_yaw = 0.0
		rider.global_position = Vector3(6, 0.1, 6)
		await frames(10)
		crate.set_absent(true)
	print("GRABFEEL_TEST_FAIL" if failed else "GRABFEEL_TEST_OK")
	quit(1 if failed else 0)
