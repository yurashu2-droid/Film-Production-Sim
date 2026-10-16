extends SceneTree
# 日替わりの廃材・門・後回しの発注を確認する。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/dailytest.gd
var game: Node
var failed := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		print("DAILY_CHECK FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shown() -> Array:
	var out: Array = []
	for pid: int in game.props:
		var p: Node = game.props[pid]
		if game.production._is_free(p) and not p.absent:
			out.append(p)
	return out


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
	var yard: Node3D = flow._yard_root
	# しまってあるのは、段ボール置き場の奥の箱と、ゴミ袋・包みの中の物だけ（どちらも日替わりの廃材ではない。cargo_kit.gd・features/junk_bags.gd が出す）
	check(flow.stash.all(func(pid: int) -> bool: return game.props[pid].kind == "carton" or flow.in_bag(game.props[pid].kind)) and not shown().any(func(p: Node) -> bool: return p.kind == "carton"), "automatic checks start with every scrap item out")
	check(flow.offered() == [flow.debut_job()] and flow.debut_job() >= 0, "first day offers only the company commercial")
	check(not (yard.get_node("GateBlock").get_child(0) as CollisionShape3D).disabled, "gate is shut before a job is taken")

	# 日替わりにして並べ直す：数が絞られ、どの依頼も撮れる組み合わせが残る
	flow.daily = true
	for round in 12:
		flow.restock()
		var out := shown()
		check(out.size() == flow.DAILY_COUNT, "only today's share is out (%d)" % out.size())
		check(out.any(func(p: Node) -> bool: return "castle" in p.tags), "something castle-like is out")
		check(out.any(func(p: Node) -> bool: return p.kind in ["riser", "carton", "applebox"]), "something to stand on is out")
		check(out.any(func(p: Node) -> bool: return "monster" in p.tags or p.kind in game.judge.MONSTER_KINDS), "a monster is out")
		check(out.filter(func(p: Node) -> bool: return "city" in p.tags or p.kind in game.judge.CITY_KINDS).size() >= 2, "two city pieces are out")
		for p: Node in out:
			check(p.global_position.y > -1.0 and p.visible, "shown item sits in the yard")
		for pid: int in flow.stash:
			check(game.props[pid].absent and game.props[pid].global_position.y < -30.0, "stored item is hidden away")
	# 2日目からは、高い足場だけ約束する（役は何に見立ててもいいので、専用の小道具が無い日もある）
	flow.day = 3
	var without_monster := 0
	for round in 12:
		flow.restock()
		var later := shown()
		check(later.size() == flow.DAILY_COUNT, "later days also show today's share (%d)" % later.size())
		check(later.any(func(p: Node) -> bool: return p.kind in ["riser", "carton", "applebox"]), "something to stand on is always out")
		if not later.any(func(p: Node) -> bool: return p.kind in game.judge.MONSTER_KINDS):
			without_monster += 1
	print("DAILY later days without a dedicated monster: ", without_monster, " / 12")
	flow.day = 1
	flow.restock()
	var before: Array = flow.stash.duplicate()

	# 依頼を受ける：買い物なしで積み込みへ進み、門が開く
	game.h_accept_job(0)
	check(flow.phase == 2 and game.state == game.S.PREP and flow.expenses == 0, "accepting goes straight to the yard")
	check(flow.stash == before, "taking a job keeps today's stock")
	for pid: int in before:
		check(game.props[pid].absent, "stored items stay hidden after the order is applied")
	await frames(90)
	check((yard.get_node("GateBlock").get_child(0) as CollisionShape3D).disabled, "gate opens once a job is taken")

	# 発注はカウンターで後から。借り物は依頼主の制作費から払い、会社の貯金は減らない
	check(flow.budget() == 500, "the first client brings a 500 coin budget")
	game.h_open_order()
	check(flow.phase == 2 and game.state == game.S.PREP and game.ordering() and flow.orderer == game.local_player().peer_id, "counter opens the order sheet for the one who asked, and the game goes on")
	game.h_order_set("fx", 1)
	game.h_order_set("balcony", 1)
	check(game.order_cost() == 360, "rentals cannot exceed the client's budget")
	game.h_order_set("fx", 0)
	game.h_order_set("dolly", 1)
	game.h_order_confirm()
	await frames(5)
	check(flow.phase == 2 and flow.wallet == 600 and flow.expenses == 80, "rental comes out of the budget, not the savings")
	game.h_open_order()
	check(flow.wallet == 600 and flow.expenses == 80 and int(game.order.get("dolly", 0)) == 1, "reopening the order shows what was ordered, and nothing changes until it is confirmed")
	game.h_order_set("dolly", 0)
	game.h_order_set("rose", 1)
	game.h_order_confirm()
	await frames(5)
	check(flow.phase == 2 and flow.wallet == 600 and flow.expenses == 20, "the confirmed order is what counts")
	for pid: int in before:
		check(game.props[pid].absent, "stored items stay hidden after re-ordering")

	# 荷台：積みすぎた分だけ「落ちそう」になり、段差で置いていかれる
	flow.hazards = true
	check(flow.prep_left < flow.PREP_TIME and flow.prep_left > flow.PREP_TIME - 30.0, "prep clock runs once a job is taken")
	var out := shown()
	# F は荷台の床に並べる（床が埋まると積まない）。小さい物から積むと、かさの合計が荷台の広さを超える
	out.sort_custom(func(a: Node, b: Node) -> bool:
		var fa: float = a.half.x * a.half.z
		var fb: float = b.half.x * b.half.z
		return fa < fb if not is_equal_approx(fa, fb) else a.pid < b.pid)
	var refused := 0
	for p: Node in out:
		if not game.host_load(p, game.truck):
			refused += 1
	check(refused > 0, "F stops loading once the deck floor is full (%d of %d refused)" % [refused, out.size()])
	var bed: Dictionary = flow.bed_load()
	check(bed["used"] > bed["cap"] and not (bed["risky"] as Array).is_empty(), "overloading marks the top of the pile as risky (%d / %d)" % [bed["used"], bed["cap"]])
	check(not game.film.pid in bed["risky"] and not game.clapper.pid in bed["risky"], "load warning excludes company gear")
	var risky: Array = (bed["risky"] as Array).duplicate()
	var data: Dictionary = flow.loadout()
	check(int(data["used"]) == int(bed["used"]) and (data["items"] as Array).any(func(item: Array) -> bool: return int(item[3]) > 0), "packing list flags what may fall")
	flow.prep_left = -75.0
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	check(game.film.rider_of == 0 and game.clapper.rider_of == 0 and flow.can_depart(), "company gear is not on the deck and does not hold up the departure")
	game.h_depart()
	check(flow.phase == 3, "truck departs")
	var count_before: int = flow.lost.size()
	flow._bump(1.0)
	check(flow.lost.size()==count_before,"bump never forcibly detaches cargo")
	var knocked: Node = game.props[risky[0]]
	risky = [knocked.pid]
	# 積み荷のいちばん上に載せた物を、横からはじき飛ばす（床に置いた物は、側板とまわりの荷物に守られている）
	knocked.restore([game.truck.global_transform * Vector3(0, game.truck.deck_top + 3.2, -1.1), Quaternion.IDENTITY, false])
	game._set_rider(knocked, game.truck, game.truck.global_transform.affine_inverse() * knocked.global_transform)
	await frames(2)
	check(knocked.rider_of == game.truck.pid and knocked.pid in flow.cargo(), "a prop on top of the pile is still cargo")
	knocked.apply_central_impulse(Vector3(30,5,0)*knocked.mass)
	await frames(25)
	check(not knocked.freeze and knocked.rider_of==0 and knocked.pid not in flow.cargo(),"physically pushed cargo leaves the truck")
	for i in 700:
		if flow.phase == 4:
			break
		await physics_frame
	check(flow.phase == 4, "truck arrives")
	check(absf(flow.lease_left - 525.0) < 2.0, "late departure shortens the shoot (%.0f)" % flow.lease_left)
	for pid: int in risky:
		check(game.props[pid].global_position.x > 40.0, "dropped item stays behind at the base")
	await frames(10)
	check(flow.at_site(game.film) and flow.at_site(game.clapper) and game.film.rider_of == 0 and game.film.global_basis.y.y > 0.95, "company gear arrives at the entrance without being loaded")
	# 突風：置いただけの軽い物は動き、重りは固定せず質量で耐える
	var sail: Node = null
	for prop: Node in game.props.values():
		if prop.absent or prop.kind in ["camera", "clapper", "spot", "script", "monitor", "truck", "mark"]:
			continue
		# 風を受ける面が広くて軽い物を1つ選ぶ（地面に寝ている板などは風で動かない）
		if sail == null and maxf(prop.half.x, prop.half.z) * prop.half.y * 4.0 * 34.0 / maxf(prop.mass, 0.3) >= 10.0:
			sail = prop
	check(sail != null, "something that catches the wind is in today's stock")
	if sail != null:
		if sail.rider_of != 0:
			game.host_unload(sail)
		sail.restore([game.SPAWN + Vector3(-4, 0.05, -3), Quaternion.IDENTITY, false])
		await frames(30)
		var from: Vector3 = sail.global_position
		var pushed: int = flow.gust(Vector3(1, 0, 0), 1.0)
		await frames(70)
		check(pushed >= 1 and sail.global_position.distance_to(from) > 0.15, "a gust moves a loose light prop (%.2f m)" % sail.global_position.distance_to(from))
		var weight: Node = game.stage.spawn("sandbag",game.SPAWN+Vector3(-4,0.05,-6))
		await frames(30)
		from = weight.global_position
		flow.gust(Vector3(1,0,0),1.0)
		await frames(70)
		check(not weight.freeze and weight.global_position.distance_to(from)<0.1,"12kg weight resists wind without freezing")
	flow.expire()
	await frames(5)
	# 精算：ギャラと、使わなかった制作費が貯金に入る。3本目の精算では家賃を払う
	flow.day = 3
	flow.wallet = 1000
	game.h_deliver(0)
	check(flow.phase == 5, "delivery settles")
	check(flow.last_payment == 150 and flow.saved == 480, "the unspent budget is kept as profit (%d)" % flow.saved)
	check(flow.rent_paid == 1200 and flow.rent_no == 1 and flow.wallet == 1000 + 150 + 480 - 1200 and not flow.bankrupt, "rent is paid on every third job (%d left)" % flow.wallet)
	check(flow.rent_amount() == 1800, "the next rent is higher")
	game.h_return_office()
	await frames(5)
	check(flow.phase == 0 and flow.day == 4 and flow.rent_in() == 3, "returning starts the next day")
	check(flow.offered().size() == flow.JOBS.size() - 1 and flow.debut_job() not in flow.offered(), "later days offer every job but the commercial")
	check(shown().size() == flow.DAILY_COUNT, "next day's stock is the same size")
	await frames(90)
	check(not (yard.get_node("GateBlock").get_child(0) as CollisionShape3D).disabled, "gate shuts again at the office")
	# 会社を大きくする買い物は貯金から。借り物の制作費とは別の財布
	flow.wallet = 400
	flow.buy("plan")
	check(int(flow.levels["plan"]) == 1 and flow.wallet == 100, "upgrades are paid from the savings")
	flow.buy("monitor")
	check(int(flow.levels["monitor"]) == 0 and flow.wallet == 100, "an upgrade the savings cannot cover is refused")
	# 家賃が払えないと倒産。事務所へ戻ると、新しい会社で最初からやり直す
	flow.day = 6
	flow.wallet = 0
	flow.settle(0)
	check(flow.bankrupt and flow.rent_paid == 0 and flow.phase == 5, "a company that cannot pay the rent goes bankrupt")
	game.h_return_office()
	await frames(5)
	check(flow.phase == 0 and flow.day == 1 and flow.wallet == flow.START_WALLET and flow.rent_no == 0 and int(flow.levels["plan"]) == 0 and not flow.bankrupt, "bankruptcy starts a fresh company")
	check(flow.offered() == [flow.debut_job()], "the fresh company starts from the commercial again")
	print("DAILYTEST_FAIL" if failed else "DAILYTEST_OK")
	quit(1 if failed else 0)
