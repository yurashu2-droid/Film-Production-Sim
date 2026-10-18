extends "res://scripts/paint_board.gd"
# 段ボール板：段ボール箱をたたんで平らにした物（features/spray_sign.gd）。表（+Z）にスプレーで描ける。
# 板は立てた向き（横 SIZE.x・縦 SIZE.y・厚み THICK）。裏と縁は、段ボール箱の素材の面をそのまま使う。
# 描く仕組み（ink・同期）は paint_board.gd。カンペ・等身大パネルと同じに cue_cards.gd に登録して、絵を全員へ配る
const CARTON := preload("res://assets/gear/carton.glb")
const SIZE := Vector2(1.1, 0.74)
const THICK := 0.02
const RESOLUTION := Vector2i(704, 474)
const BASE := Color(0.72, 0.55, 0.36)        # 段ボールの地の色（スプレーの絵の下地）
const GUIDE := Color(0.60, 0.46, 0.31)       # 会社名の下書き（鉛筆の薄い線。地より少し濃いだけ）


func build() -> void:
	kind = "cardboard"
	label = "段ボール板"
	mass = 1.2
	visual = Node3D.new()
	add_child(visual)
	# 縁と裏：段ボール箱の素材（本体の面）を、薄い箱に貼る
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x, SIZE.y, THICK)
	body.mesh = box
	body.position = Vector3(0, SIZE.y * 0.5, 0)
	var carton_mat := _carton_material()
	if carton_mat != null:
		body.material_override = carton_mat
	visual.add_child(body)
	# 表：スプレーの絵（地の色から始まる）
	make_ink(RESOLUTION)
	ink.fill(BASE)
	texture.update(ink)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SIZE
	face.mesh = quad
	face.position = Vector3(0, SIZE.y * 0.5, THICK * 0.5 + 0.001)
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = texture
	paper.roughness = 0.95
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	face.material_override = paper
	visual.add_child(face)
	surface = face
	center = Vector3(0, SIZE.y * 0.5, 0)
	half = Vector3(SIZE.x * 0.5, SIZE.y * 0.5, THICK * 0.5 + 0.004)
	hold_min = 1.3
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	collider.shape = shape
	collider.position = center
	add_child(collider)
	_refresh()


static func _carton_material() -> Material:
	var model: Node3D = CARTON.instantiate()
	var out: Material = null
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Body" and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			out = mi.get_active_material(0)
			break
	model.free()
	return out


# 表の点（この物の座標）→ 絵のピクセル。表から外れていれば null
func pixel_at(local: Vector3) -> Variant:
	var u := (local.x + SIZE.x * 0.5) / SIZE.x
	var v := 1.0 - local.y / SIZE.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0 or local.z < 0.0:
		return null
	return Vector2(u * float(res.x - 1), v * float(res.y - 1))


# スプレーで描いた所の割合（0〜1）。地の色と下書きは数えない（濃い色＝黒・赤・白で吹いた所だけ）
func painted() -> float:
	if _painted < 0.0:
		var hit := 0
		var total := 0
		for y in range(3, res.y, 6):
			for x in range(3, res.x, 6):
				total += 1
				if _sprayed(ink.get_pixel(x, y)):
					hit += 1
		_painted = float(hit) / maxf(1.0, total)
	return _painted


static func _sprayed(c: Color) -> bool:
	var off_base := absf(c.r - BASE.r) + absf(c.g - BASE.g) + absf(c.b - BASE.b)
	var off_guide := absf(c.r - GUIDE.r) + absf(c.g - GUIDE.g) + absf(c.b - GUIDE.b)
	return off_base > 0.25 and off_guide > 0.25


# 会社名の下書き（鉛筆の薄い字）を、絵の真ん中に重ねる。picture は字の形（白い所が字。透明・黒は地のまま）
func put_guide(picture: Image) -> void:
	if picture == null or picture.is_empty():
		return
	var copy := picture.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGBA8)
	var w := int(res.x * 0.86)
	var h := int(float(copy.get_height()) * float(w) / float(maxi(1, copy.get_width())))
	h = mini(h, int(res.y * 0.6))
	copy.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var x0 := (res.x - w) / 2
	var y0 := (res.y - h) / 2
	for y in h:
		for x in w:
			var a := copy.get_pixel(x, y)
			if a.a * a.v > 0.45:
				var here := ink.get_pixel(x0 + x, y0 + y)
				if not _sprayed(here):
					ink.set_pixel(x0 + x, y0 + y, GUIDE)
	_refresh()
