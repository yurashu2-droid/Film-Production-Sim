extends SceneTree
# 仕組みの登録（scripts/feature_hooks.gd）の確認。中心のファイルや仕組みを直したら、この1本を流す：
#   bash tools/run_some.sh feature_hooks_test
#   （godot --headless --path godot --fixed-fps 60 --script res://tests/feature_hooks_test.gd）
# 見る所：
#   1. 土台そのもの（作り物の仕組みで）：順番どおりに呼ぶ・最初に使った仕組みで止まる・合図は持ち主にだけ渡る・
#      食い違い（合図の重なり・関数の名前の書きまちがい・見返しに載せる合図のずれ・順番の表のまちがい）を見つける・
#      置き場に置いたスクリプトを、作って登録する
#   2. 本物のゲーム：決めた仕組みが全部登録されている・食い違いが無い・F などの順番が決めたとおり・
#      合図の持ち主と、見返しに載せる合図が決めたとおり・中心のファイルに、仕組みの合図の分岐が残っていない
const Hooks := preload("res://scripts/feature_hooks.gd")
var failed := false


# 作り物の仕組み
class Fake extends RefCounted:
	var tag := ""
	var seen: Array = []
	var takes := false
	var events: Array = []
	var rec: Array = []

	func hook_events() -> Array:
		return events

	func hook_event(n: String, _a: Array) -> void:
		seen.append("%s got %s" % [tag, n])

	func hook_rec_events() -> Array:
		return rec

	func hook_f(_me: Node) -> bool:
		seen.append(tag)
		return takes

	func hook_sync(who: int) -> void:
		seen.append("%s sync %d" % [tag, who])

	func hook_grab_block(_prop: Node) -> String:
		return "held by %s" % tag if takes else ""


# 関数の名前を書きまちがえた仕組み
class Typo extends RefCounted:
	func hook_evnts() -> Array:
		return []


# hook_events だけあって、hook_event が無い仕組み
class Half extends RefCounted:
	func hook_events() -> Array:
		return ["half"]


func _initialize() -> void:
	create_timer(80).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("FEATURE_HOOKS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func fake(tag: String, log: Array, events: Array = [], rec: Array = [], takes: bool = false) -> Fake:
	var made := Fake.new()
	made.tag = tag
	made.seen = log
	made.events = events
	made.rec = rec
	made.takes = takes
	return made


func has_line(lines: Array, part: String) -> bool:
	for line: String in lines:
		if part in line:
			return true
	return false


func run() -> void:
	# ---- 1. 土台そのもの ----
	var log: Array = []
	var hooks := Hooks.new()
	# 登録の順は、わざと逆。F は ORDERS["hook_f"] の順（director → cargo_kit）、表に無い物（zzz）は、そのあと
	hooks.add("zzz", fake("zzz", log))
	hooks.add("cargo_kit", fake("cargo_kit", log, ["kit"]))
	hooks.add("director", fake("director", log, ["desk"], ["desk"]))
	check(hooks.order_names("hook_f") == ["director", "cargo_kit", "zzz"], "F is asked in the listed order, unlisted features last (got %s)" % str(hooks.order_names("hook_f")))
	check(not hooks.first("hook_f", [null]) and log == ["director", "cargo_kit", "zzz"], "when nobody takes F, every feature is asked once, in order")
	log.clear()
	(hooks.feature("cargo_kit") as Fake).takes = true
	check(hooks.first("hook_f", [null]) and log == ["director", "cargo_kit"], "the first feature that takes F stops the rest")
	check(hooks.first_text("hook_grab_block", [null]) == "held by cargo_kit", "the first non-empty reason is returned")
	log.clear()
	hooks.run("hook_sync", [7])
	check(log == ["cargo_kit sync 7", "director sync 7", "zzz sync 7"], "other hooks run in the common order (got %s)" % str(log))
	log.clear()
	check(hooks.event("kit", [1]) and log == ["cargo_kit got kit"], "an event goes to its owner only")
	check(not hooks.event("state", [0]) and log.size() == 1, "an event nobody owns is left to the core")
	check(hooks.owner_of("desk") == "director" and hooks.owner_of("state") == "", "the owner of an event can be asked")
	check(hooks.records("desk") and not hooks.records("kit"), "only the listed events are recorded for the replay")

	# 食い違いを見つける（表に名前のある仕組みは、その関数を持っていないと食い違いになるので、ここでは表に無い名前を使う）
	var clean := Hooks.new()
	clean.add("one", fake("one", log, ["a", "b"], ["a"]))
	clean.add("two", fake("two", log, ["c"]))
	check(clean.problems(["sfx"]).is_empty(), "a clean registration has no problems (got %s)" % str(clean.problems(["sfx"])))
	var clash := Hooks.new()
	clash.add("one", fake("one", log, ["a"]))
	clash.add("two", fake("two", log, ["a"]))
	check(has_line(clash.problems(), "合図「a」が重なっている"), "two features claiming one event is reported")
	var twice := Hooks.new()
	twice.add("one", fake("one", log))
	twice.add("one", fake("one", log))
	check(has_line(twice.problems(), "同じ名前で2回"), "registering one name twice is reported")
	var typo := Hooks.new()
	typo.add("one", Typo.new())
	check(has_line(typo.problems(), "hook_evnts"), "a misspelt hook name is reported")
	var half := Hooks.new()
	half.add("one", Half.new())
	check(has_line(half.problems(), "両方そろえる"), "hook_events without hook_event is reported")
	var stray := Hooks.new()
	stray.add("one", fake("one", log, ["a"], ["zz"]))
	check(has_line(stray.problems(), "自分の合図（hook_events）に無い"), "a recorded event that is not the feature's own is reported")
	var doubled := Hooks.new()
	doubled.add("one", fake("one", log, ["a"], ["a"]))
	check(has_line(doubled.problems(["a"]), "REC_EVENTS）にもある"), "a recorded event also listed by the core is reported")
	var missing := Hooks.new()
	missing.add("one", fake("one", log, ["a"]))
	check(has_line(missing.problems(["a"]), "hook_rec_events() に無い"), "an owned event recorded only by the core is reported")
	var listed := Hooks.new()
	listed.add("rope_grab", Half.new())
	check(has_line(listed.problems(), "hook_hud() を持っていない"), "a feature named in an order list without that hook is reported")

	# 置き場に置いたスクリプトを、作って登録する
	var dir := "user://feature_hooks_test"
	DirAccess.make_dir_recursive_absolute(dir)
	for file: String in ["b_second.gd", "a_first.gd"]:
		var out := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
		out.store_string("extends Node\nvar game: Node\nvar set_up := false\n\nfunc setup() -> void:\n\tset_up = game != null\n\nfunc hook_events() -> Array:\n\treturn [\"%s\"]\n\nfunc hook_event(_n: String, _a: Array) -> void:\n\tpass\n" % file.get_basename())
		out.close()
	var stub := Node.new()
	root.add_child(stub)
	var found := Hooks.new()
	found.spawn_folder(stub, dir)
	var first: Node = found.feature("a_first") as Node
	check(found.names() == ["a_first", "b_second"] and first != null and first.get_parent() == stub and first.game == stub and first.set_up, "scripts in the folder are created in name order, given the game, set up and registered")
	check(found.owner_of("b_second") == "b_second" and found.problems().is_empty(), "their events are registered")
	check(Hooks.scripts_in("user://feature_hooks_test_missing").is_empty(), "a missing folder means no extra features")
	stub.queue_free()
	for file: String in ["b_second.gd", "a_first.gd"]:
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	for path: String in Hooks.scripts_in(Hooks.FOLDER):
		check(load(path) != null, "%s loads" % path)

	# ---- 2. 本物のゲーム ----
	var game: Node = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var real: Hooks = game.hooks
	var wanted: Array = Hooks.ORDER.duplicate()
	for path: String in Hooks.scripts_in(Hooks.FOLDER):
		wanted.append(path.get_file().get_basename())
	for name: String in wanted:
		var made: Object = real.feature(name)
		check(made != null and is_instance_valid(made) and made.get_script() != null, "%s is loaded and registered" % name)
		if name in Hooks.ORDER:
			check(made == game.get(name), "%s is the game's %s" % [name, name])
	for name: String in real.names():
		check(name in wanted, "%s is a known feature (listed in ORDER, or a file in scripts/features)" % name)
	var faults: Array = real.problems(game.REC_EVENTS)
	for line: String in faults:
		print("FEATURE_HOOKS_PROBLEM ", line)
	check(faults.is_empty(), "the registration has no problems (%d found)" % faults.size())
	for key: String in Hooks.ORDERS:
		for name: String in Hooks.ORDERS[key]:
			check(real.feature(name) != null, "%s in the order list %s is a registered feature" % [name, key])

	# 順番：決めたとおり（変えるときは、feature_hooks.gd の表と、ここの両方を直す）
	var orders := {
		"hook_f": ["director", "talent", "rope_grab", "bomb_kit", "cargo_kit", "cue_cards"],
		"hook_click": ["rope_grab"],
		"hook_key": ["talent"],
		"hook_input": ["director", "adhesive", "cue_cards"],
		"hook_hud": ["bomb_kit", "cargo_kit", "rope_grab"],
		"hook_sync": ["cargo_kit", "bomb_kit", "beats", "rope_grab"],
		"hook_core_event": ["bomb_kit", "talent"],
		"hook_take_ready": ["cargo_kit", "beats"],
		"hook_take_start": ["cargo_kit", "bomb_kit", "beats"],
		"hook_playback": ["cargo_kit", "bomb_kit", "beats"],
		"hook_playback:off": ["beats", "cargo_kit", "bomb_kit"],
	}
	for key: String in orders:
		var hook: String = key.get_slice(":", 0)
		var got: Array = real.order_names(hook, key if ":" in key else "").filter(func(name: String) -> bool: return name in Hooks.ORDER)
		check(got == orders[key], "%s is called in the decided order (got %s)" % [key, str(got)])

	# 合図の持ち主と、見返しに載せる合図
	var owners := {"kit": "cargo_kit", "bombkit": "bomb_kit", "bombnum": "bomb_kit", "ropegrab": "rope_grab", "beat": "beats"}
	for n: String in game.talent.EVENTS:
		owners[n] = "talent"
	var owned_ok := true
	for n: String in owners:
		if real.owner_of(n) != owners[n]:
			owned_ok = false
			print("FEATURE_HOOKS_PROBLEM event ", n, " belongs to '", real.owner_of(n), "', expected ", owners[n])
	check(owned_ok, "every feature event has the decided owner")
	var recorded: Array = ["bombkit", "bombnum", "beat", "stow", "lamp", "shawl", "halt", "neck", "hair"]
	var rec_ok := true
	for n: String in owners:
		if real.records(n) != (n in recorded):
			rec_ok = false
			print("FEATURE_HOOKS_PROBLEM event ", n, " recorded=", real.records(n))
	check(rec_ok, "the events recorded for the replay are the decided ones")
	var core_clean := true
	for n: String in game.REC_EVENTS:
		if real.owner_of(n) != "":
			core_clean = false
	check(core_clean, "the core's replay list holds no feature event")

	# 中心のファイルに、仕組みの合図の分岐が残っていない（残っていると、仕組みへ渡る前に、中心の側が受けてしまう）
	var left: Array = []
	for file: String in ["res://scripts/main.gd", "res://scripts/production_main.gd"]:
		var source: String = FileAccess.get_file_as_string(file)
		for n: String in owners:
			if ('n == "%s"' % n) in source or ('\t\t"%s":' % n) in source:
				left.append("%s in %s" % [n, file.get_file()])
	check(left.is_empty(), "the core files have no branch for a feature event (%s)" % str(left))

	# 合図が、持ち主まで届く（今の中身を、そのまま流す：何も変わらない）
	var before: Dictionary = game.cargo_kit.snapshot()
	game.ev("kit", [before])
	await frames(2)
	check(str(game.cargo_kit.snapshot()) == str(before), "a kit event reaches the cargo kit")

	print("FEATURE_HOOKS_TEST_FAIL" if failed else "FEATURE_HOOKS_TEST_OK")
	# 鳴っている音を止めてから終わる（終了時の「resources still in use」を出さない）
	var sfx: Node = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.silence_all()
	await frames(10)
	quit(1 if failed else 0)
