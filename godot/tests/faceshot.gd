extends Node
# 表情と新しい照明の確認用。 godot --path godot -- --faceshot

var game: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	game.hud.visible = false
	var CastVisual: GDScript = load("res://scripts/cast_visual.gd")
	var faces := ["happy", "shock", "angry", "sad", "surprised", "neutral"]
	var tags := ["01", "02", "03", "04", "06", "09"]
	var anims := ["rose", "ticket", "memo", "slate", "gavel", "wave"]
	for i in tags.size():
		var v: Node3D = CastVisual.new()
		game.add_child(v)
		v.setup(tags[i])
		v.position = Vector3(7.4 + i * 1.65, 0, -6.0)
		v.rotation.y = 0.15
		v.play(anims[i])
		v.set_face(faces[i])
	var cam := Camera3D.new()
	cam.fov = 30.0
	game.add_child(cam)
	cam.global_position = Vector3(11.6, 1.7, 3.2)
	cam.look_at(Vector3(11.5, 1.15, -6.0))
	cam.make_current()
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	get_viewport().get_texture().get_image().save_png("res://tests/shots/faces.png")
	print("FACESHOT_OK")
	get_tree().quit()
