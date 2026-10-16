extends SceneTree
# 役者を雇う（scripts/features/stand_ins.gd・main.gd の OPTIONS「ベテラン役者」「劇団の新人」）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/hire_test.gd
# 普段の遊び（flow.daily）では、雇わないと役者は出ない。雇うと、空いている役に入る（ベテランが先）。
# 班が役に入ると、雇った役者は空いている役へまわる。新人には、出遅れ・通り過ぎ・転ぶ、が起きる。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("HIRE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func option(id: String) -> Dictionary:
	for opt: Dictionary in game.OPTIONS:
		if opt["id"] == id:
			return opt
	return {}


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var roles: Node = game.hooks.feature("stand_ins")
	var me: Node3D = game.local_player()
	var a: Node = game.actors[0]
	var b: Node = game.actors[1]
	flow.daily = true          # 普段の遊びと同じにする（自動確認の中だけ付く、無料のベテランを外す）
	game.h_accept_job(int(flow.debut_job()))
	await frames(5)
	check(roles.plan == ["none", "none"] and not a.vis.visible and not b.vis.visible and a.global_position.y < -10.0, "雇わなければ、役者は出ない（%s）" % str(roles.plan))
	check(not option("actor_pro").is_empty() and int(option("actor_pro")["cost"]) > int(option("actor_new")["cost"]) and not option("actor_pro")["buy"], "発注に、ベテラン役者（高い）と劇団の新人（安い）がある。買えない（借りるだけ）")
	game.h_open_order()
	game.h_order_set("actor_pro", 1)
	check(game.order_max(option("actor_new")) == 1, "ベテランと新人を合わせて、2人まで")
	game.h_order_set("actor_new", 2)
	check(int(game.order.get("actor_new", 0)) == 1, "3人目は頼めない")
	check(game.order_cost() == int(option("actor_pro")["cost"]) + int(option("actor_new")["cost"]), "役者代は、制作費から払う（%d）" % game.order_cost())
	game.h_order_confirm()
	await frames(8)
	check(roles.plan == ["pro", "rookie"] and a.vis.visible and b.vis.visible and a.grade == "pro" and b.grade == "rookie", "雇うと、A にベテラン・B に新人が入る（%s）" % str(roles.plan))
	# 班が A に入ると、雇ったベテランは B へまわる（新人は余る）
	roles.h_cast_actor.rpc_id(1, "player", int(me.peer_id), 0)
	await frames(4)
	check(roles.plan == ["stand", "pro"] and a.stand_in == me and b.grade == "pro", "班が A に入ると、雇ったベテランは空いている B へ（%s）" % str(roles.plan))
	roles.h_cast_actor.rpc_id(1, "player", int(me.peer_id), -1)
	await frames(4)
	# 新人のハプニング：場面の動きごとに、出遅れ・通り過ぎ・転ぶ、が起きる。ベテランには起きない
	var counts := {"late": 0, "over": 0, "trip": 0}
	for i in 60:
		b.grade = "rookie"
		b.play_beat({"to": b.global_position + Vector3(0, 0, 3), "gait": "walk", "pose": "idle", "look": "", "face_go": "neutral", "face_hold": "neutral"})
		counts["late"] += 1 if b._late > 0.0 else 0
		counts["over"] += 1 if b._over > 0.0 else 0
		counts["trip"] += 1 if b._trip_at > 0.0 else 0
	check(counts["late"] > 10 and counts["over"] > 10 and counts["trip"] > 3, "新人は、出遅れる・通り過ぎる・転ぶ（60回で %s）" % str(counts))
	var calm := 0
	for i in 30:
		a.grade = "pro"
		a.play_beat({"to": a.global_position + Vector3(0, 0, 3), "gait": "walk", "pose": "idle", "look": "", "face_go": "neutral", "face_hold": "neutral"})
		calm += 1 if a._late == 0.0 and a._over == 0.0 and a._trip_at < 0.0 else 0
	check(calm == 30, "ベテランには、何も起きない")
	print("HIRE_TEST_FAIL" if failed else "HIRE_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
