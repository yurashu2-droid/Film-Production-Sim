extends SceneTree
# 拠点の飾りごとのポリゴン数を、1つずつ隠して比べる。 godot --path godot --script res://tests/prims_probe.gd
const Look := preload("res://scripts/production_look.gd")

func prims() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 60: await physics_frame
	var oroot: Node3D = game.production._office_root
	var views := {"start": null, "yard": [Vector3(66, 2.3, 16), Vector3(48, 1.2, 16)], "road": [Vector3(80, 2.3, 22), Vector3(80, 1.6, 70)]}
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	game.add_child(cam)
	var groups: Array = []
	for n in oroot.get_children():
		if n.name == "ScrapYard":
			for c in n.get_children():
				if c.name == "Surroundings":
					for c2 in c.get_children():
						if c2 is Node3D and not (c2 is Label3D):
							groups.append(c2)
			continue
		if n is Label3D or n is OmniLight3D:
			continue
		groups.append(n)
	for v: String in views:
		if views[v] == null:
			game.local_player().cam.make_current()
		else:
			cam.make_current()
			cam.global_position = views[v][0]
			cam.look_at(views[v][1])
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var base := prims()
		var line := "PRIMS %s total=%d" % [v, base]
		for g: Node3D in groups:
			g.visible = false
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			line += "  -%s=%d" % [g.name, base - prims()]
			g.visible = true
		print(line)
	quit()
