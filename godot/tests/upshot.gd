extends SceneTree
# レンタルのカウンター・備品の購入・確認用モニター・台本の開閉を撮る。
#   godot --path godot --script res://tests/upshot.gd
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/up/%s.png" % tag)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/up"))
	var flow: Node = game.production
	var me: Node = game.local_player()
	flow.wallet = 900
	game.h_accept_job(0)
	# 1) レンタルのカウンター（軽トラ側から）
	var cam := Camera3D.new()
	cam.fov = 60.0
	game.add_child(cam)
	cam.global_position = Vector3(82.5, 2.2, 21.5)
	cam.look_at(Vector3(90.5, 1.4, 16.0))
	cam.make_current()
	game.hud.visible = false
	game.production_hud.visible = false
	await snap("1_rental_counter")
	cam.global_position = Vector3(79.5, 1.9, 24.5)
	cam.look_at(flow.monitor_prop.global_position + Vector3(0, 1.0, 0))
	await snap("2_monitor_home")
	cam.current = false
	me.cam.make_current()
	game.hud.visible = true
	game.production_hud.visible = true
	# 2) カウンターの前に立つと F の案内が出て、開くと備品も買える
	me.global_position = flow.Rental.POINT + Vector3(-0.6, 0.1, 0)
	me.aim_yaw = -PI * 0.5
	for i in 30:
		await physics_frame
	print("UPSHOT station=", game.station())
	await snap("3_at_counter")
	game.h_open_order()
	await snap("4_catalog")
	game.h_buy_upgrade("monitor")
	await snap("5_bought")
	print("UPSHOT levels=", flow.levels, " wallet=", flow.wallet)
	flow.levels["monitor"] = 0
	game.h_order_confirm()
	# 3) 台本：持っただけでは開かない。F で開く
	me.global_position = Vector3(72.6, 0.1, 2.6)
	for i in 20:
		await physics_frame
	game.h_grab(flow.script_prop.pid)
	for i in 30:
		await physics_frame
	await snap("6_script_closed")
	game.script_open = true
	await snap("7_script_open")
	game.h_release()
	# 4) 現場：モニターから離れると映像は出ない。そばに立つと出る
	game.host_load(flow.monitor_prop, game.truck)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	for i in 10:
		await physics_frame
	game.h_depart()
	while flow.phase != 4:
		await physics_frame
	for i in 60:
		await physics_frame
	game.host_unload(flow.monitor_prop)
	var st: Array = flow.monitor_prop.get_state()
	st[0] = game.SPAWN + Vector3(-3.0, 0.05, -2.0)
	st[1] = Quaternion(Vector3.UP, 0.6)
	flow.monitor_prop.restore(st)
	me.global_position = game.SPAWN + Vector3(4.0, 0.1, 3.0)
	me.aim_yaw = atan2(7.0, 5.0)
	for i in 40:
		await physics_frame
	print("UPSHOT far sees=", game.can_see_monitor())
	await snap("8_site_far")
	me.global_position = flow.monitor_prop.global_position + Vector3(0.9, 0.1, 1.6)
	for i in 40:
		await physics_frame
	print("UPSHOT near sees=", game.can_see_monitor())
	await snap("9_site_near")
	print("UPSHOT_OK")
	quit()
