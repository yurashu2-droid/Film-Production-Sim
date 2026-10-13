extends SceneTree
# Dedicated fixture: no game scene, sockets, or player input.
const Stage = preload("res://scripts/stage.gd")
var failed := false

class Fixture extends Node3D:
	var props: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("RUIN_COLLISION_CHECK ", label, " ", "PASS" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func shape_count(body: RigidBody3D) -> int:
	var count := 0
	for child in body.get_children():
		if child is CollisionShape3D:
			count += 1
	return count

func overlap(body: RigidBody3D, at: Vector3, expected: bool, label: String) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.025
	query.shape = sphere
	query.transform.origin = body.global_transform * at
	query.collision_mask = 2
	var hits := body.get_world_3d().direct_space_state.intersect_shape(query)
	var touches := hits.any(func(hit: Dictionary) -> bool: return hit.collider == body)
	check(touches == expected, label)

func sweep(fixture: Node3D, body: RigidBody3D, at: Vector3, motion: Vector3, expected: bool, label: String) -> void:
	var probe := CharacterBody3D.new()
	probe.collision_layer = 8
	probe.collision_mask = 2
	probe.safe_margin = 0.001
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.06
	collider.shape = sphere
	probe.add_child(collider)
	fixture.add_child(probe)
	probe.global_position = body.global_transform * at
	await frames(2)
	var contact := probe.move_and_collide(body.global_basis * motion)
	var touches := contact != null and contact.get_collider() == body
	print("RUIN_COLLISION_SWEEP ", label, " travel=", probe.position, " touched=", touches)
	check(touches == expected, label)
	probe.free()

func test_pose(fixture: Node3D, body: RigidBody3D, pose: Transform3D, suffix: String) -> void:
	body.global_transform = pose
	await frames(2)
	overlap(body, Vector3(0, 1.02, 0.0829232), true, "stone face " + suffix)
	overlap(body, Vector3(-0.6, 1.42, 0.0829232), true, "highest stones " + suffix)
	overlap(body, Vector3(0.4725, 0.18, 0.5929232), true, "fallen stone " + suffix)
	overlap(body, Vector3(-0.8775, 0.075, -0.65), true, "rear foot " + suffix)
	overlap(body, Vector3(-0.8775, 0.575, -0.4770768), true, "sloped brace " + suffix)
	overlap(body, Vector3(-0.8775, 0.86, -0.3091), true, "off-center point follows brace slope " + suffix)
	overlap(body, Vector3(0.65, 1.02, 0.0829232), false, "missing upper stones " + suffix)
	overlap(body, Vector3(1.1, 1.42, 0.0829232), false, "space above lower end " + suffix)
	overlap(body, Vector3(0, 0.9, -0.5), false, "empty rear space " + suffix)
	overlap(body, Vector3(0, 0.9, 0.6), false, "empty front space " + suffix)
	overlap(body, Vector3(-0.8775, 1.02, -0.70), false, "space outside sloped brace " + suffix)
	await sweep(fixture, body, Vector3(0.65, 1.02, 1.2), Vector3(0, 0, -2.4), false, "pass through upper notch " + suffix)
	await sweep(fixture, body, Vector3(0, 1.02, 1.2), Vector3(0, 0, -2.4), true, "stop at stone face " + suffix)
	await sweep(fixture, body, Vector3(-0.8775, 0.075, -1.2), Vector3(0, 0, 1.0), true, "stop at rear foot " + suffix)

func run() -> void:
	var fixture := Fixture.new()
	root.add_child(fixture)
	var stage := Stage.new()
	stage.game = fixture
	fixture.add_child(stage)
	var body: RigidBody3D = stage.spawn("ruin", Vector3.ZERO)
	body.set_fixed(true)
	print("RUIN_COLLISION_SHAPES ", shape_count(body))
	check(shape_count(body) > 1 and shape_count(body) <= 12, "bounded compound primitive count")
	check(is_equal_approx(body.mass, 26.0), "original weight preserved")
	await test_pose(fixture, body, Transform3D.IDENTITY, "identity")
	await test_pose(fixture, body, Transform3D(Basis(Vector3.UP, 1.1), Vector3(4, 0.3, -3)), "translated and rotated")
	var window: RigidBody3D = stage.spawn("window", Vector3(7, 0, 5))
	window.set_fixed(true)
	var flat: RigidBody3D = stage.spawn("flat", Vector3(-7, 0, 5))
	flat.set_fixed(true)
	await frames(2)
	# 窓の壁と書割も、見た目に合わせた形の組み合わせになった（prop_shapes.gd）。表に無い物は、従来どおり箱ひとつ
	var plain: RigidBody3D = stage.spawn("applebox", Vector3(0, 0, 9))
	plain.set_fixed(true)
	check(shape_count(window) > 1 and shape_count(window) <= 12 and shape_count(flat) > 1 and shape_count(flat) <= 12 and shape_count(plain) == 1, "other prop shape generation preserved")
	overlap(window, Vector3(0, 1.2, 0.2), true, "glazed window remains solid")
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(10, 0.2, 10)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)
	fixture.add_child(floor)
	body.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.set_fixed(false)
	await frames(120)
	print("RUIN_COLLISION_SETTLE position=", body.position, " up_y=", body.basis.y.y, " velocity=", body.linear_velocity)
	check(body.position.is_finite() and absf(body.position.y) < 0.1 and body.basis.y.y > 0.95 and body.linear_velocity.length() < 0.3, "dynamic body settles on primitive supports")
	print("RUIN_COLLISION_TEST_FAIL" if failed else "RUIN_COLLISION_TEST_OK")
	fixture.queue_free()
	await process_frame
	quit(1 if failed else 0)
