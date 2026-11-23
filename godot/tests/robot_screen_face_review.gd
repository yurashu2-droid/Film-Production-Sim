extends Node3D
## The actual main.tscn player and its ordinary set_face/game selection path.
## Dedicated hidden review only; does not start a multiplayer server.
var game: Node
var player: Node
var camera: Camera3D

func _ready() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.input_locked = true
	game.h_select_cast(game.PLAYER_CASTS.find("M02"))
	player = game.local_player()
	player.set_physics_process(false)
	player.vis.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.vis.anim.advance(0.0)
	if player.vis.face_anim:
		player.vis.face_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	set_view("face")
	print("ROBOT_GAME_REVIEW_READY tag=", player.vis.tag,
		" face_player=", player.vis.face_anim != null)

func set_view(mode: String = "face") -> void:
	var aim: Vector3 = player.global_position + Vector3(0, 1.13, 0.3)
	camera.size = 0.62
	if mode == "body":
		aim = player.global_position + Vector3(0, 0.84, 0)
		camera.size = 1.95
	camera.position = aim + Vector3(0, 0, 4)
	camera.look_at(aim)
	camera.make_current()

func expression(name: String, time: float = 0.0) -> Dictionary:
	player.vis.set_face(name)
	if player.vis.face_anim and player.vis.face_anim.has_animation(name):
		player.vis.face_anim.stop()
		player.vis.face_anim.play(name, 0.0)
		player.vis.face_anim.advance(0.0)
		player.vis.face_anim.advance(time)
	return inspect()

func inspect() -> Dictionary:
	var screen := player.vis._model.find_child("castM02_game_screen", true, false) as MeshInstance3D
	var material := screen.get_active_material(0) as StandardMaterial3D
	return {"tag": player.vis.tag, "requested_face": player.vis.face,
		"face_player": player.vis.face_anim != null, "uv_offset": [material.uv1_offset.x, material.uv1_offset.y],
		"body_animation": player.vis.anim.current_animation,
		"body_clips": Array(player.vis.anim.get_animation_list()),
		"face_clips": Array(player.vis.face_anim.get_animation_list()) if player.vis.face_anim else []}
