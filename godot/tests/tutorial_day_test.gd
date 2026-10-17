extends SceneTree
# 1日目の段取り（scripts/features/tutorial_day.gd）：会社の紹介動画を受けても、廃材置き場の門は開かない。
# 使いそうな物（城の書割・爆炎の書割・等身大パネル・カンペ・箱馬）は、事務所の前に出してある。2日目の依頼では、門が開く。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/tutorial_day_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("TUTDAY_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var day: Node = game.hooks.feature("tutorial_day")
	# 日替わりで、しまってある物がある日にする（いつもの遊びと同じ）
	flow.daily = true
	flow.restock()
	await frames(5)
	game.h_accept_job(flow.debut_job())
	await frames(150)
	check(day != null and flow.phase >= 1, "会社の紹介動画を受けた")
	check(is_zero_approx(float(flow._gate)), "1日目は、廃材置き場の門が開かない")
	for row: Array in day.PILE:
		var near: bool = game.props.values().any(func(p: Node) -> bool:
			return p.kind == row[0] and not p.absent and Vector2(p.global_position.x - row[1].x, p.global_position.z - row[1].z).length() < 0.8)
		check(near, "事務所の前に「%s」が出してある" % row[0])
	# 2日目の依頼では、門が開く
	game.h_return_office() if flow.phase == 5 else null
	flow.phase = 0
	flow.day = 2
	game.h_accept_job(0)
	await frames(150)
	check(float(flow._gate) > 0.9, "2日目の依頼では、門が開く")
	print("TUTDAY_TEST_FAIL" if failed else "TUTDAY_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
