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
	# 荷台の箱の底を、離れた3点で車体に留める。留めていない箱が飛ばされた同じ衝撃でも、落ちず、ずれない
	var tied: Node = game.stage.spawn("applebox",Vector3(70,0.1,15))
	game.host_load(tied,truck)
	await frames(60)
	for corner: Vector3 in [Vector3(0.8,-1,0.8),Vector3(-0.8,-1,0.8),Vector3(0,-1,-0.8)]:
		var spot: Vector3 = tied.center+tied.half*corner
		glue.pairs.append({"a":tied.pid,"b":truck.pid,"pa":spot,"pb":truck.to_local(tied.to_global(spot)),"joined":true})
	glue.restore(glue.snapshot())
	var tied_at: Transform3D = tied.global_transform
	tied.apply_central_impulse(Vector3(60,35,0))
	await frames(80)
	check(tied.rider_of == truck.pid and glue.connected_to(tied.pid,truck.pid), "cargo glued to the deck at three spread points stays aboard")
	check(tied.global_position.distance_to(tied_at.origin)<0.03 and tied.global_basis.y.dot(tied_at.basis.y)>0.99, "three spread points hold the cargo in place through the jolt")
	glue.clear()
	tied.set_absent(true)
	var a: Node = game.stage.spawn("applebox",Vector3(70,3,15))
	var b: Node = game.stage.spawn("sandbag",Vector3(72,3,15))
	a.gravity_scale = 0
	b.gravity_scale = 0
	# 点は、向かい合う横の面の上に付ける（留めた物どうしも、点以外の所ではふつうにぶつかる）
	var a_side: Vector3 = a.center+Vector3(a.half.x,0,0)
	var b_side: Vector3 = b.center-Vector3(b.half.x,0,0)
	glue.pairs.append({"a":a.pid,"b":b.pid,"pa":a_side,"pb":b_side,"joined":false})
	await frames(3)
	check(glue.joints.is_empty() and a.global_position.distance_to(b.global_position)>1.5, "distant dots do not teleport objects")
	b.restore([a.to_global(a_side)-b_side,Quaternion.IDENTITY,false])
	game.h_grab(b.pid)
	await frames(3)
	check(glue.joints.size()==1 and not a.freeze and not b.freeze, "touching dots join two dynamic bodies")
	check(b.holder==game.local_player().peer_id and game.local_player().held==b.pid,"joining held object preserves synchronized grip")
	game.h_release()
	check(game.local_player().held==0 and b.holder==0,"bonded object can be released normally")
	# 3つ目は、面どうしを8cm離して置く。12cm以内なので留まり、物理が点どうしを寄せる
	var b_far: Vector3 = b.center+Vector3(b.half.x,0,0)
	var c_side: Vector3 = a.center-Vector3(a.half.x,0,0)
	var c: Node = game.stage.spawn("applebox",b.to_global(b_far)-c_side+Vector3(0.08,0,0))
	c.gravity_scale = 0
	glue.pairs.append({"a":b.pid,"b":c.pid,"pa":b_far,"pb":c_side,"joined":false})
	await frames(30)
	check(glue.joints.size()==2 and glue.bond_metrics().all(func(m): return m.gap<0.02),"adding another contact keeps all selected dots coincident")
	var data: Dictionary = glue.snapshot()
	glue.clear()
	check(glue.joints.is_empty(), "reset removes adhesive constraints")
	glue.restore(data)
	check(glue.connected_to(a.pid,b.pid), "snapshot restores connected objects")
	# 撮り直しのために、いまの配置と接着を覚えておく（main.gd の _take_or_cut と同じ）
	var layout := {a.pid:a.get_state(),b.pid:b.get_state(),c.pid:c.get_state()}
	var layout_glue: Dictionary = glue.snapshot()
	a.gravity_scale = 1
	b.gravity_scale = 1
	c.gravity_scale = 1
	a.apply_central_impulse(Vector3(8,0,0))
	var start_y: float = a.global_position.y
	var partner_y: float = b.global_position.y
	await frames(18)
	check(glue.joints.size()==2 and glue.bond_metrics().all(func(m): return m.gap<0.03) and a.global_position.y<start_y-0.1 and b.global_position.y<partner_y-0.1, "bonded pair moves and falls together")
	# 撮り直しと同じ手順（main.gd の _back_to_prep）：物を覚えた配置へ戻してから、接着を戻す。同じ点で留まったままで、弾けない
	for prop: Node in [a,b,c]:
		prop.restore(layout[prop.pid])
	glue.restore(layout_glue)
	await frames(6)
	var jolt := 0.0
	for prop: RigidBody3D in [a,b,c]:
		jolt = maxf(jolt,prop.linear_velocity.length())
	check(glue.joints.size()==2 and glue.bond_metrics().all(func(m): return m.gap<0.02), "retake restore keeps every bond on its dots")
	check(jolt<1.5 and a.global_position.distance_to(layout[a.pid][0])<0.1, "retake restore does not fling bonded objects")
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
