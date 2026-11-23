extends SceneTree
# 怪獣映画の脚本を一周確かめる（受注 → 積む → 移動 → 遠近法で撮る → 倒して勝利）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/kaijutest.gd
# --shots を付けて画面つきで動かすと tests/shots/kaiju に画像を残す。
var game: Node
var failed := false
var shots := false
var shot_n := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("KAIJU_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func shot(tag: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	shot_n += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/kaiju"))
	root.get_texture().get_image().save_png("res://tests/shots/kaiju/%02d_%s.png" % [shot_n, tag])
	game.film.view.get_texture().get_image().save_png("res://tests/shots/kaiju/%02d_%s_film.png" % [shot_n, tag])


func place(prop: Node, pos: Vector3, yaw: float = 0.0, lying: bool = false) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	var q := Quaternion(Vector3.UP, yaw)
	if lying:
		q = q * Quaternion(Vector3.RIGHT, PI * 0.5)
	state[1] = q
	state[2] = true
	prop.restore(state)


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


func run() -> void:
	shots = "--shots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	await frames(10)
	var flow: Node = game.production
	var S: Dictionary = game.S
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	check(job_index >= 0, "a monster-movie job exists")
	game.h_accept_job(job_index)
	check(flow.phase == 2 and game.judge.story == "kaiju", "accepting the job switches the judge to the monster script")
	game.h_open_order()
	check(game.scene_titles()[0] == flow.JOBS[job_index]["scenes"][0] and game.film_title() == flow.JOBS[job_index]["title"], "HUD titles follow the job")
	game.h_order_confirm()
	await frames(8)
	check(flow.phase == 2, "packing starts without buying anything")

	var monster: Node = of_kind("tomato_monster")[0]
	var cartons: Array = of_kind("carton")
	var boom: Node = of_kind("boomflat")[0]
	check(cartons.size() >= 2, "at least two cartons for the city")
	check(str(flow.cast_sheet()["rows"][0]["role"]) == "monster" and int(flow.cast_sheet()["rows"][0]["grade"]) < 0, "casting sheet has no monster before loading")
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	for prop: Node in [monster, boom, cartons[0], cartons[1], cartons[2]]:
		# 手の届く所まで運んだことにして、持って積む
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(2)
	await frames(4)
	var status: String = flow.loadout_status()
	print("KAIJU loadout=", status.replace("
", " | "))
	check((flow.cast_sheet()["rows"] as Array).all(func(row: Dictionary) -> bool: return int(row["grade"]) >= 0), "casting sheet is filled by tomato monster, cartons and boom flat")
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "crew arrives at the location")

	# 遠近法の配置：怪獣はカメラのすぐ手前、街と役者は奥
	place(game.film, Vector3(0, 0, 6.0))
	place(monster, Vector3(-0.95, 0, 4.55))
	place(cartons[0], Vector3(-1.6, 0, -1.6))
	place(cartons[1], Vector3(-0.2, 0, -2.0), 0.4)
	place(cartons[2], Vector3(3.0, 0, -1.4), -0.3)
	place(boom, Vector3(1.4, 0, -4.2))
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
	var hints: Array = game.live["hints"]
	print("KAIJU hints(prep)=", hints, " monster=", game.judge.frame["monster"], " city_n=", game.judge.frame["city_n"], " city_max=%.2f" % game.judge.frame["city_max"])
	check(hints.is_empty(), "preview says the forced-perspective setup is ready")
	await shot("setup")

	# 怪獣を奥へ下げると「小さい」と言われる
	place(monster, Vector3(-1.6, 0, -3.0))
	await frames(30)
	check(game.live["hints"].any(func(h: String) -> bool: return "怪獣が小さい" in h), "a far-away monster is reported as too small")
	place(monster, Vector3(-0.95, 0, 4.55))
	await frames(30)

	game.h_take()
	await frames(200)
	check(game.state == S.TAKE, "take starts")
	game.h_cue(1)
	await frames(200)
	check(game.judge.passed()[0], "scene 1: the monster towers over the city")
	await shot("scene1")
	game.h_cue(2)
	await frames(130)
	check(game.judge.passed()[1], "scene 2: explosion behind the fleeing pair")
	await shot("scene2")
	game.h_cue(3)
	await frames(260)
	check(not game.judge.passed()[2] and game.state == S.TAKE, "scene 3 waits until the monster is knocked over")
	check(game.live["hints"].any(func(h: String) -> bool: return "怪獣を倒す" in h), "hint tells the crew to topple the monster")
	# 誰かが近づいて F で倒す
	place(monster, Vector3(-1.5, 0.0, 1.6))
	monster.set_fixed(false)
	game.local_player().position = Vector3(-2.6, 0.1, 2.6)
	await frames(20)
	check(game.is_action_prop(monster) and game.prop_action_hint(monster) == "倒す", "the monster offers a topple action")
	game.h_prop_action(monster.pid)
	await frames(30)
	check(monster.global_basis.y.y < 0.6 and game.prop_action_hint(monster) == "起こす", "F knocks the monster over")
	await frames(150)
	print("KAIJU after topple: down=", game.judge.frame["monster_down"], " up_y=%.2f" % monster.global_basis.y.y, " hints=", game.live["hints"], " why=", game.judge.why[2])
	await frames(280)
	await shot("scene3")
	check(game.state == S.RESULT and not game.takes.is_empty(), "take ends after all three scenes")
	if not game.takes.is_empty():
		for r: Dictionary in game.takes[0]["results"]:
			print("  ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
		check(not false in game.takes[0]["passed"], "all three monster-movie scenes pass")
		check(game.takes[0]["results"][0]["title"] == game.judge.SCRIPT_TITLES["kaiju"][0], "results use the monster-movie scene names")
		await shot("result")
		game.h_deliver(0)
		await frames(10)
		check(flow.phase == 5 and flow.last_payment >= 1200, "delivery pays for a complete monster movie")
	print("KAIJUTEST_FAIL" if failed else "KAIJUTEST_OK")
	quit(1 if failed else 0)
