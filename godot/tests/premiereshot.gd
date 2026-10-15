extends SceneTree
# 試写会の画面を撮る：流している間（依頼主の反応）と、ギャラの読み上げ。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/premiereshot.gd
const OUT := "res://tests/shots/premiere/"


func _initialize() -> void:
	root.unfocusable = true
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("PREMIERESHOT ", name)


func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true
	while not game.startup_complete:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await frames(20)
	var flow: Node = game.production
	var premiere: Node = game.hooks.feature("premiere")
	game.h_accept_job(0)
	await frames(20)
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	game.h_take()
	for i in 400:
		if game.state == game.S.TAKE:
			break
		await physics_frame
	await frames(240)
	game._cut()
	await frames(5)
	premiere._times[0] = [0.5, -1.0, -1.0]
	game.request_deliver(0)
	await frames(60)
	await snap("screening")
	game.h_stop_replay()
	for i in 600:
		if premiere._tally_done:
			break
		await process_frame
	await frames(10)
	await snap("tally")
	quit()
