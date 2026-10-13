extends SceneTree
# 依頼の打ち合わせ画面を撮る。 godot --path godot --script res://tests/briefshot.gd
# 接尾辞は環境変数 UISHOT_SUFFIX、解像度は --resolution WxH。
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/brief/%s%s.png" % [tag, OS.get_environment("UISHOT_SUFFIX")])


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/brief"))
	var flow: Node = game.production
	flow.day = 2
	game.open_menu("board")
	await snap("0_board")
	for job: int in [0, 3, 4]:
		game.open_brief(job)
		for i in 240:
			await process_frame
		await snap("job%d" % job)
		game.open_menu("board")
	game.open_brief(1)
	for i in 30:
		await process_frame
	game.production_hud.briefing.accepted.emit(1)
	for i in 20:
		await process_frame
	print("BRIEFSHOT_OK phase=", flow.phase, " job=", flow.chosen_job, " menu=", game.menu_open)
	quit()
