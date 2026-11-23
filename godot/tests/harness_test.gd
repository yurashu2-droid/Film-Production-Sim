extends SceneTree
# ハーネス（scripts/features/harness.gd）と、ロープで人を吊る（features/contraptions.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/harness_test.gd
# A：会社の備品にハーネスが2つ。持って F で自分が着る（物は現場から消えて、体に帯が付く）。
# B：ハーネス → 滑車 → 重り。9kg の物では人は浮かない。サンドバッグ（12kg）で、人がゆっくり上がって、ぶら下がる。切ると落ちて、のびる。
# C：雇った役者に着せる。ロープの先の箱を持って歩くと、役者が上がる。箱を離すと降りる。
# D：束を持って、着けている人のハーネスに結べる。外すと、ハーネスは物に戻り、ロープはハーネスに付いたまま。
# E：撮り直しで、着けていた人が元に戻る。帰社すると、全員脱ぐ。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("HARNESS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func top_of(p: RigidBody3D) -> Vector3:
	return p.center_global() + Vector3(0, p.half.y * 0.9, 0)


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
	check(hz != null and rig != null, "ハーネスの仕組みが登録されている")
	if hz == null or rig == null:
		quit(1)
		return
	check(hz.parts.size() == 2 and str(hz.parts[0].kind) == "harness", "会社の備品：ハーネス2つ")
	var near := INF
	for h: RigidBody3D in hz.parts:
		for p: Node3D in game.props.values():
			if p != h and not p.absent and p.global_position.distance_to(h.global_position) < near:
				near = p.global_position.distance_to(h.global_position)
	check(near > 0.35, "置き場所が、ほかの物と重なっていない（いちばん近い物まで %.2f m）" % near)
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	check(game.state == game.S.PREP, "現場で準備中")
	var P: Vector3 = me.global_position
	P.y = 0.0
	var Q := P + Vector3(2.0, 0.0, 0.0)
	# ---- A：着る ----
	var h1: RigidBody3D = hz.parts[0]
	var h2: RigidBody3D = hz.parts[1]
	h1.restore([P + Vector3(0.6, 0.1, 0), Quaternion.IDENTITY, false])
	h2.restore([P + Vector3(0.6, 0.1, 1.0), Quaternion.IDENTITY, false])
	await frames(20)
	check(hz.action(me, false).is_empty(), "手ぶらの F は、何もしない")
	game.h_grab.rpc_id(1, h1.pid)
	await frames(3)
	check(int(h1.holder) == int(me.peer_id), "ハーネスを持った")
	var act: Dictionary = hz.action(me, false)
	check(str(act.get("do", "")) == "wear" and int(act.get("who", 0)) == int(me.peer_id), "持って F：人を見ていなければ、自分が着る")
	hz.h_wear.rpc_id(1, h1.pid, int(me.peer_id))
	await frames(3)
	check(int(hz.worn.get(h1.pid, 0)) == int(me.peer_id) and h1.absent and int(h1.holder) == 0 and int(me.held) == 0, "着た：物は現場から消えて、手は空く")
	check(hz._looks.has(h1.pid) and is_instance_valid(hz._looks[h1.pid][0]), "体に、帯の見た目が付いた")
	check(hz.harness_of(int(me.peer_id)) == h1.pid, "着けている人から、ハーネスが分かる")
	game.h_grab.rpc_id(1, h2.pid)
	await frames(3)
	check(str(hz.action(me, false).get("do", "")) == "full", "もう着けている人には、2つ目は着せられない")
	hz.h_wear.rpc_id(1, h2.pid, int(me.peer_id))
	await frames(2)
	check(not hz.worn.has(h2.pid), "2つ目は、断られる")
	game.h_release.rpc_id(1)
	await frames(3)
	# ---- B：重りで吊る ----
	me.global_position = Q + Vector3(-0.6, 0.05, 0)
	me.velocity = Vector3.ZERO
	var pulley: RigidBody3D = rig.parts[0]
	rig.host_mount(pulley, Q + Vector3(0.15, 5.6, 0), Vector3(-1, 0, 0), null)
	await frames(30)
	var wheel: Vector3 = rig._wheel(pulley.pid)
	var ring: Vector3 = hz.attach_at(h1.pid)
	var size: Array = hz.fit(me.vis)
	check(float(size[0]) > 0.15 and float(size[0]) < 0.8 and float(size[3]) > 0.15 and float(size[3]) < 0.8, "帯は、キャラの胴の太さに合わせる（腰 %.2f x %.2f m・胸 %.2f x %.2f m）" % [size[0], size[1], size[2], size[3]])
	check(absf(ring.y - (me.global_position.y + float(size[4]))) < 0.05 and ring.y - P.y > 0.6 and ring.y - P.y < 1.5 and ring.distance_to(me.global_position + Vector3(0, float(size[4]), 0)) < 0.9, "ロープの端は、背中の輪（高さ %.2f m）" % (ring.y - P.y))
	var bag: RigidBody3D = game.stage.spawn("sandbag", Vector3(wheel.x + 0.7, P.y + 3.5, wheel.z), 0.0)
	bag.set_fixed(true)
	bag.mass = 3.0          # まず、軽い物（3kg）として
	await frames(2)
	var row1: int = rig.host_add_row([h1.pid, Vector3.ZERO], [bag.pid, bag.to_local(top_of(bag))], [pulley.pid])
	check(row1 != 0, "ハーネスから滑車を通して、重りへロープが張れた（%.1f m）" % float(rig.rows[row1]["len"]))
	bag.set_fixed(false)
	await frames(150)
	check(bag.global_position.y > P.y + 2.5, "軽い物は、人を重りにして、ぶら下がっている（高さ %.2f m）" % (bag.global_position.y - P.y))
	check(me.is_on_floor() and me.global_position.distance_to(Q + Vector3(-0.6, 0.05, 0)) < 0.15, "軽い物（3kg）では、人は浮かないし、横へも引きずられない（%s）" % str(me.global_position - Q))
	bag.mass = 9.0          # 9kg の物（冷蔵庫の張りぼてくらい）
	bag.sleeping = false
	await frames(150)
	check(me.global_position.y < P.y + 0.3, "9kg の重りでも、人は浮かない（高さ %.2f m。足は軽くなって、滑車の下へ寄る：%s）" % [me.global_position.y - P.y, str(me.global_position - Q)])
	bag.mass = 12.0         # サンドバッグの重さに戻す
	bag.sleeping = false
	var peak := 0.0
	var lift_f := -1
	for i in 420:
		await physics_frame
		peak = maxf(peak, me.global_position.y - P.y)
		if lift_f < 0 and me.global_position.y > P.y + 2.0:
			lift_f = i
	check(me.global_position.y > P.y + 2.5 and not me.is_on_floor(), "サンドバッグ（12kg）で、人が上がって、ぶら下がる（高さ %.2f m・いちばん高い所 %.2f m）" % [me.global_position.y - P.y, peak])
	check(lift_f > 90, "上がり方は、ゆっくり（2m 上がるまで %.1f 秒）" % (float(lift_f) / 60.0))
	check(float(me.down) <= 0.0, "吊り上げられただけでは、のびない")
	print("HARNESS_INFO me y %.2f peak %.2f bag %.2f" % [me.global_position.y - P.y, peak, bag.global_position.y - P.y])
	var hang_y: float = me.global_position.y
	await frames(60)
	check(absf(me.global_position.y - hang_y) < 0.25, "ぶら下がったまま、止まっている（%.2f m 動いた）" % absf(me.global_position.y - hang_y))
	rig.host_snap(row1, 0.5)
	var downed := false
	for i in 150:
		await physics_frame
		downed = downed or float(me.down) > 0.0
	check(me.is_on_floor() and me.global_position.y < P.y + 0.3, "ロープを切ると、落ちる")
	check(downed == (hang_y - P.y > 2.9), "高い所から落ちれば、のびる（吊られていた高さ %.2f m・のびた %s）" % [hang_y - P.y, str(downed)])
	await frames(330)
	# ---- C：雇った役者を、手で引いて吊る ----
	var a: CharacterBody3D = game.actors[0]
	a.set_state(a.St.IDLE)
	var R := P + Vector3(0, 0, 5.0)
	a.velocity = Vector3.ZERO
	a.global_position = R + Vector3(0, 0.05, 0)
	me.global_position = R + Vector3(2.5, 0.05, 0)
	me.velocity = Vector3.ZERO
	await frames(20)
	game.h_grab.rpc_id(1, h2.pid)
	await frames(3)
	hz.h_wear.rpc_id(1, h2.pid, -1)
	await frames(3)
	check(int(hz.worn.get(h2.pid, 0)) == -1 and h2.absent, "雇った役者に、ハーネスを着せた")
	game.bomb_kit.stock = float(game.bomb_kit.COIL_M)      # 束は1日 10m。切れた分は戻らないので、ここでは新しい束にする
	var pulley2: RigidBody3D = rig.parts[1]
	rig.host_mount(pulley2, R + Vector3(0.15, 4.2, 0), Vector3(-1, 0, 0), null)
	await frames(20)
	var box: RigidBody3D = null
	for p: Node in game.props.values():
		if str(p.kind) == "carton" and not p.absent and box == null:
			box = p
	box.restore([me.global_position + Vector3(0.9, 0.3, 0), Quaternion.IDENTITY, false])
	await frames(20)
	game.h_grab.rpc_id(1, box.pid)
	await frames(10)
	var row2: int = rig.host_add_row([h2.pid, Vector3.ZERO], [box.pid, Vector3.ZERO], [pulley2.pid])
	check(row2 != 0 and int(box.holder) == int(me.peer_id), "役者のハーネスから滑車を通して、手に持った箱へロープを張った")
	var a_y0: float = a.global_position.y
	for i in 120:
		me.global_position.x += 2.4 / 120.0
		await physics_frame
	await frames(30)
	check(a.global_position.y > a_y0 + 1.2 and not a.is_on_floor(), "箱を持って歩くと、役者が上がる（%.2f m）" % (a.global_position.y - a_y0))
	var hung: float = a.global_position.y
	await frames(60)
	check(absf(a.global_position.y - hung) < 0.15, "持っている間は、役者は吊られたまま")
	game.h_release.rpc_id(1)
	await frames(2)
	me.global_position += Vector3(0, 0, 2.5)        # 箱の通り道から、どく（人が立っていると、引かれる箱がつかえる）
	await frames(120)
	check(a.is_on_floor() and a.global_position.y < a_y0 + 0.3, "箱を離すと、役者が降りる（箱は軽い）（役者 %s・箱 %s）" % [str(a.global_position - R), str(box.global_position - R)])
	# ---- D：結ぶ・外す ----
	var coil: RigidBody3D = game.cargo_kit.rope
	coil.restore([me.global_position + Vector3(0.5, 0.1, 0.5), Quaternion.IDENTITY, false])
	await frames(3)
	game.h_grab.rpc_id(1, coil.pid)
	await frames(3)
	me.global_position = a.global_position + Vector3(1.2, 0, 0)
	await frames(3)
	var rows_before: int = rig.rows.size()
	rig.h_tie.rpc_id(1, h2.pid, hz.attach_at(h2.pid), false)
	check(rig.pending.has(int(me.peer_id)) and int(rig.pending[int(me.peer_id)]["a"][0]) == h2.pid, "束を持って、着けているハーネスにロープの端を結べる")
	rig.h_tie.rpc_id(1, 0, a.global_position + Vector3(0.5, 2.0, 0), false)
	check(rig.rows.size() == rows_before + 1, "もう一方を結んで、張れた")
	game.h_release.rpc_id(1)
	await frames(3)
	hz.h_strip.rpc_id(1, h2.pid)
	await frames(30)
	check(not hz.worn.has(h2.pid) and not h2.absent and h2.global_position.distance_to(a.global_position) < 2.5, "外すと、ハーネスは物に戻って、その人のそばに落ちる")
	check(not hz._looks.has(h2.pid), "体の帯の見た目が消えた")
	var tied := 0
	for row: Dictionary in rig.rows.values():
		if int(row["a"][0]) == h2.pid or int(row["b"][0]) == h2.pid:
			tied += 1
			check(rig._end_at(row["a"] if int(row["a"][0]) == h2.pid else row["b"]).distance_to(h2.global_position) < 0.6, "ロープの端は、外したハーネスに付いている")
	check(tied == 2, "外しても、ロープはハーネスに結んだまま（%d 本）" % tied)
	# ---- E：撮り直し・帰社 ----
	check(hz.worn.has(h1.pid), "自分は、まだ着けている")
	game.hooks.run("hook_take_ready")      # 準備中にテイクを始める直前（production_main.gd の _take_or_cut）
	game._begin_take()
	await frames(10)
	hz.h_strip.rpc_id(1, h1.pid)
	await frames(10)
	check(not hz.worn.has(h1.pid) and not h1.absent, "本番中に脱いだ")
	game._cut()
	await frames(5)
	game.h_retake()
	await frames(30)
	check(int(hz.worn.get(h1.pid, 0)) == int(me.peer_id) and h1.absent, "撮り直しで、着けた状態に戻る")
	hz.hook_return_office()
	await frames(5)
	check(hz.worn.is_empty() and not h1.absent and hz._looks.is_empty(), "帰社で、全員脱ぐ")
	print("HARNESS_TEST_FAIL" if failed else "HARNESS_TEST_OK")
	quit(1 if failed else 0)
