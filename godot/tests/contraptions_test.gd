extends SceneTree
# 仕掛けの部品（scripts/features/contraptions.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/contraptions_test.gd
# A：束を持って、壁（空中の点）と重りを結ぶと、重りがぶら下がる。火を付けると、少しして焼き切れて落ちる。
# B：台車 → 滑車 → 重り。重りを支えるロープを焼き切ると、重りが落ちて、台車が滑車のほうへ引かれる（自動の移動撮影）。
# C：重りがボタンに落ちる → ケーブルでつないだトーチから炎 → 炎のそばのロープに火が移って焼き切れる。
# D：撮り直しで、焼き切れたロープが元に戻る。帰社すると、ロープはほどけて束へ戻る（焼けた分は戻らない）。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("RIG_CHECK ", label, " ", "OK" if ok else "FAIL")
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
	check(rig != null, "仕掛けの仕組みが登録されている")
	if rig == null:
		quit(1)
		return
	var kinds := {}
	for p: RigidBody3D in rig.parts:
		kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
	check(kinds == {"pulley": 2, "buzzer": 2, "igniter": 2}, "会社の備品：滑車2・押しボタン2・点火トーチ2（%s）" % str(kinds))
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	check(game.state == game.S.PREP, "現場で準備中")
	var bk: Node = game.bomb_kit
	var full: float = bk.stock
	var P: Vector3 = me.global_position
	P.y = 0.0
	# ---- A：ぶら下げて、焼き切る ----
	var coil: RigidBody3D = game.cargo_kit.rope
	coil.restore([P + Vector3(0.5, 0.1, 0), Quaternion.IDENTITY, false])
	await frames(3)
	game.h_grab.rpc_id(1, coil.pid)
	await frames(3)
	check(coil.holder == me.peer_id, "ロープの束を持った")
	var bag: RigidBody3D = game.stage.spawn("sandbag", P + Vector3(1.5, 1.0, 0.0), 0.0)
	await frames(1)
	var anchor := top_of(bag) + Vector3(0, 0.6, 0)
	rig.h_tie.rpc_id(1, 0, anchor, false)
	rig.h_tie.rpc_id(1, bag.pid, top_of(bag), false)
	check(rig.rows.size() == 1 and rig.pending.is_empty(), "壁と重りを結んで、ロープが1本張れた")
	var a_id: int = rig.rows.keys()[0]
	check(absf(bk.stock - (full - float(rig.rows[a_id]["len"]))) < 0.01, "張った分だけ、束が減る")
	await frames(90)
	check(bag.global_position.y > P.y + 0.6, "重りが、ロープでぶら下がっている（高さ %.2f m）" % (bag.global_position.y - P.y))
	rig.h_fire.rpc_id(1, a_id, float(rig.rows[a_id]["len"]) * 0.5)
	await frames(10)
	check(float(rig.rows[a_id]["fire"]) >= 0.0 and not bool(rig.rows[a_id]["cut"]), "火が付いた（まだ切れない）")
	await frames(int(rig.BURN_SEC * 60.0) + 60)
	check(bool(rig.rows[a_id]["cut"]), "少しして、焼き切れた")
	check(bag.global_position.y < P.y + 0.3, "重りが床へ落ちた（高さ %.2f m）" % (bag.global_position.y - P.y))
	# ---- B：台車 → 滑車 → 重り ----
	var lane := P + Vector3(0, 0, 3.5)
	var dolly: RigidBody3D = game.stage.spawn("dolly", lane + Vector3(1.0, 0.05, 0), PI * 0.5)
	var pulley: RigidBody3D = rig.parts[0]
	rig.host_mount(pulley, lane + Vector3(5.0, 2.8, 0), Vector3(-1, 0, 0), null)
	await frames(40)
	check(rig.mounts.has(pulley.pid) and pulley.fixed, "滑車を、壁（空中の点）に留めた")
	var wheel: Vector3 = rig._wheel(pulley.pid)
	var bag2: RigidBody3D = game.stage.spawn("sandbag", Vector3(wheel.x, P.y + 1.2, wheel.z), 0.0)
	await frames(1)
	# 支えのロープは、滑車からのロープと離して張る（重なっていると、火が移って両方とも焼き切れる）
	var hold_id: int = rig.host_add_row([0, top_of(bag2) + Vector3(0, 0.6, 0.5)], [bag2.pid, bag2.to_local(top_of(bag2) + Vector3(0, 0, 0.12))], [])
	var front: Vector3 = dolly.center_global()
	front.x = dolly.global_position.x + 0.3
	var pull_id: int = rig.host_add_row([dolly.pid, dolly.to_local(front)], [bag2.pid, bag2.to_local(top_of(bag2))], [pulley.pid])
	check(hold_id != 0 and pull_id != 0, "支えのロープと、台車から滑車を通して重りへ掛けたロープが張れた")
	await frames(90)
	print("RIG_INFO pull row alive %s, dolly absent %s freeze %s fixed %s pos %s, bag2 y %.2f, over %.3f" % [rig.rows.has(pull_id), dolly.absent, dolly.freeze, dolly.fixed, dolly.global_position, bag2.global_position.y, rig._length(rig._path(rig.rows[pull_id])) - float(rig.rows[pull_id]["len"]) if rig.rows.has(pull_id) else -1.0])
	var x0: float = dolly.global_position.x
	check(bag2.global_position.y > P.y + 0.6, "重りは、支えのロープでぶら下がっている")
	rig.host_ignite(hold_id, 0.1)
	await frames(int(rig.BURN_SEC * 60.0) + 150)
	check(bool(rig.rows[hold_id]["cut"]), "支えのロープが焼き切れた")
	var moved: float = dolly.global_position.x - x0
	check(moved > 0.6, "重りが落ちて、台車が滑車のほうへ引かれた（%.2f m）" % moved)
	print("RIG_INFO dolly moved %.2f m, bag2 y %.2f" % [moved, bag2.global_position.y - P.y])
	# ---- C：ボタン → トーチ → ロープ ----
	game.h_release.rpc_id(1)
	await frames(3)
	var bell: RigidBody3D = null
	var torch: RigidBody3D = null
	for p: RigidBody3D in rig.parts:
		if p.kind == "buzzer" and bell == null:
			bell = p
		if p.kind == "igniter" and torch == null:
			torch = p
	var spot := P + Vector3(0, 0, -3.0)
	bell.restore([spot + Vector3(0, 0.05, 0), Quaternion.IDENTITY, false])
	torch.restore([spot + Vector3(1.6, 0.05, 0), Quaternion.IDENTITY, false])
	await frames(30)
	game.h_grab.rpc_id(1, bell.pid)
	await frames(2)
	rig.h_wire.rpc_id(1, bell.pid, torch.pid)
	check((rig.wires.get(bell.pid, []) as Array).has(torch.pid), "ボタンとトーチを、ケーブルでつないだ")
	game.h_release.rpc_id(1)
	await frames(2)
	bell.restore([spot + Vector3(0, 0.05, 0), Quaternion.IDENTITY, false])
	await frames(30)
	var head: Vector3 = torch.global_transform * rig.TORCH_HEAD
	var line_id: int = rig.host_add_row([0, head + Vector3(-0.9, 0.15, 0)], [0, head + Vector3(0.9, 0.15, 0)], [])
	var before: Dictionary = rig.snapshot()
	var stock_before: float = bk.stock
	await frames(10)
	check(not rig.flames.has(torch.pid), "ボタンが押されるまで、炎は出ない")
	var bag3: RigidBody3D = game.stage.spawn("sandbag", spot + Vector3(0, 1.2, 0), 0.0)
	var flamed := false
	for i in 90:
		await physics_frame
		flamed = flamed or rig.flames.has(torch.pid)
	check(flamed, "重りがボタンに落ちて、トーチから炎が出た")
	await frames(int(rig.BURN_SEC * 60.0) + 40)
	check(bool(rig.rows[line_id]["cut"]), "炎のそばのロープに火が移って、焼き切れた")
	check(bag3 != null, "（重り）")
	# ---- D：撮り直し・帰社 ----
	rig._restore(before)
	await frames(2)
	check(not bool(rig.rows[line_id]["cut"]) and float(rig.rows[line_id]["fire"]) < 0.0, "撮り直しで、焼き切れたロープが元に戻る")
	check(absf(bk.stock - stock_before) < 0.01, "撮り直しで、束の長さも元のまま")
	var burned := 0.0
	for id: int in rig.rows:
		if bool(rig.rows[id]["cut"]):
			burned += float(rig.rows[id]["len"])
	rig.hook_return_office()
	await frames(2)
	check(rig.rows.is_empty() and rig.mounts.is_empty() and rig.wires.is_empty() and not pulley.fixed, "帰社：ロープはほどけ、滑車は外れ、ケーブルは抜ける")
	check(absf(bk.stock - (full - burned)) < 0.02, "帰社：ほどいたロープは束へ戻る（焼けた %.2f m は戻らない）" % burned)
	var hud: Dictionary = rig.hook_hud(me, "", "")
	check(hud is Dictionary, "画面の案内が出せる")
	print("RIG_TEST_FAIL" if failed else "RIG_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
