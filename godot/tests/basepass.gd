extends SceneTree
# 拠点の絵作り（production_look.gd）をかけた状態で撮る。 godot --path godot --script res://tests/basepass.gd [-- nolook | ビュー名...]
# 出力：tests/shots/basepass/*.png と、速さ・描画回数・ポリゴン数
const Look := preload("res://scripts/production_look.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60: await physics_frame
	if not args.has("nolook"):
		var env: Environment = null
		for child in game.stage.get_children():
			if child is WorldEnvironment:
				env = child.environment
		Look.apply(env, game.stage, game.production._office_root)
	for i in 20: await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/basepass"))
	var views := {
		"start": [],
		"top": [Vector3(60, 62, 12), Vector3(60, 0, 11.9)],
		"gate": [Vector3(70, 2.3, 16), Vector3(50, 1.2, 16)],
		"office": [Vector3(72, 2.3, 14), Vector3(72, 1.5, -4)],
		"office_hi": [Vector3(72, 4.5, 11), Vector3(72, 1.5, -4)],
		"truck": [Vector3(72, 2.3, 24), Vector3(84, 1.2, 14)],
		"truck2": [Vector3(76, 3.0, 8), Vector3(84, 0.8, 22)],
		"road": [Vector3(80, 2.3, 22), Vector3(80, 1.6, 70)],
		"trip": [Vector3(75.2, 2.8, 33.2), Vector3(80, 0.8, 38)],
		"east": [Vector3(79, 3.0, 9), Vector3(88, 1.0, -4)],
		"nw": [Vector3(66, 3.5, 2.5), Vector3(46, 1.0, -9)],
		"south": [Vector3(66, 3.0, 24), Vector3(44, 1.0, 34)],
		"lote": [Vector3(79, 3.5, 12), Vector3(91, 1.0, 26)],
		"back": [Vector3(78, 3.0, -5), Vector3(70, 1.2, -12)],
		"yardn": [Vector3(66, 3.0, -2), Vector3(60, 1.5, -12)],
		"walk1": [Vector3(72, 2.2, 8), Vector3(80, 1.2, 18)],
		"wall": [Vector3(52, 3.0, -4), Vector3(31.7, 3.0, 10)],
		"vend": [Vector3(85, 2.0, -7), Vector3(79.6, 1.0, -2)],
		"lotS": [Vector3(70, 3.0, 22), Vector3(50, 1.0, 34)],
	}
	var only: Array = []
	for a in args:
		if views.has(a):
			only.append(a)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/basepass"))
	for k: String in views:
		if not only.is_empty() and not only.has(k):
			continue
		if k == "start":
			game.local_player().cam.make_current()
			game.hud.visible = true
			game.production_hud.visible = true
		else:
			cam.make_current()
			game.hud.visible = false
			game.production_hud.visible = false
			cam.global_position = views[k][0]
			cam.look_at(views[k][1], Vector3.FORWARD if k == "top" else Vector3.UP)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/shots/basepass/%s.png" % k)
	cam.make_current()
	game.hud.visible = false
	game.production_hud.visible = false
	cam.global_position = Vector3(66, 2.3, 16)
	cam.look_at(Vector3(48, 1.2, 16))
	# 速さの計測：垂直同期を切って、歩く目線で2秒（GPU/CPUの描画時間も平均）
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await process_frame
	var t0 := Time.get_ticks_usec()
	var n := 0
	var gpu := 0.0
	var cpu := 0.0
	while Time.get_ticks_usec() - t0 < 3000000:
		await process_frame
		n += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	print("BASEPASS fps=%.0f gpu_ms=%.2f cpu_ms=%.2f" % [n / 3.0, gpu / n, cpu / n], " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	quit()
