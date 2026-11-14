extends Node
const PORT := 24705
var game: Node
var host := false
var failed := false
var done := false
var reply: Dictionary = {}
var original := {}
var boxes: Array = []
func _ready() -> void:
	host = "--adhesive-host" in OS.get_cmdline_user_args()
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(2))
	run.call_deferred()
func wait(seconds := 0.15) -> void:
	await get_tree().create_timer(seconds).timeout
func check(ok: bool,label: String) -> void:
	failed = failed or not ok
	print("ADHESIVE_NET_CHECK ",label," ","OK" if ok else "FAIL")
@rpc("any_peer","call_remote","reliable")
func ask(action: String, ok := true) -> void:
	if not host: return
	var who := multiplayer.get_remote_sender_id()
	if action == "hold":
		game.move_crew(Vector3(2,0.1,4),0,who)
		game.adhesive.tool.set_holder(who)
		game.host_ev("hold",[who,game.adhesive.tool.pid])
	elif action == "restore": game.adhesive.restore(original)
	elif action == "recorded":
		game.adhesive.rx_recorded.rpc({"first":{1:[game.film.pid,Vector3.ZERO]},"pairs":[]})
	elif action == "done":
		failed = failed or not ok
		done = true
	var result: Dictionary = game.adhesive.snapshot()
	result["host_joint_count"] = game.adhesive.joints.size()
	result["host_joint_id"] = game.adhesive.joints[0].get_instance_id() if game.adhesive.joints.has(0) else 0
	result["metrics"] = game.adhesive.bond_metrics()
	respond.rpc_id(who,result)
@rpc("authority","call_remote","reliable")
func respond(data: Dictionary) -> void:
	reply = data
func request(action: String) -> void:
	reply = {}
	ask.rpc_id(1,action)
	while reply.is_empty(): await wait(0.02)
	await wait(0.08)
func run() -> void:
	if host: check(Net.host(PORT)==OK,"host socket")
	else:
		check(Net.join("127.0.0.1",PORT)==OK,"client socket")
		await Net.joined_host
	game = load("res://production_game.tscn").instantiate()
	game.name = "Game"
	get_tree().root.add_child(game)
	while not game.startup_complete: await get_tree().process_frame
	game.production.set_physics_process(false)
	boxes = game.props.values().filter(func(p): return p.kind=="applebox")
	var glue: Node = game.adhesive
	if host:
		game.production.phase = 4
		game._set_state(game.S.PREP)
		for box in boxes: box.set_absent(false)
		for i in 2:
			boxes[i].restore([Vector3(1+i*2,0.1,1),Quaternion.IDENTITY,false])
		glue.pairs = [{"a":game.film.pid,"b":game.truck.pid,"pa":Vector3.ZERO,"pb":game.truck.to_local(game.film.global_position),"joined":true}]
		glue.restore(glue.snapshot())
		original = glue.snapshot()
		print("ADHESIVE_NET_HOST_READY")
		while not done: await wait(0.05)
		await wait(0.3)
	else:
		game.h_hello.rpc_id(1)
		while game.local_player()==null or game.production.phase!=4 or glue.pairs.is_empty(): await wait(0.05)
		await wait(0.3)
		check(glue.connected_to(game.film.pid,game.truck.pid) and glue.joints.is_empty(),"late join receives bonds with host-only physics")
		await request("snapshot")
		var first_joint_id: int = reply.host_joint_id
		check(glue.pairs[0].pa.is_equal_approx(reply.pairs[0].pa) and glue.pairs[0].pb.is_equal_approx(reply.pairs[0].pb),"late join receives the same surface points as the host")
		check(reply.host_joint_count==1 and reply.metrics.size()==1 and reply.metrics[0].gap<0.03,"only the host solves the physical bond and keeps the points together")
		glue.h_mark.rpc_id(1,Vector3(2,1.2,4),(boxes[0].center_global()-Vector3(2,1.2,4)).normalized())
		await request("snapshot")
		check(reply.first.is_empty(),"non-holder cannot apply adhesive")
		await request("hold")
		await wait(0.2)
		var origin := Vector3(2,1.2,4)
		glue.h_mark.rpc_id(1,origin,(boxes[0].center_global()-origin).normalized())
		await request("snapshot")
		check(reply.first.size()==1 and glue.first.size()==1,"client surface dot reaches host and all peers")
		check(reply.host_joint_id==first_joint_id,"client marking preserves the existing host constraint")
		glue.h_mark.rpc_id(1,origin,(boxes[1].center_global()-origin).normalized())
		await request("snapshot")
		check(reply.pairs.size()==2 and glue.pairs.size()==2 and not glue.pairs[1].joined,"two distant surface dots wait for contact")
		await request("restore")
		check(reply.pairs.size()==1 and glue.pairs.size()==1 and glue.first.is_empty(),"restored bond snapshot synchronizes peers")
		check(glue.pairs[0].joined and glue.pairs[0].pa.is_equal_approx(reply.pairs[0].pa) and glue.pairs[0].pb.is_equal_approx(reply.pairs[0].pb),"restored bond points agree on host and participant")
		glue.h_assisted_mark.rpc_id(1,origin,(boxes[0].center_global()-origin).normalized(),boxes[0].pid,boxes[1].pid)
		await request("snapshot")
		check(reply.pairs.size()==1 and glue.pairs.size()==1,"distant or stale assisted click cannot create an unintended bond")
		await request("recorded")
		check(glue.markers.size()==1 and glue.pairs.size()==1,"recorded dots synchronize without overwriting live bonds")
		await request("restore")
		check(glue.markers.size()==2,"ending replay restores live bond visuals")
		ask.rpc_id(1,"done",not failed)
		await wait(0.15)
	print("ADHESIVE_NET_TEST_FAIL" if failed else "ADHESIVE_NET_TEST_OK")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
