extends SceneTree
# 会社のCMの試写会を撮る（題名の札・場面の見出し・「終」・読み上げ）
#   godot --path godot --position -32000,-32000 --audio-driver Dummy --fixed-fps 60 --script res://tests/premiere_cm_shot.gd
const OUT := "res://tests/shots/premiere/yard_"
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


func _initialize() -> void:
	root.unfocusable = true
	create_timer(420).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("PR_CHECK ", label, " ", "OK" if ok else "FAIL")
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
	print("PR_DUMP ", tag, " scene=", beats.scene, " lit=", beats.lit, " hold=", beats.holding, " t=%.1f" % game.take_t,
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
	game._headless = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	flow = game.production
	beats = game.beats
	S = game.S
	me = game.local_player()
	# ---- 1日目：来ている依頼は、会社のCMだけ ----
	var debut: int = flow.debut_job()
	check(debut >= 0 and flow.offered() == [debut], "1日目の依頼は、会社のCMだけ")
	check(beats.Scripts.cuts(debut) and (beats.Scripts.beats(debut) as Array).size() == 3 and (flow.JOBS[debut]["scenes"] as Array).size() == 3, "CMは、3カットのカット割り")
	check(str(flow.Briefs.brief(debut)["name"]) == "ランプ部長" and (flow.Briefs.BOARDS["pr"] as Array).size() == 3, "依頼主と絵コンテの文がある")
	# ふつうに遊ぶときと同じ：現場はスタジオの段階で決まり、事故もある
	flow.hazards = true
	flow.levels["studio"] = 0
	await shoot(debut, "野外の空き地")
	check(flow.day == 2 and debut not in flow.offered() and 0 in flow.offered() and flow.offered().size() == flow.JOBS.size() - 1, "2日目から、ほかの依頼が全部来る（CMは、もう来ない）")
	print("CMSHOT done failed=", failed)
	await frames(4)
	quit(1 if failed else 0)


# その現場で、CMを受けてから納品して事務所へ戻るまで
func shoot(debut: int, site: String) -> void:
	game.h_accept_job(debut)
	await frames(20)
	check(flow.phase >= 1 and beats.cut_mode() and str(flow.story()) == "castle", "%s：受けると、城の台本の役（城・爆発）で、カット割りで進む" % site)
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
	check(await wait_lit(1, 8.0), "%s：2カット目：二人の背後で、書割が爆ぜた" % site)
	check(await wait_hold(3.0) and beats.next_scene == 2, "%s：撮れたら、また止まる" % site)
	# 場転：カメラを二人へ寄せて、ライトを手前へ向け直す（向け直さないと、顔が暗い）
	game._aim_camera(AIM_CLOSE, 40.0)
	for i in 2:
		game._aim_spot(game.spots[i], Vector3(0.0, 1.2, 1.8))
	await frames(150)
	game.h_beat(1)
	await frames(5)
	check(await wait_lit(2, 10.0), "%s：3カット目：寄りの決めポーズが撮れた" % site)
	for i in 400:
		if game.state == S.RESULT:
			break
		await physics_frame
	check(game.state == S.RESULT and not false in game.takes[0]["passed"], "%s：3カットそろって、テイクが終わる" % site)
	print("PR_MEASURE %s：テイクの長さ（回していた分だけ）%.1f 秒" % [site, float(game.takes[0]["dur"]) if not game.takes.is_empty() else -1.0])
	# ---- 試写会を撮る ----
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var premiere: Node = game.hooks.feature("premiere")
	game.request_deliver(0)
	await frames(40)
	await snap("cm_1_title")
	await frames(110)
	await snap("cm_2_chapter")
	for i in 900:
		if int(game.beats.scene) == 1:
			break
		await physics_frame
	await frames(4)
	await snap("cm_3_cut")
	for i in 1200:
		if game.state != S.REPLAY:
			break
		await physics_frame
	await frames(30)
	await snap("cm_4_end")
	for i in 900:
		if premiere._tally_done:
			break
		await process_frame
	await frames(10)
	await snap("cm_5_tally")
	game.h_return_office()
	await frames(20)


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CMSHOT ", name)
