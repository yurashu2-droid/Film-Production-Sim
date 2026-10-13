extends SceneTree
# 見立て（配役）を確かめる：属性タグの表 → 役を付ける → トイレ怪獣で一本撮る → らしさとコンボの点。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/casttest.gd
const Cast := preload("res://scripts/production_cast.gd")
var game: Node
var failed := false


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CAST_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = true
	prop.restore(state)


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


func item(kind: String) -> Dictionary:
	return {"kind": kind, "label": kind, "tags": []}


func run() -> void:
	# ---- 表だけで決まること ----
	check(Cast.fit("scrap_toilet", "monster") == 0, "a toilet is a forced monster")
	check(Cast.fit("scrap_duck", "monster") == 1, "a rubber duck is a passable monster")
	check(Cast.fit("tomato_monster", "monster") == 2 and Cast.fit("dragon_skull", "monster") == 2, "dedicated monsters fit perfectly")
	check(Cast.fit("scrap_column", "castle") == 2 and Cast.fit("scrap_clock", "castle") == 2, "tall stone things make a good castle")
	check(Cast.fit("boomflat", "boom") == 1 and Cast.fit("fx", "boom") == 2, "the painted flat is passable, the machine is the real thing")
	check(Cast.fit("carton", "city") == 1 and Cast.fit("carton", "city", ["city"]) == 2, "a window drawing makes a carton a better building")
	check(Cast.cycle("scrap_duck", "kaiju", "") == "monster", "the first role offered is the best fit")
	var seen_roles: Array = []
	var role := ""
	for i in 4:
		role = Cast.cycle("scrap_duck", "kaiju", role)
		seen_roles.append(role)
	check(seen_roles.size() == 4 and seen_roles[3] == "" and "city" in seen_roles and "boom" in seen_roles, "cycling visits every role and ends with none")
	for kind: String in Cast.PROPS:
		for a: String in Cast.PROPS[kind]["attrs"]:
			var known := false
			for r: String in Cast.ROLES:
				known = known or a in Cast.ROLES[r]["likes"]
			check(known or a in Cast.THEMES or a in ["紙", "かわいい", "ジョーカー"], "attribute '%s' of %s is used somewhere" % [a, kind])

	var plain := Cast.score("kaiju", {"monster": [item("tomato_monster")], "city": [item("carton"), item("carton")], "boom": [item("boomflat")]})
	check(int(plain["coins"]) == 60 and (plain["combos"] as Array).is_empty(), "the standard set earns the monster bonus and no combo (%d)" % int(plain["coins"]))
	var toilet := Cast.score("kaiju", {"monster": [item("scrap_toilet")], "boom": [item("fish")]})
	check(int(toilet["coins"]) == -60 - 60 + 120 and (toilet["combos"] as Array).size() == 1, "two forced roles are paid back by a shared-attribute combo (%d)" % int(toilet["coins"]))
	var named := Cast.score("kaiju", {"monster": [item("scrap_toilet")], "boom": [item("scrap_poop")]})
	check((named["combos"] as Array).size() == 1 and "トイレ怪獣の必殺技" in str(named["combos"][0]["name"]) and int(named["combos"][0]["coins"]) == Cast.NAMED_COINS, "toilet monster with a poop attack is a named combo, not counted twice")
	var dragon := Cast.score("kaiju", {"monster": [item("dragon_skull")], "city": [item("carton")], "boom": [item("boomflat")]})
	check(int(dragon["coins"]) == 60 + Cast.NAMED_COINS, "the dragon breathing fire is a named combo (%d)" % int(dragon["coins"]))
	var castle := Cast.score("castle", {"castle": [item("ruin")], "moon": [item("rock")]})
	check(int(castle["coins"]) == 60 + 0 + 120, "a stone castle with a rock for a moon is a stone combo (%d)" % int(castle["coins"]))
	var trio := Cast.score("kaiju", {"monster": [item("scrap_bus")], "city": [item("scrap_kiosk"), item("scrap_lamp")], "boom": [item("scrap_crane")]})
	check((trio["combos"] as Array).any(func(c: Dictionary) -> bool: return int(c["coins"]) == 300), "three roles sharing one attribute pay the big combo")

	# 依頼主の好み：好みの属性の物を使った役の数だけ増える
	var street := {"monster": [item("scrap_bus")], "city": [item("scrap_kiosk")], "boom": [item("boomflat")]}
	var pleased := Cast.score("kaiju", street, ["街角", "乗り物"])
	var neutral := Cast.score("kaiju", street)
	check(int(pleased["liked"]["roles"]) == 2 and int(pleased["coins"]) == int(neutral["coins"]) + 2 * Cast.LIKE_COINS, "props matching the client's taste pay per role (%d)" % int(pleased["coins"]))
	check(Cast.lines(pleased).any(func(l: Array) -> bool: return "依頼主の好み" in str(l[0]) and int(l[1]) == 120), "the review shows the client's taste")

	# ---- ゲームの中で ----
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var S: Dictionary = game.S
	var monster: Node = of_kind("scrap_toilet")[0]
	var tomato: Node = of_kind("tomato_monster")[0]
	var cartons: Array = of_kind("carton")
	var fish: Node = of_kind("fish")[0]
	check(flow.role_of(tomato) == "" and game.judge.role_of(cartons[0]) == "", "nothing has a role before a job is taken")
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	check(flow.story() == "kaiju" and flow.role_of(tomato) == "monster" and flow.role_of(cartons[0]) == "city", "dedicated props come with their role")
	check(flow.likes() == ["街角", "乗り物"] and (flow.cast_sheet()["liked"]["attrs"] as Array) == ["街角", "乗り物"], "the job carries the client's taste")
	check(flow.role_of(monster) == "" and flow.role_of(fish) == "", "junk has no role until the crew decides")
	check(flow.role_of(of_kind("flat")[0]) == "", "a castle flat has no role in a monster movie")

	# 役を付ける（近くで Y を押したのと同じ道筋）
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	place(monster, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.4))
	await frames(4)
	game.h_cast(monster.pid, "monster")
	check(flow.role_of(monster) == "monster" and flow.casting.get(monster.pid, "") == "monster", "Y casts the toilet as the monster")
	check((flow.snapshot()["casting"] as Dictionary).has(monster.pid), "casting travels in the snapshot")
	game.h_cast(of_kind("scrap_arch")[0].pid, "monster")
	check(flow.role_of(of_kind("scrap_arch")[0]) == "", "a prop out of reach cannot be cast")
	check(not flow.cast_set(game.fx.pid, "city") and not flow.cast_set(monster.pid, "castle"), "the effects machine is locked and roles outside the script are refused")
	check(flow.cast_set(tomato.pid, "") and flow.role_of(tomato) == "" and flow.casting.has(tomato.pid), "a dedicated prop can be taken out of its role")
	check(flow.cast_set(tomato.pid, "monster") and not flow.casting.has(tomato.pid), "casting back to the default clears the entry")
	check(flow.cast_set(fish.pid, "boom"), "the rubber fish becomes the monster's attack")
	var sheet: Dictionary = flow.cast_sheet()
	print("CAST sheet=", sheet)
	check(sheet["rows"][0]["role"] == "monster" and int(sheet["rows"][0]["grade"]) == 0 and "トイレ" in str(sheet["rows"][0]["items"]), "the casting sheet lists the toilet as a forced monster")
	check(int(sheet["rows"][1]["grade"]) == -1, "the city is still undecided (nothing loaded)")
	check((sheet["combos"] as Array).size() == 1 and int(sheet["coins"]) == 0, "the sheet previews the bathroom combo")
	# 配役表は、台本のページにだけ出る。発注や積み込みの画面には写さない（監督だけが知っている）
	check(not flow.has_method("needs_status") and not flow.loadout().has("checks") and "怪獣役" not in flow.loadout_status(), "the casting sheet is no longer copied onto the order and packing screens")

	# 積んで現場へ
	for prop: Node in [monster, fish, cartons[0], cartons[1], cartons[2]]:
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(2)
	await frames(4)
	check((flow.cast_sheet()["rows"] as Array).all(func(row: Dictionary) -> bool: return int(row["grade"]) >= 0), "the loaded truck fills the casting sheet")
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "crew arrives at the location")
	print("CAST pids toilet=", monster.pid, " tomato=", tomato.pid, " toilet at ", monster.global_position, " tomato at ", tomato.global_position)
	var nearest := INF
	for pid: int in game.props:
		var q: Node3D = game.props[pid]
		if not q.absent and q.global_position.x > 30.0:
			nearest = minf(nearest, Vector2(q.global_position.x, q.global_position.z).length())
	print("CAST nearest company prop from the set centre = %.1f m" % nearest)
	check(flow.at_site(game.film) and not flow.at_site(tomato) and game.judge.role_of(tomato) == "", "what stayed at the company is not on set")

	place(game.film, Vector3(0, 0, 6.0))
	place(monster, Vector3(-0.8, 0, 3.9), PI)
	place(cartons[0], Vector3(-1.6, 0, -1.6))
	place(cartons[1], Vector3(-0.2, 0, -2.0), 0.4)
	place(cartons[2], Vector3(3.0, 0, -1.4), -0.3)
	place(fish, Vector3(5.0, 0.1, 3.0))
	fish.set_fixed(false)
	place(game.spots[0], Vector3(-2.6, 0, 3.4), PI)
	place(game.spots[1], Vector3(3.4, 0, 3.4), PI)
	game.actors[0].mark.restore([Vector3(0.7, 0.05, 0.0), Quaternion.IDENTITY, false])
	game.actors[1].mark.restore([Vector3(1.9, 0.05, 0.4), Quaternion.IDENTITY, false])
	await frames(20)
	game._aim_camera(Vector3(0.6, 0.75, 0.0), 56.0)
	game._aim_spot(game.spots[0], game.actors[0].global_position + Vector3(0, 1.2, 0))
	game._aim_spot(game.spots[1], game.actors[1].global_position + Vector3(0, 1.2, 0))
	game.h_standby()
	await frames(40)
	print("CAST hints(prep)=", game.live["hints"], " monster=", game.judge.frame["monster"])
	var cam: Camera3D = game.film.view_cam
	print("CAST cam at ", cam.global_position, " toilet centre ", monster.center_global(), " up=", monster.global_basis.y, " screen=", cam.unproject_position(monster.center_global()) / Vector2(game.film.view.size))
	check((game.live["hints"] as Array).is_empty(), "the toilet reads as a monster and the fish as its attack")
	check(int(game.judge.frame["monster"]["pid"]) == monster.pid, "the judge follows the cast monster")
	check(game.is_action_prop(monster) and game.prop_action_hint(monster) == "倒す", "a cast monster can be toppled with F")

	# 役を外すと、怪獣がいないと言われる
	flow.cast_set(monster.pid, "")
	await frames(20)
	check((game.live["hints"] as Array).any(func(h: String) -> bool: return "怪獣役の物が無い" in h), "without a cast monster the hint asks for one")
	flow.cast_set(monster.pid, "monster")
	await frames(20)

	game.h_take()
	await frames(200)
	check(game.state == S.TAKE, "take starts")
	game.h_cast(fish.pid, "")
	check(flow.role_of(fish) == "boom", "roles cannot be changed during a take")
	game.h_cue(1)
	await frames(200)
	check(game.judge.passed()[0], "scene 1: the toilet towers over the city")
	var fish_before: Vector3 = fish.global_position
	game.h_cue(2)
	await frames(12)
	var flying: Vector3 = fish.global_position
	print("CAST fish launched from ", fish_before, " now ", flying, " v=", fish.linear_velocity)
	check(flying.distance_to(fish_before) > 2.0 and flying.y > 0.8, "the attack is fired from the monster")
	await frames(120)
	check(game.judge.passed()[1] and game.judge.boom_src == fish.pid, "scene 2: the fish lands behind the fleeing pair and counts as the explosion")
	game.h_cue(3)
	await frames(60)
	place(monster, Vector3(-1.5, 0.0, 1.6))
	monster.set_fixed(false)
	game.local_player().position = Vector3(-2.6, 0.1, 2.6)
	await frames(20)
	game.h_prop_action(monster.pid)
	await frames(460)
	check(game.state == S.RESULT and not game.takes.is_empty(), "take ends after all three scenes")
	if not game.takes.is_empty():
		var take: Dictionary = game.takes[0]
		check(not false in take["passed"], "all three scenes pass with a toilet and a fish")
		var report: Dictionary = take["extras"]["cast"]
		print("CAST report=", report)
		for line: Array in Cast.lines(report):
			print("  ", line[0], "  ", line[1])
		var by_role := {}
		for r: Dictionary in report["roles"]:
			by_role[r["role"]] = r
		check(by_role.has("monster") and int(by_role["monster"]["grade"]) == 0 and "トイレ" in str(by_role["monster"]["items"]), "the toilet is scored as a forced monster")
		check(by_role.has("city") and int(by_role["city"]["grade"]) == 1, "the cartons are a passable city")
		check(by_role.has("boom") and "魚" in str(by_role["boom"]["items"]), "the fish is scored as the explosion")
		check((report["combos"] as Array).size() == 1 and int(report["coins"]) == 0, "the bathroom combo pays back both forced roles")
		var bonus: int = 150 if take["extras"].get("bonus_ok", false) else 0
		check(flow.take_fee(0) == 1200 + bonus + int(report["coins"]), "the fee adds the casting coins (%d)" % flow.take_fee(0))
		game.h_deliver(0)
		await frames(10)
		check(flow.phase == 5 and flow.last_flubs.any(func(l: String) -> bool: return "コンボ" in l) and flow.last_flubs.any(func(l: String) -> bool: return "勢いはあった" in l), "the settlement mentions the combo and the forced role")
		game.h_return_office()
		await frames(10)
		check(flow.casting.is_empty() and flow.role_of(monster) == "", "casting is cleared for the next job")
	print("CASTTEST_FAIL" if failed else "CASTTEST_OK")
	quit(1 if failed else 0)
