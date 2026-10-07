extends RefCounted
## Coordinates are in the shared world's space; this root remains at the origin.
const CONTRACT_POINT := Vector3(72, 0, 1.5)
const TRUCK_POINT := Vector3(82, 0, 18)
const SPAWN_POINT := Vector3(72, 0.1, 5)

static func build(parent: Node3D, font: Font) -> Node3D:
	var root := Node3D.new()
	root.name = "ProductionOffice"
	parent.add_child(root)
	var cream := Color("d4c4a1")
	var blue := Color("4e777c")
	var wood := Color("94704a")
	var rust := Color("8f5943")
	_box(root, Vector3(62, -0.2, 11), Vector3(60, 0.4, 50), Color("787d70"), true)
	_box(root, Vector3(80, -0.21, 54), Vector3(13, 0.4, 42), Color("454b4d"), true)
	_box(root, Vector3(80, 0.005, 23), Vector3(10, 0.012, 22), Color("454b4d"))
	for z in range(31, 75, 8):
		_box(root, Vector3(80, 0.015, z), Vector3(0.16, 0.02, 3.2), Color("e7dba8"))
	# Roofless lobby: the southern entrance and the player's camera stay open.
	_box(root, Vector3(72, 0.015, -2), Vector3(14, 0.03, 12), Color("bca983"))
	_box(root, Vector3(72, 1.65, -8), Vector3(14, 3.3, 0.24), cream, true)
	_box(root, Vector3(65, 1.2, -2), Vector3(0.24, 2.4, 12), cream, true)
	_box(root, Vector3(79, 1.2, -2), Vector3(0.24, 2.4, 12), cream, true)
	for x in [67.5, 76.5]:
		_box(root, Vector3(x, 0.75, 4), Vector3(5, 1.5, 0.24), blue, true)
		_box(root, Vector3(x, 1.95, 4), Vector3(5, 0.9, 0.1), cream)
	for x in [69.85, 74.15]:
		_box(root, Vector3(x, 1.6, 4), Vector3(0.16, 3.2, 0.3), wood, true)
	# Three skewed cardboard sections make a deliberately sagging studio banner.
	for i in range(3):
		var banner := _box(root, Vector3(69.8 + i * 2.2, 3.05 - (0.18 if i == 1 else 0.0), 4.08), Vector3(2.24, 0.65, 0.1), Color("e8d69f"))
		banner.rotation.z = [-0.045, 0.015, 0.045][i]
	_text(root, font, "激安映画制作会社", Vector3(72, 2.98, 4.17), 0.009, 52, Color("553c31"))
	_text(root, font, "ようこそ！ まずは仕事を選ぼう", Vector3(72, 0.15, 6.2), 0.008, 36, Color("f7e8b8"), Vector3(-PI / 2, 0, 0))
	# Contract desk with a large noticeboard directly behind it.
	_box(root, Vector3(72, 0.88, 0.05), Vector3(3.8, 0.16, 1.4), wood, true)
	for x in [70.5, 73.5]:
		_box(root, Vector3(x, 0.42, 0.05), Vector3(0.25, 0.84, 1.1), blue, true)
	_box(root, Vector3(72, 1.65, -0.72), Vector3(4.1, 2.1, 0.16), wood, true)
	_box(root, Vector3(72, 1.65, -0.61), Vector3(3.88, 1.9, 0.04), Color("42645b"))
	_text(root, font, "お仕事掲示板", Vector3(72, 2.25, -0.56), 0.01, 48, Color("fff0c6"))
	_text(root, font, "小さな予算で、大きな映画。", Vector3(72, 0.97, 0.79), 0.006, 34, Color("fff0c6"))
	for i in range(3):
		_box(root, Vector3(70.75 + i * 1.25, 1.45, -0.56), Vector3(0.95, 0.78, 0.02), Color("e5d5a5"))
		_text(root, font, ["アクション", "怪獣映画", "おまかせ"][i], Vector3(70.75 + i * 1.25, 1.47, -0.53), 0.004, 34, Color("5a4731"))
	for i in range(3):
		_chair(root, Vector3(66.3, 0, -5.3 + i * 2), [blue, rust, Color("7f8352")][i], 0.1 * (i - 1))
	_box(root, Vector3(76.7, 0.5, -5.9), Vector3(2.3, 1, 1.2), wood, true)
	for i in range(4):
		_box(root, Vector3(76.3 + i * 0.13, 1.04 + i * 0.028, -5.9), Vector3(0.9, 0.028, 0.6), Color("e8ddbf"))
	_text(root, font, "家賃 未払い\n電気代 督促\n夢は 黒字", Vector3(76.1, 2.08, -7.83), 0.008, 40, Color("754437"))
	_box(root, Vector3(68.2, 1.7, -7.81), Vector3(2.1, 1.3, 0.08), wood)
	_text(root, font, "窓 修理中\n（段ボール）", Vector3(68.2, 1.7, -7.74), 0.006, 36, Color("392b25"))
	for x in [67.45, 68.95]:
		var tape := _box(root, Vector3(x, 1.7, -7.7), Vector3(0.18, 1.5, 0.025), Color("b8a76e"))
		tape.rotation.z = 0.2
	_sign(root, font, "廃材と軽トラ →", Vector3(76.8, 0, 6.5), blue)
	# Storage shelves sit along the far western boundary, outside movable prop slots.
	for z in [-5.0, 2.0, 9.0, 16.0]:
		for x in [37.0, 39.8]:
			_box(root, Vector3(x, 1.1, z), Vector3(0.12, 2.2, 2.5), rust, true)
		for y in [0.25, 1.05, 1.85]:
			_box(root, Vector3(38.4, y, z), Vector3(3, 0.12, 2.5), Color("797975"), true)
			_box(root, Vector3(38.1, y + 0.32, z - 0.4), Vector3(1.7, 0.55, 1.2), wood)
	_sign(root, font, "廃材置き場\n捨てない。撮る。", Vector3(44, 0, -7), rust)
	# Thin painted parking marks leave all truck interaction space unobstructed.
	for x in [77.3, 83.2]:
		_box(root, Vector3(x, 0.017, 18), Vector3(0.1, 0.025, 7), Color("d9c7a3"))
	var departure := _sign(root, font, "全員乗って出発 / F", Vector3(86, 0, 17.5), blue)
	root.set_meta("departure_label", departure)
	_sign(root, font, "スタジオ →", Vector3(87, 0, 33), blue)
	var light := OmniLight3D.new()
	light.position = Vector3(72, 3, -2)
	light.light_color = Color("ffe2a5")
	light.light_energy = 1.2
	light.omni_range = 13
	light.shadow_enabled = false
	root.add_child(light)
	return root

static func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position = pos
	root.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collider.shape = box
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

static func _text(root: Node3D, font: Font, words: String, pos: Vector3, pixel: float, size: int, color: Color, angles := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font = font
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.position = pos
	label.rotation = angles
	root.add_child(label)
	return label

static func _sign(root: Node3D, font: Font, words: String, pos: Vector3, color: Color) -> Label3D:
	_box(root, pos + Vector3(0, 0.95, 0), Vector3(0.12, 1.9, 0.12), Color("716557"), true)
	_box(root, pos + Vector3(0, 1.9, 0), Vector3(3.9, 1.05, 0.12), color)
	return _text(root, font, words, pos + Vector3(0, 1.9, 0.09), 0.006, 40, Color("fff1d1"))

static func _chair(root: Node3D, pos: Vector3, color: Color, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	root.add_child(chair)
	_box(chair, Vector3(0, 0.5, 0), Vector3(0.8, 0.12, 0.85), color, true)
	_box(chair, Vector3(0, 0.95, -0.35), Vector3(0.8, 0.9, 0.1), color, true)
	for x in [-0.29, 0.29]:
		for z in [-0.29, 0.29]:
			_box(chair, Vector3(x, 0.23, z), Vector3(0.08, 0.46, 0.08), Color("53534e"))
