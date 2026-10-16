extends SceneTree
# 段ボール箱に入る量を確かめる。入る量は、数ではなく、箱の内側の実際の広さで決まる（carton_pack.gd）。
#   小さい物は10個以上入る／中くらいの物は2〜3個／箱の内側より大きい物は入らない
#   中身は実寸で、箱の内側に、底から積んである（壁・底を突き抜けない、重ならない、宙に浮かない）
#   満杯に近いと口の高さまで積み上がる／口からはみ出すと、ふたが閉まらない／はみ出した物は、道中の段差でこぼれる
#   開いた箱の中へ手で置いた物が中身になる／箱を運ぶと中身も一緒／見ている物を取り出せる（元の大きさで出てくる）
#   下の物を抜くと、上の物が落ちる／数字の表示が無い／口より下に収まった中身は、現場まで届く
#   godot --headless --path godot --fixed-fps 60 --script res://tests/carton_pack_test.gd
const Pack := preload("res://scripts/carton_pack.gd")
var game: Node
var flow: Node
var kit: Node
var me: Node
var truck: Node
var failed := false
var toasts: Array = []


func _initialize() -> void:
	create_timer(170).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("CARTON_PACK_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func put(prop: Node, pos: Vector3, yaw: float = 0.0) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion(Vector3.UP, yaw)
	state[2] = false
	prop.restore(state)


# 目の前に置いて、手に持つ
func take(prop: Node) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	put(prop, me.global_position + Vector3(0, 1.0, 0) + me.flat_forward() * 1.4)
	await frames(2)
	game.h_grab(prop.pid)
	await frames(3)


# 物を持って、箱に入れる（F を押したのと同じ頼み方）。入ったかどうかを返す。入らなかった物は、わきへ置く
func pack(prop: Node, box: Node) -> bool:
	await take(prop)
	kit.h_pack(prop.pid, box.pid)
	await frames(3)
	var done: bool = prop.stored_in == box.pid
	if not done:
		if prop.holder != 0:
			game.h_release()
			await frames(2)
		put(prop, me.global_position + Vector3(-4.0 - 0.9 * float(prop.pid % 7), 0.4, 3.0 + 1.1 * float(prop.pid % 5)))
	return done


# 箱の真上から、箱の中へ落とす（手で置いたのと同じ：物理で落ちて、中で止まる）
func drop_in(prop: Node, box: Node, at: Vector2, height: float = 0.25) -> void:
	if me.held != 0:
		game.h_release()
		await frames(2)
	var room: AABB = box.room
	var spot: Vector3 = box.global_transform * Vector3(at.x, room.end.y + height, at.y)
	put(prop, spot - prop.center)
	await frames(2)


func has_digit(text: String) -> bool:
	for ch: String in text:
		if (ch >= "0" and ch <= "9") or (ch >= "０" and ch <= "９"):
			return true
	return false


func longest(prop: Node) -> float:
	return maxf(prop.half.x, maxf(prop.half.y, prop.half.z)) * 2.0


# 2番目に長い辺（細長い物と、かさのある物を見分ける）
func second(prop: Node) -> float:
	var sides: Array = [prop.half.x * 2.0, prop.half.y * 2.0, prop.half.z * 2.0]
	sides.sort()
	return sides[1]


# 箱の中の並びが正しいか：内側に収まる・重ならない・宙に浮かない。おかしな点を文で返す（無ければ ""）
func layout_fault(box: Node) -> String:
	var room: AABB = box.room
	var blocks: Array = kit.blocks(box)
	var items: Array = kit.box_items(box)
	var give: float = Pack.SQUEEZE * 0.5 + 0.002
	for a in blocks.size():
		var one: AABB = blocks[a]
		if one.position.x < room.position.x - give or one.end.x > room.end.x + give or one.position.z < room.position.z - give or one.end.z > room.end.z + give:
			return "%s goes through a wall" % items[a].kind
		if one.position.y < room.position.y - 0.002:
			return "%s goes through the bottom" % items[a].kind
		var held_up: bool = one.position.y < room.position.y + 0.002
		for b in blocks.size():
			if a == b:
				continue
			var other: AABB = blocks[b]
			var side_by_side: bool = one.end.x - give <= other.position.x + give or other.end.x - give <= one.position.x + give or one.end.z - give <= other.position.z + give or other.end.z - give <= one.position.z + give
			if not side_by_side:
				if one.position.y < other.end.y - 0.002 and other.position.y < one.end.y - 0.002:
					return "%s and %s overlap" % [items[a].kind, items[b].kind]
				if absf(one.position.y - other.end.y) < 0.002:
					held_up = true
		if not held_up:
			return "%s floats in the air" % items[a].kind
	return ""


# 箱の中の見た目が、実寸で、決めた場所にあるか
func shown_right(box: Node) -> bool:
	var inside: Node = box.get_node_or_null("Inside")
	var items: Array = kit.box_items(box)
	if inside == null or inside.get_child_count() != items.size():
		return false
	for item: Node in items:
		var holder: Node3D = inside.get_node_or_null("Item%d" % item.pid)
		if holder == null or not holder.transform.is_equal_approx(kit.slot_of(box.pid, item.pid)):
			return false
		if not holder.transform.basis.get_scale().is_equal_approx(Vector3.ONE) or holder.get_child_count() != 1:
			return false
		if not (holder.get_child(0) as Node3D).scale.is_equal_approx(item.visual.scale):
			return false
		if box.get_node_or_null("Fill%d" % item.pid) == null:
			return false
	return true


func load_by_hand(prop: Node, along: float) -> bool:
	if me.held != 0:
		game.h_release()
		await frames(2)
	if prop.rider_of != 0:
		game.host_unload(prop)
	var box: AABB = game.body_bounds(prop)
	var reach: float = box.size.x * 0.5
	me.global_position = truck.global_transform * Vector3(-2.9, 0.1, along + box.size.z * 0.5 + 1.6)
	me.aim_yaw = -PI * 0.5
	me.aim_pitch = -0.1
	prop.restore([truck.global_transform * Vector3(-(1.5 + reach) - box.get_center().x, 0.5 - box.position.y, along - box.get_center().z), Quaternion.IDENTITY, false])
	await frames(2)
	game.h_grab(prop.pid)
	await frames(10)
	game.h_load_truck(prop.pid)
	await frames(3)
	if prop.rider_of != truck.pid and prop.holder != 0:
		game.h_release()
	return prop.rider_of == truck.pid


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
	me = game.local_player()
	truck = game.truck
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	await frames(20)
	check(flow.phase == 2, "a job is taken and the crew is packing")

	# 詰める場所：軽トラの南西の空いた所。箱を4つ並べる
	var bench := Vector3(flow.HOME_TRUCK.x - 6.5, 0.1, flow.HOME_TRUCK.z + 5.5)
	me.global_position = bench
	me.aim_yaw = 0.0
	var boxes: Array = kit.cartons.filter(func(b: Node) -> bool: return not b.absent)
	for i in 4:
		put(boxes[i], bench + Vector3(-2.4 + 1.6 * float(i), 0.1, -1.8))
	await frames(40)
	var box_a: Node = boxes[0]
	var box_b: Node = boxes[1]
	var box_c: Node = boxes[2]
	var box_d: Node = boxes[3]
	var room: AABB = box_a.room
	var body: AABB = game.body_bounds(box_a)
	check(room.size.x < body.size.x and room.size.z < body.size.z and room.end.y <= body.end.y and room.position.y > body.position.y, "the room inside a carton is its real inside (%.2f x %.2f x %.2f m in a %.2f x %.2f x %.2f m carton)" % [room.size.x, room.size.y, room.size.z, body.size.x, body.size.y, body.size.z])

	# 今日ある物を、大きさで分ける
	# 小さい物＝いちばん長い辺が 50cm まで / 中くらいの物＝82cm までで、かさのある物（竜の頭・アヒル・お宝の箱・フクロウ像）/
	# 細長い物（スッポン・たいまつ・はさみ）は、すき間に入るので、どちらにも数えない
	# 会社の備品（接着剤・ロープ・仕掛けの部品）は、今日の小道具ではないので数えない
	var small: Array = []
	var medium: Array = []
	var slim: Array = []
	var big: Array = []
	for prop: Node in game.props.values():
		if prop.absent or prop.holder != 0 or prop.immovable or prop.rolls or prop.kind in ["carton", "truck", "mark", "fx", "script", "standin", "glue", "rope", "pulley", "buzzer", "igniter", "timer", "nightgel"] or prop.kind in kit.GEAR or prop.deck_top >= 0.0:
			continue
		if longest(prop) <= 0.5:
			small.append(prop)
		elif longest(prop) <= 0.82 and second(prop) >= 0.38:
			medium.append(prop)
		elif longest(prop) <= 0.82:
			slim.append(prop)
		else:
			big.append(prop)
	small.sort_custom(func(a: Node, b: Node) -> bool: return a.pid < b.pid)
	medium.sort_custom(func(a: Node, b: Node) -> bool: return a.pid < b.pid)
	# 手で入れる確かめに使う物は、取っておく（平たい物2つと、細長い物1つ）
	var one: Node = null
	var two: Node = null
	var three: Node = null
	for prop: Node in small:
		if prop.kind == "scrap_pie":
			one = prop
		elif prop.kind == "scrap_poop":
			two = prop
	for prop: Node in slim:
		if prop.kind == "scrap_plunger":
			three = prop
	check(one != null and two != null and three != null, "the pie, the rubber poop and the plunger are kept aside for the hand-packing checks")
	small.erase(one)
	small.erase(two)
	slim.erase(three)
	print("CARTON_PACK_NOTE small=%s" % str(small.map(func(p: Node) -> String: return p.kind)))
	print("CARTON_PACK_NOTE medium=%s" % str(medium.map(func(p: Node) -> String: return p.kind)))
	check(small.size() >= 10 and medium.size() >= 3 and big.size() >= 3, "today there are enough props to try: %d small, %d medium, %d slim, %d big" % [small.size(), medium.size(), slim.size(), big.size()])

	# ---- 小さい物：10個以上入る ----
	var empty_mass: float = box_a.mass
	var went := 0
	var weight := 0.0
	for prop: Node in small.slice(0, 12):
		if await pack(prop, box_a):
			went += 1
			weight += prop.mass
	check(went >= 10, "at least ten small props go into one carton (%d went in)" % went)
	check(layout_fault(box_a) == "", "they lie inside the carton at full size: none through a wall or the bottom, none overlapping, none floating (%s)" % layout_fault(box_a))
	check(shown_right(box_a), "what is shown inside the carton is the props at full size, where the host put them")
	check(is_equal_approx(box_a.mass, empty_mass + weight), "the carton weighs what is in it (%.1f kg)" % box_a.mass)
	check(kit.box_over(box_a) < 0.0 and not kit.lid_blocked(box_a), "they are all below the mouth of the carton (%.2f m below)" % -kit.box_over(box_a))
	var first: Node = kit.box_items(box_a)[0]
	check(first.absent and first.global_position.y < -30.0 and first.collision_layer == 0, "a packed prop itself is parked out of the world")

	# ---- 中くらいの物：2〜3個 ----
	went = 0
	for prop: Node in medium:
		if await pack(prop, box_b):
			went += 1
	check(went >= 2 and went <= 3, "two or three medium props go into one carton (%d of %d went in: %s)" % [went, medium.size(), kit.box_note(box_b)])
	check(layout_fault(box_b) == "" and shown_right(box_b), "they are stacked properly at full size too (%s)" % layout_fault(box_b))
	var refused: Node = null
	for prop: Node in medium:
		if prop.stored_in == 0 and refused == null:
			refused = prop
	if refused != null:
		var why: String = kit.pack_problem(refused, box_b)
		check(why == "もう入らない" and kit.fits_alone(refused), "the one left over is refused only because there is no room: %s" % why)

	# ---- 箱の内側より大きい物：入らない ----
	var too_big := 0
	var words: Array = []
	for prop: Node in big:
		var why: String = kit.pack_problem(prop, box_c)
		if why != "" and not kit.fits_alone(prop):
			too_big += 1
			words.append(why)
	check(too_big >= 3 and words.all(func(w: String) -> bool: return "入らない" in w and not has_digit(w)), "props bigger than the inside of a carton are refused, with a reason and no numbers (%d refused, e.g. %s)" % [too_big, str(words.slice(0, 1))])
	var rock: Node = big.filter(func(p: Node) -> bool: return p.kind == "rock")[0] if big.any(func(p: Node) -> bool: return p.kind == "rock") else big[0]
	check(not (await pack(rock, box_c)) and rock.stored_in == 0 and not rock.absent, "a refused prop stays out, in the world")

	# ---- 満杯：口の高さまで積み上がる。それ以上は「もう入らない」 ----
	var rest: Array = []
	for prop: Node in small + slim + medium:
		if prop.stored_in == 0:
			rest.append(prop)
	var full := false
	var last_why := ""
	for prop: Node in rest:
		if not (await pack(prop, box_a)):
			last_why = kit.pack_problem(prop, box_a)
			if last_why == "もう入らない":
				full = true
				break
	print("CARTON_PACK_NOTE full carton holds %d props, top is %.2f m %s the mouth" % [kit.box_items(box_a).size(), absf(kit.box_over(box_a)), "above" if kit.box_over(box_a) > 0.0 else "below"])
	check(full and not has_digit(last_why), "packing goes on until a prop no longer fits; the reason has no numbers (%s)" % last_why)
	check(kit.box_over(box_a) > -0.12, "a carton that is nearly full is piled up to its mouth (top %.2f m from the mouth)" % kit.box_over(box_a))
	check(layout_fault(box_a) == "" and shown_right(box_a), "the full carton is still stacked properly (%s)" % layout_fault(box_a))

	# ---- はみ出す：ふたが閉まらない ----
	var toilet: Node = null
	for prop: Node in game.props.values():
		if prop.kind == "scrap_toilet" and not prop.absent:
			toilet = prop
	check(toilet != null and await pack(toilet, box_c), "a toilet can be pushed into a carton")
	check(kit.box_over(box_c) > Pack.LID_GIVE and kit.box_over(box_c) <= Pack.OVER and kit.lid_blocked(box_c), "it sticks out of the mouth (%.2f m)" % kit.box_over(box_c))
	check(layout_fault(box_c) == "" and (game.body_bounds(box_c) as AABB).end.y > body.end.y + 0.1, "it stands on the bottom of the carton and can be bumped into where it sticks out")
	me.global_position = box_c.global_position + Vector3(0, 0.1, 1.2)
	await frames(2)
	game.h_toggle_carton(box_c.pid)
	await frames(30)
	check(box_c.opened and box_c.lid.disabled, "the lid of a carton with something sticking out does not close")
	me.global_position = box_b.global_position + Vector3(0, 0.1, 1.2)
	await frames(2)
	var b_over: bool = kit.lid_blocked(box_b)
	game.h_toggle_carton(box_b.pid)
	await frames(30)
	check(box_b.opened == b_over, "whether the carton of medium props closes depends only on whether they stick out (%s)" % ("they do: it stays open" if b_over else "they do not: it closes"))
	if not box_b.opened:
		game.h_toggle_carton(box_b.pid)
		await frames(30)
	me.global_position = bench

	# ---- 手で入れる：開いた箱の中へ落とした物が、中で落ち着いたら中身になる ----
	await drop_in(one, box_d, Vector2(-0.2, 0.05))
	check(one.stored_in == 0 and not one.absent, "a prop falling into an open carton is still a loose prop while it falls")
	await frames(70)
	check(one.stored_in == box_d.pid and kit.box_items(box_d) == [one], "once it has come to rest inside, it becomes the carton's contents (no F needed)")
	var spot: AABB = kit.blocks(box_d)[0] if not kit.blocks(box_d).is_empty() else AABB()
	check(absf(spot.get_center().x + 0.2) < 0.12 and absf(spot.get_center().z - 0.05) < 0.12 and absf(spot.position.y - box_d.room.position.y) < 0.002, "it lies where it landed, on the bottom (%.2f, %.2f)" % [spot.get_center().x, spot.get_center().z])
	await drop_in(two, box_d, Vector2(-0.2, 0.05))
	await frames(80)
	check(two.stored_in == box_d.pid and layout_fault(box_d) == "" and shown_right(box_d), "a second prop dropped on top of it comes to rest on it and becomes contents too (%s)" % layout_fault(box_d))
	var upper: AABB = kit.blocks(box_d)[1] if kit.blocks(box_d).size() > 1 else AABB()
	print("CARTON_PACK_NOTE dropped: %s at %s, %s at %s" % [one.kind, str(spot), two.kind, str(upper)])
	# 入れてはいけない物（接着剤の缶）は、落としても中身にならない
	var glue: Node = null
	for prop: Node in game.props.values():
		if prop.kind == "glue" and not prop.absent:
			glue = prop
	if glue != null:
		await drop_in(glue, box_d, Vector2(0.3, 0.0))
		await frames(80)
		check(glue.stored_in == 0 and not glue.absent, "a tool dropped into a carton just lies there; it does not become contents")
		put(glue, bench + Vector3(3.0, 0.3, 2.0))
		await frames(5)

	# ---- 箱を運ぶ：中身も一緒 ----
	me.global_position = box_d.global_position + Vector3(0, 0.1, 1.5)
	me.aim_yaw = 0.0
	await frames(3)
	var was: Vector3 = box_d.global_position
	game.h_grab(box_d.pid)
	await frames(10)
	check(box_d.holder == me.peer_id, "the carton with props in it can be picked up")
	me.global_position += Vector3(2.5, 0.0, 2.0)
	await frames(50)
	var inside: Node3D = box_d.get_node_or_null("Inside")
	check(box_d.global_position.distance_to(was) > 1.5 and inside != null and inside.global_position.distance_to(box_d.global_position) < 0.001 and one.stored_in == box_d.pid and two.stored_in == box_d.pid, "carried away, the carton takes its contents along")
	check(flow.whereabouts(one).distance_to(box_d.global_position) < 0.001, "the game knows the prop is where the carton is")
	game.h_release()
	await frames(50)
	check(one.stored_in == box_d.pid and layout_fault(box_d) == "", "put down again, the contents are still in place")

	# ---- 取り出す：見ている物が出てくる。元の大きさで。下の物を抜くと、上の物が落ちる ----
	me.global_position = box_d.global_position + Vector3(0, 0.1, 1.5)
	me.aim_yaw = 0.0
	await frames(3)
	# 3つ目は F で入れる（底の空いた所に並ぶ）
	check(await pack(three, box_d) and layout_fault(box_d) == "", "a third prop is put in with F and lies beside them (%s)" % three.kind)
	me.global_position = box_d.global_position + Vector3(0, 0.1, 1.5)
	await frames(3)
	me.target = box_d
	me.cam.look_at_from_position(me.global_position + Vector3(0, 1.7, 0), box_d.global_transform * Vector3(0.0, 3.0, 0.0), Vector3.UP)
	var act: Dictionary = kit.f_action(me)
	check(act.get("do", "") == "unpack" and int(act.get("item", 0)) == kit.top_item(box_d), "aiming at the carton but at no prop in it, F offers the one on top")
	# 見ている物：真上の少し手前から、その物の上面を見る
	var seen: Array = []
	for item: Node in [three, two]:
		var block: AABB = Pack.box_of(kit.slot_of(box_d.pid, item.pid), item.center, item.half)
		var top := Vector3(block.get_center().x, block.end.y, block.get_center().z)
		me.target = box_d
		me.cam.look_at_from_position(box_d.global_transform * (top + Vector3(0, 1.2, 0.03)), box_d.global_transform * top, Vector3.UP)
		act = kit.f_action(me)
		seen.append(int(act.get("item", 0)))
		if item == three:
			check(act.get("do", "") == "unpack" and act.has("point") and (act["point"] as Vector3).distance_to(box_d.global_transform * top) < 0.01, "a ring marks the prop that F would take out")
	check(seen == [three.pid, two.pid], "looking at a prop in the carton, F offers that very prop (%s)" % str(seen))
	me.target = box_d
	var view: Dictionary = kit.hud_view(me)
	check(kit._short(two) in str(view.get("tail", "")) and not has_digit(str(view.get("tail", "")) + str(view.get("keys", ""))), "the hint names it and has no numbers (%s / %s)" % [str(view.get("tail", "")), str(view.get("keys", ""))])
	game.input_locked = false
	kit._show_note(me)
	game.input_locked = true
	check(kit._note.visible and kit._short(one) in kit._note.text and not has_digit(kit._note.text), "the names of the contents hang over the carton that is aimed at (%s)" % kit._note.text)
	var notes := 0
	for box: Node in kit.cartons:
		notes += box.find_children("*", "Label3D", true, false).size()
	check(notes == 0, "no carton carries a tag of its own (nothing hangs over the others)")
	var half_was: Vector3 = one.half
	var scale_was: Vector3 = one.visual.scale
	kit.h_unpack(box_d.pid, one.pid)
	await frames(4)
	check(me.held == one.pid and one.stored_in == 0 and not one.absent and one.visible and one.collision_layer != 0, "F takes that prop out, into the hands")
	check(one.half.is_equal_approx(half_was) and one.visual.scale.is_equal_approx(scale_was) and one.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "it comes out at its own size")
	var fell: AABB = Pack.box_of(kit.slot_of(box_d.pid, two.pid), two.center, two.half)
	check(kit.box_items(box_d) == [two, three] and absf(fell.position.y - box_d.room.position.y) < 0.002 and layout_fault(box_d) == "" and shown_right(box_d), "the prop that lay on it has dropped to the bottom of the carton")
	# 口より下に収まっている箱は、ふたが閉まる
	me.target = null
	game.h_toggle_carton(box_d.pid)
	await frames(30)
	check(not box_d.opened and not box_d.lid.disabled, "a carton whose contents are below the mouth closes")
	game.h_toggle_carton(box_d.pid)
	await frames(30)
	me.target = box_d
	check(kit.f_action(me).get("do", "") == "pack" and kit.f_action(me).get("why", "x") == "", "holding it and aiming at the open carton offers to put it back")
	view = kit.hud_view(me)
	check(not has_digit(str(view.get("tail", "")) + str(view.get("keys", ""))), "that hint has no numbers either (%s / %s)" % [str(view.get("tail", "")), str(view.get("keys", ""))])
	me.target = null
	kit.h_pack(one.pid, box_d.pid)
	await frames(3)
	check(one.stored_in == box_d.pid and layout_fault(box_d) == "", "F puts it back in")
	# 持った箱の中身も、数字なしで出る
	game.h_grab(box_d.pid)
	await frames(6)
	check("中身" in str(kit.hud_view(me).get("tail", "")) and not has_digit(str(kit.hud_view(me).get("tail", ""))), "holding a carton, the hint lists what is in it, with no numbers (%s)" % str(kit.hud_view(me).get("tail", "")))
	game.h_release()
	await frames(20)
	# 満杯の箱の案内
	var spare: Node = rock
	for prop: Node in small + medium:
		if prop.stored_in == 0 and prop.holder == 0 and kit.pack_problem(prop, box_a) == "もう入らない":
			spare = prop
	if spare != rock:
		await take(spare)
		me.target = box_a
		view = kit.hud_view(me)
		check("もう入らない" in str(view.get("tail", "")) and not has_digit(str(view.get("tail", "")) + str(view.get("keys", ""))), "aiming at the full carton with a prop in hand says only that it no longer fits (%s)" % str(view.get("tail", "")))
		me.target = null
		game.h_release()
		await frames(3)
		put(spare, bench + Vector3(4.0, 0.3, 3.0))

	# ---- 現場まで：口より下に収まった中身は届く。はみ出した物は、道中の段差でこぼれる ----
	kit.spill_chance = 1.0
	var packed: Array = kit.box_items(box_a).duplicate()
	var a_over: float = kit.box_over(box_a)
	check(await load_by_hand(box_d, -0.3), "the carton with the hand-dropped props is loaded")
	check(await load_by_hand(box_c, -1.5), "the carton with the toilet sticking out is loaded")
	await frames(60)
	var riding: Array = flow.cargo(false)
	check(riding.has(box_d.pid) and riding.has(one.pid) and riding.has(two.pid) and riding.has(toilet.pid), "the truck carries the cartons and what is in them")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(5)
	check(flow.phase == 3, "the truck leaves")
	while flow.phase == 3:
		await physics_frame
	await frames(60)
	check(flow.phase == 4 and flow.at_site(box_d) and flow.at_site(one) and one.stored_in == box_d.pid and two.stored_in == box_d.pid and layout_fault(box_d) == "", "props packed below the mouth arrive on site inside their carton")
	check(toilet.stored_in == 0 and not toilet.absent and toilet.visible and not kit.box_items(box_c).has(toilet), "the toilet that stuck out was shaken out of its carton on the way (it is %s)" % ("on site" if flow.at_site(toilet) else "lost on the road"))
	check(kit.box_items(box_a) == packed and is_equal_approx(kit.box_over(box_a), a_over), "the carton left at the company keeps everything, even what sticks out (it was not shaken)")

	print("CARTON_PACK_TEST_FAIL" if failed else "CARTON_PACK_TEST_OK")
	# 鳴っている音を止めてから終わる（終了時の「resources still in use」を出さない）
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	await frames(10)
	quit(1 if failed else 0)
