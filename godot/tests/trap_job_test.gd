extends SceneTree
# 転がる大岩・予告編（production_script.gd の 9。production_beats.gd の track・drop）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/trap_job_test.gd
# 場面1：歩く二人を映したまま、カメラが動くと撮れる（止まったカメラでは撮れない）。
# 場面2：立ち止まった二人のそばで、上から物が1m以上落ちると撮れる。落とす仕掛け（ロープを焼き切る）で落とす。
var game: Node
var flow: Node
var beats: Node
var S: Dictionary
var me: Node
var failed := false


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("TRAP_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), false])


# ライト2台を、カメラの左右から、その場所へ向ける
func light(at: Vector3) -> void:
	var film: Node3D = game.film
	for i in 2:
		place(game.spots[i], film.global_position + Vector3(-1.3 + 2.6 * float(i), 0.0, 0.4), PI)
	await frames(10)
	for i in 2:
		game._aim_spot(game.spots[i], at + Vector3(0, 1.3, 0))
		game.spots[i].level = 3


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
	var rig: Node = game.hooks.feature("contraptions")
	var job := -1
	for i in flow.JOBS.size():
		if str(flow.JOBS[i]["title"]) == "転がる大岩・予告編":
			job = i
	check(job >= 0, "転がる大岩・予告編の依頼がある")
	if job < 0:
		quit(1)
		return
	check((beats.Scripts.beats(job) as Array).size() == 4 and beats.Scripts.cuts(job) and (flow.JOBS[job]["scenes"] as Array).size() == 4, "4カットのカット割り")
	check((flow.Briefs.brief(job)["lines"] as Array).size() >= 3 and str(flow.Briefs.brief(job)["name"]) == "ベレー帽先生", "打ち合わせ（ベレー帽先生）がある")
	check((flow.Briefs.BOARDS["trap"] as Array).size() == 4, "絵コンテの文が4枚ある")
	var pic: Texture2D = load("res://scripts/ui/storyboard.gd").texture("trap", 1)
	check(pic != null, "絵コンテの絵が描ける")
	flow.day = 2
	game.h_accept_job(job)
	await frames(20)
	check(beats.active() and beats.cut_mode(), "受けると、カット割りで進む")
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "現場（倉庫）に着いた")
	var book: Node = flow.script_prop
	var film: RigidBody3D = game.film
	# カメラを、印の列を横から映す所へ。カメラは台車に載せない（あとで手で動かす）
	var a1: Vector3 = beats.mark(0, 1).global_position
	var a0: Vector3 = beats.mark(0, 0).global_position
	var mid: Vector3 = (a0 + a1) * 0.5
	place(film, Vector3(mid.x - 1.0, 0.05, mid.z + 4.2), 0.0)
	await frames(20)
	await light(mid)
	me.global_position = film.global_position + Vector3(0.8, 0.1, 1.6)
	place(book, me.global_position + Vector3(0.5, 0.0, 0.0))
	await frames(10)
	# ---- 本番 ----
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(5)
	check(game.state == S.TAKE and beats.scene == 0, "本番：場面1（遺跡に踏み込む）から回る")
	# 止まったカメラ：二人は歩くが、撮れない
	await frames(90)
	check(not beats.lit[0], "カメラが止まっていると、場面1は撮れない（理由：%s）" % beats._top_reason(0))
	check(beats._top_reason(0).contains("カメラが止まって") or beats._top_reason(0) == "", "撮れない理由は、カメラが止まっていた")
	# 撮り直し：もう一度、歩く二人と一緒にカメラを動かす（台車の代わりに、毎コマ少しずつ横へ）
	game.h_beat(2)
	await frames(40)
	var moved := 0.0
	for i in 240:
		if beats.lit[0]:
			break
		if game.actors[0].beat_walking():
			film.global_position += Vector3(0.02, 0, 0)
			moved += 0.02
		await physics_frame
	check(beats.lit[0], "カメラを動かしながら歩く二人を映すと、場面1が撮れる（動かした %.2f m・理由：%s）" % [moved, beats._top_reason(0)])
	for i in 200:
		if beats.holding:
			break
		await physics_frame
	check(beats.holding and beats.next_scene == 1, "撮れたら、フィルムが止まる（場転）")
	# ---- 場転：罠を仕掛ける。二人の立ち止まる印②の横、頭の上に重りを吊る ----
	var spot: Vector3 = beats.mark(0, 1).global_position.lerp(beats.mark(1, 1).global_position, 0.5) + Vector3(0.9, 0, 0)
	var bag: RigidBody3D = game.stage.spawn("sandbag", Vector3(spot.x, 1.6, spot.z), 0.0)
	await frames(1)
	var top: Vector3 = bag.center_global() + Vector3(0, bag.half.y * 0.9, 0)
	var rope: int = rig.host_add_row([0, top + Vector3(0, 0.7, 0)], [bag.pid, bag.to_local(top)], [])
	await frames(30)
	# カメラを、二人と罠が入る所へ（固定）
	var stand: Vector3 = beats.mark(0, 1).global_position
	place(film, Vector3(stand.x + 0.4, 0.05, stand.z + 4.5), 0.0)
	await frames(30)
	await light(stand)
	game.h_beat(1)
	await frames(2)
	var resumed: float = game.take_t
	for i in 240:
		if game.actors[0].beat_arrived() and game.actors[1].beat_arrived():
			break
		await physics_frame
	await frames(20)
	check(not beats.holding and beats.scene == 1 and not beats.lit[1], "場面2：二人が立ち止まる。まだ何も落ちていない")
	var lit_at: float = game.take_t
	rig.host_ignite(rope, 0.3)
	for i in 200:
		if beats.lit[1]:
			break
		await physics_frame
	check(beats.lit[1], "ロープが焼き切れて、重りが二人のそばに落ちると、場面2が撮れる（理由：%s）" % beats._top_reason(1))
	# ---- 見返し（試写会と同じ再生）：場転で結んだロープは、回し直した時から張っていて、火を付けた時刻のあとで焼き切れる ----
	await frames(30)
	game._cut()
	await frames(5)
	game.h_replay(0)
	for i in 900:
		if float(game.replay_t) >= resumed + 0.3:
			break
		await physics_frame
	var row: Dictionary = rig.rows.get(rope, {})
	check(not row.is_empty() and not bool(row["cut"]) and float(row["fire"]) < 0.0, "見返し：場面2が始まった時、罠のロープは張っている（%s）" % str(row.get("cut", "無い")))
	for i in 900:
		if float(game.replay_t) >= lit_at + rig.BURN_SEC + 0.4:
			break
		await physics_frame
	row = rig.rows.get(rope, {})
	check(not row.is_empty() and bool(row["cut"]), "見返し：火を付けた時刻のあとで、焼き切れる")
	game.h_stop_replay()
	await frames(5)
	check(not rig._playback and rig.rows.has(rope) and bool(rig.rows[rope]["cut"]), "見返しが終わると、今の状態（焼き切れたまま）に戻る")
	print("TRAP_TEST_FAIL" if failed else "TRAP_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
