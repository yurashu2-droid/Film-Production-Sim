extends SkeletonModifier3D
# 座面を腰の支点にして、腕はハンドル、脚は足元へ向ける。
var wheel := Vector3.ZERO
var radius := 0.2
var driving := true
var lean := 0.0
var ceiling := 10.0
var model_top := 0.0

func _process_modification() -> void:
	var s := get_skeleton()
	var root := s.find_bone("ROOT")
	var body := s.find_bone("BODY")
	if root >= 0:
		s.set_bone_pose(root, s.get_bone_rest(root))
	if body >= 0:
		s.set_bone_pose(body, s.get_bone_rest(body))
		s.set_bone_pose_rotation(body, Quaternion(Vector3.RIGHT, lean))
	var head := s.find_bone("HEAD")
	if head >= 0:
		s.set_bone_pose(head, s.get_bone_rest(head))
		s.set_bone_pose_rotation(head, Quaternion(Vector3.RIGHT, -lean * 0.5))
		# 王冠や大きな頭は、車室の中にぎゅっと詰める。降車すると元の形に戻る。
		var head_y := s.get_bone_global_rest(head).origin.y
		var overflow := maxf(0.0, model_top-ceiling)
		var down := minf(overflow*0.3, 0.25/0.62)
		s.set_bone_pose_position(head, s.get_bone_rest(head).origin - Vector3(0,down,0))
		var squeeze := clampf((ceiling-head_y+down) / maxf(0.01,model_top-head_y),0.25,1.0)
		s.set_bone_pose_scale(head, Vector3(lerpf(0.8,1.0,squeeze),squeeze,lerpf(0.75,1.0,squeeze)))
	for side: String in ["L", "R"]:
		var sign_x := 1.0 if side == "L" else -1.0
		var hand_target := wheel + Vector3(sign_x * radius * 0.9, radius * 0.40, -radius * 0.16)
		if not driving:
			hand_target = s.get_bone_global_pose(body).origin + Vector3(sign_x * 0.30, 0.12, 0.40) / 0.62
		_limb(s, "UPPER_ARM." + side, "FOREARM." + side, "HAND." + side, hand_target, Vector3(sign_x * 0.5,-1,0))
		_aim(s, "THIGH." + side, "SHIN." + side, Vector3(sign_x * 0.04,-0.18,1))
		_aim(s, "SHIN." + side, "FOOT." + side, Vector3(0,-1,0.12))

func _limb(s: Skeleton3D, upper: String, lower: String, tip: String, target: Vector3, pole: Vector3) -> void:
	var a := s.find_bone(upper)
	var b := s.find_bone(lower)
	var c := s.find_bone(tip)
	if a < 0 or b < 0 or c < 0:
		return
	var origin := s.get_bone_global_pose(a).origin
	var l1 := s.get_bone_pose_position(b).length()
	var l2 := s.get_bone_pose_position(c).length()
	var reach := target - origin
	var distance := clampf(reach.length(), absf(l1-l2) + 0.001, l1+l2-0.001)
	var direction := reach.normalized()
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var along := (l1*l1 - l2*l2 + distance*distance) / (2.0 * distance)
	var elbow := origin + direction * along + bend * sqrt(maxf(0,l1*l1-along*along))
	_aim(s, upper, lower, elbow-origin)
	_aim(s, lower, tip, target-s.get_bone_global_pose(b).origin)

func _aim(s: Skeleton3D, bone: String, child: String, direction: Vector3) -> void:
	var i := s.find_bone(bone)
	var j := s.find_bone(child)
	if i < 0 or j < 0:
		return
	var basis := s.get_bone_global_pose(i).basis.orthonormalized()
	var axis := (basis * s.get_bone_pose_position(j)).normalized()
	var want := Basis(Quaternion(axis, direction.normalized())) * basis
	var parent := s.get_bone_parent(i)
	var parent_basis := s.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	s.set_bone_pose_rotation(i, (parent_basis.inverse() * want).get_rotation_quaternion())
