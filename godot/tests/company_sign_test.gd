extends SceneTree
# 会社の看板（features/company_sign.gd）と、会社の名前の絵（ui/company_logo.gd）：
#   ・入口の上に、空の金具がある。書割の社屋の文字の社名は出さない。看板が無いうちは「名無しの会社」と呼ばれる
#   ・1日目の案内：箱を開ける → 看板を作って掛ける → 掲示板、の順に1つずつ
#   ・描いた段ボール板を持って金具の下で F：接着でつないだ板ごと、まとめて掛かって止まる。
#     持っていた板がフックの下にまっすぐ掛かり、ほかの板はつないだ点を支点に面だけそろう（面の中の傾き・ずれはそのまま）
#   ・掛けた看板を撮って、会社の名前の絵にする。文の「{会社}」は、その絵になる（お知らせ・依頼主のひとこと）
#   ・描き足すと、撮り直す。看板は外して持てる・掛け直せる。帰社しても掛かったまま。倒産すると外れて、名前も無くなる
#   ・紹介動画の「看板の前に全員集合」：掛けたままの看板が、撮影カメラに看板として映る
#   godot --headless --path godot --fixed-fps 60 --script res://tests/company_sign_test.gd
const Logo := preload("res://scripts/ui/company_logo.gd")
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CSIGN_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait_sec(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


# 段ボール板に、横線を何本か吹く（描いた絵）
func paint(sheet: RigidBody3D, color: Color, seed: int) -> void:
	for row in 3:
		var pts := PackedVector2Array()
		var w := PackedFloat32Array()
		for k in 40:
			pts.append(Vector2(120 + k * 12, 140 + row * 90))
			w.append(6.0)
		sheet.spray(pts, w, color, seed + row)
	sheet.revision += 1


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var sign: Node = game.hooks.feature("company_sign")
	var kit: Node = game.hooks.feature("spray_sign")
	var box: Node = game.hooks.feature("delivery_box")
	var me: Node3D = game.local_player()
	check(sign != null and game.find_child("CompanySignHooks", true, false) != null, "入口の上に、看板を掛ける金具がある")
	var old: Label3D = game.find_child("CompanyNameSign", true, false)
	check(old == null or old.visible, "書割の社屋の、もとの社名はそのまま出ている")
	check(not sign.hung() and not Logo.has_logo(), "はじめは、金具は空で、会社の名前の絵も無い")
	game.hud.show_toast("電話だ！「%sさんですか？」" % flow.COMPANY)
	check(str(game.hud.toast_label.text).contains(Logo.NAMELESS), "看板が無いうちは「%s」と呼ばれる（%s）" % [Logo.NAMELESS, game.hud.toast_label.text])
	# ---- 1日目の案内 ----
	flow.daily = true
	flow.day = 1
	flow.phase = 0
	box.start()
	await frames(5)
	check(sign.tutorial_step() == "box", "1日目：まず、届いた宅配の箱を開ける")
	var keys: String = str(sign.hook_hud(me, "", "F 依頼を見る").get("keys_all", ""))
	check(keys.contains("宅配の箱") and not keys.contains("依頼を見る"), "箱を開ける前は、掲示板の前でも「依頼を見る」ではなく、箱を開ける案内（%s）" % keys)
	box.host_open()
	await frames(5)
	check(sign.tutorial_step() == "sign", "箱を開けたら、次は看板")
	keys = str(sign.hook_hud(me, "", "事務所の掲示板で、今日の依頼を選ぼう").get("keys_all", ""))
	check(keys.contains("看板") and keys.contains("金具"), "看板を作って金具に掛ける案内（%s）" % keys)
	check(box.LINES.any(func(l: String) -> bool: return l.contains("看板") and l.contains("段ボール")), "講師が、まず看板を作れと言う")
	# ---- 板を3枚：A（フックに掛ける）・B（右に、少し傾けてつなぐ）・C（Aの下に、1点でつないで垂れている） ----
	var a: RigidBody3D = kit.sheets[0]
	var b: RigidBody3D = kit.sheets[1]
	var c: RigidBody3D = kit.sheets[2]
	paint(a, Color(0.08, 0.08, 0.09), 1)
	paint(b, Color(0.82, 0.13, 0.1), 2)
	paint(c, Color(0.08, 0.08, 0.09), 3)
	var base := Vector3(72.0, 1.0, 9.0)
	var turn := Basis(Vector3.UP, 0.4)          # 持っている向き（斜め）
	a.restore([base, Quaternion(turn), true])
	var tilt := 0.12
	var bb := turn * Basis(Vector3.BACK, tilt)
	var pa := Vector3(0.55, 0.37, 0.01)
	var pb := Vector3(-0.53, 0.33, 0.01)
	var b_at: Vector3 = a.to_global(pa) - bb * pb
	b.restore([b_at, Quaternion(bb), true])
	var cb := turn * Basis(Vector3.RIGHT, 1.2)  # 垂れて、手前に折れている
	var pa2 := Vector3(-0.2, 0.0, 0.01)
	var pc := Vector3(0.1, 0.74, 0.0)
	c.restore([a.to_global(pa2) - cb * pc, Quaternion(cb), true])
	var adh: Node = game.adhesive
	adh.pairs.append({"a": a.pid, "b": b.pid, "pa": pa, "pb": pb, "joined": true})
	adh.pairs.append({"a": a.pid, "b": c.pid, "pa": pa2, "pb": pc, "joined": true})
	adh.restore(adh.snapshot())
	check(adh.connected_ids(a.pid).size() == 3, "3枚が接着でつながっている")
	# ---- 掛ける ----
	me.global_position = Vector3(72.0, 0.1, 9.6)
	await frames(3)
	a.restore([a.global_position, Quaternion(a.global_basis.orthonormalized()), false])
	game.h_grab(a.pid)
	await frames(3)
	check(a.holder == me.peer_id, "看板の板を持った")
	sign.h_hang(a.pid)
	check(not sign.hung(), "金具から遠いと、掛からない")
	me.global_position = Vector3(72.0, 0.1, 6.2)
	await frames(3)
	check(str(sign.hook_hud(me, "", "").get("keys_all", "")).contains("金具に掛ける"), "板を持って金具の下へ行くと、F で掛ける案内")
	check(sign.hook_f(me), "金具の下で F")
	await frames(5)
	check(sign.members.size() == 3 and sign.members[0] == a.pid, "つないだ3枚が、まとめて掛かる")
	check(a.fixed and b.fixed and c.fixed and a.holder == 0, "掛けた板は止まる（手から離れる）")
	var top: Vector3 = a.global_transform * Vector3(0, 0.74, 0)
	check(a.global_basis.z.dot(Vector3.BACK) > 0.999 and absf(top.y - (sign.HOOKS_AT[0].y - sign.HANG_DROP)) < 0.01 and absf(top.x - 72.0) < 0.01, "持っていた板は、フックの下に、まっすぐ正面へ向けて掛かる（上の縁 %.2f）" % top.y)
	check(b.global_basis.z.dot(Vector3.BACK) > 0.995 and c.global_basis.z.dot(Vector3.BACK) > 0.995, "ほかの板も、表が正面を向く（垂れていた板も）")
	var b_tilt := a.global_basis.x.signed_angle_to(b.global_basis.x, Vector3.BACK)
	check(absf(b_tilt - tilt) < 0.02, "つないだときの傾きは、そのまま残る（%.2f rad）" % b_tilt)
	var gap_b: float = a.to_global(pa).distance_to(b.to_global(pb))
	var gap_c: float = a.to_global(pa2).distance_to(c.to_global(pc))
	check(gap_b < 0.03 and gap_c < 0.03, "つないだ点は、離れない（%.3f・%.3f m）" % [gap_b, gap_c])
	check(old == null or old.visible, "看板が掛かっても、もとの社名はそのまま")
	# ---- 撮る ----
	await wait_sec(sign.SETTLE + 0.3)
	await frames(3)
	check(Logo.has_logo() and sign.shots >= 1, "掛けた看板を撮って、会社の名前の絵にする（%d回）" % sign.shots)
	var tex: Texture2D = Logo.texture
	check(tex != null and tex.get_width() > tex.get_height(), "絵は、看板の形（横長 %dx%d）" % [tex.get_width() if tex else 0, tex.get_height() if tex else 0])
	var img: Image = tex.get_image() if tex else null
	check(img != null and img.get_pixel(0, img.get_height() - 1).a < 0.1, "看板のまわりは透明")
	game.hud.show_toast("電話だ！「%sさんですか？ 動画、見ましたよ」" % flow.COMPANY)
	var twin: RichTextLabel = game.hud.toast_label.get_node_or_null(Logo.TWIN)
	check(twin != null and twin.visible and game.hud.toast_label.self_modulate.a == 0.0 and not twin.get_parsed_text().contains(Logo.NAMELESS), "お知らせの文の中で、会社の名前が看板の絵になる")
	game.hud.show_toast("ふつうのお知らせ")
	check(not twin.visible and game.hud.toast_label.self_modulate.a == 1.0 and game.hud.toast_label.text == "ふつうのお知らせ", "会社の名前が無い文は、いつもの字のまま")
	var label := Label.new()
	root.add_child(label)
	Logo.show_in(label, "おっ、%sの看板！" % flow.COMPANY)
	check(label.get_node_or_null(Logo.TWIN) != null and label.text.contains(Logo.PLACE) and Logo.plain("%s 作品" % flow.COMPANY) == flow.DEFAULT_COMPANY + " 作品", "どの文字の欄でも、絵を埋め込める（文字しか出せない所は、決まった名前）")
	label.queue_free()
	# 描き足すと、撮り直す
	var shots0: int = sign.shots
	var v0: int = Logo.version
	paint(b, Color(0.08, 0.08, 0.09), 9)
	await wait_sec(sign.SETTLE + 0.3)
	await frames(3)
	check(sign.shots > shots0 and Logo.version > v0, "描き足すと、撮り直す")
	# ---- 紹介動画：看板の前に全員集合（掛けたまま映す） ----
	var film: RigidBody3D = game.film
	film.restore([Vector3(72.0, 1.4, 11.0), Quaternion.IDENTITY, true])
	game._aim_camera(Vector3(72.0, 3.4, 4.3), 50.0)
	me.global_position = Vector3(75.5, 0.1, 9.0)
	await frames(20)
	check(game.hooks.feature("signboard").showing(), "掛けたままの看板が、撮影カメラに看板として映る")
	# ---- 1日目の段取りは、掛けた板を使わない ----
	var picked: Variant = game.hooks.feature("tutorial_day")._pick("cardboard", {})
	check(picked == null or not (picked in [a, b, c]), "1日目の段取りが出す段ボール板に、掛けた板は入らない")
	check(sign.tutorial_step() == "", "看板を掛けたら、ふつうの案内（掲示板）に戻る")
	# ---- 外す・掛け直す ----
	me.global_position = Vector3(72.0, 0.1, 6.2)
	await frames(3)
	adh.clear()                 # 依頼を受けると、接着剤の点は片づけられる（main.gd の _apply_order）
	await frames(2)
	sign.h_take_down(b.pid)
	await frames(3)
	check(not sign.hung() and b.holder == me.peer_id and not a.fixed, "掛かった看板をクリックすると、外れて手に持つ")
	check(adh.connected_ids(b.pid).size() == 3, "依頼を受けて接着剤が片づけられても、外した看板の板はつながったまま")
	check(Logo.has_logo(), "外しても、会社の名前の絵はそのまま（持ち運べる）")
	sign.h_hang(b.pid)
	await frames(3)
	check(sign.members.size() == 3 and sign.members[0] == b.pid and b.global_basis.z.dot(Vector3.BACK) > 0.999, "外した看板を、持っている板で掛け直せる")
	# ---- 帰社しても、掛かったまま ----
	var hung_at: Vector3 = a.global_position
	for s: RigidBody3D in [a, b, c]:
		s.restore([Vector3(60, 0.1, 30), Quaternion.IDENTITY, false])      # 帰社で置き場所が戻された、のつもり
	flow.day = 3
	for f: Object in game.hooks.in_order("hook_office_ready"):
		f.hook_office_ready()
	await frames(3)
	check(sign.hung() and a.global_position.distance_to(hung_at) < 0.01 and a.fixed, "帰社のあとも、看板は掛かったまま")
	check(not (c.pid in kit.spare), "掛けた板は、しまい直さない")
	# ---- 倒産：新しい会社 ----
	flow.day = 1
	for f: Object in game.hooks.in_order("hook_office_ready"):
		f.hook_office_ready()
	await frames(3)
	check(not sign.hung() and not Logo.has_logo() and not a.fixed, "倒産して新しい会社になると、看板は外れ、名前も無くなる")
	game.hud.show_toast("%s　作品" % flow.COMPANY)
	check(str(game.hud.toast_label.text).contains(Logo.NAMELESS), "新しい会社は、また「%s」" % Logo.NAMELESS)
	print("CSIGN_TEST_FAIL" if failed else "CSIGN_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)
