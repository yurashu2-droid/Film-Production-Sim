extends SceneTree
# 見ごたえ（scripts/features/spectacle.gd）を確かめる：危ない撮り方が、撮影カメラに映っていれば、ギャラに上乗せされる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/spectacle_test.gd
# 画面の外の爆発・小さく映った爆発は、上乗せしない。役者のすぐそばで、画面いっぱいに映った爆発は、両方の上乗せ。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("SPECTACLE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func start_take() -> void:
	game.h_take()
	for i in 400:
		if game.state == game.S.TAKE:
			break
		await physics_frame
	await frames(10)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var spectacle: Node = game.hooks.feature("spectacle")
	check(spectacle != null, "見ごたえの仕組みが登録されている")
	if spectacle == null:
		quit(1)
		return
	game.h_accept_job(0)
	await frames(20)
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "現場に着いた")
	var actor: Node3D = game.actors[0]
	var film: Node = game.film
	film.restore([actor.global_position + Vector3(0.0, 0.0, 6.0), Quaternion.IDENTITY, true])
	game.local_player().global_position = film.global_position + Vector3(2.5, 0.1, 2.0)
	await frames(10)
	game._aim_camera(actor.chest_pos(), 50.0)
	await frames(5)
	# テイク1：画面の外（カメラの後ろ）の大爆発と、画面の中でも小さな爆発 → 上乗せなし
	await start_take()
	game.host_ev("burst", [film.global_position + Vector3(0, 1.0, 4.0), 1.0])
	await frames(5)
	var far: Dictionary = spectacle.measure(actor.chest_pos() + Vector3(0, 0, -30.0), 0.0)
	print("SPECTACLE_MEASURE 遠くの小さな爆発：画面の %.2f" % float(far["size"]))
	game.host_ev("burst", [actor.chest_pos() + Vector3(0, 0, -30.0), 0.0])
	await frames(5)
	game._cut()
	await frames(5)
	check(game.state == game.S.RESULT and (flow.fee_lines(0) as Array).is_empty(), "画面の外の爆発・遠くの小さな爆発には、上乗せしない")
	# テイク2：役者のすぐ手前（カメラ寄り）で、画面いっぱいの大爆発 → 両方
	game.h_retake()
	await frames(10)
	await start_take()
	var near: Dictionary = spectacle.measure(actor.chest_pos() + Vector3(0.6, 0.0, 1.2), 1.0)
	print("SPECTACLE_MEASURE 役者のすぐ手前の大爆発：画面の %.2f・間一髪=%s" % [float(near["size"]), str(near["close"])])
	game.host_ev("burst", [actor.chest_pos() + Vector3(0.6, 0.0, 1.2), 1.0])
	await frames(5)
	game._cut()
	await frames(5)
	var lines: Array = flow.fee_lines(1)
	print("SPECTACLE_MEASURE 上乗せ＝", lines)
	check(lines.size() == 2 and int(lines[0][1]) + int(lines[1][1]) == spectacle.FILL_COINS + spectacle.CLOSE_COINS, "役者のすぐそばで、画面いっぱいに映った爆発は、両方の上乗せ")
	var bare: int = flow.take_fee(1) - spectacle.FILL_COINS - spectacle.CLOSE_COINS
	check(bare >= 150, "上乗せは、ギャラに入る（%d = 上乗せなしの %d ＋ %d）" % [flow.take_fee(1), bare, spectacle.FILL_COINS + spectacle.CLOSE_COINS])
	# 試写会：その爆発のところで、依頼主がもっと驚く。とばすと納品になり、精算の文にも出る
	var premiere: Node = game.hooks.feature("premiere")
	game.request_deliver(1)
	await frames(140)
	print("SPECTACLE_MEASURE 試写会のひとこと＝", premiere.last_line)
	check(game.state == game.S.REPLAY and premiere.last_line.contains("画面いっぱい"), "試写会で、その爆発に依頼主がもっと驚く")
	game.h_stop_replay()
	await frames(20)
	check(flow.last_flubs.any(func(l: String) -> bool: return "画面いっぱいの爆発" in l) and flow.last_flubs.any(func(l: String) -> bool: return "間一髪" in l), "精算の文（試写会の読み上げ）に出る")
	print("SPECTACLE_TEST_FAIL" if failed else "SPECTACLE_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(8)
	quit(1 if failed else 0)
