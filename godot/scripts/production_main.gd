extends "res://scripts/main.gd"
const Flow := preload("res://scripts/production_flow.gd")
const ProductionHud := preload("res://scripts/production_hud.gd")
const CastDress := preload("res://scripts/cast_dress.gd")
const ProductionPing := preload("res://scripts/production_ping.gd")
const ProductionExport := preload("res://scripts/production_export.gd")
const CameraSwitcher := preload("res://scripts/camera_switcher.gd")
const MonitorPopup := preload("res://scripts/monitor_popup.gd")
var camera_switcher: Node
var monitor_popup: CanvasLayer
const CueCards := preload("res://scripts/cue_cards.gd")
var cue_cards: Node
const ProductionPerformance := preload("res://scripts/production_performance.gd")
const CrewSkills := preload("res://scripts/crew_skills.gd")
const CargoKit := preload("res://scripts/cargo_kit.gd")
var cargo_kit: Node               # 段ボール箱（置き場・箱詰め）と、荷台のフックに掛けるロープ
const BombKit := preload("res://scripts/bomb_kit.gd")
var bomb_kit: Node                # 爆弾の道具（導火線になるロープ・はさみ・火薬の袋）
const RopeGrab := preload("res://scripts/rope_grab.gd")
var rope_grab: Node               # ロープを手でつかむ（左クリック）
const Beats := preload("res://scripts/production_beats.gd")
var beats: Node                   # 場面の列を持つ依頼（5場面の完全版）の進め方と採点。今までの3場面の依頼では、何もしない
const CastTalent := preload("res://scripts/cast_talent.gd")
const Director := preload("res://scripts/production_director.gd")
var director: Node                # 監督の机（事務所の机の上の、のぞき箱と発注の電話）
var _delivering_more := false     # 発注をやり直して、届いた分だけを置いている最中か（荷台に先客がいるかもしれない）
var _beside := 0                  # 荷台に置けなかった届け物を、軽トラの横に並べる順番
var crew_skills: Node
var performance: CanvasLayer
var production_export: Node
var production_ping: CanvasLayer
var _ping_last: Dictionary = {}
var _ping_local_next := 0.0
var production: Node
var production_hud: CanvasLayer
var _legacy_mode := false
var _crew_epoch := 0
# 歩く画面には何も開かない。掲示板や軽トラに近づいて F を押したときだけ画面が開く
var menu_open := ""        # ""＝歩いている / board＝依頼 / packing＝積み込み確認 / pause＝一時メニュー
var brief_job := 0          # 打ち合わせ中の依頼の番号
var script_open := false    # 手に持った台本を開いているか
var _cast_dress: Dictionary = {}   # 見立ての飾り（物のID → cast_dress.gd）。映画にも映る
var _cast_names: Dictionary = {}   # 見立ての役の名前（物のID → Label3D）。準備中だけ、制作班にだけ見える
var _attack: Dictionary = {}      # 飛んでいる途中の「怪獣の技」 {t, pos, pid}
const ATTACK_FLIGHT := 0.9        # 怪獣の技が、撃ち出されてから落ちるまでの秒数

func _ready() -> void:
	for flag in ["--autotest","--failtest","--nettest","--faceshot","--gearshot","--legacy"]:
		if flag in OS.get_cmdline_user_args():
			_legacy_mode = true
	await super._ready()
	if _legacy_mode:
		startup_complete = true
		startup_ready.emit()
		return
	production = Flow.new()
	production.name = "Production"
	add_child(production)
	await production.setup(self, startup_incremental)
	crew_skills = CrewSkills.new()
	crew_skills.name = "CrewSkills"
	crew_skills.game = self
	add_child(crew_skills)
	# キャラごとの特技（K）。経験値で育つ制作班スキルとは別物（育たない・保存しない）
	talent = CastTalent.new()
	talent.name = "CastTalent"
	talent.game = self
	add_child(talent)
	hooks.add("talent", talent)
	camera_switcher = CameraSwitcher.new()
	camera_switcher.name = "CameraSwitcher"
	camera_switcher.game = self
	add_child(camera_switcher)
	camera_switcher.setup()
	cue_cards = CueCards.new()
	cue_cards.name = "CueCards"
	cue_cards.game = self
	add_child(cue_cards)
	cue_cards.setup()
	hooks.add("cue_cards", cue_cards)
	# 段ボール置き場（箱16個・ロープ・山）。物のIDがずれないよう、ほかの物を全部作ったあとに作る
	cargo_kit = CargoKit.new()
	cargo_kit.name = "CargoKit"
	cargo_kit.game = self
	add_child(cargo_kit)
	cargo_kit.setup()
	hooks.add("cargo_kit", cargo_kit)
	# 爆弾の道具（はさみ・火薬の袋5つ。導火線は、上のロープと同じ物）。これも、ほかの物のあとに作る
	bomb_kit = BombKit.new()
	bomb_kit.name = "BombKit"
	bomb_kit.game = self
	add_child(bomb_kit)
	bomb_kit.setup()
	hooks.add("bomb_kit", bomb_kit)
	# ロープを手でつかむ（物は作らないので、物のIDには関係しない）
	rope_grab = RopeGrab.new()
	rope_grab.name = "RopeGrab"
	rope_grab.game = self
	add_child(rope_grab)
	rope_grab.setup()
	hooks.add("rope_grab", rope_grab)
	# キャラの特技で使う物（モップの王様の毛の束）。物のIDがずれないよう、いちばん最後に作る
	talent.setup()
	# 場面の列を持つ依頼で使う、役者の印②③。ふだんは片づけてある。これも、ほかの物のあとに作る
	beats = Beats.new()
	beats.name = "Beats"
	beats.game = self
	add_child(beats)
	beats.setup()
	hooks.add("beats", beats)
	# 会社の機材（カメラ・ライト・カチンコ・カンペ・モニター）を、軽トラの北東の機材置き場に並べる
	if Net.is_host():
		production.stage_gear()
	# 監督の机（のぞき箱と発注の電話）。持ち運べない置物なので、物のIDは使わない
	director = Director.new()
	director.name = "Director"
	director.game = self
	add_child(director)
	director.setup()
	hooks.add("director", director)
	# scripts/features/ に置いてある仕組み（置くだけで足される。feature_hooks.gd）。物を作るなら、ここが最後になる
	hooks.spawn_folder(self)
	monitor_popup = MonitorPopup.new()
	monitor_popup.name = "MonitorPopup"
	monitor_popup.game = self
	add_child(monitor_popup)
	production_hud = ProductionHud.new()
	production_hud.game = self
	add_child(production_hud)
	production_hud.build()
	production_ping = ProductionPing.new()
	production_ping.game = self
	add_child(production_ping)
	production_export = ProductionExport.new()
	production_export.game = self
	add_child(production_export)
	performance = ProductionPerformance.new()
	performance.name = "Performance"
	performance.game = self
	add_child(performance)
	for flag: String in OS.get_cmdline_user_args():
		if flag.begins_with("--performancenettest="):
			var test: Node = load("res://tests/performance_net_test.gd").new()
			test.name = "PerformanceNetTest"
			test.game = self
			test.role = flag.get_slice("=",1)
			add_child(test)
	if "--productionnettest" in OS.get_cmdline_user_args():
		var test: Node = load("res://tests/productionnettest.gd").new()
		test.game = self
		add_child(test)

	startup_complete = true
	startup_ready.emit()

# ---- 画面を開く場所と、マウスの出し入れ ----

# いま立っている場所で F を押すと開く画面（無ければ ""）
func station() -> String:
	var me: Node = local_player()
	if production == null or me == null or me.held != 0 or me.operating != 0 or state != S.PREP:
		return ""
	var p: Vector3 = me.global_position
	if production.phase == 0:
		var b: Vector3 = Flow.Office.CONTRACT_POINT
		if Vector2(p.x - b.x, p.z - b.z).length() < 3.6:
			return "board"
	elif production.phase == 2 and p.distance_to(Flow.HOME_TRUCK) < 4.5:
		return "packing"
	elif production.phase == 2:
		var d: Vector3 = Flow.Rental.POINT
		if Vector2(p.x - d.x, p.z - d.z).length() < 3.2:
			return "order"
	return ""


func holding_script() -> bool:
	var me: Node = local_player()
	return me != null and me.held != 0 and props.has(me.held) and props[me.held].kind == "script"


# 台本を読める人か：台本を手に持っている人と、台本の写しを開いている手帳の人（キャラの特技）。
# 場面の一覧と配役は、この人の画面にだけ出る。ほかの人は、声で聞く
func reads_script() -> bool:
	var me: Node = local_player()
	if me == null:
		return false
	return holding_script() or (talent != null and talent.note_open(me.peer_id))


# 制作モードでは、会社の機材を荷台に載せない（機材置き場に並べ、出発するといっしょに運ばれる）
func gear_on_bed() -> bool:
	return production == null


func can_see_monitor() -> bool:
	var me: Node = local_player()
	if production == null or me == null:
		return true
	return camera_switcher.nearby(me) if camera_switcher != null else production.near_monitor(me)

func program_camera() -> Node:
	return camera_switcher.camera() if camera_switcher != null else film

func select_program_camera(pid: int) -> void:
	if camera_switcher != null:
		camera_switcher.select(pid)

func open_monitor() -> bool:
	var me: Node = local_player()
	if monitor_popup == null or me == null or me.held != 0 or me.operating != 0 or me.target != camera_switcher.monitor:
		return false
	if not camera_switcher.allowed() or not camera_switcher.nearby(me): return false
	monitor_popup.set_open(true)
	return true

@rpc("any_peer","call_local","reliable")
func h_monitor_control(on: bool) -> void:
	if camera_switcher != null:
		camera_switcher.request_control(Net.sender(),on)

@rpc("any_peer","call_local","reliable")
func h_camera_cut(which: int) -> void:
	if camera_switcher != null:
		camera_switcher.request_cut(Net.sender(),which)

@rpc("any_peer","call_local","reliable")
func h_monitor_cue(cue: int) -> void:
	if camera_switcher != null and camera_switcher.controls(Net.sender()) and cue in [1,2,3]:
		if beats != null and beats.active():
			# 場面の列を持つ依頼：1＝次の場面 / 2＝もう一度。進められるのは、台本を読める人だけ
			beats.host_step(Net.sender(), cue)
			return
		if cue == 2 and bomb_armed():
			ev.rpc_id(Net.sender(), "toast", ["爆弾は合図では鳴らない。導火線に火を付ける係に合図を！", 0])
			return
		h_cue(cue)

@rpc("any_peer","call_local","reliable")
func h_monitor_stop() -> void:
	if camera_switcher != null and camera_switcher.controls(Net.sender()) and state == S.TAKE:
		_cut()


# 何も持たずに左クリックしたとき：アップグレード画面の枠に照準が合っていれば、それを買う
func world_click() -> bool:
	# 仕組みの左クリック（ロープを見て：つかむ／つかんでいれば、離す。rope_grab.gd の hook_click）
	if hooks.first("hook_click", [local_player()]):
		return true
	if production == null or production.display == null or production.display.hover == "":
		return false
	if production.display.aimed_offer().is_empty():
		return true
	h_buy_upgrade.rpc_id(1, production.display.hover)
	return true


func open_menu(which: String) -> void:
	menu_open = which
	Sfx.play("menu_open", null, -8.0)


# 依頼主との打ち合わせを開く（受けるかどうかは、その画面で決める）
func open_brief(index: int) -> void:
	if production == null or production.phase != 0 or index not in production.offered():
		return
	brief_job = index
	open_menu("brief")


func close_menu() -> void:
	if menu_open != "":
		Sfx.play("menu_close", null, -8.0)
	menu_open = ""


# 発注の画面は、開いた人の画面にだけ開く（ゲームは止まらない。ほかの人は準備を続ける）
func ordering() -> bool:
	if production == null:
		return super.ordering()
	return production.orderer != 0 and production.orderer == Net.my_id() and production.phase == 2 and state == S.PREP


# 注文を変えられるのは、発注の画面を開いている人だけ（ホストが確かめる）
func may_order(who: int) -> bool:
	if production == null:
		return super.may_order(who)
	return production.orderer != 0 and production.orderer == who and production.phase == 2 and state == S.PREP


# 現場に無い物の種類。届いている物は「決めた注文」で決まる（画面で選んでいる途中の物は、決めるまで届かない）
func _absent_kinds() -> Array:
	if production == null:
		return super._absent_kinds()
	var gone: Array = []
	for opt: Dictionary in OPTIONS:
		if int(production.ordered.get(opt["id"], 0)) == 0 and not owns(opt["id"]):
			gone.append_array(opt["kinds"])
	return gone


# 画面が開いている間だけマウスを出す。Esc で切り替える必要はない
func wants_cursor() -> bool:
	if cue_cards != null and cue_cards.editor.opened: return true
	if production == null:
		return false
	if monitor_popup != null and monitor_popup.opened:
		return true
	return menu_open != "" or character_open or ordering() or state in [S.ORDER, S.RESULT, S.DELIVERED] or production.phase == 5 or (performance != null and performance.opened)


func _grab_mouse(on: bool) -> void:
	if production == null:
		super._grab_mouse(on)


func _process(_delta: float) -> void:
	if production == null:
		return
	if menu_open == "upgrade" and production.phase not in [0, 2]:
		menu_open = ""
	if (menu_open in ["board", "brief"] and production.phase != 0) or (menu_open == "packing" and production.phase != 2):
		menu_open = ""
	if menu_open != "" and (state in [S.RESULT, S.REPLAY, S.DELIVERED] or production.phase in [3, 5]):
		menu_open = ""
	# 行き先は、空中の目印ではなく、本物の看板（掲示板・段ボール置き場・廃材と軽トラ など）と、近づいたときの「F」の案内で見せる
	# 台本を手放したら、ページも閉じる
	if script_open and not holding_script():
		script_open = false
	# 演技・効果の案内は撮影現場でだけ出す
	if performance != null and performance.get("_hint") != null:
		performance._hint.visible = production.phase == 4 and menu_open == ""
	_sync_cast_names()
	if _headless:
		return
	var mode := Input.MOUSE_MODE_VISIBLE if wants_cursor() else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


# カメラを操作している人の左クリック：次の合図を出す（数字キーへ手を伸ばさなくていい）
func operator_click() -> void:
	if production == null or state != S.TAKE:
		return
	if beats != null and beats.active():
		# 場面の列を持つ依頼：次の場面へ（台本を読める人だけ。ホストが確かめる）
		h_beat.rpc_id(1, 1)
		return
	var ok: Array = live.get("passed", [false, false, false])
	var next := 1 if not ok[0] else (2 if not ok[1] else 3)
	if next == 2 and bomb_armed():
		# 爆弾は合図では鳴らない。点火係に声をかける
		hud.show_toast("爆弾は合図では鳴らない。導火線に火を付ける係に合図を！", Hud.YELLOW)
		return
	h_cue.rpc_id(1, next)


func _escape() -> bool:
	if menu_open == "brief":
		open_menu("board")
		return true
	if menu_open != "":
		close_menu()
		return true
	if character_open:
		set_character_menu(false)
		return true
	if help_open:
		help_open = false
		return true
	if ordering():
		# 発注の画面を、決めずに閉じる（選びかけの注文は、前に決めた注文へ戻る）
		h_order_close.rpc_id(1)
		Sfx.play("menu_close", null, -8.0)
		return true
	if performance != null and performance.opened:
		return false
	if state in [S.PREP, S.COUNTDOWN, S.TAKE] and production.phase in [0, 2, 4]:
		open_menu("pause")
		return true
	return false


func _input(event: InputEvent) -> void:
	# 仕組みの、開いている画面の操作（のぞき箱・発注 → 接着剤 → カンペを書く画面。各仕組みの hook_input）
	if hooks.first("hook_input", [event]):
		get_viewport().set_input_as_handled()
		return
	if monitor_popup != null and monitor_popup.opened and monitor_popup.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if production != null and local_player() != null and not input_locked:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and _escape():
			get_viewport().set_input_as_handled()
			return
		if ordering() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			h_order_close.rpc_id(1)
			Sfx.play("menu_close", null, -8.0)
			get_viewport().set_input_as_handled()
			return
		if menu_open != "":
			var by_key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F
			var by_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
			if menu_open == "brief" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
				var picked := brief_job
				close_menu()
				h_accept_job.rpc_id(1, picked)
				get_viewport().set_input_as_handled()
				return
			if (by_key or by_mouse) and menu_open == "brief":
				open_menu("board")
				get_viewport().set_input_as_handled()
				return
			if by_key or by_mouse:
				close_menu()
				get_viewport().set_input_as_handled()
				return
	if production_export != null and not production_export.last_saved.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_O and not character_open and not help_open:
		production_export.open_saved()
		get_viewport().set_input_as_handled()
		return
	if production_export != null and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P and state == S.RESULT and not character_open and not help_open:
		production_export.begin()
		get_viewport().set_input_as_handled()
		return
	if production != null and not ui_blocking() and local_player() != null:
		var ping_key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V
		var ping_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE
		if (ping_key or ping_mouse) and _ping_phase_allowed():
			var now := Time.get_ticks_msec()/1000.0
			if now < _ping_local_next:
				return
			_ping_local_next = now + 0.7
			var me: Node = local_player()
			var op: Node = props.get(me.operating)
			var camera: Camera3D = op.view_cam if op != null and op.kind == "camera" else me.cam
			h_ping.rpc_id(1,camera.global_position,-camera.global_basis.z)
			get_viewport().set_input_as_handled()
			return
	if production == null or not event is InputEventKey or not event.pressed or event.echo or ui_blocking() or local_player() == null:
		return
	var me: Node = local_player()
	if hooks.first("hook_key", [event, me]):
		# 仕組みの、自分のキー（K＝キャラの特技。cast_talent.gd の hook_key）
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_Y and production.phase in [2, 4] and state == S.PREP:
		# 見立て：狙っている物（持っている物）の役を、らしい順に切り替える
		var subject: Node = props.get(me.held) if me.held != 0 else me.target
		if subject != null and Flow.Cast.castable(subject.kind) and not Flow.Cast.locked(subject.kind):
			h_cast.rpc_id(1, subject.pid, Flow.Cast.cycle(subject.kind, production.story(), production.role_of(subject), production.cast_tags(subject), reads_script()))
		elif subject != null:
			hud.show_toast("%s には役を付けられない" % subject.label, Hud.YELLOW)
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_F and hooks.first("hook_f", [me]):
		# 仕組みの F（各仕組みの hook_f）。最初に使った仕組みで止まる。順番は feature_hooks.gd の ORDERS["hook_f"]：
		#   机の物（のぞき箱・発注の電話）→ 仲間の頭の道具箱 → つかんだロープの端 → 爆弾の道具 → 箱とロープ → カンペ・等身大パネル
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_F:
		if production.phase == 2 and me.held != 0 and me.global_position.distance_to(Flow.HOME_TRUCK) < 4.5:
			h_load_truck.rpc_id(1,me.held)
			get_viewport().set_input_as_handled()
		elif holding_script():
			script_open = not script_open
			Sfx.play("menu_open" if script_open else "menu_close", null, -8.0)
			get_viewport().set_input_as_handled()
		elif me.held != 0 and is_action_prop(props[me.held]):
			h_prop_action.rpc_id(1,me.held)
			get_viewport().set_input_as_handled()
		elif is_action_prop(me.target):
			h_prop_action.rpc_id(1,me.target.pid)
			get_viewport().set_input_as_handled()
		elif me.held == 0 and me.target != null and me.target.kind in ["camera", "spot"]:
			# カメラ・ライトを狙っているときは、その操作が先（機材置き場は軽トラのそばなので、積み込み確認を開かない）
			pass
		elif station() == "order":
			h_open_order.rpc_id(1)
			get_viewport().set_input_as_handled()
		elif station() != "":
			open_menu(station())
			get_viewport().set_input_as_handled()

func is_action_prop(prop: Node) -> bool:
	if prop == null:
		return false
	if _topples(prop):
		return true
	return prop.has_method("set_active") and (not prop.has_method("can_activate") or prop.can_activate())


# 怪獣役の物は F で倒したり起こしたりできる（口が動く竜の頭は口の開閉を優先）
func _topples(prop: Node) -> bool:
	if judge.role_of(prop) != "monster":
		return false
	return not (prop.has_method("can_activate") and prop.can_activate())

func prop_action_hint(prop: Node) -> String:
	if _topples(prop):
		return "倒す" if prop.global_basis.y.y >= 0.6 else "起こす"
	if prop.kind == "dragon_skull":
		return "口を閉じる" if prop.active else "口を開く"
	if prop.kind == "cleaning_cart":
		return "絞り機を動かす"
	return "下げる" if prop.active else "上げる"

func _recovery_point() -> Vector3:
	if production.phase in [0,1]:
		return Flow.Office.SPAWN_POINT + Vector3(0,0.9,0)
	if production.phase == 2:
		return Flow.HOME_TRUCK + Vector3(-3,1,1)
	if production.phase == 3:
		return truck.global_position + Vector3(-3,1,0)
	return SPAWN + Vector3(0,0.9,0)

func recover_player(player: Node3D) -> void:
	if not production:
		super.recover_player(player)
		return
	player.global_position = _recovery_point()
	player.velocity = Vector3.ZERO
	h_recover_crew.rpc_id(1)

@rpc("any_peer","call_local","reliable")
func h_recover_crew() -> void:
	if not Net.is_host() or not production or replaying:
		return
	var who := Net.sender()
	var player: Node = players.get(who)
	if player == null:
		return
	var point := _recovery_point()
	move_crew(point,player.aim_yaw,who)
	var prop := _held_by(who)
	if prop:
		var saved: Array = prop.get_state()
		saved[0] = point + player.flat_forward() * 2.2
		prop.restore(saved)
		prop.set_holder(who)
		prop.grab_time = Time.get_ticks_msec() / 1000.0
	host_ev("toast",["場外に落ちた制作班を回収。撮影は続行です！",0])

# ---- 場面の列を持つ依頼（production_beats.gd） ----

# 場面を進める頼み。n：1＝次の場面へ / 2＝今の場面をもう一度
@rpc("any_peer","call_local","reliable")
func h_beat(n: int) -> void:
	if Net.is_host() and beats != null:
		beats.host_step(Net.sender(), n)


# 今までの合図（1・2・3）。場面の列を持つ依頼では使わない（場面は h_beat で進める）
@rpc("any_peer", "call_local", "reliable")
func h_cue(n: int) -> void:
	if beats != null and beats.active():
		return
	super.h_cue(n)
	# 合図を聞きたい仕組みへ（試写会の場面の見出し など。各仕組みの hook_cue）
	if Net.is_host() and state in [S.PREP, S.TAKE]:
		hooks.run("hook_cue", [n])


# 自分が、場面を進められる人か：台本を読める人と、置いてある台本のすぐそばにいる人。
# 「〜 OK！」の知らせと、場面の一覧は、この人の画面にだけ出る
func directs() -> bool:
	var me: Node = local_player()
	return me != null and beats != null and beats.may_direct(me.peer_id)


# 本番の残り秒数を、画面に出さないか。場面の列を持つ依頼では、時計は物（カメラのリールと、モニターの枠の目盛り）
func hides_take_clock() -> bool:
	return beats != null and beats.active() and state == S.TAKE


# テイクの長さ：場面の列を持つ依頼では、フィルム1本ぶん
func take_limit() -> float:
	return float(beats.FILM_SEC) if beats != null and beats.active() else super.take_limit()


# カット割りの依頼の場転：フィルムを止めている間（production_beats.gd の holding）
func take_held() -> bool:
	return state == S.TAKE and beats != null and beats.holding


# 場面の列を持つ依頼では、準備中に「足りないこと」を出さない。場面の数も、その依頼の数に合わせる
func _update_live() -> void:
	super._update_live()
	if beats != null and beats.active():
		live["mute"] = true
		if state in [S.PREP, S.COUNTDOWN]:
			# 準備中は、どの場面もまだ撮れていない（前のテイクの成否を残さない）
			live["passed"] = (beats.lamps() as Array).duplicate()
	else:
		live.erase("mute")


# B：役者を最初の印へ戻す。通し稽古も、そこで終わる
@rpc("any_peer", "call_local", "reliable")
func h_standby() -> void:
	super.h_standby()
	if Net.is_host() and beats != null and state == S.PREP:
		beats.host_reset()


# ---- 爆弾 ----

# 現場に、点火しないと鳴らない爆弾があるか（あれば、合図キーの「2」では鳴らない）。
# つなぐ・切る・注ぐ・点火は、物を手で扱って行う（bomb_kit.gd）
func bomb_armed() -> bool:
	return production != null and not fx.absent and production.on_set(fx) and (fx.loaded() or state == S.PREP)


# 借りた物を並べ直す：爆弾は空で届き、火薬の袋が軽トラの横に届く
func _apply_order() -> void:
	super._apply_order()
	if bomb_kit != null:
		bomb_kit.host_apply_order()


# 爆弾が爆発した：つないであった線は吹き飛び、こぼれた火薬に火が移る
func host_burst(box: RigidBody3D) -> void:
	var power: float = box.blast() if state == S.TAKE and box.loaded() else 0.0
	# 場面の列を持つ依頼では、役者の印（床のバミリ）は爆風で飛ばさない（役者の行き先が、爆発のたびに変わらないように）
	var pinned: bool = beats != null and beats.active()
	if pinned:
		beats.pin_marks(true)
	super.host_burst(box)
	if pinned:
		beats.pin_marks(false)
	if bomb_kit != null and box == fx:
		bomb_kit.on_bomb_burst(power)


# ---- 見立て（配役） ----

# 物に役を付ける。誰でもできる。会社での準備中と、現場の準備中だけ
@rpc("any_peer","call_local","reliable")
func h_cast(pid: int, role: String) -> void:
	if not Net.is_host() or not production or production.phase not in [2,4] or state != S.PREP or replaying:
		return
	var me: Node = players.get(Net.sender())
	var prop: Node = props.get(pid)
	if me == null or prop == null or prop.absent:
		return
	if prop.holder != Net.sender() and me.reach_base().distance_to(prop.center_global()) > Player.REACH + 2.0:
		return
	var before: Array = (production.cast_sheet()["combos"] as Array).map(func(c: Dictionary) -> String: return str(c["name"]))
	if not production.cast_set(pid, role, cast_face_side(prop, me.global_position)):
		return
	var story: String = production.story()
	if role == "":
		host_ev("toast", ["%s の役を外した" % prop.label, 0])
	else:
		var grade: int = production.cast_fit(prop, role)
		# らしさは、台本を読める人にだけ知らせる（"cast_toast"：[みんなへの文, 台本を読める人への文]）
		var cast_text := "%s → %s" % [prop.label.get_slice("（", 0), Flow.Cast.role_title(role, story)]
		host_ev("cast_toast", [cast_text, "%s（%s）" % [cast_text, Flow.Cast.GRADES[grade]["name"]]])
		if Flow.Cast.is_joker(prop.kind) and grade == 0:
			host_ev("toast", ["白紙のパネルは、ただの白い板。F で何か描けば、どの役にもなれるジョーカーになる", 1])
	host_ev("sfx", ["ui_select", prop.global_position])
	# 新しくコンボの見込みができたら知らせる
	for combo: Dictionary in production.cast_sheet()["combos"]:
		if str(combo["name"]) not in before:
			# コンボの見込みも、台本を読める人にだけ（"script_toast"）
			host_ev("script_toast", ["コンボの見込み %s　本番で映れば +%d コイン" % [combo["name"], int(combo["coins"])]])


# 怪獣の技を撃ち出す怪獣：立っている怪獣役のうち、撮影カメラにいちばん近い物（遠近法で手前に置くので）
func _attack_monster(b: Node3D) -> Node3D:
	if production == null or production.story() != "kaiju":
		return null
	var cam_pos: Vector3 = program_camera().view_cam.global_position
	var best: Node3D = null
	for p: Node3D in props.values():
		if p == b or p.absent or p.holder != 0 or judge.role_of(p) != "monster" or not production.at_site(p):
			continue
		if best == null or p.global_position.distance_to(cam_pos) < best.global_position.distance_to(cam_pos):
			best = p
	return best


# 怪獣の技が落ちる場所：カメラから見て、二人の少し向こう
func _attack_target() -> Vector3:
	var mid: Vector3 = actors_mid()
	var away: Vector3 = mid - program_camera().view_cam.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	return mid + away * 2.4 + Vector3(0, 0.45, 0)


func burst_spot(b: Node3D) -> Vector3:
	if not b.has_method("burst_point") and _attack_monster(b) != null:
		return _attack_target()
	return super.burst_spot(b)


# 爆発役に見立てた物の合図。怪獣がいれば、怪獣の頭の上から二人の向こうへ撃ち出す（怪獣の技）。
# いなければ、その場でポンと跳ねる。どちらも周りは吹き飛ばない（本物の爆風は爆弾だけ）
func host_cast_boom(b: RigidBody3D) -> bool:
	if b.has_method("pop"):
		return false
	if not _attack.is_empty():
		return true
	if b.rider_of != 0:
		host_unload(b)
	b.set_fixed(false)
	var monster := _attack_monster(b)
	if monster == null:
		b.sleeping = false
		b.apply_central_impulse(Vector3(0, 5.5, 0) * b.mass)
		b.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * b.mass * 0.4)
		_soft_burst(b.center_global(), b.pid)
		return true
	var target := _attack_target()
	var from: Vector3 = monster.center_global() + Vector3(0, monster.half.y + maxf(b.half.x, maxf(b.half.y, b.half.z)) + 0.3, 0)
	b.launch(from - b.global_basis * b.center, (target - from) / ATTACK_FLIGHT + Vector3(0, 4.9 * ATTACK_FLIGHT, 0),
		Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5)))
	_attack = {"t": ATTACK_FLIGHT, "pos": target, "pid": b.pid}
	host_ev("sfx", ["roar", monster.global_position])
	host_ev("toast", ["%s の技！ %s が飛んだ" % [monster.label, b.label], 0])
	return true


# 見立てた爆発：煙と音だけ。本番なら順序を確かめて数える
func _soft_burst(pos: Vector3, src: int) -> void:
	var counted := true
	if state == S.TAKE:
		counted = judge.on_burst(pos, src)
	host_ev("burst", [pos, 0.0])
	host_ev("sfx", ["explosion", pos])
	if state == S.TAKE:
		if not counted:
			host_ev("toast", ["怪獣が映る前に技を出した！（順序が違う）" if judge.story == "kaiju" else "告白が撮れる前に爆発した！（順序が違う）", 1])
		for a: CharacterBody3D in actors:
			if a.global_position.distance_to(pos) < 9.0:
				a.knock(Vector3(0, 3.2, 0))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_sync_cast_dress()
	if Net.is_host() and not _attack.is_empty():
		_attack["t"] = float(_attack["t"]) - delta
		if float(_attack["t"]) <= 0.0:
			var hit: Dictionary = _attack
			_attack = {}
			if state in [S.PREP, S.TAKE]:
				_soft_burst(hit["pos"], int(hit["pid"]))


# 見立ての役の名前：飾りだけだと分かりにくい役もあるので、準備中は物の上に小さく「怪獣役」と出す。
# 制作班にだけ見える（撮影カメラには映らない）。らしさの★は出さない（上映会で分かる）。本番・見返しの間は出さない
func _sync_cast_names() -> void:
	var want := {}
	var me: Node = local_player()
	if me != null and production != null and production.phase in [2, 4] and state == S.PREP and menu_open == "":
		for pid: int in production.casting:
			var prop: Node = props.get(pid)
			if prop == null or prop.absent or prop.global_position.distance_to(me.global_position) > 26.0:
				continue
			var role: String = production.role_of(prop)
			if role != "":
				want[pid] = role
	for pid: int in _cast_names.keys():
		if not want.has(pid):
			(_cast_names[pid] as Node).queue_free()
			_cast_names.erase(pid)
	for pid: int in want:
		var prop: Node3D = props[pid]
		var name_tag: Label3D = _cast_names.get(pid)
		if name_tag == null:
			name_tag = Label3D.new()
			name_tag.font = ProductionHud.UI.fnt("bold")
			name_tag.font_size = 26
			name_tag.fixed_size = true
			name_tag.pixel_size = 0.0011
			name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			name_tag.modulate = Color("f4f1ea")
			name_tag.outline_modulate = Color(0, 0, 0, 0.8)
			name_tag.outline_size = 10
			name_tag.layers = Stage.FilmCamera.CREW_LAYER
			add_child(name_tag)
			_cast_names[pid] = name_tag
		name_tag.text = Flow.Cast.role_title(want[pid], production.story())
		name_tag.global_position = prop.center_global() + Vector3(0, maxf(prop.half.y, 0.2) + 0.3, 0)


# 見立ての飾り：自分たちで役を決めた物に、その役らしい飾り（目玉・旗・炎・窓 など）を付ける。映画にも映る（cast_dress.gd）。
# 飾りは物の当たり判定の表面に貼るので、物が世界にあって当たり判定がある間に作る（箱の中にしまった物は、出てきてから）
func _sync_cast_dress() -> void:
	var want := {}
	if production != null:
		for pid: int in production.casting:
			var prop: Node = props.get(pid)
			if prop == null or prop.absent:
				continue
			var role: String = production.role_of(prop)
			if role != "":
				want[pid] = role
	for pid: int in _cast_dress.keys():
		var dress: Node = _cast_dress[pid]
		if not want.has(pid) or not is_instance_valid(dress) or dress.role != want[pid] or dress.grade != production.cast_fit(props[pid], want[pid]) or dress.face != int(production.cast_face.get(pid, 0)):
			if is_instance_valid(dress):
				dress.queue_free()
			_cast_dress.erase(pid)
	for pid: int in want:
		var prop: Node3D = props[pid]
		if _cast_dress.has(pid) or prop.collision_layer == 0:
			continue
		var dress := CastDress.new()
		dress.name = "CastDress"
		prop.add_child(dress)
		dress.build(prop, want[pid], production.cast_fit(prop, want[pid]), font, pid, int(production.cast_face.get(pid, 0)))
		_cast_dress[pid] = dress


# 物のどの側が、その位置から見えている側か（0 = 物の +z、1 = +x、2 = -z、3 = -x。外形の大きさで割って比べる）
func cast_face_side(prop: Node3D, from: Vector3) -> int:
	var d: Vector3 = prop.global_transform.affine_inverse() * from - prop.center
	var nx: float = d.x / maxf(prop.half.x, 0.05)
	var nz: float = d.z / maxf(prop.half.z, 0.05)
	if absf(nx) > absf(nz):
		return 1 if nx > 0.0 else 3
	return 0 if nz > 0.0 else 2


@rpc("any_peer","call_local","reliable")
func h_load_truck(pid: int) -> void:
	if not Net.is_host() or not production or production.phase != 2:
		return
	var me: Node = players.get(Net.sender())
	var prop: Node = props.get(pid)
	if me == null or prop == null or prop.holder != Net.sender() or me.global_position.distance_to(Flow.HOME_TRUCK) > 4.5:
		return
	if not host_load(prop,truck):
		host_ev("toast",["荷台に置ける場所が無い（床がふさがっているか、物が大きすぎる）。右ドラッグで向きを変えるか、荷物を降ろそう。左クリックなら、手で好きな所に積める",1])
		return
	var bed: Dictionary = production.bed_load()
	if overhangs(prop, truck):
		host_ev("toast",["%s を積んだ。荷台より大きいので、側板に載せただけ。ロープでしばらないと、道中で落ちやすい（ロープは段ボール置き場）" % prop.label,1])
	elif pid in bed["risky"]:
		host_ev("toast",["%s を積んだ。荷台からはみ出している（%d / %d）。道中で落ちるかも" % [prop.label, bed["used"], bed["cap"]],1])
	else:
		host_ev("toast",["%s を積んだ（荷台 %d / %d）" % [prop.label, bed["used"], bed["cap"]],0])

@rpc("any_peer","call_local","reliable")
func h_prop_action(pid: int) -> void:
	if not Net.is_host() or not production or production.phase not in [0,2,4] or replaying:
		return
	var me: Node = players.get(Net.sender())
	var prop: Node = props.get(pid)
	if me == null or prop == null or prop.absent or not is_action_prop(prop) or prop.holder not in [0,Net.sender()]:
		return
	if prop.holder != Net.sender() and me.reach_base().distance_to(prop.center_global()) > Player.REACH:
		return
	if _topples(prop):
		if prop.holder != 0:
			host_release(prop)
		if prop.rider_of != 0:
			host_unload(prop)
		var upright: bool = prop.global_basis.y.y >= 0.6
		var away: Vector3 = prop.global_position - me.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		var yaw := atan2(away.x, away.z)
		if upright:
			# 押した人から見て向こう側へ、ばったり倒れる
			var lying := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, PI * 0.5)
			prop.restore([prop.global_position + Vector3(0, maxf(prop.half.x, prop.half.z) + 0.05, 0), lying, false])
		else:
			prop.restore([Vector3(prop.global_position.x, prop.global_position.y + 0.05, prop.global_position.z), Quaternion(Vector3.UP, yaw), false])
		host_ev("sfx",["thump",prop.global_position])
		if crew_skills != null and state == S.TAKE and crew_skills.visible_prop(prop):
			crew_skills.mark(Net.sender(), "backstage", "effects")
		return
	host_ev("production_prop",[pid,not prop.active])
	host_ev("sfx",["thump",prop.global_position])

@rpc("authority","call_local","reliable")
func ev(n: String, a: Array) -> void:
	if n == "dash_dust" and a.size() >= 5:
		_spawn_dash_dust(a[0], a[1], a[3], 1.0, int(a[2]) >= 0, int(a[4]))
	elif n == "crew_crafts":
		if crew_skills != null: crew_skills.receive_crafts(a[0])
	elif n == "cast_toast":
		hud.show_toast(a[1] if reads_script() else a[0], Hud.YELLOW)
	elif n == "script_toast":
		if reads_script():
			hud.show_toast(a[0], Hud.YELLOW)
			Sfx.play("ui_ok")
	elif n == "perform":
		if players.has(a[0]):
			CrewSkills.Reactions.ensure(players[a[0]].vis)
			players[a[0]].start_performance(a[1])
	elif n == "stage_fx":
		if performance != null:
			performance.show_effect(a)
	elif n == "stash":
		if production:
			production.apply_stash(a[0])
	elif n == "production_prop":
		if props.has(a[0]) and props[a[0]].has_method("set_active"):
			props[a[0]].set_active(a[1])
	elif hooks.event(n, a):
		# 仕組みの合図（箱とロープ・爆弾の道具・ロープをつかむ・特技・場面の進み など）は、持ち主へ渡した
		pass
	elif n == "met" and beats != null and beats.active():
		# 場面の列を持つ依頼：「OK！」の知らせは、場面を進められる人にだけ（ほかの人は、モニターの枠のランプで知る）
		if directs():
			hud.show_toast("%s　OK！" % scene_titles()[a[0]], Hud.GREEN, 2.0)
			Sfx.play("ui_ok")
	else:
		super.ev(n,a)
		if n == "absent" and beats != null:
			beats.refresh()
		if n == "state" and camera_switcher != null:
			camera_switcher.state_changed()
			if monitor_popup != null: monitor_popup.state_changed()
		if n == "absent" and production:
			production.apply_stash(production.stash)
		if n == "state" and production_export != null:
			production_export.replay_state_changed(state)
		if n == "state" and performance != null:
			performance.state_changed()
		if n == "state" and crew_skills != null:
			crew_skills.replay_changed()
		# 中心の合図（absent・burst・state など）を、聞きたい仕組みへ知らせる（各仕組みの hook_core_event）
		hooks.run("hook_core_event", [n, a])


func host_ev(n: String, a: Array) -> void:
	if crew_skills != null:
		crew_skills.observe_event(n, a, Net.sender())
		if n == "dash_dust":
			a = a.duplicate()
			a.append(crew_skills.run_style(Net.sender()))
			a.append(Net.sender())
	super.host_ev(n, a)


@rpc("any_peer", "call_local", "unreliable_ordered")
func h_aim(pid: int, a: float, b: float, c: float) -> void:
	super.h_aim(pid, a, b, c)
	var prop: Node = props.get(pid)
	if crew_skills != null and prop != null and "operator" in prop and prop.operator == Net.sender() and is_finite(a) and is_finite(b) and is_finite(c) and absf(a) + absf(b) + absf(c) > 0.0001:
		crew_skills.aimed(Net.sender(), prop)


@rpc("any_peer", "call_local", "unreliable_ordered")
func h_dolly(pid: int, direction: Vector3) -> void:
	super.h_dolly(pid, direction)
	var camera: Node = props.get(pid)
	if crew_skills != null and camera != null and camera.kind == "camera" and camera.operator == Net.sender() and direction.is_finite() and direction.length_squared() > 0.01:
		crew_skills.aimed(Net.sender(), camera)


func host_load(prop: RigidBody3D, carrier: RigidBody3D, stack: bool = true) -> bool:
	var who: int = prop.holder
	var loaded := super.host_load(prop, carrier, stack)
	if loaded and crew_skills != null and carrier == truck:
		crew_skills.note_prop(who, prop.pid, "cargo")
	return loaded

func ui_blocking() -> bool:
	return super.ui_blocking() or (director != null and director.peeping()) or (cue_cards != null and cue_cards.editor.opened) or menu_open != "" or (performance != null and performance.opened) or (monitor_popup != null and monitor_popup.opened)

@rpc("any_peer","call_local","reliable")
func h_perform(clip: String) -> void:
	if Net.is_host() and performance != null:
		performance.accept_act(Net.sender(),clip)

@rpc("any_peer","call_local","reliable")
func h_stage_fx(id: String, origin: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> void:
	if Net.is_host() and performance != null:
		performance.accept_fx(Net.sender(),id,origin,direction)

@rpc("any_peer","call_local","reliable")
func h_accept_job(index: int) -> void:
	if Net.is_host() and production:
		var before: int = production.phase
		if talent != null and before == 0:
			talent.host_clear_all()      # 頭の道具箱の中身は、次の依頼へ持ち越さない
		production.accept(index)
		if before == 0 and production.phase != 0 and crew_skills != null:
			crew_skills.begin_job()

@rpc("any_peer","call_local","reliable")
func h_buy_upgrade(id: String) -> void:
	if Net.is_host() and production and production.phase in [0, 1, 2]:
		production.buy(id)

# 発注の画面を開く（机の電話・レンタルのカウンターで F）。開くのは、頼んだ人の画面だけ
@rpc("any_peer","call_local","reliable")
func h_open_order() -> void:
	if Net.is_host() and production:
		production.open_order(Net.sender())


# 発注の画面を、決めずに閉じる（Esc・右クリック・「閉じる」）
@rpc("any_peer","call_local","reliable")
func h_order_close() -> void:
	if Net.is_host() and production:
		production.close_order(Net.sender())

# のぞき箱を使い始める・やめる。一度にのぞけるのは1人（production_flow.gd の peep）
@rpc("any_peer","call_local","reliable")
func h_peep(on: bool) -> void:
	if Net.is_host() and production:
		production.peep(Net.sender(), on)


# 誰かが抜けた：その人が使っていた机の物を空ける
func _on_peer_left(id: int) -> void:
	super._on_peer_left(id)
	if Net.is_host() and production:
		production.crew_left(id)


@rpc("any_peer","call_local","reliable")
func h_depart() -> void:
	if Net.is_host() and production:
		production.depart()

@rpc("any_peer","call_local","reliable")
func h_return_office() -> void:
	if Net.is_host() and production:
		production.return_office()

@rpc("any_peer", "call_remote", "reliable")
func h_hello() -> void:
	super.h_hello()
	if cue_cards != null: cue_cards.sync_to(Net.sender())
	if talent != null: talent.sync_to(Net.sender())
	if Net.is_host() and production:
		h_production_hello()

@rpc("any_peer","call_remote","reliable")
func h_production_hello() -> void:
	if Net.is_host() and production:
		production_sync.rpc_id(Net.sender(),production.snapshot())
		if camera_switcher != null:
			camera_switcher.receive.rpc_id(Net.sender(),camera_switcher.state())
		ev.rpc_id(Net.sender(),"stash",[production.stash])
		# 各仕組みの今の状態（箱とロープ → 爆弾の道具 → 場面の進み → ロープをつかむ。各仕組みの hook_sync）
		hooks.run("hook_sync", [Net.sender()])
		var point: Vector3 = Flow.HOME_TRUCK + Vector3(-3,0.1,1) if production.phase in [2,3] else (SPAWN if production.phase in [4,5] else Flow.Office.SPAWN_POINT)
		point = _open_join_point(point,Net.sender())
		production_move.rpc(point,0.0,Net.sender(),_crew_epoch)


func _open_join_point(base: Vector3, joining: int) -> Vector3:
	# 途中参加でIDの並びが変わっても、既に立っている仲間を押さない。
	for offset in [Vector3.ZERO,Vector3(-1.2,0,0),Vector3(1.2,0,0),Vector3(0,0,1.2),Vector3(-1.2,0,1.2),Vector3(1.2,0,1.2)]:
		var point: Vector3 = base + offset
		var occupied := false
		for peer_id in players:
			if peer_id == joining: continue
			var other: Vector3 = players[peer_id].global_position
			if Vector2(other.x-point.x,other.z-point.z).length() < 0.8:
				occupied = true
				break
		if not occupied: return point
	return base

@rpc("authority","call_local","reliable")
func production_sync(data: Dictionary) -> void:
	if production:
		production.apply(data)

@rpc("authority","call_local","reliable")
func production_move(point: Vector3, yaw: float, only_peer: int = 0, epoch: int = -1) -> void:
	if epoch >= 0:
		_crew_epoch = epoch
	# 接続順によるDictionaryの並びの違いで、仲間と同じ場所に出ないようにする。
	var member_ids := players.keys()
	member_ids.sort()
	for i in member_ids.size():
		var player: Node = players[member_ids[i]]
		if only_peer != 0 and player.peer_id != only_peer:
			continue
		player._net.clear()
		player.global_position = point if only_peer != 0 else point + Vector3(float(i)*0.8,0,0)
		player.velocity = Vector3.ZERO
		player.aim_yaw = yaw
		player.vis.rotation.y = yaw + PI
		player.aim_pitch = -0.18
		player._motion = ""
		player._run_requested = false
		player.vis.play("idle",0.0,true)


func move_crew(point: Vector3, yaw: float, only_peer: int = 0) -> void:
	_crew_epoch += 1
	production_move.rpc(point,yaw,only_peer,_crew_epoch)


func send_player_state(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	if _legacy_mode:
		super.send_player_state(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name)
	else:
		rx_production_player.rpc(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name,_crew_epoch)


@rpc("any_peer","call_remote","unreliable_ordered")
func rx_production_player(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String, epoch: int) -> void:
	# 車移動前の遅延パケットを到着後のプレイヤー位置へ適用しない。
	if epoch == _crew_epoch:
		super.rx_player(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name)

@rpc("any_peer","call_local","reliable")
func h_order_set(id: String, count: int) -> void:
	super.h_order_set(id,count)

@rpc("any_peer","call_local","reliable")
func h_order_buy(id: String, on: bool) -> void:
	super.h_order_buy(id,on)

# 買って会社の持ち物になった物か
func owns(id: String) -> bool:
	return production != null and production.owned.has(id)

# 買えるのは、くり返し使える物だけ（使い切りの物は、数を選んで制作費で買う）
func can_buy(opt: Dictionary) -> bool:
	return production != null and bool(opt.get("buy",false)) and not opt.get("used_up",false)

# 借り物と使い切りの物は、依頼主の制作費の中だけ。買う物は、会社の貯金の中だけ
func order_budget() -> int:
	return int(production.budget()) if production else super.order_budget()

func order_savings() -> int:
	return int(production.wallet) if production else super.order_savings()

func _budget_short() -> String:
	return "制作費が足りない（この依頼は %d コインまで）。廃材は無料で使える" % order_budget() if production else super._budget_short()

# 火薬の袋は全部で5つ。持ち越した袋と、爆弾に付いてくる袋のぶん、買い足せる数が減る
func order_max(opt: Dictionary, o: Dictionary = order, b: Dictionary = buying) -> int:
	if production != null and bomb_kit != null and opt["id"] == "refill":
		var with_bomb := 1 if (int(o.get("fx",0)) > 0 or b.has("fx") or "fx" in production.bought_now) else 0
		return clampi(bomb_kit.SACKS - production.sack_stock.size() - with_bomb,0,int(opt["max"]))
	return super.order_max(opt,o,b)

@rpc("any_peer","call_local","reliable")
func h_order_confirm() -> void:
	if production == null:
		super.h_order_confirm()
	elif Net.is_host():
		host_confirm_order(Net.sender())


# 注文を決める（ホスト）。who：決めようとした人。
# 決められるのは、発注の画面を開いている人だけ。全体の段階は変えない（ほかの人は準備を続けている）
func host_confirm_order(who: int) -> void:
	if not may_order(who) or order_cost() > production.budget() or savings_cost() > production.wallet:
		return
	# 買った物を会社の持ち物にする（物を届ける前に）
	production.purchase()
	_deliver_order()
	host_ev("sfx", ["ui_ok", null])
	production.pack()


# 注文を決めたとき（ホスト）：変わった分だけを反映する。発注は、ほかの人の準備を止めない。
#   ・やめた物　　　：手・操作・荷台・接着から外して、片づける（載せてあった物は、その場に残す）
#   ・新しく頼んだ物：届く場所（軽トラの荷台・軽トラの横）に置く
#   ・前から在る物　：触らない（ほかの人が持っている物・接着・もう運んだ借り物は、そのまま）
# 依頼を受けたとき・事務所へ戻ったときは、今までどおり全部を並べ直す（_apply_order）
func _deliver_order() -> void:
	var was := {}                   # 決める前に出ていた物（物のID → true）
	for p: RigidBody3D in props.values():
		if not p.absent:
			was[p.pid] = true
	ev.rpc("absent", [_absent_kinds()])
	var gone: Array = []            # 今回、片づけた物（物のID）
	var came: Array = []            # 今回、届いた物
	for pid: int in props:
		var p: RigidBody3D = props[pid]
		if not p.absent:
			if not was.has(pid):
				came.append(p)
			continue
		if was.has(pid):
			gone.append(pid)
			if p.holder != 0:
				host_release(p)
			if "operator" in p and p.operator != 0:
				_stop_operating(p)
		if p.rider_of != 0:
			host_unload(p)
		p.linear_velocity = Vector3.ZERO
		p.angular_velocity = Vector3.ZERO
		p.global_position = Vector3(float(p.pid) * 3.0, -60.0, 0.0)
	# 片づけた物に載せてあった物（返した台車の上の荷物）は、その場に降ろす
	for q: RigidBody3D in props.values():
		if q.rider_of in gone:
			host_unload(q)
	adhesive.forget(gone)
	_delivering_more = true
	_place_deliveries(came)
	_delivering_more = false
	if bomb_kit != null:
		bomb_kit.host_order_changed(was)


# 荷台の決まった場所に載せる。発注をやり直して届いた物は、そこに先客（もう積んだ荷物）がいたら、
# 荷台の空いた所を探す。それも無ければ、軽トラの横に置く
func _deliver_to_bed(p: RigidBody3D, local: Transform3D) -> void:
	super._deliver_to_bed(p, local)
	if not _delivering_more:
		return
	var to_deck: Transform3D = truck.global_transform.affine_inverse()
	var mine: AABB = (local * body_bounds(p)).grow(0.02)
	var taken := false
	for r: RigidBody3D in props.values():
		if r != p and not r.absent and r.rider_of == truck.pid and mine.intersects((to_deck * r.global_transform) * body_bounds(r)):
			taken = true
	if taken and not host_load(p, truck, false):
		host_unload(p)
		p.restore([Flow.HOME_TRUCK + Vector3(-2.6 - 0.7 * float(_beside), 0.05, -1.7), Quaternion.IDENTITY, false])
		_beside = (_beside + 1) % 4

func _take_or_cut(who: int) -> void:
	if production and (production.phase != 4 or production.expired):
		ev.rpc_id(who,"toast",["撮影は現場に着いてから。期限後は撮れたテイクを納品しよう",1])
		return
	if state == S.PREP:
		# 各仕組みの hook_take_ready：箱の中身を覚える（撮り直しで戻す）・通し稽古を終える（役者は最初の印へ戻る）
		hooks.run("hook_take_ready")
	super._take_or_cut(who)


# 撮り直し：箱の中身を、テイクを始める前に戻してから、物の置き場所を戻す（各仕組みの hook_retake・hook_retake_done）
func _back_to_prep() -> void:
	hooks.run("hook_retake")
	super._back_to_prep()
	hooks.run("hook_retake_done")


# 見返し：箱の中身などは記録どおりに見せ、終わったら今の中身へ戻す（各仕組みの hook_playback）。
# 始まりは 箱とロープ → 爆弾 → 場面の進み、終わりは 場面の進み → 箱とロープ → 爆弾 の順（feature_hooks.gd の ORDERS）
func _set_playback(on: bool) -> void:
	if on:
		hooks.run("hook_playback", [true])
	super._set_playback(on)
	if not on:
		hooks.run("hook_playback", [false], "hook_playback:off")


# 仕組みが「持てない」と言う物（ロープがしっかり押さえている物は、引っぱっても抜けない。各仕組みの hook_grab_block）
func grab_block(p: Node) -> String:
	var why: String = hooks.first_text("hook_grab_block", [p])
	return why if why != "" else super.grab_block(p)

func _begin_take() -> void:
	if production:
		production.notes.reset()
		production.bonus_progress = ""
	super._begin_take()
	if crew_skills != null:
		_rec_events.append([0.0, "crew_crafts", [crew_skills.crafts.duplicate()]])
	# 各仕組みの hook_take_start：見返しの最初に流す知らせ（撮り始めたときの箱の中身・導火線）を足す。場面は最初から
	hooks.run("hook_take_start")

func _cut() -> void:
	var extras := {}
	if production:
		extras = production.notes.finish(str(production.job()["bonus"]),takes.size(),judge.passed())
	if beats != null and beats.active() and state == S.TAKE and take_t >= take_limit() - 0.001:
		# フィルムが最後まで回った
		host_ev("sfx", ["unfix", program_camera().global_position])
		host_ev("toast", ["フィルムが切れた！", 1])
	super._cut()
	hooks.run("hook_take_cut")
	if production:
		takes[-1]["extras"] = extras
		host_ev("takes",[takes,selected])
	if crew_skills != null: crew_skills.publish_preview()

@rpc("any_peer","call_local","reliable")
func h_retake() -> void:
	if production and production.expired:
		return
	super.h_retake()

# 画面（ボタン・Enter）から納品を頼む。試写会など、納品の前に流す仕組みがあれば、そちらが先（各仕組みの hook_deliver）。
# 自動確認などが h_deliver を直接呼ぶと、今までどおり、すぐ納品になる
func request_deliver(index: int) -> void:
	h_request_deliver.rpc_id(1, index)

@rpc("any_peer","call_local","reliable")
func h_request_deliver(index: int) -> void:
	if not Net.is_host() or state != S.RESULT:
		return
	if production and hooks.first("hook_deliver", [index]):
		return
	h_deliver(index)

@rpc("any_peer","call_local","reliable")
func h_deliver(index: int) -> void:
	var valid := Net.is_host() and state == S.RESULT and index >= 0 and index < takes.size()
	super.h_deliver(index)
	if production and valid:
		if crew_skills != null: crew_skills.finish_job()
		production.settle(index)

@rpc("any_peer","call_local","reliable")
func h_next() -> void:
	if production:
		if Net.is_host():
			production.return_office()
	else:
		super.h_next()

func scene_titles() -> Array:
	return production.job()["scenes"] if production else super.scene_titles()


func cue_names() -> Array:
	if beats != null and beats.active():
		if beats.cut_mode() and state == S.TAKE:
			# カット割りの依頼の本番：回している間は「カット」、止めている間（場転）は「回す」
			return ["回す（アクション）", "回す（アクション）"] if beats.holding else ["カット（場転へ）", "この場面をもう一度"]
		return ["次の場面へ", "この場面をもう一度"]
	return ["驚く", "爆発", "勝利"] if production and production.job()["script"] == "kaiju" else super.cue_names()


func film_title() -> String:
	if production and bool(production.job().get("debut", false)) and str(production.company) != "":
		return "%s 紹介動画" % production.company_name()       # 会社の名前を決めたら、紹介動画の題もその名前で
	return str(production.job()["title"]) if production else super.film_title()


func _order_bbcode() -> String:
	var text := super._order_bbcode()
	if production:
		text = text.replace("この内容で現場へ","この内容で借りる")
		text = "[b]" + production.job()["title"] + "[/b]　／　" + production.location_name() + "\n制作費 %d コイン　（使い残しは会社の儲け）\n追加注文 +150コイン：" % production.budget() + str(production.job()["bonus_title"]) + "\n\n" + text
	return text

func panel_bbcode() -> String:
	var text := super.panel_bbcode()
	if crew_skills != null and state == S.RESULT:
		text += "\n\n[b]今回の成長（納品で確定・NGも対象）[/b]\n" + crew_skills.growth_text(false)
	if production and state == S.RESULT and not takes.is_empty():
		var comments: Array[String] = production.notes.observations(takes[selected].get("extras",{}))
		if not comments.is_empty():
			text = text.replace("[color=#ffdb59][R][/color]", "[color=#efbf6b]NG日誌[/color]\n" + "\n".join(comments) + "\n\n[color=#ffdb59][R][/color]")
	if production and state == S.RESULT and not takes.is_empty():
		text += "\n[color=#ffdb59][P][/color] 見返して8コマ保存（画像・一覧PNG）\n保存先：ユーザーデータの film_stills フォルダ"
		if production_export != null and not production_export.last_saved.is_empty():
			text += "\n[color=#ffdb59][O][/color] 保存した8コマのフォルダを開く"
	if production and production.expired and state == S.RESULT and takes.size() < MAX_TAKES:
		text = text.replace("[color=#ffdb59][Space][/color] 撮り直す（あと%d回）" % (MAX_TAKES-takes.size()),"借り時間終了・撮り直し不可")
	return text


func set_character_menu(on: bool) -> void:
	super.set_character_menu(on)
	if production:
		hud.root.visible = true

@rpc("any_peer","call_local","reliable")
func h_sample() -> void:
	if production and "--productiontest" not in OS.get_cmdline_user_args():
		ev.rpc_id(Net.sender(),"toast",["見本セットは撮影だけモードで確認できる。現場では持ち込んだ道具で作ろう",0])
		return
	super.h_sample()


func _unhandled_input(event: InputEvent) -> void:
	if production and production.phase == 0 and menu_open == "board" and not character_open and not help_open and event is InputEventKey and event.pressed and not event.echo:
		var offered: Array = production.offered()
		var pick: int = event.physical_keycode - KEY_1
		if pick >= 0 and pick < offered.size():
			open_brief(int(offered[pick]))
			return
	# 場面の列を持つ依頼：1＝次の場面へ / 2＝今の場面をもう一度（3 は使わない）。進められるのは、台本を読める人だけ（ホストが確かめる）
	if production and beats != null and beats.active() and production.phase == 4 and state in [S.PREP, S.TAKE] and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_1, KEY_2, KEY_3] and not ui_blocking():
		if event.physical_keycode != KEY_3:
			h_beat.rpc_id(1, 1 if event.physical_keycode == KEY_1 else 2)
		return
	# 確認の画面の Enter（納品）：試写会を通す（request_deliver）
	if production and state == S.RESULT and not character_open and not help_open and not input_locked and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		request_deliver(selected)
		return
	# 爆弾は合図キーでは鳴らない（そばで F を押して点火する）
	if production and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_2 and state in [S.PREP, S.TAKE] and not ui_blocking() and bomb_armed():
		hud.show_toast("爆弾は合図では鳴らない。導火線の先を見て F で火を付ける", Hud.YELLOW)
		return
	super._unhandled_input(event)
	if production:
		hud.root.visible = true


func _ping_phase_allowed() -> bool:
	return production != null and production.phase in [0,2,4] and state in [S.PREP,S.COUNTDOWN,S.TAKE] and not replaying and not production.expired


@rpc("any_peer","call_local","reliable")
func h_ping(from: Vector3, direction: Vector3) -> void:
	if not Net.is_host() or production_ping == null or not _ping_phase_allowed():
		return
	var who := Net.sender()
	var player: Node = players.get(who)
	if player == null or not from.is_finite() or not direction.is_finite() or direction.length_squared() < 0.9 or direction.length_squared() > 1.1:
		return
	# のぞき箱をのぞいている人・発注の画面を開いている人は、現物が見えていない。指し示すことはできない
	if who == production.peeper or who == production.orderer:
		return
	var op: Node = props.get(player.operating)
	var origin: Vector3 = op.lens.global_position if op != null and op.kind == "camera" else player.global_position + Vector3(0,1.85,0)
	if origin.distance_to(from) > 6.0:
		return
	var now := Time.get_ticks_msec()/1000.0
	if now - float(_ping_last.get(who,-10.0)) < 0.7:
		return
	var query := PhysicsRayQueryParameters3D.create(from,from+direction.normalized()*30.0,1|2|4|16)
	var excluded: Array[RID] = [player.get_rid()]
	if player.held != 0 and props.has(player.held):
		excluded.append(props[player.held].get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_ping_last[who] = now
	var name_of_sender := "制作班"
	for member: Array in _roster:
		if member[0] == who:
			name_of_sender = PLAYER_NAMES[member[1]]
			break
	var item_name := "ここ！"
	var collider: Object = hit["collider"]
	if collider is Node and "pid" in collider and props.has(collider.pid):
		item_name = collider.label
	production_ping_event.rpc(who,hit["position"],name_of_sender+"："+item_name)


@rpc("authority","call_local","reliable")
func production_ping_event(sender: int, point: Vector3, text: String) -> void:
	if production_ping != null:
		production_ping.show_ping(sender,point,text)


@rpc("any_peer","call_local","reliable")
func h_export_replay(index: int, token: int) -> void:
	if not Net.is_host():
		return
	var who := Net.sender()
	var allowed: bool = production != null and production.phase == 4 and players.has(who) and state == S.RESULT and index >= 0 and index < _take_data.size()
	if allowed:
		allowed = (_take_data[index]["frames"] as Array).size() >= 2
	if allowed:
		super.h_replay(index)
		allowed = state == S.REPLAY
	export_ready.rpc_id(who,allowed,token)


@rpc("authority","call_local","reliable")
func export_ready(success: bool, token: int) -> void:
	if production_export != null:
		production_export.accept_reply(success,token)
