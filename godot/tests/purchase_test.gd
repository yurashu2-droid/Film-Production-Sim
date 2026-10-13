extends SceneTree
# 発注の「借りる」と「買う」：
#   借りた物は依頼が終わると返る / 買った物は貯金から払い、次の依頼でも最初から在る /
#   買った物は発注画面で「持っている」になり、二重に払わない / 貯金が足りないと買えない /
#   火薬の袋は借りられず、買うと制作費から引かれる / 使いかけの袋は量ごと持ち越し、空の袋は消える /
#   精算の内訳に出る / 倒産すると持ち物が無くなる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/purchase_test.gd
var game: Node
var flow: Node
var kit: Node
var failed := false
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("PURCHASE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func first(kind: String) -> Node:
	var found: Node = null
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.kind == kind and (found == null or prop.pid < found.pid):
			found = prop
	return found


func option(id: String) -> Dictionary:
	for opt: Dictionary in game.OPTIONS:
		if opt["id"] == id:
			return opt
	return {}


func row(id: String) -> Dictionary:
	for i in game.OPTIONS.size():
		if game.OPTIONS[i]["id"] == id:
			return game.hud.catalog.rows[i]
	return {}


# 出ている袋の、残りの量
func fills() -> Array:
	var out: Array = []
	for sack: Node in kit.sacks:
		if not sack.absent:
			out.append(snappedf(sack.fill, 0.01))
	return out


# 会社の庭の、借りた物が届く場所に在るか
func at_home(prop: Node) -> bool:
	return not prop.absent and prop.global_position.y > -1.0 and prop.global_position.distance_to(flow.HOME_TRUCK) < 12.0


# 出発して、現場で時間切れにして、納品する（精算の画面まで）
func shoot_and_deliver(brought: Array = []) -> void:
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	check(flow.phase == 4, "the crew reaches the location")
	for i in brought.size():
		brought[i].restore([game.SPAWN + Vector3(2.0 + 1.5 * float(i), 0.05, 2.0), Quaternion.IDENTITY, false])
	await frames(10)
	flow.expire()
	await frames(5)
	game.h_deliver(0)
	await frames(5)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	kit = game.bomb_kit
	var dolly: Node = first("dolly")
	var bomb: Node = game.fx
	check(flow.wallet == 600 and flow.owned.is_empty() and dolly.absent and bomb.absent, "a new company owns nothing")
	check(int(game.BUY_TIMES) == 4 and game.buy_price(option("dolly")) == 320 and game.buy_price(option("refill")) == 40, "buying costs four times the rental; powder keeps its price")

	# ---- 1本目：爆弾を借りる・台車を買う・火薬の袋を2つ買う ----
	game.h_accept_job(0)
	game.h_open_order()
	var budget: int = flow.budget()
	game.h_order_buy("balcony", true)
	check(game.buying.is_empty() and flow.wallet == 600, "an item the savings cannot cover cannot be bought (balcony 1440 > 600)")
	game.h_order_set("refill", 1)
	check(int(game.order.get("refill", 0)) == 0, "powder needs a bomb")
	game.h_order_set("fx", 1)
	game.h_order_buy("dolly", true)
	check(game.buying.has("dolly") and int(game.order.get("dolly", 0)) == 0, "the dolly is marked to buy")
	game.h_order_set("dolly", 1)
	check(not game.buying.has("dolly") and int(game.order.get("dolly", 0)) == 1, "choosing rent replaces buy")
	game.h_order_buy("dolly", true)
	check(game.buying.has("dolly") and int(game.order.get("dolly", 0)) == 0, "choosing buy replaces rent")
	game.h_order_set("refill", 2)
	game.h_order_buy("refill", true)
	check(not option("refill")["rent"] and not game.buying.has("refill") and int(game.order.get("refill", 0)) == 2, "powder sacks are bought by the piece: no rental, no keep-forever purchase")
	check(game.order_cost() == 360 + 80 and game.savings_cost() == 320, "rentals and powder come from the budget (%d), the purchase from the savings (%d)" % [game.order_cost(), game.savings_cost()])
	game.hud.catalog.sync(flow)
	check(row("dolly")["buy"].visible and row("dolly")["rent"].visible and not row("dolly")["own"].visible, "the card offers rent and buy")
	check(row("balcony")["buy"].disabled and not row("dolly")["buy"].disabled, "the buy button is off when the savings are short")
	check(not row("refill")["state"].text.is_empty() and row("refill")["rent"] == null, "the powder card has no rent/buy choice")
	game.h_order_confirm()
	await frames(8)
	check(flow.phase == 2 and flow.wallet == 280 and flow.expenses == 440 and flow.bought == 320, "the purchase leaves the savings (%d), the rest leaves the budget (%d)" % [flow.wallet, flow.expenses])
	check(flow.owned.has("dolly") and not flow.owned.has("fx") and at_home(dolly), "the bought dolly stands by the truck")
	check(not bomb.absent and fills() == [1.0, 1.0, 1.0], "the rented bomb comes with one sack, plus the two bought (%s)" % str(fills()))

	# ---- 発注をやり直す：買った物は「持っている」。二重に払わない ----
	game.h_open_order()
	game.hud.catalog.sync(flow)
	check(row("dolly")["own"].visible and not row("dolly")["buy"].visible and not row("dolly")["rent"].visible, "the card of a bought item says owned")
	game.h_order_set("dolly", 1)
	game.h_order_buy("dolly", true)
	check(int(game.order.get("dolly", 0)) == 0 and game.buying.is_empty(), "an owned item cannot be rented or bought again")
	check(game.order_cost() == 440 and game.savings_cost() == 0, "the order still holds the rentals, and nothing more to pay from the savings")
	game.h_order_confirm()
	await frames(8)
	check(flow.wallet == 280 and flow.bought == 320 and flow.expenses == 440 and at_home(dolly), "re-ordering does not charge the purchase twice")

	# ---- 袋を使う：1つは半分、1つは空。台車と袋を荷台に積んで現場へ ----
	var out: Array = kit.sacks.filter(func(sack: Node) -> bool: return not sack.absent)
	out[0].fill = 0.4
	out[1].fill = 0.0
	# 袋は荷台に積む。台車は軽トラの荷台に載らないので、現場まで押して行ったことにする（着いたあとで現場に置く）
	check(game.host_load(out[0], game.truck), "a sack is loaded on the deck")
	await shoot_and_deliver([dolly])
	check(dolly.global_position.x < 40.0 and out[0].global_position.x < 40.0, "the dolly and a sack travel to the location (%s %s)" % [str(dolly.global_position), str(out[0].global_position)])
	check(flow.phase == 5 and flow.saved == budget - 440 and flow.wallet == 280 + flow.last_payment + flow.saved, "settlement keeps the unspent budget; the purchase was already paid (%d)" % flow.wallet)
	for i in 6:
		await process_frame
	var bought_row: Label = game.production_hud._settled_bought
	check((bought_row.get_parent() as Control).visible and bought_row.text.contains("320"), "the settlement lists the purchase (%s)" % bought_row.text)
	check(game.production_hud._settled_expense.get_parent().get_child(0).text.contains("440"), "rentals and powder stay in the budget line")
	game.h_return_office()
	await frames(8)
	check(flow.phase == 0 and bomb.absent, "the rented bomb goes back when the job ends")
	check(flow.owned.has("dolly") and at_home(dolly) and dolly.rider_of == 0, "the bought dolly comes home from the location")
	check(flow.sack_stock == [0.4, 1.0] and fills() == [0.4, 1.0], "the half-used and the untouched sack are kept, the empty one is gone (%s)" % str(fills()))
	var kept: Array = kit.sacks.filter(func(sack: Node) -> bool: return not sack.absent)
	check(kept.all(func(sack: Node) -> bool: return at_home(sack)), "the kept sacks wait at the company")

	# ---- 2本目：買った物は最初から在る。持ち越した袋のぶん、買い足せる数が減る ----
	var savings: int = flow.wallet
	game.h_accept_job(0)
	await frames(5)
	check(flow.phase == 2 and at_home(dolly) and game.order.is_empty() and flow.bought == 0, "on the next job the dolly is there without ordering")
	check(fills() == [0.4, 1.0] and bomb.absent, "the kept sacks are there too, with the same amount")
	game.h_open_order()
	check(game.order_cost() == 0 and game.savings_cost() == 0, "nothing to pay for what the company owns")
	game.h_order_set("fx", 1)
	game.h_order_set("refill", 4)
	check(int(game.order.get("refill", 0)) == 2, "two kept sacks and the bomb's own sack leave room for two more (%d)" % int(game.order.get("refill", 0)))
	game.h_order_confirm()
	await frames(8)
	check(flow.wallet == savings and flow.expenses == 360 + 80, "the second job charges only the new rentals and powder")
	check(fills() == [0.4, 1.0, 1.0, 1.0, 1.0] and at_home(dolly), "kept sacks keep their amount beside the new ones (%s)" % str(fills()))
	await shoot_and_deliver()
	for i in 6:
		await process_frame
	check(flow.bought == 0 and not (game.production_hud._settled_bought.get_parent() as Control).visible, "a job without purchases has no purchase line")
	game.h_return_office()
	await frames(8)
	check(flow.owned.has("dolly") and at_home(dolly) and flow.sack_stock.size() == 5, "everything unused is carried over again (%d sacks)" % flow.sack_stock.size())

	# ---- 倒産：新しい会社には、持ち物が無い ----
	flow.hazards = true
	flow.day = 6
	flow.wallet = 0
	flow.settle(0)
	check(flow.bankrupt, "the company cannot pay the rent")
	game.h_return_office()
	await frames(8)
	check(flow.phase == 0 and flow.wallet == flow.START_WALLET and flow.owned.is_empty() and flow.sack_stock.is_empty(), "bankruptcy wipes what the company owned")
	check(dolly.absent and fills().is_empty(), "the bought dolly and the kept sacks are gone from the yard")
	flow.hazards = false
	game.h_accept_job(0)
	game.h_open_order()
	game.hud.catalog.sync(flow)
	check(not row("dolly")["own"].visible and row("dolly")["buy"].visible, "the new company can buy the dolly again")

	# ---- 爆弾を買う：次の依頼からは、爆弾を借りなくても火薬の袋だけ買える ----
	flow.wallet = 2000
	game.h_order_buy("fx", true)
	game.h_order_set("refill", 1)
	check(game.savings_cost() == 1440 and game.order_cost() == 40, "a bought bomb is paid from the savings, its powder from the budget")
	game.h_order_confirm()
	await frames(8)
	check(flow.wallet == 560 and flow.owned.has("fx") and not bomb.absent and fills() == [1.0, 1.0], "the bought bomb arrives with its own sack and the extra one (%s)" % str(fills()))
	flow.expire()
	await frames(6)
	flow.settle(0)
	game.h_return_office()
	await frames(8)
	check(flow.phase == 0 and not bomb.absent and bomb.rider_of == game.truck.pid and fills() == [1.0, 1.0], "the owned bomb and its sacks stay at the company (phase %d absent %s rider %d at %s sacks %s)" % [flow.phase, str(bomb.absent), bomb.rider_of, str(bomb.global_position), str(fills())])
	var kept_savings: int = flow.wallet
	game.h_accept_job(0)
	game.h_open_order()
	game.h_order_set("refill", 4)
	check(int(game.order.get("refill", 0)) == 3 and game.order_cost() == 120 and int(game.order.get("fx", 0)) == 0, "with an owned bomb, powder can be bought on its own (room for 3 more)")
	game.h_order_confirm()
	await frames(8)
	check(flow.wallet == kept_savings and fills().size() == 5 and not bomb.absent, "the next job starts with the owned bomb and five sacks")
	print("PURCHASE_TEST_FAIL" if failed else "PURCHASE_TEST_OK", " checks=", checks)
	quit(1 if failed else 0)
