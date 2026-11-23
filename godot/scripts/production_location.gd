extends RefCounted
## Removable location dressing; the parent owns environment, central set, actors and cameras.
## 文字の札は置かない（浮いた文字は使わない）。板だけ、矢印は絵記号（Look.picto）で面に貼る
const Look := preload("res://scripts/production_look.gd")
const OutdoorLot := preload("res://scripts/production_outdoor_lot.gd")

static func build(parent: Node3D, _font: Font, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "LocationDressing_%d" % index
	parent.add_child(root)
	match index:
		0: _warehouse(root)
		1:
			_perimeter(root)
			_studio(root)
		2:
			_perimeter(root)
			_yard(root)
	return root

static func _warehouse(root: Node3D) -> void:
	_board(root, Vector3(12.4, 2.2, -10.7), Color("3e6667"))
	_table(root, Vector3(12.2, 0, -8.3))
	_box(root, Vector3(12.2, 1.0, -8.3), Vector3(0.6, 0.04, 0.45), Color("f2e3bb"))
	_board(root, Vector3(12.4, 2, -3.8), Color("8d6146"))
	_bench(root, Vector3(12.3, 0, -1.6), Color("7f8070"))
	_parking(root, Vector3(12.2, 0, 2.8), Vector2(5, 3), Color("cab36d"))
	for z in [-7.0, -5.5]:
		_box(root, Vector3(14.3, 0.45, z), Vector3(1.3, 0.9, 1.2), Color("9a7952"), true)

static func _studio(root: Node3D) -> void:
	var apron := Look.Batch.new()
	apron.boxp(Look.mat("concrete", Color("8d8c85")), Vector3(0, -0.24, 0),
			Vector3(51, 0.4, 44))
	apron.solidp(Vector3(0, -0.24, 0), Vector3(51, 0.4, 44))
	apron.build(root, "StudioApron")
	# Dressing stays outside the 8.2-metre studio so actors and the lens remain free.
	_box(root, Vector3(6.7, 0.016, -2), Vector3(3.5, 0.025, 9), Color("595758"))
	_bench(root, Vector3(6.4, 0, -5.4), Color("76634c"))
	_board(root, Vector3(6.5, 2.15, -6.6), Color("675968"))
	_table(root, Vector3(7, 0, -2.9))
	_box(root, Vector3(7, 1.03, -2.9), Vector3(0.5, 0.12, 0.5), Color("e3d0a3"))
	_board(root, Vector3(6.5, 2.3, 1.4), Color("3e6667"))
	_board(root, Vector3(-6.3, 1.8, 3.8), Color("8d6146"))
	for i in range(3):
		_box(root, Vector3(-6.2, 0.3 + i * 0.55, -6.3), Vector3(1.3, 0.55, 1.2), Color("9a7952"), true)
	for x in [-3.7, 3.7]:
		_box(root, Vector3(x, 0.03, 4.1), Vector3(0.1, 0.025, 1.6), Color("c9b66b"))

static func _yard(root: Node3D) -> void:
	OutdoorLot.build(root)
	# Work shed wraps the parent's shutter, with its front open to the south.
	_box(root, Vector3(10.6, 1.75, -10), Vector3(7, 3.5, 0.18), Color("777b77"), true)
	for x in [7.2, 14.0]:
		_box(root, Vector3(x, 1.75, -7.6), Vector3(0.16, 3.5, 4.8), Color("777b77"), true)
	_box(root, Vector3(10.6, 3.55, -7.6), Vector3(7.2, 0.18, 5), Color("505957"))
	_table(root, Vector3(12.8, 0, -6.1))
	_bench(root, Vector3(12.5, 0, -2.8), Color("7b684b"))
	_parking(root, Vector3(16.0, 0, 6.5), Vector2(6, 6), Color("ded8bc"))

static func _perimeter(root: Node3D) -> void:
	# フェンスの外にも床を残し、ジャンプや大きな機材で柵を越えたときの余白にする。
	var fence := Look.Batch.new()
	var steel := Look.mat("metal", Color("667675"))
	var curb := Look.mat("concrete", Color("969993"))
	var wire := Look.Tint.new(Look.chain_link(Vector2(0.11, 0.11), 0.0035), Color("717e7b"))
	var corners := [Vector3(-22, 0, -18), Vector3(22, 0, -18),
			Vector3(22, 0, 18), Vector3(-22, 0, 18)]
	for side in corners.size():
		var start: Vector3 = corners[side]
		var finish: Vector3 = corners[(side + 1) % corners.size()]
		var run := finish - start
		var count := ceili(run.length() / 2.75)
		var mid := (start + finish) * 0.5
		var yaw := 0.0 if absf(run.x) > 0.0 else PI * 0.5
		fence.boxy(curb, mid + Vector3.UP * 0.10, Vector3(run.length() + 0.18, 0.28, 0.27), yaw)
		for bay in count:
			var a := start + run * (float(bay) / count)
			var b := start + run * (float(bay + 1) / count)
			fence.cylp(steel, a + Vector3.UP * 0.23, 0.055, 2.22)
			fence.poly(wire, [a + Vector3.UP * 0.24, b + Vector3.UP * 0.24,
					b + Vector3.UP * 2.37, a + Vector3.UP * 2.37])
		fence.bar(steel, start + Vector3.UP * 2.39, finish + Vector3.UP * 2.39, 0.065)
		fence.solid(Transform3D(Basis(Vector3.UP, yaw), mid + Vector3.UP * 1.2),
				Vector3(run.length() + 0.16, 2.48, 0.22))
	fence.build(root, "LocationFence")

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

static func _board(root: Node3D, at: Vector3, color: Color, arrow := 0.0) -> void:
	_box(root, at, Vector3(3.5, 1.05, 0.1), color)
	if arrow != 0.0:
		var flip := Basis.IDENTITY if arrow > 0.0 else Basis(Vector3.BACK, PI)
		Look.picto(root, Transform3D(flip, at + Vector3(0, 0, 0.0508)), "arrow", Vector2(1.2, 1.2))
	_box(root, Vector3(at.x, at.y / 2 - 0.25, at.z), Vector3(0.1, maxf(0.1, at.y - 0.5), 0.1), Color("766950"), true)

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
