extends SceneTree
const Assets = preload("res://scripts/production_assets.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	for filename in ["studio", "cleaning_cart", "lift_cart", "hose_reel", "shutter"]:
		var prop := load("res://assets/production/" + filename + ".glb").instantiate() as Node3D
		world.add_child(prop)
		var bounds := AABB()
		var first := true
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var clips: Array = []
		for player in prop.find_children("*", "AnimationPlayer", true, false):
			clips.append_array(Array(player.get_animation_list()))
		print("PRODUCTION_ASSET ", filename, " bounds=", bounds, " clips=", clips)
		prop.queue_free()
	await process_frame
	for area in ["office", "studio", "yard"]:
		var decor := Assets.decorate(world, area)
		print("PRODUCTION_DECOR ", area, " children=", decor.get_child_count())
		decor.queue_free()
	await process_frame
	Assets.decorate(world, "scrapyard")
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor.mesh = plane
	world.add_child(floor)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.20, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 2.0
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(7, 6, 9)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
	for i in 8:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://../artifacts/production_assets.png")
		root.get_texture().get_image().save_png(path)
		print("PRODUCTION_SCREENSHOT ", path)
	print("PRODUCTION_ASSET_PASS")
	quit()

