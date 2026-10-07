extends SceneTree
var game: Node
var failed := false
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PRODUCTION_CHECK ",label," ","OK" if ok else "FAIL")
	failed = failed or not ok
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(10)
	var flow: Node = game.production
	check(flow != null and flow.phase == 0 and flow.wallet == 600,"office starts with company cash")
	check(game.film.view.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden film viewport sleeps in office")
	check(game.local_player().position.x > 60,"crew arrives in physical office")
	game.local_player().position = Vector3(72,-21,5)
	await frames(3)
	check(game.local_player().position.x > 60 and game.local_player().position.y > -1,"falling from office returns to current company")
	game.set_character_menu(true)
	check(game.hud.root.visible and game.character_open,"office character picker is visible")
	game.set_character_menu(false)
	game.h_accept_job(0)
	check(flow.phase == 1 and game.state == game.S.ORDER,"job opens purchasing")
	game.h_order_set("fx",1)
	game.h_order_set("dolly",1)
	game.h_order_confirm()
	await frames(8)
	check(flow.phase == 2 and flow.wallet == 160 and flow.expenses == 440,"buying charges company once")
	game.h_order_confirm()
	check(flow.wallet == 160,"duplicate confirmation cannot charge again")
	check(game.film.rider_of == game.truck.pid and game.clapper.rider_of == game.truck.pid,"company gear remains attached in packing")
	check(not flow.can_depart(),"departure waits for crew")
	game.local_player().position = flow.HOME_TRUCK + Vector3(-3,0.1,0)
	await frames(3)
	check(flow.can_depart(),"crew plus required gear can depart")
	var lift: Node
	for prop in game.props.values():
		if prop.kind == "lift_cart":
			lift = prop
	check(lift != null and lift.can_board(),"imported lift is a usable rolling deck")
	game.h_grab(lift.pid)
	game.h_load_truck(lift.pid)
	game.host_unload(game.film)
	game.host_load(game.film,lift)
	check(lift.rider_of == game.truck.pid and flow.cargo().has(game.film.pid),"lift and nested camera can be packed")
	game.h_depart()
	check(flow.phase == 3,"departure starts journey")
	await frames(490)
	check(flow.phase == 4 and game.truck.position.distance_to(flow.SITE_TRUCK)<0.1,"journey reaches filming location")
	var landed: Vector3 = game.local_player().global_position
	check(Vector2(landed.x-game.SPAWN.x,landed.z-game.SPAWN.z).length()<0.5 and landed.y>-0.2,"cargo teleport does not launch crew away from arrival")
	var waiting := Node3D.new()
	game.add_child(waiting)
	waiting.global_position = game.SPAWN + Vector3(0.8,0,0)
	game.players[200] = waiting
	var join_point: Vector3 = game._open_join_point(game.SPAWN,100)
	check(join_point.distance_to(waiting.global_position)>=0.8 and join_point.distance_to(landed)>=0.8,"late peer with lower ID gets an unoccupied arrival point")
	game.players.erase(200)
	waiting.queue_free()
	check(game.film.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS,"film viewport resumes at actual location")
	check(game.film.rider_of == lift.pid and lift.rider_of == game.truck.pid and game.film.position.x < 25,"nested cargo arrives attached at location")
	game.local_player().position = lift.position + Vector3(1.5,0,0)
	var low: float = lift.deck_top
	var camera_local: float = game.film.ride_local.origin.y
	game.h_prop_action(lift.pid)
	await frames(190)
	check(lift.deck_top > low + 0.5 and absf(game.film.ride_local.origin.y-camera_local-(lift.deck_top-low))<0.02,"original lift animation moves the mounted camera")
	check(flow.lease_left > 590 and flow.lease_left <= 600,"rental starts on arrival")
	flow.lease_left = 0.01
	await frames(3)
	check(flow.expired and game.state == game.S.RESULT and game.takes.size() == 1,"timeout without footage still permits delivery")
	game.h_retake()
	check(game.state == game.S.RESULT,"expired job cannot start another take")
	game.h_deliver(0)
	check(flow.phase == 5 and flow.last_payment == 150 and flow.wallet == 310,"failed delivery earns small fee without softlock")
	game.h_deliver(0)
	check(flow.wallet == 310,"delivery cannot pay twice")
	game.h_return_office()
	await frames(6)
	check(flow.phase == 0 and game.local_player().position.x > 60,"return to company with earnings")
	check(game.film.view.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden film viewport sleeps again after return")
	var dragon: Node
	var cauldron: Node
	for prop: Node in game.props.values():
		if prop.kind == "dragon_skull": dragon = prop
		if prop.kind == "witch_cauldron": cauldron = prop
	game.local_player().position = dragon.position + Vector3(0,0.1,1)
	await frames(3)
	game.h_grab(dragon.pid)
	dragon.position = game.local_player().position + Vector3(0,1,5)
	var use := InputEventKey.new()
	use.physical_keycode = KEY_F
	use.pressed = true
	game._input(use)
	check(dragon.active and game.local_player().held == dragon.pid,"held dragon jaw uses normal F input")
	game.local_player().position.y = -21
	dragon.position.y = -15
	await frames(4)
	check(game.local_player().position.x > 60 and dragon.position.y > -1 and dragon.active and dragon.holder == 1,"fallen crew returns with held movie prop and jaw state")
	game.h_release()
	check(not game.is_action_prop(cauldron),"single mesh cauldron offers carrying without false open action")
	flow.wallet = 0
	game.h_accept_job(1)
	game.h_order_set("fx",1)
	check(game.order_cost() == 0,"zero cash cannot buy but free contract remains possible")
	game.h_order_confirm()
	await frames(5)
	check(flow.phase == 2 and flow.wallet == 0,"free loadout never goes negative")
	# 実カメラの映り込み・遮蔽と、選んだテイクだけの追加報酬。
	game.host_unload(game.film)
	var camera_state: Array = game.film.get_state()
	camera_state[0] = Vector3(30,0,6)
	camera_state[2] = true
	game.film.restore(camera_state)
	game._aim_camera(Vector3(30,1.2,0),50.0)
	game.local_player().position = Vector3(30,0.1,3)
	await frames(4)
	flow.notes.reset()
	flow.notes.tick(1.0)
	check(flow.notes.crew_seconds > 0.9,"staff in actual film frame is recorded")
	game.local_player().position = Vector3(40,0.1,3)
	await frames(3)
	flow.notes.reset()
	flow.notes.tick(1.0)
	check(flow.notes.crew_seconds == 0.0,"staff outside film frame is not recorded")
	var moon: Node = game.moons[0]
	var moon_state: Array = moon.get_state()
	moon_state[0] = Vector3(30,0,0)
	moon_state[2] = true
	moon.restore(moon_state)
	game._aim_camera(moon.center_global(),50.0)
	await frames(3)
	flow.notes.reset()
	flow.notes.tick(2.1)
	check(flow.notes.moon_seconds >= 2.0,"visible moon time is measured")
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6,10,0.4)
	shape.shape = box
	blocker.add_child(shape)
	game.add_child(blocker)
	blocker.position = Vector3(30,3,3)
	await frames(3)
	flow.notes.reset()
	flow.notes.tick(2.1)
	check(flow.notes.moon_seconds == 0.0,"occluded moon does not count")
	blocker.queue_free()
	var pass_all := [true,true,true]
	check(flow.notes.finish(0,0,pass_all).bonus_ok and not flow.notes.finish(0,1,pass_all).bonus_ok,"warehouse bonus requires first take")
	check(not flow.notes.finish(1,0,[false,true,true]).bonus_ok,"extra condition cannot reward failed main film")
	flow.notes.moon_seconds = 2.1
	var bonus: Dictionary = flow.notes.finish(2,0,pass_all)
	var no_bonus: Dictionary = flow.notes.finish(2,1,[true,true,false])
	game.takes = [{"passed":pass_all,"results":[],"extras":bonus},{"passed":[true,true,false],"results":[],"extras":no_bonus}]
	flow.chosen_job = 2
	game.selected = 0
	flow.settle(1)
	check(flow.last_payment == 650,"payment uses delivered take rather than currently selected bonus take")
	flow.phase = 4
	flow.settle(0)
	check(flow.last_payment == 1350,"complete film plus extra earns 150 coin bonus")
	print("PRODUCTIONTEST_FAIL" if failed else "PRODUCTIONTEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
