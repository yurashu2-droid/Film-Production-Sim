extends SceneTree
# スタントを撮る（features/stunts.gd の後半）：
#   ・役に入った人が、飛び降りる所が撮影カメラに映り、のびずに着地すると「決まった」。ギャラに上乗せ（高いほど多い）
#   ・受け止めた物が映っていなければ、もう少し上乗せ。のびた姿が映ると、少し引かれる
#   ・映っていない・役に入っていない人のスタントは、数えない
#   ・追加注文の札「どこかで1回、体を張って」は、決まったスタントが1つあれば守れる
#   ・演者の腕が上がると、のびずに済む高さが上がる
#   ・雇った役者も、強くぶつかると、のびる（ベテランは受け身がうまい）。やわらかい物があれば、のびない
#   godot --headless --path godot --fixed-fps 60 --script res://tests/stunt_shots_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(200).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("SHOT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func put(prop: Node, pos: Vector3) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	prop.restore([pos, Quaternion.IDENTITY, false])
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.sleeping = false


# 空中に置いて、床に着くまで待つ（着いてから、少し待つ）
func fall(me: Node3D, from: Vector3) -> void:
	me.velocity = Vector3.ZERO
	me.global_position = from
	await frames(3)
	for i in 600:
		await physics_frame
		if me.is_on_floor():
			break
	await frames(8)


# のびていたら、起き上がるまで待つ
func recover(me: Node3D, f: Node) -> void:
	for i in 400:
		if me.down <= 0.0 and f.downs.is_empty():
			break
		await physics_frame
	await frames(4)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var f: Node = game.hooks.feature("stunts")
	var roles: Node = game.hooks.feature("stand_ins")
	var cards: Node = game.hooks.feature("order_cards")
	var me: Node3D = game.local_player()
	var id := int(me.peer_id)
	# 1日目：会社の紹介動画（会社の前で撮る）を受けて、準備に入る
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	check(int(flow.phase) == 4 and game.state == game.S.PREP, "（準備）現場で準備中")
	var spot: Vector3 = flow.HOME_SET + Vector3(6.0, 0.0, 8.0)          # 床のある、何も無い所
	var cartons: Array = game.props.values().filter(func(p: Node) -> bool: return p.kind == "carton" and not p.absent)
	check(cartons.size() >= 2, "（準備）段ボール箱が2つ以上ある（%d）" % cartons.size())
	for c: Node in cartons:
		put(c, spot + Vector3(24.0 + float(cartons.find(c)) * 2.0, 0.3, 0.0))
	var h0: float = float(cartons[0].half.y)
	var boxes := func() -> void:
		put(cartons[0], spot + Vector3(-0.3, h0 + 0.02, 0.0))
		put(cartons[1], spot + Vector3(0.3, h0 + 0.02, 0.0))
	var no_boxes := func() -> void:
		put(cartons[0], spot + Vector3(24.0, 0.3, 0.0))
		put(cartons[1], spot + Vector3(26.0, 0.3, 0.0))

	# ---- 演者の腕が上がると、のびずに済む高さが上がる（準備中） ----
	check(is_equal_approx(f.ko_speed(id), f.KO_SPEED), "腕が1のうちは、のびる速さは元のまま（%.1f）" % f.ko_speed(id))
	await fall(me, spot + Vector3(0.0, 3.6, 0.0))
	check(me.down > 0.0, "3.6m から硬い床に落ちると、のびる")
	await recover(me, f)
	game.crew_skills.profiles[id] = {"actor": 180, "camera": 0, "backstage": 0}
	check(int(game.crew_skills.level(id, "actor")) == 3 and f.ko_speed(id) > f.speed_from(3.6), "（準備）演者の腕を3にする（のびる速さ %.1f）" % f.ko_speed(id))
	await fall(me, spot + Vector3(0.0, 3.6, 0.0))
	check(me.down <= 0.0 and f.downs.is_empty(), "演者の腕が3なら、3.6m から落ちても、のびない（受け身）")
	check((f.shots as Array).is_empty(), "準備中のスタントは、数えない")
	game.crew_skills.profiles[id] = {"actor": 0, "camera": 0, "backstage": 0}

	# ---- 本番：役に入って、カメラの前で飛び降りる ----
	roles.h_cast_actor("player", id, 0)
	await frames(4)
	check(game.actors[0].stand_in == me, "（準備）役者 A に入る")
	var film: Node3D = game.film
	film.restore([spot + Vector3(0.0, 2.6, 9.0), Quaternion.IDENTITY, true])       # 床から 6m くらいまでが映る
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	await frames(10)
	game._begin_take()
	await frames(10)
	check(game.state == game.S.TAKE and (f.shots as Array).is_empty(), "（準備）本番が始まった")
	# 1) 箱2つの上へ、5m から。箱も映っている
	boxes.call()
	await frames(40)
	await fall(me, spot + Vector3(0.0, 5.0 + h0 * 2.0, 0.0))
	var s1: Dictionary = f.shots[-1] if not (f.shots as Array).is_empty() else {}
	check(not s1.is_empty() and bool(s1.get("ok")) and bool(s1.get("seen")) and not bool(s1.get("hidden")) and str(s1.get("kind")) == "leap",
		"箱の上へ 5m から飛び降りる：決まった・映った・箱も映った（%s）" % str(s1))
	# 2) カメラを上げて、着地と箱を画面の外に。7m から
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	film.restore([spot + Vector3(0.0, 6.2, 9.0), Quaternion.IDENTITY, true])       # 床から 2m より上だけが映る
	boxes.call()
	await frames(40)
	await fall(me, spot + Vector3(0.0, 7.0 + h0 * 2.0, 0.0))
	var s2: Dictionary = f.shots[-1]
	check((f.shots as Array).size() == 2 and bool(s2.ok) and bool(s2.seen) and bool(s2.hidden), "着地を画面の外にして 7m から：決まった・映った・箱は映らなかった（%s）" % str(s2))
	# 3) 爆風で飛ばされた直後なら、「吹っ飛び」に数える
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	boxes.call()
	await frames(40)
	me.knocked = 4.0
	await fall(me, spot + Vector3(0.0, 5.0 + h0 * 2.0, 0.0))
	var s3: Dictionary = f.shots[-1]
	check((f.shots as Array).size() == 3 and str(s3.kind) == "blast" and bool(s3.ok) and bool(s3.seen), "爆風で飛ばされた直後の着地は、「吹っ飛び」（%s）" % str(s3))
	# 4) カメラが別の方を向いていると、数えない
	me.knocked = 0.0
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	film.restore([spot + Vector3(0.0, 2.6, 9.0), Quaternion(Vector3.UP, PI), true])
	boxes.call()
	await frames(40)
	await fall(me, spot + Vector3(0.0, 5.0 + h0 * 2.0, 0.0))
	var s4: Dictionary = f.shots[-1]
	check((f.shots as Array).size() == 4 and bool(s4.ok) and not bool(s4.seen) and str(s4.kind) == "leap", "カメラが別の方を向いていると、映っていない（%s）" % str(s4))
	# 5) 箱なしで 5m：のびる。その姿が映る
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	film.restore([spot + Vector3(0.0, 2.6, 9.0), Quaternion.IDENTITY, true])
	no_boxes.call()
	await frames(20)
	await fall(me, spot + Vector3(0.0, 5.0, 0.0))
	await frames(20)
	var s5: Dictionary = f.shots[-1]
	check((f.shots as Array).size() == 5 and not bool(s5.ok) and bool(s5.ko_seen) and me.down > 0.0, "箱なしで 5m：のびて、その姿が映った（%s）" % str(s5))
	check((f.filmed() as Array).size() == 2, "決まって映ったスタントは、種類ごとに1つ（飛び降り・吹っ飛び）")
	cards.cards = [{"id": "stunt", "need": "", "coins": 200, "ref": 0, "shown": true}]
	await recover(me, f)
	# ---- カット：ギャラの上乗せ ----
	game._cut()
	await frames(5)
	var index: int = game.takes.size() - 1
	game.takes[index]["passed"] = [true, false, false, false]
	var lines: Array = f.hook_fee_lines(index)
	var total := 0
	for l: Array in lines:
		total += int(l[1])
	var want: int = int(f.coins_for(f.speed_from(7.0))) + int(f.coins_for(f.speed_from(5.0))) + int(f.HIDDEN_COINS) + int(f.KO_SEEN_COINS)
	check(lines.size() == 4 and absi(total - want) <= 20, "上乗せ：飛び降り＋吹っ飛び＋箱が映らなかった−のびた姿（%d。見込み %d）%s" % [total, want, str(lines)])
	check(int(f.coins_for(f.KO_SPEED)) == 120 and int(f.coins_for(15.0)) == 230 and int(f.coins_for(40.0)) == 300, "上乗せの額：しきい値で 120・15 m/秒で 230・上限 300")
	check(cards.met(0, game.takes[index]), "札「どこかで1回、体を張って」は、守れている")
	var cues: Array = f.hook_premiere_cues(index)
	check(cues.size() == 3 and str(cues[0][2]) == "wow" and str(cues[2][2]) == "sad", "試写会で、依頼主が反応する（決まった2回と、のびた姿）%s" % str(cues.map(func(c: Array) -> String: return str(c[2]))))
	game.takes[index]["passed"] = [false, false, false, false]
	check((f.hook_fee_lines(index) as Array).is_empty(), "1場面も撮れていなければ、上乗せは無い")

	# ---- 役に入っていない人のスタントは、数えない ----
	game.h_retake()
	await frames(20)
	if game.state != game.S.PREP:
		game._set_state(game.S.PREP)
		await frames(5)
	roles.h_cast_actor("player", id, -1)
	await frames(4)
	check(game.actors[0].stand_in == null, "（準備）役から抜ける")
	film.restore([spot + Vector3(0.0, 2.6, 9.0), Quaternion.IDENTITY, true])
	me.global_position = spot + Vector3(-6.0, 0.1, 0.0)
	await frames(5)
	game._begin_take()
	await frames(10)
	check((f.shots as Array).is_empty(), "本番を始めると、数え直す")
	boxes.call()
	await frames(40)
	await fall(me, spot + Vector3(0.0, 5.0 + h0 * 2.0, 0.0))
	check((f.shots as Array).is_empty() and me.down <= 0.0, "役に入っていない人が飛び降りても、スタントに数えない")
	check(not cards.met(0, {}), "札も、守れていない")

	# ---- 雇った役者も、のびる ----
	no_boxes.call()
	var b: CharacterBody3D = game.actors[1]
	b.set_grade("pro")
	b.set_state(b.St.IDLE)
	b.global_position = spot + Vector3(1.5, 0.1, 0.0)
	b.velocity = Vector3.ZERO
	await frames(20)
	check(is_equal_approx(f.ko_speed(-2), f.KO_SPEED + f.PRO_KO), "ベテランは、受け身がうまい（のびる速さ %.1f）" % f.ko_speed(-2))
	b.knock(Vector3(0.0, 10.4, 0.0))
	await frames(100)
	check(not b.is_flat() and not f.downs.has(-2), "ベテランは、少し高く飛ばされても、のびない")
	b.set_state(b.St.IDLE)
	await frames(5)
	var count: int = (f.shots as Array).size()
	b.knock(Vector3(0.0, 14.0, 0.0))
	var flat := false
	for i in 200:
		await physics_frame
		flat = flat or (b.is_flat() and f.downs.has(-2))
		if flat:
			break
	check(flat, "雇った役者も、高く飛ばされて硬い床に落ちると、のびる")
	await frames(20)
	var stars: Node3D = f.downs[-2].stars if f.downs.has(-2) else null
	check(stars != null and stars.get_child_count() == 3 and b.vis.scale.y < 0.3, "ぺちゃんこになって、頭の上を星が回る（高さ %.2f 倍）" % b.vis.scale.y)
	var sb: Dictionary = f.shots[-1] if (f.shots as Array).size() > count else {}
	check(not sb.is_empty() and int(sb.who) == -2 and not bool(sb.ok) and str(sb.kind) == "blast" and bool(sb.ko_seen), "雇った役者のスタントも、控える（%s）" % str(sb))
	await frames(int(f.DOWN_MAX * 60.0) + 60)
	check(not b.is_flat() and not f.downs.has(-2) and b.vis.scale.y > 0.9, "数秒で、元に戻る")
	# 箱があれば、のびない
	boxes.call()
	await frames(40)
	b.set_state(b.St.IDLE)
	b.velocity = Vector3.ZERO
	b.global_position = spot + Vector3(0.0, 7.0 + h0 * 2.0, 0.0)
	var landed := false
	for i in 300:
		await physics_frame
		landed = landed or (i > 5 and b.is_on_floor())
		if landed:
			break
	await frames(10)
	var sc: Dictionary = f.shots[-1]
	check(landed and not b.is_flat() and not f.downs.has(-2) and int(sc.who) == -2 and bool(sc.ok) and str(sc.kind) == "leap", "箱の上に落ちれば、雇った役者も、のびない（%s）" % str(sc))
	game._cut()
	await frames(5)

	print("SHOT_TEST_FAIL" if failed else "SHOT_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)
