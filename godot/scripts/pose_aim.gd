extends SkeletonModifier3D
# 再生中の動きの上から、指定した骨を「この向きへ」と向け直す（腕を上げる・腰に手を当てる、など）。
# 向きは骨格のローカル空間で書く：+Z が正面、+Y が上、キャラの右手側が -X。
# 元のアニメーションは書き換えない。重ねる強さ weight を 0 にすれば元の動きに戻る。

var aims: Dictionary = {}      # 骨の名前 → 向き(Vector3)
var weight := 1.0


func set_aim(bone: String, dir: Vector3) -> void:
	aims[bone] = dir.normalized()


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or weight <= 0.001:
		return
	# 親から順に直す（肩 → ひじ → 手）
	var order: Array = []
	for bone: String in aims:
		var idx := skel.find_bone(bone)
		if idx >= 0:
			order.append([_depth(skel, idx), idx, aims[bone]])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item: Array in order:
		var idx: int = item[1]
		var dir: Vector3 = item[2]
		var parent := skel.get_bone_parent(idx)
		var parent_basis := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		var cur := skel.get_bone_global_pose(idx).basis.orthonormalized()
		# 骨は自分の +Y 方向へ伸びている。+Y を狙いへ向け、ねじれは今の姿勢からなるべく保つ
		var y := dir
		var z := cur.z - y * cur.z.dot(y)
		if z.length() < 0.05:
			z = cur.x.cross(y)
		z = z.normalized()
		var x := y.cross(z).normalized()
		var want := Basis(x, y, z)
		var q := cur.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), clampf(weight, 0.0, 1.0))
		skel.set_bone_pose_rotation(idx, (parent_basis.inverse() * Basis(q)).get_rotation_quaternion())


func _depth(skel: Skeleton3D, idx: int) -> int:
	var d := 0
	var p := skel.get_bone_parent(idx)
	while p >= 0:
		d += 1
		p = skel.get_bone_parent(p)
	return d
