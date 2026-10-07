extends Node
# 本番の ENet/RPC を二つのプロセスで通す。位置と時計だけテスト用 RPC で準備する。
var game: Node
var _requests: Array = []
var _reply: Dictionary = {}
var _done := false
var _failed := false

func _ready() -> void:
	name = "ProductionNetTest"
	_run.call_deferred()

@rpc("any_peer", "call_remote", "reliable")
func _request(action: String, success: bool = true) -> void:
	if Net.is_host():
		_requests.append([multiplayer.get_remote_sender_id(), action, success])

@rpc("authority", "call_remote", "reliable")
func _respond(data: Dictionary) -> void:
	_reply = data

func _process(_delta: float) -> void:
	if _requests.is_empty():
		return
	var request: Array = _requests.pop_front()
	match request[1]:
		"host_far":
			game.production_move.rpc(game.production.Office.SPAWN_POINT, 0.0, 1)
		"host_near":
			game.production_move.rpc(game.production.HOME_TRUCK + Vector3(-3,0.1,0), 0.0, 1)
		"lift_fixture":
			var lift := _lift()
			game.production._move(lift, Vector3(12,0.1,4))
			lift.set_fixed(true)
			game.host_unload(game.film)
			game.host_load(game.film,lift)
			game.production_move.rpc(Vector3(11,0.1,4),0.0,request[0])
		"expire":
			game.production.lease_left = 0.01
		"done":
			_failed = not request[2]
			_done = true
	await _wait(0.65)
	var data: Dictionary = game.production.snapshot()
	data["host_position"] = game.players[1].global_position
	data["client_position"] = game.players[request[0]].global_position
	data["film_rider"] = game.film.rider_of
	data["clapper_rider"] = game.clapper.rider_of
	data["truck_position"] = game.truck.global_position
	data["cargo"] = game.production.cargo()
	data["site"] = _site_status()
	var lift := _lift()
	data["lift"] = {"active":lift.active,"time":lift.action_time,"top":lift.deck_top}
	data["film_local_y"] = game.film.ride_local.origin.y
	_respond.rpc_id(request[0], data)

func _lift() -> Node:
	for prop: Node in game.props.values():
		if prop.kind == "lift_cart":
			return prop
	return null

func _site_status() -> Dictionary:
	var site: Node = game.production._site_root
	var walls_disabled: bool = not game.production._original_walls.is_empty()
	for wall: Node in game.production._original_walls:
		for shape: Node in wall.get_children():
			if shape is CollisionShape3D:
				walls_disabled = walls_disabled and shape.disabled
	return {"root":is_instance_valid(site),"studio":is_instance_valid(site) and site.find_child("studio",true,false) != null,"walls_disabled":walls_disabled}

func _lift_matches(data: Dictionary, active: bool, endpoint: float = -1.0) -> bool:
	var lift := _lift()
	var state: Dictionary = data.get("lift",{})
	var ok: bool = lift.active == active and state.get("active",not active) == active
	ok = ok and absf(lift.action_time - float(state.get("time",-10))) < 0.15 and absf(lift.deck_top - float(state.get("top",-10))) < 0.03
	if endpoint >= 0.0:
		ok = ok and absf(lift.action_time-endpoint) < 0.02
	ok = ok and game.film.rider_of == lift.pid and data.get("film_rider") == lift.pid and absf(game.film.ride_local.origin.y-float(data.get("film_local_y",-10))) < 0.03
	if not ok:
		print("LIFT_SYNC_DETAIL host=",state," local=",lift.active,"/",lift.action_time,"/",lift.deck_top," film_y=",game.film.ride_local.origin.y,"/",data.get("film_local_y"))
	return ok

func _press_lift(lift: Node) -> void:
	game.local_player().target = lift
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	game.input_locked = false
	game._input(event)
	game.input_locked = true

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ask(action: String = "snapshot") -> Dictionary:
	_reply = {}
	_request.rpc_id(1, action, not _failed)
	var elapsed := 0.0
	while _reply.is_empty() and elapsed < 5.0:
		await _wait(0.05)
		elapsed += 0.05
	if _reply.is_empty():
		_check(false, "host reply " + action)
	return _reply

func _check(ok: bool, label: String) -> void:
	print("PRODUCTION_NET ", label, " ", "OK" if ok else "FAIL")
	_failed = _failed or not ok

func _phase(expected: int, timeout: float = 4.0) -> bool:
	var elapsed := 0.0
	while game.production.phase != expected and elapsed < timeout:
		await _wait(0.1)
		elapsed += 0.1
	return game.production.phase == expected

func _run() -> void:
	var elapsed := 0.0
	while game.players.size() < 2 and elapsed < 25.0:
		await _wait(0.2)
		elapsed += 0.2
	if game.players.size() < 2:
		print("PRODUCTIONNET_FAIL no peer")
		get_tree().quit(1)
		return
	game.input_locked = true
	if Net.is_host():
		elapsed = 0.0
		while not _done and elapsed < 60.0:
			await _wait(0.2)
			elapsed += 0.2
		await _wait(1.5)
		var ok := _done and not _failed
		print("HOST PRODUCTIONNET_OK" if ok else "HOST PRODUCTIONNET_FAIL")
		get_tree().quit(0 if ok else 1)
		return
	await _wait(0.8)
	var s := await _ask()
	_check(s.get("phase") == 0 and game.production.phase == 0 and s.get("wallet") == 600 and game.production.wallet == 600, "office cash synchronized")
	_check(game.local_player().position.x > 60 and s.get("client_position", Vector3.ZERO).x > 60 and game.players[1].position.x > 60, "late join spawns in office on both peers")
	game.h_accept_job.rpc_id(1, 1)
	_check(await _phase(1), "client accepts studio job")
	game.h_order_set.rpc_id(1, "fx", 1)
	game.h_order_set.rpc_id(1, "dolly", 1)
	await _wait(0.25)
	game.h_order_confirm.rpc_id(1)
	_check(await _phase(2), "client confirms purchase")
	s = await _ask("host_far")
	_check(s.get("wallet") == 160 and game.production.wallet == 160 and s.get("expenses") == 440 and game.production.expenses == 440, "purchase cash synchronized")
	game.local_player().global_position = game.production.HOME_TRUCK + Vector3(-3,0.1,1)
	game.local_player().velocity = Vector3.ZERO
	await _wait(0.5)
	game.h_depart.rpc_id(1)
	await _wait(0.4)
	s = await _ask()
	_check(s.get("phase") == 2 and game.production.phase == 2, "departure waits for distant host")
	s = await _ask("host_near")
	_check(s.get("film_rider") == game.truck.pid and game.film.rider_of == game.truck.pid and s.get("clapper_rider") == game.truck.pid and game.clapper.rider_of == game.truck.pid, "required truck riders synchronized")
	_check(s.get("cargo", []).has(game.film.pid) and game.production.cargo().has(game.film.pid), "cargo synchronized")
	var started := Time.get_ticks_msec()
	game.h_depart.rpc_id(1)
	_check(await _phase(3), "client departs with crew")
	await _wait(1.0)
	s = await _ask()
	_check(s.get("phase") == 3 and game.production.trip_time > 0 and game.truck.position.distance_to(s.get("truck_position", Vector3.ZERO)) < 4.0, "travel progress and truck synchronized")
	_check(await _phase(4, 12.0), "arrival")
	_check(Time.get_ticks_msec() - started >= 7900, "journey lasts eight seconds")
	s = await _ask()
	_check(game.production.lease_left > 590 and float(s.get("lease_left", 0)) > 590 and game.production.chosen_job == 1, "ten minute studio lease synchronized")
	_check(game.film.rider_of == game.truck.pid and game.film.position.x < 25 and game.truck.position.distance_to(game.production.SITE_TRUCK) < 0.2, "cargo arrives attached")
	var site_expected := {"root":true,"studio":true,"walls_disabled":true}
	_check(_site_status() == site_expected and s.get("site",{}) == site_expected,"studio model and old wall colliders synchronized")
	s = await _ask("lift_fixture")
	var lift := _lift()
	var base_y: float = game.film.ride_local.origin.y
	_press_lift(lift)
	await _wait(0.3)
	s = await _ask()
	var lift_ok: bool = _lift_matches(s,true) and lift.action_time > 0.0 and lift.action_time < 3.0
	await _wait(2.6)
	s = await _ask()
	lift_ok = _lift_matches(s,true,3.0) and game.film.ride_local.origin.y > base_y + 0.45 and lift_ok
	_press_lift(lift)
	await _wait(3.2)
	s = await _ask()
	lift_ok = _lift_matches(s,false,0.0) and absf(game.film.ride_local.origin.y-base_y) < 0.03 and lift_ok
	_check(lift_ok,"free lift F up/down action and camera local height synchronized")
	s = await _ask("expire")
	_check(game.production.expired and s.get("expired", false) and game.state == game.S.RESULT and game.takes.size() == 1, "expiry creates deliverable take")
	game.h_deliver.rpc_id(1, 0)
	_check(await _phase(5), "client delivers after expiry")
	s = await _ask()
	_check(s.get("wallet") == 310 and game.production.wallet == 310 and s.get("last_payment") == 150 and game.production.last_payment == 150, "settlement cash synchronized")
	game.h_return_office.rpc_id(1)
	_check(await _phase(0), "client returns to office")
	s = await _ask()
	_check(game.production.wallet == 310 and s.get("wallet") == 310 and game.local_player().position.x > 60 and game.players[1].position.x > 60, "return spawn and cash synchronized")
	await _ask("done")
	print("CLIENT PRODUCTIONNET_FAIL" if _failed else "CLIENT PRODUCTIONNET_OK")
	get_tree().quit(1 if _failed else 0)

