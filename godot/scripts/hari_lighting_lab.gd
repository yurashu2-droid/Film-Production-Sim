extends "res://scripts/cardboard_stunt_lab.gd"
## Dedicated reference-driven character exhibit, using the earlier neutral rig.

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_file("res://assets/characters/hari_lighting/hari_lighting.glb", state)
	assert(result == OK, "HARI GLB import failed")
	character = document.generate_scene(state)
	character.name = "Character"
	add_child(character)
	player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null, "HARI animation missing")
	player.get_animation("Light_Check").loop_mode = Animation.LOOP_LINEAR
	player.play("Light_Check")
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("ded8c9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f3e9d8")
	environment.ambient_light_energy = 0.50
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	_light(Vector3(-3, 5, 4), 0.95, Color("fff1e2"), true)
	_light(Vector3(3, 3, -2), 0.65, Color("d4e4ee"), false)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ded8c9")
	material.roughness = 1.0
	floor_mesh.material_override = material
	floor_mesh.position.y = -0.004
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	add_child(camera)
	set_view("hero")
	_build_titles()
	print("HARI_LAB_READY clips=", player.get_animation_list(), " meshes=", _mesh_count(character))

func _build_titles() -> void:
	title_layer = CanvasLayer.new()
	add_child(title_layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic", "Noto Sans CJK JP", "Arial"])
	font.font_weight = 700
	_label("CHEAP SHOT  /  LIGHTING CREW", Vector2(68, 52), 20, Color("68462c"), font)
	_label("あかり係\nハリ", Vector2(64, 108), 64, Color("253738"), font)
	_label("小さな灯りで、\n大きな見せ場を。", Vector2(70, 292), 26, Color("674d3c"), font)
	_label("02", Vector2(69, 535), 96, Color("ad7e2b"), font)
	_label("MUSTARD JACKET\nSIDE-PART BOB\nPORTABLE WORK LIGHT", Vector2(78, 683), 18, Color("4c605c"), font)
	_label("REFERENCE → PART STUDIES → 3D", Vector2(72, 831), 17, Color("68462c"), font)
	_label("SPACE  再生 / 停止\n← →  回転\nR  初期ビュー", Vector2(1290, 744), 16, Color("4c605c"), font)

func set_view(view: String) -> void:
	var target := Vector3(0, 0.83, 0)
	var offset := Vector3(2.3, 0.85, 5)
	match view:
		"front": offset = Vector3(0, 0.01, 6)
		"left": offset = Vector3(-6, 0.01, 0)
		"right": offset = Vector3(6, 0.01, 0)
		"back": offset = Vector3(0, 0.01, -6)
		"top": offset = Vector3(0, 6, 0.1)
	if view == "hero": target += Vector3(-0.38, 0, 0.18)
	camera.position = target + offset
	camera.look_at(target)

func set_part(part: String) -> void:
	show_titles(false)
	var target := Vector3(0, 1.35, 0)
	var size := 0.85
	match part:
		"hair": target = Vector3(0, 1.45, 0)
		"cuff":
			target = Vector3(0.38, 0.74, 0.02)
			size = 0.50
		"lamp":
			target = Vector3(0.48, 0.42, 0.02)
			size = 0.66
	camera.size = size
	camera.position = target + Vector3(2.1, 0.6, 5)
	camera.look_at(target)

func reset_view() -> void:
	camera.size = 2.35
	set_view("hero")
	show_titles(true)

func evidence() -> Dictionary:
	var feet := {}
	for side in ["Right", "Left"]:
		var boot := character.find_child("Boot_sole_" + side, true, false) as Node3D
		feet[side] = [boot.global_position.x, boot.global_position.y, boot.global_position.z]
	var wrist := character.find_child("Wrist_Left", true, false) as Node3D
	var lamp := character.find_child("LampPivot", true, false) as Node3D
	return {"clips": player.get_animation_list(), "meshes": _mesh_count(character),
		"seconds": player.current_animation_position, "feet": feet,
		"lamp_attachment": [lamp.position.x, lamp.position.y, lamp.position.z],
		"lamp_is_child_of_hand": lamp.get_parent() == wrist}
