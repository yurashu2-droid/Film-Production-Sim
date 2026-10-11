extends SceneTree
# Conventional --script capture: no dev-session runner, TCP server or hot reload.
const FRAMES := [12, 30, 54, 72]
var folder := ""

class CaptureDriver extends Node:
	var destination: String
	var viewport: SubViewport
	var preview: Node3D
	var frames := 0
	var sample := 0
	var started := false
	var pending := false
	var simulation_start := 0
	var simulation_us := 0
	var capture_us := 0
	var states: Array = []

	func _physics_process(_delta: float) -> void:
		if get_tree().paused:
			return
		frames += 1
		if frames == FRAMES[sample]:
			get_tree().paused = true
			pending = true
			simulation_us += Time.get_ticks_usec() - simulation_start

	func _process(_delta: float) -> void:
		if not started:
			if FileAccess.file_exists(destination.path_join("begin")):
				started = true
				simulation_start = Time.get_ticks_usec()
				get_tree().paused = false
			return
		if not pending:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if get_tree().paused else SubViewport.UPDATE_ALWAYS
			return
		pending = false
		var before := Time.get_ticks_usec()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		RenderingServer.force_draw(false)
		var error := viewport.get_texture().get_image().save_png(destination.path_join("%03d.png" % FRAMES[sample]))
		if error != OK:
			push_error("Benchmark PNG failed")
			get_tree().quit(2)
			return
		capture_us += Time.get_ticks_usec() - before
		states.append(preview.sample_state())
		sample += 1
		if sample == FRAMES.size():
			var file := FileAccess.open(destination.path_join("done.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"states": states, "simulation_s": simulation_us / 1000000.0,
				"capture_s": capture_us / 1000000.0, "pid": OS.get_process_id()}))
			file.close()
			get_tree().quit()
		else:
			simulation_start = Time.get_ticks_usec()
			get_tree().paused = false

func _initialize() -> void:
	root.unfocusable = true
	Engine.max_fps = 60
	paused = true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			folder = argument.trim_prefix("--output=")
	_boot.call_deferred()

func _boot() -> void:
	if folder.is_empty():
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var preview: Node3D = load("res://addons/dev_session/benchmarks/vfx_preview.tscn").instantiate()
	viewport.add_child(preview)
	var driver := CaptureDriver.new()
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	driver.process_physics_priority = 100000
	driver.destination = folder
	driver.viewport = viewport
	driver.preview = preview
	root.add_child(driver)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var file := FileAccess.open(folder.path_join("ready.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "mouse_captured": false}))
