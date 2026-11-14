extends RefCounted
## 元GLBを変えず、既存リアクションの間と反復から追加の芝居を組む。
const NAMES := {"skill_double_flinch":"二度びっくり", "skill_slow_flinch":"大げさなのけぞり"}

static func ensure(visual: Node) -> void:
	if not visual.has("flinch") or visual.has("skill_double_flinch"): return
	var source: Animation = visual.anim.get_animation(visual.tag + "_flinch")
	var library: AnimationLibrary = visual.anim.get_animation_library("")
	var twice: Animation = source.duplicate(true)
	var offset := source.length + 0.22
	twice.length = offset + source.length
	twice.loop_mode = Animation.LOOP_NONE
	for track in source.get_track_count():
		for key in source.track_get_key_count(track):
			twice.track_insert_key(track, offset + source.track_get_key_time(track, key), source.track_get_key_value(track, key), source.track_get_key_transition(track, key))
	library.add_animation(visual.tag + "_skill_double_flinch", twice)
	var slow: Animation = source.duplicate(true)
	for track in slow.get_track_count():
		for key in range(slow.track_get_key_count(track) - 1, -1, -1):
			slow.track_set_key_time(track, key, slow.track_get_key_time(track, key) * 1.8)
	slow.length = source.length * 1.8
	slow.loop_mode = Animation.LOOP_NONE
	library.add_animation(visual.tag + "_skill_slow_flinch", slow)
