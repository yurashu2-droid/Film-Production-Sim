extends Node
# 機材の見た目を近くから撮る。  godot --path godot -- --gearshot

var game: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	game.hud.visible = false
	game.spots[0].tilt = -0.25
	game.film.cam_yaw = 0.5
	game.film.cam_pitch = -0.15
	var cam := Camera3D.new()
	cam.fov = 45.0
	game.add_child(cam)
	cam.make_current()
	var by_kind := {}
	for p in game.props.values():
		if not by_kind.has(p.kind):
			by_kind[p.kind] = p
	var views := {
		"camera": [Vector3(1.1, 1.55, 1.5), Vector3(0, 1.1, 0)],
		"spot": [Vector3(-1.6, 1.9, 2.2), Vector3(0, 1.3, 0)],
		"spot_head": [Vector3(-0.7, 2.15, 0.9), Vector3(0, 2.0, 0)],
		"partition": [Vector3(3.6, 1.6, 0.4), Vector3(0, 0.9, 1.0)],
		"greenscreen": [Vector3(4.6, 1.7, 0.0), Vector3(0, 1.0, 0)],
		"dolly": [Vector3(1.8, 1.2, 1.6), Vector3(0, 0.4, 0)],
		"boom": [Vector3(1.2, 0.8, 2.0), Vector3(0, 0.3, 0.6)],
		"carton": [Vector3(1.4, 0.8, 0.9), Vector3(0, 0.2, 0.3)],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	for k: String in views:
		var p: Node3D = by_kind[k.get_slice("_", 0)]
		var base: Vector3 = p.global_position
		cam.global_position = base + views[k][0]
		cam.look_at(base + views[k][1])
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/shots/gear_%s.png" % k)
	print("GEARSHOT_OK")
	get_tree().quit()
