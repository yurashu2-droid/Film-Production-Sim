extends Node3D
## Standalone asset presentation. Runtime GLB import avoids changing project setup.

var character: Node3D
var player: AnimationPlayer
var camera: Camera3D
var title_layer: CanvasLayer

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_file("res://assets/characters/cardboard_stunt/cardboard_stunt.glb", state)
	assert(result == OK, "Character GLB import failed")
	character = document.generate_scene(state)
	character.name = "Character"
	add_child(character)
	player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null, "GLB animation missing")
	for clip in player.get_animation_list():
		if clip != "RESET":
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)
			break
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("ded8c9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f3e9d8")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	_light(Vector3(-3, 5, 4), 0.95, Color("fff1d4"), true)
	_light(Vector3(3, 3, -2), 0.55, Color("d4e4ee"), false)
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
	camera.size = 2.65
	add_child(camera)
	set_view("hero")
	_build_titles()
	print("STUNT_LAB_READY clips=", player.get_animation_list())

func _light(where: Vector3, energy: float, tint: Color, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	add_child(light)
	light.position = where
	light.look_at(Vector3(0, 0.8, 0))
	light.light_energy = energy
	light.light_color = tint
	light.shadow_enabled = shadows
	light.directional_shadow_max_distance = 15
	light.shadow_bias = 0.03

func _build_titles() -> void:
	title_layer = CanvasLayer.new()
	add_child(title_layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic", "Noto Sans CJK JP", "Arial"])
	font.font_weight = 700
	_label("CHEAP SHOT  /  STUNT DEPARTMENT", Vector2(68, 52), 20, Color("68462c"), font)
	_label("段ボール\nスタントマン", Vector2(64, 108), 58, Color("253738"), font)
	_label("予算は軽い。\n気合いは重い。", Vector2(70, 292), 26, Color("674d3c"), font)
	_label("01", Vector2(69, 535), 96, Color("ac432c"), font)
	_label("KRAFT ARMOR\nGAFFER TAPE\nRUBBER BOOTS", Vector2(78, 683), 18, Color("4c605c"), font)
	_label("3D CHARACTER STUDY   /   2026.10", Vector2(72, 831), 17, Color("68462c"), font)
	_label("SPACE  合図 / 停止\n← →  回転\nR  初期ビュー", Vector2(1290, 744), 16, Color("4c605c"), font)

func _label(text: String, where: Vector2, size: int, color: Color, font: Font) -> void:
	var label := Label.new()
	label.text = text
	label.position = where
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_color", color)
	title_layer.add_child(label)

func set_view(view: String) -> void:
	var target := Vector3(0, 0.95, 0)
	var offset := Vector3(3, 1.65, 5)
	match view:
		"front": offset = Vector3(0, 0.15, 6)
		"left": offset = Vector3(-6, 0.15, 0)
		"right": offset = Vector3(6, 0.15, 0)
		"back": offset = Vector3(0, 0.15, -6)
		"top": offset = Vector3(0, 6, 0.1)
	if view == "hero":
		target += Vector3(-0.40, 0, 0.24)
	camera.position = target + offset
	camera.look_at(target)

func set_time(seconds: float) -> void:
	player.seek(seconds, true)

func show_titles(shown: bool) -> void:
	title_layer.visible = shown

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if player.is_playing(): player.pause()
				else: player.play()
			KEY_LEFT: character.rotation.y -= 0.2
			KEY_RIGHT: character.rotation.y += 0.2
			KEY_R:
				character.rotation.y = 0
				set_view("hero")

func evidence() -> Dictionary:
	var feet := {}
	for side in ["L", "R"]:
		var boot := character.find_child("Boot_sole_" + side, true, false) as Node3D
		feet[side] = [boot.global_position.x, boot.global_position.y, boot.global_position.z]
	return {"clips": player.get_animation_list(), "playing": player.is_playing(),
		"seconds": player.current_animation_position, "meshes": _mesh_count(character), "feet": feet}

func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children(): count += _mesh_count(child)
	return count
