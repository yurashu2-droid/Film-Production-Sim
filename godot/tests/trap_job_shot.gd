extends SceneTree
# 転がる大岩・予告編を、撮影カメラの画で撮る（仕掛けで、カメラを動かし、罠を落とす）。
#   場面1：重りが滑車越しに台車を引き、カメラが歩く二人と一緒に動く（支えのロープに火を付けておく）
#   場面2：場転の間に、罠の重りを吊ったロープに火を付けてから、1 で回す → 立ち止まった二人のそばに重りが落ちる
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/trap_job_shot.gd
const OUT := "res://tests/shots/trap_job/"
const MARKS := [[Vector3(-10.8, 0.05, -1.5), Vector3(-14.2, 0.05, -1.5), Vector3(-14.6, 0.05, 0.4)],
	[Vector3(-10.8, 0.05, -0.4), Vector3(-14.2, 0.05, -0.4), Vector3(-15.0, 0.05, 1.0)]]
const WALL_X := -17.0           # 倉庫の西の壁（内側の面）
var game: Node
var flow: Node
var beats: Node
var rig: Node
var S: Dictionary
var me: Node
var shots: Array = []


func _initialize() -> void:
	root.unfocusable = true
	create_timer(300).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = false) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), fixed])


func point_camera(camera: Node, point: Vector3, fov: float) -> void:
	var d: Vector3 = camera.global_basis.inverse() * (point - (camera.global_position + Vector3(0, camera.HEAD_Y, 0)))
	camera.cam_yaw = atan2(-d.x, -d.z)
	camera.cam_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	camera.fov = fov


func top_of(p: RigidBody3D) -> Vector3:
	return p.center_global() + Vector3(0, p.half.y * 0.9, 0)


func film_snap(tag: String, caption: String) -> void:
	await RenderingServer.frame_post_draw
	game.film.view.get_texture().get_image().save_png(OUT + tag + ".png")
	shots.append([tag, caption])
	print("TRAPSHOT ", tag)


func light(at: Vector3) -> void:
	for i in 2:
		place(game.spots[i], Vector3(game.film.global_position.x - 1.8 + 3.6 * float(i), 0.0, game.film.global_position.z + 1.4), PI)
	await frames(10)
	for i in 2:
		game._aim_spot(game.spots[i], at + Vector3(0, 1.3, 0))
		game.spots[i].level = 3


func part(kind: String, n: int = 0) -> RigidBody3D:
	for p: RigidBody3D in rig.parts:
		if p.kind == kind:
			if n == 0:
				return p
			n -= 1
	return null


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	beats = game.beats
	rig = game.hooks.feature("contraptions")
	S = game.S
	me = game.local_player()
	var job := -1
	for i in flow.JOBS.size():
		if str(flow.JOBS[i]["title"]) == "転がる大岩・予告編":
			job = i
	flow.day = 2
	game.h_accept_job(job)
	await frames(20)
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	print("TRAPSHOT phase ", flow.phase)
	for aid in 2:
		for step in 3:
			beats.place_spot(aid, step, MARKS[aid][step])
	# 撮る場所（倉庫の東の壁ぎわ）に置いてある物を、よそへ寄せる（届いた物・モニターなど）
	var k := 0
	for p: Node in game.props.values():
		if p.absent or p.immovable or p.kind == "mark" or p in rig.parts or p == game.film or p in game.spots or p == flow.script_prop:
			continue
		var at: Vector3 = p.global_position
		if at.x < -7.5 and at.z > -3.5 and at.z < 6.5:
			place(p, Vector3(-4.0 + float(k % 8) * 1.2, 0.1, 8.5 + float(k / 8) * 1.2))
			k += 1
	print("TRAPSHOT moved aside ", k)
	# ---- 場面1の仕掛け：台車（カメラ）→ 壁の滑車 → 重り。重りは、支えのロープで吊っておく ----
	var dolly: RigidBody3D = game.stage.spawn("dolly", Vector3(-10.4, 0.05, 3.6), -PI * 0.5)
	await frames(30)
	var film: RigidBody3D = game.film
	place(film, dolly.global_position + Vector3(0, dolly.deck_top + 0.03, 0), 0.0)
	await frames(30)
	point_camera(film, Vector3(-12.4, 1.0, -1.0), 60.0)
	await frames(2)
	print("TRAPSHOT after aim: film yaw %.2f view dir %s cam_yaw %.2f" % [film.global_rotation.y, -film.view_cam.global_basis.z, film.cam_yaw])
	# カメラの足を、台車の荷台に接着する（一直線でない3点で、固く留まる）
	var deck_y: float = dolly.global_position.y + dolly.deck_top
	var pairs: Array = []
	for off: Vector3 in [Vector3(0.25, 0, 0), Vector3(-0.2, 0, 0.2), Vector3(-0.2, 0, -0.2)]:
		var w: Vector3 = Vector3(film.global_position.x, deck_y, film.global_position.z) + off
		pairs.append({"a": film.pid, "b": dolly.pid, "pa": film.to_local(w), "pb": dolly.to_local(w), "joined": true})
	game.adhesive.restore({"first": {}, "pairs": pairs})
	await frames(10)
	var pulley := part("pulley")
	rig.host_mount(pulley, Vector3(WALL_X, 2.4, 3.6), Vector3(1, 0, 0), null)
	await frames(3)
	var wheel: Vector3 = rig._wheel(pulley.pid)
	var bag1: RigidBody3D = game.stage.spawn("sandbag", Vector3(wheel.x + 0.15, 1.3, wheel.z), 0.0)
	await frames(1)
	var hold1: int = rig.host_add_row([bag1.pid, bag1.to_local(top_of(bag1) + Vector3(0, 0, -0.1))], [0, Vector3(WALL_X, 2.5, 2.8)], [])
	# 台車の真ん中の高さの前（引く向きが重心を通るので、台車が回らない）。少しゆるませて結ぶ（吊った重りが落ち着くまで、引かない）
	var side: Vector3 = dolly.center_global() + Vector3(-dolly.half.z - 0.05, 0.0, 0)
	var pull: int = rig.host_add_row([dolly.pid, dolly.to_local(side)], [bag1.pid, bag1.to_local(top_of(bag1))], [pulley.pid])
	rig.rows[pull]["len"] = float(rig.rows[pull]["len"]) + 0.1
	# ---- 場面2の仕掛け：罠の重りを、二人の立ち止まる所の先の壁から吊る ----
	var bag2: RigidBody3D = game.stage.spawn("sandbag", Vector3(WALL_X + 0.35, 1.75, -0.9), 0.0)
	await frames(1)
	var hold2: int = rig.host_add_row([bag2.pid, bag2.to_local(top_of(bag2))], [0, top_of(bag2) + Vector3(-0.3, 0.6, 0)], [])
	await frames(60)
	await light(Vector3(-12.6, 0, -1.0))
	me.global_position = Vector3(-12.4, 0.1, 6.0)
	place(flow.script_prop, me.global_position + Vector3(0.5, 0.0, 0.0))
	await frames(60)
	# ---- 本番 ----
	print("TRAPSHOT before take: film yaw %.2f view dir %s dolly yaw %.2f cam_yaw %.2f" % [film.global_rotation.y, -film.view_cam.global_basis.z, dolly.global_rotation.y, film.cam_yaw])
	game.h_take()
	# 班の誰かが、カウントダウンの終わりごろに、支えのロープに火を付ける（焼き切れるころに、二人が歩き出している）
	var lit := false
	for i in 400:
		if game.state == S.TAKE:
			break
		if not lit and game.state == S.COUNTDOWN and game.countdown_t < 1.1:
			rig.host_ignite(hold1, 0.25)
			lit = true
		await physics_frame
	if not lit:
		rig.host_ignite(hold1, 0.25)
	var x0: float = dolly.global_position.x
	await frames(20)
	await film_snap("1a_walk", "場面1：二人が歩き出す（支えのロープが燃えている）")
	var snapped := false
	for i in 300:
		await physics_frame
		if not snapped and x0 - dolly.global_position.x > 0.5:
			await film_snap("1b_track", "場面1：重りが落ちて、カメラ（台車）が二人と一緒に動く")
			snapped = true
		if beats.lit[0]:
			break
	print("TRAPSHOT scene1 lit ", beats.lit[0], " moved %.2f why %s" % [x0 - dolly.global_position.x, beats._top_reason(0)])
	for i in 200:
		if beats.holding:
			break
		await physics_frame
	# ---- 場転：カメラを、二人と罠が入る所へ寄せ直す ----
	game.adhesive.restore({"first": {}, "pairs": []})
	place(film, Vector3(-12.4, 0.05, 3.8), 0.0, false)
	await frames(30)
	point_camera(film, Vector3(-15.0, 1.1, -1.0), 62.0)
	await light(Vector3(-14.6, 0, -1.0))
	await frames(10)
	# 罠の重りのロープに火を付けてから、回す（燃え切るまでに、二人が印②で止まる）
	rig.host_ignite(hold2, 0.5)
	game.h_beat(1)
	for i in 240:
		if game.actors[0].beat_arrived() and game.actors[1].beat_arrived():
			break
		await physics_frame
	var dropped := false
	var y0: float = bag2.global_position.y
	await frames(2)
	await film_snap("2a_stop", "場面2：立ち止まる二人。壁ぎわで、罠のロープが燃えている")
	for i in 240:
		await physics_frame
		if not dropped and y0 - bag2.global_position.y > 0.9:
			await film_snap("2c_drop", "場面2：罠が作動。二人のそばに重りが落ちる")
			dropped = true
		if beats.lit[1] and dropped:
			break
	print("TRAPSHOT scene2 lit ", beats.lit[1], " why ", beats._top_reason(1))
	await frames(10)
	# 一覧（2×2〜3）
	var f := FileAccess.open(OUT + "captions.txt", FileAccess.WRITE)
	for s: Array in shots:
		f.store_line("%s\t%s" % [s[0], s[1]])
	f.close()
	quit(0)
