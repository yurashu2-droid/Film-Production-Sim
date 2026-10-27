extends SceneTree
# 見立ての飾りの「それっぽさの段」（cast_dress.gd の level：1 立て札 / 2 ひと手間 / 3 本気）を、新しい8役で並べて撮る。
#   godot --path godot --fixed-fps 60 --resolution 640x480 --script res://tests/cast_dress_levels_shot.gd   （画面ありで流す）
#   1枚ずつ tests/shots/cast_dress/levels/ に保存し、行 = 役、列 = 段 の見比べ表を tests/shots/cast_dress/levels_sheet.png にまとめる
#   物は CAND の左から、空き地に出せる物を選ぶ（無ければ大きさの手ごろな scrap_ の物）
var game: Node
const OUT := "res://tests/shots/cast_dress/"
const CastDress := preload("res://scripts/cast_dress.gd")
const ROLES := [
	["ghost", "おばけ", ["scrap_lamp", "trashbag"]],
	["cake", "ケーキ", ["applebox", "scrap_pie"]],
	["saloon", "酒場", ["scrap_kiosk", "scrap_fridge"]],
	["tumble", "回転草", ["trashbag", "rock"]],
	["dish", "料理", ["fish", "scrap_pie"]],
	["stove", "コンロ", ["applebox", "scrap_fridge"]],
	["katsudon", "カツ丼", ["basket", "scrap_pie"]],
	["rocket", "宇宙船", ["scrap_column", "scrap_lamp"]],
]
const LEVELS := ["Lv1 立て札", "Lv2 ひと手間", "Lv3 本気"]
const CELL := Vector2i(320, 240)
const CAP := 30


func _initialize() -> void:
	create_timer(300).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func usable(p: Node) -> bool:
	return not (p.absent or p.immovable or p.fixed or p.holder != 0)


func pick(kinds: Array) -> Node3D:
	for kind: String in kinds:
		for p: Node in game.props.values():
			if usable(p) and p.kind == kind:
				return p
	for p: Node in game.props.values():
		var long := maxf(p.half.x, maxf(p.half.y, p.half.z))
		if usable(p) and long > 0.25 and long < 0.8 and p.kind.begins_with("scrap_"):
			return p
	return null


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "levels/"))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var me: Node3D = game.local_player()
	var at := Vector3(70.0, 0.0, 11.0)
	me.global_position = at + Vector3(6, 0.1, 6)
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	var cells: Array = []   # 行ごとに [見出し, [Image, Image, Image]]
	for row: Array in ROLES:
		var role: String = row[0]
		var prop: Node3D = pick(row[2])
		if prop == null:
			print("NO PROP ", row[2])
			continue
		var home: Vector3 = prop.global_position
		var home_rot: Quaternion = prop.quaternion
		prop.restore([at + Vector3(0, prop.half.y + 0.3, 0), Quaternion.IDENTITY, true])
		await frames(40)
		var imgs: Array = []
		for lv in [1, 2, 3]:
			var dress := CastDress.new()
			prop.add_child(dress)
			dress.build(prop, role, 2, game.font, prop.pid, game.cast_face_side(prop, prop.global_transform * (prop.center + Vector3(0.3, 0, 2.0))), true, lv)
			var c: Vector3 = prop.center_global()
			var size := maxf(prop.half.x, maxf(prop.half.y, prop.half.z))
			cam.global_position = c + prop.global_basis * Vector3(size * 1.6, size * 1.3, size * 3.2) + Vector3(0, 0.3, 0)
			cam.look_at(c + Vector3(0, size * 0.25, 0))
			cam.make_current()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var name := "%s_%s_lv%d" % [role, prop.kind, lv]
			img.save_png(OUT + "levels/" + name + ".png")
			print("SHOT ", name, " pieces=", dress.get_child_count())
			imgs.append(img)
			dress.free()
		cells.append(["%s（%s）" % [row[1], prop.kind], imgs])
		prop.restore([home, home_rot, true])
		await frames(5)
	await sheet(cells)
	print("CAST_DRESS_LEVELS_SHOT_OK")
	quit(0)


# 見比べ表：上に段の見出し、各行の下に役の名前
func sheet(cells: Array) -> void:
	var w := CELL.x * 3
	var h := CAP + cells.size() * (CELL.y + CAP)
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.13)
	bg.size = Vector2(w, h)
	vp.add_child(bg)
	for i in 3:
		vp.add_child(caption(LEVELS[i], Vector2(i * CELL.x, 0), CELL.x))
	for r in cells.size():
		var y := CAP + r * (CELL.y + CAP)
		for i in 3:
			var img: Image = (cells[r][1][i] as Image).duplicate()
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.position = Vector2(i * CELL.x, y)
			tr.size = Vector2(CELL)
			vp.add_child(tr)
		vp.add_child(caption(cells[r][0], Vector2(0, y + CELL.y), w))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + "levels_sheet.png")
	vp.queue_free()


func caption(text: String, pos: Vector2, width: int) -> Label:
	var l := Label.new()
	l.text = text
	if game.font != null:
		l.add_theme_font_override("font", game.font)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(width, CAP)
	return l
