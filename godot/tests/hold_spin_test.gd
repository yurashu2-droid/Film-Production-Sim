extends SceneTree
# 持った物の回転が「画面から見たままの向き」になっているかを確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/hold_spin_test.gd
# 物をどの向きで掴んでいても、マウスを縦に動かせば画面の横軸まわり、横に動かせば上向きの軸まわりに回ること。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("HOLD_SPIN_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# いまの目標の向きから、回した分の軸と角度を取り出す
func turned(before: Basis, after: Basis) -> Array:
	var dq := (Quaternion(after) * Quaternion(before).inverse()).normalized()
	if dq.w < 0.0:
		dq = -dq
	return [dq.get_axis(), dq.get_angle()]


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	game.h_accept_job(0)
	await frames(20)
	var me: Node = game.local_player()
	var box: Node
	for pid: int in game.props:
		if game.props[pid].kind == "applebox":
			box = game.props[pid]
			break
	# 物を、いろいろな向きで掴ませて試す（前は、横向きに掴むと縦の回転が「横への傾き」になった）
	for start_yaw: float in [0.0, PI * 0.5, 2.1]:
		for view_yaw: float in [0.0, 1.2]:
			me.aim_yaw = view_yaw
			me.aim_pitch = -0.2
			await frames(4)
			var fwd: Vector3 = me.flat_forward()
			var state: Array = box.get_state()
			state[0] = me.global_position + fwd * 1.6 + Vector3(0, 0.05, 0)
			state[1] = Quaternion(Vector3.UP, start_yaw)
			state[2] = false
			box.restore(state)
			await frames(4)
			game.h_grab(box.pid)
			await frames(6)
			var tag := "掴んだ向き %.1f・視線 %.1f" % [start_yaw, view_yaw]
			check(me.held == box.pid, "%s：掴めた" % tag)
			var right: Vector3 = Basis(Vector3.UP, view_yaw) * Vector3.RIGHT
			var base: Basis = game.hold_target(me.peer_id, box)[4]
			me.spin_hold(Vector3.RIGHT, 0.4)
			var tilt: Array = turned(base, game.hold_target(me.peer_id, box)[4])
			check(absf(tilt[1] - 0.4) < 0.01 and (tilt[0] as Vector3).dot(right) > 0.99, "%s：縦に動かすと、画面の横軸まわりに回る" % tag)
			base = game.hold_target(me.peer_id, box)[4]
			me.spin_hold(Vector3.UP, 0.3)
			var swing: Array = turned(base, game.hold_target(me.peer_id, box)[4])
			check(absf(swing[1] - 0.3) < 0.01 and (swing[0] as Vector3).dot(Basis.from_euler(Vector3(me.aim_pitch, view_yaw, 0.0)) * Vector3.UP) > 0.99, "%s：縦に回したあとでも、横に動かすと画面の縦軸まわりに回る" % tag)
			base = game.hold_target(me.peer_id, box)[4]
			me.spin_hold(Vector3.RIGHT, -1.9)
			me.spin_hold(Vector3.RIGHT, 0.5)
			var again: Array = turned(base, game.hold_target(me.peer_id, box)[4])
			check(absf(again[1] - 1.4) < 0.01 and (again[0] as Vector3).dot(-right) > 0.99, "%s：大きく回しても、同じ軸で回り続ける" % tag)
			# 体ごと向きを変えると、回した分も一緒について回る
			base = game.hold_target(me.peer_id, box)[4]
			me.aim_yaw = view_yaw + 0.7
			await frames(6)
			var carried: Array = turned(base, game.hold_target(me.peer_id, box)[4])
			check(absf(carried[1] - 0.7) < 0.02 and (carried[0] as Vector3).dot(Vector3.UP) > 0.99, "%s：向きを変えると、物も同じだけ回る" % tag)
			game.h_release()
			await frames(6)
	# 重力：回していない間は、掴んだ点を支点に垂れる。回している間は向きを保つ
	var plank: Node
	for pid: int in game.props:
		if game.props[pid].kind == "riser":      # 重い物（足場 24kg）。軽い物は垂れない
			plank = game.props[pid]
			break
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0
	await frames(4)
	var st: Array = plank.get_state()
	st[0] = me.global_position + me.flat_forward() * 2.2 + Vector3(0, 0.05, 0)
	st[1] = Quaternion.IDENTITY
	st[2] = false
	plank.restore(st)
	await frames(6)
	# 板の右上の角を掴む
	var corner: Vector3 = plank.center + Vector3(plank.half.x * 0.9, plank.half.y * 0.9, 0)
	game.h_grab(plank.pid, corner)
	await frames(4)
	me.hold_offset = Vector3(0, 1.6, 0)
	await frames(90)
	check(me.held == plank.pid, "板の角を掴めた")
	check(plank.global_basis.y.dot(Vector3.UP) > 0.98, "回している扱いの間（確認の既定）は、角を掴んでも向きを保つ")
	me.hold_turning = false
	await frames(240)
	var grip_at: Vector3 = plank.global_transform * plank.hold_grip_local
	var hang_dir: Vector3 = (plank.center_global() - grip_at).normalized()
	print("HOLD_SPIN_MEASURE 掴んだ点=", grip_at, " 垂れた向き=", hang_dir, " 上向き=", plank.global_basis.y.dot(Vector3.UP), " 回る速さ=", plank.angular_velocity.length())
	check(hang_dir.dot(Vector3.DOWN) > 0.9, "右クリックを離すと、掴んだ角を支点に垂れる（重心が真下へ来る）")
	check(plank.angular_velocity.length() < 0.6, "揺れは、しばらくすると収まる")
	var hung: Basis = plank.global_basis.orthonormalized()
	me.hold_turning = true
	await frames(30)
	check(Quaternion(hung).angle_to(Quaternion(plank.global_basis.orthonormalized())) < 0.08, "回し始めても、前の向きへ跳ね戻らない（垂れた向きのまま止まる）")
	me.spin_hold(Vector3.FORWARD, 0.8)
	await frames(60)
	var set_to: Basis = plank.global_basis.orthonormalized()
	check(Quaternion(hung).angle_to(Quaternion(set_to)) > 0.6, "押している間は、重力に逆らって回せる")
	await frames(60)
	check(Quaternion(set_to).angle_to(Quaternion(plank.global_basis.orthonormalized())) < 0.05, "押している間は、回した向きを保つ")
	me.hold_turning = false
	await frames(240)
	grip_at = plank.global_transform * plank.hold_grip_local
	check((plank.center_global() - grip_at).normalized().dot(Vector3.DOWN) > 0.9, "離すと、また垂れる")
	game.h_release()
	await frames(6)
	# 軽い物（カンペ）：右クリックを離していても垂れず、視点と同じだけ向きを変える（画面の中での向きが変わらない）
	var card: Node = game.cue_cards.card
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0
	me.hold_turning = true
	await frames(4)
	var cs: Array = card.get_state()
	cs[0] = me.global_position + me.flat_forward() * 1.8 + Vector3(0, 0.05, 0)
	cs[1] = Quaternion.IDENTITY
	cs[2] = false
	card.restore(cs)
	await frames(6)
	game.h_grab(card.pid, card.center + Vector3(card.half.x * 0.9, card.half.y * 0.9, 0))
	await frames(4)
	me.hold_offset = Vector3(0, 1.2, 0)
	await frames(60)
	check(me.held == card.pid, "カンペの角を掴めた")
	# 力を抜いていない（ふだんの持ち方）
	await frames(120)
	var view_then: Basis = Basis.from_euler(Vector3(me.aim_pitch, me.aim_yaw, 0.0))
	var card_then: Basis = card.global_basis.orthonormalized()
	for i in 30:
		me.aim_pitch = lerpf(0.0, 0.4, (i + 1) / 30.0)
		me.aim_yaw = lerpf(0.0, 0.6, (i + 1) / 30.0)
		await frames(1)
	await frames(90)
	var view_now: Basis = Basis.from_euler(Vector3(me.aim_pitch, me.aim_yaw, 0.0))
	var kept: float = Quaternion(view_now.inverse() * card.global_basis.orthonormalized()).angle_to(Quaternion(view_then.inverse() * card_then))
	print("HOLD_SPIN_MEASURE カンペ：視点から見た向きのずれ=", rad_to_deg(kept), "度")
	check(kept < 0.12, "力を抜いていなければ、垂れず、視点から見た向きが変わらない")
	game.h_release()
	await frames(6)
	# 転がして運ぶ物（台車）：ふだんは床を転がす。右クリックを押している間だけ、浮かせて持ち上げられる
	var dolly: Node
	for pid: int in game.props:
		if game.props[pid].kind == "dolly" and not game.props[pid].absent:
			dolly = game.props[pid]
			break
	if dolly != null:
		me.aim_yaw = 0.0
		me.aim_pitch = -0.3
		me.hold_offset = Vector3.ZERO
		await frames(4)
		var ds: Array = dolly.get_state()
		ds[0] = me.global_position + me.flat_forward() * 2.6 + Vector3(0, 0.05, 0)
		ds[1] = Quaternion.IDENTITY
		ds[2] = false
		dolly.restore(ds)
		await frames(30)
		game.h_grab(dolly.pid)
		await frames(20)
		var floor_y: float = dolly.global_position.y
		me.aim_pitch = 0.3
		await frames(60)
		check(me.held == dolly.pid and dolly.global_position.y - floor_y < 0.1, "台車は、ふだんは見上げても床から浮かない")
		me.hold_raise = true
		await frames(90)
		check(dolly.global_position.y - floor_y > 0.4, "右クリックの間は、台車が浮いて持ち上がる（%.2f m）" % (dolly.global_position.y - floor_y))
		me.hold_raise = false
		await frames(120)
		check(dolly.global_position.y - floor_y < 0.15, "離すと、床へ降りる")
		game.h_release()
		await frames(6)
	print("HOLD_SPIN_TEST_FAIL" if failed else "HOLD_SPIN_TEST_OK")
	var sfx := root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	await frames(8)
	quit(1 if failed else 0)
