extends SceneTree
# 事務所の奥のアップグレード画面を撮る。照準を合わせて左クリックで買えることも確かめる。
#   godot --path godot --script res://tests/lockershot.gd
var game: Node
var failed := false


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("DISPLAY_CHECK ", what, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func snap(tag: String) -> void:
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/up/%s.png" % tag)


# 画面の中の枠の中心へ、プレイヤーの視線を向ける
func aim_at(id: String) -> void:
	var flow: Node = game.production
	var me: Node = game.local_player()
	var disp: Node3D = flow.display
	var box: Control = disp._cards[id]["box"]
	var c: Vector2 = box.get_global_rect().get_center()
	var local := Vector3((c.x / disp.VIEW.x - 0.5) * disp.SCREEN.x, (0.5 - c.y / disp.VIEW.y) * disp.SCREEN.y, 0.0)
	var target: Vector3 = disp._quad.global_transform * local
	for step in 40:
		var cam := root.get_camera_3d()
		var want: Vector3 = (target - cam.global_position).normalized()
		var have: Vector3 = -cam.global_basis.z
		me.aim_yaw += (atan2(-want.x, -want.z) - atan2(-have.x, -have.z)) * 0.6
		me.aim_pitch += (asin(want.y) - asin(have.y)) * 0.6
		await physics_frame
		await process_frame


func left_click() -> void:
	for down: bool in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = Vector2(root.size) * 0.5
		root.push_input(b)
		await process_frame
	for i in 10:
		await process_frame


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
	flow.wallet = 1000
	me.global_position = Vector3(69.6, 0.1, -3.2)
	me.aim_yaw = 0.0
	me.aim_pitch = 0.1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 40:
		await physics_frame
	await snap("a_display")
	await aim_at("studio")
	check(flow.display.hover == "studio", "aiming at a card highlights it (%s)" % flow.display.hover)
	await snap("b_aim_studio")
	await left_click()
	check(int(flow.levels["studio"]) == 1 and flow.wallet == 400, "left click buys the aimed upgrade (wallet %d)" % flow.wallet)
	await snap("c_bought_studio")
	await aim_at("car")
	await left_click()
	check(int(flow.levels["car"]) == 0 and flow.wallet == 400, "cannot buy what the company cannot afford")
	await aim_at("plan")
	await left_click()
	check(int(flow.levels["plan"]) == 1 and flow.wallet == 100, "a second click buys another track")
	await snap("d_bought_plan")
	print("LOCKERSHOT_FAIL" if failed else "LOCKERSHOT_OK", " levels=", flow.levels, " lease=", flow.lease_time(), " place=", flow.location_name())
	quit(1 if failed else 0)
