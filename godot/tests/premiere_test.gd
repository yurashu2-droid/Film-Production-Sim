extends SceneTree
# 試写会（scripts/features/premiere.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/premiere_test.gd
# 画面から納品を頼むと、選んだテイクを依頼主と見てから納品になる。見返し（R）は試写会にならない。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("PREMIERE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var S: Dictionary = game.S
	var flow: Node = game.production
	var premiere: Node = game.hooks.feature("premiere")
	check(premiere != null, "試写会の仕組みが登録されている")
	if premiere == null:
		quit(1)
		return
	game.h_accept_job(0)
	await frames(20)
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "現場に着いた")
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	check(game.state == S.TAKE, "本番が始まった")
	await frames(150)
	game._cut()
	await frames(5)
	check(game.state == S.RESULT and game.takes.size() == 1, "カットして確認の画面になった")
	check(premiere._times.has(0) and (premiere._times[0] as Array).size() == 3, "本番中に、場面ごとの撮れた時刻を測っている（%s）" % str(premiere._times.get(0)))
	# 場面1が 0.5 秒で撮れたことにする（何も組んでいないので、この本番では場面が撮れていない）
	premiere._times[0] = [0.5, -1.0, -1.0]
	# ふつうの見返し（R）は、試写会にならない。終わっても納品しない
	game.h_replay(0)
	await frames(20)
	check(game.state == S.REPLAY and premiere.screening == -1 and not premiere._layer.visible, "見返しは、試写会にならない")
	game.h_stop_replay()
	await frames(5)
	check(game.state == S.RESULT and flow.phase == 4, "見返しが終わっても、納品はしない")
	# 画面から納品を頼む：試写会が始まる
	game.request_deliver(0)
	await frames(2)
	check(game.state == S.REPLAY and premiere.screening == 0 and premiere._layer.visible, "納品を頼むと、試写会でテイクが流れる")
	check(premiere._name.text != "" and premiere._title.text.contains(str(flow.job()["title"])), "依頼主の名前と、映画の題が出る")
	game.request_deliver(0)
	await frames(1)
	check(game.state == S.REPLAY and flow.phase == 4, "流している間に、もう一度押しても納品しない")
	await frames(60)
	print("PREMIERE_MEASURE 依頼主のひとこと＝", premiere.last_line)
	check(premiere.last_line.contains("告白"), "場面が撮れた時刻に、依頼主が反応する")
	# とばす（Enter・Esc は見返しを止める）：締めのひとことのあと、納品になる
	game.h_stop_replay()
	await frames(10)
	check(game.state == S.DELIVERED and flow.phase == 5, "とばすと、納品になる")
	print("PREMIERE_MEASURE 締め＝", premiere.last_line)
	check(premiere.last_line.contains("爆発") or premiere.last_line.contains("何の映画"), "撮れなかった場面には、首をかしげる")
	await frames(40)
	check(premiere._sheet.visible and not premiere.tally.is_empty() and str(premiere.tally[0][0]) == "納品の基本", "依頼主が、ギャラの中身を読み上げ始める")
	var voices: int = premiere.tally.filter(func(r: Array) -> bool: return bool(r[2])).size()
	print("PREMIERE_MEASURE 読み上げ＝", premiere.tally.size(), "行（依頼主のせりふ ", voices, "）")
	premiere.finish_tally()
	check(premiere._total.text.contains("+%d" % int(flow.last_payment)), "最後に、ギャラの合計が出る")
	premiere.finish_tally()
	check(not premiere._layer.visible and premiere.screening == -1, "読み上げを閉じると、いつもの精算の画面に戻る")
	print("PREMIERE_TEST_FAIL" if failed else "PREMIERE_TEST_OK")
	var sfx := root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	await frames(8)
	quit(1 if failed else 0)
