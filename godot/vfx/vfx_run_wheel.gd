extends "res://vfx/vfx_base.gd"
# 脚ぐるぐる。走りの周期の違う瞬間の脚を、同じ場所に何本も重ねて、脚が車輪のように回って見えるようにする。
# 参考：ルーニー・テューンズ（ロード・ランナー）の車輪脚、ソニックのダッシュ、アニメの「マルチプル」。
# 仕組みはスミアの写しと同じ（骨格の写しに過去のポーズを流し込む）。違いは、写しを「いまの場所」に置くことと、腰より上を描かないこと。
# まわりに、光らない白い弧を回して勢いを足す。
# 走者ひとりにつき1つだけ生かし、蹴り出しや着地の合図が来るたびに延命する。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const FEED_SEC := 0.6
const FPS := 12.0
const COPIES := 8          # 重ねる脚の数
const SPAN := 0.72         # どれだけ前までのポーズを使うか（秒）。走りの一周ぶんくらい
const ARC_POINTS := 12

var runner: Node3D
var _size := 1.0
var _tall := 1.6
var _fed_until := 0.0
var _power := 0.0          # 0〜1。速く走っている間 1 へ
var _frame := -1
var _prev: Vector3
var _forward := Vector3.FORWARD
var _skel: Skeleton3D
var _mats: Array[ShaderMaterial] = []
var _copies: Array[Skeleton3D] = []
var _poses: Array = []     # [時刻, 各骨のポーズ]。新しい順
var _arcs: Array[MeshInstance3D] = []


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	add_to_group("dash_dust")
	for other in get_tree().get_nodes_in_group("run_wheel"):
		if other.runner == runner and not other.is_queued_for_deletion():
			other.feed(direction, size, trail, global_position)
			queue_free()
			return
	var skels := runner.find_children("*", "Skeleton3D", true, false) if is_instance_valid(runner) else []
	if skels.is_empty():
		queue_free()
		return
	_skel = skels[0]
	add_to_group("run_wheel")
	life = 0.0
	_size = size
	_tall = float(runner.get("vis").get("height")) if runner.get("vis") else 1.6
	_prev = runner.global_position
	_forward = Vector3(direction.x, 0, direction.z).normalized()
	var sources: Array[MeshInstance3D] = []
	for source: MeshInstance3D in runner.find_children("*", "MeshInstance3D", true, false):
		if source.skin and source.mesh and source.is_visible_in_tree() and not source.has_meta("vfx_echo"):
			sources.append(source)
	for c in COPIES:
		var copy := Skeleton3D.new()
		for b in _skel.get_bone_count():
			copy.add_bone(_skel.get_bone_name(b))
		for b in _skel.get_bone_count():
			copy.set_bone_parent(b, _skel.get_bone_parent(b))
			copy.set_bone_rest(b, _skel.get_bone_rest(b))
		copy.top_level = true
		add_child(copy)
		for source in sources:
			var echo := MeshInstance3D.new()
			echo.set_meta("vfx_echo", true)
			echo.mesh = source.mesh
			echo.skin = source.skin
			echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for s in source.mesh.get_surface_count():
				# 古いポーズほど薄く（網点を小さく）
				var mat := Lib.material("smear", {"whole": true, "amount": 0.02, "ghosting": lerpf(0.0, 0.45, float(c) / (COPIES - 1)), "dot_size": 4.0})
				var base := source.get_active_material(s) as BaseMaterial3D
				if base:
					mat.set_shader_parameter("albedo_texture", base.albedo_texture)
					mat.set_shader_parameter("albedo", base.albedo_color)
				echo.set_surface_override_material(s, mat)
				_mats.append(mat)
			copy.add_child(echo)
			echo.skeleton = NodePath("..")
			echo.transform = _skel.global_transform.affine_inverse() * source.global_transform
		_copies.append(copy)
	for i in 3:
		var arc: MeshInstance3D = Ribbon.new()
		arc.material_override = Lib.material("stroke", {"width": randf_range(0.03, 0.05) * size})
		add_child(arc)
		_arcs.append(arc)
	feed(direction, size, trail, global_position)


func feed(_direction: Vector3, _feed_size: float, _trail: bool, _pos: Vector3) -> void:
	_fed_until = age + FEED_SEC


func _tick(delta: float) -> void:
	if not is_instance_valid(runner) or not is_instance_valid(_skel):
		queue_free()
		return
	var move := runner.global_position - _prev
	_prev = runner.global_position
	move.y = 0.0
	var speed := move.length() / maxf(delta, 0.0001)
	if speed > 0.5:
		_forward = move.normalized()
	var feeding := age < _fed_until
	_power = move_toward(_power, 1.0 if feeding and speed > 3.5 else 0.0, delta * 5.0)
	# ポーズを記録し、写しへ「一歩ぶんの中の違う瞬間」を渡す。置く場所はいまの走者の位置
	var pose: Array[Transform3D] = []
	for b in _skel.get_bone_count():
		pose.append(_skel.get_bone_pose(b))
	_poses.push_front([age, pose])
	while age - _poses[-1][0] > SPAN + 0.1:
		_poses.pop_back()
	for c in _copies.size():
		var lag := SPAN * (c + 1) / COPIES
		var past: Array = _poses[-1]
		for entry: Array in _poses:
			if age - entry[0] >= lag:
				past = entry
				break
		var copy := _copies[c]
		copy.global_transform = _skel.global_transform
		copy.visible = _power > 0.02
		var old: Array[Transform3D] = past[1]
		for b in old.size():
			# 腕は腰の高さまで下がって脚に混ざるので、根元で縮めて消す
			if _skel.get_bone_name(b).begins_with("UPPER_ARM"):
				copy.set_bone_pose_scale(b, Vector3.ONE * 0.001)
				continue
			copy.set_bone_pose_position(b, old[b].origin)
			copy.set_bone_pose_rotation(b, old[b].basis.get_rotation_quaternion())
			copy.set_bone_pose_scale(b, old[b].basis.get_scale())
	for mat in _mats:
		mat.set_shader_parameter("strength", _power)
		mat.set_shader_parameter("cut_above", _prev.y + 0.46 * _tall)
		mat.set_shader_parameter("smear_dir", -_forward)
	# まわりを回る白い弧（コマ打ちで描き替える）
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		var side := _forward.cross(Vector3.UP)
		var center := _prev + Vector3(0, 0.25 * _tall, 0)
		for arc in _arcs:
			var points := PackedVector3Array()
			if _power > 0.6:
				var radius := randf_range(0.2, 0.34) * _tall * _size
				var start := randf_range(0.0, TAU)
				var sweep := randf_range(1.4, 3.2)
				var lean := side * randf_range(-0.16, 0.16) * _size
				for p in ARC_POINTS:
					var a := start - sweep * float(p) / (ARC_POINTS - 1)
					var p_at := center + lean + (_forward * cos(a) + Vector3.UP * sin(a)) * radius
					p_at.y = maxf(p_at.y, _prev.y + 0.03)
					points.append(p_at)
			arc.draw(points)
	if not feeding and _power <= 0.0:
		queue_free()
