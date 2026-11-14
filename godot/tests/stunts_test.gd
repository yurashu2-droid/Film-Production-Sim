extends SceneTree
# スタントの土台（features/stunts.gd）：
#   ・低い所から降りても、何も起きない。高い所から硬い床に落ちると、のびる（ぺちゃんこ・星・動けない・持っていた物を落とす）
#   ・数秒で、元に戻る
#   ・段ボール箱が足りていれば、受け止める（箱は、はじかれる）。足りなければ、のびる
#   ・スロー光線を浴びていれば、高い所から降りても平気
#   godot --headless --path godot --fixed-fps 60 --script res://tests/stunts_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("STUNT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func put(prop: Node, pos: Vector3) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	prop.restore([pos, Quaternion.IDENTITY, false])
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.sleeping = false


# 空中に置いて、床に着くまで待つ（着いてから、少し待つ）
func fall(me: Node3D, from: Vector3) -> void:
	me.velocity = Vector3.ZERO
	me.global_position = from
	await frames(3)
	for i in 600:
		await physics_frame
		if me.is_on_floor():
			break
	await frames(6)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var f: Node = game.hooks.feature("stunts")
	var me: Node3D = game.local_player()
	var id := int(me.peer_id)
	check(f != null, "スタントの仕組みが、登録されている")
	var spot: Vector3 = game.production.HOME_SET + Vector3(6.0, 0.0, 8.0)       # 床のある、何も無い所
	var cartons: Array = game.props.values().filter(func(p: Node) -> bool: return p.kind == "carton" and not p.absent)
	check(cartons.size() >= 3, "段ボール箱が3つ以上ある（%d）" % cartons.size())
	for c: Node in cartons:
		put(c, spot + Vector3(20.0 + float(cartons.find(c)) * 2.0, 0.3, 0.0))        # 箱は、いったん遠くへ

	# ---- 低い所：何も起きない ----
	await fall(me, spot + Vector3(0.0, 2.0, 0.0))
	check(me.down <= 0.0 and f.downs.is_empty() and me.vis.scale.is_equal_approx(Vector3.ONE), "2m から降りても、何も起きない")
	me.velocity.y = me.JUMP
	await frames(60)
	check(me.down <= 0.0 and f.downs.is_empty(), "その場で跳んでも、何も起きない")

	# ---- 高い所から硬い床：のびる ----
	game.act_grab(int(cartons[0].pid))
	await frames(10)
	check(int(me.held) == int(cartons[0].pid), "（準備）箱を1つ持つ")
	await fall(me, spot + Vector3(0.0, 5.0, 0.0))
	check(me.down > 2.0 and f.downs.has(id), "5m から硬い床に落ちると、のびる（%.1f 秒）" % me.down)
	await frames(15)
	check(me.vis.scale.y < 0.3 and me.vis.scale.x > 1.2, "のびている間は、ぺちゃんこ（高さ %.2f 倍）" % me.vis.scale.y)
	check(int(me.held) == 0, "持っていた物は、落とす")
	var stars: Node3D = f.downs[id].stars if f.downs.has(id) else null
	check(stars != null and stars.get_child_count() == 3 and (stars.get_child(0) as MeshInstance3D).layers == f.CREW_LAYER, "頭の上を星が3つ回る（映画に映らない層）")
	check(str(me.vis.face) == "shock", "顔は、びっくり")
	var before: Vector3 = me.global_position
	Input.action_press("move_forward")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("move_forward")
	Input.action_release("jump")
	check(me.global_position.distance_to(before) < 0.05, "のびている間は、歩けない・跳べない（動いた分 %.2f m）" % me.global_position.distance_to(before))
	game.act_grab(int(cartons[1].pid))
	await frames(6)
	check(int(me.held) == 0, "のびている間は、物を持てない（ホストが断る）")
	await frames(int(f.DOWN_MAX * 60.0) + 30)
	check(me.down <= 0.0 and f.downs.is_empty() and me.vis.scale.is_equal_approx(Vector3.ONE), "数秒で、元に戻る")
	check(not is_instance_valid(stars) or stars.is_queued_for_deletion() or stars.get_children().all(func(s: Node) -> bool: return not s.visible), "星は、落ちて、いなくなる")
	before = me.global_position
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	check(me.global_position.distance_to(before) > 0.5, "戻ったら、また歩ける（%.2f m）" % me.global_position.distance_to(before))

	# ---- 段ボール箱が受け止める ----
	me.velocity = Vector3.ZERO
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	await frames(5)
	var h0: float = float(cartons[0].half.y)
	put(cartons[0], spot + Vector3(-0.3, h0 + 0.02, 0.0))
	put(cartons[1], spot + Vector3(0.3, h0 + 0.02, 0.0))
	await frames(50)
	var c0: Vector3 = cartons[0].global_position
	var need: float = f.speed_from(5.0)
	check(need - 2.0 * float(f.SOFT["carton"]) < f.KO_SPEED and need >= f.KO_SPEED, "（計算）5m は、箱2つで足りる（%.1f m/秒）" % need)
	await fall(me, spot + Vector3(0.0, 5.0 + h0 * 2.0, 0.0))
	check(me.down <= 0.0 and f.downs.is_empty(), "箱2つの上に 5m から落ちても、のびない")
	await frames(20)
	check(cartons[0].global_position.distance_to(c0) > 0.3, "受け止めた箱は、はじかれて動く（%.2f m）" % cartons[0].global_position.distance_to(c0))

	# ---- 足りないと、のびる ----
	me.velocity = Vector3.ZERO
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	await frames(5)
	put(cartons[1], spot + Vector3(20.0, 0.3, 4.0))
	put(cartons[0], spot + Vector3(0.0, h0 + 0.02, 0.0))
	await frames(50)
	need = f.speed_from(9.0)
	check(need - float(f.SOFT["carton"]) >= f.KO_SPEED, "（計算）9m は、箱1つでは足りない（%.1f m/秒）" % need)
	await fall(me, spot + Vector3(0.0, 9.0 + h0 * 2.0, 0.0))
	check(me.down > 0.0 and f.downs.has(id), "箱1つの上に 9m から落ちると、のびる")
	await frames(int(f.DOWN_MAX * 60.0) + 40)
	check(me.down <= 0.0 and f.downs.is_empty(), "また、元に戻る")

	# ---- スロー光線の中なら、平気 ----
	put(cartons[0], spot + Vector3(20.0, 0.3, 0.0))
	var slow: Node = game.hooks.feature("slow_ray")
	if not slow.on:
		slow.h_switch()
	slow.beam_override = [spot + Vector3(-4.0, 0.9, 0.0), Vector3(1.0, 0.0, 0.0)]       # 着地する所を、横から照らす
	me.velocity = Vector3.ZERO
	me.global_position = spot + Vector3(0.0, 5.0, 0.0)
	await frames(3)
	var soaked := false
	for i in 900:
		await physics_frame
		soaked = soaked or int(me.peer_id) in slow.players_in
		if me.is_on_floor():
			break
	await frames(6)
	check(soaked and me.down <= 0.0 and f.downs.is_empty(), "スロー光線の中に 5m から降りても、のびない")
	slow.beam_override = []
	if slow.on:
		slow.h_switch()
	await frames(5)

	print("STUNT_TEST_FAIL" if failed else "STUNT_TEST_OK")
	quit(1 if failed else 0)
