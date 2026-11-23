extends SceneTree
# 接着剤の「支点」を撮る。白い板はカンペ（撮影のために、同じ物を何枚か作る）。
#   01〜03：2段に積んだ木箱（足場）の手前の面に板を当てて留め、手を離す。
#     左＝板の左上の角を1点だけ留める。留めた点を支点に回って、ぶら下がる。
#     右＝離れた3点（左上・右上・下のまん中）を留める。水平のまま固まる。
#   04：床に寝かせた板の端に箱馬を載せ、箱馬の底のまん中と板を1点だけ留めて、箱馬を持ち上げる。
#     箱馬の底の面が板を押さえるので、1点でも垂れない（面がつっかえる場所は、支えになる）。
#   05：床の木箱の手前の面に板を当てて左上の角を1点だけ留め、木箱を持ち上げる。板は留めた点からぶら下がる。
#   06：同じ形で離れた3点を留めて、木箱を持ち上げる。板はいっしょに動く。
#   godot --path godot --script res://tests/adhesive_shot.gd      （画面つきで動かす。画像は tests/shots/adhesive へ）
const OUT := "res://tests/shots/adhesive/"
const SPOTS := [Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1)]      # 板の左上・右上・下のまん中（1＝板の端）
var game: Node
var cam: Camera3D


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# 物理を止めてから撮る（待っている間に板が動かないように）
func snap(tag: String) -> void:
	paused = true
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	paused = false
	print("ADHESIVE_SHOT ", tag)


func view(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()


func caption(text: String, at: Vector3, size: int = 96) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = game.font
	label.font_size = size
	label.pixel_size = 0.004
	label.outline_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	game.add_child(label)
	return label


func new_board() -> RigidBody3D:
	var board: RigidBody3D = (load("res://scripts/cue_card.gd") as GDScript).new()
	board.build()
	game.stage._register(board, Vector3(0, 0.1, -9), 0.0)
	return board


# 2つの物を、いまの場所の1点（at）で留める
func pin(a: Node3D, b: Node3D, at: Vector3) -> void:
	var data: Dictionary = game.adhesive.snapshot()
	data.pairs.append({"a": a.pid, "b": b.pid, "pa": a.to_local(at), "pb": b.to_local(at), "joined": true})
	game.adhesive.restore(data)


# 板の裏の、spot（板のまん中から見た位置。1＝板の端）の所
func board_spot(board: Node3D, spot: Vector2) -> Vector3:
	return board.to_global(board.center + Vector3(spot.x * (board.half.x - 0.06), spot.y * (board.half.y - 0.06), -board.half.z))


# 板を1枚、上の木箱の手前の面に当てて、count 点で留める
func hang_board(board: RigidBody3D, top: Node3D, count: int) -> void:
	board.set_absent(false)
	board.restore([Vector3(top.global_position.x, top.global_position.y + 0.04, top.global_position.z + top.half.z + board.half.z + 0.003), Quaternion.IDENTITY, false])
	# 留めるまでは、手で持って当てているのと同じ（落ちない）
	board.gravity_scale = 0.0
	await frames(4)
	for i in count:
		pin(board, top, board_spot(board, SPOTS[i]))


func turned(board: Node3D, from: Basis = Basis.IDENTITY) -> float:
	return rad_to_deg(Quaternion(board.global_basis.orthonormalized()).angle_to(Quaternion(from.orthonormalized())))


func worst_gap() -> float:
	var worst := 0.0
	for m: Dictionary in game.adhesive.bond_metrics():
		worst = maxf(worst, m.gap)
	return worst


# 持った物の、目標からの位置のずれ（m）と向きのずれ（度）
func off_target(body: Node) -> Vector2:
	var goal: Array = game.hold_target(body.holder, body)
	return Vector2(body.center_global().distance_to(goal[0]), turned(body, goal[4]))


func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	game.production.set_physics_process(false)
	game.camera_switcher.set_process(false)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	game.input_locked = false
	game.adhesive.clear()
	for body: Node in game.props.values():
		body.set_absent(true)
	for actor: Node3D in game.actors:
		actor.set_physics_process(false)
		actor.global_position = Vector3(25, 0, 25)
	var player: Node = game.local_player()
	player.global_position = Vector3(0, 0.1, 11)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.fov = 50.0
	game.hud.visible = false
	game.production_hud.visible = false
	game.performance.visible = false

	# ---- 01〜03：木箱を2段に積んだ山を2つ。左は1点、右は3点で板を留める ----
	var tops: Array = []
	for x: float in [-2.1, 2.1]:
		game.stage.spawn_riser(Vector3(x, 0.02, 0), 0.0)
		tops.append(game.stage.spawn_riser(Vector3(x, 0.95, 0), 0.0))
	await frames(60)
	var boards: Array = [game.cue_cards.card, new_board()]
	await hang_board(boards[0], tops[0], 1)
	await hang_board(boards[1], tops[1], 3)
	var notes: Array = [caption("1点だけ留めた", tops[0].global_position + Vector3(0, 1.3, 0.56)), caption("離れた3点で留めた", tops[1].global_position + Vector3(0, 1.3, 0.56))]
	view(Vector3(0, 1.5, 5.4), Vector3(0, 1.2, 0))
	await frames(10)
	await snap("01_glued_held")
	# 手を離す
	var start: Vector3 = boards[1].global_position
	for board: RigidBody3D in boards:
		board.gravity_scale = 1.0
		board.sleeping = false
	await frames(22)
	print("ADHESIVE_SHOT swinging one_point_deg=", turned(boards[0]), " three_point_deg=", turned(boards[1]))
	await snap("02_one_point_swinging")
	var peak := 0.0
	var worst := 0.0
	for i in 400:
		await frames(1)
		peak = maxf(peak, turned(boards[0]))
		worst = maxf(worst, worst_gap())
	print("ADHESIVE_SHOT settled one_point_deg=", turned(boards[0]), " peak_deg=", peak, " spin=", boards[0].angular_velocity.length(),
		" three_point_deg=", turned(boards[1]), " three_point_moved_m=", boards[1].global_position.distance_to(start), " max_gap_m=", worst)
	await snap("03_settled")
	# 片付ける（次の場面に写り込まないように）
	game.adhesive.clear()
	for note: Label3D in notes:
		note.queue_free()
	for prop: Node in game.props.values():
		prop.set_absent(true)

	# ---- 04：箱馬の底のまん中と、床に寝かせた板を1点だけ留めて、箱馬を持ち上げる ----
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)      # 表を上にして寝かせる
	var plate: RigidBody3D = new_board()
	plate.restore([Vector3(9.0, 0.03, 0.0), Quaternion(flat), false])
	var box: Node = game.stage.spawn("applebox", Vector3(8.62, 0.06, -0.41))
	player.global_position = Vector3(7.5, 0.1, 0.9)
	player.aim_yaw = -0.7
	player.aim_pitch = -0.25
	await frames(60)
	pin(box, plate, box.to_global(box.center - Vector3(0, box.half.y, 0)))
	await frames(10)
	var lying: Basis = plate.global_basis
	game.h_grab(box.pid, box.center)
	for i in 6:
		game.h_hold_command("lift", 0.25)
	await frames(150)
	print("ADHESIVE_SHOT under box_y=", box.global_position.y, " plate_y=", plate.center_global().y, " plate_turned_deg=", turned(plate, lying), " gap_m=", worst_gap())
	var note: Label3D = caption("箱の底のまん中を1点留めて持ち上げた：\n底の面がつっかえるので、板は垂れない", Vector3(9.0, 2.35, -0.4), 64)
	view(Vector3(9.9, 2.7, 4.4), Vector3(8.8, 1.3, -0.3))
	await snap("04_carried_now")
	game.h_release()
	game.adhesive.clear()
	note.queue_free()
	box.set_absent(true)
	plate.set_absent(true)

	# ---- 05・06：床の木箱の手前の面に板を留めて、木箱を持ち上げる（1点：ぶら下がる／3点：いっしょに動く） ----
	player.global_position = Vector3(-11.3, 0.1, 0.4)
	player.aim_yaw = -PI * 0.5
	player.aim_pitch = 0.0
	for shot: Array in [[1, "05_carried_dangling", "木箱を持ち上げた：1点留めの板は\n留めた点からぶら下がる"], [3, "06_carried_rigid", "木箱を持ち上げた：離れた3点で留めた板は\nいっしょに動く"]]:
		var crate: Node = game.stage.spawn_riser(Vector3(-9, 0.02, 0), 0.0)
		var plank: RigidBody3D = new_board()
		plank.restore([Vector3(-9, 0.03, crate.half.z + plank.half.z + 0.003), Quaternion.IDENTITY, false])
		await frames(40)
		for i in int(shot[0]):
			pin(plank, crate, board_spot(plank, SPOTS[i]))
		await frames(10)
		var on_floor: float = turned(plank)
		game.h_grab(crate.pid, crate.center)
		for i in 5:
			game.h_hold_command("lift", 0.25)
		worst = 0.0
		for i in 240:
			await frames(1)
			worst = maxf(worst, worst_gap())
		var miss := off_target(crate)
		print("ADHESIVE_SHOT ", shot[1], " plank_deg on_floor=", on_floor, " lifted=", turned(plank), " crate_y=", crate.global_position.y,
			" crate_off_target_m=", miss.x, " crate_tilt_deg=", miss.y, " crate_speed=", crate.linear_velocity.length(), " max_gap_m=", worst)
		note = caption(shot[2], Vector3(-9, 2.95, 0.6), 64)
		view(Vector3(-8.0, 1.8, 5.3), Vector3(-9.2, 1.5, 0))
		await snap(shot[1])
		game.h_release()
		game.adhesive.clear()
		note.queue_free()
		crate.set_absent(true)
		plank.set_absent(true)
		await frames(5)

	current_scene = null
	game.queue_free()
	game = null
	root.get_node("Sfx").silence_all()
	await frames(8)
	quit(0)
