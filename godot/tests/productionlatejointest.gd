extends Node
# Two real ENet processes; only fixtures and inspection use test RPCs.
const PORT := 24681
const GAME := preload("res://production_game.tscn")
var game: Node
var role := "client"
var failed := false
var done := false
var cleanup_ok := false
var departed_peer := 0
var joining := false
var reply := {}
var lift: Node
var first_host_position := Vector3.ZERO
var rejoin_host_position := Vector3.ZERO

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--productionlatejoin="):
			role = argument.get_slice("=",1)
	Net.joined_host.connect(_joined)
	_run.call_deferred()

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(ok: bool, label: String) -> void:
	print("PRODUCTION_LATEJOIN_CHECK ",label," ","OK" if ok else "FAIL")
	failed = failed or not ok

func create_game() -> void:
	game = GAME.instantiate()
	game.name = "Game"
	get_tree().root.add_child(game)
	lift = null
	for prop in game.props.values():
		if prop.kind == "lift_cart":
			lift = prop

func _joined() -> void:
	if joining:
		joining = false
		_create_joined_game.call_deferred()

func _create_joined_game() -> void:
	create_game()
	game.h_hello.rpc_id(1)

func connect_client() -> bool:
	joining = true
	check(Net.join("127.0.0.1",PORT) == OK,"client ENet socket opens")
	var elapsed := 0.0
	while (game == null or game.players.size() < 2) and elapsed < 12.0:
		await wait(0.05)
		elapsed += 0.05
	return game != null and game.players.size() == 2

func snapshot() -> Dictionary:
	var state: Dictionary = game.production.snapshot()
	var locals := 0
	for player in game.players.values():
		locals += int(player.is_local)
	var disabled := true
	for wall in game.production._original_walls:
		for child in wall.get_children():
			if child is CollisionShape3D:
				disabled = disabled and child.disabled
	state.merge({"path":str(game.get_path()),"count":game.players.size(),"locals":locals,
		"host_position":game.players[1].global_position,"state":game.state,"tally":game.film.tally.visible,
		"viewport_always":game.film.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"yard":game.production._site_root != null and game.production._site_root.get_node_or_null("ProductionDecor_yard/shutter") != null,
		"walls_disabled":disabled,"truck":game.truck.global_position,"lift":lift.global_position,
		"camera":game.film.global_position,"lift_rider":lift.rider_of,"camera_rider":game.film.rider_of,
		"cargo":game.production.cargo(),"film_operator":game.film.operator,"clapper_holder":game.clapper.holder,
		"cleanup_ok":cleanup_ok,"first_host_position":first_host_position,"rejoin_host_position":rejoin_host_position})
	return state

@rpc("any_peer","call_remote","reliable")
func request(action: String, client_ok: bool = true) -> void:
	if role != "host":
		return
	var sender := multiplayer.get_remote_sender_id()
	if action == "prepare_rejoin":
		departed_peer = sender
		game.production_move.rpc(Vector3(0,0.1,8),0.0,1)
		await wait(0.2)
		rejoin_host_position = game.players[1].global_position
		_after_disconnect.call_deferred()
	elif action == "done":
		failed = failed or not client_ok
		done = true
	await wait(0.1)
	respond.rpc_id(sender,snapshot())

@rpc("authority","call_remote","reliable")
func respond(data: Dictionary) -> void:
	reply = data

func ask(action := "snapshot") -> Dictionary:
	reply = {}
	request.rpc_id(1,action,not failed)
	var elapsed := 0.0
	while reply.is_empty() and elapsed < 6.0:
		await wait(0.05)
		elapsed += 0.05
	check(not reply.is_empty(),"host reply " + action)
	return reply

func _after_disconnect() -> void:
	var elapsed := 0.0
	while game.players.has(departed_peer) and elapsed < 5.0:
		await wait(0.05)
		elapsed += 0.05
	cleanup_ok = not game.players.has(departed_peer) and game.film.operator == 0 and game.clapper.holder == 0
	check(cleanup_ok,"departed peer roster holder and operator cleaned on host")
	game.h_take()
	await wait(3.2)
	check(game.state == game.S.TAKE,"host starts take before rejoin")
	print("PRODUCTION_LATEJOIN_TAKE_READY")

func compare_state(host_state: Dictionary, label: String) -> void:
	var local := snapshot()
	check(local.wallet == host_state.get("wallet") and local.expenses == host_state.get("expenses") and local.chosen_job == host_state.get("chosen_job") and local.expired == host_state.get("expired") and absf(local.lease_left-float(host_state.get("lease_left",0))) < 1.0,label + " company and lease synchronized")
	check(local.path == host_state.get("path") and local.count == 2 and local.locals == 1 and host_state.get("locals") == 1 and game.local_player().is_local and not game.players[1].is_local,label + " Game path and exactly one local player")
	check(local.lift_rider == host_state.get("lift_rider") and local.camera_rider == host_state.get("camera_rider") and local.lift_rider == game.truck.pid and local.camera_rider == lift.pid and local.cargo.has(game.film.pid) and host_state.get("cargo",[]).has(game.film.pid),label + " truck lift camera nested cargo synchronized")
	var position_ok: bool = local.truck.distance_to(host_state.get("truck",Vector3.ZERO)) < 1.0 and local.lift.distance_to(host_state.get("lift",Vector3.ZERO)) < 1.0 and local.camera.distance_to(host_state.get("camera",Vector3.ZERO)) < 1.0
	check(position_ok,label + " cargo world positions synchronized")
	if not position_ok:
		print("LATEJOIN_POSITION_DETAIL ",label," client=",[local.truck,local.lift,local.camera]," host=",[host_state.truck,host_state.lift,host_state.camera])

func _run() -> void:
	if role == "host":
		check(Net.host(PORT) == OK,"host dedicated ENet socket opens")
		create_game()
		await wait(0.2)
		game.h_accept_job(2)
		game.h_order_set("fx",1)
		game.h_order_set("dolly",1)
		game.h_order_confirm()
		game.local_player().global_position = game.production.HOME_TRUCK + Vector3(-3,0.1,0)
		game.host_load(lift,game.truck)
		game.host_unload(game.film)
		game.host_load(game.film,lift)
		await wait(0.1)
		game.h_depart()
		first_host_position = game.players[1].global_position
		check(game.production.phase == 3,"host is traveling before client starts")
		print("PRODUCTION_LATEJOIN_TRAVEL_READY")
		var elapsed := 0.0
		while not done and elapsed < 50.0:
			await wait(0.1)
			elapsed += 0.1
		check(done,"client completes both joins")
		await wait(0.5)
		print("HOST PRODUCTIONLATEJOIN_FAIL" if failed else "HOST PRODUCTIONLATEJOIN_OK")
		get_tree().quit(1 if failed else 0)
		return
	if not await connect_client():
		check(false,"travel join receives roster")
		get_tree().quit(1)
		return
	await wait(0.6)
	var host_state := await ask()
	check(game.production.phase == 3 and host_state.get("phase") == 3,"client joins during travel")
	compare_state(host_state,"travel join")
	# The original crew is carried along by truck collision during the journey.
	var travel_spawn_ok: bool = game.local_player().global_position.distance_to(game.production.HOME_TRUCK) < 5.0 and game.players[1].global_position.distance_to(host_state.host_position) < 1.0 and game.players[1].global_position.distance_to(game.local_player().global_position) > 3.0
	check(travel_spawn_ok,"travel hello places only joining peer near truck")
	if not travel_spawn_ok:
		print("LATEJOIN_SPAWN_DETAIL client=",game.local_player().global_position," host=",game.players[1].global_position," original_host=",host_state.first_host_position)
	var elapsed := 0.0
	while game.production.phase != 4 and elapsed < 10.0:
		await wait(0.1)
		elapsed += 0.1
	await wait(0.6)
	host_state = await ask()
	check(game.production.phase == 4 and host_state.get("phase") == 4,"travel join arrives with original crew")
	compare_state(host_state,"arrival")
	check(snapshot().yard and snapshot().walls_disabled and host_state.get("yard",false) and host_state.get("walls_disabled",false),"actual yard shutter and disabled warehouse collisions on both peers")
	check(game.local_player().global_position.distance_to(game.SPAWN) < 2.0,"arrival places late crew at filming entrance")
	# Production custody RPCs establish both resources before departure.
	game.h_operate.rpc_id(1,game.film.pid,true)
	game.h_grab.rpc_id(1,game.clapper.pid)
	await wait(0.3)
	host_state = await ask()
	check(host_state.get("film_operator") == Net.my_id() and host_state.get("clapper_holder") == Net.my_id(),"client owns camera operation and held clapper before disconnect")
	await ask("prepare_rejoin")
	var old_id := Net.my_id()
	var old_peer := multiplayer.multiplayer_peer
	old_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.mode = "solo"
	game.queue_free()
	await get_tree().process_frame
	game = null
	lift = null
	check(get_tree().root.get_node_or_null("Game") == null,"old Game is completely freed before reconnect")
	await wait(4.3)
	if not await connect_client():
		check(false,"take rejoin receives fresh roster")
		get_tree().quit(1)
		return
	await wait(1.3)
	host_state = await ask()
	check(game.production.phase == 4 and game.state == game.S.TAKE and host_state.get("state") == game.S.TAKE,"new Game joins in active TAKE")
	compare_state(host_state,"take rejoin")
	check(game.film.tally.visible and game.film.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS and host_state.get("tally",false) and host_state.get("viewport_always",false),"active take tally and film SubViewport UPDATE_ALWAYS on both peers")
	check(snapshot().yard and snapshot().walls_disabled and host_state.get("cleanup_ok",false),"fresh Game restores yard and host cleans previous peer custody")
	check(not game.players.has(old_id) or old_id == Net.my_id(),"old client roster is removed")
	# Allow the entrance's nearby physical props to resolve the new capsule after spawn.
	var take_spawn_ok: bool = game.local_player().global_position.distance_to(game.SPAWN) < 2.0 and game.players[1].global_position.distance_to(host_state.rejoin_host_position) < 0.3
	check(take_spawn_ok,"take hello places only new peer at site entrance")
	if not take_spawn_ok:
		print("LATEJOIN_TAKE_SPAWN_DETAIL client=",game.local_player().global_position," host=",game.players[1].global_position," expected_host=",host_state.rejoin_host_position)
	await ask("done")
	print("CLIENT PRODUCTIONLATEJOIN_FAIL" if failed else "CLIENT PRODUCTIONLATEJOIN_OK")
	get_tree().quit(1 if failed else 0)
