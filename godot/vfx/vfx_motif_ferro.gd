extends "res://vfx/vfx_base.gd"
# NASA: Novel Rocket Fuel Spawned Ferrofluid Industry. Magnetic surface instability.
# One continuous liquid sheet: migrating spikes -> crown impulse -> flatten and drain.
# No noise dissolution, particles, cone instances, or independent object scaling.
var _material: ShaderMaterial

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx := new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = pos
	fx.scale = Vector3.ONE * size
	fx.life = 4.4
	fx._build()
	return fx

func _build() -> void:
	var sheet := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6.2, 6.2)
	mesh.subdivide_width = 170
	mesh.subdivide_depth = 170
	sheet.mesh = mesh
	_material = ShaderMaterial.new()
	_material.shader = preload("res://vfx/shaders/motif_ferro.gdshader")
	sheet.material_override = _material
	sheet.custom_aabb = AABB(Vector3(-3.2, -0.1, -3.2), Vector3(6.4, 4.0, 6.4))
	add_child(sheet)

func _tick(_delta: float) -> void:
	_material.set_shader_parameter("age", age)
