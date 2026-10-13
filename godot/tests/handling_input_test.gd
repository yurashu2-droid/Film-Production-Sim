extends SceneTree
## Synthetic REAL viewport input. No holder/target assignment or direct command call.
## Graphics additionally checks post-draw pickup and records arranged poses.
var game: Node
var failed := false
var checks := 0
var rendered := false

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func():
		print("HANDLING_INPUT_TEST_TIMEOUT")
		quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	failed = failed or not ok
	print("HANDLING_INPUT_CHECK ",label," ","OK" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count: await physics_frame

func click() -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = Vector2(root.size)*0.5
		event.global_position = event.position
		root.push_input(event,true)
		await process_frame

func key(code: Key, shift := false) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		event.shift_pressed = shift
		root.push_input(event,true)
		await process_frame

func drag(delta: Vector2, shift := false, alt := false) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	event.shift_pressed = shift
	event.alt_pressed = alt
	event.position = Vector2(root.size)*0.5
	event.global_position = event.position
	root.push_input(event,true)
	await process_frame

func wheel(alt := false, shift := false, up := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.alt_pressed = alt
	event.shift_pressed = shift
	event.position = Vector2(root.size)*0.5
	event.global_position = event.position
	root.push_input(event,true)
	await process_frame

func target_transform(player: Node, prop: Node) -> Transform3D:
	var target: Array = game.hold_target(player.peer_id,prop)
	var basis: Basis = target[4] if target.size()>4 else Basis.from_euler(Vector3(target[3],target[1],0))
	return Transform3D(basis,target[0]-basis*prop.center)

func shot(label: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://tests/shots/handling")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"capture "+label)

func run() -> void:
	rendered = DisplayServer.get_name()!="headless"
	if not rendered:
		print("HANDLING_INPUT_TEST_PENDING requires real rendering and viewport mouse capture")
		quit(3)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if not "startup_complete" in game:
		check(false,"production scene script loads")
		print("HANDLING_INPUT_TEST_FAIL")
		quit(1)
		return
	while not game.startup_complete: await process_frame
	game.production.set_physics_process(false)
	game.camera_switcher.set_process(false)
	game.production.phase = 4
	game._set_state(game.S.PREP)
	for prop: Node in game.props.values(): prop.set_absent(true)
	var player: Node = game.local_player()
	player.set_physics_process(false)
	player.vis.anim.active = false
	player.global_position = Vector3(0,0.1,4)
	player.aim_yaw = 0.0
	player.aim_pitch = 0.0
	var body: Node = game.stage.spawn("applebox",Vector3(0.65,1.05,2.2))
	body.restore([body.global_position,Quaternion.from_euler(Vector3(0.32,0.67,-0.24)),false])
	body.gravity_scale = 0.0
	await frames(4)
	player.cam.global_position = Vector3(0,2.4,5.7)
	player.cam.look_at(body.center_global())
	player._find_target()
	check(player.target==body,"real view ray targets the tilted object")
	var ray := PhysicsRayQueryParameters3D.create(player.cam.global_position,player.cam.global_position-player.cam.global_basis.z*9.0,1|2|4|16)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.collider!=body:
		check(false,"pickup ray reaches a physical surface")
		print("HANDLING_INPUT_TEST_FAIL")
		quit(1)
		return
	var local_point: Vector3 = body.to_local(hit.position)
	game.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("HANDLING_INPUT_MEASURE ready ",JSON.stringify({"mouse_mode":Input.mouse_mode,"blocked":game.ui_blocking(),"local":player.is_local,"input_enabled":player.is_processing_input(),"target_pid":player.target.pid if player.target!=null else 0}))
	var before: Transform3D = body.global_transform
	await shot("before_pickup")
	# On a renderer the following event occurs AFTER frame_post_draw, catching the
	# old physics-overwrite path as well as input consumed twice by HUD/_unhandled.
	await click()
	check(player.held==body.pid and body.holder==player.peer_id,"one viewport click acquires once")
	if player.held!=body.pid:
		print("HANDLING_INPUT_MEASURE missed_click ",JSON.stringify({"mouse_mode":Input.mouse_mode,"blocked":game.ui_blocking(),"held":player.held,"holder":body.holder,"handled":root.is_input_handled()}))
		print("HANDLING_INPUT_TEST_FAIL")
		quit(1)
		return
	await frames(6)
	check(body.global_position.distance_to(before.origin)<0.02,"viewport pickup retains the arranged position")
	check(body.global_basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion())<0.03,"viewport pickup retains roll and tilt")
	check(body.hold_grip_local.distance_to(local_point)<0.0001,"viewport click stores the actual local ray hit")
	await shot("after_pickup")
	var view_before := Vector2(player.aim_yaw,player.aim_pitch)
	var pivot_before: Vector3 = target_transform(player,body)*local_point
	await drag(Vector2(80,35))
	check(absf(player.hold_yaw)>0.1 and absf(player.hold_pitch)>0.1,"right drag rotates the selected object")
	check(Vector2(player.aim_yaw,player.aim_pitch).is_equal_approx(view_before),"right drag leaves the view aim unchanged")
	check((target_transform(player,body)*local_point).distance_to(pivot_before)<0.002,"right drag rotates about the clicked surface point")
	var yaw_before: float = player.hold_yaw
	await drag(Vector2(80,0),true)
	var fine_delta: float = absf(angle_difference(yaw_before,player.hold_yaw))
	check(fine_delta>0.02 and fine_delta<0.15,"Shift right drag provides a smaller useful adjustment")
	var offset_before: Vector3 = player.hold_offset
	await drag(Vector2(20,-12),false,true)
	check(player.hold_offset.distance_to(offset_before)>0.03,"Alt right drag translates the holding target")
	for i in 3: await wheel(false,false,false)
	check(player.hold_dist<1.6,"wheel can bring the object closer than the old fixed minimum")
	var old_goal := target_transform(player,body)
	await key(KEY_L)
	var lifted := target_transform(player,body)
	check(absf(lifted.origin.y-old_goal.origin.y-0.2)<0.002,"L lifts by the documented step")
	await key(KEY_L,true)
	check(absf(target_transform(player,body).origin.y-old_goal.origin.y)<0.002,"Shift L lowers by the same step")
	await wheel(true,true)
	check(absf(target_transform(player,body).origin.y-old_goal.origin.y-0.05)<0.002,"Alt Shift wheel provides a fine vertical step")
	var tilted := target_transform(player,body)
	await key(KEY_G)
	var pulled := target_transform(player,body)
	check(pulled.origin.distance_to(tilted.origin)>0.1,"G explicitly pulls the object to carrying position")
	# Revised user contract: G is a one-time upright-and-pull, not tilt-preserving.
	check(pulled.basis.y.dot(Vector3.UP)>0.999,"G explicitly requests upright while pulling")
	await frames(180)
	check(body.global_position.distance_to(pulled.origin)<0.12,"physical object reaches explicit carrying position")
	await shot("explicit_pull")
	var before_qe: Quaternion = body.global_basis.get_rotation_quaternion()
	player.set_physics_process(true)
	Input.action_press("rot_left")
	await frames(24)
	Input.action_release("rot_left")
	player.set_physics_process(false)
	check(absf(player.hold_yaw)>0.3,"Q rotation reads real InputMap while holding")
	check(body.global_basis.get_rotation_quaternion().angle_to(before_qe)>0.20,"Q produces useful physical rotation within 0.4 seconds")
	await drag(Vector2(0,35))
	var adjusted := target_transform(player,body)
	await frames(120)
	check(body.global_basis.get_rotation_quaternion().angle_to(adjusted.basis.get_rotation_quaternion())<0.03,"later tilt adjustments survive the one-time G command")
	await key(KEY_R)
	check(target_transform(player,body).basis.y.dot(Vector3.UP)>0.999,"R explicitly requests upright")
	await frames(180)
	check(body.global_basis.y.dot(Vector3.UP)>0.995,"physical object becomes upright only after R")
	await shot("explicit_upright")
	var released: Transform3D = body.global_transform
	await click()
	check(player.held==0 and body.holder==0,"second viewport click releases once")
	check(body.global_position.distance_to(released.origin)<0.03,"release input leaves the arranged position intact")
	await surface_pivots(player,body)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_scene = null
	game.queue_free()
	game = null
	root.get_node("Sfx").silence_all()
	await frames(8)
	print("HANDLING_INPUT_TEST_FAIL" if failed else ("HANDLING_INPUT_TEST_OK" if rendered else "HANDLING_INPUT_TEST_PENDING")," checks=",checks," rendering=",rendered)
	quit(1 if failed else (0 if rendered else 3))

func surface_pivots(player: Node, body: Node) -> void:
	var previous_point := Vector3.INF
	for sample: Dictionary in [{"name":"center","x":0.0,"y":0.0},{"name":"edge","x":0.8,"y":0.0},{"name":"corner","x":0.8,"y":0.8}]:
		body.restore([Vector3(0.65,1.05,2.2),Quaternion.from_euler(Vector3(0.25,0.55,-0.2)),false])
		body.gravity_scale = 0.0
		await frames(4)
		var aimed: Vector3 = body.to_global(body.center+Vector3(body.half.x*sample.x,body.half.y*sample.y,body.half.z))
		player.cam.global_position = aimed+body.global_basis.z*3.0
		player.cam.look_at(aimed)
		player._find_target()
		var ray := PhysicsRayQueryParameters3D.create(player.cam.global_position,player.cam.global_position-player.cam.global_basis.z*9.0,1|2|4|16)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==body,"real ray hits "+sample.name+" surface")
		if hit.is_empty() or hit.collider!=body: continue
		var local_point: Vector3 = body.to_local(hit.position)
		if previous_point.is_finite(): check(local_point.distance_to(previous_point)>0.10,"regrabbing selects a different "+sample.name+" point")
		previous_point = local_point
		var before: Transform3D = body.global_transform
		await click()
		check(body.global_transform.is_equal_approx(before),sample.name+" acquisition has no transform jump")
		check(body.hold_grip_local.distance_to(local_point)<0.0001,sample.name+" acquisition stores the newly clicked local point")
		var point: Vector3 = target_transform(player,body)*local_point
		await drag(Vector2(65,30))
		var wanted := target_transform(player,body)
		var goal_error := (wanted*local_point).distance_to(point)
		var peak_error := 0.0
		for i in 90:
			await frames(1)
			peak_error = maxf(peak_error,body.to_global(local_point).distance_to(point))
		var end_error: float = body.to_global(local_point).distance_to(point)
		print("HANDLING_INPUT_MEASURE surface_pivot ",JSON.stringify({"sample":sample.name,"local_x":local_point.x,"local_y":local_point.y,"local_z":local_point.z,"goal_error_m":goal_error,"peak_error_m":peak_error,"end_error_m":end_error}))
		check(goal_error<0.002,sample.name+" target rotates about its picked point")
		check(end_error<0.04,sample.name+" physical picked point converges to the pivot")
		# View changes must move the held point after a jump-free pickup.
		var before_view: Transform3D = game.hold_view_anchor(player)
		var before_target: Vector3 = wanted*local_point
		# No right button: ordinary look input, rather than object rotation.
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(55,-20)
		motion.position = Vector2(root.size)*0.5
		root.push_input(motion,true)
		await process_frame
		player.head.rotation = Vector3(player.aim_pitch,player.aim_yaw,0)
		await frames(2)
		var expected: Vector3 = game.hold_view_anchor(player)*(before_view.affine_inverse()*before_target)
		var actual: Vector3 = target_transform(player,body)*local_point
		print("HANDLING_INPUT_MEASURE view_follow ",JSON.stringify({"sample":sample.name,"requested_distance_m":expected.distance_to(before_target),"actual_distance_m":actual.distance_to(before_target),"target_error_m":actual.distance_to(expected)}))
		check(actual.distance_to(before_target)>0.04,sample.name+" held point follows a subsequent view rotation")
		check(actual.distance_to(expected)<0.02,sample.name+" maintains its view-relative picked offset")
		await click()
