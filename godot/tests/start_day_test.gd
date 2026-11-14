extends SceneTree
# 遊んで確かめる用の起動（scripts/features/start_day.gd）：「-- --day2」を付けると 2日目から始まり、掲示板に新しい依頼が出る。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/start_day_test.gd   （「-- --day2」を付けて起動したのと同じ扱いを、中で行う）
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func check(ok: bool, label: String) -> void:
	print("START_DAY_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	var flow: Node = game.production
	var sd: Node = game.hooks.feature("start_day")
	sd.apply([])
	check(int(flow.day) == 1, "付けなければ、1日目のまま")
	sd.apply(["--day2"])
	var titles: Array = flow.offered().map(func(i: int) -> String: return str(flow.JOBS[i]["title"]))
	check(int(flow.day) == 2, "2日目から始まる")
	check(not titles.has(str(flow.JOBS[flow.debut_job()]["title"])), "会社のCMは出ない")
	for t: String in ["転がる大岩・予告編", "空き巣にご用心", "月夜の自転車", "沈まない船の舳先で", "弾をよける男", "階段を駆け上がれ", "カップ麺の3分（CM）", "髪がなびく車のCM"]:
		check(titles.has(t), "掲示板に「%s」が出る" % t)
	# デバッグ用のモード：全部の物が出ている・門が開いている・好きな日と依頼から
	var job: int = flow.offered()[0]
	sd.apply(["--debug", "--day=3", "--job=%d" % job])
	for i in 200:
		if int(flow.phase) >= 1:
			break
		await physics_frame
	await frames(90)
	check(flow.debug and int(flow.day) == 3 and int(flow.wallet) >= sd.DEBUG_COINS - 2000, "デバッグ用のモード：3日目から、貯金は多め（%d日目・%d コイン）" % [int(flow.day), int(flow.wallet)])
	check((flow.stash as Array).filter(func(pid: int) -> bool: return flow._is_free(game.props[pid])).is_empty(), "デバッグ用のモード：廃材は全部出ている（しまっていない）")
	check(int(flow.phase) >= 1 and int(flow.chosen_job) == job, "デバッグ用のモード：--job で、その依頼を受けた所から始まる")
	check(float(flow._gate) > 0.9, "デバッグ用のモード：廃材置き場の門は開いている")
	print("START_DAY_TEST_FAIL" if failed else "START_DAY_TEST_OK")
	quit(1 if failed else 0)
