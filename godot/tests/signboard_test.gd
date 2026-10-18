extends SceneTree
# 会社のCMの「手描きの看板」（scripts/features/signboard.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/signboard_test.gd
# 何か描いたカンペが、表をカメラへ向けて、隠れずに1秒以上映ると、ギャラに上乗せ。白紙・裏向きは数えない。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("SIGNBOARD_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var sign: Node = game.hooks.feature("signboard")
	check(sign != null, "手描きの看板の仕組みが登録されている")
	if sign == null:
		quit(1)
		return
	check("会社の名前" in " ".join(flow.Briefs.brief(flow.debut_job())["lines"]), "ランプ部長が、会社の名前をどこかに映してほしいと言う（何にどう描くかは言わない）")
	game.h_accept_job(flow.debut_job())
	await frames(20)
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(20)
	check(flow.phase == 4, "現場に着いた")
	var O: Vector3 = flow.site_center()          # 会社のCMは、会社の前で撮る
	var film: Node = game.film
	film.restore([O + Vector3(0, 0, 5), Quaternion.IDENTITY, true])
	game.local_player().global_position = O + Vector3(3.0, 0.1, 6.5)
	await frames(10)
	game._aim_camera(O + Vector3(0, 1.0, -1.6), 56.0)
	var card: RigidBody3D = game.cue_cards.card
	card.restore([O + Vector3(1.4, 0.0, 0.0), Quaternion.IDENTITY, true])
	await frames(10)
	check(not sign.showing(), "白紙のカンペは、看板にならない")
	for i in 12:
		card.draw_line(Vector2(80, 80 + i * 50), Vector2(940, 100 + i * 50), Color.BLACK, 22.0)
	print("SIGNBOARD_MEASURE 描いた割合=%.2f" % float(card.painted()))
	check(sign.showing(), "会社の名前を描いたカンペが、表をカメラへ向けて映っている")
	card.restore([O + Vector3(1.4, 0.0, 0.0), Quaternion(Vector3.UP, PI), true])
	await frames(10)
	check(not sign.showing(), "裏を向けると、映っていない")
	card.restore([O + Vector3(1.4, 0.0, 0.0), Quaternion.IDENTITY, true])
	await frames(10)
	# 本番：1秒以上映して、カット
	game.h_take()
	for i in 400:
		if game.state == game.S.TAKE:
			break
		await physics_frame
	await frames(100)
	game._cut()
	await frames(5)
	var lines: Array = flow.fee_lines(0)
	print("SIGNBOARD_MEASURE 上乗せ＝", lines)
	check(lines.any(func(l: Array) -> bool: return "看板" in str(l[0]) and int(l[1]) == sign.SIGN_COINS), "CMに看板が映ると、ギャラに上乗せ")
	# 試写会：看板が映ったところで、依頼主が気づく
	var premiere: Node = game.hooks.feature("premiere")
	game.request_deliver(0)
	var noticed := false
	for i in 400:
		if premiere.last_line.contains("『%s』の看板" % flow.company_name()):
			noticed = true
			break
		await physics_frame
	check(noticed, "試写会で、看板が映ったところで依頼主が気づく")
	game.h_stop_replay()
	await frames(10)
	print("SIGNBOARD_TEST_FAIL" if failed else "SIGNBOARD_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(8)
	quit(1 if failed else 0)
