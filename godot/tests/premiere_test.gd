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
	await frames(30)
	game.h_cue(1)          # 合図1（告白）。試写会では、この時刻に「第1場」の見出しが出る
	await frames(120)
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
	check(game.state == S.RESULT and premiere.screening == 0 and premiere._layer.visible and premiere._card_box.visible, "納品を頼むと、まず題名の札（映画は、札のあとで流れ始める）")
	check(premiere._card_big.text.contains(str(flow.job()["title"])), "札には、映画の題名")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	check(premiere.hook_input(space), "札の間は、撮り直し（Space）などのキーが効かない")
	await frames(int(premiere.CARD_SEC * 60.0) + 10)
	check(game.state == S.REPLAY and premiere._layer.visible and not premiere._card_box.visible, "札のあとで、試写会でテイクが流れる")
	check(premiere._name.text != "" and premiere._title.text.contains(str(flow.job()["title"])), "依頼主の名前と、映画の題が出る")
	# 歩ける試写会：全員が事務所のスクリーンの前に集まり、カメラはスクリーンの方。見ている間も歩ける
	var me: Node3D = game.local_player()
	check(game.audience and me.global_position.distance_to(premiere.SEATS) < 3.0, "試写会は、事務所のスクリーンの前に集まって見る（%s）" % str(me.global_position))
	check(get_root().get_viewport().get_camera_3d() == premiere._cam, "カメラは、スクリーンの方を向いたまま")
	check(not premiere._doubles.is_empty() and game.replay_doubles.size() == premiere._doubles.size(), "撮影中の班の動きは、人形が再現する（%d 体）" % premiere._doubles.size())
	var before := me.global_position
	var locked: bool = game.input_locked
	game.input_locked = false
	Input.action_press("move_forward")
	await frames(40)
	Input.action_release("move_forward")
	game.input_locked = locked
	check(me.global_position.distance_to(before) > 0.4 and game.state == S.REPLAY, "見ている間も、プレイヤーは歩ける（%.2f m）" % me.global_position.distance_to(before))
	game.request_deliver(0)
	await frames(1)
	check(game.state == S.REPLAY and flow.phase == 4, "流している間に、もう一度押しても納品しない")
	await frames(60)
	print("PREMIERE_MEASURE 依頼主のひとこと＝", premiere.last_line)
	check(premiere.last_line.contains("告白"), "場面が撮れた時刻に、依頼主が反応する")
	check(premiere._chapter.text.begins_with("第1場"), "3場面の依頼でも、合図を出した時刻に場面の見出しが出る（%s）" % premiere._chapter.text)
	# とばす（Enter・Esc は見返しを止める）：締めのひとことのあと、納品になる
	game.h_stop_replay()
	await frames(10)
	check(game.state == S.DELIVERED and flow.phase == 5, "とばすと、納品になる")
	check(premiere._card_box.visible and premiere._card_big.text == "終" and not premiere._sheet.visible, "見終わると「終」の札が出て、読み上げはそのあと")
	await frames(120)
	print("PREMIERE_MEASURE 締め＝", premiere.last_line)
	check(premiere.last_line.contains("爆発") or premiere.last_line.contains("何の映画"), "「終」のあと、撮れなかった場面には首をかしげる")
	check(premiere._sheet.visible and not premiere.tally.is_empty() and str(premiere.tally[0][0]) == "納品の基本", "依頼主が、ギャラの中身を読み上げ始める")
	var voices: int = premiere.tally.filter(func(r: Array) -> bool: return bool(r[2])).size()
	print("PREMIERE_MEASURE 読み上げ＝", premiere.tally.size(), "行（依頼主のせりふ ", voices, "）")
	premiere.finish_tally()
	check(premiere._total.text.contains("+%d" % int(flow.last_payment)), "最後に、ギャラの合計が出る")
	premiere.finish_tally()
	check(not premiere._layer.visible and premiere.screening == -1, "読み上げを閉じると、いつもの精算の画面に戻る")
	check(not game.audience and game.replay_doubles.is_empty() and get_root().get_viewport().get_camera_3d() != premiere._cam, "終わると、カメラも体も元に戻り、人形は片づく")
	print("PREMIERE_TEST_FAIL" if failed else "PREMIERE_TEST_OK")
	var sfx := root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	await frames(8)
	quit(1 if failed else 0)
