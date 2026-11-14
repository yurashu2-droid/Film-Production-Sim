extends Node
## 吊りクレーン（会社の庭の、背の高いやぐら）。高い所にロープを掛ける場所が無い、を埋める備品。
## 廃材置き場のミニ撮影クレーン塔（S098）と同じ形を、高さ 5.6m にした物。画面の窓や運転席は無い：ロープを掛けて、人や重りで引く。
##   ・腕と塔に、ロープを掛けられる滑車が4つ付いている（鉄の車が見える所）：
##       腕の先 ／ 塔の上 ／ 塔の根元 ／ 腕の後ろの端
##     ロープの束を持って、滑車を見て F で、結んでいる途中のロープを掛ける（features/contraptions.gd。クランプの滑車と同じ）。
##     例：ハーネス → 腕の先 → 腕の後ろの端 → サンドバッグ（釣り合いの重り。ロープ 8m）
##         ハーネス → 腕の先 → 手に持った箱（横へ歩いて引く。ロープ 7m くらい）
##         塔の上・塔の根元の滑車は、塔に沿ってロープを下ろすときに使う（会社の束は1日 10m なので、人を地面から吊るには足りない。
##         低い所から吊る・軽い物や照明を吊るとき用）
##   ・重い（MASS）が、持って運べる。重い物を腕の先に吊ると、クレーンごと倒れる（土台に重りを載せると、倒れにくくなる）
##   ・当たり判定は、ミニチュアと同じ表（prop_shapes.gd の scrap_crane）を拡大して使う。腕の下は通れる
## 会社の庭に置いてある。遠くの現場へは、軽トラに載らないので持って行けない
const Prop := preload("res://scripts/prop.gd")
const PropShapes := preload("res://scripts/prop_shapes.gd")

const MODEL := "res://assets/production/scrap/S098_crane_tower_rebuilt.glb"
const HEIGHT := 5.6                  # 腕の先の滑車が 5m 弱。人は、足が 3m くらいの高さまで上がる（落ちれば、のびる高さ）
const MASS := 55.0                   # 人ひとり・台車（20kg）を腕の先に吊っても倒れない。40kg の物を吊ると倒れる
const HOME_AT := Vector3(66.0, 0.0, 22.5)
const HOME_YAW := 0.0
const SHAPE_SIZE := 1.5              # 下の寸法を測ったときの高さ（prop_shapes.gd の scrap_crane の "size"）
# 滑車の場所（高さ SHAPE_SIZE のときの寸法。HEIGHT に合わせて拡大する）[名前, 場所]
const GUIDES := [
	["腕の先の滑車", Vector3(0.535, 1.325, -0.03)],
	["塔の上の滑車", Vector3(0.035, 1.325, -0.03)],
	["塔の根元の滑車", Vector3(0.03, 0.15, -0.03)],
	["腕の後ろの滑車", Vector3(-0.55, 1.325, -0.03)],
]
const WHEEL_R := 0.09
# もとの模型の、腕の先から下がっている飾りの線と鉤（ロープと紛らわしいので消す）。模型のままの座標
const HOOK_BOX := AABB(Vector3(1.05, 1.6, -0.2), Vector3(0.4, 1.15, 0.4))

var game: Node
var cranes: Array = []               # クレーン（物）。いまは1台


func setup() -> void:
	var p := _spawn(HOME_AT, HOME_YAW)
	cranes.append(p)
	if Net.is_host() and game.production != null:
		game.production._home_layout[p.pid] = p.get_state()


func _spawn(pos: Vector3, yaw: float) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "crane"
	p.label = "吊りクレーン"
	p.mass = MASS
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	var raw: AABB = game.stage.merged_aabb(model)
	_drop_hook(model)
	var factor := HEIGHT / maxf(raw.size.x, maxf(raw.size.y, raw.size.z))
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-raw.get_center().x, -raw.position.y, -raw.get_center().z) * factor
	var root := Node3D.new()
	root.add_child(model)
	for k in GUIDES.size():
		_add_wheel(root, guide_local(k))
	p.visual = root
	p.add_child(root)
	var size := raw.size * factor
	p.center = Vector3(0, size.y * 0.5, 0)
	p.half = size * 0.5
	p.hold_min = maxf(p.half.x, p.half.z) + 1.2
	PropShapes.build_sized(p, "scrap_crane", HEIGHT)
	p.angular_damp = 2.0
	return game.stage._register(p, pos, yaw)


# 滑車の場所（物から見て）
func guide_local(k: int) -> Vector3:
	return (GUIDES[k][1] as Vector3) * (HEIGHT / SHAPE_SIZE)


func guide_at(p: Node3D, k: int) -> Vector3:
	return p.global_transform * guide_local(k)


func guide_name(k: int) -> String:
	return str(GUIDES[clampi(k, 0, GUIDES.size() - 1)][0])


# 滑車の車（鉄の車と、挟む板）。ロープは、車の中心を通る
func _add_wheel(root: Node3D, at: Vector3) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.74, 0.78)
	steel.metallic = 0.7
	steel.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.21, 0.23)
	dark.roughness = 0.6
	for side: float in [-1.0, 1.0]:
		var disc := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = WHEEL_R
		c.bottom_radius = WHEEL_R
		c.height = 0.016
		c.radial_segments = 20
		disc.mesh = c
		disc.material_override = steel
		disc.rotation.x = PI * 0.5
		disc.position = at + Vector3(0, 0, side * 0.02)
		root.add_child(disc)
		var plate := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.07, WHEEL_R * 2.0 + 0.1, 0.01)
		plate.mesh = b
		plate.material_override = dark
		plate.position = at + Vector3(0, 0.02, side * 0.036)
		root.add_child(plate)
	var groove := MeshInstance3D.new()
	var g := CylinderMesh.new()
	g.top_radius = WHEEL_R * 0.75
	g.bottom_radius = WHEEL_R * 0.75
	g.height = 0.026
	g.radial_segments = 20
	groove.mesh = g
	groove.material_override = dark
	groove.rotation.x = PI * 0.5
	groove.position = at
	root.add_child(groove)


# もとの模型の、腕の先の飾り（下がっている線と鉤）を消す。面の頂点が全部、飾りの箱に入っている面だけを抜く
func _drop_hook(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var node: Node3D = mi
		while node != null and node != model:
			xf = node.transform * xf
			node = node.get_parent() as Node3D
		if HOOK_BOX.encloses(xf * mi.mesh.get_aabb()):
			mi.visible = false
			continue
		if not HOOK_BOX.intersects(xf * mi.mesh.get_aabb()):
			continue
		var made := ArrayMesh.new()
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if index.is_empty():
				index.resize(verts.size())
				for i in verts.size():
					index[i] = i
			var kept := PackedInt32Array()
			for t in range(0, index.size() - 2, 3):
				var inside := true
				for c in 3:
					inside = inside and HOOK_BOX.has_point(xf * verts[index[t + c]])
				if not inside:
					kept.append(index[t])
					kept.append(index[t + 1])
					kept.append(index[t + 2])
			arrays[Mesh.ARRAY_INDEX] = kept
			made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			made.surface_set_material(made.get_surface_count() - 1, mi.mesh.surface_get_material(s))
		mi.mesh = made


# ---- ロープの通り道の番号（contraptions.gd の via に入れる。負の数＝クレーンの滑車） ----

static func via_id(pid: int, k: int) -> int:
	return -(pid * 8 + k)


static func via_pid(via: int) -> int:
	return (-via) >> 3


static func via_k(via: int) -> int:
	return (-via) & 7


func via_at(via: int) -> Vector3:
	var p: Node3D = game.props.get(via_pid(via))
	return guide_at(p, via_k(via)) if p != null and str(p.get("kind")) == "crane" else Vector3.ZERO


func via_ok(via: int) -> bool:
	var p: Node = game.props.get(via_pid(via))
	return via < 0 and p != null and str(p.kind) == "crane" and not p.absent and via_k(via) < GUIDES.size()
