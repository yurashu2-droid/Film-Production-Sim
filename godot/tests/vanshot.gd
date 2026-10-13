extends SceneTree
# ロケバンの見た目を撮る（窓あり）。 godot --path godot --script res://tests/vanshot.gd
# 保存先: godot/tests/shots/van/
var game: Node
var cam: Camera3D


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/van/%s.png" % tag)


func look(from: Vector3, at: Vector3, fov: float = 55.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov
	cam.make_current()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/van"))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	cam = Camera3D.new()
	root.add_child(cam)
	var flow: Node = game.production
	var truck: Node3D = game.truck
	flow.levels["car"] = 1
	truck.set_vehicle("van")
	var me: Node3D = game.local_player()
	var home: Vector3 = flow.HOME_TRUCK
	game.h_accept_job(0)
	for i in 40:
		await physics_frame

	# 1. 斜め前から（人が横に立って大きさがわかる）
	me.global_position = home + Vector3(-2.3, 0.1, 1.0)
	me.rotation.y = -PI * 0.5
	for i in 20:
		await physics_frame
	look(home + Vector3(-6.0, 2.2, 5.5), home + Vector3(0, 0.9, 0.2))
	await snap("1_base_front_left")
	# 2. 反対の斜め後ろから
	look(home + Vector3(5.5, 2.4, -6.0), home + Vector3(0, 0.9, -0.5))
	await snap("2_base_rear_right")
	# 真横（スライドドア側）
	look(home + Vector3(7.0, 1.4, 0.0), home + Vector3(0, 1.0, 0.0), 45.0)
	await snap("2b_base_side_door")
	# 真横（運転席側）人と並べて
	look(home + Vector3(-7.0, 1.2, 0.0), home + Vector3(0, 1.0, 0.0), 45.0)
	await snap("2c_base_side_driver")

	# 3. 荷物を積んだ後ろ
	var loaded := 0
	var spots := [Vector3(-0.5, 0, -1.9), Vector3(0.5, 0, -1.9), Vector3(0.0, 0, -1.3), Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5)]
	for pid: int in game.props:
		var p: Node = game.props[pid]
		# 小さめの物だけを、荷台のあちこちへ（大きな物は積み上がってしまうため）
		if flow._is_free(p) and not p.absent and p.rider_of == 0 and p.deck_top < 0.0 and not p.fixed and not p.immovable and loaded < spots.size() and maxf(p.half.x, p.half.z) < 0.7 and p.half.y < 0.6:
			var at: Vector3 = spots[loaded]
			p.global_position = truck.global_transform * Vector3(at.x, truck.deck_top + 0.5, at.z)
			game.host_load(p, truck)
			loaded += 1
			print("LOADED ", p.kind, " local=", p.ride_local.origin)
	for i in 20:
		await physics_frame
	me.global_position = home + Vector3(-1.0, 0.1, -4.2)
	me.rotation.y = PI
	for i in 20:
		await physics_frame
	look(home + Vector3(0.0, 2.2, -8.0), home + Vector3(0, 0.9, -1.0), 50.0)
	await snap("3_rear_cargo")
	look(home + Vector3(-2.6, 3.4, -6.2), home + Vector3(0, 0.8, -1.2), 50.0)
	await snap("3b_rear_cargo_high")
	look(home + Vector3(3.0, 1.8, -4.0), home + Vector3(0, 0.9, -0.8), 55.0)
	await snap("3c_side_door_cargo")
	# プレイヤー視点（照準が通るか）
	me.cam.make_current()
	await snap("3d_player_view")

	# 4. 移動の途中（走行の演出カメラ）
	flow.prep_left = 100.0
	me.global_position = home + Vector3(-3, 0.1, 0)
	for i in 5:
		await physics_frame
	game.h_depart()
	var done := false
	while flow.phase == 3:
		await physics_frame
		if not done and flow.trip_time >= 4.0:
			done = true
			await snap("4_travel_mid")
	for i in 90:
		await physics_frame
	# 5. 現場に着いた
	var site: Vector3 = flow.SITE_TRUCK
	look(site + Vector3(-4.0, 2.4, -6.5), site + Vector3(0, 0.9, 0.0))
	await snap("5_site_a")
	look(site + Vector3(-2.5, 2.0, 4.2), site + Vector3(0, 0.9, 0.0), 60.0)
	await snap("5_site_b")
	look(site + Vector3(-9.0, 7.0, 2.0), site + Vector3(0, 0.5, 0.0), 60.0)
	await snap("5_site_top")
	print("VANSHOT_OK ", truck.global_position, " loaded=", loaded)
	quit()
