extends SceneTree
# ゴミ袋・ブルーシートの包み（scripts/features/junk_bags.gd）：
#   ・廃材置き場にいつも置いてある。袋の中の物（production_scrap.gd の "bag"）は、最初はしまってある
#   ・持って左右に振る（向きを3回切り返す）と、ゴミ袋からは小道具、包みからは大道具が、持っている人の前に出てくる。F でも出る
#   ・1日に出せる数を使い切ると、空っぽ。次の日には袋がまた詰まり、出した物はしまわれる
#   ・依頼主が用意する物（features/job_props.gd）：日替わりでしまってあった廃材は、その置き場所へ戻る。袋の中の物は、廃材置き場の空いた所に出る
#   godot --headless --path godot --fixed-fps 60 --script res://tests/junk_bags_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("JUNK_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func out_items(size: String) -> Array:
	var flow: Node = game.production
	return game.props.values().filter(func(p: Node) -> bool: return flow.bag_of(str(p.kind)) == size and not p.absent)


func bag(kind: String, n: int = 0) -> RigidBody3D:
	var jb: Node = game.hooks.feature("junk_bags")
	for b: RigidBody3D in jb.bags:
		if b.kind == kind:
			if n == 0:
				return b
			n -= 1
	return null


func hold(me: Node3D, p: RigidBody3D) -> void:
	if me.held != 0:
		game.h_release()
		await frames(3)
	p.restore([me.global_position + Vector3(0.6, 0.1, 0.0), Quaternion.IDENTITY, false])
	await frames(4)
	game.h_grab(p.pid)
	await frames(3)


# 左右に振る：自分の向きを、すばやく行ったり来たりさせる
func shake(me: Node3D) -> void:
	var base: float = me.aim_yaw
	for i in 7:
		for k in 6:
			me.aim_yaw = base + (0.35 if i % 2 == 0 else -0.35) * float(k + 1) / 6.0
			await process_frame
	me.aim_yaw = base
	await frames(4)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var jb: Node = game.hooks.feature("junk_bags")
	var me: Node3D = game.local_player()
	var trash := bag("trashbag")
	var tarp := bag("tarpbundle")
	check(jb != null and jb.bags.size() == 6 and trash != null and tarp != null, "廃材置き場に、ゴミ袋4つと包み2つがある")
	check(jb.bags.all(func(b: Node) -> bool: return not b.absent and b.global_position.y > -1.0), "袋は、いつも出ている")
	var bagged: Array = game.props.values().filter(func(p: Node) -> bool: return flow.in_bag(str(p.kind)))
	check(bagged.size() >= 140, "袋の中の物が、140個以上ある（%d）" % bagged.size())
	check(bagged.all(func(p: Node) -> bool: return p.absent and p.global_position.y < -30.0 and p.pid in flow.stash), "袋の中の物は、最初はしまってある")
	# ---- ゴミ袋を振る ----
	me.global_position = trash.global_position + Vector3(-1.2, 0.1, 0.0)
	await frames(3)
	await hold(me, trash)
	check(trash.holder == me.peer_id, "ゴミ袋を持った")
	check(str(jb.hook_hud(me, "", "").get("keys_all", "")).contains("あと 4 個"), "案内に、今日あと何個出るかが出る")
	await shake(me)
	var small: Array = out_items("small")
	check(small.size() == 1, "左右に振ると、小道具がひとつ出てくる（%d）" % small.size())
	if small.size() == 1:
		var item: Node3D = small[0]
		await frames(40)
		check(item.global_position.distance_to(me.global_position) < 2.5 and item.global_position.y > -0.5, "持っている人の前に出る（%.1fm）" % item.global_position.distance_to(me.global_position))
		check(not (item.pid in flow.stash), "出た物は、しまってある物の一覧から外れる")
	check(int(jb.left[trash.pid]) == 3, "残りが 3 になる")
	# ゆっくり見回すのは、振ったことにならない
	var base: float = me.aim_yaw
	await frames(70)
	for i in 180:
		me.aim_yaw = base + sin(float(i) / 180.0 * TAU) * 0.6
		await process_frame
	check(out_items("small").size() == 1, "ゆっくり見回しても、出てこない")
	# F でも出る。使い切ると空っぽ
	for i in 3:
		me.target = null
		game.hooks.first("hook_f", [me])
		await frames(40)
	check(out_items("small").size() == 4 and int(jb.left[trash.pid]) == 0, "F でも出る。4つで使い切る（%d）" % out_items("small").size())
	check(str(jb.hook_hud(me, "", "").get("keys_all", "")).contains("空っぽ"), "使い切ると、案内は「空っぽ」")
	game.hooks.first("hook_f", [me])
	await frames(30)
	check(out_items("small").size() == 4, "空っぽの袋は、振っても何も出ない")
	check(trash.visual.scale.y < 0.8, "空っぽの袋は、しぼむ")
	# ---- 包みを振る：大道具 ----
	me.global_position = tarp.global_position + Vector3(-1.6, 0.1, 0.0)
	await frames(3)
	await hold(me, tarp)
	await shake(me)
	var large: Array = out_items("large")
	check(large.size() == 1, "包みを振ると、大道具がひとつ出てくる（%d）" % large.size())
	if large.size() == 1:
		await frames(60)
		var piece: Node3D = large[0]
		check(piece.global_position.y > -0.5 and piece.global_position.y < 0.6, "大道具は、足元に出る（y=%.2f）" % piece.global_position.y)
	game.h_release()
	await frames(5)
	# ---- 次の日：出した物はしまわれ、袋はまた詰まる ----
	flow.restock()
	jb.hook_office_ready()
	await frames(5)
	check(out_items("small").is_empty() and out_items("large").is_empty(), "次の日には、出した物がしまわれる")
	check(int(jb.left[trash.pid]) == 4 and trash.visual.scale.y > 0.9, "袋は、また詰まっている")
	# ---- 依頼主が用意する物 ----
	var boat: Node = null
	for p: Node in game.props.values():
		if p.kind == "scrap_rowboat_shell":
			boat = p
	jb.deliver(boat)
	var hidden: Array = (flow.stash as Array).duplicate()
	hidden.erase(boat.pid)
	game.host_ev("stash", [hidden])
	await frames(40)
	check(not boat.absent and boat.global_position.y > -0.5 and boat.global_position.distance_to(flow.Yard.CENTER) < 20.0,
		"袋の中の物を、廃材置き場の空いた所に出せる（%s）" % str(boat.global_position))
	# 日替わりでしまってあった廃材は、依頼を受けると、その置き場所へ戻る（ホームの置き場所）
	flow.daily = true
	var fan: Node = null
	for p: Node in game.props.values():
		if p.kind == "scrap_fan":
			fan = p
	for round in 30:
		flow.restock()
		if fan.pid in flow.stash:
			break
	check(fan.pid in flow.stash and fan.absent, "日替わりで、送風機がしまってある日を作る")
	var ship := -1
	for i in flow.JOBS.size():
		if "scrap_fan" in (flow.JOBS[i].get("props", []) as Array):
			ship = i
	flow.day = 2
	game.h_accept_job(ship)
	await frames(30)
	check(not fan.absent and fan.global_position.y > -0.5 and fan.global_position.distance_to(flow._home_layout[fan.pid][0]) < 1.0,
		"依頼主が用意する送風機は、地面の下ではなく、置き場所に出る（%s）" % str(fan.global_position))
	print("JUNK_TEST_FAIL" if failed else "JUNK_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
