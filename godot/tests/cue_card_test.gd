extends SceneTree
var failed := false

func check(ok: bool, label: String) -> void:
	print("CUE_CARD_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func frames(count: int) -> void:
	for i in count: await physics_frame

func _initialize() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	run.call_deferred()

func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	var cards: Node = game.get("cue_cards")
	check(cards != null, "company provides a drawable cue card")
	if cards == null:
		quit(1)
		return
	game.production.phase = 4
	game._set_state(game.S.PREP)
	var card: Node = cards.card
	check(card.visual.scene_file_path == "res://assets/gear/Q07_Replaceable_Cue_Board.glb", "uses the supplied sketchbook model")
	var player: Node = game.local_player()
	player.global_position = Vector3(110,0.1,14)
	game.h_grab(card.pid)
	await frames(5)
	var start: Vector3 = player.global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = true
	root.push_input(event)
	await frames(2)
	check(cards.editor.opened and game.ui_blocking() and cards.editor.root.visible, "F opens paint while holding card")
	Input.action_press("move_forward")
	await frames(6)
	Input.action_release("move_forward")
	check(Vector2(player.global_position.x-start.x,player.global_position.z-start.z).length() < 0.03, "painting prevents walking")
	var sample_y := int(card.RESOLUTION.y*0.3)
	var canvas: Control = cards.editor.canvas
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	a.pressed = true
	a.position = canvas.size * Vector2(0.2,0.3)
	canvas._gui_input(a)
	var motion := InputEventMouseMotion.new()
	motion.position = canvas.size * Vector2(0.8,0.3)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(motion)
	cards.editor.flush()
	check(card.ink.get_pixel(512,sample_y).r < 0.2, "paint stroke immediately appears on physical card")
	check(card.surface.get_surface_override_material(card._ink_surface).albedo_texture == card.texture, "front face uses live drawing texture")
	# 持った物は、拾った向きのまま視点について回る（main.gd の hold_frame）。下を見ても、手元から見たカンペの向きは変わらない
	var level: Array = game.hold_target(player.peer_id,card)
	var view_level := Basis.from_euler(Vector3(player.aim_pitch,player.aim_yaw,0.0))
	player.aim_pitch = -0.9
	var carry: Array = game.hold_target(player.peer_id,card)
	var view_down := Basis.from_euler(Vector3(player.aim_pitch,player.aim_yaw,0.0))
	var drift: float = Quaternion(view_level.inverse() * (level[4] as Basis)).angle_to(Quaternion(view_down.inverse() * (carry[4] as Basis)))
	print("CUE_CARD_MEASURE 視点から見た向きのずれ=%.1f度" % rad_to_deg(drift))
	check(drift < 0.05, "the card keeps its place in the hands when looking down")
	check(carry[0].y > player.vis.grip_pos(false).y, "hands support lower part of card")
	var snapshot: Array = card.get_state()
	cards.h_clear(card.pid)
	check(card.ink.get_pixel(512,sample_y).r > 0.9, "clear erases card")
	card.apply_state(snapshot,true)
	check(card.ink.get_pixel(512,sample_y).r < 0.2, "snapshot restores drawing for late joins and replay")
	cards.editor.close()
	check(not game.ui_blocking() and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "closing paint restores gameplay input")
	game.host_release(card)
	check(player.held == 0, "card can be put down")
	print("CUE_CARD_TEST_FAIL" if failed else "CUE_CARD_TEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
