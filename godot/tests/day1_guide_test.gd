extends SceneTree
# 1日目の講師の案内（features/day1_guide.gd）：箱を開けて、あいさつが済んだあと、講師がやる事を1つずつ教える。
#   ・箱を開ける前・あいさつの途中は、出ない
#   ・掲示板 → 段ボールの台 → カメラ → 城 → 爆炎の書割 → 台本 → 役に入る → カチンコ、の順に番が進む
#   ・講師は、目当てのそばへ先に行って立つ。目当てには、青い輪と矢印が出る。画面の下の案内の先頭に、いまやる事が出る
#   ・先に済ませた事は、飛ばす。一度済んだ事は、あとで物を動かしても戻らない
#   ・本番が始まると、場面ごとにひとこと。止めると（場転）、次の用意を言う。撮れない理由は、ホストから全員へ
#   godot --headless --path godot --fixed-fps 60 --script res://tests/day1_guide_test.gd
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("GUIDE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3, yaw: float = 0.0, fixed: bool = false) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	prop.restore([pos, Quaternion(Vector3.UP, yaw), fixed])


func of_kind(kind: String) -> Array:
	return game.props.values().filter(func(p: Node) -> bool: return p.kind == kind and not p.absent)


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.startup_complete:
		await process_frame
	await frames(20)
	var flow: Node = game.production
	var box: Node = game.hooks.feature("delivery_box")
	var guide: Node = game.hooks.feature("day1_guide")
	var guides: Node = game.hooks.feature("holo_guides")
	var stand: Node = game.hooks.feature("stand_ins")
	var beats: Node = game.beats
	var S: Dictionary = game.S
	var me: Node3D = game.local_player()
	check(guide != null and not guide.on and not guide.teacher.visible, "自動確認の中では、案内の講師は出ない")
	# ---- 1日目：箱を開けて、あいさつが済むまでは出ない ----
	guide.force = true
	guides.force = true
	flow.daily = true
	flow.levels["camera"] = 0
	game.hooks.feature("camera_kit").apply()
	box.start()
	await frames(5)
	check(not guide.on, "箱を開ける前は、まだ出ない")
	box.host_open()
	await frames(40)
	check(not guide.on and box.talking(), "講師が箱の上であいさつしている間は、まだ出ない")
	me.global_position = box.box.global_position + Vector3(0, 0.1, 1.6)
	await frames(100)
	for i in box.LINES.size():
		box.hook_f(me)
	await frames(70)
	check(not box.talking() and guide.on and guide.teacher.visible, "あいさつが済むと、案内の講師に替わる")
	# ---- 掲示板 ----
	check(guide.step == "board" and str(guide.said).contains("掲示板"), "まず、掲示板で依頼を受けろと言う（%s）" % str(guide.said).replace("\n", " "))
	await frames(120)
	check(guide.marker.visible and flat(guide.marker.global_position, flow.Office.CONTRACT_POINT) < 0.1, "掲示板の前に、青い輪と矢印が出る")
	check(flat(guide.teacher.global_position, flow.Office.CONTRACT_POINT) < 2.5, "講師は、掲示板のそばへ先に行って立つ（%.1f m）" % flat(guide.teacher.global_position, flow.Office.CONTRACT_POINT))
	var keys: String = str(guide.hook_hud(me, "", "事務所の掲示板で、今日の依頼を選ぼう\nTab あそびかた").get("keys_all", ""))
	check(keys.begins_with("掲示板で、自分の会社の依頼を受けよう") and not keys.contains("今日の依頼を選ぼう") and keys.contains("Tab あそびかた"), "画面の下の案内の先頭に、いまやる事が出る（%s）" % keys.replace("\n", " | "))
	keys = str(guide.hook_hud(me, "", "F 依頼を見る\nTab あそびかた").get("keys_all", ""))
	check(keys.contains("F 依頼を見る"), "操作の案内（F 依頼を見る）は、消さない（%s）" % keys.replace("\n", " | "))
	# せりふは、しばらくすると消えて、進まなければ、もう一度言う
	await frames(int(guide.LINE_SEC * 60.0))
	check(str(guide.said) == "", "せりふは、%.1f 秒で消える" % guide.LINE_SEC)
	guide._same_t = guide.AGAIN_SEC - 0.2
	await frames(30)
	check(str(guide.said).contains("掲示板"), "進まないままだと、同じ事をもう一度言う")
	# ---- 依頼を受ける（会社の前で撮る依頼は、受けるとすぐ撮影の準備に入る）----
	game.h_accept_job(flow.debut_job())
	await frames(30)
	var O: Vector3 = flow.site_center()
	# ---- 段ボールの台 → カメラ → 城 → 書割 → 台本 → 役 → カチンコ ----
	check(flow.phase == 4 and guide.step == "boxes", "依頼を受けると、まず段ボールの台（%s）" % guide.step)
	var boxes: Array = of_kind("applebox")
	check(boxes.any(func(b: Node) -> bool: return flat(guide.target(), b.global_position) < 0.1), "目当ては、まだ影の所に無い段ボール")
	keys = str(guide.hook_hud(me, "", "左クリック 持つ ／ 事務所の前の物を、舞台の青い影に合わせて置こう（あと 5）").get("keys_all", ""))
	check(keys.begins_with("段ボールを2つ") and not keys.contains("合わせて置こう") and keys.contains("左クリック 持つ"), "もとの「青い影に合わせて置こう」は、いまやる事の札に替わる（%s）" % keys)
	# 先に城を置いても、番は段ボールのまま。城は、済みとして数える
	var board: Node = of_kind("flat")[0]
	place(board, O + guides.CASTLE_AT)
	await frames(40)
	check(guide.step == "boxes", "先に城を置いても、いまの番は段ボールの台のまま")
	var spot: Vector3 = O + guides.CAM_AT
	var top := 0.0
	for k in 2:
		place(boxes[k], spot + Vector3(0, 0.05 + top, 0))
		top += float(boxes[k].half.y) * 2.0
		await frames(25)
	await frames(30)
	check(guide.step == "camera" and str(guide.said).contains("カメラ"), "段ボールを2つ積むと、次はカメラ（%s）" % guide.step)
	check(flat(guide.target(), game.film.global_position) < 0.1, "目当ては、カメラ（まだ手に持っていない）")
	place(game.film, spot + Vector3(0, top + 0.1, 0))
	await frames(60)
	check(guide.step == "blast", "カメラを載せると、城は済んでいるので飛ばして、爆炎の書割（%s）" % guide.step)
	# 一度済んだ事は、あとで物を動かしても戻らない
	place(board, O + Vector3(6.0, 0.0, 6.0))
	await frames(30)
	check(guide.step == "blast", "済んだ城を動かしても、番は戻らない")
	var boom: Node = of_kind("boomflat")[0]
	place(boom, O + guides.FLAT_AT)
	await frames(60)
	check(guide.step == "script" and str(guide.said).contains("台本"), "書割を立てると、次は台本（%s）" % guide.step)
	var book: Node3D = flow.script_prop
	check(flat(guide.target(), book.global_position) < 0.1, "目当ては、事務所の机の上の台本")
	place(book, O + Vector3(3.0, 0.0, 6.0))
	me.global_position = O + Vector3(3.4, 0.1, 6.4)
	await frames(40)
	check(guide.step == "role" and str(guide.said).contains("Y"), "台本を撮る場所のそばに置くと、次は役に入る（%s）" % guide.step)
	check(not guide.marker.visible, "役に入る番は、目当ての物が無い（輪と矢印は出ない）")
	stand.h_cast_actor("player", int(me.peer_id), 0)
	await frames(20)
	check(guide.step == "take" and str(guide.said).contains("カチンコ"), "社長の役に入ると、次はカチンコ（%s）" % guide.step)
	check(flat(guide.target(), game.clapper.global_position) < 0.1 and guide.marker.visible, "目当ては、カチンコ")
	keys = str(guide.hook_hud(me, "", "\nカチンコを持って F で本番開始 ／ 1・2・3 合図のリハーサル ／ Tab あそびかた").get("keys_all", ""))
	check(keys.begins_with("カチンコを持って F で本番"), "案内の先頭も、カチンコ（%s）" % keys.replace("\n", " | "))
	# ---- 本番：場面ごとにひとこと・場転・撮れない理由 ----
	game.h_standby()
	await frames(30)
	game.h_take()
	for i in 400:
		if game.state == S.TAKE:
			break
		await physics_frame
	await frames(10)
	check(game.state == S.TAKE and guide.step == "scene0" and str(guide.said).contains("社員紹介"), "本番が回ると、1カット目のひとこと（%s）" % guide.step)
	check(guide.hook_hud(me, "", "1・2・3 合図").is_empty(), "本番中は、画面の下の案内には足さない")
	game.host_ev("guide_say", ["寄りが足りない"])
	await frames(5)
	check(str(guide.said).contains("寄りが足りない"), "撮れない理由は、ホストから全員へ届いて、講師が言う（%s）" % str(guide.said).replace("\n", " "))
	game.h_beat(1)
	for i in 240:
		if beats.holding:
			break
		await physics_frame
	await frames(10)
	check(beats.holding and str(guide.step).begins_with("hold") and str(guide.said).contains("カット"), "止めると（場転）、次の用意を言う（%s）" % guide.step)
	# ---- 2日目からは出ない ----
	flow.day = 2
	await frames(90)
	check(not guide.on and not guide.teacher.visible and not guide.marker.visible, "2日目からは、案内の講師は出ない")
	print("GUIDE_TEST_FAIL" if failed else "GUIDE_TEST_OK")
	root.get_node("Sfx").silence_all()
	await frames(4)
	quit(1 if failed else 0)
