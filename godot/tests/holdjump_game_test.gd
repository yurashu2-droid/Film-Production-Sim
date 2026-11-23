extends SceneTree
# 実際のゲームの中で確かめる：物を持ったまま跳べる。ただし、自分で持っている物の上からは跳べない。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/holdjump_game_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("HOLDJUMP_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


# ジャンプのキーを1コマだけ押して、いちばん高く上がった高さを返す
func hop(me: Node) -> float:
	var start: float = me.global_position.y
	var top := start
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	for i in 40:
		await physics_frame
		top = maxf(top, me.global_position.y)
	return top - start


func of_kind(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			return game.props[pid]
	return null


func place(prop: Node, pos: Vector3, fixed: bool = false) -> void:
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion.IDENTITY
	state[2] = fixed
	prop.restore(state)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	game.h_accept_job(0)
	var me: Node = game.local_player()
	var open := Vector3(73.0, 0.1, 25.5)          # 軽トラの南西の、何も無い地面（確認用モニターから離れた所）
	me.global_position = open
	await frames(30)
	check(me.is_on_floor(), "the crew member stands on open ground")
	var free_hop: float = await hop(me)
	check(free_hop > 0.6, "empty hands: a normal jump (%.2f m)" % free_hop)

	# 物を持って、平らな地面から跳ぶ
	var carton: Node = of_kind("carton")
	place(carton, open + Vector3(0, 0.3, -1.4))
	await frames(20)
	game.h_grab(carton.pid)
	await frames(30)
	check(me.held == carton.pid and me.is_on_floor(), "holding a carton on the ground")
	var held_hop: float = await hop(me)
	check(held_hop > 0.6, "holding a prop: the jump is back (%.2f m)" % held_hop)
	# 歩きながらでも跳べる
	Input.action_press("move_forward")
	await frames(20)
	var walking_hop: float = await hop(me)
	Input.action_release("move_forward")
	check(walking_hop > 0.6, "holding a prop and walking: still jumps (%.2f m)" % walking_hop)
	game.host_release(carton)
	await frames(20)

	# 自分で持っている物の上からは跳べない（持ち上げた物に乗って、どこまでも登るのを防ぐ）
	var riser: Node = of_kind("riser")
	me.global_position = open + Vector3(3.0, 0.1, 0)
	place(riser, open + Vector3(3.0, 0.02, 0), true)
	await frames(10)
	me.global_position = riser.global_position + Vector3(0, riser.half.y * 2.0 + 0.1, 0)
	await frames(30)
	check(me.is_on_floor() and me.global_position.y > 0.5, "standing on the riser (y=%.2f)" % me.global_position.y)
	var on_free: float = await hop(me)
	check(on_free > 0.6, "a prop nobody holds is a fine take-off point (%.2f m)" % on_free)
	await frames(30)
	riser.set_fixed(false)
	game.h_grab(riser.pid)
	await frames(20)
	check(me.held == riser.pid, "grabbing the riser while standing on it")
	var before: float = me.global_position.y
	var own_hop: float = await hop(me)
	check(own_hop < 0.25, "no jump from the prop you are holding (%.2f m)" % own_hop)
	await frames(60)
	check(me.global_position.y < before + 0.3, "and it does not carry its holder upward (y %.2f → %.2f)" % [before, me.global_position.y])
	print("HOLDJUMP_GAME_TEST_FAIL" if failed else "HOLDJUMP_GAME_TEST_OK")
	quit(1 if failed else 0)
