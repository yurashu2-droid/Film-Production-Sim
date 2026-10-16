extends SceneTree
# 「転がる大岩・予告編」の3カット目を、撮影カメラの画で撮る：カメラへ向かって走る二人と、後ろから迫る張りぼての大岩。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/boulder_shot.gd
const OUT := "res://tests/shots/trap_job/"
const RUN_FROM := [Vector3(-12.3, 0.05, -5.0), Vector3(-11.1, 0.05, -5.2)]   # 印②（走り出す所）
const RUN_TO := [Vector3(-12.1, 0.05, 1.2), Vector3(-11.2, 0.05, 1.0)]       # 印③（逃げ切る所）
const CAM_AT := Vector3(-11.9, 0.05, 3.9)
var game: Node
var beats: Node
var shots: Array = []


func _initialize() -> void:
	root.unfocusable = true
	create_timer(360).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), false])


func point_camera(camera: Node, point: Vector3, fov: float) -> void:
	var d: Vector3 = camera.global_basis.inverse() * (point - (camera.global_position + Vector3(0, camera.HEAD_Y, 0)))
	camera.cam_yaw = atan2(-d.x, -d.z)
	camera.cam_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	camera.fov = fov


func film_snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	game.film.view.get_texture().get_image().save_png(OUT + tag + ".png")
	shots.append(tag)
	print("BOULDERSHOT ", tag)


func until_holding() -> void:
	for i in 300:
		if beats.holding:
			return
		await physics_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	beats = game.beats
	var S: Dictionary = game.S
	var me: Node3D = game.local_player()
	var rock: RigidBody3D = game.hooks.feature("boulder").rock
	var job := -1
	for i in flow.JOBS.size():
		if str(flow.JOBS[i]["title"]) == "転がる大岩・予告編":
			job = i
	flow.day = 2
	game.h_accept_job(job)
	await frames(20)
	game.h_open_order()
	game.h_order_set("boulder", 1)
	game.h_order_confirm()
	await frames(10)
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	for aid in 2:
		(beats.mark(aid, 0) as Node).restore([RUN_FROM[aid] + Vector3(-3.0, 0, 0.0), Quaternion.IDENTITY, false])     # 場面1の印は、大岩の通り道の外へ
		(beats.mark(aid, 1) as Node).restore([RUN_FROM[aid], Quaternion.IDENTITY, false])
		(beats.mark(aid, 2) as Node).restore([RUN_TO[aid], Quaternion.IDENTITY, false])
	var film: RigidBody3D = game.film
	place(film, CAM_AT, 0.0)
	await frames(30)
	point_camera(film, Vector3(-11.4, 0.9, -3.0), 62.0)
	for i in 2:
		place(game.spots[i], CAM_AT + Vector3(-1.8 + 3.6 * float(i), 0.0, 1.2), PI)
	await frames(10)
	for i in 2:
		game._aim_spot(game.spots[i], Vector3(-11.6, 1.3, -1.8))
		game.spots[i].level = 3
	me.global_position = CAM_AT + Vector3(2.0, 0.1, 3.0)
	place(flow.script_prop, me.global_position + Vector3(0.5, 0.0, 0.0))
	place(rock, Vector3(-11.7, 0.1, -9.5))
	await frames(30)
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
	await frames(150)          # 場転：二人は印②（走り出す所）で待つ
	game.h_beat(1)
	for i in 120:
		if game.actors[0].beat_walking():
			break
		await physics_frame
	# 張りぼての大岩を、二人の真後ろから転がす（押す人は画面の外の奥）
	var mid: Vector3 = (game.actors[0].global_position + game.actors[1].global_position) * 0.5
	rock.launch(Vector3(mid.x + 1.1, 0.1, mid.z - 2.4), Vector3(0, 0, 3.7), Vector3(4.3, 0, 0))
	for k in 4:
		await frames(20)
		await film_snap("chase_%d" % k)
	for i in 120:
		if beats.lit[2]:
			break
		await physics_frame
	print("BOULDERSHOT lit ", beats.lit[2], " why ", beats._top_reason(2))
	quit(0)
