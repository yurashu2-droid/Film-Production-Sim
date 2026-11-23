extends SceneTree
# 制作モードの画面を順に撮る。出力 res://tests/shots/ui/<名前><接尾辞>.png
# 接尾辞は環境変数 UISHOT_SUFFIX。解像度は --resolution WxH で変える。
# UISHOT_JOB=3 のように依頼の番号を渡すと、その依頼（怪獣など）で撮る。
var game: Node
var suffix := ""
func _initialize() -> void:
	suffix = OS.get_environment("UISHOT_SUFFIX")
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(label: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://tests/shots/ui/%s%s.png" % [label, suffix])
	root.get_texture().get_image().save_png(path)
	print("UISHOT ", label)
func collect_boxes(n: Node, out: Array) -> void:
	if n.get_class() == "PanelContainer" and n.has_signal("pressed"):
		out.append(n)
	for c in n.get_children():
		collect_boxes(c, out)
func fake_takes() -> Array:
	return [
		{"results": [
			{"ok": true, "title": "告白（高低差・城・明るさ）", "detail": "二人が高低差つきで城のセットと一緒に映った", "at": 6.0},
			{"ok": false, "title": "背後で大爆発", "detail": "爆発が二人の背後に映らなかった", "at": 0.0},
			{"ok": true, "title": "爆発のあと再会", "detail": "近づいた二人が映った", "at": 31.0}],
		"passed": [true, false, true], "dur": 42.0,
		"extras": {"cameos": {"スタッフ": 1.2}, "early_boom": true, "bonus_ok": false}},
		{"results": [
			{"ok": true, "title": "告白（高低差・城・明るさ）", "detail": "二人が高低差つきで城のセットと一緒に映った", "at": 6.0},
			{"ok": true, "title": "背後で大爆発", "detail": "爆発が二人の背後に映った", "at": 20.0},
			{"ok": true, "title": "爆発のあと再会", "detail": "近づいた二人が映った", "at": 31.0}],
		"passed": [true, true, true], "dur": 55.0, "extras": {"bonus_ok": true}}]
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/ui"))
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(100)
	await shot("title")
	menu.solo_button.pressed.emit()
	while menu.game_node == null or not menu.game_node.startup_complete or menu._transition.active:
		await frames(1)
	game = menu.game_node
	game.h_select_cast(1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(120)
	await shot("office_walk")
	game.open_menu("board")
	await frames(20)
	await shot("office")
	game.open_menu("pause")
	await frames(20)
	await shot("pause")
	game.close_menu()
	var job := 2
	if OS.get_environment("UISHOT_JOB") != "": job = int(OS.get_environment("UISHOT_JOB"))
	game.h_accept_job(job)
	game.h_open_order()
	await frames(30)
	await shot("shop")
	# マウスでも同じ操作ができる：行のクリック＝Space、ホバー＝カーソル移動
	var rows: Array = game.hud._opt_rows
	rows[3]["box"].hovered.emit()
	rows[3]["box"].pressed.emit()
	await frames(5)
	print("UISHOT_CLICK order dolly=", game.order.get("dolly", 0), " cursor=", game.order_cursor)
	rows[3]["box"].pressed.emit()
	await frames(5)
	print("UISHOT_CLICK order dolly after toggle=", game.order.get("dolly", 0))
	# 道具をいくつか選んだ注文表（カーソルは2行目）
	for option in ["fx", "refill", "dolly", "fix"]: game.h_order_set(option, 1)
	game.order_cursor = 1
	await frames(10)
	await shot("shop_items")
	game.order_cursor = 2
	await frames(4)
	await shot("shop_refill")
	for option in ["refill", "fix"]: game.h_order_set(option, 0)
	game.h_order_confirm()
	await frames(12)
	await shot("wallet_popup")
	await frames(10)
	var flow: Node = game.production
	var wanted := {"plywood":1,"riser":1,"moon":1}
	for prop in game.props.values():
		if prop.absent or not wanted.has(prop.kind): continue
		if wanted[prop.kind] <= 0: continue
		wanted[prop.kind] -= 1
		game.host_load(prop,game.truck)
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3,0.1,0)
	await frames(40)
	await shot("packing_walk")
	game.open_menu("packing")
	await frames(20)
	await shot("packing")
	game.close_menu()
	game.h_depart()
	await frames(150)
	await shot("travel")
	while flow.phase != 4: await frames(15)
	await frames(60)
	game.local_player().position = game.SPAWN
	await frames(30)
	await shot("prep")
	# 条件が揃ったときの「足りないこと」欄（緑の点）。見た目だけ確かめる
	game.hud.set_process(false)
	game.hud._set_hints(["この画なら条件を満たせる"], "ok")
	game.hud._hint_box.visible = true
	await shot("hint_ok")
	game.hud.set_process(true)
	game.hud.show_toast("スタジオ返却まで10分！ まず荷下ろし。Tabで操作確認")
	await frames(20)
	await shot("toast")
	game.hud.show_toast("カチンコを持って F で本番開始", game.hud.RED)
	await frames(20)
	await shot("toast_red")
	game.hud.show_toast("追加注文を達成した。納品料にコインが上乗せされる。この長い文章は二行に折り返されて、左右の板に重ならない。", game.hud.GREEN)
	await frames(20)
	await shot("toast_long")
	game.h_grab(game.clapper.pid)
	game.h_use()
	await frames(20)
	await shot("countdown")
	while game.state != game.S.TAKE: await frames(10)
	await frames(80)
	await shot("take")
	game.hud.set_process(false)
	game.hud._sync_cues(game.live, [true, true, false])
	await shot("take_cues")
	game.hud.set_process(true)
	game.hud.show_slate("clap", 1)
	await frames(8)
	await shot("slate")
	game.h_take()
	while game.state != game.S.RESULT: await frames(5)
	await frames(15)
	await shot("slate_cut")
	while game.hud.slate.mode != "": await frames(5)
	await frames(30)
	await shot("result")
	# 成否が混ざったテイク（見た目の確認用に差し替える）
	var real_takes: Array = game.takes.duplicate(true)
	game.takes = fake_takes()
	game.selected = 0
	await frames(10)
	await shot("result_mixed")
	var chips: Array = []
	collect_boxes(game.hud.result_view, chips)
	chips[1].pressed.emit()
	await frames(5)
	print("UISHOT_CLICK select=", game.selected)
	game.selected = 0
	game.selected = 1
	await frames(10)
	await shot("result_pass")
	game.takes = real_takes
	game.selected = 0
	game.h_replay(0)
	await frames(50)
	await shot("replay")
	while game.state == game.S.REPLAY: await frames(15)
	game.h_deliver(0)
	await frames(40)
	await shot("delivered")
	while flow.phase != 5: await frames(10)
	await frames(60)
	await shot("settlement")
	game.h_return_office()
	await frames(30)
	game.set_character_menu(true)
	await frames(30)
	await shot("character")
	game.set_character_menu(false)
	game.help_open = true
	await frames(10)
	await shot("help")
	print("UISHOT_FLOW_OK")
	quit()
