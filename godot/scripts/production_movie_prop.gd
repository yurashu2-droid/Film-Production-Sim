extends "res://scripts/prop.gd"
## Lightweight special-effects hand props from unchanged owner-provided GLBs.
## Also builds the free "scrap" props listed in production_scrap.gd (one table row each).
const Scrap := preload("res://scripts/production_scrap.gd")
const PropShapes := preload("res://scripts/prop_shapes.gd")
var active := false
var _jaw: Node3D
var _jaw_rest := Transform3D.IDENTITY
var source_bounds := AABB()

func build_model(model_kind: String) -> void:
	if Scrap.has_kind(model_kind):
		_build_scrap(Scrap.find(model_kind))
		return
	assert(model_kind in ["dragon_skull", "witch_cauldron", "tomato_monster"])
	kind = model_kind
	label = {"dragon_skull": "竜の頭・手持ち特撮", "witch_cauldron": "魔女の鍋", "tomato_monster": "トマト怪獣・抱える役者"}[kind]
	mass = {"dragon_skull": 2.5, "witch_cauldron": 8.0, "tomato_monster": 10.0}[kind]
	rolls = false
	tags = ["monster"] if kind in ["dragon_skull", "tomato_monster"] else []
	hold_min = 0.9 if kind == "dragon_skull" else 1.2
	visual = load("res://assets/production/movie_props/" + kind + ".glb").instantiate() as Node3D
	add_child(visual)
	var first := true
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		var local := mesh.transform as Transform3D
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != visual:
			local = ancestor.transform * local
			ancestor = ancestor.get_parent() as Node3D
		var bounds: AABB = local * mesh.get_aabb()
		source_bounds = bounds if first else source_bounds.merge(bounds)
		first = false
	var extent := maxf(source_bounds.size.x, maxf(source_bounds.size.y, source_bounds.size.z))
	var target_size: float = {"dragon_skull": 0.7, "witch_cauldron": 1.0, "tomato_monster": 1.4}[kind]
	var factor := target_size / extent
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(-source_bounds.get_center().x, -source_bounds.position.y, -source_bounds.get_center().z) * factor
	var size := source_bounds.size * factor
	center = Vector3(0, size.y * 0.5, 0)
	half = size * 0.5
	if kind == "dragon_skull":
		_jaw = visual.find_child("jawPivot", true, false) as Node3D
		if _jaw != null:
			_jaw_rest = _jaw.transform
	else:
		# Source exports vertex colours without a material; enable them explicitly.
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.82
			mesh.material_override = material
	if PropShapes.has(kind):
		# 見た目に合わせた形の組み合わせ（prop_shapes.gd の表。鍋は丸い胴と3本の脚、トマト怪獣は丸い体と足）
		PropShapes.build_sized(self, kind, target_size)
	else:
		# 竜の頭：角を除いた外形の箱ひとつ（手に持つ小さな物なので、これで足りる）
		var box := BoxShape3D.new()
		box.size = Vector3(size.x * 0.7, size.y, size.z * 0.85)
		_add_collider(box, center)

## Merged mesh bounds of `visual` in its own space (before scaling).
func _measure_visual() -> AABB:
	var merged := AABB()
	var first := true
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		var local := mesh.transform as Transform3D
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != visual:
			local = ancestor.transform * local
			ancestor = ancestor.get_parent() as Node3D
		var bounds: AABB = local * mesh.get_aabb()
		merged = bounds if first else merged.merge(bounds)
		first = false
	return merged

## Free scrap-yard prop: GLB normalised to d.size (longest side), base on y=0, imported materials kept.
func _build_scrap(d: Dictionary) -> void:
	kind = d["kind"]
	label = d["label"]
	mass = float(d["mass"])
	tags = (d.get("tags", []) as Array).duplicate()
	one_sided = bool(d.get("one_sided", false))
	rolls = false
	visual = (load("res://assets/production/scrap/" + String(d["file"]) + ".glb") as PackedScene).instantiate() as Node3D
	add_child(visual)
	source_bounds = _measure_visual()
	var extent := maxf(source_bounds.size.x, maxf(source_bounds.size.y, source_bounds.size.z))
	var factor: float = float(d["size"]) / extent
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(-source_bounds.get_center().x, -source_bounds.position.y, -source_bounds.get_center().z) * factor
	var size := source_bounds.size * factor
	center = Vector3(0, size.y * 0.5, 0)
	half = size * 0.5
	hold_min = maxf(1.1, half.z + 0.95)
	var boxes: Array = []
	if PropShapes.has(kind):
		# 見た目に合わせた形の組み合わせ（prop_shapes.gd の表）。表の寸法は表の "size" のときのものなので、いまの size に合わせる
		PropShapes.build_sized(self, kind, float(d["size"]))
	else:
		# 表に無い物：一覧（production_scrap.gd）の shape で決める大ざっぱな形
		match String(d.get("shape", "box")):
			"cyl":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = minf(size.x, size.z) * 0.5
				cylinder.height = size.y
				_add_collider(cylinder, center)
			"arch":
				# two legs plus a lintel: the opening stays walkable
				boxes = [[0.1, 0.375, 0.5, 0.2, 0.75, 0.9], [0.9, 0.375, 0.5, 0.2, 0.75, 0.9], [0.5, 0.88, 0.5, 1.0, 0.24, 0.9]]
			_:
				boxes = [[0.5, 0.5, 0.5, 0.97, 1.0, 0.97]]
	for b: Array in boxes:
		var box := BoxShape3D.new()
		box.size = Vector3(size.x * b[3], size.y * b[4], size.z * b[5])
		_add_collider(box, Vector3((b[0] - 0.5) * size.x, b[1] * size.y, (b[2] - 0.5) * size.z))
	# 重心：表に書いてあればそれ（上で付いている）。無ければ、一覧の com（高さに対する割合）
	if d.has("com") and not PropShapes.has_com(kind):
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, size.y * float(d["com"]), 0)
	if mass >= 20.0:
		angular_damp = 2.0

func _add_collider(shape: Shape3D, at: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	add_child(collider)

func can_activate() -> bool:
	return _jaw != null

## Snap the intact authored jaw hierarchy to two poses; all peers see exact same pose.
func set_active(on: bool) -> void:
	active = on and can_activate()
	if _jaw != null:
		_jaw.transform = _jaw_rest
		if active:
			_jaw.rotate_object_local(Vector3.RIGHT, deg_to_rad(24.0))

func get_state() -> Array:
	var state := super.get_state()
	state.append(active)
	return state

func _apply_extra(state: Array) -> void:
	set_active(bool(state[3]) if state.size() > 3 else false)
