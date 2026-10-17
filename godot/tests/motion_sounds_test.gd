extends SceneTree
# 体と物の動きの音（scripts/features/motion_sounds.gd）を確かめる。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/motion_sounds_test.gd
# 歩く・走ると足が着くたびに足音、跳んで降りると着地、持った物を振る・物が吹き飛ぶと風切り。
# 立っているだけ・物が落ちるだけ・置き直しでは鳴らない。
var game: Node
var failed := false
var heard: Array = []          # [名前, 秒]


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("MOTION_SOUNDS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func count(name: String) -> int:
	return heard.filter(func(h: Array) -> bool: return h[0] == name).size()


func times(name: String) -> Array:
	return heard.filter(func(h: Array) -> bool: return h[0] == name).map(func(h: Array) -> float: return h[1])


func intervals(name: String) -> Array:
	var t := times(name)
	var out: Array = []
	for i in range(1, t.size()):
		out.append(snappedf(t[i] - t[i - 1], 0.01))
	return out


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var sounds: Node = game.hooks.feature("motion_sounds")
	check(sounds != null, "足音と風切りの仕組みがある")
	var sfx: Node = root.get_node("Sfx")
	check(sfx.has_sound("step") and sfx.has_sound("land") and sfx.has_sound("whoosh") and sfx.has_sound("whoosh_soft"), "足音・着地・風切りの音がある")
	sfx.played.connect(func(s: String, _p: Variant) -> void: heard.append([s, Engine.get_physics_frames() / 60.0]))
	var me: Node3D = game.local_player()
	me.set_cast("01")               # 足のあるキャラ（車輪のロボット M02 は足音なし）
	me.global_position = Vector3(72, 0.1, 14)
	me.aim_pitch = -0.25
	me.aim_yaw = -PI * 0.5
	await frames(30)

	# 立っているだけ：鳴らない
	heard.clear()
	await frames(60)
	check(count("step") == 0, "立っているだけでは足音は鳴らない")

	# 歩く
	game.input_locked = false
	Input.action_press("move_forward")
	await frames(150)
	print("MOTION_SOUNDS_MEASURE 歩き：%d歩 間隔 %s" % [count("step"), intervals("step")])
	var walk := count("step")
	check(walk >= 3 and walk <= 7, "歩くと、2.5秒で3〜7歩の足音（%d）" % walk)
	# 走る
	heard.clear()
	me.aim_yaw = PI * 0.5           # 来た道を戻る（開けている）
	Input.action_press("run")
	await frames(150)
	Input.action_release("run")
	Input.action_release("move_forward")
	var run_iv := intervals("step")
	print("MOTION_SOUNDS_MEASURE 走り：%d歩 間隔 %s" % [count("step"), run_iv])
	check(count("step") > walk, "走ると、歩くより足音が多い（%d）" % count("step"))
	# 走り出しの踏み切り（素早い2歩）と、走りへ移る間（約0.5秒）のあとは、走りの動きの1歩ごと
	var even := run_iv.size() >= 5 and run_iv.slice(3).all(func(v: float) -> bool: return v > 0.25 and v < 0.5)
	check(even, "走っている間の足音は0.25〜0.5秒おき")
	await frames(40)
	heard.clear()
	await frames(40)
	check(count("step") == 0, "止まると足音も止まる")

	# 跳んで降りる
	heard.clear()
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(70)
	check(count("land") == 1, "跳んで降りると、着地の音が1回（%d）" % count("land"))
	game.input_locked = true

	# 物：落ちるだけ・置き直しでは鳴らない。吹き飛ぶと鳴る
	var prop: RigidBody3D = null
	for id: int in game.props:
		var p: RigidBody3D = game.props[id]
		if not p.immovable and not p.absent and not p.fixed and p.stored_in == 0 and p.holder == 0 and p.mass <= 6.0 and p.kind != "clapper":
			prop = p
			break
	check(prop != null, "軽い物がある")
	var spot := me.global_position + Vector3(-3.0, 0.0, 0.0)
	heard.clear()
	prop.restore([spot + Vector3(0, 3.0, 0), Quaternion.IDENTITY, false])
	await frames(90)
	check(count("whoosh") + count("whoosh_soft") == 0, "置き直し・落ちて倒れるだけでは風切りは鳴らない")
	heard.clear()
	prop.launch(spot + Vector3(0, 0.6, 0), Vector3(0, 4.0, 15.0), Vector3(0, 0, 6.0))
	await frames(30)
	print("MOTION_SOUNDS_MEASURE 飛ばした：%s" % [heard.map(func(h: Array) -> String: return h[0])])
	check(count("whoosh") + count("whoosh_soft") == 1 and count("whoosh") == 1, "勢いよく飛ばすと「ブンッ」が1回だけ")
	await frames(120)

	# 持った物を、振り向いて振る
	prop.restore([me.global_position + Vector3(-1.2, 1.0, 0.0), Quaternion.IDENTITY, false])
	await frames(10)
	game.act_grab(prop.pid)
	await frames(40)
	check(prop.holder == me.peer_id, "物を持った")
	heard.clear()
	for i in 10:
		me.aim_yaw += 0.12          # 0.17秒で約70度振り向く
		await physics_frame
	await frames(10)
	print("MOTION_SOUNDS_MEASURE 振り向き：%s" % [heard.map(func(h: Array) -> String: return h[0])])
	check(count("whoosh") + count("whoosh_soft") == 1, "持ったまま勢いよく振り向くと、風切りが1回")
	heard.clear()
	for i in 40:
		me.aim_yaw += 0.01          # ゆっくり回すと鳴らない
		await physics_frame
	check(count("whoosh") + count("whoosh_soft") == 0, "ゆっくり回すと風切りは鳴らない")

	# 車輪のロボット：走っている間、車輪とモーターの音がくり返し鳴る。止まると止む。足音は鳴らない
	me.set_cast("M02")
	me.aim_yaw = -PI * 0.5
	await frames(20)
	heard.clear()
	game.input_locked = false
	Input.action_press("move_forward")
	await frames(90)
	var tire: AudioStreamPlayer3D = me.get_node_or_null("robot_tire")
	var motor: AudioStreamPlayer3D = me.get_node_or_null("robot_motor")
	check(tire != null and motor != null and tire.playing and motor.playing, "車輪のロボットが走ると、車輪とモーターの音が鳴る")
	if motor != null:
		print("MOTION_SOUNDS_MEASURE ロボット：音量 %.1fdB 高さ %.2f" % [motor.volume_db, motor.pitch_scale])
	check(count("step") == 0, "車輪のロボットは足音を鳴らさない")
	Input.action_release("move_forward")
	game.input_locked = true
	await frames(90)
	check(tire != null and not tire.playing and not motor.playing, "止まると、車輪とモーターの音が止む")
	# 走りながら跳んで降りると「ガタッ」（人の着地音ではない）。モーターは一瞬止まって、戻る
	game.input_locked = false
	Input.action_press("move_forward")
	await frames(40)
	heard.clear()
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var stalled := false
	for i in 80:
		await physics_frame
		if count("robot_land") > 0 and motor != null and motor.volume_db < -50.0:
			stalled = true
	await frames(30)
	var revived: bool = motor != null and motor.playing and motor.volume_db > -45.0
	Input.action_release("move_forward")
	game.input_locked = true
	check(count("robot_land") == 1 and count("land") == 0, "ロボットが跳んで降りると「ガタッ」が1回（人の着地音は鳴らない）")
	check(stalled and revived, "着地でモーターが一瞬止まり、また鳴り出す")
	await frames(60)

	# 画面のボタン：乗せると「カチ」、押すと「カシャッ」。自分で鳴らすボタン（own_sfx）は鳴らさない
	heard.clear()
	var button := Button.new()
	root.add_child(button)
	button.mouse_entered.emit()
	button.pressed.emit()
	var quiet := Button.new()
	quiet.set_meta("own_sfx", true)
	root.add_child(quiet)
	quiet.mouse_entered.emit()
	quiet.pressed.emit()
	check(count("ui_hover") == 1 and count("ui_press") == 1, "ボタンに乗せると ui_hover、押すと ui_press が1回ずつ鳴る")
	button.queue_free()
	quiet.queue_free()
	# メニュー（Escape の一時メニューなど）：開くとページをめくる音、閉じると本を閉じる音
	heard.clear()
	game.open_menu("pause")
	game.close_menu()
	check(count("menu_open") == 1 and count("menu_close") == 1, "メニューを開くと menu_open、閉じると menu_close")
	print("MOTION_SOUNDS_MEASURE 鳴らした数：足音 %d・着地 %d・風切り %d" % [sounds.steps, sounds.lands, sounds.swishes])
	print("MOTION_SOUNDS_TEST_FAIL" if failed else "MOTION_SOUNDS_TEST_OK")
	sfx.silence_all()
	quit(1 if failed else 0)
