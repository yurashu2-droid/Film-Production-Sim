extends "res://tests/pair_net_base.gd"
# 仕掛けの部品（scripts/features/contraptions.gd）の二人通信：
#   参加者が、束を持ってロープを張る・火を付ける・滑車を留める・ボタンとトーチをケーブルでつなぐ・ボタンを押す・時計を巻く。
#   決めるのはホスト。「どこからどこへ・長さ・燃えている所・切れたか・留めた滑車・ケーブル・炎・時計」が両方の画面で一致する /
#   束を持っていない人・離れた人の操作は断られる / 途中参加でも、張ったロープ・留めた滑車・ケーブルが届く。
# 会社での準備中（phase 2）のまま確かめる。
#   godot --headless --path godot res://tests/contraptions_net_test.tscn -- --rig-net-test-host      （参加者は -client）

const SPOT := Vector3(-7.5, 0.0, -1.5)   # 軽トラ HOME から見た、仕掛けを組む場所


func configure() -> void:
	prefix = "RIG_NET"
	port = 24881
	flag = "rig-net-test"
	budget = 90.0


func after_game() -> void:
	game.production.set_physics_process(false)


func rig() -> Node:
	return game.hooks.feature("contraptions")


func part(kind: String) -> RigidBody3D:
	for p: RigidBody3D in rig().parts:
		if p.kind == kind:
			return p
	return null


func at() -> Vector3:
	return game.production.HOME_TRUCK + SPOT


# 画面に見える様子。ロープは「番号・端の物・滑車・長さ（5cm刻み）・燃えているか・切れたか」
func view() -> Dictionary:
	var r: Node = rig()
	var rows := {}
	for id: int in r.rows:
		var row: Dictionary = r.rows[id]
		rows[id] = [int(row["a"][0]), int(row["b"][0]), (row["via"] as Array).duplicate(), snappedf(float(row["len"]), 0.05), float(row["fire"]) >= 0.0, bool(row["cut"])]
	var mounts: Array = r.mounts.keys()
	mounts.sort()
	var pulley := part("pulley")
	var fans: Array = r.fans.keys()
	fans.sort()
	var nf: Node = game.hooks.feature("night_filter")
	var night: Array = nf.night.keys() if nf != null else []
	night.sort()
	var bd: Node = game.hooks.feature("backdrop")
	var backdrop: Array = []
	if bd != null:
		for pid: int in bd.backdrop:
			backdrop.append("%d:%s" % [pid, bd.backdrop[pid]])
		backdrop.sort()
	return {"rows": rows, "pending": r.pending.size(), "mounts": mounts, "pulley_fixed": pulley.fixed if pulley != null else false,
		"wires": r.wires.duplicate(true), "stock": snappedf(float(game.bomb_kit.stock), 0.05), "fans": fans, "night": night, "backdrop": backdrop}


func host_action(action: String, _arg: Variant, who: int) -> Dictionary:
	var base := at()
	match action:
		"stage":
			# 束と部品を、空き地に並べる。参加者はそのそばに立つ
			loose(game.cargo_kit.rope, base + Vector3(0.6, 0.06, 0.4))
			loose(part("igniter"), base + Vector3(1.4, 0.06, -0.6))
			loose(part("buzzer"), base + Vector3(-0.6, 0.06, -0.6))
			loose(part("pulley"), base + Vector3(0.0, 0.06, 0.9))
			loose(part("timer"), base + Vector3(-1.2, 0.06, 0.6))
			crew_to(who, base + Vector3(0.2, 0.1, 0.0))
			crew_to(1, base + Vector3(-4.0, 0.1, 4.0))
		"far":
			crew_to(who, base + Vector3(-16.0, 0.1, 0.0))
		"near":
			crew_to(who, base + Vector3(0.2, 0.1, 0.0))
		"fan_here":
			# 廃材置き場の送風機と、夜用フィルターと、撮影カメラを、参加者のそばへ
			for p: Node in game.props.values():
				if p.kind == "scrap_fan" and not p.absent:
					loose(p, base + Vector3(1.2, 0.06, 1.2))
					break
			loose(game.hooks.feature("night_filter").gel, base + Vector3(-0.8, 0.06, 0.8))
			loose(game.hooks.feature("backdrop").cans[1], base + Vector3(-0.4, 0.06, -0.9))
			loose(game.film, base + Vector3(0.8, 0.06, -1.4))
			crew_to(who, base + Vector3(0.2, 0.1, 0.0))
		"burn":
			# 火を付けたロープが、焼き切れるまで待つ
			var r: Node = rig()
			await until(func() -> bool: return r.rows.values().any(func(row: Dictionary) -> bool: return bool(row["cut"])), 8.0)
	await frames(3)
	return {}


func loose(prop: Node, pos: Vector3) -> void:
	place(prop, pos)
	prop.set_fixed(false)


func client_run() -> void:
	var flow: Node = game.production
	var reply: Dictionary = await request("hello")
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	reply = await request("stage")
	var r: Node = rig()
	var coil: RigidBody3D = game.cargo_kit.rope
	var torch := part("igniter")
	var bell := part("buzzer")
	var pulley := part("pulley")
	var clock := part("timer")
	check(r != null and torch != null and bell != null and pulley != null and clock != null, "the contraption parts exist on the participant with the same ids")
	var anchor: Vector3 = at() + Vector3(1.4, 2.0, -0.6)

	# ---- 束を持っていないと、結べない ----
	r.h_tie.rpc_id(1, 0, anchor, false)
	reply = await request("snapshot")
	check(reply["view"]["pending"] == 0 and reply["view"]["rows"].is_empty(), "without the coil in hand, nothing gets tied")

	# ---- 張る：塀の代わりの空中の点と、トーチの頭 ----
	game.h_grab.rpc_id(1, coil.pid)
	check(await until(func() -> bool: return game.local_player().held == coil.pid), "the participant picks up the coil")
	reply = await request("far")
	r.h_tie.rpc_id(1, 0, anchor, false)
	reply = await request("snapshot")
	check(reply["view"]["pending"] == 0, "a rope cannot be tied from far away")
	reply = await request("near")
	r.h_tie.rpc_id(1, 0, anchor, false)
	reply = await request("snapshot")
	check(reply["view"]["pending"] == 1, "the participant ties the first end on the host")
	check(await until(func() -> bool: return r.pending.size() == 1), "and sees the rope hanging from the knot to the coil")
	var top: Vector3 = torch.global_transform * Vector3(0, 0.6, 0)
	r.h_tie.rpc_id(1, torch.pid, top, false)
	reply = await request("snapshot")
	var tied: Dictionary = reply["view"]
	check(tied["rows"].size() == 1 and tied["pending"] == 0 and tied["stock"] < 10.0, "the second end makes a taut rope on the host (%s)" % str(tied["rows"]))
	await sees(tied, ["rows", "pending", "stock"], "the participant sees the same rope, length and coil stock")
	var id: int = tied["rows"].keys()[0]

	# ---- 火を付ける：両方の画面で燃えて、焼き切れる ----
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the coil down")
	r.h_fire.rpc_id(1, id, float(r.rows[id]["len"]) * 0.5)
	check(await until(func() -> bool: return r.rows.has(id) and float(r.rows[id]["fire"]) >= 0.0), "the fire shows on the participant's rope")
	reply = await request("burn")
	check(bool(reply["view"]["rows"][id][5]), "the rope burns through on the host")
	await sees(reply["view"], ["rows"], "and snaps on the participant's screen too")

	# ---- 滑車を留める ----
	game.h_grab.rpc_id(1, pulley.pid)
	check(await until(func() -> bool: return game.local_player().held == pulley.pid), "the participant picks up a pulley")
	r.h_mount.rpc_id(1, pulley.pid, at() + Vector3(0.4, 2.2, 1.6), Vector3(0, 0, -1), 0)
	reply = await request("snapshot")
	check(reply["view"]["mounts"] == [pulley.pid] and reply["view"]["pulley_fixed"], "the pulley is clamped on the host")
	await sees(reply["view"], ["mounts", "pulley_fixed"], "and on the participant")
	check(await until(func() -> bool: return game.local_player().held == 0), "clamping takes it out of the participant's hands")

	# ---- ボタン → トーチ：ケーブルでつなぎ、押すと炎 ----
	game.h_grab.rpc_id(1, bell.pid)
	check(await until(func() -> bool: return game.local_player().held == bell.pid), "the participant picks up the bell")
	r.h_wire.rpc_id(1, bell.pid, torch.pid)
	reply = await request("snapshot")
	check((reply["view"]["wires"].get(bell.pid, []) as Array).has(torch.pid), "the cable is plugged in on the host")
	await sees(reply["view"], ["wires"], "and on the participant")
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the bell down")
	reply = await request("near")
	r.h_press.rpc_id(1, bell.pid)
	check(await until(func() -> bool: return r.flames.has(torch.pid)), "pressing the bell lights the torch on the participant's screen")

	# ---- 目覚まし時計：巻くと、両方の画面で針が回る ----
	r.h_wind.rpc_id(1, clock.pid)
	check(await until(func() -> bool: return r.timers.has(clock.pid)), "winding the clock shows on the participant")

	# ---- 送風機：参加者が手ぶらで回す。両方の画面で回る ----
	reply = await request("fan_here")
	var fan: Node = null
	for p: Node in game.props.values():
		if p.kind == "scrap_fan" and not p.absent:
			fan = p
			break
	check(fan != null, "the scrap-yard fan is out on the participant")
	r.h_fan.rpc_id(1, fan.pid)
	reply = await request("snapshot")
	check(reply["view"]["fans"] == [fan.pid], "the participant switches the fan on at the host")
	await sees(reply["view"], ["fans"], "and the fan runs on the participant's screen")
	# ---- 夜用フィルター：参加者が撮影カメラに付ける。両方の画面で、そのカメラが夜になる ----
	var nf: Node = game.hooks.feature("night_filter")
	game.h_grab.rpc_id(1, nf.gel.pid)
	check(await until(func() -> bool: return game.local_player().held == nf.gel.pid), "the participant picks up the night gel")
	nf.h_toggle.rpc_id(1, game.film.pid)
	reply = await request("snapshot")
	check(reply["view"]["night"] == [game.film.pid], "the participant clips the gel onto the film camera at the host")
	await sees(reply["view"], ["night"], "and the participant sees the same")
	check(await until(func() -> bool: return game.film.view_cam.environment != null), "the participant's copy of that camera now films at night")
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the gel down")
	# ---- 背景フィルム：参加者が宇宙の缶を撮影カメラに入れる。両方の画面で、そのカメラに合成の板が付く ----
	var bd: Node = game.hooks.feature("backdrop")
	var space: Node = bd.cans[1]
	game.h_grab.rpc_id(1, space.pid)
	check(await until(func() -> bool: return game.local_player().held == space.pid), "the participant picks up the space backdrop can")
	bd.h_set.rpc_id(1, game.film.pid, "space")
	reply = await request("snapshot")
	check(reply["view"]["backdrop"] == ["%d:space" % game.film.pid], "the participant loads the space backdrop into the film camera at the host")
	await sees(reply["view"], ["backdrop"], "and the participant sees the same")
	check(await until(func() -> bool: return game.film.view_cam.get_node_or_null("BackdropKey") != null), "the participant's copy of that camera now keys out green")
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the can down")
	# ---- 途中参加：焼き切れたロープ・留めた滑車・ケーブル・回っている送風機・夜用フィルターが届く ----
	reply = await request("snapshot")
	var expected: Dictionary = reply["view"]
	await rejoin()
	reply = await request("hello")
	await sees(expected, ["rows", "mounts", "pulley_fixed", "wires", "fans", "night", "backdrop"], "a late joiner receives the rope, the clamped pulley, the cable, the running fan, the night gel and the backdrop", LATE)
