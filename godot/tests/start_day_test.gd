extends SceneTree
# 遊んで確かめる用の起動（scripts/features/start_day.gd）：「-- --day2」を付けると 2日目から始まり、掲示板に新しい依頼が出る。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/start_day_test.gd -- --day2
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


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
	var titles: Array = flow.offered().map(func(i: int) -> String: return str(flow.JOBS[i]["title"]))
	check(int(flow.day) == 2, "2日目から始まる")
	check(not titles.has(str(flow.JOBS[flow.debut_job()]["title"])), "会社のCMは出ない")
	for t: String in ["転がる大岩・予告編", "空き巣にご用心", "月夜の自転車", "沈まない船の舳先で", "弾をよける男", "階段を駆け上がれ", "カップ麺の3分（CM）", "髪がなびく車のCM"]:
		check(titles.has(t), "掲示板に「%s」が出る" % t)
	print("START_DAY_TEST_FAIL" if failed else "START_DAY_TEST_OK")
	quit(1 if failed else 0)
