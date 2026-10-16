extends SceneTree
# 映り込みの減点を、映り込んだ人が映っているコマに付ける（production_notes.gd の cameo_at・features/premiere.gd）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/cameo_frame_test.gd
# 本番の途中で、班の誰か（自分）が撮影カメラの前に1秒ほど立つ → 試写会のその時刻に、依頼主が気づく →
# フィルムの採点で「〜が〜秒出演」の行が、その時刻に写したコマに付く（今までは最後の「終」のコマだった）。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CAMEO_CHECK ", label, " ", "OK" if ok else "FAIL")
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
	var me: Node3D = game.local_player()
	game.h_accept_job(0)
	await frames(20)
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "現場に着いた")
	var film: Node3D = game.program_camera()
	var aside: Vector3 = film.global_position + film.global_basis.z * 2.0 + Vector3(0, 0.1, 0)
	me.global_position = aside
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(90)
	# 本番の途中で、カメラの前に立つ（2.5秒）
	var eye: Camera3D = film.view_cam
	var ahead: Vector3 = -eye.global_basis.z
	ahead.y = 0.0
	var front: Vector3 = eye.global_position + ahead.normalized() * 3.0
	front.y = film.global_position.y + 0.1
	me.global_position = front
	await frames(150)
	me.global_position = aside
	await frames(60)
	game._cut()
	await frames(5)
	var notes: RefCounted = flow.notes
	var name: String = notes.cameo_at.keys()[0] if not notes.cameo_at.is_empty() else ""
	check(name != "" and float(notes.cameos.get(name, 0.0)) >= 0.5, "本番中に、映り込んだ人と秒数を数えた（%s）" % str(notes.cameos))
	var at: float = float(notes.cameo_at.get(name, -1.0))
	check(at > 1.2 and at < 4.5, "はっきり映った時刻を控えた（%.2f 秒）" % at)
	check((premiere._cameo_times.get(0, []) as Array).size() == 1, "試写会の反応の予定に、映り込みが入る")
	game.request_deliver(0)
	var heard := ""
	for i in 900:
		await physics_frame
		if premiere.last_line.contains(name):
			heard = premiere.last_line
		if game.state == S.DELIVERED:
			break
	check(heard != "", "試写会のその時刻に、依頼主が気づく（%s）" % heard)
	var cameo_shot := false
	for shot: Array in premiere._shots:
		if str(shot[2]) == "cameo:%s" % name:
			cameo_shot = absf(float(shot[0]) - at) < 0.6
	check(cameo_shot, "映り込んだ時刻のコマを写した")
	for i in 400:
		if premiere._sheet.visible:
			break
		await physics_frame
	premiere.finish_tally()
	await frames(5)
	var on_frame := ""
	for item: Array in premiere._items:
		for row: Array in item[2]:
			if str(row[0]).contains("秒出演"):
				on_frame = str(item[4])
	check(on_frame == "cameo:%s" % name, "「〜秒出演」の行は、映り込んだコマに付く（%s）" % on_frame)
	print("CAMEO_TEST_FAIL" if failed else "CAMEO_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
