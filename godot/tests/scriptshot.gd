extends SceneTree
# 台本（1冊だけの小道具）と、持ったときに出るページを撮る。 godot --path godot --script res://tests/scriptshot.gd
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/script/%s%s.png" % [tag, OS.get_environment("UISHOT_SUFFIX")])


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/script"))
	var flow: Node = game.production
	var book: Node = flow.script_prop
	var me: Node = game.local_player()
	print("SCRIPTSHOT desk pos=", book.global_position)
	me.global_position = Vector3(72.6, 0.1, 2.6)
	me.aim_yaw = 0.0
	me.aim_pitch = -0.5
	for i in 30:
		await physics_frame
	var cam := Camera3D.new()
	cam.fov = 45.0
	game.add_child(cam)
	cam.global_position = Vector3(73.7, 1.9, 1.5)
	cam.look_at(book.global_position)
	cam.make_current()
	await snap("0_on_desk")
	cam.current = false
	me.cam.make_current()
	game.h_grab(book.pid)
	for i in 30:
		await physics_frame
	await snap("1_blank")
	game.h_release()
	flow.day = 2
	game.h_accept_job(3)
	for i in 30:
		await physics_frame
	print("SCRIPTSHOT after accept pos=", book.global_position, " holder=", book.holder)
	me.global_position = Vector3(72.6, 0.1, 2.6)
	for i in 20:
		await physics_frame
	game.h_grab(book.pid)
	for i in 30:
		await physics_frame
	await snap("2_kaiju")
	print("SCRIPTSHOT_OK held=", me.held == book.pid, " page=", game.production_hud.script_page.visible)
	quit()
