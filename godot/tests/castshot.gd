extends SceneTree
# 見立て（配役）と等身大パネルの画面を撮る：打ち合わせの絵コンテ・物の属性と役・配役表・ペイント・テイク確認・精算。
#   godot --path godot --script res://tests/castshot.gd      （画面つきで動かす。出力は tests/shots/cast）
var game: Node
var flow: Node
var me: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String, film: bool = false) -> void:
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/cast/%s.png" % tag)
	if film:
		game.film.view.get_texture().get_image().save_png("res://tests/shots/cast/%s_film.png" % tag)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			return game.props[pid]
	return null


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = true) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = fixed
	prop.restore(state)


# 物の正面（dir の逆から）に立って、照準を合わせる。背中ごしのカメラは右肩の上にある
func aim_at(prop: Node3D, dir: Vector3 = Vector3(0, 0, -1), dist: float = 2.6) -> bool:
	var right := dir.cross(Vector3.UP)
	me.global_position = prop.center_global() - dir * dist - right * 0.9
	me.global_position.y = 0.1
	me.aim_yaw = atan2(-dir.x, -dir.z)
	for step in 14:
		me.aim_pitch = -0.15 - 0.05 * step
		await frames(6)
		if me.target == prop:
			return true
	return false


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(60)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/cast"))
	flow = game.production
	me = game.local_player()
	var cards: Node = game.cue_cards
	var kaiju := 3

	# 1〜2：打ち合わせ（絵コンテ）。2日目なら全部の依頼が出る
	flow.day = 2
	game.production_sync.rpc(flow.snapshot())
	game.open_menu("board")
	game.open_brief(kaiju)
	for i in 240:
		await process_frame
	await snap("1_brief_kaiju")
	game.open_brief(0)
	for i in 240:
		await process_frame
	await snap("2_brief_castle")
	game.close_menu()
	game.h_accept_job(kaiju)
	await frames(30)

	# 3：廃材を見ると、属性と「Y 役を決める」が出る
	var toilet: Node = of_kind("scrap_toilet")
	var poop: Node = of_kind("scrap_poop")
	var ok := await aim_at(toilet, Vector3(-1, 0, 0) if toilet.global_basis.z.x > 0.5 else Vector3(1, 0, 0))
	print("CASTSHOT aim toilet=", ok)
	await snap("3_yard_attrs")
	game.h_cast(toilet.pid, "monster")
	await frames(20)
	await snap("3b_yard_cast")
	me.global_position = poop.global_position + Vector3(1.5, 0.1, 0)
	await frames(5)
	game.h_cast(poop.pid, "boom")
	await frames(10)

	# 4：機材レンタルの画面（配役表とコンボの見込み）
	game.h_open_order()
	await snap("4_order_sheet")
	game.h_order_confirm()
	await frames(10)

	# 5：等身大パネルに描く
	var panel: Node = cards.panel
	ok = await aim_at(panel, -panel.global_basis.z, 2.3)
	print("CASTSHOT aim panel=", ok)
	await snap("5_panel_blank")
	cards.editor.open_board(panel)
	await frames(4)
	var col := func(name: String) -> Color:
		for c: Array in cards.PANEL_COLORS:
			if c[0] == name:
				return c[1]
		return Color.BLACK
	var line := func(pts: Array, paint: String, radius: float) -> void:
		cards.h_draw(panel.pid, PackedVector2Array(pts), col.call(paint), radius)
	# 子どもの落書きふうの怪獣：水色の空・緑の体・目・口・とげ
	cards.h_fill(panel.pid, col.call("水色"))
	line.call([Vector2(256, 520), Vector2(256, 1000)], "緑", 48.0)
	line.call([Vector2(170, 620), Vector2(170, 1040)], "緑", 48.0)
	line.call([Vector2(342, 620), Vector2(342, 1040)], "緑", 48.0)
	line.call([Vector2(256, 400), Vector2(256, 470)], "緑", 48.0)
	line.call([Vector2(200, 360), Vector2(312, 360)], "緑", 48.0)
	line.call([Vector2(96, 700), Vector2(40, 610)], "緑", 22.0)
	line.call([Vector2(416, 700), Vector2(472, 610)], "緑", 22.0)
	line.call([Vector2(140, 1100), Vector2(140, 1160)], "緑", 40.0)
	line.call([Vector2(372, 1100), Vector2(372, 1160)], "緑", 40.0)
	for x: int in [200, 256, 312]:
		line.call([Vector2(x - 26, 290), Vector2(x, 230), Vector2(x + 26, 290)], "黄", 10.0)
	line.call([Vector2(206, 352), Vector2(206, 353)], "白", 30.0)
	line.call([Vector2(306, 352), Vector2(306, 353)], "白", 30.0)
	line.call([Vector2(212, 356), Vector2(212, 357)], "黒", 12.0)
	line.call([Vector2(300, 356), Vector2(300, 357)], "黒", 12.0)
	line.call([Vector2(196, 450), Vector2(256, 478), Vector2(316, 450)], "赤", 10.0)
	for x: int in [216, 256, 296]:
		line.call([Vector2(x, 462), Vector2(x, 478)], "白", 7.0)
	line.call([Vector2(60, 1180), Vector2(450, 1180)], "茶", 22.0)
	await frames(4)
	await snap("6_panel_paint")
	cards.editor.close()
	await frames(4)
	game.h_cast(panel.pid, "city")
	await frames(10)
	await snap("7_panel_cast")

	# 8：台本（配役と、見立てに合わせたせりふ）
	var book: Node = flow.script_prop
	me.global_position = book.global_position + Vector3(0.9, 0.1, 0.6)
	await frames(6)
	game.h_grab(book.pid)
	await frames(10)
	game.script_open = true
	await snap("8_script")
	game.script_open = false
	game.host_release(book)
	await frames(4)

	# 9：積み込み確認（配役表）
	var cartons: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == "carton" and not game.props[pid].absent:
			cartons.append(game.props[pid])
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(4)
	for prop: Node in [toilet, poop, cartons[0], cartons[1]]:
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(20)
	game.open_menu("packing")
	await snap("9_packing")
	game.close_menu()
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	print("CASTSHOT phase=", flow.phase)

	# 10：現場。トイレ怪獣・段ボールとパネルの街・うんこが技
	place(game.film, Vector3(0, 0, 6.0))
	place(toilet, Vector3(-0.8, 0, 3.9), 0.25)
	place(cartons[0], Vector3(-1.6, 0, -1.6))
	place(cartons[1], Vector3(-0.2, 0, -2.0), 0.4)
	place(panel, Vector3(3.2, 0, -1.9), -0.25)
	place(poop, Vector3(5.2, 0.1, 3.4), 0.0, false)
	place(game.spots[0], Vector3(-2.6, 0, 3.4), PI)
	place(game.spots[1], Vector3(3.4, 0, 3.4), PI)
	game.actors[0].mark.restore([Vector3(0.7, 0.05, 0.0), Quaternion.IDENTITY, false])
	game.actors[1].mark.restore([Vector3(1.9, 0.05, 0.4), Quaternion.IDENTITY, false])
	await frames(20)
	game._aim_camera(Vector3(0.6, 0.75, 0.0), 56.0)
	game._aim_spot(game.spots[0], game.actors[0].global_position + Vector3(0, 1.2, 0))
	game._aim_spot(game.spots[1], game.actors[1].global_position + Vector3(0, 1.2, 0))
	game.h_standby()
	me.global_position = Vector3(-4.6, 0.1, 7.6)
	me.aim_yaw = -0.75
	me.aim_pitch = -0.12
	await frames(40)
	print("CASTSHOT hints=", game.live["hints"])
	await snap("10_set", true)
	game.h_take()
	await frames(200)
	game.h_cue(1)
	await frames(200)
	game.h_cue(2)
	await snap("11_attack", true)
	await frames(120)
	game.h_cue(3)
	await frames(60)
	me.global_position = Vector3(-2.6, 0.1, 5.4)
	await frames(10)
	game.h_prop_action(toilet.pid)
	await frames(460)
	print("CASTSHOT state=", game.state, " passed=", game.takes[0]["passed"] if not game.takes.is_empty() else [])
	await snap("12_review")
	if not game.takes.is_empty():
		game.h_deliver(0)
		for i in 60:
			await process_frame
		await snap("13_settle")
	print("CASTSHOT_OK")
	quit()
