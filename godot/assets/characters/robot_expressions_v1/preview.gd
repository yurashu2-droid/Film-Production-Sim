extends Node3D
## Isolated inspection scene. Overrides the instantiated screen only.
## Image.load avoids starting the editor or changing existing import settings.

const FOLDER := "res://assets/characters/robot_expressions_v1/"
const NAMES := ["neutral", "happy", "surprised", "worried", "angry", "sleep"]
var model: Node3D
var display: MeshInstance3D
var original_material: StandardMaterial3D
var camera: Camera3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("252c39")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4cddd")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -28, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 3, 4)
	fill.light_energy = 0.65
	fill.omni_range = 8.0
	add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("333b47")
	floor_material.roughness = 0.95
	floor.material_override = floor_material
	add_child(floor)
	model = (load("res://assets/cast/castM02_game.glb") as PackedScene).instantiate()
	add_child(model)
	display = model.find_child("castM02_game_screen", true, false) as MeshInstance3D
	assert(display != null, "The intended M02 screen must exist.")
	original_material = display.get_active_material(0) as StandardMaterial3D
	assert(original_material != null, "The intended M02 screen material must exist.")
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	set_view("body", "front")
	print("ROBOT_EXPRESSION_PREVIEW_READY screen=", display.name,
		" emission_energy=", original_material.emission_energy_multiplier,
		" source_filter=", original_material.texture_filter)

func set_view(mode: String = "body", angle: String = "front") -> void:
	var aim := Vector3(0, 1.27, 0)
	camera.size = 2.85
	if mode == "face":
		aim = Vector3(0, 1.827, 0.508)
		camera.size = 0.90
	var offset := Vector3(0, 0, 6)
	if angle == "diagonal":
		offset = Vector3(2.15, 0.18, 6)
	camera.position = aim + offset
	camera.look_at(aim)

func original_face() -> void:
	display.set_surface_override_material(0, null)

func apply_expression(index: int) -> void:
	assert(index >= 0 and index < NAMES.size())
	var image := Image.new()
	var error := image.load(FOLDER + NAMES[index] + ".png")
	assert(error == OK)
	image.generate_mipmaps()
	var material := original_material.duplicate() as StandardMaterial3D
	material.emission_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(8, 16, 1)
	material.uv1_offset = Vector3.ZERO
	material.texture_repeat = false
	display.set_surface_override_material(0, material)

func inspection() -> Dictionary:
	return {"target": "CastM02", "display_node": str(display.get_path()),
		"surface_count": display.mesh.get_surface_count(),
		"screen_aabb": str(display.get_aabb()),
		"source_emission_energy": original_material.emission_energy_multiplier,
		"source_texture_filter": original_material.texture_filter,
		"expressions": NAMES}
