extends SceneTree
# 仕掛けの部品を、遊ぶときと同じ操作で使う（照準を合わせて F。F は production_main.gd と同じ順で、仕組みへ回す）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/contraptions_play_test.gd
# 束を持って壁を見て F → 重りを見て F で張る / 手ぶらでロープを見て F で火 / 滑車を持って壁を見て F で留める /
# ボタンを持ってトーチを見て F でつなぐ / 手ぶらでボタンを見て F で押す → 炎。画面の案内も、その操作を出す。
var game: Node
var rig: Node
var me: Node3D
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("RIGPLAY_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# その点を、画面の真ん中で見る
func look_at_point(at: Vector3) -> void:
	for i in 8:
		var from: Vector3 = me.cam.global_position
		var d := (at - from).normalized()
		me.aim_yaw = atan2(-d.x, -d.z)
		me.aim_pitch = asin(clampf(d.y, -1.0, 1.0))
		await frames(2)


func press_f() -> bool:
	return game.hooks.first("hook_f", [me])


func hud_keys() -> String:
	return str(rig.hook_hud(me, "", "").get("keys_all", ""))


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	rig = game.hooks.feature("contraptions")
	me = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	# 会社の前の東の塀（x＝92.3）の前に立つ
	var wall_x := 92.27
	var stand := Vector3(wall_x - 2.2, 0.1, 18.0)
	me.global_position = stand
	await frames(5)
	# ---- 結ぶ ----
	var coil: RigidBody3D = game.cargo_kit.rope
	coil.restore([stand + Vector3(0.4, 0.1, 0.4), Quaternion.IDENTITY, false])
	await frames(3)
	game.h_grab.rpc_id(1, coil.pid)
	await frames(3)
	var wall_pt := Vector3(wall_x, 2.0, 18.0)
	await look_at_point(wall_pt)
	var act: Dictionary = rig.f_action(me)
	check(str(act.get("do", "")) == "tie" and int(act.get("pid", -1)) == 0, "束を持って塀を見ると、結べる（%s）" % str(act.get("do", "")))
	check(hud_keys().contains("結ぶ"), "画面の案内：%s" % hud_keys())
	check(press_f() and rig.pending.has(int(me.peer_id)), "F で、ロープの端を塀に結んだ")
	var bag: RigidBody3D = game.stage.spawn("sandbag", Vector3(wall_x - 0.9, 0.05, 19.0), 0.0)
	await frames(30)
	await look_at_point(bag.center_global())
	check(str(rig.f_action(me).get("do", "")) == "tie" and int(rig.f_action(me).get("pid", 0)) == bag.pid, "重りを見ると、もう一方を結べる")
	check(hud_keys().contains("もう一方"), "画面の案内：%s" % hud_keys())
	press_f()
	await frames(2)
	check(rig.rows.size() == 1 and rig.pending.is_empty(), "F で、塀と重りの間にロープが張れた")
	# 床を見ているときは、F を横取りしない（荷台に積む などへ回す）
	await look_at_point(stand + Vector3(1.0, 0.0, -1.5))
	check(rig.f_action(me).is_empty(), "束を持って床を見ているときは、仕掛けの F にならない")
	# ---- 火を付ける（手ぶら） ----
	game.h_release.rpc_id(1)
	await frames(3)
	coil.restore([stand + Vector3(-1.5, 0.1, 1.5), Quaternion.IDENTITY, false])
	await frames(3)
	var id: int = rig.rows.keys()[0]
	var mid: Vector3 = rig._point_at(rig._path(rig.rows[id]), float(rig.rows[id]["len"]) * 0.5)
	await look_at_point(mid)
	check(str(rig.f_action(me).get("do", "")) == "fire", "手ぶらでロープを見ると、火を付けられる（%s）" % str(rig.f_action(me)))
	check(hud_keys().contains("火を付ける"), "画面の案内：%s" % hud_keys())
	press_f()
	await frames(2)
	check(float(rig.rows[id]["fire"]) >= 0.0, "F で、ロープに火が付いた")
	# ---- 滑車を塀に留める ----
	var pulley: RigidBody3D = null
	var bell: RigidBody3D = null
	var torch: RigidBody3D = null
	for p: RigidBody3D in rig.parts:
		if p.kind == "pulley" and pulley == null:
			pulley = p
		if p.kind == "buzzer" and bell == null:
			bell = p
		if p.kind == "igniter" and torch == null:
			torch = p
	pulley.restore([stand + Vector3(0.5, 0.1, -0.6), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab.rpc_id(1, pulley.pid)
	await frames(5)
	await look_at_point(Vector3(wall_x, 2.2, 18.8))
	check(str(rig.f_action(me).get("do", "")) == "mount", "滑車を持って塀を見ると、留められる")
	press_f()
	await frames(5)
	check(rig.mounts.has(pulley.pid) and pulley.fixed and pulley.holder == 0, "F で、滑車が塀に留まった（手から離れる）")
	# ---- ボタンとトーチを、ケーブルでつなぐ ----
	torch.restore([stand + Vector3(1.0, 0.05, 1.4), Quaternion.IDENTITY, false])
	bell.restore([stand + Vector3(-0.3, 0.05, 0.8), Quaternion.IDENTITY, false])
	await frames(20)
	game.h_grab.rpc_id(1, bell.pid)
	await frames(5)
	await look_at_point(torch.center_global())
	check(str(rig.f_action(me).get("do", "")) == "wire", "ボタンを持ってトーチを見ると、ケーブルでつなげる")
	check(hud_keys().contains("ケーブル"), "画面の案内：%s" % hud_keys())
	press_f()
	await frames(2)
	check((rig.wires.get(bell.pid, []) as Array).has(torch.pid), "F で、ケーブルがつながった")
	game.h_release.rpc_id(1)
	await frames(30)
	# ---- 手ぶらでボタンを押す → 炎 ----
	await look_at_point(bell.center_global())
	check(str(rig.f_action(me).get("do", "")) == "press", "手ぶらでボタンを見ると、押せる（%s）" % str(rig.f_action(me).get("do", "")))
	press_f()
	await frames(3)
	check(rig.flames.has(torch.pid), "F でボタンを押すと、つないだトーチから炎が出る")
	print("RIGPLAY_TEST_FAIL" if failed else "RIGPLAY_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
