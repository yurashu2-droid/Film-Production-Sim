extends SceneTree
# 場所が変わるカット割り「旅する二人」を、通しで確かめる（城の門 → 月夜の丘 → 爆発 → 寄りで決め）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/travel_test.gd
# 月夜の丘の場面は、前の場面の城が映っていると撮れない（場所が変わったように見えない）。
# カットして城を片づけ、月役の物を出して回し直すと撮れる。
var game: Node
var flow: Node
var beats: Node
var S: Dictionary
var me: Node
var failed := false

const CAM_AT := Vector3(0.0, 0.0, 5.0)
const AIM_WIDE := Vector3(0.0, 1.0, -1.6)
const AIM_CLOSE := Vector3(0.0, 0.8, 1.8)
const MARKS := [[Vector3(-0.7, 0.05, -1.6), Vector3(-1.0, 0.05, -0.5), Vector3(-0.6, 0.05, 1.8)],
	[Vector3(0.7, 0.05, -1.6), Vector3(1.0, 0.05, -0.5), Vector3(0.6, 0.05, 1.8)]]
const CASTLE_AT := Vector3(0.0, 0.0, -2.8)
const FLAT_AT := Vector3(1.9, 0.0, -3.0)
const SPOT_AT := [Vector3(-2.6, 0.0, 2.6), Vector3(2.6, 0.0, 2.6)]
const ME_AT := Vector3(3.0, 0.1, 6.0)          # カメラの後ろ（画面の外）
const MOON_AT := Vector3(-1.7, 0.0, -3.4)
const AWAY := Vector3(9.0, 0.0, 14.0)           # 画面の外（片づけた城の置き場）


func _initialize() -> void:
	create_timer(200).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("TRAVEL_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = true) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), fixed])


func of_kind(kind: String) -> Array:
	return game.props.values().filter(func(p: Node) -> bool: return p.kind == kind and not p.absent)


func dump(tag: String) -> void:
	var f: Dictionary = game.judge.frame
	var acts: Array = f.get("actors", [])
	print("TRAVEL_DUMP ", tag, " scene=", beats.scene, " lit=", beats.lit, " hold=", beats.holding, " t=%.1f" % game.take_t,
		" actors=", acts.map(func(a: Dictionary) -> String: return "%.2f%s%s" % [float(a["h"]), "" if a["vis"] else "-not", "" if a["lit"] else "-dark"]),
		" st=", [game.actors[0].st, game.actors[1].st], " castle=", f.get("castle"), " any=", f.get("castle_any"), " back=", f.get("castle_back"),
		" fx_in=", f.get("fx_in"), " behind=", f.get("fx_behind"), " close=", f.get("close"), " crew=", flow.notes.crew_in_frame(), " why=", beats.why)


# 場面が撮れるまで待つ（最大 sec 秒）
func wait_lit(i: int, sec: float) -> bool:
	for k in int(sec * 60.0):
		if i < beats.lit.size() and beats.lit[i]:
			return true
		await physics_frame
	dump("scene %d" % i)
	return false


func wait_hold(sec: float) -> bool:
	for k in int(sec * 60.0):
		if beats.holding:
			return true
		await physics_frame
	return false


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	beats = game.beats
	S = game.S
	me = game.local_player()
	var job := -1
	for i in flow.JOBS.size():
		if str(flow.JOBS[i].get("board", "")) == "travel":
			job = i
	check(job >= 0 and beats.Scripts.cuts(job) and (beats.Scripts.beats(job) as Array).size() == 4, "場所が変わる4カットの依頼がある")
	flow.day = 2
	flow.all_jobs = true
	check(job in flow.offered(), "2日目から来る（--day2 と同じく、全部出す）")
	await shoot(job, str(flow.JOBS[job]["location"]))
	print("TRAVEL_TEST_FAIL" if failed else "TRAVEL_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)


# その現場で、CMを受けてから納品して事務所へ戻るまで
func shoot(debut: int, site: String) -> void:
	game.h_accept_job(debut)
	await frames(20)
	check(flow.phase >= 1 and beats.cut_mode() and str(flow.story()) == "castle", "%s：受けると、城の台本の役（城・月・爆発）で、カット割りで進む" % site)
	me.global_position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(490)
	check(flow.phase == 4 and flow.location_name() == site, "%s：現場に着いた" % site)
	# ---- 現場：アーチを城に見立て、爆炎の書割を奥に立て、ライトを二人へ ----
	var arch: Node = of_kind("scrap_arch")[0]
	var flat: Node = of_kind("boomflat")[0]
	var film: Node = game.film
	place(film, CAM_AT)
	place(arch, CASTLE_AT, PI)
	place(flat, FLAT_AT, 0.0)
	for aid in 2:
		for step in 3:
			(beats.mark(aid, step) as Node).restore([MARKS[aid][step], Quaternion.IDENTITY, false])
	for i in 2:
		place(game.spots[i], SPOT_AT[i], PI)
	var book: Node = flow.script_prop
	me.global_position = ME_AT
	place(book, ME_AT + Vector3(0.6, 0.0, 0.0), 0.0, false)
	await frames(30)
	check(flow.cast_set(arch.pid, "castle") and flow.role_of(arch) == "castle", "%s：アーチを、城の役にする" % site)
	check(flow.role_of(flat) == "boom", "%s：爆炎の書割は、最初から爆発の役" % site)
	for i in 2:
		game._aim_spot(game.spots[i], Vector3(0.0, 1.3, -1.0))
		game.spots[i].level = 3
	game._aim_camera(AIM_WIDE, 56.0)
	game.h_standby()
	await frames(30)
	# ---- 本番 ----
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	check(game.state == S.TAKE and beats.scene == 0, "%s：カチンコで、1カット目が回る" % site)
	check(await wait_lit(0, 8.0), "%s：1カット目：城の前の二人が撮れた" % site)
	check(await wait_hold(3.0) and beats.next_scene == 1, "%s：撮れたら、フィルムが止まる（場転）" % site)
	await frames(90)
	game.h_beat(1)
	await frames(5)
	check(not beats.holding and beats.scene == 1, "%s：1 で、2カット目を回す" % site)
	# 月夜の丘：城を残したまま回すと、撮れない（前の場面の城が映っている）
	var moon: Node = of_kind("carton")[0]
	await frames(240)
	check(not beats.lit[1] and "前の場面の城" in str(beats.why[1]), "%s：城が映ったままだと、月夜の丘は撮れない" % site)
	game.h_beat(1)
	await frames(5)
	check(beats.holding and beats.next_scene == 1, "%s：撮れていない場面で 1：止めて、同じ場面を撮り直す" % site)
	# 場転：城を片づけて、段ボールを月の役にして出す
	place(arch, AWAY, PI)
	place(moon, MOON_AT)
	await frames(10)
	check(flow.cast_set(moon.pid, "moon") and flow.role_of(moon) == "moon", "%s：段ボールを、月の役にする" % site)
	await frames(60)
	game.h_beat(1)
	await frames(5)
	check(await wait_lit(1, 8.0), "%s：城を片づけて月を出すと、月夜の丘が撮れた" % site)
	check(await wait_hold(3.0) and beats.next_scene == 2, "%s：撮れたら止まる（次は爆発）" % site)
	await frames(60)
	game.h_beat(1)
	await frames(5)
	check(await wait_lit(2, 8.0), "%s：月の下で、書割が爆ぜた" % site)
	check(await wait_hold(3.0) and beats.next_scene == 3, "%s：撮れたら止まる（次は寄り）" % site)
	# 場転：カメラを二人へ寄せて、ライトを手前へ向け直す（向け直さないと、顔が暗い）
	game._aim_camera(AIM_CLOSE, 40.0)
	for i in 2:
		game._aim_spot(game.spots[i], Vector3(0.0, 1.2, 1.8))
	await frames(150)
	game.h_beat(1)
	await frames(5)
	check(await wait_lit(3, 10.0), "%s：4カット目：寄りの決めポーズが撮れた" % site)
	for i in 400:
		if game.state == S.RESULT:
			break
		await physics_frame
	check(game.state == S.RESULT and not false in game.takes[0]["passed"], "%s：4カットそろって、テイクが終わる" % site)
	print("TRAVEL_MEASURE %s：テイクの長さ（回していた分だけ）%.1f 秒" % [site, float(game.takes[0]["dur"]) if not game.takes.is_empty() else -1.0])
	# ---- 試写会（放送）→ 電話 ----
	if game.state == S.RESULT:
		game.request_deliver(0)
		await frames(140)
		var premiere: Node = game.hooks.feature("premiere")
		check(game.state == S.REPLAY and premiere.screening == 0, "%s：納品を頼むと、試写会（放送）が始まる" % site)
		game.h_stop_replay()
		await frames(20)
		check(flow.phase == 5 and int(flow.last_payment) >= 150 + 4 * 250 + 350, "%s：4カットそろったギャラ（%d）" % [site, int(flow.last_payment)])
		premiere.finish_tally()
		premiere.finish_tally()
	else:
		game._cut()
		await frames(5)
		game.h_deliver(0)
		await frames(10)
	game.h_return_office()
	await frames(20)
