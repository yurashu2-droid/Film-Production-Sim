extends SceneTree
# 最初の画面・閉じた門・今日の廃材の見え方を撮る。 godot --path godot --script res://tests/dailyshot.gd
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/daily/%s.png" % tag)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/daily"))
	var flow: Node = game.production
	flow.daily = true
	flow.restock()
	# 1) 始まった瞬間の画面（プレイヤーの目線、画面の文字つき）
	await snap("1_start")
	game.open_menu("board")
	await snap("2_board_day1")
	game.close_menu()
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	game.add_child(cam)
	cam.make_current()
	game.hud.visible = false
	game.production_hud.visible = false
	# 2) 依頼を受ける前：門は閉まっている
	cam.global_position = Vector3(70, 2.3, 16)
	cam.look_at(Vector3(50, 1.2, 16))
	await snap("3_gate_shut")
	# 3) 依頼を受けたあと：門が開き、今日の廃材だけが並ぶ
	game.h_accept_job(0)
	for i in 100:
		await physics_frame
	await snap("4_gate_open")
	cam.global_position = Vector3(57, 2.3, 16)
	cam.look_at(Vector3(40, 1.0, 14))
	await snap("5_today_inside")
	cam.global_position = Vector3(48, 30, 16.01)
	cam.look_at(Vector3(48, 0, 16), Vector3.RIGHT)
	await snap("6_today_top")
	# 4) 歩く目線での目印
	cam.current = false
	game.local_player().cam.make_current()
	game.hud.visible = true
	game.production_hud.visible = true
	await snap("7_after_accept")
	print("DAILYSHOT stock=", flow.DAILY_COUNT, " stash=", flow.stash.size(), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	quit()
