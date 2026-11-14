extends SceneTree
# 起動画面を画面つきで撮る。出力 res://tests/shots/ui/title[_suffix].png
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 260: await process_frame
	await RenderingServer.frame_post_draw
	var suffix := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suffix="): suffix = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/ui"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/shots/ui/title%s.png" % suffix))
	print("TITLE_FPS ", Engine.get_frames_per_second())
	# 声を張った瞬間と、ケースにマウスを載せた見た目も撮る
	if menu.get("_film_set") != null:
		menu._film_set._next_shout = 0.0
		menu._film_set.set_hover(1, true)
		for i in 24: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/shots/ui/title_shout%s.png" % suffix))
		for i in 200: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/shots/ui/title_later%s.png" % suffix))
	print("UISHOT_TITLE_OK")
	quit()
