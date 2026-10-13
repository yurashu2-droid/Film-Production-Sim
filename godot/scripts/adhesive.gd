extends Node
## 接着剤。物の表面に付けた点どうしを、物理の「点留め」でつなぐ（計算するのはホストだけ）。
## 留めた点は離れないが、その点のまわりには自由に回る（支点）。点以外の所は、くっついていないのと同じで、ふつうにぶつかる。
## 1点だけなら、ぶら下がる・倒れる・回る。離れた所をもう1点留めると、2点を結ぶ線を軸にした蝶番になる。
## 一直線でない3点を留めると、ほぼ固まる。接着した時の向きへ戻そうとする力は無い。
const TOUCH := 0.12
const SEARCH := 0.18
## 留めた2つの物が、互いに回る勢いの弱まる速さ（毎秒）。回り続けて止まらないのを防ぐだけの弱い抵抗
const SWING_DAMP := 1.5
## これより遅い回り方（rad/秒）には抵抗をかけない。止まりかけの物を起こし続けないため
const SWING_REST := 0.05
## 3点目が、いちばん離れた2点を結ぶ線からこれ以上外れていれば「一直線でない」（固く留まっている）とみなす（m）
const RIGID_SPREAD := 0.05
const JOINED_TOAST := "接着した！ 留めた点を支点に回る。離れた所も留めると固まる"
var game: Node
var tool: RigidBody3D
var applying := false
var first := {} # peer -> [prop id, local surface point]
var pairs: Array = []
var joints := {}
var markers: Array[Node3D] = []
var _shown := {}
var _joint_specs := {}
var _preview := {}
var _preview_root: Node3D
var _preview_dots: Array[MeshInstance3D] = []
var _preview_line: ImmediateMesh
var _preview_time := 0.0

func _ready() -> void:
	# 物を持つ処理が先に動いてから、接着した物どうしの回る勢いを弱める
	process_physics_priority = 10

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
	if me == null or tool == null or game.ui_blocking() or me.held != tool.pid: return false
	# 接着剤を持っている間は、F を押すだけで塗る（塗るモードへの切り替えは無い）。
	# 左クリックは今までどおり「置く」。Shift+F は、付けた最初の点の取り消し
	if not event.is_action_pressed("operate"): return false
	if Input.is_key_pressed(KEY_SHIFT):
		h_cancel.rpc_id(1)
		_clear_preview()
		return true
	_update_preview(me)
	if _preview.get("ready",false):
		h_assisted_mark.rpc_id(1,me.cam.global_position,-me.cam.global_basis.z,_preview.a,_preview.b)
	else:
		h_mark.rpc_id(1,me.cam.global_position,-me.cam.global_basis.z)
	return true

func hint() -> String:
	if _preview.has("b") and (not _eligible(game.props.get(_preview.a)) or not _eligible(game.props.get(_preview.b))): _clear_preview()
	if _preview.get("ready",false):
		return "接着剤：%s ↔ %s　F で接着 ／ Shift+F 最初の点を取消 ／ 左クリックで置く" % [game.props[_preview.a].label,game.props[_preview.b].label]
	if _preview.get("count",0)>1:
		return "接着剤：相手が複数。F で1点目、次に接着したい物を狙って F ／ Shift+F 取消 ／ 左クリックで置く"
	if _preview.has("b"):
		return "接着剤：%s へもう少し近づける（接着は12cm以内） ／ F で2点を指定 ／ 左クリックで置く" % game.props[_preview.b].label
	return "接着剤：F 表面に点を付ける（2点で1組。点同士を近づけると接着） ／ Shift+F 最初の点を取消 ／ 左クリックで置く"

func _physics_process(delta: float) -> void:
	var me: Node = game.local_player()
	# 持っている間は、いつでも塗れる（相手の候補を出し続ける）
	applying = me != null and tool != null and me.held == tool.pid and not game.ui_blocking()
	if applying:
		_preview_time -= delta
		if _preview_time<=0.0:
			_preview_time = 0.1
			_update_preview(me)
	else: _clear_preview()
	if not Net.is_host() or game.replaying: return
	_calm_swing(delta)
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
		game.host_ev("toast",[JOINED_TOAST,0])

func allowed(who: int) -> bool:
	return tool != null and tool.holder == who and not game.replaying and not game.input_locked and game.state in [game.S.PREP,game.S.COUNTDOWN,game.S.TAKE]

@rpc("any_peer","call_local","reliable")
func h_mark(origin: Vector3, direction: Vector3) -> void:
	var who := Net.sender()
	if not Net.is_host() or not allowed(who): return
	var hit := _surface_hit(who,origin,direction)
	if hit.is_empty(): return
	mark(who,hit.collider.pid,hit.collider.to_local(hit.position))

func _surface_hit(who: int, origin: Vector3, direction: Vector3) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or direction.length()<0.5: return {}
	var player: Node3D = game.players.get(who)
	if player == null or origin.distance_to(player.global_position)>8: return {}
	var q := PhysicsRayQueryParameters3D.create(origin,origin+direction.normalized()*9,1|2|4|16)
	q.exclude = [tool.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not _eligible(hit.collider): return {}
	var prop: Node3D = hit.collider
	if hit.position.distance_to(player.global_position+Vector3.UP)>player.REACH: return {}
	return hit

func _eligible(prop: Object) -> bool:
	return prop is RigidBody3D and "pid" in prop and prop != tool and not prop.absent and prop.kind != "mark" and (not "operator" in prop or prop.operator == 0)

## local_point belongs to the explicitly selected source; no centre-distance guesses.
func nearby_candidates(pid: int, local_point: Vector3, only_pid := 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source: Node3D = game.props.get(pid)
	if source == null or not _eligible(source) or not local_point.is_finite(): return result
	var point := source.to_global(local_point)
	var sphere := SphereShape3D.new()
	sphere.radius = SEARCH
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY,point)
	query.collision_mask = 1|2|4|16
	query.exclude = [source.get_rid()]
	if tool != null: query.exclude = [source.get_rid(),tool.get_rid()]
	var space := source.get_world_3d().direct_space_state
	var hits := space.intersect_shape(query,64)
	# A capped crowded query must not masquerade as a unique candidate.
	if hits.size()==64: return result
	var candidates := {}
	for hit: Dictionary in hits:
		if not _eligible(hit.collider): continue
		if only_pid!=0 and hit.collider.pid!=only_pid: continue
		candidates[hit.collider.pid] = hit.collider
	for id: int in candidates:
		var target: Node3D = candidates[id]
		var exclusions: Array[RID] = [source.get_rid()]
		if tool != null: exclusions.append(tool.get_rid())
		for hit: Dictionary in hits:
			if hit.rid != target.get_rid(): exclusions.append(hit.rid)
		query.exclude = exclusions
		var info := space.get_rest_info(query)
		if info.is_empty() or info.rid!=target.get_rid(): continue
		var distance := point.distance_to(info.point)
		if distance>SEARCH: continue
		if distance>0.003:
			var direction: Vector3 = (info.point-point).normalized()
			var ray := PhysicsRayQueryParameters3D.create(point+direction*0.001,info.point+direction*0.003,1|2|4|16)
			ray.exclude = [source.get_rid()]
			if tool != null: ray.exclude = [source.get_rid(),tool.get_rid()]
			var obstruction := space.intersect_ray(ray)
			if not obstruction.is_empty() and obstruction.collider!=target: continue
		result.append({"a":pid,"b":id,"pa":local_point,"pb":target.to_local(info.point),"gap":distance})
	result.sort_custom(func(a,b): return a.b<b.b)
	return result

@rpc("any_peer","call_local","reliable")
func h_assisted_mark(origin: Vector3, direction: Vector3, expected_a: int, expected_b: int) -> void:
	var who := Net.sender()
	if not Net.is_host() or not allowed(who): return
	var hit := _surface_hit(who,origin,direction)
	if hit.is_empty(): return
	var choices: Array[Dictionary]
	if first.has(who):
		var old: Array = first[who]
		if old[0]!=expected_a or hit.collider.pid!=expected_b: return
		choices = nearby_candidates(old[0],old[1],expected_b)
	else:
		if hit.collider.pid!=expected_a: return
		choices = nearby_candidates(expected_a,hit.collider.to_local(hit.position))
	if choices.size()!=1 or choices[0].b!=expected_b or choices[0].gap>TOUCH:
		game.ev.rpc_id(who,"toast",["接着する相手が動いた。もう一度狙ってクリック",0])
		return
	var choice: Dictionary = choices[0]
	if _duplicate_contact(choice): return
	pairs.append({"a":choice.a,"b":choice.b,"pa":choice.pa,"pb":choice.pb,"joined":true})
	first.erase(who)
	rx_state.rpc(snapshot())
	game.host_ev("toast",[JOINED_TOAST,0])

func _duplicate_contact(choice: Dictionary) -> bool:
	for pair: Dictionary in pairs:
		if pair.a==choice.a and pair.b==choice.b and pair.pa.distance_to(choice.pa)<0.04 and pair.pb.distance_to(choice.pb)<0.04: return true
		if pair.a==choice.b and pair.b==choice.a and pair.pa.distance_to(choice.pb)<0.04 and pair.pb.distance_to(choice.pa)<0.04: return true
	return false

func _update_preview(me: Node) -> void:
	_preview.clear()
	var hit := _surface_hit(me.peer_id,me.cam.global_position,-me.cam.global_basis.z)
	if hit.is_empty():
		_clear_preview()
		return
	var choices: Array[Dictionary]
	if first.has(me.peer_id):
		var old: Array = first[me.peer_id]
		choices = nearby_candidates(old[0],old[1],hit.collider.pid)
	else:
		choices = nearby_candidates(hit.collider.pid,hit.collider.to_local(hit.position))
	_preview["count"] = choices.size()
	if choices.size()==1:
		_preview.merge(choices[0])
		_preview["ready"] = choices[0].gap<=TOUCH
		_show_preview(_preview)
	elif choices.size()>1:
		_show_preview(choices[0],false)
	else:
		if _preview_root != null: _preview_root.hide()

func _clear_preview() -> void:
	_preview.clear()
	_preview_time = 0.0
	if _preview_root != null: _preview_root.hide()

func _show_preview(choice: Dictionary, unambiguous := true) -> void:
	if _preview_root == null:
		_preview_root = Node3D.new()
		add_child(_preview_root)
		for i in 2:
			var dot := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.035
			mesh.height = 0.07
			mesh.radial_segments = 12
			mesh.rings = 6
			dot.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dot.material_override = mat
			_preview_root.add_child(dot)
			_preview_dots.append(dot)
		_preview_line = ImmediateMesh.new()
		var line := MeshInstance3D.new()
		line.mesh = _preview_line
		_preview_root.add_child(line)
	var color := Color(0.2,0.9,1.0) if unambiguous and choice.gap<=TOUCH else Color(1.0,0.65,0.15)
	var pa: Vector3 = game.props[choice.a].to_global(choice.pa)
	var pb: Vector3 = game.props[choice.b].to_global(choice.pb)
	_preview_dots[0].global_position = pa
	_preview_dots[1].global_position = pb
	for dot: MeshInstance3D in _preview_dots: dot.material_override.albedo_color = color
	_preview_line.clear_surfaces()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_preview_dots[1].visible = unambiguous
	if unambiguous:
		_preview_line.surface_begin(Mesh.PRIMITIVE_LINES,mat)
		_preview_line.surface_add_vertex(_preview_root.to_local(pa))
		_preview_line.surface_add_vertex(_preview_root.to_local(pb))
		_preview_line.surface_end()
	_preview_root.show()

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
	if broadcast: rebuild()
	else: _sync_joints()
	show_recorded(snapshot())
	if broadcast and Net.is_host() and Net.has_peers(): rx_snapshot.rpc(snapshot())

func drop_joints() -> void:
	for joint: Node in joints.values():
		remove_child(joint)
		joint.queue_free()
	joints.clear()
	_joint_specs.clear()

func rebuild() -> void:
	drop_joints()
	_sync_joints()

func _joint_spec(pair: Dictionary) -> Dictionary:
	return {"a":pair.a,"b":pair.b,"pa":pair.pa,"pb":pair.pb,"body_a":game.props[pair.a].get_rid(),"body_b":game.props[pair.b].get_rid()}

func _sync_joints() -> void:
	if not Net.is_host() or game.replaying:
		drop_joints()
		return
	var live := {}
	for i in pairs.size():
		var pair: Dictionary = pairs[i]
		var a: Node3D = game.props.get(pair.a)
		var b: Node3D = game.props.get(pair.b)
		if not pair.joined or a == null or b == null or a.absent or b.absent: continue
		live[i] = _joint_spec(pair)
	for i: int in joints.keys():
		if live.has(i) and _joint_specs.get(i) == live[i]: continue
		var joint: Node = joints[i]
		remove_child(joint)
		joint.queue_free()
		joints.erase(i)
		_joint_specs.erase(i)
	for i in pairs.size():
		if not live.has(i) or joints.has(i): continue
		var pair: Dictionary = pairs[i]
		var a: Node3D = game.props.get(pair.a)
		var b: Node3D = game.props.get(pair.b)
		# 点で留めるだけ。向きは縛らない。留めた2つの物も、点以外の所ではふつうにぶつかる
		var joint := PinJoint3D.new()
		joint.exclude_nodes_from_collision = false
		add_child(joint)
		joint.global_position = a.to_global(pair.pa)
		joint.node_a = joint.get_path_to(a)
		joint.node_b = joint.get_path_to(b)
		# 選んだ2点を、それぞれの物の上の位置のまま留める。表面が少し離れていても物を置き直さず、物理が点どうしを寄せる
		PhysicsServer3D.joint_make_pin(joint.get_rid(),a.get_rid(),pair.pa,b.get_rid(),pair.pb)
		joints[i] = joint
		_joint_specs[i] = live[i]
		a.sleeping = false
		b.sleeping = false

# 留めた2つの物が互いに回る勢いを、少しずつ弱める（回り続けて止まらないのを防ぐ）。
# 同じ大きさで逆向きの回す力を両方へ加えるだけ。点のまわりに回る自由も、重力でぶら下がる動きも残る
func _calm_swing(delta: float) -> void:
	if delta <= 0.0: return
	var fade := 1.0 - exp(-SWING_DAMP * delta)
	for index: int in joints:
		if index >= pairs.size(): continue
		var pair: Dictionary = pairs[index]
		var a: RigidBody3D = game.props.get(pair.a)
		var b: RigidBody3D = game.props.get(pair.b)
		if a == null or b == null or a.absent or b.absent: continue
		if (a.freeze or a.sleeping) and (b.freeze or b.sleeping): continue
		var state_a := PhysicsServer3D.body_get_direct_state(a.get_rid())
		var state_b := PhysicsServer3D.body_get_direct_state(b.get_rid())
		if state_a == null or state_b == null: continue
		var spin := state_b.angular_velocity - state_a.angular_velocity
		var speed := spin.length()
		if speed < SWING_REST: continue
		var axis := spin / speed
		var give := _turn_give(a,state_a,a.to_global(pair.pa),axis) + _turn_give(b,state_b,b.to_global(pair.pb),axis)
		if give < 0.000001: continue
		var impulse := axis * (fade * speed / give)
		if not a.freeze: a.apply_torque_impulse(impulse)
		if not b.freeze: b.apply_torque_impulse(-impulse)

# その物を、留めた点のまわりで axis の向きに回すときの回りやすさ（慣性の逆数）。固めてある物は回らないので 0。
# これで割ると、軽い物も重い物も、同じ速さで落ち着く
func _turn_give(body: RigidBody3D, state: PhysicsDirectBodyState3D, point: Vector3, axis: Vector3) -> float:
	if body.freeze: return 0.0
	var give := axis.dot(state.inverse_inertia_tensor * axis)
	if give < 0.000001: return 0.0
	var arm := point - state.transform.origin - state.center_of_mass
	return 1.0 / (1.0/give + body.mass * (arm - axis*arm.dot(axis)).length_squared())

## その物と、接着でつながっている物ぜんぶのID（その物も含む。同じIDは1回だけ。現場に無い物は数えない）。
## 1点だけの接着でも「つながっている」。固まっているかどうかは見ない
func connected_ids(pid: int) -> Array[int]:
	var result: Array[int] = []
	var todo: Array[int] = [pid]
	while not todo.is_empty():
		var id: int = todo.pop_back()
		var prop: Node = game.props.get(id)
		if id in result or prop == null or prop.absent: continue
		result.append(id)
		for pair: Dictionary in pairs:
			if not pair.joined: continue
			if pair.a == id: todo.append(pair.b)
			elif pair.b == id: todo.append(pair.a)
	return result

## その物と、固く留まっている物のID（その物も含む。同じIDは1回だけ。現場に無い物は数えない）。
## 固く＝同じ2つの物を、一直線でない3点以上で留めてある。持つ処理が、手でいっしょに動かす仲間を決めるのに使う。
## 1点・2点・一直線に並んだ点で留めただけの相手は入らない（留めた点からぶら下がる側）
func rigid_ids(pid: int) -> Array[int]:
	var result: Array[int] = []
	var todo: Array[int] = [pid]
	while not todo.is_empty():
		var id: int = todo.pop_back()
		var prop: Node = game.props.get(id)
		if id in result or prop == null or prop.absent: continue
		result.append(id)
		var spots := _spots_on(id)
		for other: int in spots:
			if _spread(spots[other]) >= RIGID_SPREAD: todo.append(other)
	return result

## 手で動かしている仲間（held）に、点で留まってぶら下がっている物のまとまり。
## 1つのまとまりは {"bodies":[ぶら下がっている物のID…], "points":[[仲間のID, 留めた点（その仲間から見た位置）]…]}。
## 固めてある物（車体など）につながっているまとまりは、ぶら下がっていないので返さない
func hanging_groups(held: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var taken := {}
	for id: int in held: taken[id] = true
	for member: int in held:
		for first: int in _spots_on(member):
			if taken.has(first): continue
			# first から、手で動かしている仲間を通らずにつながる物をぜんぶ集める
			var bodies: Array[int] = []
			var anchored := false
			var todo: Array[int] = [first]
			while not todo.is_empty():
				var id: int = todo.pop_back()
				if taken.has(id): continue
				taken[id] = true
				var prop: Node = game.props.get(id)
				if prop == null or prop.absent: continue
				bodies.append(id)
				anchored = anchored or prop.freeze
				for next: int in _spots_on(id): todo.append(next)
			if anchored or bodies.is_empty(): continue
			var points: Array = []
			for holder_id: int in held:
				var spots := _spots_on(holder_id)
				for other: int in spots:
					if not other in bodies: continue
					for spot: Vector3 in spots[other]: points.append([holder_id,spot])
			if not points.is_empty(): result.append({"bodies":bodies,"points":points})
	return result

# その物の上の留めた点を、相手ごとにまとめる（相手のID → その物から見た点の一覧）
func _spots_on(id: int) -> Dictionary:
	var spots := {}
	for pair: Dictionary in pairs:
		if not pair.joined or not pair.has("pa"): continue
		var other := 0
		var spot := Vector3.ZERO
		if pair.a == id:
			other = pair.b
			spot = pair.pa
		elif pair.b == id:
			other = pair.a
			spot = pair.pb
		else: continue
		if not spots.has(other): spots[other] = []
		(spots[other] as Array).append(spot)
	return spots

# 点の広がり：いちばん離れた2点を結ぶ線から、ほかの点がどれだけ外れているか（2点以下や一直線なら 0）
func _spread(list: Array) -> float:
	if list.size() < 3: return 0.0
	var a: Vector3 = list[0]
	var b: Vector3 = list[1]
	var far := 0.0
	for i in list.size():
		for j in range(i+1,list.size()):
			var d: float = (list[i] as Vector3).distance_to(list[j])
			if d > far:
				far = d
				a = list[i]
				b = list[j]
	if far < 0.001: return 0.0
	var axis := (b-a)/far
	var off := 0.0
	for point: Vector3 in list:
		var r := point-a
		off = maxf(off,(r-axis*r.dot(axis)).length())
	return off

## 留めてある組ごとの、2つの点の離れぐあい（gap、m）。物理が点を寄せきれているかを確かめるのに使う。
## 接着した時の向きは覚えていないので、どれだけ回ったかは返さない
func bond_metrics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pair: Dictionary in pairs:
		if not pair.joined: continue
		var a: Node3D = game.props.get(pair.a)
		var b: Node3D = game.props.get(pair.b)
		if a == null or b == null or a.absent or b.absent: continue
		result.append({"a":pair.a,"b":pair.b,"gap":a.to_global(pair.pa).distance_to(b.to_global(pair.pb))})
	return result

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

# 片づけた物（借りるのをやめた物）に付いていた接着だけを外す（ホスト）。ほかの接着は、そのまま残す
func forget(pids: Array) -> void:
	if not Net.is_host() or pids.is_empty(): return
	var kept: Array = pairs.filter(func(pair: Dictionary) -> bool: return pair.a not in pids and pair.b not in pids)
	var marks: Dictionary = first.duplicate(true)
	for who: int in first:
		if first[who][0] in pids: marks.erase(who)
	if kept.size() == pairs.size() and marks.size() == first.size(): return
	restore({"first":marks,"pairs":kept})

func clear() -> void:
	applying = false
	_clear_preview()
	if Net.is_host(): rx_state.rpc({})

func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id(): rx_state.rpc_id(who,snapshot())

func connected_to(pid: int, carrier: int) -> bool:
	if pid == carrier: return false
	return carrier in connected_ids(pid)

func _peer_left(who: int) -> void:
	if Net.is_host() and first.has(who):
		first.erase(who)
		rx_state.rpc(snapshot())
