extends SceneTree
# バミリ（役者の立ち位置を、床のテープで教える。features/bami.gd・production_beats.gd の spots）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/bami_test.gd
# 床に印の物は無い → 役者を見て F → 床を左クリックで、そこが立ち位置（役者が歩き、テープが貼られる）→
# もう一度教えると次の立ち位置・指している間の F で選び直し・同じ立ち位置は貼り替え・右クリック（h_peel）ではがす →
# 教えていない役者は決まった場所 → 回している間は教えられない・場転の間は次の場面の立ち位置 →
# 役に入った人の M（足元に自分のバミリ）と、教えていない役の「止まった所が立ち位置」→ 帰社ではがす。
# 二人での同期（立ち位置が全員にそろう・途中参加）は kaiju5_net_test.gd が見ている
var game: Node
var flow: Node
var beats: Node
var bami: Node
var S: Dictionary
var me: Node
var failed := false
var checks := 0


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("BAMI_CHECK ", label, " ", "OK" if ok else "FAIL")
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


func of_kind(kind: String) -> Array:
	return game.props.values().filter(func(p: Node) -> bool: return p.kind == kind)


# 視点（カメラ）から、その点を見る（後ろからの視点なので、カメラの位置から向きを決め直す）
func aim(target: Vector3) -> void:
	for i in 4:
		var from: Vector3 = me.cam.global_position
		var d := target - from
		me.aim_yaw = atan2(-d.x, -d.z)
		me.aim_pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await frames(2)


func tapes() -> Array:
	return bami._tapes.values().filter(func(t: Variant) -> bool: return is_instance_valid(t) and not (t as Node).is_queued_for_deletion())


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# 役者を見て F → 床を指して左クリック（本物の操作の関数を通す）。教えた立ち位置の番号を返す（-1＝教えられなかった）
func teach(aid: int, floor_at: Vector3, extra_f: int = 0) -> int:
	var a: Node3D = game.actors[aid]
	await aim(a.global_position + Vector3(0, 0.9, 0))
	if not bami.hook_f(me):
		return -1
	for k in extra_f:
		bami.hook_f(me)
	var step: int = bami._aim_step
	await aim(floor_at)
	bami.hook_click(me)
	await frames(3)
	return step


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
	bami = game.hooks.feature("bami")
	S = game.S
	me = game.local_player()
	check(bami != null, "バミリの仕組みが、置くだけで登録されている")
	check(of_kind("mark").is_empty() and not ("pid" in game.actors[0].mark), "床に印の物は無い（役者の待つ場所は、物ではない）")
	check(Keybinds.code("self_mark") == KEY_M and Keybinds.ACTIONS.filter(func(a: Array) -> bool: return a[2] == KEY_M).size() == 1, "足元のバミリは M（ほかのキーと重ならない）")
	# ---- カット割りの依頼（怪獣ドラマ）を受けて、現場へ ----
	var job := -1
	for i in flow.JOBS.size():
		if job < 0 and beats.Scripts.cuts(i) and (beats.Scripts.beats(i) as Array).size() == 5:
			job = i
	flow.day = 2
	game.h_accept_job(job)
	await frames(20)
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4 and beats.cut_mode() and beats.step_count() == 3, "現場に着いた（カット割り・立ち位置は3つ）")
	var a: Node3D = game.actors[0]
	var b: Node3D = game.actors[1]
	var home_ok := true
	for aid in 2:
		for step in 3:
			home_ok = home_ok and not beats.taught(aid, step) and beats.spot(aid, step).distance_to(beats.MARK_HOME[aid][step] + flow.site_center()) < 0.01
	check(home_ok and tapes().is_empty(), "教えるまでは、立ち位置は決まった場所で、床には何も無い")
	check(flat(a.global_position, beats.home(0, 0)) < 0.2, "役者は、決まった場所で待つ")

	# ---- 役者を見て F → 床を左クリック ----
	me.global_position = Vector3(0.5, 0.1, 2.0)
	await frames(10)
	var spot1 := Vector3(0.6, 0.0, -1.2)
	await aim(a.global_position + Vector3(0, 0.9, 0))
	var hud: Dictionary = bami.hook_hud(me, "", "")
	check(bami.looked_actor(me) == a and str(hud.get("keys_all", "")).contains("立ち位置を教える（立ち位置1）"), "役者を見ると、案内に「F 立ち位置を教える（立ち位置1）」（%s）" % str(hud))
	var step := await teach(0, spot1)
	check(step == 0 and beats.taught(0, 0) and flat(beats.spot(0, 0), spot1) < 0.35, "見て F → 床を左クリックで、立ち位置1を教えた（%s）" % str(beats.spot(0, 0)))
	var tape: Node3D = bami._tapes.get("0:0")
	check(tape != null and flat(tape.global_position, beats.spot(0, 0)) < 0.01 and tape.find_children("*", "CollisionObject3D", true, false).is_empty() and tape.find_children("*", "Label3D", true, false).is_empty(),
		"足元に、役者の色のテープが貼られる（当たり判定も、浮いた文字も無い）")
	var tab: MeshInstance3D = tape.get_child(2)
	check(((tab.material_override as StandardMaterial3D).albedo_texture as Texture2D) != null, "番号は、テープの切れ端の絵に書いてある")
	await frames(200)
	check(a.beat_arrived() and flat(a.global_position, beats.spot(0, 0)) < 0.2, "役者は、教えた所まで歩いて、そこに立つ")
	check(not game.props.values().any(func(p: Node) -> bool: return p.kind == "mark"), "テープは、持てる物ではない")
	# もう一度教える：次の、まだ教えていない立ち位置
	var spot2 := Vector3(1.8, 0.0, 0.2)
	step = await teach(0, spot2)
	check(step == 1 and flat(beats.spot(0, 1), spot2) < 0.35 and tapes().size() == 2, "同じ役者にもう一度教えると、立ち位置2")
	# 指している間の F で、立ち位置を選び直す（3 → 1）。同じ立ち位置は、テープが貼り替わる
	var spot1b := Vector3(-0.8, 0.0, -2.0)
	step = await teach(0, spot1b, 1)
	check(step == 0 and flat(beats.spot(0, 0), spot1b) < 0.35 and tapes().size() == 2, "指している間の F で選び直し、立ち位置1を教え直すと、テープが貼り替わる")
	# はがす
	await frames(200)
	bami.h_peel(0, 1)
	await frames(3)
	check(not beats.taught(0, 1) and tapes().size() == 1 and beats.spot(0, 1).distance_to(beats.home(0, 1)) < 0.01, "はがすと、その立ち位置は決まった場所に戻る")
	check(not beats.taught(1, 0) and not beats.taught(1, 1), "教えていない役者B は、決まった場所のまま")

	# ---- 通し稽古：教えた役者は教えた所へ、教えていない役者は決まった所へ ----
	beats._enter(0, false)            # 場面1：立ち位置1 → 2
	await frames(240)
	check(flat(a.global_position, beats.home(0, 1)) < 0.3 and flat(b.global_position, beats.home(1, 1)) < 0.3, "立ち位置2を教えていない二人は、決まった場所へ歩く")
	game.h_standby()
	await frames(5)
	check(flat(a.global_position, spot1b) < 0.4, "B で戻すと、教えた立ち位置1で待つ")

	# ---- 本番：回している間は教えられない。場転の間は、次の場面の立ち位置 ----
	var book: Node = flow.script_prop
	me.global_position = game.film.global_position + Vector3(0.6, 0.1, 1.2)
	await frames(2)
	place(book, me.global_position + Vector3(0.5, 0.0, 0.0))
	await frames(5)
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(5)
	check(bami.blocked() != "", "回している間は、立ち位置を教えられない")
	bami.h_teach(0, 2, 0, Vector3.ZERO, Vector3(2.0, 0, -1.0), false)
	await frames(2)
	check(not beats.taught(0, 2), "回している間の頼みは、ホストが断る")
	beats._met(0)
	await frames(100)
	game.h_beat(1)              # 場面2（怪獣あらわる）
	await frames(10)
	beats._met(1)
	await frames(100)
	check(beats.holding and beats.next_scene == 2 and bami.blocked() == "", "場転の間（次は場面3）は、教えられる")
	var next_to := int((beats.list()[2] as Dictionary)["to"])
	var next_from := int((beats.list()[2] as Dictionary)["from"])
	check(beats.teach_step(1) == next_to, "場転の間は、次の場面で役者が向かう立ち位置（%d）を教える" % (next_to + 1))
	var spot3 := Vector3(2.2, 0.0, 1.0)
	me.global_position = Vector3(3.5, 0.1, 3.5)
	await frames(5)
	bami.h_teach(1, -1, 0, Vector3.ZERO, spot3, false)
	await frames(3)
	check(beats.taught(1, next_to) and flat(beats.spot(1, next_to), spot3) < 0.01, "役者B の立ち位置%dを教えた" % (next_to + 1))
	var reached := false
	for i in 300:
		await physics_frame
		reached = reached or flat(b.global_position, spot3) < 0.3
	check(reached and flat(b.global_position, beats.spot(1, next_from)) < 0.3, "役者は教えた所まで行って確かめ、次の場面の始まりの立ち位置へ戻って待つ")
	me.global_position = book.global_position + Vector3(-0.5, 0.1, 0.0)      # 台本のそばへ戻る（場面を進められる人）
	await frames(3)
	game.h_beat(1)              # 場面3：役者B は教えた所へ
	await frames(260)
	check(flat(b.global_position, spot3) < 0.3, "回し直すと、役者B は教えた立ち位置へ向かう")
	game._cut()
	await frames(5)
	game.h_retake()
	await frames(20)

	# ---- 自分で演じる：M で足元にバミリ（歩かされない）。教えていない立ち位置は、止まった所 ----
	check(game.state == S.PREP, "準備に戻った")
	var stand: Node = game.hooks.feature("stand_ins")
	stand.h_cast_actor("player", int(me.peer_id), 1)
	await frames(10)
	check(b.stand_in == me, "役者B の役に入った")
	hud = bami.hook_hud(me, "", "WASD 移動")
	check(str(hud.get("keys_all", "")).begins_with("M 足元にバミリ"), "役に入ると、案内に「M 足元にバミリ」（%s）" % str(hud))
	me.global_position = Vector3(-2.0, 0.1, 1.5)
	await frames(10)
	var at: Vector3 = me.global_position
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_M
	ev.pressed = true
	var want: int = beats.teach_step(1)
	check(bami.hook_key(ev, me), "M を受け取る")
	await frames(3)
	var mine := want if beats.taught(1, want) else -1
	check(mine >= 0 and flat(beats.spot(1, mine), at) < 0.05 and flat(me.global_position, at) < 0.05, "足元に、自分の役のバミリが貼られる（自分は動かされない）")
	# 教えていない立ち位置（役者B の立ち位置… の残り）へ向かう場面：止まった所に着いたとみる
	var free_scene := -1
	for i in beats.list().size():
		if free_scene < 0 and not beats.taught(1, int((beats.list()[i] as Dictionary)["to"])):
			free_scene = i
	if free_scene >= 0:
		beats._enter(free_scene, false)
		await frames(40)
		check(b.beat_arrived(), "教えていない立ち位置なら、役に入った人が止まった所が、その場面の立ち位置")
	stand.h_cast_actor("player", int(me.peer_id), -1)
	await frames(5)

	# ---- 帰社：現場のバミリは、はがして帰る ----
	beats.hook_return_office()
	await frames(3)
	check(tapes().is_empty() and not beats.taught(0, 0) and not beats.taught(1, next_to), "帰社すると、テープは全部はがれる")
	print("BAMI_TEST_FAIL checks=%d" % checks if failed else "BAMI_TEST_OK checks=%d" % checks)
	quit(1 if failed else 0)
