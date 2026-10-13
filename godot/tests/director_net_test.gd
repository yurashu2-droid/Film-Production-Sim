extends "res://tests/pair_net_base.gd"
# 監督の机の二人通信：
#   スライド：ホストが決めた中身が、参加者にも、あとから入った人にも、同じに届く
#   のぞき箱：参加者がのぞくと、ホストは使えない。やめるとホストが使える。誰がのぞいているかは、両方の画面で姿に出る
#   発注　　：開くのは、頼んだ人の画面だけ。その間もホストは歩ける・物を持てる・時計が進む。
#             選んでいる途中の物は届かず、決めると届く。決めずに閉じる・途中で抜ける、は前の注文へ戻る。
#             ホストが持っている物や接着は、発注を決めても、そのまま
#   godot --headless --path godot res://tests/director_net_test.tscn -- --director-net-test-host   （参加者は -client）

const CLIENT_SPOT := Vector3(71.5, 0.1, 1.7)      # 机の前（のぞき箱と電話のどちらにも近い）
const HOST_SPOT := Vector3(72.7, 0.1, 2.4)
const WORK_SPOT := Vector3(77.5, 0.1, 9.5)        # 事務所の外の空いた所（西へ歩ける）


func configure() -> void:
	prefix = "DIRECTOR_NET"
	port = 24871
	flag = "director-net-test"
	budget = 110.0


func view() -> Dictionary:
	var flow: Node = game.production
	var desk: Node = game.director
	var me: Node = game.local_player()
	var poses := {}
	for id: int in game.players:
		var pose: Node = game.players[id].vis.skel.get_node_or_null("DeskPose")
		poses[id] = str(pose.mode) if pose != null else ""
	return {"phase": flow.phase, "slides": flow.slides, "peeper": flow.peeper, "orderer": flow.orderer, "ordered": flow.ordered,
		"order": game.order, "buying": game.buying, "expenses": flow.expenses, "poses": poses,
		"dolly": not first("dolly").absent, "bomb": not game.fx.absent, "sandbag": not first("sandbag").absent,
		"glue": game.adhesive.pairs.size(), "prep": flow.prep_left,
		# ここから下は、その人の画面だけの様子（見比べない）
		"ordering": game.ordering(), "peeping": desk.peeping(), "blocked": game.ui_blocking(),
		"catalog": game.hud.catalog.visible, "slide": desk.view.visible, "held": me.held if me != null else 0}


func host_action(action: String, arg: Variant, who: int) -> Dictionary:
	var out := {}
	match action:
		"desk":
			# 二人を、机の前へ
			crew_to(1, HOST_SPOT)
			crew_to(who, CLIENT_SPOT)
		"peep":
			# ホストの制作班が、のぞく・やめる（F を押したのと同じ道筋）
			game.h_peep(bool(arg))
		"order":
			# ホストの制作班が、発注の画面を開こうとする
			game.h_open_order()
		"work":
			# ホストの制作班が、物を持って歩く（誰かが発注していても、止まらない）
			var fish: Node = first("fish")
			crew_to(1, WORK_SPOT, PI * 0.5)
			place(fish, WORK_SPOT + Vector3(-1.2, 0.4, 0.0))
			fish.set_fixed(false)
			await wait(0.2)
			game.h_grab(fish.pid)
			await wait(0.1)
			var me: Node3D = game.local_player()
			var from: Vector3 = me.global_position
			Input.action_press("move_forward")
			await wait(0.9)
			Input.action_release("move_forward")
			await wait(0.1)
			out["moved"] = me.global_position.distance_to(from)
		"glue":
			# 物どうしを接着しておく（発注を決めても、外れないことを確かめる）
			var cart: Node = first("lift_cart")
			game.adhesive.pairs = [{"a": cart.pid, "b": game.truck.pid, "pa": Vector3.ZERO, "pb": game.truck.to_local(cart.global_position), "joined": true}]
			game.adhesive.restore(game.adhesive.snapshot())
	await frames(4)
	return out


func client_run() -> void:
	var flow: Node = game.production
	var desk: Node = game.director
	var mine: int = Net.my_id()
	var shared := ["phase", "slides", "peeper", "orderer", "ordered", "order", "buying", "expenses", "poses", "dolly", "bomb", "sandbag", "glue"]

	# ---- スライド：依頼を受けると、ホストが決めた中身が両方に届く ----
	var reply: Dictionary = await request("hello")
	check((reply["view"]["slides"] as Dictionary).is_empty() and flow.slides.is_empty(), "there are no slides before a job is taken")
	game.h_accept_job.rpc_id(1, job_of("kaiju"))
	check(await until(func() -> bool: return flow.phase == 2 and not flow.slides.is_empty()), "the job taken by the participant brings the slides")
	reply = await request("desk")
	var deck: Dictionary = reply["view"]["slides"]
	check(not deck.is_empty() and (deck["rows"] as Array).size() == 3 and int(deck["job"]) == job_of("kaiju"), "the host decided the slides for this job")
	await sees(reply["view"], ["slides", "phase"], "host and participant have the same slides")

	# ---- のぞき箱：一度に1人。誰がのぞいているかは、両方の画面で見える ----
	game.h_peep.rpc_id(1, true)
	check(await until(func() -> bool: return desk.peeping()), "the participant starts peeping")
	await wait(0.3)
	check(desk.view.visible and desk.view.count() == 5 and desk.view.shown_kinds(0).size() == 9 and game.ui_blocking(), "the participant's screen shows the slides and nothing else")
	reply = await request("snapshot")
	check(reply["view"]["peeper"] == mine and str(reply["view"]["poses"].get(mine, "")) == "peep", "the host sees the participant leaning over the peep box")
	check(not reply["view"]["slide"] and not reply["view"]["blocked"] and not reply["view"]["peeping"], "the host's own screen is not covered")
	reply = await request("peep", true)
	check(reply["view"]["peeper"] == mine and not reply["view"]["peeping"], "the host cannot peep while the participant does")
	game.h_peep.rpc_id(1, false)
	check(await until(func() -> bool: return not desk.peeping() and not desk.view.visible), "the participant stops, and the world is back")
	reply = await request("peep", true)
	check(reply["view"]["peeper"] == 1 and reply["view"]["peeping"] and reply["view"]["slide"], "now the host can peep")
	await sees(reply["view"], ["peeper"], "the participant knows the box is taken")
	check(await until(func() -> bool: return game.players[1].vis.skel.get_node_or_null("DeskPose") != null), "and sees the host leaning over the box")
	game.h_peep.rpc_id(1, true)
	reply = await request("snapshot")
	check(reply["view"]["peeper"] == 1 and not desk.peeping() and not desk.view.visible, "the participant is refused while the host peeps")

	# ---- あとから入った人にも、同じスライドと「誰がのぞいているか」が届く ----
	await rejoin()
	flow = game.production
	desk = game.director
	mine = Net.my_id()
	reply = await request("snapshot")
	check(reply["view"]["slides"] == deck and reply["view"]["peeper"] == 1, "the host still has the same slides, and is still peeping")
	await sees(reply["view"], ["slides", "peeper", "phase", "ordered"], "a late joiner receives the same slides and who is peeping", LATE)
	check(await until(func() -> bool: return game.players.has(1) and game.players[1].vis.skel.get_node_or_null("DeskPose") != null, LATE), "and sees the host at the peep box")
	reply = await request("peep", false)
	await sees(reply["view"], ["peeper"], "the host stops peeping")

	# ---- 発注：開くのは、頼んだ人の画面だけ。ホストは止まらない ----
	reply = await request("desk")
	var clock: float = float(reply["view"]["prep"])
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()), "the participant opens the order screen")
	await wait(0.3)
	check(game.hud.catalog.visible and game.ui_blocking() and flow.phase == 2 and game.state == game.S.PREP, "it opens on the participant's screen, and the phase does not change")
	reply = await request("work")
	var working: Dictionary = reply["view"]
	check(working["orderer"] == mine and working["phase"] == 2 and not working["ordering"] and not working["catalog"] and not working["blocked"], "the host has no order screen and is not held up")
	check(float(reply.get("moved", 0.0)) > 1.0 and int(working["held"]) != 0, "the host walks and carries a prop meanwhile (%.1f m)" % float(reply.get("moved", 0.0)))
	check(float(working["prep"]) < clock - 0.5, "and the prep clock runs on")
	check(str(working["poses"].get(mine, "")) == "phone", "the host sees the participant on the phone")
	reply = await request("order")
	check(reply["view"]["orderer"] == mine and not reply["view"]["ordering"], "the host cannot open the order screen at the same time")
	# 選んでいる途中の物は、決めるまで届かない
	game.h_order_set.rpc_id(1, "dolly", 1)
	game.h_order_set.rpc_id(1, "fx", 1)
	reply = await request("glue")
	var choosing: Dictionary = reply["view"]
	check(int(choosing["order"].get("dolly", 0)) == 1 and int(choosing["order"].get("fx", 0)) == 1 and not choosing["dolly"] and not choosing["bomb"] and int(choosing["expenses"]) == 0, "what the participant is choosing has not arrived on the host")
	await sees(choosing, ["order", "dolly", "bomb", "expenses", "glue"], "nor on the participant")
	# 決める：物が届く。ホストの手の物と接着は、そのまま
	game.h_order_confirm.rpc_id(1)
	check(await until(func() -> bool: return not game.ordering() and not first("dolly").absent and not game.fx.absent), "the order is confirmed and the things arrive on the participant")
	reply = await request("snapshot")
	var done: Dictionary = reply["view"]
	check(done["orderer"] == 0 and done["dolly"] and done["bomb"] and int(done["expenses"]) == 440, "the host delivered the dolly and the bomb (%d)" % int(done["expenses"]))
	check(int(done["held"]) == int(working["held"]) and int(done["glue"]) == 1, "the host still holds its prop, and the glue is still there")
	await sees(done, shared, "both peers agree on the order, the deliveries and the desk")
	check(not game.hud.catalog.visible and not game.ui_blocking(), "the participant's order screen is closed")

	# ---- 決めずに閉じる：選びかけの注文は、前に決めた注文へ戻る ----
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()), "the participant opens the order screen again")
	game.h_order_set.rpc_id(1, "rose", 1)
	check(await until(func() -> bool: return int(game.order.get("rose", 0)) == 1), "a rose is on the slip")
	game.h_order_close.rpc_id(1)
	check(await until(func() -> bool: return not game.ordering()), "and the screen is closed without confirming")
	reply = await request("snapshot")
	check(reply["view"]["orderer"] == 0 and int(reply["view"]["order"].get("rose", 0)) == 0 and int(reply["view"]["expenses"]) == 440, "the host dropped the unconfirmed rose")
	await sees(reply["view"], shared, "the participant's slip is back to the confirmed order")

	# ---- 発注の途中で抜けた人：席が空く。あとから入った人には、決めた注文だけが見える ----
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()), "the participant is ordering when the connection drops")
	game.h_order_set.rpc_id(1, "fix", 1)
	reply = await request("snapshot")
	check(reply["view"]["orderer"] == mine and int(reply["view"]["order"].get("fix", 0)) == 1 and not reply["view"]["sandbag"], "weights are on the slip, not delivered")
	await rejoin()
	flow = game.production
	desk = game.director
	reply = await request("snapshot")
	check(reply["view"]["orderer"] == 0 and int(reply["view"]["order"].get("fix", 0)) == 0 and not reply["view"]["sandbag"] and reply["view"]["dolly"], "the host freed the desk and dropped the unconfirmed weights")
	await sees(reply["view"], ["orderer", "ordered", "order", "expenses", "dolly", "bomb", "sandbag", "slides", "peeper"], "a late joiner sees the confirmed order and its deliveries", LATE)
	check(not game.ordering() and not game.hud.catalog.visible and not desk.view.visible, "and has no order screen and no slide open")
