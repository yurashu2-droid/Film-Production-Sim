extends SceneTree
# 準備中の見立ての見え方を撮る：飾り（映画にも映る）と、物の上の役の名前（制作班にだけ）。
#   godot --path godot --fixed-fps 60 --resolution 1280x720 --script res://tests/cast_name_shot.gd   （画面ありで流す。tests/shots/cast_name/ に保存）
var game: Node
const OUT := "res://tests/shots/cast_name/"


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String) -> Node3D:
	for p: Node in game.props.values():
		if p.kind == kind and not p.absent:
			return p
	return null


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju":
			game.h_accept_job(i)
			break
	flow.phase = 2
	var me: Node3D = game.local_player()
	var at: Vector3 = flow.HOME_TRUCK + Vector3(-4, 0, 3)
	var toilet := of_kind("scrap_toilet")
	var fish := of_kind("fish")
	var kiosk := of_kind("scrap_kiosk")
	toilet.restore([at + Vector3(0, 0.6, 0), Quaternion.IDENTITY, true])
	fish.restore([at + Vector3(1.3, 0.3, 0.3), Quaternion(Vector3.UP, -0.4), true])
	kiosk.restore([at + Vector3(-1.8, 0.6, -0.3), Quaternion.IDENTITY, true])
	await frames(30)
	# 物の正面側から役を付ける（顔はこちら側に付く）
	me.global_position = at + Vector3(0, 0.1, 2.2)
	await frames(2)
	for p: Node3D in [toilet, fish, kiosk]:
		var face: int = game.cast_face_side(p, me.global_position)
		flow.cast_set(p.pid, {"scrap_toilet": "monster", "fish": "boom", "scrap_kiosk": "city"}[p.kind], face)
	me.global_position = at + Vector3(5, 0.1, 5)
	await frames(20)
	var cam := Camera3D.new()
	cam.fov = 50
	root.add_child(cam)
	cam.global_position = at + Vector3(0.2, 1.7, 3.6)
	cam.look_at(at + Vector3(-0.2, 0.6, 0))
	cam.make_current()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "prep.png")
	print("names ", game._cast_names.size(), " dress ", game._cast_dress.size())
	print("CAST_NAME_SHOT_OK")
	quit(0)
