extends Node
# 実ENetで途中参加、操作権、採用映像、退出を確認する。
const PORT := 24686
var game: Node
var host := false
var failed := false
var ready_peer := 0
var done := false
var reply: Array = []

func _ready() -> void:
	host = "--monitor-host" in OS.get_cmdline_user_args()
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(2))
	run.call_deferred()

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("MONITOR_NET_CHECK ",label," ","OK" if ok else "FAIL")

@rpc("any_peer","call_remote","reliable")
func ask(action: String, client_ok := true) -> void:
	if not host: return
	var who := multiplayer.get_remote_sender_id()
	match action:
		"near":
			game.production_move.rpc(game.camera_switcher.monitor.global_position+Vector3(2,0,0),0.0,who)
		"far":
			game.production_move.rpc(game.camera_switcher.monitor.global_position+Vector3(20,0,0),0.0,who)
		"snapshot": pass
		"done":
			ready_peer = who
			failed = failed or not client_ok
			done = true
	await wait(0.1)
	respond.rpc_id(who,game.camera_switcher.state())

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
	game.input_locked = true
	if host:
		game.h_accept_job(0)
		game.production.phase = 4
		game._set_state(game.S.PREP)
		game.host_unload(game.camera_switcher.monitor)
		# 依頼を受けると、会社の機材を機材置き場へ戻す予約（次の物理のコマ）が入る。位置を直接書くと、その予約に上書きされる
		game.camera_switcher.monitor.restore([Vector3(8,0.1,8),Quaternion.IDENTITY,true])
		game.camera_switcher.select(game.camera_switcher.cameras[1].pid)
		while not done: await wait(0.05)
		while game.players.has(ready_peer): await wait(0.05)
		check(game.camera_switcher.operator_peer == 0,"disconnect releases control")
	else:
		game.h_hello.rpc_id(1)
		while game.local_player() == null or game.production.phase != 4: await wait(0.05)
		await wait(0.3)
		var switcher: Node = game.camera_switcher
		check(switcher.index() == 1,"late join receives B program")
		await request("near")
		game.h_camera_cut.rpc_id(1,2)
		await request("snapshot")
		check(switcher.index() == 1 and reply[0] == switcher.active_pid,"non-operator cannot switch")
		game.h_monitor_control.rpc_id(1,true)
		await request("snapshot")
		check(switcher.operator_peer == Net.my_id() and reply[1] == Net.my_id(),"operator lease synchronized")
		game.h_camera_cut.rpc_id(1,2)
		await request("snapshot")
		check(switcher.index() == 2 and reply[0] == switcher.active_pid,"C cut synchronized")
		await request("far")
		game.h_camera_cut.rpc_id(1,0)
		await request("snapshot")
		check(switcher.index() == 2 and switcher.operator_peer == 0,"distance releases control and rejects cut")
		await request("near")
		game.h_monitor_control.rpc_id(1,true)
		await request("snapshot")
		ask.rpc_id(1,"done",not failed)
		await wait(0.15)
	print("MONITOR_NET_TEST_FAIL" if failed else "MONITOR_NET_TEST_OK")
	# 通信を先に閉じ、破棄したGameへ遅延パケットが届かないようにする。
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
