extends SceneTree
# Route real viewport events through the home screen and gameplay HUD.
var failed := false

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	print("CAMERA_INPUT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func mouse_button(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)

func motion(point: Vector2, buttons: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(40, -15)
	event.screen_relative = event.relative
	event.button_mask = buttons
	root.push_input(event, true)

func camera_moves(game: Node, label: String) -> void:
	var player: Node = game.local_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for point in [Vector2(800,450), Vector2(1300,450)]:
		var before := Vector2(player.aim_yaw, player.aim_pitch)
		motion(point)
		var delta: Vector2 = Vector2(player.aim_yaw, player.aim_pitch) - before
		# 視点の回り方は感度のつまみ（sens_scale、user://settings.cfg に残る）で変わるので、今の倍率から期待値を出す
		var step: float = player.MOUSE_SENS * player.sens_scale
		var want := Vector2(-40.0 * step, 15.0 * step)
		check(delta.is_equal_approx(want), label + " camera responds over HUD at " + str(point) + " delta=" + str(delta) + " want=" + str(want))
	await frames(2)
	check(is_equal_approx(player.head.rotation.y, player.aim_yaw) and player.cam.current, label + " active camera follows aim")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("CAMERA_INPUT_TEST_FAIL requires a graphics window")
		quit(2)
		return
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(20)
	menu.solo_button.pressed.emit()
	while menu.game_node == null or not menu.game_node.startup_complete or menu._transition.active:
		await frames(1)
	var game: Node = menu.game_node
	await camera_moves(game, "office")
	game.h_accept_job(0)
	game.h_open_order()
	game.h_order_confirm()
	await frames(20)
	await camera_moves(game, "packing")
	# 歩いている間は、押せる画面を何も出さない。軽トラで開いたときだけマウスで押せる
	check(not game.production_hud._packing.visible and not game.wants_cursor(), "walking shows no clickable panel and keeps the mouse captured")
	game.local_player().position = game.production.HOME_TRUCK + Vector3(-3,0.1,0)
	await frames(3)
	check(game.station() == "packing", "truck offers the packing checklist")
	game.open_menu("packing")
	await frames(3)
	check(game.production_hud._packing.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "opening the checklist shows the cursor without pressing Esc")
	var character_button: Control = game.production_hud._pack_character
	mouse_button(character_button.get_global_rect().get_center())
	check(game.character_open, "checklist button opens character picker with the mouse")
	game.close_menu()
	var player: Node = game.local_player()
	var before := Vector2(player.aim_yaw, player.aim_pitch)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	motion(Vector2(800,450))
	check(Vector2(player.aim_yaw, player.aim_pitch).is_equal_approx(before), "character picker blocks camera input")
	game.set_character_menu(false)
	await frames(3)
	var carton: Node
	for prop: Node in game.props.values():
		if prop.kind == "carton":
			carton = prop
			break
	player.held = carton.pid
	var hold_before: float = player.hold_yaw
	before = Vector2(player.aim_yaw, player.aim_pitch)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	motion(Vector2(800,450), MOUSE_BUTTON_MASK_RIGHT)
	# 画面で見たままに回す（player.gd）：右へ動かすと上向きの軸まわりに＋へ回る。感度のつまみの倍率も掛かる
	var hold_want: float = 40.0 * player.MOUSE_SENS * player.sens_scale * 2.0
	check(is_equal_approx(player.hold_yaw-hold_before,hold_want) and Vector2(player.aim_yaw,player.aim_pitch).is_equal_approx(before), "right drag rotates held object without turning camera spin=" + str(player.hold_yaw-hold_before) + " want=" + str(hold_want))
	player.held = 0
	player.position = game.production.HOME_TRUCK + Vector3(-3,0.1,0)
	await frames(3)
	game.h_depart()
	await create_timer(8.5).timeout
	check(game.production.phase == 4, "journey reaches filming location")
	await camera_moves(game, "site")
	print("CAMERA_INPUT_TEST_FAIL" if failed else "CAMERA_INPUT_TEST_OK")
	quit(1 if failed else 0)
