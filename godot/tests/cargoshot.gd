extends SceneTree
# 運ぶ仕組みを撮る：会社の機材置き場 → F で積んだ荷台 → 積み込み確認 → 現場に着いた直後（3種類の現場）。
#   godot --path godot --script res://tests/cargoshot.gd      （画面つきで動かす。画像は tests/shots/cargo へ）
var game: Node
var flow: Node
var me: Node
var truck: Node
var cam: Camera3D


func _initialize() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(tag: String) -> void:
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/cargo/%s.png" % tag)
	print("CARGOSHOT ", tag)


# 自分で置いたカメラで撮る（from から at を見る）。画面の文字は消す
func view(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	game.hud.visible = false
	game.production_hud.visible = false


# 遊ぶ人の画面に戻す
func play_view() -> void:
	cam.current = false
	me.cam.make_current()
	game.hud.visible = true
	game.production_hud.visible = true


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


# 荷台の西側に立って、目の前に持った物を F で積む（積めなければ、手に持ったままになる）
func load_from_west(prop: Node, turn: float = 0.0) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var facing := Quaternion(Vector3.UP, turn)
	var box: AABB = Transform3D(Basis(facing), Vector3.ZERO) * (game.body_bounds(prop) as AABB)
	var reach: float = box.size.x * 0.5
	me.global_position = truck.global_transform * Vector3(-(1.5 + reach * 2.0 + 0.6), 0.1, -1.2)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(-(1.5 + reach) - box.get_center().x, 0.5 - box.position.y, -1.2 - box.get_center().z), facing, false])
	await frames(2)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(20)
	if prop.rider_of != truck.pid:
		print("CARGOSHOT no room on the deck floor for ", prop.kind, " (stays in hand)")


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(60)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/cargo"))
	flow = game.production
	me = game.local_player()
	truck = game.truck
	cam = Camera3D.new()
	game.add_child(cam)
	var yard: Rect2 = flow.Office.GEAR_YARD
	var yard_mid := Vector3(yard.get_center().x, 0.9, yard.get_center().y)

	for round_no in 3:
		game.h_accept_job(round_no)
		await frames(40)
		if round_no == 0:
			# 1) 会社：軽トラ（荷台は空）と、北東の機材置き場
			view(Vector3(75.2, 4.6, 22.8), Vector3(82.6, 0.8, 14.6), 62.0)
			await snap("1_gear_yard")
			view(Vector3(80.9, 3.7, 19.4), yard_mid + Vector3(0.2, -0.3, 0.6), 58.0)
			await snap("2_gear_yard_close")
			# 遊ぶ人の画面：軽トラの後ろに立って、機材置き場のほうを見る（遠くからの目印と、足元の案内）
			play_view()
			me.global_position = flow.HOME_TRUCK + Vector3(-1.0, 0.1, -5.6)
			me.aim_yaw = -PI * 0.62
			me.aim_pitch = -0.12
			await frames(30)
			await snap("3_player_at_truck")
		# F で積む（大きさの違う物を、同じ場所から続けて）
		var items: Array = [[of_kind("plywood")[0], PI * 0.5], [of_kind("tomato_monster")[0], 0.0], [of_kind("carton")[0], 0.0], [of_kind("carton")[1], 0.0], [of_kind("rock")[0], 0.0], [of_kind("applebox")[0], 0.0]]
		if round_no == 1:
			items = [[of_kind("riser")[0], 0.0], [of_kind("carton")[0], 0.0], [of_kind("rock")[0], 0.0]]
		elif round_no == 2:
			items = [[of_kind("witch_cauldron")[0], 0.0], [of_kind("carton")[0], 0.0], [of_kind("carton")[1], 0.0], [of_kind("dragon_skull")[0], 0.0]]
		for item: Array in items:
			await load_from_west(item[0], item[1])
		await frames(60)
		if round_no == 0:
			# 2) F で積んだ荷台（後ろの上から）
			view(truck.global_transform * Vector3(-2.6, 4.4, -5.2), truck.global_transform * Vector3(0, 1.2, -1.1), 55.0)
			await snap("4_loaded_bed")
			# 3) 積み込み確認の画面
			play_view()
			me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
			me.aim_yaw = -PI * 0.5
			await frames(20)
			game.open_menu("packing")
			await snap("5_packing_sheet")
			game.close_menu()
		me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
		await frames(5)
		game.h_depart()
		if round_no == 0:
			await frames(50)
			await snap("6_departing")
		while flow.phase == 3:
			await physics_frame
		await frames(90)
		# 4) 現場に着いた直後：遊ぶ人の画面と、搬入口を上から見た図
		play_view()
		await frames(10)
		await snap("7_site%d_arrival" % flow.site_index())
		view(game.SPAWN + Vector3(-3.6, 6.2, 5.4), game.SPAWN + Vector3(2.6, 0.6, -2.2), 62.0)
		await snap("8_site%d_entrance" % flow.site_index())
		play_view()
		print("CARGOSHOT site=", flow.site_index(), " lost=", flow.lost, " cargo_on_site=", items.all(func(i: Array) -> bool: return flow.at_site(i[0])))
		flow.lease_left = 0.01
		await frames(4)
		game.h_deliver(0)
		await frames(4)
		game.h_return_office()
		await frames(60)
	print("CARGOSHOT_OK")
	quit(0)
