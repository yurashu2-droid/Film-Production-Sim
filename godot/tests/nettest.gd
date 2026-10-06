extends Node
# 2つ同時起動して、ホスト方式の同期を確かめる。
#   ホスト:   godot --headless --path godot -- --host --nettest
#   参加者:   godot --headless --path godot -- --join=127.0.0.1 --nettest
# 参加者側が「持つ → 見本 → 本番 → 合図」を出し、両方の画面で同じ結果になるかを見る。

var game: Node
var _host_actions: Array = []
var _reply: Dictionary = {}


# テスト用の要求はRPC外のフレームで実行し、ホスト本人の操作にする。
@rpc("any_peer", "call_remote", "reliable")
func _queue_host(action: String) -> void:
	if Net.is_host():
		_host_actions.append([multiplayer.get_remote_sender_id(), action])


func _process(_delta: float) -> void:
	if _host_actions.is_empty():
		return
	var request: Array = _host_actions.pop_front()
	match request[1]:
		"grab": game.act_grab(game.clapper.pid)
		"release": game.act_release()
		"choices":
			game.h_select_cast(3)
			for p in game.props.values():
				if p.kind == "carton":
					p.set_fixed(true)
					p.position = game.players[request[0]].position + Vector3(1, 0, 0)
					break
	await _wait(0.1)
	var client: Node = game.players.get(request[0])
	if client == null:
		return
	var carton: Node
	for p in game.props.values():
		if p.kind == "carton":
			carton = p
			break
	var clap: Node = game.clapper
	_host_reply.rpc_id(request[0], {
		"holder": clap.holder, "host": game.local_player().held, "client": client.held,
		"age": Time.get_ticks_msec() / 1000.0 - clap.grab_time, "state": game.state,
		"host_collision": clap.get_collision_exceptions().has(game.local_player()),
		"client_collision": clap.get_collision_exceptions().has(client),
		"pitch": client.hold_pitch, "animation": client.vis.current,
		"host_cast": game.local_player().vis.tag, "client_cast": client.vis.tag,
		"dust_count": get_tree().get_nodes_in_group("dash_dust").size(),
		"recorded_dust": game._rec_events.filter(func(e: Array): return e[1] == "dash_dust").size(),
		"carton_open": carton.opened, "carton_amount": carton.open_amount,
	})


@rpc("authority", "call_remote", "reliable")
func _host_reply(snapshot: Dictionary) -> void:
	_reply = snapshot


func _ask_host(action: String = "snapshot") -> Dictionary:
	_reply = {}
	_queue_host.rpc_id(1, action)
	var elapsed := 0.0
	while _reply.is_empty() and elapsed < 3.0:
		await _wait(0.05)
		elapsed += 0.05
	return _reply


func _clapper_is(s: Dictionary, owner: int, phase: String) -> bool:
	var pid: int = game.clapper.pid
	var host_held: int = pid if owner == 1 else 0
	var client_held: int = pid if owner == Net.my_id() else 0
	var ok: bool = s.get("holder", -1) == owner and s.get("host", -1) == host_held and s.get("client", -1) == client_held
	ok = ok and game.players[1].held == host_held and game.local_player().held == client_held
	ok = ok and s.get("host_collision", false) == (owner == 1) and s.get("client_collision", false) == (owner == Net.my_id())
	print("CLAPPER_NET ", phase, " ", "OK" if ok else "FAIL", " ", s)
	return ok



func _ready() -> void:
	name = "NetTest"
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	var who := "HOST" if Net.mode == "host" else "CLIENT"
	var S: Dictionary = game.S
	var t := 0.0
	while game.players.size() < 2 and t < 20.0:
		await _wait(0.2)
		t += 0.2
	print(who, " players=", game.players.size(), " my_id=", Net.my_id())
	if game.players.size() < 2:
		print(who, " NETTEST_FAIL no peer")
		get_tree().quit(1)
		return
	if Net.mode == "host":
		while game.state != S.RESULT and t < 70.0:
			await _wait(0.5)
			t += 0.5
		_report(who)
		var host_ok: bool = game.state == S.RESULT and not game.takes.is_empty() and not false in game.takes[0]["passed"]
		print(who, " NETTEST_OK" if host_ok else " NETTEST_FAIL")
		await _wait(2.0)
		get_tree().quit(0 if host_ok else 1)
		return

	var me: Node = game.local_player()
	game.h_select_cast.rpc_id(1, 5)
	for id in ["balcony", "dolly"]:
		game.h_order_set.rpc_id(1, id, 1)
	game.h_order_confirm.rpc_id(1)
	await _wait(1.0)
	print(who, " order state=", game.state, " fx_absent=", game.fx.absent, " balcony_visible=", game.order)
	var choice_sync: Dictionary = await _ask_host("choices")
	var choice_ok: bool = choice_sync.get("host_cast", "") == "03" and choice_sync.get("client_cast", "") == "02"
	choice_ok = choice_ok and me.vis.tag == "02" and game.players[1].vis.tag == "03"
	print("CHOICE_PHASE_CAST ", choice_ok, " host=", game.players[1].vis.tag, " client=", me.vis.tag, " ", choice_sync)
	var carton: Node
	for p in game.props.values():
		if p.kind == "carton":
			carton = p
			break
	game.act_toggle_carton(carton.pid)
	await _wait(0.8)
	choice_sync = await _ask_host()
	choice_ok = choice_ok and not choice_sync.get("carton_open", true) and float(choice_sync.get("carton_amount", 1.0)) == 0.0
	choice_ok = choice_ok and not carton.opened and carton.open_amount == 0.0
	print("CHOICE_PHASE_CLOSE ", carton.opened, " ", carton.open_amount, " ", choice_sync)
	game.act_toggle_carton(carton.pid)
	await _wait(0.8)
	print("CHOICE_PHASE_OPEN ", carton.opened, " ", carton.open_amount)
	choice_ok = choice_ok and carton.opened and carton.open_amount == 1.0
	print("CHOICE_NET_OK" if choice_ok else "CHOICE_NET_FAIL", " ", choice_sync)
	# 短い走り出しのクリップ名も相手側まで届く。
	game.input_locked = false
	Input.action_press("run")
	Input.action_press("move_forward")
	await _wait(0.06)
	var motion_sync: Dictionary = await _ask_host()
	Input.action_release("move_forward")
	Input.action_release("run")
	game.input_locked = true
	var motion_net_ok: bool = motion_sync.get("animation", "") == "run_start"
	print("MOTION_NET_OK" if motion_net_ok else "MOTION_NET_FAIL")
	var dust_net_ok: bool = motion_sync.get("dust_count", 0) == 1 and get_tree().get_nodes_in_group("dash_dust").size() == 1
	print("DUST_NET_OK" if dust_net_ok else "DUST_NET_FAIL")
	var fx: Node3D = game.clapper
	await _wait(0.5)
	var p0: Vector3 = fx.global_position
	me.aim_yaw = -1.0
	game.act_grab(fx.pid)
	await _wait(1.5)
	var moved: float = fx.global_position.distance_to(p0)
	print(who, " grab held=", me.held == fx.pid, " prop moved on my screen=%.2f" % moved)
	var ok: bool = choice_ok and motion_net_ok and dust_net_ok and me.held == fx.pid and moved > 0.5 and game.state == S.PREP and game.fx.absent
	me.hold_yaw = 0.45
	me.hold_pitch = 0.35
	await _wait(0.8)
	var carry_sync: Dictionary = await _ask_host()
	var rotated := Basis.from_euler(Vector3(me.hold_pitch, me.aim_yaw + me.hold_yaw, 0.0))
	var carry_ok: bool = absf(carry_sync.get("pitch", -10.0) - 0.35) < 0.01 and carry_sync.get("animation", "").begins_with("onehand_")
	carry_ok = carry_ok and fx.global_basis.orthonormalized().get_rotation_quaternion().angle_to(rotated.get_rotation_quaternion()) < 0.2
	print("CARRY_NET_OK" if carry_ok else "CARRY_NET_FAIL", " ", carry_sync)
	ok = ok and carry_ok
	game.act_release()
	await _wait(0.5)
	ok = ok and me.held == 0
	var s := await _ask_host("grab")
	var steal_ok := _clapper_is(s, 1, "host_pickup")
	game.act_grab(game.clapper.pid)
	await _wait(0.15)
	s = await _ask_host()
	steal_ok = _clapper_is(s, 1, "first_second_protected") and float(s.get("age", 2.0)) < 1.0 and steal_ok
	await _wait(1.1)
	game.act_grab(game.clapper.pid)
	await _wait(0.15)
	s = await _ask_host()
	steal_ok = _clapper_is(s, Net.my_id(), "client_steals") and steal_ok
	s = await _ask_host("grab")
	steal_ok = _clapper_is(s, Net.my_id(), "client_first_second_protected") and float(s.get("age", 2.0)) < 1.0 and steal_ok
	await _wait(1.1)
	s = await _ask_host("grab")
	steal_ok = _clapper_is(s, 1, "host_steals_back") and steal_ok
	game.act_release()  # 元の持ち主が離しても、取り返した人の物は落ちない
	await _wait(0.15)
	s = await _ask_host()
	steal_ok = _clapper_is(s, 1, "former_owner_release") and steal_ok
	s = await _ask_host("release")
	steal_ok = _clapper_is(s, 0, "release") and steal_ok
	game.h_sample.rpc_id(1)
	await _wait(2.0)
	var balcony: Node3D
	for p in game.props.values():
		if p.kind == "balcony":
			balcony = p
	print(who, " sample balcony=", balcony.global_position, " actorA=", game.actors[0].global_position, " hints=", game.live["hints"])
	ok = ok and balcony.global_position.distance_to(Vector3(0, 0, -3)) < 0.2 and game.actors[0].global_position.y > 0.7
	game.act_grab(game.clapper.pid)
	await _wait(0.2)
	game.act_use()
	await _wait(1.3)
	s = await _ask_host("grab")
	steal_ok = _clapper_is(s, Net.my_id(), "countdown_protected") and s.get("state", -1) == S.COUNTDOWN and float(s.get("age", 0.0)) >= 1.0 and steal_ok
	await _wait(2.0)
	game.act_release()
	await _wait(0.2)
	print("CLAPPER_NET_OK" if steal_ok else "CLAPPER_NET_FAIL")
	ok = ok and steal_ok and game.state == S.TAKE
	game.act_dash_dust()
	var dust_record: Dictionary = await _ask_host()
	var dust_record_ok: bool = dust_record.get("recorded_dust", 0) == 1
	print("DUST_RECORD_OK" if dust_record_ok else "DUST_RECORD_FAIL")
	ok = ok and dust_record_ok
	game.h_cue.rpc_id(1, 1)
	await _wait(4.5)
	game.h_cue.rpc_id(1, 2)
	await _wait(2.5)
	game.h_cue.rpc_id(1, 3)
	t = 0.0
	while game.state != S.RESULT and t < 30.0:
		await _wait(0.5)
		t += 0.5
	_report(who)
	ok = ok and game.state == S.RESULT and not game.takes.is_empty() and not false in game.takes[0]["passed"]
	print(who, " NETTEST_OK" if ok else " NETTEST_FAIL")
	get_tree().quit(0 if ok else 1)


func _report(who: String) -> void:
	print(who, " state=", game.state, " takes=", game.takes.size())
	if not game.takes.is_empty():
		for r: Dictionary in game.takes[0]["results"]:
			print(who, "   ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
	for a in game.actors:
		print(who, "   ", a.label, " pos=", a.global_position)
