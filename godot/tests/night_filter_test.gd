extends SceneTree
# 夜用フィルター（scripts/features/night_filter.gd）：持って撮影カメラを見て F で付けると、そのカメラの映像だけが夜になる。もう一度で外す。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/night_filter_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("NIGHT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var nf: Node = game.hooks.feature("night_filter")
	check(nf != null and nf.gel != null, "夜用フィルター（青いゲル）が、会社の備品にある")
	var flow: Node = game.production
	var me: Node3D = game.local_player()
	game.h_accept_job(int(flow.debut_job()))
	await frames(20)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30)
	var film: Node3D = game.film
	me.global_position = film.global_position + Vector3(1.2, 0.1, 0.8)
	nf.gel.restore([me.global_position + Vector3(0.4, 0.1, 0.0), Quaternion.IDENTITY, false])
	await frames(5)
	game.h_grab.rpc_id(1, nf.gel.pid)
	await frames(3)
	check(nf.gel.holder == me.peer_id, "フィルターを持った")
	me.target = film
	check(str(nf.hook_hud(me, "", "").get("keys_all", "")).contains("付ける"), "カメラを見ると、案内は「付ける」")
	me.target = film
	check(game.hooks.first("hook_f", [me]), "F は、フィルターの仕組みが受ける")
	await frames(3)
	var env: Environment = film.view_cam.environment
	check(nf.night.has(film.pid) and env != null and env.adjustment_enabled and env.adjustment_brightness < 1.0, "付けたカメラの映像だけが、暗く青い夜になる")
	var others := 0
	for p: Node in game.props.values():
		if p.kind == "camera" and p != film and p.view_cam.environment != null:
			others += 1
	check(others == 0, "ほかのカメラは、昼のまま")
	me.target = film
	game.hooks.first("hook_f", [me])
	await frames(3)
	check(not nf.night.has(film.pid) and film.view_cam.environment == null, "もう一度 F で外すと、昼に戻る")
	print("NIGHT_TEST_FAIL" if failed else "NIGHT_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
