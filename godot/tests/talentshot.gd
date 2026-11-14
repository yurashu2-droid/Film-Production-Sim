extends SceneTree
# キャラの特技の画面を撮る：キャラを選ぶ画面・段ボール頭の頭の道具箱（しまう前と後）・左下の枠・手帳の人の台本の写し・ロボットのおなかランプ。
# あとの4人：ショールをかけた物と肩の枚数・「止まれ！」の吹き出しと「ぴたっ」と背中の札・伸ばした首・毛ひもを掛けた荷台と毛の減った頭。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/talentshot.gd
#   画面つきで動かす（窓は画面の外に出し、マウスも捕まえない）。出力は tests/shots/talent
const OUT := "res://tests/shots/talent/"
var game: Node
var flow: Node
var talent: Node
var me: Node
var close: Camera3D


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
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	print("TALENTSHOT ", tag)


func film(tag: String) -> void:
	await RenderingServer.frame_post_draw
	game.film.view.get_texture().get_image().save_png(OUT + tag + ".png")
	print("TALENTSHOT ", tag)


func first(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			return game.props[pid]
	return null


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = false) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = fixed
	prop.restore(state)


func ahead(distance: float, side: float = 0.0, up: float = 0.25) -> Vector3:
	var forward: Vector3 = me.flat_forward()
	return me.global_position + forward * distance + Vector3(-forward.z, 0, forward.x) * side + Vector3(0, up, 0)


# 自分のキャラを、近くの別のカメラから撮る（頭の上やおなかを確かめる）。from は、キャラから見た位置（前が +z）
func look_close(from: Vector3, at_height: float, fov: float = 42.0) -> void:
	if close == null:
		close = Camera3D.new()
		game.add_child(close)
	var facing := Basis(Vector3.UP, me.vis.rotation.y)
	close.fov = fov
	close.global_position = me.global_position + facing * from
	close.look_at(me.global_position + Vector3(0, at_height, 0))
	close.make_current()


func look_own() -> void:
	me.cam.make_current()


# 決めた場所から、決めた所を撮る
func look_from(from: Vector3, at: Vector3, fov: float = 46.0) -> void:
	if close == null:
		close = Camera3D.new()
		game.add_child(close)
	close.fov = fov
	close.global_position = from
	close.look_at(at)
	close.make_current()


# 会社の、いつもの撮り場所に立つ
func stand_home() -> void:
	me.global_position = flow.HOME_TRUCK + Vector3(-7.5, 0.1, 7.0)
	me.aim_yaw = PI * 0.75
	me.aim_pitch = -0.2
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(8)


# あとの4人の特技（会社での準備中）
func four_more() -> void:
	var kit: Node = game.cargo_kit
	var toilet: Node = first("scrap_toilet")
	var pie: Node = first("scrap_pie")
	var chicken: Node = first("scrap_chicken")
	var duck: Node = first("scrap_duck")
	var torch: Node = first("scrap_torch")

	# 10：ドレスの人。肩に2枚 → 物にかけると1枚 → 無し。ずれた布
	await pick("01")
	await stand_home()
	place(toilet, ahead(2.6, 0.0))
	place(pie, ahead(2.2, -1.5))
	place(chicken, ahead(2.4, 1.5))
	await frames(60)
	look_close(Vector3(0.6, 1.5, 3.0), 1.0)
	await snap("10_shawl_shoulders_two", 6)
	look_close(Vector3(-1.2, 1.9, -3.0), 1.0)
	await snap("10_shawl_shoulders_two_back", 6)
	look_own()
	print("TALENTSHOT aim toilet=", await aim_at(toilet))
	await snap("10_shawl_before")
	talent.host_use(me.peer_id, toilet.pid)
	await frames(50)
	print("TALENTSHOT aim toilet=", await aim_at(toilet))
	await snap("10_shawl_one_on")
	look_from(toilet.center_global() + Vector3(1.6, 1.0, 1.8), toilet.center_global())
	await snap("10_shawl_one_on_close", 6)
	look_close(Vector3(0.6, 1.5, 3.0), 1.0)
	await snap("10_shawl_shoulders_one", 6)
	talent.host_use(me.peer_id, chicken.pid)
	await frames(30)
	talent.host_shawl_push(toilet.pid, Vector3(0.65, 0, 0.2))
	await frames(20)
	look_from(toilet.center_global() + Vector3(1.9, 1.3, 2.4), (toilet.center_global() + chicken.center_global()) * 0.5)
	await snap("10_shawl_two_on_one_slid", 6)
	look_close(Vector3(0.6, 1.5, 3.0), 1.0)
	await snap("10_shawl_shoulders_none", 6)
	look_own()
	me.aim_pitch = -0.3
	await frames(6)
	await snap("10_shawl_two_on")
	talent.host_shawl_push(toilet.pid, Vector3(-0.8, 0, 0.5))
	await frames(18)
	await snap("10_shawl_flying", 2)
	talent.host_clear_all()
	await frames(20)

	# 11：カエルの警官。背中の札（立っている）→ 止まれ！（吹き出し・ぴたっ・倒れた札）
	await pick("02")
	await stand_home()
	look_close(Vector3(-1.4, 1.7, -2.8), 1.0)
	await snap("11_halt_paddle_up", 6)
	look_own()
	await snap("11_halt_paddle_up_own")
	place(toilet, flow.HOME_TRUCK + Vector3(-14, 0.3, 12))
	place(chicken, ahead(3.0, -0.8, 3.2))
	place(duck, ahead(3.6, 0.9, 3.8))
	place(torch, ahead(2.4, 0.2, 2.8))
	place(pie, ahead(4.2, -0.2, 4.2))
	await frames(14)
	talent.host_use(me.peer_id)
	await frames(26)
	await snap("11_halt_shout", 2)
	look_close(Vector3(-2.2, 2.0, -3.4), 1.6, 60.0)
	await snap("11_halt_paddle_down", 2)
	look_own()
	await frames(260)
	look_close(Vector3(-1.4, 1.7, -2.8), 1.0)
	await snap("11_halt_paddle_rising", 2)
	look_own()

	# 12：ベレー帽の人。首を伸ばす前と後
	await pick("04")
	await stand_home()
	look_close(Vector3(2.6, 1.3, 1.6), 1.0)
	await snap("12_neck_in", 6)
	look_own()
	await snap("12_neck_in_own")
	talent.host_use(me.peer_id)
	await frames(60)
	look_close(Vector3(2.6, 1.3, 1.6), 1.25)
	await snap("12_neck_out", 6)
	look_own()
	await snap("12_neck_out_own")
	me.set_first_person(true)
	await frames(10)
	await snap("12_neck_out_first_person")
	me.set_first_person(false)
	talent.host_use(me.peer_id)
	await frames(40)

	# 13：モップの王様。頭の房（いっぱい）→ 毛ひもを荷台に掛ける → 房が減る
	await pick("06")
	await stand_home()
	look_close(Vector3(1.0, 2.6, 4.8), 1.7)
	await snap("13_hair_full", 6)
	look_close(Vector3(-1.2, 3.0, -4.8), 1.7)
	await snap("13_hair_full_back", 6)
	look_own()
	await snap("13_hair_full_own")
	var truck: Node3D = game.truck
	var box: Node = null
	for carton: Node in kit.cartons:
		if box == null and not carton.absent:
			box = carton
	var along: float = (truck.hooks[4] as Vector3).z
	var bounds: AABB = game.body_bounds(box)
	me.global_position = truck.global_transform * Vector3(-2.9, 0.1, along + bounds.size.z * 0.5 + 1.6)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	box.restore([truck.global_transform * Vector3(-(1.5 + bounds.size.x * 0.5) - bounds.get_center().x, 0.5 - bounds.position.y, along - bounds.get_center().z), Quaternion.IDENTITY, false])
	await frames(2)
	game.h_grab(box.pid)
	await frames(10)
	game.h_load_truck(box.pid)
	await frames(40)
	print("TALENTSHOT carton on the bed=", box.rider_of == truck.pid)
	# 向こうのフックに先に結び、手前のフックに結ぶ
	var local: Vector3 = truck.hooks[9]
	var spot: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
	var to: Vector3 = kit.hook_at(9) - spot
	me.global_position = Vector3(spot.x, truck.global_position.y + 0.1, spot.z)
	me.aim_yaw = atan2(-to.x, -to.z)
	me.aim_pitch = -0.1
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(6)
	talent.host_use(me.peer_id)
	await frames(30)
	await snap("13_hair_bundle_in_hand")
	kit.rng.seed = 11
	kit.h_hook(4)
	await frames(40)
	await snap("13_hair_one_end_tied")
	kit.h_hook(9)
	await frames(60)
	talent.host_use(me.peer_id)
	await frames(200)
	await snap("13_hair_cord_on")
	look_from(truck.global_transform * Vector3(2.4, 2.4, along - 2.0), truck.global_transform * Vector3(0, 1.2, along), 50.0)
	await snap("13_hair_cord_on_bed", 6)
	look_from(truck.global_transform * Vector3(0.2, 3.6, along + 0.4), truck.global_transform * Vector3(0, 1.0, along), 60.0)
	await snap("13_hair_cord_on_bed_top", 6)
	await stand_home()
	look_close(Vector3(1.0, 2.6, 4.8), 1.7)
	await snap("13_hair_thin", 6)
	look_close(Vector3(-1.2, 3.0, -4.8), 1.7)
	await snap("13_hair_thin_back", 6)
	look_own()
	await snap("13_hair_thin_own")
	print("TALENTSHOT hair left=%.2f pinned=%s" % [talent.hair_left(me.peer_id), str(kit.pinned(box.pid))])
	# 片付け：ほどいて、箱を降ろす
	for lash_id: int in kit.lashes.keys():
		kit.h_untie(lash_id)
	await frames(6)
	game.host_unload(box)
	place(box, flow.HOME_TRUCK + Vector3(-12, 0.3, 4))
	await frames(10)


# 物に照準を合わせる（カメラは肩ごしなので、カメラから物への向きに、少しずつ寄せる）
func aim_at(prop: Node3D) -> bool:
	for step in 10:
		var to: Vector3 = prop.center_global() - me.cam.global_position
		me.aim_yaw = atan2(-to.x, -to.z)
		me.aim_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.0)
		await frames(3)
	await frames(4)
	return me.target == prop


func pick(tag: String) -> void:
	game.h_select_cast(game.PLAYER_CASTS.find(tag))
	await frames(4)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true          # マウスを捕まえない（画面の外で動かすので）
	while not game.startup_complete:
		await process_frame
	await frames(40)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	flow = game.production
	talent = game.talent
	me = game.local_player()
	game.h_accept_job(0)
	await frames(20)

	# 1：キャラを選ぶ画面（特技の名前と説明。準備中の札）
	game.set_character_menu(true)
	game.hud.character_picker.choose(game.PLAYER_CASTS.find("09"))
	await snap("1_picker_box_head", 20)
	game.hud.character_picker.choose(game.PLAYER_CASTS.find("M02"))
	await snap("1_picker_robot", 20)
	game.hud.character_picker.choose(game.PLAYER_CASTS.find("03"))
	await snap("1_picker_notebook", 20)
	for row: Array in [["06", "mop_king"], ["01", "dress"], ["02", "frog_officer"], ["04", "beret"]]:
		game.hud.character_picker.choose(game.PLAYER_CASTS.find(row[0]))
		await snap("1_picker_" + str(row[1]), 20)
	game.set_character_menu(false)

	# 2：段ボール頭。小物を前に並べる
	await pick("09")
	me.global_position = flow.HOME_TRUCK + Vector3(-7.5, 0.1, 7.0)
	me.aim_yaw = PI * 0.75
	me.aim_pitch = -0.32
	me.vis.rotation.y = me.aim_yaw + PI
	await frames(6)
	var pie: Node = first("scrap_pie")
	var chicken: Node = first("scrap_chicken")
	var torch: Node = first("scrap_torch")
	var duck: Node = first("scrap_duck")
	place(pie, ahead(1.7, 0.0))
	place(chicken, ahead(2.0, -0.9))
	place(torch, ahead(2.0, 0.9))
	place(duck, ahead(2.9, 0.3))
	await frames(60)
	print("TALENTSHOT aim pie=", await aim_at(pie))
	await snap("2_before_stow")
	look_close(Vector3(0.5, 2.5, 3.0), 1.75)
	await snap("2_before_stow_close", 4)
	look_own()

	# 3：見ている小物を K でしまう
	talent.host_use(me.peer_id, pie.pid)
	await frames(50)
	await snap("3_one_stowed")
	look_close(Vector3(0.5, 2.5, 3.0), 1.75)
	await snap("3_one_stowed_close", 4)
	look_own()

	# 4：3つ入れる
	talent.host_use(me.peer_id, chicken.pid)
	await frames(30)
	talent.host_use(me.peer_id, torch.pid)
	await frames(50)
	print("TALENTSHOT aim duck=", await aim_at(duck))
	await snap("4_three_stowed")
	look_close(Vector3(0.5, 2.5, 3.0), 1.75)
	await snap("4_three_stowed_close", 4)
	look_close(Vector3(-2.6, 2.3, -1.6), 1.75)
	await snap("4_three_stowed_back", 4)
	look_close(Vector3(0.0, 2.75, 1.25), 2.15, 50.0)
	await snap("4_three_stowed_top", 4)
	look_own()

	# 5：手ぶらの K で、最後に入れた物が手に出る
	me.aim_pitch = -0.2
	me.aim_yaw = PI * 0.75
	await frames(8)
	talent.host_use(me.peer_id)
	await frames(40)
	await snap("5_taken_out")
	game.h_release()
	await frames(10)

	# 5b：手帳の人。台本を持たずに、K で台本の写しを開く
	await pick("03")
	await frames(60)
	me.aim_pitch = -0.2
	me.aim_yaw = PI * 0.75
	await frames(8)
	talent.host_use(me.peer_id)
	await frames(40)
	await snap("8_notebook_page")
	talent.host_use(me.peer_id)
	# あそびかた（K の行が入っているか）
	game.help_open = true
	await snap("9_help", 20)
	game.help_open = false

	await four_more()

	# 6：ロボットのおなかランプ。現場へ行き、ライトを消して役者の前に立つ
	await pick("M02")
	await frames(30)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(4)
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	await frames(60)
	for rig: Node in game.spots:
		rig.level = 0
	game.actors[0].mark.restore([Vector3(0.0, 0.05, -1.0), Quaternion.IDENTITY, false])
	game.actors[1].mark.restore([Vector3(1.3, 0.05, -1.2), Quaternion.IDENTITY, false])
	game.h_standby()
	place(game.film, Vector3(-3.2, 0, 3.4), 0.0, true)
	await frames(30)
	game._aim_camera(Vector3(0.4, 1.1, -0.6), 52.0)
	me.global_position = Vector3(0.7, 0.1, 1.9)
	me.aim_yaw = 0.0
	me.aim_pitch = -0.12
	me.vis.rotation.y = PI
	await frames(40)
	await snap("6_lamp_off")
	await film("6_lamp_off_film")
	look_close(Vector3(1.7, 1.1, 2.3), 0.85, 46.0)
	await snap("6_lamp_off_close", 4)
	look_own()
	talent.host_use(me.peer_id)
	await frames(30)
	await snap("7_lamp_on")
	await film("7_lamp_on_film")
	look_close(Vector3(1.7, 1.1, 2.3), 0.85, 46.0)
	await snap("7_lamp_on_close", 4)
	look_own()
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for i in 2:
		print("TALENTSHOT face brightness actor %d = %.3f" % [i, game.judge.brightness(space, game.actors[i].head_pos())])
	print("TALENTSHOT_DONE")
	quit(0)
