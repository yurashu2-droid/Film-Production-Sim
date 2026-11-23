extends SceneTree
## Dedicated offline regression: real game player, original sheet and body clips.
var failed := false
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		print("ROBOT_FACE_CHECK FAIL ", label)

func screen_material(visual: Node) -> StandardMaterial3D:
	var screen := visual._model.find_child("castM02_game_screen", true, false) as MeshInstance3D
	return screen.get_active_material(0) as StandardMaterial3D

func frame_at(visual: Node, name: String, time: float) -> void:
	visual.set_face(name)
	visual.face_anim.stop()
	visual.face_anim.play(name, 0.0)
	visual.face_anim.advance(0.0)
	visual.face_anim.advance(time)

func run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.input_locked = true
	game.h_select_cast(game.PLAYER_CASTS.find("M02"))
	var player: Node = game.local_player()
	player.set_physics_process(false)
	var visual: Node = player.vis
	check(visual.face_anim != null, "M02 game player has a screen expression player")
	if visual.face_anim == null:
		game.free()
		print("ROBOT_SCREEN_FACE_TEST_FAIL checks=", checks)
		quit(1)
		return
	visual.face_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	visual.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var names := ["neutral", "happy", "angry", "sad", "surprised", "shock", "love", "sleep", "loading", "error", "static", "question", "dizzy", "battery", "ok", "rec"]
	var fps := [4.0, 8.0, 10.0, 6.0, 6.0, 10.0, 6.0, 3.0, 8.0, 4.0, 12.0, 5.0, 8.0, 3.0, 8.0, 2.0]
	var material := screen_material(visual)
	check(material.emission_texture.get_size() == Vector2(1024, 1792), "original 8x16 atlas is retained")
	check(material.emission_texture.resource_path == "res://assets/cast/castM02_game_castM02_screen.png", "original expression PNG is used")
	check(visual.face_anim.get_animation_list().size() == 16, "all sixteen original screen states")
	for row in names.size():
		var clip: Animation = visual.face_anim.get_animation(names[row])
		check(is_equal_approx(clip.length, 8.0 / fps[row]), "source FPS " + names[row])
		check(clip.loop_mode == (Animation.LOOP_NONE if names[row] in ["shock", "ok"] else Animation.LOOP_LINEAR), "source loop mode " + names[row])
		for frame in 8:
			frame_at(visual, names[row], float(frame) / fps[row] + 0.001)
			check(material.uv1_offset.is_equal_approx(Vector3(float(frame) / 8, float(row) / 16, 0)), "source frame " + names[row] + " " + str(frame))
		frame_at(visual, names[row], clip.length + 0.001)
		check(material.uv1_offset.is_equal_approx(Vector3(7.0 / 8 if names[row] in ["shock", "ok"] else 0.0, float(row) / 16, 0)), "hold or loop " + names[row])
	# The neutral cell's seventh frame is the authored blink; no invented blink clip.
	frame_at(visual, "neutral", 6.0 / 4 + 0.001)
	check(material.uv1_offset.x == 6.0 / 8, "original neutral blink frame")
	visual.set_face("happy")
	check(material.uv1_offset == Vector3(0, 1.0 / 16, 0), "set_face applies first cell immediately")
	visual.face_anim.advance(0.26)
	var offset := material.uv1_offset
	visual.set_face("happy")
	check(material.uv1_offset == offset, "repeat state does not restart its animation")
	# Material ownership: changing one robot cannot change another player or cached GLB.
	var second := preload("res://scripts/cast_visual.gd").new()
	root.add_child(second)
	second.setup("M02")
	second.face_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(screen_material(second) != material, "per-instance screen material")
	second.set_face("angry")
	check(material.uv1_offset == offset and screen_material(second).uv1_offset.y == 2.0 / 16, "robot expressions stay independent")
	var raw: Node = (load("res://assets/cast/castM02_game.glb") as PackedScene).instantiate()
	root.add_child(raw)
	check(screen_material_from_model(raw).uv1_offset == Vector3.ZERO, "cached imported material stays neutral")
	var imported: AnimationPlayer = raw.find_children("*", "AnimationPlayer", true, false)[0]
	for body: String in imported.get_animation_list():
		if body == "RESET":
			continue
		check(visual.anim.has_animation(body), "original body clip " + body)
		check(visual.anim.get_animation(body).get_track_count() == imported.get_animation(body).get_track_count(), "body tracks preserved " + body)
	visual.play("run", 0.0)
	visual.anim.advance(0.2)
	var body_time: float = visual.anim.current_animation_position
	visual.set_face("sad")
	check(visual.anim.current_animation == "M02_run" and visual.anim.current_animation_position == body_time, "face switching preserves running body")
	visual.anim.advance(0.1)
	check(is_equal_approx(visual.anim.current_animation_position, body_time + 0.1), "body continues playing")
	player.start_performance("face:surprised")
	check(material.uv1_offset.y == 4.0 / 16, "existing performance menu request reaches screen")
	player.apply_net(player.position, 0.0, 0.0, 0.0, 1.6, 0.0, 0.0, "idle|angry")
	check(material.uv1_offset.y == 2.0 / 16, "existing remote player packet reaches screen offline")
	player.apply_state([player.position, 0.0, "idle", "shock", "M02"])
	check(material.uv1_offset.y == 5.0 / 16, "existing recorded player state reaches screen")
	var actor := preload("res://scripts/actor.gd").new()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.setup("M02", [])
	actor.set_state(actor.St.CONFESS)
	check(screen_material(actor.vis).uv1_offset.y == 1.0 / 16, "NPC confession reaches original smile")
	actor.apply_state([Vector3.ZERO, 0.0, "idle", "sad"], true)
	check(screen_material(actor.vis).uv1_offset.y == 3.0 / 16, "NPC restored state reaches original sadness")
	var human := preload("res://scripts/cast_visual.gd").new()
	root.add_child(human)
	human.setup("01")
	human.set_face("happy")
	check(human.face_anim != null and human.face_anim.current_animation == "happy", "existing human bone expressions continue")
	frame_at(visual, "happy", 0.0)
	visual.face_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for tick in 17:
		await physics_frame
	check(material.uv1_offset.is_equal_approx(Vector3(2.0 / 8, 1.0 / 16, 0)), "normal engine callbacks advance authored frames")
	human.free()
	actor.free()
	raw.free()
	second.free()
	game.free()
	await process_frame
	print("ROBOT_SCREEN_FACE_TEST_", "FAIL" if failed else "OK", " checks=", checks)
	quit(1 if failed else 0)

func screen_material_from_model(model: Node) -> StandardMaterial3D:
	var screen := model.find_child("castM02_game_screen", true, false) as MeshInstance3D
	return screen.get_active_material(0) as StandardMaterial3D
