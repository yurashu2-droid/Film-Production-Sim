extends SceneTree
# ロープを手でつかむ所を撮る：狙った所の案内・端をつかんで引いている所・途中をつまみ上げた所・
# 離して落ち着いた所・切れ端を爆弾につないだ所・切れ端をフックに結んだ所。
#   godot --path godot --script res://tests/rope_grab_shot.gd      （画面つきで動かす。出力は tests/shots/rope_grab）
var game: Node
var flow: Node
var kit: Node
var ck: Node
var grab: Node
var bomb: Node
var me: Node
var eye: Camera3D
var floor_y := 0.0


func _initialize() -> void:
	run.call_deferred()


func snap(tag: String, wait: int = 14) -> void:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/rope_grab/%s.png" % tag)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = true) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = fixed
	prop.restore(state)


func look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	eye.global_position = from
	eye.look_at(at, Vector3.UP)
	eye.fov = fov
	eye.make_current()


# キャラを、正面の右ななめ前から撮る（手元が見える）
func front_view(dist: float = 3.0, fov: float = 55.0) -> void:
	var ff: Vector3 = me.flat_forward()
	var right := Vector3(-ff.z, 0.0, ff.x)
	look(me.global_position + ff * dist * 0.8 + right * dist * 0.6 + Vector3(0, 1.5, 0), me.global_position + Vector3(0, 0.75, 0), fov)


func own_view() -> void:
	me.cam.make_current()


func stand(pos: Vector3, yaw: float = 0.0, pitch: float = -0.2) -> void:
	me.global_position = Vector3(pos.x, floor_y + 0.1, pos.z)
	me.aim_yaw = yaw
	me.aim_pitch = pitch
	await frames(6)


func walk(by: Vector3, steps: int) -> void:
	for i in steps:
		me.global_position += by / float(steps)
		await physics_frame


func scrap(from: Vector3, to: Vector3) -> int:
	var a := Vector3(from.x, floor_y + 0.03, from.z)
	var b := Vector3(to.x, floor_y + 0.03, to.z)
	var id: int = kit.host_add_scrap(PackedVector3Array([a, b]), a.distance_to(b))
	await frames(90)
	return id


# 自分の目で、その点を狙う（体はその点から dist だけ離れて立つ）。つかめる所が見つかるまで、少しずつ見下ろす
func aim_point(point: Vector3, dir: Vector3, dist: float) -> bool:
	me.global_position = point - dir * dist
	me.global_position.y = floor_y + 0.1
	me.aim_yaw = atan2(-dir.x, -dir.z)
	for step in 50:
		me.aim_pitch = -0.05 - 0.02 * step
		await frames(4)
		if not (grab.aim(me) as Dictionary).is_empty():
			return true
	return false


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(60)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/rope_grab"))
	flow = game.production
	kit = game.bomb_kit
	ck = game.cargo_kit
	grab = game.rope_grab
	me = game.local_player()
	bomb = game.fx
	eye = Camera3D.new()
	game.add_child(eye)
	flow.day = 2
	game.production_sync.rpc(flow.snapshot())
	game.h_accept_job(3)
	await frames(20)
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_confirm()
	await frames(40)
	var spot: Vector3 = flow.HOME_TRUCK + Vector3(-7.5, 0.0, -1.5)
	place(bomb, spot + Vector3(0, 0.05, 0))
	var none: Array[RID] = []
	floor_y = kit._floor_under(spot + Vector3(2, 1, 2), none).y
	await frames(20)

	# 1：床の切れ端の端を狙う（自分の目。「左クリック つかむ」の案内と、狙った所の輪）
	var p0: Vector3 = spot + Vector3(1.5, 0, 2.5)
	var id: int = await scrap(p0, p0 + Vector3(3.0, 0, 0))
	var rope: Node = kit.cords[id]
	var found: bool = await aim_point(rope.tip(), Vector3(-0.5, 0, -0.85).normalized(), 2.2)
	print("ROPE_SHOT aim found=", found, " ", grab.aim(me))
	own_view()
	await snap("01_aim_at_end")

	# 2：端をつかんで、引いて歩く
	grab.handle_click(me)
	await frames(50)
	print("ROPE_SHOT holding=", grab.holding(me.peer_id), " pose=", me.vis.current, " hand=", grab.hand_point(me) - me.global_position, " grip=", me.vis.grip_pos(true) - me.global_position)
	own_view()
	await snap("02_end_in_hand_own_view")
	me.aim_yaw = PI          # +Z のほうを向いて歩く
	me.aim_pitch = -0.15
	await walk(Vector3(0.3, 0, 1.6), 50)
	front_view(4.2)
	await snap("03_pulling_end", 3)
	own_view()
	await snap("03b_pulling_end_own_view", 3)
	await walk(Vector3(0.3, 0, 1.8), 55)
	await frames(30)
	front_view(4.6)
	await snap("04_pulled_and_standing")
	front_view(1.8, 50.0)
	await snap("04b_hand_close")
	print("ROPE_SHOT pulled: stretch=", rope.path_length() / rope.length, " pose=", me.vis.current, " hand=", grab.hand_point(me) - me.global_position, " grip=", me.vis.grip_pos(true) - me.global_position)

	# 3：離す → 落ちて止まる
	grab.handle_click(me)
	await frames(20)
	await snap("05_just_dropped", 2)
	await frames(240)
	print("ROPE_SHOT dropped: asleep=", rope.asleep, " speed=", rope.speed())
	await snap("06_dropped_at_rest")

	# 4：途中をつまみ上げる
	var mid: Vector3 = rope.point_at(1.5)
	await stand(mid + Vector3(0.0, 0, 0.9), 0.0, -0.1)
	grab.h_grab(grab.CORD, id, 1.5)
	await frames(90)
	front_view(3.6)
	await snap("07_middle_lifted")
	await walk(Vector3(1.2, 0, 0), 40)
	await frames(20)
	front_view(3.6)
	await snap("07b_middle_carried_a_little")
	own_view()
	await snap("07c_middle_lifted_own_view")
	me.aim_pitch = -0.1
	grab.h_release()
	await frames(240)
	look(me.global_position + Vector3(1.6, 1.8, 3.0), me.global_position + Vector3(-0.5, 0.2, 0), 55.0)
	await snap("08_middle_dropped_at_rest")
	print("ROPE_SHOT mid dropped: asleep=", rope.asleep, " speed=", rope.speed())

	# 5：切れ端を拾って、爆弾の口金につなぐ
	var r0: Vector3 = spot + Vector3(0.9, 0, 1.1)
	var id3: int = await scrap(r0, r0 + Vector3(1.5, 0, 0))
	await stand(spot + Vector3(1.7, 0, 0.5), PI * 0.5, -0.25)
	grab.h_grab(grab.CORD, id3, 1.5)
	await frames(50)
	look(spot + Vector3(-0.6, 1.4, 2.6), spot + Vector3(1.0, 0.6, 0.4), 55.0)
	await snap("09_scrap_end_in_hand_by_bomb")
	own_view()
	await snap("09b_scrap_by_bomb_own_view")
	grab.h_use("bomb", -1)
	await frames(8)
	look(spot + Vector3(1.6, 1.3, 2.8), spot + Vector3(0.8, 0.5, 0.2), 55.0)
	await snap("10_scrap_just_connected", 2)
	await frames(200)
	await snap("11_scrap_connected_at_rest")
	look(spot + Vector3(0.9, 0.8, 1.3), spot + Vector3(0.2, 0.45, 0.2), 50.0)
	await snap("11b_connected_close")
	var fuse: Node = kit.cords.get(id3)
	print("ROPE_SHOT fuse: bomb=", fuse != null and fuse.a_body == bomb, " asleep=", fuse.asleep if fuse != null else false, " length=", fuse.length if fuse != null else -1.0)

	# 6：切れ端を、軽トラのフックに結ぶ → もう片方も結ぶ
	var truck: Node3D = game.truck
	var local: Vector3 = truck.hooks[2]
	var side: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
	var away := Vector3(signf((side - truck.global_position).x), 0, 0)
	var id4: int = await scrap(side + Vector3(0, 0, 0.3), side + Vector3(0, 0, 0.3) + away * 4.5)
	var to_hook: Vector3 = ck.hook_at(2) - side
	await stand(side, atan2(-to_hook.x, -to_hook.z), -0.1)
	grab.h_grab(grab.CORD, id4, 0.0)
	await frames(50)
	look(side + away * 2.6 + Vector3(0, 1.6, 2.4), ck.hook_at(2) + Vector3(0, -0.2, 0), 55.0)
	await snap("12_scrap_end_in_hand_by_truck")
	front_view(2.4)
	await snap("12b_hand_close")
	look(side + away * 2.6 + Vector3(0, 1.6, 2.4), ck.hook_at(2) + Vector3(0, -0.2, 0), 55.0)
	grab.h_use("hook", 2)
	await frames(200)
	await snap("13_scrap_tied_to_hook")
	var hung := 0
	for lid: int in ck.lashes:
		hung = lid
	if hung != 0:
		var line: Node = ck.lashes[hung]["cord"]
		await stand(line.tip() - away * 1.0 + Vector3(0, 0, 0.5), atan2(-to_hook.x, -to_hook.z), -0.1)
		grab.h_grab(grab.LASH, hung, line.length)
		await frames(40)
		var from: Vector3 = me.global_position
		for i in 80:
			me.global_position = from.lerp(Vector3(side.x, floor_y + 0.1, side.z), float(i + 1) / 80.0)
			await physics_frame
		await frames(30)
		print("ROPE_SHOT carried back: holding=", grab.holding(me.peer_id))
		await snap("14_free_end_carried_back")
		grab.h_use("hook", 7)
		await frames(240)
		print("ROPE_SHOT tied: ", ck.lash_count(), " lashes=", ck.lashes.size())
		look(truck.global_position + Vector3(0, 3.6, -4.4), truck.global_transform * Vector3(0, 1.0, -0.8), 55.0)
		await snap("15_tied_across_the_bed")
		look(side + away * 2.6 + Vector3(0, 1.6, 2.4), ck.hook_at(2) + Vector3(0, -0.2, 0), 55.0)
		await snap("15b_tied_across_side_view")
	print("ROPE_SHOT_DONE")
	root.get_node("Sfx").silence_all()
	game.queue_free()
	await frames(8)
	quit(0)
