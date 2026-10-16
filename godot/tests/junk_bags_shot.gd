extends SceneTree
# ゴミ袋・ブルーシートの包みの見た目：廃材置き場で、袋を振って小道具を、包みを振って大道具を出したところを撮る。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/junk_bags_shot.gd
const OUT := "res://tests/shots/allprops/"
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
	for layer: Node in [game.get("hud"), game.get("production_hud")]:
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = false
	var jb: Node = game.hooks.feature("junk_bags")
	var me: Node3D = game.local_player()
	var trash: RigidBody3D = null
	var tarp: RigidBody3D = null
	for b: RigidBody3D in jb.bags:
		if b.kind == "trashbag" and trash == null:
			trash = b
		if b.kind == "tarpbundle" and tarp == null:
			tarp = b
	# 袋と包みを、会社の前の空いた所に並べる（撮りやすいように）。持つ人は奥に立ち、中身は手前（カメラのほう）へ出る
	var spot := Vector3(66.0, 0.05, 22.0)
	trash.restore([spot + Vector3(-1.2, 0, 0), Quaternion.IDENTITY, false])
	tarp.restore([spot + Vector3(1.6, 0, -0.2), Quaternion(Vector3.UP, 0.3), false])
	var bag2: RigidBody3D = jb.bags[3]
	bag2.restore([spot + Vector3(-2.2, 0, -0.6), Quaternion(Vector3.UP, 1.0), false])
	await frames(20)
	var eye := Camera3D.new()
	eye.fov = 48.0
	game.add_child(eye)
	eye.global_position = spot + Vector3(0.2, 2.3, 5.6)
	eye.look_at(spot + Vector3(0.2, 0.5, 0.6), Vector3.UP)
	eye.make_current()
	me.global_position = spot + Vector3(-1.2, 0.1, -1.2)
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "junk_1_bags.png")
	# ゴミ袋を持って、3回出す
	game.h_grab(trash.pid)
	await frames(5)
	for i in 3:
		me.global_position = trash.global_position + Vector3(0.6 * (i - 1), 0.0, -0.9)
		await frames(2)
		jb.h_shake(trash.pid)
		await frames(50)
	game.h_release()
	await frames(10)
	# 包みを持って、1回出す
	me.global_position = tarp.global_position + Vector3(0.0, 0.1, -1.3)
	await frames(3)
	game.h_grab(tarp.pid)
	await frames(5)
	jb.h_shake(tarp.pid)
	await frames(10)
	game.h_release()
	await frames(90)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "junk_2_out.png")
	print("JUNKSHOT OK")
	quit(0)
