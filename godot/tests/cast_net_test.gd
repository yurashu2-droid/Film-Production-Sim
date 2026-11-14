extends "res://tests/pair_net_base.gd"
# 見立て（配役）の二人通信：
#   参加者が付けた役はホストに届く / ホストが付けた役は参加者の flow.casting と flow.role_of() に出る /
#   役を外せる / 配役表（cast_sheet）と依頼主の好み（likes）が両方で同じ / 途中参加でも届く。
#   遠い人・台本にない役・知らない物の依頼は、ホストが断る。
# 会社での準備中（phase 2）のまま確かめる。出発も到着も使わない。
#   godot --headless --path godot res://tests/cast_net_test.tscn -- --cast-net-test-host      （参加者は -client）

# 見る物（種類）。専用の小道具と、廃材置き場の物
const WATCH := ["scrap_toilet", "fish", "tomato_monster", "scrap_bus", "carton"]
# 軽トラ（HOME_TRUCK）の西側に並べる。どれも立ったまま動かない
const PLACES := {
	"scrap_toilet": Vector3(-3.8, 0.3, 2.0),
	"fish": Vector3(-2.4, 0.3, 2.0),
	"tomato_monster": Vector3(-5.6, 0.3, 1.2),
	"scrap_bus": Vector3(-5.6, 0.3, -1.4),
	"carton": Vector3(-0.8, 0.3, 2.2),
}
const CLIENT_SPOT := Vector3(-3.0, 0.1, 0.0)
const HOST_SPOT := Vector3(-3.0, 0.1, -1.8)
const FAR_SPOT := Vector3(-12.0, 0.1, -12.0)


func configure() -> void:
	prefix = "CAST_NET"
	port = 24851
	flag = "cast-net-test"
	budget = 50.0


func after_game() -> void:
	# 定期の送り直しに頼らず、cast_set 自身の送信で届くことを確かめる
	game.production.set_physics_process(false)


func view() -> Dictionary:
	var flow: Node = game.production
	var pids := {}
	var roles := {}
	for kind: String in WATCH:
		var prop: Node = first(kind)
		pids[kind] = prop.pid
		roles[kind] = flow.role_of(prop)
	# 物の上に出る見立ての札（制作班の画面にだけ出る）
	var tags := {}
	for pid: int in game._cast_dress:
		tags[pid] = str(game._cast_dress[pid].role)
	return {"phase": flow.phase, "story": flow.story(), "likes": flow.likes(), "casting": flow.casting.duplicate(),
		"pids": pids, "roles": roles, "sheet": flow.cast_sheet(), "tags": tags}


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var base: Vector3 = game.production.HOME_TRUCK
	match action:
		"stage":
			for kind: String in PLACES:
				place(first(kind), base + PLACES[kind])
			crew_to(1, base + HOST_SPOT)
			crew_to(who, base + CLIENT_SPOT)
		"near":
			crew_to(who, base + CLIENT_SPOT)
		"far":
			crew_to(who, base + FAR_SPOT)
		"cast":
			# ホストの制作班が付ける（近くで Y を押したのと同じ道筋）
			game.h_cast(int(arg[0]), str(arg[1]))
	# ホスト自身の札は次のフレームで変わるので、落ち着くまで待ってから見せる
	await frames(3)
	return {}


func client_run() -> void:
	var flow: Node = game.production
	var toilet: Node = first("scrap_toilet")
	var fish: Node = first("fish")
	var tomato: Node = first("tomato_monster")
	var bus: Node = first("scrap_bus")
	var same := ["casting", "roles", "sheet", "tags"]

	# ---- 依頼を受ける前は、役がない ----
	var reply: Dictionary = await request("hello")
	check(reply["view"]["pids"] == view()["pids"], "both peers number the props the same way")
	check(reply["view"]["phase"] == 0 and flow.phase == 0 and (reply["view"]["casting"] as Dictionary).is_empty() and flow.casting.is_empty()
		and reply["view"]["roles"]["tomato_monster"] == "" and view()["roles"]["tomato_monster"] == "", "before a job is taken nothing is cast and nothing has a role")

	# 参加者が依頼を受ける（誰でもできる）。台本の役と、依頼主の好みが決まる
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2 and flow.story() == "kaiju"), "the job taken by the participant starts on both peers")
	reply = await request("snapshot")
	check(reply["view"]["story"] == "kaiju" and not (reply["view"]["likes"] as Array).is_empty(), "the host has the job and the client's taste")
	await sees(reply["view"], ["likes", "roles", "casting", "sheet"], "the client's taste and the dedicated roles are the same on both peers")
	check(view()["roles"]["tomato_monster"] == "monster" and view()["roles"]["carton"] == "city" and view()["roles"]["scrap_toilet"] == "", "dedicated props come with their role and junk has none")

	# ---- 見立てる物と制作班を、軽トラの西側へ ----
	reply = await request("stage")

	# 参加者が付けた役が、ホストに届く（ホストが認めたものが、参加者の画面に戻る）
	game.h_cast.rpc_id(1, toilet.pid, "monster")
	reply = await request("snapshot")
	check(reply["view"]["casting"].get(toilet.pid, "") == "monster" and reply["view"]["roles"]["scrap_toilet"] == "monster", "a role set by the participant reaches the host")
	check(str(reply["view"]["tags"].get(toilet.pid, "")) == "monster", "and the host's screen dresses the toilet as the monster")
	await sees(reply["view"], same, "the host's decision comes back into the participant's own flow.casting and flow.role_of(), and its label shows")

	# ホストが付けた役が、参加者の画面に出る
	reply = await request("cast", [fish.pid, "boom"])
	check(reply["view"]["casting"].get(fish.pid, "") == "boom" and reply["view"]["roles"]["fish"] == "boom", "the host casts the rubber fish as the explosion")
	await sees(reply["view"], same, "a role set by the host shows in the participant's flow.casting and flow.role_of()")

	# 専用の役を持たない物にも、参加者が街役を付ける。三つの役がそろい、配役表が両方で同じになる
	game.h_cast.rpc_id(1, bus.pid, "city")
	reply = await request("snapshot")
	var sheet: Dictionary = reply["view"]["sheet"]
	var decided := 0
	for row: Dictionary in sheet["rows"]:
		decided += 1 if int(row["grade"]) >= 0 else 0
	check(decided == 3 and (sheet["combos"] as Array).size() >= 1 and int(sheet["liked"]["roles"]) >= 1, "the casting sheet has all three roles, a combo and the client's taste")
	await sees(reply["view"], same + ["likes"], "the casting sheet, the open roles and the client's taste are the same on both peers")

	# ---- 断られる依頼 ----
	var before: Dictionary = reply["view"]["casting"].duplicate()
	game.h_cast.rpc_id(1, toilet.pid, "castle")
	game.h_cast.rpc_id(1, 987654, "monster")
	reply = await request("snapshot")
	check(reply["view"]["casting"] == before, "a role the script does not have and an unknown prop are refused")
	reply = await request("far")
	game.h_cast.rpc_id(1, fish.pid, "city")
	reply = await request("snapshot")
	check(reply["view"]["casting"] == before and reply["view"]["roles"]["fish"] == "boom", "a participant who is far from the prop cannot cast it")
	await sees(reply["view"], same, "a refused request changes nothing on the participant either")
	reply = await request("near")

	# ---- 役を外す ----
	game.h_cast.rpc_id(1, toilet.pid, "")
	reply = await request("snapshot")
	check(not (reply["view"]["casting"] as Dictionary).has(toilet.pid) and reply["view"]["roles"]["scrap_toilet"] == "", "taking the role off junk leaves no entry on the host")
	check(int(reply["view"]["sheet"]["rows"][0]["grade"]) == -1, "and the monster row of the host's casting sheet is open again")
	await sees(reply["view"], same, "the participant's casting and casting sheet lose it too")
	# 専用の役がある物は、外した印（空）が残る。付け直すと、もとの役に戻って印が消える
	game.h_cast.rpc_id(1, tomato.pid, "")
	reply = await request("snapshot")
	check(reply["view"]["casting"].get(tomato.pid, "x") == "" and reply["view"]["roles"]["tomato_monster"] == "", "a dedicated prop can be taken out of its role")
	await sees(reply["view"], same, "the participant sees the dedicated prop without its role")
	game.h_cast.rpc_id(1, tomato.pid, "monster")
	reply = await request("snapshot")
	check(not (reply["view"]["casting"] as Dictionary).has(tomato.pid) and reply["view"]["roles"]["tomato_monster"] == "monster", "casting it back to its own role clears the entry")
	await sees(reply["view"], same, "the participant sees the dedicated prop back in its role")

	# ---- 途中参加：入り直した人にも、いまの配役が届く ----
	game.h_cast.rpc_id(1, tomato.pid, "")
	reply = await request("cast", [toilet.pid, "monster"])
	var expected: Dictionary = reply["view"]
	check((expected["casting"] as Dictionary).size() == 4 and expected["casting"].get(tomato.pid, "x") == "", "the cast before the rejoin: toilet, fish, bus and the removed tomato monster")
	await rejoin()
	flow = game.production
	reply = await request("hello")
	check(reply["view"]["pids"] == view()["pids"], "the late joiner numbers the props the same way")
	await sees(expected, same + ["likes", "story", "phase"], "a late joiner receives the roles, the sheet and the taste", LATE)
