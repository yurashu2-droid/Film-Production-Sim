extends "res://tests/pair_net_base.gd"
# 爆弾の道具（導火線の束・はさみ・火薬の袋）の二人通信：
#   参加者が、束を持ってつなぐ・歩いて伸ばす・はさみで切る・袋から注ぐ・線の先に点火する。
#   決めるのはホスト。「どこにつながっているか・長さ・どこで切れたか・火がどこまで進んだか・火薬の量・こぼれた粉」が
#   両方の画面で一致する（線の節の位置は、各自の画面で計算するので見比べない）/
#   燃え尽きると "burst" の合図が参加者にも届く / 道具を持っていない人・離れた人の操作は断られる /
#   途中参加でも、いまの線・火薬・こぼれた粉が届く。
# 会社での準備中（phase 2）のまま確かめる。出発も到着も使わない（本番の爆発は現場でしか起きない）。
#   godot --headless --path godot res://tests/bomb_net_test.tscn -- --bomb-net-test-host      （参加者は -client）

const EXPLOSION_SCRIPT := "res://vfx/vfx_explosion.gd"
const REHEARSAL_LIFE := 2.4           # 小さな爆発（試し発火）の演出の寿命。導火線の最後の溜めは、これより短い
const SPOT := Vector3(-7.5, 0.0, -1.5)   # 爆弾を置く場所（軽トラ HOME から見た位置）

var _lives: Array = []                # 参加者の画面に現れた爆発の演出の寿命（種類の見分けに使う）


func configure() -> void:
	prefix = "BOMB_NET"
	port = 24853
	flag = "bomb-net-test"
	budget = 75.0


func after_game() -> void:
	game.production.set_physics_process(false)
	game.child_entered_tree.connect(_note_child)


# 爆発の演出が現れたら、寿命を控える（寿命は現れたあとで決まるので、一呼吸おいて読む）
func _note_child(node: Node) -> void:
	var script: Script = node.get_script()
	if script != null and script.resource_path == EXPLOSION_SCRIPT:
		_note_life.call_deferred(node)


func _note_life(node: Node) -> void:
	if is_instance_valid(node):
		_lives.append(node.life)


func rehearsal_pop_seen() -> bool:
	return _lives.any(func(life: float) -> bool: return is_equal_approx(life, REHEARSAL_LIFE))


# 画面に見える様子。線は「番号・つながり先・燃えているか」と、長さ（5cm刻み）。
# 燃えている・伸びている間の長さは動き続けるので、止まっている間だけ見比べる
func view() -> Dictionary:
	var kit: Node = game.bomb_kit
	var bomb: Node = game.fx
	var flow: Node = game.production
	var links := {}
	var lengths := {}
	for id: int in kit.cords:
		var cord: Node = kit.cords[id]
		links[id] = [cord.a_body.pid if cord.a_body != null else 0, cord.b_body.pid if cord.b_body != null else 0, cord.burning]
		lengths[id] = snappedf(cord.length, 0.05)
	var fills: Array = []
	var out := 0
	for sack: Node in kit.sacks:
		fills.append(snappedf(sack.fill, 0.01))
		out += 0 if sack.absent else 1
	var spilled := 0.0
	for spill: Array in kit.spills:
		spilled += float(spill[1])
	return {"absent": bomb.absent, "coil": not kit.coil.absent, "sacks": out, "powder": snappedf(bomb.powder, 0.01), "stage": bomb.stage(),
		"links": links, "lengths": lengths, "has_cord": bomb.has_cord, "stock": snappedf(kit.stock, 0.05), "fills": fills,
		"piles": kit.spills.size(), "spilled": snappedf(spilled, 0.001), "fuse": bomb.fuse, "pouring": not kit.rates.is_empty(),
		"order": game.order, "phase": flow.phase, "expenses": flow.expenses}


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var kit: Node = game.bomb_kit
	var bomb: Node = game.fx
	var at: Vector3 = game.production.HOME_TRUCK + SPOT
	match action:
		"stage":
			# 爆弾を空き地に置き、道具をそばへ並べる。参加者は爆弾の +X 側に立つ
			place(bomb, at + Vector3(0, 0.05, 0))
			loose(kit.coil, at + Vector3(0.9, 0.06, 0.3))
			loose(kit.scissors, at + Vector3(2.4, 0.1, 0.9))
			crew_to(who, at + Vector3(1.6, 0.1, 0))
			crew_to(1, at + Vector3(-2.0, 0.1, 3.0))
		"near":
			crew_to(who, at + Vector3(1.6, 0.1, 0))
		"coil_here":
			# 束を、爆弾のそばへ持ってきたことにする（運ぶ所は省く）
			loose(kit.coil, at + Vector3(0.9, 0.06, 0.3))
			crew_to(who, at + Vector3(1.6, 0.1, 0))
		"far":
			crew_to(who, at + Vector3(-17.0, 0.1, 0))
		"go":
			# その人を、その場所（爆弾から見た位置）へ移す
			crew_to(who, at + (arg as Vector3))
		"walk":
			# 持っている物ごと、少しずつ歩かせる（線が束から出ていく）
			var from: Vector3 = game.players[who].global_position
			for i in 30:
				crew_to(who, from + (arg as Vector3) * float(i + 1) / 30.0)
				await frames(2)
			await settle()
		"sack":
			# 袋の口が、爆弾の口（＋ずらし）の真上に来るように置く。参加者は、その +X 側に立つ
			var sack: Node = kit.sacks[0]
			var offset: Vector3 = arg
			var stand: Vector3 = at + Vector3(1.6, 0.1, 0) + offset
			crew_to(who, stand)
			# 参加者の位置は、少し遅れてホストに届く。届いてから袋を置く（持ったあとに体が動くと、袋も付いて動く）
			await until(func() -> bool: return Vector2(game.players[who].global_position.x - stand.x, game.players[who].global_position.z - stand.z).length() < 0.15)
			await frames(6)
			loose(sack, bomb.mouth() + offset + Vector3(sack.SPOUT, 0.42 - sack.center.y, 0))
		"settle":
			await settle()
		"burst":
			# 火が口金に届いて、ホストが爆発の合図を出すまで待つ
			await until(func() -> bool: return kit.bomb_cord() == null and bomb.fuse < 0.0, 12.0)
		"host_light":
			# ホストの制作班が、線の先に火を付ける
			var cord: Node = kit.bomb_cord()
			if cord != null:
				crew_to(1, cord.tip() + Vector3(0.5, 0.1, 0.5))
				await frames(4)
				kit.h_light(cord.id, 1)
	# ホスト自身の見た目は次のフレームで変わるので、落ち着くまで待ってから見せる
	await frames(3)
	return {}


# 置き直す（固定しない。手に持てる）
func loose(prop: Node, pos: Vector3) -> void:
	place(prop, pos)
	prop.set_fixed(false)


# 線の長さと、注ぐ勢いが落ち着くまで待つ
func settle() -> void:
	var kit: Node = game.bomb_kit
	var last := -1.0
	var calm := 0
	for i in 300:
		var total := 0.0
		for cord: Node in kit.cords.values():
			total += cord.length if not cord.burning else 0.0
		# 持って歩いている人の位置は、少し遅れて届く。しばらく変わらないのを確かめる
		calm = calm + 1 if is_equal_approx(total, last) and kit.rates.is_empty() and not kit._dirty else 0
		if calm >= 6:
			break
		last = total
		await frames(10)


func client_run() -> void:
	var flow: Node = game.production
	var kit: Node = game.bomb_kit
	var bomb: Node = game.fx
	var cords := ["links", "lengths", "has_cord", "stock"]
	var powder := ["powder", "stage", "fills", "piles", "spilled"]
	var stock := ["absent", "coil", "sacks"] + cords + powder

	# ---- 依頼を受けて、爆弾を借りる（参加者が発注する） ----
	var reply: Dictionary = await request("hello")
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()) and flow.phase == 2, "the participant opens the order desk")
	game.h_order_set.rpc_id(1, "fx", 1)
	game.h_order_set.rpc_id(1, "refill", 1)
	game.h_order_confirm.rpc_id(1)
	check(await until(func() -> bool: return flow.phase == 2 and not bomb.absent), "the order is confirmed and the bomb is rented on the participant")
	reply = await request("snapshot")
	var rented: Dictionary = reply["view"]
	check(not rented["absent"] and rented["coil"] and rented["sacks"] == 2 and rented["powder"] == 0.0 and rented["links"].is_empty(), "the host has an empty bomb, two sacks and the rope coil")
	check(rented["expenses"] == 360 + 40, "the rental is paid from the client's budget")
	await sees(rented, stock + ["order", "expenses"], "the participant sees the same kit and order")

	# ---- 道具を持っていない人・離れた人の操作は断られる ----
	reply = await request("stage")
	kit.h_connect.rpc_id(1)
	kit.h_pour.rpc_id(1, true)
	kit.h_pour.rpc_id(1, false)
	reply = await request("snapshot")
	check(reply["view"]["links"].is_empty() and reply["view"]["powder"] == 0.0, "without the coil or a sack in hand, nothing connects and nothing pours")

	# ---- つなぐ：参加者が束を持って、口金につなぐ ----
	game.h_grab.rpc_id(1, kit.coil.pid)
	check(await until(func() -> bool: return game.local_player().held == kit.coil.pid), "the participant picks up the coil")
	reply = await request("far")
	kit.h_connect.rpc_id(1)
	reply = await request("snapshot")
	check(reply["view"]["links"].is_empty(), "the coil cannot be connected from far away")
	reply = await request("near")
	kit.h_connect.rpc_id(1)
	reply = await request("settle")
	var joined: Dictionary = reply["view"]
	check(joined["links"].size() == 1 and joined["has_cord"] and joined["links"].values()[0] == [bomb.pid, kit.coil.pid, false], "the participant connects the fuse to the bomb on the host")
	await sees(joined, cords, "the participant sees the same connection, length and coil stock")

	# ---- 伸ばす：束を持って歩くと、線が出ていく ----
	reply = await request("walk", Vector3(4.0, 0, 0.5))
	var paid: Dictionary = reply["view"]
	var id: int = paid["links"].keys()[0]
	check(paid["lengths"][id] > joined["lengths"][id] + 3.0 and paid["stock"] < joined["stock"] - 3.0, "walking away with the coil pays the fuse out on the host (%.2f m)" % paid["lengths"][id])
	await sees(paid, cords, "the participant's fuse is the same length")
	var mine: Node = kit.cords.get(id)
	check(mine != null and mine.pts.size() > 20 and mine.pts[0].distance_to(bomb.mouth()) < 0.1, "the participant's own copy of the fuse runs from the bomb's mouth (%d nodes)" % (mine.pts.size() if mine != null else 0))
	var low := 0
	if mine != null:
		for p: Vector3 in mine.pts:
			low += 1 if p.y < bomb.global_position.y + 0.08 else 0
	check(mine != null and low > mine.pts.size() / 2, "and lies on the floor there too")

	# ---- 切る：はさみを持っていないと切れない。持てば、決めた所で切れて、切れ端が残る ----
	kit.h_cut.rpc_id(1, id, 2.5)
	reply = await request("snapshot")
	check(reply["view"]["links"].size() == 1, "the coil is not a pair of scissors")
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the coil down")
	game.h_grab.rpc_id(1, kit.scissors.pid)
	check(await until(func() -> bool: return game.local_player().held == kit.scissors.pid), "and picks up the scissors")
	reply = await request("go", Vector3(2.4, 0.1, 0.8))
	kit.h_cut.rpc_id(1, id, 2.5)
	reply = await request("settle")
	var cut: Dictionary = reply["view"]
	check(cut["links"].size() == 2 and cut["lengths"][id] == 2.5 and cut["links"][id] == [bomb.pid, 0, false], "the participant cuts the fuse at 2.5 m on the host")
	var scrap_id := 0
	for other: int in cut["links"]:
		if other != id:
			scrap_id = other
	check(cut["links"][scrap_id] == [0, 0, false] and absf(cut["lengths"][scrap_id] - (paid["lengths"][id] - 2.5)) < 0.11, "the rest is a loose scrap")
	await sees(cut, cords, "the participant sees the cut fuse and the scrap")
	var scrap: Node = kit.cords.get(scrap_id)
	check(scrap != null and scrap.pts.size() >= 2 and scrap.tip().distance_to(bomb.global_position) > 2.0, "the scrap lies where it was cut off, on the participant's screen too")
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the scissors down")

	# ---- 注ぐ：参加者が袋を持って F。入った量と、袋の残りが一致する ----
	reply = await request("sack", Vector3.ZERO)
	var sack: Node = kit.sacks[0]
	game.h_grab.rpc_id(1, sack.pid)
	check(await until(func() -> bool: return game.local_player().held == sack.pid), "the participant picks up a sack")
	kit.h_pour.rpc_id(1, true)
	check(await until(func() -> bool: return sack.pour_rate > 0.0), "the pouring shows on the participant's screen")
	check(await until(func() -> bool: return bomb.powder > 0.15, 20.0), "powder arrives in the participant's bomb while pouring")
	kit.h_pour.rpc_id(1, false)
	reply = await request("settle")
	var poured: Dictionary = reply["view"]
	check(poured["powder"] > 0.15 and poured["fills"][0] < 1.0 and not poured["pouring"] and poured["piles"] == 0, "the host's bomb holds what the participant poured (%.2f; the sack keeps %.2f)" % [poured["powder"], poured["fills"][0]])
	check(absf(poured["powder"] + poured["fills"][0] - 1.0) < 0.02, "what left the sack is in the bomb")
	await sees(poured, powder, "the participant sees the same amount in the bomb and in the sack")
	check(await until(func() -> bool: return sack.pour_rate <= 0.0), "the pouring stops on the participant's screen")
	# 外す：口から離れた所で注ぐと、床にこぼれる
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the sack down")
	reply = await request("sack", Vector3(0, 0, 2.2))
	game.h_grab.rpc_id(1, sack.pid)
	check(await until(func() -> bool: return game.local_player().held == sack.pid), "and picks it up beside the bomb")
	kit.h_pour.rpc_id(1, true)
	# 出はじめは少ししか出ない。目に見える量になるまで注ぐ
	check(await until(func() -> bool: return not kit.spills.is_empty() and float(kit.spills[0][1]) > 0.03, 25.0), "powder poured beside the bomb shows as a pile on the participant's floor")
	kit.h_pour.rpc_id(1, false)
	reply = await request("settle")
	var spilled: Dictionary = reply["view"]
	check(spilled["piles"] >= 1 and spilled["spilled"] > 0.0 and spilled["powder"] == poured["powder"], "the host has the spill; the bomb got none of it (%d piles, %.2f spilled; bomb %.2f → %.2f)" % [spilled["piles"], spilled["spilled"], poured["powder"], spilled["powder"]])
	await sees(spilled, powder, "the participant sees the same spill")
	game.h_release.rpc_id(1)
	check(await until(func() -> bool: return game.local_player().held == 0), "the participant puts the sack down again")

	# ---- 途中参加：つないだ線・切れ端・火薬・こぼれた粉が届く ----
	var expected: Dictionary = spilled
	await rejoin()
	kit = game.bomb_kit
	bomb = game.fx
	reply = await request("hello")
	await sees(expected, stock + ["order", "phase", "expenses"], "a late joiner receives the fuse, the scrap, the powder and the spill", LATE)
	var late: Node = kit.cords.get(id)
	check(late != null and late.pts[0].distance_to(bomb.mouth()) < 0.15 and absf(late.path_length() - late.length) < 0.4, "the late joiner's fuse is laid out from the bomb (%.2f m)" % (late.length if late != null else -1.0))
	var late_scrap: Node = kit.cords.get(scrap_id)
	check(late_scrap != null and late_scrap.tip().distance_to(bomb.global_position) > 2.0, "and the scrap lies where the host has it")

	# ---- 点火：離れた人には付けられない。線の先で付けると、両方の画面で火が進む ----
	reply = await request("far")
	kit.h_light.rpc_id(1, id, 1)
	reply = await request("snapshot")
	check(reply["view"]["links"][id] == [bomb.pid, 0, false], "the fuse cannot be lit from far away")
	reply = await request("go", Vector3(2.9, 0.1, 0.8))
	kit.h_light.rpc_id(1, id, 1)
	reply = await request("snapshot")
	check(reply["view"]["links"].has(id) and reply["view"]["links"][id][2] and reply["view"]["fuse"] < 0.0, "the participant lights the tip on the host")
	check(await until(func() -> bool: return kit.cords.has(id) and kit.cords[id].burning), "the fire shows on the participant's fuse")
	var burnt: float = kit.cords[id].length
	check(await until(func() -> bool: return not kit.cords.has(id) or kit.cords[id].length < burnt - 0.3), "and eats the fuse there too")
	# 燃えている途中：ホストの長さと、ずれていない
	reply = await request("snapshot")
	if reply["view"]["lengths"].has(id) and kit.cords.has(id):
		check(absf(float(reply["view"]["lengths"][id]) - kit.cords[id].length) < 0.35, "the fire is at the same place on both screens (host %.2f m, participant %.2f m)" % [reply["view"]["lengths"][id], kit.cords[id].length])

	# ---- 燃え尽きる：爆発の合図が届く。準備中は音と煙だけで、火薬は減らない。こぼれた粉には火が移る ----
	reply = await request("burst")
	check(not reply["view"]["links"].has(id) and not reply["view"]["has_cord"], "the fuse burns down to the bomb on the host")
	check(reply["view"]["powder"] == expected["powder"], "a rehearsal pop uses up no powder")
	check(await until(func() -> bool: return rehearsal_pop_seen()), "the burst signal reaches the participant (a small pop shows)")
	check(await until(func() -> bool: return not kit.cords.has(id) and not bomb.has_cord), "the burnt fuse is gone on the participant")
	reply = await request("settle")
	await sees(reply["view"], cords + powder, "afterwards both screens agree again")
	check(reply["view"]["piles"] == 0, "the blast set the spilled powder alight")

	# ---- ホストの制作班が操作した結果も、参加者に届く ----
	reply = await request("coil_here")
	game.h_grab.rpc_id(1, kit.coil.pid)
	check(await until(func() -> bool: return game.local_player().held == kit.coil.pid), "the participant picks up the coil again")
	kit.h_connect.rpc_id(1)
	reply = await request("walk", Vector3(1.5, 0, 0))
	game.h_release.rpc_id(1)
	reply = await request("host_light")
	var relit: Dictionary = reply["view"]
	check(relit["links"].values().any(func(link: Array) -> bool: return link[0] == bomb.pid and link[2]), "the host crew lights a fresh fuse")
	check(await until(func() -> bool: return kit.bomb_cord() != null and kit.bomb_cord().burning), "what the host lit burns on the participant's screen")
