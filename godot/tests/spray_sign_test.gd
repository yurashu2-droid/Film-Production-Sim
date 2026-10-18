extends SceneTree
# 看板づくり（features/spray_sign.gd）：
#   ・段ボール板がはじめから2枚、スプレー缶が黒・赤の2本ある
#   ・空の段ボール箱を Shift+F でたたむと、箱は奥へしまわれ、その場に段ボール板が出る
#   ・缶を持って吹くと、狙った板に色が付く（持っていない人・遠い人は吹けない）
#   ・はじめて吹くときに決めた名前が、会社の名前になる（事務所の建物の看板・紹介動画の題・看板への反応）
#   ・吹いた板を、表をカメラへ向けて立てると、看板として映っている（signboard.gd）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/spray_sign_test.gd
#   SPRAY_SHOTS=1 を付けて画面ありで流すと、tests/shots/spray/ に絵を残す
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("SPRAY_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func shot(cam: Camera3D, from: Vector3, at: Vector3, file: String) -> void:
	if OS.get_environment("SPRAY_SHOTS") == "" or DisplayServer.get_name() == "headless":
		return
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/spray/"))
	root.get_texture().get_image().save_png("res://tests/shots/spray/%s.png" % file)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var kit: Node = game.hooks.feature("spray_sign")
	var me: Node3D = game.local_player()
	var cam := Camera3D.new()
	root.add_child(cam)
	check(kit != null and kit.sheets.size() == kit.SHOWN + kit.SPARE and kit.cans.size() == 2, "段ボール板（%d枚）とスプレー缶（2本）がある" % kit.sheets.size())
	var shown: Array = kit.sheets.filter(func(s: Node3D) -> bool: return s.global_position.y > -1.0)
	check(shown.size() == kit.SHOWN, "はじめから出ている板は %d 枚（%d 枚）" % [kit.SHOWN, shown.size()])
	check(kit.sheets.all(func(s: Node) -> bool: return game.cue_cards.boards.has(s.pid)), "板は、描ける物として登録してある（絵が全員に配られる）")
	# ---- たたむ ----
	var box: RigidBody3D = game.cargo_kit.boxes._issue()
	var spot := Vector3(66.0, 0.05, 12.0)
	box.restore([spot, Quaternion.IDENTITY, false])
	me.global_position = spot + Vector3(0, 0.1, 1.6)
	await frames(30)
	check(kit._foldable(box), "空いて開いた段ボール箱は、たためる")
	kit.h_fold(box.pid)
	await frames(10)
	check(box.absent and box.pid in flow.stash, "たたんだ箱は、奥へしまわれる")
	var folded: Array = kit.sheets.filter(func(s: Node3D) -> bool: return s.global_position.distance_to(spot) < 0.8)
	check(folded.size() == 1 and kit.spare.size() == kit.SPARE - 1, "その場に、段ボール板が1枚出る")
	# ---- 立てて、吹く ----
	var sheet: RigidBody3D = shown[0]
	var board_at := Vector3(70.0, 0.05, 11.0)
	sheet.restore([board_at, Quaternion.IDENTITY, true])       # 表（+Z）を南へ向けて立てる（自動確認では、止めて立てる）
	var can: RigidBody3D = kit.cans[0]
	me.global_position = board_at + Vector3(0, 0.1, 1.8)
	can.restore([me.global_position + Vector3(0.4, 0, 0), Quaternion.IDENTITY, false])
	await frames(10)
	kit.h_spray(sheet.pid, PackedVector2Array([Vector2(100, 200), Vector2(300, 220)]), can.pid)
	await frames(2)
	check(is_zero_approx(sheet.painted()), "缶を持っていないと、吹けない")
	game.h_grab(can.pid)
	await frames(10)
	check(can.holder == me.peer_id, "スプレー缶を持った")
	check(str(kit.hook_hud(me, "", "").get("keys", "")).contains("スプレー"), "缶を持つと、吹き方の案内が出る")
	# 名前を決める（はじめて吹くとき）
	kit.h_name("ドタバタ映像社", sheet.pid)
	await frames(5)
	check(flow.company == "ドタバタ映像社" and flow.company_name() == "ドタバタ映像社", "決めた名前が、会社の名前になる")
	var sign: Label3D = game.find_child("CompanyNameSign", true, false)
	check(sign != null and sign.text == "ドタバタ映像社", "事務所の建物の看板も、その名前になる")
	await frames(10)
	await shot(cam, board_at + Vector3(-0.4, 1.0, 1.6), board_at + Vector3(0, 0.38, 0), "guide")
	kit.h_name("別の名前", sheet.pid)
	await frames(3)
	check(flow.company == "ドタバタ映像社", "名前は、一度決めたら変わらない")
	# 吹く：太い線を何本か
	for row in 6:
		var pts := PackedVector2Array()
		for k in 20:
			pts.append(Vector2(80 + k * 27, 120 + row * 45 + (k % 3) * 6))
		kit.h_spray(sheet.pid, pts, can.pid)
	await frames(5)
	check(sheet.painted() > 0.05, "吹いた所に、色が付く（%.2f）" % sheet.painted())
	# 実際の操作：缶を持って、板を狙い、F（operate）を押したまま
	var by_hand: float = sheet.painted()
	# 視点を下げていって、板に照準が合う向きを探す（後ろからの視点なので、向きでカメラの場所も変わる）
	me.aim_yaw = 0.0
	var found := false
	for k in 40:
		me.aim_pitch = -0.2 - float(k) * 0.02
		await process_frame
		if not kit._aim(me).is_empty():
			found = true
			break
	check(found, "板に照準を合わせられる（視点の上下 %.2f）" % me.aim_pitch)
	var pitch0: float = me.aim_pitch
	Input.action_press("operate")
	for k in 40:
		me.aim_yaw = sin(float(k) * 0.3) * 0.12
		me.aim_pitch = pitch0 + sin(float(k) * 0.17) * 0.03
		await process_frame
	Input.action_release("operate")
	await frames(10)
	check(sheet.painted() > by_hand + 0.005, "缶を持って F を押したまま狙うと、吹ける（%.3f → %.3f）" % [by_hand, sheet.painted()])
	me.global_position = board_at + Vector3(0, 0.1, 9.0)
	var before: float = sheet.painted()
	kit.h_spray(sheet.pid, PackedVector2Array([Vector2(600, 400), Vector2(650, 420)]), can.pid)
	await frames(2)
	check(is_equal_approx(sheet.painted(), before), "遠くからは、吹けない")
	# ---- 看板として映る ----
	var film: RigidBody3D = game.film
	film.restore([board_at + Vector3(0, 0, 4.5), Quaternion.IDENTITY, true])
	game._aim_camera(board_at + Vector3(0, 0.4, 0), 50.0)
	me.global_position = board_at + Vector3(3.0, 0.1, 5.0)
	await frames(20)
	var signboard: Node = game.hooks.feature("signboard")
	check(signboard.showing(), "吹いた板を、表をカメラへ向けて立てると、看板として映る")
	signboard._by_take[99] = true
	signboard._first_by_take[99] = 1.0
	var cues: Array = signboard.hook_premiere_cues(99)
	check(not cues.is_empty() and str(cues[0][1]).contains("ドタバタ映像社"), "看板への反応は、会社の名前で呼ぶ（%s）" % (str(cues[0][1]) if not cues.is_empty() else ""))
	flow.chosen_job = flow.debut_job()
	flow.phase = 2
	check(str(game.film_title()).contains("ドタバタ映像社"), "紹介動画の題も、会社の名前（%s）" % game.film_title())
	flow.phase = 0
	await shot(cam, board_at + Vector3(-1.2, 1.4, 3.0), board_at + Vector3(0, 0.4, 0), "sign")
	print("SPRAY_TEST_FAIL" if failed else "SPRAY_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
