extends SceneTree
# カット割りの依頼（「怪獣ドラマ 第1話（カット割り）」）の、カットと場転を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/cuts_test.gd
# 場面が撮れると少し回してからフィルムが止まる（カット）→ 止めている間は、時計・記録・採点が止まる（場転）→
# 役者は次の場面の最初の印へ歩いて待つ → 台本を読める人の 1 で回し直す → 見返しでは、カットの前後がつながって流れる。
# 場面そのものの撮れ方（怪獣の映り方など）は kaiju5_test.gd が見ている。ここでは、場面が撮れたことにして進める。
var game: Node
var flow: Node
var beats: Node
var S: Dictionary
var me: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CUTS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	prop.restore([pos, Quaternion.IDENTITY, false])


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	beats = game.beats
	S = game.S
	me = game.local_player()
	# ---- 依頼 ----
	var job := -1
	for i in flow.JOBS.size():
		if job < 0 and beats.Scripts.cuts(i) and (beats.Scripts.beats(i) as Array).size() == 5:
			job = i          # 怪獣ドラマ（会社のCMも、カット割りの依頼）
	check(job >= 0 and (flow.JOBS[job]["scenes"] as Array).size() == 5 and (beats.Scripts.beats(job) as Array).size() == 5, "カット割りの依頼がある（5場面）")
	check(not beats.Scripts.cuts(job - 1), "完全版は、長回しのまま")
	check(str(flow.Briefs.brief(job).get("name", "")) != "" and (flow.Briefs.brief(job)["lines"] as Array).size() >= 3, "依頼主の打ち合わせがある")
	flow.day = 2
	game.h_accept_job(job)
	await frames(20)
	check(beats.active() and beats.cut_mode(), "受けると、カット割りで進む")
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "現場に着いた")
	# 台本を読める人（台本のすぐそばにいる）
	var book: Node = flow.script_prop
	me.global_position = game.film.global_position + Vector3(0.6, 0.1, 1.2)
	await frames(2)
	place(book, me.global_position + Vector3(0.5, 0.0, 0.0))
	await frames(10)
	check(beats.may_direct(me.peer_id), "台本のそばの人が、場面を進められる")
	# ---- 本番：カチンコで、最初の場面がそのまま始まる ----
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(5)
	check(game.state == S.TAKE and beats.scene == 0 and not beats.holding, "カチンコの合図で、最初の場面から回る")
	await frames(60)
	var t1: float = game.take_t
	check(t1 > 0.8, "回している間は、フィルムが進む（%.2f 秒）" % t1)
	# 場面1が撮れたことにする → 少し回してから、カット
	beats._met(0)
	await frames(20)
	check(not beats.holding and game.take_t > t1, "撮れてすぐには止めない（少し回す）")
	await frames(70)
	check(beats.holding and beats.next_scene == 1 and game.take_held(), "撮れたら、フィルムが止まる（場転。次は場面2）")
	check(game.cue_names()[0].contains("回す"), "止めている間の 1 は「回す」")
	# 場転の間は、時計も記録も採点も止まる。役者は、次の場面の最初の印へ歩いて待つ
	var t2: float = game.take_t
	var rec2: int = (game._rec_frames as Array).size()
	var ev2: int = (game._rec_events as Array).size()
	var b: Dictionary = beats.list()[1]
	var from_a: Vector3 = beats.spot(0, int(b.get("from", 0)))
	var monster: Node = null
	for p: Node in game.props.values():
		if p.kind == "toy_kaiju" or game.judge.role_of(p) == "monster":
			monster = p
			break
	if monster != null:
		place(monster, game.film.global_position + Vector3(-0.9, 0.0, -1.4))      # 場転：怪獣を出す
	await frames(240)
	check(is_equal_approx(float(game.take_t), t2), "止めている間は、フィルム（時計）が減らない")
	check((game._rec_frames as Array).size() == rec2, "止めている間は、映像を記録しない")
	check((game._rec_events as Array).size() == ev2, "止めている間の音や出来事も、映画に入らない")
	var walked: float = Vector2(game.actors[0].global_position.x - from_a.x, game.actors[0].global_position.z - from_a.z).length()
	check(walked < 0.7, "役者は、次の場面の最初の印へ歩いて、そこで待つ（残り %.2f m）" % walked)
	# 止めている間の爆発は、映画に映らない（使い損。怪獣の技の場面にも数えない）
	beats.on_burst(game.film.global_position + Vector3(0, 0, -6), 0)
	check(float(beats._boom_t) < 0.0, "止めている間の爆発は、数えない")
	# 回し直す：1
	game.h_beat(1)
	await frames(10)
	check(not beats.holding and beats.scene == 1 and game.take_t > t2, "1 で、用意した場面から回し直す")
	check(game.cue_names()[0].contains("カット"), "回している間の 1 は「カット」")
	# 撮れないまま 1：同じ場面を、場転のあとに撮り直す
	await frames(30)
	game.h_beat(1)
	await frames(5)
	check(beats.holding and beats.next_scene == 1 and not beats.lit[1], "撮れていない場面で 1 を押すと、同じ場面を撮り直すために止める")
	await frames(30)
	game.h_beat(2)
	await frames(10)
	check(not beats.holding and beats.scene == 1, "止めている間は、2 でも回し直す")
	await frames(40)
	game._cut()
	await frames(5)
	check(game.state == S.RESULT and not beats.holding, "カットでテイクが終わる")
	# 見返し：記録の時刻に、場転の分のすき間がない（カットの前後が、つながって流れる）
	var data: Dictionary = game._take_data[0]
	var times: Array = (data["frames"] as Array).map(func(f: Array) -> float: return float(f[0]))
	var gap := 0.0
	for i in range(1, times.size()):
		gap = maxf(gap, float(times[i]) - float(times[i - 1]))
	print("CUTS_MEASURE 記録 ", times.size(), " コマ・長さ %.2f 秒・いちばん大きいすき間 %.3f 秒" % [float(data["dur"]), gap])
	check(gap < 0.12 and float(data["dur"]) < 7.0, "見返しは、回していた時間だけで、すき間なくつながる")
	var held_events := 0
	for e: Array in data["events"]:
		if str(e[1]) == "beat" and bool((e[2][0] as Dictionary).get("hold", false)):
			held_events += 1
	check(held_events == 0, "見返しの中で、フィルムが止まったままにならない")
	print("CUTS_TEST_FAIL" if failed else "CUTS_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)
