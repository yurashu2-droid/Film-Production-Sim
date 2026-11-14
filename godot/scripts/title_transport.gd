extends Node3D
# ホーム奥の搬送係。物理や本編の小道具には触れず、同じ一組を画面外で戻す。
const CastVisual := preload("res://scripts/cast_visual.gd")
const PoseAim := preload("res://scripts/pose_aim.gd")
const SPEED := 1.25
const RAMP := 0.6
const FIRST_DISTANCE := 9.5
const SECOND_DISTANCE := 9.5
const FIRST_TIME := FIRST_DISTANCE / SPEED + RAMP * 0.5
const SECOND_TIME := SECOND_DISTANCE / SPEED + RAMP * 0.5
const STUCK_TIME := 0.85
const PASS_TIME := FIRST_TIME + STUCK_TIME + SECOND_TIME
const REST_TIME := 9.0

var elapsed := -2.0
var _staff: Node3D
var _cargo: Node3D
var _wheels: Array[Node3D] = []

func setup() -> void:
	name = "BackgroundTransport"
	position = Vector3(-8.5, 0, -2.1)
	rotation.y = PI * 0.5
	var cart := (load("res://assets/production/lift_cart.glb") as PackedScene).instantiate() as Node3D
	cart.scale = Vector3.ONE * 1.1
	cart.rotation.y = -PI * 0.5
	add_child(cart)
	# 昇降は使わず、低い荷台のまま運ぶ。車輪だけ移動距離に合わせて回す。
	for node: Node in cart.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop()
	for node: Node in cart.find_children("*", "Node3D", true, false):
		if node.name.begins_with("FIXED_WHEEL_") or node.name.begins_with("SWIVEL_WHEEL_"):
			_wheels.append(node as Node3D)
	_cargo = Node3D.new()
	_cargo.position.y = 0.49
	# 大きな尾が、踏ん張ったスタッフの顔にかぶらない距離を取る。
	_cargo.position.z = 0.55
	add_child(_cargo)
	var duck := (load("res://assets/title/P049_rubber_duck_refined.glb") as PackedScene).instantiate() as Node3D
	_cargo.add_child(duck)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in duck.find_children("*", "MeshInstance3D", true, false):
		var box := duck.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var scale_factor := 2.5 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	duck.scale = Vector3.ONE * scale_factor
	duck.position = -(bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)) * scale_factor
	# 少しこちらへ顔を向け、横切るアヒルだと分かるシルエットにする。
	_cargo.rotation.y = -0.2
	_staff = CastVisual.new()
	add_child(_staff)
	_staff.setup("01")
	_staff.scale = Vector3.ONE * 0.85
	_staff.position.z = -1.15
	# 体を少しこちらへ向ける。横の補正で両手の中心は取っ手に残す。
	_staff.rotation.y = -0.45
	_staff.position.x = 0.18
	var pose := PoseAim.new()
	_staff.skel.add_child(pose)
	for side: String in ["L", "R"]:
		var sign_x := 1.0 if side == "L" else -1.0
		pose.set_aim("UPPER_ARM." + side, Vector3(sign_x * 0.25, 0.30, 0.92))
		pose.set_aim("FOREARM." + side, Vector3(-sign_x * 0.10, 0.45, 0.89))
		pose.set_aim("HAND." + side, Vector3(0, 0, 1))
	_update()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= PASS_TIME + REST_TIME:
		elapsed = fmod(elapsed, PASS_TIME + REST_TIME)
	_update()

# ための間だけ歩行を止め、再び踏み出した分だけ台車も加速する。
func _distance(time: float) -> float:
	return SPEED * (time * time / (2.0 * RAMP) if time < RAMP else time - RAMP * 0.5)

func _update() -> void:
	visible = elapsed >= 0.0 and elapsed < PASS_TIME
	if not visible:
		_staff.anim.speed_scale = 0.0
		return
	var distance := 0.0
	var speed := 0.0
	var effort := 0.0
	if elapsed < FIRST_TIME:
		distance = _distance(elapsed)
		speed = SPEED * minf(elapsed / RAMP, 1.0)
	elif elapsed < FIRST_TIME + STUCK_TIME:
		distance = FIRST_DISTANCE
		effort = sin((elapsed - FIRST_TIME) / STUCK_TIME * PI)
	else:
		var restart := elapsed - FIRST_TIME - STUCK_TIME
		distance = FIRST_DISTANCE + _distance(restart)
		speed = SPEED * minf(restart / RAMP, 1.0)
	position.x = -8.5 + distance
	_staff.play("walk" if speed > 0.02 else "idle", 0.18)
	_staff.anim.speed_scale = speed / SPEED * 0.95 if speed > 0.02 else 1.0
	_staff.rotation.x = 0.06 + effort * 0.07
	_staff.set_face("angry" if effort > 0.1 else "neutral")
	# 進み始めの慣性と、小さな車輪の揺れ。止まると荷物も落ち着く。
	var roll := sin(distance * 6.0) * 0.018 * speed / SPEED
	_cargo.rotation.z = roll + effort * 0.035
	_cargo.rotation.x = (1.0 - speed / SPEED) * -0.035
	for wheel: Node3D in _wheels:
		wheel.rotation.z = -distance / 0.13
