extends SceneTree
# 監督の机（のぞき箱・参考スライド・発注の電話）の画面を撮る。出力は tests/shots/director/
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/director_shot.gd
#   画面つきで動かす（窓は画面の外に出し、マウスも捕まえない）
#   別の画面の大きさで確かめるとき：--resolution 1280x720 を足し、環境変数 DIRECTOR_SHOT_OUT に出力先（res://…/）を入れる
const OUT := "res://tests/shots/director/"
const Slides := preload("res://scripts/production_slides.gd")
var game: Node
var flow: Node
var desk: Node
var me: Node
var extra: Camera3D
var out := OUT


func _initialize() -> void:
	root.unfocusable = true
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(tag: String, wait: int = 12) -> void:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + tag + ".png")
	print("DIRECTOR_SHOT ", tag)


func first(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			return game.props[pid]
	return null


# 決めた場所から、決めた所を撮る
func look_from(from: Vector3, at: Vector3, fov: float = 46.0) -> void:
	if extra == null:
		extra = Camera3D.new()
		game.add_child(extra)
	extra.fov = fov
	extra.global_position = from
	extra.look_at(at)
	extra.make_current()


func look_own() -> void:
	me.cam.make_current()


# 自分の視点を、その場所へ向ける（照準を合わせる）
func face(at: Vector3) -> void:
	var from: Vector3 = me.global_position + Vector3(0, 2.35, 0)
	var d: Vector3 = at - from
	me.aim_yaw = atan2(-d.x, -d.z)
	me.aim_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(6)


func pick(tag: String) -> void:
	game.h_select_cast(game.PLAYER_CASTS.find(tag))
	await frames(12)
	me = game.local_player()


# 2人目の制作班を、その場に立たせる（通信はしない。姿と位置だけ）
func add_crew(id: int, cast: int, at: Vector3, yaw: float) -> Node:
	game._roster.append([id, cast])
	game._apply_roster()
	var other: Node = game.players[id]
	other.global_position = at
	other.vis.rotation.y = yaw
	return other


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(40)
	if OS.get_environment("DIRECTOR_SHOT_OUT") != "":
		out = OS.get_environment("DIRECTOR_SHOT_OUT")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	flow = game.production
	desk = game.director
	me = game.local_player()
	var box: Vector3 = desk.BOX_AT
	var phone: Vector3 = desk.PHONE_AT
	# 本番と同じに、今日の廃材を18個だけ出す（全部はそろわない日にする）
	seed(11)
	flow.daily = true
	flow.restock()
	var kaiju := 0
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and kaiju == 0:
			kaiju = i
	game.h_accept_job(kaiju)
	await frames(20)

	# 1：事務所の机。西から、のぞき箱・カタログ・電話・台本
	me.global_position = Vector3(74.6, 0.1, 2.6)
	look_from(Vector3(71.5, 2.0, 2.9), Vector3(71.45, 1.1, 0.1), 50.0)
	await snap("1_desk")
	look_from(box + Vector3(0.9, 0.75, 1.5), box + Vector3(0.1, 0.3, 0.0), 36.0)
	await snap("1_desk_peep_box")
	look_from(phone + Vector3(-0.9, 0.7, 1.3), phone + Vector3(-0.2, 0.1, 0.0), 36.0)
	await snap("1_desk_phone")

	# 2：机の前に立って、のぞき箱を見る（名前と F の案内）
	look_own()
	me.global_position = Vector3(70.95, 0.1, 2.4)
	await face(box + Vector3(0, 0.3, 0.1))
	await snap("2_aim_peep_box")
	print("DIRECTOR_SHOT aim=", desk.aimed(), " label=", game.hud.target_label.text, " keys=", game.hud.keys.text.get_slice("\n", 0))
	me.global_position = Vector3(71.8, 0.1, 2.4)
	await face(phone + Vector3(-0.1, 0.12, 0.0))
	await snap("2_aim_phone")
	print("DIRECTOR_SHOT aim=", desk.aimed(), " label=", game.hud.target_label.text, " keys=", game.hud.keys.text.get_slice("\n", 0))

	# 3：のぞく。まず、ほかの人から見た姿（箱に顔を寄せて止まる）。キャラを替えて、全員ぶん
	for tag: String in ["M02", "04", "09", "03", "01", "02", "06"]:
		await pick(tag)
		me.global_position = Vector3(70.95, 0.1, 2.2)
		await frames(4)
		game.h_peep(true)
		await frames(20)
		desk.view.visible = false
		look_from(box + Vector3(2.3, 0.9, 1.9), box + Vector3(0.0, 0.25, 0.6), 40.0)
		await snap("3_peeping_%s" % tag, 8)
		look_from(box + Vector3(-2.1, 1.3, 2.6), box + Vector3(0.0, 0.2, 0.5), 40.0)
		await snap("3_peeping_%s_back" % tag, 8)
		desk.view.visible = true
		game.h_peep(false)
		await frames(10)
	await pick("M02")

	# 4：のぞいている人の画面（スライド）。見やすい中身に決め直してから撮る
	me.global_position = Vector3(70.95, 0.1, 2.2)
	await frames(4)
	look_own()
	game.h_peep(true)
	await frames(12)
	await snap("4_slide_1_roles")
	print("DIRECTOR_SHOT deck=", flow.slides)
	print("DIRECTOR_SHOT today=", flow.obtainable_kinds())
	for i in range(1, desk.view.count()):
		desk.view.step(1)
		await snap("4_slide_%d" % (i + 1))
	game.h_peep(false)
	await frames(10)

	# 城の依頼のスライドも1組（役が城・月・爆発になる）
	flow.slides = Slides.build(0, "castle", flow.Briefs.brief(0)["likes"], flow.obtainable_kinds(), 5)
	game.production_sync.rpc(flow.snapshot())
	me.global_position = Vector3(70.95, 0.1, 2.2)
	await frames(4)
	game.h_peep(true)
	await frames(12)
	await snap("5_castle_slide_1_roles")
	desk.view.step(1)
	await snap("5_castle_slide_2_likes")
	game.h_peep(false)
	await frames(10)
	await company_screens(kaiju)
	await order_while_others_work()
	# あそびかた（Tab）：文が増えたので、画面に収まっているかを見る
	look_own()
	game.help_open = true
	await snap("9_help", 20)
	game.help_open = false
	await set_screens()
	print("DIRECTOR_SHOT_OK")
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	for i in 8:
		await process_frame
	quit()


# 6：集める人の画面（会社）。場面の一覧も配役表も無い。現物を見ると、名前と属性は出る
func company_screens(kaiju: int) -> void:
	flow.slides = Slides.build(kaiju, "kaiju", flow.Briefs.brief(kaiju)["likes"], flow.obtainable_kinds(), 3)
	game.production_sync.rpc(flow.snapshot())
	look_own()
	var bus: Node = first("scrap_bus")
	var cart: Node = first("lift_cart")
	me.global_position = flow.HOME_TRUCK + Vector3(-7.5, 0.1, 6.0)
	me.aim_yaw = PI * 0.75
	me.aim_pitch = -0.2
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(6)
	var ahead: Vector3 = me.flat_forward()
	cart.restore([me.global_position + ahead * 2.6 + Vector3(0, 0.1, 0), Quaternion(Vector3.UP, 0.6), false])
	if bus != null and not bus.absent:
		bus.restore([me.global_position + ahead * 3.4 + Vector3(-ahead.z, 0, ahead.x) * 2.0 + Vector3(0, 0.1, 0), Quaternion(Vector3.UP, me.aim_yaw + PI), false])
	await frames(40)
	await face(cart.center_global())
	await snap("6_gatherer_yard")
	print("DIRECTOR_SHOT gatherer label=", game.hud.target_label.text)
	# 積み込み確認：荷台と機材だけ（配役表は無い）
	game.h_cast(cart.pid, "monster")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(6)
	game.open_menu("packing")
	await snap("6_packing_no_cast_sheet", 20)
	game.close_menu()
	await frames(4)


# 7：発注。自分の画面にだけ開く（今日の廃材の一覧・配役表は無い）。その間も、ほかの人は動いている
func order_while_others_work() -> void:
	# 机の電話で開く：自分の画面
	me.global_position = Vector3(71.8, 0.1, 1.5)
	me.aim_yaw = 0.0
	me.vis.rotation.y = PI
	await frames(6)
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_set("refill", 1)
	await snap("7_order_screen", 20)
	game.h_order_confirm()
	await frames(20)
	# 届いた物：軽トラの荷台の爆弾と、横の火薬の袋
	look_from(flow.HOME_TRUCK + Vector3(-6.2, 2.4, -5.6), flow.HOME_TRUCK + Vector3(-1.6, 0.5, -1.9), 46.0)
	await snap("7_order_delivered", 10)
	# もう1人が電話で発注している間：自分（集める人）の画面は、そのまま。物を持って歩ける。時計も進む
	var caller: Node = add_crew(2, 3, Vector3(71.85, 0.05, 1.55), PI)
	flow.open_order(2)
	# 自分は、届いた火薬の袋を運んでいる
	var sack: Node = game.bomb_kit.sacks[0]
	me.global_position = Vector3(72.7, 0.1, 3.4)
	await face(Vector3(71.9, 1.3, 0.6))
	sack.restore([me.global_position + me.flat_forward() * 1.2 + Vector3(0, 1.0, 0), Quaternion.IDENTITY, false])
	await frames(3)
	game.h_grab(sack.pid)
	await frames(30)
	look_own()
	await snap("7_other_orders_my_screen", 10)
	print("DIRECTOR_SHOT other orders: orderer=", flow.orderer, " my catalog=", game.hud.catalog.visible, " blocked=", game.ui_blocking(), " caller pose=", caller.vis.skel.get_node_or_null("DeskPose") != null)
	look_from(Vector3(75.2, 1.75, 0.3), Vector3(72.5, 1.05, 1.9), 44.0)
	await snap("7_ordering_seen_by_others", 10)
	look_own()
	flow.close_order(2)
	game.h_release()
	game._roster = game._roster.filter(func(r: Array) -> bool: return r[0] != 2)
	game._apply_roster()
	await frames(4)


# 8：現場。台本を持たない人の画面には、場面の一覧が無い。台本を持つと出る
func set_screens() -> void:
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(4)
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	await frames(30)
	look_own()
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.15
	me.vis.rotation.y = me.aim_yaw + PI
	await snap("8_set_without_script", 20)
	var book: Node = flow.script_prop
	book.restore([me.global_position + me.flat_forward() * 1.2 + Vector3(0, 0.4, 0), Quaternion.IDENTITY, false])
	await frames(4)
	game.h_grab(book.pid)
	await frames(10)
	await snap("8_set_holding_script", 20)
	var use := InputEventKey.new()
	use.physical_keycode = KEY_F
	use.pressed = true
	game._input(use)
	await snap("8_set_script_open", 20)
	game.h_release()
	await frames(6)
