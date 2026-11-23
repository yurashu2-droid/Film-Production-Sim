extends "res://tests/pair_net_base.gd"
# キャラの特技の二人通信：
#   参加者（段ボール頭）が K でしまう・出す → ホストで実行され、両方の画面で同じ中身になる（物の消え方・頭の上の見た目・手に持った物）/
#   入らない物は断られる / ホスト（ロボット）のランプが参加者の画面でも点く・消える /
#   仲間（ホスト）が、参加者の頭から F で1つ取り出せる。離れていると取り出せない /
#   参加者が抜けると、中身は足元にこぼれる / あとから入った人にも、ランプと頭の中身が届く。
#   あとの4人（TALENT4）：参加者のショール（かける・ずれる・外す）、「止まれ！」（落ちてくる物が止まる・札が倒れる）、
#   びよーん首、毛ひも（荷台のフックに結ぶ）が、両方の画面で同じになる。あとから入った人にも届く。
# 会社での準備中（phase 2）のまま確かめる。出発も到着も使わない。
#   godot --headless --path godot res://tests/cast_talent_net_test.tscn -- --cast-talent-net-test-host      （参加者は -client）

const WATCH := ["fish", "crown", "scrap_pie", "scrap_toilet"]
# 軽トラ（HOME_TRUCK）の西側に並べる。固定はしない（固定した物は、頭にしまえない）
const PLACES := {
	"fish": Vector3(-2.4, 0.3, 1.2),
	"crown": Vector3(-3.6, 0.3, 1.2),
	"scrap_pie": Vector3(-3.0, 0.3, -2.9),
	"scrap_toilet": Vector3(-4.6, 0.3, 0.4),
}
const CLIENT_SPOT := Vector3(-3.0, 0.1, 0.0)
const HOST_SPOT := Vector3(-3.0, 0.1, -1.8)
const FAR_SPOT := Vector3(-12.0, 0.1, -12.0)


func configure() -> void:
	prefix = "CAST_TALENT_NET"
	port = 24856
	flag = "cast-talent-net-test"
	budget = 150.0


func after_game() -> void:
	game.production.set_physics_process(false)


# 置き直す（固定しない）
func lay(prop: Node, pos: Vector3) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion.IDENTITY
	state[2] = false
	prop.restore(state)


# その人の画面に見える状態：頭の中身・ランプ・物の消え方・頭の上の縮めた見た目・おなかの光・手に持った物
func view() -> Dictionary:
	var talent: Node = game.talent
	var lamps: Array = talent.lamps.keys()
	lamps.sort()
	var seen := {}
	for kind: String in WATCH:
		var prop: Node3D = first(kind)
		seen[kind] = [prop.absent, prop.stored_in, prop.global_position.y > -10.0]
	var casts := {}
	var heads := {}
	var lit := {}
	var held := {}
	for who: int in game.players:
		var pl: Node = game.players[who]
		casts[who] = pl.vis.tag
		held[who] = pl.held
		var rack: Node = pl.vis.skel.get_node_or_null("TalentStow")
		heads[who] = rack.get_child_count() if rack != null else 0
		var lamp: Node3D = pl.vis.get_node_or_null("TalentLamp")
		lit[who] = lamp != null and lamp.visible
	# あとの4人：ショール（かかっている物・ずれ・布の見た目・肩の枚数）、首、毛（束・残り・頭の房）、止まれ！の札、掛けたひも
	var shawls := {}
	for pid: int in talent.shawls:
		shawls[pid] = [int(talent.shawls[pid][0]), snappedf(float(talent.shawls[pid][1]), 0.01)]
	var cloths := {}
	for kind: String in WATCH:
		cloths[kind] = first(kind).get_node_or_null("TalentShawl") != null
	var necks: Array = talent.necks.keys()
	necks.sort()
	var hair := {}
	for pid: int in talent.hair:
		hair[pid] = [int(talent.hair[pid][0]), bool(talent.hair[pid][1]), snappedf(float(talent.hair[pid][2]), 0.1)]
	var shoulders := {}
	var rise := {}
	var tufts := {}
	var paddle := {}
	for who: int in game.players:
		var crew: Node = game.players[who]
		shoulders[who] = talent.shown_shawls_left(who)
		rise[who] = snappedf(crew.neck, 0.1)
		var locks: Node = crew.vis.skel.get_node_or_null("TalentTufts")
		tufts[who] = locks.find_children("*", "MeshInstance3D", true, false).size() if locks != null else -1
		paddle[who] = talent.halt_ready(who) >= 1.0
	var lashes: Array = []
	var ids: Array = game.cargo_kit.lashes.keys()
	ids.sort()
	for lash_id: int in ids:
		var lash: Dictionary = game.cargo_kit.lashes[lash_id]
		lashes.append([int(lash["a"]), int(lash["b"]), int(lash.get("coil", 0))])
	return {"phase": game.production.phase, "stowed": talent.stowed.duplicate(true), "lamps": lamps, "props": seen,
		"casts": casts, "heads": heads, "lit": lit, "held": held,
		"shawls": shawls, "cloths": cloths, "shoulders": shoulders, "necks": necks, "rise": rise,
		"hair": hair, "tufts": tufts, "paddle": paddle, "lashes": lashes}


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var base: Vector3 = game.production.HOME_TRUCK
	match action:
		"stage":
			for kind: String in PLACES:
				lay(first(kind), base + PLACES[kind])
			crew_to(1, base + HOST_SPOT)
			crew_to(who, base + CLIENT_SPOT)
		"near":
			crew_to(1, base + HOST_SPOT)
		"far":
			crew_to(1, base + FAR_SPOT)
		"cast":
			game.h_select_cast(game.PLAYER_CASTS.find(str(arg)))
		"lamp", "draw":
			game.talent.host_use(1)                       # ホストの制作班が K を押す
		"stow":
			game.talent.host_use(1, first(str(arg)).pid)  # ホストの制作班が、物を見て K
		"take":
			game.talent.host_take(1, who)                 # ホストの制作班が、参加者の頭を見て F
		"release":
			game.h_release()
		"push":
			# ホストが、ショールを風で押す
			game.talent.host_shawl_push(first(str(arg)).pid, Vector3(0.4, 0, 0))
		"shawl":
			game.talent.host_use(1, first(str(arg)).pid)  # ホストの制作班が、物を見て K
		"drop":
			# 参加者の目の前の高い所から、物を落とす
			var crew: Node = game.players[who]
			lay(first(str(arg)), crew.global_position + crew.flat_forward() * 2.5 + Vector3(0, 6.0, 0))
			await wait(0.3)
			return {"y": first(str(arg)).global_position.y}
		"halted":
			var prop: Node3D = first(str(arg))
			return {"halted": game.talent.halted(prop.pid), "y": prop.global_position.y, "speed": prop.linear_velocity.length(), "gravity": prop.gravity_scale}
		"bed":
			# 参加者を、荷台のフックの外側へ
			var truck: Node3D = game.truck
			var local: Vector3 = truck.hooks[int(arg)]
			var spot: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
			var to: Vector3 = game.cargo_kit.hook_at(int(arg)) - spot
			crew_to(who, Vector3(spot.x, truck.global_position.y + 0.1, spot.z), atan2(-to.x, -to.z))
	# 中身がこぼれる処理（次の物理コマ）と、頭の上の見た目（次の描画）が済んでから見せる
	await wait(0.25)
	return {}


func client_run() -> void:
	var flow: Node = game.production
	var talent: Node = game.talent
	var mine: int = multiplayer.get_unique_id()
	var fish: Node = first("fish")
	var crown: Node = first("crown")
	var toilet: Node = first("scrap_toilet")
	var contents := ["stowed", "props", "heads", "held"]

	# ---- 依頼を受けて、参加者が段ボール頭になる ----
	var reply: Dictionary = await request("hello")
	game.h_accept_job.rpc_id(1, job_of("castle"))
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	game.h_select_cast.rpc_id(1, game.PLAYER_CASTS.find("09"))
	reply = await request("stage")
	check(reply["view"]["casts"][mine] == "09" and reply["view"]["casts"][1] == "M02", "the host sees a box head and a robot")
	await sees(reply["view"], ["phase", "casts", "props"], "the participant sees the same crew and props")
	check(talent.usable() and talent.cast_of(mine) == "09", "the participant may use the talent")

	# ---- 入らない物は断られる ----
	talent.h_use.rpc_id(1, toilet.pid, false)
	reply = await request("snapshot")
	check((reply["view"]["stowed"] as Dictionary).is_empty() and reply["view"]["props"]["scrap_toilet"] == [false, 0, true], "the host refuses a toilet")
	await sees(reply["view"], contents, "nothing changes on the participant's screen")

	# ---- しまう：見て K ----
	talent.h_use.rpc_id(1, fish.pid, false)
	reply = await request("snapshot")
	check(reply["view"]["stowed"] == {mine: [fish.pid]} and reply["view"]["props"]["fish"] == [true, -mine, false], "K from the participant stows the fish on the host")
	check(reply["view"]["heads"][mine] == 1, "the host sees it on the participant's head")
	await sees(reply["view"], contents, "the participant sees the fish gone and on its own head")
	check(talent.slots(game.local_player()).size() == 1 and game.production_hud.talent_slots.visible, "the participant's slots show it")

	# ---- しまう：持って K ----
	game.h_grab.rpc_id(1, crown.pid)
	check(await until(func() -> bool: return game.local_player().held == crown.pid), "the participant holds the crown")
	talent.h_use.rpc_id(1, 0, false)
	reply = await request("snapshot")
	check(reply["view"]["stowed"] == {mine: [fish.pid, crown.pid]} and reply["view"]["held"][mine] == 0, "K with a held prop stows it and empties the hand")
	await sees(reply["view"], contents, "the participant's screen agrees")

	# ---- 出す：手ぶらの K で、最後に入れた物が手に来る ----
	talent.h_use.rpc_id(1, 0, false)
	reply = await request("snapshot")
	check(reply["view"]["stowed"] == {mine: [fish.pid]} and reply["view"]["held"][mine] == crown.pid and reply["view"]["props"]["crown"][0] == false, "K with empty hands takes the crown out into the participant's hand")
	await sees(reply["view"], contents, "the participant sees the crown in its hand")
	check(await until(func() -> bool: return crown.global_position.distance_to(game.local_player().global_position) < 3.0), "the crown arrives near the participant on its own screen")
	talent.h_use.rpc_id(1, 0, false)
	reply = await request("snapshot")
	check(reply["view"]["stowed"] == {mine: [fish.pid, crown.pid]}, "and K puts it back")
	await sees(reply["view"], contents, "both screens show two props in the head")

	# ---- ホストのロボットのランプ ----
	reply = await request("lamp")
	check(reply["view"]["lamps"] == [1] and reply["view"]["lit"][1], "the host's robot lights its lamp")
	await sees(reply["view"], ["lamps", "lit"], "the lamp shines on the participant's screen")
	reply = await request("lamp")
	check((reply["view"]["lamps"] as Array).is_empty() and not reply["view"]["lit"][1], "and switches it off")
	await sees(reply["view"], ["lamps", "lit"], "the lamp goes out on the participant's screen")
	reply = await request("lamp")
	await sees(reply["view"], ["lamps", "lit"], "and on again")

	# ---- 仲間が頭から取り出す（F）----
	reply = await request("far")
	reply = await request("take")
	check(reply["view"]["stowed"] == {mine: [fish.pid, crown.pid]} and reply["view"]["held"][1] == 0, "a crew member far away cannot reach into the head")
	reply = await request("near")
	reply = await request("take")
	check(reply["view"]["stowed"] == {mine: [fish.pid]} and reply["view"]["held"][1] == crown.pid, "next to the box head, F takes the last prop into the host's hand")
	await sees(reply["view"], contents, "the participant sees its head emptied by one and the host holding the crown")
	reply = await request("release")

	# ---- 参加者が抜ける：中身は足元にこぼれる。入り直した人には、ランプが届く ----
	await rejoin()
	flow = game.production
	talent = game.talent
	var second: int = multiplayer.get_unique_id()
	reply = await request("hello")
	check((reply["view"]["stowed"] as Dictionary).is_empty() and reply["view"]["props"]["fish"] == [false, 0, true], "when the box head leaves, the fish spills out on the host")
	check(reply["view"]["lamps"] == [1], "the host's lamp is still on")
	await sees(reply["view"], ["stowed", "props", "lamps", "lit"], "a late joiner sees the spilled fish and the lit lamp", LATE)

	# ---- ホストが段ボール頭になって、物をしまう。入り直した人には、頭の中身が届く ----
	reply = await request("cast", "09")
	check((reply["view"]["lamps"] as Array).is_empty() and reply["view"]["casts"][1] == "09", "the lamp goes out when the host becomes a box head")
	await sees(reply["view"], ["lamps", "lit", "casts"], "the participant sees that too")
	reply = await request("stow", "scrap_pie")
	var pie: Node = first("scrap_pie")
	check(reply["view"]["stowed"] == {1: [pie.pid]} and reply["view"]["heads"][1] == 1, "the host stows the pie")
	await sees(reply["view"], ["stowed", "props", "heads"], "the participant sees the pie on the host's head")
	await rejoin()
	reply = await request("hello")
	check(reply["view"]["stowed"] == {1: [first("scrap_pie").pid]} and multiplayer.get_unique_id() != second, "the host still has the pie when someone joins again")
	await sees(reply["view"], ["stowed", "props", "heads", "casts"], "a late joiner receives the head contents and sees them on the head", LATE)
	reply = await request("draw")
	check((reply["view"]["stowed"] as Dictionary).is_empty() and reply["view"]["held"][1] == first("scrap_pie").pid, "the host takes the pie out again")
	await sees(reply["view"], contents, "and the late joiner sees it come out")
	reply = await request("release")

	# ---- TALENT4：あとの4人 ----
	talent = game.talent          # 入り直したので、ゲームは作り直されている
	mine = multiplayer.get_unique_id()
	toilet = first("scrap_toilet")
	fish = first("fish")
	var four := ["shawls", "cloths", "shoulders", "necks", "rise", "hair", "tufts", "paddle", "lashes", "casts"]
	# ドレスの人：ショールをかける・ずれる・外す
	game.h_select_cast.rpc_id(1, game.PLAYER_CASTS.find("01"))
	reply = await request("stage")
	check(reply["view"]["casts"][mine] == "01" and reply["view"]["shoulders"][mine] == 2, "the host sees the participant as the dress wearer, with two shawls on the shoulders")
	await sees(reply["view"], four, "the participant sees the same")
	talent.h_use.rpc_id(1, toilet.pid, false)
	reply = await request("snapshot")
	check(reply["view"]["shawls"] == {toilet.pid: [mine, 0.0]} and reply["view"]["cloths"]["scrap_toilet"] and reply["view"]["shoulders"][mine] == 1, "K from the participant puts a shawl on the toilet on the host")
	await sees(reply["view"], four, "the participant sees the cloth on the toilet and one shawl left on its shoulder")
	check("shawl" in game.production.cast_tags(toilet), "the participant's own casting sheet counts the shawl")
	reply = await request("push", "scrap_toilet")
	check(reply["view"]["shawls"] == {toilet.pid: [mine, 0.4]}, "a push on the host slides the cloth")
	await sees(reply["view"], four, "the participant sees it slid by the same amount")
	talent.h_use.rpc_id(1, toilet.pid, false)
	reply = await request("snapshot")
	check((reply["view"]["shawls"] as Dictionary).is_empty() and not reply["view"]["cloths"]["scrap_toilet"] and reply["view"]["shoulders"][mine] == 2, "K again takes it off")
	await sees(reply["view"], four, "both shawls are back on the shoulders on both screens")

	# カエルの警官：落ちてくる物が止まる。札が倒れる
	game.h_select_cast.rpc_id(1, game.PLAYER_CASTS.find("02"))
	reply = await request("snapshot")
	check(reply["view"]["casts"][mine] == "02" and reply["view"]["paddle"][mine], "the participant becomes the frog officer, paddle up")
	await sees(reply["view"], ["casts", "paddle"], "on both screens")
	reply = await request("drop", "fish")
	talent.h_use.rpc_id(1, 0, false)
	reply = await request("halted", "fish")
	check(reply["halted"] and float(reply["y"]) > 2.0 and float(reply["speed"]) < 0.01 and float(reply["gravity"]) == 0.0, "K from the participant stops the falling fish in mid-air on the host (%.1f m up)" % float(reply["y"]))
	check(not reply["view"]["paddle"][mine], "and the paddle drops on the host")
	await sees(reply["view"], ["paddle"], "the paddle drops on the participant's screen too")
	check(await until(func() -> bool: return fish.global_position.y > 2.0), "the participant sees the fish hanging in the air")
	var shouts := 0
	for node: Node in game.get_children():
		if node is Label3D and (node as Label3D).text in ["止まれ！", "ぴたっ"]:
			shouts += 1
	check(shouts == 0, "no words float in the air on the participant's screen either")
	await wait(3.6)
	reply = await request("halted", "fish")
	check(not reply["halted"] and float(reply["gravity"]) == 1.0 and float(reply["y"]) < 2.0, "after the two seconds it falls again, gravity back")

	# ベレー帽の人：首を伸ばす・戻す
	game.h_select_cast.rpc_id(1, game.PLAYER_CASTS.find("04"))
	reply = await request("snapshot")
	talent.h_use.rpc_id(1, 0, false)
	await wait(0.6)
	reply = await request("snapshot")
	check(reply["view"]["necks"] == [mine] and is_equal_approx(float(reply["view"]["rise"][mine]), 0.5), "K from the participant stretches its neck on the host")
	await sees(reply["view"], ["necks", "rise", "casts"], "the participant's own view rises by the same height")
	check(game.local_player().vis.skel.get_node_or_null("TalentNeck") != null and is_equal_approx(game.local_player().head.position.y, 2.35), "its head is lifted on its own screen")
	talent.h_use.rpc_id(1, 0, false)
	await wait(0.6)
	reply = await request("snapshot")
	check((reply["view"]["necks"] as Array).is_empty() and is_equal_approx(float(reply["view"]["rise"][mine]), 0.0), "K again pulls it back")
	await sees(reply["view"], ["necks", "rise"], "on both screens")
	talent.h_use.rpc_id(1, 0, false)
	await wait(0.3)

	# モップの王様：毛ひもを、荷台のフックからフックへ
	game.h_select_cast.rpc_id(1, game.PLAYER_CASTS.find("06"))
	reply = await request("bed", 9)
	check((reply["view"]["necks"] as Array).is_empty() and reply["view"]["casts"][mine] == "06", "changing character pulls the neck back")
	await sees(reply["view"], ["necks", "rise", "casts", "tufts"], "the participant is the mop king with a full head of hair on both screens")
	var full_locks: int = reply["view"]["tufts"][mine]
	talent.h_use.rpc_id(1, 0, false)
	reply = await request("snapshot")
	var bundle: Node = talent.hair_coil_of(mine)
	check(bundle != null and reply["view"]["held"][mine] == bundle.pid and reply["view"]["hair"][bundle.pid] == [mine, true, 6.0], "K from the participant puts the hair bundle in its hand on the host")
	await sees(reply["view"], ["hair", "held"], "the participant sees the bundle in its hand")
	check(not bundle.absent, "the bundle is visible on the participant's screen")
	game.cargo_kit.h_hook.rpc_id(1, 4)
	await wait(0.5)
	game.cargo_kit.h_hook.rpc_id(1, 9)
	await wait(0.6)
	reply = await request("snapshot")
	check(reply["view"]["lashes"] == [[4, 9, bundle.pid]] and float(reply["view"]["hair"][bundle.pid][2]) < 5.0, "the participant ties a hair cord from hook to hook on the host (%.1f m of hair left)" % float(reply["view"]["hair"][bundle.pid][2]))
	await sees(reply["view"], ["lashes", "hair", "tufts"], "the participant sees the cord, the hair that is left, and a thinner head")
	check(int(reply["view"]["tufts"][mine]) < full_locks, "the host sees less hair on the participant's head (%d locks, was %d)" % [int(reply["view"]["tufts"][mine]), full_locks])
	talent.h_use.rpc_id(1, 0, false)
	reply = await request("snapshot")
	check(reply["view"]["held"][mine] == 0 and reply["view"]["hair"][bundle.pid][1] == false, "K again puts the bundle away")
	await sees(reply["view"], ["hair", "held", "lashes"], "on both screens")
	check(bundle.absent, "the bundle disappears on the participant's screen")

	# あとから入った人にも届く：ホストのショールと、掛けたままの毛ひも
	reply = await request("cast", "01")
	reply = await request("near")
	reply = await request("shawl", "scrap_pie")
	check((reply["view"]["shawls"] as Dictionary).size() == 1 and reply["view"]["shoulders"][1] == 1, "the host, now the dress wearer, covers the pie")
	await rejoin()
	reply = await request("hello")
	check((reply["view"]["shawls"] as Dictionary).size() == 1 and (reply["view"]["lashes"] as Array).size() == 1, "the shawl and the hair cord are still there when someone joins again")
	await sees(reply["view"], ["shawls", "cloths", "shoulders", "hair", "lashes", "necks"], "a late joiner receives the shawl, the hair that is left and the cord", LATE)
