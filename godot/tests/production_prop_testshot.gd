extends SceneTree
const Cart = preload("res://scripts/production_prop.gd")
class MockGame extends Node:
	var props := {}
	func hold_target(_id: int, prop: Node) -> Array:
		return [Vector3(1.5, prop.center.y, 1.7), 0.0, 0.0, 0.0]
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
	floor_box.size = Vector3(10, 0.1, 10)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.05
	floor.add_child(floor_shape)
	world.add_child(floor)
	var lift := Cart.new()
	lift.build_model("lift_cart")
	lift.game = mock
	lift.pid = 81
	world.add_child(lift)
	lift.set_fixed(true)
	mock.props[81] = lift
	var cleaning := Cart.new()
	cleaning.build_model("cleaning_cart")
	world.add_child(cleaning)
	cleaning.position.z = 1.7
	cleaning.set_fixed(true)
	var rider := preload("res://scripts/prop.gd").new()
	rider.pid = 82
	rider.game = mock
	rider.rider_of = 81
	rider.ride_local.origin = Vector3(0, lift.deck_top, 0)
	world.add_child(rider)
	mock.props[82] = rider
	var rider_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.24, 0.28)
	rider_mesh.mesh = box
	rider_mesh.position.y = 0.12
	rider.add_child(rider_mesh)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13,0.17,0.21)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	light.light_energy = 1.8
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2.6,2.2,3.6)
	camera.look_at(Vector3(0,0.6,0.8))
	camera.current = true
	await _shot("production_carts_low")
	var low := lift.deck_top
	lift.set_active(true)
	cleaning.set_active(true)
	for i in 195:
		await physics_frame
	print("PRODUCTION_CART low=",low," high=",lift.deck_top," rider=",rider.ride_local.origin.y," state=",lift.get_state())
	assert(lift.deck_top > low + 0.5)
	assert(absf(rider.ride_local.origin.y - lift.deck_top) < 0.001)
	assert(lift.can_board())
	assert(lift.rolls and cleaning.rolls and lift.mass > 0.0)
	await _shot("production_carts_high")
	lift.set_active(false)
	for i in 195:
		await physics_frame
	assert(absf(lift.deck_top - low) < 0.001)
	assert(absf(rider.ride_local.origin.y - low) < 0.001)
	cleaning.game = mock
	cleaning.set_fixed(false)
	cleaning.set_holder(1)
	for i in 60:
		await physics_frame
	assert(cleaning.position.x > 0.5)
	cleaning.set_holder(0)
	print("PRODUCTION_CARRY position=", cleaning.position)
	print("PRODUCTION_CART_PASS")
	quit()
func _shot(filename: String) -> void:
	for i in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+filename+".png"))


