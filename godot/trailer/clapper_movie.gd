extends SceneTree
## 本番の合図のカチンコ（ui/clapper_overlay.gd）が入ってきてから消えるまでを、動画に撮る。
## Godot の動画書き出し（--write-movie）と一緒に使う。決まった速さ（--fixed-fps）で回すので、動きの速さは本物と同じになる。
##   Godot --path godot --resolution 1280x720 --fixed-fps 30 --write-movie out.avi --script res://trailer/clapper_movie.gd
## 何コマ目から撮影したい所かを CLAPPER_MOVIE_START <コマ> で出す（前の準備のコマは、あとで切る）
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
	await frames(30)
	var flow: Node = game.production
	flow.accept(0)
	await frames(10)
	flow.depart()
	await frames(10)
	flow.arrive()
	await frames(90)
	print("CLAPPER_MOVIE_START ", Engine.get_frames_drawn())
	await frames(12)
	game._take_or_cut(1)
	await frames(180)
	print("CLAPPER_MOVIE_END ", Engine.get_frames_drawn())
	quit()
