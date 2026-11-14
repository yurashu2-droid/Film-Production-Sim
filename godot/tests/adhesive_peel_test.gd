extends SceneTree
# 接着剤をはがす（adhesive.gd の h_peel・hook_f・hook_hud）：
#   ・素手で接着剤の点を狙って F を押すと、はがれる。黄（1点目だけ）は、その点が消える
#   ・緑（くっついた組）は、組ごと消えて、留めていた点留め（ジョイント）も外れる
#   ・何かを持っているときは、はがせない（F は、持っている物の操作のまま）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/adhesive_peel_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("PEEL_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var glue: Node = game.adhesive
	var me: Node3D = game.local_player()
	# 接着できる物を2つ、目の前に置く
	var picks: Array = game.props.values().filter(func(p: Node) -> bool: return glue._eligible(p) and not p.absent and p.kind not in ["glue", "clapper"])
	var a: RigidBody3D = picks[0]
	var b: RigidBody3D = picks[1]
	var front: Vector3 = me.global_position + Vector3(0, 0, -1.2)
	a.restore([front + Vector3(-0.4, 0.3, 0), Quaternion.IDENTITY, true])
	b.restore([front + Vector3(0.4, 0.3, 0), Quaternion.IDENTITY, true])
	await frames(5)
	var eye: Vector3 = me.cam.global_position
	# 黄：1点目だけ
	glue.mark(me.peer_id, a.pid, a.center)
	await frames(2)
	var at_a: Vector3 = a.global_transform * a.center
	check(not glue.dot_on_ray(eye, at_a - eye).is_empty(), "aiming at a yellow point finds it")
	check(glue.dot_on_ray(eye, at_a - eye + Vector3(0, 1.0, 0)).is_empty(), "aiming away finds nothing")
	glue.h_peel(eye, at_a - eye)
	await frames(2)
	check(glue.first.is_empty() and glue.markers.is_empty(), "F with an empty hand peels the yellow point")
	# 緑：くっついた組
	glue.restore({"first": {}, "pairs": [{"a": a.pid, "b": b.pid, "pa": a.center, "pb": b.center, "joined": true}]})
	await frames(4)
	var joints_before: int = glue.joints.size()
	var at_b: Vector3 = b.global_transform * b.center
	check(glue.dot_on_ray(eye, at_b - eye).has("pair"), "aiming at a green point finds its pair")
	# 持っている間は、はがせない
	me.held = a.pid
	check(not glue._peelable(me), "holding something, the glue cannot be peeled")
	me.held = 0
	glue.h_peel(eye, at_b - eye)
	await frames(4)
	check(glue.pairs.is_empty() and glue.joints.is_empty(), "peeling a green point removes the pair and its joint (joints %d → %d)" % [joints_before, glue.joints.size()])
	print("PEEL_TEST_FAIL" if failed else "PEEL_TEST_OK")
	quit(1 if failed else 0)
