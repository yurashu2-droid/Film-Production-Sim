extends SceneTree
# 爆弾の画面を撮る：借りる画面・届いた道具・床を這う導火線・はさみで切る所・粉を注ぐ所・
# 量の多い少ない・火花が進む所・現場での大爆発。
#   godot --path godot --script res://tests/bombshot.gd      （画面つきで動かす。出力は tests/shots/bomb）
var game: Node
var flow: Node
var kit: Node
var bomb: Node
var me: Node
var eye: Camera3D          # 撮るための、自由に置けるカメラ（制作班の目の代わり）


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String, film: bool = false, wait: int = 14) -> void:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/bomb/%s.png" % tag)
	if film:
		game.film.view.get_texture().get_image().save_png("res://tests/shots/bomb/%s_film.png" % tag)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


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


# 自由なカメラで見る
func look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	eye.global_position = from
	eye.look_at(at, Vector3.UP)
	eye.fov = fov
	eye.make_current()


# 制作班（自分）の目で見る
func own_view() -> void:
	me.cam.make_current()


func take(prop: Node) -> void:
	game.h_release()
	await frames(2)
	prop.set_fixed(false)
	game.h_grab(prop.pid)
	await frames(3)


func carried(prop: Node) -> void:
	for i in 240:
		if prop.global_position.distance_to(bomb.global_position) < 2.2 and prop.linear_velocity.length() < 0.3:
			break
		await physics_frame
	await frames(6)


func walk(by: Vector3, steps: int) -> void:
	for i in steps:
		me.global_position += by / float(steps)
		await physics_frame


func hold_over_bomb(sack: Node, offset: Vector3 = Vector3.ZERO) -> void:
	game.h_release()
	await frames(2)
	me.global_position = bomb.global_position + Vector3(1.6, 0.1, 0) + offset
	place(sack, bomb.mouth() + offset + Vector3(sack.SPOUT, 0.42 - sack.center.y, 0), 0.0, false)
	await frames(2)
	game.h_grab(sack.pid)
	await frames(4)


# 自分の目で、その点を狙う（体はその点から dist だけ離れて立つ）。ok(me) が {} でなくなるまで、少しずつ見下ろす
func aim_point(point: Vector3, dir: Vector3, dist: float, ok: Callable) -> bool:
	me.global_position = point - dir * dist
	me.global_position.y = bomb.global_position.y + 0.1
	me.aim_yaw = atan2(-dir.x, -dir.z)
	for step in 40:
		me.aim_pitch = -0.1 - 0.025 * step
		await frames(4)
		if not (ok.call(me) as Dictionary).is_empty():
			return true
	return false


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(60)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/bomb"))
	flow = game.production
	kit = game.bomb_kit
	me = game.local_player()
	bomb = game.fx
	eye = Camera3D.new()
	game.add_child(eye)
	flow.day = 2
	game.production_sync.rpc(flow.snapshot())
	game.h_accept_job(3)
	await frames(20)

	# 1：借りる画面（爆弾・火薬の袋・導火線の束）
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_set("refill", 2)
	await snap("01_order")
	game.h_order_confirm()
	await frames(40)

	# 2：届いた道具（軽トラの横の袋と束）と、会社のはさみ
	var delivery: Vector3 = flow.HOME_TRUCK + kit.DELIVERY
	me.global_position = delivery + Vector3(-6, 0.1, -6)
	look(delivery + Vector3(-1.6, 1.5, -2.6), delivery + Vector3(-0.5, 0.15, -0.2))
	await snap("02_delivered")
	var tools: Vector3 = (kit.scissors.global_position + kit.coil.global_position) * 0.5
	look(tools + Vector3(1.0, 1.0, 1.4), tools, 45.0)
	await snap("02b_scissors_and_rope")

	# 3：つなぐ → 束を持って離れる → 線が垂れて床を這う
	var spot: Vector3 = flow.HOME_TRUCK + Vector3(-7.5, 0.0, -1.5)
	place(bomb, spot + Vector3(0, 0.05, 0))
	place(kit.coil, spot + Vector3(0.9, 0.06, 0.3), 0.0, false)
	me.global_position = spot + Vector3(1.6, 0.1, 0)
	await frames(30)
	look(spot + Vector3(0.9, 0.9, 1.3), spot + Vector3(0, 0.5, 0), 50.0)
	await snap("03_empty_bomb_no_fuse")
	await take(kit.coil)
	kit.h_connect()
	await frames(20)
	look(spot + Vector3(1.4, 1.2, 1.6), spot + Vector3(0.3, 0.4, 0), 50.0)
	await snap("04_connected")
	await walk(Vector3(2.2, 0, 0.3), 55)
	look(spot + Vector3(1.6, 1.5, 3.4), spot + Vector3(1.6, 0.4, 0))
	await snap("05_paying_out", false, 3)
	await walk(Vector3(2.3, 0, 0.3), 55)
	await frames(90)
	game.h_release()
	await frames(240)
	var rest: Node = kit.bomb_cord()
	print("BOMBSHOT rest: asleep=", rest.asleep, " speed=", rest.speed(), " length=", rest.length, " path=", rest.path_length())
	look(spot + Vector3(2.6, 2.4, 4.6), spot + Vector3(2.6, 0.2, 0))
	await snap("06_fuse_on_floor")
	await frames(120)
	await snap("06a_fuse_on_floor_2s_later")
	print("BOMBSHOT rest 2s later: asleep=", rest.asleep, " speed=", rest.speed(), " length=", rest.length)
	look(spot + Vector3(-0.9, 0.55, 1.5), spot + Vector3(2.0, 0.15, 0.2), 55.0)
	await snap("06b_fuse_low_angle")

	# 4：はさみで、線の好きな所を見て切る
	var cord: Node = kit.bomb_cord()
	place(kit.scissors, spot + Vector3(2.4, 0.1, 1.4), 0.0, false)
	await frames(10)
	await take(kit.scissors)
	var cut_at: Vector3 = cord.point_at(2.4)
	own_view()
	var aimed := await aim_point(cut_at, Vector3(0, 0, -1), 1.7, kit.aim_cord)
	print("BOMBSHOT cut aim=", aimed, " ", kit.f_action(me).get("do", ""), " s=", kit.f_action(me).get("s", -1.0))
	await snap("07_scissors_aim")
	var did: bool = kit.handle_f(me)
	await frames(30)
	print("BOMBSHOT cut handled=", did, " cords=", kit.cords.size(), " left on bomb=", cord.length)
	await snap("08_after_cut")
	look(cut_at + Vector3(0.2, 0.9, 1.1), cut_at, 45.0)
	await snap("08b_cut_close")
	game.h_release()
	await frames(10)

	# 5：粉を注ぐ。量は、玉のふくらみ・口の粉・袋のしぼみで見分ける
	var sack: Node = kit.sacks[0]
	var close_from: Vector3 = spot + Vector3(0.75, 1.25, 1.35)
	var close_at: Vector3 = spot + Vector3(0.1, 0.5, 0)
	await hold_over_bomb(sack)
	look(close_from, close_at, 50.0)
	kit.h_pour(true)
	for i in 600:
		if bomb.powder >= 0.12:
			break
		await physics_frame
	await snap("09_pouring_start", false, 2)
	kit.h_pour(false)
	await frames(50)
	print("BOMBSHOT a little: powder=", bomb.powder, " sack=", sack.fill)
	place(sack, spot + Vector3(-0.75, 0.05, 0.25), 0.3, false)
	await frames(40)
	await snap("10_a_little")
	await hold_over_bomb(sack)
	kit.h_pour(true)
	for i in 600:
		if bomb.powder >= 0.5:
			break
		await physics_frame
	await snap("11_pouring_gush", false, 2)
	kit.h_pour(false)
	await frames(50)
	print("BOMBSHOT plenty: powder=", bomb.powder, " sack=", sack.fill)
	place(sack, spot + Vector3(-0.75, 0.05, 0.25), 0.3, false)
	await frames(40)
	await snap("12_plenty")
	await hold_over_bomb(sack)
	kit.h_pour(true)
	for i in 900:
		if sack.fill <= 0.0:
			break
		await physics_frame
	kit.h_pour(false)
	await frames(50)
	print("BOMBSHOT whole sack: powder=", bomb.powder, " sack=", sack.fill)
	place(sack, spot + Vector3(-0.75, 0.05, 0.25), 0.3, false)
	await frames(40)
	await snap("13_whole_sack")
	# 口を外して注ぐと、床にこぼれて残る
	sack = kit.sacks[1]
	await hold_over_bomb(sack, Vector3(0.1, 0, 0.9))
	kit.h_pour(true)
	await frames(100)
	look(spot + Vector3(1.3, 1.3, 2.4), spot + Vector3(0.1, 0.3, 0.5), 50.0)
	await snap("14_spilling", false, 2)
	kit.h_pour(false)
	await frames(50)
	place(sack, spot + Vector3(-0.75, 0.05, 0.9), 0.3, false)
	await frames(30)
	await snap("14b_spilled")

	# 6：線の先を見て点火。火花が、線の上を進む（会社では試し発火）
	own_view()
	var tip: Vector3 = cord.tip()
	aimed = await aim_point(tip, Vector3(0, 0, -1), 1.6, kit.aim_end)
	print("BOMBSHOT tip aim=", aimed, " ", kit.f_action(me).get("do", ""))
	await snap("15_tip_aim")
	did = kit.handle_f(me)
	await frames(45)
	print("BOMBSHOT light handled=", did, " burning=", cord.burning)
	await snap("16_lit", false, 2)
	me.global_position = spot + Vector3(5.0, 0.1, 4.0)
	await frames(60)
	look(spot + Vector3(1.2, 1.3, 2.6), spot + Vector3(0.9, 0.2, 0), 55.0)
	await snap("17_spark_running", false, 2)
	for i in 600:
		if not kit.cords.has(cord.id) or cord.length < 0.45:
			break
		await physics_frame
	look(spot + Vector3(1.2, 1.3, 2.6), spot + Vector3(0.9, 0.2, 0), 55.0)
	await snap("18_spark_near_mouth", false, 1)
	await frames(50)
	look(spot + Vector3(1.2, 1.3, 2.6), spot + Vector3(0.9, 0.2, 0), 55.0)
	await snap("19_rehearsal_pop", false, 1)
	await frames(120)
	look(spot + Vector3(1.2, 1.3, 2.6), spot + Vector3(0.9, 0.2, 0), 55.0)
	await snap("19b_after_pop")
	print("BOMBSHOT after rehearsal: powder=", bomb.powder, " spills=", kit.spills.size(), " cords=", kit.cords.size())

	# 7：現場で、袋1つ全部の大爆発
	var monster: Node = of_kind("tomato_monster")[0]
	var cartons: Array = of_kind("carton")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(4)
	for prop: Node in [monster, cartons[0], cartons[1], cartons[2], bomb]:
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(20)
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	place(game.film, Vector3(0, 0, 6.0))
	place(monster, Vector3(-0.95, 0, 4.55))
	place(cartons[0], Vector3(-1.6, 0, -1.6))
	place(cartons[1], Vector3(-0.2, 0, -2.0), 0.4)
	place(cartons[2], Vector3(3.0, 0, -1.4), -0.3)
	place(bomb, Vector3(3.4, 0, -4.4))
	place(game.spots[0], Vector3(-2.6, 0, 3.4), PI)
	place(game.spots[1], Vector3(3.4, 0, 3.4), PI)
	game.actors[0].mark.restore([Vector3(0.7, 0.05, 0.0), Quaternion.IDENTITY, false])
	game.actors[1].mark.restore([Vector3(1.9, 0.05, 0.4), Quaternion.IDENTITY, false])
	await frames(20)
	game._aim_camera(Vector3(0.6, 0.75, 0.0), 56.0)
	game._aim_spot(game.spots[0], game.actors[0].global_position + Vector3(0, 1.2, 0))
	game._aim_spot(game.spots[1], game.actors[1].global_position + Vector3(0, 1.2, 0))
	game.h_standby()
	# 道具は、現場へ運んだことにする（置き直す）。会社で入れた火薬は、そのまま（袋1つ全部）
	kit.stock = kit.COIL_M
	place(kit.coil, bomb.global_position + Vector3(0.9, 0.06, 0.3), 0.0, false)
	place(kit.scissors, bomb.global_position + Vector3(3.0, 0.1, 1.2), 0.0, false)
	me.global_position = bomb.global_position + Vector3(1.6, 0.1, 0)
	await frames(10)
	await take(kit.coil)
	kit.h_connect()
	await frames(3)
	await walk(Vector3(3.6, 0, 0.8), 90)
	await frames(40)
	cord = kit.bomb_cord()
	await take(kit.scissors)
	kit.h_cut(cord.id, 3.0)
	await frames(3)
	game.h_release()
	await frames(30)
	look(bomb.global_position + Vector3(2.0, 2.2, 4.2), bomb.global_position + Vector3(1.6, 0.2, 0))
	await snap("20_set_ready")
	own_view()
	print("BOMBSHOT on set: powder=", bomb.powder, " fuse=", cord.length)
	game.h_take()
	await frames(200)
	game.h_cue(1)
	await frames(200)
	me.global_position = cord.tip() + Vector3(0.5, 0.1, 0.5)
	await frames(4)
	kit.h_light(cord.id, 1)
	me.global_position = Vector3(-5.5, 0.1, 8.5)
	me.aim_yaw = -0.6
	me.aim_pitch = -0.1
	await frames(100)
	await snap("21_fuse_on_set", true, 2)
	for i in 600:
		if not bomb.loaded():
			break
		await physics_frame
	await frames(4)
	await snap("22_big_boom", true, 2)
	await frames(8)
	await snap("22b_big_boom", true, 2)
	await frames(40)
	await snap("22c_big_boom", true, 2)
	await frames(110)
	game.h_cue(3)
	await frames(60)
	place(monster, Vector3(-1.5, 0.0, 1.6))
	monster.set_fixed(false)
	me.global_position = Vector3(-2.6, 0.1, 5.4)
	await frames(10)
	game.h_prop_action(monster.pid)
	await frames(460)
	print("BOMBSHOT state=", game.state, " passed=", game.takes[0]["passed"] if not game.takes.is_empty() else [], " powder=", bomb.powder)
	await snap("23_review")
	print("BOMBSHOT_OK")
	quit()
