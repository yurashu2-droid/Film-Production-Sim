extends "res://scripts/prop.gd"
# 絵を描ける面を持つ物の共通部分（カンペ・等身大パネル）。
# 面の絵（ink）は筆の命令を全員へ配って同じ絵にする。途中参加と見返しには PNG を丸ごと渡す。
signal ink_restored
var res := Vector2i(1024, 724)     # 絵の大きさ（ピクセル）
var ink: Image
var texture: ImageTexture
var surface: MeshInstance3D
var _ink_surface := -1
var revision := 0
var _png := PackedByteArray()
var _png_fresh := false            # _png が、いまの絵のものか
var _painted := -1.0               # 白でない所の割合の控え（-1＝数え直す）


func make_ink(size: Vector2i) -> void:
	res = size
	ink = Image.create(res.x, res.y, false, Image.FORMAT_RGB8)
	ink.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(ink)


# 素材に用意された「絵を差し替える面」を探して、描いている絵をそのまま映す。lit＝照明の影響を受けるか
func bind_surface(root: Node3D, material_name: String, lit: bool = false) -> bool:
	var found := false
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i)
			if original == null or original.resource_name != material_name:
				continue
			surface = mesh
			_ink_surface = i
			var paper := original.duplicate() as StandardMaterial3D
			paper.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
			paper.albedo_texture = texture
			paper.albedo_color = Color.WHITE
			paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mesh.set_surface_override_material(i, paper)
			found = true
	return found


func draw_line(from: Vector2, to: Vector2, color: Color, radius: float, refresh: bool = true) -> void:
	var steps := maxi(1, int(ceil(from.distance_to(to) / maxf(1, radius * 0.5))))
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / steps)
		var x0 := maxi(0, int(floor(p.x - radius)))
		var x1 := mini(res.x - 1, int(ceil(p.x + radius)))
		var y0 := maxi(0, int(floor(p.y - radius)))
		var y1 := mini(res.y - 1, int(ceil(p.y + radius)))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if Vector2(x, y).distance_squared_to(p) <= radius * radius:
					ink.set_pixel(x, y, color)
	if refresh:
		_refresh()


# 面をまるごと1色で塗る
func fill_ink(color: Color) -> void:
	ink.fill(color)
	_refresh()


func clear_ink() -> void:
	fill_ink(Color.WHITE)


# 用意された絵を貼る（見本など）。大きさは面に合わせる
func set_picture(picture: Image) -> void:
	var copy := picture.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGB8)
	copy.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)
	ink = copy
	_refresh()


# 白でない所の割合（0〜1）。粗く数える。何か描いてあるかどうかの目安
func painted() -> float:
	if _painted < 0.0:
		var hit := 0
		var total := 0
		for y in range(4, res.y, 8):
			for x in range(4, res.x, 8):
				var c := ink.get_pixel(x, y)
				total += 1
				if c.r < 0.93 or c.g < 0.93 or c.b < 0.93:
					hit += 1
		_painted = float(hit) / maxf(1.0, total)
	return _painted


func _refresh() -> void:
	texture.update(ink)
	# PNG は途中参加・見返し・保存のときしか要らない。筆を動かすたびに全員で作ると、見本を貼ったパネルでは1回に0.1秒以上かかる
	_png_fresh = false
	_painted = -1.0


# いまの絵の PNG。必要になったときに作る（絵が変わらない間は、作り直さない）
func png() -> PackedByteArray:
	if not _png_fresh:
		_png = ink.save_png_to_buffer()
		_png_fresh = true
	return _png


func get_state() -> Array:
	var state := super.get_state()
	state.append_array([revision, png()])
	return state


# Reliable brush commands carry ink; frequent physics packets only carry transforms.
func network_state() -> Array:
	return super.get_state()


func _apply_extra(state: Array) -> void:
	if state.size() < 5 or (int(state[3]) == revision and state[4] == png()):
		return
	var image := Image.new()
	if image.load_png_from_buffer(state[4]) != OK or image.get_size() != res:
		return
	image.convert(Image.FORMAT_RGB8)
	ink = image
	revision = int(state[3])
	_refresh()
	ink_restored.emit()
