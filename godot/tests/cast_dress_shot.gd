extends SceneTree
# 見立ての飾りの見え方を、役ごとに撮る（cast_dress.gd）。物を1つずつ空き地へ出して、飾りを付けて、正面の斜めから撮る。
#   godot --path godot --fixed-fps 60 --resolution 640x480 --script res://tests/cast_dress_shot.gd   （画面ありで流す。tests/shots/cast_dress/ に保存）
#   役と物の組は PAIRS。最後に、役に合わない物（★1）の曲がった飾りも撮る
var game: Node
const OUT := "res://tests/shots/cast_dress/"
const CastDress := preload("res://scripts/cast_dress.gd")
const PAIRS := [
	["monster", "scrap_toilet"], ["moon", "scrap_pie"], ["castle", "scrap_vending"], ["city", "scrap_phone"], ["boom", "fish"],
	["ruins", "scrap_column"], ["relic", "scrap_idol"], ["bigrock", "trashbag"], ["door", "scrap_fridge"], ["xmas", "scrap_cactus"],
	["bike", "applebox"], ["woods", "rock"], ["ship", "scrap_tub"], ["sea", "scrap_fountain"], ["roof", "scrap_kiosk"],
	["agent", "scrap_vending"], ["steps", "riser"], ["summit", "rock"], ["noodle", "basket"], ["kettle", "scrap_poop"],
	["car", "tarpbundle"], ["street", "scrap_kiosk"],
]


func _initialize() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func pick(kind: String) -> Node3D:
	var any: Node3D = null
	for p: Node in game.props.values():
		if p.absent or p.immovable or p.fixed or p.holder != 0:
			continue
		if p.kind == kind:
			return p
		var long := maxf(p.half.x, maxf(p.half.y, p.half.z))
		if any == null and long > 0.25 and long < 0.8 and p.kind.begins_with("scrap_"):
			any = p
	return any


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var me: Node3D = game.local_player()
	var at := Vector3(70.0, 0.0, 11.0)
	me.global_position = at + Vector3(6, 0.1, 6)
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	var shots := PAIRS.duplicate()
	shots.append(["monster", "scrap_lamp", 0])
	for i in shots.size():
		var role: String = shots[i][0]
		var prop: Node3D = pick(str(shots[i][1]))
		if prop == null:
			print("NO PROP ", shots[i][1])
			continue
		var home: Vector3 = prop.global_position
		var home_rot: Quaternion = prop.quaternion
		prop.restore([at + Vector3(0, prop.half.y + 0.3, 0), Quaternion.IDENTITY, true])
		await frames(40)
		var dress := CastDress.new()
		prop.add_child(dress)
		dress.build(prop, role, int(shots[i][2]) if shots[i].size() > 2 else 2, game.font, prop.pid, game.cast_face_side(prop, prop.global_transform * (prop.center + Vector3(0.3, 0, 2.0))))
		var c: Vector3 = prop.center_global()
		var size := maxf(prop.half.x, maxf(prop.half.y, prop.half.z))
		cam.global_position = c + prop.global_basis * Vector3(size * 1.6, size * 1.3, size * 3.2) + Vector3(0, 0.3, 0)
		cam.look_at(c + Vector3(0, size * 0.25, 0))
		cam.make_current()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var name := "%02d_%s_%s%s" % [i, role, prop.kind, "_misfit" if shots[i].size() > 2 else ""]
		root.get_texture().get_image().save_png(OUT + name + ".png")
		print("SHOT ", name, " pieces=", dress.get_child_count())
		dress.queue_free()
		prop.restore([home, home_rot, true])
		await frames(5)
	print("CAST_DRESS_SHOT_OK")
	quit(0)
