extends SceneTree
# 追加注文の札（features/order_cards.gd）：
#   ・自動確認の中では引かない。force を立てると、依頼を受けたときに引く
#   ・枚数は依頼の格で決まる（格1・2＝1枚、格3＝2枚、格4＝3枚）。2枚以上なら、最後の1枚は現場に着いてから届く
#   ・いっしょに引かない組（予算半分と借り物なし）・逆の注文（映り込み0.5秒以内の依頼に「スタッフも出して」）は出ない
#   ・守れた札だけ、ギャラに上乗せされる。1場面も撮れていなければ、上乗せは無い
#   godot --headless --path godot --fixed-fps 60 --script res://tests/order_cards_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CARDS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func ids(list: Array) -> Array:
	return list.map(func(c: Dictionary) -> String: return str(c["id"]))


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var f: Node = game.hooks.feature("order_cards")
	check(f != null and (f.cards as Array).is_empty(), "はじめは、札は無い")
	# ---- 自動確認の中では、受けても引かない ----
	var easy := 4          # お嬢様の大怪獣（格1・追加注文は一発OK）
	var crew := 3          # 怪獣、段ボールの街に現る（格2・追加注文は映り込み0.5秒以内）
	var big := 5           # 怪獣…完全版（格4）
	check(flow.job_rank(easy) == 1 and flow.job_rank(big) == 4 and str(flow.JOBS[crew]["bonus"]) == "no_crew", "確認に使う依頼の格と追加注文が、思ったとおり")
	game.h_accept_job(easy)
	await frames(20)
	check((f.cards as Array).is_empty() and not f._paper.visible, "自動確認の中では、依頼を受けても札は引かない")
	# ---- 引き方：枚数・組み合わせ ----
	flow.chosen_job = easy
	var one: Array = f.draw(1)
	check(one.size() == 1 and bool(one[0]["shown"]), "格1の依頼は1枚。すぐ届く（%s）" % str(ids(one)))
	flow.chosen_job = big
	var three: Array = f.draw(1)
	check(three.size() == 3 and bool(three[0]["shown"]) and bool(three[1]["shown"]) and not bool(three[2]["shown"]), "格4の依頼は3枚。最後の1枚は、あとで届く（%s）" % str(ids(three)))
	var clash := false
	var all_seen := {}
	for s in 200:
		var got: Array = ids(f.draw(s))
		clash = clash or ("half_budget" in got and "no_rental" in got) or got.size() != 3
		for id: String in got:
			all_seen[id] = true
	check(not clash, "「予算半分」と「借り物なし」は、いっしょには出ない（200回引いて）")
	check(all_seen.size() == (f.CARDS as Dictionary).size(), "どの札も出る（%d 種類）" % all_seen.size())
	flow.chosen_job = crew
	var cameo := false
	for s in 200:
		cameo = cameo or "cameo" in ids(f.draw(s))
	check(not cameo, "「映り込み0.5秒以内」の依頼には、「スタッフも出して」は出ない")
	for s in 200:
		for card: Dictionary in f.draw(s):
			if str(card["id"]) == "show_item":
				clash = clash or int(card["ref"]) == 0 or not str(card["need"]).contains("「") or str(card["need"]).contains("%s")
			if str(card["id"]) == "short":
				clash = clash or not str(card["need"]).contains("24 秒")
	check(not clash, "「これを映して」には物の名前が、「短くまとめて」には秒数（3場面なら24秒）が入る")
	# ---- 受けると届く。画面の左下の紙に並ぶ ----
	game.h_return_office()
	await frames(10)
	flow.phase = 0
	f.force = true
	game.h_accept_job(big)
	await frames(20)
	var shown: Array = (f.cards as Array).filter(func(c: Dictionary) -> bool: return bool(c["shown"]))
	check((f.cards as Array).size() == 3 and shown.size() == 2, "受けると、3枚のうち2枚がすぐ届く（事務所での準備のうちに見える）")
	game.input_locked = false
	await frames(5)
	check(f._paper.visible and f._rows.get_child_count() == 1 + 2 * 2, "左下の FAX の紙に、届いた2枚が並ぶ")
	# ---- 現場に着くと、差し込みの1枚が届く ----
	flow.phase = 4
	await frames(10)
	check((f.cards as Array).all(func(c: Dictionary) -> bool: return bool(c["shown"])) and f._rows.get_child_count() == 1 + 3 * 2, "現場に着くと、差し込みの1枚も届く")
	# ---- 守れた札だけ、上乗せ ----
	f.cards = [
		{"id": "half_budget", "need": "", "coins": 150, "ref": 0, "shown": true},
		{"id": "quick", "need": "", "coins": 120, "ref": 0, "shown": true},
		{"id": "hide_gear", "need": "", "coins": 120, "ref": 0, "shown": true},
		{"id": "cameo", "need": "", "coins": 100, "ref": 0, "shown": true},
	]
	flow.expenses = int(flow.budget() / 2)
	flow.lease_left = 200.0          # 5分は残っていない
	f._gear_sec = 0.1
	flow.notes.crew_seconds = 0.4
	game.takes = [{"results": [], "passed": [true, false, false, false, false], "dur": 30.0}]
	f.hook_take_cut()
	var lines: Array = f.hook_fee_lines(0)
	var total := 0
	for l: Array in lines:
		total += int(l[1])
	check(lines.size() == 2 and total == 270, "守れた2枚（予算半分・機材を映さない）だけ、上乗せ 270（%s）" % str(lines))
	check(int(flow.take_fee(0)) >= 270, "上乗せは、ギャラの計算に入る（%d）" % int(flow.take_fee(0)))
	game.takes = [{"results": [], "passed": [false, false, false, false, false], "dur": 30.0}]
	f.hook_take_cut()
	check((f.hook_fee_lines(0) as Array).is_empty(), "1場面も撮れていなければ、札の上乗せは無い")
	# 個別の決まり
	f.cards = [{"id": "no_rental", "need": "", "coins": 200, "ref": 0, "shown": true}, {"id": "short", "need": "", "coins": 120, "ref": 0, "shown": true},
		{"id": "show_item", "need": "", "coins": 150, "ref": 1, "shown": true}, {"id": "rookie", "need": "", "coins": 150, "ref": 0, "shown": true}]
	flow.expenses = 0
	f._item_sec = {2: 2.5}
	game.hooks.feature("stand_ins").plan = ["rookie", "none", "none", "none"]
	var take := {"results": [], "passed": [true, true, true, true, true], "dur": 39.0}
	check(f.met(0, take) and f.met(1, take) and f.met(2, take) and f.met(3, take), "借り物なし・短く（5場面なら40秒以内）・物を2秒映す・新人を使う、を守れている")
	flow.expenses = 10
	f._item_sec = {2: 1.0}
	game.hooks.feature("stand_ins").plan = ["pro", "none", "none", "none"]
	take["dur"] = 41.0
	check(not f.met(0, take) and not f.met(1, take) and not f.met(2, take) and not f.met(3, take), "どれも、外れると守れていない")
	# ---- 帰社すると、札は片づく ----
	game.takes = []
	flow.phase = 5
	game.h_return_office()
	await frames(20)
	check((f.cards as Array).is_empty() and not f._paper.visible, "帰社すると、札は片づく")
	print("CARDS_TEST_FAIL" if failed else "CARDS_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)
