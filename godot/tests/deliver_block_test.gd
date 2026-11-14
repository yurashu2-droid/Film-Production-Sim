extends SceneTree
# 何も撮れていないテイクの納品（production_flow.gd の deliver_block・settle、features/debut_calls.gd）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/deliver_block_test.gd
# ・1場面も撮れていないテイクは、撮り直しが残っている間は「このテイクを納品」を押しても納品できない
# ・借り時間切れ・撮り直しを使い切ったなら、失敗として精算する。ギャラの基本分 150 も、浮いた制作費も出ない
# ・1日目の紹介動画の失敗では、評判は下がらない。テレビ局のコメントも電話も来ず、翌日もう一度紹介動画が来る
# ・2日目に紹介動画を撮れれば電話が鳴り、3日目から3枚。家賃の周期は、紹介動画を上げた日から数える
var game: Node
var flow: Node
var S: Dictionary
var failed := false


func _initialize() -> void:
	create_timer(400).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("DELIVER_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# 紹介動画を受けて、その場で本番を回して、すぐカットする（何も組まない）
func empty_take(debut: int) -> void:
	game.h_accept_job(debut)
	await frames(20)
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(10)
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(30)
	if game.state == S.TAKE:
		game._cut()
	await frames(5)


# 画面から納品を頼み、ネットに上げる見返しはとばして、納品まで進める
func deliver_by_button() -> void:
	game.request_deliver(0)
	for i in 900:
		if game.state == S.DELIVERED:
			break
		if game.state == S.REPLAY:
			game.h_stop_replay()
		await physics_frame
	await frames(5)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	S = game.S
	flow.hazards = true
	flow.day = 1
	var debut: int = flow.debut_job()
	var calls: Node = game.hooks.feature("debut_calls")
	var premiere: Node = game.hooks.feature("premiere")
	check(flow.offered() == [debut], "1日目は、紹介動画だけ")
	# ---- 1日目：何も撮らずにカット ----
	await empty_take(debut)
	check(game.state == S.RESULT and game.takes.size() == 1 and not (game.takes[0]["passed"] as Array).has(true), "何も組まずにカットすると、1場面も撮れていないテイクになる")
	check(flow.deliver_block(0) != "", "撮り直しが残っている間は、納品できない（%s）" % flow.deliver_block(0))
	game.request_deliver(0)
	await frames(10)
	check(game.state == S.RESULT and flow.phase == 4 and int(premiere.screening) == -1, "「このテイクを納品」を押しても、納品も試写会も始まらない")
	# 撮り直しを使い切っていれば、失敗として納品できる
	var take: Dictionary = game.takes[0]
	game.takes.append(take.duplicate(true))
	game.takes.append(take.duplicate(true))
	check(flow.deliver_block(0) == "", "撮り直しを使い切ったら、納品できる")
	game.takes.resize(1)
	check(flow.deliver_block(0) != "", "まだ撮り直せるなら、やはり納品できない")
	# 借り時間切れ：納品（失敗の精算）を許す
	flow.expire()
	await frames(5)
	check(flow.expired and flow.deliver_block(0) == "", "借り時間切れなら、納品できる")
	var extra := 0
	for line: Array in flow.fee_lines(0):
		extra += int(line[1])
	var fee: int = flow.take_fee(0)
	check(fee == maxi(0, flow.cast_coins(0) + extra), "何も撮れていないテイクには、ギャラの基本分 150 が付かない（%d）" % fee)
	var wallet_before: int = flow.wallet
	var rep_before: int = flow.reputation
	await deliver_by_button()
	check(game.state == S.DELIVERED and flow.phase == 5, "失敗のテイクを納品した")
	check(flow.saved == 0 and flow.wallet == wallet_before + flow.last_payment and flow.last_payment == fee, "浮いた制作費は依頼主へ返す。貯金は増えない（%d → %d）" % [wallet_before, flow.wallet])
	check(flow.wallet <= wallet_before + maxi(0, fee), "何もしないで納品しても、得にならない")
	check(flow.rep_change == 0 and flow.reputation == rep_before, "1日目の失敗では、評判は下がらない（%d）" % flow.rep_change)
	check(not flow.last_flubs.any(func(l: String) -> bool: return l.contains("ランプ") or l.contains("テレビ")), "何も映っていない動画には、テレビ局のコメントが来ない")
	check(flow.debut_redo, "翌日、もう一度紹介動画を撮る")
	check(flow.rent_paid == 0 and flow.rent_in() == flow.RENT_EVERY + 1, "精算の画面の家賃：この日は数えない（あと%d本＝表示は%d本）" % [flow.rent_in(), flow.rent_in() - 1])
	check(int((premiere.build_tally() as Array)[0][1]) == 0, "試写会の読み上げでも、納品の基本は 0")
	game.h_return_office()
	await frames(20)
	check(int(calls.rang) == 0, "電話は鳴らない")
	check(flow.phase == 0 and flow.day == 2 and flow.offered() == [debut], "2日目の掲示板には、もう一度紹介動画だけ")
	check(flow.rent_in() == 3, "撮り直しの日は、家賃の周期に数えない（あと%d本）" % flow.rent_in())
	# ---- 2日目：1場面撮れた紹介動画を上げる ----
	await empty_take(debut)
	check(game.state == S.RESULT, "2日目もテイクが終わる")
	game.takes[0]["passed"][0] = true
	check(flow.deliver_block(0) == "", "1場面でも撮れていれば、納品できる")
	game.h_deliver(0)
	await frames(5)
	check(flow.phase == 5 and not flow.debut_redo and flow.last_payment > 0, "撮れた紹介動画は、ふつうに精算（ギャラ %d）" % flow.last_payment)
	check(flow.last_flubs.any(func(l: String) -> bool: return l.contains("ランプ")), "テレビ局のコメントが来る")
	check(flow.rent_paid == 0, "紹介動画の日に、家賃は来ない")
	game.h_return_office()
	await frames(20)
	check(int(calls.rang) >= 1, "帰社すると、電話が鳴る")
	check(flow.day == 3 and debut not in flow.offered() and flow.offered().size() == 3, "3日目から、ほかの依頼が3枚来る")
	check(flow.rent_in() == 2, "家賃は、紹介動画を上げた日から数えて3本目（あと%d本）" % flow.rent_in())
	print("DELIVER_TEST_FAIL" if failed else "DELIVER_TEST_OK")
	var sfx := root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	await frames(4)
	quit(1 if failed else 0)
