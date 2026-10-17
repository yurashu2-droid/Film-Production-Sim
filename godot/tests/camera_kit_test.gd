extends SceneTree
# カメラの形（scripts/features/camera_kit.gd）：
#   ・最初は三脚なし（カメラ本体だけ）。床に置くと低い所から写る。段ボールの上に載せると、高い所から写る
#   ・「会社を大きくする」で三脚（400コイン）を買うと、三脚に載る
#   ・自動確認の中（flow.daily が false）は、今までどおり三脚あり
#   godot --headless --path godot --fixed-fps 60 --script res://tests/camera_kit_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CAMKIT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func lens_y(cam: Node3D) -> float:
	return (cam.view_cam as Camera3D).global_position.y


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var kit: Node = game.hooks.feature("camera_kit")
	var cam: RigidBody3D = game.film
	check(kit != null and cam.tripod and is_equal_approx(float(cam.head_y), cam.HEAD_Y), "自動確認の中では、三脚に載っている")
	# ---- ふつうに遊ぶとき：最初は三脚なし ----
	flow.daily = true
	flow.levels["camera"] = 0
	kit.apply()
	var spot: Vector3 = flow.HOME_TRUCK + Vector3(-6.0, 0.0, 3.0)
	cam.restore([spot + Vector3(0, 0.05, 0), Quaternion.IDENTITY, false])
	await frames(60)
	check(not cam.tripod and float(cam.half.y) < 0.25 and float(cam.mass) < 8.0, "三脚なし：カメラ本体だけの、小さな物になる（高さ %.2fm）" % (float(cam.half.y) * 2.0))
	var low := lens_y(cam)
	check(low < 0.45, "床に置くと、低い所から写る（レンズの高さ %.2fm）" % low)
	var legs: Node3D = cam.visual.find_child("PIVOT_LEG_01_SPLAY", true, false)
	check(legs != null and not legs.visible, "三脚の脚は、見えない")
	# 段ボールを2つ積んで、その上に載せる
	var boxes: Array = game.props.values().filter(func(p: Node) -> bool: return p.kind == "applebox")
	var top := 0.0
	for k in mini(2, boxes.size()):
		var b: RigidBody3D = boxes[k]
		b.restore([spot + Vector3(2.0, 0.05 + top, 0), Quaternion.IDENTITY, false])
		top += float(b.half.y) * 2.0
		await frames(20)
	cam.restore([spot + Vector3(2.0, top + 0.1, 0), Quaternion.IDENTITY, false])
	await frames(90)
	var high := lens_y(cam)
	check(high > low + 0.3, "箱を積んだ上に載せると、高い所から写る（レンズの高さ %.2fm）" % high)
	# ---- 三脚を買う ----
	flow.wallet = 1000
	flow.buy("camera")
	await frames(10)
	check(int(flow.levels.get("camera", 0)) == 1 and flow.wallet == 600, "三脚は400コインで買える")
	check(cam.tripod and is_equal_approx(float(cam.head_y), cam.HEAD_Y), "買うと、撮影カメラが三脚に載る")
	cam.restore([spot + Vector3(0, 0.05, 0), Quaternion.IDENTITY, false])
	await frames(60)
	check(lens_y(cam) > 1.1, "三脚に載ったカメラは、床に置いても高い所から写る（%.2fm）" % lens_y(cam))
	print("CAMKIT_TEST_FAIL" if failed else "CAMKIT_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
