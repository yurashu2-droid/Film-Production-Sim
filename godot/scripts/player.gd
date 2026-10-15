extends CharacterBody3D
# 制作班のメンバー。自分の移動は各自の手元で動かし、位置だけ他の参加者へ送る。
# 物を持つ・固定する・機材を操作する、はホストへの依頼として game 経由で出す。

const VehicleRide := preload("res://scripts/vehicle_ride.gd")

const CastVisual := preload("res://scripts/cast_visual.gd")
const FacePicker := preload("res://scripts/face_picker.gd")
const FirstPersonArms := preload("res://scripts/first_person_arms.gd")

const WALK := 3.4
const RUN := 5.8
const JUMP := 5.8
const GRAVITY := 16.0
const REACH := 3.8
const MOUSE_SENS := 0.0026
const SETTINGS_FILE := "user://settings.cfg"
# マウスの感度の倍率（一時メニューのつまみで変える。視点・持った物の回転・カメラの操作に掛かる）
static var sens_scale := 1.0


static func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_FILE) == OK:
		sens_scale = clampf(float(file.get_value("input", "mouse_sens", 1.0)), 0.2, 3.0)


static func set_sens(value: float) -> void:
	sens_scale = clampf(value, 0.2, 3.0)
	var file := ConfigFile.new()
	file.load(SETTINGS_FILE)
	file.set_value("input", "mouse_sens", sens_scale)
	file.save(SETTINGS_FILE)
# 三人称の視点：左右のずれは無し（照準の真下に自分のキャラが来る）。
# 頭の基準（高さ1.85）から、視線に対して上へ VIEW_RISE だけ離れた所を軸に、真後ろへ VIEW_BACK 下がる。
# 視線はいつも頭の基準から VIEW_RISE 離れた所を通るので、見下ろしてもキャラが照準の先を隠さない。
const VIEW_RISE := 0.5
const VIEW_BACK := 4.0
# 一人称のとき、自分の体だけを置く描画の層。自分の視点カメラはこの層を映さない（撮影カメラや他人の画面には映る）。
const SELF_LAYER := 1 << 12
const HEAD_Y := 1.85          # 頭の基準の高さ（視点の軸）

# 一人称で見ているか（F2 で切り替え。その回の間だけ覚えておく。保存はしない）
static var first_person := false

var game: Node
var peer_id := 1
var is_local := false
var aim_yaw := 0.0
var aim_pitch := -0.25
var hold_dist := 1.6
var hold_yaw := 0.0
var hold_pitch := 0.0
var hold_roll := 0.0
# 持った物を回している最中か（右クリックか Q/E を押している間）。回している間だけ、物に重力がかからず向きを保つ。
# 離すと、掴んだ点を支点に垂れる。マウスを捕まえて遊んでいるときだけ切り替える（それ以外は true のまま）
var hold_turning := true
# 力を抜いて持っているか（N で切り替え）。抜いている間は、掴んだ点を支点に物が垂れる。ふだんは抜かず、視点と同じ向きを保つ
var hold_limp := false
# 転がして運ぶ物（台車など）を、床から持ち上げているか。N で切り替える（降ろすと、床を転がす）
var hold_raise := false
var _limp_key := false
var hold_offset := Vector3.ZERO
var hold_revision := 0
var held := 0           # 持っている物のID
var operating := 0      # 操作中の機材のID
var target: Node3D      # 照準が合っている物
var target_hit := Vector3.ZERO

var vis: Node3D
var head: Node3D
var arm: SpringArm3D
var cam: Camera3D
var operator_cam: Camera3D
var face_picker: Node3D   # 表情えらび（F3）。自分の画面にだけ頭が並ぶ
var arms: Node3D          # 一人称で自分にだけ見える、手と腕の写し（左・右。first_person_arms.gd）
var _self_layer_t := 0.0
var _view_rise := VIEW_RISE
# 伸ばした首の高さ（m。ベレー帽の人の特技。cast_talent.gd が、全員の画面で決める）。
# この分だけ、視点（三人称でも一人称でも）と、物に手が届く基準が上がる。伸ばしている間は走れない
var neck := 0.0

var _vehicle_ride: RefCounted

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
var _performance := ""
var _performance_left := 0.0
var _performance_length := 0.0


func setup(cast_tag: String) -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.25
	# 小道具は足場にはなるが、その速度は体にもらわない（床・壁だけを「動く足場」として扱う）。
	# 足元の物が弾かれたり持ち上げられたりしても、乗っている人は放り投げられない。
	platform_floor_layers = 1
	platform_wall_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
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
	head.position = Vector3(0, HEAD_Y + neck, 0)
	add_child(head)
	if is_local:
		arm = SpringArm3D.new()
		arm.spring_length = VIEW_BACK
		arm.margin = 0.2
		arm.collision_mask = 1
		arm.position = Vector3(0, _view_rise, 0)
		head.add_child(arm)
		cam = Camera3D.new()
		cam.fov = 68.0
		cam.near = 0.1
		arm.add_child(cam)
		cam.current = true
		var al := AudioListener3D.new()
		cam.add_child(al)
		al.make_current()
		operator_cam = Camera3D.new()
		operator_cam.name = "CameraOperatorView"
		operator_cam.fov = 48.0
		operator_cam.near = 0.025
		# 一人称の手の写しは、カメラ操作の視点には映さない（体の全部が本体で映る）
		operator_cam.cull_mask = operator_cam.cull_mask & ~FirstPersonArms.LAYER
		add_child(operator_cam)
		face_picker = FacePicker.new()
		face_picker.name = "FacePicker"
		face_picker.player = self
		cam.add_child(face_picker)
		_apply_view()


func set_cast(cast_tag: String) -> void:
	if vis.tag == cast_tag:
		return
	cancel_performance()
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
	_apply_view()


# ---- 視点（三人称 ⇄ 一人称）----

# 一人称の目の高さ。キャラの頭の高さに合わせる（低すぎ・高すぎは丸める）
func eye_height() -> float:
	var y := 1.2
	var bone: int = vis.skel.find_bone("HEAD")
	if bone >= 0:
		y = (vis.skel.get_bone_global_rest(bone).origin.y + 0.3) * CastVisual.SCALE
	return clampf(y, 1.2, 1.75)


func set_neck(rise: float) -> void:
	neck = rise
	if head != null:
		head.position.y = HEAD_Y + rise


# 物に手が届くかを測る基準（足元。首を伸ばしていれば、その分だけ高い）
func reach_base() -> Vector3:
	return global_position + Vector3(0, neck, 0)


func set_first_person(on: bool) -> void:
	first_person = on
	_apply_view()


func _apply_view() -> void:
	if not is_local or cam == null:
		return
	arm.spring_length = 0.0 if first_person else VIEW_BACK
	# 帽子の羽根などで背の高いキャラは、てっぺんが照準にかからない所まで視点を上げる
	var top := 0.0
	for mesh: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			top = maxf(top, mesh.get_aabb().end.y * CastVisual.SCALE)
	_view_rise = clampf(top + 0.2 - HEAD_Y, VIEW_RISE, 1.1)
	cam.cull_mask = (cam.cull_mask & ~SELF_LAYER) if first_person else (cam.cull_mask | SELF_LAYER)
	_apply_self_layer()
	_apply_arms()
	_place_view()


# 一人称の間、自分の体を自分の視点から外す。ふつうの層（1）にある物だけを移すので、
# 制作班だけに見せる表示などは、そのままの層に残る。
func _apply_self_layer() -> void:
	for mesh: GeometryInstance3D in vis.find_children("*", "GeometryInstance3D", true, false):
		if first_person and mesh.layers == 1:
			mesh.layers = SELF_LAYER
		elif not first_person and mesh.layers == SELF_LAYER:
			mesh.layers = 1


# 一人称の間だけ、自分の手と腕の写しを出す。キャラを替えたら作り直す。
# 写しは本体と同じ骨で動くので、腕の動きは本体と同じ。置き場所だけ、視点に合わせてずらす（_process）
func _apply_arms() -> void:
	if first_person and (not is_instance_valid(arms) or not vis.is_ancestor_of(arms)):
		arms = FirstPersonArms.build(vis)
	_show_arms()


# 自分の視点カメラで見ている間だけ映す（カメラ操作・移動の場面など、ほかのカメラの間は隠す）
func _show_arms() -> void:
	if is_instance_valid(arms):
		arms.visible = first_person and cam != null and cam.current


func _place_view() -> void:
	if arm == null:
		return
	if first_person:
		# 頭の基準は上下にも向くので、その分を打ち消して、目の高さにまっすぐ置く
		arm.position = head.basis.inverse() * Vector3(0, eye_height() - HEAD_Y, 0)
	else:
		arm.position = Vector3(0, _view_rise, 0)


func board_vehicle(truck: Node3D, seat_index: int) -> void:
	if _vehicle_ride == null:
		_vehicle_ride = VehicleRide.new()
	_vehicle_ride.enter(self, truck, seat_index)

func leave_vehicle() -> void:
	if _vehicle_ride != null:
		_vehicle_ride.leave(self)

func vehicle_riding() -> bool:
	return _vehicle_ride != null and _vehicle_ride.vehicle != null

func aim_forward() -> Vector3:
	return Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)) * Vector3.FORWARD


func flat_forward() -> Vector3:
	return Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))


func knock(impulse: Vector3) -> void:
	if is_local and operating == 0:
		velocity += impulse
		vis.set_face("shock")
		_face_t = 1.6


func _input(event: InputEvent) -> void:
	if is_local and face_picker != null and face_picker.handle_key(event):
		get_viewport().set_input_as_handled()
		return
	if not is_local or game.ui_blocking() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# 捕捉中のマウスはプレイ操作。照準や HUD が先に入力を吸わないようにする。
	# 中クリックは制作モードの目印操作へ渡す。
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		_handle_gameplay_input(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_local and event is InputEventKey and not event.echo and _handle_view_keys(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	_handle_gameplay_input(event)


# F2：三人称 ⇄ 一人称 ／ F3：押している間、表情の頭が並ぶ。離すと決まる
func _handle_view_keys(key: InputEventKey) -> bool:
	if key.physical_keycode == KEY_F2:
		if key.pressed:
			set_first_person(not first_person)
		return true
	if key.physical_keycode == KEY_F3 and face_picker != null:
		if key.pressed:
			face_picker.open()
		else:
			face_picker.close(true)
		return true
	return false


func _handle_gameplay_input(event: InputEvent) -> void:
	if not is_local or game.ui_blocking():
		return
	if game.adhesive != null and game.adhesive.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	# 表情えらびを開いている間、マウスは頭を選ぶのに使う（歩くのはそのまま）
	if face_picker != null and face_picker.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		if held != 0 and operating == 0 and not game.adhesive.applying and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
			# キーを減らした（2026-10-14）：Shift の微調整と、Alt+右ドラッグの位置ずらしは外した
			# （速さは感度のつまみで、位置は視点とホイールで合わせる）
			var fine := 1.0
			var prop: Node = game.props.get(held)
			if true:
				# 画面で見たままに回す：横に動かすと上向きの軸まわり、縦に動かすと画面の横軸まわり
				# （手前の面が、マウスを動かした向きへ動く）。倒れないようにしてある物は、横だけ
				if prop and not prop.axis_lock_angular_x:
					spin_hold(Vector3.RIGHT, rel.y * MOUSE_SENS * sens_scale * 2.0 * fine)
				spin_hold(Vector3.UP, rel.x * MOUSE_SENS * sens_scale * 2.0 * fine)
		elif operating != 0:
			game.act_aim(operating, -rel.x * MOUSE_SENS * sens_scale * 0.6, -rel.y * MOUSE_SENS * sens_scale * 0.6, 0.0)
		else:
			aim_yaw = wrapf(aim_yaw - rel.x * MOUSE_SENS * sens_scale, -PI, PI)
			aim_pitch = clampf(aim_pitch - rel.y * MOUSE_SENS * sens_scale, -1.2, 1.0)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and held == 0 and operating == 0 and game.world_click():
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and game.has_method("open_monitor") and game.open_monitor():
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
				# ホイールは奥行きだけ（高さは、見上げる・見下ろすで変わる）
				hold_dist = clampf(hold_dist + wheel * 0.2, 0.0, 5.4)
		elif mb.button_index == MOUSE_BUTTON_LEFT and operating != 0:
			if game.has_method("operator_click"):
				game.operator_click()
		elif mb.button_index == MOUSE_BUTTON_LEFT and operating == 0:
			if held != 0:
				game.act_release()
			else:
				_find_target()
				if target:
					game.act_grab(target.pid, target.to_local(target_hit))
	elif held != 0 and operating == 0 and event is InputEventKey and not event.echo:
		if event.is_action_pressed("hold_upright"):
			game.act_hold_command("upright")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hold_pull"):
			game.act_hold_command("pull")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("operate"):
			_handle_operate()
	elif event.is_action_pressed("operate"):
		_handle_operate()


func _handle_operate() -> void:
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


func _can_jump_from_floor() -> bool:
	if not is_on_floor():
		return false
	if held == 0:
		return true
	# 物を持っていても、ふつうの床や他の物の上からは跳べる。
	# 跳べないのは、自分で持っている物（と、それに接着した物）を足場にしているときだけ。
	# そこから跳べると、持ち上げた物に乗って跳び、また足元へ引き寄せて…と、どこまでも登れてしまう。
	return not _standing_on_held()


# 自分で持っている物か、それに接着でつながった物か
func _own_support(body: Object) -> bool:
	if body == null or not "pid" in body:
		return false
	return body.pid == held or (game.adhesive != null and game.adhesive.connected_to(held, body.pid))


# いま、自分で持っている物（接着先も含む）の上に立っているか
func _standing_on_held() -> bool:
	# 直前の移動で実際に踏んだ床。接地の状態は前回の move_and_slide の結果なので、
	# 持ち物との衝突を外した直後でも、ここには踏んでいた記録が残っている
	var floor_cos := cos(floor_max_angle)
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		for j in contact.get_collision_count():
			if contact.get_normal(j).dot(up_direction) >= floor_cos and _own_support(contact.get_collider(j)):
				return true
	# 平らな床に立っている・歩いている間は、踏んだ記録が残らない。足の真下と、足のふち4か所を下へ調べる
	var space := get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.22, 0, 0), Vector3(-0.22, 0, 0), Vector3(0, 0, 0.22), Vector3(0, 0, -0.22)]:
		var feet := global_position + offset
		var ray := PhysicsRayQueryParameters3D.create(feet + up_direction * 0.12, feet - up_direction * 0.32, 1 | 2 | 4)
		ray.exclude = [get_rid()]
		ray.hit_from_inside = true
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			continue
		# 足元へ持ち込んだ物の内側（法線ゼロ）や側面は、足場ではない
		if (hit.normal as Vector3).dot(up_direction) < floor_cos or (hit.position as Vector3).y > global_position.y + 0.03:
			continue
		if _own_support(hit.collider):
			return true
	return false


func _physics_process(delta: float) -> void:
	if vehicle_riding():
		_vehicle_ride.update(self)
		return
	if not is_local:
		_follow_net(delta)
		return
	if game.replaying and not game.audience:
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
	# ロープをつかんでいる間（rope_grab.gd）：片手で持つ構えで、体は視線の向き
	var roping: bool = game.get("rope_grab") != null and game.rope_grab.holding(peer_id)
	if roping and pose == "":
		pose = "onehand_"

	if op and op.kind == "camera":
		# 撮影係の身体はその場に保つ。視点だけを機材へ寄せる。
		velocity = Vector3.ZERO
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
			if not blocked and op == null and Input.is_action_just_pressed("jump") and _can_jump_from_floor():
				velocity.y = JUMP
		else:
			velocity.y -= GRAVITY * delta
		game.update_hold_collision(self)
		move_and_slide()
		_push_light_props()
		if global_position.y < -20.0:
			game.recover_player(self)
		var face := dir
		if held != 0 or op or roping:
			face = ff
		if face.length() > 0.1:
			vis.rotation.y = lerp_angle(vis.rotation.y, atan2(face.x, face.z), clampf(delta * 12.0, 0.0, 1.0))
		_animate_movement(delta, pose, dir, blocked)

	head.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
	_place_view()
	if first_person:
		# 頭にしまった小物など、あとから体に付いた物も自分の視点から外す
		_self_layer_t -= delta
		if _self_layer_t <= 0.0:
			_self_layer_t = 0.5
			_apply_self_layer()
			if is_instance_valid(arms):
				FirstPersonArms.match_look(arms)
	if _face_t > 0.0:
		_face_t -= delta
		if _face_t <= 0.0:
			vis.set_face("neutral")
	if is_local and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# N：力を抜く・入れるの切り替え。物を持ち直すと、力を入れた状態に戻る
		var limp_key: bool = Input.is_physical_key_pressed(KEY_N) and not game.ui_blocking()
		if limp_key and not _limp_key and held != 0:
			hold_limp = not hold_limp
			var rolling: bool = game.props.has(held) and game.props[held].rolls
			if rolling:
				game.hud.show_toast("床から離した（自由に動かせる）。もう一度 N で床を転がす" if hold_limp else "床を転がす", game.hud.YELLOW)
			else:
				game.hud.show_toast("力を抜いた（物が垂れる）。もう一度 N で、向きを保つ" if hold_limp else "力を入れた（向きを保つ）", game.hud.YELLOW)
		_limp_key = limp_key
		if held == 0:
			hold_limp = false
		# 転がして運ぶ物（台車など）は、N で持ち上げる・降ろす（力を抜く代わり）
		var raise: bool = held != 0 and hold_limp and game.props.has(held) and game.props[held].rolls
		if raise != hold_raise:
			hold_raise = raise
			game.send_hold_raise(raise)
		var turning: bool = held == 0 or not hold_limp or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("rot_left") or Input.is_action_pressed("rot_right")
		if turning != hold_turning:
			hold_turning = turning
			game.send_hold_turning(turning)
	# Q/E は傾けるだけ（視線の軸まわり。右ドラッグでは出しにくい向き）。横に回すのは右ドラッグ
	var can_tilt: bool = held != 0 and not blocked and game.props.has(held) and not game.props[held].axis_lock_angular_z
	if Input.is_action_pressed("rot_left") and can_tilt:
		spin_hold(Vector3.FORWARD, delta * 1.6)
	if Input.is_action_pressed("rot_right") and can_tilt:
		spin_hold(Vector3.FORWARD, -delta * 1.6)
	_find_target()

	_send_t -= delta
	if _send_t <= 0.0 and Net.has_peers():
		_send_t = 0.05
		game.send_player_state(global_position, vis.rotation.y, aim_yaw, aim_pitch, hold_dist, hold_yaw, hold_pitch, vis.current + "|" + vis.face)
		if held != 0:
			game.send_hold_controls(hold_dist, hold_yaw, hold_pitch, hold_offset, hold_roll, hold_revision)

func _process(delta: float) -> void:
	if is_local:
		# 視点は、描画のコマごとに向きを変える（物理のコマごとだけだと、速い画面では視点を振ったときにカクつく）
		if head != null:
			head.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
		_show_arms()
		if is_instance_valid(arms) and arms.visible:
			FirstPersonArms.place(arms, self, delta)
	if not is_local or operator_cam == null or vehicle_riding(): return
	var op: Node = game.props.get(operating)
	if not game.replaying and op != null and op.kind == "camera":
		operator_cam.global_transform = op.operation_view()
		operator_cam.make_current()
	elif operator_cam.current:
		cam.make_current()


# Keep movement responsive while matching the short anticipation / push-off clip.
func _movement_speed(delta: float, dir: Vector3, blocked: bool) -> float:
	if Input.is_action_pressed("crouch") and not blocked:
		_run_start_elapsed = 0.0
		return WALK * 0.5
	var wants_run := dir.length() > 0.1 and Input.is_action_pressed("run") and held == 0 and operating == 0 and not blocked and not Input.is_action_pressed("crouch") and neck <= 0.01
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
	var push := smoothstep(CastVisual.RUN_START_ANTICIPATION, CastVisual.RUN_START_ANTICIPATION + CastVisual.RUN_START_ACCELERATION, _run_start_elapsed)
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
	var crouching := Input.is_action_pressed("crouch") and not blocked
	var wants_run := moving and Input.is_action_pressed("run") and held == 0 and operating == 0 and not blocked and not crouching and neck <= 0.01
	if performance_active():
		_performance_left -= delta
		if moving or blocked or not is_on_floor() or operating != 0 or held != 0 or crouching or _performance_left <= 0.0:
			cancel_performance()
		else:
			vis.play(_performance,0.06)
			_run_requested = false
			_update_running_dust(delta,false)
			return
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
	elif _dash_dust_pending and _run_start_elapsed >= CastVisual.RUN_START_ANTICIPATION:
		_dash_dust_pending = false
		game.act_dash_dust()
	_run_requested = wants_run
	if not is_on_floor():
		vis.play(pose + "jump")
	elif crouching:
		vis.play(pose + ("crouch_walk" if moving else "crouch_idle"))
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


# 持っている物を、いまの向きからさらに回す。axis は視点から見た軸（RIGHT＝画面の横、UP＝上、FORWARD＝視線）。
# 回した結果は、今までどおり角度3つ（hold_pitch / hold_yaw / hold_roll）で持つ・送る
func spin_hold(axis: Vector3, angle: float) -> void:
	var spin := Basis(axis, angle) * Basis.from_euler(Vector3(hold_pitch, hold_yaw, hold_roll))
	var angles := spin.orthonormalized().get_euler()
	hold_pitch = angles.x
	hold_yaw = angles.y
	hold_roll = angles.z


func _find_target() -> void:
	target = null
	target_hit = Vector3.ZERO
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
		if p.distance_to(global_position + Vector3(0, 1.0 + neck, 0)) <= REACH:
			target = c
			target_hit = p


# ---- 他の参加者の画面での表示 ----

func apply_net(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	_net = [pos, body_yaw, anim_name.get_slice("|", 0)]
	vis.set_face(anim_name.get_slice("|", 1))
	aim_yaw = a_yaw
	aim_pitch = a_pitch
	# 保持中の操作は世代付きの専用パケットで受ける。
	if hold_revision == 0 or multiplayer.get_remote_sender_id() == 0:
		# 直接の状態復元は従来の呼び出しも使える。受信中の旧パケットは通さない。
		apply_hold_controls(h_dist, h_yaw, h_pitch, Vector3.ZERO, 0.0, hold_revision)


func apply_hold_controls(dist: float, yaw: float, pitch: float, offset: Vector3, roll: float, revision: int) -> void:
	if revision != hold_revision:
		return
	if not is_finite(dist) or not is_finite(yaw) or not is_finite(pitch) or not is_finite(roll) or not offset.is_finite():
		return
	hold_dist = clampf(dist, 0.0, 5.4)
	hold_yaw = wrapf(yaw, -PI, PI)
	hold_pitch = wrapf(pitch, -PI, PI)
	hold_roll = wrapf(roll, -PI, PI)
	hold_offset = offset.limit_length(REACH)


func _follow_net(delta: float) -> void:
	if _net.is_empty():
		return
	var w := clampf(delta * 14.0, 0.0, 1.0)
	global_position = global_position.lerp(_net[0] as Vector3, w)
	vis.rotation.y = lerp_angle(vis.rotation.y, _net[1] as float, w)
	if performance_active():
		_performance_left -= delta
		# 古い移動パケットが一つ届いても、演技開始を即座に上書きしない。
		if _performance_left <= 0.0 or (_performance_length-_performance_left > 0.15 and _net[2] != _performance):
			cancel_performance()
	vis.play(_performance if performance_active() else _net[2] as String, 0.12)

func performance_active() -> bool:
	return _performance != "" and _performance_left > 0.0

func start_performance(clip: String) -> void:
	if clip.begins_with("face:"):
		vis.set_face(clip.trim_prefix("face:"))
		_face_t = 4.0
		return
	if not vis.has(clip):
		return
	_motion = ""
	_dash_dust_pending = false
	_run_requested = false
	_performance = clip
	_performance_length = vis.length(clip)
	_performance_left = _performance_length
	vis.play(clip,0.08,true)

func cancel_performance() -> void:
	_performance = ""
	_performance_left = 0.0


func get_state() -> Array:
	return [global_position, vis.rotation.y, vis.current, vis.face, vis.tag]


func apply_state(s: Array) -> void:
	cancel_performance()
	if s.size() >= 5:
		set_cast(s[4] as String)
	_motion = ""
	_run_requested = false
	_ground_y = (s[0] as Vector3).y
	global_position = s[0]
	vis.rotation.y = s[1]
	vis.play(s[2] as String, 0.12)
	vis.set_face(s[3] as String)
