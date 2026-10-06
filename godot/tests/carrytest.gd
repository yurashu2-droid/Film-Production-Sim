extends SceneTree
# Run with a graphics window: Godot --path godot --script res://tests/carrytest.gd
# Input, physical rotation, carrying clips, network/replay names and scaled decks.
var game: Node
var failed := false
func _initialize() -> void:
	run.call_deferred()
	create_timer(25.0).timeout.connect(func(): quit(2))
func check(ok: bool, label: String) -> void:
	print("CARRY_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func wait(sec: float) -> void:
	await create_timer(sec).timeout
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("CARRYTEST_FAIL requires a graphics window")
		quit(2)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	game.h_order_set("dolly", 1)
	game.h_order_confirm()
	await wait(0.5)
	var me: Node = game.local_player()
	var box: Node
	var cart: Node
	for p in game.props.values():
		if p.kind == "carton": box = p
		if p.kind == "dolly": cart = p
	me.global_position = Vector3(0,0.02,7)
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0
	box.restore([Vector3(0,0.05,5),Quaternion.IDENTITY,false])
	game.h_grab(box.pid)
	await wait(0.6)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(140,60)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	var old_view := Vector2(me.aim_yaw, me.aim_pitch)
	game.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	me._unhandled_input(motion)
	game.input_locked = true
	check(absf(me.hold_yaw) > 0.1 and Vector2(me.aim_yaw,me.aim_pitch).is_equal_approx(old_view), "right drag rotates without moving view")
	if failed:
		quit(1)
		return
	check(absf(me.hold_pitch)>0.1,"vertical rotation")
	await wait(1.2)
	check(box.center_global().distance_to(game.hold_target(me.peer_id,box)[0])<0.2,"prop follows hands")
	var desired := Basis.from_euler(Vector3(me.hold_pitch,me.hold_yaw,0))
	check(box.global_basis.orthonormalized().get_rotation_quaternion().angle_to(desired.get_rotation_quaternion())<0.15,"physical held rotation")
	check(me.vis.current.begins_with("carry_"),"holding pose")
	await shot("carry_box")
	var snap: Array = me.get_state()
	me.vis.play("idle",0)
	me.apply_state(snap)
	check(me.vis.current==snap[2],"replay carries animation")
	var sent_pitch: float = me.hold_pitch
	me.hold_pitch = 0.0
	me.apply_net(me.global_position,me.vis.rotation.y,me.aim_yaw,me.aim_pitch,me.hold_dist,me.hold_yaw,sent_pitch,me.vis.current+"|neutral")
	check(is_equal_approx(me.hold_pitch,sent_pitch),"network pitch")
	motion.button_mask = 0
	game.input_locked=false
	me._unhandled_input(motion)
	game.input_locked=true
	check(not Vector2(me.aim_yaw,me.aim_pitch).is_equal_approx(old_view),"normal mouse restores view")
	game.h_release()
	await wait(0.3)
	check(me.vis.current=="idle" and me.hold_pitch==0.0,"release resets pose and pitch")
	var Stage = load("res://scripts/stage.gd")
	for prop in [box,cart]:
		var raw: Node3D = load("res://assets/gear/"+Stage.DEFS[prop.kind]["file"]+".glb").instantiate()
		var bounds: AABB = Stage.merged_aabb(raw)
		check((prop.half*2).is_equal_approx(bounds.size*2),prop.kind+" dimensions doubled")
		raw.free()
	check(is_equal_approx(cart.deck_top,0.64) and cart.deck_half.is_equal_approx(Vector2(1.0,1.32)),"scaled cargo deck")
	check((cart.find_children("*","CollisionShape3D",false,false)[0].shape as BoxShape3D).size.is_equal_approx(Vector3(1.84,0.64,2.4)),"scaled dolly collider")
	for tag in game.PLAYER_CASTS:
		var v: Node3D = load("res://scripts/cast_visual.gd").new()
		root.add_child(v)
		v.setup(tag)
		for clip in ["carry_idle","carry_walk","onehand_idle","onehand_walk"]:
			check(v.has(clip),tag+" "+clip)
		v.play("carry_walk",0)
		v.anim.advance(0.2)
		for side in ["L","R"]:
			var hand: int = v.skel.find_bone("HAND."+side)
			var shoulder: int = v.skel.find_bone("UPPER_ARM."+side)
			var offset: Vector3 = v.skel.get_bone_global_pose(hand).origin-v.skel.get_bone_global_pose(shoulder).origin
			check(offset.z>0.15,tag+" forward hand "+side)
		v.queue_free()
	game.h_sample()
	await wait(0.3)
	check(game.film.rider_of==cart.pid and absf(game.film.global_position.y-cart.global_position.y-cart.deck_top)<0.03,"camera on resized deck")
	game.h_grab(cart.pid)
	await wait(1.0)
	await shot("carry_dolly")
	game.h_release()
	game.h_grab(game.clapper.pid)
	await wait(1.0)
	await shot("carry_clapper")
	print("CARRYTEST_FAIL" if failed else "CARRYTEST_OK")
	quit(1 if failed else 0)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.global_position = game.local_player().global_position + Vector3(-3.5,2.4,-3.5)
	cam.look_at(game.local_player().global_position+Vector3(0,1,-0.8))
	cam.current=true
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	root.get_texture().get_image().save_png("res://tests/shots/"+label+".png")
	cam.queue_free()
	game.local_player().cam.current=true
