extends SceneTree
# 視点と表情えらびを確かめる：三人称はキャラの真後ろ（左右のずれ無し）／F2 で一人称（目の高さ・自分の体は自分にだけ見えない）
# ／一人称では自分の手と腕だけが自分の視点に映る（7人ぶん。first_person_arms.gd）
# ／F3 で表情の数だけ頭が並び、選ぶと表情が変わる（7人ぶん）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/view_test.gd
const FilmCamera := preload("res://scripts/film_camera.gd")
const FirstPersonArms := preload("res://scripts/first_person_arms.gd")
var game: Node
var me: Node
var id := 1
var failed := false


func _initialize() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("VIEW_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, 0.0)
	state[2] = false
	prop.restore(state)


func first(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			return game.props[pid]
	return null


func ahead(distance: float, up: float = 0.25) -> Vector3:
	return me.global_position + me.flat_forward() * distance + Vector3(0, up, 0)


# 表情の合図は、本当の時間で0.3秒あけないと続けて送れない
func wait_real(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		await physics_frame


# 本物のキー入力
func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	game.input_locked = false
	root.push_input(event)


# 物に照準を合わせる（視点カメラから物への向きへ、少しずつ寄せる）
func aim_at(prop: Node3D) -> bool:
	for step in 10:
		var to: Vector3 = prop.center_global() - me.cam.global_position
		me.aim_yaw = atan2(-to.x, -to.z)
		me.aim_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.0)
		await frames(3)
	await frames(4)
	return me.target == prop


# 照準の線（視点カメラの正面）と、点との距離
func line_gap(point: Vector3) -> float:
	var from: Vector3 = me.cam.global_position
	var dir: Vector3 = -me.cam.global_basis.z
	var to: Vector3 = point - from
	return (to - dir * to.dot(dir)).length()


# 体の部品（一人称の手の写しは数えない）
func body_meshes() -> Array:
	var out := []
	for mesh: MeshInstance3D in me.vis.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_parent().name != FirstPersonArms.NODE_NAME:
			out.append(mesh)
	return out


# 一人称の手の写し（左・右）
func arm_meshes() -> Array:
	if not is_instance_valid(me.arms) or not me.vis.is_ancestor_of(me.arms):
		return []
	return me.arms.get_children()


# 手の写しが、そのカメラに映るか（全部の部品について。写しが無ければ偽）
func arms_seen_by(camera: Camera3D) -> bool:
	var parts := arm_meshes()
	for arm: MeshInstance3D in parts:
		if not arm.is_visible_in_tree() or arm.layers & camera.cull_mask == 0:
			return false
	return parts.size() == 2


func arms_hidden_from(camera: Camera3D) -> bool:
	for arm: MeshInstance3D in arm_meshes():
		if arm.is_visible_in_tree() and arm.layers & camera.cull_mask != 0:
			return false
	return true


# 写しの三角形が、全部、腕の骨（付け根から先）に付いた頂点だけでできているか。頭・胴・足が混ざっていないか
func arms_only() -> bool:
	var skel: Skeleton3D = me.vis.skel
	var parts := arm_meshes()
	for arm: MeshInstance3D in parts:
		var arrays := arm.mesh.surface_get_arrays(0)
		var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var per: int = bones.size() / count
		if index.size() < 30:
			return false
		for i: int in index:
			var best := 0
			for j in per:
				if weights[i * per + j] > weights[i * per + best]:
					best = j
			var bind: int = bones[i * per + best]
			var bind_name := str(arm.skin.get_bind_name(bind))
			var bone: int = skel.find_bone(bind_name) if bind_name != "" else arm.skin.get_bind_bone(bind)
			var on_arm := false
			while bone >= 0:
				if skel.get_bone_name(bone) == "UPPER_ARM." + str(arm.name):
					on_arm = true
				bone = skel.get_bone_parent(bone)
			if not on_arm:
				return false
	return parts.size() == 2


# 画面に見える手首の場所（写しはずらして置くので、本体の手首とは違う所に来る）
func shown_wrist(side: String) -> Vector3:
	var skel: Skeleton3D = me.vis.skel
	var arm: MeshInstance3D = me.arms.get_node(side)
	var body: MeshInstance3D = me.arms.get_node(me.arms.get_meta("source") as NodePath)
	var real: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("HAND." + side)).origin
	return arm.global_transform * body.global_transform.affine_inverse() * real


# 手首が、視点の前・画面の下の側にあるか（左右とも）
func hands_in_front() -> bool:
	for side: String in ["L", "R"]:
		var local: Vector3 = me.cam.global_transform.affine_inverse() * shown_wrist(side)
		if local.z > -0.15 or local.z < -1.0 or local.y > 0.0 or absf(local.x) > 0.5:
			print("VIEW hand ", me.vis.tag, " ", side, " ", local)
			return false
	return true


# 自分の体が、そのカメラに映るか（全部の部品について）
func body_seen_by(camera: Camera3D) -> bool:
	for mesh: MeshInstance3D in body_meshes():
		if mesh.layers & camera.cull_mask == 0:
			return false
	return true


func body_hidden_from(camera: Camera3D) -> bool:
	for mesh: MeshInstance3D in body_meshes():
		if mesh.layers & camera.cull_mask != 0:
			return false
	return true


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._headless = true
	while not game.startup_complete:
		await process_frame
	await frames(40)
	me = game.local_player()
	id = me.peer_id
	game.h_accept_job(0)
	await frames(20)
	game.h_select_cast(game.PLAYER_CASTS.find("03"))
	await frames(6)
	me = game.local_player()

	# ---- 1：三人称はキャラの真後ろ ----
	check(not me.first_person, "はじめは三人称")
	var duck: Node = first("scrap_duck")
	var crate: Node = first("carton")
	check(duck != null and crate != null, "確かめに使う小物と箱がある")
	place(duck, ahead(2.2))
	await frames(30)
	var worst_side := 0.0
	var worst_gap := 9.0
	var head_below := true
	for pitch: float in [-1.2, -0.8, -0.4, 0.0, 0.5, 1.0]:
		me.aim_pitch = pitch
		await frames(4)
		var right: Vector3 = me.cam.global_basis.x
		worst_side = maxf(worst_side, absf((me.cam.global_position - me.global_position).dot(right)))
		worst_gap = minf(worst_gap, line_gap(me.vis.head_pos()))
		# キャラの頭は、照準（画面の中心）より下に映る
		var local: Vector3 = me.cam.global_transform.affine_inverse() * me.vis.head_pos()
		if pitch <= 0.5 and (local.y >= 0.0 or absf(local.x) > 0.02 or local.z >= 0.0):
			head_below = false
	check(worst_side < 0.01, "三人称：視点カメラが左右にずれていない（ずれ %.3f m）" % worst_side)
	check(worst_gap > 0.2, "三人称：照準の線がキャラの頭に重ならない（すき間 %.2f m）" % worst_gap)
	check(head_below, "三人称：キャラの頭は照準の真下に映る")
	me.aim_pitch = -0.25
	await frames(4)
	var back: float = (me.cam.global_position - me.global_position).dot(-me.flat_forward())
	check(back > 2.0, "三人称：視点カメラはキャラの後ろ（%.2f m）" % back)
	check(await aim_at(duck), "三人称：照準の先の小物を狙える")
	game.act_grab(duck.pid, duck.to_local(me.target_hit))
	await frames(20)
	check(duck.holder == id and me.held == duck.pid, "三人称：狙った小物を持てる")
	me.aim_yaw += 0.6
	await frames(40)
	var held_side: float = absf((me.cam.global_transform.affine_inverse() * duck.center_global()).x)
	check(held_side < 0.6, "三人称：持った物が画面の左右の真ん中あたりに来る（ずれ %.2f m）" % held_side)
	game.act_release()
	await frames(20)
	check(duck.holder == 0 and me.held == 0, "三人称：置ける")
	check(body_seen_by(me.cam), "三人称：自分の体が自分の画面に映る")
	check(arm_meshes().is_empty(), "三人称：手の写しは、まだ作られていない")

	# ---- 2：F2 で一人称 ----
	key(KEY_F2)
	await frames(6)
	check(me.first_person, "F2 で一人称になる")
	var eye: Vector3 = me.global_position + Vector3(0, me.eye_height(), 0)
	check(me.cam.global_position.distance_to(eye) < 0.03, "一人称：視点カメラが目の高さ（%.2f m）にある" % me.eye_height())
	me.aim_pitch = -1.0
	await frames(4)
	check(me.cam.global_position.distance_to(eye) < 0.03, "一人称：見下ろしても目の位置は動かない")
	check(body_hidden_from(me.cam), "一人称：自分の体は自分の視点に映らない")
	check(body_seen_by(game.film.view_cam), "一人称：自分の体は撮影カメラの層に残る")
	check(me.operator_cam.cull_mask & me.SELF_LAYER != 0, "一人称：カメラ操作の視点には体が映る")
	# 手：自分の視点にだけ、腕の写しが映る。撮影カメラ・カメラ操作の視点には映らない（体は本体が1つだけ映る）
	me.aim_pitch = -0.15
	for i in 30:
		await process_frame
	check(arms_seen_by(me.cam), "一人称：自分の視点に、手と腕（左・右）が映る")
	check(arms_only(), "一人称：映るのは腕の骨に付いた所だけ（頭・胴・足は入っていない）")
	check(arms_hidden_from(game.film.view_cam) and arms_hidden_from(me.operator_cam), "一人称：手の写しは、撮影カメラ・カメラ操作の視点には映らない（二重にならない）")
	check(hands_in_front(), "一人称：手ぶらの手が、視点の前・画面の下の側にある")
	var shadows := true
	for arm: MeshInstance3D in arm_meshes():
		if arm.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows = false
	check(shadows, "一人称：手の写しは影を落とさない（影は本体の1つだけ）")
	place(duck, ahead(1.8))
	await frames(30)
	check(await aim_at(duck), "一人称：目の高さから小物を狙える")
	game.act_grab(duck.pid, duck.to_local(me.target_hit))
	await frames(20)
	check(duck.holder == id, "一人称：持てる")
	for i in 40:
		await process_frame
	var far_real := 0.0
	var far_shown := 0.0
	for side: String in ["L", "R"]:
		var real: Vector3 = me.vis.skel.global_transform * me.vis.skel.get_bone_global_pose(me.vis.skel.find_bone("HAND." + side)).origin
		far_real = maxf(far_real, real.distance_to(duck.center_global()))
		far_shown = maxf(far_shown, shown_wrist(side).distance_to(duck.center_global()))
	check(far_shown < far_real - 0.05, "一人称：持つ構えの手が、持った物のそばへ寄る（%.2f m → %.2f m）" % [far_real, far_shown])
	var seen := true
	for mesh: MeshInstance3D in duck.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible and mesh.layers & me.cam.cull_mask == 0:
			seen = false
	check(seen, "一人称：持った物は見える層のまま")
	me.aim_yaw -= 0.7
	me.aim_pitch = -0.2
	await frames(50)
	var to_held: Vector3 = (duck.center_global() - me.cam.global_position).normalized()
	check(to_held.dot(-me.cam.global_basis.z) > 0.8, "一人称：持った物が視線について来て、画面の中にある")
	game.act_release()
	await frames(20)
	check(duck.holder == 0, "一人称：置ける")
	# 一人称のままキャラを替えても、体は隠れたまま
	game.h_select_cast(game.PLAYER_CASTS.find("M02"))
	await frames(6)
	me = game.local_player()
	check(me.first_person and body_hidden_from(me.cam) and body_seen_by(game.film.view_cam), "一人称：キャラを替えても体は自分にだけ映らない")
	# 7人ぶん：手の写しが作れる・腕だけ・体は撮影カメラに全部1つ
	for tag: String in game.PLAYER_CASTS:
		game.h_select_cast(game.PLAYER_CASTS.find(tag))
		await frames(10)
		me = game.local_player()
		me.aim_pitch = -0.15
		for i in 30:
			await process_frame
		check(me.vis.tag == tag and arms_seen_by(me.cam) and arms_only(), "%s：一人称で、腕だけの写しが自分の視点に映る" % tag)
		check(body_hidden_from(me.cam) and body_seen_by(game.film.view_cam) and arms_hidden_from(game.film.view_cam), "%s：頭や胴は自分に映らず、撮影カメラには体の全部が1つだけ映る" % tag)
		check(hands_in_front(), "%s：手ぶらの手が、視点の前・画面の下の側にある" % tag)
	game.h_select_cast(game.PLAYER_CASTS.find("M02"))
	await frames(10)
	me = game.local_player()
	# 撮影カメラの操作は一人称でも入れる・出ると元の視点へ戻る
	var film: Node = game.film
	place(film, ahead(1.6, 0.05))
	await frames(40)
	game.act_operate(film.pid, true)
	await frames(10)
	for i in 4:
		await process_frame
	check(me.operating == film.pid and me.operator_cam.current, "一人称：撮影カメラを操作できる")
	check(arms_hidden_from(me.operator_cam) and not me.arms.visible, "一人称：カメラ操作の間、手の写しは出ない")
	game.act_operate(film.pid, false)
	await frames(10)
	for i in 4:
		await process_frame
	check(me.operating == 0 and me.cam.current and me.first_person, "一人称：カメラ操作を終えると一人称へ戻る")
	check(arms_seen_by(me.cam), "一人称：カメラ操作を終えると、手がまた映る")
	key(KEY_F2)
	await frames(6)
	back = (me.cam.global_position - me.global_position).dot(-me.flat_forward())
	check(not me.first_person and body_seen_by(me.cam) and me.arm.spring_length > 3.0, "F2 でもう一度押すと三人称へ戻る")
	for i in 4:
		await process_frame
	check(not arm_meshes().is_empty() and arms_hidden_from(me.cam) and arms_hidden_from(game.film.view_cam), "三人称へ戻すと、手の写しは隠れる（体は本体だけ）")

	# ---- 3：F3 で表情の頭が並ぶ ----
	var picker: Node = me.face_picker
	var crew_layer: int = FilmCamera.CREW_LAYER
	for tag: String in game.PLAYER_CASTS:
		game.h_select_cast(game.PLAYER_CASTS.find(tag))
		await frames(10)
		await wait_real(350)
		me = game.local_player()
		picker = me.face_picker
		var want := 0
		for face: String in picker.ORDER:
			if me.vis.face_anim != null and me.vis.face_anim.has_animation(face):
				want += 1
		var yaw_before: float = me.aim_yaw
		key(KEY_F3)
		await frames(4)
		var shown := 0
		var on_crew := true
		var seen_faces := {}
		for slot: Node in picker._slots:
			var head: Node = slot.get_child(0)
			seen_faces[head.face] = true
			var parts := 0
			for mesh: MeshInstance3D in head.find_children("*", "MeshInstance3D", true, false):
				if not mesh.visible:
					continue
				parts += 1
				if mesh.layers != crew_layer or mesh.layers & game.film.view_cam.cull_mask != 0:
					on_crew = false
			if parts > 0:
				shown += 1
		check(picker.opened and want >= 5 and shown == want and seen_faces.size() == want, "%s：F3 で表情の数だけ頭が並ぶ（%d個）" % [tag, shown])
		check(on_crew, "%s：並んだ頭は撮影カメラに映らない層" % tag)
		# マウスを右へ：となりの頭へ移る（視点は回らない）
		picker.select(0)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(picker.MOUSE_STEP * 2.0, 0)
		me._handle_gameplay_input(motion)
		check(picker.index == 2 and is_equal_approx(me.aim_yaw, yaw_before), "%s：マウスの左右で頭を選ぶ（視点は回らない）" % tag)
		await frames(20)
		var slot_now: Node3D = picker._slots[2]
		var slot_other: Node3D = picker._slots[0]
		check(slot_now.scale.x > slot_other.scale.x * 1.3, "%s：選んだ頭は大きく見える" % tag)
		key(KEY_4)
		check(picker.index == 3, "%s：数字キーで頭を選ぶ" % tag)
		var chosen: String = picker.faces[picker.index]
		key(KEY_F3, false)
		await frames(6)
		check(not picker.opened and not picker.visible and me.vis.face == chosen, "%s：F3 を離すと選んだ表情（%s）になる" % [tag, chosen])
	# いちばん背の高いキャラ（帽子の羽根）でも、てっぺんが照準より下に映る
	me.aim_pitch = -0.15
	await frames(6)
	var tip := 0.0
	for mesh: MeshInstance3D in me.vis.find_children("*", "MeshInstance3D", true, false):
		tip = maxf(tip, (me.vis.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()).end.y)
	var tip_local: Vector3 = me.cam.global_transform.affine_inverse() * (me.global_position + Vector3(0, tip, 0))
	check(me.vis.tag == "06" and tip > 2.3 and tip_local.y < -0.1, "背の高いキャラでも、てっぺん（%.2f m）が照準より下に映る" % tip)
	# ホイールと左クリックでも選べる
	await wait_real(350)
	key(KEY_F3)
	await frames(2)
	picker.select(0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	me._handle_gameplay_input(wheel)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var wheel_face: String = picker.faces[1]
	me._handle_gameplay_input(click)
	await frames(6)
	check(not picker.opened and me.vis.face == wheel_face and me.held == 0, "ホイールで移り、左クリックで決まる（物はつかまない）")
	# 窓を開いている間は並ばない
	game.set_character_menu(true)
	key(KEY_F3)
	await frames(2)
	check(not picker.opened, "ほかの画面を開いている間は並ばない")
	key(KEY_F3, false)
	game.set_character_menu(false)

	print("VIEW_TEST_OK" if not failed else "VIEW_TEST_FAIL")
	quit(0 if not failed else 1)
