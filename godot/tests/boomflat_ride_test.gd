extends SceneTree
# 爆炎の書割（boom_flat.gd）を荷台に積むと、荷台の上にある間は「積んだまま」で、落ちた扱いにならないか。
# 書割の center（寝ている板の真ん中）は土台より 0.6 m 前に出ているので、落ちたかは当たり判定の箱（土台）の中心で見る（prop.gd の ride_point）。
# あわせて、F で積むときの近さは、軽トラのいまの位置で見る（production_main.gd の h_load_truck）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/boomflat_ride_test.gd
var game: Node
var flow: Node
var me: Node
var truck: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("BOOMFLAT_RIDE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


# 西側に立って、持った物を F で積む。turn＝持つ向き、along＝軽トラに沿った位置
func load_from_west(prop: Node, turn: float, along: float) -> bool:
	me.global_position = truck.global_transform * Vector3(-2.6, 0.1, along)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(-1.7, 0.6, along), Quaternion(Vector3.UP, turn), false])
	await frames(2)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(2)
	return prop.rider_of == truck.pid


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(20)
	flow = game.production
	me = game.local_player()
	truck = game.truck
	game.h_accept_job(0)
	await frames(30)
	var flat: Node = of_kind("boomflat")[0]
	# 土台の中心と center は、0.6 m ずれている（ずれていなければ、この確認は意味が無い）
	check(flat.ride_point().distance_to(flat.center_global()) > 0.5, "the flat's collider centre is not its center (%.2f m apart)" % flat.ride_point().distance_to(flat.center_global()))
	# 向きを変えて何度か積む。積めた向きでは、しばらく置いても積んだままのはず
	var tried := 0
	var stayed := 0
	for turn: float in [PI * 0.5, -PI * 0.5, 0.0, PI]:
		if flat.rider_of != 0:
			game.host_unload(flat)
		if not await load_from_west(flat, turn, -0.6):
			game.h_release()
			await frames(4)
			continue
		tried += 1
		await frames(120)
		var c: Vector3 = truck.to_local(flat.ride_point())
		var over: bool = absf(c.x - truck.deck_c.x) < truck.deck_half.x and absf(c.z - truck.deck_c.y) < truck.deck_half.y and c.y > truck.deck_top - 0.2
		if over and flat.rider_of == truck.pid:
			stayed += 1
		else:
			print("  turn=%.2f rider=%d base=%s" % [turn, flat.rider_of, str(c)])
	check(tried >= 1 and stayed == tried, "the boom flat stays loaded while its base is on the deck (%d of %d)" % [stayed, tried])
	# 荷台の端に寄せて置く：土台は荷台の上、寝ている板（center）は側板の外へ出る向き。それでも落ちた扱いにならない
	if flat.rider_of == 0:
		await load_from_west(flat, PI * 0.5, -0.6)
		game.h_release()
		await frames(4)
	var edge_at := Vector3(truck.deck_c.x - (truck.deck_half.x - 0.3), truck.deck_top + 0.01, truck.deck_c.y)
	flat.restore([truck.global_transform * edge_at, truck.global_basis.get_rotation_quaternion() * Quaternion(Vector3.UP, PI * 0.5), false])
	flat.rider_of = truck.pid
	await frames(60)
	var base_c: Vector3 = truck.to_local(flat.ride_point())
	var board_c: Vector3 = truck.to_local(flat.center_global())
	check(absf(base_c.x - truck.deck_c.x) < truck.deck_half.x and absf(board_c.x - truck.deck_c.x) > truck.deck_half.x + 0.25, "at the deck edge, the base is on the deck and the lying board sticks out (base x=%.2f, board x=%.2f)" % [base_c.x, board_c.x])
	check(flat.rider_of == truck.pid, "the boom flat at the deck edge is still loaded (rider=%d)" % flat.rider_of)

	# 軽トラが家の位置からずれていても、そのそばに立てば F で積める（近さは軽トラのいまの位置で見る）
	if flat.rider_of != 0:
		game.host_unload(flat)
	var box: Node = of_kind("carton")[0]
	truck.global_position = truck.global_position + Vector3(0, 0, 6.0)
	await frames(10)
	var moved: bool = await load_from_west(box, 0.0, 0.0)
	check(moved, "next to the truck parked away from its home spot, F still loads (%s)" % str(truck.global_position))

	print("BOOMFLAT_RIDE_TEST_FAIL" if failed else "BOOMFLAT_RIDE_TEST_OK")
	quit(1 if failed else 0)
