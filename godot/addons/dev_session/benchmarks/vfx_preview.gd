extends Node3D
# Measurement fixture, not a new production VFX. Reuses sculpted_dust.gd.
# Same deterministic effect, camera, ground and physics clock for both workflows.
const EFFECT_PATH := "res://.godot/dev_session/vfx_benchmark_effect.gd"
var effect: Node3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.12, 0.16, 0.20)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	add_child(environment)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.24, 0.30, 0.33)
	ground.material_override = material
	add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(2.8, 2.0, 3.8)
	camera.fov = 36.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.35, 0.6))
	camera.make_current()
	rebuild_effect()

func rebuild_effect() -> void:
	if is_instance_valid(effect):
		effect.free()
	effect = load(EFFECT_PATH).new()
	effect.name = "Dust"
	add_child(effect)
	effect.burst(Vector3.FORWARD, 1.4, false)

func replay() -> void:
	# Reset the clock while retaining the live instance and its constructed meshes.
	effect.age = 0.0
	effect._update_puffs()

func sample_state() -> Dictionary:
	if not is_instance_valid(effect):
		return {"alive": false}
	return {"alive": true, "age": effect.age, "count": effect._count,
		"instance": effect.get_instance_id()}
