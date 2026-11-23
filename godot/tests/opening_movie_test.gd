extends SceneTree
# 1日目の最初のムービー（features/opening_movie.gd）：
#   ・自動確認の中では流れない。start() で始めると、流れている間は動けない
#   ・場面は、決まった秒で 広告 → 成功者の声 → 値段 → 購入 → 暗転 の順に変わる。最後まで流れると、動けるようになる
#   ・Enter で、いつでも飛ばせる
#   ・流れている間は、宅配の箱は落ちてこない。終わってから、落ちてくる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/opening_movie_test.gd
#   MOVIE_SHOTS=1 を付けて画面ありで流すと、tests/shots/tutorial/ に場面ごとの絵を残す
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("MOVIE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func shot(file: String) -> void:
	if OS.get_environment("MOVIE_SHOTS") == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/tutorial/"))
	root.get_texture().get_image().save_png("res://tests/shots/tutorial/%s.png" % file)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var movie: Node = game.hooks.feature("opening_movie")
	var box: Node = game.hooks.feature("delivery_box")
	check(movie != null and not movie.playing and not game.input_locked, "自動確認の中では、ムービーは流れない")
	# ---- 始める：流れている間は動けない。箱も落ちてこない ----
	box.start(true)
	movie.start()
	await frames(10)
	check(movie.playing and game.input_locked and movie.shot == "hook", "始めると、最初の場面（広告）が出て、動けなくなる（%s）" % movie.shot)
	check(game.find_child("OpeningMovieScreen", true, false) != null, "ムービーの画面が、ゲームの画面の上に出ている")
	await frames(60 * 4)
	check(not box.box.visible and not box.landed, "流れている間は、宅配の箱は落ちてこない")
	await shot("movie_1_hook")
	# ---- 場面は、決まった秒で変わる ----
	var seen: Array = ["hook"]
	for i in 60 * 17:
		await physics_frame
		if movie.playing and movie.shot != "" and movie.shot != seen[-1]:
			seen.append(movie.shot)
			if movie.shot != "black":
				await frames(170)
				await shot("movie_%d_%s" % [seen.size(), movie.shot])
	check(seen == ["hook", "voice", "price", "buy", "black"], "場面は、広告 → 成功者の声 → 値段 → 購入 → 暗転 の順（%s）" % str(seen))
	await frames(90)
	check(not movie.playing and not game.input_locked and game.find_child("OpeningMovieScreen", true, false) == null, "最後まで流れると、ゲームの画面に戻って、動けるようになる")
	# ---- 終わってから、箱が落ちてくる ----
	var waited := 0
	while not box.landed and waited < 400:
		await frames(1)
		waited += 1
	check(box.landed, "ムービーのあとで、宅配の箱が落ちてくる（%d コマ後）" % waited)
	# ---- Enter で飛ばせる ----
	movie.start()
	await frames(30)
	check(movie.playing and game.input_locked, "もう一度始めた")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await frames(5)
	check(not movie.playing and not game.input_locked, "Enter で、いつでも飛ばせる")
	print("MOVIE_TEST_FAIL" if failed else "MOVIE_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)
