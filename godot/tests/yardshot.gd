extends SceneTree
# 拠点（事務所・廃材置き場・軽トラ）の見え方を撮る。 godot --path godot --script res://tests/yardshot.gd
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60: await physics_frame
	game.hud.visible = false
	game.production_hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	game.add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/yard"))
	var views := {
		"top": [Vector3(60, 62, 12), Vector3(60, 0, 11.9)],
		"gate": [Vector3(70, 2.3, 16), Vector3(50, 1.2, 16)],
		"inside": [Vector3(57, 2.3, 16), Vector3(40, 1.0, 14)],
		"aisle": [Vector3(46, 2.3, 4), Vector3(46, 1.0, 26)],
		"office": [Vector3(72, 2.3, 14), Vector3(72, 1.5, -4)],
		"truck": [Vector3(72, 2.3, 24), Vector3(84, 1.2, 14)],
		"road": [Vector3(80, 2.3, 22), Vector3(80, 1.6, 70)],
	}
	for k: String in views:
		cam.global_position = views[k][0]
		cam.look_at(views[k][1], Vector3.FORWARD if k == "top" else Vector3.UP)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/shots/yard/%s.png" % k)
	# 歩くときの目線で2秒流してから、速さを測る
	cam.global_position = Vector3(66, 2.3, 16)
	cam.look_at(Vector3(48, 1.2, 16))
	var t0 := Time.get_ticks_usec()
	var n := 0
	while Time.get_ticks_usec() - t0 < 2000000:
		await process_frame
		n += 1
	print("YARDSHOT walk_fps=%.0f" % (n / 2.0))
	print("YARDSHOT fps=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	quit()
