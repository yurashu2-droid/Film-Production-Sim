extends SceneTree
# 一時メニュー（Esc）の画面を撮る：マウスの感度のつまみが見えるか。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/menushot.gd
const OUT := "res://tests/shots/menu/"


func _initialize() -> void:
	root.unfocusable = true
	run.call_deferred()


func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game.open_menu("pause")
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "pause.png")
	print("MENUSHOT pause")
	quit()
