extends "res://tests/pair_net_base.gd"
# 5場面の台本（場面の列を持つ依頼）の二人通信：
#   依頼を受けると、印②③（番号つき）・カメラのリール・モニターのランプと目盛りが、両方の画面に出る /
#   場面を進められるのは、台本を読める人だけ（決めるのはホスト）。参加者が進めた場面が、両方で同じ /
#   役者の動き・印の場所・撮れた場面のランプ・フィルムの残りが、両方で同じ /
#   「OK！」の知らせは、進めた人（参加者）にだけ出て、台本から離れたホストには出ない /
#   通し稽古の途中から入った人にも、いまの場面と印が届く。
# 会社で受けて、軽トラで現場へ行き、1場面目だけを本番で撮る。
#   godot --headless --path godot res://tests/kaiju5_net_test.tscn -- --kaiju5-net-test-host      （参加者は -client）

# 現場の置き方（1場面目が撮れる置き方。数字は、通信で少しずれても同じに丸まる値）
const CAM_AT := Vector3(0.0, 0.0, 6.0)
const AIM_WALK := Vector3(3.6, 0.9, -0.3)
const CITY_AT := [Vector3(0.3, 0.0, -2.4), Vector3(1.9, 0.0, -2.9), Vector3(3.5, 0.0, -2.0)]
const MARKS := [[Vector3(5.5, 0.05, 0.5), Vector3(1.0, 0.05, 0.5), Vector3(-0.5, 0.05, 1.0)],
	[Vector3(6.5, 0.05, -0.5), Vector3(2.0, 0.05, -0.5), Vector3(1.0, 0.05, 1.0)]]
const SPOT_AT := [Vector3(3.3, 0.0, 9.5), Vector3(-3.2, 0.0, 4.6)]
const SPOT_AIM := [Vector3(3.5, 1.3, 0.0), Vector3(0.1, 1.3, 1.0)]
const BOOK_AT := Vector3(1.0, 0.1, 7.0)
const NEAR_BOOK := Vector3(0.2, 0.1, 7.0)              # 台本のそば（カメラの後ろ）
const FAR := Vector3(-3.0, 0.1, 9.5)                   # 台本から遠い（カメラの後ろ）
const HOST_AT := Vector3(-5.0, 0.1, 9.0)               # ホストの制作班（台本から遠い・画面の外）


func configure() -> void:
	prefix = "KAIJU5_NET"
	port = 24875
	flag = "kaiju5-net-test"
	budget = 130.0


func job_of_beats() -> int:
	var jobs: Array = game.production.JOBS
	for i in jobs.size():
		if not (game.beats.Scripts.beats(i) as Array).is_empty():
			return i
	return -1


func view() -> Dictionary:
	var flow: Node = game.production
	var beats: Node = game.beats
	var monitor: Node = game.camera_switcher.monitor
	var present := 0
	var labels: Array = []
	var marks: Array = []
	var pids: Array = []
	for aid in 2:
		for step in 3:
			var disc: Node3D = beats.mark(aid, step)
			pids.append(disc.pid)
			present += 0 if disc.absent else 1
			labels.append(str(disc.label))
			marks.append([] if disc.absent else [snappedf(disc.global_position.x, 0.25), snappedf(disc.global_position.z, 0.25)])
	var actors: Array = []
	for a: Node3D in game.actors:
		actors.append([snappedf(a.global_position.x, 0.5), snappedf(a.global_position.z, 0.5)])
	var passed: Array = []
	if not (game.takes as Array).is_empty():
		passed = game.takes[0]["passed"]
	return {"phase": flow.phase, "job": flow.chosen_job, "active": beats.active(), "scene": beats.scene, "lit": beats.lit.duplicate(), "rehearsal": beats.rehearsal,
		"pids": pids, "present": present, "labels": labels, "marks": marks, "actors": actors,
		"lamps": (monitor.lamps_shown as Array).duplicate(), "ticks": monitor.ticks_left, "reel": game.film.film_shown, "film": snappedf(game.film.film_frac, 0.02),
		"state": game.state, "passed": passed, "limit": game.take_limit(), "titles": (game.scene_titles() as Array).size(), "mute": game.live.get("mute", false)}


# ホスト：現場に、1場面目が撮れる置き方を作る
func stage(who: int) -> void:
	var beats: Node = game.beats
	place(game.film, CAM_AT)
	var city: Array = []
	for kind: String in ["carton", "applebox"]:
		for prop: Node in of_kind(kind):
			if not prop.absent and city.size() < 3:
				city.append(prop)
	for i in city.size():
		place(city[i], CITY_AT[i])
	for i in 2:
		place(game.spots[i], SPOT_AT[i], PI)
	for aid in 2:
		for step in 3:
			(beats.mark(aid, step) as Node).restore([MARKS[aid][step], Quaternion.IDENTITY, false])
	place(game.production.script_prop, BOOK_AT)
	crew_to(1, HOST_AT)
	crew_to(who, FAR)
	await frames(20)
	for i in 2:
		game._aim_spot(game.spots[i], SPOT_AIM[i])
		game.spots[i].level = 3
	game._aim_camera(AIM_WALK, 56.0)
	await frames(10)


func host_action(action: String, _arg: Variant, who: int) -> Dictionary:
	var flow: Node = game.production
	var beats: Node = game.beats
	var extra := {}
	match action:
		"to_set":
			# 二人とも軽トラのそばへ集まって出発。着いたら、置き方を作る
			crew_to(1, flow.HOME_TRUCK + Vector3(-3, 0.1, 0))
			crew_to(who, flow.HOME_TRUCK + Vector3(-3, 0.1, 1.4))
			await until(func() -> bool: return flow.can_depart(), 8.0)
			game.h_depart()
			await until(func() -> bool: return flow.phase == 4, 25.0)
			await wait(0.6)
			await stage(who)
		"near_book":
			crew_to(who, NEAR_BOOK)
			await until(func() -> bool: return beats.may_direct(who), 6.0)
		"far":
			crew_to(who, FAR)
			await until(func() -> bool: return not beats.may_direct(who), 6.0)
		"arrive":
			# 役者が印②に着くまで
			await until(func() -> bool: return game.actors[0].beat_arrived() and game.actors[1].beat_arrived(), 8.0)
		"take":
			game.h_take()
			await until(func() -> bool: return game.state == game.S.TAKE, 8.0)
		"scene1":
			await until(func() -> bool: return beats.lit.size() == 5 and bool(beats.lit[0]), 10.0)
			await frames(6)
			extra["host_toast"] = str(game.hud.toast_label.text)
			extra["host_directs"] = game.directs()
		"cut":
			game.h_take()
			await until(func() -> bool: return game.state == game.S.RESULT, 6.0)
	# ホスト自身の見た目は次のフレームで変わるので、落ち着くまで待ってから見せる
	await frames(3)
	return extra


func client_run() -> void:
	var flow: Node = game.production
	var beats: Node = game.beats
	var job := job_of_beats()

	# ---- 依頼を受ける前：今までどおり、印は2つ ----
	var reply: Dictionary = await request("hello")
	check(job >= 0 and reply["view"]["pids"] == view()["pids"], "both peers number the six marks the same way")
	check(not reply["view"]["active"] and reply["view"]["present"] == 2 and not view()["active"] and view()["present"] == 2 and not view()["reel"] and (view()["lamps"] as Array).is_empty(),
		"before the job only the two usual marks are out, on both peers")

	# ---- 参加者が、5場面の依頼を受ける ----
	flow.day = 2
	game.h_accept_job.rpc_id(1, job)
	check(await until(func() -> bool: return flow.phase == 2 and beats.active()), "the five-scene job starts on both peers")
	reply = await request("snapshot")
	var taken: Dictionary = reply["view"]
	check(taken["active"] and taken["present"] == 6 and taken["titles"] == 5 and taken["limit"] == beats.FILM_SEC and "立ち位置の印 B③" in taken["labels"], "the host has six numbered marks and a five-scene, one-roll take")
	await sees(taken, ["job", "active", "present", "labels", "marks", "titles", "limit", "scene", "lit"], "the participant sees the same six marks, in the same places")

	# ---- 軽トラで現場へ。置き方は、ホストが作る ----
	reply = await request("to_set")
	check(await until(func() -> bool: return flow.phase == 4, 20.0), "both arrive at the location")
	reply = await request("snapshot")
	var on_set: Dictionary = reply["view"]
	check(on_set["phase"] == 4 and on_set["reel"] and on_set["lamps"] == [false, false, false, false, false] and on_set["ticks"] == 18 and on_set["mute"], "on the set the host shows the reel, five dark lamps and a full row of ticks")
	await sees(on_set, ["phase", "marks", "reel", "lamps", "ticks", "scene", "mute"], "the participant sees the marks where the host put them, and the same reel, lamps and ticks", LATE)

	# ---- 台本を読めない人は、場面を進められない ----
	game.h_beat.rpc_id(1, 1)
	reply = await request("snapshot")
	check(reply["view"]["scene"] == -1 and not game.directs() and "台本を読める人だけ" in str(game.hud.toast_label.text), "away from the script, the participant cannot turn the page (and is told why)")
	reply = await request("near_book")
	check(await until(func() -> bool: return game.directs()), "next to the script lying on the floor, the participant may direct")

	# ---- 通し稽古：参加者が進めた場面が、両方で同じ。役者も同じ所へ歩く ----
	game.h_beat.rpc_id(1, 1)
	reply = await request("arrive")
	var rehearsed: Dictionary = reply["view"]
	check(rehearsed["scene"] == 0 and rehearsed["rehearsal"] and rehearsed["actors"] == [[1.0, 0.5], [2.0, -0.5]] and rehearsed["ticks"] == 18 and rehearsed["lamps"] == [false, false, false, false, false],
		"the host plays scene 1 as a rehearsal: the actors walk to mark 2, no film is used, no lamp lights")
	await sees(rehearsed, ["scene", "rehearsal", "actors", "lit", "lamps", "ticks"], "the participant sees the same scene and the actors at the same marks")

	# ---- 途中参加：通し稽古の途中から入った人にも、いまの場面と印が届く ----
	await rejoin()
	flow = game.production
	beats = game.beats
	reply = await request("hello")
	check(reply["view"]["pids"] == view()["pids"], "the late joiner numbers the marks the same way")
	await sees(rehearsed, ["phase", "job", "active", "present", "labels", "marks", "scene", "rehearsal", "actors", "reel", "lamps", "ticks", "titles", "limit"],
		"a late joiner receives the job, the six marks, the current scene and the actors' places", LATE)

	# B で役者を戻す（誰でもできる）
	game.h_standby.rpc_id(1)
	reply = await request("snapshot")
	check(reply["view"]["scene"] == -1 and not reply["view"]["rehearsal"], "B ends the rehearsal on the host")
	await sees(reply["view"], ["scene", "rehearsal"], "and on the participant")

	# ---- 本番：1場面目を撮る。ランプとフィルムが、両方で同じ ----
	reply = await request("near_book")
	reply = await request("take")
	check(await until(func() -> bool: return game.state == game.S.TAKE), "the take starts on both peers")
	await frames(4)
	check(not game.hud.take_row.visible and not game.production_hud._clock.visible, "the participant's screen shows no seconds during this take")
	game.h_beat.rpc_id(1, 1)
	reply = await request("scene1")
	var shot: Dictionary = reply["view"]
	check(shot["scene"] == 0 and not shot["rehearsal"] and shot["lit"] == [true, false, false, false, false] and shot["lamps"] == [true, false, false, false, false], "scene 1 is taken on the host: its lamp lights")
	check(not reply.get("host_directs", true) and "OK！" not in str(reply.get("host_toast", "")), "the host's crew member, away from the script, gets no 'OK!' notice")
	check(await until(func() -> bool: return "OK！" in str(game.hud.toast_label.text)), "the participant, who directs, is told that the scene is in the can")
	await sees(shot, ["scene", "rehearsal", "lit", "lamps"], "the participant's monitor lights the same lamp")
	check(shot["ticks"] < 18 or shot["film"] < 1.0, "film is running on the host (%s ticks, %.2f left)" % [str(shot["ticks"]), float(shot["film"])])
	await sees(shot, ["ticks"], "the participant's film ticks match the host's")

	# カット：テイクの長さ（使ったフィルム）と、撮れた場面が、両方で同じ
	reply = await request("cut")
	var result: Dictionary = reply["view"]
	check(result["state"] == game.S.RESULT and result["passed"] == [true, false, false, false, false] and result["lamps"] == [true, false, false, false, false] and result["scene"] == -1, "after the cut the host shows what the take got")
	await sees(result, ["state", "passed", "lamps", "ticks", "film", "scene"], "the participant sees the same result, lamps and used film")
