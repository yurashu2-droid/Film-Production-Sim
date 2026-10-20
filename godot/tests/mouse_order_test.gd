extends SceneTree
# 発注画面が本物のマウスで操作できるかを確かめる（画面つきで動かす）。
#   godot --path godot --script res://tests/mouse_order_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("MOUSE_ORDER_CHECK ", what, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move)
	await process_frame
	for down: bool in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = at
		b.global_position = at
		root.push_input(b)
		await process_frame
	for i in 6:
		await process_frame


func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	# 掲示板の依頼カード → 打ち合わせ → 受ける、までをマウスだけで
	game.open_menu("board")
	for i in 20:
		await process_frame
	await click(center(game.production_hud._wall.button_for(game.production.offered()[0])))
	check(game.menu_open == "brief", "clicking a job card opens the briefing")
	for i in 20:
		await process_frame
	await click(center(game.production_hud.briefing.accept))
	for i in 10:
		await process_frame
	check(game.production.phase == 2 and game.menu_open == "", "accept button in the briefing starts the job")
	game.h_open_order()
	for i in 30:
		await process_frame
	check(game.hud.catalog.visible, "catalog is open")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "cursor is shown on the catalog")
	var rows: Array = game.hud._opt_rows
	await click(center(rows[3]["box"]))
	check(int(game.order.get("dolly", 0)) == 1, "clicking a card adds it")
	await click(center(rows[3]["box"]))
	check(int(game.order.get("dolly", 0)) == 0, "clicking again removes it")
	await click(center(rows[1]["box"]))
	await click(center(rows[2]["plus"]))
	check(int(game.order.get("refill", 0)) == 1, "plus button adds a refill")
	await click(center(game.hud._order_button))
	for i in 10:
		await process_frame
	check(game.production.phase == 2 and game.production.expenses == 400, "confirm button closes the order (%d)" % game.production.expenses)
	print("MOUSE_ORDER_TEST_FAIL" if failed else "MOUSE_ORDER_TEST_OK")
	quit(1 if failed else 0)
