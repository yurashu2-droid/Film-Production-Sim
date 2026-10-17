extends SceneTree
# 爆弾を確かめる（数字やキーで決めず、物を手で扱う作り）：
#   つなぐ前は、点火した瞬間に爆発 / 束を持って口金につなぎ、離れると線が出ていく（重力で垂れて床を這う）/
#   はさみで切ると短くなり、切れ端が床に残る / 線の長さぶんの時間で爆発する / 燃えている途中で切ると爆発しない /
#   袋から注いだ量で爆風の強さがとぎれなく変わる / 袋1つ全部で大爆発 / 注ぐ量にはむらがある / 外せば床にこぼれる /
#   数字の表示が無い / 本番で爆発すると空になり、大きな爆発はギャラが増える。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/bomb_test.gd
const Cast := preload("res://scripts/production_cast.gd")
const FxBox := preload("res://scripts/fx_box.gd")
var game: Node
var kit: Node
var bomb: Node
var me: Node
var failed := false
var checks := 0
var booms: Array = []          # 鳴った爆発の音 [名前, 物理コマの番号]
var tick := 0
var whole_note := 0.0


func _initialize() -> void:
	run.call_deferred()


func _physics_process(_delta: float) -> bool:
	tick += 1
	return false


func check(ok: bool, label: String) -> void:
	checks += 1
	print("BOMB_CHECK ", label, " ", "OK" if ok else "FAIL")
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


func of_kind(kind: String) -> Array:
	var out: Array = []
	for pid: int in game.props:
		if game.props[pid].kind == kind and not game.props[pid].absent:
			out.append(game.props[pid])
	return out


func boom(bags: int) -> Dictionary:
	return Cast.score("kaiju", {"boom": [{"kind": "fx", "label": "爆弾", "tags": ["powder%d" % bags]}]})


func _heard(sound: String, _position: Variant) -> void:
	if sound.begins_with("explosion"):
		booms.append([sound, tick])


# 手に持つ（いま持っている物は置く）
func take(prop: Node) -> void:
	game.h_release()
	await frames(2)
	prop.set_fixed(false)
	game.h_grab(prop.pid)
	await frames(3)


# 爆弾のそばに立ち、そこへ持ってきた物を手に持つ（運ぶ所は省く）
func fetch(prop: Node) -> void:
	game.h_release()
	await frames(2)
	me.global_position = bomb.global_position + Vector3(1.6, 0.1, 0)
	place(prop, bomb.global_position + Vector3(0.9, 0.06, 0.3), 0.0, false)
	await frames(20)
	game.h_grab(prop.pid)
	await frames(3)


# 持ったまま歩く（1コマに step ずつ）
func walk(by: Vector3, steps: int) -> void:
	for i in steps:
		me.global_position += by / float(steps)
		await physics_frame


# 袋を、口が爆弾の口の真上に来るように持つ（自分は爆弾の +X 側に立つ）
func hold_over_bomb(sack: Node, offset: Vector3 = Vector3.ZERO) -> void:
	game.h_release()
	await frames(2)
	me.global_position = bomb.global_position + Vector3(1.6, 0.1, 0) + offset
	var mouth: Vector3 = bomb.mouth() + offset
	place(sack, mouth + Vector3(sack.SPOUT, 0.42 - sack.center.y, 0), 0.0, false)
	await frames(2)
	game.h_grab(sack.pid)
	await frames(4)


# count コマのあいだ F を押して離す。[押している間に入った量, 離したあとに入った量]
func pour(count: int) -> Array:
	var before: float = bomb.powder
	kit.h_pour(true)
	await frames(count)
	kit.h_pour(false)
	var released: float = bomb.powder
	await frames(45)
	return [released - before, bomb.powder - released]


func digits(text: String) -> bool:
	for ch in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


func labels(node: Node) -> int:
	return node.find_children("*", "Label3D", true, false).size()


func on_floor(cord: Node, ground: float) -> float:
	var low := 0
	for p: Vector3 in cord.pts:
		if p.y < ground + 0.08:
			low += 1
	return float(low) / float(maxi(1, cord.pts.size()))


func run() -> void:
	# ---- 採点：量を3段階に当てはめる。たくさん入れた爆発ほどギャラが増える ----
	check(int(boom(1)["coins"]) == 60 and (boom(1)["combos"] as Array).is_empty(), "a modest amount is a proper explosion")
	check(int(boom(2)["coins"]) == 60 + 120 and "大爆発" in str(boom(2)["combos"][0]["name"]), "plenty of powder is a big explosion")
	check(int(boom(3)["coins"]) == 60 + 250 and "超" in str(boom(3)["combos"][0]["name"]), "a whole sack is a huge explosion")
	check(FxBox.stage_of(0.0) == 0 and FxBox.stage_of(0.3) == 1 and FxBox.stage_of(0.6) == 2 and FxBox.stage_of(1.0) == 3, "the amount maps onto the three grades")
	var rising := true
	var last := 0.0
	for i in 21:
		var power: float = FxBox.blast_of(float(i) / 20.0)
		rising = rising and power > last
		last = power
	check(rising and FxBox.blast_of(0.1) < 0.7 and FxBox.blast_of(1.0) >= 1.9, "the blast grows continuously with the amount (%.2f → %.2f)" % [FxBox.blast_of(0.05), FxBox.blast_of(1.0)])

	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	root.get_node("Sfx").played.connect(_heard)
	var flow: Node = game.production
	var S: Dictionary = game.S
	bomb = game.fx
	kit = game.bomb_kit
	me = game.local_player()
	var coil: Node = kit.coil
	var scissors: Node = kit.scissors
	var sacks: Array = kit.sacks
	check(not scissors.absent and not coil.absent and coil == game.cargo_kit.rope and sacks.all(func(s: Node) -> bool: return s.absent), "before renting: the company's scissors and rope are out (the fuse is the cargo rope)")
	check(not game.OPTIONS.any(func(o: Dictionary) -> bool: return o["id"] == "fuse"), "the fuse is no longer a rental item")
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "kaiju" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_set("refill", 2)
	game.h_order_confirm()
	await frames(8)
	check(not bomb.absent and bomb.label == "爆弾" and bomb.kind == "fx", "the rental is a bomb")
	check(is_zero_approx(bomb.powder) and not bomb.loaded() and bomb.charges == 0, "the bomb arrives empty")
	check(sacks.filter(func(s: Node) -> bool: return not s.absent).size() == 3 and sacks.all(func(s: Node) -> bool: return is_equal_approx(s.fill, 1.0)), "one sack comes with the bomb, two more were bought: three full sacks")
	check(is_equal_approx(kit.stock, kit.COIL_M) and kit.cords.is_empty(), "the rope is a separate coil, not yet connected")
	check(flow.expenses == 360 + 80, "the bomb and the powder are paid from the budget (%d)" % flow.expenses)
	check(labels(bomb) == 0 and labels(coil) == 0 and labels(sacks[0]) == 0 and labels(scissors) == 0, "no number tags on the bomb, the coil, the sacks or the scissors")

	# ---- 会社で：つなぐ前は、点火した瞬間に爆発する ----
	var spot: Vector3 = flow.HOME_TRUCK + Vector3(-7.5, 0.0, -1.5)
	place(bomb, spot + Vector3(0, 0.05, 0))
	me.global_position = spot + Vector3(-14, 0.1, -3)
	await frames(30)
	var ground: float = bomb.global_position.y
	kit.h_light_bomb()
	await frames(2)
	check(bomb.fuse < 0.0, "the bomb cannot be lit from far away")
	me.global_position = spot + Vector3(1.6, 0.1, 0)
	await frames(4)
	var t0 := tick
	kit.h_light_bomb()
	await frames(2)
	check(bomb.fuse > 0.0 and bomb.fuse < 1.0, "without a fuse, lighting leaves under a second")
	await frames(70)
	check(bomb.fuse < 0.0 and booms.size() == 1 and int(booms[0][1]) - t0 < 60, "and it goes off at once (%d frames; a rehearsal pop here)" % (int(booms[0][1]) - t0 if not booms.is_empty() else -1))

	# ---- つなぐ：束を持って、口金につなぐ。離れると線が出ていき、重力で垂れて床を這う ----
	place(coil, spot + Vector3(0.9, 0.06, 0.3), 0.0, false)
	await frames(20)
	kit.h_connect()
	check(kit.cords.is_empty(), "connecting needs the coil in hand")
	await take(coil)
	kit.h_connect()
	await frames(3)
	var cord: Node = kit.bomb_cord()
	check(cord != null and cord.a_body == bomb and cord.b_body == coil and bomb.has_cord, "F with the coil connects its end to the bomb's mouth")
	if cord == null:
		print("BOMB_TEST_FAIL")
		quit(1)
		return
	var short: float = cord.length
	await walk(Vector3(4.5, 0, 0.6), 110)
	await frames(90)
	var reach: float = bomb.mouth().distance_to(coil.global_position)
	print("BOMB cord length=", cord.length, " reach=", reach, " stock=", kit.stock, " nodes=", cord.pts.size(), " floor=", on_floor(cord, ground))
	check(cord.length > short + 3.0 and cord.length >= reach and cord.length < reach + 2.6, "carrying the coil away pays the fuse out (%.2f m for a %.2f m walk)" % [cord.length, reach])
	check(is_equal_approx(kit.stock + cord.length, kit.COIL_M), "what is paid out leaves the coil (%.2f m left)" % kit.stock)
	check(on_floor(cord, ground) > 0.5 and cord.path_length() > reach * 1.03, "the fuse hangs down and lies along the floor, not a stiff rod (%.0f%% of it on the floor)" % (on_floor(cord, ground) * 100.0))
	var mouth: Vector3 = bomb.mouth()
	check(cord.pts[0].distance_to(mouth) < 0.02 and cord.pts[3].y < mouth.y, "it starts at the mouth and drops from there")
	check(labels(cord) == 0, "no number tag on the fuse")
	# 案内は動作だけ（数字なし）
	var hint: Dictionary = game.cargo_kit.hud_view(me)
	check("結ぶ" in str(hint.get("keys_all", "")) and "つなぐ" in str(hint.get("keys_all", "")), "holding the rope: the hint offers both tying to a truck hook and connecting to the bomb")
	check(str(kit.f_action(me).get("do", "")) == "coil" and str(game.cargo_kit.f_action(me).get("do", "")) == "rope", "the same rope still works as the cargo rope")
	# 置いて数秒たった線：全部の節が止まっている。長さも伸び縮みしない
	game.h_release()
	await frames(240)
	var rest_pts: PackedVector3Array = cord.pts.duplicate()
	var rest_len: float = cord.length
	var rest_stock: float = kit.stock
	print("BOMB rest: speed=", cord.speed(), " asleep=", cord.asleep, " stretch=", cord.path_length() / cord.length)
	check(cord.asleep and is_zero_approx(cord.speed()), "a rope left alone comes to a complete stop (top speed %.4f m/s)" % cord.speed())
	check(cord.path_length() <= cord.length * 1.01 and cord.path_length() > cord.length * 0.9, "it is not stretched, and lies at about its full length (laid out %.2f m of %.2f m)" % [cord.path_length(), cord.length])
	await frames(180)
	var drift := 0.0
	for i in rest_pts.size():
		drift = maxf(drift, rest_pts[i].distance_to(cord.pts[i]))
	check(cord.pts.size() == rest_pts.size() and is_zero_approx(drift), "three seconds later not one node has moved (%.5f m)" % drift)
	check(is_equal_approx(cord.length, rest_len) and is_equal_approx(kit.stock, rest_stock), "and its length has not changed")
	whole_note = cord.length
	await take(coil)

	# ---- はさみで切る：切った所までの長さになり、切れ端が床に残る ----
	var whole: float = cord.length
	check(absf(whole - whole_note) < 0.3, "picking the coil up again does not jerk more rope out (%.2f → %.2f m)" % [whole_note, whole])
	kit.h_cut(cord.id, 2.0)
	check(is_equal_approx(cord.length, whole), "cutting needs the scissors in hand")
	place(scissors, me.global_position + Vector3(-0.6, 0.1, 0.4), 0.0, false)
	await take(scissors)
	hint = kit.hud_view(me)
	check("切る" in str(hint.get("keys", "")), "holding the scissors: the hint says to cut")
	me.global_position = bomb.global_position + Vector3(2.0, 0.1, 0.8)
	await frames(4)
	kit.h_cut(cord.id, 2.0)
	await frames(3)
	var scrap: Node = null
	for other: Node in kit.cords.values():
		if other != cord:
			scrap = other
	check(absf(cord.length - 2.0) < 0.06 and cord.a_body == bomb and cord.b_body == null, "the fuse is cut where the scissors were (%.2f m left on the bomb)" % cord.length)
	check(scrap != null and absf(scrap.length - (whole - 2.0)) < 0.1 and scrap.a_body == null and scrap.b_body == null, "the cut-off piece is a loose scrap (%.2f m)" % (scrap.length if scrap != null else -1.0))
	await frames(120)
	check(scrap != null and kit.cords.has(scrap.id) and on_floor(scrap, ground) > 0.9, "the scrap falls and stays on the floor")
	check(coil.holder == 0 and kit.coil_cord() == null and kit.stock < kit.COIL_M - whole + 0.01, "the coil keeps only what was never paid out")

	# ---- 点火：火は線の上を、長さぶんの時間をかけて進む。燃えた所は無くなる ----
	game.h_release()
	await frames(2)
	me.global_position = cord.tip() + Vector3(0.6, 0.1, 0.5)
	me.global_position.y = ground + 0.1
	await frames(4)
	var lit: float = cord.length
	t0 = tick
	booms.clear()
	kit.h_light(cord.id, 1)
	await frames(2)
	check(cord.burning and bomb.fuse < 0.0, "F at the tip lights the fuse; the bomb itself is not lit yet")
	await frames(58)
	check(absf(cord.length - (lit - 1.0 / kit.BURN_SEC_PER_M)) < 0.06 and booms.is_empty(), "after one second the fire has eaten %.2f m (one metre takes %.1f s)" % [lit - cord.length, kit.BURN_SEC_PER_M])
	var want := int(lit * kit.BURN_SEC_PER_M * 60.0)
	await frames(want - 60 - 12)
	check(booms.is_empty(), "nothing happens until the fire reaches the mouth")
	await frames(40)
	var took: int = int(booms[0][1]) - t0 if not booms.is_empty() else -1
	check(absi(took - want) <= 6, "a %.2f m fuse burns for %d frames (expected about %d)" % [lit, took, want])
	check(kit.bomb_cord() == null and not bomb.has_cord, "the burnt fuse is gone")
	check(is_zero_approx(bomb.powder), "an empty bomb only pops")

	# 短く切りすぎた線：逃げる間が無い
	await fetch(coil)
	kit.h_connect()
	await frames(3)
	await walk(Vector3(2.5, 0, 0), 60)
	await frames(30)
	cord = kit.bomb_cord()
	await take(scissors)
	kit.h_cut(cord.id, 0.4)
	await frames(3)
	t0 = tick
	booms.clear()
	kit.h_light(cord.id, 1)
	await frames(60)
	took = int(booms[0][1]) - t0 if not booms.is_empty() else -1
	check(took > 0 and took <= int(0.4 * kit.BURN_SEC_PER_M * 60.0) + 6, "a fuse cut too short goes off almost at once (%d frames)" % took)

	# ---- 束を使い切る：先が束から外れて落ちる ----
	kit.stock = 2.2
	await fetch(coil)
	kit.h_connect()
	await frames(3)
	await walk(Vector3(3.0, 0, 0), 70)
	await frames(60)
	cord = kit.bomb_cord()
	check(cord != null and cord.b_body == null and is_zero_approx(kit.stock) and cord.length < 2.3 and on_floor(cord, ground) > 0.4, "when the coil runs out, the end slips off and drops (%.2f m of fuse)" % (cord.length if cord != null else -1.0))

	# ---- 燃えている途中で切る：火は切れた先へ進まず、爆発しない ----
	kit.stock = kit.COIL_M          # 新しい束に取り替えたことにする
	await fetch(coil)
	kit.h_connect()
	await frames(3)
	await walk(Vector3(3.0, 0, 0), 70)
	await frames(30)
	cord = kit.bomb_cord()
	await take(scissors)
	kit.h_cut(cord.id, 2.6)
	await frames(3)
	booms.clear()
	kit.h_light(cord.id, 1)
	await frames(40)
	var before_cut: int = kit.cords.size()
	kit.h_cut(cord.id, 1.0)
	await frames(3)
	var burning_scrap: Node = null
	for other: Node in kit.cords.values():
		if other.burning:
			burning_scrap = other
	check(not cord.burning and absf(cord.length - 1.0) < 0.06 and cord.a_body == bomb, "cutting ahead of the fire leaves a dead fuse on the bomb")
	check(burning_scrap != null and burning_scrap != cord and kit.cords.size() == before_cut + 1, "the fire stays on the cut-off piece")
	await frames(300)
	check(booms.is_empty() and bomb.fuse < 0.0, "the bomb does not go off")
	check(burning_scrap == null or not kit.cords.has(burning_scrap.id), "the burning piece burns away to nothing")
	check(kit.bomb_cord() == cord and absf(cord.length - 1.0) < 0.06, "the dead fuse is still there")

	# ---- 火薬：袋から口へ注ぐ。量は見た目で分かる（玉のふくらみ・口の粉・袋のしぼみ・重さ） ----
	var sack: Node = sacks[0]
	var empty_scale: float = bomb._body.scale.x
	var empty_mass: float = bomb.mass
	var full_sack: float = sack._bag.scale.y
	await hold_over_bomb(sack)
	hint = kit.hud_view(me)
	check("注ぐ" in str(hint.get("keys", "")) and not digits(str(hint["keys"]).get_slice("\n", 0)), "holding a sack: the hint says to pour")
	# むら：同じ時間だけ押しても、入る量は毎回ちがう。止めても少しこぼれる
	var got: Array = []
	var dribbled := 0
	for trial in 8:
		bomb.powder = 0.0
		sack.fill = 1.0
		var result: Array = await pour(60)
		got.append(float(result[0]) + float(result[1]))
		if float(result[1]) > 0.0005:
			dribbled += 1
	print("BOMB pours (1 s each)=", got)
	check(float(got.max()) - float(got.min()) > 0.03 and float(got.max()) > float(got.min()) * 1.4, "the same one-second pour gives a different amount every time (%.2f … %.2f)" % [got.min(), got.max()])
	check(dribbled == 8, "a little more runs out after letting go")
	# 時間に比例しない：出が悪い時と、どさっと出る時がある
	bomb.powder = 0.0
	sack.fill = 1.0
	var steps: Array = []
	kit.h_pour(true)
	for i in 30:
		var was: float = bomb.powder
		await frames(6)
		steps.append(bomb.powder - was)
	kit.h_pour(false)
	await frames(45)
	var moving: Array = steps.filter(func(x: float) -> bool: return x > 0.00001)
	print("BOMB pour steps=", steps.map(func(x: float) -> float: return snappedf(x, 0.001)))
	check(not moving.is_empty() and float(moving.max()) > float(moving.min()) * 5.0, "the flow is uneven: a trickle, then a gush (%.3f … %.3f per tenth of a second)" % [moving.min(), moving.max()])
	await frames(4)
	var part: float = bomb.powder
	check(part > 0.05 and bomb._body.scale.x > empty_scale + 0.02 and bomb.mass > empty_mass + 0.5 and bomb._level.visible, "what is inside shows: the ball swells, powder rises in the mouth, the bomb gets heavier (%.2f in)" % part)
	check(sack.fill < 0.95 and sack._bag.scale.y < full_sack - 0.02 and sack.mass < sack.FULL_MASS, "and the sack sags")
	check(is_equal_approx(bomb.blast(), FxBox.blast_of(part)), "the blast follows the amount")
	# 袋1つを全部入れる：口いっぱいで、いちばん大きな爆発
	bomb.powder = 0.0
	sack.fill = 1.0
	kit.h_pour(true)
	for i in 1200:
		if sack.fill <= 0.0:
			break
		await physics_frame
	await frames(50)
	check(is_zero_approx(sack.fill) and kit.rates.is_empty(), "the sack runs empty and stops")
	check(bomb.powder > 0.93 and bomb.stage() == 3 and bomb.blast() > 1.85 and bomb._heap.visible, "a whole sack fills the bomb to the brim: the huge explosion (%.2f in, blast ×%.2f)" % [bomb.powder, bomb.blast()])
	check(kit.spills.is_empty(), "poured over the mouth, nothing is spilled")
	kit.h_pour(true)
	await frames(10)
	check(kit.rates.is_empty(), "an empty sack pours nothing")
	kit.h_pour(false)
	# あふれる：口いっぱいの爆弾へさらに注ぐと、まわりにこぼれる
	sack = sacks[1]
	await hold_over_bomb(sack)
	kit.h_pour(true)
	await frames(150)
	kit.h_pour(false)
	await frames(45)
	var near := 0
	for spill: Array in kit.spills:
		if (spill[0] as Vector3).distance_to(bomb.global_position) < 0.8:
			near += 1
	check(is_equal_approx(bomb.powder, bomb.CAP) and near > 0, "pouring into a full bomb overflows onto the floor around it (%d piles)" % kit.spills.size())
	# 外す：口から離れた所で注ぐと、全部が床にこぼれて残る
	var piles: int = kit.spills.size()
	await hold_over_bomb(sack, Vector3(0, 0, 1.1))
	kit.h_pour(true)
	await frames(120)
	kit.h_pour(false)
	await frames(45)
	var missed := 0.0
	for spill: Array in kit.spills:
		if (spill[0] as Vector3).distance_to(bomb.global_position + Vector3(0, 0, 1.1)) < 0.5:
			missed += float(spill[1])
	check(kit.spills.size() > piles and missed > 0.01 and is_equal_approx(bomb.powder, bomb.CAP), "pouring beside the bomb spills it all on the floor (%.2f)" % missed)
	check(kit._spill_root.get_child_count() >= kit.spills.size(), "the spilled powder is shown on the floor")
	game.h_release()
	await frames(2)
	# こぼれた粉に火が移る：爆弾のすぐそばなら、爆弾も爆発する
	booms.clear()
	kit._touch_spills(bomb.global_position + Vector3(0, 0, 1.1), 0.1, 0.0)
	await frames(90)
	check(kit.spills.is_empty(), "fire runs from pile to pile and burns all the spilled powder")
	check(booms.size() >= 3, "and the fire reaches the bomb standing in its own spill (%d pops)" % booms.size())
	check(kit.bomb_cord() == null, "the blast takes the connected fuse with it")

	# ---- 積んで現場へ（線をつないだ爆弾は、線ごと運ばれる） ----
	kit.stock = kit.COIL_M
	await fetch(coil)
	kit.h_connect()
	await frames(3)
	await walk(Vector3(1.5, 0, 0), 40)
	await take(scissors)
	kit.h_cut(kit.bomb_cord().id, 1.2)
	await frames(3)
	game.h_release()
	await frames(2)
	var monster: Node = of_kind("tomato_monster")[0]
	var cartons: Array = of_kind("carton")
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	# 箱が大きくなったので、箱3つを先に積むと荷台の床が埋まる。爆弾を先に積む（床に置けなかった箱は、手に持ったまま現場へ行く）
	for prop: Node in [monster, bomb, cartons[0], cartons[1], cartons[2]]:
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(12)
	check(bomb.pid in flow.cargo(), "the bomb rides on the truck")
	check("powder%d" % bomb.stage() in flow.cast_tags(bomb) and (flow.cast_sheet()["combos"] as Array).any(func(c: Dictionary) -> bool: return "大爆発" in str(c["name"])), "the casting sheet previews the big explosion once a full bomb is packed")
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "crew arrives at the location")
	cord = kit.bomb_cord()
	check(cord != null and cord.tip().distance_to(bomb.global_position) < 2.5, "the connected fuse came along with the bomb")

	place(game.film, Vector3(0, 0, 6.0))
	place(monster, Vector3(-0.95, 0, 4.55))
	place(cartons[0], Vector3(-1.6, 0, -1.6))
	place(cartons[1], Vector3(-0.2, 0, -2.0), 0.4)
	place(cartons[2], Vector3(3.0, 0, -1.4), -0.3)
	place(bomb, Vector3(1.4, 0, -6.0))
	place(game.spots[0], Vector3(-2.6, 0, 3.4), PI)
	place(game.spots[1], Vector3(3.4, 0, 3.4), PI)
	game.actors[0].mark.restore([Vector3(0.7, 0.05, 0.0), Quaternion.IDENTITY, false])
	game.actors[1].mark.restore([Vector3(1.9, 0.05, 0.4), Quaternion.IDENTITY, false])
	await frames(20)
	# 道具は会社に置いてきた。確認のために、現場へ運んだことにする（置き直す）
	place(coil, bomb.global_position + Vector3(0.9, 0.06, 0.3), 0.0, false)
	place(scissors, bomb.global_position + Vector3(2.6, 0.1, 0.9), 0.0, false)
	sack = sacks[2]
	# 新しく量って入れる（会社で入れた分は、確認のために空にする）
	bomb.powder = 0.0
	await hold_over_bomb(sack)
	kit.h_pour(true)
	for i in 900:
		if bomb.powder >= bomb.BIG:
			break
		await physics_frame
	kit.h_pour(false)
	await frames(50)
	print("BOMB poured on set=", bomb.powder, " sack left=", sack.fill)
	check(bomb.powder >= bomb.BIG and sack.fill > 0.0, "pouring until it looks like plenty overshoots a little (%.2f)" % bomb.powder)
	# 採点の確認をそろえるため、入れすぎた分は捨てたことにする（大爆発の範囲に収める）
	bomb.powder = minf(bomb.powder, 0.62)
	await fetch(coil)
	kit.h_connect()
	await frames(3)
	await walk(Vector3(3.2, 0, 0.4), 80)
	await frames(40)
	cord = kit.bomb_cord()
	await take(scissors)
	kit.h_cut(cord.id, 2.6)
	await frames(3)
	game.h_release()
	await frames(2)
	print("BOMB on set: fuse=", cord.length, " burning=", cord.burning, " stock=", kit.stock, " cords=", kit.cords.size())
	check(absf(cord.length - 2.6) < 0.06 and not cord.burning, "on set: a fresh fuse, cut to length")
	game._aim_camera(Vector3(0.6, 0.75, 0.0), 56.0)
	game._aim_spot(game.spots[0], game.actors[0].global_position + Vector3(0, 1.2, 0))
	game._aim_spot(game.spots[1], game.actors[1].global_position + Vector3(0, 1.2, 0))
	game.h_standby()
	await frames(40)
	print("BOMB hints(prep)=", game.live["hints"])
	check((game.live["hints"] as Array).is_empty() and game.bomb_armed(), "the bomb on set is the explosion")

	# 合図キーの 2 では鳴らない
	game.input_locked = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.keycode = KEY_2
	key.pressed = true
	root.push_input(key)
	await frames(4)
	game.input_locked = true
	check(bomb.fuse < 0.0 and not cord.burning, "the cue key does not set off the bomb")

	game.h_take()
	await frames(200)
	check(game.state == S.TAKE, "take starts")
	game.h_cue(1)
	await frames(200)
	check(game.judge.passed()[0], "scene 1 passes")
	var grade: int = bomb.stage()
	me.global_position = cord.tip() + Vector3(0.5, 0.1, 0.5)
	await frames(4)
	booms.clear()
	kit.h_light(cord.id, 1)
	await frames(2)
	check(cord.burning, "the pyro lights the fuse on set")
	me.global_position = Vector3(9.0, 0.1, 7.0)
	await frames(120)
	check(not game.judge.passed()[1] and bomb.loaded() and booms.is_empty(), "nothing happens until the fuse burns down")
	await frames(130)
	check(not bomb.loaded() and game.judge.boom_power == grade and grade == 2, "the explosion uses up the powder (grade %d)" % game.judge.boom_power)
	# 本物の爆発の音は、火薬の量で explosion / explosion_big / explosion_huge のどれか（空は explosion_fizzle）
	check(booms.any(func(b: Array) -> bool: return b[0] in ["explosion", "explosion_big", "explosion_huge"]), "it is a real blast this time")
	check(booms.any(func(b: Array) -> bool: return b[0] == "explosion_big"), "a big charge (grade 2) sounds like a big blast")
	await frames(60)
	check(game.judge.passed()[1] and game.judge.boom_src == bomb.pid, "scene 2: the bomb goes off behind the pair")
	game.h_cue(3)
	await frames(60)
	place(monster, Vector3(-1.5, 0.0, 1.6))
	monster.set_fixed(false)
	me.global_position = Vector3(-2.6, 0.1, 2.6)
	await frames(20)
	game.h_prop_action(monster.pid)
	await frames(460)
	check(game.state == S.RESULT and not game.takes.is_empty(), "take ends")
	if not game.takes.is_empty():
		var shot: Dictionary = game.takes[0]
		print("BOMB passed=", shot["passed"], " cast=", shot["extras"]["cast"])
		for line: Array in Cast.lines(shot["extras"]["cast"]):
			print("  ", line[0], "  ", line[1])
		check(not false in shot["passed"], "all three scenes pass with the bomb")
		var report: Dictionary = shot["extras"]["cast"]
		check((report["combos"] as Array).any(func(c: Dictionary) -> bool: return "大爆発" in str(c["name"]) and int(c["coins"]) == 120), "the big explosion is paid")
		var bonus: int = 150 if shot["extras"].get("bonus_ok", false) else 0
		check(flow.take_fee(0) == 1200 + bonus + int(report["coins"]) and int(report["coins"]) == 60 + 0 + 60 + 120, "the fee adds the explosion bonus (%d)" % flow.take_fee(0))
	print("BOMB_TEST_FAIL" if failed else "BOMB_TEST_OK", " checks=", checks)
	quit(1 if failed else 0)
