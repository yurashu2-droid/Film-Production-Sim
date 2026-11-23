extends SceneTree
# 積みすぎて出発し、段差で物が落ちる様子を撮る。 godot --path godot --script res://tests/travelshot.gd
var game: Node


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/travel/%s.png" % tag)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	for i in 40:
		await physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/travel"))
	var flow: Node = game.production
	seed(3)
	flow.daily = true
	flow.hazards = true
	flow.restock()
	game.h_accept_job(0)
	var out: Array = []
	for pid: int in game.props:
		var p: Node = game.props[pid]
		if flow._is_free(p) and not p.absent:
			out.append(p)
	for p: Node in out:
		game.host_load(p, game.truck)
	flow.prep_left = 20.0
	game.local_player().global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	for i in 30:
		await physics_frame
	await snap("0_walk")
	game.open_menu("packing")
	for i in 20:
		await process_frame
	await snap("1_packing_over")
	game.close_menu()
	game.h_depart()
	flow._bumped = 2          # 自然の段差は止めて、決まった時刻に必ず落とす
	var done := false
	var shots := {2.75: "2_bump", 3.1: "3_falling", 3.7: "4_left_behind", 6.5: "5_later"}
	var taken := {}
	while flow.phase == 3:
		await physics_frame
		if not done and flow.trip_time >= 2.6:
			done = true
			flow._bump(1.0)
		for t: float in shots:
			if flow.trip_time >= t and not taken.has(t):
				taken[t] = true
				await snap(shots[t])
	for i in 60:
		await physics_frame
	await snap("6_arrived")
	print("TRAVELSHOT_OK lost=", flow.lost)
	quit()
