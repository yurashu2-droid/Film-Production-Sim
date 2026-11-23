extends SceneTree
# ロープを手でつかむ（rope_grab.gd）を確かめる：
#   端をつかんで歩くと、ロープがついて来る / 途中をつかむと、そこが持ち上がり両側が垂れる / 長さが伸び縮みしない /
#   離すと落ちて数秒で止まる / 張ったロープは動かない（手から抜ける）/ 両端がつながったロープは、たるみの分だけ動く /
#   束から出ている途中のロープを引くと、束から出てくる / 燃えている先のそばはつかめない・火が来たら手を離す /
#   切れ端を拾って爆弾につなげると、その長さの導火線になる / 切れ端をフックに結べる・もう片方も結べる・ほどくと切れ端に戻る /
#   はさみ・点火・ほどくは今までどおり / 案内は動作だけ（数字なし）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/rope_grab_test.gd
var game: Node
var kit: Node          # bomb_kit.gd
var ck: Node           # cargo_kit.gd
var grab: Node         # rope_grab.gd
var bomb: Node
var me: Node
var truck: Node
var failed := false
var checks := 0
var booms: Array = []
var tick := 0
var floor_y := 0.0


func _initialize() -> void:
	create_timer(170).timeout.connect(func(): quit(2))
	run.call_deferred()


func _physics_process(_delta: float) -> bool:
	tick += 1
	return false


func check(ok: bool, label: String) -> void:
	checks += 1
	print("ROPE_GRAB_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


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


func _heard(sound: String, _position: Variant) -> void:
	if sound.begins_with("explosion"):
		booms.append([sound, tick])


func take(prop: Node) -> void:
	game.h_release()
	await frames(2)
	prop.set_fixed(false)
	game.h_grab(prop.pid)
	await frames(3)


func stand(pos: Vector3) -> void:
	me.global_position = Vector3(pos.x, floor_y + 0.1, pos.z)
	me.velocity = Vector3.ZERO
	await frames(4)


# その点に照準を合わせる（確かめる直前に呼ぶ。次のコマで、カメラは元に戻る）
func aim(point: Vector3) -> void:
	var from: Vector3 = me.global_position + Vector3(0, 1.6, 0)
	me.cam.look_at_from_position(from + (from - point).normalized() * 0.5, point, Vector3.UP)


func has_digit(text: String) -> bool:
	for ch in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


func on_floor(cord: Node) -> float:
	var low := 0
	for p: Vector3 in cord.pts:
		if p.y < floor_y + 0.08:
			low += 1
	return float(low) / float(maxi(1, cord.pts.size()))


func stretch(cord: Node) -> float:
	return float(cord.path_length()) / maxf(float(cord.length), 0.01)


func holding() -> bool:
	return grab.holding(me.peer_id)


func gap() -> float:
	if not holding():
		return -1.0
	return (grab.grabs[me.peer_id]["at"] as Vector3).distance_to(grab.hand_point(me))


# 床に、まっすぐな切れ端を置く（ホストの道具で作る。番号を返す）
func scrap(from: Vector3, to: Vector3) -> int:
	var a := Vector3(from.x, floor_y + 0.03, from.z)
	var b := Vector3(to.x, floor_y + 0.03, to.z)
	var id: int = kit.host_add_scrap(PackedVector3Array([a, b]), a.distance_to(b))
	await frames(90)
	return id


# そのフックの外側に立つ
func hook_spot(hook: int) -> Vector3:
	var local: Vector3 = truck.hooks[hook]
	return truck.global_transform * Vector3(local.x + signf(local.x) * 1.45, 0.0, local.z)


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	root.get_node("Sfx").played.connect(_heard)
	var flow: Node = game.production
	bomb = game.fx
	kit = game.bomb_kit
	ck = game.cargo_kit
	grab = game.rope_grab
	me = game.local_player()
	truck = game.truck
	ck.rng.seed = 7
	var coil: Node = kit.coil
	var scissors: Node = kit.scissors
	check(grab != null and grab.grabs.is_empty(), "the production game has the rope-grab helper")
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_confirm()
	await frames(8)
	var spot: Vector3 = flow.HOME_TRUCK + Vector3(-7.5, 0.0, -1.5)
	place(bomb, spot + Vector3(0, 0.05, 0))
	var none: Array[RID] = []
	floor_y = kit._floor_under(spot + Vector3(2, 1, 2), none).y
	await stand(spot + Vector3(5.3, 0, 3.0))
	await frames(20)

	# ---- 端をつかんで歩く：ロープがついて来る。伸びない ----
	var p0: Vector3 = spot + Vector3(1.5, 0, 2.0)
	var id: int = await scrap(p0, p0 + Vector3(3.0, 0, 0))
	var rope: Node = kit.cords[id]
	check(rope.asleep and rope.a_body == null and rope.b_body == null and is_equal_approx(rope.length, 3.0), "a 3 m scrap lies still on the floor")
	await stand(rope.tip() + Vector3(0.8, 0, 1.0))
	aim(rope.tip())
	me.target = null
	var seen: Dictionary = grab.aim(me)
	check(not seen.is_empty() and int(seen["kind"]) == grab.CORD and int(seen["id"]) == id and absf(float(seen["s"]) - rope.length) < 0.01, "looking at the end of a rope on the floor finds that end")
	var hint: Dictionary = grab.hud_view(me, "", "")
	check("つかむ" in str(hint.get("keys", "")) and "左クリック" in str(hint.get("keys", "")) and not has_digit(str(hint.get("keys", "")) + str(hint.get("label", ""))), "the hint only names the action: %s" % str(hint.get("keys", "")).replace("\n", " / "))
	check(str(kit.f_action(me).get("do", "")) == "light", "F on the loose end still lights it (bare hands)")
	hint = grab.hud_view(me, "ロープの先", "F 点火")
	check("点火" in str(hint["keys"]) and "つかむ" in str(hint["keys"]), "both the F hint and the grab hint are shown")
	aim(rope.tip())
	me.target = null
	check(grab.handle_click(me), "a left click on the rope is taken as a grab")
	await frames(2)
	check(holding() and absf(float(grab.grabs[me.peer_id]["s"]) - rope.length) < 0.01, "the end is in the hand")
	await frames(40)
	check(gap() >= 0.0 and gap() < 0.08, "the grabbed end comes to the hand (%.3f m away)" % gap())
	hint = grab.hud_view(me, "", "")
	check("離す" in str(hint.get("keys", "")) and not has_digit(str(hint.get("keys", ""))), "while holding, the hint says how to let go")
	var worst := 1.0
	var far := 0.0
	var from: Vector3 = me.global_position
	for i in 130:
		me.global_position = from + Vector3(0.5, 0, 4.0) * float(i + 1) / 130.0
		await physics_frame
		worst = maxf(worst, stretch(rope))
		far = maxf(far, gap())
	await frames(40)
	var hand: Vector3 = grab.hand_point(me)
	print("ROPE_GRAB walk: stretch=", worst, " gap=", far, " root moved=", rope.root().distance_to(p0), " root-hand=", rope.root().distance_to(hand))
	check(holding() and far < 0.3, "walking with the end: it stays in the hand (never more than %.2f m away)" % far)
	check(rope.root().distance_to(p0) > 1.5 and rope.root().distance_to(hand) <= rope.length + 0.05, "the rest of the rope is dragged along (the far end moved %.2f m)" % rope.root().distance_to(p0))
	check(worst < 1.06 and stretch(rope) < 1.02, "the rope does not stretch (at most %.1f%% while moving)" % ((worst - 1.0) * 100.0))
	check(rope.tip().y > floor_y + 0.6 and rope.root().y < floor_y + 0.08, "it hangs from the hand down to the floor")
	check(is_equal_approx(rope.length, 3.0), "its length is unchanged")

	# ---- 離す：その場に落ちて、数秒で止まる ----
	aim(rope.tip())
	check(grab.handle_click(me), "a second left click lets go")
	await frames(240)
	print("ROPE_GRAB rest: speed=", rope.speed(), " asleep=", rope.asleep, " stretch=", stretch(rope), " floor=", on_floor(rope))
	check(not holding(), "the hand is empty again")
	check(rope.asleep and is_zero_approx(rope.speed()), "the dropped rope comes to a complete stop")
	check(on_floor(rope) > 0.95 and stretch(rope) <= 1.01 and stretch(rope) > 0.85 and is_equal_approx(rope.length, 3.0), "it lies on the floor at its full length (%.2f m laid out)" % rope.path_length())
	var rest: PackedVector3Array = rope.pts.duplicate()
	await frames(120)
	var drift := 0.0
	for i in rest.size():
		drift = maxf(drift, rest[i].distance_to(rope.pts[i]))
	check(is_zero_approx(drift), "two seconds later not one node has moved")

	# ---- 途中をつかむ：そこが持ち上がり、両側が垂れる ----
	var mid: Vector3 = rope.point_at(1.5)
	await stand(mid + Vector3(0.3, 0, 1.0))
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0
	grab.h_grab(grab.CORD, id, 1.5)
	await frames(100)
	var k: int = rope.node_at(1.5)
	print("ROPE_GRAB mid: y=", rope.pts[k].y - floor_y, " ends=", rope.root().y - floor_y, ",", rope.tip().y - floor_y, " stretch=", stretch(rope), " gap=", gap())
	check(holding() and rope.pts[k].y > floor_y + 0.6 and absf(rope.pts[k].y - grab.hand_point(me).y) < 0.05 and gap() < 0.08, "grabbing the middle lifts that point to the hand (%.2f m up)" % (rope.pts[k].y - floor_y))
	check(rope.root().y < floor_y + 0.08 and rope.tip().y < floor_y + 0.08 and rope.pts[k - 6].y < rope.pts[k].y - 0.3 and rope.pts[k + 6].y < rope.pts[k].y - 0.3, "both sides hang down from the hand to the floor")
	check(stretch(rope) < 1.02 and is_equal_approx(rope.length, 3.0), "still the same length, not stretched")
	var f_mid: Dictionary = grab.f_action(me)
	check(str(f_mid.get("do", "")) == "mid" and not grab.handle_f(me), "holding the middle offers no F action")
	grab.h_release()
	await frames(240)
	print("ROPE_GRAB mid rest: asleep=", rope.asleep, " speed=", rope.speed(), " floor=", on_floor(rope), " stretch=", stretch(rope))
	check(not holding() and rope.asleep and on_floor(rope) > 0.95, "let go, it drops and stops again")
	check(grab.f_action(me).is_empty(), "bare hands: the grab helper takes no F")

	# ---- はさみを持っているとき：切るが先。つかめない ----
	place(scissors, me.global_position + Vector3(-0.6, 0.1, 0.4), 0.0, false)
	await take(scissors)
	aim(rope.point_at(1.0))
	me.target = null
	check(str(kit.f_action(me).get("do", "")) == "cut" and grab.aim(me).is_empty() and not grab.handle_click(me), "with the scissors in hand F still cuts, and the click is not a rope grab")
	grab.h_grab(grab.CORD, id, 1.0)
	check(not holding(), "a rope cannot be grabbed while carrying something")
	game.h_release()
	await frames(3)

	# ---- 燃えているロープ：火のそばはつかめない。燃えていない所は引ける。火が来たら手を離す ----
	var q0: Vector3 = spot + Vector3(1.5, 0, 6.0)
	var id2: int = await scrap(q0, q0 + Vector3(1.8, 0, 0))
	var burn: Node = kit.cords[id2]
	await stand(burn.tip() + Vector3(0.6, 0, 0.8))
	kit.h_light(id2, 1)
	await frames(2)
	check(burn.burning, "a scrap is lit at its tip")
	aim(burn.tip())
	me.target = null
	seen = grab.aim(me)
	check(not seen.is_empty() and bool(seen["hot"]), "the burning tip is seen as hot")
	grab.h_grab(grab.CORD, id2, burn.length - 0.1)
	await frames(2)
	check(not holding(), "the burning part cannot be grabbed")
	await stand(burn.root() + Vector3(-0.5, 0, 0.8))
	var root_was: Vector3 = burn.root()
	grab.h_grab(grab.CORD, id2, 0.0)
	await frames(2)
	check(holding(), "the part that is not burning yet can be grabbed")
	from = me.global_position
	for i in 40:
		me.global_position = from + Vector3(-1.0, 0, 0.6) * float(i + 1) / 40.0
		await physics_frame
	check(holding() and burn.burning and burn.root().distance_to(root_was) > 0.6, "and pulled away while it burns (moved %.2f m)" % burn.root().distance_to(root_was))
	var let_go_at := -1.0
	for i in 400:
		await physics_frame
		if not holding():
			let_go_at = float(burn.length) if kit.cords.has(id2) else 0.0
			break
	check(let_go_at > 0.02 and let_go_at < grab.HOT, "when the fire reaches the hand, the hand lets go (%.2f m left)" % let_go_at)
	await frames(60)
	check(not kit.cords.has(id2), "the scrap burns away")

	# ---- 切れ端を拾って、爆弾につなぐ：その長さの導火線になる ----
	var r0: Vector3 = spot + Vector3(0.9, 0, 1.1)
	var id3: int = await scrap(r0, r0 + Vector3(1.5, 0, 0))
	var fuse: Node = kit.cords[id3]
	await stand(spot + Vector3(1.7, 0, 0.5))
	grab.h_grab(grab.CORD, id3, fuse.length)
	await frames(30)
	check(holding() and grab.end_of(fuse, float(grab.grabs[me.peer_id]["s"])) == 1, "the scrap's end is picked up")
	me.target = bomb
	var act: Dictionary = grab.f_action(me)
	hint = grab.hud_view(me, "爆弾", "F 点火\n左クリック 持つ")
	check(str(act.get("do", "")) == "bomb" and "つなぐ" in str(hint.get("keys", "")) and not has_digit(str(hint.get("keys", ""))), "looking at the bomb with the end in hand offers to connect it")
	me.target = bomb
	check(grab.handle_f(me), "F is taken by the rope in hand")
	await frames(3)
	check(kit.cords.has(id3) and fuse.a_body == bomb and kit.bomb_cord() == fuse and bomb.has_cord and not holding(), "the scrap is now connected to the bomb's mouth, and the hand is empty")
	check(absf(fuse.length - 1.5) < 0.01 and fuse.b_body == null, "it is a fuse of the scrap's length (%.2f m)" % fuse.length)
	await frames(180)
	print("ROPE_GRAB fuse: root-mouth=", fuse.root().distance_to(bomb.mouth()), " stretch=", stretch(fuse), " asleep=", fuse.asleep, " speed=", fuse.speed())
	check(fuse.root().distance_to(bomb.mouth()) < 0.03 and stretch(fuse) < 1.03 and fuse.asleep, "it starts at the mouth, is not stretched, and has come to rest")
	await stand(fuse.tip() + Vector3(0.6, 0, 0.5))
	var lit: float = fuse.length
	var t0 := tick
	booms.clear()
	kit.h_light(id3, 1)
	await frames(2)
	check(fuse.burning, "the picked-up fuse can be lit at its tip as before")
	var want := int(lit * kit.BURN_SEC_PER_M * 60.0)
	await frames(want + 30)
	var took: int = int(booms[0][1]) - t0 if not booms.is_empty() else -1
	check(absi(took - want) <= 8, "it burns for its length: %d frames (expected about %d)" % [took, want])
	await frames(120)

	# ---- 切れ端をフックに結ぶ：フックから垂れたロープになる ----
	var side: Vector3 = hook_spot(2)
	var along: Vector3 = (truck.global_transform.basis.z).normalized()
	var id4: int = await scrap(side + along * 0.3, side + along * 0.3 + Vector3(signf((side - truck.global_position).x), 0, 0) * 4.5)
	var piece: Node = kit.cords[id4]
	var stock_was: float = kit.stock
	await stand(side)
	grab.h_grab(grab.CORD, id4, 0.0)
	await frames(30)
	check(holding(), "another scrap's end is picked up beside the truck")
	aim(ck.hook_at(2))
	me.target = null
	act = grab.f_action(me)
	hint = grab.hud_view(me, "", "")
	check(str(act.get("do", "")) == "hook" and int(act.get("hook", -1)) == 2 and "結ぶ" in str(hint.get("keys", "")), "looking at a hook with the end in hand offers to tie it")
	aim(ck.hook_at(2))
	me.target = null
	check(grab.handle_f(me), "F ties it")
	await frames(3)
	var hung := 0
	for lid: int in ck.lashes:
		if int(ck.lashes[lid]["a"]) == 2 and int(ck.lashes[lid]["b"]) == ck.END_FREE:
			hung = lid
	check(hung != 0 and not kit.cords.has(id4) and not holding(), "the scrap became a rope tied to the hook; the hand is empty")
	if hung == 0:
		print("ROPE_GRAB_TEST_FAIL")
		quit(1)
		return
	var line: Node = ck.lashes[hung]["cord"]
	check(absf(line.length - 4.5) < 0.01 and int(ck.lashes[hung]["coil"]) == ck.SCRAP and is_equal_approx(kit.stock, stock_was), "it keeps its length and takes nothing from the coil (%.2f m)" % line.length)
	await frames(200)
	print("ROPE_GRAB hung: root-hook=", line.root().distance_to(ck.hook_at(2)), " tip y=", line.tip().y - floor_y, " stretch=", stretch(line), " speed=", line.speed())
	check(line.root().distance_to(ck.hook_at(2)) < 0.03 and line.tip().y < floor_y + 0.1 and stretch(line) < 1.03, "it hangs from the hook down to the ground")
	check(ck.lash_count() == 0, "one end tied is not yet a lashing")

	# もう片方の端も結ぶ：荷台に掛かる。余った分は、結び目の先に垂れる
	await stand(line.tip() + Vector3(0.3, 0, 0.6))
	grab.h_grab(grab.LASH, hung, line.length)
	await frames(30)
	check(holding() and gap() < 0.1, "the hanging rope's free end is picked up")
	aim(ck.hook_at(2))
	me.target = null
	check(str(grab.f_action(me).get("do", "")) != "hook", "it cannot be tied to the hook it already hangs from")
	# 荷台をはさんだ向こうのフックへ、こちら側から投げて結ぶ（束のロープと同じ。軽トラを回り込むには、長さが足りない）
	from = me.global_position
	for i in 90:
		me.global_position = from.lerp(Vector3(side.x, floor_y + 0.1, side.z), float(i + 1) / 90.0)
		await physics_frame
	await frames(25)
	check(holding(), "carried back beside the truck")
	aim(ck.hook_at(7))
	me.target = null
	act = grab.f_action(me)
	check(str(act.get("do", "")) == "hook" and int(act.get("hook", -1)) == 7, "the far hook is offered")
	aim(ck.hook_at(7))
	me.target = null
	check(grab.handle_f(me), "F ties the second end")
	await frames(3)
	var total := 0.0
	var spare := 0
	for lid: int in ck.lashes:
		total += float(ck.lashes[lid]["cord"].length)
		if lid != hung:
			spare = lid
	check(int(ck.lashes[hung]["b"]) == 7 and ck.lash_count() == 1 and not holding(), "the rope now runs from hook to hook")
	check(absf(total - 4.5) < 0.02, "no rope appeared or vanished (%.2f m in all)" % total)
	check(spare != 0 and int(ck.lashes[spare]["a"]) == 7 and int(ck.lashes[spare]["b"]) == ck.END_FREE, "what was left over hangs past the knot (%.2f m)" % (float(ck.lashes[spare]["cord"].length) if spare != 0 else -1.0))
	await frames(240)
	print("ROPE_GRAB tied: stretch=", stretch(line), " length=", line.length, " speed=", line.speed())
	check(stretch(line) < 1.03 and line.root().distance_to(ck.hook_at(2)) < 0.03 and line.tip().distance_to(ck.hook_at(7)) < 0.03, "it spans the bed between the two hooks")

	# ---- 張ったロープは動かない：つかんでも、手から抜ける（束のロープを、フックのそばまで行って結んで張る） ----
	await stand(hook_spot(0))
	await take(coil)
	ck.h_hook(0)
	await frames(15)
	game.h_release()
	await stand(hook_spot(5))
	await take(coil)
	await frames(10)
	ck.h_hook(5)
	await frames(15)
	game.h_release()
	await frames(200)
	var tight := 0
	for lid: int in ck.lashes:
		if int(ck.lashes[lid]["a"]) == 0 and int(ck.lashes[lid]["b"]) == 5:
			tight = lid
	check(tight != 0, "the coil's rope is tied tight across the bed as before")
	var taut: Node = ck.lashes[tight]["cord"] if tight != 0 else line
	var before: PackedVector3Array = taut.pts.duplicate()
	grab.h_grab(grab.LASH, tight, taut.length * 0.5)
	await frames(2)
	check(holding(), "a taut rope can be touched")
	var moved := 0.0
	worst = 1.0
	for i in 150:
		await physics_frame
		worst = maxf(worst, stretch(taut))
		for j in mini(before.size(), taut.pts.size()):
			moved = maxf(moved, before[j].distance_to(taut.pts[j]))
	print("ROPE_GRAB taut: moved=", moved, " stretch=", worst, " holding=", holding())
	check(moved < 0.4 and worst < 1.03, "but it does not come along: it gives only its little slack (%.2f m at most), without stretching" % moved)
	check(not holding(), "and it slips out of the hand")
	ck.h_untie(tight)
	await frames(3)
	check(not ck.lashes.has(tight), "the coil's rope unties as before")

	# ---- ほどく：今までどおり F。切れ端から作ったロープは、床の切れ端に戻る ----
	aim(line.point_at(line.length * 0.5))
	me.target = null
	check(str(ck.f_action(me).get("do", "")) == "untie" and not grab.aim(me).is_empty(), "bare hands at a tied rope: F still unties, and a click would grab")
	hint = grab.hud_view(me, "ロープ", "F ほどく")
	check("ほどく" in str(hint["keys"]) and "つかむ" in str(hint["keys"]), "both hints are shown")
	var scraps_was: int = kit.cords.size()
	ck.h_untie(hung)
	await frames(3)
	check(not ck.lashes.has(hung) and kit.cords.size() == scraps_was + 1 and is_equal_approx(kit.stock, stock_was), "untied, it falls as a scrap again (nothing is wound back onto the coil)")
	ck.h_untie(spare)
	await frames(3)
	check(ck.lashes.is_empty(), "the spare piece is untied too")

	# ---- 束から出ている途中のロープ：両端がつながっている。たるみの分だけ動く。束に残りがあれば、引けば出てくる ----
	place(coil, bomb.global_position + Vector3(0.9, 0.06, 0.3), 0.0, false)
	await stand(bomb.global_position + Vector3(1.6, 0, 0))
	await frames(20)
	game.h_grab(coil.pid)
	await frames(3)
	kit.h_connect()
	await frames(3)
	from = me.global_position
	for i in 90:
		me.global_position = from + Vector3(3.5, 0, 0.5) * float(i + 1) / 90.0
		await physics_frame
	game.h_release()
	await frames(280)
	var feed: Node = kit.bomb_cord()
	print("ROPE_GRAB paid out: ", feed != null, " coil=", feed.b_body == coil if feed != null else false, " asleep=", feed.asleep if feed != null else false, " speed=", feed.speed() if feed != null else -1.0, " len=", feed.length if feed != null else -1.0, " holder=", coil.holder)
	check(feed != null and feed.b_body == coil and feed.asleep, "a fuse is paid out from the coil and lies still")
	if feed == null:
		print("ROPE_GRAB_TEST_FAIL")
		quit(1)
		return
	var kept: float = kit.stock
	var len_was: float = feed.length
	kit.stock = 0.0              # 束を使い切ったことにする：両端がつながった、決まった長さのロープ
	var half: float = feed.length * 0.5
	mid = feed.point_at(half)
	await stand(mid + Vector3(0, 0, 1.0))
	me.aim_yaw = 0.0
	me.aim_pitch = 0.0
	var mid_y: float = mid.y
	grab.h_grab(grab.CORD, feed.id, half)
	await frames(2)
	check(holding(), "its middle can be grabbed")
	worst = 1.0
	var rose := 0.0
	k = feed.node_at(half)
	for i in 100:
		await physics_frame
		worst = maxf(worst, stretch(feed))
		rose = maxf(rose, feed.pts[k].y - mid_y)
	print("ROPE_GRAB two ends: rose=", rose, " stretch=", worst, " holding=", holding(), " slack=", feed.length - bomb.mouth().distance_to(feed.tip()))
	check(rose > 0.1 and worst < 1.03 and is_equal_approx(feed.length, len_was), "tied at both ends, it gives only its slack (rose %.2f m, stretched %.1f%% at most)" % [rose, (worst - 1.0) * 100.0])
	check(feed.root().distance_to(bomb.mouth()) < 0.03 and feed.b_body == coil, "both ends stay where they are tied")
	if holding():
		grab.h_release()
	await frames(120)
	kit.stock = kept
	# 束に近い所をつかんで、横へ歩く（爆弾の側は、つかんだ所までの長さしか無い。束の側は、束から出てくる）
	var near_coil: float = feed.length - 1.0
	await stand(feed.point_at(near_coil) + Vector3(-1.2, 0, 0.5))          # 手が、爆弾の側のロープの長さの内に入る所
	grab.h_grab(grab.CORD, feed.id, near_coil)
	await frames(30)
	from = me.global_position
	for i in 90:
		me.global_position = from + Vector3(0, 0, 0.9) * float(i + 1) / 90.0
		await physics_frame
	await frames(30)
	print("ROPE_GRAB feed: length ", len_was, " -> ", feed.length, " stock ", kept, " -> ", kit.stock, " holding=", holding())
	check(holding() and feed.length > len_was + 0.5 and is_equal_approx(kit.stock + feed.length, kept + len_was), "with rope left on the coil, pulling the middle draws more out (%.2f → %.2f m)" % [len_was, feed.length])
	grab.h_release()
	await frames(240)
	print("ROPE_GRAB feed rest: asleep=", feed.asleep, " speed=", feed.speed(), " stretch=", stretch(feed), " len=", feed.length, " stock=", kit.stock)
	check(feed.asleep and stretch(feed) < 1.02, "let go, it settles")

	# ---- 出発すると、手から離れる ----
	await stand(rope.point_at(1.0) + Vector3(0, 0, 1.0))
	grab.h_grab(grab.CORD, id, 1.0)
	await frames(2)
	var held_before: bool = holding()
	game.state = game.S.RESULT
	await frames(3)
	check(held_before and not holding(), "the hand lets go when the scene is no longer being prepared or shot")
	game.state = game.S.PREP

	print("ROPE_GRAB_TEST_FAIL" if failed else "ROPE_GRAB_TEST_OK", " checks=", checks)
	root.get_node("Sfx").silence_all()
	game.queue_free()
	await frames(8)
	quit(1 if failed else 0)
