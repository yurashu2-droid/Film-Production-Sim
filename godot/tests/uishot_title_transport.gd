extends SceneTree
# 実際のホームを一定時間刻みで描画し、搬送演出の確認用フレームを保存する。
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu := (load("res://start_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 60:
		await process_frame
	var transport: Node3D = menu._film_set.get_node("BackgroundTransport")
	transport.elapsed = 0.0
	var folder := ProjectSettings.globalize_path("res://tests/shots/ui/transport")
	DirAccess.make_dir_recursive_absolute(folder)
	var frame := 0
	for i in 690:
		await process_frame
		if i % 3 != 0:
			continue
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		if i in [210, 300, 390]:
			shot.save_png(folder + "/full_%03d.png" % i)
		shot.resize(800, 450, Image.INTERPOLATE_LANCZOS)
		shot.save_png(folder + "/frame_%03d.png" % frame)
		frame += 1
	print("TITLE_TRANSPORT_CAPTURE_OK frames=", frame, " elapsed=", transport.elapsed, " visible=", transport.visible)
	quit()
