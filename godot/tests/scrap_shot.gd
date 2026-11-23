extends SceneTree
# 廃材置き場の追加小道具のスクリーンショット（実ウィンドウで実行）。
# godot --path godot --script res://tests/scrap_shot.gd  →  tests/shots/scrap/*.png
const Scrap := preload("res://scripts/production_scrap.gd")
var game: Node
var cam: Camera3D
var by_kind := {}

func _initialize() -> void:
	run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func shot(name: String, from: Vector3, look: Vector3, fov: float = 60.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(look, Vector3.UP)
	cam.make_current()
	await frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tests/shots/scrap/%s.png" % name))
	print("SHOT ", name)

func hold(kind: String, pos: Vector3, yaw: float) -> void:
	var p: RigidBody3D = by_kind[kind]
	p.set_fixed(true)
	p.global_position = pos
	p.rotation = Vector3(0, yaw, 0)

func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(120)
	game.hud.root.visible = false
	for layer in game.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for pid in game.props:
		by_kind[game.props[pid].kind] = game.props[pid]
	cam = Camera3D.new()
	cam.far = 200.0
	game.add_child(cam)
	# (a) 敷地の全体
	await shot("a_overview", Vector3(54, 9.0, 16.0), Vector3(54, 0.0, 28.5), 62.0)
	await shot("a_overview_wide", Vector3(54, 14.0, 12.0), Vector3(54, 0.0, 27.0), 70.0)
	# (b) グループごと
	await shot("b_city", Vector3(54.5, 1.7, 20.5), Vector3(54.5, 0.6, 25.0), 62.0)
	await shot("b_city_left", Vector3(47.0, 1.5, 21.0), Vector3(49.5, 0.6, 25.0), 62.0)
	await shot("b_city_right", Vector3(61.0, 1.5, 21.0), Vector3(58.5, 0.6, 25.0), 62.0)
	await shot("b_monsters", Vector3(49.5, 1.5, 24.5), Vector3(49.5, 0.5, 28.5), 62.0)
	await shot("b_dressing", Vector3(58.0, 1.5, 24.0), Vector3(58.0, 0.5, 28.5), 62.0)
	await shot("b_castle_tree", Vector3(49.5, 1.6, 27.0), Vector3(49.0, 0.9, 32.0), 62.0)
	# (c) 遠近法のデモ：低いカメラの1m手前にトマト怪獣、3〜5m先にミニチュアの街
	for kind in by_kind:
		var p: RigidBody3D = by_kind[kind]
		if kind.begins_with("scrap_") or kind == "tomato_monster":
			p.set_fixed(true)
	var o := Vector3(64.0, 0.0, 5.0)   # カメラの足元
	hold("tomato_monster", o + Vector3(-0.75, 0.0, 1.2), PI)
	var city := [["scrap_crane", 0.4, 4.4], ["scrap_clock", -0.4, 3.2], ["scrap_kiosk", 1.4, 3.0], ["scrap_chimney", 2.6, 3.8],
		["scrap_lamp", 3.4, 3.1], ["scrap_bridge", 1.0, 4.9], ["scrap_bus", -1.6, 4.2]]
	var used := {}
	for c in city:
		if used.has(c[0]):
			continue
		used[c[0]] = true
		hold(c[0], o + Vector3(c[1], 0.0, c[2]), PI)
	await frames(10)
	await shot("c_forced_perspective", o + Vector3(0.0, 0.3, 0.0), o + Vector3(1.0, 0.7, 5.0), 80.0)
	await shot("c_forced_perspective_side", o + Vector3(-3.5, 1.4, -1.0), o + Vector3(0.0, 0.5, 3.0), 55.0)
	quit()
