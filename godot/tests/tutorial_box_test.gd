extends SceneTree
# 1日目の始まり（features/delivery_box.gd）と、青いガイド（features/holo_guides.gd）：
#   ・宅配の箱が届いていると、貯金は 1,000,600 コイン。画面の数字は 3桁ごとにカンマで区切る
#   ・箱を F で開けると、100万が引き落とされて 600 になる。画面の数字は、くるくる減ってから 600 に止まる
#   ・開いた箱から講師（青いホログラム）が出てきて話す。F で次のせりふへ飛ばせる
#   ・開けずに買い物をしても、そこで箱が開いて払う（100万は使えない）
#   ・紹介動画の依頼を受けると、事務所の前に青い影が出る。カメラ・箱・城・書割を合わせると緑になる。映画には映らない
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
	# ---- 箱は、空から落ちてくる ----
	me.global_position = Vector3(72.0, 0.1, 5.0)          # 起きる所（production_office.gd の SPAWN_POINT）
	box.start(true)
	await frames(5)
	check(not box.landed and not box.box.visible and box.hook_hud(me, "", "").is_empty(), "落ちてくる前は、箱は見えず、開ける案内も出ない")
	var waited := 0
	while not box.box.visible and waited < 400:
		await frames(1)
		waited += 1
	check(box.box.visible and box.box.global_position.y > 3.0 and not box.landed, "少しすると、箱が空の高い所に現れる（%d コマ待った・高さ %.1f）" % [waited, box.box.global_position.y])
	await frames(24)
	check(box.box.global_position.y > 0.5 and box.box.global_position.y < box.DROP_H, "箱は落ちている途中（高さ %.1f）" % box.box.global_position.y)
	# 絵は、遊ぶ人の画面のまま撮る（床の近くまで落ちてきた所・床に当たった拍子）
	while box.box.global_position.y > 1.7:
		await frames(1)
	await shot(cam, box.AT + Vector3(-1.6, 1.5, 4.6), box.AT + Vector3(0, 2.6, 0), "box_falling")
	while box.box.global_position.y > 0.02:
		await frames(1)
	await frames(4)
	await shot(cam, box.AT + Vector3(-1.6, 1.5, 4.6), box.AT + Vector3(0, 0.6, 0), "box_landed")
	await frames(70)
	check(box.landed and box.box.global_position.distance_to(box.AT) < 0.05, "落ちた箱は、起きた所の目の前の床に止まる")
	check(str(box.hook_hud(me, "", "").get("keys", "")) == "" and not box.near(me), "少し離れていると、まだ開ける案内は出ない")
	# 開けるまで、ガタガタして、中から声がする
	var spoke := ""
	var glowed := 0.0
	for i in 240:
		await frames(1)
		if box._mutter.text != "":
			spoke = box._mutter.text
		glowed = maxf(glowed, box._glow.light_energy)
	check(spoke.contains("箱の中から"), "落ちた箱の中から、声がする（%s）" % spoke)
	check(glowed > 0.8, "ガタッと動くたびに、ふたのすき間から青い光がもれる（%.1f）" % glowed)
	box._rattle(1.0)
	await frames(3)
	await shot(cam, box.AT + Vector3(-1.2, 1.3, 2.6), box.AT + Vector3(0, 0.45, 0), "box_rattle")
	# すぐそばに立つと、その人に呼びかける
	me.global_position = box.box.global_position + Vector3(0, 0.1, 1.5)
	box._mutter.text = ""
	box._mutter_t = 0.0
	box._far_i = 2                # はじめの2つを言い終えたあと
	await frames(4)
	check(box.NEAR.any(func(l: String) -> bool: return box._mutter.text.contains(l)), "そばに立つと、その人に呼びかける（%s）" % box._mutter.text)
	# みんなが離れると、跳ねてついて来る
	var hop_from: Vector3 = box.box.global_position
	me.global_position = Vector3(72.0, 0.1, 10.5)
	await frames(60 * 7)
	var moved: float = box.box.global_position.distance_to(hop_from)
	var gap: float = Vector2(me.global_position.x - box.box.global_position.x, me.global_position.z - box.box.global_position.z).length()
	check(moved > 1.0 and not box.opened, "みんなが離れると、箱が跳ねてついて来る（%.1f m 動いた）" % moved)
	check(gap > 1.6 and gap < box.FOLLOW_FAR, "ついて来た箱は、人の手前で止まる（あと %.1f m）" % gap)
	await shot(cam, box.box.global_position + Vector3(-2.4, 1.6, 2.4), box.box.global_position + Vector3(0, 0.4, 0), "box_followed")
	# 追いついた箱を開ける：ふたが弾けて、数字が真ん中に大きく出る
	me.global_position = box.box.global_position + Vector3(0, 0.1, 1.5)
	await frames(3)
	check(box.hook_f(me), "ついて来た箱も、そばで F を押すと開けられる")
	await frames(50)
	check(box.opened and flow.wallet == 600, "開けると、100万が引き落とされる（%d）" % flow.wallet)
	check(box._big.visible and box._big.text.contains(","), "引き落としの間、貯金の数字が画面の真ん中に大きく出る（%s）" % box._big.text)
	await shot(cam, box.box.global_position + Vector3(-0.6, 1.5, 2.6), box.box.global_position + Vector3(0, 0.9, 0), "box_open_big")
	await frames(200)
	check(not box._big.visible and hud.wallet_shown == -1 and hud._wallet_num.text == "600", "大きな数字は消えて、貯金の表示は 600 に止まる（%s）" % hud._wallet_num.text)
	await frames(60)
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
	check("box0" in names and "box1" in names and "camera" in names and "castle" in names and "blast" in names and names.filter(func(n: String) -> bool: return n.begins_with("mark")).size() == 0,
		"影は、箱2つ・カメラ・城・書割（役者の印は出さない）（%s）" % ", ".join(names))
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
	check(all_ok, "カメラ・箱・城・書割を合わせると、全部緑になる")
	await shot(cam, o + Vector3(3.2, 2.4, 9.0), o + Vector3(0, 0.4, 0.5), "guides_green")
	print("TUTBOX_TEST_FAIL" if failed else "TUTBOX_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
