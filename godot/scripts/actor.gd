extends CharacterBody3D
# 合図で動く役者（NPC）。仕込み中は立ち位置の印の上で待つ。

const CastVisual := preload("res://scripts/cast_visual.gd")

enum St { STANDBY, IDLE, CONFESS, FLINCH, REUNION_MOVE, REUNION_HOLD }

const CONFESS_SEC := 6.0
const RUN_SPEED := 3.4
const GRAVITY := 16.0

var game: Node
var aid := 0
var label := ""
var vis: Node3D
var mark: Node3D
var partner: CharacterBody3D
var st := St.STANDBY
var st_t := 0.0
var after_flinch := St.IDLE
var special: Array = []       # 告白で使う固有モーション
var playback := false

var _stuck := 0.0
var _net: Array = []
var _spec_i := 0
var _spec_t := 0.0


func setup(cast_tag: String, specials: Array) -> void:
	special = specials
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	cs.shape = cap
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	vis = CastVisual.new()
	add_child(vis)
	vis.setup(cast_tag)
	set_state(St.STANDBY)


func is_confessing() -> bool:
	return st == St.CONFESS


func head_pos() -> Vector3:
	return vis.head_pos()


func chest_pos() -> Vector3:
	return vis.chest_pos()


func set_state(s: St) -> void:
	st = s
	# 待機中は印に付いて回るだけの幽霊にする（瞬間移動でセットを弾き飛ばさないため）
	collision_layer = 0 if s == St.STANDBY else 8
	collision_mask = 0 if s == St.STANDBY else 7     # 役者どうしは重なれる（頭の上に乗らないように）
	st_t = 0.0
	_stuck = 0.0
	_spec_i = 0
	_spec_t = 0.0


func knock(impulse: Vector3) -> void:
	if st == St.STANDBY:
		return
	after_flinch = St.REUNION_MOVE if st in [St.REUNION_MOVE, St.REUNION_HOLD] else St.IDLE
	velocity = impulse
	set_state(St.FLINCH)
	vis.play("flinch", 0.08, true)


func _face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(delta * 9.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if playback:
		return
	if not multiplayer.is_server():
		_follow_net(delta)
		return
	st_t += delta
	match st:
		St.STANDBY:
			velocity = Vector3.ZERO
			global_position = mark.global_position + Vector3(0, 0.04, 0)
			_face(partner.global_position, delta)
			vis.play("idle")
		St.IDLE:
			_fall(delta, 10.0)
			_face(partner.global_position, delta)
			vis.play("idle")
		St.CONFESS:
			_fall(delta, 10.0)
			_face(partner.global_position, delta)
			_spec_t -= delta
			if _spec_t <= 0.0 and not special.is_empty():
				var a: String = special[_spec_i % special.size()]
				_spec_i += 1
				_spec_t = vis.length(a) + 0.25
				vis.play(a, 0.15, true)
			if st_t >= CONFESS_SEC:
				set_state(St.IDLE)
		St.FLINCH:
			_fall(delta, 2.5)
			if st_t >= 1.1 and is_on_floor():
				set_state(after_flinch)
		St.REUNION_MOVE:
			_reunion_move(delta)
		St.REUNION_HOLD:
			# 重なって着地したら、手を取れる距離まで離れる
			var sep := global_position - partner.global_position
			sep.y = 0.0
			if sep.length() < 0.8 and is_on_floor():
				var away := sep.normalized() if sep.length() > 0.02 else Vector3(1.0 if aid == 0 else -1.0, 0, 0)
				velocity.x = away.x * 1.6
				velocity.z = away.z * 1.6
			_fall(delta, 12.0)
			_face(partner.global_position, delta)
			if st_t < vis.length("grab"):
				vis.play("grab", 0.15)
			else:
				vis.play("idle")


func _fall(delta: float, friction: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var k := clampf(friction * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, 0.0, k)
	velocity.z = lerpf(velocity.z, 0.0, k)
	move_and_slide()


func _reunion_move(delta: float) -> void:
	var d := partner.global_position - global_position
	var dy := absf(d.y)
	d.y = 0.0
	var dist := d.length()
	if dist < 1.0 and dy < 0.5 and is_on_floor():
		set_state(St.REUNION_HOLD)
		if partner.st == St.REUNION_MOVE:
			partner.set_state(St.REUNION_HOLD)
		return
	# 相手が高い所にいて近いなら、下の役者はその場で待つ（上の役者が降りてくる）
	if dist < 1.0 and partner.global_position.y > global_position.y + 0.4:
		_fall(delta, 12.0)
		_face(partner.global_position, delta)
		vis.play("idle")
		return
	var before := global_position
	var dir := d.normalized() if dist > 0.05 else global_basis.z
	velocity.x = dir.x * RUN_SPEED
	velocity.z = dir.z * RUN_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_face(partner.global_position, delta)
	vis.play("run" if is_on_floor() else "jump")
	# 手すりや小道具に引っかかったら跳び越える
	var moved := (global_position - before).length() / maxf(delta, 0.0001)
	if is_on_floor() and moved < 0.6:
		_stuck += delta
		if _stuck > 0.35:
			velocity.y = 7.0
			_stuck = 0.0
	else:
		_stuck = 0.0


# ---- 同期と記録 ----

func get_state() -> Array:
	return [global_position, rotation.y, vis.current]


func apply_state(s: Array, immediate: bool = false) -> void:
	if immediate:
		global_position = s[0]
		rotation.y = s[1]
		vis.play(s[2] as String, 0.12)
	else:
		_net = s


func _follow_net(delta: float) -> void:
	if _net.is_empty():
		return
	var w := clampf(delta * 14.0, 0.0, 1.0)
	global_position = global_position.lerp(_net[0] as Vector3, w)
	rotation.y = lerp_angle(rotation.y, _net[1] as float, w)
	vis.play(_net[2] as String, 0.12)
