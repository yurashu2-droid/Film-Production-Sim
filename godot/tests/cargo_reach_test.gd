extends SceneTree
# 「F で積んだ物が現場に届く」ことを、3種類の現場で確かめる。
#   依頼を受ける → 会社の機材は機材置き場に並び、荷台は空いている
#   → 大きさの違う物を、荷台の横に立って F で積む → 荷台の床に落ち着く
#   → 出発 → 到着：積んだ物は全部現場にあり、道中で落とした物が無い。
#     会社の機材（カメラ3台・ライト2台・カチンコ・カンペ・確認用モニター）は搬入口のそばに立って並び、
#     壁の中・物の上・役者の立ち位置に出ていない
#   → 事務所へ戻ると、機材は機材置き場に立っている
# ほかに：わざわざ荷台に積んだ機材・手に持ったままの機材や台本・道中で荷台から落ちた機材・
#         ふさがった置き場所・並べたままの機材と突風・低い荷物の真上に重ねる・荷台がいっぱいのとき。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/cargo_reach_test.gd
var game: Node
var flow: Node
var me: Node
var truck: Node
var failed := false


func _initialize() -> void:
	create_timer(190).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CARGO_REACH_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


# 当たり判定を囲む箱（ワールド座標）
func box_of(prop: Node3D) -> AABB:
	return prop.global_transform * (game.body_bounds(prop) as AABB)


# 当たり判定を囲む箱（軽トラのローカル座標）
func deck_box(prop: Node3D) -> AABB:
	return truck.global_transform.affine_inverse() * box_of(prop)


# 物の底の、荷台の床からの高さ
func above_deck(prop: Node3D) -> float:
	return deck_box(prop).position.y - float(truck.deck_top)


# 物の中心が荷台の上にあるか
func over_deck(prop: Node3D) -> bool:
	var c: Vector3 = deck_box(prop).get_center()
	return absf(c.x - truck.deck_c.x) < truck.deck_half.x and absf(c.z - truck.deck_c.y) < truck.deck_half.y


# 持って F で積む（軽トラのそばに立っている前提）。積めなければ、手に残る
func grab_and_load(prop: Node) -> bool:
	await frames(2)
	if me.global_position.distance_to(flow.HOME_TRUCK) > 4.5:
		check(false, "%s: the crew member stands within reach of the truck" % prop.kind)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(2)
	return prop.rider_of == truck.pid


# 実際に遊ぶときに近い形で積む：荷台の横（W＝西・E＝東・R＝後ろ）に立ち、目の前に持った物を F で積む。
# 積めたかどうかを返す
func load_by_hand(prop: Node, side: String, turn: float = 0.0) -> bool:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var facing := Quaternion(Vector3.UP, turn)
	var box: AABB = Transform3D(Basis(facing), Vector3.ZERO) * (game.body_bounds(prop) as AABB)
	var out := Vector3(-1, 0, 0)          # 軽トラから外へ向かう向き
	var along := Vector3(0, 0, -1.2)      # 軽トラに沿った位置
	var body := 1.2                       # 軽トラの中心から、その側の外面まで
	if side == "E":
		out = Vector3(1, 0, 0)
		along = Vector3(0, 0, -1.0)
	elif side == "R":
		out = Vector3(0, 0, -1)
		along = Vector3(0.2, 0, 0)
		body = 2.7
	var reach: float = absf(out.x) * box.size.x * 0.5 + absf(out.z) * box.size.z * 0.5
	var centre: Vector3 = out * (body + 0.3 + reach) + along
	var feet: Vector3 = out * (body + 0.3 + reach * 2.0 + 0.6) + along
	me.global_position = truck.global_transform * Vector3(feet.x, 0.1, feet.z)
	me.aim_yaw = atan2(out.x, out.z)      # 軽トラのほうを向く
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(centre.x - box.get_center().x, 0.5 - box.position.y, centre.z - box.get_center().z), facing, false])
	return await grab_and_load(prop)


# 荷台の上まで持ち上げてから F で積む（西側に立ち、先に載っている target の真上に持つ）
func load_over(prop: Node, target: Node3D) -> bool:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var over: Vector3 = deck_box(target).get_center()
	var box: AABB = game.body_bounds(prop)
	me.global_position = truck.global_transform * Vector3(-2.4, 0.1, over.z)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = 0.1
	prop.restore([truck.global_transform * Vector3(over.x - box.get_center().x, float(truck.deck_top) + 1.6 - box.position.y, over.z - box.get_center().z), Quaternion.IDENTITY, false])
	return await grab_and_load(prop)


# 現場に立っている機材を確かめる。on_bed＝荷台に積んで運んだ機材 / blocked＝そこには置いていないはずの箱（ふさいだ場所）
func check_gear_on_site(tag: String, on_bed: Array, blocked: Array) -> void:
	var gear: Array = flow.gear()
	var kinds := {}
	for prop: Node in gear:
		kinds[prop.kind] = int(kinds.get(prop.kind, 0)) + 1
	check(kinds == {"camera": 3, "spot": 2, "clapper": 1, "cue_card": 1, "monitor": 1}, "%s: all eight pieces of company gear exist (%s)" % [tag, str(kinds)])
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var standing: Array = []
	var all_ok := true
	for prop: Node3D in gear:
		var name := "%s#%d" % [prop.kind, prop.pid]
		if prop in on_bed:
			continue
		var box := box_of(prop)
		var ok: bool = flow.at_site(prop) and not prop.fixed and prop.rider_of == 0 and prop.holder == 0
		if not ok:
			print("  ", name, " is not free-standing on site: at_site=", flow.at_site(prop), " fixed=", prop.fixed, " rider=", prop.rider_of)
		# 立っている・地面に付いている・搬入口のそば
		var upright: bool = prop.global_basis.y.y > 0.97 and box.position.y > -0.08 and box.position.y < 0.12
		var near: bool = Vector2(prop.global_position.x - game.SPAWN.x, prop.global_position.z - game.SPAWN.z).length() < 8.5
		if not upright or not near:
			print("  ", name, " upright=", upright, " near=", near, " up=%.2f bottom=%.2f pos=%s" % [prop.global_basis.y.y, box.position.y, str(prop.global_position)])
		# 壁の中ではない（床の少し上から、てっぺんまでの箱が、壁・現場の飾り・ほかの物・人に当たらない）
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.size.x - 0.04, box.size.y - 0.15, box.size.z - 0.04)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, Vector3(box.get_center().x, box.end.y - shape.size.y * 0.5, box.get_center().z))
		query.collision_mask = 1 | 2 | 4 | 8
		query.exclude = [prop.get_rid()]
		var hits: Array = space.intersect_shape(query, 4)
		if not hits.is_empty():
			print("  ", name, " touches ", hits.map(func(h: Dictionary) -> String: return str(h["collider"].name)))
		# 物の上ではない（真下は床）
		var ray := PhysicsRayQueryParameters3D.create(box.get_center(), box.get_center() - Vector3(0, box.size.y, 0), 1 | 2 | 4 | 16)
		ray.exclude = [prop.get_rid()]
		var floor_hit: Dictionary = space.intersect_ray(ray)
		var on_floor: bool = not floor_hit.is_empty() and not "pid" in floor_hit["collider"]
		if not on_floor:
			print("  ", name, " does not stand on the floor: ", floor_hit.get("collider"))
		# 役者の立ち位置ではない
		var clear_of_cast := true
		for actor: Node3D in game.actors:
			for point: Vector3 in [actor.global_position, actor.mark.global_position]:
				if Vector2(point.x - box.get_center().x, point.z - box.get_center().z).length() < 1.5:
					clear_of_cast = false
		# 着いた人の立つ所でもない
		var clear_of_crew: bool = Vector2(me.global_position.x - box.get_center().x, me.global_position.z - box.get_center().z).length() > 1.0
		for other: AABB in blocked:
			if box.grow(-0.02).intersects(other):
				ok = false
				print("  ", name, " stands in the blocked spot")
		all_ok = all_ok and ok and upright and near and hits.is_empty() and on_floor and clear_of_cast and clear_of_crew
		standing.append([name, box])
	check(all_ok, "%s: company gear stands free at the loading entrance (not in walls, on props, or on the cast)" % tag)
	var apart := true
	for i in standing.size():
		for j in range(i + 1, standing.size()):
			if (standing[i][1] as AABB).grow(-0.01).intersects((standing[j][1] as AABB).grow(-0.01)):
				apart = false
				print("  ", standing[i][0], " overlaps ", standing[j][0])
	check(apart and standing.size() == gear.size() - on_bed.size(), "%s: the gear does not overlap (%d standing)" % [tag, standing.size()])


# 会社の機材置き場に、機材が立って並んでいるか
func check_gear_at_home(tag: String) -> void:
	var count := {}
	var ok := true
	var boxes: Array = []
	var yard: Rect2 = flow.Office.GEAR_YARD
	for prop: Node3D in flow.gear():
		var n: int = count.get(prop.kind, 0)
		count[prop.kind] = n + 1
		var home: Array = flow.gear_home(prop.kind, n)
		var box := box_of(prop)
		var here: bool = Vector2(prop.global_position.x - home[0].x, prop.global_position.z - home[0].z).length() < 0.15
		var fine: bool = here and prop.global_basis.y.y > 0.97 and prop.rider_of == 0 and not prop.fixed and box.position.y > -0.08 and box.position.y < 0.12
		fine = fine and yard.grow(0.05).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		if not fine:
			print("  %s#%d is not at home: pos=%s home=%s up=%.2f rider=%d" % [prop.kind, prop.pid, str(prop.global_position), str(home[0]), prop.global_basis.y.y, prop.rider_of])
		ok = ok and fine
		for other: AABB in boxes:
			if box.grow(-0.01).intersects(other.grow(-0.01)):
				ok = false
				print("  %s#%d overlaps another piece of gear in the yard" % [prop.kind, prop.pid])
		boxes.append(box)
	check(ok and boxes.size() == 8, "%s: company gear stands in the gear yard, apart from each other" % tag)


# 何個かを順に、横に立って F で積む。[物, 側, 向き] の並び。全部が荷台の床に置かれるはず
func load_all(tag: String, items: Array) -> Array:
	var loaded: Array = []
	for item: Array in items:
		var done: bool = await load_by_hand(item[0], item[1], item[2])
		check(done and above_deck(item[0]) < 0.12, "%s: %s is put on the deck floor from the %s side (%.2f m above it)" % [tag, item[0].kind, item[1], above_deck(item[0])])
		if not done:
			game.h_release()
		loaded.append(item[0])
		await frames(30)
	return loaded


# しばらく置いたあとも、荷台の床（limit より低い所）に落ち着いているか
func check_bed(tag: String, loaded: Array, limit: float = 0.2) -> void:
	var ok := true
	for prop: Node3D in loaded:
		var height := above_deck(prop)
		var fine: bool = prop.rider_of == truck.pid and over_deck(prop) and height > -0.06 and height < limit
		if not fine:
			print("  %s#%d: rider=%d over_deck=%s bottom=%.2f above the deck" % [prop.kind, prop.pid, prop.rider_of, str(over_deck(prop)), height])
		ok = ok and fine
	check(ok, "%s: everything loaded with F has settled on the deck floor" % tag)


# 現場に着いたあと：積んだ物が全部あり、落とした物が無い
func check_arrival(tag: String, site: int, loaded: Array) -> void:
	check(flow.phase == 4 and flow.site_index() == site, "%s: the crew arrives at site %d" % [tag, site])
	var here := true
	for prop: Node3D in loaded:
		if not flow.at_site(prop) or prop.absent:
			here = false
			print("  %s#%d did not reach the site: %s" % [prop.kind, prop.pid, str(prop.global_position)])
	check(here and (flow.lost as Array).is_empty(), "%s: all %d loaded props are on site and nothing was lost on the way (lost=%s)" % [tag, loaded.size(), str(flow.lost)])


# 撮らずに納品して、事務所へ戻る
func wrap_up() -> void:
	flow.lease_left = 0.01
	await frames(4)
	game.h_deliver(0)
	await frames(4)
	game.h_return_office()
	await frames(90)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(20)
	flow = game.production
	me = game.local_player()
	truck = game.truck
	var cameras: Array = of_kind("camera")
	var cartons: Array = of_kind("carton")
	check_gear_at_home("before any job")

	# ---- 1本目：倉庫（現場0）。大きさの違う物を、3方向から F で積む ----
	game.h_accept_job(0)
	await frames(30)
	check(flow.phase == 2 and flow.site_index() == 0, "job 1 is taken (warehouse)")
	check_gear_at_home("job 1")
	check((flow.cargo() as Array).is_empty() and not of_kind("camera").any(func(c: Node) -> bool: return c.rider_of != 0), "the deck starts empty: company gear is not loaded")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	check(flow.can_depart(), "the crew can leave without loading any gear")
	var data: Dictionary = flow.loadout()
	check((data["gear"] as Array).size() == 5 and (data["gear"] as Array).any(func(g: Array) -> bool: return g[0] == "camera" and int(g[2]) == 3) and not data["script"][2], "the packing sheet lists the gear as travelling along, and the script as not packed")
	check("いっしょに運ぶ" in str(flow.loadout_status()), "the packing text says the gear travels along")
	# 機材置き場は軽トラのそば。カメラを狙って F を押すと、積み込み確認は開かず、カメラの操作になる
	me.global_position = Vector3(82.0, 0.1, 15.8)
	await frames(3)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.keycode = KEY_F
	key.pressed = true
	game.input_locked = false
	var near_truck: bool = game.station() == "packing"
	me.target = cameras[2]
	root.push_input(key, true)
	await frames(3)
	check(near_truck and me.operating == cameras[2].pid and game.menu_open == "", "F on a camera in the gear yard operates it instead of opening the packing sheet")
	me.target = cameras[2]
	root.push_input(key, true)
	await frames(3)
	check(me.operating == 0, "F again leaves the camera")
	me.target = null
	root.push_input(key, true)
	await frames(2)
	check(game.menu_open == "packing", "with nothing aimed at, F by the truck opens the packing sheet")
	game.close_menu()
	game.input_locked = true
	# 箱が大きくなったので、箱は東から・岩は西から積む（同じ側から続けて積むと、岩が台本の置き場所へ押し出される）
	var loaded: Array = await load_all("job 1", [[of_kind("tomato_monster")[0], "W", 0.0], [cartons[0], "E", 0.0], [of_kind("rock")[0], "W", 0.0], [of_kind("applebox")[0], "R", 0.0], [of_kind("fish")[0], "W", 0.0]])
	# 台本は、箱馬を積んだのと同じ後ろから。箱馬の真上に来るので、その上に載ってもいい（低い荷物には重ねる）
	var book: Node = flow.script_prop
	check(await load_by_hand(book, "R") and above_deck(book) < 0.3, "job 1: the script is put low on the deck (%.2f m above it)" % above_deck(book))
	loaded.append(book)
	await frames(120)
	check_bed("job 1", loaded, 0.3)
	check((flow.loadout()["script"] as Array)[2], "the loaded script counts as packed")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(20)
	check(flow.phase == 3 and flow.gear().all(func(g: Node) -> bool: return flow.at_site(g)), "on departure the gear leaves the yard with the truck")
	await frames(470)
	await frames(60)
	check_arrival("job 1", 0, loaded)
	check_gear_on_site("job 1", [], [])
	await wrap_up()
	check(flow.phase == 0, "back at the office after job 1")
	check_gear_at_home("after job 1")

	# ---- 2本目：室内スタジオ（現場1）。わざわざ荷台に積んだ機材と、手に持ったままの機材 ----
	game.h_accept_job(1)
	await frames(30)
	check(flow.phase == 2 and flow.site_index() == 1, "job 2 is taken (studio)")
	var camera_b: Node = cameras[1]
	# 箱が大きくなったので、足場（1.8m）・箱・カメラの三脚は、同時には床に並ばない。足場の代わりに岩を積み、カメラは箱馬より先に積む
	loaded = await load_all("job 2", [[of_kind("rock")[0], "W", 0.0], [cartons[1], "E", 0.0], [camera_b, "E", 0.0], [of_kind("applebox")[1], "R", 0.0]])
	await frames(120)
	check_bed("job 2", loaded)
	check(flow.bed_load()["used"] == flow.bulk(loaded[0]) + flow.bulk(loaded[1]) + flow.bulk(loaded[3]), "gear loaded on purpose does not use up the deck")
	# カチンコを手に持ったまま出発する
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	var clapper: Node = game.clapper
	clapper.restore([me.global_position + Vector3(1.0, 1.0, 0), Quaternion.IDENTITY, false])
	await frames(2)
	game.h_grab(clapper.pid)
	await frames(10)
	check(clapper.holder == me.peer_id, "the clapper is in hand at departure")
	game.h_depart()
	await frames(490)
	await frames(60)
	check_arrival("job 2", 1, loaded)
	check(camera_b.rider_of == truck.pid and over_deck(camera_b), "the camera loaded on purpose arrives on the deck, not twice")
	check(clapper.holder == 0 and clapper.rider_of == 0 and me.held == 0, "the clapper held at departure is set down with the gear")
	check_gear_on_site("job 2", [camera_b], [])
	await wrap_up()
	check_gear_at_home("after job 2")

	# ---- 3本目：野外（現場2）。背の高い物の上には載せない。ふさがった置き場所はよける。台本は手に持って行く ----
	game.h_accept_job(2)
	await frames(30)
	check(flow.phase == 2 and flow.site_index() == 2, "job 3 is taken (outdoor lot)")
	var spot: Node = game.spots[0]
	# 先に背の高い物（廃板とライト）を積み、同じ場所から箱を積む
	loaded = await load_all("job 3", [[of_kind("plywood")[0], "W", PI * 0.5], [spot, "W", 0.0], [cartons[2], "W", 0.0], [cartons[3], "W", 0.0], [of_kind("applebox")[2], "W", 0.0], [of_kind("fish")[0], "W", 0.0]])
	await frames(120)
	check_bed("job 3", loaded)
	# 台本は手に持ったまま出発する
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	book.restore([me.global_position + Vector3(1.0, 1.0, 0), Quaternion.IDENTITY, false])
	await frames(2)
	game.h_grab(book.pid)
	await frames(10)
	check(book.holder == me.peer_id and (flow.loadout()["script"] as Array)[2], "the script in hand counts as packed")
	game.h_depart()
	await frames(40)
	# 道中：荷台に積んだライトが落ちる。カメラAの置き場所は、先にふさいでおく。
	# 箱が大きくなったので、はじき飛ばしても箱に受け止められて荷台に残ることがある。道へ置き直して、落ちたことにする
	game.host_unload(spot)
	spot.restore([truck.global_position + Vector3(4.0, 0.3, -3.0), Quaternion.IDENTITY, false])
	var blocker: Node = of_kind("flat")[0]
	var slot: Array = flow.gear_site("camera", 0)
	blocker.restore([Vector3(slot[0].x, 0.02, slot[0].z), Quaternion.IDENTITY, true])
	await frames(60)
	check(spot.rider_of == 0 and not flow.cargo().has(spot.pid), "the light knocked off the deck is left on the road for now")
	loaded.erase(spot)
	await frames(390)
	await frames(60)
	check_arrival("job 3", 2, loaded)
	check(flow.at_site(book) and book.holder == 0 and Vector2(book.global_position.x - game.SPAWN.x, book.global_position.z - game.SPAWN.z).length() < 6.0, "the script carried in hand arrives at the entrance (%s)" % str(book.global_position))
	# 落ちた機材も置いていかない。ふさがった場所はよけて並ぶ
	check_gear_on_site("job 3", [], [box_of(blocker)])
	# 野外の現場は突風が吹く。搬入口に並べたままの機材は、荷下ろしの間に風で倒れない（動かしたあとは、ふつうに風を受ける）
	flow.gust(Vector3(1, 0, 0.35).normalized(), 1.0)
	await frames(240)
	check_gear_on_site("job 3 after a gust", [], [box_of(blocker)])
	var card: Node = game.cue_cards.card
	card.restore([Vector3(2.0, 0.05, 4.0), Quaternion.IDENTITY, false])
	await frames(30)
	var card_at: Vector3 = card.global_position
	flow.gust(Vector3(1, 0, 0.35).normalized(), 1.0)
	await frames(120)
	check(card.global_position.distance_to(card_at) > 0.3, "gear carried onto the set catches the wind again (%.2f m)" % card.global_position.distance_to(card_at))
	await wrap_up()
	check_gear_at_home("after job 3")

	# ---- 重ねる・断る：低い荷物の真上で F を押せば上に積む。高くなるなら床へ。床が無ければ断る ----
	game.h_accept_job(4)
	await frames(30)
	var base: Node = cartons[0]
	check(await load_by_hand(base, "W") and above_deck(base) < 0.12, "a carton goes on the empty deck")
	await frames(40)
	# 箱の大きさが変わっても確かめられるよう、高さは実際の箱から測る（LOAD_HIGH より低く載るなら重ねる。高くなるなら床へ）
	var second: Node = cartons[1]
	var top: float = deck_box(base).end.y - float(truck.deck_top)
	var stacks: bool = top + 0.03 < float(game.LOAD_HIGH)
	var loaded_second: bool = await load_over(second, base)
	if stacks:
		check(loaded_second and absf(above_deck(second) - (top + 0.03)) < 0.08, "held right over a low carton, the next one is stacked on it (%.2f m above the deck)" % above_deck(second))
		await frames(90)
		check(second.rider_of == truck.pid and above_deck(second) > top - 0.15, "the stacked carton stays on top")
		top = deck_box(second).end.y - float(truck.deck_top)
	else:
		check(loaded_second and above_deck(second) < 0.12, "a carton this tall is not stacked: the next one goes to the deck floor (%.2f m above the deck)" % above_deck(second))
	var third: Node = cartons[2]
	var placed: bool = await load_over(third, base)
	check(top + 0.03 >= float(game.LOAD_HIGH) and placed and above_deck(third) < 0.12, "one more would sit too high, so it goes to the deck floor nearby (%.2f m above the deck)" % above_deck(third))
	await frames(40)
	# 小さい物から順に、床が埋まるまで積む
	var more: Array = [cartons[3]]
	for kind: String in ["applebox", "rock", "dragon_skull", "tomato_monster", "witch_cauldron", "flat", "riser", "plywood"]:
		more.append_array(of_kind(kind))
	var packed: Array = [base, second, third]
	var refused: Node = null
	for prop: Node in more:
		var took: bool = await load_by_hand(prop, "W", PI * 0.5 if prop.kind in ["plywood", "flat"] else 0.0)
		if not took:
			refused = prop
			break
		packed.append(prop)
		await frames(20)
	check(refused != null and packed.size() >= 7, "a full deck refuses the next prop (%d packed, %s refused)" % [packed.size(), refused.kind if refused else "nothing"])
	if refused != null:
		check(refused.holder == me.peer_id and refused.rider_of == 0, "the refused %s stays in hand" % refused.kind)
		game.h_release()
	await frames(90)
	var high := false
	for prop: Node3D in packed:
		if (prop != second or not stacks) and (prop.rider_of != truck.pid or above_deck(prop) > 0.2):
			high = true
			print("  %s#%d: rider=%d, %.2f m above the deck" % [prop.kind, prop.pid, prop.rider_of, above_deck(prop)])
	check(not high, "everything F packed sits on the deck floor, except the one stacked on purpose")

	print("CARGO_REACH_TEST_FAIL" if failed else "CARGO_REACH_TEST_OK")
	quit(1 if failed else 0)
