extends SceneTree
# ロケバン（軽トラの上位互換）の荷台・切り替え・出発を確認する。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/vantest.gd
var game: Node
var failed := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		print("VAN_CHECK ", what, " FAIL")


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func inside_deck(r: Node, tol: float = 0.001) -> bool:
	var t: Node = game.truck
	var o: Vector3 = r.ride_local.origin
	return absf(o.x - t.deck_c.x) <= t.deck_half.x + tol and absf(o.z - t.deck_c.y) <= t.deck_half.y + tol


# 荷台の中の物が、見た目の位置（世界座標）でも荷台の上にあるか
func on_deck_world(r: Node) -> bool:
	var want: Vector3 = game.truck.global_transform * r.ride_local.origin
	return r.global_position.distance_to(want) < 0.05


func riders() -> Array:
	var out: Array = []
	for pid: int in game.props:
		var p: Node = game.props[pid]
		if p.rider_of == game.truck.pid:
			out.append(p)
	return out


func shape_count() -> int:
	var n := 0
	for c in game.truck.get_children():
		if c is CollisionShape3D:
			n += 1
	return n


# 後ろ（荷台の外）から荷物の中心へ向けた照準が、その荷物に当たるか（プレイヤーの _find_target と同じ層）
func ray_hits(r: Node, from_local: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(game.truck.global_transform * from_local, r.center_global(), 1 | 2 | 4 | 16)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == r


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var truck: Node = game.truck
	check(truck.vehicle == "kei" and truck.label == "軽トラ" and is_equal_approx(truck.deck_top, (0.67 * truck.VEHICLE_SCALE)), "starts as the kei truck")
	check(shape_count() == 2, "kei truck has two shapes (%d)" % shape_count())

	# 車の段階（ロケバン）は別の開発者の仕組みが production_sync で反映するので、そちらも合わせておく
	flow.levels["car"] = 1
	# 切り替え：数値・ラベル・当たり判定が替わり、同じ指定を繰り返しても変わらない
	truck.set_vehicle("van")
	truck.set_vehicle("van")
	truck.set_vehicle("nonsense")
	await frames(2)
	check(truck.vehicle == "van" and truck.label == "ロケバン", "switches to the van")
	check(shape_count() == 5, "van has five shapes (%d)" % shape_count())
	check(truck.deck_top > 0.3 and truck.deck_half.x > 0.5 and truck.deck_half.y > 1.0, "van has a deck")
	print("VAN_INFO deck_top=%.3f deck_half=%s deck_c=%s" % [truck.deck_top, truck.deck_half, truck.deck_c])
	var vis_nodes := 0
	for c in truck.get_children():
		if c is Node3D and not c is CollisionShape3D and not c.is_queued_for_deletion():
			vis_nodes += 1
	check(vis_nodes == 1, "exactly one visual after repeated switching (%d)" % vis_nodes)

	# 依頼を受ける：カメラとカチンコがバンの床の上、荷室の中に載る
	game.h_accept_job(0)
	await frames(10)
	check(flow.phase == 2, "job accepted")
	for g: Node in [game.film, game.clapper]:
		check(g.rider_of == truck.pid, "%s rides the van" % g.kind)
		check(is_equal_approx(g.ride_local.origin.y, truck.deck_top), "%s sits on the van floor (y=%.3f)" % [g.kind, g.ride_local.origin.y])
		check(inside_deck(g), "%s is inside the cargo area" % g.kind)
		check(on_deck_world(g), "%s follows the van in the world" % g.kind)
	var behind := Vector3(0.0, 1.5, -5.0)
	check(ray_hits(game.film, behind), "aim from behind reaches the camera")
	check(ray_hits(game.clapper, behind), "aim from behind reaches the clapper")
	check(ray_hits(game.film, Vector3(4.0, 1.4, 0.3)), "aim through the sliding door reaches the camera")

	# 空いている小道具をいくつか積む
	var loaded: Array = []
	for pid: int in game.props:
		var p: Node = game.props[pid]
		if flow._is_free(p) and not p.absent and p.rider_of == 0 and p.deck_top < 0.0 and not p.fixed and not p.immovable:
			loaded.append(p)
	loaded.sort_custom(func(a: Node, b: Node) -> bool: return a.pid < b.pid)
	check(loaded.size() >= 3, "there are free props to load (%d)" % loaded.size())
	loaded = loaded.slice(0, 6)
	var reachable := 0
	for p: Node in loaded:
		# 荷台の外（後ろ）で手を離したことにして、そこから積む
		p.global_position = truck.global_transform * Vector3(0.1, truck.deck_top + 0.5, -2.0)
		game.host_load(p, truck)
		check(p.rider_of == truck.pid, "%s is loaded" % p.kind)
		check(inside_deck(p), "%s is inside the van deck (%s)" % [p.kind, p.ride_local.origin])
		check(p.ride_local.origin.y >= truck.deck_top - 0.001, "%s is not below the floor" % p.kind)
	await frames(5)
	for p: Node in loaded:
		check(on_deck_world(p), "%s follows the van in the world" % p.kind)
		if ray_hits(p, behind):
			reachable += 1
	check(reachable >= 1, "a loaded prop can be aimed at from behind (%d of %d)" % [reachable, loaded.size()])
	var before: Dictionary = {}
	for r: Node in riders():
		before[r.pid] = r.ride_local.origin

	# 走る：バンのまま着く。荷物は載ったまま
	flow.prep_left = 100.0
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	check(flow.phase == 3, "van departs")
	for i in 800:
		if flow.phase == 4:
			break
		await physics_frame
	check(flow.phase == 4, "van arrives")
	await frames(5)
	check(truck.vehicle == "van", "still a van at the site")
	check(truck.global_position.distance_to(flow.SITE_TRUCK) < 0.5, "van is parked at the site")
	for pid: int in before:
		var r: Node = game.props[pid]
		check(r.rider_of == truck.pid, "%s still rides after arriving" % r.kind)
		check(on_deck_world(r), "%s moved with the van" % r.kind)
		check((r.ride_local.origin - (before[pid] as Vector3)).length() < 0.01, "%s kept its place on the deck" % r.kind)
	check(game.film.rider_of == truck.pid and game.clapper.rider_of == truck.pid, "company gear arrived")

	# 軽トラへ戻す：荷物は付いたまま、軽トラの荷台の高さに合わせてずれる
	truck.set_vehicle("kei")
	await frames(3)
	check(truck.vehicle == "kei" and truck.label == "軽トラ" and is_equal_approx(truck.deck_top, (0.67 * truck.VEHICLE_SCALE)), "back to the kei truck")
	check(shape_count() == 2, "kei shapes restored (%d)" % shape_count())
	for pid: int in before:
		var r: Node = game.props[pid]
		check(r.rider_of == truck.pid, "%s still rides after switching back" % r.kind)
		check(inside_deck(r), "%s is inside the kei deck" % r.kind)
		var dy: float = r.ride_local.origin.y - (before[pid] as Vector3).y
		check(absf(dy - ((0.67 * truck.VEHICLE_SCALE) - (0.55 * truck.VEHICLE_SCALE))) < 0.001, "%s moved up by the deck difference (%.3f)" % [r.kind, dy])
		check(on_deck_world(r), "%s follows the kei in the world" % r.kind)
	truck.set_vehicle("van")
	await frames(3)
	for pid: int in before:
		var r: Node = game.props[pid]
		check(r.rider_of == truck.pid and inside_deck(r) and on_deck_world(r), "%s is fine after going back to the van" % r.kind)
		check(r.ride_local.origin.y >= truck.deck_top - 0.001, "%s is back on the van floor" % r.kind)
	check(shape_count() == 5, "van shapes restored (%d)" % shape_count())

	print("VANTEST_FAIL" if failed else "VANTEST_OK")
	quit(1 if failed else 0)
