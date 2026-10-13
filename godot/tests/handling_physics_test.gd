extends SceneTree
## Independent regressions. Fixtures prepare real props; samples never reposition them.
## Run directly, without a listening multiplayer socket. Aggregate runner preserves logs.
var game: Node
var failed := false
var pending := false
var checks := 0
var metrics: Dictionary = {}

func _initialize() -> void:
	create_timer(110.0).timeout.connect(func():
		print("HANDLING_PHYSICS_TEST_TIMEOUT")
		quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	failed = failed or not ok
	print("HANDLING_PHYSICS_CHECK ",label," ","OK" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count: await physics_frame

func measured(label: String, values: Dictionary) -> void:
	metrics[label] = values
	print("HANDLING_PHYSICS_MEASURE ",label," ",JSON.stringify(values))

func rotation_of(body: Node3D) -> Quaternion:
	return body.global_basis.orthonormalized().get_rotation_quaternion()

func hold_goal(body: Node) -> Transform3D:
	var target: Variant = game.hold_target(body.holder,body)
	if target is Transform3D: return target
	# The original API exposes center/yaw/ground/pitch. This adapter is diagnostic;
	# preservation assertions compare the actual body against its pre-grab transform.
	var basis: Basis = target[4] if target.size()>4 else Basis.from_euler(Vector3(float(target[3]),float(target[1]),0))
	var position: Vector3 = target[0] - basis*body.center
	if target.size()==4: position.y = maxf(position.y,float(target[2])+0.03)
	return Transform3D(basis,position)

func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if not "startup_complete" in game:
		check(false,"production scene script loads")
		print("HANDLING_PHYSICS_TEST_FAIL")
		quit(1)
		return
	while not game.startup_complete: await process_frame
	game.production.set_physics_process(false)
	game.camera_switcher.set_process(false)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	game.input_locked = false
	game.adhesive.clear()
	for body: Node in game.props.values(): body.set_absent(true)
	for actor: Node3D in game.actors:
		actor.set_physics_process(false)
		actor.global_position = Vector3(25,0,25)
	var player: Node = game.local_player()
	player.set_physics_process(false)
	player.global_position = Vector3(0,0.1,4)
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0
	player.vis.anim.active = false
	await test_grab_preserves_transform(player)
	await test_cue_card(player)
	await test_glue_flex_and_multiple()
	await test_glue_carry(player)
	await test_monitor_weight_and_support(player)
	await test_operation_response(player)
	print("HANDLING_PHYSICS_TEST_FAIL" if failed else ("HANDLING_PHYSICS_TEST_PENDING" if pending else "HANDLING_PHYSICS_TEST_OK")," checks=",checks)
	current_scene = null
	game.queue_free()
	game = null
	root.get_node("Sfx").silence_all()
	await frames(8)
	quit(1 if failed else (3 if pending else 0))

func test_grab_preserves_transform(player: Node) -> void:
	var body: Node = game.stage.spawn("applebox",Vector3(0.65,1.05,2.2))
	body.restore([body.global_position,Quaternion.from_euler(Vector3(0.32,0.67,-0.24)),false])
	body.gravity_scale = 0.0
	await frames(4)
	var before: Transform3D = body.global_transform
	game.h_grab(body.pid)
	check(body.holder==player.peer_id and player.held==body.pid,"real grab acquires the prop")
	if body.holder==0:
		body.set_absent(true)
		return
	var goal: Transform3D = hold_goal(body)
	var goal_gap := goal.origin.distance_to(before.origin)
	var goal_angle := goal.basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion())
	var max_gap := 0.0
	var max_angle := 0.0
	for i in 12:
		await frames(1)
		max_gap = maxf(max_gap,body.global_position.distance_to(before.origin))
		max_angle = maxf(max_angle,rotation_of(body).angle_to(before.basis.get_rotation_quaternion()))
	measured("pickup",{"goal_gap_m":goal_gap,"goal_angle_rad":goal_angle,"first_12_max_gap_m":max_gap,"first_12_max_angle_rad":max_angle})
	check(goal_gap<0.002,"pickup target preserves the initial position")
	check(goal_angle<0.002,"pickup target preserves pitch yaw and roll")
	check(max_gap<0.02,"stationary pickup does not pull the object to the hands")
	check(max_angle<0.03,"stationary pickup does not upright the object")
	var offset: Vector3 = body.global_position-player.global_position
	player.global_position += Vector3(0.6,0,0)
	await frames(90)
	var follow_gap: float = (body.global_position-player.global_position).distance_to(offset)
	measured("move_without_recenter",{"offset_error_m":follow_gap})
	check(follow_gap<0.05,"walking preserves the acquired spatial offset")
	# Explicit pull API is supplied by the holding owner. Missing API is reported as
	# pending, not silently counted as a passing recenter regression.
	if game.has_method("h_hold_command"):
		var pull_start: Vector3 = body.global_position
		game.call("h_hold_command","pull")
		await frames(90)
		measured("explicit_pull",{"distance_m":body.global_position.distance_to(pull_start),"goal_error_m":body.global_position.distance_to(hold_goal(body).origin)})
		check(body.global_position.distance_to(pull_start)>0.10,"explicit pull moves a deliberately offset prop")
		check(body.global_position.distance_to(hold_goal(body).origin)<0.12,"explicit pull reaches the requested target")
		# User revision: G performs the former upright-and-pull once.
		check(hold_goal(body).basis.y.dot(Vector3.UP)>0.999,"G requests upright once while pulling")
		player.hold_roll = 0.2
		var adjusted := hold_goal(body)
		await frames(90)
		check(rotation_of(body).angle_to(adjusted.basis.get_rotation_quaternion())<0.03,"G does not keep erasing later roll adjustments")
	else:
		pending = true
		print("HANDLING_PHYSICS_PENDING explicit pull API not finalized")
	var release_transform: Transform3D = body.global_transform
	game.h_release()
	check(body.global_transform.is_equal_approx(release_transform),"release preserves the arranged transform immediately")
	check(body.holder==0 and player.held==0,"release clears ownership")
	body.set_absent(true)
	player.global_position = Vector3(0,0.1,4)
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0
	player.head.rotation = Vector3.ZERO

func test_cue_card(player: Node) -> void:
	var card: Node = game.cue_cards.card
	card.set_absent(false)
	card.restore([Vector3(0.6,1.1,2.4),Quaternion.from_euler(Vector3(0.3,0.4,-0.2)),false])
	card.gravity_scale = 0.0
	await frames(4)
	var before: Transform3D = card.global_transform
	game.h_grab(card.pid)
	check(hold_goal(card).is_equal_approx(before),"cue card's special carry target does not override passive pickup")
	game.h_hold_command("pull")
	var target := hold_goal(card)
	var front: Vector3 = target.basis*Vector3.BACK
	check(front.dot(player.flat_forward())>0.99 and target.basis.y.dot(Vector3.UP)>0.999,"explicit G uses the cue card's readable upright facing")
	check((target*card.center).y>player.vis.grip_pos(false).y+0.20,"explicit G supports the card above the hands")
	await frames(120)
	check(card.global_position.distance_to(target.origin)<0.04,"cue card physically reaches explicit carrying position")
	game.h_release()
	card.set_absent(true)

func point_error(glue: Node) -> float:
	var worst := 0.0
	for pair: Dictionary in glue.pairs:
		if not pair.joined: continue
		var a: Node3D = game.props[pair.a]
		var b: Node3D = game.props[pair.b]
		worst = maxf(worst,a.to_global(pair.pa).distance_to(b.to_global(pair.pb)))
	return worst

func bond(glue: Node, a: Node3D, b: Node3D, world_point: Vector3) -> void:
	var data: Dictionary = glue.snapshot()
	data.pairs.append({"a":a.pid,"b":b.pid,"pa":a.to_local(world_point),"pb":b.to_local(world_point),"joined":true})
	glue.restore(data)

func test_glue_flex_and_multiple() -> void:
	var glue: Node = game.adhesive
	var a: Node = game.stage.spawn("applebox",Vector3(-5,3,0))
	var b: Node = game.stage.spawn("applebox",Vector3(-5,3,0))
	# Real meshes/colliders remain active; boxes touch at their measured side faces.
	b.global_position.x += a.half.x+b.half.x+0.002
	a.gravity_scale = 0.0
	b.gravity_scale = 0.0
	a.set_fixed(true)
	await frames(4)
	var contact := Vector3((a.center_global().x+b.center_global().x)*0.5,a.center_global().y,a.center_global().z)
	bond(glue,a,b,contact)
	await frames(15)
	var rest: Quaternion = rotation_of(b)
	b.apply_torque_impulse(Vector3(0,0,0.45))
	var peak := 0.0
	var late := 0.0
	var worst_point := 0.0
	var finite := true
	for i in 240:
		await frames(1)
		var angle := rotation_of(b).angle_to(rest)
		peak = maxf(peak,angle)
		if i>=180: late = maxf(late,angle)
		worst_point = maxf(worst_point,point_error(glue))
		finite = finite and b.global_position.is_finite() and b.linear_velocity.is_finite() and b.angular_velocity.is_finite()
	measured("glue_flex",{"peak_angle_rad":peak,"last_60_max_angle_rad":late,"max_point_error_m":worst_point,"finite":finite})
	# 接着した点は支点。回す力をかけると、以前の上限（5度）を越えて回れる。回る勢いは、やがて収まる。
	check(peak>deg_to_rad(5.0),"one glued point pivots past the old five-degree stop")
	check(b.angular_velocity.length()<0.2,"swing around the glued point calms down")
	check(worst_point<0.04 and finite,"adhesive surface points remain close and finite")
	var c: Node = game.stage.spawn("applebox",b.global_position+Vector3(b.half.x*2+0.002,0,0))
	c.gravity_scale = 0.0
	await frames(4)
	var before: Transform3D = b.global_transform
	bond(glue,b,c,(b.center_global()+c.center_global())*0.5)
	check(b.global_transform.is_equal_approx(before),"adding a second bond does not teleport an existing member")
	check(glue.joints.size()==2 and glue.connected_to(a.pid,c.pid),"multiple bonds preserve transitive connectivity")
	# Two separated anchors on the same pair catch conflicting/rebuilt constraints.
	bond(glue,a,b,contact+Vector3(0,0.10,0))
	c.apply_central_impulse(Vector3(0,0,0.5))
	var max_speed := 0.0
	worst_point = 0.0
	for i in 600:
		await frames(1)
		worst_point = maxf(worst_point,point_error(glue))
		for body: Node in [b,c]:
			max_speed = maxf(max_speed,body.linear_velocity.length())
			finite = finite and body.global_position.is_finite() and body.linear_velocity.is_finite() and body.angular_velocity.is_finite()
	measured("multiple_bonds",{"samples":600,"max_point_error_m":worst_point,"max_speed_mps":max_speed,"finite":finite,"joints":glue.joints.size()})
	check(glue.joints.size()==3 and finite and worst_point<0.06 and max_speed<4.0,"three bonds remain bounded for ten seconds")
	var state: Dictionary = glue.snapshot()
	glue.clear()
	check(glue.joints.is_empty(),"clearing removes all constraints")
	glue.restore(state)
	check(glue.joints.size()==3 and glue.connected_to(a.pid,c.pid),"snapshot restores every bond")
	glue.clear()
	for body: Node in [a,b,c]: body.set_absent(true)

# 持った物（body）と、それに接着した相手（partner）を count コマ見守る。
# 終わりの60コマでの body の目標からのずれ・速さと、相手が body に対して回った角度、留めた点のずれを返す
func watch_carry(body: Node, partner: Node, rest: Quaternion, count: int) -> Dictionary:
	var out := {"offset":0.0,"tilt":0.0,"speed":0.0,"spin":0.0,"point":0.0,"finite":true,"swing":0.0}
	for i in count:
		await frames(1)
		out.point = maxf(out.point,point_error(game.adhesive))
		out.finite = out.finite and body.global_position.is_finite() and partner.global_position.is_finite()
		if i>=count-60:
			var goal := hold_goal(body)
			out.offset = maxf(out.offset,body.global_position.distance_to(goal.origin))
			out.tilt = maxf(out.tilt,rotation_of(body).angle_to(goal.basis.get_rotation_quaternion()))
			out.speed = maxf(out.speed,body.linear_velocity.length())
			out.spin = maxf(out.spin,body.angular_velocity.length())
	out.swing = (rotation_of(body).inverse()*rotation_of(partner)).angle_to(rest)
	return out

# 接着した物を持って運ぶ。点で留めた相手は、留めた点からぶら下がる。離れた3点で固く留めた相手は、いっしょに動く。
# どちらでも、持った物そのものは目標の位置と向きに付いてくる（ぶら下がった相手に振り回されない）
func test_glue_carry(player: Node) -> void:
	var glue: Node = game.adhesive
	glue.clear()
	player.global_position = Vector3(-14,0.1,7)
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0
	# 木箱（足場）の手前の面に、板（カンペ）を当てて留める。床に置いてある間は、板は床に支えられて回れない
	var card: Node = game.cue_cards.card
	for count: int in [1,3]:
		var crate: Node = game.stage.spawn_riser(Vector3(-14,0.02,4),0.0)
		card.set_absent(false)
		card.restore([Vector3(-14,0.03,4+crate.half.z+card.half.z+0.003),Quaternion.IDENTITY,false])
		await frames(40)
		var spots := [Vector2(-1,1),Vector2(1,1),Vector2(0,-1)]
		for i in count:
			bond(glue,card,crate,card.to_global(card.center+Vector3(spots[i].x*(card.half.x-0.06),spots[i].y*(card.half.y-0.06),-card.half.z)))
		await frames(10)
		var flat: Quaternion = rotation_of(crate).inverse()*rotation_of(card)
		game.h_grab(crate.pid,crate.center)
		for i in 6: game.h_hold_command("lift",0.25)
		var lifted: Dictionary = await watch_carry(crate,card,flat,180)
		measured("glue_carry_board_%d" % count,lifted)
		if count==1:
			check(lifted.swing>deg_to_rad(30.0),"lifting a crate lets a board glued at one point swing down from that point")
		else:
			check(lifted.swing<deg_to_rad(3.0),"a board glued at three spread points moves with the held crate")
		check(lifted.offset<0.08 and lifted.tilt<deg_to_rad(15.0) and lifted.speed<0.3 and lifted.spin<0.3,"the held crate reaches its target and rests with the glued board attached")
		check(lifted.point<0.03 and lifted.finite,"carried bond points stay together")
		game.h_release()
		glue.clear()
		crate.set_absent(true)
		card.set_absent(true)
	# 箱馬の横の面の下の縁に、12kg の重りを1点で留める（面がつっかえない位置なので、持ち上げるとぶら下がる）
	var box: Node = game.stage.spawn("applebox",Vector3(-14,0.02,4))
	var bag: Node = game.stage.spawn("sandbag",Vector3(-16,0.02,4))
	await frames(2)
	bag.restore([Vector3(-14-box.half.x-bag.half.x-0.002,0.02,4),Quaternion.IDENTITY,false])
	await frames(40)
	var own_inertia: Vector3 = PhysicsServer3D.body_get_direct_state(box.get_rid()).inverse_inertia
	bond(glue,box,bag,box.to_global(box.center+Vector3(-box.half.x-0.001,-box.half.y,0)))
	await frames(10)
	var beside: Quaternion = rotation_of(box).inverse()*rotation_of(bag)
	game.h_grab(box.pid,box.center)
	for i in 6: game.h_hold_command("lift",0.25)
	var hung: Dictionary = await watch_carry(box,bag,beside,180)
	measured("glue_carry_weight",hung)
	check(hung.swing>deg_to_rad(60.0) and bag.center_global().y<box.center_global().y-0.15,"a 12kg weight glued at one point hangs below the held box")
	check(hung.offset<0.08 and hung.tilt<deg_to_rad(15.0),"the held box stays on target under a dangling 12kg weight")
	check(hung.speed<0.3 and hung.spin<0.3 and hung.point<0.03 and hung.finite,"the dangling weight does not shake the held box")
	# 歩いて、向きも変える
	player.global_position += Vector3(2,0,0)
	player.hold_yaw = 0.8
	var walked: Dictionary = await watch_carry(box,bag,beside,180)
	measured("glue_carry_weight_walk",walked)
	check(walked.offset<0.08 and walked.tilt<deg_to_rad(15.0) and walked.point<0.04 and walked.finite,"walking and turning keeps the held box on target with 12kg dangling")
	game.h_release()
	await frames(5)
	check(PhysicsServer3D.body_get_direct_state(box.get_rid()).inverse_inertia.is_equal_approx(own_inertia),"releasing restores the box's own resistance to turning")
	glue.clear()
	box.set_absent(true)
	# 軽い板（カンペ 0.5kg）を寝かせ、その縁に同じ重りを1点で留めて、板を持ち上げる（軽い物で重い物をぶら下げる）
	player.global_position = Vector3(-14,0.1,7)
	card.set_absent(false)
	card.restore([Vector3(-14,0.03,4.4),Quaternion(Basis(Vector3.RIGHT,-PI*0.5)),false])
	await frames(30)
	var edge: Vector3 = card.to_global(card.center+Vector3(-card.half.x,0,0))
	bag.restore([Vector3(edge.x-bag.half.x-0.003,0.02,edge.z),Quaternion.IDENTITY,false])
	await frames(40)
	bond(glue,card,bag,edge)
	await frames(10)
	var level: Quaternion = rotation_of(card).inverse()*rotation_of(bag)
	game.h_grab(card.pid,card.center)
	for i in 6: game.h_hold_command("lift",0.25)
	var light: Dictionary = await watch_carry(card,bag,level,240)
	measured("glue_carry_light_board",light)
	check(light.swing>deg_to_rad(60.0) and bag.center_global().y<card.center_global().y-0.1,"a 12kg weight hangs from the edge of a held 0.5kg board")
	check(light.offset<0.08 and light.tilt<deg_to_rad(15.0) and light.speed<0.5 and light.point<0.04 and light.finite,"even a 0.5kg board stays on target with 12kg dangling from it")
	game.h_release()
	glue.clear()
	card.set_absent(true)
	bag.set_absent(true)
	player.global_position = Vector3(0,0.1,4)
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0

func test_monitor_weight_and_support(player: Node) -> void:
	var monitor: Node = game.camera_switcher.monitor
	monitor.set_absent(false)
	monitor.set_fixed(false)
	monitor.restore([Vector3(5,0.02,5),Quaternion.IDENTITY,false])
	await frames(90)
	check(is_equal_approx(monitor.mass,45.0),"monitor has the specified 45kg mass")
	check(monitor.rolls and not monitor.freeze,"monitor rolls with physical gravity")
	check(monitor.screen_size().is_equal_approx(Vector2(2.48,1.40)),"weight change retains screen dimensions")
	# モニターの当たり判定は見た目どおりになり、支柱の間（画面の下）に乗れる台は無くなった。上のひさしに立たせる
	player.global_position = monitor.to_global(Vector3(0,2.72,0.10))
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	game.input_locked = true
	await frames(20)
	var supported := false
	for i in player.get_slide_collision_count():
		supported = supported or player.get_slide_collision(i).get_collider()==monitor
	check(player.is_on_floor() and supported,"fixture stands on the monitor before pickup")
	var before: Vector3 = player.global_position
	game.input_locked = false
	game.h_grab(monitor.pid)
	if monitor.holder!=0:
		var support_goal := hold_goal(monitor)
		game.h_hold_command("lift",0.2)
		game.h_hold_command("pull")
		check(hold_goal(monitor).is_equal_approx(support_goal) and not monitor.hold_lifted,"support rejects lift and pull without changing the holding target")
	game.input_locked = true
	var max_distance := 0.0
	var peak_speed := 0.0
	var peak_platform := 0.0
	var lowest: float = player.global_position.y
	var first_six_drop := 0.0
	for i in 120:
		await frames(1)
		max_distance = maxf(max_distance,player.global_position.distance_to(before))
		peak_speed = maxf(peak_speed,player.velocity.length())
		peak_platform = maxf(peak_platform,player.get_platform_velocity().length())
		lowest = minf(lowest,player.global_position.y)
		if i<6: first_six_drop = maxf(first_six_drop,before.y-player.global_position.y)
	measured("self_supported_pickup",{"samples":120,"max_distance_m":max_distance,"first_six_drop_m":first_six_drop,"peak_speed_mps":peak_speed,"peak_platform_mps":peak_platform,"lowest_y_m":lowest,"holder":monitor.holder})
	check(first_six_drop<0.03,"pickup preserves the crew's supporting collision immediately")
	check(max_distance<2.0 and peak_speed<8.0 and peak_platform<8.0 and lowest>=-0.05,"picking own support cannot launch or drop crew through the floor")
	if monitor.holder!=0: game.host_release(monitor)
	player.set_physics_process(false)
	# A second REAL character stands on the monitor; the picker is on the ground.
	game._roster.append([2,3])
	game._apply_roster()
	var occupant: Node = game.players[2]
	occupant.is_local = true
	monitor.restore([Vector3(5,0.02,5),Quaternion.IDENTITY,false])
	player.global_position = Vector3(7,0.1,5)
	await frames(90)
	occupant.global_position = monitor.to_global(Vector3(0,2.72,0.10))
	occupant.velocity = Vector3.ZERO
	game.input_locked = true
	await frames(20)
	check(occupant.is_on_floor(),"second crew is grounded before another person picks up the monitor")
	before = occupant.global_position
	game.input_locked = false
	game.h_grab(monitor.pid)
	game.input_locked = true
	max_distance = 0.0
	peak_speed = 0.0
	peak_platform = 0.0
	for i in 120:
		await frames(1)
		max_distance = maxf(max_distance,occupant.global_position.distance_to(before))
		peak_speed = maxf(peak_speed,occupant.velocity.length())
		peak_platform = maxf(peak_platform,occupant.get_platform_velocity().length())
	measured("other_supported_pickup",{"samples":120,"max_distance_m":max_distance,"peak_speed_mps":peak_speed,"peak_platform_mps":peak_platform})
	check(max_distance<0.20 and peak_speed<1.0 and peak_platform<1.0,"stationary pickup keeps another crew's support stable")
	if monitor.holder!=0: game.host_release(monitor)
	occupant.set_physics_process(false)
	occupant.global_position = Vector3(30,0.1,30)
	# 45kg regression: a successful RPC/changed target is not proof of transport.
	# Measure real travel on the game's floor with the monitor's actual colliders.
	game.input_locked = false
	player.global_position = Vector3(5,0.1,8)
	monitor.restore([Vector3(5,0.02,5),Quaternion.IDENTITY,false])
	await frames(90)
	game.h_grab(monitor.pid)
	var transport_start: Vector3 = monitor.global_position
	game.h_hold_command("pull")
	var transport_goal := hold_goal(monitor)
	var requested := Vector2(transport_goal.origin.x-transport_start.x,transport_goal.origin.z-transport_start.z).length()
	var travel := 0.0
	for i in 120:
		await frames(1)
		travel = maxf(travel,Vector2(monitor.global_position.x-transport_start.x,monitor.global_position.z-transport_start.z).length())
	var remaining := Vector2(monitor.global_position.x-transport_goal.origin.x,monitor.global_position.z-transport_goal.origin.z).length()
	measured("monitor_explicit_transport",{"samples":120,"requested_m":requested,"actual_travel_m":travel,"remaining_m":remaining,"mass_kg":monitor.mass})
	check(requested>1.0,"monitor transport fixture requests a real floor displacement")
	check(travel>0.5 and remaining<0.20,"explicit pull physically transports the 45kg monitor against floor friction")
	# Pressure against a real wall must not be tested with a target on the near side.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 2
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.10,4.0,3.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	game.add_child(wall)
	var wall_x: float = monitor.global_position.x+2.2
	wall.global_position = Vector3(wall_x,2.0,monitor.global_position.z)
	player.hold_offset = Vector3(4,0,0)
	check(hold_goal(monitor).origin.x>wall_x,"monitor wall fixture requests a target beyond the wall")
	await frames(180)
	measured("monitor_wall",{"body_x_m":monitor.global_position.x,"wall_x_m":wall_x,"target_x_m":hold_goal(monitor).origin.x})
	check(monitor.global_position.x<wall_x-1.20,"transported monitor's wide screen remains outside the wall")
	game.host_release(monitor)
	wall.queue_free()
	monitor.set_absent(true)

# Frozen reference from prop.gd before this holding work (the original velocity
# controller). It is ONLY a measurement reference; production scripts are untouched.
func legacy_drive(body: Node, wanted: Transform3D) -> void:
	var max_speed := clampf(16.0/(1.0+body.mass*0.07),2.2,11.0)
	var velocity: Vector3 = (wanted.origin-body.global_position)*10.0
	if body.rolls: velocity.y = 0.0
	velocity = velocity.limit_length(max_speed)
	if body.rolls: velocity.y = body.linear_velocity.y
	body.linear_velocity = velocity
	var difference := (wanted.basis.get_rotation_quaternion()*rotation_of(body).inverse()).normalized()
	if difference.w<0: difference = -difference
	var angle := difference.get_angle()
	body.angular_velocity = difference.get_axis()*angle*9.0 if angle>0.001 else Vector3.ZERO

func test_operation_response(player: Node) -> void:
	player.set_physics_process(false)
	game.input_locked = false
	player.global_position = Vector3(-8,0.0004,7)
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0
	player.head.rotation = Vector3.ZERO
	# Real supplied props span light/medium/heavy and rolling/nonrolling equipment.
	for sample: Dictionary in [{"kind":"carton","bond":false},{"kind":"sandbag","bond":false},{"kind":"dolly","bond":false},{"kind":"monitor","bond":false},{"kind":"applebox","bond":true}]:
		var body: Node = game.camera_switcher.monitor if sample.kind=="monitor" else game.stage.spawn(sample.kind,Vector3(-8,0.02,4))
		body.set_absent(false)
		var partner: Node = game.stage.spawn("sandbag",Vector3(-10,0.02,4)) if sample.bond else null
		var results := {}
		var reference_target := Transform3D.IDENTITY
		# Measure the actual current command first, then give the frozen old driver
		# that SAME target. Different native G targets are not a fair speed comparison.
		for reference: bool in [false,true]:
			game.adhesive.clear()
			var reset: Array = body.get_state()
			reset[0] = Vector3(-8,0.02,4)
			reset[1] = Quaternion.IDENTITY
			reset[2] = false
			body.restore(reset)
			body.set_physics_process(true)
			if partner!=null:
				partner.restore([Vector3(-8-body.half.x-partner.half.x-0.002,0.02,4),Quaternion.IDENTITY,false])
			await frames(30)
			if partner!=null:
				bond(game.adhesive,body,partner,body.to_global(body.center+Vector3(-body.half.x-0.001,0,0)))
			game.h_grab(body.pid,body.center)
			# Normal placement is an explicit offset/rotation away from the picker.
			# This isolates driving response from G's evolving hand-pose semantics.
			if not body.rolls: game.h_hold_command("lift",0.2)
			player.hold_offset = Vector3(0,0,-2)
			player.hold_yaw = 0.6
			var target := hold_goal(body)
			if reference:
				target = reference_target
				body.physics_material_override.friction = 0.9 # original Prop material
			else: reference_target = target
			var start: Vector3 = body.global_position
			var start_rotation := rotation_of(body)
			body.set_physics_process(not reference)
			var reached := -1
			var peak_speed := 0.0
			var peak_spin := 0.0
			for i in 90:
				if reference: legacy_drive(body,target)
				await frames(1)
				peak_speed = maxf(peak_speed,body.linear_velocity.length())
				peak_spin = maxf(peak_spin,body.angular_velocity.length())
				var distance: float = Vector2(body.global_position.x-target.origin.x,body.global_position.z-target.origin.z).length() if body.rolls else body.global_position.distance_to(target.origin)
				if reached<0 and distance<0.20 and rotation_of(body).angle_to(target.basis.get_rotation_quaternion())<0.12: reached = i+1
			var travel: float = Vector2(body.global_position.x-start.x,body.global_position.z-start.z).length()
			var turn: float = rotation_of(body).angle_to(start_rotation)
			var target_shift: float = hold_goal(body).origin.distance_to(target.origin) if not reference else 0.0
			results["legacy" if reference else "current"] = {"travel_m":travel,"turn_rad":turn,"settled_frame":reached,"peak_speed_mps":peak_speed,"peak_spin_radps":peak_spin,"target_shift_m":target_shift,"target_origin":[target.origin.x,target.origin.y,target.origin.z]}
			game.host_release(body)
			body.set_physics_process(true)
		measured("response_"+sample.kind+("_bonded" if sample.bond else ""),{"mass_kg":body.mass,"rolls":body.rolls,"samples":90,"legacy":results.legacy,"current":results.current})
		check(results.current.travel_m>0.5 and results.current.turn_rad>0.35,sample.kind+" ordinary placement responds to translation and rotation")
		check(results.current.target_shift_m<0.005,sample.kind+" stationary comparison keeps its requested target stable")
		check(results.current.settled_frame>0,sample.kind+" reaches useful placement accuracy within 1.5 seconds")
		if results.legacy.settled_frame>0:
			check(results.current.settled_frame>0 and results.current.settled_frame<=maxi(60,results.legacy.settled_frame*2+15),sample.kind+" response retains usable speed relative to the legacy driver")
		game.adhesive.clear()
		body.set_absent(true)
		if partner!=null: partner.set_absent(true)

