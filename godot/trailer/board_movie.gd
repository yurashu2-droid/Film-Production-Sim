extends SceneTree
## 依頼の掲示板（赤い布に吊るしたポスター。ui/poster_wall_3d.gd）の揺れを、動画に撮る。
##   Godot --path godot --resolution 1280x720 --fixed-fps 30 --write-movie out.avi --script res://trailer/board_movie.gd
## BOARD_MOVIE_START <コマ> から先が、掲示板を開いたあと
var game: Node


func _initialize() -> void:
	run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	game.production.day = 3
	game.open_menu("board")
	await frames(10)
	print("BOARD_MOVIE_START ", Engine.get_frames_drawn())
	await frames(100)
	game.production_hud._wall.pan(1)          # 次の依頼へ（壁を横に見て回る）
	await frames(70)
	game.production_hud._wall.pan(-1)
	await frames(50)
	print("BOARD_MOVIE_END ", Engine.get_frames_drawn())
	quit()
