extends Node
## Surface dots are local to each body. Only touching dots create a physical bond.
const TOUCH := 0.12
var game: Node
var tool: RigidBody3D
var applying := false
var first := {} # peer -> [prop id, local surface point]
var pairs: Array = []
var joints := {}
var markers: Array[Node3D] = []
var _shown := {}

func setup() -> void:
	Net.peer_left.connect(_peer_left)
	tool = game.stage.spawn("glue",Vector3(12.5,0.05,7.6))
	var label := Label3D.new()
	label.text = "接着剤"
	label.font = game.font
	label.font_size = 48
	label.pixel_size = 0.0015
	label.position = tool.center + Vector3(0,0,tool.half.z+0.012)
	tool.add_child(label)

func handle_input(event: InputEvent) -> bool:
	var me: Node = game.local_player()
	if me == null or game.ui_blocking() or me.held != tool.pid: return false
	if event.is_action_pressed("operate"):
		applying = not applying
		game.hud.show_toast("左クリックで物の表面に接着点を2つ付ける。物を動かして点同士を合わせる" if applying else "接着剤を持っている：Fで塗る／左クリックで置く",game.Hud.YELLOW)
		return true
	if not applying or not event is InputEventMouseButton or not event.pressed: return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		h_mark.rpc_id(1,me.cam.global_position,-me.cam.global_basis.z)
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		h_cancel.rpc_id(1)
		return true
	return false

func hint() -> String:
	if applying:
		return "接着剤：左クリック 表面に点を付ける（2点で1組） ／ 右クリック 最初の点を取消 ／ F 終了。点同士を近づけると接着"
	return "接着剤：F で塗る ／ 左クリックで置く"

func _physics_process(_delta: float) -> void:
	var me: Node = game.local_player()
	if me == null or me.held != tool.pid or game.ui_blocking(): applying = false
	if not Net.is_host() or game.replaying: return
	var changed := false
	for pair: Dictionary in pairs:
		if pair.joined: continue
		var a: Node3D = game.props.get(pair.a)
		var b: Node3D = game.props.get(pair.b)
		if a == null or b == null or a.absent or b.absent: continue
		var pa: Vector3 = a.to_global(pair.pa)
		var pb: Vector3 = b.to_global(pair.pb)
		if pa.distance_to(pb)>TOUCH: continue
		pair.joined = true
		changed = true
	if changed:
		rx_state.rpc(snapshot())
		game.host_ev("toast",["接着した！ 重りや台車と一緒に動く",0])

func allowed(who: int) -> bool:
	return tool.holder == who and not game.replaying and not game.input_locked and game.state in [game.S.PREP,game.S.COUNTDOWN,game.S.TAKE]

@rpc("any_peer","call_local","reliable")
func h_mark(origin: Vector3, direction: Vector3) -> void:
	var who := Net.sender()
	if not Net.is_host() or not allowed(who) or not origin.is_finite() or not direction.is_finite() or direction.length()<0.5: return
	var player: Node3D = game.players.get(who)
	if player == null or origin.distance_to(player.global_position)>8: return
	var q := PhysicsRayQueryParameters3D.create(origin,origin+direction.normalized()*9,1|2|4|16)
	q.exclude = [tool.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.collider is RigidBody3D or not "pid" in hit.collider: return
	var prop: Node3D = hit.collider
	if prop.absent or prop.kind == "mark" or hit.position.distance_to(player.global_position+Vector3.UP)>player.REACH: return
	if "operator" in prop and prop.operator != 0: return
	mark(who,prop.pid,prop.to_local(hit.position))

func mark(who: int, pid: int, point: Vector3) -> void:
	if first.has(who):
		var old: Array = first[who]
		if old[0] == pid:
			game.ev.rpc_id(who,"toast",["2つ目の点は別の物に付けよう",0])
			return
		pairs.append({"a":old[0],"b":pid,"pa":old[1],"pb":point,"joined":false})
		first.erase(who)
		game.ev.rpc_id(who,"toast",["2点を付けた。接着剤を置いて物を動かし、黄色の点同士を合わせよう",0])
	else:
		first[who] = [pid,point]
		game.ev.rpc_id(who,"toast",["1点目を付けた。別の物の表面に2点目を付けよう",0])
	rx_state.rpc(snapshot())

@rpc("any_peer","call_local","reliable")
func h_cancel() -> void:
	if not Net.is_host() or not allowed(Net.sender()): return
	first.erase(Net.sender())
	rx_state.rpc(snapshot())

func snapshot() -> Dictionary:
	return {"first":first.duplicate(true),"pairs":pairs.duplicate(true)}

@rpc("authority","call_local","reliable")
func rx_state(data: Dictionary) -> void:
	restore(data,false)

@rpc("authority","call_remote","reliable")
func rx_snapshot(data: Dictionary) -> void:
	restore(data,false)

@rpc("authority","call_remote","reliable")
func rx_recorded(data: Dictionary) -> void:
	show_recorded(data)

func restore(data: Dictionary, broadcast := true) -> void:
	first = data.get("first",{}).duplicate(true)
	pairs = data.get("pairs",[]).duplicate(true)
	rebuild()
	show_recorded(snapshot())
	if broadcast and Net.is_host() and Net.has_peers(): rx_snapshot.rpc(snapshot())

func drop_joints() -> void:
	for joint: Node in joints.values():
		remove_child(joint)
		joint.queue_free()
	joints.clear()

func rebuild() -> void:
	drop_joints()
	if not Net.is_host() or game.replaying: return
	for i in pairs.size():
		var pair: Dictionary = pairs[i]
		if not pair.joined: continue
		var a: Node3D = game.props.get(pair.a)
		var b: Node3D = game.props.get(pair.b)
		if a == null or b == null or a.absent or b.absent: continue
		var joint := Generic6DOFJoint3D.new()
		add_child(joint)
		joint.global_position = a.to_global(pair.pa)
		joint.node_a = joint.get_path_to(a)
		joint.node_b = joint.get_path_to(b)
		# Store both selected local anchors, even when their surfaces are slightly apart.
		# The solver brings the dots together; adding a bond never teleports a held body.
		PhysicsServer3D.joint_make_generic_6dof(joint.get_rid(),a.get_rid(),Transform3D(a.global_basis.inverse(),pair.pa),b.get_rid(),Transform3D(b.global_basis.inverse(),pair.pb))
		for axis: String in ["x","y","z"]:
			joint.call("set_flag_"+axis,Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT,true)
			joint.call("set_flag_"+axis,Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT,true)
			joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT,0.0)
			joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT,0.0)
			joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,0.0)
			joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,0.0)
		joints[i] = joint
		a.sleeping = false
		b.sleeping = false

func show_recorded(data: Dictionary) -> void:
	if data == _shown: return
	_shown = data.duplicate(true)
	if Net.is_host() and game.replaying and Net.has_peers(): rx_recorded.rpc(data)
	for marker: Node3D in markers:
		marker.get_parent().remove_child(marker)
		marker.queue_free()
	markers.clear()
	for dot: Array in data.get("first",{}).values(): _dot(dot[0],dot[1],Color.YELLOW)
	for pair: Dictionary in data.get("pairs",[]):
		var color := Color(0.3,1.0,0.45) if pair.joined else Color.YELLOW
		_dot(pair.a,pair.pa,color)
		_dot(pair.b,pair.pb,color)

func _dot(pid: int, point: Vector3, color: Color) -> void:
	var prop: Node3D = game.props.get(pid)
	if prop == null: return
	var dot := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 12
	mesh.rings = 6
	dot.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.7
	dot.material_override = mat
	prop.add_child(dot)
	dot.position = point
	markers.append(dot)

func clear() -> void:
	applying = false
	if Net.is_host(): rx_state.rpc({})

func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id(): rx_state.rpc_id(who,snapshot())

func connected_to(pid: int, carrier: int) -> bool:
	if pid == carrier: return false
	var todo: Array = [pid]
	var seen := {}
	while not todo.is_empty():
		var id: int = todo.pop_back()
		if seen.has(id): continue
		seen[id] = true
		for pair: Dictionary in pairs:
			if not pair.joined: continue
			var other: int = pair.b if pair.a == id else (pair.a if pair.b == id else 0)
			if other == carrier: return true
			if other != 0: todo.append(other)
	return false

func _peer_left(who: int) -> void:
	if Net.is_host() and first.has(who):
		first.erase(who)
		rx_state.rpc(snapshot())
