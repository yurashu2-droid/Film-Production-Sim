extends SceneTree
# 走りの演出を Motion Lab で走らせ、コマ並べ画像を tests/shots/vfx_review に保存する。画面つきで実行する。
const STYLES := ["scramble", "kick", "smear", "volt", "thunder"]
const TIMES := [0.16, 0.3, 1.0, 1.25]
func _initialize() -> void:
	run.call_deferred()
	create_timer(40.0, true, false, true).timeout.connect(func(): quit(2))
func run() -> void:
	var lab: Node = load("res://motion_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await create_timer(0.3).timeout
	var sheet := Image.create(640 * 4, 360 * STYLES.size(), false, Image.FORMAT_RGB8)
	for s in STYLES.size():
		lab.sustain_run = true
		lab.set_dust_style(STYLES[s])
		for i in TIMES.size():
			while lab.trial_time < TIMES[i]:
				await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			frame = frame.get_region(Rect2i(480, 120, 1120, 630))     # 走者のまわりだけ切り出す
			frame.resize(640, 360, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(frame, Rect2i(0, 0, 640, 360), Vector2i(i * 640, s * 360))
		print("RUNFX_SHOT ", STYLES[s], " ", get_nodes_in_group("dash_dust").size())
	var dir := ProjectSettings.globalize_path("res://tests/shots/vfx_review")
	DirAccess.make_dir_recursive_absolute(dir)
	sheet.save_png(dir.path_join("run_fx.png"))
	quit(0)
