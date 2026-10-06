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
	await wait(1.8)
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
	lab.loop_enabled = true
	lab.start_trial()
	await wait(1.85)
	check(lab._active and lab.trial_time < 0.4, "loop restarts actual controller")
	lab.queue_free()
	await process_frame
	check(not paused and is_equal_approx(Engine.time_scale, 1.0), "lab cleanup restores engine")
	print("LABTEST_FAIL" if failed else "LABTEST_OK")
	quit(1 if failed else 0)
