extends "res://scripts/prop.gd"
# スプレー缶（features/spray_sign.gd）。持って F を押している間、狙った段ボール板に色を吹く。
# 見た目はユーザーの素材 SprayCan_400ml（小物/スプレー缶/SprayCan_400ml.blend → assets/gear/spray_can.glb。実寸 400ml 缶）。
# 形と比率はそのまま。使うときはキャップを外した姿にし、肩の色の帯を塗料の色にする（黒・赤の見分け）。
# 霧の出口は素材の印 SprayOrigin（押しボタンのノズル）
const Stage := preload("res://scripts/stage.gd")
const MODEL := preload("res://assets/gear/spray_can.glb")
var paint := Color.BLACK
var _origin: Node3D


func build(color_name: String, color: Color) -> void:
	kind = "spray_paint"
	label = "スプレー缶（%s）" % color_name
	paint = color
	mass = 0.4
	visual = MODEL.instantiate()
	add_child(visual)
	# キャップは外してある（押しボタンが見える）
	var cap: Node3D = visual.find_child("Cap_RemovePivot", true, false)
	if cap != null:
		cap.visible = false
	# 肩の色の帯：塗料の色
	var ring: MeshInstance3D = visual.find_child("Shoulder_ColorDonut", true, false) as MeshInstance3D
	if ring != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color if color.v > 0.05 else Color(0.06, 0.06, 0.07)
		mat.roughness = 0.45
		ring.material_override = mat
	_origin = visual.find_child("SprayOrigin", true, false)
	var bounds := Stage.merged_aabb(visual)
	center = bounds.get_center()
	half = bounds.size * 0.5
	hold_min = 0.9
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(half.x, half.z)
	shape.height = bounds.size.y
	collider.shape = shape
	collider.position = center
	add_child(collider)


# 缶の口（世界の座標）。吹いた色の霧を出す所
func nozzle_global() -> Vector3:
	if _origin != null and is_instance_valid(_origin):
		return _origin.global_position
	return global_transform * Vector3(0, half.y * 2.0, 0)
