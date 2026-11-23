extends Node3D
## キャラ選びのタンス（3D）。まん中が原点。棒の高さは rail_y。吊るす物は、棒の上（z=0）に置く。
## 色と形は、ユーザーの見本の絵（2026-11-23。茶色い木のタンス・くすんだ緑の奥・両開きの戸・上に扇の飾り）に寄せた。
const WOOD := Color("a9582a")
const WOOD_DARK := Color("7e3f1f")
const WOOD_LIGHT := Color("c0703a")
const INLAY := Color("e3b46a")
const BACK := Color("6c8c79")
const BRASS := Color("f0b232")
const RAIL := Color("d6933f")

var rail_y := 0.0
var inner := Vector2.ZERO         # 中の広さ（幅・高さ）


func build(width: float, height: float, depth: float = 0.9) -> void:
	inner = Vector2(width, height)
	var t := 0.14                                  # 板の厚み
	var z0 := -depth * 0.55                        # 奥の板
	var zc := z0 + depth * 0.5
	rail_y = height * 0.5 - 0.5
	_box(Vector3(0, 0, z0), Vector3(width + t * 2, height + t * 2, 0.06), BACK)
	# 上・下・左右の板（中の面は暗く見えるよう、少し濃い色の薄板を重ねる）
	_box(Vector3(0, height * 0.5 + t * 0.5, zc), Vector3(width + t * 2 + 0.16, t, depth + 0.1), WOOD)
	_box(Vector3(0, -height * 0.5 - t * 0.5, zc), Vector3(width + t * 2 + 0.16, t, depth + 0.1), WOOD)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * (width * 0.5 + t * 0.5), 0, zc), Vector3(t, height, depth), WOOD_DARK)
	# 台（脚）
	_box(Vector3(0, -height * 0.5 - t - 0.11, zc), Vector3(width + t * 2 - 0.1, 0.22, depth - 0.06), WOOD_DARK)
	# 上の幕板（前に下がる厚い板。山なりの飾りの下半分を隠す）
	_box(Vector3(0, height * 0.5 + t - 0.17, zc + depth * 0.5 + 0.06), Vector3(width + t * 2 + 0.16, 0.34, 0.06), WOOD)
	# 上の飾り：山なりの板と、扇
	var crown := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.1
	cyl.radial_segments = 48
	crown.mesh = cyl
	crown.rotation.x = PI * 0.5
	crown.scale = Vector3(width * 0.62, 1.0, 0.62)
	crown.position = Vector3(0, height * 0.5 + t, zc + depth * 0.5 + 0.02)
	crown.material_override = _mat(WOOD_LIGHT)
	add_child(crown)
	for k in 5:
		var petal := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		petal.mesh = sp
		var ang := deg_to_rad(-64.0 + 32.0 * float(k))
		petal.scale = Vector3(0.055, 0.17, 0.02)
		petal.rotation.z = -ang
		petal.position = Vector3(sin(ang) * 0.1, height * 0.5 + t - 0.24 + cos(ang) * 0.1, zc + depth * 0.5 + 0.095)
		petal.material_override = _mat(BRASS)
		add_child(petal)
	# 開いた戸（左右）。内側に細い飾り枠、取っ手
	var door_w := minf(width * 0.2, 0.9)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * (width * 0.5 + t), 0, zc + depth * 0.5)
		hinge.rotation.y = side * deg_to_rad(-72.0)
		add_child(hinge)
		_box(Vector3(side * door_w * 0.5, 0, 0), Vector3(door_w, height + t * 2, 0.07), WOOD, hinge)
		var fw := door_w - 0.22
		var fh := height - 0.3
		for row: Array in [[Vector3(0, fh * 0.5, 0), Vector3(fw, 0.022, 0.02)], [Vector3(0, -fh * 0.5, 0), Vector3(fw, 0.022, 0.02)],
				[Vector3(-fw * 0.5, 0, 0), Vector3(0.022, fh, 0.02)], [Vector3(fw * 0.5, 0, 0), Vector3(0.022, fh, 0.02)]]:
			for face: float in [-0.04, 0.04]:
				_box(Vector3(side * door_w * 0.5, 0, face) + row[0], row[1], INLAY, hinge)
		var knob := MeshInstance3D.new()
		var ks := SphereMesh.new()
		ks.radius = 0.06
		ks.height = 0.12
		knob.mesh = ks
		knob.position = Vector3(side * (door_w - 0.12), 0, 0.07)
		knob.material_override = _mat(BRASS)
		hinge.add_child(knob)
	# 棒と、両はしの受け
	var rail := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.026
	rm.bottom_radius = 0.026
	rm.height = width - 0.1
	rail.mesh = rm
	rail.rotation.z = PI * 0.5
	rail.position = Vector3(0, rail_y, 0)
	rail.material_override = _mat(RAIL)
	add_child(rail)
	for side: float in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.055
		cs.height = 0.11
		cap.mesh = cs
		cap.position = Vector3(side * (width * 0.5 - 0.05), rail_y, 0)
		cap.material_override = _mat(RAIL.darkened(0.12))
		add_child(cap)


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic_specular = 0.1
	return m


func _box(at: Vector3, size: Vector3, col: Color, parent: Node = null) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.position = at
	(parent if parent != null else self).add_child(mi)
