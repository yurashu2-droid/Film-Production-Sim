extends SceneTree
# Real floor contacts exercise jump eligibility without running the carry driver.
class JumpWorld extends Node3D:
	var props: Dictionary = {}
	var adhesive: Node

var failed := false

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		print("HELD_JUMP_TEST_TIMEOUT")
		quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("HELD_JUMP_CHECK ", label, " ", "OK" if ok else "FAIL")

func platform(world: Node3D, id: int, x: float) -> RigidBody3D:
	var body: RigidBody3D = load("res://scripts/prop.gd").new()
	body.pid = id
	body.fixed = true
	body.game = world
	body.position.x = x
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 0.4, 2)
	shape.shape = box
	shape.position.y = -0.2
	body.add_child(shape)
	world.add_child(body)
	body.set_physics_process(false)
	world.props[id] = body
	return body

func settle(player: CharacterBody3D, position: Vector3) -> void:
	player.position = position
	for i in 8:
		await physics_frame
		player.velocity = Vector3.DOWN
		player.move_and_slide()

func run() -> void:
	var world := JumpWorld.new()
	root.add_child(world)
	world.adhesive = load("res://scripts/adhesive.gd").new()
	world.adhesive.game = world
	world.add_child(world.adhesive)
	world.adhesive.set_physics_process(false)
	var support := platform(world, 1, 0.0)
	platform(world, 2, 4.0)
	platform(world, 3, 8.0)
	var player: CharacterBody3D = load("res://scripts/player.gd").new()
	player.game = world
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.setup("M02")
	await settle(player, Vector3(0, 0.03, 0))
	check(player.is_on_floor() and player.get_slide_collision_count() > 0, "fixture has a real supporting contact")
	check(player._can_jump_from_floor(), "unheld platform allows jumping")
	player.held = support.pid
	check(not player._can_jump_from_floor(), "own held platform cannot be a takeoff point")
	player.add_collision_exception_with(support)
	support.add_collision_exception_with(player)
	check(player.is_on_floor() and not player._can_jump_from_floor(), "cached grounded state after ignoring the held body cannot enable a jump")
	player.remove_collision_exception_with(support)
	support.remove_collision_exception_with(player)
	player.held = 2
	check(player._can_jump_from_floor(), "holding another prop does not disable normal jumping")
	world.adhesive.pairs = [{"a": 1, "b": 3, "joined": true}, {"a": 3, "b": 2, "joined": true}]
	check(not player._can_jump_from_floor(), "indirectly glued support cannot be a takeoff point")
	world.adhesive.pairs.clear()
	check(player._can_jump_from_floor(), "detaching the support allows jumping again")
	player.held = 0
	check(player._can_jump_from_floor(), "releasing the prop allows jumping again")
	player.velocity = Vector3.UP * player.JUMP
	player.move_and_slide()
	check(not player._can_jump_from_floor(), "airborne crew cannot jump again")
	print("HELD_JUMP_TEST_FAIL" if failed else "HELD_JUMP_TEST_OK")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
