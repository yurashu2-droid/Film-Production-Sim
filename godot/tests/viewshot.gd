extends SceneTree
# 視点と表情えらびの画面を撮る：三人称（手ぶら・大きい物・小物）／一人称（手ぶら・物を持つ）／F3 で頭が並んだ所。
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tests/viewshot.gd
#   画面つきで動かす（窓は画面の外に出し、マウスも捕まえない）。出力は tests/shots/view
#   一人称の手だけを撮る：最後に「-- --arms」を付ける（7人ぶんを、8コマずつ1枚にまとめた arms_*.png）
const OUT := "res://tests/shots/view/"
var game: Node
var me: Node


func _initialize() -> void:
	root.unfocusable = true
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func snap(tag: String, wait: int = 12) -> void:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	print("VIEWSHOT ", tag)


func first(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			return game.props[pid]
	return null


func place(prop: Node, pos: Vector3) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, 0.0)
	state[2] = false
	prop.restore(state)


func ahead(distance: float, up: float = 0.25) -> Vector3:
	return me.global_position + me.flat_forward() * distance + Vector3(0, up, 0)


func aim_at(prop: Node3D) -> bool:
	for step in 10:
		var to: Vector3 = prop.center_global() - me.cam.global_position
		me.aim_yaw = atan2(-to.x, -to.z)
		me.aim_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.0)
		await frames(3)
	await frames(4)
	return me.target == prop


func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	game.input_locked = false
	root.push_input(event)


func pick(tag: String) -> void:
	game.h_select_cast(game.PLAYER_CASTS.find(tag))
	await frames(8)
	me = game.local_player()


# 物を前に置いて、狙って持ち、視線を水平に戻して撮る。pull が真なら G で手元へ寄せる
func hold_shot(prop: Node, tag: String, pull: bool) -> void:
	place(prop, ahead(2.0))
	await frames(40)
	var ok: bool = await aim_at(prop)
	print("VIEWSHOT aim ", tag, " ", ok)
	game.act_grab(prop.pid, prop.to_local(me.target_hit) if ok else null)
	await frames(20)
	if pull:
		game.act_hold_command("pull")
		await frames(10)
	me.aim_pitch = -0.15
	await frames(50)
	await snap(tag)
	game.act_release()
	await frames(20)
	place(prop, me.global_position + Vector3(6, 0.3, 6))
	await frames(5)


# ---- 一人称の手（first_person_arms.gd）----

const CELL := Vector2i(800, 450)


func screen(wait: int = 12) -> Image:
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


# 何コマかを1枚にまとめる（左上から右へ、2列）
func sheet(tag: String, pictures: Array) -> void:
	var out := Image.create(CELL.x * 2, CELL.y * ((pictures.size() + 1) / 2), false, Image.FORMAT_RGB8)
	for i in pictures.size():
		var picture: Image = pictures[i]
		if picture == null:
			continue
		picture.convert(Image.FORMAT_RGB8)
		picture.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(picture, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 2) * CELL.x, (i / 2) * CELL.y))
	out.save_png(OUT + tag + ".png")
	print("VIEWSHOT ", tag)


func take(prop: Node, pull: bool) -> void:
	place(prop, ahead(2.0))
	await frames(40)
	var ok: bool = await aim_at(prop)
	game.act_grab(prop.pid, prop.to_local(me.target_hit) if ok else null)
	await frames(20)
	if pull:
		game.act_hold_command("pull")
		await frames(10)
	me.aim_pitch = -0.15
	await frames(50)
	print("VIEWSHOT take ", prop.kind, " aim=", ok, " held=", me.held == prop.pid, " anim=", me.vis.current)


func drop(prop: Node) -> void:
	game.act_release()
	await frames(20)
	place(prop, me.global_position + Vector3(6, 0.3, 6))
	await frames(5)


# 同じ瞬間の、撮影カメラの絵（自分の正面に置いて、こちらへ向ける）
func film_picture() -> Image:
	var film: Node = game.film
	place(film, ahead(3.2, 0.05))
	await frames(30)
	film.cam_yaw = 0.0
	var to_me: Vector3 = me.global_position - film.global_position
	film.global_rotation.y = atan2(-to_me.x, -to_me.z)
	await frames(20)
	await RenderingServer.frame_post_draw
	var picture: Image = film.view.get_texture().get_image()
	place(film, me.global_position + Vector3(-6, 0.1, 6))
	await frames(10)
	return picture


func arms_shots() -> void:
	var home: Vector3 = me.global_position
	var big: Node = first("carton")
	var small: Node = first("clapper")
	if not me.first_person:
		key(KEY_F2)
	for tag: String in game.PLAYER_CASTS:
		await pick(tag)
		me.global_position = home
		me.velocity = Vector3.ZERO
		me.aim_yaw = 0.0
		me.aim_pitch = -0.15
		await frames(30)
		var pictures := []
		pictures.append(await screen())                 # 1：手ぶら・正面
		me.aim_pitch = -0.9
		await frames(10)
		pictures.append(await screen())                 # 2：手ぶら・見下ろす
		me.aim_pitch = -0.15
		Input.action_press("move_forward")
		await frames(40)
		pictures.append(await screen(2))                # 3：歩く
		await frames(7)
		pictures.append(await screen(2))                # 4：歩く（少しあと。腕の振りが分かる）
		me.global_position = home
		Input.action_press("run")
		await frames(55)
		pictures.append(await screen(2))                # 5：走る
		Input.action_release("move_forward")
		Input.action_release("run")
		await frames(30)
		me.global_position = home
		await frames(10)
		await take(big, true)
		pictures.append(await screen())                 # 6：大きい物を手元に持つ
		await drop(big)
		await take(small, true)
		pictures.append(await screen())                 # 7：片手の小物を手元に持つ
		pictures.append(await film_picture())           # 8：同じ瞬間の撮影カメラ
		await drop(small)
		await sheet("arms_" + tag, pictures)
	# 道具とロープ（2人ぶん）
	for tag: String in ["03", "M02"]:
		await pick(tag)
		me.global_position = home
		me.aim_yaw = 0.0
		me.aim_pitch = -0.15
		await frames(30)
		var extra := []
		var kit: Node = game.get("bomb_kit")
		var grab: Node = game.get("rope_grab")
		if kit != null and grab != null:
			var right := Vector3(-me.flat_forward().z, 0.0, me.flat_forward().x)
			var a: Vector3 = me.global_position + me.flat_forward() * 1.0 - right + Vector3(0, 0.03, 0)
			var id: int = kit.host_add_scrap(PackedVector3Array([a, a + right * 2.0]), 2.0)
			await frames(90)
			grab.h_grab(grab.CORD, id, 1.0)
			await frames(100)
			print("VIEWSHOT rope ", tag, " holding=", grab.holding(me.peer_id), " anim=", me.vis.current)
			extra.append(await screen())                # 1：ロープの途中をつかむ
			me.aim_pitch = -0.7
			await frames(20)
			extra.append(await screen())                # 2：つかんだまま見下ろす
			me.aim_pitch = -0.15
			grab.h_release()
			await frames(20)
		else:
			extra.append(null)
			extra.append(null)
		var tools := [first("glue"), kit.scissors if kit != null else null, null]
		if kit != null and not kit.sacks.is_empty() and kit.sacks[0].visible:
			tools[2] = kit.sacks[0]
		for tool: Variant in tools:
			if tool == null:
				extra.append(null)
				continue
			await take(tool, true)
			extra.append(await screen())                # 3〜5：接着剤・はさみ・火薬の袋
			await drop(tool)
		await take(big, false)
		extra.append(await screen())                    # 6：大きい物を、つかんだ所のまま持つ
		await drop(big)
		await sheet("arms_tools_" + tag, extra)
	key(KEY_F2)
	await frames(10)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true
	while not game.startup_complete:
		await process_frame
	await frames(40)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	me = game.local_player()
	if "--arms" in OS.get_cmdline_user_args():
		# 手だけを撮る：火薬の袋も出るよう、爆破を注文した怪獣映画の仕事で
		var job := 0
		for i in game.production.JOBS.size():
			if game.production.JOBS[i]["script"] == "kaiju":
				job = i
				break
		game.h_accept_job(job)
		game.h_open_order()
		game.h_order_set("fx", 1)
		game.h_order_confirm()
		await frames(30)
		await pick("03")
		me.cam.make_current()
		await arms_shots()
		print("VIEWSHOT_DONE")
		quit(0)
		return
	game.h_accept_job(0)
	await frames(20)
	await pick("03")
	me.cam.make_current()
	var kinds := []
	for pid: int in game.props:
		kinds.append(game.props[pid].kind)
	print("VIEWSHOT kinds ", kinds)
	var big: Node = first("carton")
	var small: Node = first("clapper")
	var mid: Node = first("scrap_duck")

	# 三人称
	me.aim_pitch = -0.15
	await frames(20)
	await snap("1_third_empty")
	me.aim_pitch = -0.9
	await frames(10)
	await snap("1_third_look_down")
	me.aim_pitch = 0.5
	await frames(10)
	await snap("1_third_look_up")
	await hold_shot(big, "2_third_big_grab", false)
	await hold_shot(big, "2_third_big_pull", true)
	await hold_shot(small, "3_third_small_pull", true)
	await hold_shot(mid, "3_third_mid_grab", false)

	# 一人称
	key(KEY_F2)
	me.aim_pitch = -0.15
	await frames(20)
	await snap("4_first_empty")
	me.aim_pitch = -1.1
	await frames(10)
	await snap("4_first_look_down")
	await hold_shot(big, "5_first_big_grab", false)
	await hold_shot(big, "5_first_big_pull", true)
	await hold_shot(small, "5_first_small_pull", true)
	# 一人称のとき、撮影カメラには自分が映る
	await RenderingServer.frame_post_draw
	place(game.film, ahead(3.0, 0.05))
	await frames(30)
	game.film.cam_yaw = 0.0
	var to_me: Vector3 = me.global_position - game.film.global_position
	game.film.global_rotation.y = atan2(-to_me.x, -to_me.z)
	await frames(20)
	await RenderingServer.frame_post_draw
	game.film.view.get_texture().get_image().save_png(OUT + "6_first_film_camera.png")
	print("VIEWSHOT 6_first_film_camera")
	place(game.film, me.global_position + Vector3(-6, 0.1, 6))
	await frames(10)
	me.aim_pitch = -0.15
	key(KEY_F3)
	await frames(30)
	await snap("7_faces_first_03")
	key(KEY_F3, false)
	key(KEY_F2)
	await frames(10)

	# F3：頭が並んだ所（キャラごと）
	for tag: String in ["03", "M02", "04", "09", "01", "02", "06"]:
		await pick(tag)
		me.aim_pitch = -0.15
		await frames(30)
		key(KEY_F3)
		await frames(6)
		me.face_picker.select(1 if tag != "M02" else 3)
		await frames(30)
		await snap("8_faces_" + tag)
		# 撮影カメラには映らないこと（最初のキャラだけ撮る）
		key(KEY_F3, false)
		await frames(30)
	await arms_shots()
	print("VIEWSHOT_DONE")
	quit(0)
