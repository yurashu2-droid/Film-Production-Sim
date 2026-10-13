extends "res://scripts/prop.gd"
## 台本（1冊だけの小道具）。持っている人の画面にだけ、中身が出る。
## 形は単純な箱で組む：表紙・中の紙・背・題名の帯。


func build_model() -> void:
	kind = "script"
	label = "台本"
	mass = 0.6
	hold_min = 0.8
	var size := Vector3(0.36, 0.06, 0.5)
	center = Vector3(0, size.y * 0.5, 0)
	half = size * 0.5
	visual = Node3D.new()
	add_child(visual)
	_box(Vector3(0, 0.03, 0), Vector3(0.34, 0.044, 0.48), Color("f1ecdd"))          # 中の紙
	_box(Vector3(0, 0.055, 0), Vector3(0.36, 0.012, 0.5), Color("d94b3a"))          # 表紙
	_box(Vector3(0, 0.005, 0), Vector3(0.36, 0.01, 0.5), Color("c13f30"))           # 裏表紙
	_box(Vector3(-0.17, 0.03, 0), Vector3(0.03, 0.062, 0.5), Color("8e2d22"))       # 背
	_box(Vector3(0.02, 0.062, -0.08), Vector3(0.22, 0.004, 0.2), Color("f6f1e4"))   # 題名の紙
	var title := Label3D.new()
	title.text = "台本"
	title.font = load("res://assets/fonts/NotoSansJP-VF.ttf")
	title.font_size = 96
	title.pixel_size = 0.0011
	title.modulate = Color("1b1c20")
	title.outline_size = 0
	title.position = Vector3(0.02, 0.066, -0.08)
	title.rotation = Vector3(-PI * 0.5, 0, 0)
	visual.add_child(title)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = center
	add_child(collider)


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	visual.add_child(mi)
