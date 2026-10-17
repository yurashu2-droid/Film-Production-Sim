extends SceneTree
# 役に入る（兼任。scripts/features/stand_ins.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/stand_ins_test.gd
# 自分が Y で役者 A に入る・等身大パネルを役者 B にする。役者は姿を消して付いていき、印に着いたかを、その人の位置で決める。
# 役に入った人は「映り込み」に数えない。帰社すると、役から抜ける。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("STAND_INS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func press_y() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Y
	key.pressed = true
	return key


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var roles: Node = game.hooks.feature("stand_ins")
	check(roles != null, "役に入る仕組みが登録されている")
	if roles == null:
		quit(1)
		return
	var me: Node3D = game.local_player()
	var a: Node = game.actors[0]
	var b: Node = game.actors[1]
	# 1日目：会社のCM（会社の前で撮る）を受けて、その場で準備に入る
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	check(int(flow.phase) == 4 and game.state == game.S.PREP, "現場（会社の前）で準備中")
	# 何も狙っていない Y：自分が役者 A に入る
	me.target = null
	check(roles.hook_key(press_y(), me), "何も狙っていない Y は、役に入る操作になる")
	await frames(3)
	check(a.stand_in == me and not a.vis.visible, "役者 A は姿を消して、自分に付いていく")
	check(me.vis.find_child("RoleSash", true, false) != null, "自分に、役の色のたすきが掛かる")
	me.global_position = me.global_position + Vector3(2.0, 0, 0)
	await frames(4)
	check(a.global_position.distance_to(me.global_position) < 0.05, "役者 A の位置は、自分の位置に重なる（判定は役者を見るので、自分の位置で数えられる）")
	# 印へ向かう場面：自分が印に着くと「着いた」、離れると「着いていない」
	var spot: Vector3 = me.global_position + Vector3(0, 0, -3.0)
	a.play_beat({"to": spot, "gait": "walk", "pose": "idle", "look": "", "face_go": "neutral", "face_hold": "neutral"})
	await frames(3)
	check(not a.beat_arrived(), "印から遠いうちは、着いていない")
	me.global_position = spot + Vector3(0.3, 0, 0.2)
	await frames(4)
	check(a.beat_arrived(), "自分が印のそばへ行くと、着いた（%.2f m）" % Vector2(spot.x - me.global_position.x, spot.z - me.global_position.z).length())
	me.global_position = spot + Vector3(3.0, 0, 0)
	await frames(4)
	check(not a.beat_arrived(), "印から離れると、着いていない")
	# 撮影カメラの真ん前に立っても、役に入っている間は「映り込み」に数えない
	var film: Node3D = game.film
	var front: Vector3 = film.global_position - film.global_basis.z * 3.0
	me.global_position = Vector3(front.x, me.global_position.y, front.z)
	await frames(4)
	check((flow.notes.crew_in_frame() as Array).is_empty(), "役に入っている人は、映り込みに数えない")
	# 等身大パネルを役者 B に
	var panel: Node = null
	for p: Node in game.props.values():
		if p.kind == "standin" and not p.absent:
			panel = p
	check(panel != null, "等身大パネルがある")
	if panel != null:
		me.global_position = panel.global_position + Vector3(1.2, 0, 0)
		await frames(3)
		me.target = panel
		roles.hook_key(press_y(), me)        # 1回目：A（自分から A を取る）
		await frames(3)
		check(a.stand_in == panel and roles.role_of("player", int(me.peer_id)) == -1, "パネルを A にすると、自分は A から外れる")
		me.target = panel
		roles.hook_key(press_y(), me)        # 2回目：B
		await frames(3)
		check(b.stand_in == panel and a.stand_in == null and a.vis.visible, "パネルは B になり、A は NPC の役者に戻る")
		var b_before: Vector3 = b.global_position
		panel.global_position = panel.global_position + Vector3(0, 0, 1.0)
		await frames(6)
		var gap: float = Vector2(b.global_position.x - panel.global_position.x, b.global_position.z - panel.global_position.z).length()
		check(gap < 0.3 and b.global_position.distance_to(b_before) > 0.7, "役者 B は、パネルに付いていく（パネルを動かすと、役者も動いたことになる。ずれ %.2f m）" % gap)
	# 自分の Y：A → B → C → D → やめる（狙いは毎コマ照準から決め直されるので、押す直前に外す）
	me.target = null
	roles.hook_key(press_y(), me)
	await frames(3)
	check(roles.role_of("player", int(me.peer_id)) == 0, "Y で A")
	me.target = null
	roles.hook_key(press_y(), me)
	await frames(3)
	check(roles.role_of("player", int(me.peer_id)) == 1 and b.stand_in == me, "もう一度 Y で B（パネルは B から外れる）")
	# 会社の紹介動画は、役者が4人（社長と社員3人）。B のあとは C → D → やめる
	for want: int in [2, 3]:
		me.target = null
		roles.hook_key(press_y(), me)
		await frames(3)
		check(roles.role_of("player", int(me.peer_id)) == want, "もう一度 Y で %s（4人の台本）" % ["A", "B", "C", "D"][want])
	me.target = null
	roles.hook_key(press_y(), me)
	await frames(3)
	check(roles.role_of("player", int(me.peer_id)) == -1 and me.vis.find_child("RoleSash", true, false) == null, "もう一度 Y でやめる（たすきも外れる）")
	# 帰社すると、みんな役から抜ける
	me.target = null
	roles.hook_key(press_y(), me)
	await frames(3)
	roles.hook_return_office()
	await frames(3)
	check(a.stand_in == null and b.stand_in == null and a.vis.visible and b.vis.visible, "帰社すると、役から抜け、NPC の役者に戻る")
	print("STAND_INS_TEST_FAIL" if failed else "STAND_INS_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
