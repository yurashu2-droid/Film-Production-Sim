extends RefCounted
## Removable location dressing; the parent owns environment, central set, actors and cameras.
static func build(parent: Node3D, font: Font, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "LocationDressing_%d" % index
	parent.add_child(root)
	match index:
		0: _warehouse(root, font)
		1: _studio(root, font)
		2: _yard(root, font)
	return root

static func _warehouse(root: Node3D, font: Font) -> void:
	_board(root, font, "倉庫レンタル 10分\n延長は、気合ではできません", Vector3(12.4, 2.2, -10.7), Color("3e6667"))
	_table(root, Vector3(12.2, 0, -8.3))
	_box(root, Vector3(12.2, 1.0, -8.3), Vector3(0.6, 0.04, 0.45), Color("f2e3bb"))
	_text(root, font, "受付 / 鍵はこちら", Vector3(12.2, 1.5, -8.1), 0.007)
	_board(root, font, "返却は元の場所へ\n爆発した物も、ひとまず相談", Vector3(12.4, 2, -3.8), Color("8d6146"))
	_bench(root, Vector3(12.3, 0, -1.6), Color("7f8070"))
	_text(root, font, "控室（兼・通路）", Vector3(12.3, 1.4, -2.1), 0.006)
	_parking(root, Vector3(12.2, 0, 2.8), Vector2(5, 3), Color("cab36d"))
	_text(root, font, "積み下ろし\n腰から先に壊さない", Vector3(12.2, 0.025, 2.8), 0.006, true)
	for z in [-7.0, -5.5]:
		_box(root, Vector3(14.3, 0.45, z), Vector3(1.3, 0.9, 1.2), Color("9a7952"), true)

static func _studio(root: Node3D, font: Font) -> void:
	# Dressing stays outside the 8.2-metre studio so actors and the lens remain free.
	_box(root, Vector3(6.7, 0.016, -2), Vector3(3.5, 0.025, 9), Color("595758"))
	_bench(root, Vector3(6.4, 0, -5.4), Color("76634c"))
	_board(root, font, "控室 / 定員：気持ち2名\n主役も荷物も譲り合い", Vector3(6.5, 2.15, -6.6), Color("675968"))
	_table(root, Vector3(7, 0, -2.9))
	_box(root, Vector3(7, 1.03, -2.9), Vector3(0.5, 0.12, 0.5), Color("e3d0a3"))
	_text(root, font, "差し入れ（お湯）", Vector3(7, 1.5, -3.15), 0.006)
	_board(root, font, "スタジオ 10分貸切\n広く見せるのは監督の仕事", Vector3(6.5, 2.3, 1.4), Color("3e6667"))
	_board(root, font, "静かに！ 本番中\n壁の向こうは普通の廊下", Vector3(-6.3, 1.8, 3.8), Color("8d6146"))
	for i in range(3):
		_box(root, Vector3(-6.2, 0.3 + i * 0.55, -6.3), Vector3(1.3, 0.55, 1.2), Color("9a7952"), true)
	_text(root, font, "画角の外は\n見なかったことに", Vector3(-6.2, 2.15, -6.15), 0.006)
	for x in [-3.7, 3.7]:
		_box(root, Vector3(x, 0.03, 4.1), Vector3(0.1, 0.025, 1.6), Color("c9b66b"))

static func _yard(root: Node3D, font: Font) -> void:
	_box(root, Vector3(0, -0.24, -2), Vector3(48, 0.4, 40), Color("727669"), true)
	# Work shed wraps the parent's shutter, with its front open to the south.
	_box(root, Vector3(8, 1.75, -10), Vector3(7, 3.5, 0.18), Color("777b77"), true)
	for x in [4.6, 11.4]:
		_box(root, Vector3(x, 1.75, -7.6), Vector3(0.16, 3.5, 4.8), Color("777b77"), true)
	_box(root, Vector3(8, 3.55, -7.6), Vector3(7.2, 0.18, 5), Color("505957"))
	_board(root, font, "ロケ管理小屋\n電源は借り物 / 夢は自前", Vector3(8, 2.8, -5.08), Color("3e6667"))
	_table(root, Vector3(10.2, 0, -6.1))
	_bench(root, Vector3(12.5, 0, -2.8), Color("7b684b"))
	_board(root, font, "空き地ロケ 10分\n近所には、超大作より静けさ", Vector3(12.5, 2, -4), Color("8d6146"))
	# Far scenery sits behind the movie set, never in the central actor rectangle.
	for spec in [[Vector3(-10, 0, -15), Color("698183")], [Vector3(0, 0, -17), Color("8c725b")]]:
		_container(root, spec[0], spec[1])
	for p in [Vector3(-18, 0, -14), Vector3(-14, 0, -18), Vector3(15, 0, -15), Vector3(20, 0, -10)]:
		_tree(root, p)
	for x in range(-20, 23, 4):
		_box(root, Vector3(x, 0.7, -20), Vector3(0.12, 1.4, 0.12), Color("766950"))
	_box(root, Vector3(0, 0.8, -20), Vector3(44, 0.1, 0.1), Color("a5956e"))
	for x in [12.5, 18.7]:
		_box(root, Vector3(x, 0.025, 8.5), Vector3(0.08, 0.03, 7), Color("ded8bc"))
	_text(root, font, "搬入 / 帰りも軽トラ", Vector3(15.5, 0.03, 11.1), 0.005, true)
	_board(root, font, "駐車場 →\n主演俳優も徒歩でどうぞ", Vector3(20, 1.9, 4), Color("3e6667"))
	for i in range(4):
		_box(root, Vector3(-18, 0.22 + i * 0.28, 3), Vector3(2.5, 0.2, 1), Color("776444"))

static func _container(root: Node3D, at: Vector3, color: Color) -> void:
	_box(root, at + Vector3(0, 1.55, 0), Vector3(7, 3.1, 3), color, true)
	for i in range(14):
		_box(root, at + Vector3(-3.25 + i * 0.5, 1.55, 1.52), Vector3(0.045, 2.95, 0.06), color.darkened(0.14))
	_box(root, at + Vector3(0, 3.16, 0), Vector3(7.1, 0.12, 3.1), color.darkened(0.2))

static func _tree(root: Node3D, at: Vector3) -> void:
	_box(root, at + Vector3(0, 1.4, 0), Vector3(0.5, 2.8, 0.5), Color("766047"), true)
	for i in range(3):
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.5 - i * 0.22
		sphere.height = 2.4
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("596d4c").lightened(i * 0.025)
		mat.roughness = 1
		mesh.material_override = mat
		mesh.position = at + Vector3(i * 0.3, 3.1 + i * 0.8, 0)
		root.add_child(mesh)

static func _table(root: Node3D, at: Vector3) -> void:
	_box(root, at + Vector3(0, 0.95, 0), Vector3(2, 0.12, 0.9), Color("a0855c"), true)
	for x in [-0.8, 0.8]:
		_box(root, at + Vector3(x, 0.45, 0), Vector3(0.12, 0.9, 0.7), Color("586365"), true)

static func _bench(root: Node3D, at: Vector3, color: Color) -> void:
	_box(root, at + Vector3(0, 0.45, 0), Vector3(2.6, 0.15, 0.75), color, true)
	_box(root, at + Vector3(0, 0.85, -0.3), Vector3(2.6, 0.7, 0.1), color, true)
	for x in [-1, 1]:
		_box(root, at + Vector3(x, 0.2, 0), Vector3(0.15, 0.4, 0.6), color, true)

static func _parking(root: Node3D, at: Vector3, size: Vector2, color: Color) -> void:
	for x in [-size.x / 2, size.x / 2]:
		_box(root, at + Vector3(x, 0.024, 0), Vector3(0.08, 0.025, size.y), color)
	for z in [-size.y / 2, size.y / 2]:
		_box(root, at + Vector3(0, 0.024, z), Vector3(size.x, 0.025, 0.08), color)

static func _board(root: Node3D, font: Font, text: String, at: Vector3, color: Color) -> void:
	_box(root, at, Vector3(3.5, 1.05, 0.1), color)
	_text(root, font, text, at + Vector3(0, 0, 0.08), 0.005)
	_box(root, Vector3(at.x, at.y / 2 - 0.25, at.z), Vector3(0.1, maxf(0.1, at.y - 0.5), 0.1), Color("766950"), true)

static func _text(root: Node3D, font: Font, words: String, at: Vector3, pixel: float, floor_text := false) -> void:
	var label := Label3D.new()
	label.text = words
	label.font = font
	label.font_size = 42
	label.pixel_size = pixel
	label.modulate = Color("f6e8c7")
	label.outline_size = 0
	label.position = at
	if floor_text: label.rotation.x = -PI / 2
	root.add_child(label)

static func _box(root: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position = at
	root.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = size
		shape.shape = collider
		body.add_child(shape)
		mesh.add_child(body)
