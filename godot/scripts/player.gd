extends CharacterBody3D
# 制作班のメンバー。自分の移動は各自の手元で動かし、位置だけ他の参加者へ送る。
# 物を持つ・固定する・機材を操作する、はホストへの依頼として game 経由で出す。

const CastVisual := preload("res://scripts/cast_visual.gd")

const WALK := 3.4
const RUN := 5.8
const JUMP := 5.8
const GRAVITY := 16.0
const REACH := 3.8
const MOUSE_SENS := 0.0026

var game: Node
var peer_id := 1
var is_local := false
var aim_yaw := 0.0
var aim_pitch := -0.25
var hold_dist := 1.6
var hold_yaw := 0.0
var hold_pitch := 0.0
var held := 0           # 持っている物のID
var operating := 0      # 操作中の機材のID
var target: Node3D      # 照準が合っている物

var vis: Node3D
var head: Node3D
var arm: SpringArm3D
var cam: Camera3D

var _net: Array = []
var _send_t := 0.0
var _face_t := 0.0
var _motion := ""
var _motion_t := 0.0
var _run_requested := false
var _run_start_elapsed := 0.0
var _run_entry_speed := 0.0
var _ground_y := 0.0
var _dash_dust_pending := false
var _dust_contacts: Array[bool] = [true, true]
var _wheel_dust_distance := 0.0


func setup(cast_tag: String) -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.25
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.5
	cs.shape = cap
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	vis = CastVisual.new()
	add_child(vis)
	vis.setup(cast_tag)
	head = Node3D.new()
	head.position = Vector3(0, 1.85, 0)
	add_child(head)
	if is_local:
		arm = SpringArm3D.new()
		arm.spring_length = 4.0
		arm.margin = 0.2
		arm.collision_mask = 1
		arm.position = Vector3(0.9, 0.1, 0)
		head.add_child(arm)
		cam = Camera3D.new()
		cam.fov = 68.0
		cam.near = 0.1
		arm.add_child(cam)
		cam.current = true
		var al := AudioListener3D.new()
		cam.add_child(al)
		al.make_current()


func set_cast(cast_tag: String) -> void:
	if vis.tag == cast_tag:
		return
	var yaw: float = vis.rotation.y
	var animation: String = vis.current
	var face: String = vis.face
	remove_child(vis)
	vis.queue_free()
	vis = CastVisual.new()
	add_child(vis)
	vis.setup(cast_tag)
	vis.rotation.y = yaw
	vis.play(animation)
	vis.set_face(face)


func aim_forward() -> Vector3:
	return Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)) * Vector3.FORWARD


func flat_forward() -> Vector3:
	return Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))


func knock(impulse: Vector3) -> void:
	if is_local and operating == 0:
		velocity += impulse
		vis.set_face("shock")
		_face_t = 1.6


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or game.ui_blocking():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		if held != 0 and operating == 0 and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
			hold_yaw = wrapf(hold_yaw - rel.x * MOUSE_SENS * 2.0, -PI, PI)
			var prop: Node = game.props.get(held)
			if prop and not prop.axis_lock_angular_x:
				hold_pitch = clampf(hold_pitch - rel.y * MOUSE_SENS * 2.0, -PI * 0.48, PI * 0.48)
		elif operating != 0:
			game.act_aim(operating, -rel.x * MOUSE_SENS * 0.6, -rel.y * MOUSE_SENS * 0.6, 0.0)
		else:
			aim_yaw = wrapf(aim_yaw - rel.x * MOUSE_SENS, -PI, PI)
			aim_pitch = clampf(aim_pitch - rel.y * MOUSE_SENS, -1.2, 1.0)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var wheel := 0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel = 1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel = -1
		if wheel != 0:
			if operating != 0:
				game.act_aim(operating, 0.0, 0.0, float(wheel))
			elif held != 0:
				hold_dist = clampf(hold_dist + wheel * 0.2, 1.6, 4.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and operating == 0:
			if held != 0:
				game.act_release()
			elif target:
				game.act_grab(target.pid)
	elif event.is_action_pressed("operate"):
		if operating != 0:
			game.act_operate(operating, false)
		elif held != 0 and game.props.has(held) and game.props[held].kind == "clapper":
			game.act_use()
		elif held != 0 and game.props.has(held) and game.props[held].kind == "carton":
			game.act_toggle_carton(held)
		elif target and target.kind == "carton" and held == 0:
			game.act_toggle_carton(target.pid)
		elif target and target.kind in ["camera", "spot"] and held == 0:
			game.act_operate(target.pid, true)
	elif event.is_action_pressed("fix"):
		if held != 0:
			game.act_fix(held)
		elif target:
			game.act_fix(target.pid)


func _physics_process(delta: float) -> void:
	if not is_local:
		_follow_net(delta)
		return
	if game.replaying:
		return
	var blocked: bool = game.ui_blocking()
	var iv := Vector2.ZERO
	if not blocked:
		iv = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var op: Node3D = game.props.get(operating) if operating != 0 else null
	var carried: Node = game.props.get(held)
	var pose := ""
	if carried:
		pose = "onehand_" if carried.kind in CastVisual.ONE_HAND_PROPS else "carry_"

	if op and op.kind == "camera":
		# カメラ操作中は台車のようにカメラごと動く。自分はカメラの後ろに付く
		var f: Vector3 = op.shoot_dir()
		f.y = 0.0
		f = f.normalized()
		var r := Vector3(-f.z, 0.0, f.x)
		game.act_dolly(operating, r * iv.x + f * iv.y)
		var back := 0.9
		var stand: Vector3 = op.global_position
		if op.rider_of != 0:
			back = maxf(1.35, game.props[op.rider_of].deck_half.y + 0.5) # 台車の後ろに立つ
			stand.y -= float(game.props[op.rider_of].deck_top)
		global_position = stand - f * back
		velocity = Vector3.ZERO
		vis.rotation.y = atan2(f.x, f.z)
		aim_yaw = atan2(-f.x, -f.z)
		_motion = ""
		_run_requested = false
		_ground_y = global_position.y
		vis.play(pose + "idle")
	else:
		if op:
			iv = Vector2.ZERO
		var ff := flat_forward()
		var right := Vector3(-ff.z, 0.0, ff.x)
		var dir := (right * iv.x + ff * iv.y).limit_length(1.0)
		var speed := _movement_speed(delta, dir, blocked)
		var k := clampf(delta * (12.0 if is_on_floor() else 3.0), 0.0, 1.0)
		velocity.x = lerpf(velocity.x, dir.x * speed, k)
		velocity.z = lerpf(velocity.z, dir.z * speed, k)
		if is_on_floor():
			if not blocked and op == null and Input.is_action_just_pressed("jump"):
				velocity.y = JUMP
		else:
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_push_light_props()
		if global_position.y < -20.0:
			game.recover_player(self)
		var face := dir
		if held != 0 or op:
			face = ff
		if face.length() > 0.1:
			vis.rotation.y = lerp_angle(vis.rotation.y, atan2(face.x, face.z), clampf(delta * 12.0, 0.0, 1.0))
		_animate_movement(delta, pose, dir, blocked)

	head.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
	if _face_t > 0.0:
		_face_t -= delta
		if _face_t <= 0.0:
			vis.set_face("neutral")
	if Input.is_action_pressed("rot_left") and held != 0 and not blocked:
		hold_yaw += delta * 2.2
	if Input.is_action_pressed("rot_right") and held != 0 and not blocked:
		hold_yaw -= delta * 2.2
	_find_target()

	_send_t -= delta
	if _send_t <= 0.0 and Net.has_peers():
		_send_t = 0.05
		game.send_player_state(global_position, vis.rotation.y, aim_yaw, aim_pitch, hold_dist, hold_yaw, hold_pitch, vis.current + "|" + vis.face)


# Keep movement responsive while matching the short anticipation / push-off clip.
func _movement_speed(delta: float, dir: Vector3, blocked: bool) -> float:
	var wants_run := dir.length() > 0.1 and Input.is_action_pressed("run") and held == 0 and operating == 0 and not blocked
	if not wants_run:
		_run_start_elapsed = 0.0
		return WALK
	var duration: float = vis.length("run_start")
	if not is_on_floor():
		_run_start_elapsed = duration
		return RUN
	if not _run_requested:
		_run_start_elapsed = 0.0
		_run_entry_speed = clampf(Vector2(velocity.x, velocity.z).length(), RUN * 0.15, RUN)
	_run_start_elapsed += delta
	# The existing velocity smoothing supplies the final part of acceleration.
	var push := smoothstep(duration * 0.2, duration * 0.7, _run_start_elapsed)
	return lerpf(_run_entry_speed, RUN, push)


func _start_motion(name: String) -> void:
	if not vis.has(name):
		return
	_motion = name
	_dash_dust_pending = name == "run_start"
	_motion_t = vis.length(name)
	vis.play(name, 0.06, true)


func _animate_movement(delta: float, pose: String, dir: Vector3, blocked: bool) -> void:
	var moving := dir.length() > 0.1
	var wants_run := moving and Input.is_action_pressed("run") and held == 0 and operating == 0 and not blocked
	var hs := Vector2(velocity.x, velocity.z).length()
	if not wants_run and _motion == "run_start":
		_motion = ""
	_motion_t -= delta
	if _motion_t <= 0.0 or not is_on_floor() or blocked or operating != 0:
		_motion = ""
	# 物を持ち始めたら腕の構えを優先する。離した後に持つ構えを残さない。
	if pose != "" and not _motion.begins_with(pose):
		_motion = ""
	if (pose != "carry_" and _motion.begins_with("carry_")) or (pose != "onehand_" and _motion.begins_with("onehand_")):
		_motion = ""
	if is_on_floor() and not blocked and operating == 0:
		if _ground_y - global_position.y > 0.18:
			_start_motion(pose + "step_down")
		elif wants_run and not _run_requested:
			_start_motion("run_start")
		elif not moving and _run_requested and hs > WALK * 0.65:
			_start_motion(pose + "run_stop")
	if is_on_floor():
		_ground_y = global_position.y
	if not wants_run or not is_on_floor() or _motion != "run_start":
		_dash_dust_pending = false
	elif _dash_dust_pending and _run_start_elapsed >= vis.length("run_start") * 0.2:
		_dash_dust_pending = false
		game.act_dash_dust()
	_run_requested = wants_run
	if not is_on_floor():
		vis.play(pose + "jump")
	elif _motion != "":
		vis.play(_motion, 0.06)
	elif hs > 4.4:
		vis.play(pose + "run")
	elif hs > 0.4:
		vis.play(pose + "walk")
	else:
		vis.play(pose + "idle")
	_update_running_dust(delta, wants_run and is_on_floor() and _motion == "" and hs > 4.4)


func _update_running_dust(delta: float, running: bool) -> void:
	if not running or game.dash_dust_style not in game.STEP_STYLES:
		_dust_contacts = [true, true]
		_wheel_dust_distance = 0.0
		return
	if vis.tag == "M02":
		# 車輪のキャラは足の代わりに移動距離で小さく巻き上げる。
		_wheel_dust_distance += Vector2(velocity.x, velocity.z).length() * delta
		if _wheel_dust_distance >= 1.3:
			_wheel_dust_distance -= 1.3
			game.act_dash_dust(0)
		return
	for i in 2:
		var height: float = vis.foot_position("L" if i == 0 else "R").y - global_position.y
		if height > 0.13:
			_dust_contacts[i] = false
		elif height < 0.065 and not _dust_contacts[i]:
			_dust_contacts[i] = true
			game.act_dash_dust(i)


# 軽い物は歩いて押しのけられる（物理はホストだけが持つので、今はホスト側のみ）
func _push_light_props() -> void:
	if not multiplayer.is_server():
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var b := c.get_collider() as RigidBody3D
		if b and b.mass <= 8.0 and not b.freeze and "pid" in b and b.pid != held:
			var n := -c.get_normal()
			n.y = 0.0
			b.apply_central_impulse(n * minf(b.mass, 3.0) * 0.6)


func _find_target() -> void:
	target = null
	if cam == null or operating != 0:
		return
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 9.0, 1 | 2 | 4 | 16)
	var ex: Array[RID] = []
	if held != 0 and game.props.has(held):
		ex.append((game.props[held] as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var c: Object = hit.collider
	if c is RigidBody3D and "pid" in c:
		var p: Vector3 = hit.position
		if p.distance_to(global_position + Vector3(0, 1.0, 0)) <= REACH:
			target = c


# ---- 他の参加者の画面での表示 ----

func apply_net(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	_net = [pos, body_yaw, anim_name.get_slice("|", 0)]
	vis.set_face(anim_name.get_slice("|", 1))
	aim_yaw = a_yaw
	aim_pitch = a_pitch
	hold_dist = h_dist
	hold_yaw = h_yaw
	hold_pitch = h_pitch


func _follow_net(delta: float) -> void:
	if _net.is_empty():
		return
	var w := clampf(delta * 14.0, 0.0, 1.0)
	global_position = global_position.lerp(_net[0] as Vector3, w)
	vis.rotation.y = lerp_angle(vis.rotation.y, _net[1] as float, w)
	vis.play(_net[2] as String, 0.12)


func get_state() -> Array:
	return [global_position, vis.rotation.y, vis.current, vis.face, vis.tag]


func apply_state(s: Array) -> void:
	if s.size() >= 5:
		set_cast(s[4] as String)
	_motion = ""
	_run_requested = false
	_ground_y = (s[0] as Vector3).y
	global_position = s[0]
	vis.rotation.y = s[1]
	vis.play(s[2] as String, 0.12)
	vis.set_face(s[3] as String)
