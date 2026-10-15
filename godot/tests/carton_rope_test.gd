extends SceneTree
# 運ぶ仕組み（段ボール箱とロープ）を確かめる。
#   段ボール置き場：箱は16個。置き場に4個出ていて、持っていくと次が出る。山から手にもらえる。無くなったら断られる
#   箱の大きさ：前の約1.3倍（比率は同じ）。今までどおり開け閉めでき、街役の既定
#   箱詰め：入る物・入らない物（箱・機材・台本・パネル・印・大きい物・接着した物・固定した物）。
#     入る量は箱の内側の広さで決まる（数では数えない。くわしくは carton_pack_test.gd）
#   入れると見えなくなり、箱を荷台に積めば「持っていく物」と配役表に数えられる。荷台のかさは箱の分だけ
#   ロープ：荷台のフックに端を結び、荷物をはさんだ向こうのフックに結ぶと、物理のロープが荷物の上に掛かる（棒ではない）。
#     きちんと掛けて張った荷物は、道中で動かない。掛けていない・たるんだロープの荷物は、ずれる・落ちる。
#     1本で2つ押さえられる。束の長さが足りないと掛けきれない。ほどける。はさみで切ると押さえが外れる。
#     数字の表示は無い。置いて数秒でロープが止まる。現場に着いても掛かったまま（自分でほどく）
#   現場：箱ごと届き、取り出せる。見返しは記録どおり、撮り直しでテイク前の中身に戻る。帰社で全部元へ
#   godot --headless --path godot --fixed-fps 60 --script res://tests/carton_rope_test.gd
const BESIDE := 1.0          # フックの外に立って束・はさみを手に持つとき、いったん置く所までの距離（荷台の外）
var game: Node
var flow: Node
var kit: Node
var me: Node
var truck: Node
var failed := false


func _initialize() -> void:
	create_timer(236).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CARTON_ROPE_CHECK ", label, " ", "OK" if ok else "FAIL")
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


func any_of(kind: String) -> Node:
	for pid: int in game.props:
		if game.props[pid].kind == kind:
			return game.props[pid]
	return null


# 置き直す（動かないよう固定はしない）
func put(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = false
	prop.restore(state)


# 目の前に置いて、手に持つ。ahead＝置く所までの距離（持った物は、その位置のまま手に付いて来る。
# フックの外に立って 1.4m 先に置くと荷台の中に入り、積んだ箱を突き飛ばす。軽トラの横では BESIDE）
func take(prop: Node, ahead: float = 1.4) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	put(prop, me.global_position + Vector3(0, 1.0, 0) + me.flat_forward() * ahead)
	await frames(2)
	game.h_grab(prop.pid)
	await frames(3)


# 物を持って、箱に入れる（F を押したのと同じ頼み方）。入ったかどうかを返す
func pack(prop: Node, box: Node) -> bool:
	await take(prop)
	kit.h_pack(prop.pid, box.pid)
	await frames(3)
	var done: bool = prop.stored_in == box.pid
	if not done and prop.holder != 0:
		game.h_release()
		await frames(2)
	return done


# 荷台の西側に立って、目の前に持った物を F で積む
func load_by_hand(prop: Node, turn: float = 0.0, along: float = -1.2) -> bool:
	if me.held != 0:
		game.h_release()
		await frames(2)
	if prop.rider_of != 0:
		game.host_unload(prop)
	var facing := Quaternion(Vector3.UP, turn)
	var box: AABB = Transform3D(Basis(facing), Vector3.ZERO) * (game.body_bounds(prop) as AABB)
	var reach: float = box.size.x * 0.5
	# 幅の広い物でも軽トラのそば（4.5m 以内）に立てるよう、物の横に立つ
	me.global_position = truck.global_transform * Vector3(-2.9, 0.1, along + box.size.z * 0.5 + 1.6)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(-(1.5 + reach) - box.get_center().x, 0.5 - box.position.y, along - box.get_center().z), facing, false])
	await frames(2)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(3)
	if prop.rider_of != truck.pid and prop.holder != 0:
		game.h_release()
	return prop.rider_of == truck.pid


# そのフックの外側に立って、軽トラのほうを向く（手に持った物が、フックのそばに来る）
func stand_at(hook: int) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	var local: Vector3 = truck.hooks[hook]
	var spot: Vector3 = truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)
	var to: Vector3 = kit.hook_at(hook) - spot
	me.global_position = Vector3(spot.x, truck.global_position.y + 0.1, spot.z)
	me.aim_yaw = atan2(-to.x, -to.z)
	me.aim_pitch = -0.1
	await frames(3)


# 束を持って、フック from に結び、フック to に結ぶ。near＝2つ目のフックのそばまで歩いて結ぶ（false＝1つ目のそばから投げる）。
# できたロープの番号を返す（掛けきれなければ 0）
func lash(from: int, to: int, near: bool = true) -> int:
	var before: Array = kit.lashes.keys()
	await stand_at(from)
	await take(kit.rope, BESIDE)
	kit.h_hook(from)
	await frames(15)
	if near:
		await stand_at(to)
		await take(kit.rope, BESIDE)
		await frames(10)
	kit.h_hook(to)
	await frames(15)
	game.h_release()
	await frames(2)
	for id: int in kit.lashes:
		if id not in before and int(kit.lashes[id]["b"]) >= 0:
			return id
	return 0


# その点に照準を合わせる（確かめる直前に呼ぶ。次のコマで、カメラは元に戻る）
func aim(point: Vector3) -> void:
	var from: Vector3 = me.global_position + Vector3(0, 1.6, 0)
	me.cam.look_at_from_position(from + (from - point).normalized() * 0.5, point, Vector3.UP)


func has_digit(text: String) -> bool:
	for ch: String in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


# いまのロープの様子を書き出す（確認の結果を読むときの手がかり）
func note(tag: String, props: Array) -> void:
	var text := ""
	for id: int in kit.lashes:
		var l: Dictionary = kit.lashes[id]
		text += " rope%d[%d>%d len=%.2f slack=%.3f asleep=%s]" % [id, int(l["a"]), int(l["b"]), float(l["cord"].length), float(l["slack"]), str(l["cord"].asleep)]
	for prop: Node in props:
		text += " %s:hold=%.2f%s" % [prop.kind, kit.grip_of(prop.pid), "(pinned)" if kit.pinned(prop.pid) else ""]
	print("CARTON_ROPE_NOTE ", tag, " stock=%.2f" % kit.stock(), text)


# 軽トラから見た、物の真ん中
func on_truck(prop: Node3D) -> Vector3:
	return truck.global_transform.affine_inverse() * prop.center_global()


# ロープの節のうち、その物の真上（上面の高さのあたり）にある数
func knots_over(cord: Node3D, prop: Node3D) -> int:
	var box: AABB = game.body_bounds(prop)
	var inv: Transform3D = prop.global_transform.affine_inverse()
	var count := 0
	for point: Vector3 in cord.pts:
		var l: Vector3 = inv * point
		if l.x > box.position.x - 0.03 and l.x < box.end.x + 0.03 and l.z > box.position.z - 0.03 and l.z < box.end.z + 0.03 and l.y > box.end.y - 0.3 and l.y < box.end.y + 0.15:
			count += 1
	return count


# ロープの節のうち、軽トラから見た横の位置が from〜to の間にある物の、高さの平均（たるむと下がる）
func height_between(cord: Node3D, from: float, to: float) -> float:
	var inv: Transform3D = truck.global_transform.affine_inverse()
	var sum := 0.0
	var count := 0
	for point: Vector3 in cord.pts:
		var l: Vector3 = inv * point
		if l.x > from and l.x < to:
			sum += l.y
			count += 1
	return sum / float(maxi(count, 1))


# ロープが止まる（眠る）まで待つ。止まらなければ limit コマで打ち切る（確かめる側で asleep を見る）
func settle(cord: Node3D, limit: int = 600) -> void:
	for i in limit:
		if cord.asleep:
			return
		await physics_frame


# 撮らずに納品して、事務所へ戻る
func wrap_up() -> void:
	flow.lease_left = 0.01
	await frames(4)
	game.h_deliver(0)
	await frames(4)
	game.h_return_office()
	await frames(60)


func out_cartons() -> Array:
	return kit.cartons.filter(func(b: Node) -> bool: return not b.absent)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(20)
	flow = game.production
	kit = game.cargo_kit
	kit.spill_chance = 0.0        # 道中で箱からこぼれるかどうかは、carton_pack_test.gd で確かめる（ここでは、こぼさない）
	me = game.local_player()
	truck = game.truck
	var S: Dictionary = game.S
	var yard: Rect2 = kit.YARD

	# ---- 段ボール置き場 ----
	check(kit != null and kit.cartons.size() == kit.CARTON_COUNT and kit.CARTON_COUNT >= 16, "there are %d cartons in all" % kit.cartons.size())
	var shown: Array = out_cartons()
	check(shown.size() == kit.SHOWN and kit.reserve().size() == kit.CARTON_COUNT - kit.SHOWN, "%d cartons stand in the carton yard and %d wait in reserve" % [shown.size(), kit.reserve().size()])
	check(shown.all(func(b: Node3D) -> bool: return yard.has_point(Vector2(b.global_position.x, b.global_position.z)) and b.opened and not b.fixed and b.global_basis.y.y > 0.97), "the cartons in the yard stand open inside its outline")
	check(yard.has_point(Vector2(kit.pile.global_position.x, kit.pile.global_position.z)) and yard.has_point(Vector2(kit.rope.global_position.x, kit.rope.global_position.z)), "the pile and the rope are in the carton yard")
	# 置き場は、軽トラと廃材置き場の間。機材置き場・軽トラの横の立ち位置・荷台の横をふさがない
	var gate: Vector3 = flow.Yard.gate_point()
	check(yard.get_center().x > gate.x and yard.end.x < flow.HOME_TRUCK.x - 2.0, "the carton yard lies between the scrap yard gate and the truck")
	var clear := not yard.grow(0.6).intersects(flow.Office.GEAR_YARD)
	for z: float in [0.0, 0.6, 1.2]:
		clear = clear and not yard.grow(1.0).has_point(Vector2(flow.HOME_TRUCK.x - 3.0, flow.HOME_TRUCK.z + z))
	check(clear, "the carton yard keeps clear of the gear yard and of the spot beside the truck")
	check(not flow.Yard.Slots.SLOTS.has("carton") and flow.yard_stock().all(func(row: Array) -> bool: return row[0] != "carton"), "cartons are no longer part of the daily scrap")

	# 大きさ：前（拡大率 2.0 で 幅0.83×高さ0.56×奥行0.61）の約1.3倍。全方向に同じ倍率
	var box_a: Node = shown[0]
	var body: AABB = game.body_bounds(box_a)
	var ratio := Vector3(body.size.x / 0.83, body.size.y / 0.56, body.size.z / 0.61)
	check(ratio.x > 1.25 and ratio.x < 1.36 and absf(ratio.x - ratio.y) < 0.03 and absf(ratio.x - ratio.z) < 0.03, "a carton is about 1.3 times as big in every direction (%.2f x %.2f x %.2f m)" % [body.size.x, body.size.y, body.size.z])
	check(is_equal_approx(box_a.visual.scale.x, box_a.visual.scale.y) and is_equal_approx(box_a.visual.scale.x, box_a.visual.scale.z), "the model keeps its proportions")
	check(box_a.room.size.x > 0.9 and box_a.room.size.z > 0.6 and box_a.room.end.y < body.end.y, "the room inside follows the size (%.2f x %.2f x %.2f m)" % [box_a.room.size.x, box_a.room.size.y, box_a.room.size.z])

	# ---- 依頼を受ける（怪獣映画）。箱は街役の既定のまま ----
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	await frames(20)
	check(flow.phase == 2 and flow.role_of(box_a) == "city", "after taking a job the cartons are still the default city")

	# 持っていくと、空いた所に次の箱が出る
	me.global_position = Vector3(yard.get_center().x, 0.1, yard.position.y - 1.6)
	me.aim_yaw = PI
	put(box_a, Vector3(yard.position.x + 1.5, 0.3, yard.position.y - 4.0))
	await frames(50)
	check(out_cartons().size() == kit.SHOWN + 1 and kit.reserve().size() == kit.CARTON_COUNT - kit.SHOWN - 1, "when a carton is carried away the next one appears in its place (%d out)" % out_cartons().size())
	# 山を見て F：手に1箱
	me.global_position = kit.pile.global_position + Vector3(1.9, 0.1, 0.0)
	me.aim_yaw = PI * 0.5
	await frames(2)
	me.target = kit.pile
	check(kit.f_action(me).get("do", "") == "take", "aiming at the pile with empty hands offers a carton")
	var before: int = out_cartons().size()
	kit.h_take_carton()
	await frames(4)
	var handed: Node = game.props.get(me.held)
	check(handed != null and handed.kind == "carton" and handed.holder == me.peer_id and out_cartons().size() == before + 1 and handed.opened, "F on the pile puts a fresh open carton in the hands")
	check(handed != null and handed.global_position.distance_to(me.global_position) < 3.0, "the carton appears at the hands (%.2f m away)" % (handed.global_position.distance_to(me.global_position) if handed != null else -1.0))
	kit.h_take_carton()
	await frames(2)
	check(out_cartons().size() == before + 1, "with full hands no second carton is handed out")
	# 何個も出せる。無くなったら断られる
	var park := Vector3(yard.position.x - 2.0, 0.3, yard.position.y - 6.0)
	var took := 0
	while took < 20:
		if me.held != 0:
			var mine: Node = game.props[me.held]
			game.h_release()
			await frames(1)
			put(mine, park + Vector3(-1.4 * float(took % 6), 0.0, -1.5 * float(took / 6)))
			mine.set_fixed(true)
		if kit.reserve().is_empty():
			break
		kit.h_take_carton()
		await frames(3)
		took += 1
	check(kit.reserve().is_empty() and out_cartons().size() == kit.CARTON_COUNT, "every carton can be taken out (%d out)" % out_cartons().size())
	kit.h_take_carton()
	await frames(3)
	check(me.held == 0 and out_cartons().size() == kit.CARTON_COUNT, "when the pile is used up, nothing more comes out")
	me.target = kit.pile
	check("もう無い" in str(kit.hud_view(me).get("tail", "")), "and the hint says the pile is used up")
	me.target = null

	# ---- 箱詰め：入る物・入らない物 ----
	var fish: Node = of_kind("fish")[0]
	var pie: Node = of_kind("scrap_pie")[0]
	var crown: Node = of_kind("crown")[0]
	var letter: Node = of_kind("letter")[0]
	var tape: Node = of_kind("tape")[0]
	var skull: Node = of_kind("dragon_skull")[0]
	var duck: Node = of_kind("scrap_duck")[0]
	var toilet: Node = of_kind("scrap_toilet")[0]
	var rock: Node = of_kind("rock")[0]
	check(kit.fits_alone(fish) and kit.fits_alone(pie) and kit.fits_alone(skull) and kit.fits_alone(duck) and kit.fits_alone(toilet) and not kit.fits_alone(rock), "what fits is decided by real size: a fish, a pie, the skull, the duck and a toilet fit an empty carton, a foam rock does not")
	var box_b: Node = shown[1]
	var box_c: Node = shown[2]
	var bench := Vector3(flow.HOME_TRUCK.x - 6.5, 0.1, flow.HOME_TRUCK.z + 5.5)       # 軽トラの南西の空いた所で詰める
	me.global_position = bench
	me.aim_yaw = 0.0
	put(box_b, bench + Vector3(0, 0.1, -1.8))
	put(box_c, bench + Vector3(1.6, 0.1, -1.8))
	await frames(40)
	var refused: Array = []
	for kind: String in ["carton", "camera", "spot", "clapper", "cue_card", "monitor", "script", "standin", "mark", "rope", "glue"]:
		var thing: Node = any_of(kind) if kind != "carton" else shown[3]
		if kit.pack_problem(thing, box_b) == "":
			refused.append(kind)
	check(refused.is_empty(), "cartons, gear, the script, the stand-in, marks and tools are refused (%s)" % str(refused))
	check(kit.pack_problem(game.fx, box_b) != "" and kit.pack_problem(rock, box_b) != "" and kit.pack_problem(of_kind("plywood")[0], box_b) != "", "the bomb and big props are refused")
	check(kit.pack_problem(fish, box_b) == "" and kit.pack_problem(toilet, box_b) == "", "a rubber fish and a toilet may go in")
	# 断られた物は手に残り、失格にもならない
	check(not (await pack(rock, box_b)) and rock.stored_in == 0 and not rock.absent, "a refused prop stays out of the carton")
	put(rock, bench + Vector3(-3.0, 0.3, 0.0))
	# 固定した物・接着した物
	fish.set_fixed(true)
	check(kit.pack_problem(fish, box_b) != "", "a fixed prop is refused")
	fish.set_fixed(false)
	game.adhesive.pairs.append({"a": crown.pid, "b": letter.pid, "pa": Vector3.ZERO, "pb": Vector3.ZERO, "joined": true})
	check(kit.pack_problem(crown, box_b) != "" and kit.pack_problem(letter, box_b) != "", "glued props are refused")
	game.adhesive.pairs.clear()
	# 閉じた箱には入らない
	game.h_toggle_carton(box_b.pid)
	await frames(30)
	check(not box_b.opened and not box_b.lid.disabled and kit.pack_problem(fish, box_b) != "", "a closed carton has a lid to stand on and takes nothing")
	game.h_toggle_carton(box_b.pid)
	await frames(30)
	check(box_b.opened and box_b.lid.disabled, "F opens it again")

	# ---- 入れる：見えなくなり、箱の中身になる ----
	var empty_mass: float = box_b.mass
	check(await pack(fish, box_b), "the rubber fish goes into the open carton")
	check(fish.absent and not fish.visible and fish.collision_layer == 0 and fish.holder == 0 and me.held == 0, "a packed prop is hidden, has no collision and leaves the hands")
	check(fish.global_position.y < -30.0, "the host parks it out of the world")
	check(kit.box_items(box_b) == [fish] and "ゴムの魚" in kit.box_note(box_b) and not has_digit(kit.box_note(box_b)), "the carton lists it, with no numbers: %s" % kit.box_note(box_b))
	var inside: Node = box_b.get_node_or_null("Inside")
	check(inside != null and inside.get_child_count() == 1 and box_b.get_node_or_null("Fill%d" % fish.pid) != null and box_b.get_node_or_null("KitNote") == null, "the contents show inside the carton at full size; no tag hangs over it all the time")
	check(box_b.mass > empty_mass + 0.4, "the carton gets heavier (%.1f kg)" % box_b.mass)
	check(not flow.cargo().has(fish.pid) and not flow.cargo().has(box_b.pid), "a carton on the ground is not cargo yet")
	# 小さい物は、4つ入れても、まだ入る（数では数えない）
	check(await pack(pie, box_b) and await pack(crown, box_b) and await pack(letter, box_b), "three more small props fit")
	check(kit.pack_problem(tape, box_b) == "" and not kit.lid_blocked(box_b), "four small props do not fill a carton: there is room for more, and the lid can still close")
	put(tape, bench + Vector3(-2.0, 0.3, 1.0))
	# 中くらいの物は2つ。トイレは入るが、口からはみ出して、ふたが閉まらない
	check(await pack(skull, box_c) and await pack(duck, box_c), "two medium props go into one carton")
	var box_d: Node = shown[3]
	put(box_d, bench + Vector3(-1.6, 0.1, -1.8))
	await frames(20)
	check(await pack(toilet, box_d) and kit.lid_blocked(box_d), "a toilet goes in, but it sticks out of the top")
	me.global_position = box_d.global_position + Vector3(0, 0.1, 1.2)
	game.h_toggle_carton(box_d.pid)
	await frames(6)
	check(box_d.opened, "and the lid of that carton will not close")
	# 手ぶらで箱を見て F：見ている物（ここでは、決めた物）が出てくる
	me.global_position = bench
	await frames(2)
	me.target = box_b
	game.input_locked = false
	kit._show_note(me)
	game.input_locked = true
	check(kit.f_action(me).get("do", "") == "unpack" and kit._note.visible and "ゴムの魚" in kit._note.text and not has_digit(kit._note.text), "aiming at a filled carton offers to take a prop out and shows the contents above it (%s)" % kit._note.text)
	me.target = null
	kit._show_note(me)
	check(not kit._note.visible, "the tag goes away when the carton is no longer aimed at")
	kit.h_unpack(box_b.pid, letter.pid)
	await frames(4)
	check(me.held == letter.pid and letter.stored_in == 0 and not letter.absent and letter.visible and letter.collision_layer != 0, "F takes the chosen prop out, into the hands")
	check(letter.global_position.distance_to(me.global_position) < 3.0 and kit.box_items(box_b) == [fish, pie, crown], "it appears at the hands and the carton keeps the rest")
	# 持っている物と、開いた箱：F は「箱に入れる」（照準は毎フレーム決め直されるので、確かめる直前に合わせる）
	me.target = box_b
	check(kit.f_action(me).get("do", "") == "pack" and kit.f_action(me).get("why", "x") == "", "holding a prop and aiming at an open carton offers to pack it")
	me.target = null
	kit.h_pack(letter.pid, box_b.pid)
	await frames(3)
	check(letter.stored_in == box_b.pid, "and it goes back in")

	# ---- 箱ごと積む：中身も「持っていく物」と配役表に数える。荷台のかさは箱の分だけ ----
	check(flow.role_of(skull) == "monster", "the dragon skull in the carton keeps its monster role")
	check(not (flow.cast_sheet()["rows"] as Array).any(func(r: Dictionary) -> bool: return r["role"] == "monster" and int(r["grade"]) >= 0), "before loading, the casting sheet has no monster")
	check(await load_by_hand(box_b, 0.0, -0.1), "the full carton is loaded with F")
	check(await load_by_hand(box_c, 0.0, -1.0), "the carton with the dragon skull is loaded with F")
	await frames(60)
	var riding: Array = flow.cargo(false)
	check(riding.has(box_b.pid) and riding.has(fish.pid) and riding.has(letter.pid) and riding.has(skull.pid) and not riding.has(toilet.pid), "the truck carries the cartons and what is in them (not the carton left on the ground)")
	check(flow.bed_load()["used"] == flow.bulk(box_b) + flow.bulk(box_c), "only the cartons use up the deck (%d)" % flow.bed_load()["used"])
	check((flow.cast_sheet()["rows"] as Array).any(func(r: Dictionary) -> bool: return r["role"] == "monster" and "竜" in str(r["items"])), "the casting sheet counts the skull inside the loaded carton")
	check((flow.loadout()["items"] as Array).any(func(row: Array) -> bool: return row[0] == "fish") and (flow.loadout()["items"] as Array).any(func(row: Array) -> bool: return row[0] == "carton" and int(row[2]) == 2), "the packing sheet lists the cartons and their contents")

	# ---- ロープ：荷台のフック ----
	var green: Node = of_kind("greenscreen")[0]
	var partition: Node = of_kind("partition")[0]
	var bk: Node = game.bomb_kit
	var hooks: Array = truck.hooks
	var sides := [0, 0]
	for at: Vector3 in hooks:
		sides[0 if at.x < 0.0 else 1] += 1
	var hook_root: Node = truck.get_node_or_null("RopeHooks")
	check(hooks.size() >= 10 and sides[0] == sides[1] and hook_root != null and hook_root.get_child_count() == hooks.size(), "the truck has %d rope hooks, the same number on each side, each with a ring to see" % hooks.size())
	var rear_end: float = float(truck.deck_c.y) - float(truck.deck_half.y)
	check(hooks.all(func(at: Vector3) -> bool: return absf(at.x) > float(truck.deck_half.x) - 0.02) and hooks.any(func(at: Vector3) -> bool: return at.z < rear_end + 0.3), "the hooks sit along the edges of the bed, down to its rear corners")
	check(absf(on_truck(box_b).z - (hooks[4] as Vector3).z) < 0.3, "the first carton stands between a pair of hooks (%.2f m along the bed, hooks at %.2f m)" % [on_truck(box_b).z, (hooks[4] as Vector3).z])
	var texts: Array = []          # ロープの案内の文（数字が無いことを、あとで確かめる）

	# 束を持つ：案内は動作だけ
	kit.rng.seed = 11
	await stand_at(4)
	await take(kit.rope, BESIDE)
	check(me.held == kit.rope.pid and is_equal_approx(kit.stock(), float(bk.COIL_M)), "the rope coil is in hand, with all its rope on it")
	aim(me.global_position + Vector3(0, 30, 0) + me.flat_forward())          # 何も狙っていない
	var hint: String = str(kit.hud_view(me).get("keys_all", ""))
	texts.append(hint.get_slice("\n", 0))
	check("結ぶ" in hint and "つなぐ" in hint, "holding the coil: the hint offers tying to a hook and connecting to the bomb")
	aim(kit.hook_at(4))
	var act: Dictionary = kit.f_action(me)
	texts.append(str(kit.hud_view(me).get("keys_all", "")).get_slice("\n", 0))
	check(act.get("do", "") == "hook" and int(act.get("hook", -1)) == 4 and str(kit.hud_view(me).get("keys_all", "")).begins_with("F フックに結ぶ"), "aiming at a hook offers: F, tie to the hook")
	# 1つ目のフックに結ぶ：ロープは、フックから束まで
	kit.h_hook(4)
	await frames(15)
	var open: Dictionary = kit.open_lash()
	check(not open.is_empty() and int(open.get("a", -1)) == 4 and kit.lash_count() == 0, "F ties one end to the hook; the other end is still on the coil")
	var cord: Node3D = open["cord"]
	check(cord.root().distance_to(kit.hook_at(4)) < 0.05 and cord.tip().distance_to(kit.rope.global_transform * kit._coil_exit()) < 0.15 and kit.stock() < float(bk.COIL_M), "the rope runs from the hook to the coil and comes off the coil")
	aim(kit.hook_at(4))
	texts.append(str(kit.hud_view(me).get("keys_all", "")).get_slice("\n", 0))
	check(kit.f_action(me).get("do", "") == "unhook" and str(kit.hud_view(me).get("keys_all", "")).begins_with("F ほどく"), "aiming at the same hook offers to untie it again")
	# 束を持って反対側へ：ロープが束から出ていく
	await stand_at(9)
	await take(kit.rope, BESIDE)
	await frames(40)
	check(cord.length > 2.0 and absf(kit.stock() + cord.length - float(bk.COIL_M)) < 0.01, "carrying the coil to the other side pays the rope out (%.2f m)" % cord.length)
	# 2つ目のフックに結ぶ：1本のロープが、箱の上に掛かる
	aim(kit.hook_at(9))
	check(kit.f_action(me).get("do", "") == "hook" and int(kit.f_action(me).get("hook", -1)) == 9, "aiming at the hook across the bed offers to tie the other end")
	kit.h_hook(9)
	await frames(30)
	var first: int = int(open["id"])
	check(kit.lash_count() == 1 and kit.open_lash().is_empty() and int(kit.lashes[first]["b"]) == 9, "F ties the other end: one rope from hook to hook")
	check(cord.root().distance_to(kit.hook_at(4)) < 0.05 and cord.tip().distance_to(kit.hook_at(9)) < 0.05 and absf(kit.stock() + cord.length - float(bk.COIL_M)) < 0.01, "both ends are on their hooks; what was pulled tight went back onto the coil (%.2f m of rope used)" % cord.length)
	game.h_release()
	await frames(360)
	# 形：荷物の上に掛かっている。棒ではない（フックから側板の外を上がり、箱の上を通り、反対側へ下りる）
	var top_b: float = (box_b.global_transform * (game.body_bounds(box_b) as AABB)).end.y
	var highest := -INF
	for point: Vector3 in cord.pts:
		highest = maxf(highest, point.y)
	check(knots_over(cord, box_b) >= 6 and absf(highest - top_b) < 0.12, "the rope lies across the top of the carton (%d knots there, highest %.2f m, carton top %.2f m)" % [knots_over(cord, box_b), highest, top_b])
	var chord: float = cord.root().distance_to(cord.tip())
	check(cord.length > chord * 1.25 and highest > kit.hook_at(4).y + 0.6, "it is not a straight rod: %.2f m of rope for %.2f m between the hooks" % [cord.length, chord])
	# 置いて数秒で止まる
	var rest: PackedVector3Array = cord.pts.duplicate()
	check(cord.asleep and cord.speed() == 0.0, "a few seconds after tying, the rope is at rest")
	await frames(90)
	check(cord.pts == rest, "and it stays still (no knot moves)")
	# 効き目：きちんと掛けて張ったロープは、箱を押さえる
	check(float(kit.lashes[first]["slack"]) < 0.08 and kit.grip_of(box_b.pid) >= kit.FIRM_ON and kit.pinned(box_b.pid), "tied by hand over the middle of the carton, the rope holds it (slack %.2f m, hold %.2f)" % [float(kit.lashes[first]["slack"]), kit.grip_of(box_b.pid)])
	check(kit.grip_of(box_c.pid) == 0.0 and not kit.pinned(box_c.pid), "the carton with no rope over it is not held")
	# 押さえた物は、引っぱっても抜けない
	me.global_position = truck.global_transform * Vector3(-2.3, 0.1, -0.1)
	game.h_grab(box_b.pid)
	await frames(2)
	check(box_b.holder == 0 and "ロープ" in game.grab_block(box_b) and game.grab_block(box_c) == "", "a carton held by the rope cannot be pulled out, and the notice names the rope")
	# 押さえてあっても、箱の出し入れはできる
	kit.h_unpack(box_b.pid, letter.pid)
	await frames(4)
	check(me.held == letter.pid, "a prop can still be taken out of a roped carton")
	kit.h_pack(letter.pid, box_b.pid)
	await frames(3)
	check(letter.stored_in == box_b.pid, "and put back")
	# 手ぶらで、掛けたロープを見る：F でほどく
	aim(cord.point_at(cord.length * 0.5))
	act = kit.f_action(me)
	texts.append(str(kit.hud_view(me).get("label", "")) + str(kit.hud_view(me).get("keys_all", "")))
	check(act.get("do", "") == "untie" and int(act.get("lash", 0)) == first and kit.hud_view(me).get("label", "") == "ロープ" and str(kit.hud_view(me).get("keys_all", "")) == "F ほどく", "with empty hands, aiming at the rope offers: F, untie")

	# ---- 1本で2つ押さえる ----
	var spare: Node = null
	for box: Node in kit.cartons:
		if not box.absent and box.fixed and spare == null:
			spare = box
	spare.set_fixed(false)
	put(box_c, truck.global_transform * Vector3(-0.42, float(truck.deck_top) + 0.05, (hooks[2] as Vector3).z), PI * 0.5)
	put(spare, truck.global_transform * Vector3(0.42, float(truck.deck_top) + 0.05, (hooks[2] as Vector3).z), PI * 0.5)
	await frames(50)
	game._try_load(box_c)
	game._try_load(spare)
	var both: int = await lash(2, 7, true)
	await frames(60)
	check(both != 0 and kit.lash_count() == 2, "a second rope goes over two cartons standing side by side")
	check(kit.grip_of(box_c.pid) >= kit.FIRM_ON and kit.grip_of(spare.pid) >= kit.FIRM_ON, "one rope holds both (hold %.2f and %.2f)" % [kit.grip_of(box_c.pid), kit.grip_of(spare.pid)])

	# ---- はさみで切る：もう押さえない ----
	var rope_two: Node3D = kit.lashes[both]["cord"]
	var used_two: float = rope_two.length
	await stand_at(7)
	await take(bk.scissors, BESIDE)
	var mid: float = rope_two.length * 0.5
	aim(rope_two.point_at(mid))
	act = kit.f_action(me)
	texts.append(str(kit.hud_view(me).get("label", "")) + str(kit.hud_view(me).get("keys_all", "")).get_slice("\n", 0))
	check(act.get("do", "") == "cut" and int(act.get("lash", 0)) == both and str(kit.hud_view(me).get("keys_all", "")).begins_with("F 切る"), "with the scissors, aiming at the rope offers: F, cut")
	kit.h_cut_lash(both, mid)
	await frames(90)
	var pieces: Array = kit.lashes.values().filter(func(l: Dictionary) -> bool: return int(l["b"]) == kit.END_FREE)
	var roots: Array = pieces.map(func(l: Dictionary) -> int: return int(l["a"]))
	roots.sort()
	check(kit.lash_count() == 1 and pieces.size() == 2 and roots == [2, 7], "the cut rope is two loose ends, each hanging from its hook")
	check(kit.grip_of(box_c.pid) == 0.0 and kit.grip_of(spare.pid) == 0.0 and not kit.pinned(box_c.pid), "a cut rope holds nothing any more")
	check(kit.pinned(box_b.pid), "the other rope still holds its carton")
	var low_ends := true
	for piece: Dictionary in pieces:
		low_ends = low_ends and (piece["cord"] as Node3D).tip().y < top_b - 0.2
	check(low_ends, "the cut ends have dropped down")
	# ほどく：束に巻き戻る
	game.h_release()
	await frames(2)
	# はさみは片付ける（フックの横に落ちたままだと、あおりに立てかかり、次にそのフックへ結ぶロープが、はさみの先に載る）
	bk.scissors.restore((flow._home_layout[bk.scissors.pid] as Array).duplicate())
	var before_untie: float = kit.stock()
	for piece: Dictionary in pieces:
		kit.h_untie(int(piece["id"]))
	await frames(4)
	check(kit.lashes.size() == 1 and absf(kit.stock() - before_untie - used_two) < 0.05, "F on a rope unties it and winds it back onto the coil (%.2f m back)" % (kit.stock() - before_untie))

	# ---- たるんだロープ・低い物・束の長さ ----
	put(spare, park + Vector3(1.4, 0.0, 1.5))
	spare.set_fixed(true)
	var low_box: Node = of_kind("applebox")[0]
	put(low_box, truck.global_transform * Vector3(0.55, float(truck.deck_top) + 0.05, (hooks[2] as Vector3).z))
	await frames(40)
	var again: int = await lash(2, 7, true)
	await frames(120)
	var rope_c: Node3D = kit.lashes[again]["cord"]
	check(kit.pinned(box_c.pid) and kit.grip_of(low_box.pid) == 0.0, "the rope holds the carton it rests on; the low apple box beside it, which the rope does not touch, is not held")
	await settle(rope_c)
	note("tight over box_c", [box_b, box_c, low_box])
	var sag_tight: float = height_between(rope_c, -1.0, 1.0)
	kit.host_loosen(again, 0.35)
	await frames(360)
	note("loosened", [box_b, box_c])
	var sag_loose: float = height_between(rope_c, -1.0, 1.0)
	check(sag_loose < sag_tight - 0.08 and rope_c.asleep, "a slack rope hangs visibly lower between the side boards (%.2f m on average against %.2f m) and comes to rest" % [sag_loose, sag_tight])
	check(kit.grip_of(box_c.pid) < kit.FIRM_OFF and not kit.pinned(box_c.pid), "a slack rope does not hold the carton (hold %.2f)" % kit.grip_of(box_c.pid))
	game.host_unload(low_box)
	put(low_box, bench + Vector3(3.0, 0.3, 1.0))
	# 背の高い物に掛けるには、たくさんロープが要る：束の残りでは届かない
	check(await load_by_hand(partition, 0.0, (hooks[1] as Vector3).z), "the folding partition is loaded across the side boards")
	check(game.overhangs(partition, truck), "it is wider than the deck")
	await frames(40)
	var coil_look: float = kit.rope.visual.scale.x
	var left_over: float = kit.stock()
	check(coil_look < float(game.stage.DEFS["rope"]["scale"]) * 0.9, "the coil looks thinner once rope has been used")
	# 1つ目のフックのそばから、向こうのフックへ投げて結ぼうとする：届かないので、結べない
	var third: int = await lash(1, 6, false)
	check(third == 0 and kit.lash_count() == 2 and not kit.open_lash().is_empty() and int(kit.open_lash()["a"]) == 1, "with %.1f m left on the coil the rope does not reach over the tall partition: the second end is refused" % left_over)
	await stand_at(1)
	await take(kit.rope, BESIDE)
	kit.h_hook(1)
	await frames(4)
	check(kit.open_lash().is_empty() and absf(kit.stock() - left_over) < 0.05, "F on the first hook again takes the rope back")
	# 束を持って向こう側まで歩く：途中でロープを使い切って、先が束から外れる
	third = await lash(1, 6, true)
	var dropped: Array = kit.lashes.values().filter(func(l: Dictionary) -> bool: return int(l["b"]) == kit.END_FREE)
	check(third == 0 and kit.lash_count() == 2 and kit.open_lash().is_empty() and dropped.size() == 1 and int(dropped[0]["a"]) == 1 and kit.stock() < 0.05, "carried round to the far hook, the coil runs out and the rope end drops off it (%.2f m left)" % kit.stock())
	if dropped.size() == 1:
		kit.h_untie(int(dropped[0]["id"]))
	await frames(4)
	check(kit.lashes.size() == 2 and absf(kit.stock() - left_over) < 0.05, "untying the dropped rope winds it back onto the coil")
	# 数字・一覧は出さない
	check(texts.all(func(t: String) -> bool: return t != "" and not has_digit(t)), "the rope hints name actions only, with no numbers (%s)" % " / ".join(texts))
	check(not flow.bed_load().has("tied") and (flow.loadout()["items"] as Array).all(func(row: Array) -> bool: return row.size() == 4), "the packing sheet lists nothing about ropes")
	var tags := 0
	for l: Dictionary in kit.lashes.values():
		tags += (l["cord"] as Node).find_children("*", "Label3D", true, false).size()
	check(tags == 0 and hook_root.find_children("*", "Label3D", true, false).is_empty(), "no number tags on the ropes or the hooks")

	# ---- 1回目の移動：張ったロープの箱は動かない。たるんだロープの箱はずれる。掛けていない背の高い物は落ちる ----
	await frames(120)
	note("before trip 1", [box_b, box_c, partition])
	var held_at: Vector3 = on_truck(box_b)
	var loose_at: Vector3 = on_truck(box_c)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	# 走っている間ずっと（発進から、1つ目の段差を越えたあとまで）、荷台の上でのずれのいちばん大きい値を見る
	var drift := 0.0
	for i in 200:
		await physics_frame
		drift = maxf(drift, on_truck(box_b).distance_to(held_at))
	note("trip 1, driving", [box_b, box_c, partition])
	check(flow.phase == 3 and drift < 0.01, "a carton under a tight rope does not move on the deck while driving, over the first bump too (%.3f m at most)" % drift)
	check(cord.root().distance_to(kit.hook_at(4)) < 0.05 and knots_over(cord, box_b) >= 6, "the rope rides along with the truck, still across the carton")
	while flow.phase == 3:
		await physics_frame
	await frames(60)
	note("trip 1, arrived", [box_b, box_c])
	check(flow.phase == 4, "the crew arrives")
	check(flow.lost.has(partition.label) and not flow.at_site(partition), "the tall partition with no rope fell off on the way (lost=%s)" % str(flow.lost))
	check(flow.at_site(box_b) and flow.at_site(box_c) and not flow.lost.has(box_b.label), "the cartons arrive")
	check(on_truck(box_b).distance_to(held_at) < 0.02 and on_truck(box_c).distance_to(loose_at) > on_truck(box_b).distance_to(held_at) + 0.02, "under the tight rope the carton stayed put (%.3f m); under the slack rope the other one shifted (%.3f m)" % [on_truck(box_b).distance_to(held_at), on_truck(box_c).distance_to(loose_at)])
	# 現場に着いても、ロープは掛かったまま。自分でほどく
	check(kit.lash_count() == 2 and cord.root().distance_to(kit.hook_at(4)) < 0.05 and kit.pinned(box_b.pid), "on arrival the ropes are still on, and still hold")
	me.global_position = truck.global_transform * Vector3(-2.3, 0.1, -0.1)
	await frames(2)
	game.h_grab(box_b.pid)
	await frames(2)
	check(box_b.holder == 0, "the roped carton cannot be lifted off the deck yet")
	kit.h_untie(first)
	kit.h_untie(again)
	await frames(10)
	check(kit.lashes.is_empty() and not kit.pinned(box_b.pid) and absf(kit.stock() - float(bk.COIL_M)) < 0.2, "untying both winds the rope back onto the coil (%.2f m)" % kit.stock())
	# 中身も届いている。見えないまま（判定に数えない）で、配役表には出る
	check(flow.at_site(fish) and flow.at_site(skull) and fish.absent and skull.absent and fish.stored_in == box_b.pid, "the contents arrive inside their cartons, still hidden")
	check(not flow.at_site(toilet) and toilet.stored_in == box_d.pid, "the carton left at the company stays there with its toilet")
	check((flow.cast_sheet()["rows"] as Array).any(func(r: Dictionary) -> bool: return r["role"] == "monster" and "竜" in str(r["items"])), "on site the casting sheet still counts the packed skull")
	check(game.judge.role_of(skull) == "monster" and skull.absent, "but the hidden skull cannot be filmed")
	# 現場で取り出す
	me.global_position = truck.global_transform * Vector3(-2.3, 0.1, -1.4)
	await frames(2)
	game.h_grab(box_c.pid)
	await frames(3)
	check(box_c.holder == me.peer_id, "the untied carton can be lifted off the deck")
	game.h_release()
	put(box_c, Vector3(4.0, 0.1, 4.0))
	put(box_b, Vector3(6.0, 0.1, 4.0))
	me.global_position = Vector3(4.0, 0.1, 6.0)
	me.aim_yaw = 0.0
	await frames(30)
	kit.h_unpack(box_c.pid)
	await frames(4)
	check(me.held == duck.pid and flow.at_site(duck) and not duck.absent and duck.global_position.distance_to(me.global_position) < 3.0, "on site the rubber duck comes out of the carton into the hands")
	game.h_release()
	put(duck, Vector3(2.0, 0.3, 3.0))
	await frames(20)

	# ---- 撮り直し・見返し ----
	check(kit.box_items(box_c) == [skull] and kit.box_items(box_b) == [fish, pie, crown, letter], "before the take: the skull is packed, the duck is out")
	var duck_at: Vector3 = duck.global_position
	game.h_take()
	await frames(240)
	check(game.state == S.TAKE, "the take starts")
	# 本番中に、頭を出して、アヒルをしまう
	kit.h_unpack(box_c.pid)
	await frames(4)
	check(me.held == skull.pid, "during the take the skull is taken out")
	game.h_release()
	await frames(20)
	await take(duck)
	kit.h_pack(duck.pid, box_c.pid)
	await frames(20)
	check(duck.stored_in == box_c.pid and skull.stored_in == 0, "and the duck is packed instead")
	game.h_take()
	await frames(10)
	check(game.state == S.RESULT and not game.takes.is_empty(), "cut")
	# 見返し：最初は撮り始めたときの中身。終わったら、今の中身
	game.h_replay(0)
	await frames(12)
	check(game.state == S.REPLAY and skull.stored_in == box_c.pid and skull.absent and duck.stored_in == 0 and not duck.absent, "the replay starts with the contents as they were when the take began")
	game.h_stop_replay()
	await frames(6)
	check(game.state == S.RESULT and duck.stored_in == box_c.pid and skull.stored_in == 0 and not skull.absent, "after the replay the contents are as they are now")
	# 撮り直し：テイクを始める前の中身と置き場所に戻る
	game.h_retake()
	await frames(20)
	check(game.state == S.PREP and kit.box_items(box_c) == [skull] and skull.absent and duck.stored_in == 0 and not duck.absent, "a retake puts the contents back as they were before the take")
	check(duck.global_position.distance_to(duck_at) < 0.3, "and the duck is back where it stood (%.2f m)" % duck.global_position.distance_to(duck_at))

	# ---- 帰社：全部元へ ----
	await wrap_up()
	check(flow.phase == 0, "back at the office")
	check(kit.contents.is_empty() and kit.lashes.is_empty() and is_equal_approx(kit.stock(), float(bk.COIL_M)), "no carton has contents, no rope is strung and the coil is full again")
	var home_ok := true
	for prop: Node3D in [fish, pie, crown, letter, skull, duck, toilet, tape, partition, rock]:
		var home: Vector3 = flow._home_layout[prop.pid][0]
		if prop.stored_in != 0 or prop.absent or prop.global_position.distance_to(home) > 0.6:
			home_ok = false
			print("  %s is not back home: stored=%d absent=%s %.2f m away" % [prop.kind, prop.stored_in, str(prop.absent), prop.global_position.distance_to(home)])
	check(home_ok, "everything that was packed or lost is back where it belongs")
	shown = out_cartons()
	check(shown.size() == kit.SHOWN and kit.reserve().size() == kit.CARTON_COUNT - kit.SHOWN, "all cartons are back in the carton yard (%d out, %d in reserve)" % [shown.size(), kit.reserve().size()])
	check(shown.all(func(b: Node3D) -> bool: return yard.has_point(Vector2(b.global_position.x, b.global_position.z)) and b.opened and not b.fixed and b.get_node_or_null("Inside") == null and is_equal_approx(b.mass, b.empty_mass)), "they stand open and empty")
	check(kit.rope.global_position.distance_to(flow._home_layout[kit.rope.pid][0]) < 0.6 and kit.rope.holder == 0, "the rope is back in the carton yard")

	# ---- 2回目の移動：同じパーテーションに、こんどはロープをきちんと掛ける → 落ちない。掛けていないグリーンバックは落ちる ----
	game.h_accept_job(0)
	await frames(20)
	check(await load_by_hand(partition, 0.0, (hooks[2] as Vector3).z) and game.overhangs(partition, truck), "the partition is loaded across the side boards again")
	check(await load_by_hand(green, 0.0, -2.0) and game.overhangs(green, truck), "and the green screen, wider still")
	await frames(30)
	kit.rng.seed = 12
	var tall: int = await lash(2, 7, true)
	await frames(180)
	note("before trip 2", [partition, green])
	check(tall != 0, "there is enough rope to go over the partition")
	var rope_p: Node3D = kit.lashes[tall]["cord"]
	var top_p: float = (partition.global_transform * (game.body_bounds(partition) as AABB)).end.y
	highest = -INF
	for point: Vector3 in rope_p.pts:
		highest = maxf(highest, point.y)
	check(absf(highest - top_p) < 0.15 and knots_over(rope_p, partition) >= 2, "the rope goes up over the top of the partition (%.2f m, top %.2f m), using %.1f m of rope" % [highest, top_p, rope_p.length])
	check(kit.pinned(partition.pid) and kit.grip_of(green.pid) == 0.0, "the partition is held; the green screen has no rope")
	var tall_at: Vector3 = on_truck(partition)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	while flow.phase == 3:
		await physics_frame
	await frames(60)
	note("trip 2, arrived", [partition, green])
	check(flow.phase == 4 and flow.at_site(partition) and not flow.lost.has(partition.label) and on_truck(partition).distance_to(tall_at) < 0.03, "roped down, the tall partition reaches the site where it stood (%.3f m, lost=%s)" % [on_truck(partition).distance_to(tall_at), str(flow.lost)])
	check(flow.lost.has(green.label), "the green screen, shaken the same way with no rope, fell off")
	game.h_grab(partition.pid)
	await frames(3)
	check(partition.holder == 0 and kit.lash_count() == 1, "on site the rope still holds the partition")
	me.global_position = truck.global_transform * Vector3(-2.6, 0.1, (hooks[2] as Vector3).z)
	await frames(3)
	kit.h_untie(tall)
	await frames(10)
	game.h_grab(partition.pid)
	await frames(3)
	check(partition.holder == me.peer_id, "untied, the partition can be picked up again")

	print("CARTON_ROPE_TEST_FAIL" if failed else "CARTON_ROPE_TEST_OK")
	# 鳴っている音を止めてから終わる（終了時の「resources still in use」を出さない）
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	game.queue_free()
	await frames(8)
	quit(1 if failed else 0)
