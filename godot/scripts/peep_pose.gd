extends SkeletonModifier3D
## 机の上の物を使っている人の姿勢。再生中の動き（立ち姿）の上から、毎コマ重ねる。元の動きは書き換えない。
##   "peep" ：のぞき箱に顔を寄せる（上体を前へ倒し、両手を箱に添える。脚は立ったまま）
##   "phone"：受話器を耳に当てる（右手を顔の横へ上げる）
## ほかの人の画面にも同じ姿勢を出す（誰がのぞいているか＝誰が監督かが、見て分かる）。
## 向きは骨格のローカル空間で書く：+Z が正面、+Y が上、キャラの右手側が -X。

var mode := "peep"
var lean := 0.62          # 上体を前へ倒す角度（ラジアン）


func _process_modification() -> void:
	var s := get_skeleton()
	if s == null:
		return
	if mode == "peep":
		_peep(s)
	elif mode == "phone":
		_phone(s)


func _peep(s: Skeleton3D) -> void:
	var body := s.find_bone("BODY")
	if body < 0:
		return
	# 脚は体の骨の子になっている。倒す前の向きを覚えておき、倒したあとで元の向きへ戻す（脚は立ったまま）
	var legs := {}
	for leg: String in ["THIGH.L", "THIGH.R"]:
		var bone := s.find_bone(leg)
		if bone >= 0:
			legs[bone] = s.get_bone_global_pose(bone).basis.orthonormalized()
	_turn(s, body, Vector3.RIGHT, lean)
	for bone: int in legs:
		_face(s, bone, legs[bone])
	# 顔は、のぞき口のほう（前）へ向け直す
	var head := s.find_bone("HEAD")
	if head >= 0:
		_turn(s, head, Vector3.RIGHT, -lean * 0.5)
	# 両手を、箱の横へ添える
	for side: String in ["L", "R"]:
		var out := 1.0 if side == "L" else -1.0
		_aim(s, "UPPER_ARM." + side, "FOREARM." + side, Vector3(out * 0.35, -0.55, 1.0))
		_aim(s, "FOREARM." + side, "HAND." + side, Vector3(-out * 0.25, 0.45, 1.0))


func _phone(s: Skeleton3D) -> void:
	# ひじを曲げて、右手を耳の横へ
	_aim(s, "UPPER_ARM.R", "FOREARM.R", Vector3(-0.5, -0.8, 0.4))
	_aim(s, "FOREARM.R", "HAND.R", Vector3(0.45, 1.0, 0.05))
	var head := s.find_bone("HEAD")
	if head >= 0:
		_turn(s, head, Vector3.BACK, -0.14)


# 骨を、骨格の空間の軸まわりに回す（いまの姿勢に足す）
func _turn(s: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	_face(s, bone, Basis(axis, angle) * s.get_bone_global_pose(bone).basis.orthonormalized())


# 骨を、骨格の空間での向き want にする
func _face(s: Skeleton3D, bone: int, want: Basis) -> void:
	var parent := s.get_bone_parent(bone)
	var parent_basis := s.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	s.set_bone_pose_rotation(bone, (parent_basis.inverse() * want).get_rotation_quaternion())


# 骨を、子の骨が direction のほうへ伸びる向きにする（seated_pose.gd と同じ考え方）
func _aim(s: Skeleton3D, bone: String, child: String, direction: Vector3) -> void:
	var i := s.find_bone(bone)
	var j := s.find_bone(child)
	if i < 0 or j < 0:
		return
	var basis := s.get_bone_global_pose(i).basis.orthonormalized()
	var axis := (basis * s.get_bone_pose_position(j)).normalized()
	_face(s, i, Basis(Quaternion(axis, direction.normalized())) * basis)
