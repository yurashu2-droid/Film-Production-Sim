extends SceneTree
# キャラの特技を確かめる：7人ぶんの表 → 段ボール頭「頭の道具箱」（しまう・出す・運ぶ・こぼれる・見返し・撮り直し・帰社）
# → ロボット「おなかランプ」（点ける・採点の明るさ・消す） → 手帳の人「台本の写し」（台本を持たずにページを開く）。
# 会社での準備中に、あとの4人（TALENT4）：ドレスの人「ショール」・カエルの警官「止まれ！」・ベレー帽の人「びよーん首」・モップの王様「毛ひも」。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/cast_talent_test.gd
const Talents := preload("res://scripts/cast_talents.gd")
const Roles := preload("res://scripts/production_cast.gd")
const FilmCamera := preload("res://scripts/film_camera.gd")
const CASTS := ["M02", "04", "09", "03", "01", "02", "06"]
var game: Node
var flow: Node
var talent: Node
var me: Node
var id := 1
var failed := false


func _initialize() -> void:
	create_timer(420).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CAST_TALENT_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = false) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = fixed
	prop.restore(state)


func first(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			return game.props[pid]
	return null


# 自分の少し前（向いている先）
func ahead(distance: float, side: float = 0.0) -> Vector3:
	var forward: Vector3 = me.flat_forward()
	return me.global_position + forward * distance + Vector3(-forward.z, 0, forward.x) * side + Vector3(0, 0.25, 0)


# その物を手に持ってから K（しまえる物なら頭に入る）
func stow_held(prop: Node) -> void:
	place(prop, ahead(1.3))
	await frames(3)
	game.h_grab(prop.pid)
	await frames(2)
	talent.host_use(id)
	await frames(2)


# 本物のキー入力（production_main.gd の _input を通る）
func key(code: int, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.shift_pressed = shift
	event.pressed = true
	game.input_locked = false
	root.push_input(event)


func pick(kind: String) -> void:
	game.h_select_cast(game.PLAYER_CASTS.find(kind))
	await frames(3)


func has_digit(text: String) -> bool:
	for ch: String in text:
		if (ch >= "0" and ch <= "9") or (ch >= "０" and ch <= "９"):
			return true
	return false


# 物に照準を合わせる（カメラは後ろにあるので、カメラから物への向きに、少しずつ寄せる）。合ったかどうかを返す
func aim_at(prop: Node3D) -> bool:
	for step in 12:
		var to: Vector3 = prop.center_global() - me.cam.global_position
		me.aim_yaw = atan2(-to.x, -to.z)
		me.aim_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.0)
		await frames(3)
	await frames(3)
	return me.target == prop


# 制作班にだけ見える文字（頭の上の吹き出し・物の上の札）のうち、その文の物
func words(text: String) -> Array:
	var out: Array = []
	for node: Node in game.get_children():
		if node is Label3D and (node as Label3D).text == text:
			out.append(node)
	return out


# 軽トラから見た、物の真ん中
func on_truck(prop: Node3D) -> Vector3:
	return game.truck.global_transform.affine_inverse() * prop.center_global()


# そのフックの外側に立って、軽トラのほうを向く。手に持っている物は、手元へ持ってくる
func stand_at(hook: int) -> void:
	var truck: Node3D = game.truck
	var local: Vector3 = truck.hooks[hook]
	var spot: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
	var to: Vector3 = game.cargo_kit.hook_at(hook) - spot
	me.global_position = Vector3(spot.x, truck.global_position.y + 0.1, spot.z)
	me.aim_yaw = atan2(-to.x, -to.z)
	me.aim_pitch = -0.1
	await frames(3)
	var held: Node = game.props.get(me.held)
	if held != null:
		held.restore([me.global_position + Vector3(0, 1.0, 0) + me.flat_forward() * 1.0, Quaternion.IDENTITY, false])
		talent._hand_over(id, held)
		await frames(6)


# 荷台の西側に立って、目の前に持った物を F で積む（carton_rope_test.gd と同じやり方）
func load_by_hand(prop: Node, along: float) -> bool:
	var truck: Node3D = game.truck
	var box: AABB = game.body_bounds(prop)
	me.global_position = truck.global_transform * Vector3(-2.9, 0.1, along + box.size.z * 0.5 + 1.6)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(-(1.5 + box.size.x * 0.5) - box.get_center().x, 0.5 - box.position.y, along - box.get_center().z), Quaternion.IDENTITY, false])
	await frames(2)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(3)
	if prop.rider_of != truck.pid and prop.holder != 0:
		game.h_release()
	return prop.rider_of == truck.pid


# あとの4人の特技（会社での準備中に確かめる）。荷台に毛ひもで押さえた箱を残して返す（道中で動かないことを、あとで確かめる）
func four_more(toilet: Node, pie: Node, plunger: Node, chicken: Node, rose: Node) -> Array:
	var kit: Node = game.cargo_kit
	var texts: Array = []          # 案内の文（数字が無いことを、最後に確かめる）
	me.global_position = flow.HOME_TRUCK + Vector3(-6, 0.1, 6)
	me.aim_yaw = 0.0
	me.aim_pitch = -0.25
	await frames(4)

	# ---- TALENT4-1 ドレスの人「ショールをかける」 ----
	await pick("01")
	await frames(4)
	var story: String = flow.story()
	var bad_role := ""
	for role: String in Roles.roles_for(story):
		if flow.cast_fit(toilet, role) == 0 and role != "boom":
			bad_role = role
	var good: Node = null
	var good_role := ""
	for prop: Node in game.props.values():
		if prop.absent or not Roles.castable(prop.kind) or prop == toilet or prop.kind == "fx":
			continue
		for role: String in Roles.roles_for(story):
			if good == null and flow.cast_fit(prop, role) == 2:
				good = prop
				good_role = role
	check(bad_role != "" and good != null, "there is a role the toilet is forced into (%s) and a prop that is perfect for a role (%s as %s)" % [bad_role, good.kind if good else "-", good_role])
	check(talent.shawls_left(id) == Talents.SHAWL_COUNT and talent.shown_shawls_left(id) == 2, "the dress wearer starts with two shawls")
	place(toilet, ahead(1.8))
	place(good, ahead(2.2, 1.6))
	place(pie, ahead(1.6, -1.4))
	await frames(20)
	flow.cast_set(toilet.pid, bad_role)
	var coins_plain: int = flow.cast_sheet()["coins"]
	me.target = toilet
	texts.append(str(talent.hint(me)["keys"]))
	check(str(talent.hint(me)["keys"]) == "K ショールをかける", "looking at a prop offers: K, put the shawl on")
	talent.host_use(id, toilet.pid)
	await frames(4)
	check(talent.shawled(toilet.pid) and "shawl" in flow.cast_tags(toilet), "K puts a shawl on the prop aimed at")
	check(flow.cast_fit(toilet, bad_role) == 1, "a forced fit (0) becomes a plausible one (1)")
	check(int(flow.cast_sheet()["coins"]) > coins_plain, "the casting sheet total goes up (%d -> %d)" % [coins_plain, int(flow.cast_sheet()["coins"])])
	var cloth: Node = toilet.get_node_or_null("TalentShawl")
	check(cloth is MeshInstance3D and (cloth as MeshInstance3D).layers == 1 and toilet.find_children("*", "CollisionShape3D", true, false).all(func(c: Node) -> bool: return c.get_parent() != cloth), "a cloth lies on the prop: on the film layer, with no collision")
	var cloth_box: AABB = (cloth as MeshInstance3D).get_aabb()
	check(cloth_box.end.y >= toilet.center.y + toilet.half.y and cloth_box.position.y < toilet.center.y + toilet.half.y - 0.1 and cloth_box.size.x > toilet.half.x * 2.0, "it covers the top and hangs down the sides (%.2f m down)" % (toilet.center.y + toilet.half.y - cloth_box.position.y))
	check(talent.shawls_left(id) == 1 and talent.shown_shawls_left(id) == 1, "one shawl is left")
	me.target = toilet
	texts.append(str(talent.hint(me)["keys"]))
	check(str(talent.hint(me)["keys"]) == "K ショールを外す", "looking at a covered prop offers: K, take the shawl off")
	talent.host_use(id, good.pid)
	await frames(4)
	check(talent.shawled(good.pid) and flow.cast_fit(good, good_role) == 2, "a perfect fit (2) stays perfect under a shawl")
	check(Roles.fit(toilet.kind, bad_role, ["shawl"]) == 1 and Roles.attrs(toilet.kind, ["shawl"]) == Roles.attrs(toilet.kind), "the shawl adds no attribute")
	var joker := ""
	for kind: String in Roles.PROPS:
		if Roles.is_joker(kind):
			joker = kind
	check(joker != "" and Roles.fit(joker, bad_role, ["blank"]) == 0 and Roles.fit(joker, bad_role, ["blank", "shawl"]) == 1, "a blank life-size panel under a shawl is plausible too")
	check(talent.shawls_left(id) == 0 and talent.shown_shawls_left(id) == 0, "with both shawls out, none are left")
	talent.host_use(id, pie.pid)
	await frames(4)
	check(not talent.shawled(pie.pid) and "もう無い" in talent.shawl_refusal(id, pie), "a third shawl is refused")
	check(talent.shawl_refusal(id, game.clapper) != "" and not Roles.castable(game.clapper.kind), "a prop that cannot be cast is refused")
	talent.host_use(id, toilet.pid)
	await frames(4)
	check(not talent.shawled(toilet.pid) and flow.cast_fit(toilet, bad_role) == 0 and toilet.get_node_or_null("TalentShawl") == null, "K on the covered prop takes the shawl off, and the fit is forced again")
	check(talent.shawls_left(id) == 1 and talent.shown_shawls_left(id) == 1 and int(flow.cast_sheet()["coins"]) == coins_plain, "the shawl is back")
	game.h_grab(pie.pid)
	await frames(3)
	check(talent.shawl_refusal(id, pie) != "", "a prop someone holds is refused")
	me.target = toilet
	key(KEY_K)
	await frames(4)
	check(talent.shawled(toilet.pid) and me.held == pie.pid, "the K key puts the shawl on the prop aimed at, even with something in the hand")
	game.h_release()
	await frames(3)
	# 風・爆風：布がずれる。ずれきったら飛ぶ（効果も消える）
	talent.rng.seed = 7
	var unslid: int = toilet.get_node("TalentShawl").get_instance_id()
	talent.host_shawl_push(toilet.pid, Vector3(0.4, 0, 0))
	await frames(4)
	var slid: Node = toilet.get_node_or_null("TalentShawl")
	check(talent.shawled(toilet.pid) and is_equal_approx(float(talent.shawls[toilet.pid][1]), 0.4) and slid != null and slid.get_instance_id() != unslid, "a push slides the cloth to one side (it is redrawn)")
	check(absf((slid as MeshInstance3D).get_aabb().get_center().x - toilet.center.x) > 0.05 or absf((slid as MeshInstance3D).get_aabb().get_center().z - toilet.center.z) > 0.05, "the slid cloth hangs off-centre")
	var lost_before: int = int(talent.shawl_lost.get(id, 0))
	talent.host_shawl_push(toilet.pid, Vector3(0.7, 0, 0))
	await frames(4)
	var landed: Array = talent.shawls.keys().filter(func(pid: int) -> bool: return pid != good.pid and pid != toilet.pid)
	print("CAST_TALENT shawl blown off: landed on %s, lost %d" % [str(landed.map(func(pid: int) -> String: return str(game.props[pid].kind))), int(talent.shawl_lost.get(id, 0)) - lost_before])
	check(not talent.shawled(toilet.pid) and flow.cast_fit(toilet, bad_role) == 0, "pushed too far, the cloth flies off and its effect is gone")
	check(landed.size() + int(talent.shawl_lost.get(id, 0)) - lost_before == 1 and talent.shawls_left(id) == 0, "it either catches on a prop downwind or is lost; it does not come back to the shoulder")
	var slips: Dictionary = {}
	for pid: int in talent.shawls:
		slips[pid] = float(talent.shawls[pid][1])
	check(flow.gust(Vector3(1, 0, 0.2), 1.0) >= 0, "a gust blows")
	await frames(4)
	var stirred := true
	for pid: int in slips:
		stirred = stirred and (not talent.shawled(pid) or float(talent.shawls[pid][1]) > float(slips[pid]))
	check(stirred and not slips.is_empty(), "a gust shifts every cloth that is out")
	for pid: int in talent.shawls.keys():
		talent.host_shawl_push(pid, Vector3(0, 0, 0.05))
	talent.on_burst(good.center_global() + Vector3(0.5, 0, 0), 1.0)
	await frames(4)
	print("CAST_TALENT shawls after the blast: %s lost %s" % [str(talent.shawls), str(talent.shawl_lost)])
	# 次の依頼を受けるときの片付けで、全部肩に戻る
	talent.host_clear_all()
	await frames(4)
	check(talent.shawls.is_empty() and talent.shawls_left(id) == 2 and talent.shown_shawls_left(id) == 2 and good.get_node_or_null("TalentShawl") == null, "clearing for a new job brings both shawls back to the shoulders")
	flow.cast_set(toilet.pid, "")
	place(toilet, flow.HOME_TRUCK + Vector3(-12, 0.3, 9))
	place(good, flow.HOME_TRUCK + Vector3(-13, 0.3, 11))

	# ---- TALENT4-2 カエルの警官「止まれ！」 ----
	await pick("02")
	me.global_position = flow.HOME_TRUCK + Vector3(-6, 0.1, 6)
	me.aim_yaw = 0.0
	await frames(6)
	texts.append(str(talent.hint(me)["keys"]))
	check(str(talent.hint(me)["keys"]) == "K 止まれ！" and is_equal_approx(talent.halt_ready(id), 1.0), "the frog officer is offered K, and the paddle on the back is up")
	var paddle: Node3D = me.vis.skel.get_node("TalentPaddle/Hinge")
	check(absf(paddle.rotation.x) < 0.05, "the red paddle stands upright")
	check(Talents.in_halt_fan(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -4.9)) and Talents.in_halt_fan(Vector3.ZERO, Vector3.FORWARD, Vector3(3.3, 0, -3.5)), "the fan reaches five metres and 45 degrees")
	check(not Talents.in_halt_fan(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -5.2)) and not Talents.in_halt_fan(Vector3.ZERO, Vector3.FORWARD, Vector3(3.6, 0, -3.3)) and not Talents.in_halt_fan(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 3.0)), "not farther, not wider, not behind")
	var riser: Node = first("riser")
	place(chicken, ahead(3.0) + Vector3(0, 4.0, 0))          # 扇形の中：落ちてくる
	place(pie, ahead(3.0, 5.2) + Vector3(0, 4.0, 0))         # 横に外れている
	place(plunger, ahead(-3.0) + Vector3(0, 4.0, 0))         # 後ろ
	place(riser, ahead(2.0, -1.2), 0.0, true)                # 扇形の中だが、固定してある
	game.h_grab(rose.pid)                                   # 手に持っている物
	await frames(10)
	check(chicken.linear_velocity.y < -0.8 and chicken.gravity_scale == 1.0, "a chicken is falling in front (%.1f m/s)" % chicken.linear_velocity.y)
	talent.host_use(id)
	await frames(2)
	var stopped_at: Vector3 = chicken.global_position
	check(talent.halted(chicken.pid) and chicken.linear_velocity.length() < 0.01 and chicken.gravity_scale == 0.0, "K stops it dead in mid-air")
	check(not talent.halted(pie.pid) and not talent.halted(plunger.pid) and not talent.halted(rose.pid) and not talent.halted(riser.pid) and not talent.halted(game.truck.pid), "things to the side, behind, in the hand, fixed, and the truck are not stopped")
	var bubble: Array = words("止まれ！")
	var snaps: Array = words("ぴたっ")
	check(bubble.size() == 1 and (bubble[0] as Label3D).layers == FilmCamera.CREW_LAYER and (bubble[0] as Label3D).global_position.y > me.global_position.y + 1.5, "a speech bubble pops over the head, for the crew only")
	check(snaps.size() >= 1 and snaps.all(func(l: Label3D) -> bool: return l.layers == FilmCamera.CREW_LAYER) and snaps.any(func(l: Label3D) -> bool: return l.global_position.distance_to(chicken.center_global()) < 1.0), "and a small tag on the stopped prop")
	check(flow.gust(Vector3(1, 0, 0), 3.0) >= 0, "a strong gust blows while it is stopped")
	await frames(58)
	check(chicken.global_position.distance_to(stopped_at) < 0.02 and chicken.global_position.y > me.global_position.y + 2.0, "one second later it has not moved, gust or not (%.3f m)" % chicken.global_position.distance_to(stopped_at))
	check(pie.global_position.y < me.global_position.y + 1.5 and plunger.global_position.y < me.global_position.y + 1.5, "the others fell")
	check(talent.halt_ready(id) < 0.3 and paddle.rotation.x < -0.8, "the paddle has dropped behind the back")
	place(pie, ahead(2.5) + Vector3(0, 4.0, 0))
	await frames(6)
	talent.host_use(id)
	await frames(2)
	check(not talent.halted(pie.pid) and words("止まれ！").size() <= 1, "it cannot be used again right away")
	await frames(80)
	check(not talent.halted(chicken.pid) and chicken.gravity_scale == 1.0 and chicken.global_position.y < stopped_at.y - 0.5, "after two seconds the chicken falls again, with its gravity back")
	game.h_release()
	await frames(300)
	check(talent.halt_ready(id) > 0.9 and talent.halt_ready(id) < 1.0 and paddle.rotation.x > -0.3, "the paddle rises slowly (%.2f)" % talent.halt_ready(id))
	await frames(40)
	check(is_equal_approx(talent.halt_ready(id), 1.0), "after eight seconds it is ready again")
	place(chicken, ahead(2.5) + Vector3(0, 3.0, 0))
	await frames(8)
	talent.host_use(id)
	await frames(3)
	check(talent.halted(chicken.pid), "it stops a prop again")
	check(me.vis.current == "halt" or not me.vis.has("halt"), "with the halt motion")
	game.h_grab(chicken.pid)
	await frames(3)
	check(not talent.halted(chicken.pid) and me.held == chicken.pid, "grabbing a stopped prop frees it")
	game.h_release()
	await frames(70)
	check(chicken.gravity_scale == 1.0 and chicken.global_position.y < me.global_position.y + 1.5, "let go, it falls as usual")
	place(riser, flow.HOME_TRUCK + Vector3(-14, 0.2, 13))

	# ---- TALENT4-3 ベレー帽の人「びよーん首」 ----
	await pick("04")
	me.global_position = flow.HOME_TRUCK + Vector3(-6, 0.1, 6)
	me.aim_yaw = 0.0
	me.aim_pitch = -0.25
	await frames(10)
	texts.append(str(talent.hint(me)["keys"]))
	check(str(talent.hint(me)["keys"]) == "K 首を伸ばす" and is_equal_approx(me.head.position.y, 1.85) and me.neck == 0.0, "the beret wearer is offered K, with the neck at rest")
	var cam_low: float = me.cam.global_position.y
	# 高い所の物：首を伸ばさないと、手が届かない
	place(chicken, me.global_position + me.flat_forward() * 1.0 + Vector3(0, 5.05 - chicken.center.y, 0), 0.0, true)
	await frames(4)
	check(not await aim_at(chicken), "a prop five metres up is out of reach")
	var monitor: Node3D = flow.monitor_prop
	var monitor_level: int = int(flow.levels.get("monitor", 0))
	flow.levels["monitor"] = 0
	var far_spot: Vector3 = monitor.global_position + Vector3(-5.0, 0, 0)
	far_spot.y = me.global_position.y
	var here: Vector3 = me.global_position
	me.global_position = far_spot
	check(not monitor.absent and not flow.near_monitor(me), "five metres from the review monitor is too far to look at it")
	me.global_position = here
	talent.host_use(id)
	me.aim_yaw = 0.0
	me.aim_pitch = -0.25
	await frames(40)
	texts.append(str(talent.hint(me)["keys"]))
	check(talent.neck_out(id) and str(talent.hint(me)["keys"]) == "K 首を戻す", "K stretches the neck")
	check(is_equal_approx(me.neck, Talents.NECK_RISE) and absf(me.cam.global_position.y - cam_low - Talents.NECK_RISE) < 0.05, "the view rises half a metre (%.2f m)" % (me.cam.global_position.y - cam_low))
	var lift: Node = me.vis.skel.get_node_or_null("TalentNeck")
	check(lift != null and absf(float(lift.rise) * me.vis.SCALE - Talents.NECK_RISE) < 0.01 and lift.get_parent() == me.vis.skel, "the head bone is lifted by the same height on the model")
	check(is_equal_approx(me.reach_base().y, me.global_position.y + Talents.NECK_RISE), "the host measures reach from half a metre higher")
	check(await aim_at(chicken), "the high prop can now be aimed at")
	me.set_first_person(true)
	await frames(4)
	check(absf(me.cam.global_position.y - (me.global_position.y + me.eye_height() + Talents.NECK_RISE)) < 0.03, "in first person the eye is half a metre higher too")
	me.set_first_person(false)
	await frames(4)
	me.global_position = far_spot
	check(flow.near_monitor(me), "with the neck out, the monitor can be watched from five metres")
	me.global_position = monitor.global_position + Vector3(-7.0, 0, 0)
	check(not flow.near_monitor(me), "but not from seven")
	me.global_position = here
	flow.levels["monitor"] = monitor_level
	# 走れない（歩きだけ）
	place(chicken, ahead(3.0, -3.0))
	me.aim_pitch = -0.25
	me.aim_yaw = -PI * 0.5          # 軽トラのほう（何も置いていない向き）へ歩く
	game.input_locked = false
	Input.action_press("move_forward")
	Input.action_press("run")
	await frames(60)
	var slow: float = Vector2(me.velocity.x, me.velocity.z).length()
	check(not game.ui_blocking() and slow > 2.0 and slow < me.WALK + 0.2, "with the neck out, running is only a walk (%.1f m/s)" % slow)
	talent.host_use(id)
	await frames(70)
	var fast: float = Vector2(me.velocity.x, me.velocity.z).length()
	Input.action_release("move_forward")
	Input.action_release("run")
	game.input_locked = true
	check(not talent.neck_out(id) and fast > me.WALK + 1.0, "K again pulls the neck back, and running works (%.1f m/s)" % fast)
	await frames(30)
	check(me.neck == 0.0 and is_equal_approx(me.head.position.y, 1.85) and float(lift.rise) == 0.0, "the view and the head are back where they were")
	me.global_position = here
	me.aim_yaw = 0.0
	await frames(4)
	# 撮影カメラの操作中は使えない。伸ばしたまま操作し始めると、戻る
	me.operating = game.film.pid
	talent.host_use(id)
	await frames(3)
	check(not talent.neck_out(id), "it cannot be used while operating the camera")
	me.operating = 0
	talent.host_use(id)
	await frames(3)
	me.operating = game.film.pid
	await frames(3)
	check(not talent.neck_out(id), "starting to operate the camera pulls the neck back")
	me.operating = 0
	talent.host_use(id)
	await frames(30)
	check(talent.neck_out(id) and me.neck > 0.4, "the neck is out again")
	await pick("M02")
	await frames(30)
	check(talent.necks.is_empty() and me.neck == 0.0, "changing character pulls it back")

	# ---- TALENT4-4 モップの王様「毛ひも」 ----
	await pick("06")
	await frames(6)
	var truck: Node3D = game.truck
	var hooks: Array = truck.hooks
	var box: Node = null
	for carton: Node in kit.cartons:
		if box == null and not carton.absent:
			box = carton
	check(await load_by_hand(box, (hooks[4] as Vector3).z), "a carton is loaded between a pair of hooks")
	await frames(60)
	var rope_before: float = kit.stock()
	var tufts: Node = me.vis.skel.get_node_or_null("TalentTufts")
	var full_hair: int = tufts.find_children("*", "MeshInstance3D", true, false).size() if tufts else 0
	check(talent.hair_coils.size() == Talents.HAIR_COILS and is_equal_approx(talent.hair_left(id), Talents.HAIR_M) and full_hair > 0, "the mop king starts with a full head of hair (%d locks)" % full_hair)
	texts.append(str(talent.hint(me)["keys"]))
	check(str(talent.hint(me)["keys"]) == "K 毛ひもを出す", "K is offered to pull out a hair cord")
	# 短いひもなので、荷台をはさんだ向こうのフックに先に結んでから、手前のフックに結ぶ（軽トラを回り込まない）
	await stand_at(9)
	talent.host_use(id)
	await frames(6)
	var coil: Node = talent.hair_coil_of(id)
	check(coil != null and me.held == coil.pid and not coil.absent and kit.is_coil(coil) and coil.kind == Talents.HAIR_KIND, "K puts a bundle of hair in the hand: it counts as a rope coil")
	texts.append(str(talent.hint(me)["keys"]))
	texts.append(str(kit.hud_view(me).get("keys_all", "")).get_slice("\n", 0))
	check(str(talent.hint(me)["keys"]) == "K 毛ひもをしまう" and kit.f_action(me).get("do", "") in ["rope", "hook"], "holding it, the rope hints apply")
	kit.rng.seed = 11
	kit.h_hook(4)
	await frames(15)
	var open: Dictionary = kit.open_lash(coil.pid)
	check(not open.is_empty() and int(open["a"]) == 4 and kit.open_lash().is_empty(), "F ties one end of the hair to a hook; the company rope is not involved")
	check(absf(talent.hair_left(id) + float(open["cord"].length) - Talents.HAIR_M) < 0.02, "the hair in the hand gets shorter as the cord pays out")
	kit.h_hook(9)
	await frames(30)
	var cord: Node3D = open.get("cord")
	check(kit.lash_count() == 1 and int(open["b"]) == 9 and int(open["coil"]) == coil.pid, "F on the hook across the bed ties the other end: one hair cord over the carton")
	check(absf(talent.hair_left(id) + cord.length - Talents.HAIR_M) < 0.02 and talent.hair_left(id) < Talents.HAIR_M - 1.5, "the cord came out of the king's own hair (%.2f m used)" % cord.length)
	check(is_equal_approx(kit.stock(), rope_before), "the company rope coil is as long as before")
	talent.host_use(id)
	await frames(6)
	check(me.held == 0 and coil.absent and not talent.hair_out(id) and kit.lash_count() == 1, "K again puts the bundle away; the cord stays on the truck")
	await frames(20)
	tufts = me.vis.skel.get_node_or_null("TalentTufts")
	var thin_hair: int = tufts.find_children("*", "MeshInstance3D", true, false).size()
	check(thin_hair < full_hair, "the head has visibly less hair (%d locks, was %d)" % [thin_hair, full_hair])
	await frames(340)
	print("CAST_TALENT hair cord: length %.2f, hold on the carton %.2f, pinned %s" % [cord.length, kit.grip_of(box.pid), str(kit.pinned(box.pid))])
	check(kit.pinned(box.pid), "the hair cord holds the carton to the bed")
	# 出したまま手から離すと、束はしまわれる。結びかけのひもは、巻き戻る
	var used: float = Talents.HAIR_M - talent.hair_left(id)
	await stand_at(3)
	talent.host_use(id)
	await frames(6)
	kit.h_hook(3)
	await frames(15)
	check(not kit.open_lash(coil.pid).is_empty() and talent.hair_left(id) < Talents.HAIR_M - used - 0.2, "a second cord is started")
	game.h_release()
	await frames(6)
	check(coil.absent and kit.open_lash(coil.pid).is_empty() and kit.lashes.size() == 1 and absf(Talents.HAIR_M - talent.hair_left(id) - used) < 0.02, "dropping the bundle puts it away and winds the unfinished cord back")
	check(texts.all(func(text: String) -> bool: return text != "" and not has_digit(text)), "the hints of these four name actions only, with no numbers (%s)" % " / ".join(texts))
	var numbered := false
	for word: Label3D in me.vis.find_children("*", "Label3D", true, false):
		numbered = numbered or has_digit(word.text)
	check(not numbered and not game.production_hud.talent_slots.visible, "nothing on the character or the screen counts what is left")
	me.global_position = flow.HOME_TRUCK + Vector3(-6, 0.1, 6)
	me.aim_yaw = 0.0
	me.aim_pitch = -0.25
	await frames(4)
	return [box, on_truck(box), coil, cord]


func run() -> void:
	# ---- 表だけで決まること ----
	var named := true
	for tag: String in CASTS:
		named = named and Talents.has(tag) and Talents.title(tag) != "" and Talents.describe(tag) != ""
	check(named and Talents.TALENTS.size() == CASTS.size(), "all seven characters have a talent with a name and a description")
	check(Talents.ready("M02") and Talents.ready("09") and Talents.ready("03"), "the robot's lamp, the box head's tool box and the notebook copy are playable")
	check(CASTS.all(func(tag: String) -> bool: return Talents.ready(tag)), "all seven talents are playable: nothing is marked as coming soon")
	check(Talents.hair_tufts(Talents.HAIR_M).all(func(v: float) -> bool: return v == 1.0) and Talents.hair_tufts(0.0).all(func(v: float) -> bool: return v == 0.0) and Talents.hair_tufts(2.5).count(1.0) == 2, "the locks on the head follow the hair that is left")
	check(Talents.can_stow("anything", Vector3(0.425, 0.1, 0.1), 3.0), "85 cm and 3 kg still fit")
	check(Talents.stow_refusal("anything", Vector3(0.43, 0.1, 0.1), 1.0) == "入らない（大きすぎ）", "longer than 85 cm does not fit")
	check(Talents.stow_refusal("anything", Vector3(0.1, 0.1, 0.1), 3.1) == "入らない（重すぎ）", "heavier than 3 kg does not fit")
	for kind: String in ["clapper", "script", "cue_card", "standin", "camera", "spot", "monitor", "mark", "fx", "glue", "carton"]:
		check(not Talents.can_stow(kind, Vector3(0.05, 0.05, 0.05), 0.1), "%s is never stowed, whatever its size" % kind)
	check(Talents.LAMP_FACTOR + 0.05 < 0.30, "the lamp alone stays under the face brightness threshold")
	check(Talents.lamp_falloff(0.0, 0.0) == 1.0 and Talents.lamp_falloff(0.0, Talents.LAMP_RANGE) == 0.0 and Talents.lamp_falloff(Talents.LAMP_ANGLE + 1.0, 1.0) == 0.0, "the lamp fades with distance and stops at the edge of its cone")

	# ---- ゲームの中で ----
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	talent = game.talent
	me = game.local_player()
	id = me.peer_id
	var S: Dictionary = game.S
	check(talent != null and InputMap.has_action("talent"), "the talent node and the K action exist")
	check(not talent.usable(), "talents wait until a job is taken")
	game.h_accept_job(0)
	game.h_open_order()
	game.h_order_set("rose", 1)
	game.h_order_confirm()
	await frames(8)
	check(talent.usable() and flow.phase == 2, "talents work while preparing at the company")

	var pie: Node = first("scrap_pie")
	var plunger: Node = first("scrap_plunger")
	var chicken: Node = first("scrap_chicken")
	var rose: Node = first("rose")
	var toilet: Node = first("scrap_toilet")
	var sandbag: Node = first("sandbag")
	for prop: Node in [rose, pie, plunger, chicken, first("letter"), first("crown"), first("fish"), first("filmcan"), first("tape"), first("basket"), first("recorder"), first("scrap_poop"), first("scrap_torch"), first("scrap_duck"), first("scrap_idol"), first("dragon_skull"),
			toilet, first("scrap_mushroom"), first("scrap_chest"), sandbag, first("carton"), first("riser"), first("flat"), first("rock"), first("boom"), first("applebox")]:
		print("CAST_TALENT size %s longest=%.2f mass=%.1f -> %s" % [prop.kind, maxf(prop.half.x, maxf(prop.half.y, prop.half.z)) * 2.0, prop.mass, "fits" if Talents.can_stow(prop.kind, prop.half, prop.mass) else Talents.stow_refusal(prop.kind, prop.half, prop.mass)])
	for prop: Node in [rose, pie, plunger, chicken]:
		check(Talents.can_stow(prop.kind, prop.half, prop.mass), "%s fits in the head" % prop.label)
	for prop: Node in [toilet, sandbag, game.clapper, flow.script_prop]:
		check(not Talents.can_stow(prop.kind, prop.half, prop.mass), "%s does not" % prop.label)

	# あとの4人（ショール・止まれ！・びよーん首・毛ひも）
	var tied: Array = await four_more(toilet, pie, plunger, chicken, rose)
	check(pie.stored_in == 0 and not pie.absent and talent.stowed.is_empty() and talent.lamps.is_empty(), "none of that touched the box head's or the robot's state")

	# ---- 段ボール頭「頭の道具箱」 ----
	await pick("09")
	check(me.vis.tag == "09" and talent.cast_of(id) == "09", "the box head is picked")
	# 入らない物は断る（失格にはしない。手で持つのは今までどおり）
	place(toilet, ahead(1.6))
	await frames(3)
	talent.host_use(id, toilet.pid)
	await frames(2)
	check(toilet.stored_in == 0 and not toilet.absent, "a toilet aimed at is refused")
	check(talent.stow_refusal(id, toilet) != "" and talent.stow_refusal(id, pie) == "", "the reason is known before pressing K")
	game.h_grab(game.clapper.pid)
	await frames(2)
	talent.host_use(id)
	await frames(2)
	check(me.held == game.clapper.pid and game.clapper.stored_in == 0, "the clapper stays in the hand")
	game.h_release()
	await frames(2)
	place(toilet, flow.HOME_TRUCK + Vector3(-12, 0.3, 9))

	# しまう：持っている小物に K
	var bed_before: int = flow.bed_load()["used"]
	check(flow.cast_set(pie.pid, "boom"), "the pie is cast as the explosion first")
	place(pie, ahead(1.3))
	await frames(3)
	game.h_grab(pie.pid)
	await frames(2)
	check(me.held == pie.pid and talent.hint(me)["keys"].begins_with("K 頭にしまう"), "holding a small prop offers K")
	await frames(3)
	check(str(game.hud.target_label.text).ends_with("K：頭にしまう") and "パイ" in str(game.hud.target_label.text), "the name of the held prop says it fits in the head")
	talent.host_use(id)
	await frames(2)
	check(me.held == 0 and pie.holder == 0, "K takes the held prop out of the hand")
	check(pie.absent and pie.stored_in == -id and pie.global_position.y < -50.0, "the stowed prop leaves the set")
	check(talent.stowed_of(id) == [pie.pid], "and is listed in the head")
	check(pie.pid in flow.cargo() and pie.pid not in flow.cargo(false), "a stowed prop travels with its owner, not on the truck")
	check(flow.bed_load()["used"] == bed_before, "and takes no room on the truck bed")
	check((flow.loadout()["items"] as Array).any(func(row: Array) -> bool: return row[0] == "scrap_pie"), "the packing list shows it among the things going to the set")
	check(flow.role_of(pie) == "boom" and "パイ" in str(flow.cast_sheet()["rows"][2]["items"]), "its role stays and still shows in the casting sheet")
	check("頭から出す" in str(talent.hint(me)["keys"]), "with empty hands K offers to take it out")
	await frames(3)
	var rack: Node = me.vis.skel.get_node_or_null("TalentStow")
	check(rack != null and rack.get_child_count() == 1, "a small copy peeks out of the head")
	check(game.production_hud.talent_slots.visible and talent.slots(me).size() == 1 and talent.slots(me)[0]["kind"] == "scrap_pie", "the owner's screen shows the slots")
	check(str(game.hud.keys.text).begins_with("K 頭から出す"), "the key guide starts with the talent")

	# しまう：手ぶらで小物を見て K
	place(plunger, ahead(1.5))
	await frames(3)
	talent.host_use(id, plunger.pid)
	await frames(2)
	check(plunger.stored_in == -id and talent.stowed_of(id) == [pie.pid, plunger.pid], "K on an aimed small prop stows it too")
	# 遠くの物はしまえない。しまう物が無い K は、最後に入れた物を出す
	place(chicken, ahead(9.0))
	await frames(3)
	talent.host_use(id, chicken.pid)
	await frames(3)
	check(chicken.stored_in == 0 and not chicken.absent, "a prop out of reach is not stowed")
	check(me.held == plunger.pid and not plunger.absent and plunger.stored_in == 0 and talent.stowed_of(id) == [pie.pid], "K with nothing to stow takes out the last one, into the hand")
	await frames(30)
	check(plunger.global_position.distance_to(me.global_position) < 2.6 and plunger.global_position.y > -1.0, "the prop taken out is at hand (%.1f m)" % plunger.global_position.distance_to(me.global_position))
	talent.host_use(id)
	await frames(2)
	check(me.held == 0 and talent.stowed_of(id) == [pie.pid, plunger.pid], "and K puts it back")
	# 3つまで
	await stow_held(rose)
	check(talent.stowed_of(id) == [pie.pid, plunger.pid, rose.pid], "three props fit")
	await frames(3)
	check(me.vis.skel.get_node("TalentStow").get_child_count() == 3 and talent.slots(me).size() == 3, "all three show on the head and in the slots")
	await stow_held(chicken)
	check(me.held == chicken.pid and chicken.stored_in == 0 and talent.stowed_of(id).size() == 3, "a fourth is refused and stays in the hand")
	check("いっぱい" in talent.stow_refusal(id, chicken), "because the head is full")
	# Shift+K：手がふさがっていても出せる（足元に転がる）
	talent.host_use(id, 0, true)
	await frames(60)
	check(talent.stowed_of(id) == [pie.pid, plunger.pid] and not rose.absent and rose.holder == 0 and me.held == chicken.pid, "Shift+K with full hands drops the last one at the feet")
	check(rose.global_position.distance_to(me.global_position) < 3.5 and rose.global_position.y > -1.0, "it lands nearby (%.1f m)" % rose.global_position.distance_to(me.global_position))
	game.h_release()
	await frames(2)
	talent.host_use(id, 0, true)
	await frames(3)
	check(me.held == plunger.pid and talent.stowed_of(id) == [pie.pid], "Shift+K with free hands takes the last one into the hand")
	game.h_release()
	await frames(2)

	# 本物のキー：見ている小物に K、手ぶらで Shift+K
	place(plunger, ahead(1.5))
	await frames(6)
	me.target = plunger
	key(KEY_K)
	await frames(3)
	check(talent.stowed_of(id) == [pie.pid, plunger.pid], "the K key stows the prop aimed at")
	me.target = null
	key(KEY_K, true)
	await frames(3)
	check(talent.stowed_of(id) == [pie.pid] and me.held == plunger.pid, "Shift and K take it out again")
	game.h_release()
	await frames(2)

	# 仲間の頭を見る：中身の入った段ボール頭の仲間に照準が合うと、F の案内が出る（取り出すところは、二人通信のテストで確かめる）
	game._roster.append([2, game.PLAYER_CASTS.find("09")])
	game.ev("roster", [game._roster])
	await frames(2)
	var mate: Node = game.players[2]
	mate.global_position = ahead(2.2) - Vector3(0, 0.15, 0)
	talent.on_event("stow", [2, plunger.pid, true])
	await frames(3)
	for step in 10:
		var to: Vector3 = talent.head_top(mate) - Vector3(0, 0.4, 0) - me.cam.global_position
		me.aim_yaw = atan2(-to.x, -to.z)
		me.aim_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.0)
		await frames(3)
	check(talent.crew_aimed(me) == 2, "looking at a box-head crew member with something in the head is recognised")
	check("F 頭から取り出す" in str(talent.hint(me)["keys"]) and "頭の道具箱" in str(talent.hint(me)["target"]), "and F is offered, with the contents by name")
	me.aim_yaw = wrapf(me.aim_yaw + PI, -PI, PI)
	await frames(4)
	check(talent.crew_aimed(me) == 0, "with the back turned, it is not")
	game._roster.pop_back()
	game.ev("roster", [game._roster])
	await frames(4)
	check(not game.players.has(2) and not talent.stowed.has(2) and not plunger.absent and plunger.stored_in == 0, "when that crew member leaves, the contents spill out")
	me.aim_yaw = 0.0
	me.aim_pitch = -0.25
	await frames(4)

	# 借りるのをやめた物は、頭の中からも消える
	await stow_held(rose)
	check(talent.stowed_of(id) == [pie.pid, rose.pid], "the rented rose is in the head")
	game.h_open_order()
	game.h_order_set("rose", 0)
	game.h_order_confirm()
	await frames(8)
	check(talent.stowed_of(id) == [pie.pid] and rose.absent and rose.stored_in == 0, "returning the rental empties its slot")
	check(pie.absent and pie.stored_in == -id, "the rest stays stowed through a new order")

	# ---- 出発 → 到着：頭の中の物は、持ち主といっしょに着く ----
	await stow_held(chicken)
	check(talent.stowed_of(id) == [pie.pid, chicken.pid], "two props are in the head before leaving")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	for i in 900:
		if flow.phase == 4:
			break
		await physics_frame
	await frames(20)
	check(flow.phase == 4, "the crew arrives")
	check(pie.stored_in == -id and pie.absent and chicken.stored_in == -id and talent.stowed_of(id) == [pie.pid, chicken.pid], "the head still holds both props")
	# 毛ひもで押さえた箱は、道中で動いていない。現場に着いても掛かったまま。ほどくと、毛が頭に戻る
	var tied_box: Node3D = tied[0]
	check(flow.at_site(tied_box) and on_truck(tied_box).distance_to(tied[1]) < 0.03, "the carton under the hair cord did not move on the way (%.3f m)" % on_truck(tied_box).distance_to(tied[1]))
	check(game.cargo_kit.lash_count() == 1 and talent.hair_left(id) < Talents.HAIR_M - 1.5, "the hair cord is still on at the set")
	await stand_at(4)
	game.cargo_kit.h_untie(int(game.cargo_kit.lashes.keys()[0]))
	await frames(6)
	check(game.cargo_kit.lashes.is_empty() and absf(talent.hair_left(id) - Talents.HAIR_M) < 0.02, "untying it gives the hair back")
	check(flow.at_site(pie) and pie.pid in flow.cargo() and pie.label not in flow.lost and chicken.label not in flow.lost, "they count as brought to the set, not lost on the way")
	check(not game.judge.role_of(pie) == "" and (game.live["hints"] as Array).any(func(h: String) -> bool: return "爆発" in h), "a prop in the head has a role but does not show on camera")
	me.global_position = Vector3(0, 0.1, 4)
	me.aim_yaw = 0.0
	await frames(4)
	talent.host_use(id)
	await frames(30)
	check(me.held == chicken.pid and not chicken.absent and flow.at_site(chicken) and chicken.global_position.distance_to(me.global_position) < 2.6, "on the set, K takes a prop out of the head")
	game.h_release()
	await frames(40)
	var chicken_at: Vector3 = chicken.global_position

	# ---- 本番：見返しと、撮り直し ----
	game.h_take()
	await frames(4)
	check(game.state == S.COUNTDOWN, "the countdown starts with the pie in the head and the chicken on the floor")
	await frames(200)
	check(game.state == S.TAKE, "the take starts")
	talent.host_use(id)
	await frames(20)
	check(me.held == pie.pid and talent.stowed_of(id).is_empty(), "during the take the pie comes out")
	game.h_release()
	await frames(20)
	talent.host_use(id, chicken.pid)
	await frames(20)
	check(talent.stowed_of(id) == [chicken.pid] and chicken.absent, "and the chicken goes in")
	game.h_take()
	await frames(10)
	check(game.state == S.RESULT and talent.stowed_of(id) == [chicken.pid], "after the cut the head holds the chicken")
	game.h_replay(0)
	await frames(3)
	check(game.state == S.REPLAY and talent.shown_stowed(id) == [pie.pid], "the replay starts with what was in the head when the take began")
	check(not chicken.absent and chicken.stored_in == -id and talent.stowed_of(id) == [chicken.pid], "props in the head are shown during a replay, and the real contents are untouched")
	check(chicken.global_position.distance_to(chicken_at) < 0.5, "the chicken is back where the recording has it (%.2f m)" % chicken.global_position.distance_to(chicken_at))
	check(not talent.usable(), "talents are off during a replay")
	for i in 600:
		if game.state != S.REPLAY:
			break
		await physics_frame
	check(game.state == S.RESULT and talent.shown_stowed(id) == [chicken.pid] and chicken.absent and chicken.global_position.y < -50.0, "after the replay the real contents are back")
	game.h_retake()
	await frames(10)
	check(game.state == S.PREP and talent.stowed_of(id) == [pie.pid], "a retake puts the head back as it was before the take")
	check(pie.absent and pie.stored_in == -id and not chicken.absent and chicken.stored_in == 0, "the pie is stowed again and the chicken is out")
	check(chicken.global_position.distance_to(chicken_at) < 0.5, "the chicken is back at its place (%.2f m)" % chicken.global_position.distance_to(chicken_at))

	# ---- キャラを替えると、中身は足元にこぼれる ----
	await pick("M02")
	await frames(60)
	check(me.vis.tag == "M02" and talent.stowed.is_empty(), "changing character empties the head")
	check(not pie.absent and pie.stored_in == 0 and pie.global_position.distance_to(me.global_position) < 3.0 and pie.global_position.y > -1.0, "the pie spills at the feet (%.1f m)" % pie.global_position.distance_to(me.global_position))
	check(not game.production_hud.talent_slots.visible, "the slots are only for the box head")

	# ---- ロボット「おなかランプ」 ----
	for rig: Node in game.spots:
		rig.level = 0
	me.global_position = Vector3(0, 0.1, 4)
	me.vis.rotation.y = 0.0
	await frames(4)
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var front: Vector3 = me.global_position + Vector3(0, 1.5, 2.0)
	var behind: Vector3 = me.global_position + Vector3(0, 1.5, -2.0)
	var dark_front: float = game.judge.brightness(space, front)
	var dark_behind: float = game.judge.brightness(space, behind)
	check("ランプを点ける" in str(talent.hint(me)["keys"]), "the robot is offered its lamp")
	key(KEY_K)
	await frames(3)
	var lit_front: float = game.judge.brightness(space, front)
	print("CAST_TALENT lamp front %.3f -> %.3f, behind %.3f -> %.3f" % [dark_front, lit_front, dark_behind, game.judge.brightness(space, behind)])
	check(talent.lamp_on(id) and "ランプを消す" in str(talent.hint(me)["keys"]), "K lights the belly lamp")
	check(lit_front > dark_front + 0.08, "two metres ahead gets brighter")
	check(is_equal_approx(game.judge.brightness(space, behind), dark_behind), "behind the robot nothing changes")
	check(lit_front < game.judge.MIN_LIGHT, "the lamp alone is not enough for a face (%.2f < %.2f)" % [lit_front, game.judge.MIN_LIGHT])
	var lamp: Node = me.vis.get_node_or_null("TalentLamp")
	var glass: MeshInstance3D = me.vis.find_child("castM02_game_glass", true, false)
	check(lamp != null and lamp.visible and glass.material_override != null, "the lamp shines and the belly window glows")
	# 月と合わせると、顔の明るさの基準に届く
	var moon: Node = game.moons[0]
	var moon_only := 0.0
	if moon.absent:
		moon.set_absent(false)
	place(moon, front + Vector3(1.0, -3.0, 0.3), 0.0, true)
	await frames(3)
	talent.host_use(id)
	await frames(2)
	moon_only = game.judge.brightness(space, front)
	check(not talent.lamp_on(id) and not lamp.visible and glass.material_override == null, "K again switches it off")
	talent.host_use(id)
	await frames(2)
	var both: float = game.judge.brightness(space, front)
	print("CAST_TALENT moon only %.3f, moon and lamp %.3f" % [moon_only, both])
	check(moon_only < game.judge.MIN_LIGHT and both >= game.judge.MIN_LIGHT, "the moon alone is too dark, the moon and the lamp together are enough")
	place(moon, Vector3(60, 0, 40), 0.0, true)
	# 物でさえぎると届かない
	var wall: Node = first("riser")
	place(wall, me.global_position + Vector3(0, 0.0, 1.0), 0.0, true)
	await frames(3)
	check(is_equal_approx(game.judge.brightness(space, me.global_position + Vector3(0, 0.6, 2.0)), dark_front), "a prop in the way blocks the lamp")
	place(wall, Vector3(60, 0, 44), 0.0, true)
	await pick("03")
	await frames(3)
	check(talent.lamps.is_empty(), "the lamp goes out when the robot becomes someone else")

	# ---- 手帳の人「台本の写し」：台本を持っていなくても、台本のページを開ける ----
	var page: Control = game.production_hud.script_page
	check(me.vis.tag == "03" and me.held == 0 and flow.script_prop.holder == 0 and not page.visible, "the notebook keeper holds no script and sees no page")
	check("手帳で台本を読む" in str(talent.hint(me)["keys"]), "K is offered for the notebook")
	talent.host_use(id)
	await frames(4)
	check(talent.note_open(id) and page.visible and me.held == 0, "K opens the script page without holding the script")
	check(me.vis.current == "memo" or not me.vis.has("memo"), "with the note-taking motion")
	check("手帳を閉じる" in str(talent.hint(me)["keys"]) and flow.script_prop.holder == 0 and not flow.script_prop.absent, "the one real script stays where it is")
	talent.host_use(id)
	await frames(4)
	check(not talent.note_open(id) and not page.visible, "K again closes it")
	talent.host_use(id)
	await pick("09")
	await frames(4)
	check(talent.notes.is_empty() and not page.visible, "the page closes when the keeper becomes someone else")

	# ---- TALENT4-5 本番中のショールは、見返しでも同じに流れる。撮り直すと、テイク前のかけ方に戻る ----
	await pick("01")
	await frames(6)
	me.global_position = Vector3(0, 0.1, 4)
	me.aim_yaw = 0.0
	place(chicken, ahead(1.6))
	await frames(20)
	check(Roles.castable(chicken.kind) and talent.shawls.is_empty(), "on the set, before the take, nothing wears a shawl")
	var takes_before: int = game.takes.size()
	game.h_take()
	await frames(200)
	check(game.state == S.TAKE, "a take starts with the dress wearer on the set")
	await frames(30)
	talent.host_use(id, chicken.pid)
	await frames(30)
	check(talent.shawled(chicken.pid), "during the take the shawl goes on the chicken")
	game.h_take()
	await frames(10)
	check(game.state == S.RESULT and game.takes.size() == takes_before + 1 and talent.shawled(chicken.pid), "after the cut the chicken still wears it")
	game.h_replay(game.takes.size() - 1)
	await frames(3)
	check(game.state == S.REPLAY and talent.shown_shawls().is_empty() and talent.shown_shawls_left(id) == 2 and talent.shawled(chicken.pid), "the replay starts with the shawl still on the shoulder; the real state is untouched")
	await frames(12)
	check(chicken.get_node_or_null("TalentShawl") == null and talent.shown_shawls_left(id) == 2, "and that is what the screen shows")
	# 見返しの間に流れる合図は、見た目だけを変える（首・毛・止まれ！の札も同じ仕組み）
	talent.on_event("neck", [id, true])
	talent.on_event("hair", [talent.hair_coils[0].pid, id, true, 3.0])
	talent.on_event("halt", [id, []])
	check(talent.shown_neck(id) and not talent.neck_out(id), "a neck event in a replay shows the neck out, without changing the real state")
	check(is_equal_approx(talent.shown_hair_left(id), 3.0) and is_equal_approx(talent.hair_left(id), Talents.HAIR_M) and talent.hair_coils[0].stored_in == talent.HAIR_STORED, "a hair event in a replay shows less hair, without touching the real bundle")
	check(talent.halt_ready(id) < 0.1 and not talent.halt_wait.has(id), "a halt event in a replay drops the paddle, without starting the real wait")
	var shown_on := false
	for i in 900:
		if game.state != S.REPLAY:
			break
		shown_on = shown_on or (talent.shown_shawls().has(chicken.pid) and chicken.get_node_or_null("TalentShawl") != null)
		await physics_frame
	check(shown_on, "partway through the replay the shawl appears on the chicken, as recorded")
	check(game.state == S.RESULT and talent.shown_shawls().has(chicken.pid) and not talent.shown_neck(id) and is_equal_approx(talent.shown_hair_left(id), Talents.HAIR_M) and is_equal_approx(talent.halt_ready(id), 1.0), "after the replay the real state shows again")
	game.h_retake()
	await frames(10)
	check(game.state == S.PREP and not talent.shawled(chicken.pid) and talent.shawls_left(id) == 2, "a retake puts the shawl back on the shoulder, as before the take")
	await frames(6)
	check(chicken.get_node_or_null("TalentShawl") == null and talent.hair_coils[0].absent, "and the cloth is gone from the chicken")
	await pick("09")
	await frames(4)

	# ---- 納品して事務所へ：中身は元の置き場所へ戻る ----
	await stow_held(pie)
	check(talent.stowed_of(id) == [pie.pid], "the pie is in the head again")
	game.h_take()
	await frames(200)
	game.h_take()
	await frames(10)
	check(game.state == S.RESULT and talent.stowed_of(id) == [pie.pid], "a second take is cut with the pie in the head")
	game.h_deliver(game.takes.size() - 1)
	await frames(10)
	check(flow.phase == 5 and pie.stored_in == -id, "the pie is still in the head at the settlement")
	game.h_return_office()
	await frames(20)
	check(flow.phase == 0 and talent.stowed.is_empty() and pie.stored_in == 0 and not pie.absent, "back at the office the head is empty")
	var home: Vector3 = flow._home_layout[pie.pid][0]
	check(pie.global_position.distance_to(home) < 1.0, "and the pie is back in the scrap yard (%.2f m from its place)" % pie.global_position.distance_to(home))
	check(chicken.global_position.distance_to(flow._home_layout[chicken.pid][0]) < 1.0 and not chicken.absent, "like every other prop")
	# 次の依頼を受けると、ショール・毛・首・札は、全部元に戻る
	var bundle: Node = talent.hair_coils[0]
	talent.hair[bundle.pid] = [id, false, 2.0]
	talent.shawl_lost[id] = 1
	talent.halt_wait[id] = 5.0
	game.h_accept_job(0)
	await frames(8)
	check(flow.phase != 0 and talent.shawls.is_empty() and talent.shawls_left(id) == Talents.SHAWL_COUNT and talent.necks.is_empty(), "taking the next job brings the shawls back")
	check(is_equal_approx(talent.hair_left(id), Talents.HAIR_M) and talent.hair_coils.all(func(c: Node) -> bool: return c.absent and is_equal_approx(float(talent.hair[c.pid][2]), Talents.HAIR_M)) and is_equal_approx(talent.halt_ready(id), 1.0), "and the hair, and the paddle")
	print("CAST_TALENT_TEST_FAIL" if failed else "CAST_TALENT_TEST_OK")
	# 鳴っている音を止めて、ゲームを片付けてから終わる（鳴っている最中に終わると、終了時に「resources still in use」が出る）
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	game.queue_free()
	for i in 8:
		await process_frame
	quit(1 if failed else 0)
