extends SkeletonModifier3D
## キャラが元から手に持っている小道具（骨 PROP・CLAP に付いたバラ・クリップボード・木づち・カチンコなど）を、
## 物を持っている間だけ外す（骨を見えないほど小さくする）。本体と一人称の腕（first_person_arms.gd）は同じ骨なので、両方から消える。
## 何かを持っているかは player.gd が毎コマ決める（全員の画面で、持っている物は同じ）
## 段ボール頭（09）の手の紙は、使い道が無いので、いつも外しておく（2026-10-24 ユーザー）
const BONES := ["PROP", "CLAP"]
const ALWAYS_HIDE := ["09"]

var hidden := false
var always := false             # 物を持っていなくても外す
var _bones: PackedInt32Array = PackedInt32Array()


func setup(skel: Skeleton3D) -> void:
	_bones = PackedInt32Array()
	# キャラの種類（cast_visual.gd の tag）は、骨の上の方の親が持っている
	var up: Node = skel
	while up != null:
		if "tag" in up and up.get("tag") is String:
			always = str(up.get("tag")) in ALWAYS_HIDE
			break
		up = up.get_parent()
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
		s.set_bone_pose_scale(b, Vector3.ONE * 0.001 if hidden or always else Vector3.ONE)
