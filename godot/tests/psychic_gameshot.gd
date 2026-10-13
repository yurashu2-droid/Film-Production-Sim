extends SceneTree
# 念力の演出（scripts/features/psychic_hold.gd → vfx/vfx_psychic.gd）を、実際のゲームの画面で撮る：
# 三人称で、遠くの物をつかむ → 振る → 止める → 離す。続けて一人称、手元へ寄せた時（出ないこと）も撮る。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/psychic_gameshot.gd
#   画面つきで動かす（窓は画面の外に出し、マウスも捕まえない）。出力は tests/shots/vfx_review/psychic_game.png
#   型を替える：最後に「-- --style=giza」
const CELL := Vector2i(800, 450)
var game: Node
var me: Node
var pictures: Array = []


func _initialize() -> void:
	root.unfocusable = true
	create_timer(200).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(wait: int = 2) -> void:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	pictures.append(root.get_texture().get_image())


func first(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			return game.props[pid]
	return null


func place(prop: Node, pos: Vector3) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, 0.4)
	state[2] = false
	prop.restore(state)


func aim_at(prop: Node3D) -> bool:
	for step in 10:
		var to: Vector3 = prop.center_global() - me.cam.global_position
		me.aim_yaw = atan2(-to.x, -to.z)
		me.aim_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.0)
		await frames(3)
	await frames(4)
	return me.target == prop


# 物を前に置いて、狙って持つ → 視線を上げて振る → 止める → 離す。その間を撮る
func scene(prop: Node, distance: float) -> void:
	place(prop, me.global_position + me.flat_forward() * distance + Vector3(0, 0.3, 0))
	await frames(40)
	var ok: bool = await aim_at(prop)
	game.act_grab(prop.pid, prop.to_local(me.target_hit) if ok else null)
	await frames(8)
	await snap()                    # つかんだ直後（包んでいく途中）
	print("PSYCHIC_GAMESHOT holding links=", game.get_node("PsychicHold")._links.size(), " fx=", get_nodes_in_group("vfx").size())
	me.aim_pitch = -0.02
	await frames(10)
	me.aim_yaw += 0.5
	await frames(7)
	await snap()                    # 振っている最中
	await frames(80)
	await snap()                    # 止めている
	game.act_release()
	await frames(7)
	await snap()                    # 離した直後


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--style="):
			ProjectSettings.set_setting("vfx/psychic_style", arg.trim_prefix("--style="))
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true
	while not game.startup_complete:
		await process_frame
	await frames(40)
	game.h_accept_job(0)
	await frames(20)
	game.h_select_cast(game.PLAYER_CASTS.find("M02"))
	await frames(8)
	me = game.local_player()
	me.cam.make_current()
	var kinds := []
	for pid: int in game.props:
		if not game.props[pid].absent:
			kinds.append(game.props[pid].kind)
	print("PSYCHIC_GAMESHOT kinds ", kinds)
	var big: Node = first("carton")
	var mid: Node = first("applebox") if first("applebox") != null else first("scrap_duck")
	me.aim_pitch = -0.15
	await frames(20)
	await scene(big, 3.0)                      # 三人称：大きい物
	await frames(60)
	await scene(mid if mid != null else big, 3.2)      # 三人称：中くらいの物
	await frames(60)
	# 一人称
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F2
	event.keycode = KEY_F2
	event.pressed = true
	game.input_locked = false
	root.push_input(event)
	await frames(20)
	await scene(big, 2.6)
	await frames(60)
	print("PSYCHIC_GAMESHOT links ", game.get_node("PsychicHold")._links.size(), " fx ", get_nodes_in_group("vfx").size())
	var sheet := Image.create(CELL.x * 4, CELL.y * ((pictures.size() + 3) / 4), false, Image.FORMAT_RGB8)
	var full := ProjectSettings.globalize_path("res://tests/shots/vfx_review/psychic_game")
	DirAccess.make_dir_recursive_absolute(full)
	for i in pictures.size():
		var picture: Image = pictures[i]
		picture.convert(Image.FORMAT_RGB8)
		picture.save_png(full.path_join("%02d.png" % i))
		picture.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 4) * CELL.x, (i / 4) * CELL.y))
	var dir := ProjectSettings.globalize_path("res://tests/shots/vfx_review")
	DirAccess.make_dir_recursive_absolute(dir)
	sheet.save_png(dir.path_join("psychic_game.png"))
	print("PSYCHIC_GAMESHOT_DONE")
	quit(0)
