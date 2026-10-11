extends SceneTree
var game: Node
var failed := false
var sample := {}
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		print("DRIVING_CHECK ", what, " FAIL")
func frames(n: int) -> void:
	for i in n: await physics_frame
func sample_pose(p: Node) -> void:
	var s: Skeleton3D = p.vis.skel
	sample = {}
	for bone: String in ["BODY", "HAND.L", "HAND.R"]:
		sample[bone] = s.global_transform * s.get_bone_global_pose(s.find_bone(bone)).origin
	var seat: Dictionary = game.truck.seat(0)
	sample["seat"] = game.truck.global_transform * seat.hip
	sample["wheel"] = game.truck.global_transform * seat.wheel
func settle_pose(p: Node) -> void:
	p.vis.skel.get_node("SeatedPose").modification_processed.connect(sample_pose.bind(p))
	await frames(4)
func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete: await process_frame
	await frames(5)
	var p: Node = game.local_player()
	check(p.has_method("board_vehicle"), "player supports seated vehicle travel")
	if not p.has_method("board_vehicle"):
		print("VEHICLE_DRIVING_TEST_FAIL")
		quit(1)
		return
	game.h_accept_job(0)
	if "hazards" in game.production:
		game.production.hazards = false
	var variants: Array = ["kei", "van"] if game.truck.has_method("set_vehicle") else ["kei"]
	for kind: String in variants:
		if "levels" in game.production:
			game.production.levels["car"] = 1 if kind == "van" else 0
		if game.truck.has_method("set_vehicle"):
			game.truck.set_vehicle(kind)
		for tag: String in game.PLAYER_CASTS:
			p.set_cast(tag)
			game.production.phase = 3
			p.board_vehicle(game.truck, 0)
			await settle_pose(p)
			var hip: Vector3 = sample["BODY"]
			var seat: Dictionary = game.truck.seat(0)
			check(hip.distance_to(sample.seat) < 0.035, kind + tag + " pelvis contacts seat")
			for side: String in ["L", "R"]:
				var hand: Vector3 = sample["HAND." + side]
				var wheel: Vector3 = sample.wheel
				check(absf(hand.distance_to(wheel) - float(seat.radius)) < 0.10, kind + tag + side + " hand holds steering rim")
			check(p.collision_layer == 0 and p.collision_mask == 0, "seated player cannot be pushed out by vehicle")
			check(p.vis.scale.is_equal_approx(Vector3.ONE), "character retains its normal size")
			game.production.phase = 2
			p.leave_vehicle()
			await frames(2)
			check(p.collision_layer == 8 and p.collision_mask == 15 and not p.vis.skel.has_node("SeatedPose"), "exit restores walking collision and removes seat pose")
			var head: int = p.vis.skel.find_bone("HEAD")
			if head >= 0:
				check(p.vis.skel.get_bone_pose_scale(head).is_equal_approx(Vector3.ONE), "exit restores original head proportions")
			p.global_position = game.production.HOME_TRUCK + Vector3(-3,0.1,0)
	if "levels" in game.production:
		game.production.levels["car"] = 0
	if game.truck.has_method("set_vehicle"):
		game.truck.set_vehicle("kei")
	p.global_position = game.production.HOME_TRUCK + Vector3(-3,0.1,0)
	await frames(3)
	game.h_depart()
	await frames(60)
	check(p.vehicle_riding(), "departure seats actual player")
	check(p.global_position.distance_to(game.truck.global_position) < 4.0, "seat follows moving truck")
	game.production.arrive()
	await frames(3)
	check(not p.vehicle_riding() and p.collision_layer == 8, "arrival restores normal player")
	game._roster = [[1,0],[2,1],[3,6],[4,4]]
	game._apply_roster()
	game.production.phase = 3
	await frames(4)
	var positions: Array[Vector3] = []
	for id: int in game.players:
		var member: Node = game.players[id]
		check(member.vehicle_riding(), "all four crew board")
		for previous: Vector3 in positions:
			check(previous.distance_to(member.global_position) > 0.4, "crew have separate seats")
		positions.append(member.global_position)
	game.production.phase = 4
	await frames(2)
	for member: Node in game.players.values():
		check(not member.vehicle_riding() and member.collision_layer == 8,"all crew exit")
	print("VEHICLE_DRIVING_TEST_FAIL" if failed else "VEHICLE_DRIVING_TEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
