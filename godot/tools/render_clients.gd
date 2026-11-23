extends SceneTree
# 依頼主の顔写真を、実際のキャラクターのモデルから撮って書き出す。
#   godot --path godot --script res://tools/render_clients.gd    （画面つきで動かす。そのあと --import）
# 出力：res://assets/ui/clients/<キャラ>.png（背景は透明、胸から上）
const CastVisual := preload("res://scripts/cast_visual.gd")
const SIZE := 512
const TAGS := ["M02", "04", "09", "03", "01", "02", "06"]


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/clients"))
	var view := SubViewport.new()
	view.size = Vector2i(SIZE, SIZE)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6dbe6")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	view.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0dc")
	key.light_energy = 1.4
	key.rotation_degrees = Vector3(-35, 32, 0)
	view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("b9cdf0")
	rim.light_energy = 0.6
	rim.rotation_degrees = Vector3(-15, -140, 0)
	view.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 24.0
	view.add_child(cam)
	cam.make_current()
	for tag: String in TAGS:
		var vis: Node3D = CastVisual.new()
		view.add_child(vis)
		vis.setup(tag)
		vis.play("idle", 0.0, true)
		for i in 20:
			await process_frame
		var head: Vector3 = vis.head_pos()
		var chest: Vector3 = vis.chest_pos()
		var mid := head.lerp(chest, 0.35)
		var span := maxf(head.distance_to(chest), 0.25)
		# モデルの正面は +Z。少し斜め上から
		cam.global_position = mid + Vector3(0.45, 0.12, 1.0).normalized() * span * 7.5
		cam.look_at(mid)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := view.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var used := img.get_used_rect().grow(4).intersection(Rect2i(0, 0, SIZE, SIZE))
		if used.size.x > 8 and used.size.y > 8:
			img = img.get_region(used)
		img.save_png("res://assets/ui/clients/%s.png" % tag)
		vis.queue_free()
		await process_frame
	print("CLIENTS_RENDERED")
	quit()
