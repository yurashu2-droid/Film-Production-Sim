extends RefCounted
## 機材レンタルの出張カウンター。軽トラの東どなりに建てる。ここで F を押すと、押した人の画面にだけ、発注の画面が開く（事務所の机の電話と同じ画面。品物は、軽トラの荷台と横に届く）。
## 事務所と同じ色（青緑・生成り・木）で、単純な箱で組む。看板に文字は書かず、撮影機の絵を板の面に貼る（Look.picto）。
const Look := preload("res://scripts/production_look.gd")
const POINT := Vector3(89.6, 0, 16.0)        # カウンターの前に立つ場所の目安
const TEAL := Color("4e777c")
const CREAM := Color("d4c4a1")
const WOOD := Color("94704a")


static func build(parent: Node3D, _font: Font) -> Node3D:
	var root := Node3D.new()
	root.name = "RentalCounter"
	root.position = Vector3(91.0, 0, 16.0)
	root.rotation.y = -PI * 0.5              # 正面（+Z）を西の軽トラ側へ向ける
	parent.add_child(root)
	_box(root, Vector3(0, 0.55, 0.35), Vector3(3.2, 1.1, 0.5), TEAL, true)             # カウンター
	_box(root, Vector3(0, 1.12, 0.35), Vector3(3.4, 0.06, 0.7), WOOD, false)           # 天板
	_box(root, Vector3(0, 1.4, -0.45), Vector3(3.4, 2.8, 0.12), CREAM, true)           # 背の壁
	for x: float in [-1.64, 1.64]:
		_box(root, Vector3(x, 1.4, -0.05), Vector3(0.12, 2.8, 0.9), CREAM, true)       # 両袖
	# 縞のひさし
	for i in 8:
		var slat := _box(root, Vector3(-1.5 + i * 0.43, 2.72, 0.55), Vector3(0.43, 0.06, 1.3), TEAL if i % 2 == 0 else Color("f1ead8"), false)
		slat.rotation.x = 0.28
	# 看板と、棚の上の見本
	_box(root, Vector3(0, 3.15, -0.3), Vector3(3.0, 0.62, 0.1), Color("2a2c32"), false)
	Look.picto(root, Transform3D(Basis.IDENTITY, Vector3(-0.95, 3.15, -0.2492)), "movie_camera", Vector2(0.56, 0.56))
	for i in 2:
		_box(root, Vector3(0.45, 3.24 - i * 0.18, -0.248), Vector3(1.6 - i * 0.5, 0.07, 0.004), Color("f4f1ea") if i == 0 else Color("e5392d"), false)
	_box(root, Vector3(0, 2.0, -0.33), Vector3(3.0, 0.05, 0.3), WOOD, false)
	for i in 4:
		_box(root, Vector3(-1.1 + i * 0.72, 2.2, -0.33), Vector3(0.42, 0.34, 0.24), [Color("e5392d"), Color("f4c430"), Color("3d6f8e"), Color("7f8352")][i], false)
	_box(root, Vector3(-1.0, 1.25, 0.35), Vector3(0.5, 0.2, 0.34), Color("2a2c32"), false)   # レジ
	_box(root, Vector3(0.9, 1.18, 0.35), Vector3(0.7, 0.05, 0.5), Color("f1ead8"), false)    # 伝票の束
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.3, 0.6)
	lamp.light_color = Color("ffe2a5")
	lamp.light_energy = 0.9
	lamp.omni_range = 5.0
	lamp.shadow_enabled = false
	root.add_child(lamp)
	return root


static func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi

