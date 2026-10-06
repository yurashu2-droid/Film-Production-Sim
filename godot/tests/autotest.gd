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
	var balcony_route: bool = "--route=balcony" in OS.get_cmdline_user_args()
	await _shot("order")
	if balcony_route:
		for id in ["balcony", "dolly", "fix", "rose"]:
			game.h_order_set(id, 1)
	else:
		for id in ["fx", "refill", "dolly"]:
			game.h_order_set(id, 1)
	game.h_order_set("balcony" if not balcony_route else "fx", 1)      # 予算オーバーは通らないはず
	await _shot("order_chosen")
	var cost: int = game.order_cost()
	game.h_order_confirm()
	await _wait(0.6)
	var on_truck := 0
	for p in game.props.values():
		if p.rider_of == game.truck.pid:
			on_truck += 1
	print("ORDER route=", "balcony" if balcony_route else "fx", " cost=", cost, " state=", game.state, " on_truck=", on_truck, " fx_absent=", game.fx.absent, " charges=", game.fx.charges)
	if cost > 600 or game.state != S.PREP or on_truck < 4:
		print("AUTOTEST_FAIL order")
	print("AUTOTEST props=", game.props.size(), " actors=", game.actors.size(), " players=", game.players.size())
	print("PREP hints(before)=", game.live["hints"])
	await _shot("start")
	if not balcony_route:
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
	await _measure_performance()
	await _shot("sample")
	# カチンコを持って打つと本番が始まる
	game.h_use()
	await _wait(0.1)
	var no_clapper_start: bool = game.state == S.PREP
	game.h_grab(game.clapper.pid)
	await _wait(0.4)
	await _shot("clapper_held")
	game.h_use()
	await _wait(1.2)
	print("CLAPPER start_without=", not no_clapper_start, " countdown=", game.state == S.COUNTDOWN)
	await _shot("slate")
	if not no_clapper_start or game.state != S.COUNTDOWN:
		print("AUTOTEST_FAIL clapper")
	await _wait(2.0)
	await _shot("slate_clap")
	await _wait(0.2)
	game.h_release()
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


# PNGの保存直後の瞬間値には保存処理の停止時間が混ざるため、
# 画像を保存しない連続2秒の通常描画を測る。
func _measure_performance() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var main_view: Viewport = get_viewport()
	var film_view: Viewport = game.film.view
	for vp: Viewport in [main_view, film_view]:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	var start := Time.get_ticks_usec()
	var count := 0
	var draws := 0.0
	var gpu_ms := 0.0
	while Time.get_ticks_usec() - start < 2000000:
		await get_tree().process_frame
		count += 1
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		for vp: Viewport in [main_view, film_view]:
			gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
	var fps := count * 1000000.0 / (Time.get_ticks_usec() - start)
	print("PERF steady fps=%.1f draw_calls=%.0f gpu_ms=%.2f" % [fps, draws / count, gpu_ms / count])
	for vp: Viewport in [main_view, film_view]:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), false)


# 持つ・回す・置く・固定・機材操作の確認
func _hands_on() -> void:
	var me: Node = game.local_player()
	var fx: Node3D = game.fx
	var ok := true
	me.aim_yaw = -1.2
	me.aim_pitch = -0.1
	# 持つ・回す確認は床の空いた場所で行う。荷台の他の積み荷で進路を塞がない。
	game.host_unload(fx)
	var pick_pos: Vector3 = me.global_position + me.flat_forward() * 2.0
	pick_pos.y = 0.02
	fx.restore([pick_pos, Quaternion.IDENTITY, false, fx.charges])
	await _wait(0.2)
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
	var cart: Node3D
	for p in game.props.values():
		if p.kind == "dolly":
			cart = p
	# 台車に物を載せる → 一緒に動く → 持つと降りる
	cart.restore([Vector3(4.0, 0.0, 6.0), Quaternion(Vector3.UP, PI), false])
	fx.restore([Vector3(4.0, 1.0, 6.0), Quaternion.IDENTITY, false])
	game._try_load(fx)
	await _wait(0.2)
	var on_cart: bool = fx.rider_of == cart.pid
	cart.linear_velocity = Vector3(2.0, 0, 0)
	await _wait(0.5)
	var follow: float = Vector2(fx.global_position.x - cart.global_position.x, fx.global_position.z - cart.global_position.z).length()
	game.h_grab(fx.pid)
	await _wait(0.2)
	print("CART loaded=", on_cart, " follow_gap=%.2f y=%.2f" % [follow, fx.global_position.y], " after_grab_rider=", fx.rider_of)
	ok = ok and on_cart and follow < 0.05 and fx.rider_of == 0
	game.h_release()
	# ライトを持つと、見ている方向へ光が向く
	var hand: Node3D = game.spots[1]
	me.aim_pitch = 0.3
	game.h_grab(hand.pid)
	await _wait(0.8)
	print("HANDLIGHT tilt=%.2f pan=%.2f" % [hand.tilt, hand.pan])
	ok = ok and absf(hand.tilt - 0.38) < 0.05 and absf(hand.pan) < 0.05
	game.h_release()
	me.aim_pitch = -0.1
	# カメラを台車に載せて移動撮影
	cart.restore([Vector3(film.global_position.x, 0, film.global_position.z), Quaternion(Vector3.UP, PI), false])
	film.restore([cart.global_position + Vector3(0, cart.deck_top, 0), Quaternion.IDENTITY, false, 0.0, 0.0, 52.0])
	game.host_load(film, cart)
	await _wait(0.3)
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
