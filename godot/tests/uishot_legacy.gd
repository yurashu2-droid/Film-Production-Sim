extends SceneTree
# 撮影だけモード（main.tscn）の画面を撮る。出力 res://tests/shots/ui/legacy_<名前><接尾辞>.png
var game: Node
var suffix := ""
func _initialize() -> void:
	suffix = OS.get_environment("UISHOT_SUFFIX")
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(label: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://tests/shots/ui/legacy_%s%s.png" % [label, suffix])
	root.get_texture().get_image().save_png(path)
	print("UISHOT ", label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/ui"))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(60)
	for option in ["fx", "dolly"]: game.h_order_set(option, 1)
	game.order_cursor = 3
	await frames(10)
	await shot("order")
	game.h_order_confirm()
	await frames(60)
	await shot("prep")
	game.h_grab(game.clapper.pid)
	game.h_use()
	while game.state != game.S.TAKE: await frames(10)
	await frames(60)
	await shot("take")
	game.h_take()
	while game.state != game.S.RESULT: await frames(5)
	while game.hud.slate.mode != "": await frames(5)
	await frames(30)
	await shot("result")
	game.h_deliver(0)
	await frames(40)
	await shot("delivered")
	game.help_open = true
	await frames(10)
	await shot("help")
	print("UISHOT_LEGACY_OK")
	quit()
