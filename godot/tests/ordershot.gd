extends SceneTree
# 発注画面（カタログ）と積み込み確認を撮る。 godot --path godot --script res://tests/ordershot.gd
# 接尾辞は環境変数 UISHOT_SUFFIX、解像度は --resolution WxH、依頼は UISHOT_JOB。
var game: Node
var suffix := ""


func _initialize() -> void:
	suffix = OS.get_environment("UISHOT_SUFFIX")
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/order/%s%s.png" % [tag, suffix])


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/order"))
	var flow: Node = game.production
	seed(7)
	flow.daily = true
	flow.restock()
	var job := 0
	if OS.get_environment("UISHOT_JOB") != "":
		job = int(OS.get_environment("UISHOT_JOB"))
	game.h_accept_job(job)
	game.h_open_order()
	await snap("1_empty")
	game.hud._opt_rows[1]["box"].pressed.emit()
	game.hud._opt_rows[3]["box"].pressed.emit()
	await snap("2_chosen")
	game.h_order_set("refill", 2)
	game.h_order_set("balcony", 1)
	await snap("3_over")
	game.h_order_set("balcony", 0)
	game.h_order_set("refill", 0)
	game.h_order_confirm()
	for prop: Node in game.props.values():
		if not prop.absent and flow._is_free(prop) and prop.kind in ["plywood", "riser", "carton", "moon", "scrap_arch", "boomflat", "tomato_monster"]:
			game.host_load(prop, game.truck)
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	for i in 30:
		await physics_frame
	game.open_menu("packing")
	await snap("4_packing")
	print("ORDERSHOT_OK")
	quit()
