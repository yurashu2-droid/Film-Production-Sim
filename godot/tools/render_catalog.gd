extends SceneTree
# 発注画面などに載せる「物の写真」を、実際の3Dモデルから撮って書き出す。
#   godot --path godot --script res://tools/render_catalog.gd      （画面つきで動かす）
#   そのあと godot --headless --path godot --import で取り込む
#   環境変数 CATALOG_NEW=1 を付けると、まだ写真の無い物だけを撮る（物を足したとき）
#   環境変数 CATALOG_ONLY=cardboard,fish のように種類を並べると、その種類だけを撮る
# 出力：res://assets/ui/catalog/<種類>.png（背景は透明）。モデルを差し替えたら撮り直す。
const SIZE := 384
const OUT := "res://assets/ui/catalog/"
# 始めから置いていないことがある物：種類 → 作るスクリプト（build() で形ができる物）
const EXTRA := {"cardboard": "res://scripts/cardboard_sheet.gd"}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 30:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

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
	env.ambient_light_color = Color("cfd6e2")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	view.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff1dc")
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-42, 38, 0)
	view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("b9cdf0")
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-18, -120, 0)
	view.add_child(fill)
	var cam := Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~(1 << 11)      # 制作班にだけ見える表示（役の札・爆弾の残り）は撮らない
	cam.fov = 26.0
	view.add_child(cam)
	cam.make_current()

	# 種類ごとに1枚。借りる一式は、まとめて1枚にも撮る
	var groups := {"set_balcony": ["balcony", "window"]}
	var first := {}
	for pid: int in game.props:
		var p: Node = game.props[pid]
		if p.kind == "mark" or first.has(p.kind):
			continue
		first[p.kind] = p
		groups[p.kind] = [p.kind]
	# 爆弾の部品（導火線・火薬）は、物として単独では出てこない。爆弾をもう1つ作って、見せ方だけ変えて撮る
	var samples: Array = []
	# （爆弾の見せ方の切り替え preview が無い版では、撮らない。写真は前に撮った物を使う）
	var has_preview := false
	for m: Dictionary in (load("res://scripts/fx_box.gd") as GDScript).get_script_method_list():
		has_preview = has_preview or str(m["name"]) == "preview"
	if first.has("fx") and has_preview:
		for part: String in ["bomb", "fuse", "powder"]:
			var sample: Node3D = (load("res://scripts/fx_box.gd") as GDScript).new()
			sample.build()
			sample.preview(part)
			samples.append(sample)
			var photo_name: String = "fx" if part == "bomb" else "fx_" + part
			first[photo_name] = sample
			groups[photo_name] = [photo_name]
	# 始めから置いていない物（段ボール板は、看板の仕組みが出すまで無いことがある）は、ここで1つ作って撮る
	for kind: String in EXTRA:
		if first.has(kind):
			continue
		var extra: Node3D = (load(EXTRA[kind]) as GDScript).new()
		extra.build()
		samples.append(extra)
		first[kind] = extra
		groups[kind] = [kind]
	var done := 0
	var only_new := OS.get_environment("CATALOG_NEW") != ""
	var only: PackedStringArray = OS.get_environment("CATALOG_ONLY").split(",", false)
	for name: String in groups:
		if only_new and FileAccess.file_exists(OUT + name + ".png"):
			continue
		if not only.is_empty() and not only.has(name):
			continue
		var holder := Node3D.new()
		view.add_child(holder)
		var x := 0.0
		for kind: String in groups[name]:
			if not first.has(kind):
				continue
			var copy: Node3D = (first[kind] as Node).duplicate(0)
			copy.visible = true
			holder.add_child(copy)
			copy.transform = Transform3D.IDENTITY
			var box := _bounds(copy, Transform3D.IDENTITY)
			copy.position = Vector3(x - box.position.x, -box.position.y, -box.get_center().z)
			x += box.size.x + 0.25
		var all := _bounds(holder, Transform3D.IDENTITY)
		var center := all.get_center()
		var radius := all.size.length() * 0.5
		var dir := Vector3(0.62, 0.42, 1.0).normalized()
		cam.global_position = center + dir * (radius / tan(deg_to_rad(cam.fov * 0.5)) * 1.04)
		cam.look_at(center)
		cam.near = 0.05
		cam.far = 200.0
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := view.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		# 余白を切り落として、物だけを大きく見せる
		var used := img.get_used_rect().grow(6).intersection(Rect2i(0, 0, SIZE, SIZE))
		if used.size.x > 8 and used.size.y > 8:
			img = img.get_region(used)
		img.save_png(OUT + name + ".png")
		done += 1
		holder.queue_free()
		await process_frame
	for sample: Node in samples:
		sample.free()
	print("CATALOG_RENDERED ", done)
	quit()


# 子の見える物すべてを包む箱
func _bounds(node: Node, t: Transform3D) -> AABB:
	var out := AABB()
	var has := false
	var stack: Array = [[node, t]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var tt: Transform3D = it[1]
		if n is VisualInstance3D and (n as VisualInstance3D).visible and not (n is Light3D):
			var b: AABB = tt * (n as VisualInstance3D).get_aabb()
			if b.size.length() > 0.001:
				out = b if not has else out.merge(b)
				has = true
		for c in n.get_children():
			if c is Node3D:
				stack.push_back([c, tt * (c as Node3D).transform])
	return out
