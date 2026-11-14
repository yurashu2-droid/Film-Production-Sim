extends SceneTree
const Stage = preload("res://scripts/stage.gd")
var failed := false

class Fixture extends Node3D:
	var props: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("PLYWOOD_STRUCTURE_CHECK ", label, " ", "PASS" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func visible_contact(visual: Node3D, point: Vector3, except: MeshInstance3D) -> bool:
	for part in visual.get_children():
		if part is MeshInstance3D and part != except:
			var local_point: Vector3 = part.transform.affine_inverse() * point
			if part.mesh.get_aabb().grow(0.008).has_point(local_point):
				return true
	return false

func overlap(body: RigidBody3D, at: Vector3, expected: bool, label: String) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.01
	query.shape = sphere
	query.transform.origin = body.global_transform * at
	query.collision_mask = 2
	var hits := body.get_world_3d().direct_space_state.intersect_shape(query)
	var touches := hits.any(func(hit: Dictionary) -> bool: return hit.collider == body)
	check(touches == expected, label)

func run() -> void:
	var fixture := Fixture.new()
	root.add_child(fixture)
	var stage := Stage.new()
	stage.game = fixture
	fixture.add_child(stage)
	var body: RigidBody3D = stage.spawn_plywood(Vector3.ZERO, 0)
	body.set_fixed(true)
	var braces: Array[MeshInstance3D] = []
	var posts: Array[MeshInstance3D] = []
	var rails: Array[MeshInstance3D] = []
	var painted_faces := 0
	for part in body.visual.get_children():
		if not (part is MeshInstance3D) or not (part.mesh is BoxMesh):
			continue
		var box: BoxMesh = part.mesh
		if absf(part.rotation.x) > 0.1:
			braces.append(part)
		elif box.size.y > 2.0 and box.size.x < 0.1 and box.size.z < 0.1:
			posts.append(part)
		elif box.size.x > 0.8 and box.size.y < 0.12 and box.size.z < 0.08:
			rails.append(part)
		var material: StandardMaterial3D = part.material_override
		if material != null and material.albedo_texture != null:
			painted_faces += 1
			check(box.size.is_equal_approx(Vector3(1.5, 2.5, 0.02)) and part.position.is_equal_approx(Vector3(0, 1.25, 0.012)), "painted face dimensions and placement preserved")
	check(painted_faces == 1 and body.one_sided and is_equal_approx(body.mass, 7.0), "one scenic face and original weight")
	check(braces.size() == 2 and posts.size() == 2 and rails.size() == 3, "complete rear frame")
	for brace in braces:
		var box: BoxMesh = brace.mesh
		var top: Vector3 = brace.transform * Vector3(0, box.size.y * 0.5, 0)
		var bottom: Vector3 = brace.transform * Vector3(0, -box.size.y * 0.5, 0)
		print("PLYWOOD_STRUCTURE_BRACE top=", top, " bottom=", bottom)
		check(top.z > -0.15 and bottom.z < -0.5, "brace slopes from frame to rear foot")
		check(visible_contact(body.visual, top, brace), "upper brace end has visible support")
		check(visible_contact(body.visual, bottom, brace), "lower brace end has visible support")
		var lowest := INF
		for i in 8:
			lowest = minf(lowest, (brace.transform * box.get_aabb().get_endpoint(i)).y)
		check(lowest >= -0.001, "brace does not penetrate floor")
	for rail in rails:
		var box: BoxMesh = rail.mesh
		var left: Vector3 = rail.transform * Vector3(-box.size.x * 0.5, 0, 0)
		var right: Vector3 = rail.transform * Vector3(box.size.x * 0.5, 0, 0)
		check(visible_contact(body.visual, left, rail) and visible_contact(body.visual, right, rail), "horizontal rail endpoints meet frame")
		check(absf(left.x + 0.465) < 0.002 and absf(right.x - 0.465) < 0.002, "rail uses butt joints instead of deep overlap")
	await frames(2)
	overlap(body, Vector3(0, 1.5, 0.002), true, "scenic panel remains solid")
	overlap(body, Vector3(0.5, 1.7, -0.0405), true, "rear upright has collision")
	overlap(body, Vector3(0.5, 0.5275, -0.3485), true, "diagonal support has collision")
	overlap(body, Vector3(0.5, 0.8, -0.1977), true, "off-center collision follows diagonal slope")
	overlap(body, Vector3(0.5, 0.025, -0.3), true, "foot has collision")
	overlap(body, Vector3(0, 0.03, -0.45), false, "space between rear feet stays empty")
	body.global_transform = Transform3D(Basis(Vector3.UP, 0.8), Vector3(4, 0.2, -3))
	await frames(2)
	overlap(body, Vector3(0.5, 0.5275, -0.3485), true, "rotated support collision follows model")
	overlap(body, Vector3(0.5, 0.8, -0.1977), true, "rotated off-center diagonal collision")
	overlap(body, Vector3(0, 0.03, -0.45), false, "rotated empty rear space")
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8, 0.2, 8)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)
	fixture.add_child(floor)
	body.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))
	body.set_fixed(false)
	await frames(120)
	print("PLYWOOD_STRUCTURE_SETTLE position=", body.position, " up_y=", body.basis.y.y, " velocity=", body.linear_velocity)
	check(body.position.is_finite() and absf(body.position.y) < 0.1 and body.basis.y.y > 0.95 and body.linear_velocity.length() < 0.3, "assembled board rests on floor")
	print("PLYWOOD_STRUCTURE_TEST_FAIL" if failed else "PLYWOOD_STRUCTURE_TEST_OK")
	fixture.queue_free()
	await process_frame
	quit(1 if failed else 0)
