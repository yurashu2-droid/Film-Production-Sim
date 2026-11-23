extends "res://tests/pair_net_base.gd"
# 「借りる／買う」の二人通信：
#   参加者が発注する（台車を買う・爆弾を借りる・火薬の袋を1つ）。決めるのはホスト。
#   買った物・貯金・出ている袋が、両方の画面で一致する / 精算のあと事務所へ戻ると、
#   買った台車と使いかけの袋が両方の画面に残り、借りた爆弾は消える /
#   あとから入った人にも、持ち物と持ち越した袋が届く / 次の依頼でも最初から在る。
#   godot --headless --path godot res://tests/purchase_net_test.tscn -- --purchase-net-test-host   （参加者は -client）

func configure() -> void:
	prefix = "PURCHASE_NET"
	port = 24861
	flag = "purchase-net-test"
	budget = 90.0


func view() -> Dictionary:
	var flow: Node = game.production
	var kit: Node = game.bomb_kit
	var dolly: Node = first("dolly")
	var fills: Array = []
	for sack: Node in kit.sacks:
		if not sack.absent:
			fills.append(snappedf(sack.fill, 0.01))
	var owned: Array = flow.owned.keys()
	owned.sort()
	return {"phase": flow.phase, "wallet": flow.wallet, "expenses": flow.expenses, "bought": flow.bought, "owned": owned,
		"bought_now": flow.bought_now, "sack_stock": flow.sack_stock, "fills": fills, "order": game.order, "buying": game.buying,
		"dolly": not dolly.absent, "dolly_home": not dolly.absent and dolly.global_position.distance_to(flow.HOME_TRUCK) < 12.0,
		"bomb": not game.fx.absent, "day": flow.day}


func host_action(action: String, _arg: Variant, _who: int) -> Dictionary:
	var flow: Node = game.production
	var kit: Node = game.bomb_kit
	match action:
		"use":
			# 袋を使ったことにする：1つめは半分、2つめは空
			var out: Array = kit.sacks.filter(func(sack: Node) -> bool: return not sack.absent)
			out[0].fill = 0.5
			out[1].fill = 0.0
		"settle":
			# 現場へは行かず、時間切れ → 納品 まで進める（精算の中身だけを確かめる）
			flow.expire()
			await frames(6)
			flow.settle(0)
		"return":
			flow.return_office()
	await frames(4)
	return {}


func client_run() -> void:
	var flow: Node = game.production
	var all := ["phase", "wallet", "expenses", "bought", "owned", "bought_now", "sack_stock", "fills", "order", "buying", "dolly", "dolly_home", "bomb"]

	# ---- 参加者が発注する ----
	var reply: Dictionary = await request("hello")
	game.h_accept_job.rpc_id(1, 0)
	check(await until(func() -> bool: return flow.phase == 2), "the job starts on both peers")
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()) and flow.phase == 2, "the participant opens the order desk")
	game.h_order_buy.rpc_id(1, "balcony", true)
	game.h_order_buy.rpc_id(1, "dolly", true)
	check(await until(func() -> bool: return game.buying.has("dolly")), "the participant's buy choice comes back from the host")
	reply = await request("snapshot")
	check(reply["view"]["buying"].has("dolly") and not reply["view"]["buying"].has("balcony"), "the host refuses a purchase the savings cannot cover")
	check(reply["view"]["wallet"] == 600 and reply["view"]["owned"].is_empty(), "nothing is paid until the order is confirmed")
	game.h_order_set.rpc_id(1, "fx", 1)
	game.h_order_set.rpc_id(1, "refill", 1)
	game.h_order_confirm.rpc_id(1)
	check(await until(func() -> bool: return flow.phase == 2 and flow.owned.has("dolly")), "the order is confirmed and the purchase reaches the participant")
	reply = await request("snapshot")
	var bought: Dictionary = reply["view"]
	check(bought["wallet"] == 280 and bought["expenses"] == 400 and bought["bought"] == 320 and bought["owned"] == ["dolly"], "the host paid the dolly from the savings and the rest from the budget")
	check(bought["dolly_home"] and bought["bomb"] and bought["fills"] == [1.0, 1.0], "the host has the dolly, the bomb and two sacks")
	await sees(bought, all, "the participant sees the same purchase, savings and kit")

	# ---- 精算：買った物の出費が、参加者にも届く ----
	reply = await request("use")
	reply = await request("settle")
	var settled: Dictionary = reply["view"]
	check(settled["phase"] == 5 and settled["bought"] == 320, "the host settles with the purchase on the books")
	await sees(settled, ["phase", "wallet", "bought", "expenses"], "the participant sees the same settlement")

	# ---- 事務所へ戻る：買った台車と使いかけの袋は残り、借りた爆弾は返る ----
	reply = await request("return")
	var home: Dictionary = reply["view"]
	check(home["phase"] == 0 and home["owned"] == ["dolly"] and home["dolly_home"] and not home["bomb"], "back at the office the host keeps the dolly, not the bomb")
	check(home["sack_stock"] == [0.5] and home["fills"] == [0.5], "the host keeps the half-used sack and drops the empty one")
	await sees(home, all, "the participant sees the same belongings at the office")

	# ---- あとから入った人にも届く ----
	await rejoin()
	flow = game.production
	await sees(home, all, "a late joiner sees the owned dolly and the kept sack", LATE)

	# ---- 次の依頼：発注しなくても、最初から在る ----
	game.h_accept_job.rpc_id(1, 0)
	check(await until(func() -> bool: return flow.phase == 2), "the next job starts")
	reply = await request("snapshot")
	var next: Dictionary = reply["view"]
	check(next["dolly_home"] and next["fills"] == [0.5] and next["order"].is_empty() and next["bought"] == 0 and next["wallet"] == home["wallet"], "on the next job the host has the dolly and the sack without ordering")
	await sees(next, all, "the participant sees the same on the next job", LATE)
	game.h_open_order.rpc_id(1)
	check(await until(func() -> bool: return game.ordering()) and flow.phase == 2, "the order desk opens again")
	game.h_order_buy.rpc_id(1, "dolly", true)
	game.h_order_set.rpc_id(1, "dolly", 1)
	reply = await request("snapshot")
	check(reply["view"]["buying"].is_empty() and int(reply["view"]["order"].get("dolly", 0)) == 0, "the host refuses to rent or buy what the company owns")
	game.hud.catalog.sync(flow)
	var card: Dictionary = {}
	for i in game.OPTIONS.size():
		if game.OPTIONS[i]["id"] == "dolly":
			card = game.hud.catalog.rows[i]
	check(card["own"].visible and not card["buy"].visible, "the participant's order screen says owned")
