extends "res://scripts/prop.gd"
# 爆炎の書割。ふだんは寝ていて、爆発の合図で跳ね上がる。無料だが、周りは吹き飛ばない。

const PropShapes := preload("res://scripts/prop_shapes.gd")
const LYING := -1.5
const UP_SEC := 2.4

var board: Node3D
var board_shape: CollisionShape3D   # 絵の板の当たり（板が立っている間だけ効く）
var _t := -1.0


func build() -> void:
	kind = "boomflat"
	label = "爆炎の書割（合図で跳ね上がる）"
	mass = 6.0
	tags = ["boom"]
	center = Vector3(0, 0.08, -0.6)
	half = Vector3(0.9, 0.1, 0.9)
	hold_min = 1.9
	angular_damp = 3.0
	visual = Node3D.new()
	add_child(visual)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.42, 0.27)
	wood.roughness = 0.9
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.08, 0.5)
	base.mesh = bm
	base.material_override = wood
	base.position = Vector3(0, 0.04, 0)
	visual.add_child(base)

	board = Node3D.new()
	board.position = Vector3(0, 0.08, -0.2)
	board.rotation.x = LYING
	visual.add_child(board)
	var front := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.2, 2.2)
	front.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _burst_texture()
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fm.alpha_scissor_threshold = 0.5
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.emission_enabled = true
	fm.emission_texture = fm.albedo_texture
	fm.emission_energy_multiplier = 2.5
	fm.roughness = 0.9
	front.material_override = fm
	front.position = Vector3(0, 1.1, 0.012)
	board.add_child(front)
	var stick := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.07, 1.5, 0.04)
	stick.mesh = sm
	stick.material_override = wood
	stick.position = Vector3(0, 0.75, -0.02)
	board.add_child(stick)

	# 当たり判定は表（prop_shapes.gd）：土台。寝ている板には付けない（荷台に積めなくなる・廃材置き場で隣の物と重なる）
	PropShapes.build(self, kind)
	# 絵の板の当たり：板が立っている間（合図で跳ね上がった時・物ごと立てて置いた時）だけ効かせる。
	# 立っている絵をすり抜けるのが変だった（2026-11-11 ユーザー）。人も物も当たる。土台の当たり（最初の形）の後ろに足す
	board_shape = CollisionShape3D.new()
	board_shape.name = "BoardShape"
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.9, 0.06)
	board_shape.shape = bs
	board_shape.disabled = true
	add_child(board_shape)
	_place_board_shape()


# 絵の板の当たりを、いまの板に重ねる。板の高さの向きが上を向いていれば（立っていれば）効かせる
func _place_board_shape() -> void:
	board_shape.transform = visual.transform * board.transform * Transform3D(Basis.IDENTITY, Vector3(0, 1.1, -0.005))
	var up: Vector3 = (visual.basis * board.basis).y
	if is_inside_tree():
		up = global_basis * up
	var standing := up.normalized().y > 0.6
	if board_shape.disabled == standing:
		board_shape.set_deferred("disabled", not standing)


func board_standing() -> bool:
	return not board_shape.disabled


# 荷台から落ちたかは、当たり判定の箱（土台）の中心で見る。center は寝ている板の真ん中で、
# 土台より 0.6 m 前に出ているため、荷台の上にあっても外へはみ出して見えてしまう
func ride_point() -> Vector3:
	for c: Node in get_children():
		if c is CollisionShape3D:
			return global_transform * (c as CollisionShape3D).position
	return center_global()


# ギザギザの爆炎を絵に描く
func _burst_texture() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var a := atan2(p.y, p.x)
			var r := p.length()
			var edge := 0.72 + 0.26 * absf(sin(a * 7.0)) * (0.6 + 0.4 * sin(a * 3.0 + 1.0))
			if r > edge:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif r > edge * 0.72:
				img.set_pixel(x, y, Color(0.92, 0.25, 0.08, 1))
			elif r > edge * 0.42:
				img.set_pixel(x, y, Color(1.0, 0.6, 0.1, 1))
			else:
				img.set_pixel(x, y, Color(1.0, 0.92, 0.45, 1))
	return ImageTexture.create_from_image(img)


func burst_point() -> Vector3:
	return global_transform * Vector3(0, 1.2, -0.2)


func pop() -> void:
	_t = 0.0


func _process(delta: float) -> void:
	_place_board_shape()
	if _t < 0.0:
		return
	_t += delta
	var k := 0.0
	if _t < 0.14:
		k = _t / 0.14
	elif _t < UP_SEC:
		k = 1.0 + 0.06 * sin(_t * 22.0) * maxf(0.0, 0.6 - _t)
	else:
		k = 1.0 - clampf((_t - UP_SEC) / 0.5, 0.0, 1.0)
	board.rotation.x = lerpf(LYING, 0.0, k)
	if _t > UP_SEC + 0.5:
		_t = -1.0
		board.rotation.x = LYING
