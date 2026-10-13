extends Node
## 成長はホストが観測し、受け取った本人だけが自分のプロフィールへ保存する。
const Profile := preload("res://scripts/crew_profile.gd")
const Workshop := preload("res://scripts/crew_workshop.gd")
const Reactions := preload("res://scripts/crew_reactions.gd")
const SAMPLE_INTERVAL := 0.2

var game: Node
var profile := Profile.new()
var profiles := {}
var run_styles := {}
var records := {}
var preview := {}
var last_report := {}
var crafts := {}
var camera_memos: Array = [{}, {}]
var job_id := ""
var job_closed := false
var save_error := ""
var _registered := false
var _memos := {}
var _held := {}
var _contributors := {"cargo":{}, "setup":{}, "framing":{}, "lighting":{}}
var _acting_until := {}
var _durations := {}
var _operations := {}
var _sample_t := 0.0
var _before_replay := {}
var _was_replaying := false

func _ready() -> void:
	var filename := "user://crew_skills.cfg"
	# ヘッドレス試験・専用ランナーは普段の育成データを汚さない。
	if game._headless or "--script" in OS.get_cmdline_args():
		filename = ""
	for arg: String in OS.get_cmdline_user_args():
		if "test" in arg: filename = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-profile="): filename = arg.trim_prefix("--crew-profile=")
	if profile.open(filename) != OK: save_error = "育成データを読み込めませんでした"
	if not FileAccess.file_exists(filename) and Profile.allowed_style(game.dash_dust_style, 0):
		profile.run_style = game.dash_dust_style

func _physics_process(delta: float) -> void:
	if not _registered and game.local_player() != null:
		_registered = true
		register_profile.rpc_id(1, profile.xp, profile.run_style)
	_sample_t += delta
	if _sample_t < SAMPLE_INTERVAL: return
	_sample_t = 0.0
	if Net.is_host() and game.production != null and game.production.phase == 4 and game.state == game.S.TAKE and not game.replaying and not job_closed:
		sample_take(SAMPLE_INTERVAL)

@rpc("any_peer", "call_local", "reliable")
func register_profile(data: Dictionary, style: String) -> void:
	if not Net.is_host(): return
	var who := Net.sender()
	if not game.players.has(who) or profiles.has(who): return
	profiles[who] = Profile.clean_xp(data)
	run_styles[who] = style if Profile.allowed_style(style, profiles[who].actor) else "sculpted"
	sync_profiles.rpc(profiles, run_styles)
	receive_crafts.rpc_id(who, crafts)

@rpc("authority", "call_local", "reliable")
func sync_profiles(data: Dictionary, styles: Dictionary) -> void:
	profiles = data.duplicate(true)
	run_styles = styles.duplicate()
	game.dash_dust_style = run_style(Net.my_id())
	if game.performance != null: game.performance.refresh_actions()

func level(who: int, role: String) -> int:
	return Profile.level_for(int(profiles.get(who, {}).get(role, 0)))

func run_style(who: int) -> String:
	return str(run_styles.get(who, "sculpted"))

@rpc("any_peer", "call_local", "reliable")
func choose_run_style(style: String) -> void:
	if not Net.is_host(): return
	var who := Net.sender()
	if not profiles.has(who) or not Profile.allowed_style(style, profiles[who].actor): return
	run_styles[who] = style
	sync_profiles.rpc(profiles, run_styles)
	style_saved.rpc_id(who, style)

@rpc("authority", "call_local", "reliable")
func style_saved(style: String) -> void:
	profile.run_style = style
	if profile.save() != OK: save_error = "走り演出の選択を保存できませんでした"

func begin_job() -> void:
	if not Net.is_host(): return
	job_id = Crypto.new().generate_random_bytes(16).hex_encode()
	job_closed = false
	records.clear()
	_held.clear()
	_acting_until.clear()
	_durations.clear()
	_operations.clear()
	for key: String in _contributors: _contributors[key].clear()
	_memos.clear()
	reset_job.rpc()
	receive_crafts.rpc({})

@rpc("authority", "call_local", "reliable")
func reset_job() -> void:
	preview.clear()
	last_report.clear()
	camera_memos = [{}, {}]

func active_job() -> bool:
	return Net.is_host() and not job_closed and not game.replaying and game.production != null and game.production.phase in [2, 4] and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE]

func mark(who: int, role: String, action: String) -> void:
	if who <= 0 or not game.players.has(who) or not Profile.ACTIONS.get(role, {}).has(action): return
	if not records.has(who): records[who] = {"actor":[], "camera":[], "backstage":[]}
	if action not in records[who][role]: records[who][role].append(action)

func note_prop(who: int, pid: int, action: String) -> void:
	if not active_job() or who <= 0 or not _contributors.has(action): return
	if not _contributors[action].has(pid): _contributors[action][pid] = []
	if who not in _contributors[action][pid]: _contributors[action][pid].append(who)

func aimed(who: int, prop: Node) -> void:
	if not active_job(): return
	if prop.kind == "camera":
		note_prop(who, prop.pid, "framing")
		if game.state == game.S.TAKE: _operations[prop.pid] = who
	elif prop.kind == "spot":
		note_prop(who, prop.pid, "lighting")

func observe_event(event: String, args: Array, who: int) -> void:
	if not active_job(): return
	if event == "hold":
		var member: int = int(args[0])
		if int(args[1]) != 0 and game.props.has(args[1]):
			var prop: Node3D = game.props[args[1]]
			_held[member] = [prop.pid, prop.global_transform]
		elif _held.has(member):
			var item: Array = _held[member]
			var prop: Node3D = game.props.get(item[0])
			if prop != null and (prop.global_position.distance_to(item[1].origin) > 0.08 or not prop.global_basis.is_equal_approx(item[1].basis)):
				note_prop(member, prop.pid, "setup")
				if prop.kind in ["camera", "spot"]: aimed(member, prop)
				if prop.rider_of == game.truck.pid: note_prop(member, prop.pid, "cargo")
			_held.erase(member)
	elif event == "perform" and game.state == game.S.TAKE:
		_acting_until[int(args[0])] = Time.get_ticks_msec() + 2000
	elif game.state == game.S.TAKE:
		if event == "stage_fx":
			if visible_point(args[3]) or visible_point(args[4]): mark(int(args[0]), "backstage", "effects")
		elif event in ["production_prop", "pop", "fuse", "carton"] and game.props.has(args[0]):
			if visible_prop(game.props[args[0]]): mark(who, "backstage", "effects")
		elif event == "burst" and visible_point(args[0]):
			mark(who, "backstage", "effects")

func visible_point(point: Vector3, excluded: Array = []) -> bool:
	var camera: Node = game.program_camera()
	if camera == null or camera.absent: return false
	var lens: Camera3D = camera.view_cam
	if not game.judge._in_frame(lens, Vector2(camera.view.size), point): return false
	var ignore: Array = [camera.get_rid()]
	ignore.append_array(excluded)
	return not game.judge._blocked(game.get_world_3d().direct_space_state, lens.global_position, point, ignore)

func visible_prop(prop: Node) -> bool:
	return not prop.absent and visible_point(prop.center_global(), [prop.get_rid()])

func _accrue(who: int, action: String, dt: float, threshold: float) -> void:
	var key := "%d:%s" % [who, action]
	_durations[key] = float(_durations.get(key, 0.0)) + dt
	if _durations[key] >= threshold: mark(who, "actor", action)

func sample_take(dt: float) -> void:
	if not active_job() or game.state != game.S.TAKE: return
	var subjects: Array[Vector3] = []
	var visible_cast: Array[int] = []
	var performing: Array[int] = []
	for actor: Node3D in game.actors:
		var point := actor.global_position + Vector3.UP
		if visible_point(point, [actor.get_rid()]): subjects.append(point)
	for who: int in game.players:
		var player: Node = game.players[who]
		var point: Vector3 = player.global_position + Vector3.UP * 0.9
		if not visible_point(point, [player.get_rid()]): continue
		subjects.append(point)
		visible_cast.append(who)
		var acting: bool = player.performance_active() or int(_acting_until.get(who, 0)) > Time.get_ticks_msec()
		var moving: bool = str(player.vis.current) in ["run", "run_start", "jump", "crouch", "crouch_walk", "crouch_idle"] and player.operating == 0
		if acting: _accrue(who, "acting", dt, 0.4)
		if moving: _accrue(who, "action", dt, 0.8)
		if acting or moving: performing.append(who)
	if subjects.size() >= 2:
		for who: int in performing: _accrue(who, "ensemble", dt, 0.4)
	var used_props := {}
	for action: String in ["cargo", "setup"]:
		for pid: int in _contributors[action]:
			var prop: Node = game.props.get(pid)
			if prop != null and prop.kind not in ["camera", "spot", "clapper"] and visible_prop(prop):
				used_props[pid] = true
				for who: int in _contributors[action][pid]: mark(who, "backstage", action)
	var camera: Node = game.program_camera()
	if subjects.is_empty() and used_props.is_empty(): return
	for who: int in _contributors.framing.get(camera.pid, []): mark(who, "camera", "framing")
	if _operations.has(camera.pid): mark(_operations[camera.pid], "camera", "operation")
	used_props[camera.pid] = true
	used_props[game.clapper.pid] = true
	for spot: Node in game.spots:
		if spot.absent or spot.level <= 0: continue
		for point: Vector3 in subjects:
			var direction: Vector3 = point - spot.beam_origin()
			if direction.length() > spot.RANGE or rad_to_deg(spot.beam_dir().angle_to(direction)) > spot.ANGLE: continue
			if game.judge._blocked(game.get_world_3d().direct_space_state, spot.beam_origin(), point, [spot.get_rid()]): continue
			used_props[spot.pid] = true
			for who: int in _contributors.lighting.get(spot.pid, []): mark(who, "camera", "lighting")
			break
	for action: String in ["cargo", "setup"]:
		for pid: int in used_props:
			for who: int in _contributors[action].get(pid, []): mark(who, "backstage", action)

func publish_preview() -> void:
	if not Net.is_host(): return
	for who: int in game.players:
		receive_preview.rpc_id(who, Profile.report(profiles.get(who, {}), records.get(who, {})))

@rpc("authority", "call_local", "reliable")
func receive_preview(report: Dictionary) -> void:
	preview = report

func finish_job() -> void:
	if not Net.is_host() or job_closed: return
	job_closed = true
	if job_id.is_empty(): job_id = Crypto.new().generate_random_bytes(16).hex_encode()
	for who: int in game.players:
		var contributions: Dictionary = records.get(who, {})
		var report := Profile.report(profiles.get(who, {}), contributions)
		var totals := {}
		for role: String in Profile.ROLES: totals[role] = report[role].after_xp
		profiles[who] = totals
		receive_receipt.rpc_id(who, job_id, contributions)
	sync_profiles.rpc(profiles, run_styles)

@rpc("authority", "call_local", "reliable")
func receive_receipt(receipt: String, contributions: Dictionary) -> void:
	var report := profile.award(receipt, contributions)
	if report.is_empty(): return
	last_report = report
	preview = report
	if profile.last_save_error != OK: save_error = "成長を保存できませんでした。保存先の空き容量を確認してください"

func growth_text(final: bool = true) -> String:
	var report: Dictionary = last_report if final else preview
	var lines: Array[String] = []
	for role: String in Profile.ROLES:
		var row: Dictionary = report.get(role, {})
		if row.is_empty(): continue
		var detail: Array[String] = []
		for action: String in row.actions: detail.append(Profile.ACTIONS[role][action] + "20")
		if row.gained > 0: detail.append("納品10")
		var level_text := "Lv%d" % int(row.after_level)
		if row.after_level != row.before_level: level_text = "Lv%d → Lv%d" % [row.before_level, row.after_level]
		lines.append("%s  +%d XP  %s  累計%d" % [Profile.NAMES[role], row.gained, level_text, row.after_xp])
		if not detail.is_empty(): lines.append("  " + " / ".join(detail))
		if row.before_level < 2 and row.after_level >= 2: lines.append("  解放！ " + Profile.UNLOCKS[role])
	if not save_error.is_empty(): lines.append(save_error)
	return "\n".join(lines)

@rpc("any_peer", "call_local", "reliable")
func camera_memo(slot: int, restore: bool) -> void:
	if not Net.is_host() or slot not in [0, 1] or not active_job(): return
	var who := Net.sender()
	var player: Node = game.players.get(who)
	if player == null or level(who, "camera") < 2: return
	var camera: Node = game.props.get(player.operating)
	if camera == null or camera.kind != "camera" or camera.operator != who: return
	if not _memos.has(who): _memos[who] = [{}, {}]
	if restore:
		var memo: Dictionary = _memos[who][slot]
		if memo.is_empty(): return
		camera.cam_yaw = wrapf(memo.yaw - camera.global_rotation.y, -PI, PI)
		camera.cam_pitch = memo.pitch
		camera.fov = memo.fov
		camera.aim(0.0, 0.0, 0.0)
		aimed(who, camera)
	else:
		_memos[who][slot] = {"yaw":camera.global_rotation.y + camera.cam_yaw, "pitch":camera.cam_pitch, "fov":camera.fov}
	receive_memos.rpc_id(who, _memos[who])
	game.ev.rpc_id(who, "toast", ["構図%dを%s" % [slot + 1, "戻した" if restore else "記憶した"], 0])

@rpc("authority", "call_local", "reliable")
func receive_memos(data: Array) -> void:
	camera_memos = data

@rpc("any_peer", "call_local", "reliable")
func craft(recipe: String) -> void:
	if not Net.is_host() or not active_job() or game.state != game.S.PREP or not Workshop.RECIPES.has(recipe): return
	var who := Net.sender()
	var player: Node = game.players.get(who)
	if player == null or level(who, "backstage") < 2: return
	var prop: Node = game.props.get(player.held)
	if prop == null or prop.kind != "carton" or prop.holder != who or prop.absent: return
	crafts[prop.pid] = recipe
	note_prop(who, prop.pid, "setup")
	receive_crafts.rpc(crafts)
	game.ev.rpc_id(who, "toast", ["段ボールに「%s」を貼った。仲間も使える" % Workshop.RECIPES[recipe], 0])

@rpc("authority", "call_local", "reliable")
func receive_crafts(data: Dictionary) -> void:
	var previous := crafts.duplicate()
	crafts = data.duplicate()
	for pid: int in previous:
		if not crafts.has(pid) and game.props.has(pid): Workshop.apply(game.props[pid], "")
	for pid: int in crafts:
		if game.props.has(pid): Workshop.apply(game.props[pid], str(crafts[pid]))

func replay_changed() -> void:
	if game.replaying and not _was_replaying:
		_before_replay = crafts.duplicate()
	elif not game.replaying and _was_replaying:
		receive_crafts(_before_replay)
	_was_replaying = game.replaying
