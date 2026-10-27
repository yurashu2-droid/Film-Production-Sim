extends SceneTree
var failed := false
var game: Node

func check(ok: bool, label: String) -> void:
	print("CREW_SKILLS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): quit(2))
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(8)
	check(game.get("crew_skills") != null, "production game connects crew progression")
	if game.get("crew_skills") == null:
		quit(1)
		return
	var skills: Node = game.crew_skills
	check(skills.profile.path.is_empty(), "automated run never writes normal player save")
	check(skills.level(1, "actor") == 1, "new host registered at Lv1")
	skills.choose_run_style("volt")
	check(skills.run_style(1) != "volt", "locked VFX rejected by host")
	game.production.phase = 4
	skills.begin_job()
	game.h_operate(game.film.pid, true)
	skills.camera_memo(0, false)
	check(skills.camera_memos[0].is_empty(), "locked camera memo rejected")
	game.h_operate(game.film.pid, false)
	game.performance.accept_act(1, "skill_double_flinch")
	check(not game.local_player().performance_active(), "locked reaction rejected")
	var carton: Node
	for prop: Node in game.props.values():
		if prop.kind == "carton" and carton == null: carton = prop
		if prop != game.film and prop != game.clapper and prop != game.truck and prop.kind not in ["spot", "mark"]:
			prop.set_absent(true)
	carton.set_absent(false)
	# 1日目の朝は軽トラが離れた所（TRUCK_AWAY）に停まっている（5dbba2b）。依頼を受けずに搬入を試すので、いつもの所へ戻す
	game.production._move(game.truck, game.production.HOME_TRUCK, 0.0)
	game.production.phase = 2
	game.local_player().global_position = game.production.HOME_TRUCK + Vector3(-3, 0.1, 0)
	game.h_grab(carton.pid)
	game.h_load_truck(carton.pid)
	check(carton.rider_of == game.truck.pid, "real loading action carries cardboard")
	game.host_unload(carton)
	# 積み込みの置き直し（restore）は次の物理フレームで反映される。先に済ませないと、あとで動かした位置が荷台へ戻される
	await frames(1)
	game.production.phase = 4
	game.local_player().global_position = Vector3(0, 0.1, 0)
	game.host_unload(game.film)
	game.film.restore([Vector3(0, 0, 6), Quaternion.IDENTITY, false])
	game.film.set_absent(false)
	game._aim_camera(Vector3(0, 1.0, 0), 65.0)
	game.h_operate(game.film.pid, true)
	game.h_aim(game.film.pid, 0.002, 0.0, 0.0)
	game.h_operate(game.film.pid, false)
	for i in game.actors.size():
		var at := Vector3(-1.5 + i * 3.0, 0.1, -1.5)
		game.actors[i].mark.restore([at, Quaternion.IDENTITY, false])
		game.actors[i].global_position = at
	var spot: Node = game.spots[0]
	game.host_unload(spot)
	spot.restore([Vector3(-3, 0, 2), Quaternion.IDENTITY, false])
	spot.set_absent(false)
	game._aim_spot(spot, Vector3(0, 1, 0))
	game.h_operate(spot.pid, true)
	game.h_aim(spot.pid, 0.002, 0.0, 0.0)
	game.h_operate(spot.pid, false)
	game.h_grab(carton.pid)
	carton.global_position = Vector3(2.4, 0.05, -2)
	game.h_release()
	await frames(4)
	check(skills.records.is_empty(), "preparation only becomes XP when filmed")
	game.h_take()
	game.countdown_t = 0.01
	await frames(5)
	check(game.state == game.S.TAKE and skills.visible_point(game.local_player().global_position + Vector3.UP), "real take sees performer")
	game.h_perform("face:happy")
	await frames(38)
	game.h_operate(game.film.pid, true)
	game.h_aim(game.film.pid, 0.002, 0.0, 0.0)
	await frames(14)
	game.h_operate(game.film.pid, false)
	game.local_player().aim_yaw = 0.0
	Input.action_press("move_right")
	Input.action_press("run")
	await frames(62)
	Input.action_release("move_right")
	Input.action_release("run")
	game.performance.accept_fx(1, "aura", Vector3.ZERO, Vector3.ZERO)
	await frames(3)
	game._cut()
	check(skills.profile.xp.actor == 0 and not skills.preview.is_empty(), "cut displays pending growth without saving XP")
	check(skills.preview.actor.gained == 70, "filmed acting, movement, and ensemble are credited")
	check(skills.preview.camera.gained >= 50, "framing before take and camera operation are credited")
	check(skills.preview.backstage.gained == 70, "filmed cargo, setup, and effects are credited")
	var pending: Dictionary = skills.records.duplicate(true)
	game.h_replay(0)
	await frames(16)
	game.h_stop_replay()
	check(skills.records == pending, "replay cannot grant contribution")
	game.h_deliver(0)
	var earned: Dictionary = skills.profile.xp.duplicate()
	check(game.production.phase == 5 and skills.job_closed and skills.profile.level("actor") == 2, "failed film delivers, saves growth, and unlocks Lv2")
	check(skills.growth_text().contains("解放！") and not skills.last_report.is_empty(), "settlement explains level and unlocks")
	game.h_deliver(0)
	check(skills.profile.xp == earned, "duplicate delivery has no growth")
	game.production.phase = 4
	game.state = game.S.PREP
	skills.begin_job()
	# 次の一本を撮る前から、解放済みの道具を操作できる。
	skills.choose_run_style("volt")
	check(skills.run_style(1) == "volt" and game.dash_dust_style == "volt", "unlocked running VFX applies to owner")
	game.h_operate(game.film.pid, true)
	var original := Vector3(game.film.cam_yaw, game.film.cam_pitch, game.film.fov)
	skills.camera_memo(0, false)
	game.h_aim(game.film.pid, 0.2, 0.1, 1.0)
	skills.camera_memo(0, true)
	check(Vector3(game.film.cam_yaw, game.film.cam_pitch, game.film.fov).is_equal_approx(original), "Lv2 memo restores direction and zoom")
	game.h_operate(game.film.pid, false)
	game.h_grab(carton.pid)
	skills.craft("window")
	check(carton.has_node("CrewArtwork") and "city" in carton.tags and carton.kind == "carton", "Lv2 decorates original cardboard into a city prop")
	game.h_release()
	game.performance._last_act.clear()
	game.h_perform("skill_double_flinch")
	check(game.local_player().performance_active() and game.local_player().vis.has("skill_double_flinch"), "Lv2 reaction uses existing actor clips")
	game.local_player().cancel_performance()
	game._begin_take()
	game.h_dash_dust(-1)
	check(game._rec_events.any(func(e: Array) -> bool: return e[1] == "dash_dust" and e[2][3] == "volt" and e[2][4] == 1), "recording stores chosen VFX and actual owner")
	check(game._rec_events.any(func(e: Array) -> bool: return e[1] == "crew_crafts" and e[2][0].get(carton.pid) == "window"), "recording keeps cardboard appearance")
	await frames(5)
	game._cut()
	game.state = game.S.PREP
	game.h_grab(carton.pid)
	skills.craft("shield")
	game.h_release()
	game.state = game.S.RESULT
	game.h_replay(1)
	await frames(6)
	check(skills.crafts.get(carton.pid) == "window", "replay restores filmed artwork")
	game.h_stop_replay()
	check(skills.crafts.get(carton.pid) == "shield", "leaving replay restores current artwork")
	for tag: String in game.PLAYER_CASTS:
		game.local_player().set_cast(tag)
		game.performance.refresh_actions()
		check("skill_double_flinch" in game.performance.actions and "skill_slow_flinch" in game.performance.actions, tag + " keeps learned reactions after appearance change")
	if not failed: print("CREW_SKILLS_TEST_OK")
	game.queue_free()
	await frames(2)
	quit(1 if failed else 0)
