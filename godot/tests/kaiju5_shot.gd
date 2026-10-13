extends SceneTree
# 5場面の台本「怪獣、段ボールの街に現る・完全版」の画面を撮る。出力は tests/shots/kaiju5/
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/kaiju5_shot.gd
#   画面つきで動かす（窓は画面の外に出し、マウスも捕まえない）
# 撮る物：依頼ボードと打ち合わせ・参考スライド・6つの印・台本の冊子・立ち止まった役者・
#         5場面それぞれの撮影カメラの絵（怪獣を隠してある最初の絵・爆発の直後を含む）・
#         モニターの枠のランプと目盛り・カメラのリール（始め・残りわずか）・テイクのあとの理由の表示。
# 置き方は、自動確認（kaiju5_test.gd）と同じ。
const T := preload("res://tests/kaiju5_test.gd")
const OUT := "res://tests/shots/kaiju5/"
var game: Node
var flow: Node
var beats: Node
var kit: Node
var net: Node
var S: Dictionary
var me: Node
var mate: Node
var film: Node
var cam_b: Node
var monster: Node
var bomb: Node
var book: Node
var board: Node
var cartons: Array = []
var extra: Camera3D
var job := -1


func _initialize() -> void:
	root.unfocusable = true
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(tag: String, wait: int = 10) -> void:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	print("KAIJU5_SHOT ", tag)


# 採用中の撮影カメラの絵
func film_shot(tag: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	(game.program_camera().view as SubViewport).get_texture().get_image().save_png(OUT + tag + ".png")
	print("KAIJU5_SHOT ", tag)


# 決めた場所から、決めた所を撮る（カメラを操作している間も、外から撮れるように、自分の視点の切り替えを止めておく）
func look_from(from: Vector3, at: Vector3, fov: float = 46.0) -> void:
	if extra == null:
		extra = Camera3D.new()
		game.add_child(extra)
	me.set_process(false)
	extra.fov = fov
	extra.global_position = from
	extra.look_at(at)
	extra.make_current()


func look_own() -> void:
	me.set_process(true)
	me.cam.make_current()


func face(at: Vector3) -> void:
	var from: Vector3 = me.global_position + Vector3(0, 2.35, 0)
	var d: Vector3 = at - from
	me.aim_yaw = atan2(-d.x, -d.z)
	me.aim_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(6)


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = true) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = fixed
	prop.restore(state)


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


func as_mate(action: Callable) -> void:
	net.acting_as = mate.peer_id
	action.call()
	net.acting_as = 0


func aim(point: Vector3, fov: float) -> void:
	var d: Vector3 = film.global_basis.inverse() * (point - (film.global_position + Vector3(0, film.HEAD_Y, 0)))
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	game.h_aim(film.pid, wrapf(yaw - film.cam_yaw, -PI, PI), pitch - film.cam_pitch, (film.fov - fov) / 3.0)


func point_camera(camera: Node, point: Vector3, fov: float) -> void:
	var d: Vector3 = camera.global_basis.inverse() * (point - (camera.global_position + Vector3(0, camera.HEAD_Y, 0)))
	camera.cam_yaw = atan2(-d.x, -d.z)
	camera.cam_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	camera.fov = fov


func lay_out() -> void:
	place(film, T.CAM_AT)
	place(cam_b, T.CAM_B_AT)
	place(monster, T.MONSTER_AT, 0.0, false)
	for i in 4:
		place(cartons[i], T.CITY_AT[i], 0.2 * i, false)
	for i in 2:
		place(game.spots[i], T.SPOT_AT[i], PI)


func start_take() -> void:
	game.h_operate(film.pid, true)
	await frames(3)
	as_mate(func() -> void: game.h_grab(game.clapper.pid))
	await frames(3)
	as_mate(func() -> void: game.h_use())
	await frames(200)
	as_mate(func() -> void: game.h_release())
	await frames(2)


func blast(amount: float) -> void:
	bomb.powder = amount
	mate.global_position = bomb.global_position + Vector3(-1.4, 0.1, 0.4)
	await frames(3)
	as_mate(func() -> void: kit.h_light_bomb())
	await frames(2)
	mate.global_position = T.OFFSTAGE


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(40)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	net = root.get_node("Net")
	flow = game.production
	beats = game.beats
	kit = game.bomb_kit
	S = game.S
	me = game.local_player()
	film = game.film
	cam_b = game.camera_switcher.cameras[1]
	bomb = game.fx
	for i in flow.JOBS.size():
		if not (beats.Scripts.beats(i) as Array).is_empty():
			job = i
	await office_screens()
	await go_to_set()
	await set_screens()
	await good_take()
	await bad_take()
	print("KAIJU5_SHOT_OK")
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	for i in 8:
		await process_frame
	quit()


# ---- 事務所：依頼ボード・打ち合わせ・参考スライド ----

func office_screens() -> void:
	flow.day = 2
	me.global_position = flow.Office.CONTRACT_POINT + Vector3(0, 0.1, 1.5)
	await frames(6)
	game.open_menu("board")
	await snap("01_board_day2", 20)
	game.open_brief(job)
	await snap("02_briefing", 330)
	game.close_menu()
	await frames(4)
	game.h_accept_job(job)
	await frames(20)
	me.global_position = Vector3(70.95, 0.1, 2.2)
	await frames(4)
	look_own()
	game.h_peep(true)
	await frames(12)
	var view: Node = game.director.view
	await snap("03_slide_1_roles")
	for i in range(1, view.count()):
		view.step(1)
		await snap("03_slide_%d" % (i + 1), 16)
	game.h_peep(false)
	await frames(10)


func go_to_set() -> void:
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_set("refill", 1)
	game.h_order_confirm()
	await frames(8)
	monster = of_kind("tomato_monster")[0]
	cartons = of_kind("carton")
	book = flow.script_prop
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	for prop: Node in [monster, bomb, cartons[0], cartons[1], book]:
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(12)
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	await frames(30)
	game._roster.append([2, 2])
	game._apply_roster()
	mate = game.players[2]
	mate.global_position = T.OFFSTAGE
	game.crew_skills.queue_free()
	game.crew_skills = null
	cartons = of_kind("carton")
	board = of_kind("plywood")[0]
	# 6つの印：着いたときの並び（まだ誰も動かしていない）
	look_from(Vector3(-1.0, 5.2, 5.4), Vector3(-1.0, 0.0, -0.9), 50.0)
	await snap("04_marks_as_delivered", 20)
	lay_out()
	place(bomb, T.BOMB_AT)
	place(board, T.BOARD_AWAY)
	place(game.camera_switcher.monitor, T.MONITOR_AT, PI)
	for aid in 2:
		for step in 3:
			(beats.mark(aid, step) as Node).restore([T.MARKS[aid][step], Quaternion.IDENTITY, false])
	place(book, T.BOOK_AT, 0.0, false)
	me.global_position = T.ME_AT
	await frames(40)
	for i in 2:
		game._aim_spot(game.spots[i], T.SPOT_AIM[i])
		game.spots[i].level = 3
	point_camera(cam_b, T.AIM_B, T.FOV_B)
	bomb.powder = T.POWDER_GOOD
	await frames(10)


# ---- 現場の準備中：印・台本の冊子・通し稽古 ----

func set_screens() -> void:
	# 置き直した6つの印（上から）と、近くから
	look_from(Vector3(2.6, 8.5, 5.0), Vector3(2.6, 0.0, 0.3), 52.0)
	await snap("04_marks_overview", 20)
	look_from(Vector3(2.2, 1.7, 3.0), Vector3(1.4, 0.0, 0.1), 50.0)
	await snap("04_marks_close", 10)
	# 台本の冊子：持って開く（場面ごとの小さな絵コンテ）
	look_own()
	await face(Vector3(0.6, 1.0, 0.0))
	game.h_grab(book.pid)
	await frames(6)
	game.script_open = true
	await snap("05_script_page", 20)
	# 通し稽古：場面を進める。台本のページは、いまの場面を濃く見せる
	game.h_beat(1)
	await frames(200)
	game.h_beat(1)
	await frames(60)
	await snap("05_script_page_scene2", 10)
	game.script_open = false
	game.h_release()
	await frames(4)
	place(book, T.BOOK_AT, 0.0, false)
	# 通り道をふさぐ：立ち止まって困った顔（もう一人は、絵のために離れた印へ行かせる）
	place(board, T.BLOCK_AT, PI * 0.5)
	(beats.mark(1, 2) as Node).restore([Vector3(3.2, 0.05, 1.8), Quaternion.IDENTITY, false])
	await frames(20)
	game.h_beat(1)
	await frames(150)
	look_from(Vector3(0.1, 1.25, 2.6), Vector3(0.75, 1.05, 0.97), 36.0)
	await snap("06_actor_stuck", 10)
	look_from(Vector3(2.6, 2.2, 2.8), Vector3(0.6, 0.8, 0.6), 44.0)
	await snap("06_actor_stuck_wide", 4)
	place(board, T.BOARD_AWAY)
	(beats.mark(1, 2) as Node).restore([T.MARKS[1][2], Quaternion.IDENTITY, false])
	game.h_standby()
	await frames(20)
	# 台本をそばに置いた監督の画面（場面の一覧が出る。準備中の「答え」は出ない）
	look_own()
	await face(Vector3(0.6, 1.0, 0.0))
	await snap("07_director_prep_hud", 20)


# ---- うまくいったテイク：5場面それぞれの、撮影カメラの絵 ----

func good_take() -> void:
	# 導火線の代わりに、じかに点火する（撮るのは絵なので、点火の手間は省く）
	aim(T.AIM_WALK, T.FOV_WIDE)
	await start_take()
	aim(T.AIM_WALK, T.FOV_WIDE)
	await frames(10)
	# リール（始め）
	look_from(film.global_position + Vector3(0.75, 1.75, 0.55), film.global_position + Vector3(0.0, 1.55, 0.0), 36.0)
	await snap("22_reel_start", 70)
	look_from(film.global_position + Vector3(-1.6, 1.9, 1.5), film.global_position + Vector3(0.0, 1.35, 0.0), 40.0)
	await snap("22_reel_start_wide", 6)
	look_own()
	await snap("24_operator_view", 10)
	# 1：街を歩いてくる（怪獣は、画面の外）
	game.operator_click()
	await frames(70)
	await film_shot("10_film_scene1_monster_hidden")
	await frames(80)
	await snap("24_operator_view_scene1_ok", 4)
	# 2：カメラを振って、怪獣を見せる
	aim(T.AIM_WIDE, T.FOV_WIDE)
	game.operator_click()
	await frames(130)
	await film_shot("11_film_scene2_monster")
	# モニターの枠（ランプ2つ・目盛り）
	look_from(game.camera_switcher.monitor.global_position + Vector3(-0.3, 1.9, -3.4), game.camera_switcher.monitor.global_position + Vector3(0.0, 1.8, 0.0), 46.0)
	await snap("20_monitor_lamps", 8)
	look_from(game.camera_switcher.monitor.global_position + Vector3(0.0, 1.25, -1.5), game.camera_switcher.monitor.global_position + Vector3(0.0, 1.1, 0.0), 40.0)
	await snap("20_monitor_lamps_close", 4)
	look_from(game.camera_switcher.monitor.global_position + Vector3(0.0, 2.3, -1.9), game.camera_switcher.monitor.global_position + Vector3(0.0, 2.55, 0.0), 44.0)
	await snap("20_monitor_ticks_close", 4)
	# 3：怪獣の技
	game.operator_click()
	await frames(60)
	await blast(T.POWDER_GOOD)
	await frames(48 + 14)
	await film_shot("12_film_boom")
	await frames(40)
	await film_shot("12_film_boom_after")
	await frames(140)
	await film_shot("13_film_scene3_city_down")
	# 4：怪獣が倒れる
	game.operator_click()
	await frames(60)
	as_mate(func() -> void: game.h_prop_action(monster.pid))
	await frames(80)
	await film_shot("14_film_scene4_monster_down")
	# 5：寄り
	game.operator_click()
	await frames(120)
	await film_shot("15_film_scene5_wide_not_enough")
	aim(T.AIM_CLOSE, T.FOV_CLOSE)
	await frames(60)
	await film_shot("15_film_scene5_close")
	look_own()
	await snap("21_director_hud_scene5", 6)
	for i in 400:
		if game.state != S.TAKE:
			break
		await physics_frame
	await snap("30_result_good", 110)


# ---- うまくいかなかったテイク：理由の表示・残りわずかのリール ----

func bad_take() -> void:
	game.h_retake()
	await frames(20)
	# 怪獣を板の後ろに隠す置き方（別の解き方）
	place(board, T.BOARD_HIDE)
	aim(T.AIM_WIDE, T.FOV_WIDE)
	await frames(20)
	await film_shot("16_film_monster_behind_board")
	place(board, T.BOARD_AWAY)
	await start_take()
	aim(T.AIM_WIDE, T.FOV_WIDE)
	# 1：怪獣が先に映っている
	game.operator_click()
	await frames(220)
	# 2：黒子が映り込む
	game.operator_click()
	mate.global_position = T.IN_SHOT
	await frames(120)
	await film_shot("17_film_crew_in_shot")
	mate.global_position = T.OFFSTAGE
	await frames(150)
	# 3：火薬が多すぎる
	game.operator_click()
	await frames(80)
	await blast(T.POWDER_MUCH)
	await frames(62)
	await film_shot("18_film_too_much_powder")
	await frames(260)
	# 4：倒す人が映っている（怪獣は、もう吹き飛んでいる）
	game.operator_click()
	await frames(120)
	# 5
	game.operator_click()
	await frames(200)
	# 残りわずか：リールが細くなり、目盛りが赤くなる（時計を進める）
	game.take_t = beats.FILM_SEC - 9.0
	await frames(30)
	look_from(film.global_position + Vector3(0.75, 1.75, 0.55), film.global_position + Vector3(0.0, 1.55, 0.0), 36.0)
	await snap("23_reel_low", 8)
	look_from(game.camera_switcher.monitor.global_position + Vector3(-0.3, 1.9, -3.4), game.camera_switcher.monitor.global_position + Vector3(0.0, 1.8, 0.0), 46.0)
	await snap("23_monitor_low", 4)
	look_own()
	for i in 900:
		if game.state != S.TAKE:
			break
		await physics_frame
	await snap("31_result_reasons", 110)
	for r: Dictionary in game.takes[game.takes.size() - 1]["results"]:
		print("  ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
