extends "res://scripts/prop.gd"
# 16:9 の大型確認モニター。幅・高さとも元の画面の4倍。運べるキャスター台。
const SCREEN_SIZE := Vector2(2.48, 1.40)
const SCREEN_CENTER := Vector3(0, 1.84, 0.145)
var screen: MeshInstance3D
var _screen_material: StandardMaterial3D
var _rec: MeshInstance3D
var _channels: Array[MeshInstance3D] = []

func screen_size() -> Vector2:
	return SCREEN_SIZE

func build_model() -> void:
	kind = "monitor"
	label = "大型確認モニター"
	mass = 28.0
	rolls = true
	hold_min = 1.7
	center = Vector3(0,1.36,0)
	half = Vector3(1.43,1.36,0.55)
	visual = Node3D.new()
	add_child(visual)
	var black := Color("202329")
	var metal := Color("686e75")
	# 薄いベゼル、背面の制御部、画面上の短い遮光フード。
	_box(Vector3(0,1.84,0),Vector3(2.64,1.58,0.24),black)
	_box(Vector3(0,1.84,-0.20),Vector3(2.30,1.24,0.18),Color("34383d"))
	_box(Vector3(0,2.645,0.12),Vector3(2.68,0.04,0.34),black)
	for x: float in [-1.26,1.26]:
		_box(Vector3(x,1.84,0.14),Vector3(0.04,1.43,0.012),Color("101215"))
	_box(Vector3(0,1.12,0.145),Vector3(2.48,0.04,0.012),Color("101215"))
	# 通気スリットと VESA 取付部。後ろから見ても薄い画面に見える。
	for i in 14:
		_box(Vector3(-0.78+i*0.12,2.23,-0.298),Vector3(0.064,0.025,0.01),Color("101215"))
	_box(Vector3(0,1.60,-0.32),Vector3(0.58,0.46,0.08),metal)
	for x: float in [-0.22,0.22]:
		for y: float in [1.45,1.75]:
			_cylinder(Vector3(x,y,-0.37),0.028,0.024,black,Vector3(PI/2,0,0))
	# 取っ手：筐体から浮かせ、両端で支える。
	for x: float in [-1.40,1.40]:
		_box(Vector3(x,1.84,-0.12),Vector3(0.045,0.54,0.045),metal)
		for y: float in [1.59,2.09]:
			_box(Vector3(x*0.965,y,-0.12),Vector3(0.10,0.045,0.045),metal)
	# 二本の支柱と広いキャスター台。
	for x: float in [-0.58,0.58]:
		_box(Vector3(x,0.76,-0.19),Vector3(0.055,1.13,0.055),metal)
		_box(Vector3(x,0.40,-0.19),Vector3(0.080,0.46,0.080),black)
	_box(Vector3(0,0.21,-0.10),Vector3(1.74,0.075,0.08),metal)
	for x: float in [-0.80,0.80]:
		_box(Vector3(x,0.21,-0.10),Vector3(0.08,0.075,1.0),metal)
		for z: float in [-0.54,0.34]:
			_box(Vector3(x,0.15,z),Vector3(0.12,0.12,0.16),metal)
			_cylinder(Vector3(x,0.095,z),0.095,0.085,Color("181a1d"),Vector3(0,0,PI/2))
	# 画面下の操作ボタン、電源灯、録画灯。
	for i in 3:
		_channels.append(_box(Vector3(-0.92+i*0.16,1.085,0.135),Vector3(0.105,0.040,0.032),Color("515963")))
	_cylinder(Vector3(0.85,1.085,0.14),0.035,0.025,metal,Vector3(PI/2,0,0))
	_box(Vector3(1.00,1.085,0.145),Vector3(0.032,0.018,0.014),Color("73d6ae"))
	_rec = _box(Vector3(1.12,1.085,0.145),Vector3(0.032,0.018,0.014),Color("742924"))
	screen = MeshInstance3D.new()
	screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	screen.mesh = quad
	screen.position = SCREEN_CENTER
	_screen_material = StandardMaterial3D.new()
	_screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen_material.albedo_color = Color.WHITE
	screen.material_override = _screen_material
	visual.add_child(screen)
	_shape(Vector3(0,1.84,0),Vector3(2.68,1.62,0.42))
	_shape(Vector3(0,0.54,-0.10),Vector3(1.75,1.08,1.10))

func attach(view: SubViewport) -> void:
	_screen_material.albedo_texture = view.get_texture()

func set_on_air(index: int, recording: bool) -> void:
	for i in _channels.size():
		_channels[i].material_override.albedo_color = Color("d9604c") if i == index else Color("515963")
	_rec.material_override.albedo_color = Color("ef5146") if recording else Color("742924")

func _shape(at: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = at
	add_child(collider)

func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(mesh,at,color)

func _cylinder(at: Vector3, radius: float, height: float, color: Color, rotation: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var part := _part(mesh,at,color)
	part.rotation = rotation
	return part

func _part(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.44
	material.metallic = 0.65 if color == Color("686e75") else 0.0
	part.material_override = material
	visual.add_child(part)
	return part
