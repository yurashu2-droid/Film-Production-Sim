extends SceneTree
const MovieProp = preload("res://scripts/production_movie_prop.gd")
class MockGame extends Node:
	var props := {}
	func hold_target(_id: int, prop: Node) -> Array:
		return [Vector3(0.6, 1.35, 0), 0.3, 0.0, 0.0]
var mock := MockGame.new()
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(mock)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(10,0.1,10)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.05
	floor.add_child(floor_shape)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10,10)
	ground.mesh = plane
	world.add_child(ground)
	world.add_child(floor)
	var monster := MovieProp.new()
	monster.build_model("tomato_monster")
	monster.game = mock
	monster.pid = 201
	world.add_child(monster)
	var original := monster.get_state()
	print("TOMATO bounds=",monster.source_bounds," size=",monster.half*2," mass=",monster.mass)
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
	camera.position = Vector3(2.2,1.8,-3.0)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	for i in 60:
		await physics_frame
	assert(absf(monster.position.y) < 0.08)
	await _shot("production_tomato_floor")
	monster.set_holder(1)
	for i in 90:
		await physics_frame
	assert(monster.holder == 1 and monster.position.x > 0.3 and monster.position.y > 0.5)
	print("TOMATO held=",monster.global_position)
	await _shot("production_tomato_held")
	monster.set_holder(0)
	var deck := Node3D.new()
	world.add_child(deck)
	deck.position = Vector3(0,0.5,0)
	mock.props[202] = deck
	monster.rider_of = 202
	monster.ride_local = Transform3D(Basis.IDENTITY, Vector3(0,0.1,0))
	monster._apply_freeze()
	for i in 3:
		await physics_frame
	assert(monster.global_position.is_equal_approx(Vector3(0,0.6,0)))
	monster.restore(original)
	for i in 3:
		await physics_frame
	assert(monster.rider_of == 0 and monster.holder == 0 and monster.position.length() < 0.1)
	assert(not monster.can_activate())
	print("TOMATO_PROP_PASS")
	quit()
func _shot(filename: String) -> void:
	for i in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+filename+".png"))
