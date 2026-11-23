extends SceneTree
# 吊りクレーン（scripts/features/crane_tower.gd）と、その滑車にロープを掛ける（features/contraptions.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/crane_tower_test.gd
# A：会社の庭に1台。高さ 5.6m。滑車が4つ。置き場所が、ほかの物と重なっていない。立ったまま動かない。
# B：束を持って滑車を見て F：最初の端なら結ぶ・結んでいる途中なら掛ける。
# C：ハーネス → 腕の先 → 腕の後ろ → サンドバッグ：役者が上がる。クレーンは倒れない。
# D：ハーネス → 腕の先 → 手に持った箱：箱を持って横へ歩くと、役者が上がる。クレーンは倒れない・引きずられない。
#    塔に沿って下ろす道（腕の先 → 塔の上 → 塔の根元）は、束の 10m では、地面の人までは届かない。
# E：重い物（40kg）を腕の先に吊ると、クレーンごと倒れる。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(170).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CRANE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func top_of(p: RigidBody3D) -> Vector3:
	return p.center_global() + Vector3(0, p.half.y * 0.9, 0)


func tilt(p: Node3D) -> float:
	return rad_to_deg(p.global_basis.y.angle_to(Vector3.UP))


# 視線（カメラの真ん中）を、その点へ向ける
func look(me: Node3D, at: Vector3) -> void:
	for i in 8:
		var d: Vector3 = (at - (me.cam as Camera3D).global_position).normalized()
		me.aim_yaw = atan2(-d.x, -d.z)
		me.aim_pitch = clampf(asin(d.y), -1.2, 1.0)
		await frames(2)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var rig: Node = game.hooks.feature("contraptions")
	var hz: Node = game.hooks.feature("harness")
	var cz: Node = game.hooks.feature("crane_tower")
	check(cz != null and rig != null and hz != null, "吊りクレーンの仕組みが登録されている")
	if cz == null or rig == null or hz == null:
		quit(1)
		return
	# ---- A：置いてある ----
	var crane: RigidBody3D = cz.cranes[0]
	check(cz.cranes.size() == 1 and str(crane.kind) == "crane" and not crane.absent, "会社の庭に、吊りクレーンが1台")
	check(absf(float(crane.half.y) * 2.0 - cz.HEIGHT) < 0.05 and (cz.GUIDES as Array).size() == 4, "高さ %.1f m・滑車4つ" % (float(crane.half.y) * 2.0))
	await frames(120)
	check(tilt(crane) < 2.0 and crane.global_position.distance_to(cz.HOME_AT) < 0.3, "置いたまま、立っている（傾き %.1f 度・ずれ %.2f m）" % [tilt(crane), crane.global_position.distance_to(cz.HOME_AT)])
	var near := INF
	var who := ""
	var reach: float = maxf(float(crane.half.x), float(crane.half.z))
	for p: Node3D in game.props.values():
		if p != crane and not p.absent:
			var d: float = Vector2(p.global_position.x - crane.global_position.x, p.global_position.z - crane.global_position.z).length()
			if d < near:
				near = d
				who = str(p.kind)
	check(near > reach, "置き場所が、ほかの物と重なっていない（いちばん近い物：%s まで %.2f m）" % [who, near])
	var tip: Vector3 = cz.guide_at(crane, 0)
	check(tip.y - crane.global_position.y > 4.0 and absf(tip.y - cz.guide_at(crane, 1).y) < 0.01 and cz.guide_at(crane, 2).y - crane.global_position.y < 0.8, "腕の先の滑車は高い所（%.2f m）、根元の滑車は低い所" % (tip.y - crane.global_position.y))
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	check(game.state == game.S.PREP and not crane.absent, "現場（事務所の前）で準備中。クレーンは庭にある")
	var P: Vector3 = crane.global_position
	# ---- B：束を持って、滑車を見て F ----
	var coil: RigidBody3D = game.cargo_kit.rope
	var base: Vector3 = cz.guide_at(crane, 2)
	me.global_position = Vector3(base.x + 1.6, P.y + 0.05, base.z + 0.3)
	me.velocity = Vector3.ZERO
	coil.restore([me.global_position + Vector3(0.6, 0.1, 0.6), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab.rpc_id(1, coil.pid)
	await frames(5)
	await look(me, base)
	var act: Dictionary = rig.f_action(me)
	check(str(act.get("do", "")) == "tie" and int(act.get("pid", 0)) == crane.pid and (act["point"] as Vector3).distance_to(base) < 0.01, "束を持って、塔の根元の滑車を見ると「結ぶ」（%s）" % str(act.get("name", "")))
	await look(me, cz.guide_at(crane, 1))
	act = rig.f_action(me)
	check(str(act.get("do", "")) == "tie" and (act["point"] as Vector3).distance_to(cz.guide_at(crane, 1)) < 0.01, "塔の上の滑車（高さ %.1f m）も、下から狙える" % (cz.guide_at(crane, 1).y - P.y))
	rig.hook_f(me)
	await frames(2)
	check(rig.pending.has(int(me.peer_id)), "F で、端を結んだ（結んでいる途中）")
	await look(me, base)
	act = rig.f_action(me)
	check(str(act.get("do", "")) == "via" and int(act.get("pid", 0)) == cz.via_id(crane.pid, 2), "結んでいる途中に、根元の滑車を見ると「掛ける」")
	rig.hook_f(me)
	await frames(2)
	check((rig.pending[int(me.peer_id)]["via"] as Array) == [cz.via_id(crane.pid, 2)], "F で、滑車に掛かった")
	game.h_release.rpc_id(1)
	await frames(5)
	check(rig.pending.is_empty(), "束を手放すと、やめる")
	# ---- C：重りで吊る ----
	var a: CharacterBody3D = game.actors[0]
	a.set_state(a.St.IDLE)
	a.velocity = Vector3.ZERO
	a.global_position = Vector3(tip.x, P.y + 0.05, tip.z)
	var h: RigidBody3D = hz.parts[0]
	hz.host_wear(h, -1)
	var tail: Vector3 = cz.guide_at(crane, 3)
	var bag: RigidBody3D = game.stage.spawn("sandbag", Vector3(tail.x - 0.25, tail.y - 0.7, tail.z), 0.0)
	bag.set_fixed(true)
	await frames(10)
	var row1: int = rig.host_add_row([h.pid, Vector3.ZERO], [bag.pid, bag.to_local(top_of(bag))], [cz.via_id(crane.pid, 0), cz.via_id(crane.pid, 3)])
	check(row1 != 0, "ハーネス → 腕の先 → 腕の後ろ → サンドバッグ、とロープが張れた（%.1f m）" % (float(rig.rows[row1]["len"]) if row1 != 0 else 0.0))
	bag.set_fixed(false)
	var a_y0: float = a.global_position.y
	var most := 0.0
	for i in 420:
		await physics_frame
		most = maxf(most, tilt(crane))
	check(a.global_position.y > a_y0 + 2.5 and not a.is_on_floor(), "サンドバッグが下がって、役者が上がる（%.2f m）" % (a.global_position.y - a_y0))
	var ring: Vector3 = hz.attach_at(h.pid)
	check(tip.y - ring.y > hz.JAM - 0.15 and tip.y - ring.y < hz.JAM + 0.35, "上がりきると、滑車の 1m 下で止まる（背中の輪は、滑車の %.2f m 下。頭が腕につかえない）" % (tip.y - ring.y))
	check(bag.global_position.y > P.y + 0.6, "重りは、途中でぶら下がったまま（高さ %.2f m）" % (bag.global_position.y - P.y))
	var still: float = a.global_position.y
	await frames(60)
	check(absf(a.global_position.y - still) < 0.08, "上がりきった所で、揺れずに止まっている（1秒で %.3f m）" % absf(a.global_position.y - still))
	check(most < 8.0 and crane.global_position.distance_to(P) < 0.4, "クレーンは倒れない（いちばん傾いた時 %.1f 度・ずれ %.2f m）" % [most, crane.global_position.distance_to(P)])
	print("CRANE_INFO actor rise %.2f bag y %.2f" % [a.global_position.y - a_y0, bag.global_position.y - P.y])
	rig.host_snap(row1, 1.0)
	await frames(150)
	check(a.is_on_floor(), "切ると、役者が落ちる")
	# ---- D：塔に沿って下ろして、手で引く ----
	rig.rows.clear()
	rig._changed()
	game.bomb_kit.stock = float(game.bomb_kit.COIL_M)      # 束は1日 10m。切れた分は戻らないので、ここでは新しい束にする
	bag.restore([P + Vector3(-4.0, 0.2, 3.0), Quaternion.IDENTITY, false])
	a.set_state(a.St.IDLE)
	a.velocity = Vector3.ZERO
	a.global_position = Vector3(tip.x, P.y + 0.05, tip.z)
	var box: RigidBody3D = null
	for p: Node in game.props.values():
		if str(p.kind) == "carton" and not p.absent and box == null:
			box = p
	me.global_position = Vector3(tip.x, P.y + 0.05, tip.z + 1.6)
	me.velocity = Vector3.ZERO
	me.aim_yaw = 0.0
	me.aim_pitch = -0.2
	box.restore([me.global_position + Vector3(0, 0.3, 0.9), Quaternion.IDENTITY, false])
	await frames(20)
	game.h_grab.rpc_id(1, box.pid)
	await frames(15)
	var long_way: int = rig.host_add_row([h.pid, Vector3.ZERO], [box.pid, Vector3.ZERO], [cz.via_id(crane.pid, 0), cz.via_id(crane.pid, 1), cz.via_id(crane.pid, 2)])
	check(long_way == 0, "塔に沿って下ろす道は、束の 10m では、地面の人までは届かない（張れない）")
	var row2: int = rig.host_add_row([h.pid, Vector3.ZERO], [box.pid, Vector3.ZERO], [cz.via_id(crane.pid, 0)])
	check(row2 != 0 and int(box.holder) == int(me.peer_id), "ハーネス → 腕の先 → 手に持った箱、とロープが張れた（%.1f m）" % (float(rig.rows[row2]["len"]) if row2 != 0 else 0.0))
	a_y0 = a.global_position.y
	most = 0.0
	for i in 150:
		me.global_position.z += 2.6 / 150.0
		await physics_frame
		most = maxf(most, tilt(crane))
	await frames(40)
	check(a.global_position.y > a_y0 + 1.2 and not a.is_on_floor(), "箱を持って歩くと、役者が上がる（%.2f m）" % (a.global_position.y - a_y0))
	check(most < 8.0 and crane.global_position.distance_to(P) < 0.4, "横から手で引いても、クレーンは倒れない・引きずられない（傾き %.1f 度・ずれ %.2f m）" % [most, crane.global_position.distance_to(P)])
	game.h_release.rpc_id(1)
	await frames(3)
	me.global_position += Vector3(3.0, 0, 0)
	await frames(150)
	check(a.is_on_floor(), "箱を離すと、役者が降りる")
	# ---- E：重すぎる物 ----
	rig.rows.clear()
	rig._changed()
	game.bomb_kit.stock = float(game.bomb_kit.COIL_M)
	a.global_position = P + Vector3(-5.0, 0.05, -3.0)
	box.restore([P + Vector3(-5.0, 0.3, 3.0), Quaternion.IDENTITY, false])
	bag.restore([Vector3(tip.x, P.y + 2.5, tip.z), Quaternion.IDENTITY, true])
	bag.mass = 40.0          # バルコニーくらいの重さの物として
	await frames(5)
	var row3: int = rig.host_add_row([crane.pid, cz.guide_local(0)], [bag.pid, bag.to_local(top_of(bag))], [])
	bag.set_fixed(false)
	most = 0.0
	for i in 300:
		await physics_frame
		most = maxf(most, tilt(crane))
	check(row3 != 0 and most > 25.0, "40kg の物を腕の先に吊ると、クレーンごと倒れる（傾き %.1f 度）" % most)
	print("CRANE_TEST_FAIL" if failed else "CRANE_TEST_OK")
	quit(1 if failed else 0)
