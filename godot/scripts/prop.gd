extends RigidBody3D
# 持てる物の共通部分。
# 物理はホストだけが計算する。他の参加者は固めた状態で、受け取った位置へ寄せるだけ。

const L_WORLD := 1
const L_PROP := 2
const L_THIN := 4    # 手すりなど、当たるが撮影では透けて見える物
const L_CHAR := 8
const L_MARK := 16

var game: Node
var pid := 0
var kind := ""
var label := ""
var tags: Array = []
var one_sided := false       # 塗った面（+Z）だけが「城」に見える
var fixed := false
var holder := 0              # 持っている参加者のID（0=誰も持っていない）
var hold_min := 1.2
var carry_yaw := 0.0          # 持ったときの向きの補正
var rolls := false           # 持ち上げずに床を転がして運ぶ（台車）
var rider_of := 0            # 載っている台車のID（0=載っていない）
var ride_local := Transform3D.IDENTITY
var deck_top := -1.0         # 物を載せられる荷台の高さ（-1=荷台なし）
var deck_half := Vector2.ZERO
var deck_c := Vector2.ZERO   # 荷台の中心（ローカルのx,z）
var immovable := false       # 軽トラなど、動かせない物
var absent := false          # 今回の依頼では借りていない物（現場に無い）
var grab_time := 0.0
var _layers: Array = []
var _restore_pending := false
var _restore_transform := Transform3D.IDENTITY
var _teleport_ticks := 0
var center := Vector3.ZERO   # 見た目の中心（ローカル）
var half := Vector3.ONE * 0.2
var visual: Node3D
var playback := false        # 見返し中は記録どおりに動かす

var _net: Array = []


func _ready() -> void:
	collision_layer = L_PROP
	collision_mask = L_WORLD | L_PROP | L_CHAR
	continuous_cd = false
	can_sleep = true
	_apply_freeze()


func is_host() -> bool:
	return multiplayer.is_server()


func center_global() -> Vector3:
	return global_transform * center


func _apply_freeze() -> void:
	if not is_host() or playback or rider_of != 0:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC if _teleport_ticks > 0 else RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = fixed or absent
	if freeze:
		_restore_pending = false


func set_fixed(v: bool) -> void:
	fixed = v
	_apply_freeze()


func set_absent(v: bool) -> void:
	if v == absent:
		return
	absent = v
	visible = not v
	if v:
		_layers = [collision_layer, collision_mask]
		collision_layer = 0
		collision_mask = 0
	elif not _layers.is_empty():
		collision_layer = _layers[0]
		collision_mask = _layers[1]
	_apply_freeze()


func set_playback(v: bool) -> void:
	playback = v
	_apply_freeze()
	if not v:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


func set_holder(id: int) -> void:
	holder = id
	gravity_scale = 0.0 if id != 0 and not rolls else 1.0
	if id == 0:
		linear_velocity *= 0.25
		angular_velocity *= 0.1
	sleeping = false


func _physics_process(delta: float) -> void:
	if _teleport_ticks > 0:
		_teleport_ticks -= 1
		if _teleport_ticks == 0:
			_apply_freeze()
	if playback:
		return
	if not is_host():
		_follow_net(delta)
		return
	if rider_of != 0:
		# 台車に載っている間は、台車と一緒に動く
		var d: Node3D = game.props.get(rider_of)
		if d == null:
			rider_of = 0
			_apply_freeze()
		else:
			global_transform = d.global_transform * ride_local
	elif holder != 0 and not fixed:
		_drive_hold()
	_host_tick(delta)


# 描画完了時の置き直しは、次の物理同期で古い位置に上書きされる。
# 物理状態にも移動先を渡し、荷台の移動速度を引き継がずに再開する。
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _restore_pending:
		return
	state.transform = _restore_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_restore_pending = false


func _host_tick(_delta: float) -> void:
	pass


func _drive_hold() -> void:
	var tgt: Variant = game.hold_target(holder, self)
	if tgt == null:
		game.host_release(self)
		return
	var want: Vector3 = tgt[0]
	var want_yaw: float = tgt[1]
	var want_basis := Basis.from_euler(Vector3(float(tgt[3]), want_yaw, 0.0))
	var origin_goal: Vector3 = want - want_basis * center
	origin_goal.y = maxf(origin_goal.y, float(tgt[2]) + 0.03)
	var max_speed := clampf(16.0 / (1.0 + mass * 0.07), 2.2, 11.0)
	var v := (origin_goal - global_position) * 10.0
	if rolls:
		v.y = 0.0
	if v.length() > max_speed:
		v = v.normalized() * max_speed
	if rolls:
		v.y = linear_velocity.y
	linear_velocity = v
	var dq := (Quaternion(want_basis) * Quaternion(global_basis.orthonormalized()).inverse()).normalized()
	if dq.w < 0.0:
		dq = -dq
	var ang := dq.get_angle()
	angular_velocity = dq.get_axis() * ang * 9.0 if ang > 0.001 else Vector3.ZERO


# ---- 同期と記録 ----

func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed]


func apply_state(s: Array, immediate: bool = false) -> void:
	if immediate:
		global_transform = Transform3D(Basis(s[1] as Quaternion), s[0] as Vector3)
		fixed = s[2]
		_apply_extra(s)
	else:
		_net = s


func _apply_extra(_s: Array) -> void:
	pass


func _follow_net(delta: float) -> void:
	if _net.is_empty():
		return
	# 現場へのワープは補間せず、移動する足場の速度として扱わせない。
	var distant := global_position.distance_to(_net[0] as Vector3) > 8.0
	if distant:
		_begin_teleport()
	var w := 1.0 if distant else clampf(delta * 14.0, 0.0, 1.0)
	var p: Vector3 = global_position.lerp(_net[0] as Vector3, w)
	var q: Quaternion = Quaternion(global_basis.orthonormalized()).slerp(_net[1] as Quaternion, w)
	global_transform = Transform3D(Basis(q), p)
	fixed = _net[2]
	_apply_extra(_net)
	if distant:
		reset_physics_interpolation()


func _begin_teleport() -> void:
	# KINEMATIC の瞬間移動は経路上の物を押し、足場速度も発生する。
	# 二度の物理同期だけ STATIC にしてから、通常の台車追従へ戻す。
	_teleport_ticks = 2
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


# ホスト側で、置き直し用に元の状態へ戻す
func restore(s: Array) -> void:
	if global_position.distance_to(s[0] as Vector3) > 8.0:
		_begin_teleport()
	rider_of = 0
	set_holder(0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(s[1] as Quaternion), s[0] as Vector3)
	set_fixed(s[2])
	_apply_extra(s)
	_restore_transform = global_transform
	_restore_pending = not freeze
	reset_physics_interpolation()
