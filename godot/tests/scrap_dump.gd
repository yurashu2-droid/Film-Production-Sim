extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20:
		await physics_frame
	for pid in game.props:
		var p: Node3D = game.props[pid]
		print("PROP %d %s (%.1f, %.1f, %.1f) half=(%.2f, %.2f, %.2f)" % [pid, p.kind, p.global_position.x, p.global_position.y, p.global_position.z, p.half.x, p.half.y, p.half.z])
	quit()
