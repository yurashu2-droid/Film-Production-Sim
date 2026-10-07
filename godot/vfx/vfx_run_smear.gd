extends "res://vfx/vfx_base.gd"
# 走りのスミア。キャラ自身の色のまま、体が後ろへ伸び、少し前のポーズが網点で重なる。
# 参考：『The Dover Boys』(1942) のスミアフレーム、アニメの「マルチプル」（手足を複数描く）、『オーバーウォッチ』の3Dスミア。
#   1. いまのポーズの後ろ側を、帯状に引き伸ばす（体の流れ）
#   2. 少し前のポーズの写しを2体、薄く重ねる（手足の動きの跡）
# 走者ひとりにつき1つだけ生かし、蹴り出しや着地の合図が来るたびに延命する。

const FEED_SEC := 0.6             # 合図が途切れてから続ける秒数
const FPS := 12.0                 # 帯の出方を描き替える速さ（コマ打ち）
const LAGS: Array[float] = [0.05, 0.1]      # 写しがどれだけ前のポーズか（秒）
const GHOSTING: Array[float] = [0.35, 0.65]
const HISTORY_SEC := 0.2

var runner: Node3D
var electric := false     # true で伸びた先を雷の光にする（vfx_run_volt.gd が使う）
var _size := 1.0
var _fed_until := 0.0
var _kick := 0.0          # 蹴り出し直後だけ大きく伸ばす
var _amount := 0.0
var _prev: Vector3
var _dir := Vector3.BACK
var _skel: Skeleton3D
var _echoes: Array[MeshInstance3D] = []      # 本体の骨格に付けた写し（片付けが要る）
var _mats: Array[ShaderMaterial] = []
var _lag_skels: Array[Skeleton3D] = []
var _poses: Array = []    # [時刻, 骨格の位置, 各骨のポーズ]。新しい順


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	add_to_group("dash_dust")
	for other in get_tree().get_nodes_in_group("run_smear"):
		if other.runner == runner and not other.is_queued_for_deletion():
			other.feed(direction, size, trail, global_position)
			queue_free()
			return
	var skels := runner.find_children("*", "Skeleton3D", true, false) if is_instance_valid(runner) else []
	if skels.is_empty():
		queue_free()
		return
	_skel = skels[0]
	add_to_group("run_smear")
	life = 0.0
	_size = size
	_prev = runner.global_position
	_dir = -Vector3(direction.x, 0, direction.z).normalized()
	var sources: Array[MeshInstance3D] = []
	for source: MeshInstance3D in runner.find_children("*", "MeshInstance3D", true, false):
		if source.skin and source.mesh and source.is_visible_in_tree() and not source.has_meta("vfx_echo"):
			sources.append(source)
	# 1. いまのポーズ：本体と同じ骨格に付ける。動きは完全に一致する
	for source in sources:
		var echo := _echo(source, false, 0.0)
		source.get_parent().add_child(echo)
		echo.skeleton = source.skeleton
		echo.transform = source.transform
		_echoes.append(echo)
	# 2. 少し前のポーズ：骨格の写しを作り、過去のポーズを毎フレーム流し込む
	for lag in LAGS.size():
		var copy := Skeleton3D.new()
		for b in _skel.get_bone_count():
			copy.add_bone(_skel.get_bone_name(b))
		for b in _skel.get_bone_count():
			copy.set_bone_parent(b, _skel.get_bone_parent(b))
			copy.set_bone_rest(b, _skel.get_bone_rest(b))
		copy.top_level = true
		add_child(copy)
		for source in sources:
			var echo := _echo(source, true, GHOSTING[lag])
			copy.add_child(echo)
			echo.skeleton = NodePath("..")
			echo.transform = _skel.global_transform.affine_inverse() * source.global_transform
		_lag_skels.append(copy)
	feed(direction, size, trail, global_position)


func _echo(source: MeshInstance3D, whole: bool, ghosting: float) -> MeshInstance3D:
	var echo := MeshInstance3D.new()
	echo.set_meta("vfx_echo", true)
	echo.mesh = source.mesh
	echo.skin = source.skin
	echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in source.mesh.get_surface_count():
		var mat := Lib.material("smear", {"whole": whole, "ghosting": ghosting})
		if electric:
			mat.set_shader_parameter("edge_color", Vector3(7, 4.6, 0.5))
			mat.set_shader_parameter("tip_color", Vector3(10, 9.5, 6))
			mat.set_shader_parameter("sharpness", 3.2)
			mat.set_shader_parameter("zigzag", 0.4)
			mat.set_shader_parameter("ghost_tint", 0.3)
		var base := source.get_active_material(s) as BaseMaterial3D
		if base:
			mat.set_shader_parameter("albedo_texture", base.albedo_texture)
			mat.set_shader_parameter("albedo", base.albedo_color)
		echo.set_surface_override_material(s, mat)
		_mats.append(mat)
	return echo


func feed(_direction: Vector3, _feed_size: float, trail: bool, _pos: Vector3) -> void:
	_fed_until = age + FEED_SEC
	if not trail:
		_kick = 1.0


func _tick(delta: float) -> void:
	if not is_instance_valid(runner) or not is_instance_valid(_skel):
		queue_free()
		return
	var move := runner.global_position - _prev
	_prev = runner.global_position
	move.y = 0.0
	var speed := move.length() / maxf(delta, 0.0001)
	if speed > 0.5:
		_dir = -move.normalized()
	_kick = move_toward(_kick, 0.0, delta * 2.5)
	var fast := clampf((speed - 2.5) / 3.5, 0.0, 1.0)
	var target := 0.0
	if age < _fed_until:
		target = (fast * 0.7 + _kick * 0.9) * _size
	_amount = lerpf(_amount, target, 1.0 - exp(-delta * 14.0))
	for mat in _mats:
		mat.set_shader_parameter("smear_dir", _dir)
		mat.set_shader_parameter("amount", _amount)
		mat.set_shader_parameter("strength", clampf(_amount / (0.45 * _size), 0.0, 1.0))
		mat.set_shader_parameter("step_seed", floorf(age * (15.0 if electric else FPS)))
	# ポーズを記録し、写しへ「少し前」のものを渡す
	var pose: Array[Transform3D] = []
	for b in _skel.get_bone_count():
		pose.append(_skel.get_bone_pose(b))
	_poses.push_front([age, _skel.global_transform, pose])
	while age - _poses[-1][0] > HISTORY_SEC:
		_poses.pop_back()
	for lag in _lag_skels.size():
		var past: Array = _poses[-1]
		for entry: Array in _poses:
			if age - entry[0] >= LAGS[lag]:
				past = entry
				break
		var copy := _lag_skels[lag]
		copy.global_transform = past[1]
		var old: Array[Transform3D] = past[2]
		for b in old.size():
			copy.set_bone_pose_position(b, old[b].origin)
			copy.set_bone_pose_rotation(b, old[b].basis.get_rotation_quaternion())
			copy.set_bone_pose_scale(b, old[b].basis.get_scale())
	if age >= _fed_until and _amount < 0.01:
		queue_free()


func _exit_tree() -> void:
	for echo in _echoes:
		if is_instance_valid(echo):
			echo.queue_free()
