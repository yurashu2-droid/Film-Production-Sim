extends SceneTree
# 見立ての飾りの、今の方式（左）と改良版（右：場所を細かく選ぶ・平たい飾りはデカール）を、同じ物・同じ向きで並べて撮る。
#   godot --path godot --fixed-fps 60 --resolution 640x480 --script res://tests/cast_dress_compare.gd   （画面ありで流す。tests/shots/cast_dress_compare/ に保存）
var game: Node
const OUT := "res://tests/shots/cast_dress_compare/"
const CastDress := preload("res://scripts/cast_dress.gd")
const PAIRS := [
	["moon", "boulder"], ["moon", "scrap_pie"], ["city", "scrap_column"], ["city", "scrap_vending"],
	["ruins", "scrap_column"], ["relic", "scrap_idol"], ["bigrock", "rock"], ["door", "scrap_fridge"],
	["monster", "scrap_crane"], ["agent", "scrap_crane"], ["street", "scrap_kiosk"], ["monster", "scrap_toilet"],
]


func _initialize() -> void:
	create_timer(300).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func pick(kind: String) -> Node3D:
	for p: Node in game.props.values():
		if p.kind == kind and not p.absent and p.holder == 0:
			return p
	return null


func grab(cam: Camera3D) -> Image:
	cam.make_current()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


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
	me.global_position = at + Vector3(7, 0.1, 7)
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	for i in PAIRS.size():
		var role: String = PAIRS[i][0]
		var prop: Node3D = pick(str(PAIRS[i][1]))
		if prop == null:
			print("NO PROP ", PAIRS[i][1])
			continue
		var home: Vector3 = prop.global_position
		var home_rot: Quaternion = prop.quaternion
		var was_fixed: bool = prop.fixed
		prop.restore([at + Vector3(0, prop.half.y + 0.3, 0), Quaternion.IDENTITY, true])
		await frames(40)
		var c: Vector3 = prop.center_global()
		var size := maxf(prop.half.x, maxf(prop.half.y, prop.half.z))
		cam.global_position = c + prop.global_basis * Vector3(size * 1.4, size * 1.1, size * 3.0) + Vector3(0, 0.3, 0)
		cam.look_at(c + Vector3(0, size * 0.2, 0))
		var side: int = game.cast_face_side(prop, cam.global_position)
		var shots: Array[Image] = []
		for fit: bool in [false, true]:
			var dress := CastDress.new()
			prop.add_child(dress)
			dress.build(prop, role, 2, game.font, prop.pid, side, fit)
			shots.append(await grab(cam))
			dress.free()
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var both := Image.create(w * 2 + 6, h, false, shots[0].get_format())
		both.fill(Color(1, 1, 1))
		both.blit_rect(shots[0], Rect2i(0, 0, w, h), Vector2i(0, 0))
		both.blit_rect(shots[1], Rect2i(0, 0, w, h), Vector2i(w + 6, 0))
		var name := "%02d_%s_%s" % [i, role, prop.kind]
		both.save_png(OUT + name + ".png")
		print("SHOT ", name)
		prop.restore([home, home_rot, was_fixed])
		await frames(5)
	print("CAST_DRESS_COMPARE_OK")
	quit(0)
