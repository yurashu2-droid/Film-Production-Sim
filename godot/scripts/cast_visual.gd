extends Node3D
# キャラの見た目とモーション再生。素材は+Z向き・大きめなので縮めて使う。

const SCALE := 0.62
const LOOPS := ["idle", "walk", "run", "crouch_idle", "crouch_walk"]

var tag := ""
var anim: AnimationPlayer
var skel: Skeleton3D
var height := 1.6
var current := ""
var _head := -1
var _body := -1


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
	play("idle")


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


func head_pos() -> Vector3:
	if _head < 0:
		return global_position + Vector3(0, height * 0.85, 0)
	return skel.global_transform * (skel.get_bone_global_pose(_head).origin + Vector3(0, 0.3, 0))


func chest_pos() -> Vector3:
	if _body < 0:
		return global_position + Vector3(0, height * 0.55, 0)
	return skel.global_transform * (skel.get_bone_global_pose(_body).origin + Vector3(0, 0.75, 0))
