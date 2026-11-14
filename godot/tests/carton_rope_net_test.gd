extends "res://tests/pair_net_base.gd"
# 段ボール箱とロープの二人通信：
#   参加者が物を箱に入れる → ホストで箱の中身になり、参加者の画面でも物が消えて、箱の中に見える /
#   入らない物・離れた人の頼みは、ホストが断る / ホストの制作班が入れた物も、参加者に届く /
#   箱の中の並び（実寸で積んだ場所と向き）が、両方の画面で同じ / 開いた箱へ手で落とした物も、中身になって届く /
#   参加者が取り出す → 選んだ物が、参加者の手に出る / 山から1箱もらう /
#   参加者が、荷台のフックにロープの端を結び、向こうのフックにも結ぶ → 両方の画面で、同じフックからフックへ、同じ長さの
#   ロープが箱の上に掛かる。ロープが押さえた箱は持てない / 途中参加でも、箱の中身・出ている箱・掛けたロープが届く /
#   あとから入った人が、はさみで切る・ほどく → 両方の画面で、切れた先がそれぞれのフックから垂れ、ほどくと束に戻る。
# 会社での準備中（phase 2）のまま確かめる。出発も到着も使わない。
#   godot --headless --path godot res://tests/carton_rope_net_test.tscn -- --carton-rope-net-test-host      （参加者は -client）

const WATCH := ["fish", "scrap_pie", "rock"]
const BENCH := Vector3(-5.0, 0.1, 5.6)        # 軽トラ（HOME_TRUCK）から見た、箱を並べる場所


func configure() -> void:
	prefix = "CARTON_ROPE_NET"
	port = 24857
	flag = "carton-rope-net-test"
	budget = 70.0


func after_game() -> void:
	# 定期の送り直しに頼らず、箱とロープ自身の送信で届くことを確かめる
	game.production.set_physics_process(false)


func has_digit(text: String) -> bool:
	for ch: String in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


# 画面に見える様子：箱の中身・消えている物・中身の名前と、箱の中の見た目（どの物が、どこに、どの向きで）・持っている物・掛けたロープ・束の残り・置き場の箱の数
func view() -> Dictionary:
	var flow: Node = game.production
	var kit: Node = game.cargo_kit
	var stored := {}
	var gone := {}
	for kind: String in WATCH:
		var prop: Node = first(kind)
		stored[kind] = prop.stored_in
		gone[kind] = prop.absent
	var notes := {}
	var inside := {}
	var shown := {}
	var weights := {}
	var out := 0
	for box: Node in kit.cartons:
		out += 0 if box.absent else 1
		if kit.box_note(box) != "":
			notes[box.pid] = kit.box_note(box)
		var model: Node = box.get_node_or_null("Inside")
		if model != null:
			inside[box.pid] = model.get_child_count()
			# 箱の中に実際に見えている写し：名前（物のID）・場所・向き
			var rows: Array = []
			for holder: Node3D in model.get_children():
				var b: Basis = holder.transform.basis
				rows.append([str(holder.name), holder.transform.origin.snappedf(0.001), b.x.snappedf(0.01), b.y.snappedf(0.01)])
			shown[box.pid] = rows
		if not is_equal_approx(box.mass, box.empty_mass):
			weights[box.pid] = snappedf(box.mass, 0.01)
	var held := {}
	for id: int in game.players:
		held[id] = game.players[id].held
	# 掛けたロープ：どのフックからどのフックへ（ropes）と、その長さ（rope_len）。押さえている物（pinned）は、ホストだけが知っている
	var ids: Array = kit.lashes.keys()
	ids.sort()
	var ropes: Array = []
	var rope_len: Array = []
	for id: int in ids:
		ropes.append([id, int(kit.lashes[id]["a"]), int(kit.lashes[id]["b"])])
		rope_len.append(snappedf(float(kit.lashes[id]["cord"].length), 0.01))
	var pinned: Array = []
	for pid: int in kit.holds:
		if kit.pinned(pid):
			pinned.append(pid)
	pinned.sort()
	var riding: Array = Array(flow.cargo(false))
	riding.sort()
	return {"phase": flow.phase, "boxes": kit.contents.duplicate(true), "stored": stored, "absent": gone, "notes": notes, "inside": inside, "shown": shown,
		"weights": weights, "held": held, "ropes": ropes, "rope_len": rope_len, "pinned": pinned, "stock": snappedf(float(game.bomb_kit.stock), 0.01),
		"out": out, "reserve": kit.reserve().size(), "cargo": riding}


# 自分の画面のロープ：両端がフックにあり、箱の上を通っているか（節の位置は、各自の画面で計算している）
func rope_over(id: int, box: Node3D) -> bool:
	var kit: Node = game.cargo_kit
	if not kit.lashes.has(id):
		return false
	var lash: Dictionary = kit.lashes[id]
	var cord: Node3D = lash["cord"]
	if int(lash["a"]) < 0 or int(lash["b"]) < 0 or cord.pts.size() < 4:
		return false
	if cord.root().distance_to(kit.hook_at(int(lash["a"]))) > 0.1 or cord.tip().distance_to(kit.hook_at(int(lash["b"]))) > 0.1:
		return false
	var bounds: AABB = game.body_bounds(box)
	var inv: Transform3D = box.global_transform.affine_inverse()
	var over := 0
	for point: Vector3 in cord.pts:
		var l: Vector3 = inv * point
		if l.x > bounds.position.x and l.x < bounds.end.x and l.z > bounds.position.z and l.z < bounds.end.z and l.y > bounds.end.y - 0.3 and l.y < bounds.end.y + 0.15:
			over += 1
	return over >= 5


# ホストだけ：その場所へ置き直す（固定はしない。持てるように）
func put(prop: Node, pos: Vector3) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion.IDENTITY
	state[2] = false
	prop.restore(state)


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var flow: Node = game.production
	var kit: Node = game.cargo_kit
	var base: Vector3 = flow.HOME_TRUCK
	var boxes: Array = of_kind("carton")
	match action:
		"stage":
			# 箱を2つ並べ、手前に小物と岩を置く。二人は箱の手前に立つ
			put(boxes[0], base + BENCH + Vector3(0, 0.1, -1.9))
			put(boxes[1], base + BENCH + Vector3(1.7, 0.1, -1.9))
			put(first("fish"), base + BENCH + Vector3(-0.6, 0.2, -0.7))
			put(first("scrap_pie"), base + BENCH + Vector3(0.3, 0.2, -0.7))
			put(first("rock"), base + BENCH + Vector3(-2.2, 0.2, 0.4))
			crew_to(who, base + BENCH)
			crew_to(1, base + BENCH + Vector3(1.7, 0, 0))
			await frames(40)
		"near":
			crew_to(who, base + BENCH)
		"far":
			crew_to(who, base + BENCH + Vector3(-9.0, 0, 9.0))
		"pile":
			crew_to(who, kit.pile.global_position + Vector3(1.9, 0.1, 0.0))
		"truck":
			# 箱を挟むフック（左の2番）の外側に立つ
			crew_to(who, game.truck.global_transform * Vector3(-2.65, 0.1, (game.truck.hooks[2] as Vector3).z), -PI * 0.5)
			# 束とはさみも、手の届く所へ持って来ておく
			if kit.rope.holder == 0:
				put(kit.rope, game.truck.global_transform * Vector3(-2.0, 0.3, (game.truck.hooks[2] as Vector3).z + 0.5))
			if game.bomb_kit.scissors.holder == 0:
				put(game.bomb_kit.scissors, game.truck.global_transform * Vector3(-2.0, 0.3, (game.truck.hooks[2] as Vector3).z - 0.5))
			await frames(20)
		"snug":
			# 結び目のゆるみは、でたらめに決まる。確認では、よく張れる種を選んでおく
			for candidate in range(1, 400):
				kit.rng.seed = candidate
				if kit.rng.randf_range(0.0, kit.KNOT_LOOSE) + 4.0 * kit.rng.randf_range(0.0, kit.THROW_LOOSE) < 0.05:
					kit.rng.seed = candidate
					break
		"settle":
			await frames(int(arg))
		"drop_in":
			# 開いた箱の真上から、物を落とす（手で箱の中へ置いたのと同じ）
			var target: Node = game.props[int(arg[1])]
			var thing: Node = game.props[int(arg[0])]
			put(thing, target.global_transform * Vector3(0.2, float(target.room.end.y) + 0.25, 0.0) - thing.center)
			# 中で止まって、少したつと中身になる（止まるまでの時間は、落ち方で変わる）
			for i in 300:
				if thing.stored_in != 0:
					break
				await frames(1)
		"host_pack":
			# ホストの制作班が、物を持って箱に入れる
			game.h_grab(int(arg[0]))
			await frames(3)
			kit.h_pack(int(arg[0]), int(arg[1]))
		"deck":
			# 箱を荷台に載せる（手で置いたのと同じ）
			var box: Node = game.props[int(arg)]
			put(box, game.truck.global_transform * Vector3(0.0, float(game.truck.deck_top) + 0.15, (game.truck.hooks[2] as Vector3).z))
			await frames(40)
			game._try_load(box)
		"release":
			# その参加者が持っている物を、手から離す
			var mine: Node = game._held_by(who)
			if mine != null:
				game.host_release(mine)
	# ホスト自身の画面（箱の中の見た目・ロープ）が変わるのを待ってから見せる
	await frames(3)
	return {}


func client_run() -> void:
	var flow: Node = game.production
	var kit: Node = game.cargo_kit
	var me: Node = game.local_player()
	var mine: int = me.peer_id
	var fish: Node = first("fish")
	var pie: Node = first("scrap_pie")
	var rock: Node = first("rock")
	var boxes: Array = of_kind("carton")
	var box: Node = boxes[0]
	var packing := ["boxes", "stored", "absent", "notes", "inside", "shown", "weights", "held"]
	var roping := ["ropes", "rope_len", "stock", "held"]

	# ---- 依頼を受けて、箱を並べる ----
	var reply: Dictionary = await request("hello")
	check(reply["view"]["out"] == kit.SHOWN and reply["view"]["reserve"] == kit.CARTON_COUNT - kit.SHOWN, "the host has %d cartons out and %d in reserve" % [reply["view"]["out"], reply["view"]["reserve"]])
	await sees(reply["view"], ["out", "reserve", "boxes"], "the participant sees the same cartons in the yard", LATE)
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	reply = await request("stage")

	# ---- 参加者が箱に入れる ----
	game.h_grab.rpc_id(1, fish.pid)
	check(await until(func() -> bool: return me.held == fish.pid), "the participant holds the rubber fish")
	kit.h_pack.rpc_id(1, fish.pid, box.pid)
	reply = await request("snapshot")
	check(reply["view"]["boxes"] == {box.pid: [fish.pid]} and reply["view"]["stored"]["fish"] == box.pid and reply["view"]["absent"]["fish"] and reply["view"]["held"][mine] == 0, "F from the participant packs the fish into the carton on the host")
	check(reply["view"]["notes"].has(box.pid) and "ゴムの魚" in str(reply["view"]["notes"][box.pid]) and reply["view"]["inside"].get(box.pid, 0) == 1 and str(reply["view"]["shown"][box.pid][0][0]) == "Item%d" % fish.pid, "the host's carton shows its contents (%s)" % str(reply["view"]["notes"].get(box.pid, "")))
	await sees(reply["view"], packing, "the participant sees the fish gone into the carton too")
	check(not fish.visible and fish.collision_layer == 0 and me.held == 0, "on the participant the packed fish is hidden and out of the hands")

	# ---- 入らない物・離れた人の頼みは断られる ----
	game.h_grab.rpc_id(1, rock.pid)
	check(await until(func() -> bool: return me.held == rock.pid), "the participant holds the foam rock")
	kit.h_pack.rpc_id(1, rock.pid, box.pid)
	reply = await request("snapshot")
	check(reply["view"]["stored"]["rock"] == 0 and not reply["view"]["absent"]["rock"] and reply["view"]["held"][mine] == rock.pid and reply["view"]["boxes"] == {box.pid: [fish.pid]}, "a prop that is too big is refused and stays in the participant's hands")
	reply = await request("release")
	await sees(reply["view"], packing, "the participant's hands are empty again")
	reply = await request("far")
	game.h_grab.rpc_id(1, pie.pid)
	check(await until(func() -> bool: return me.held == pie.pid), "far away, the participant holds the cream pie")
	kit.h_pack.rpc_id(1, pie.pid, box.pid)
	kit.h_unpack.rpc_id(1, box.pid, 0)
	reply = await request("snapshot")
	check(reply["view"]["stored"]["scrap_pie"] == 0 and reply["view"]["boxes"] == {box.pid: [fish.pid]}, "a participant far from the carton can neither pack nor unpack")
	reply = await request("release")
	reply = await request("near")

	# ---- ホストの制作班が入れた物も、参加者に届く ----
	reply = await request("host_pack", [pie.pid, box.pid])
	check(reply["view"]["boxes"] == {box.pid: [fish.pid, pie.pid]} and reply["view"]["stored"]["scrap_pie"] == box.pid, "the host crew packs the cream pie")
	var note: String = str(reply["view"]["notes"].get(box.pid, ""))
	check("ゴムの魚" in note and "クリームパイ" in note and not has_digit(note), "the carton names both, and counts nothing (%s)" % note)
	check((reply["view"]["shown"][box.pid] as Array).size() == 2, "both lie in the host's carton")
	await sees(reply["view"], packing, "what the host packed shows on the participant, lying in the same places")
	check(kit.box_note(box) == note, "the participant's hint lists the same contents (%s)" % kit.box_note(box))

	# ---- 参加者が取り出す：選んだ物が手に出る ----
	kit.h_unpack.rpc_id(1, box.pid, pie.pid)
	reply = await request("snapshot")
	check(reply["view"]["boxes"] == {box.pid: [fish.pid]} and reply["view"]["stored"]["scrap_pie"] == 0 and not reply["view"]["absent"]["scrap_pie"] and reply["view"]["held"][mine] == pie.pid, "F from the participant takes the chosen prop (the pie) out, into the participant's hands")
	await sees(reply["view"], packing, "the participant sees the pie out of the carton and in hand")
	check(await until(func() -> bool: return pie.visible and pie.global_position.distance_to(me.global_position) < 3.5), "the pie shows up at the participant's hands")
	reply = await request("release")

	# ---- 開いた箱の中へ、手で落とす：中で落ち着いたら中身になり、参加者にも同じ並びで届く ----
	reply = await request("drop_in", [pie.pid, box.pid])
	check(reply["view"]["boxes"] == {box.pid: [fish.pid, pie.pid]} and reply["view"]["stored"]["scrap_pie"] == box.pid and reply["view"]["absent"]["scrap_pie"], "a prop dropped into the open carton becomes its contents on the host")
	await sees(reply["view"], packing, "the participant sees it lying in the same place in the carton")
	check(not pie.visible and pie.collision_layer == 0, "on the participant the dropped prop itself is hidden")
	kit.h_unpack.rpc_id(1, box.pid, pie.pid)
	reply = await request("snapshot")
	check(reply["view"]["boxes"] == {box.pid: [fish.pid]} and reply["view"]["held"][mine] == pie.pid, "and the participant can take it out again")
	await sees(reply["view"], packing, "the participant sees the pie out of the carton again")
	reply = await request("release")

	# ---- 山から1箱 ----
	reply = await request("pile")
	var before: Dictionary = reply["view"]
	kit.h_take_carton.rpc_id(1)
	reply = await request("snapshot")
	var fresh: int = int(reply["view"]["held"][mine])
	check(fresh != 0 and game.props[fresh].kind == "carton" and reply["view"]["out"] == before["out"] + 1 and reply["view"]["reserve"] == before["reserve"] - 1, "F on the pile hands the participant a fresh carton from the reserve")
	await sees(reply["view"], ["out", "reserve", "held"], "the participant sees the new carton in hand and one fewer in reserve")
	check(await until(func() -> bool: return not game.props[fresh].absent and game.props[fresh].global_position.distance_to(me.global_position) < 3.5), "the carton shows up at the participant's hands")
	reply = await request("release")

	# ---- ロープ：フックに結ぶ・向こうのフックにも結ぶ・押さえた箱は持てない ----
	reply = await request("deck", box.pid)
	reply = await request("truck")
	check(reply["view"]["cargo"].has(box.pid) and reply["view"]["cargo"].has(fish.pid), "the carton on the deck and the fish inside are cargo on the host")
	await sees(reply["view"], ["cargo"], "and on the participant", LATE)
	game.h_grab.rpc_id(1, kit.rope.pid)
	check(await until(func() -> bool: return me.held == kit.rope.pid and kit.rope.global_position.distance_to(me.global_position) < 3.0), "the participant holds the rope coil")
	kit.h_hook.rpc_id(1, 2)
	reply = await request("snapshot")
	var ropes: Array = reply["view"]["ropes"]
	check(ropes.size() == 1 and ropes[0][1] == 2 and ropes[0][2] == kit.END_COIL and reply["view"]["stock"] < game.bomb_kit.COIL_M, "F from the participant ties one end to the hook on the host; the other end is on the coil")
	await sees(reply["view"], ["ropes", "held"], "the participant sees the rope from that hook to the coil")
	var rope_id: int = ropes[0][0]
	check(await until(func() -> bool: return kit.lashes.has(rope_id) and kit.lashes[rope_id]["cord"].root().distance_to(kit.hook_at(2)) < 0.1 and kit.lashes[rope_id]["cord"].tip().distance_to(kit.rope.global_position) < 0.6), "on the participant it runs from the hook to the coil in hand")
	reply = await request("snug")
	kit.h_hook.rpc_id(1, 7)
	reply = await request("settle", 60)
	check(reply["view"]["ropes"] == [[rope_id, 2, 7]] and reply["view"]["pinned"] == [box.pid], "F on the hook across the bed ties the other end on the host, and the rope holds the carton")
	await sees(reply["view"], roping, "the participant sees the same rope, hook to hook, the same length, and the same rope left on the coil")
	check(await until(func() -> bool: return rope_over(rope_id, box)), "on the participant the rope lies across the top of the carton, both ends on their hooks")
	check(kit.holds.is_empty(), "how well it holds is not sent to the participant (it is judged by eye)")
	reply = await request("release")
	game.h_grab.rpc_id(1, box.pid)
	reply = await request("snapshot")
	check(reply["view"]["held"][mine] == 0 and box.holder == 0, "the carton held by the rope cannot be picked up")
	# ロープが掛かっていても、中身は出し入れできる
	kit.h_unpack.rpc_id(1, box.pid, 0)
	reply = await request("snapshot")
	check(reply["view"]["held"][mine] == fish.pid and reply["view"]["boxes"] == {}, "but its contents can still be taken out")
	await sees(reply["view"], packing, "the participant sees the empty carton")
	kit.h_pack.rpc_id(1, fish.pid, box.pid)
	reply = await request("snapshot")
	check(reply["view"]["boxes"] == {box.pid: [fish.pid]}, "and packed again")
	await sees(reply["view"], packing, "the participant sees the fish back in the carton")

	# ---- 途中参加：箱の中身・出ている箱・掛けたロープが届く ----
	var expected: Dictionary = reply["view"]
	await rejoin()
	kit = game.cargo_kit
	reply = await request("hello")
	await sees(expected, ["boxes", "stored", "absent", "notes", "inside", "shown", "weights", "ropes", "rope_len", "stock", "out", "reserve"], "a late joiner receives the carton contents, the cartons that are out and the rope on the truck", LATE)
	me = game.local_player()
	mine = me.peer_id
	box = of_kind("carton")[0]
	check(await until(func() -> bool: return rope_over(rope_id, box)), "on the late joiner the rope lies across the carton, both ends on their hooks")

	# ---- あとから入った人が、はさみで切る → 押さえが外れ、切れた先がそれぞれのフックから垂れる ----
	reply = await request("truck")
	game.h_grab.rpc_id(1, game.bomb_kit.scissors.pid)
	check(await until(func() -> bool: return me.held == game.bomb_kit.scissors.pid), "the late joiner holds the scissors")
	var whole: float = kit.lashes[rope_id]["cord"].length
	kit.h_cut_lash.rpc_id(1, rope_id, whole * 0.5)
	reply = await request("settle", 30)
	ropes = reply["view"]["ropes"]
	check(ropes.size() == 2 and ropes[0][2] == kit.END_FREE and ropes[1][2] == kit.END_FREE and [ropes[0][1], ropes[1][1]] == [2, 7] and reply["view"]["pinned"] == [], "F with the scissors cuts the rope on the host: two loose ends on their hooks, holding nothing")
	await sees(reply["view"], ["ropes", "rope_len", "stock"], "the participant sees the same two loose ends")
	check(await until(func() -> bool: return kit.lashes.size() == 2 and kit.lashes.values().all(func(l: Dictionary) -> bool: return l["cord"].tip().y < kit.hook_at(2).y + 0.9)), "on the participant the cut ends have dropped")
	reply = await request("release")
	game.h_grab.rpc_id(1, box.pid)
	reply = await request("snapshot")
	check(reply["view"]["held"][mine] == box.pid, "with the rope cut, the carton can be picked up again")
	reply = await request("release")

	# ---- ほどく：束に巻き戻る ----
	kit.h_untie.rpc_id(1, int(ropes[0][0]))
	kit.h_untie.rpc_id(1, int(ropes[1][0]))
	reply = await request("snapshot")
	check(reply["view"]["ropes"] == [] and is_equal_approx(reply["view"]["stock"], game.bomb_kit.COIL_M), "F on the loose ends unties them on the host; all the rope is back on the coil")
	await sees(reply["view"], ["ropes", "rope_len", "stock"], "and the ropes are gone on the participant")
