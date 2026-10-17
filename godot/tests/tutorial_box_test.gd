extends SceneTree
# 1日目の始まり（features/delivery_box.gd）と、青いガイド（features/holo_guides.gd）：
#   ・宅配の箱が届いていると、貯金は 1,000,600 コイン。画面の数字は 3桁ごとにカンマで区切る
#   ・箱を F で開けると、100万が引き落とされて 600 になる。画面の数字は、くるくる減ってから 600 に止まる
#   ・開いた箱から講師（青いホログラム）が出てきて話す。F で次のせりふへ飛ばせる
#   ・開けずに買い物をしても、そこで箱が開いて払う（100万は使えない）
#   ・紹介動画の依頼を受けると、事務所の前に青い影が出る。カメラ・箱・印・城・書割を合わせると緑になる。映画には映らない
#   godot --headless --path godot --fixed-fps 60 --script res://tests/tutorial_box_test.gd
#   TUTBOX_SHOTS=1 を付けて画面ありで流すと、tests/shots/tutorial/ に絵を残す
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("TUTBOX_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func shots() -> bool:
	return OS.get_environment("TUTBOX_SHOTS") != "" and DisplayServer.get_name() != "headless"


func shot(cam: Camera3D, from: Vector3, at: Vector3, file: String) -> void:
	if not shots():
		return
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/tutorial/"))
	root.get_texture().get_image().save_png("res://tests/shots/tutorial/%s.png" % file)


func place(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), false])


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var box: Node = game.hooks.feature("delivery_box")
	var guides: Node = game.hooks.feature("holo_guides")
	var hud: Node = game.production_hud
	var me: Node3D = game.local_player()
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	check(box != null and not box.on and flow.wallet == flow.START_WALLET, "自動確認の中では、箱は届いていない（貯金はふだんの %d）" % flow.wallet)
	# ---- 箱が届いている ----
	box.start()
	await frames(5)
	check(flow.wallet == 1000600 and box.box.visible and not box.opened, "箱が届いていると、貯金は 1,000,600 コイン")
	check(hud._wallet_num.text == "1,000,600", "画面の貯金は、カンマで区切って出る（%s）" % hud._wallet_num.text)
	me.global_position = box.box.global_position + Vector3(0, 0.1, 1.6)
	await frames(5)
	var hint: Dictionary = box.hook_hud(me, "", "")
	check(str(hint.get("keys", "")).contains("開ける"), "箱のそばでは、F で開けられると出る")
	me.global_position = box.box.global_position + Vector3(1.6, 0.1, 0.3)
	await frames(2)
	await shot(cam, box.box.global_position + Vector3(-0.3, 1.3, 1.7), box.box.global_position + Vector3(0, 0.3, 0), "box_closed")
	me.global_position = box.box.global_position + Vector3(0, 0.1, 1.6)
	await frames(2)
	check(box.hook_f(me), "箱のそばで F を押すと、箱を開ける")
	await frames(30)
	check(box.opened and flow.wallet == 600, "開けると、100万が引き落とされて 600 コインになる（%d）" % flow.wallet)
	var mid: int = int(hud.wallet_shown)
	await frames(30)
	mid = int(hud.wallet_shown)
	check(mid > 600 and mid < 1000600, "画面の数字は、くるくる減っていく途中（%d）" % mid)
	await frames(120)
	check(hud.wallet_shown == -1 and hud._wallet_num.text == "600", "減り終わると、画面の数字は 600 に止まる（%s）" % hud._wallet_num.text)
	check(box.line == 0 and box._teacher.visible and box._bubble.text != "", "開いた箱から講師が出てきて、話し始める")
	me.global_position = box.box.global_position + Vector3(1.6, 0.1, 0.3)
	await frames(2)
	await shot(cam, box.box.global_position + Vector3(-0.5, 1.5, 2.3), box.box.global_position + Vector3(0, 0.95, 0), "box_teacher")
	me.global_position = box.box.global_position + Vector3(0, 0.1, 1.6)
	await frames(2)
	check(box.hook_f(me) and box.line == 1, "話の途中で F を押すと、次のせりふへ飛ぶ")
	for i in box.LINES.size():
		box.hook_f(me)
	await frames(60)
	check(box.line == -1 and not box._teacher.visible, "最後まで飛ばすと、講師は消える")
	# ---- 開けずに買い物をしても、そこで払う ----
	box.start()
	await frames(5)
	flow.buy("camera")
	await frames(10)
	check(box.opened and flow.wallet == 200, "開けないまま三脚（400）を買っても、そこで箱が開いて払う（残り %d）" % flow.wallet)
	await frames(200)
	# ---- 青いガイド ----
	flow.wallet = 600
	flow.daily = true
	flow.levels["camera"] = 0
	game.hooks.feature("camera_kit").apply()
	box.on = false
	await frames(5)
	flow.accept(flow.debut_job())
	await frames(30)
	check(guides.active() and guides.root != null and guides.root.visible, "紹介動画の依頼を受けると、事務所の前に青い影が出る")
	var names: Array = guides.guides.map(func(g: Dictionary) -> String: return str(g["name"]))
	check("box0" in names and "box1" in names and "camera" in names and "castle" in names and "blast" in names and names.filter(func(n: String) -> bool: return n.begins_with("mark")).size() == 4,
		"影は、箱2つ・カメラ・印4つ・城・書割（%s）" % ", ".join(names))
	var crew_only := true
	for mi: VisualInstance3D in guides.root.find_children("*", "VisualInstance3D", true, false):
		crew_only = crew_only and mi.layers == guides.CREW_LAYER
	check(crew_only and (game.film.view_cam.cull_mask & guides.CREW_LAYER) == 0, "影は、映画には映らない層にある")
	check(not guides.done("camera") and not guides.done("box0"), "置く前は、影は青いまま")
	var o: Vector3 = flow.HOME_SET
	await shot(cam, o + Vector3(3.2, 2.4, 9.0), o + Vector3(0, 0.4, 0.5), "guides_blue")
	# 箱を2つ積んで、その上にカメラ
	var boxes: Array = game.props.values().filter(func(p: Node) -> bool: return p.kind == "applebox" and not p.absent)
	var spot: Vector3 = o + guides.CAM_AT
	var top := 0.0
	for k in 2:
		place(boxes[k], spot + Vector3(0, 0.05 + top, 0))
		top += float(boxes[k].half.y) * 2.0
		await frames(20)
	place(game.film, spot + Vector3(0, top + 0.1, 0))
	for aid in 4:
		place(game.beats.marks[aid][0], o + guides.MARK_AT[aid])
	var flat: Node = game.props.values().filter(func(p: Node) -> bool: return p.kind == "flat" and not p.absent)[0]
	place(flat, o + guides.CASTLE_AT)
	var boom: Node = game.props.values().filter(func(p: Node) -> bool: return p.kind == "boomflat" and not p.absent)[0]
	place(boom, o + guides.FLAT_AT)
	await frames(90)
	var all_ok := true
	for g: Dictionary in guides.guides:
		all_ok = all_ok and bool(g["ok"])
		if not bool(g["ok"]):
			print("TUTBOX_NOTE まだ青い：", g["name"])
	check(all_ok, "カメラ・箱・印・城・書割を合わせると、全部緑になる")
	await shot(cam, o + Vector3(3.2, 2.4, 9.0), o + Vector3(0, 0.4, 0.5), "guides_green")
	print("TUTBOX_TEST_FAIL" if failed else "TUTBOX_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
