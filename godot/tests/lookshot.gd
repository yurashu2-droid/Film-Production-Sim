extends SceneTree
# 同じモデルを「ちゃんとした照明」で撮る比較用。 godot --path godot -s res://tests/lookshot.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.85, 0.87, 0.9)
	sm.sky_horizon_color = Color(0.9, 0.9, 0.9)
	sm.ground_bottom_color = Color(0.6, 0.6, 0.6)
	sm.ground_horizon_color = Color(0.85, 0.85, 0.85)
	sky.sky_material = sm
	e.sky = sky
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.62, 0.63)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.ssao_radius = 0.6
	e.ssao_intensity = 2.2
	e.ssil_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.25
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 38, 0)
	key.light_energy = 0.85
	key.light_color = Color(1.0, 0.97, 0.92)
	key.shadow_enabled = true
	key.light_angular_distance = 2.5
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 20.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -120, 0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.8, 0.88, 1.0)
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.62, 0.63)
	fm.roughness = 0.95
	floor.material_override = fm
	world.add_child(floor)

	var x := -2.3
	for tag: String in ["01", "02", "03"]:
		var m: Node3D = (load("res://assets/cast/cast%s_game.glb" % tag) as PackedScene).instantiate()
		m.scale = Vector3.ONE * 0.62
		m.position = Vector3(x, 0, 0)
		m.rotation.y = 0.25
		world.add_child(m)
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(tag + "_idle")
		ap.seek(0.6, true)
		x += 1.75
	var tri: Node3D = (load("res://assets/gear/T06_Fluid_Tripod.glb") as PackedScene).instantiate()
	tri.position = Vector3(2.9, 0, 0.3)
	tri.rotation.y = -0.6
	world.add_child(tri)
	var cam_model: Node3D = (load("res://assets/gear/C04_Field_Camera.glb") as PackedScene).instantiate()
	tri.find_child("ATTACH_C04_CAMERA_ROOT", true, false).add_child(cam_model)
	var box: Node3D = (load("res://assets/gear/carton.glb") as PackedScene).instantiate()
	box.position = Vector3(3.5, 0, 1.2)
	box.rotation.y = 0.5
	world.add_child(box)

	var cam := Camera3D.new()
	cam.fov = 32.0
	world.add_child(cam)
	cam.global_position = Vector3(0.9, 1.6, 9.6)
	cam.look_at(Vector3(0.75, 0.8, 0))
	cam.make_current()
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	root.get_texture().get_image().save_png("res://tests/shots/look_studio.png")
	print("LOOKSHOT_OK")
	quit()
