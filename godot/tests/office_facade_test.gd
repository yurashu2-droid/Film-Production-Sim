extends SceneTree
# 書割の社屋（事務所の正面）の切り欠きを確かめる（scripts/features/office_facade.gd）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/office_facade_test.gd
# 自分の視点のカメラと体のあいだに書割が挟まるときだけ、自分の視点から消える。撮影カメラには、いつでも映る。
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("OFFICE_FACADE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# その場所に立って、カメラが体の南（事務所の外の側）に来る向きにする
func stand(me: Node3D, at: Vector3, camera_south: bool) -> void:
	me.global_position = at
	for yaw: float in [0.0, PI]:
		me.aim_yaw = yaw
		me.aim_pitch = -0.25
		await frames(8)
		if (me.cam.global_position.z > me.global_position.z) == camera_south:
			return


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var facade: Node = game.hooks.feature("office_facade")
	var Office := preload("res://scripts/production_office.gd")
	check(facade != null and game.find_child("OfficeFacade", true, false) != null, "書割の社屋と、切り欠きの仕組みがある")
	var me: Node3D = game.local_player()
	# 通りから見る：消えない
	await stand(me, Vector3(72, 0.1, 14), true)
	check(not facade.hidden and (me.cam.cull_mask & Office.FACADE_LAYER) != 0, "通りから見ると、書割が見える")
	# 入口から入ってすぐ（カメラは外）：自分が隠れるので消える
	await stand(me, Vector3(72, 0.1, 2.5), true)
	print("OFFICE_FACADE_MEASURE 入口：体 z=%.1f カメラ z=%.1f y=%.1f" % [me.global_position.z, me.cam.global_position.z, me.cam.global_position.y])
	check(facade.hidden and (me.cam.cull_mask & Office.FACADE_LAYER) == 0, "入口から入ってすぐは、カメラと体のあいだの書割が消える")
	# 奥で、正面のほうを向く（カメラは奥の側）：書割の裏が見える
	await stand(me, Vector3(72, 0.1, -5.5), false)
	check(not facade.hidden and (me.cam.cull_mask & Office.FACADE_LAYER) != 0, "奥から正面を向くと、書割の裏（ベニヤと支え）が見える")
	# 撮影カメラには、いつでも映る
	check((game.film.view_cam.cull_mask & Office.FACADE_LAYER) != 0, "撮影カメラには、書割がいつでも映る")
	print("OFFICE_FACADE_TEST_FAIL" if failed else "OFFICE_FACADE_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(8)
	quit(1 if failed else 0)
