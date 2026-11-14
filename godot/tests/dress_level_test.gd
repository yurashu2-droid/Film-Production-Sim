extends SceneTree
# 見立ての飾りの段（cast_dress.gd の level：1 立て札 / 2 ひと手間 / 3 本気）を確かめる。
#   段 = もとのらしさ（ショール抜き 0..2）+ 1、役を付けた人が裏方 Lv3 以上なら +1、ショールがかかっていれば +1（1〜3）
#   表（production_cast.gd の dress_level）→ ゲームの中で：料理番組の「料理」の役を、合わない物・合う物に付ける。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/dress_level_test.gd
const Cast := preload("res://scripts/production_cast.gd")
const Profile := preload("res://scripts/crew_profile.gd")
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("DRESS_LEVEL_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func place(prop: Node, pos: Vector3) -> void:
	if prop.rider_of != 0:
		game.host_unload(prop)
	var state: Array = prop.get_state()
	state[0] = pos
	state[1] = Quaternion.IDENTITY
	state[2] = true
	prop.restore(state)


func dress_of(prop: Node) -> Node:
	var d: Variant = game._cast_dress.get(prop.pid)
	return d if d != null and is_instance_valid(d) else null


func run() -> void:
	# ---- 表 ----
	var table := {
		[0, false, false]: 1, [0, true, false]: 2, [0, false, true]: 2, [0, true, true]: 3,
		[1, false, false]: 2, [1, true, false]: 3, [1, false, true]: 3, [1, true, true]: 3,
		[2, false, false]: 3, [2, true, false]: 3, [2, false, true]: 3, [2, true, true]: 3,
	}
	for key: Array in table:
		var got := Cast.dress_level(int(key[0]), bool(key[1]), bool(key[2]))
		check(got == int(table[key]), "fit %d crafty %s shawl %s -> level %d (got %d)" % [key[0], key[1], key[2], table[key], got])
	check(Cast.plain_fit("scrap_toilet", "monster", ["shawl"]) == 0 and Cast.fit("scrap_toilet", "monster", ["shawl"]) == 1, "plain fit ignores the shawl")
	check(Profile.level_for(179) == 2 and Profile.level_for(180) == Cast.CRAFT_LEVEL, "backstage Lv3 starts at 180 xp")

	# ---- ゲームの中で ----
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var flow: Node = game.production
	var job_index := -1
	for i in flow.JOBS.size():
		if flow.JOBS[i]["script"] == "cooking" and job_index < 0:
			job_index = i
	game.h_accept_job(job_index)
	check(flow.story() == "cooking", "took the cooking show job")
	var me_id: int = root.get_node("Net").my_id()
	game.crew_skills.profiles = {me_id: {"actor": 0, "camera": 0, "backstage": 0}}
	# 「料理」に合わない物（0）と、合う物（1 以上）を、世界にある物から選ぶ
	var poor: Node = null
	var good: Node = null
	for pid: int in game.props:
		var p: Node = game.props[pid]
		if p.absent or p.collision_layer == 0 or p.stored_in != 0 or p.holder != 0 or not Cast.castable(p.kind) or Cast.locked(p.kind) or Cast.default_role(p.kind) != "":
			continue
		var pf := Cast.plain_fit(p.kind, "dish", flow.cast_tags(p))
		if pf == 0 and poor == null:
			poor = p
		elif pf >= 1 and (good == null or pf > Cast.plain_fit(good.kind, "dish", flow.cast_tags(good))):
			good = p
	check(poor != null and good != null, "found a poor-fit and a good-fit prop for the dish (%s / %s)" % [poor.kind if poor else "-", good.kind if good else "-"])
	if poor == null or good == null:
		_finish()
		return
	var good_fit := Cast.plain_fit(good.kind, "dish", flow.cast_tags(good))
	place(poor, flow.HOME_TRUCK + Vector3(-3, 0.4, 1.4))
	place(good, flow.HOME_TRUCK + Vector3(-6, 0.4, 1.4))
	await frames(4)
	check(flow.cast_set(poor.pid, "dish", 0, me_id) and flow.cast_set(good.pid, "dish", 0, me_id), "cast both as the dish")
	check(int(flow.cast_by.get(poor.pid, 0)) == me_id and (flow.snapshot()["cast_by"] as Dictionary).has(poor.pid), "the host remembers who cast it, and it travels in the snapshot")
	await frames(3)
	var d: Node = dress_of(poor)
	check(d != null and d.level == 1, "a poor fit by a green crew gets just a sign (level %d)" % (d.level if d else -1))
	d = dress_of(good)
	check(d != null and d.level == good_fit + 1, "a good fit gets a better dress (fit %d -> level %d)" % [good_fit, d.level if d else -1])

	# ショール（ドレスの人の特技）で +1
	game.host_ev("shawl", [poor.pid, me_id, 0.0, Vector2.ZERO, 0, null])
	await frames(3)
	d = dress_of(poor)
	check(game.talent.shawled(poor.pid) and d != null and d.level == 2, "a shawl lifts the poor fit one step (level %d)" % (d.level if d else -1))
	game.talent.host_shawl_off(poor.pid)
	await frames(3)
	d = dress_of(poor)
	check(not game.talent.shawled(poor.pid) and d != null and d.level == 1, "taking the shawl off drops it back (level %d)" % (d.level if d else -1))

	# 裏方 Lv3 の人が付けた物は +1
	game.crew_skills.profiles = {me_id: {"actor": 0, "camera": 0, "backstage": Profile.THRESHOLDS[2]}}
	await frames(3)
	d = dress_of(poor)
	check(game.crew_skills.level(me_id, "backstage") >= 3 and d != null and d.level == 2, "a crafty caster (backstage Lv3) lifts it one step (level %d)" % (d.level if d else -1))
	game.host_ev("shawl", [poor.pid, me_id, 0.0, Vector2.ZERO, 0, null])
	await frames(3)
	d = dress_of(poor)
	check(d != null and d.level == 3, "craft and shawl together make it all-out (level %d)" % (d.level if d else -1))
	# 役を付けた人が分からない（by 無し）なら、腕は効かない
	flow.cast_by.erase(poor.pid)
	game.talent.host_shawl_off(poor.pid)
	await frames(3)
	d = dress_of(poor)
	check(d != null and d.level == 1, "without a known caster the craft does not count (level %d)" % (d.level if d else -1))
	# 役を外す（その物の、もとの役に戻す）と、覚えた人も消える
	flow.cast_set(poor.pid, "dish", 0, me_id)
	check(int(flow.cast_by.get(poor.pid, 0)) == me_id, "casting again remembers the caster")
	flow.cast_set(poor.pid, Cast.default_role(poor.kind), -1, me_id)
	check(not flow.cast_by.has(poor.pid) and not flow.casting.has(poor.pid), "back to its own role forgets the caster")
	_finish()


func _finish() -> void:
	print("DRESS_LEVEL_TEST_OK" if not failed else "DRESS_LEVEL_TEST_FAIL")
	quit(1 if failed else 0)
