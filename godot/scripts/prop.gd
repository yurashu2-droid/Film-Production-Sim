extends RigidBody3D
# 持てる物の共通部分。
# 物理はホストだけが計算する。他の参加者は固めた状態で、受け取った位置へ寄せるだけ。

const L_WORLD := 1
const L_PROP := 2
const L_THIN := 4    # 手すりなど、当たるが撮影では透けて見える物
const L_CHAR := 8
const L_MARK := 16
# 持った物にぶら下がった物に引っぱられても動きを乱されないよう、その重さの何倍までの引っぱりを手が受け止めるか
const HANG_GRIP := 3.0
const HANG_DAMP := 1.1       # 手に持って垂れている物の、揺れの収まりやすさ（大きいほど早く止まる。小さいほど、ぶらんぶらん揺れる）
const HANG_SHAKE := 25.0     # 手の動きで揺れる強さの上限（手の加速度。m/秒²）

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
var stored_in := 0           # しまってある先。0＝外に出ている / 正＝箱（その箱の物のID）/ 負＝人の体（−参加者のID）
var grab_time := 0.0
var hold_reference_valid := false
var hold_transform := Transform3D.IDENTITY
var hold_view_transform := Transform3D.IDENTITY
var hold_grip_local := Vector3.ZERO
var hold_player_position := Vector3.ZERO
var hold_forward := Vector3.FORWARD
var hold_lifted := false
var _held_roll_friction := -1.0
var _hold_com_local := Vector3.ZERO
var _hold_inverse_inertia := Basis.IDENTITY
var _hold_gravity := Vector3(0, -9.8, 0)
var _hold_set_valid := false          # 前のコマで手が決めた速さを覚えているか（1つだけ持って動かしている間）
var _hold_set_velocity := Vector3.ZERO
var _hold_brace := 0.0                # ぶら下がりを支えるために上げてある回りにくさ（0＝元のまま）
var _layers: Array = []
var _restore_pending := false
var _restore_transform := Transform3D.IDENTITY
var _launch: Array = []      # 置き直しの直後に与える速度 [並進, 回転]（撃ち出すとき）
var _teleport_ticks := 0
var center := Vector3.ZERO   # 見た目の中心（ローカル）
var half := Vector3.ONE * 0.2
var visual: Node3D
var playback := false        # 見返し中は記録どおりに動かす

var _net: Array = []
var _raise_seen := false        # 直前に見た、持っている人の「持ち上げている」の値（変わったときだけ切り替える）
var _hang_yaw := 0.0            # 直前のコマの、持っている人の視点の左右の向き（垂れている物を、視点と一緒に回すため）
var _hang_yaw_valid := false
var _hang_grip_at := Vector3.ZERO      # 前のコマの、手の場所（垂れている物を、手の動きで揺らすため）
var _hang_grip_speed := Vector3.ZERO
var _hang_grip_valid := false


func _ready() -> void:
	collision_layer = L_PROP
	collision_mask = L_WORLD | L_PROP | L_CHAR
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	can_sleep = true
	_apply_freeze()


func is_host() -> bool:
	return multiplayer.is_server()


func center_global() -> Vector3:
	return global_transform * center


func _apply_freeze() -> void:
	if not is_host() or playback:
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


# しまう・出す（全員の画面で呼ぶ）。keeper：0＝外に出す / 正＝箱の物のID / 負＝−参加者のID。
# しまってある間は、現場に無い物と同じ扱い（見えない・当たらない・判定に数えない）。
# ホストは、現場に無い物と同じ待機場所（y=−60）へ停める。出すときの置き場所は、呼ぶ側が決める
func set_stored(keeper: int) -> void:
	stored_in = keeper
	set_absent(keeper != 0)
	if keeper != 0 and is_host():
		rider_of = 0
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		global_position = Vector3(float(pid) * 3.0, -60.0, 0.0)


func set_playback(v: bool) -> void:
	playback = v
	_apply_freeze()
	if not v:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


func set_holder(id: int, local_grip: Variant = null) -> void:
	if id != 0 and (holder != id or not hold_reference_valid):
		# つかむだけでは置き方を変えない。運搬の補助は別の明示操作。
		hold_transform = global_transform
		hold_grip_local = local_grip if local_grip is Vector3 else center
		hold_reference_valid = true
		hold_lifted = false
		_raise_seen = false
		var crew: Variant = game.get("players") if game != null else null
		var player: Node3D = crew.get(id) if crew is Dictionary else null
		if player != null:
			hold_player_position = player.global_position
			hold_forward = player.aim_forward()
			hold_view_transform = game.hold_view_anchor(player) if game.has_method("hold_view_anchor") else Transform3D(Basis.IDENTITY, player.global_position)
	holder = id
	if id != 0 and rolls and physics_material_override != null and _held_roll_friction < 0.0:
		# 箱型の接触形状にも、手で運搬中のキャスターの転がり抵抗を与える。
		# 重量と保持の加速度は維持する。解放後は元の接触抵抗へ戻す。
		_held_roll_friction = physics_material_override.friction
		physics_material_override.friction = minf(_held_roll_friction, 0.08)
	elif id == 0 and _held_roll_friction >= 0.0:
		if physics_material_override != null:
			physics_material_override.friction = _held_roll_friction
		_held_roll_friction = -1.0
	gravity_scale = 0.0 if id != 0 and not rolls else 1.0
	_hold_set_valid = false
	if id == 0:
		_brace_for_hanging(0.0)
		hold_reference_valid = false
		hold_lifted = false
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
		# 積載は位置の記録だけ。重力・摩擦・衝突が荷物を支える。
		var d: Node3D = game.props.get(rider_of)
		if d == null or d.absent:
			rider_of = 0
		else:
			ride_local = d.global_transform.affine_inverse() * global_transform
			var c: Vector3 = d.to_local(center_global())
			if absf(c.x-d.deck_c.x)>d.deck_half.x+0.25 or absf(c.z-d.deck_c.y)>d.deck_half.y+0.25 or c.y < d.deck_top-0.2:
				rider_of = 0
	if holder != 0 and not fixed:
		_drive_hold(delta)
	_host_tick(delta)


# 描画完了時の置き直しは、次の物理同期で古い位置に上書きされる。
# 物理状態にも移動先を渡し、荷台の移動速度を引き継がずに再開する。
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_hold_com_local = state.center_of_mass_local
	_hold_inverse_inertia = state.inverse_inertia_tensor
	_hold_gravity = state.total_gravity
	if not _restore_pending:
		return
	state.transform = _restore_transform
	state.linear_velocity = Vector3.ZERO if _launch.is_empty() else _launch[0]
	state.angular_velocity = Vector3.ZERO if _launch.is_empty() else _launch[1]
	_launch = []
	_restore_pending = false


func _host_tick(_delta: float) -> void:
	pass


func _drive_hold(delta: float) -> void:
	var tgt: Variant = game.hold_target(holder, self)
	if tgt == null:
		game.host_release(self)
		return
	# 転がして運ぶ物：持っている人が N を押すと、床に張り付くのをやめる（ほかの物と同じに動かせる）。もう一度 N で床を転がす
	if rolls:
		var raiser: Node = game.players.get(holder)
		var raise: bool = raiser != null and raiser.hold_raise
		if raise != _raise_seen:
			_raise_seen = raise
			hold_lifted = raise
			gravity_scale = 0.0 if raise else 1.0
			if raise:
				# 床に張り付くのをやめるだけ。その場から動かさない（今の場所と向きを、持ち方の基準にする）。
				# そのあと視点を上げ下げすれば、ほかの物と同じように上下に動かせる
				hold_transform = global_transform
				hold_view_transform = game.hold_view_anchor(raiser)
	var want: Vector3 = tgt[0]
	var want_yaw: float = tgt[1]
	var want_basis: Basis = tgt[4] if tgt.size() > 4 else Basis.from_euler(Vector3(float(tgt[3]), want_yaw, 0.0))
	var steady := _hold_set_valid
	_hold_set_valid = false
	var group := _hold_connected_bodies()
	if group.size() > 1:
		_brace_for_hanging(0.0)
		_drive_hold_group(tgt, want_basis, group, delta)
		return
	# 人が乗っている物は「重くて持ち上がらない」。床の上をゆっくり引きずれるだけにする
	# （乗っている人を、足場ごと放り投げないため）
	var loaded: bool = game.has_method("crew_on") and game.crew_on(self)
	if loaded:
		_brace_for_hanging(0.0)
		gravity_scale = 1.0
		var drag := Vector3.ZERO
		if tgt.size() > 5:
			drag = (tgt[5] - global_transform * hold_grip_local) * 4.0
		drag.y = 0.0
		drag = drag.limit_length(0.6)
		linear_velocity = Vector3(move_toward(linear_velocity.x, drag.x, 6.0 * delta), linear_velocity.y, move_toward(linear_velocity.z, drag.z, 6.0 * delta))
		angular_velocity = angular_velocity.move_toward(Vector3.ZERO, 20.0 * delta)
		return
	if gravity_scale != 0.0 and not rolls:
		gravity_scale = 0.0
	# 点で留めてぶら下がっている物があれば、その重さを支え、振り回されないよう回りにくくする
	var hanging := Vector2.ZERO
	if not rolls or hold_lifted:
		hanging = _support_hanging(group)
	_brace_for_hanging(hanging.y)
	var from_velocity := linear_velocity
	if steady and hanging.x > 0.0:
		# ぶら下がった物に引かれて変わった速さは、その重さの HANG_GRIP 倍で説明できる大きさまで、
		# 手が受け止めたものとして取り除く。衝突や爆発で受けた、それより大きな勢いは残る
		from_velocity -= (linear_velocity - _hold_set_velocity).limit_length(HANG_GRIP * hanging.x / mass * delta)
	var origin_goal: Vector3 = want - want_basis * center
	# 古い4要素の機材用目標にも対応するが、通常保持に足元への自動持ち上げはない。
	var max_speed := clampf(16.0 / (1.0 + mass * 0.07), 2.2, 11.0)
	var dq := (Quaternion(want_basis) * Quaternion(global_basis.orthonormalized()).inverse()).normalized()
	if dq.w < 0.0:
		dq = -dq
	var ang := dq.get_angle()
	var axis := dq.get_axis() if ang > 0.001 else Vector3.UP
	var lever := _hold_surface_lever(axis)
	var max_spin := minf(7.0 / (1.0 + mass * 0.004), 6.0 / maxf(lever, 0.25))
	var angular_accel := minf(60.0 / (1.0 + mass * 0.008), 60.0 / maxf(lever, 0.25))
	var spin := axis * minf(ang * 9.0, minf(max_spin, sqrt(2.0 * angular_accel * ang))) if ang > 0.001 else Vector3.ZERO
	var next_spin := angular_velocity.move_toward(spin, angular_accel * delta)
	# 回していない間は、向きを保たない：掴んだ点を支点に、重さで垂れる・揺れる（振り子）。
	# 真ん中を掴めば垂れず、端を掴むほど大きく垂れる。倒れないようにしてある物・転がす物は、今までどおり
	var holder_node: Node = game.players.get(holder)
	# 垂れるかどうかは、持っている人が決める（N で力を抜く。player.gd の hold_limp）。重さでは変えない
	var droop := 1.0
	var hanging_now := false
	if droop > 0.0 and holder_node != null and not holder_node.hold_turning and tgt.size() > 5 and hold_reference_valid and not rolls and not axis_lock_angular_x:
		var arm: Vector3 = global_basis * (_hold_com_local - hold_grip_local)
		# 手（掴んだ点）が動くと、その勢いで物が揺れる（振り子の支点を揺らすのと同じ）。
		# 物の向きを視点に合わせて回すことはしない（それをすると、くるくる回る）
		var grip_at: Vector3 = tgt[5]
		var shake := Vector3.ZERO
		if _hang_grip_valid:
			var grip_speed: Vector3 = (grip_at - _hang_grip_at) / maxf(delta, 0.001)
			shake = ((grip_speed - _hang_grip_speed) / maxf(delta, 0.001)).limit_length(HANG_SHAKE)
			_hang_grip_speed = grip_speed
		_hang_grip_at = grip_at
		_hang_grip_valid = true
		var pull: Vector3 = arm.cross(Vector3.DOWN * 9.8 - shake) / (arm.length_squared() + half.length_squared() / 3.0 + 0.0004)
		var swing: Vector3 = (angular_velocity + pull * delta) * maxf(0.0, 1.0 - HANG_DAMP * delta)
		hanging_now = true
		if droop >= 1.0:
			next_spin = swing
			game.hold_rebase(holder_node, self)
		else:
			# 中くらいの重さ：向きを保つ力と、垂れる力のあいだ
			next_spin = next_spin.lerp(swing, droop)
	if not hanging_now:
		_hang_grip_valid = false
		_hang_grip_speed = Vector3.ZERO
	_hang_yaw_valid = holder_node != null
	if holder_node != null:
		_hang_yaw = holder_node.aim_yaw
	var v := (origin_goal - global_position) * 10.0
	var grip_radius := Vector3.ZERO
	if tgt.size() > 5:
		var grip_now: Vector3 = global_transform * hold_grip_local
		grip_radius = global_basis * (hold_grip_local - _hold_com_local)
		v = (tgt[5] - grip_now) * 10.0
	if rolls and not hold_lifted:
		v.y = 0.0
	if v.length() > max_speed:
		v = v.normalized() * max_speed
	# 回転する物の中心の移動も補償し、選んだ表面点を回転の支点にする。
	v -= next_spin.cross(grip_radius)
	if rolls and not hold_lifted:
		v.y = linear_velocity.y
	# 制限するのは手が加える速度変化だけ。衝突・爆発の速度を切り詰めない。
	var acceleration := clampf(48.0 / (1.0 + mass * 0.012), 22.0, 46.0)
	acceleration = minf(96.0, acceleration + (angular_accel + spin.length_squared()) * grip_radius.length())
	linear_velocity = from_velocity.move_toward(v, acceleration * delta)
	angular_velocity = next_spin
	_hold_set_velocity = linear_velocity
	_hold_set_valid = true


func _hold_surface_lever(axis: Vector3) -> float:
	var longest := 0.25
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var corner := center + half * Vector3(x, y, z) - _hold_com_local
				longest = maxf(longest, axis.cross(global_basis * corner).length())
	return longest


# 手でいっしょに動かす仲間：自分と、接着で固く留まっている物（一直線でない3点以上で留めた相手）。
# 点で留めただけの相手は入れない。その相手は重力を受けたまま、留めた点からぶら下がってついてくる
func _hold_connected_bodies() -> Array[Node]:
	var result: Array[Node] = [self]
	var glue: Variant = game.get("adhesive") if game != null else null
	if glue == null or not glue.has_method("rigid_ids"):
		return result
	for id: int in glue.rigid_ids(pid):
		if id == pid:
			continue
		var member: Node = game.props.get(id)
		if member != null and not member.absent:
			result.append(member)
	return result


# ぶら下がった物に振り回されないよう、持っている間だけ、この物を回りにくくする。
# need＝ぶら下がった重さが留めた点に付いたとみた回りにくさ。0 で元に戻す。
# 回す速さは手が直接決めているので、手の操作への反応は変わらない
func _brace_for_hanging(need: float) -> void:
	var want := 0.0
	if need > 0.0:
		want = need + mass * half.length_squared() / 3.0
	if absf(want - _hold_brace) <= 0.02 * maxf(want, _hold_brace):
		return
	_hold_brace = want
	inertia = Vector3.ONE * want      # 0 にすると、形から決まる元の値に戻る


# 手で動かしている物（group）に、点で留まってぶら下がっている物の重さを、留めた点で支える。
# ぶら下がった物そのものには触らないので、重力を受けて、留めた点のまわりに垂れる・揺れる。
# 返すのは、この物にかかる (支えた重さの合計 N, ぶら下がった物の重さが留めた点に付いたとみた回りにくさ kg·m²)
func _support_hanging(group: Array[Node]) -> Vector2:
	var burden := Vector2.ZERO
	var glue: Variant = game.get("adhesive") if game != null else null
	if glue == null or not glue.has_method("hanging_groups"):
		return burden
	var ids: Array[int] = []
	for member: Node in group:
		ids.append(member.pid)
	for hang: Dictionary in glue.hanging_groups(ids):
		var weight := Vector3.ZERO
		var heft := 0.0       # 重力を受けてぶら下がっている重さ（kg）。ほかの人が持っている物は数えない
		var reach := 0.0      # ぶら下がった物の大きさ
		for id: int in hang.bodies:
			var body: Node = game.props.get(id)
			if body != null and (body._hold_gravity as Vector3).length_squared() > 0.01:
				weight += body._hold_gravity * body.mass
				heft += body.mass
				reach = maxf(reach, (body.half as Vector3).length())
		var share: Vector3 = -weight / float((hang.points as Array).size())
		for point: Array in hang.points:
			var member: RigidBody3D = game.props.get(point[0])
			if member == null or member.freeze:
				continue
			var arm: Vector3 = member.global_basis * (point[1] as Vector3)
			member.apply_force(share, arm)
			member.sleeping = false
			if member == self:
				# 腕の長さ：留めた点までの距離に、ぶら下がった物の大きさを足す（寄りかかって押してくる分）
				var lever: float = (arm - global_basis * _hold_com_local).length() + reach
				burden.x += share.length()
				burden.y += heft / float((hang.points as Array).size()) * lever * lever
	return burden


func _drive_hold_group(tgt: Array, basis: Basis, group: Array[Node], _delta: float) -> void:
	var total_mass := 0.0
	var centre_of_group := Vector3.ZERO
	for member: Node in group:
		if member.fixed or member.immovable:
			# 固定車体等につながった物を、保持で無理に剥がさない。
			return
		var member_com: Vector3 = member.global_transform * member._hold_com_local
		total_mass += member.mass
		centre_of_group += member_com * member.mass
	centre_of_group /= maxf(total_mass, 0.1)
	if not rolls or hold_lifted:
		_support_hanging(group)
	var difference := (Quaternion(basis) * Quaternion(global_basis.orthonormalized()).inverse()).normalized()
	if difference.w < 0.0:
		difference = -difference
	var angle := difference.get_angle()
	var axis := difference.get_axis() if angle > 0.001 else Vector3.UP
	var lever := 0.25
	for member: Node in group:
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					var corner: Vector3 = member.to_global(member.center + member.half * Vector3(x, y, z))
					lever = maxf(lever, axis.cross(corner - centre_of_group).length())
	var angular_accel := minf(60.0 / (1.0 + total_mass * 0.008), 60.0 / lever)
	var max_spin := minf(7.0 / (1.0 + total_mass * 0.004), 6.0 / lever)
	var spin := axis * minf(angle * 9.0, minf(max_spin, sqrt(2.0 * angular_accel * angle))) if angle > 0.001 else Vector3.ZERO
	var grip_now: Vector3 = global_transform * hold_grip_local
	var point: Vector3 = tgt[5] if tgt.size() > 5 else tgt[0]
	var velocity: Vector3 = (point - grip_now) * 10.0
	if rolls and not hold_lifted:
		velocity.y = 0.0
	velocity = velocity.limit_length(clampf(16.0 / (1.0 + mass * 0.07), 2.2, 11.0))
	velocity -= spin.cross(grip_now - centre_of_group)
	var acceleration := clampf(48.0 / (1.0 + total_mass * 0.012), 22.0, 46.0)
	# 一部品だけへ速度を押し付けず、同じ剛体運動の速度場を、固く留まった仲間へ配る。
	# 軽い部品をつかんでも、重い接着先の重力や慣性に操作が負けない。
	for member: Node in group:
		if member.freeze:
			continue
		var member_com: Vector3 = member.global_transform * member._hold_com_local
		var wanted_velocity := velocity + spin.cross(member_com - centre_of_group)
		var change: Vector3 = (wanted_velocity - member.linear_velocity) * 18.0
		change = change.limit_length(minf(96.0, acceleration + angular_accel * (member_com - grip_now).length()))
		if rolls and not hold_lifted:
			change.y = 0.0
		elif member.gravity_scale != 0.0:
			change -= member._hold_gravity
		member.apply_central_force(change * member.mass)
		var turn: Vector3 = ((spin - member.angular_velocity) * 18.0).limit_length(angular_accel)
		if turn.length_squared() > 0.000001:
			var direction := turn.normalized()
			var inverse: float = direction.dot(member._hold_inverse_inertia * direction)
			if inverse > 0.000001:
				member.apply_torque(turn / inverse)
		member.sleeping = false


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


# ホスト側で、その場所へ置き直してから速度を与える（怪獣の技を撃ち出す）
func launch(at: Vector3, velocity: Vector3, spin: Vector3) -> void:
	restore([at, global_transform.basis.get_rotation_quaternion(), false])
	_launch = [velocity, spin]
	sleeping = false


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
