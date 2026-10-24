extends SceneTree
# 名場面のパロディの依頼（production_script.gd の 10〜16）を確かめる土台。
#   派生側が決めること：TITLE（依頼の題）・TARGETS（確かめる場面の番号）・prepare()（本番前の配置）・
#   before(t)（その場面を回す直前＝場転のあいだの用意）・during(t)（回し始めたあとの仕掛け。await 可）
# 流れ：依頼を受ける → 現場へ（会社の前で撮る依頼は、その場で）→ prepare → 本番 → 確かめない場面は撮れたことにして進む →
#   確かめる場面は before → 回す → during → 撮れたか（PARODY_CHECK の行）
var game: Node
var flow: Node
var beats: Node
var rig: Node
var S: Dictionary
var me: Node3D
var failed := false
var C := Vector3.ZERO           # 撮影現場の真ん中


func title() -> String:
	return ""


func targets() -> Array:
	return []


func prepare() -> void:
	pass


func before(_t: int) -> void:
	pass


func during(_t: int) -> void:
	pass


func label() -> String:
	return "PARODY"


func _initialize() -> void:
	create_timer(400).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(label(), "_CHECK ", text, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = false) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), fixed])


# 撮影カメラを置いて、その点へ向ける
func aim_camera(at: Vector3, look: Vector3, fov: float = 60.0) -> void:
	var film: RigidBody3D = game.film
	place(film, at, 0.0)
	await frames(20)
	var d: Vector3 = film.global_basis.inverse() * (look - (film.global_position + Vector3(0, film.HEAD_Y, 0)))
	film.cam_yaw = atan2(-d.x, -d.z)
	film.cam_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	film.fov = fov


func light(at: Vector3) -> void:
	var film: Node3D = game.film
	for i in 2:
		place(game.spots[i], film.global_position + Vector3(-1.4 + 2.8 * float(i), 0.0, 0.5), PI)
	await frames(10)
	for i in 2:
		game._aim_spot(game.spots[i], at + Vector3(0, 1.3, 0))
		game.spots[i].level = 3


func set_mark(aid: int, step: int, pos: Vector3) -> void:
	beats.place_spot(aid, step, pos)


func of_kind(kind: String) -> RigidBody3D:
	for p: Node in game.props.values():
		if p.kind == kind and not p.absent:
			return p
	return null


func until_holding() -> void:
	for i in 400:
		if beats.holding:
			return
		await physics_frame


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
	rig = game.hooks.feature("contraptions")
	S = game.S
	me = game.local_player()
	var job := -1
	for i in flow.JOBS.size():
		if str(flow.JOBS[i]["title"]) == title():
			job = i
	check(job >= 0, "依頼「%s」がある" % title())
	if job < 0:
		quit(1)
		return
	check((flow.Briefs.brief(job)["lines"] as Array).size() >= 3 and flow.Briefs.BOARDS.has(str(flow.JOBS[job].get("board", ""))), "打ち合わせと絵コンテの文がある")
	check((beats.Scripts.beats(job) as Array).size() == (flow.JOBS[job]["scenes"] as Array).size(), "場面の数が、依頼の場面の名前とそろう")
	flow.day = 2
	await accept(job)
	me.position = flow.HOME_TRUCK + Vector3(-3, 0.1, 0)
	await frames(3)
	game.h_depart()
	await frames(30 if flow.shoots_home() else 490)
	check(flow.phase == 4 and game.state == S.PREP, "現場で準備中（%s）" % ("会社の前" if flow.shoots_home() else str(flow.job()["location"])))
	C = flow.site_center()
	me.global_position = C + Vector3(4.5, 0.1, 7.0)
	place(flow.script_prop, me.global_position + Vector3(0.5, 0.0, 0.0))
	await prepare()
	await frames(30)
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(5)
	check(game.state == S.TAKE, "本番が始まった")
	var list: Array = beats.list()
	for i in list.size():
		if not (i in targets()):
			if i == beats.scene and not beats.lit[i]:
				beats._met(i)
			if i == list.size() - 1:
				break
			await until_holding()
			if (i + 1) in targets():
				await before(i + 1)
			game.h_beat(1)
			await frames(3)
			continue
		# 確かめる場面
		if i == 0:
			pass        # 最初の場面は、本番の始まりから回っている（用意は prepare）
		await during(i)
		for k in 900:
			if beats.lit[i]:
				break
			await physics_frame
		check(beats.lit[i], "場面%d（%s）が撮れる（理由：%s）" % [i + 1, str(list[i]["rule"]), beats._top_reason(i)])
		if OS.get_environment("PARODY_SHOTS") != "" and DisplayServer.get_name() != "headless":
			# 撮れた瞬間の、撮影カメラの画（画面ありで流したときだけ）
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/parody/"))
			game.film.view.get_texture().get_image().save_png("res://tests/shots/parody/%s_%d.png" % [label().to_lower(), i + 1])
		if i == list.size() - 1 or not beats.lit[i]:
			break
		await until_holding()
		if (i + 1) in targets():
			await before(i + 1)
		game.h_beat(1)
		await frames(3)
	print(label(), "_TEST_FAIL" if failed else "_TEST_OK")
	await frames(2)
	quit(1 if failed else 0)


# 依頼を受ける（派生側で、発注などを足すときは上書きする）
func accept(job: int) -> void:
	game.h_accept_job(job)
	await frames(20)
