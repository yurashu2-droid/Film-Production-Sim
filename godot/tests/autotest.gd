extends Node
# 自動確認：見本セット → 本番 → 合図1・2・3 → 結果 → 見返し。
#   godot --path godot -- --autotest [--shots]
# 画面つきで動かすと tests/shots に画像を残す。

var game: Node
var shots := false
var n := 0


func _ready() -> void:
	shots = "--shots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(tag: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	n += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	get_viewport().get_texture().get_image().save_png("res://tests/shots/%02d_%s.png" % [n, tag])
	game.film.view.get_texture().get_image().save_png("res://tests/shots/%02d_%s_film.png" % [n, tag])


func _run() -> void:
	var S: Dictionary = game.S
	await _wait(1.0)
	print("AUTOTEST props=", game.props.size(), " actors=", game.actors.size(), " players=", game.players.size())
	print("PREP hints(before)=", game.live["hints"])
	await _shot("start")
	await _hands_on()
	game.h_sample()
	await _wait(2.0)
	print("PREP hints(sample)=", game.live["hints"])
	for a in game.actors:
		print("  actor ", a.label, " pos=", a.global_position, " light=%.2f" % game.judge.brightness(a.get_world_3d().direct_space_state, a.head_pos()))
	print("  frame=", game.judge.frame)
	for p in game.props.values():
		if p.kind in ["balcony", "mark", "window", "camera", "spot", "plywood", "flat", "moon", "fx"]:
			print("  ", p.kind, " pos=", p.global_position, " up=%.2f" % p.global_basis.y.y, " layer=", p.collision_layer, " mask=", p.collision_mask, " freeze=", p.freeze)
	await _shot("sample")
	print("PERF fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	game.h_take()
	await _wait(3.4)
	print("state=", game.state, " (TAKE=", S.TAKE, ")")
	await _wait(0.6)
	game.h_cue(1)
	var t := 0.0
	while not game.judge.passed()[0] and t < 7.0:
		await _wait(0.25)
		t += 0.25
	print("confess passed=", game.judge.passed()[0], " after ", t, " acc=", game.judge.conf_acc, " why=", game.judge.why[0])
	await _shot("confess")
	await _wait(1.0)
	game.h_cue(2)
	await _wait(1.25)
	await _shot("boom")
	await _wait(1.3)
	print("boom passed=", game.judge.passed()[1], " why=", game.judge.why[1])
	game.h_cue(3)
	t = 0.0
	while game.state == S.TAKE and t < 20.0:
		await _wait(0.25)
		t += 0.25
		if is_equal_approx(t, 3.0):
			await _shot("reunion")
	print("take ended state=", game.state, " t=", t)
	for a in game.actors:
		print("  actor ", a.label, " pos=", a.global_position, " st=", a.st)
	if game.takes.is_empty():
		print("AUTOTEST_FAIL no take")
		get_tree().quit(1)
		return
	for r: Dictionary in game.takes[0]["results"]:
		print("  ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
	await _shot("result")
	game.h_replay(0)
	await _wait(6.0)
	print("replay state=", game.state, " t=%.1f" % game.replay_t)
	await _shot("replay")
	game.h_stop_replay()
	await _wait(0.3)
	game.h_deliver(0)
	await _wait(0.5)
	print("delivered ok=", game.delivered_ok, " state=", game.state)
	await _shot("delivered")
	var all_ok: bool = not false in game.takes[0]["passed"]
	print("AUTOTEST_OK" if all_ok and game.delivered_ok else "AUTOTEST_FAIL")
	get_tree().quit(0 if all_ok else 1)


# 持つ・回す・置く・固定・機材操作の確認
func _hands_on() -> void:
	var me: Node = game.local_player()
	var fx: Node3D = game.fx
	var ok := true
	me.aim_yaw = -1.2
	me.aim_pitch = -0.1
	game.h_grab(fx.pid)
	await _wait(1.2)
	var tgt: Array = game.hold_target(me.peer_id, fx)
	var err: float = fx.center_global().distance_to(tgt[0])
	print("HOLD held=", me.held == fx.pid, " err=%.2f" % err)
	ok = ok and me.held == fx.pid and err < 0.35
	me.aim_yaw = 0.4
	me.hold_yaw = 1.0
	await _wait(1.2)
	tgt = game.hold_target(me.peer_id, fx)
	err = fx.center_global().distance_to(tgt[0])
	print("HOLD moved err=%.2f yaw=%.2f want=%.2f" % [err, fx.global_rotation.y, wrapf(tgt[1], -PI, PI)])
	ok = ok and err < 0.35 and absf(angle_difference(fx.global_rotation.y, tgt[1])) < 0.15
	await _shot("holding")
	game.h_release()
	await _wait(1.0)
	print("RELEASE held=", me.held, " y=%.2f" % fx.global_position.y)
	ok = ok and me.held == 0 and fx.global_position.y < 0.1
	game.h_fix(fx.pid)
	await _wait(0.1)
	game.h_grab(fx.pid)
	await _wait(0.2)
	print("FIX fixed=", fx.fixed, " held=", me.held)
	ok = ok and fx.fixed and me.held == 0
	game.h_fix(fx.pid)
	var film: Node3D = game.film
	var p0: Vector3 = film.global_position
	game.h_operate(film.pid, true)
	await _wait(0.1)
	game.h_aim(film.pid, 0.3, 0.1, 2.0)
	game.input_locked = false
	Input.action_press("move_forward")
	await _wait(1.0)
	Input.action_release("move_forward")
	game.input_locked = true
	print("OPERATE op=", me.operating == film.pid, " yaw=%.2f fov=%.1f moved=%.2f" % [film.cam_yaw, film.fov, film.global_position.distance_to(p0)])
	ok = ok and me.operating == film.pid and absf(film.cam_yaw - 0.3) < 0.01 and film.global_position.distance_to(p0) > 1.0
	await _shot("viewfinder")
	game.h_operate(film.pid, false)
	var rig: Node3D = game.spots[0]
	game.h_operate(rig.pid, true)
	game.h_aim(rig.pid, 0.2, 0.1, 1.0)
	await _wait(0.1)
	print("SPOT pan=%.2f level=%d" % [rig.pan, rig.level])
	ok = ok and absf(rig.pan - 0.2) < 0.01 and rig.level == 3
	game.h_operate(rig.pid, false)
	await _wait(0.1)
	print("HANDS_ON_OK" if ok and me.operating == 0 else "HANDS_ON_FAIL")
