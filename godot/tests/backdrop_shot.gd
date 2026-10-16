extends SceneTree
# グリーンバックの合成の見た目：現場で、撮影カメラの前に緑の布と役者（自分）を置き、背景フィルムなし・城・宇宙・海で撮る。
#   godot --path godot --fixed-fps 60 --script res://tests/backdrop_shot.gd   （画面を描くので headless では撮れない）
var game: Node


func _initialize() -> void:
	root.unfocusable = true
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	# 会社の備品の置き場所（仕掛けの道具・夜用フィルターの隣）
	var eye := Camera3D.new()
	eye.fov = 50.0
	game.add_child(eye)
	eye.global_position = Vector3(68.6, 1.7, 21.6)
	eye.look_at(Vector3(68.6, 0.2, 18.8), Vector3.UP)
	eye.make_current()
	game.local_player().global_position = Vector3(64.0, 0.1, 22.0)
	for layer: Node in [game.get("hud"), game.get("production_hud")]:
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = false
	await frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/parody/backdrop_kit.png")
	eye.queue_free()
	var flow: Node = game.production
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(40)
	var film: Node3D = game.film
	var C: Vector3 = flow.site_center()
	var gs: Node = null
	for p: Node in game.props.values():
		if p.kind == "greenscreen":
			gs = p
	print("SHOT greenscreen ", gs != null, " absent ", gs.absent if gs != null else null)
	var yaw := float(OS.get_environment("GS_YAW")) if OS.get_environment("GS_YAW") != "" else 0.0
	film.restore([C + Vector3(0, 0.05, 4.0), Quaternion.IDENTITY, false])
	if gs != null:
		if gs.absent:
			gs.set_absent(false)
		gs.restore([C + Vector3(0, 0.05, -0.5), Quaternion(Vector3.UP, deg_to_rad(yaw)), true])
	var me: Node3D = game.local_player()
	me.global_position = C + Vector3(0.5, 0.1, 1.4)
	await frames(40)
	var bd: Node = game.hooks.feature("backdrop")
	for theme: String in ["none", "castle", "space", "sea"]:
		game.host_ev("backdrop", [{} if theme == "none" else {film.pid: theme}])
		await frames(8)
		await RenderingServer.frame_post_draw
		film.view.get_texture().get_image().save_png("res://tests/shots/parody/backdrop_%s.png" % theme)
	print("BACKDROPSHOT OK")
	quit(0)
