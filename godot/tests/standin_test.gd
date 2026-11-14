extends SceneTree
# 等身大パネルを確かめる：見て F で開く → 色つきで描く → 下塗り・見本・白紙 → ジョーカーとしての採点。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/standin_test.gd
const Cast := preload("res://scripts/production_cast.gd")
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("STANDIN_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)


func stroke(canvas: Control, from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = canvas.size * from
	canvas._gui_input(down)
	var move := InputEventMouseMotion.new()
	move.position = canvas.size * to
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = canvas.size * to
	canvas._gui_input(up)


func item(kind: String, blank: bool = false) -> Dictionary:
	return {"kind": kind, "label": kind, "tags": ["blank"] if blank else []}


func run() -> void:
	# ---- 採点の表：ジョーカー ----
	check(Cast.is_joker("standin") and Cast.fit("standin", "monster") == 1 and Cast.fit("standin", "castle") == 1 and Cast.fit("standin", "moon") == 1, "a painted panel passes for any role")
	check(Cast.fit("standin", "monster", ["blank"]) == 0, "a blank panel is a forced choice")
	var joker := Cast.score("kaiju", {"monster": [item("scrap_toilet")], "boom": [item("standin")]})
	check((joker["combos"] as Array).size() == 1 and "ジョーカー" in str(joker["combos"][0]["name"]) and int(joker["coins"]) == -60 + 0 + 120, "the joker completes one combo with another role (%d)" % int(joker["coins"]))
	var blank := Cast.score("kaiju", {"monster": [item("scrap_toilet")], "boom": [item("standin", true)]})
	check((blank["combos"] as Array).is_empty() and int(blank["coins"]) == -120, "a blank panel completes nothing (%d)" % int(blank["coins"]))
	var upgrade := Cast.score("kaiju", {"monster": [item("scrap_toilet")], "city": [item("scrap_fountain")], "boom": [item("standin")]})
	check((upgrade["combos"] as Array).size() == 1 and int(upgrade["combos"][0]["coins"]) == 300, "the joker turns a two-role combo into a three-role one")
	var lonely := Cast.score("kaiju", {"monster": [item("standin")], "city": [item("carton")]})
	check((lonely["combos"] as Array).is_empty(), "the joker needs a themed partner")
	var named := Cast.score("kaiju", {"monster": [item("scrap_toilet")], "city": [item("standin")], "boom": [item("scrap_poop")]})
	check((named["combos"] as Array).size() == 2, "a named combo stays, and the joker widens the theme to three roles")

	# ---- ゲームの中で ----
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var cards: Node = game.cue_cards
	var panel: Node = cards.panel
	check(panel != null and panel.kind == "standin", "the company owns a life-size panel")
	check(panel.visual.scene_file_path == "res://assets/gear/P04_Actor_StandIn.glb", "uses the supplied stand-in model")
	check(panel.surface != null and panel.surface.get_surface_override_material(panel._ink_surface).albedo_texture == panel.texture, "the front sheet shows the live drawing")
	check(absf(float(panel.res.x) / panel.res.y - 32.0 / 75.0) < 0.001, "the drawing keeps the sheet's 32:75 shape")
	check(panel.global_basis.y.y > 0.98 and panel.global_position.y < 0.3, "the panel stands on the ground (y=%.2f)" % panel.global_position.y)
	check(panel.blank(), "it starts blank")
	check(not game.production._is_free(panel), "it is company gear, not part of the daily scrap")

	# 依頼を受けて、パネルの前に立つ
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	var me: Node = game.local_player()
	var front: Vector3 = panel.global_basis.z
	# カメラは真後ろにあるので、パネルの正面に立てば照準が乗る
	var stand: Vector3 = panel.global_position + front * 2.2 + Vector3(0, 0.1, 0)
	me.global_position = stand
	me.aim_yaw = atan2(front.x, front.z)
	me.aim_pitch = -0.3      # 少し見下ろす（背中ごしのカメラは頭より高い）
	await frames(30)
	check(me.target == panel, "standing in front, the crew member looks at the panel")
	check(cards.board_for(me) == panel, "it can be painted without picking it up")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	key(KEY_F)
	await frames(3)
	var editor: Node = cards.editor
	check(editor.opened and editor.board == panel and game.ui_blocking(), "F opens the paint screen for the panel")
	var canvas: Control = editor.canvas
	check(canvas.resolution == panel.res and canvas.size.y > canvas.size.x, "the canvas is portrait like the sheet")
	# 赤で横に1本、青で縦に1本
	var red: Color = cards.PANEL_COLORS[5][1]
	var blue: Color = cards.PANEL_COLORS[11][1]
	editor.color = red
	editor.radius = 22.0
	stroke(canvas, Vector2(0.2, 0.25), Vector2(0.8, 0.25))
	editor.flush()
	editor.color = blue
	stroke(canvas, Vector2(0.5, 0.5), Vector2(0.5, 0.9))
	editor.flush()
	await frames(2)
	var at_red: Color = panel.ink.get_pixel(int(panel.res.x * 0.5), int(panel.res.y * 0.25))
	var at_blue: Color = panel.ink.get_pixel(int(panel.res.x * 0.5), int(panel.res.y * 0.7))
	check(at_red.is_equal_approx(Color(red.r, red.g, red.b)) and at_blue.is_equal_approx(Color(blue.r, blue.g, blue.b)), "strokes land on the sheet in the chosen colours")
	check(not panel.blank(), "a painted panel is no longer blank (%.3f)" % panel.painted())
	cards.h_draw(panel.pid, PackedVector2Array([Vector2(10, 10), Vector2(60, 60)]), Color(0.3, 0.9, 0.1), 8.0)
	check(panel.ink.get_pixel(30, 30).is_equal_approx(Color.WHITE), "colours outside the paint box are refused")
	# 下塗り・見本・白紙
	var green: Color = cards.PANEL_COLORS[9][1]
	cards.h_fill(panel.pid, green)
	check(panel.ink.get_pixel(5, 5).is_equal_approx(Color(green.r, green.g, green.b)) and panel.painted() > 0.99, "fill covers the whole sheet")
	cards.h_preset(panel.pid, "actor_a")
	var corner: Color = panel.ink.get_pixel(8, 8)
	var body: Color = panel.ink.get_pixel(int(panel.res.x * 0.5), int(panel.res.y * 0.45))
	check(not panel.blank() and panel.ink.get_size() == panel.res and not corner.is_equal_approx(body), "the sample actor picture can be pasted")
	var keep: Array = panel.get_state()
	cards.h_clear(panel.pid)
	check(panel.blank(), "clearing brings back a blank sheet")
	panel.apply_state(keep, true)
	check(not panel.blank(), "a snapshot restores the picture for late joiners and replays")
	key(KEY_F)
	await frames(3)
	check(not editor.opened and not game.ui_blocking(), "F closes the paint screen")

	# カンペも今までどおり開ける（道具は別）
	game.h_grab(cards.card.pid)
	await frames(5)
	key(KEY_F)
	await frames(3)
	check(editor.opened and editor.board == cards.card and editor.canvas.resolution == cards.card.res, "the cue card still opens its own paint screen")
	key(KEY_F)
	await frames(3)
	game.host_release(cards.card)
	await frames(3)

	# ジョーカーとして役に付ける
	me.global_position = stand
	await frames(10)
	game.h_cast(panel.pid, "monster")
	check(flow.role_of(panel) == "monster" and flow.cast_fit(panel, "monster") == 1, "the painted panel is cast as a passable monster")
	cards.h_clear(panel.pid)
	check(flow.cast_fit(panel, "monster") == 0 and "blank" in flow.cast_tags(panel), "wiping it makes the casting forced again")
	cards.h_preset(panel.pid, "actor_b")
	var toilet: Node = null
	for pid: int in game.props:
		if game.props[pid].kind == "scrap_toilet":
			toilet = game.props[pid]
	flow.cast_set(toilet.pid, "boom")
	var sheet: Dictionary = flow.cast_sheet()
	print("STANDIN sheet=", sheet)
	check((sheet["combos"] as Array).size() == 1 and "ジョーカー" in str(sheet["combos"][0]["name"]), "the casting sheet previews the joker combo")
	check("等身大パネル" == str(flow.cast_names().get("monster", "")), "the script calls it by its short name")
	game.h_return_office()
	print("STANDIN_TEST_FAIL" if failed else "STANDIN_TEST_OK")
	quit(1 if failed else 0)
