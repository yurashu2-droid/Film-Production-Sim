extends SceneTree
# 見立ての荷札の見え方を撮る（役を付けた物の、前の上の角から垂れる紙の札）。
#   godot --path godot --fixed-fps 60 --script res://tests/cast_tag_shot.gd   （画面ありで流す。tests/shots/cast_tag/ に保存）
var game: Node
const OUT := "res://tests/shots/cast_tag/"


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String) -> Array:
	return game.props.values().filter(func(p: Node) -> bool: return p.kind == kind)


func snap(cam: Camera3D, from: Vector3, at: Vector3, name: String) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


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
	me.global_position = at + Vector3(0, 0.1, 2.4)
	var toilet: Node3D = of_kind("scrap_toilet")[0]
	var fish: Node3D = of_kind("fish")[0]
	toilet.restore([at + Vector3(0, 0.6, 0), Quaternion.IDENTITY, true])
	fish.restore([at + Vector3(1.4, 0.3, 0.2), Quaternion(Vector3.UP, -0.5), true])
	await frames(20)
	game.h_cast(toilet.pid, "monster")
	game.h_cast(fish.pid, "boom")
	await frames(10)
	print("tags ", game._cast_tags.size())
	var cam := Camera3D.new()
	cam.fov = 50
	root.add_child(cam)
	me.global_position = at + Vector3(4, 0.1, 4)
	await frames(4)
	await snap(cam, at + Vector3(0.6, 1.5, 2.6), at + Vector3(0.6, 0.5, 0), "pair")
	var c: Vector3 = toilet.center_global()
	await snap(cam, c + Vector3(0.35, 0.25, 1.0), c + Vector3(0.25, 0.1, 0), "close")
	print("CAST_TAG_SHOT_OK")
	quit(0)
