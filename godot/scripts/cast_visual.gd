extends Node3D
# キャラの見た目とモーション再生。素材は+Z向き・大きめなので縮めて使う。
# 体の動きと表情は別々の再生機で重ねる（走りながら驚く、など）。

const SCALE := 0.62
const LOOPS := ["idle", "walk", "run", "crouch_idle", "crouch_walk"]
const ONE_HAND_PROPS := ["clapper", "rose", "letter", "tape", "crown", "fish"]
const FACE_BONES := ["FACE", "EYE.", "LID.", "PUPIL.", "MOUTH.", "JAW"]

var tag := ""
var anim: AnimationPlayer
var face_anim: AnimationPlayer
var skel: Skeleton3D
var height := 1.6
var current := ""
var face := "neutral"
var _head := -1
var _body := -1
var _blink := 2.0
var _blinking := 0.0


func setup(cast_tag: String) -> void:
	tag = cast_tag
	var model: Node3D = (load("res://assets/cast/cast%s_game.glb" % tag) as PackedScene).instantiate()
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	_head = skel.find_bone("HEAD")
	_body = skel.find_bone("BODY")
	for a: String in anim.get_animation_list():
		if a.trim_prefix(tag + "_") in LOOPS:
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	if _head >= 0:
		height = (skel.get_bone_global_rest(_head).origin.y + 0.5) * SCALE
	_setup_face()
	_setup_transitions()
	_setup_carry()
	play("idle")
	_blink = randf_range(1.0, 4.0)


# 書き出された動きは全部の骨を含んでいるので、体の動きから顔の骨を、表情から体の骨を外して重ねられるようにする
func _setup_face() -> void:
	var prefix := tag + "_face_"
	var faces: Array = []
	for a: String in anim.get_animation_list():
		if a.begins_with(prefix):
			faces.append(a)
	if faces.is_empty():
		return
	for a: String in anim.get_animation_list():
		var an := anim.get_animation(a)
		if an.has_meta("split"):
			continue
		an.set_meta("split", true)
		var is_face := a.begins_with(prefix)
		for t in range(an.get_track_count() - 1, -1, -1):
			var bone := str(an.track_get_path(t)).get_slice(":", 1)
			var on_face := false
			for k: String in FACE_BONES:
				if bone.begins_with(k):
					on_face = true
			if on_face != is_face:
				an.remove_track(t)
	face_anim = AnimationPlayer.new()
	anim.get_parent().add_child(face_anim)
	face_anim.root_node = anim.root_node
	var lib := AnimationLibrary.new()
	for a: String in faces:
		lib.add_animation(a.trim_prefix(prefix), anim.get_animation(a))
	face_anim.add_animation_library("", lib)
	face_anim.play("neutral")


# 一瞬のリアクションは全編を短く再生する。途中で通常の移動に上書きしない。
func _setup_transitions() -> void:
	var lib := anim.get_animation_library("")
	var clips := {"run_start": ["dash", 0.4], "run_stop": ["brake", 0.32], "step_down": ["flinch", 0.28]}
	for name: String in clips:
		if has(name) or not has(clips[name][0]):
			continue
		var clip := anim.get_animation(tag + "_" + clips[name][0]).duplicate(true) as Animation
		var speed: float = float(clips[name][1]) / clip.length
		for t in clip.get_track_count():
			for k in clip.track_get_key_count(t):
				clip.track_set_key_time(t, k, clip.track_get_key_time(t, k) * speed)
		clip.length = float(clips[name][1])
		clip.loop_mode = Animation.LOOP_NONE
		lib.add_animation(tag + "_" + name, clip)


# 既存の「手を伸ばす」動きから腕だけを保持し、歩行・ジャンプの脚と体は残す。
# 生成したクリップ名をそのまま同期・録画できるので、別の状態同期は要らない。
func _setup_carry() -> void:
	if has("carry_idle") or not has("grab"):
		return
	var grab := anim.get_animation(tag + "_grab")
	var lib := anim.get_animation_library("")
	for base: String in ["idle", "walk", "run", "jump", "step_down", "run_stop"]:
		if not has(base):
			continue
		for mode: String in ["carry", "onehand"]:
			var clip := anim.get_animation(tag + "_" + base).duplicate(true) as Animation
			for t in range(clip.get_track_count()):
				var bone := str(clip.track_get_path(t)).get_slice(":", 1)
				var side := bone.right(1)
				var is_arm := bone.begins_with("UPPER_ARM.") or bone.begins_with("FOREARM.") or bone.begins_with("HAND.") or bone.begins_with("FINGERS.") or bone.begins_with("THUMB.") or bone.begins_with("JAW_UP.") or bone.begins_with("JAW_DOWN.")
				if not is_arm or (mode == "onehand" and side != "R") or clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
					continue
				var source_path := str(clip.track_get_path(t)).trim_suffix("L") + "R" if side == "L" else str(clip.track_get_path(t))
				var source := grab.find_track(NodePath(source_path), Animation.TYPE_ROTATION_3D)
				if source < 0:
					continue
				var q := grab.rotation_track_interpolate(source, grab.length * 0.45)
				if side == "L":
					q = Quaternion(q.x, -q.y, -q.z, q.w) # 左右対称の骨の構え
				while clip.track_get_key_count(t) > 0:
					clip.track_remove_key(t, 0)
				clip.rotation_track_insert_key(t, 0.0, q)
			lib.add_animation(tag + "_" + mode + "_" + base, clip)


func has(a: String) -> bool:
	return anim.has_animation(tag + "_" + a)


func play(a: String, blend: float = 0.18, restart: bool = false) -> void:
	if a == current and not restart:
		return
	if not has(a):
		a = "idle"
	current = a
	anim.play(tag + "_" + a, blend)
	if restart:
		anim.seek(0.0)


func length(a: String) -> float:
	return anim.get_animation(tag + "_" + a).length if has(a) else 1.0


# 表情：neutral / happy / angry / sad / surprised / shock
func set_face(f: String) -> void:
	if f == face or f == "":
		return
	face = f
	if face_anim and face_anim.has_animation(f):
		face_anim.play(f, 0.12)
		_blinking = 0.0


func _process(delta: float) -> void:
	if face_anim == null:
		return
	if _blinking > 0.0:
		_blinking -= delta
		if _blinking <= 0.0:
			face_anim.play(face, 0.08)
		return
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.0, 5.5)
		if face in ["neutral", "happy", "sad", "angry"] and face_anim.has_animation("blink"):
			face_anim.play("blink", 0.04)
			_blinking = face_anim.get_animation("blink").length


func head_pos() -> Vector3:
	if _head < 0:
		return global_position + Vector3(0, height * 0.85, 0)
	return skel.global_transform * (skel.get_bone_global_pose(_head).origin + Vector3(0, 0.3, 0))


func chest_pos() -> Vector3:
	if _body < 0:
		return global_position + Vector3(0, height * 0.55, 0)
	return skel.global_transform * (skel.get_bone_global_pose(_body).origin + Vector3(0, 0.75, 0))


func grip_pos(one_hand: bool) -> Vector3:
	var right := skel.get_bone_global_pose(skel.find_bone("HAND.R")).origin
	if one_hand:
		return skel.global_transform * right
	var left := skel.get_bone_global_pose(skel.find_bone("HAND.L")).origin
	return skel.global_transform * ((left + right) * 0.5)
