extends RefCounted
# Development-only synchronized views of ONE World3D, with sampled numeric checks.
signal idle_ready
var runtime: Node
var views: Array = []
var plan: Dictionary
var folder: String
var start_tick := 0

func run(owner: Node, request: Dictionary) -> Dictionary:
	runtime = owner
	plan = request.duplicate(true)
	plan.erase("token")  # Transport authentication must never enter exported evidence.
	if plan.get("op") == "capture_views":
		plan.frames = [0]
		plan.events = []
	var error := _validate()
	if not error.is_empty():
		return runtime._error(error)
	folder = str(plan.output).simplify_path()
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return runtime._error("Cannot create output folder")
	var was_paused: bool = runtime.get_tree().paused
	var old_size: Vector2i = runtime._viewport.size
	var held := {}
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			held[action] = Input.get_action_strength(action)
	var pending: Dictionary = runtime._pending_input.duplicate(true)
	runtime.get_tree().paused = true
	var result: Dictionary = await _execute()
	# One exit path for successful and rejected execution. No persistent cameras.
	for view in views:
		if not view.game:
			view.viewport.free()
	views.clear()
	runtime._viewport.size = old_size
	runtime._viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	runtime._capturing = false
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action) and not held.has(action):
			Input.action_release(action)
	for action in held:
		if not Input.is_action_pressed(action) or not is_equal_approx(Input.get_action_strength(action), held[action]):
			Input.action_press(action, held[action])
	runtime._pending_input = pending
	runtime.get_tree().paused = was_paused
	return result

func _validate() -> String:
	if DisplayServer.get_name() == "headless":
		return "Review images need --mode render"
	if not str(plan.get("output", "")).is_absolute_path():
		return "output must be an absolute directory"
	var frames: Variant = plan.get("frames", [])
	if not frames is Array or frames.is_empty() or frames.size() > 120:
		return "frames needs 1..120 ascending sample frames"
	var last := -1
	for frame in frames:
		if not _integer(frame) or frame <= last or frame > 600 or frame < 0:
			return "frames must be ascending integers in 0..600"
		last = int(frame)
	var size: Variant = plan.get("size", [640, 360])
	if not size is Array or size.size() != 2:
		return "size must be [width, height]"
	for dimension in size:
		if not _integer(dimension) or dimension < 64 or dimension > 1600:
			return "size dimensions must be integers in 64..1600"
	plan.size = size
	var specs: Variant = plan.get("views", [{"id": "game"}])
	if not specs is Array or specs.is_empty() or specs.size() > 4:
		return "views needs 1..4 cameras"
	var identifiers := {}
	var valid_id := RegEx.new()
	valid_id.compile("^[A-Za-z][A-Za-z0-9_-]{0,31}$")
	for spec in specs:
		if not spec is Dictionary:
			return "Each view must be an object"
		var id := str(spec.get("id", ""))
		if valid_id.search(id) == null or identifiers.has(id):
			return "Camera IDs must be unique safe identifiers"
		identifiers[id] = true
		if id != "game":
			for key in ["position", "target"] if not spec.has("follow") else ["offset", "look_offset"]:
				if not _vector_ok(spec.get(key)):
					return "Camera needs finite Vector3 " + key
			if not is_finite(float(spec.get("fov", 50.0))) or float(spec.get("fov", 50.0)) < 5 or float(spec.get("fov", 50.0)) > 150:
				return "Camera fov must be in 5..150"
	plan.views = specs
	var events: Variant = plan.get("events", [])
	if not events is Array or events.size() > 120:
		return "events must be an array of at most 120 commands"
	for event in events:
		if not event is Dictionary or not _integer(event.get("frame")) or int(event.frame) < 0 or int(event.frame) > last:
			return "Event frame must be an integer within the capture timeline"
		if str(event.get("op", "")) not in ["call", "input", "set"]:
			return "Events only support call, input and set"
	var combined := {}
	for frame in frames:
		combined[int(frame)] = true
	for event in events:
		combined[int(event.frame)] = true
	if combined.size() > 120:
		return "Capture and event timeline exceeds 120 sample times"
	plan.events = events
	var checks: Variant = plan.get("checks", [])
	if not checks is Array or checks.size() > 16:
		return "checks must be an array of at most 16 limits"
	for check in checks:
		if not check is Dictionary or str(check.get("type", "")) not in ["feet", "property", "group_count"]:
			return "Unsupported check type"
		for key in ["min", "max", "tolerance", "ground_y"]:
			if check.has(key) and (not (check[key] is int or check[key] is float) or not is_finite(float(check[key]))):
				return "Check limits must be finite numbers"
		if check.get("type") == "feet" and (not check.has("ground_y") or float(check.get("tolerance", 0.03)) < 0):
			return "Feet checks require explicit ground_y and nonnegative tolerance"
	plan.checks = checks
	return ""

func _execute() -> Dictionary:
	if not str(plan.get("scene", "")).is_empty():
		var loaded: Dictionary = await runtime._dispatch({"op": "load", "scene": plan.scene})
		if not loaded.ok:
			return loaded
	if not is_instance_valid(runtime._scene):
		return runtime._error("Load a scene before review")
	for spec in plan.views:
		if spec.has("follow") and not runtime._node(str(spec.follow)) is Node3D:
			return runtime._error("Camera follow node must exist and be Node3D")
	for check in plan.checks:
		var reading := _check(check)
		if reading.has("error"):
			return runtime._error(reading.error)
	var capture_size := Vector2i(plan.size[0], plan.size[1])
	for spec in plan.views:
		if spec.id == "game":
			views.append({"id": "game", "game": true, "viewport": runtime._viewport, "spec": spec})
		else:
			var viewport := SubViewport.new()
			viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
			viewport.size = capture_size
			# world_3d may be null when own_world_3d is enabled; resolve the actual world.
			viewport.world_3d = runtime._viewport.find_world_3d()
			viewport.msaa_3d = runtime._viewport.msaa_3d
			viewport.positional_shadow_atlas_size = runtime._viewport.positional_shadow_atlas_size
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			runtime.add_child(viewport)
			var camera := Camera3D.new()
			camera.fov = float(spec.get("fov", 50.0))
			viewport.add_child(camera)
			camera.make_current()
			views.append({"id": spec.id, "game": false, "viewport": viewport, "camera": camera, "spec": spec})
	var timeline: Array = plan.frames.duplicate()
	for event in plan.events:
		if event.frame not in timeline:
			timeline.append(event.frame)
	timeline.sort()
	if timeline.size() > 120:
		return runtime._error("Capture and event timeline exceeds 120 sample times")
	var samples := []
	var previous := 0
	start_tick = runtime._ticks
	var began := Time.get_ticks_usec()
	for frame in timeline:
		if frame > previous:
			await runtime._dispatch({"op": "step", "frames": frame - previous})
		# Resume outside physics so queued input edges apply to the next physics tick.
		await runtime.get_tree().process_frame
		_after_process.call_deferred()
		await idle_ready
		for event in plan.events:
			if event.frame == frame:
				var changed: Dictionary = await runtime._dispatch(event)
				if not changed.ok:
					return runtime._error("Event at frame %d: %s" % [frame, changed.error])
		if not is_instance_valid(runtime._scene):
			return runtime._error("Scene was removed during review")
		var readings := []
		for check in plan.checks:
			var reading := _check(check)
			if reading.has("error"):
				return runtime._error(reading.error)
			readings.append(reading)
		var capture := _capture(frame, readings)
		if capture.has("error"):
			return runtime._error(capture.error)
		samples.append({"frame": frame, "time": frame / 60.0, "physics_frames": runtime._ticks,
			"checks": readings, "images": capture.images})
		previous = frame
	var manifest_path := folder.path_join("manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return runtime._error("Cannot save manifest")
	file.store_string(JSON.stringify({"scenario": plan, "samples": samples, "physics_hz": 60,
		"elapsed_s": (Time.get_ticks_usec() - began) / 1000000.0, "pid": OS.get_process_id()}, "\t"))
	return runtime._ok({"manifest": manifest_path, "samples": samples.size(),
		"images": samples.size() * views.size(), "advanced": previous})

func _capture(frame: int, readings: Array) -> Dictionary:
	runtime._capturing = true
	# Scheduled transforms must be visible in this same sample, without another tick.
	_flush_transforms(runtime._scene)
	for view in views:
		if not view.game:
			var spec: Dictionary = view.spec
			var origin := Vector3.ZERO
			if spec.has("follow"):
				var follower := runtime._node(str(spec.follow)) as Node3D
				if not is_instance_valid(follower):
					return {"error": "Camera follow node disappeared: " + str(spec.follow)}
				origin = follower.global_position
			view.camera.position = origin + _vec(spec.offset if spec.has("follow") else spec.position)
			var target := origin + _vec(spec.look_offset if spec.has("follow") else spec.target)
			if view.camera.position.distance_squared_to(target) < 0.000001:
				return {"error": "Camera position equals target"}
			var direction: Vector3 = (target - view.camera.position).normalized()
			view.camera.look_at(target, Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
			# Flush deferred transform notifications before drawing a newly created camera.
			view.camera.force_update_transform()
		view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# All cameras draw the same frozen state in one render submission.
	RenderingServer.force_draw(false)
	var images := []
	for view in views:
		var image: Image = view.viewport.get_texture().get_image()
		if image == null or image.is_empty():
			return {"error": "No rendered image for " + str(view.id)}
		# Keep the game's original viewport/layout; reduce only the exported image.
		var render_size := Vector2(image.get_width(), image.get_height())
		image.resize(int(plan.size[0]), int(plan.size[1]), Image.INTERPOLATE_LANCZOS)
		var path := folder.path_join("%03d_%s.png" % [frame, view.id])
		if image.save_png(path) != OK:
			return {"error": "Cannot save " + path}
		var focus := {}
		var camera: Camera3D = view.viewport.get_camera_3d()
		if camera != null:
			for reading in readings:
				if reading.type == "feet" and not reading.passed:
					var points := []
					for side in ["left", "right"]:
						var world := _vec(reading.details[side])
						if not camera.is_position_behind(world):
							var pixel: Vector2 = camera.unproject_position(world) * Vector2(image.get_width(), image.get_height()) / render_size
							points.append(runtime._encode(pixel))
					focus[reading.id] = points
		images.append({"view": view.id, "path": path, "physics_frames": runtime._ticks,
			"width": image.get_width(), "height": image.get_height(), "focus": focus})
		view.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return {"images": images}

func _after_process() -> void:
	idle_ready.emit()

func _flush_transforms(node: Node) -> void:
	if node is Node3D:
		node.force_update_transform()
	for child in node.get_children():
		_flush_transforms(child)

func _check(spec: Dictionary) -> Dictionary:
	var kind := str(spec.type)
	var node: Node = runtime._node(str(spec.get("node", ".")))
	var value := 0.0
	var low := float(spec.get("min", -INF))
	var high := float(spec.get("max", INF))
	var details := {}
	if kind == "group_count":
		for member in runtime.get_tree().get_nodes_in_group(str(spec.get("group", ""))):
			if member == runtime._scene or runtime._scene.is_ancestor_of(member):
				value += 1
	elif node == null:
		return {"error": "Check node missing: " + str(spec.get("node", "."))}
	elif kind == "feet":
		var visual: Node = node
		if spec.has("visual_property"):
			if not runtime._has_property(node, str(spec.visual_property)):
				return {"error": "Missing visual property"}
			visual = node.get(str(spec.visual_property)) as Node
		if visual == null or not visual.has_method("foot_position"):
			return {"error": "Feet check needs foot_position(side), measured at the sole"}
		var left: Variant = visual.call("foot_position", "L")
		var right: Variant = visual.call("foot_position", "R")
		if not left is Vector3 or not right is Vector3:
			return {"error": "foot_position must return Vector3"}
		details = {"left": runtime._encode(left), "right": runtime._encode(right), "ground_y": spec.ground_y}
		value = minf(left.y, right.y) - float(spec.ground_y)
		low = -float(spec.get("tolerance", 0.03))
	else:
		var property := str(spec.get("property", ""))
		if not runtime._has_property(node, property):
			return {"error": "Check property missing: " + property}
		var raw: Variant = node.get(property)
		if not raw is float and not raw is int:
			return {"error": "Check property must be numeric"}
		value = float(raw)
	if not is_finite(value):
		return {"error": "Nonfinite check reading"}
	return {"id": str(spec.get("id", kind)), "type": kind, "value": value,
		"passed": value >= low and value <= high, "severity": maxf(0, maxf(low - value, value - high)),
		"details": details}

func _vector_ok(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not (component is float or component is int) or not is_finite(float(component)):
			return false
	return true

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value))

func _vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
