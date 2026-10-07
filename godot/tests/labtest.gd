extends SceneTree
var lab: Node
var failed := false
func _initialize() -> void:
	run.call_deferred()
	create_timer(20.0, true, false, true).timeout.connect(func(): quit(2))
func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
func check(ok: bool, label: String) -> void:
	print("LAB_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func run() -> void:
	check(ResourceLoader.exists("res://motion_lab.tscn"), "lab scene exists")
	if failed:
		quit(1)
		return
	lab = load("res://motion_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await wait(0.15)
	check("dash_dust_style" in lab and lab.get("dash_dust_style") == "sculpted", "sculpted smoke is the default")
	if failed:
		quit(1)
		return
	lab.start_trial()
	await wait(0.22)
	check(lab.local_player().vis.current == "run_start", "lab uses real controller startup")
	check(get_nodes_in_group("dash_dust").size() == 1, "one dust burst at push-off")
	for key in [KEY_C, KEY_T, KEY_TAB, KEY_F9]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		root.push_input(event)
	check(not lab.character_open and not lab.help_open, "game shortcuts isolated from lab")
	lab.toggle_pause()
	var time: float = lab.trial_time
	if get_nodes_in_group("dash_dust").is_empty():
		quit(1)
		return
	var cloud: Node = get_nodes_in_group("dash_dust")[0]
	check(cloud.get_script().resource_path.ends_with("sculpted_dust.gd") and cloud.lifetime > 1.0, "sculpted smoke has longer follow-through")
	var age: float = cloud.age
	var clip_time: float = lab.local_player().vis.anim.current_animation_position
	await wait(0.08)
	check(is_equal_approx(lab.trial_time, time) and is_equal_approx(cloud.age, age), "pause freezes player and dust")
	lab.step_one()
	await wait(0.08)
	check(paused and absf(lab.trial_time - time - 1.0/60.0) < 0.001, "single frame advances once")
	check(cloud.age > age, "single frame advances dust too")
	check(lab.local_player().vis.anim.current_animation_position > clip_time, "single frame advances skeletal animation")
	lab.reset_trial()
	await wait(0.1)
	check(not paused and get_nodes_in_group("dash_dust").is_empty(), "reset clears preview effects")
	lab.set_dust_style("mesh")
	await wait(0.22)
	var mesh_clouds := get_nodes_in_group("dash_dust")
	check(mesh_clouds.size() == 1 and mesh_clouds[0].get_script().resource_path.ends_with("toon_dust.gd"), "original effect remains selectable")
	lab.set_dust_style("kenney")
	await wait(0.22)
	check(get_nodes_in_group("dash_dust").size() == 1 and get_nodes_in_group("dash_dust")[0].get_child(0).texture.resource_path.contains("kenney_smoke"), "Kenney texture remains selectable")
	lab.set_dust_style("sculpted")
	await wait(0.22)
	check(get_nodes_in_group("dash_dust").size() == 1 and lab.dash_dust_style == "sculpted", "switch back clears previous effect")
	lab.reset_trial()
	lab.choose_character(0)
	check(lab.local_player().vis.tag == "M02", "character selection")
	lab.dust_enabled = false
	lab.start_trial()
	await wait(0.25)
	check(get_nodes_in_group("dash_dust").is_empty(), "dust comparison toggle")
	lab.reset_trial()
	lab.set_playback_speed(0.5)
	lab.dust_enabled = true
	lab.start_trial()
	await wait(0.32)
	check(lab.trial_time > 0.1 and lab.trial_time < 0.2, "half speed simulation")
	lab.toggle_pause()
	time = lab.trial_time
	lab.step_one()
	await wait(0.08)
	check(absf(lab.trial_time - time - 1.0/60.0) < 0.001, "step remains one game frame at half speed")
	lab.reset_trial()
	lab.set_playback_speed(1.0)
	lab.choose_character(3)
	lab.start_trial()
	if DisplayServer.get_name() != "headless":
		await wait(0.25)
		lab.toggle_pause()
		await lab.save_frame()
		var saved: String = lab._status.text.trim_prefix("保存しました: ")
		check(FileAccess.file_exists(saved) and FileAccess.file_exists(saved.trim_suffix(".png") + ".json"), "PNG and metadata export")
		await RenderingServer.frame_post_draw
		var dir := ProjectSettings.globalize_path("res://tests/shots")
		DirAccess.make_dir_recursive_absolute(dir)
		root.get_texture().get_image().save_png(dir.path_join("motion_lab.png"))
		lab.toggle_pause()
	# Release at 1.0s + contact-cloud lifetime 0.84s, measured in simulation frames.
	# Wall-clock timers can finish before physics catches up under rendering load.
	for frame in 130:
		await physics_frame
	check(get_nodes_in_group("dash_dust").is_empty(), "dust geometry expires")
	# A tap shorter than the anticipation must not puff.
	lab.reset_trial()
	await wait(0.12)
	lab.input_locked = false
	Input.action_press("run")
	Input.action_press("move_forward")
	await wait(0.03)
	Input.action_release("run")
	Input.action_release("move_forward")
	await wait(0.12)
	check(get_nodes_in_group("dash_dust").is_empty(), "cancelled anticipation emits no dust")
	lab.reset_trial()
	lab.sustain_run = true
	lab.start_trial()
	await wait(1.85)
	check(lab._active and lab.local_player().vis.current == "run", "sustained run previews full loop")
	var trails := get_nodes_in_group("dash_dust")
	check(not trails.is_empty() and trails.all(func(d: Node): return d._trail and d._size < 0.6), "continued contact smoke is smaller than startup")
	lab._release_input()
	await wait(1.5)
	check(get_nodes_in_group("dash_dust").is_empty(), "stopping ends contact smoke and cleans geometry")
	Input.action_press("run")
	Input.action_press("move_forward")
	await wait(0.65)
	var runner: Node = lab.local_player()
	var speed_before: Vector3 = runner.velocity
	runner.position.z = -20.0
	lab._physics_process(1.0 / 60.0)
	check(runner.position.z > -12.4 and runner.velocity.is_equal_approx(speed_before) and runner.vis.current == "run", "sustained run stays on floor without restarting pose")
	lab.sustain_run = false
	lab.reset_trial()
	lab.loop_enabled = true
	lab.start_trial()
	await wait(1.85)
	check(lab._active and lab.trial_time < 0.4, "loop restarts actual controller")
	lab.queue_free()
	await process_frame
	check(not paused and is_equal_approx(Engine.time_scale, 1.0), "lab cleanup restores engine")
	print("LABTEST_FAIL" if failed else "LABTEST_OK")
	quit(1 if failed else 0)
