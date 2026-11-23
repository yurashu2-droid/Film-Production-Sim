extends SceneTree
# 物の上に載った物は、下の物を持って動かすと、いっしょについて来るか。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/stack_carry_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(80.0).timeout.connect(func() -> void:
		print("STACK_CARRY_TEST_TIMEOUT")
		quit(2))
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("STACK_CARRY_CHECK ", what, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(n: int) -> void:
	for i in n:
		await physics_frame


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
	me.aim_pitch = -0.2
	# [名前, 毎コマの左右, 毎コマの上下, コマ数, 持ち上げ]
	var moves := [["slow", 0.004, 0.0, 90, 0.0], ["fast", 0.02, 0.0, 30, 0.0], ["look_up", 0.0, 0.006, 60, 0.0], ["look_down", 0.0, -0.006, 50, 0.0], ["lift", 0.003, 0.0, 60, 0.6]]
	for kind: String in ["applebox", "carton", "dolly"]:
		for move: Array in moves:
			me.aim_yaw = 0.0
			me.aim_pitch = -0.2
			var low: Node = game.stage.spawn(kind, Vector3(0, 0.02, 2.0))
			await frames(30)
			var top_y: float = low.global_position.y + low.deck_top if low.deck_top >= 0.0 else (low.global_transform * (low.center + Vector3(0, low.half.y, 0))).y
			var high: Node = game.stage.spawn("applebox", Vector3(0, top_y + 0.02, 2.0))
			await frames(90)
			var rel: Transform3D = low.global_transform.affine_inverse() * high.global_transform
			game.h_grab(low.pid, low.center)
			await frames(10)
			if float(move[4]) > 0.0:
				for j in 3:
					game.act_hold_command("lift", 0.2)
					await frames(8)
			for i in int(move[3]):
				me.aim_yaw += float(move[1])
				me.aim_pitch += float(move[2])
				await physics_frame
			await frames(30)
			var want: Vector3 = low.global_transform * rel.origin
			var drift: float = high.global_position.distance_to(want)
			var moved: float = low.global_position.distance_to(Vector3(0, low.global_position.y, 2.0))
			var tilt: float = rad_to_deg(acos(clampf(low.global_basis.orthonormalized().y.dot(Vector3.UP), -1, 1)))
			print("STACK_CARRY %s %s low_moved=%.2f low_tilt=%.0f top_drift=%.2f" % [kind, move[0], moved, tilt, drift])
			# 大きく傾けた時（見上げて 30 度より傾いた時）は、上の物が滑り落ちてよい
			if tilt <= 30.0:
				check(drift < 0.12, "%s %s: the prop on top comes along" % [kind, move[0]])
			game.h_release()
			await frames(20)
			low.set_absent(true)
			high.set_absent(true)
			await frames(5)
	print("STACK_CARRY_TEST_FAIL" if failed else "STACK_CARRY_TEST_OK")
	quit(1 if failed else 0)
