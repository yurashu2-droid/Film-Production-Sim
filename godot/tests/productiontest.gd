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
	check(game.local_player().position.x > 60,"crew arrives in physical office")
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
	flow.wallet = 0
	game.h_accept_job(1)
	game.h_order_set("fx",1)
	check(game.order_cost() == 0,"zero cash cannot buy but free contract remains possible")
	game.h_order_confirm()
	await frames(5)
	check(flow.phase == 2 and flow.wallet == 0,"free loadout never goes negative")
	print("PRODUCTIONTEST_FAIL" if failed else "PRODUCTIONTEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
