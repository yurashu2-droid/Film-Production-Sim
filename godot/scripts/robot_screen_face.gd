extends AnimationPlayer
## CastM02's existing LED sheet is separate from its body/bone animations.
## Row order, FPS and loop flags come from game/castM02_screen.json, authored
## by make_m02_screens.py. Reuse the imported emission texture unchanged.
const COLS := 8
const ROWS := 16
const CLIPS := [
	["neutral", 4.0, true], ["happy", 8.0, true], ["angry", 10.0, true],
	["sad", 6.0, true], ["surprised", 6.0, true], ["shock", 10.0, false],
	["love", 6.0, true], ["sleep", 3.0, true], ["loading", 8.0, true],
	["error", 4.0, true], ["static", 12.0, true], ["question", 5.0, true],
	["dizzy", 8.0, true], ["battery", 3.0, true], ["ok", 8.0, false],
	["rec", 2.0, true],
]

func setup(model: Node3D) -> void:
	name = "RobotScreenFace"
	var display := model.find_child("castM02_game_screen", true, false) as MeshInstance3D
	assert(display != null)
	var source := display.get_active_material(0) as StandardMaterial3D
	assert(source != null and source.emission_texture != null)
	# Imported materials are shared resources: only this robot owns the clone.
	display.material_override = source.duplicate() as StandardMaterial3D
	root_node = NodePath("..")
	var path := NodePath(str(get_parent().get_path_to(display)) + ":material_override:uv1_offset")
	var library := AnimationLibrary.new()
	for row in CLIPS.size():
		var spec: Array = CLIPS[row]
		var clip := Animation.new()
		clip.length = float(COLS) / float(spec[1])
		clip.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track, path)
		clip.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		for frame in COLS:
			clip.track_insert_key(track, float(frame) / float(spec[1]),
				Vector3(float(frame) / COLS, float(row) / ROWS, 0.0))
		library.add_animation(spec[0], clip)
	add_animation_library("", library)
	play("neutral")
	advance(0.0)
