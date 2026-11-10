extends "res://tests/pair_net_base.gd"
# ハーネス（scripts/features/harness.gd）の二人通信：
#   参加者が、ハーネスを持って自分で着る。着けている人・物が現場から消えたこと・体の帯が、両方の画面で一致する /
#   ホストが、参加者のハーネス → 滑車 → 重り、とロープを張る。参加者の体は、参加者の画面で引かれて上がる
#   （自分の体は自分の画面で動かしているので、引く力も自分の画面で出す）。ホストの画面でも、参加者は高い所にいて、重りは下がっている /
#   ぶら下がったまま、大きく揺れない / ホストが切ると、参加者が落ちる / 参加者が脱ぐと、両方の画面で物に戻る。
# 会社での準備中（phase 2）のまま確かめる。
#   godot --headless --path godot res://tests/harness_net_test.tscn -- --harness-net-test-host      （参加者は -client）

const SPOT := Vector3(-7.5, 0.0, -1.5)   # 軽トラ HOME から見た、吊る場所
const HEAVY := 14.0                      # 重りにする段ボール箱の重さ（両方の画面で、同じ重さにする）


func configure() -> void:
	prefix = "HARNESS_NET"
	port = 24893
	flag = "harness-net-test"
	budget = 90.0


func after_game() -> void:
	game.production.set_physics_process(false)


func hz() -> Node:
	return game.hooks.feature("harness")


func rig() -> Node:
	return game.hooks.feature("contraptions")


func at() -> Vector3:
	return game.production.HOME_TRUCK + SPOT


func weight() -> RigidBody3D:
	return first("carton")


func view() -> Dictionary:
	var worn: Array = []
	for pid: int in hz().worn:
		worn.append("%d:%d" % [pid, int(hz().worn[pid])])
	worn.sort()
	var gone: Array = []
	for p: RigidBody3D in hz().parts:
		gone.append(bool(p.absent))
	var cut := 0
	for row: Dictionary in rig().rows.values():
		cut += 1 if bool(row["cut"]) else 0
	return {"worn": worn, "gone": gone, "rows": rig().rows.size(), "cut": cut}


func host_action(action: String, _arg: Variant, who: int) -> Dictionary:
	var base := at()
	var out := {}
	match action:
		"stage":
			var h: RigidBody3D = hz().parts[0]
			place(h, base + Vector3(0.7, 0.1, 0.4))
			h.set_fixed(false)
			crew_to(who, base + Vector3(0.2, 0.1, 0.0))
			crew_to(1, base + Vector3(-5.0, 0.1, 4.0))
		"rig":
			# 参加者の上に滑車。反対側に、重りの箱（まず止めておいて、張ってから離す）
			var pl: Node3D = game.players[who]
			var pulley: RigidBody3D = rig().parts[0]
			rig().host_mount(pulley, pl.global_position + Vector3(0.8, 5.6, 0), Vector3(-1, 0, 0), null)
			await frames(10)
			var wheel: Vector3 = rig()._wheel(pulley.pid)
			var box := weight()
			box.empty_mass = HEAVY          # 箱の重さは「空の重さ＋中身」で決め直される（cargo_boxes.gd）ので、空の重さを変える
			box.mass = HEAVY
			place(box, Vector3(wheel.x + 0.8, base.y + 3.6, wheel.z))
			await frames(5)
			var id: int = rig().host_add_row([hz().harness_of(who), Vector3.ZERO], [box.pid, Vector3(0, float(box.half.y), 0)], [pulley.pid])
			out["row"] = id
			box.set_fixed(false)
		"where":
			var pl: Node3D = game.players[who]
			out["crew_y"] = pl.global_position.y - base.y
			out["box_y"] = weight().global_position.y - base.y
			out["box_mass"] = weight().mass
		"cut":
			for id: int in rig().rows.keys():
				rig().host_snap(id, 1.0)
	await frames(3)
	return out


func client_run() -> void:
	var flow: Node = game.production
	var reply: Dictionary = await request("hello")
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	reply = await request("stage")
	var me: Node3D = game.local_player()
	var mine: int = int(me.peer_id)
	var h: RigidBody3D = hz().parts[0]
	var base := at()
	check(h != null and str(h.kind) == "harness", "the harness exists on the participant")
	check(await until(func() -> bool: return me.global_position.distance_to(base + Vector3(0.2, 0.1, 0)) < 1.0), "the participant stands by the harness")

	# ---- 着る ----
	hz().h_wear.rpc_id(1, h.pid, mine)
	reply = await request("snapshot")
	check((reply["view"]["worn"] as Array).is_empty(), "without the harness in hand, nobody gets dressed")
	game.h_grab.rpc_id(1, h.pid)
	check(await until(func() -> bool: return me.held == h.pid), "the participant picks up the harness")
	hz().h_wear.rpc_id(1, h.pid, mine)
	reply = await request("snapshot")
	check(reply["view"]["worn"] == ["%d:%d" % [h.pid, mine]], "the host records the participant as wearing it")
	await sees(reply["view"], ["worn", "gone"], "both peers agree: who wears it, and the prop is gone from the set")
	check(await until(func() -> bool: return hz()._looks.has(h.pid) and me.held == 0), "the straps show on the participant's own body, and the hands are free")

	# ---- 吊る ----
	weight().empty_mass = HEAVY
	weight().mass = HEAVY
	var floor_y: float = me.global_position.y - base.y
	reply = await request("rig")
	check(int(reply.get("row", 0)) != 0, "the host ties harness -> pulley -> weight")
	await sees(reply["view"], ["rows"], "the rope reaches the participant")
	var lifted: bool = await until(func() -> bool: return me.global_position.y > base.y + floor_y + 1.5, 15.0)
	check(lifted, "the participant's own body is lifted on the participant's screen (y %.2f)" % (me.global_position.y - base.y))
	# 上がりきって落ち着くまで待つ（0.5秒で 5cm も動かなくなるまで）
	var last := -INF
	for i in 20:
		last = me.global_position.y
		await wait(0.5)
		if absf(me.global_position.y - last) < 0.05:
			break
	var low := INF
	var high := -INF
	for i in 60:
		await get_tree().physics_frame
		low = minf(low, me.global_position.y - base.y)
		high = maxf(high, me.global_position.y - base.y)
	check(low > floor_y + 1.2 and high - low < 0.25, "the participant keeps hanging without bouncing (y %.2f .. %.2f)" % [low, high])
	reply = await request("where")
	check(float(reply["crew_y"]) > floor_y + 1.0 and float(reply["box_y"]) < 2.4, "on the host too: the participant is up (y %.2f) and the weight has come down (y %.2f)" % [float(reply["crew_y"]), float(reply["box_y"])])
	print(prefix, "_INFO floor ", snappedf(floor_y, 0.01), " hang y ", snappedf(low, 0.01), " .. ", snappedf(high, 0.01), " host sees crew ", snappedf(float(reply["crew_y"]), 0.01), " box ", snappedf(float(reply["box_y"]), 0.01), " box mass host ", reply["box_mass"], " mine ", weight().mass)

	# ---- 切る ----
	reply = await request("cut")
	check(int(reply["view"]["cut"]) >= 1, "the host cuts the rope")
	check(await until(func() -> bool: return me.is_on_floor() and me.global_position.y < base.y + floor_y + 0.2, 6.0), "the participant falls back to the floor")

	# ---- 脱ぐ ----
	hz().h_strip.rpc_id(1, h.pid)
	reply = await request("snapshot")
	check((reply["view"]["worn"] as Array).is_empty(), "the participant takes it off on the host")
	await sees(reply["view"], ["worn", "gone"], "both peers agree: nobody wears it, and the prop is back")
	check(await until(func() -> bool: return not hz()._looks.has(h.pid)), "the straps are gone from the body")
