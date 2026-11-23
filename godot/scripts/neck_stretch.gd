extends SkeletonModifier3D
## ベレー帽の人「びよーん首」：頭の骨を上へ持ち上げる（歩く・跳ぶ・持つ動きに重ねる）。
## 動きの再生が決めた姿勢に、毎コマ足すだけ。元の動きは書き換えない。

var bone := -1
var rise := 0.0          # 持ち上げる高さ（キャラの素材の大きさで）


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or bone < 0 or rise <= 0.0001:
		return
	skel.set_bone_pose_position(bone, skel.get_bone_pose_position(bone) + Vector3(0, rise, 0))
