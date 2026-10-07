extends SceneTree
const MovieProp = preload("res://scripts/production_movie_prop.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var dragon := MovieProp.new()
	dragon.build_model("dragon_skull")
	world.add_child(dragon)
	dragon.set_fixed(true)
	var pot := MovieProp.new()
	pot.build_model("witch_cauldron")
	world.add_child(pot)
	pot.position.x = 1.1
	pot.set_fixed(true)
	print("MOVIE_PROP dragon raw=",dragon.source_bounds," size=",dragon.half*2," mass=",dragon.mass)
	print("MOVIE_PROP pot raw=",pot.source_bounds," size=",pot.half*2," mass=",pot.mass)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16,0.20,0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	light.light_energy = 1.1
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(1.8,1.3,2.0)
	camera.look_at(Vector3(0.55,0.3,0))
	camera.current = true
	assert(dragon.can_activate() and not pot.can_activate())
	await _shot("production_movie_closed")
	dragon.set_active(true)
	var open_state := dragon.get_state()
	var jaw_pose: Transform3D = dragon._jaw.transform
	await _shot("production_movie_open")
	dragon.set_active(false)
	assert(not dragon._jaw.transform.is_equal_approx(jaw_pose))
	dragon.restore(open_state)
	assert(dragon.active and dragon._jaw.transform.is_equal_approx(jaw_pose))
	pot.set_active(true)
	assert(not pot.active)
	dragon.set_holder(1)
	assert(dragon.holder == 1 and dragon.gravity_scale == 0.0)
	dragon.set_holder(0)
	print("MOVIE_PROP_PASS")
	quit()
func _shot(filename: String) -> void:
	for i in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+filename+".png"))

