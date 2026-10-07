extends "res://scripts/prop.gd"
## Lightweight special-effects hand props from unchanged owner-provided GLBs.
var active := false
var _jaw: Node3D
var _jaw_rest := Transform3D.IDENTITY
var source_bounds := AABB()

func build_model(model_kind: String) -> void:
	assert(model_kind in ["dragon_skull", "witch_cauldron", "tomato_monster"])
	kind = model_kind
	label = {"dragon_skull": "竜の頭・手持ち特撮", "witch_cauldron": "魔女の鍋", "tomato_monster": "トマト怪獣・抱える役者"}[kind]
	mass = {"dragon_skull": 2.5, "witch_cauldron": 8.0, "tomato_monster": 10.0}[kind]
	rolls = false
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
	var collider := CollisionShape3D.new()
	if kind == "dragon_skull":
		var box := BoxShape3D.new()
		box.size = Vector3(size.x * 0.7, size.y, size.z * 0.85)
		collider.shape = box
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
		var cylinder := CylinderShape3D.new()
		cylinder.radius = minf(size.x, size.z) * 0.36
		cylinder.height = size.y
		collider.shape = cylinder
	collider.position = center
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
