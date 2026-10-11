extends Node
const PORT := 24702
var game: Node
var host := false
var failed := false
var done := false
var reply: Array = []
var original: Array = []

func _ready() -> void:
	host = "--cue-host" in OS.get_cmdline_user_args()
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(2))
	run.call_deferred()

func wait(seconds := 0.15) -> void:
	await get_tree().create_timer(seconds).timeout

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("CUE_CARD_NET_CHECK ",label," ","OK" if ok else "FAIL")

@rpc("any_peer","call_remote","reliable")
func ask(action: String, client_ok := true) -> void:
	if not host: return
	var who := multiplayer.get_remote_sender_id()
	if action == "hold":
		game.cue_cards.card.set_holder(who)
		game.host_ev("hold",[who,game.cue_cards.card.pid])
	elif action == "restore":
		game.cue_cards.card.restore(original)
	elif action == "done":
		failed = failed or not client_ok
		done = true
	respond.rpc_id(who,[game.cue_cards.card.ink.get_pixel(512,320),game.cue_cards.card.revision])

@rpc("authority","call_remote","reliable")
func respond(data: Array) -> void:
	reply = data

func request(action: String) -> void:
	reply = []
	ask.rpc_id(1,action)
	while reply.is_empty(): await wait(0.02)

func run() -> void:
	if host: check(Net.host(PORT) == OK,"host socket")
	else:
		check(Net.join("127.0.0.1",PORT) == OK,"client socket")
		await Net.joined_host
	game = load("res://production_game.tscn").instantiate()
	game.name = "Game"
	get_tree().root.add_child(game)
	while not game.startup_complete: await get_tree().process_frame
	var cards: Node = game.cue_cards
	if host:
		game.production.phase = 4
		game._set_state(game.S.PREP)
		game.h_grab(cards.card.pid)
		cards.h_draw(cards.card.pid,PackedVector2Array([Vector2(256,320),Vector2(768,320)]),Color.RED,8)
		original = cards.card.get_state()
		game.h_release()
		print("CUE_CARD_NET_HOST_READY")
		while not done: await wait(0.05)
		await wait(0.3)
	else:
		game.h_hello.rpc_id(1)
		while game.local_player() == null or game.production.phase != 4: await wait(0.05)
		await wait(0.3)
		check(cards.card.ink.get_pixel(512,320).is_equal_approx(Color.RED),"late join receives existing paint")
		var points := PackedVector2Array([Vector2(512,128),Vector2(512,512)])
		cards.h_draw.rpc_id(1,cards.card.pid,points,Color.BLUE,8)
		await request("snapshot")
		check((reply[0] as Color).is_equal_approx(Color.RED),"non-holder cannot repaint another card")
		await request("hold")
		cards.h_draw.rpc_id(1,cards.card.pid,points,Color.BLUE,8)
		await request("snapshot")
		check((reply[0] as Color).is_equal_approx(Color.BLUE) and cards.card.ink.get_pixel(512,320).is_equal_approx(Color.BLUE),"client brush appears on host and client")
		cards.h_clear.rpc_id(1,cards.card.pid)
		await request("snapshot")
		check((reply[0] as Color).is_equal_approx(Color.WHITE) and cards.card.ink.get_pixel(512,320).is_equal_approx(Color.WHITE),"clear synchronizes both cards")
		await request("restore")
		check((reply[0] as Color).is_equal_approx(Color.RED) and cards.card.ink.get_pixel(512,320).is_equal_approx(Color.RED),"restored take also updates every participant")
		ask.rpc_id(1,"done",not failed)
		await wait(0.15)
	print("CUE_CARD_NET_TEST_FAIL" if failed else "CUE_CARD_NET_TEST_OK")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
