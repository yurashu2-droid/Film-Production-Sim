extends SceneTree
# 5場面の台本「怪獣、段ボールの街に現る・完全版」を確かめる（場面どうしが、同じ物・同じ場所・同じ人手を取り合う）。
#   受注 → 印①②③が6つ出る → 通し稽古（フィルムは減らない・爆弾は鳴らない・通り道をふさぐと役者が立ち止まる）→
#   テイク1：二人ぶんの手（台本とカメラの係／火薬と黒子の係）で、5場面を一本のフィルムに収める → 見返し。
#   テイク2：撮れない撮り方（怪獣が先に映る・火薬が少なすぎる・多すぎる）と、やり直し。最後はフィルム切れ。
#   テイク3：別の解き方（怪獣を板の後ろに隠してどける・別のカメラへ切り替えて寄る）と、倒す人が映った場合。 → 納品。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/kaiju5_test.gd
# ひとつの画面の中で、二人目の制作班の操作を出すために、Net.acting_as を使う（自動確認だけの仕掛け）。
# 物を運ぶ・歩く所は省いて、置き直している（ほかの確認と同じ）。爆発・倒れ方・映り方は、ゲームの計算そのまま。
var game: Node
var flow: Node
var beats: Node
var kit: Node
var net: Node
var S: Dictionary
var me: Node                    # 一人目：台本とカメラの係（この画面の人）
var mate: Node                  # 二人目：カチンコ・火薬・黒子の係
var film: Node
var cam_b: Node
var monster: Node
var bomb: Node
var book: Node
var board: Node
var cartons: Array = []
var failed := false
var checks := 0
var heard: Array = []           # 鳴った音の名前
var job := -1

# 現場の置き方（確認の中で決めた、うまくいく一例。野外の現場は、東の奥に小屋があるので、西側を使う）
const CAM_AT := Vector3(0.0, 0.0, 6.0)
const MONSTER_AT := Vector3(-0.95, 0.0, 4.55)          # カメラのすぐ手前（遠近法で大きく見せる）
const CITY_AT := [Vector3(0.3, 0.0, -2.4), Vector3(1.9, 0.0, -2.9), Vector3(3.5, 0.0, -2.0), Vector3(5.0, 0.0, -2.6)]
const BOMB_AT := Vector3(1.6, 0.0, -6.2)               # 街の向こう。怪獣とカメラからは遠い
const MARKS := [[Vector3(5.4, 0.05, 0.4), Vector3(1.0, 0.05, 0.4), Vector3(-0.5, 0.05, 0.9)],
	[Vector3(6.2, 0.05, -0.4), Vector3(1.9, 0.05, -0.3), Vector3(0.7, 0.05, 1.0)]]
const SPOT_AT := [Vector3(3.3, 0.0, 9.5), Vector3(-3.2, 0.0, 4.6)]
const SPOT_AIM := [Vector3(3.5, 1.3, 0.0), Vector3(0.1, 1.3, 1.0)]
const AIM_WALK := Vector3(3.6, 0.9, -0.3)              # 1場面目：右へ振って、怪獣を画面の外に
const AIM_WIDE := Vector3(0.6, 0.75, 0.0)              # 2〜4場面目：怪獣を手前に入れた引き
const AIM_CLOSE := Vector3(-0.4, 0.6, 2.4)             # 5場面目：寄り（倒れた怪獣も入れる）
const FOV_WIDE := 56.0
const FOV_CLOSE := 44.0
const CAM_B_AT := Vector3(-2.6, 0.0, 5.6)              # 2台目：倒れた怪獣ごしに、印③の二人を寄りで撮る
const AIM_B := Vector3(0.2, 0.6, 2.0)
const FOV_B := 40.0
const ME_AT := Vector3(0.2, 0.1, 7.0)                  # カメラの後ろ
const BOOK_AT := Vector3(1.0, 0.1, 7.0)                # 置いた台本（カメラのそば）
const MONITOR_AT := Vector3(0.9, 0.0, 8.9)
const OFFSTAGE := Vector3(-2.4, 0.1, 7.4)              # カメラの後ろ（画面の外）。ここから怪獣に手が届く
const BOARD_HIDE := Vector3(-0.8, 0.0, 5.3)            # 怪獣の前に立てた板（カメラから怪獣が見えない）
const BOARD_AWAY := Vector3(-8.0, 0.0, 7.0)
const BEHIND_BOARD := Vector3(-2.2, 0.1, 4.2)          # 板の陰（カメラから見えない）
const IN_SHOT := Vector3(0.6, 0.1, 3.2)                # 画面の中（怪獣に手が届く）
const BLOCK_AT := Vector3(0.45, 0.0, 0.75)             # 印②から③への通り道
const POWDER_GOOD := 0.45
const POWDER_FEW := 0.04
const POWDER_MUCH := 1.0
const FUSE_M := 6.0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("KAIJU5_CHECK ", label, " ", "OK" if ok else "FAIL")
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


func _heard(sound: String, _position: Variant) -> void:
	heard.append(sound)


# 二人目の操作として呼ぶ
func as_mate(action: Callable) -> void:
	net.acting_as = mate.peer_id
	action.call()
	net.acting_as = 0


# カメラの係が、カメラをその向き・画角へ動かす（操作中の人の入力と同じ道。首振りとズームの差分を送る）
func aim(point: Vector3, fov: float) -> void:
	var d: Vector3 = film.global_basis.inverse() * (point - (film.global_position + Vector3(0, film.HEAD_Y, 0)))
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	game.h_aim(film.pid, wrapf(yaw - film.cam_yaw, -PI, PI), pitch - film.cam_pitch, (film.fov - fov) / 3.0)


# 置き物のカメラの向きを決める（準備のうち）
func point_camera(camera: Node, point: Vector3, fov: float) -> void:
	var d: Vector3 = camera.global_basis.inverse() * (point - (camera.global_position + Vector3(0, camera.HEAD_Y, 0)))
	camera.cam_yaw = atan2(-d.x, -d.z)
	camera.cam_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	camera.fov = fov


func lamps() -> Array:
	return game.camera_switcher.monitor.lamps_shown


func none_lit() -> bool:
	return lamps() == [false, false, false, false, false]


# 画面に出ている文字（見えているラベル）を集める
func words(node: Node, out: Array) -> Array:
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text != "":
		out.append((node as Label).text)
	for child in node.get_children():
		words(child, out)
	return out


func why(i: int) -> String:
	return str(beats.why[i]) if i < beats.why.size() else ""


func upright(prop: Node3D) -> bool:
	return prop.global_basis.y.normalized().y >= 0.6


func dump(tag: String) -> void:
	var f: Dictionary = game.judge.frame
	var acts: Array = f.get("actors", [])
	var sizes: Array = []
	for a: Dictionary in acts:
		sizes.append("%.2f%s" % [float(a["h"]), "" if a["vis"] else ("-dark" if a["shown"] else "-out")])
	var m: Dictionary = f.get("monster", {})
	print("KAIJU5 ", tag, " scene=", beats.scene, " lit=", beats.lit, " t=%.1f" % game.take_t, " actors=", sizes, " st=", [game.actors[0].st, game.actors[1].st],
		" monster[in=", m.get("in"), " seen=", m.get("seen"), " up=", m.get("up"), " size=%.2f]" % float(m.get("size", 0.0)), " at=", (monster.center_global() as Vector3).snapped(Vector3.ONE * 0.01),
		" peek=", f.get("monster_peek"), " down=", f.get("monster_down"), " city=", f.get("city_n"), " city_max=%.2f" % float(f.get("city_max", 0.0)),
		" fx_in=", f.get("fx_in"), " behind=", f.get("fx_behind"), " crew=", flow.notes.crew_in_frame(),
		" A=", (game.actors[0].global_position as Vector3).snapped(Vector3.ONE * 0.01), " B=", (game.actors[1].global_position as Vector3).snapped(Vector3.ONE * 0.01), " cam=", game.program_camera().name, " yaw=%.2f" % film.cam_yaw)


# カメラ・ライト・怪獣・街を、決めた場所へ置く
func lay_out() -> void:
	place(film, CAM_AT)
	place(cam_b, CAM_B_AT)
	place(monster, MONSTER_AT, 0.0, false)
	for i in 4:
		place(cartons[i], CITY_AT[i], 0.2 * i, false)
	for i in 2:
		place(game.spots[i], SPOT_AT[i], PI)


# 二人目がカチンコを打って、本番を始める。一人目は、カメラを操作している
func start_take() -> void:
	game.h_operate(film.pid, true)
	await frames(3)
	as_mate(func() -> void: game.h_grab(game.clapper.pid))
	await frames(3)
	as_mate(func() -> void: game.h_use())
	await frames(200)
	as_mate(func() -> void: game.h_release())
	await frames(2)


# 二人目が、その量の火薬の入った爆弾に、じかに火を付けて、画面の外へ逃げる（導火線なし：すぐ爆発する）
func blast(amount: float) -> void:
	bomb.powder = amount
	mate.global_position = bomb.global_position + Vector3(-1.4, 0.1, 0.4)
	await frames(3)
	as_mate(func() -> void: kit.h_light_bomb())
	await frames(2)
	mate.global_position = OFFSTAGE


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	net = root.get_node("Net")
	root.get_node("Sfx").played.connect(_heard)
	flow = game.production
	beats = game.beats
	kit = game.bomb_kit
	S = game.S
	me = game.local_player()
	film = game.film
	cam_b = game.camera_switcher.cameras[1]
	bomb = game.fx

	await test_office()
	await test_set_up()
	await test_rehearsal()
	await test_good_take()
	await test_replay()
	await test_wrong_ways()
	await test_other_ways()
	await test_delivery()
	print("KAIJU5_TEST_FAIL" if failed else "KAIJU5_TEST_OK", " checks=", checks)
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)


# ---- 事務所：依頼・印・ギャラ・監督だけが見る絵 ----

func test_office() -> void:
	for i in flow.JOBS.size():
		if job < 0 and not (beats.Scripts.beats(i) as Array).is_empty() and not beats.Scripts.cuts(i):
			job = i          # 長回しの完全版（カット割りの依頼は cuts_test.gd）
	check(job >= 0 and flow.JOBS.size() >= 6 and (flow.JOBS[job]["scenes"] as Array).size() == 5 and (beats.Scripts.of(job)["scenes"] as Array).size() == 5 and (beats.list() as Array).is_empty(),
		"a sixth job exists with five scenes and a scene list")
	var old_jobs := 0
	for i in flow.JOBS.size():
		if (beats.Scripts.beats(i) as Array).is_empty() and (flow.JOBS[i]["scenes"] as Array).size() == 3:
			old_jobs += 1
	check(old_jobs == 5, "the five earlier jobs keep their three scenes")
	check(flow.offered() == [0], "on the first day only the practice job is offered")
	flow.day = 2
	check(job in flow.offered(), "from the second day the complete edition is offered")
	check(not beats.active() and game.judge.beats == null and of_kind("mark").size() == 2, "before the job: two marks, and the old judge")
	check(game.take_limit() == game.TAKE_SEC and not game.hides_take_clock(), "the old jobs keep their sixty-second take and its clock")
	check(not film.film_shown and (game.camera_switcher.monitor.lamps_shown as Array).is_empty(), "no reel on the camera and no lamps on the monitor for the old jobs")

	game.h_accept_job(job)
	await frames(6)
	check(flow.phase == 2 and beats.active() and game.judge.story == "kaiju" and game.judge.beats == beats, "accepting it switches to the scene list")
	var marks: Array = of_kind("mark")
	var labels: Array = marks.map(func(m: Node) -> String: return str(m.label))
	check(marks.size() == 6 and "立ち位置の印 A①" in labels and "立ち位置の印 A③" in labels and "立ち位置の印 B②" in labels, "six numbered marks are out: %s" % str(labels))
	var numerals: Array = []
	for aid in 2:
		for step in 3:
			var disc: Node = beats.mark(aid, step)
			numerals.append(str((disc.get_node("Numeral") as Label3D).text) if (disc.get_node("Numeral") as Label3D).visible else "-")
	check(numerals == ["1", "2", "3", "1", "2", "3"], "each mark shows its number on the floor disc")
	check(game.actors[0].mark == beats.mark(0, 0) and game.actors[1].mark == beats.mark(1, 0), "the actors wait on their first marks")
	check(is_equal_approx(game.take_limit(), beats.FILM_SEC) and beats.FILM_SEC >= 80.0, "the take is one roll of film (%.0f s)" % beats.FILM_SEC)
	# ギャラ：5場面そろうと、今までの 1.5 倍
	game.takes = [{"passed": [true, true, true, true, true], "results": [], "extras": {}}, {"passed": [true, true, true, false, false], "results": [], "extras": {}}]
	check(flow.take_fee(0) == 1800 and flow.take_fee(1) == 150 + 3 * 250, "five scenes pay 1800, half as much again as the old 1200 (%d / %d)" % [flow.take_fee(0), flow.take_fee(1)])
	game.takes = []
	check((game.scene_titles() as Array).size() == 5 and game.cue_names() == ["次の場面へ", "この場面をもう一度"], "the HUD names follow the job: five scenes, two keys")
	check(flow.Briefs.BRIEFS.size() == flow.JOBS.size() and (flow.Briefs.BOARDS["kaiju5"] as Array).size() == 5 and str(flow.JOBS[job]["board"]) == "kaiju5", "the job has its own client and five storyboard captions")
	# 絵コンテ5枚（鉛筆の絵）と、のぞき箱の参考スライド
	var boards := 0
	var same_as_old := 0
	for i in 5:
		var picture: Texture2D = game.production_hud.script_page.Storyboard.texture("kaiju5", i)
		boards += 1 if picture != null and picture.get_width() > 100 else 0
		same_as_old += 1 if game.production_hud.script_page.Storyboard.svg("kaiju5", i) == game.production_hud.script_page.Storyboard.svg("kaiju", mini(i, 2)) else 0
	check(boards == 5 and same_as_old == 0, "five pencil storyboards are drawn for this job")
	var view: Node = game.director.view
	view.sync(flow.slides, flow.JOBS)
	check(view.count() == 2 + 5, "the peep box has a slide for each of the five scenes (%d slides)" % view.count())
	var titles: Array = []
	for i in range(2, view.count()):
		titles.append_array(view.texts(i))
	check((flow.JOBS[job]["scenes"] as Array).all(func(scene: String) -> bool: return scene in titles), "each slide carries its scene name")
	view.close()

	# 借りる：爆弾と火薬
	game.h_open_order()
	game.h_order_set("fx", 1)
	game.h_order_set("refill", 1)
	game.h_order_confirm()
	await frames(8)
	check(not bomb.absent and flow.expenses == 400, "the bomb and a spare sack fit the budget (%d of %d)" % [flow.expenses, flow.budget()])

	# 積む：怪獣・爆弾・段ボール・台本。会社の機材は、いっしょに運ばれる
	monster = of_kind("tomato_monster")[0]
	cartons = of_kind("carton")
	book = flow.script_prop
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	for prop: Node in [monster, bomb, cartons[0], cartons[1], book]:
		place(prop, flow.HOME_TRUCK + Vector3(-3, 0.3, 1.2))
		prop.set_fixed(false)
		await frames(3)
		game.h_grab(prop.pid)
		await frames(2)
		game.h_load_truck(prop.pid)
		await frames(12)
	check(monster.pid in flow.cargo() and bomb.pid in flow.cargo() and book.pid in flow.cargo(), "the monster, the bomb and the script are packed")
	game.h_depart()
	await frames(490)
	check(flow.phase == 4, "the crew arrives at the location")
	check(of_kind("mark").size() == 6 and (beats.mark(0, 2) as Node3D).global_position.distance_to(beats.MARK_HOME[0][2]) < 0.4, "the six marks are waiting on the set")
	check(film.film_shown and (game.camera_switcher.cameras as Array).all(func(c: Node) -> bool: return c.film_shown and is_equal_approx(c.film_frac, 1.0)), "every camera carries a full reel")
	check(none_lit() and game.camera_switcher.monitor.ticks_left == 18, "the monitor frame shows five dark lamps and a full row of film ticks")


# ---- 現場：置き方を決める ----

func test_set_up() -> void:
	# 二人目の制作班（この画面の中だけの人。操作は Net.acting_as で出す）
	game._roster.append([2, 2])
	game._apply_roster()
	mate = game.players[2]
	mate.global_position = OFFSTAGE
	# 育成の記録（制作班スキル）は、参加者ひとりずつへ通信で返す。二人目は通信の相手ではないので、この確認では外しておく
	game.crew_skills.queue_free()
	game.crew_skills = null
	cartons = of_kind("carton")
	board = of_kind("plywood")[0]
	check(cartons.size() >= 4, "four cartons for the city (%d)" % cartons.size())
	lay_out()
	place(bomb, BOMB_AT)
	place(board, BOARD_AWAY)
	place(game.camera_switcher.monitor, MONITOR_AT, PI)
	for aid in 2:
		for step in 3:
			(beats.mark(aid, step) as Node).restore([MARKS[aid][step], Quaternion.IDENTITY, false])
	place(book, BOOK_AT, 0.0, false)
	me.global_position = ME_AT
	await frames(40)
	for i in 2:
		game._aim_spot(game.spots[i], SPOT_AIM[i])
		game.spots[i].level = 3
	point_camera(cam_b, AIM_B, FOV_B)
	# 火薬：袋から注ぐ（むらがあるので、入れすぎた分は捨てたことにして、量をそろえる）
	var sack: Node = kit.sacks[0]
	var coil: Node = kit.coil
	var scissors: Node = kit.scissors
	me.global_position = bomb.global_position + Vector3(1.6, 0.1, 0)
	place(sack, bomb.mouth() + Vector3(sack.SPOUT, 0.42 - sack.center.y, 0), 0.0, false)
	await frames(2)
	game.h_grab(sack.pid)
	await frames(4)
	kit.h_pour(true)
	for i in 900:
		if bomb.powder >= POWDER_GOOD:
			break
		await physics_frame
	kit.h_pour(false)
	await frames(50)
	check(bomb.powder >= POWDER_GOOD, "powder is poured from the sack into the bomb (%.2f)" % bomb.powder)
	bomb.powder = POWDER_GOOD
	game.h_release()
	await frames(2)
	# 導火線：束をつないで、歩いて伸ばし、はさみで切る（小屋の無い西側へ伸ばす）
	me.global_position = bomb.global_position + Vector3(-1.6, 0.1, 0)
	place(coil, bomb.global_position + Vector3(-0.9, 0.06, 0.3), 0.0, false)
	place(scissors, bomb.global_position + Vector3(-7.4, 0.1, 1.6), 0.0, false)
	await frames(20)
	game.h_grab(coil.pid)
	await frames(3)
	kit.h_connect()
	await frames(3)
	for i in 160:
		me.global_position += Vector3(-6.6, 0, 1.0) / 160.0
		await physics_frame
	await frames(40)
	var cord: Node = kit.bomb_cord()
	game.h_release()
	await frames(2)
	scissors.set_fixed(false)
	game.h_grab(scissors.pid)
	await frames(3)
	if cord != null:
		kit.h_cut(cord.id, FUSE_M)
	await frames(3)
	game.h_release()
	await frames(2)
	check(cord != null and absf(cord.length - FUSE_M) < 0.08, "a %.1f m fuse is laid from the bomb (%.2f m: about %.0f s)" % [FUSE_M, cord.length if cord != null else -1.0, FUSE_M * kit.BURN_SEC_PER_M])
	me.global_position = ME_AT
	place(scissors, Vector3(-9.0, 0.1, 9.0), 0.0, false)
	place(coil, Vector3(-9.5, 0.1, 9.0), 0.0, false)
	place(sack, Vector3(-10.0, 0.1, 9.0), 0.0, false)
	await frames(30)


# ---- 通し稽古：準備中に場面を進める ----

func test_rehearsal() -> void:
	var a: Node = game.actors[0]
	var b: Node = game.actors[1]
	check(game.state == S.PREP and beats.scene == -1 and a.st == a.St.STANDBY, "before rehearsing, the actors stand by on mark 1")
	check((game.live["hints"] as Array).is_empty() and game.live.get("mute", false) and (game.live["passed"] as Array).size() == 5, "no hint list in this job: the picture is for the crew to judge")
	await process_frame
	check(not (game.hud.hints as Label).text.contains("この画なら") and (words(game.hud.root, []) as Array).all(func(text: String) -> bool: return not "条件を満たせる" in text), "and no 'this framing is fine' answer on screen")
	# 台本を読めない人は進められない（二人目は、台本から遠い）
	as_mate(func() -> void: game.h_beat(1))
	await frames(4)
	check(beats.scene == -1 and not beats.may_direct(mate.peer_id), "someone who cannot read the script cannot turn the page")
	# 台本を手から置いても、すぐそばにいれば進められる
	check(book.holder == 0 and beats.may_direct(me.peer_id) and game.directs() and not game.reads_script(), "the script lying within reach still lets its reader direct")
	me.global_position = ME_AT + Vector3(5.0, 0, 0)
	await frames(3)
	game.h_beat(1)
	await frames(3)
	await process_frame
	check(not beats.may_direct(me.peer_id) and beats.scene == -1 and "台本を読める人だけ" in str(game.hud.toast_label.text), "but not from five metres away: the page does not turn")
	# 台本を持っている人がいれば、その人だけ
	as_mate(func() -> void: game.h_grab(book.pid))
	await frames(3)
	check(beats.may_direct(mate.peer_id) and mate.held == book.pid, "whoever holds the script can direct")
	me.global_position = ME_AT
	await frames(3)
	check(not beats.may_direct(me.peer_id), "and standing next to someone else's script is not enough")
	as_mate(func() -> void: game.h_release())
	await frames(3)
	place(book, BOOK_AT, 0.0, false)
	await frames(20)
	# 台本の冊子：場面ごとに小さな絵コンテ。せりふは、いまの場面の分だけ開く
	game.h_grab(book.pid)
	await frames(3)
	game.script_open = true
	await frames(3)
	await process_frame
	await process_frame
	var page: Control = game.production_hud.script_page
	var pictures: Array = page.find_children("*", "TextureRect", true, false)
	var open_talks: Array = (page._talks as Array).filter(func(talk: Control) -> bool: return talk.visible)
	var page_words: Array = words(page, [])
	check(page.visible and pictures.size() == 5 and pictures.all(func(pic: TextureRect) -> bool: return pic.texture != null), "the script booklet carries a small storyboard for each of the five scenes")
	check((page._blocks as Array).size() == 5 and open_talks.size() == 1 and page_words.any(func(text: String) -> bool: return "第5場" in text) and page_words.any(func(text: String) -> bool: return "1 で次の場面へ" in text),
		"it lists five scenes, opens the lines of one, and tells which keys turn the page")
	game.script_open = false
	game.h_release()
	await frames(3)
	place(book, BOOK_AT, 0.0, false)
	await frames(20)

	var powder: float = bomb.powder
	heard.clear()
	# キーボードの 1（今までの合図のキー）が、この依頼では「次の場面へ」になる
	game.input_locked = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.keycode = KEY_1
	key.pressed = true
	root.push_input(key)
	await frames(30)
	game.input_locked = true
	check(beats.scene == 0 and beats.rehearsal and a.st == a.St.BEAT_GO and a.vis.current == "walk" and a.vis.face == "happy", "the 1 key starts scene 1 as a rehearsal: the actors walk")
	check(not game.actors[0].is_confessing() and not heard.has("roar"), "and it is no longer the old cue 1")
	await frames(200)
	check(a.st == a.St.BEAT_HOLD and a.global_position.distance_to(MARKS[0][1]) < 0.3 and b.global_position.distance_to(MARKS[1][1]) < 0.3, "they walk straight to mark 2 and wait there")
	await frames(200)
	check(a.st == a.St.BEAT_HOLD and beats.scene == 0, "they keep waiting until the director turns the page")
	game.h_beat(3)
	await frames(4)
	check(beats.scene == 0, "3 does nothing in this job")
	game.h_beat(1)
	await frames(120)
	check(beats.scene == 1 and a.st == a.St.BEAT_HOLD and a.vis.face == "surprised", "scene 2: they freeze, looking up")
	# 通り道をふさぐ：役者は、その場で立ち止まって困った顔をする（よけない・登らない）
	place(board, BLOCK_AT, PI * 0.5)
	await frames(10)
	game.h_beat(1)
	await frames(150)
	check(beats.scene == 2 and a.st == a.St.BEAT_STUCK and a.vis.face == "sad" and a.global_position.distance_to(MARKS[0][2]) > 0.6 and a.global_position.y < 0.3,
		"a board across the way stops actor A, who stands there looking troubled (%.2f m short)" % a.global_position.distance_to(MARKS[0][2]))
	check(b.st == b.St.BEAT_HOLD and b.global_position.distance_to(MARKS[1][2]) < 0.3, "actor B, whose way is clear, reaches mark 3")
	await frames(120)
	check(a.st == a.St.BEAT_STUCK, "the stuck actor does not climb or squeeze past")
	# どけて「もう一度」：その場面の最初の印へ戻って、やり直す
	place(board, BOARD_AWAY)
	await frames(10)
	game.h_beat(2)
	await frames(12)
	check(beats.scene == 2 and b.st == b.St.BEAT_GO and b.vis.current == "run" and not b.beat_walking(), "2 sends them back to redo the scene")
	var back := false
	for i in 200:
		back = back or (a.global_position.distance_to(MARKS[0][1]) < 0.3 and b.global_position.distance_to(MARKS[1][1]) < 0.4)
		await physics_frame
	check(back and a.st == a.St.BEAT_HOLD and a.global_position.distance_to(MARKS[0][2]) < 0.3, "they return to mark 2 and run to mark 3 again")
	game.h_beat(1)
	await frames(40)
	game.h_beat(1)
	await frames(200)
	check(beats.scene == 4 and a.vis.current == "jump" and a.vis.face == "happy" and a.global_position.distance_to(b.global_position) < 1.45, "scene 5: they meet and cheer")
	game.h_beat(1)
	await frames(4)
	check(beats.scene == 4, "there is no page after the last scene")
	check(game.state == S.PREP and is_zero_approx(game.take_t) and is_equal_approx(beats.film_frac(), 1.0) and is_equal_approx(film.film_frac, 1.0), "rehearsing uses no film")
	check(is_equal_approx(bomb.powder, powder) and bomb.fuse < 0.0 and not heard.has("explosion") and kit.bomb_cord() != null, "and the bomb stays quiet: no powder is used")
	check(none_lit(), "no lamp lights in a rehearsal")
	game.h_standby()
	await frames(6)
	check(beats.scene == -1 and not beats.rehearsal and a.st == a.St.STANDBY and a.global_position.distance_to(MARKS[0][0]) < 0.2, "B ends the rehearsal: back to mark 1")


# ---- テイク1：二人ぶんの手で、5場面を一本に ----

func test_good_take() -> void:
	var a: Node = game.actors[0]
	var cord: Node = kit.bomb_cord()
	# 一人目：台本をそばに置いて、カメラを操作する。二人目：カチンコ・点火・黒子
	game.h_operate(film.pid, true)
	await frames(3)
	check(film.operator == me.peer_id and me.operating == film.pid and me.held == 0, "the first crew member operates the camera, the script at their feet")
	aim(AIM_WALK, FOV_WIDE)
	await frames(20)
	await start_take()
	check(game.state == S.TAKE and beats.scene == -1 and mate.held == 0, "the second crew member claps: the take starts")
	# 長い導火線に、先に火を付ける（時計の代わり）。そのあと、画面の外へ
	mate.global_position = cord.tip() + Vector3(-0.5, 0.1, 0.5)
	await frames(4)
	as_mate(func() -> void: kit.h_light(cord.id, 1))
	await frames(2)
	check(cord.burning, "the fuse is lit first: it is the clock for scene 3")
	mate.global_position = OFFSTAGE
	await frames(10)
	# 1：街を歩いてくる（怪獣は、画面の外）
	game.operator_click()
	await frames(20)
	check(beats.scene == 0 and not game.judge.frame["monster_peek"] and int(game.judge.frame["city_n"]) >= 2, "scene 1 starts with the city in the picture and the monster out of it")
	# 数字の表示が無い：残り秒数は、どこにも出ない
	await process_frame
	var shown: Array = words(game.hud.root, []) + words(game.production_hud.root, [])
	var clock := RegEx.new()
	clock.compile("\\d+:\\d\\d|\\d+\\s*秒")
	check(not game.hud.take_row.visible and not game.production_hud._clock.visible and shown.all(func(text: String) -> bool: return clock.search(text) == null),
		"during this take no seconds are shown anywhere on screen")
	check(film.find_children("*", "Label3D", true, false).is_empty() and game.camera_switcher.monitor.find_children("*", "Label3D", true, false).is_empty(), "and neither the reel nor the monitor frame carries a number")
	await frames(110)
	check(beats.lit[0] and lamps()[0], "scene 1 is in the can: its lamp lights on the monitor (why=%s)" % why(0))
	await process_frame
	check("OK！" in str(game.hud.toast_label.text) and "街を歩いてくる" in str(game.hud.toast_label.text), "the one who directs is told so")
	await frames(40)
	# 2：カメラを振って、怪獣を見せる
	aim(AIM_WIDE, FOV_WIDE)
	game.operator_click()
	await frames(150)
	check(beats.lit[1] and lamps() == [true, true, false, false, false], "scene 2: panning reveals the monster towering over the city (why=%s)" % why(1))
	# 3：導火線が燃え尽きる前に、次の場面へ
	game.operator_click()
	await frames(10)
	check(beats.scene == 2 and a.vis.current == "run" and cord.burning, "scene 3: the pair runs while the fuse is still burning")
	for i in 600:
		if beats._boom_t >= 0.0:
			break
		await physics_frame
	check(beats._boom_t >= 0.0 and not bomb.loaded() and heard.has("explosion"), "the bomb goes off during scene 3")
	await frames(200)
	dump("after the blast")
	print("KAIJU5 fallen=", beats._fallen.size(), " of ", beats._boom_snap.size(), " monster_fell=", beats._mon_fell, " boom_ok=", beats._boom_ok)
	check(beats.lit[2] and beats._fallen.size() >= 2 and upright(monster), "scene 3: the blast topples the city and leaves the monster standing (why=%s)" % why(2))
	check(upright(film) and upright(game.spots[0]) and upright(game.spots[1]), "the camera and the lights are still standing")
	# 4：二人目が、カメラの後ろ（画面の外）から怪獣を倒す
	game.operator_click()
	await frames(60)
	check((flow.notes.crew_in_frame() as Array).is_empty(), "nobody of the crew is in the picture")
	as_mate(func() -> void: game.h_prop_action(monster.pid))
	await frames(100)
	check(not upright(monster) and beats.lit[3], "scene 4: the monster falls with nobody in the picture (why=%s)" % why(3))
	# 5：引きのままでは撮れない。寄ると撮れる
	game.operator_click()
	await frames(150)
	dump("scene 5, wide")
	check(not beats.lit[4] and "寄りが足りない" in why(4), "scene 5 is not taken in the wide shot (why=%s)" % why(4))
	var before_zoom: float = film.film_frac
	aim(AIM_CLOSE, FOV_CLOSE)
	await frames(130)
	dump("scene 5, close")
	check(beats.lit[4] and lamps() == [true, true, true, true, true], "zooming in takes scene 5: all five lamps are lit (why=%s)" % why(4))
	check(film.film_frac < before_zoom and film.film_frac < 0.9 and film.reel_fill(0) < 1.0 and film.reel_fill(1) > film.REEL_EMPTY and game.camera_switcher.monitor.ticks_left < 18,
		"the reel has thinned and the film ticks have gone down as the take ran (%.0f%% left)" % (film.film_frac * 100.0))
	await frames(260)
	check(game.state == S.RESULT and not game.takes.is_empty(), "the take ends once all five are in the can")
	if game.takes.is_empty():
		return
	for r: Dictionary in game.takes[0]["results"]:
		print("  ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
	check(game.takes[0]["passed"] == [true, true, true, true, true], "all five scenes on one roll of film, with two pairs of hands")
	check(float(game.takes[0]["dur"]) < beats.FILM_SEC * 0.6, "with film to spare (%.0f of %.0f s used)" % [float(game.takes[0]["dur"]), beats.FILM_SEC])
	check(lamps() == [true, true, true, true, true] and beats.scene == -1, "while checking the take, the lamps show what it got")


# ---- 見返し：場面の進み・ランプ・フィルムが、撮ったときと同じに流れる ----

func test_replay() -> void:
	game.h_replay(0)
	await frames(30)
	check(game.state == S.REPLAY and none_lit() and beats.scene == -1 and film.film_frac > 0.95, "the replay starts with dark lamps and a full reel")
	var seen_scenes: Array = []
	var lamp_counts: Array = []
	for i in 2400:
		if game.state != S.REPLAY:
			break
		if beats.scene not in seen_scenes:
			seen_scenes.append(beats.scene)
		var lit_now: int = lamps().count(true)
		if lit_now not in lamp_counts:
			lamp_counts.append(lit_now)
		await physics_frame
	check(seen_scenes == [-1, 0, 1, 2, 3, 4] and lamp_counts == [0, 1, 2, 3, 4, 5], "it turns the pages and lights the lamps in the same order (%s / %s)" % [str(seen_scenes), str(lamp_counts)])
	check(game.state == S.RESULT and lamps() == [true, true, true, true, true] and beats.scene == -1, "after the replay the result is back")


# ---- テイク2：撮れない撮り方と、やり直し。最後はフィルム切れ ----

func test_wrong_ways() -> void:
	var a: Node = game.actors[0]
	game.h_retake()
	await frames(20)
	check(game.state == S.PREP and none_lit() and a.st == a.St.STANDBY and upright(monster) and cartons.slice(0, 4).all(func(c: Node3D) -> bool: return upright(c) and c.global_position.distance_to(CITY_AT[cartons.find(c)]) < 0.5),
		"retake: the set is back as it was, the lamps are dark")
	check(not bomb.loaded() and kit.bomb_cord() == null, "but the powder and the fuse are used up")
	# 1：怪獣が先に映っていると、撮れない
	aim(AIM_WIDE, FOV_WIDE)
	await start_take()
	aim(AIM_WIDE, FOV_WIDE)
	game.operator_click()
	await frames(220)
	check(not beats.lit[0] and "怪獣が先に映っていた" in why(0) and a.st == a.St.BEAT_HOLD, "scene 1 with the monster in the picture is not taken (why=%s)" % why(0))
	# カメラを振って、もう一度
	aim(AIM_WALK, FOV_WIDE)
	game.h_beat(2)
	await frames(30)
	check(a.st == a.St.BEAT_GO and a.vis.current == "run" and not a.beat_walking(), "again: the actors hurry back to mark 1 (this does not count as walking)")
	await frames(250)
	check(beats.lit[0], "and the second walk, with the monster out of the picture, is taken (why=%s)" % why(0))
	aim(AIM_WIDE, FOV_WIDE)
	game.operator_click()
	await frames(150)
	check(beats.lit[1], "scene 2 is taken")
	# 3：火薬が少なすぎると、街が倒れない
	game.operator_click()
	await frames(80)
	await blast(POWDER_FEW)
	await frames(260)
	check(not beats.lit[2] and "街が倒れなかった" in why(2) and cartons.slice(0, 4).all(func(c: Node3D) -> bool: return upright(c)) and upright(monster),
		"too little powder: the city stays up, scene 3 is not taken (why=%s)" % why(2))
	# 多すぎると、怪獣まで倒れる
	game.h_beat(2)
	await frames(100)
	await blast(POWDER_MUCH)
	await frames(260)
	dump("too much powder")
	check(not beats.lit[2] and "怪獣まで倒れた" in why(2) and beats._fallen.size() >= 2, "too much powder: the monster goes down with the city, scene 3 is not taken (why=%s)" % why(2))
	# 立て直して、ちょうどよい量で
	lay_out()
	await frames(30)
	game.h_beat(2)
	await frames(100)
	await blast(POWDER_GOOD)
	await frames(260)
	check(beats.lit[2] and upright(monster), "the right amount: the city falls, the monster stands, scene 3 is taken (why=%s)" % why(2))
	# フィルムが切れると、テイクが終わる（残りわずかで、リールが鳴る）
	heard.clear()
	var low_seen := false
	var ran := 0
	for i in 6000:
		if game.state != S.TAKE:
			break
		low_seen = low_seen or (film._film_low and game.camera_switcher.monitor.ticks_left <= 3)
		ran += 1
		await physics_frame
	await frames(4)
	await process_frame
	check(game.state == S.RESULT and float(game.takes[1]["dur"]) >= beats.FILM_SEC - 0.1 and float(game.takes[1]["dur"]) < beats.FILM_SEC + 0.1, "when the film runs out the take ends (%.1f s)" % float(game.takes[1]["dur"]))
	check(low_seen and heard.count("ui_select") >= 10 and heard.has("unfix"), "near the end the reel rattles, and the last ticks turn red")
	check(game.takes[1]["passed"] == [true, true, true, false, false], "three scenes were taken on that roll")
	var results: Array = game.takes[1]["results"]
	for r: Dictionary in results:
		print("  ", "OK " if r["ok"] else "NG ", r["title"], " / ", r["detail"])
	check("フィルムが切れて" in str(results[3]["detail"]) and "フィルムが切れて" in str(results[4]["detail"]), "the scenes it never reached say so")
	check(lamps() == [true, true, true, false, false] and game.camera_switcher.monitor.ticks_left == 0 and is_zero_approx(film.film_frac), "the lamps and the empty reel show that take")
	# 場面を進められる人の画面の一覧（5行）も、そのテイクの成否になる（前のテイクの印が残らない）
	for i in 30:
		await process_frame
	var boxes: Array = (game.hud.order_boxes as Array) + (game.hud.more_boxes as Array)
	var rows: Array = (game.hud.order_lines as Array) + (game.hud.more_lines as Array)
	check(boxes.size() == 5 and boxes.map(func(box: Control) -> bool: return box.on and box.progress > 0.5) == [true, true, true, false, false] and rows.all(func(row: Label) -> bool: return row.is_visible_in_tree()),
		"the director's scene list has five rows and shows the same result")
	# テイク確認は選んだテイクを見せる（はじめは出来のよいテイク1）。テイク2を選ぶと、その理由が並ぶ
	var chosen: int = game.selected
	for i in 400:
		if (game.hud.panel as Control).visible:
			break
		await process_frame
	game.h_select(1)
	for i in 12:
		await process_frame
	var detail_words: Array = []
	for label: Node in (game.hud.result_view as Node).find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion():
			detail_words.append((label as Label).text)
	game.h_select(chosen)
	for i in 12:
		await process_frame
	check((game.hud.result_view as Control).visible and detail_words.any(func(text: String) -> bool: return "フィルムが切れて" in text) and detail_words.any(func(text: String) -> bool: return "怪獣の技で街がこわれる" in text), "the take check lists each scene with its reason")


# ---- テイク3：別の解き方（板の後ろに隠してどける・2台目のカメラで寄る）と、倒す人が映った場合 ----

func test_other_ways() -> void:
	game.h_retake()
	await frames(20)
	# 怪獣の前に板を立てて隠す。カメラは、最初から引きのまま
	place(board, BOARD_HIDE)
	bomb.powder = POWDER_GOOD
	aim(AIM_WIDE, FOV_WIDE)
	await start_take()
	aim(AIM_WIDE, FOV_WIDE)
	await frames(10)
	check(not game.judge.look()["monster_peek"], "a board in front of the monster hides it from the camera")
	game.operator_click()
	await frames(220)
	check(beats.lit[0], "scene 1 is taken without panning: the monster is behind the board (why=%s)" % why(0))
	# 2：黒子が、板の陰に隠れている間は映っていない。画面に出ると、その間は撮れていない
	game.operator_click()
	await frames(30)
	mate.global_position = BEHIND_BOARD
	await frames(30)
	check((flow.notes.crew_in_frame() as Array).is_empty(), "the stagehand behind the board is not in the picture")
	place(board, BOARD_AWAY)
	mate.global_position = IN_SHOT
	await frames(140)
	check(not beats.lit[1] and "スタッフが映っていた" in why(1) and not (flow.notes.crew_in_frame() as Array).is_empty(), "the board is gone, but with a crew member in the picture scene 2 is not counted (why=%s)" % why(1))
	mate.global_position = OFFSTAGE
	await frames(150)
	check(beats.lit[1], "once they step out, scene 2 is taken: the monster was revealed by moving the board")
	# 3：ちょうどよい量で
	game.operator_click()
	await frames(80)
	await blast(POWDER_GOOD)
	await frames(260)
	check(beats.lit[2], "scene 3 is taken (why=%s)" % why(2))
	# 4：倒す人が映っていると、撮れない
	game.operator_click()
	await frames(60)
	mate.global_position = IN_SHOT
	await frames(20)
	as_mate(func() -> void: game.h_prop_action(monster.pid))
	await frames(4)
	mate.global_position = OFFSTAGE
	await frames(120)
	check(not upright(monster) and not beats.lit[3] and "倒す人が映っていた" in why(3), "the monster is pushed over by someone in the picture: scene 4 is not taken (why=%s)" % why(3))
	# 起こして、画面の外から倒し直す
	mate.global_position = IN_SHOT
	await frames(4)
	as_mate(func() -> void: game.h_prop_action(monster.pid))
	await frames(4)
	mate.global_position = OFFSTAGE
	await frames(70)
	check(upright(monster) and not beats.lit[3], "the monster is stood up again")
	as_mate(func() -> void: game.h_prop_action(monster.pid))
	await frames(100)
	check(not upright(monster) and beats.lit[3], "pushed over from out of the picture, scene 4 is taken (why=%s)" % why(3))
	# 5：引きのままでは撮れない。2台目のカメラへ切り替えると撮れる
	game.operator_click()
	await frames(150)
	check(not beats.lit[4] and "寄りが足りない" in why(4), "scene 5 is not taken in the wide shot")
	game.h_operate(film.pid, false)
	await frames(3)
	game.h_monitor_control(true)
	await frames(3)
	game.h_camera_cut(1)
	await frames(130)
	dump("camera B")
	check(game.program_camera() == cam_b and beats.lit[4], "cutting to the second camera, set up close, takes scene 5 (why=%s)" % why(4))
	await frames(260)
	check(game.state == S.RESULT and game.takes.size() == 3 and game.takes[2]["passed"] == [true, true, true, true, true], "the third take also has all five scenes")


# ---- 納品 ----

func test_delivery() -> void:
	check(game.state == S.RESULT and game.takes.size() == 3, "three takes are in")
	if game.state != S.RESULT or game.takes.size() < 3:
		return
	var cast: Dictionary = game.takes[0]["extras"].get("cast", {})
	print("KAIJU5 cast=", cast.get("coins", 0), " bonus=", game.takes[0]["extras"].get("bonus_ok", false))
	check(game.takes[0]["extras"].get("bonus_ok", false) and not game.takes[2]["extras"].get("bonus_ok", false), "the first take earns the one-take bonus, the third does not")
	check(int(cast.get("coins", 0)) >= 60 and (cast.get("roles", []) as Array).size() == 3, "the casting is scored from scenes 2 and 3: monster, city and explosion")
	game.h_select(0)
	game.h_deliver(0)
	await frames(10)
	check(flow.phase == 5 and game.delivered_ok and flow.last_payment == 1800 + 150 + int(cast.get("coins", 0)), "delivering the complete take pays %d coins" % flow.last_payment)
	check(flow.last_payment >= 1800 * 1 and 1800 == 1200 * 3 / 2, "the base fee is half as much again as the three-scene jobs")
	game.h_return_office()
	await frames(10)
	check(flow.phase == 0 and not beats.active() and game.judge.beats == null and of_kind("mark").size() == 2 and not film.film_shown, "back at the office the extra marks, the reels and the scene list are put away")
