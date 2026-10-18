extends SceneTree
# 張りぼての大岩（features/boulder.gd）と、「大岩に追われる」場面の採点（production_beats.gd の chase）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/boulder_test.gd
# 借りなければ無い・借りると軽トラの横に届く・押すと転がる（だんだん弱まる）。
# 転がる大岩・予告編の3カット目：逃げる二人の前を転がっても撮れない。後ろから迫ると撮れる。
var game: Node
var flow: Node
var beats: Node
var S: Dictionary
var failed := false


func _initialize() -> void:
	create_timer(260).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("BOULDER_CHECK ", label, " ", "OK" if ok else "FAIL")
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


func light(at: Vector3) -> void:
	var film: Node3D = game.film
	for i in 2:
		place(game.spots[i], film.global_position + Vector3(-1.3 + 2.6 * float(i), 0.0, 0.4), PI)
	await frames(10)
	for i in 2:
		game._aim_spot(game.spots[i], at + Vector3(0, 1.3, 0))
		game.spots[i].level = 3


# 画面ありで BOULDER_SHOTS=1 のときだけ、撮影カメラの近くから撮る（tests/shots/boulder/）
func shot(name: String, only := -1) -> void:
	if OS.get_environment("BOULDER_SHOTS") == "" or DisplayServer.get_name() == "headless":
		return
	var film: Node3D = game.film
	var cam := Camera3D.new()
	cam.fov = 55
	root.add_child(cam)
	var mid: Vector3 = (game.actors[0].global_position + game.actors[1].global_position) * 0.5
	if only >= 0:
		mid = game.actors[only].global_position
	cam.global_position = mid + (film.global_position - mid).normalized() * 3.2 + Vector3(0, 1.5, 0)
	cam.look_at(mid + Vector3(0, 0.5, 0))
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/boulder/"))
	root.get_texture().get_image().save_png("res://tests/shots/boulder/%s.png" % name)
	cam.queue_free()


func until_holding() -> void:
	for i in 300:
		if beats.holding:
			return
		await physics_frame


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
	var me: Node3D = game.local_player()
	var rock: RigidBody3D = game.hooks.feature("boulder").rock
	check(rock != null and rock.absent, "張りぼての大岩は、借りなければ無い")
	var job := -1
	for i in flow.JOBS.size():
		if str(flow.JOBS[i]["title"]) == "転がる大岩・予告編":
			job = i
	check(job >= 0 and str((beats.Scripts.beats(job) as Array)[2]["rule"]) == "chase", "転がる大岩・予告編の3カット目は、大岩に追われる場面")
	flow.day = 2
	game.h_accept_job(job)
	await frames(20)
	# ---- 借りる：軽トラの横に届く ----
	game.h_open_order()
	game.h_order_set("boulder", 1)
	game.h_order_confirm()
	await frames(10)
	check(not rock.absent and rock.global_position.distance_to(game.hooks.feature("boulder").HOME_AT) < 0.6, "借りると、軽トラの横に届く（%s）" % str(rock.global_position))
	# ---- 押すと転がる。だんだん弱まる ----
	await frames(30)
	rock.apply_central_impulse(Vector3(-rock.mass * 3.0, 0, 0))
	await frames(20)
	var spin: float = rock.angular_velocity.length()
	var speed: float = rock.linear_velocity.length()
	check(spin > 2.0 and speed > 1.0, "押すと、回りながら転がる（%.1f m/秒・%.1f rad/秒）" % [speed, spin])
	await frames(240)
	check(rock.linear_velocity.length() < speed * 0.6, "転がりは、だんだん弱まる（%.2f m/秒）" % rock.linear_velocity.length())
	# ---- 現場（倉庫）へ ----
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "現場（倉庫）に着いた")
	var a1: Vector3 = beats.mark(0, 1).global_position
	var a2: Vector3 = beats.mark(0, 2).global_position
	var film: RigidBody3D = game.film
	# カメラは、走り出す所を真ん中に、少し引いて（後ろから迫る大岩も入るように）
	place(film, Vector3(a1.x + 0.4, 0.05, a1.z + 6.5), 0.0)
	await frames(20)
	await light((a1 + a2) * 0.5)
	me.global_position = film.global_position + Vector3(0.8, 0.1, 2.0)
	place(flow.script_prop, me.global_position + Vector3(0.5, 0.0, 0.0))
	place(rock, Vector3(a1.x - 6.0, 0.7, a1.z + 1.5))
	await frames(10)
	# ---- 本番：場面1・2は撮れたことにして、3カット目へ ----
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(5)
	beats._met(0)
	await until_holding()
	game.h_beat(1)
	await frames(10)
	beats._met(1)
	await until_holding()
	game.h_beat(1)
	await frames(3)
	check(beats.scene == 2 and not beats.holding, "3カット目（大岩に追われる）が回り始めた")
	# 二人の前を、同じ向きに転がる：撮れない
	var run_dir := Vector3(a2.x - a1.x, 0, a2.z - a1.z).normalized()
	for i in 120:
		if game.actors[0].beat_walking():
			break
		await physics_frame
	var mid: Vector3 = (game.actors[0].global_position + game.actors[1].global_position) * 0.5
	rock.launch(Vector3(mid.x, 0.7, mid.z) + run_dir * 1.5, run_dir * 3.0, run_dir.cross(Vector3.DOWN) * 4.0)
	await frames(90)
	check(not beats.lit[2], "大岩が二人の前を転がっても、撮れない（理由：%s）" % beats._top_reason(2))
	check(beats._top_reason(2).contains("前"), "撮れない理由は「二人の前にあった」")
	# 撮り直し：止めて、もう一度回す。今度は後ろから迫らせる
	game.h_beat(1)
	await until_holding()
	await frames(120)
	game.h_beat(1)
	for i in 120:
		if game.actors[0].beat_walking():
			break
		await physics_frame
	mid = (game.actors[0].global_position + game.actors[1].global_position) * 0.5
	rock.launch(Vector3(mid.x, 0.7, mid.z) - run_dir * 2.2, run_dir * 3.2, run_dir.cross(Vector3.DOWN) * 4.5)
	for i in 150:
		if beats.lit[2]:
			break
		await physics_frame
	check(beats.lit[2], "後ろから迫らせると、3カット目が撮れる（理由：%s）" % beats._top_reason(2))
	# ---- 4カット目（落ち）：穴に飛び込んで、大岩をよける ----
	await until_holding()
	check(beats.next_scene == 3 and str((beats.Scripts.beats(job) as Array)[3]["rule"]) == "pit", "場転：次は、穴に飛び込む場面")
	check(load("res://scripts/ui/storyboard.gd").texture("trap", 3) != null, "4枚目の絵コンテ（穴から顔を出す二人）が描ける")
	# 場転：バスタブを穴に見立てて、逃げる先（③）に置き、二人の③の印をその中へ移す
	# BOULDER_HOLE=1 なら、バスタブの代わりに段ボール板を床に置いて、黒い穴を描いた板にする（絵に描いた穴・★1）
	var painted := OS.get_environment("BOULDER_HOLE") != ""
	var hole_kind := "cardboard" if painted else "scrap_tub"
	var tub: RigidBody3D = null
	for p: Node in game.props.values():
		if p.kind == hole_kind and not p.absent and not p.fixed:
			tub = p
			break
	var end_a: Vector3 = beats.mark(0, 2).global_position
	var end_b: Vector3 = beats.mark(1, 2).global_position
	var spot: Vector3 = (end_a + end_b) * 0.5
	if painted:
		tub.restore([Vector3(spot.x, 0.1, spot.z), Quaternion(Vector3.RIGHT, -PI * 0.5), false])     # 寝かせて、床に置く
	else:
		place(tub, Vector3(spot.x, 0.4, spot.z), 0.0)
	await frames(40)
	check(flow.Cast.fit("carton", "pit") == 1 and flow.Cast.fit("cardboard", "pit") == 0, "段ボール箱はまあまあの穴（★2）、段ボール板は描いた穴（★1）")
	check(flow.cast_set(tub.pid, "pit") and flow.role_of(tub) == "pit" and flow.cast_fit(tub, "pit") == (0 if painted else 2), "%s は、穴の役になる" % tub.label)
	await frames(3)
	check(game._cast_dress.has(tub.pid) and not (game._cast_dress[tub.pid] as Node).find_children("*", "Decal", true, false).is_empty(), "穴の役の物には、黒い穴が描かれる")
	var bottom: Vector3 = tub.center_global() + Vector3(0, tub.half.y + 0.2, 0)       # ふちの上から落とすと、中の底に乗る
	place(beats.mark(0, 2), bottom + Vector3(-0.3, 0, 0))
	place(beats.mark(1, 2), bottom + Vector3(0.3, 0, 0))
	await frames(40)
	place(rock, Vector3(a1.x - 6.0, 0.7, a1.z + 1.5))
	await frames(10)
	game.h_beat(1)
	for i in 400:
		if game.actors[0].beat_arrived() and game.actors[1].beat_arrived():
			break
		await physics_frame
	await frames(40)
	var dived: bool = game.actors[0].in_pit() == tub and game.actors[1].in_pit() == tub
	check(beats.scene == 3 and dived, "二人は走って、バスタブの中へ飛び込む（%s・%s）" % [str(game.actors[0].global_position), str(tub.global_position)])
	check(game.actors[0].body_pose == "duck" and (game.actors[0].vis.position.y < -0.3 if painted else game.actors[0].vis.position.y > 0.0) and game.actors[0].vis.scale.x < 0.95 and game.actors[0].collision_layer == 0, "バスタブの中の底に立って、身を縮める（大岩に当たらない。%.2f m 上げて、%.2f 倍）" % [game.actors[0].vis.position.y, game.actors[0].vis.scale.x])
	await shot("pit_ducked")
	await frames(30)
	check(not beats.lit[3] and beats._top_reason(3).contains("転がる物"), "まだ大岩が通っていない（理由：%s）" % beats._top_reason(3))
	# ---- 穴の外にいると、大岩にぺちゃんこにされて、しばらくして戻る ----
	var home0: Vector3 = game.actors[0].global_position
	var out_at: Vector3 = home0 + Vector3(0, 0, 3.0)
	game.actors[0].global_position = out_at
	await frames(5)
	rock.launch(out_at + Vector3(-4.0, 0.8, 0.0), Vector3(4.0, 0, 0), Vector3(0, 0, -5.0))
	var flattened := false
	for i in 120:
		if game.actors[0].is_flat():
			flattened = true
			break
		await physics_frame
	await frames(10)
	check(flattened and game.actors[0].vis.scale.y < 0.4 and game.actors[0].collision_layer == 0, "穴の外で大岩に追いつかれると、ぺちゃんこになる（大岩は上を通る）")
	check((beats.why[3] as Dictionary).keys().any(func(k: String) -> bool: return k.contains("ぺちゃんこ")), "撮れない理由に「ぺちゃんこにされた」が入る")
	await frames(30)
	await shot("flat", 0)
	place(rock, Vector3(a1.x - 6.0, 0.7, a1.z + 1.5))      # 大岩は片づける（跳ね返って、またつぶさないように）
	for i in 200:
		if not game.actors[0].is_flat():
			break
		await physics_frame
	await frames(30)
	check(not game.actors[0].is_flat() and game.actors[0].vis.scale.y > 0.45, "しばらくすると、ぽんと元に戻る")
	game.actors[0].global_position = home0          # 穴へ戻す
	await frames(60)
	# 大岩を、穴のすぐ横に転がす
	var by: Vector3 = run_dir.cross(Vector3.UP).normalized()
	var mid4: Vector3 = (game.actors[0].global_position + game.actors[1].global_position) * 0.5
	rock.launch(Vector3(mid4.x, 0.7, mid4.z) - run_dir * 3.5 + by * 1.4, run_dir * 3.4, run_dir.cross(Vector3.DOWN) * 4.5)
	for i in 180:
		if beats.lit[3]:
			break
		if i == 40:
			await shot("pit_rock")
		await physics_frame
	check(beats.lit[3], "穴の二人のそばを大岩が転がっていくと、4カット目が撮れる（理由：%s）" % beats._top_reason(3))
	check(not game.actors[0].is_flat() and not game.actors[1].is_flat(), "穴の中の二人は、つぶれない")
	print("BOULDER_TEST_FAIL" if failed else "BOULDER_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
