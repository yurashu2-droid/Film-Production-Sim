extends Node
## Dedicated real ENet regression. Fixtures are host-only; clients invoke game RPCs.
const PORT := 24817
var game: Node
var net: Node
var host := false
var failed := false
var done := false
var checks := 0
var serial := 0
var replies := {}
var queue: Array = []
var busy := false
var body: Node
var boxes: Array = []
var watching := false
var watch_transform := Transform3D.IDENTITY
var watch_gap := 0.0
var watch_angle := 0.0
var watch_samples := 0
var monitor_watch: Node
var monitor_start := Vector3.ZERO
var monitor_distance := 0.0
var monitor_speed := 0.0
var monitor_platform := 0.0
var settling_frames := 0
var picked_local := Vector3.ZERO

func on_monitor(player: Node, monitor: Node) -> bool:
	if not player.is_on_floor(): return false
	for i in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_collider()==monitor: return true
	return false

func _ready() -> void:
	net = get_tree().root.get_node("Net")
	host = "--handling-host" in OS.get_cmdline_user_args()
	get_tree().create_timer(70.0).timeout.connect(func():
		print("HANDLING_NET_TEST_TIMEOUT ","HOST" if host else "CLIENT")
		get_tree().quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	failed = failed or not ok
	print("HANDLING_NET_CHECK ","HOST " if host else "CLIENT ",label," ","OK" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func wait(seconds := 0.05) -> void:
	await get_tree().create_timer(seconds).timeout

func rotation_of(prop: Node3D) -> Quaternion:
	return prop.global_basis.orthonormalized().get_rotation_quaternion()

func goal(who: int) -> Transform3D:
	var target: Array = game.hold_target(who,body)
	var basis: Basis = target[4] if target.size()>4 else Basis.from_euler(Vector3(target[3],target[1],0))
	return Transform3D(basis,target[0]-basis*body.center)

func pick_corner(player: Node) -> void:
	var aimed: Vector3 = body.to_global(body.center+Vector3(body.half.x*0.8,body.half.y*0.6,body.half.z))
	# Aim the real third-person camera without writing its target/holder fields.
	for i in 18:
		var direction: Vector3 = (aimed-player.cam.global_position).normalized()
		player.aim_yaw = atan2(-direction.x,-direction.z)
		player.aim_pitch = asin(clampf(direction.y,-1.0,1.0))
		await frames(1)
	await wait(0.15) # Let the same view state reach the authoritative peer.
	player._find_target()
	var ray := PhysicsRayQueryParameters3D.create(player.cam.global_position,player.cam.global_position-player.cam.global_basis.z*9.0,1|2|4|16)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider==body and player.target==body,"participant's real ray reaches a corner surface")
	if hit.is_empty() or hit.collider!=body: return
	picked_local = body.to_local(hit.position)
	print("HANDLING_NET_MEASURE clicked_local ",JSON.stringify({"x":picked_local.x,"y":picked_local.y,"z":picked_local.z,"center_distance_m":picked_local.distance_to(body.center)}))
	check(picked_local.distance_to(body.center)>0.10,"network grip uses a surface point rather than the body center")
	# Headless peers have no native mouse capture; the render test covers viewport
	# dispatch. Here call the public game API with the independently raycast point.
	game.act_grab(body.pid,picked_local)

@rpc("any_peer","call_remote","reliable")
func ask(sequence: int, action: String, client_ok := true) -> void:
	if host: queue.append([multiplayer.get_remote_sender_id(),sequence,action,client_ok])

@rpc("authority","call_remote","reliable")
func answer(sequence: int, data: Dictionary) -> void:
	replies[sequence] = data

func request(action: String) -> Dictionary:
	serial += 1
	var sequence := serial
	ask.rpc_id(1,sequence,action)
	var elapsed := 0.0
	while not replies.has(sequence) and elapsed<6.0:
		await wait(0.02)
		elapsed += 0.02
	if not replies.has(sequence):
		check(false,"host reply timeout: "+action)
		return {}
	var data: Dictionary = replies[sequence]
	replies.erase(sequence)
	return data

func _physics_process(_delta: float) -> void:
	if not host or game==null: return
	if watching and body!=null:
		watch_samples += 1
		watch_gap = maxf(watch_gap,body.global_position.distance_to(watch_transform.origin))
		watch_angle = maxf(watch_angle,rotation_of(body).angle_to(watch_transform.basis.get_rotation_quaternion()))
	if monitor_watch!=null:
		monitor_distance = maxf(monitor_distance,monitor_watch.global_position.distance_to(monitor_start))
		monitor_speed = maxf(monitor_speed,monitor_watch.velocity.length())
		monitor_platform = maxf(monitor_platform,monitor_watch.get_platform_velocity().length())

func _process(_delta: float) -> void:
	if not host or busy or queue.is_empty(): return
	busy = true
	var action: Array = queue.pop_front()
	var who: int = action[0]
	match action[2]:
		"prepare":
			if body.holder!=0: game.host_release(body)
			game.move_crew(Vector3(0,0.1,4),0.0,who)
			body.restore([Vector3(0.65,1.05,2.2),Quaternion.from_euler(Vector3(0.32,0.67,-0.24)),false])
			body.gravity_scale = 0.0
			await frames(4)
			watch_transform = body.global_transform
			watch_gap = 0.0
			watch_angle = 0.0
			watch_samples = 0
			watching = true
		"observe": await frames(12)
		"settle":
			watching = false
			# Acceleration-limited motion has variable duration. Retain tight spatial
			# tolerances and wait for measured convergence, bounded to four seconds.
			settling_frames = 0
			for i in 240:
				await frames(1)
				settling_frames += 1
				var wanted := goal(body.holder)
				if i>15 and body.global_position.distance_to(wanted.origin)<0.025 and rotation_of(body).angle_to(wanted.basis.get_rotation_quaternion())<0.03: break
			check(settling_frames<240,"held body converges before the four second deadline")
		"self_monitor","other_monitor":
			watching = false
			game.adhesive.clear()
			if body.holder!=0: game.host_release(body)
			var monitor: Node = game.camera_switcher.monitor
			if monitor.holder!=0: game.host_release(monitor)
			monitor.set_absent(false)
			monitor.restore([Vector3(5,0.02,5),Quaternion.IDENTITY,false])
			await frames(60)
			# モニターの当たり判定は見た目どおりになり、支柱の間（画面の下）に乗れる台は無くなった。上のひさしに立たせる
			var point: Vector3 = monitor.to_global(Vector3(0,2.72,0.10))
			if action[2]=="self_monitor":
				game.move_crew(point,0.0,who)
				monitor_watch = null # local-client samples are authoritative for its body.
			else:
				game.move_crew(Vector3(7,0.1,5),0.0,who)
				# 参加者の体が、ひさしの上から離れるのを待つ（同じ所に2人を重ねると押し合って、モニターごと吹き飛ぶ）
				await frames(30)
				monitor.restore([Vector3(5,0.02,5),Quaternion.IDENTITY,false])
				await frames(30)
				point = monitor.to_global(Vector3(0,2.72,0.10))
				var me: Node = game.local_player()
				me.global_position = point
				me.velocity = Vector3.ZERO
				me.set_physics_process(true)
				# Establish the fixture BEFORE pickup; never correct crew during samples.
				for i in 90:
					await frames(1)
					if on_monitor(me,monitor): break
				check(on_monitor(me,monitor),"host fixture stands on monitor before participant pickup")
				monitor_watch = me
				monitor_start = me.global_position
				monitor_distance = 0.0
				monitor_speed = 0.0
				monitor_platform = 0.0
		"observe_monitor": await frames(120)
		"late_prepare":
			monitor_watch = null
			game.local_player().set_physics_process(false)
			game.local_player().global_position = Vector3(0,0.1,4)
			var monitor: Node = game.camera_switcher.monitor
			if monitor.holder!=0: game.host_release(monitor)
			monitor.set_absent(true)
			if body.holder!=0: game.host_release(body)
			body.restore([Vector3(0.65,1.05,2.2),Quaternion.from_euler(Vector3(0.32,0.67,-0.24)),false])
			body.gravity_scale = 0.0
			await frames(4)
			# These calls occur outside ask's RPC context: the actor is the host.
			game.h_grab(body.pid)
			game.h_hold_command("lift",0.2)
			var second: Node = boxes[1]
			second.set_absent(false)
			second.restore([body.global_position+Vector3(body.half.x+second.half.x+0.002,0,0),Quaternion.IDENTITY,false])
			second.gravity_scale = 0.0
			await frames(4)
			var contact: Vector3 = (body.center_global()+second.center_global())*0.5
			game.adhesive.restore({"first":{},"pairs":[{"a":body.pid,"b":second.pid,"pa":body.to_local(contact),"pb":second.to_local(contact),"joined":true}]})
			await frames(120)
		"done":
			failed = failed or not action[3]
			done = true
	await frames(2)
	var me: Node = game.players.get(who)
	var data := {"body":body.global_transform,"holder":body.holder,"host_held":game.players[1].held,"client_held":me.held if me!=null else 0,
		"watch_gap_m":watch_gap,"watch_angle_rad":watch_angle,"watch_samples":watch_samples,
		"glue":game.adhesive.snapshot(),"host_joints":game.adhesive.joints.size(),
		"monitor_distance_m":monitor_distance,"monitor_speed_mps":monitor_speed,"monitor_platform_mps":monitor_platform}
	data["settling_frames"] = settling_frames
	if body.holder!=0:
		data["goal"] = goal(body.holder)
		data["revision"] = game.players[body.holder].hold_revision
	answer.rpc_id(who,action[1],data)
	busy = false

func create_game() -> void:
	game = load("res://production_game.tscn").instantiate()
	game.name = "Game"
	get_tree().root.add_child(game)
	while not game.startup_complete: await get_tree().process_frame
	game.production.set_physics_process(false)
	game.camera_switcher.set_process(false)
	game.input_locked = false
	boxes = game.props.values().filter(func(p): return p.kind=="applebox")
	boxes.sort_custom(func(a,b): return a.pid<b.pid)
	body = boxes[0]

func run() -> void:
	check((net.host(PORT) if host else net.join("127.0.0.1",PORT))==OK,"dedicated socket opens")
	if failed:
		get_tree().quit(1)
		return
	# Register /root/Game before the connection can deliver world packets. ENet is
	# already in client mode, so body freezing and hello still use the real path.
	await create_game()
	if not host:
		var connection_time := 0.0
		while multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and connection_time<10.0:
			await wait(0.05)
			connection_time += 0.05
		check(multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"client handshake completes on port 24817")
		if failed:
			print("CLIENT HANDLING_NET_TEST_FAIL connection_status=",multiplayer.multiplayer_peer.get_connection_status())
			get_tree().quit(1)
			return
	if host:
		game.production.phase = 4
		game._set_state(game.S.PREP)
		for prop: Node in game.props.values(): prop.set_absent(true)
		# Presence is synchronized by kind at hello. Keep every applebox present,
		# otherwise a hidden sibling would mark the tested box absent on the client.
		for i in boxes.size():
			boxes[i].set_absent(false)
			boxes[i].restore([Vector3(20+i*2,3,20),Quaternion.IDENTITY,true])
		var monitor: Node = game.camera_switcher.monitor
		monitor.set_absent(false)
		monitor.restore([Vector3(5,0.02,5),Quaternion.IDENTITY,false])
		game.local_player().set_physics_process(false)
		game.local_player().global_position = Vector3(0,0.1,4)
		print("HANDLING_NET_HOST_READY")
		while not done: await wait()
		await wait(0.3)
	else:
		await client_cases()
	print("HOST " if host else "CLIENT ","HANDLING_NET_TEST_FAIL" if failed else "HANDLING_NET_TEST_OK"," checks=",checks)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game.queue_free()
	game = null
	get_tree().root.get_node("Sfx").silence_all()
	await frames(8)
	get_tree().quit(1 if failed else 0)

func client_cases() -> void:
	while game.local_player()==null or game.production.phase!=4: await wait()
	var me: Node = game.local_player()
	me.set_physics_process(false)
	var data := await request("prepare")
	# Keep the actual controller running, including carry poses and position packets.
	# Freezing it for the entire test makes G use an idle character's lowered hands.
	me.set_physics_process(true)
	game.input_locked = true
	await frames(30)
	await wait(1.3) # Includes one full-world resend; body packets are interpolated.
	var before: Transform3D = data.body
	await pick_corner(me)
	data = await request("observe")
	check(data.get("holder",0)==net.my_id() and data.get("client_held",0)==body.pid and me.held==body.pid,"client acquisition agrees with authoritative ownership")
	var wanted: Transform3D = data.get("goal",Transform3D.IDENTITY)
	print("HANDLING_NET_MEASURE client_pickup ",JSON.stringify({"goal_gap_m":wanted.origin.distance_to(before.origin),"goal_angle_rad":wanted.basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion()),"max_gap_m":data.watch_gap_m,"max_angle_rad":data.watch_angle_rad,"samples":data.watch_samples}))
	check(wanted.origin.distance_to(before.origin)<0.002 and wanted.basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion())<0.002,"client pickup preserves the host target pose")
	check(data.watch_gap_m<0.02 and data.watch_angle_rad<0.03,"client pickup does not cause a physical snap on the host")
	await wait(0.3)
	check(body.global_position.distance_to(before.origin)<0.05 and rotation_of(body).angle_to(before.basis.get_rotation_quaternion())<0.03,"client displayed pose preserves the picked pose")
	check(body.hold_grip_local.distance_to(picked_local)<0.0001,"participant receives the selected local grip point")
	var initial_point: Vector3 = wanted*picked_local
	me.hold_yaw = 0.25
	me.hold_pitch = 0.15
	game.send_hold_controls(me.hold_dist,me.hold_yaw,me.hold_pitch,me.hold_offset,me.hold_roll,me.hold_revision)
	await wait(0.15)
	data = await request("settle")
	var server_point: Vector3 = (data.goal as Transform3D)*picked_local
	var client_point: Vector3 = goal(me.peer_id)*picked_local
	print("HANDLING_NET_MEASURE picked_pivot ",JSON.stringify({"server_pivot_error_m":server_point.distance_to(initial_point),"peer_target_error_m":server_point.distance_to(client_point),"physical_point_error_m":((data.body as Transform3D)*picked_local).distance_to(server_point)}))
	check(server_point.distance_to(initial_point)<0.002,"network rotation keeps the clicked surface pivot")
	check(server_point.distance_to(client_point)<0.002,"host and participant agree on the picked point target")
	check(((data.body as Transform3D)*picked_local).distance_to(server_point)<0.04,"authoritative physical picked point reaches its target")
	me.hold_yaw = 0.0
	me.hold_pitch = 0.0
	game.send_hold_controls(me.hold_dist,me.hold_yaw,me.hold_pitch,me.hold_offset,me.hold_roll,me.hold_revision)
	await wait(0.15)
	data = await request("settle")
	var previous_goal: Transform3D = data.goal
	var old_revision: int = data.get("revision",0)
	game.h_hold_command.rpc_id(1,"lift",0.2)
	data = await request("settle")
	wanted = data.goal
	check(absf(wanted.origin.y-previous_goal.origin.y-0.2)<0.002,"client lift requests the specified vertical increment")
	check(me.hold_revision==data.revision and body.hold_lifted,"reliable hold adjustment reaches the participant")
	# A delayed pre-command control packet and the legacy motion fields must not
	# undo a reliable adjustment. Send actual packets; do not copy server state.
	game.rx_hold_controls.rpc_id(1,4.8,1.7,-1.2,Vector3(1,1,1),0.8,old_revision)
	game.rx_production_player.rpc_id(1,me.global_position,me.vis.rotation.y,me.aim_yaw,me.aim_pitch,4.8,1.7,-1.2,me.vis.current+"|neutral",game._crew_epoch)
	await wait(0.2)
	data = await request("snapshot")
	check((data.goal as Transform3D).is_equal_approx(wanted),"old controls and movement packet fields cannot undo lift")
	game.h_hold_command.rpc_id(1,"pull")
	data = await request("settle")
	check((data.goal as Transform3D).origin.distance_to(wanted.origin)>0.1,"explicit pull changes the target only when requested")
	check((data.goal as Transform3D).basis.y.dot(Vector3.UP)>0.999,"network G requests upright once while pulling")
	me.hold_roll = 0.18
	game.send_hold_controls(me.hold_dist,me.hold_yaw,me.hold_pitch,me.hold_offset,me.hold_roll,me.hold_revision)
	await wait(0.15)
	data = await request("settle")
	check((data.body as Transform3D).basis.get_rotation_quaternion().angle_to((data.goal as Transform3D).basis.get_rotation_quaternion())<0.03,"network G does not erase later roll adjustments")
	await wait(0.3)
	check(body.global_position.distance_to((data.body as Transform3D).origin)<0.08,"participant converges to the host's physical carried position")
	game.h_hold_command.rpc_id(1,"upright")
	data = await request("settle")
	print("HANDLING_NET_MEASURE upright ",JSON.stringify({"target_up":(data.goal as Transform3D).basis.y.dot(Vector3.UP),"body_up":(data.body as Transform3D).basis.y.dot(Vector3.UP),"angle_error_rad":(data.goal as Transform3D).basis.get_rotation_quaternion().angle_to((data.body as Transform3D).basis.get_rotation_quaternion()),"frames":data.settling_frames}))
	check((data.body as Transform3D).basis.y.dot(Vector3.UP)>0.995,"upright is an explicit separately synchronized command")
	game.h_release.rpc_id(1)
	data = await request("snapshot")
	check(data.holder==0 and me.held==0,"release reaches both peers")
	await request("self_monitor")
	me.set_physics_process(true)
	game.input_locked = true
	await frames(30)
	var on_monitor := false
	for i in me.get_slide_collision_count():
		on_monitor = on_monitor or me.get_slide_collision(i).get_collider()==game.camera_switcher.monitor
	check(me.is_on_floor() and on_monitor,"client is grounded on its actual monitor collider before pickup")
	var start: Vector3 = me.global_position
	game.h_grab.rpc_id(1,game.camera_switcher.monitor.pid)
	var max_distance := 0.0
	var max_speed := 0.0
	var max_platform := 0.0
	for i in 120:
		await frames(1)
		max_distance = maxf(max_distance,me.global_position.distance_to(start))
		max_speed = maxf(max_speed,me.velocity.length())
		max_platform = maxf(max_platform,me.get_platform_velocity().length())
	print("HANDLING_NET_MEASURE client_self_support ",JSON.stringify({"max_distance_m":max_distance,"max_speed_mps":max_speed,"max_platform_mps":max_platform}))
	check(max_distance<0.20 and max_speed<1.0 and max_platform<1.0,"participant pickup preserves its own support without launch")
	game.h_release.rpc_id(1)
	await request("other_monitor")
	await frames(30)
	game.h_grab.rpc_id(1,game.camera_switcher.monitor.pid)
	data = await request("observe_monitor")
	print("HANDLING_NET_MEASURE host_other_support ",JSON.stringify({"max_distance_m":data.monitor_distance_m,"max_speed_mps":data.monitor_speed_mps,"max_platform_mps":data.monitor_platform_mps}))
	check(data.monitor_distance_m<0.20 and data.monitor_speed_mps<1.0 and data.monitor_platform_mps<1.0,"participant pickup preserves another crew's support on the host")
	game.h_release.rpc_id(1)
	await request("late_prepare")
	# Reconnect the same worker using a new Game; exercise the actual hello snapshot.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game.queue_free()
	game = null
	await frames(4)
	check(net.join("127.0.0.1",PORT)==OK,"reconnect socket opens")
	await create_game()
	while game.local_player()==null or game.production.phase!=4: await wait()
	game.local_player().set_physics_process(false)
	data = await request("snapshot")
	await wait(1.3)
	check(data.host_held==body.pid and game.players[1].held==body.pid,"late join receives the current host grip")
	check(game.players[1].hold_revision==data.revision and body.hold_reference_valid,"late join receives adjusted grip revision and reference")
	check(body.global_position.distance_to((data.body as Transform3D).origin)<0.08,"late join receives the current physical pose")
	check(data.host_joints==1 and game.adhesive.joints.is_empty() and game.adhesive.pairs==data.glue.pairs,"late join receives bonds with host-only solving")
	serial += 1
	ask.rpc_id(1,serial,"done",not failed)
	await wait(0.15)
