extends SkeletonModifier3D
## キャラが元から手に持っている小道具（骨 PROP・CLAP に付いたバラ・クリップボード・木づち・カチンコなど）を、
## 物を持っている間だけ外す（骨を見えないほど小さくする）。本体と一人称の腕（first_person_arms.gd）は同じ骨なので、両方から消える。
## 何かを持っているかは player.gd が毎コマ決める（全員の画面で、持っている物は同じ）
const BONES := ["PROP", "CLAP"]

var hidden := false
var _bones: PackedInt32Array = PackedInt32Array()


func setup(skel: Skeleton3D) -> void:
	_bones = PackedInt32Array()
	for name: String in BONES:
		var b := skel.find_bone(name)
		if b >= 0:
			_bones.append(b)


func has_props() -> bool:
	return not _bones.is_empty()


func _process_modification() -> void:
	var s := get_skeleton()
	if s == null:
		return
	for b: int in _bones:
		s.set_bone_pose_scale(b, Vector3.ONE * 0.001 if hidden else Vector3.ONE)
