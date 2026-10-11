extends Node
# A local, explicit development runtime. No autoload or editor plugin required.
signal stepped
var _server := TCPServer.new()
var _clients: Array = []
var _token := ""
var _busy := false
var _capturing := false
var _remaining := 0
var _ticks := 0
var _viewport: SubViewport
var _scene: Node
var _scene_path := ""
var _pending_input := {}

func start(port: int, token: String) -> Error:
	name = "DevSession"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100000
	_token = token
	_viewport = SubViewport.new()
	_viewport.name = "Game"
	_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	_viewport.size = Vector2i(1600, 900)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var error := _server.listen(port, "127.0.0.1")
	if error != OK:
		push_error("Dev session listen failed: %s" % error_string(error))
	return error

func _process(_delta: float) -> void:
	if not _capturing:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if get_tree().paused else SubViewport.UPDATE_ALWAYS
	# The real game can ask to capture the mouse; this worker must not capture it.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _server.is_connection_available():
		_clients.append({"peer": _server.take_connection(), "buffer": ""})
	for client in _clients.duplicate():
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(client)
			continue
		var count := peer.get_available_bytes()
		if count > 0:
			var packet := peer.get_data(count)
			if packet[0] == OK:
				# Accumulate bytes so fragmented UTF-8 paths stay intact.
				var bytes: PackedByteArray = client.get("bytes", PackedByteArray())
				bytes.append_array(packet[1])
				client.bytes = bytes
				if bytes.size() > 1048576:
					peer.disconnect_from_host()
					continue
		if _busy or not client.has("bytes"):
			continue
		var bytes: PackedByteArray = client.bytes
		var newline := bytes.find(10)
		if newline < 0:
			continue
		client.bytes = bytes.slice(newline + 1)
		var request: Variant = JSON.parse_string(bytes.slice(0, newline).get_string_from_utf8())
		_busy = true
		_reply(peer, request)
		break

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	_ticks += 1
	if _remaining > 0:
		_remaining -= 1
		if _remaining == 0:
			get_tree().paused = true
			stepped.emit()

func _reply(peer: StreamPeerTCP, request: Variant) -> void:
	var response: Dictionary
	if not request is Dictionary or request.get("token", "") != _token:
		response = _error("Invalid local session request")
	else:
		response = await _dispatch(request)
	peer.put_data((JSON.stringify(response) + "\n").to_utf8_buffer())
	_busy = false
	if request is Dictionary and request.get("op") == "shutdown" and response.get("ok", false):
		get_tree().quit.call_deferred()

func _dispatch(request: Dictionary) -> Dictionary:
	var op: String = request.get("op", "status")
	match op:
		"status":
			return _ok({"pid": OS.get_process_id(), "project": ProjectSettings.globalize_path("res://"), "mode": "headless" if DisplayServer.get_name() == "headless" else "render", "scene": _scene_path, "paused": get_tree().paused, "physics_frames": _ticks, "window_visible": get_tree().root.visible, "mouse_captured": Input.mouse_mode != Input.MOUSE_MODE_VISIBLE})
		"shutdown":
			return _ok("stopping")
		"load":
			var path: String = request.get("scene", "")
			if not path.begins_with("res://") or not path.ends_with(".tscn") or not ResourceLoader.exists(path):
				return _error("Scene must be an existing res:// .tscn")
			var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
			if packed == null or not packed.can_instantiate():
				return _error("Cannot load scene; inspect the session log")
			get_tree().paused = true
			Engine.time_scale = 1.0
			_pending_input.clear()
			for action in InputMap.get_actions():
				Input.action_release(action)
			if is_instance_valid(_scene):
				_scene.free()
			_scene = packed.instantiate()
			_scene_path = path
			_viewport.add_child(_scene)
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return _ok({"scene": path, "node": str(_scene.get_path())})
		"step":
			var frames := int(request.get("frames", 1))
			if frames < 1 or frames > 3600:
				return _error("frames must be 1..3600")
			_remaining = frames
			_flush_input()
			get_tree().paused = false
			await stepped
			return _ok({"physics_frames": _ticks, "advanced": frames})
		"pause":
			if not bool(request.get("paused", true)):
				_flush_input()
			get_tree().paused = bool(request.get("paused", true))
			return _ok(get_tree().paused)
		"input":
			var action: String = request.get("action", "")
			if not InputMap.has_action(action):
				return _error("Unknown action: " + action)
			if get_tree().paused:
				_pending_input[action] = {"pressed": bool(request.get("pressed", true)), "strength": float(request.get("strength", 1.0))}
			if bool(request.get("pressed", true)):
				Input.action_press(action, float(request.get("strength", 1.0)))
			else:
				Input.action_release(action)
			var event := InputEventAction.new()
			event.action = action
			event.pressed = bool(request.get("pressed", true))
			event.strength = float(request.get("strength", 1.0))
			var was_paused := get_tree().paused
			get_tree().paused = false
			_viewport.push_input(event, true)
			get_tree().paused = was_paused
			return _ok(action)
		"reload":
			return _reload_script(str(request.get("path", "")))
		"capture":
			if DisplayServer.get_name() == "headless":
				return _error("PNG needs a session started with --mode render")
			var path: String = request.get("path", "")
			if path.is_empty() or not path.ends_with(".png"):
				return _error("Provide a PNG output path")
			_capturing = true
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			# Hidden windows can suppress the automatic draw loop, including its signal.
			RenderingServer.force_draw(false)
			var image := _viewport.get_texture().get_image()
			_capturing = false
			if image == null or image.is_empty():
				return _error("No rendered image")
			var error := image.save_png(path)
			return _ok(path) if error == OK else _error(error_string(error))
		"tree", "get", "set", "call":
			var node := _node(str(request.get("node", ".")))
			if node == null:
				return _error("Node not found")
			if op == "tree":
				return _ok(_tree(node, clampi(int(request.get("depth", 3)), 0, 12)))
			if op == "call":
				var method: String = request.get("method", "")
				if not node.has_method(method):
					return _error("Method not found: " + method)
				var was_paused := get_tree().paused
				var result: Variant = await node.callv(method, request.get("args", []))
				get_tree().paused = was_paused
				return _ok(_encode(result))
			var properties: Array = request.get("properties", []) if op == "get" else [request.get("property", "")]
			var values := {}
			for property: String in properties:
				if not _has_property(node, property):
					return _error("Property not found: " + property)
				if op == "set":
					var value: Variant = request.get("value")
					if node.get(property) is Vector3 and value is Array and value.size() == 3:
						value = Vector3(value[0], value[1], value[2])
					node.set(property, value)
				values[property] = _encode(node.get(property))
			return _ok(values)
	return _error("Unknown operation: " + op)

func _reload_script(path: String) -> Dictionary:
	if not path.begins_with("res://") or not path.ends_with(".gd") or path.begins_with("res://addons/dev_session/") or not FileAccess.file_exists(path):
		return _error("Provide an existing project .gd outside the session addon")
	var script := ResourceLoader.load(path) as GDScript
	if script == null:
		return _error("Cannot load script")
	var previous := script.source_code
	script.source_code = FileAccess.get_file_as_string(path)
	var error := script.reload(true)
	if error != OK:
		script.source_code = previous
		script.reload(true)
		return _error("Reload failed; previous code restored: " + error_string(error))
	return _ok({"path": path, "state_kept": true, "note": "Use load to rebuild initialized objects or structural changes"})

func _flush_input() -> void:
	# Godot stamps action edges for the NEXT physics tick. Apply while still idle,
	# just before unpausing, rather than from a physics callback one tick too late.
	for action: String in _pending_input:
		Input.action_release(action)
		if _pending_input[action].pressed:
			Input.action_press(action, _pending_input[action].strength)
	_pending_input.clear()

func _node(path: String) -> Node:
	if not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(NodePath(path))

func _has_property(node: Node, property: String) -> bool:
	for item in node.get_property_list():
		if item.name == property:
			return true
	return false

func _tree(node: Node, depth: int) -> Dictionary:
	var children := []
	if depth > 0:
		for child in node.get_children():
			children.append(_tree(child, depth - 1))
	return {"name": node.name, "path": str(node.get_path()), "class": node.get_class(), "script": node.get_script().resource_path if node.get_script() != null else "", "children": children}

func _encode(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Object:
		return str(value.get_path()) if value is Node and value.is_inside_tree() else str(value)
	if value is Array:
		var result := []
		for item in value:
			result.append(_encode(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _encode(value[key])
		return result
	return value

func _ok(result: Variant) -> Dictionary:
	return {"ok": true, "result": result}

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
