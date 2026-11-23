extends "res://tests/pair_net_base.gd"
# ロープを手でつかむ（rope_grab.gd）の二人通信：
#   参加者が、床の切れ端の端をつかんで歩く。決めるのはホスト。
#   「だれが・どのロープの・どこをつかんでいるか」が両方の画面で一致し、ロープの形もおおむね同じ
#   （つかんだ点の場所が一致・端の場所の差が小さい。節の位置は各自の画面で計算する）/
#   遠くからはつかめない / ホストの制作班がはさみで切ると、参加者は切れた先をそのままつかんでいる /
#   離すと、両方の画面で落ちて止まる / あとから入った人にも、だれがどこをつかんでいるかが届く /
#   参加者が、切れ端を爆弾の口金につなぐ・軽トラのフックに結ぶ。
# 会社での準備中（phase 2）のまま確かめる。
#   godot --headless --path godot res://tests/rope_grab_net_test.tscn -- --rope-grab-net-test-host      （参加者は -client）

const SPOT := Vector3(-7.5, 0.0, -1.5)   # 爆弾を置く場所（軽トラ HOME から見た位置）


func configure() -> void:
	prefix = "ROPE_GRAB_NET"
	port = 24873
	flag = "rope-grab-net-test"
	budget = 80.0


func after_game() -> void:
	game.production.set_physics_process(false)


func view() -> Dictionary:
	var kit: Node = game.bomb_kit
	var ck: Node = game.cargo_kit
	var grab: Node = game.rope_grab
	var grabs := {}
	var hands := {}
	for who: int in grab.grabs:
		var g: Dictionary = grab.grabs[who]
		grabs[who] = [int(g["kind"]), int(g["id"]), snappedf(float(g["s"]), 0.05)]
		hands[who] = g["at"]
	var links := {}
	var lengths := {}
	var shape := {}
	for id: int in kit.cords:
		var cord: Node = kit.cords[id]
		links[id] = [cord.a_body.pid if cord.a_body != null else 0, cord.b_body.pid if cord.b_body != null else 0, cord.burning]
		lengths[id] = snappedf(cord.length, 0.05)
		shape[id] = [cord.root(), cord.tip(), cord.speed()]
	var lashes := {}
	for id: int in ck.lashes:
		var lash: Dictionary = ck.lashes[id]
		lashes[id] = [int(lash["a"]), int(lash["b"]), int(lash.get("coil", 0)), snappedf(float(lash["cord"].length), 0.05)]
	return {"grabs": grabs, "hands": hands, "links": links, "lengths": lengths, "shape": shape, "lashes": lashes,
		"absent": game.fx.absent, "phase": game.production.phase}


func floor_at(pos: Vector3) -> float:
	var none: Array[RID] = []
	return game.bomb_kit._floor_under(pos + Vector3(0, 1.0, 0), none).y


# 床に、まっすぐな切れ端を置く（ホスト）
func scrap(from: Vector3, to: Vector3) -> int:
	var y := floor_at(from) + 0.03
	var a := Vector3(from.x, y, from.z)
	var b := Vector3(to.x, y, to.z)
	return game.bomb_kit.host_add_scrap(PackedVector3Array([a, b]), a.distance_to(b))


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var kit: Node = game.bomb_kit
	var ck: Node = game.cargo_kit
	var grab: Node = game.rope_grab
	var bomb: Node = game.fx
	var at: Vector3 = game.production.HOME_TRUCK + SPOT
	var out := {}
	match action:
		"stage":
			# 爆弾を空き地に置き、3m の切れ端を床に置く。参加者は、その先のそばに立つ
			place(bomb, at + Vector3(0, 0.05, 0))
			var id: int = scrap(at + Vector3(1.5, 0, 2.0), at + Vector3(4.5, 0, 2.0))
			out["id"] = id
			crew_to(who, at + Vector3(5.3, 0.1, 3.0))
			crew_to(1, at + Vector3(-3.0, 0.1, 6.0))
			var scissors: Node = kit.scissors
			place(scissors, at + Vector3(-3.0, 0.1, 5.0))
			scissors.set_fixed(false)
			await frames(60)
		"go":
			crew_to(who, at + (arg as Vector3))
			await frames(20)
		"walk":
			var from: Vector3 = game.players[who].global_position
			for i in 40:
				crew_to(who, from + (arg as Vector3) * float(i + 1) / 40.0)
				await frames(2)
			await frames(60)
		"settle":
			await wait(float(arg) if arg != null else 2.5)
		"host_cut":
			# ホストの制作班が、はさみを持って、その線を根元から s（m）の所で切る
			var cord: Node = kit.cords.get(int(arg[0]))
			if cord != null:
				game.h_grab(kit.scissors.pid)
				await frames(4)
				crew_to(1, cord.point_at(float(arg[1])) + Vector3(0.4, 0.1, 0.8))
				await frames(20)
				kit.h_cut(int(arg[0]), float(arg[1]))
				await frames(4)
				game.h_release()
		"host_grab":
			# ホストの制作班が、その線の根元から s（m）の所をつかむ
			var cord: Node = kit.cords.get(int(arg[0]))
			if cord != null:
				crew_to(1, cord.point_at(float(arg[1])) + Vector3(0.3, 0.1, 0.9))
				await frames(20)
				grab.h_grab(grab.CORD, int(arg[0]), float(arg[1]))
				await frames(60)
		"host_release":
			grab.h_release()
		"stage_bomb":
			# 爆弾のそばに、1.5m の切れ端を置く。参加者は、その先のそばに立つ
			out["id"] = scrap(at + Vector3(0.9, 0, 1.1), at + Vector3(2.4, 0, 1.1))
			crew_to(who, at + Vector3(1.7, 0.1, 0.5))
			await frames(60)
		"stage_hook":
			# 軽トラのフック（2番）の外側に、4m の切れ端を置く。参加者は、そのフックの外側に立つ
			var truck: Node3D = game.truck
			var local: Vector3 = truck.hooks[2]
			var side: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
			var away := Vector3(signf((side - truck.global_position).x), 0, 0)
			out["id"] = scrap(side + Vector3(0, 0, 0.3), side + Vector3(0, 0, 0.3) + away * 4.0)
			crew_to(who, Vector3(side.x, truck.global_position.y + 0.1, side.z))
			await frames(60)
	await frames(3)
	return out


# 自分の画面のロープの形が、ホストの形とおおむね同じになるまで待つ（端の場所の差が limit より小さい）
func same_shape(theirs: Dictionary, id: int, limit: float, timeout := WAIT) -> Array:
	var kit: Node = game.bomb_kit
	var worst := [INF, INF]
	var ok: bool = await until(func() -> bool:
		var cord: Node = kit.cords.get(id)
		if cord == null or not (theirs["shape"] as Dictionary).has(id):
			return false
		worst[0] = cord.root().distance_to(theirs["shape"][id][0])
		worst[1] = cord.tip().distance_to(theirs["shape"][id][1])
		return float(worst[0]) < limit and float(worst[1]) < limit, timeout)
	return [ok, worst[0], worst[1]]


func client_run() -> void:
	var flow: Node = game.production
	var kit: Node = game.bomb_kit
	var ck: Node = game.cargo_kit
	var grab: Node = game.rope_grab
	var bomb: Node = game.fx
	var me_id: int = multiplayer.get_unique_id()
	var state := ["grabs", "links", "lengths"]

	var reply: Dictionary = await request("hello")
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()), "the participant opens the order desk")
	game.h_order_set.rpc_id(1, "fx", 1)
	game.h_order_confirm.rpc_id(1)
	check(await until(func() -> bool: return flow.phase == 2 and not bomb.absent), "the bomb is rented on the participant")

	# ---- 床の切れ端 ----
	reply = await request("stage")
	var id: int = reply["id"]
	check(id != 0 and reply["view"]["links"].has(id) and reply["view"]["grabs"].is_empty(), "the host lays a 3 m scrap on the floor")
	await sees(reply["view"], state, "the participant sees the scrap, and nobody holding it")
	var rope: Node = kit.cords.get(id)
	var root_was: Vector3 = rope.root() if rope != null else Vector3.ZERO

	# ---- 遠くからは、つかめない ----
	reply = await request("go", Vector3(-17.0, 0.1, 0))
	grab.h_grab.rpc_id(1, grab.CORD, id, 3.0)
	reply = await request("snapshot")
	check(reply["view"]["grabs"].is_empty(), "the rope cannot be grabbed from far away")

	# ---- 参加者が、端をつかむ ----
	reply = await request("go", Vector3(5.3, 0.1, 3.0))
	grab.h_grab.rpc_id(1, grab.CORD, id, 3.0)
	check(await until(func() -> bool: return grab.holding(me_id)), "the participant grabs the end of the rope")
	reply = await request("snapshot")
	check(reply["view"]["grabs"].get(me_id, []) == [grab.CORD, id, 3.0], "on the host, the participant holds that rope at its end")
	await sees(reply["view"], state, "both screens agree on who holds which rope where")

	# ---- 歩く：ロープがついて来る。両方の画面で、形がおおむね同じ ----
	reply = await request("walk", Vector3(0.5, 0, 3.5))
	var walked: Dictionary = reply["view"]
	check(walked["grabs"].has(me_id) and (walked["shape"][id][0] as Vector3).distance_to(root_was) > 1.5, "on the host the rope is dragged along behind the participant (far end moved %.2f m)" % (walked["shape"][id][0] as Vector3).distance_to(root_was))
	check(grab.holding(me_id) and rope.root().distance_to(root_was) > 1.5 and rope.path_length() < rope.length * 1.03, "on the participant's screen too, without stretching")
	var hand_gap := [INF]
	var hand_ok: bool = await until(func() -> bool:
		hand_gap[0] = (grab.grabs[me_id]["at"] as Vector3).distance_to(walked["hands"][me_id]) if grab.holding(me_id) else INF
		return float(hand_gap[0]) < 0.2)
	check(hand_ok, "the grabbed point is at the same place on both screens (%.2f m apart)" % float(hand_gap[0]))
	var same: Array = await same_shape(walked, id, 0.6)
	print(prefix, " shape while held: far end ", same[1], " m apart, held end ", same[2], " m apart")
	check(same[0], "the rope's shape is roughly the same on both screens (ends within %.2f and %.2f m)" % [same[1], same[2]])

	# ---- ホストの制作班が、はさみで切る：参加者は、切れた先をそのままつかんでいる ----
	reply = await request("host_cut", [id, 1.5])
	var cut: Dictionary = reply["view"]
	var far_id := 0
	for other: int in cut["links"]:
		if other != id:
			far_id = other
	check(far_id != 0 and cut["lengths"][id] == 1.5 and cut["grabs"].get(me_id, []) == [grab.CORD, far_id, 1.5], "cut by the host crew: the participant still holds the cut-off piece at its end")
	await sees(cut, state, "the participant sees the cut, and still holds the same end")

	# ---- 離す：両方の画面で落ちて止まる ----
	grab.h_release.rpc_id(1)
	check(await until(func() -> bool: return not grab.holding(me_id)), "the participant lets go")
	reply = await request("settle", 3.5)
	var dropped: Dictionary = reply["view"]
	check(dropped["grabs"].is_empty() and float(dropped["shape"][far_id][2]) < 0.01 and float(dropped["shape"][id][2]) < 0.01, "on the host both pieces have come to rest")
	await sees(dropped, state, "nobody holds anything on either screen")
	same = await same_shape(dropped, far_id, 0.6)
	check(same[0], "the dropped piece lies in roughly the same place on both screens (ends within %.2f and %.2f m)" % [same[1], same[2]])
	same = await same_shape(dropped, id, 0.6)
	check(same[0], "and so does the other piece (ends within %.2f and %.2f m)" % [same[1], same[2]])
	var piece: Node = kit.cords.get(far_id)
	check(await until(func() -> bool: return piece != null and piece.speed() < 0.01), "it has come to rest on the participant's screen too")

	# ---- あとから入った人にも、だれがどこをつかんでいるかが届く ----
	reply = await request("host_grab", [far_id, 0.0])
	var held: Dictionary = reply["view"]
	check(held["grabs"].get(1, []) == [grab.CORD, far_id, 0.0], "the host crew grabs the other end of the piece")
	await sees(held, state, "the participant sees the host crew holding it")
	await rejoin()
	kit = game.bomb_kit
	ck = game.cargo_kit
	grab = game.rope_grab
	bomb = game.fx
	me_id = multiplayer.get_unique_id()
	reply = await request("snapshot")
	held = reply["view"]
	await sees(held, state, "a late joiner is told who holds which rope where", LATE)
	var late_gap := [INF]
	var late_ok: bool = await until(func() -> bool:
		late_gap[0] = (grab.grabs[1]["at"] as Vector3).distance_to(held["hands"][1]) if grab.holding(1) and bool(grab.grabs[1]["set"]) else INF
		return float(late_gap[0]) < 0.3, LATE)
	check(late_ok, "and sees the grabbed point where the host has it (%.2f m apart)" % float(late_gap[0]))
	reply = await request("host_release")
	await sees(reply["view"], state, "the host crew lets go on both screens")

	# ---- 参加者が、切れ端を爆弾の口金につなぐ ----
	check(await until(func() -> bool: return not bomb.absent, LATE), "the late joiner has the bomb")
	reply = await request("stage_bomb")
	var fuse_id: int = reply["id"]
	await sees(reply["view"], state, "a short scrap lies beside the bomb on both screens")
	grab.h_use.rpc_id(1, "bomb", -1)
	reply = await request("snapshot")
	check(reply["view"]["links"][fuse_id] == [0, 0, false], "nothing is connected without a rope end in hand")
	grab.h_grab.rpc_id(1, grab.CORD, fuse_id, 1.5)
	check(await until(func() -> bool: return grab.holding(me_id)), "the participant picks up the scrap's end")
	grab.h_use.rpc_id(1, "bomb", -1)
	reply = await request("settle", 1.5)
	var fused: Dictionary = reply["view"]
	check(fused["links"][fuse_id] == [bomb.pid, 0, false] and fused["lengths"][fuse_id] == 1.5 and not fused["grabs"].has(me_id), "the participant connects the scrap to the bomb's mouth on the host: a 1.5 m fuse")
	await sees(fused, state, "the participant sees the same fuse")
	var fuse: Node = kit.cords.get(fuse_id)
	check(await until(func() -> bool: return fuse != null and fuse.root().distance_to(bomb.mouth()) < 0.1 and bomb.has_cord), "on the participant's screen it runs from the bomb's mouth")

	# ---- 参加者が、切れ端を軽トラのフックに結ぶ ----
	reply = await request("stage_hook")
	var hook_id: int = reply["id"]
	await sees(reply["view"], state, "a scrap lies beside the truck on both screens")
	grab.h_grab.rpc_id(1, grab.CORD, hook_id, 0.0)
	check(await until(func() -> bool: return grab.holding(me_id)), "the participant picks up its end")
	grab.h_use.rpc_id(1, "hook", 2)
	reply = await request("settle", 1.5)
	var hung: Dictionary = reply["view"]
	var lash_id := 0
	for lid: int in hung["lashes"]:
		lash_id = lid
	check(lash_id != 0 and hung["lashes"][lash_id] == [2, ck.END_FREE, ck.SCRAP, 4.0] and not hung["links"].has(hook_id) and not hung["grabs"].has(me_id), "the participant ties it to a truck hook on the host")
	await sees(hung, state + ["lashes"], "the participant sees the rope hanging from the hook, and the scrap gone")
	var line: Node = ck.lashes[lash_id]["cord"] if ck.lashes.has(lash_id) else null
	check(await until(func() -> bool: return line != null and line.root().distance_to(ck.hook_at(2)) < 0.1), "on the participant's screen it hangs from that hook")
