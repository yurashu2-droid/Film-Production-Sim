extends "res://scripts/prop.gd"
# スプレー缶（features/spray_sign.gd）。持って F を押している間、狙った段ボール板に色を吹く。
# 使える素材が無いので、缶の形（胴・肩・キャップ・ノズル）を作る。色は缶ごとに決まっている（黒・赤）
var paint := Color.BLACK


func build(color_name: String, color: Color) -> void:
	kind = "spray_paint"
	label = "スプレー缶（%s）" % color_name
	paint = color
	mass = 0.4
	visual = Node3D.new()
	add_child(visual)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.78, 0.79, 0.8)
	metal.metallic = 0.6
	metal.roughness = 0.35
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color.lerp(Color(0.25, 0.25, 0.28), 0.15) if color != Color.BLACK else Color(0.12, 0.12, 0.13)
	body_mat.roughness = 0.4
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = color if color != Color.BLACK else Color(0.18, 0.18, 0.2)
	cap_mat.roughness = 0.55
	_part(CylinderMesh.new(), 0.033, 0.033, 0.17, 0.085 + 0.006, body_mat)       # 胴
	_part(CylinderMesh.new(), 0.034, 0.034, 0.012, 0.006, metal)                  # 底の縁
	_part(CylinderMesh.new(), 0.018, 0.033, 0.03, 0.191 + 0.006, metal)           # 肩
	_part(CylinderMesh.new(), 0.02, 0.022, 0.035, 0.224 + 0.006, cap_mat)         # キャップ
	var nozzle := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.012, 0.01, 0.016)
	nozzle.mesh = nb
	nozzle.material_override = metal
	nozzle.position = Vector3(0, 0.236 + 0.006, 0.014)
	visual.add_child(nozzle)
	center = Vector3(0, 0.125, 0)
	half = Vector3(0.034, 0.125, 0.034)
	hold_min = 0.9
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.034
	shape.height = 0.25
	collider.shape = shape
	collider.position = center
	add_child(collider)


func _part(mesh: CylinderMesh, top: float, bottom: float, height: float, y: float, mat: Material) -> void:
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	visual.add_child(mi)


# 缶の口（世界の座標）。吹いた色の霧を出す所
func nozzle_global() -> Vector3:
	return global_transform * Vector3(0, 0.236, 0.022)
