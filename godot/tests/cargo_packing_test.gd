extends SceneTree
# Physical regressions: releasing must not upright cargo; visible truck panels must stop it.
var game: Node
var failed := false
func check(ok: bool, label: String) -> void:
	print("CARGO_PACKING_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	run.call_deferred()
func hit(from: Vector3, to: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,2))
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	await frames(12)
	game._set_state(game.S.PREP)
	var truck: Node = game.truck
	truck.global_transform = Transform3D(Basis.IDENTITY,Vector3(40,5,40))
	for p in game.props.values():
		if p != truck: p.set_absent(true)
	var box: Node = game.stage.spawn("applebox",Vector3(40,7,39))
	var basis := Basis.from_euler(Vector3(PI*0.5,0.3,0))
	box.restore([Vector3(40,7,39),Quaternion(basis),false])
	box.set_holder(1)
	var before: Transform3D = box.global_transform
	game.host_release(box)
	check(box.global_transform.is_equal_approx(before),"drop preserves the hand-arranged position and tilt")
	check(box.rider_of == truck.pid and not box.freeze,"drop registers dynamic cargo without snapping")
	box.set_absent(true)
	game.film.set_absent(false)
	game.film.restore([Vector3(35,7,40),Quaternion.IDENTITY,false])
	game.local_player().hold_pitch = PI*0.4
	check(absf(float(game.hold_target(1,game.film)[3]))>1.0,"camera can be tilted for packing")
	game.film.set_absent(true)
	await frames(3)
	check(hit(Vector3(40,6.25,38.9),Vector3(42,6.25,38.9)).get("collider")==truck,"right sideboard blocks cargo")
	check(hit(Vector3(40,6.25,38.9),Vector3(38,6.25,38.9)).get("collider")==truck,"left sideboard blocks cargo")
	check(hit(Vector3(40,6.25,38.9),Vector3(40,6.25,40.5)).get("collider")==truck,"front of bed blocks cargo")
	truck.set_traveling(true)
	await frames(3)
	check(hit(Vector3(40,6.25,38.9),Vector3(40,6.25,36.8)).get("collider")==truck,"closed tailgate blocks cargo")
	truck.set_traveling(false)
	await frames(3)
	check(hit(Vector3(40,6.25,38.9),Vector3(40,6.25,36.8)).is_empty(),"open tailgate leaves a real loading opening")
	check(hit(Vector3(40,6.5,37.15),Vector3(40,5.8,37.15)).get("collider")==truck,"open tailgate supports cargo as a horizontal panel")
	# A small dynamic box strikes the sideboard at carrying speed, below its top edge.
	var probe: Node = load("res://scripts/prop.gd").new()
	probe.game = game
	probe.mass = 2
	probe.center = Vector3(0,0.12,0)
	probe.half = Vector3.ONE*0.12
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE*0.24
	cs.shape = shape
	cs.position = probe.center
	probe.add_child(cs)
	game.add_child(probe)
	probe.global_position = Vector3(40,6.10,38.9)
	probe.gravity_scale = 0
	probe.linear_velocity = Vector3(8,0,0)
	await frames(40)
	check(probe.global_position.x<40.99,"carrying-speed cargo cannot tunnel through sideboard")
	probe.restore([Vector3(40,6.10,38.9),Quaternion(Basis(Vector3.UP,-PI*0.5)),false])
	game.local_player().global_position = Vector3(38.5,5.5,38.9)
	game.local_player().aim_yaw = -PI*0.5
	game.local_player().aim_pitch = 0.0
	game.local_player().hold_pitch = 0
	game.local_player().hold_dist = 4.0
	probe.set_holder(1)
	await frames(90)
	check(probe.global_position.x<40.99,"held cargo presses against the wall instead of passing through")
	probe.queue_free()
	box.set_absent(false)
	box.restore([Vector3(40,8,38.9),Quaternion(basis),false])
	game.host_load(box,truck)
	check(Quaternion(box.global_basis.orthonormalized()).angle_to(Quaternion(basis))<0.01,"F loading assistance preserves cargo tilt")
	await frames(90)
	check(box.rider_of==truck.pid and box.global_position.y>5.9,"tilted cargo settles physically on deck")
	print("CARGO_PACKING_TEST_FAIL" if failed else "CARGO_PACKING_TEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
