extends SceneTree
var failed := false
func check(ok: bool, label: String) -> void:
	print("CARGO_ADHESIVE_CHECK ",label," ","OK" if ok else "FAIL")
	failed = failed or not ok
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	run.call_deferred()
func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	check(not game.film.freeze, "initial truck cargo uses gravity")
	check(not InputMap.has_action("fix"), "G fixing action removed")
	check(game.get("adhesive") != null, "company supplies adhesive")
	if game.get("adhesive") == null:
		game.queue_free()
		await process_frame
		quit(1)
		return
	var glue: Node = game.adhesive
	game.production.set_physics_process(false)
	game._set_state(game.S.PREP)
	game.local_player().global_position = Vector3(72,0.1,14)
	var truck: Node = game.truck
	var item: Node = game.stage.spawn("applebox",Vector3(70,0.1,15))
	game.host_load(item,truck)
	await frames(60)
	check(not item.freeze and item.rider_of == truck.pid, "cargo rests physically on deck")
	check(not item.get_collision_exceptions().has(truck), "deck collision stays enabled")
	item.apply_central_impulse(Vector3(60,35,0))
	await frames(80)
	check(item.rider_of == 0, "cargo thrown above sideboard falls off without invisible lock")
	var a: Node = game.stage.spawn("applebox",Vector3(70,3,15))
	var b: Node = game.stage.spawn("sandbag",Vector3(72,3,15))
	a.gravity_scale = 0
	b.gravity_scale = 0
	glue.pairs.append({"a":a.pid,"b":b.pid,"pa":Vector3.ZERO,"pb":Vector3.ZERO,"joined":false})
	await frames(3)
	check(glue.joints.is_empty() and a.global_position.distance_to(b.global_position)>1.5, "distant dots do not teleport objects")
	b.restore([a.global_position,Quaternion.IDENTITY,false])
	game.h_grab(b.pid)
	await frames(3)
	check(glue.joints.size()==1 and not a.freeze and not b.freeze, "touching dots join two dynamic bodies")
	check(b.holder==game.local_player().peer_id and game.local_player().held==b.pid,"joining held object preserves synchronized grip")
	game.h_release()
	check(game.local_player().held==0 and b.holder==0,"bonded object can be released normally")
	var c: Node = game.stage.spawn("applebox",a.global_position+Vector3(0.08,0,0))
	c.gravity_scale = 0
	# Isolate the joint anchor test from the overlapping synthetic body geometry.
	c.collision_layer = 0
	c.collision_mask = 0
	glue.pairs.append({"a":b.pid,"b":c.pid,"pa":Vector3.ZERO,"pb":Vector3.ZERO,"joined":false})
	await frames(10)
	check(glue.joints.size()==2 and a.global_position.distance_to(b.global_position)<0.02 and b.global_position.distance_to(c.global_position)<0.02,"adding another contact keeps all selected dots coincident")
	var data: Dictionary = glue.snapshot()
	glue.clear()
	check(glue.joints.is_empty(), "reset removes adhesive constraints")
	glue.restore(data)
	check(glue.connected_to(a.pid,b.pid), "snapshot restores connected objects")
	a.gravity_scale = 1
	b.gravity_scale = 1
	a.apply_central_impulse(Vector3(8,0,0))
	var start_y: float = a.global_position.y
	await frames(18)
	check(a.global_position.distance_to(b.global_position)<0.12 and a.global_position.y<start_y-0.1, "bonded pair moves and falls together")
	var heavy: Node = game.stage.spawn("sandbag",Vector3(65,0,15))
	heavy.set_fixed(false)
	game.production._gust_dir = Vector3(1,0,0)
	check(heavy.mass==12 and not heavy.freeze, "existing sandbag is a real 12kg weight")
	var v: Vector3 = heavy.linear_velocity
	game.production._blow(1.0/60.0)
	await frames(1)
	check(absf(heavy.linear_velocity.x-v.x)<0.05, "heavy weight resists gust by mass")
	print("CARGO_ADHESIVE_TEST_FAIL" if failed else "CARGO_ADHESIVE_TEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
