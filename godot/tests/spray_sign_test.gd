extends SceneTree
# 看板づくり（features/spray_sign.gd）：
#   ・段ボール板がはじめから2枚、スプレー缶が黒・赤の2本ある
#   ・空の段ボール箱を Shift+F でたたむと、箱は奥へしまわれ、その場に段ボール板が出る
#   ・缶を持って吹くと、狙った板に色が付く（持っていない人・遠い人は吹けない）
#   ・名前は打ち込まない：吹いても、名前を聞く画面は出ない（手で書く）。会社の名前は、掛けた看板の絵（company_sign_test.gd）
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


# 横線の跡の断面：x 200〜500 の列で濃さを平均し、山の高さ（0〜1）と、半分の高さでの幅（ピクセル）を測る
func _band(sheet: RigidBody3D, y: int) -> Vector2:
	var profile: Array = []
	var peak := 0.0
	for dy in range(-90, 91):
		var yy := y + dy
		var sum := 0.0
		if yy >= 0 and yy < sheet.res.y:
			for x in range(200, 500, 2):
				var c: Color = sheet.ink.get_pixel(x, yy)
				sum += clampf((sheet.BASE.v - c.v) / sheet.BASE.v, 0.0, 1.0)
		var d := sum / 150.0
		profile.append(d)
		peak = maxf(peak, d)
	var width := 0
	for d: float in profile:
		if d >= peak * 0.5:
			width += 1
	return Vector2(peak, width)


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
	kit.h_spray(sheet.pid, PackedVector2Array([Vector2(100, 200), Vector2(300, 220)]), PackedFloat32Array([6.0, 6.0]), can.pid)
	await frames(2)
	check(is_zero_approx(sheet.painted()), "缶を持っていないと、吹けない")
	game.h_grab(can.pid)
	await frames(10)
	check(can.holder == me.peer_id, "スプレー缶を持った")
	check(str(kit.hook_hud(me, "", "").get("keys", "")).contains("スプレー"), "缶を持つと、吹き方の案内が出る")
	var sign: Label3D = game.find_child("CompanyNameSign", true, false)
	check(sign != null and sign.visible, "書割の社屋の、もとの社名はそのまま出ている（会社の名前として呼ぶのは、入口の上に掛けた段ボールの看板）")
	# 吹く：太い線を何本か
	for row in 6:
		var pts := PackedVector2Array()
		for k in 68:
			pts.append(Vector2(80 + k * 8, 120 + row * 45 + (k % 3) * 2))
		var widths := PackedFloat32Array()
		widths.resize(32)
		widths.fill(6.0)
		for part in [pts.slice(0, 32), pts.slice(32, 64), pts.slice(64)]:
			var w := widths.slice(0, (part as PackedVector2Array).size())
			kit.h_spray(sheet.pid, part, w, can.pid)
	await frames(5)
	check(sheet.painted() > 0.05, "吹いた所に、色が付く（%.2f）" % sheet.painted())
	# 実際の操作：缶を持って、板を狙い、F（operate）を押したまま
	var by_hand: float = sheet.painted()
	var rev0: int = sheet.revision
	me.global_position = board_at + Vector3(0.0, 0.1, 1.2)      # 字を書くときは近づく（遠いと太く薄い霧になる）
	await frames(3)
	# 視点を下げていって、板に照準が合う向きを探す（後ろからの視点なので、向きでカメラの場所も変わる）
	me.aim_yaw = 0.0
	var found := false
	for k in 50:
		me.aim_pitch = -0.2 - float(k) * 0.02
		await process_frame
		if not kit._aim(me).is_empty():
			found = true
			break
	check(found, "板に照準を合わせられる（視点の上下 %.2f）" % me.aim_pitch)
	var pitch0: float = me.aim_pitch - 0.12      # 最初に当たるのは板の上の縁なので、少し下（真ん中寄り）を狙う
	Input.action_press("operate")
	for k in 40:
		me.aim_yaw = sin(float(k) * 0.3) * 0.12
		me.aim_pitch = pitch0 + sin(float(k) * 0.17) * 0.03
		await process_frame
	Input.action_release("operate")
	await frames(10)
	check(int(sheet.revision) > rev0 + 3, "缶を持って F を押したまま狙うと、吹ける（絵の版 %d → %d）" % [rev0, int(sheet.revision)])
	check(not game.input_locked and kit.find_children("*", "LineEdit", true, false).is_empty(), "はじめて吹いても、名前を打ち込む画面は出ない（手で書く）")
	check(flow.company == "", "吹いても、会社の名前は打ち込まれない")
	# 近いと細く濃い・遠いと太く薄い：同じ長さの線を、近い時と遠い時の広がりで吹き比べる
	var near_sheet: RigidBody3D = kit.sheets[1]
	near_sheet.restore([board_at + Vector3(1.4, 0.0, 0.0), Quaternion.IDENTITY, true])
	# 1コマごとに 8px ずつ動かした線（ふつうの速さで横に払う）
	var line := PackedVector2Array()
	var near := PackedFloat32Array()
	var far := PackedFloat32Array()
	var line2 := PackedVector2Array()
	for k in 68:
		line.append(Vector2(80 + k * 8, 120))
		line2.append(Vector2(80 + k * 8, 300))
		near.append(kit.spread_for(0.2))
		far.append(kit.spread_for(1.6))
	near_sheet.spray(line, near, Color.BLACK, 7)
	var near_dark: float = near_sheet.painted()
	var band_near := _band(near_sheet, 120)
	near_sheet.ink.fill(near_sheet.BASE)
	near_sheet._refresh()
	near_sheet.spray(line2, far, Color.BLACK, 7)
	var band_far := _band(near_sheet, 300)
	check(band_near.x > band_far.x and band_near.y < band_far.y, "近いと細く濃い（濃さ %.2f・幅 %dpx）、遠いと太く薄い（濃さ %.2f・幅 %dpx）" % [band_near.x, int(band_near.y), band_far.x, int(band_far.y)])
	near_sheet.ink.fill(near_sheet.BASE)
	near_sheet._refresh()
	# 同じ所に近くから吹き続けると、垂れる
	var dwell := PackedVector2Array()
	var dwell_w := PackedFloat32Array()
	for k in 30:
		dwell.append(Vector2(350, 200))
		dwell_w.append(kit.spread_for(0.15))
	near_sheet.spray(dwell, dwell_w, Color.BLACK, 11)
	var below: Color = near_sheet.ink.get_pixel(350, 245)
	var dripped := false
	for x in range(330, 371):
		for y in range(225, 280):
			if (near_sheet.ink.get_pixel(x, y) as Color).v < 0.25:
				dripped = true
	check(dripped and near_dark >= 0.0, "同じ所に近くから吹き続けると、下へ垂れる")
	near_sheet.ink.fill(near_sheet.BASE)
	near_sheet._refresh()
	me.global_position = board_at + Vector3(0, 0.1, 9.0)
	var before: float = sheet.painted()
	kit.h_spray(sheet.pid, PackedVector2Array([Vector2(600, 400), Vector2(650, 420)]), PackedFloat32Array([6.0, 6.0]), can.pid)
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
	check(not cues.is_empty() and str(cues[0][1]).contains(flow.COMPANY), "看板への反応は、会社の名前（看板の絵）で呼ぶ（%s）" % (str(cues[0][1]) if not cues.is_empty() else ""))
	flow.chosen_job = flow.debut_job()
	flow.phase = 2
	check(str(game.film_title()) == str(flow.job()["title"]), "名前を打ち込まないので、紹介動画の題は依頼の題のまま（%s）" % game.film_title())
	flow.phase = 0
	await shot(cam, board_at + Vector3(-1.2, 1.4, 3.0), board_at + Vector3(0, 0.4, 0), "sign")
	print("SPRAY_TEST_FAIL" if failed else "SPRAY_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
