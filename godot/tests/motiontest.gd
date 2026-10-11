extends SceneTree
# Godot --headless --path godot --script res://tests/motiontest.gd
var game: Node
var failed := false
func _initialize() -> void:
	run.call_deferred()
	create_timer(25.0).timeout.connect(func(): quit(2))
func wait(sec: float) -> void:
	await create_timer(sec).timeout
func check(ok: bool, label: String) -> void:
	print("MOTION_CHECK ",label," ","OK" if ok else "FAIL")
	failed = failed or not ok
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.h_order_confirm()
	game.input_locked=true
	await wait(0.3)
	var me: Node = game.local_player()
	for clip in ["run_start","run_stop","step_down","carry_step_down"]:
		check(me.vis.has(clip),"clip "+clip)
	if failed:
		quit(1)
		return
	me.global_position=Vector3(0,0.02,6)
	me.velocity=Vector3.ZERO
	me.aim_yaw=0.0
	await wait(0.2)
	game.input_locked=false
	Input.action_press("run")
	Input.action_press("move_forward")
	await wait(0.08)
	var early_speed := Vector2(me.velocity.x, me.velocity.z).length()
	check(me.vis.current=="run_start" and early_speed>0.5,"run starts without input delay")
	check(early_speed < 1.5,"anticipation holds back initial speed")
	await wait(0.04)
	check(me.vis.current == "run_start" and Vector2(me.velocity.x, me.velocity.z).length() < 1.5,"extended anticipation holds back speed")
	check(get_nodes_in_group("dash_dust").is_empty(),"dust waits for extended push-off")
	await wait(0.16)
	var accelerating_speed := Vector2(me.velocity.x, me.velocity.z).length()
	check(accelerating_speed > early_speed + 0.7 and accelerating_speed < me.RUN * 0.9,"accelerates through startup pose")
	await shot("run_start")
	await wait(0.5)
	check(Vector2(me.velocity.x, me.velocity.z).length() > me.RUN * 0.95,"reaches full running speed")
	check(me.vis.current=="run","run loop after start")
	Input.action_release("move_forward")
	await wait(0.08)
	check(me.vis.current=="run_stop","braking once when movement stops")
	await shot("run_stop")
	Input.action_release("run")
	await wait(0.5)
	check(me.vis.current=="idle","return to idle")
	# Walking into a run should retain existing momentum.
	Input.action_press("move_forward")
	await wait(0.4)
	Input.action_press("run")
	await wait(0.08)
	check(Vector2(me.velocity.x, me.velocity.z).length() > me.WALK * 0.85,"walk-to-run keeps momentum")
	Input.action_release("run")
	await wait(0.08)
	check(me.vis.current == "walk","releasing run cancels startup pose")
	Input.action_release("move_forward")
	await wait(0.4)
	Input.action_press("run")
	Input.action_press("move_forward")
	await wait(0.04)
	Input.action_release("move_forward")
	Input.action_release("run")
	await wait(0.08)
	check(me.vis.current not in ["run_start", "run_stop"],"short tap cancels anticipation")
	await wait(0.3)
	# Walking off a prop-height platform must cause one brief landing reaction.
	var platform := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(1.8,0.9,1.8)
	cs.shape=shape
	platform.add_child(cs)
	game.add_child(platform)
	platform.global_position=Vector3(0,0.45,6)
	me.global_position=Vector3(0,0.94,6)
	me.velocity=Vector3.ZERO
	await wait(0.25)
	Input.action_press("move_forward")
	var landed := false
	var elapsed := 0.0
	while elapsed < 1.5:
		await physics_frame
		elapsed += 1.0/Engine.physics_ticks_per_second
		if me.vis.current=="step_down":
			landed=true
			break
	check(landed and me.is_on_floor(),"step off platform landing")
	var snapshot: Array = me.get_state()
	await shot("step_down")
	Input.action_release("move_forward")
	await wait(0.45)
	check(me.vis.current=="idle","landing reaction finishes")
	var idle_snapshot: Array = me.get_state()
	me.apply_state(snapshot)
	check(me.vis.current=="step_down","landing pose in replay snapshot")
	me.apply_state(idle_snapshot)
	# A ground-level jump doesn't count as stepping down from an object.
	Input.action_press("jump")
	await wait(0.03)
	Input.action_release("jump")
	var ground_reaction := false
	elapsed=0.0
	while elapsed < 1.1:
		await physics_frame
		elapsed += 1.0/Engine.physics_ticks_per_second
		ground_reaction = ground_reaction or me.vis.current=="step_down"
	check(not ground_reaction,"normal ground jump")
	# Holding on landing retains the grip, including with the run key held.
	var box: Node
	for p in game.props.values():
		if p.kind=="carton": box=p
	me.global_position=Vector3(0,0.94,6)
	me.velocity=Vector3.ZERO
	box.restore([Vector3(0,0.95,4.8),Quaternion.IDENTITY,false])
	game.h_grab(box.pid)
	await wait(0.3)
	Input.action_press("run")
	Input.action_press("move_forward")
	landed=false
	elapsed=0.0
	while elapsed < 1.5:
		await physics_frame
		elapsed += 1.0/Engine.physics_ticks_per_second
		if me.vis.current=="carry_step_down":
			landed=true
			break
	check(landed and me.held==box.pid,"carrying through landing")
	await shot("carry_step_down")
	Input.action_release("move_forward")
	Input.action_release("run")
	game.h_release()
	await wait(0.5)
	for tag in game.PLAYER_CASTS:
		var v: Node = load("res://scripts/cast_visual.gd").new()
		root.add_child(v)
		v.setup(tag)
		for clip in ["dash","brake","run_start","run_stop","step_down","carry_step_down"]:
			check(v.has(clip),tag+" "+clip)
		v.queue_free()
	print("MOTIONTEST_FAIL" if failed else "MOTIONTEST_OK")
	quit(1 if failed else 0)


func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await wait(0.08)
	var me: Node = game.local_player()
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.global_position=me.global_position+Vector3(-2.7,2.0,-3.0)
	cam.look_at(me.global_position+Vector3(0,0.9,0))
	cam.current=true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	root.get_texture().get_image().save_png("res://tests/shots/motion_"+label+".png")
	cam.queue_free()
	me.cam.current=true
