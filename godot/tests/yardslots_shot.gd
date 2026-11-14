extends SceneTree
# 廃材置き場の置き方を撮る：物が、置き場の山（パレット・布の山・棚）や隣の物に重なっていないかを目で見る。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/yardslots_shot.gd
#   見たい場所を足すなら：-- --at=<ヤードの x>,<ヤードの z>（置き場所の表 production_yard_slots.gd と同じ座標）
#   画面つきで動かす（窓は画面の外に出す）。出力は tests/shots/yard_slots
#   （拠点全体の見え方を撮るのは tests/yardshot.gd）
const OUT := "res://tests/shots/yard_slots/"
const Yard := preload("res://scripts/production_yard.gd")
# 見る場所（ヤードの座標）：名前, 中心, 見る幅（m）
const SPOTS := [
	["stack_corner", Vector2(-3.2, 3.2), 5.0],     # 布の山のまわり（書割・足場）
	["west_half", Vector2(-6.0, 3.0), 13.0],
	["east_half", Vector2(6.0, 3.0), 13.0],
	["whole", Vector2(0.0, 1.0), 27.0],
]
var game: Node
var cam: Camera3D


func _initialize() -> void:
	root.unfocusable = true
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(tag: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	print("YARDSLOTS_SHOT ", tag)


# 真上から（上が、入口と反対の奥＝ヤードの -z）
func top(center: Vector2, width: float) -> void:
	var at := Yard.to_world(center, 0.0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = width
	cam.global_position = at + Vector3(0, 14.0, 0)
	cam.look_at(at, Yard.xform().basis * Vector3(0, 0, -1))


# 斜め上から。from は、中心から見たカメラの位置（ヤードの座標の向き。+z が入口側）
func tilt(center: Vector2, from: Vector3) -> void:
	var at := Yard.to_world(center, 0.4)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 50.0
	cam.global_position = at + Yard.xform().basis * from
	cam.look_at(at)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true
	while not game.startup_complete:
		await process_frame
	await frames(120)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	cam = Camera3D.new()
	game.add_child(cam)
	cam.make_current()
	game.hud.visible = false
	var spots: Array = SPOTS.duplicate()
	for flag: String in OS.get_cmdline_user_args():
		if flag.begins_with("--at="):
			var xz := flag.trim_prefix("--at=").split_floats(",")
			spots = [["at", Vector2(xz[0], xz[1]), 5.0]]
	for spot: Array in spots:
		top(spot[1], spot[2])
		await snap("%s_top" % spot[0])
		if float(spot[2]) <= 6.0:
			tilt(spot[1], Vector3(3.2, 2.6, 3.4))
			await snap("%s_from_gate" % spot[0])
			tilt(spot[1], Vector3(-3.4, 2.4, -3.0))
			await snap("%s_from_back" % spot[0])
	print("YARDSLOTS_SHOT_DONE")
	quit()
