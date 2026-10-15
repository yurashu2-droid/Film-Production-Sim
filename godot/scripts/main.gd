extends Node3D
# 進行の中心。P2P（参加者の1人がホスト）方式が前提。
#   act_*  : 各参加者が押した操作。ホストへ依頼として送るだけ
#   h_*    : ホストが依頼を受けて実行する
#   ev     : ホストから全員への知らせ（音・状態・演出）
# ソロは「相手のいないホスト」なので、同じ経路をそのまま通る。

const Stage := preload("res://scripts/stage.gd")
const Player := preload("res://scripts/player.gd")
const Judge := preload("res://scripts/judge.gd")
const KenneyDust := preload("res://scripts/kenney_dust.gd")
const SculptedDust := preload("res://scripts/sculpted_dust.gd")
const ToonDust := preload("res://scripts/toon_dust.gd")
const VfxLib := preload("res://vfx/vfx_lib.gd")
const VfxExplosion := preload("res://vfx/vfx_explosion.gd")
# 走りの演出。先の3つは元からの土ぼこり、次の3つはアニメ調（スミア・スミア×雷・雷の疾走）、最後の2つは蹴り上げの土ぼこりと、脚ぐるぐる＋土ぼこり
const DUST_STYLES: Array[String] = ["sculpted", "mesh", "kenney", "smear", "volt", "thunder", "kick", "scramble"]
const STEP_STYLES: Array[String] = ["sculpted", "smear", "volt", "thunder", "kick", "scramble"]     # 走行中の一歩ごとにも出すもの
const RUN_FX := {
	"smear": preload("res://vfx/vfx_run_gale.gd"),
	"volt": preload("res://vfx/vfx_run_volt.gd"),
	"thunder": preload("res://vfx/vfx_run_thunder.gd"),
	"kick": preload("res://vfx/vfx_run_dust.gd"),
	"scramble": preload("res://vfx/vfx_run_scramble.gd"),
}
const Hud := preload("res://scripts/hud.gd")

const S := {"PREP": 0, "COUNTDOWN": 1, "TAKE": 2, "RESULT": 3, "REPLAY": 4, "DELIVERED": 5, "ORDER": 6}
const TAKE_SEC := 60.0
const MAX_TAKES := 3
const REWARD := 1200
const PLAYER_CASTS := ["M02", "04", "09", "03", "01", "02", "06"]
const PLAYER_NAMES := ["ロボット", "ベレー帽の人", "段ボール頭", "手帳の人", "ドレスの人", "カエルの警官", "モップの王様"]
# 見返し（録画）に載せる合図。仕組みの合図は、ここではなく、各仕組みの hook_rec_events() に書く（feature_hooks.gd）
const REC_EVENTS := ["sfx", "music", "burst", "fuse", "pop", "carton", "dash_dust", "stage_fx", "perform", "camera_program"]
const SPAWN := Vector3(9.5, 0.1, 6.5)     # 搬入口の前
# F で荷台に積むとき
const LOAD_HIGH := 0.9       # 物の底が、荷台の床からこの高さ以上になる置き方はしない（背の高い物の上に載ると、すぐ落ちる）
const LOAD_EDGE := 0.03      # 荷台のふち（側板・前の壁）からの余白
const LOAD_GRID := 0.2       # 空き場所を探すときの刻み
const BUDGET := 600
# 買う値段は、借りる値段の何倍か（買った物は会社の持ち物になり、次の依頼からは発注しなくても最初から在る）
const BUY_TIMES := 4
# 軽トラに積んでもらう物（借りる・買う）。値段は企画書の仮の値
#   cost：借りる値段 / rent：借りられるか / buy：買えるか / used_up：使うと減る物（買うだけ。値段は cost のまま）
const OPTIONS := [
	{"id": "balcony", "name": "借りるバルコニー一式", "desc": "バルコニーとアーチ窓の壁。置くだけで城になる", "cost": 360, "max": 1, "kinds": ["balcony", "window"], "rent": true, "buy": true},
	{"id": "fx", "name": "爆弾", "desc": "火薬の袋が1つ付く。袋から口へ注いだ量で、爆発の大きさが決まる。会社のロープをつなぐと導火線になる。つながないと、点火した瞬間に爆発する", "cost": 360, "max": 1, "kinds": ["fx"], "rent": true, "buy": true},
	{"id": "refill", "name": "火薬の袋", "desc": "袋から爆弾の口へ注ぐ。入れすぎると大爆発。こぼした粉にも火が移る（爆弾が必要）", "cost": 40, "max": 4, "kinds": [], "rent": false, "buy": true, "used_up": true},
	{"id": "dolly", "name": "台車", "desc": "荷物運びと、カメラを載せての移動撮影", "cost": 80, "max": 1, "kinds": ["dolly"], "rent": true, "buy": true},
	{"id": "fix", "name": "重り（サンドバッグ）", "desc": "12kgの重り3個。風に飛ばされにくい。載せたり接着して支える", "cost": 60, "max": 1, "kinds": ["sandbag"], "rent": true, "buy": true},
	{"id": "rose", "name": "造花（約束のバラ）", "desc": "告白の小道具。無くても撮れる", "cost": 20, "max": 1, "kinds": ["rose"], "rent": true, "buy": true},
]

var dash_dust_style := str(ProjectSettings.get_setting("vfx/dash_dust_style", "sculpted"))
var font: Font
var stage: Node3D
var hud: CanvasLayer
var judge: RefCounted

var _layout_glue := {}
var _replay_glue := {}
const FeatureHooks := preload("res://scripts/feature_hooks.gd")
var hooks: FeatureHooks = FeatureHooks.new()      # 仕組みの登録。中心の側は、ここを通して各仕組みを呼ぶ
var adhesive: Node
var talent: Node               # キャラごとの特技（cast_talent.gd）。制作モードだけ使う
var props: Dictionary = {}
var actors: Array = []
var spots: Array = []
var moons: Array = []
var players: Dictionary = {}
var film: RigidBody3D
var _program_before_replay := 0
var fx: RigidBody3D
var clapper: RigidBody3D
var truck: RigidBody3D
var booms: Array = []
var order: Dictionary = {}      # 借りた物と、使い切りの物（id → 数）
var buying: Dictionary = {}     # 今回の発注で「買う」にした物（id → 1）。発注を決めると会社の持ち物になる
var order_cursor := 0

var state: int = 0
var take_t := 0.0
var countdown_t := 0.0
var takes: Array = []            # テイクごとの結果（全員が持つ）
var selected := 0
var delivered_ok := false
var reunion_cued := false
var replaying := false
var replay_t := 0.0
# 歩ける試写会（features/premiere.gd）：見返しの間も、プレイヤーは自分の体で歩ける。
# 撮影中の班の動きは、プレイヤーの体ではなく replay_doubles（プレイヤーの番号 → 人形）に再現する
var audience := false
var replay_doubles := {}
var character_open := false
var help_open := false
var input_locked := false      # 自動確認中は手元の入力を受けない
signal startup_ready
var startup_incremental := false
var startup_complete := false
var live: Dictionary = {"hints": [], "passed": [false, false, false], "charges": 2}

var _roster: Array = []          # [参加者ID, 見た目の番号]
var _take_data: Array = []       # 見返し用の記録（ホストだけが持つ）
var _layout: Dictionary = {}
var _layout_riders: Dictionary = {}
var _rec_frames: Array = []
var _rec_events: Array = []
var _rec_t := 0.0
var _replay: Dictionary = {}
var _replay_i := 0
var _replay_ev := 0
var _sync_t := 0.0
var _full_sync := 0
var _last_sent: Dictionary = {}
var _settle_resend: Dictionary = {}     # 物のID → 止まったあと、同じ状態をあと何回送るか
const SETTLE_RESENDS := 3
var _live_t := 0.0
var _auto_cut := -1.0
var _beep := 0
var _headless := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if not _headless:
		VfxLib.warm()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Noto Sans CJK JP", "sans-serif"])
	font = sf
	_setup_input()
	_parse_args()
	judge = Judge.new()
	judge.game = self
	stage = Stage.new()
	stage.game = self
	stage.name = "Stage"
	add_child(stage)
	if startup_incremental:
		await stage.build(true)
	else:
		stage.build()
	adhesive = preload("res://scripts/adhesive.gd").new()
	adhesive.name = "Adhesive"
	adhesive.game = self
	add_child(adhesive)
	adhesive.setup()
	hooks.add("adhesive", adhesive)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	hud.build()
	if startup_incremental:
		await get_tree().process_frame
	Net.peer_left.connect(_on_peer_left)
	Net.joined_host.connect(func() -> void: h_hello.rpc_id(1))
	Net.join_failed.connect(func() -> void: hud.show_toast("ホストに接続できなかった", Hud.RED, 6.0))
	if Net.mode != "client":
		_roster = [[Net.my_id(), 0]]
		_apply_roster()
		_apply_order()
		state = S.ORDER
	if "--nettest" in OS.get_cmdline_user_args():
		var nt: Node = (load("res://tests/nettest.gd") as GDScript).new()
		nt.game = self
		input_locked = true
		add_child(nt)
		return
	if "--failtest" in OS.get_cmdline_user_args():
		var ft: Node = (load("res://tests/failtest.gd") as GDScript).new()
		ft.game = self
		input_locked = true
		add_child(ft)
		return
	if "--faceshot" in OS.get_cmdline_user_args():
		var fs: Node = (load("res://tests/faceshot.gd") as GDScript).new()
		fs.game = self
		input_locked = true
		add_child(fs)
		return
	if "--gearshot" in OS.get_cmdline_user_args():
		var gs: Node = (load("res://tests/gearshot.gd") as GDScript).new()
		gs.game = self
		input_locked = true
		add_child(gs)
		return
	if "--autotest" in OS.get_cmdline_user_args():
		var at: Node = (load("res://tests/autotest.gd") as GDScript).new()
		at.game = self
		input_locked = true
		add_child(at)
		return
	_grab_mouse(state != S.ORDER)


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--host":
			var err := Net.host()
			print("HOST ", "OK" if err == OK else "FAIL %d" % err)
		elif a.begins_with("--join"):
			var addr := a.get_slice("=", 1) if a.contains("=") else "127.0.0.1"
			Net.join(addr)
			print("JOIN ", addr)


func _setup_input() -> void:
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"run": KEY_SHIFT, "jump": KEY_SPACE, "crouch": KEY_CTRL, "operate": KEY_F, "rot_left": KEY_Q, "rot_right": KEY_E,
		"hold_upright": KEY_R, "hold_pull": KEY_G, "hold_lift": KEY_L, "talent": KEY_K}
	for n: String in keys:
		if not InputMap.has_action(n):
			InputMap.add_action(n)
			var e := InputEventKey.new()
			e.physical_keycode = keys[n]
			InputMap.action_add_event(n, e)


func _grab_mouse(on: bool) -> void:
	if _headless:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on and not character_open else Input.MOUSE_MODE_VISIBLE


func local_player() -> Node:
	return players.get(Net.my_id())

func recover_player(player: Node3D) -> void:
	player.global_position = Vector3(0,1,8)
	player.velocity = Vector3.ZERO


func ui_blocking() -> bool:
	# 歩ける試写会（audience）の見返しの間は、歩くことだけはできる（物の操作は、見返しの間はホストが受け付けない）
	return state == S.RESULT or state == S.DELIVERED or (state == S.REPLAY and not audience) or ordering() or character_open or help_open or input_locked


# 自分の画面に、発注の画面が開いているか。
# 撮影だけモードでは、全員が同時に発注する（state が ORDER の間）。
# 制作モードでは、発注を開いた人の画面にだけ開く（production_main.gd が上書きする。ゲームは止まらない）
func ordering() -> bool:
	return state == S.ORDER


# その人が、いま注文を変えられるか（ホストが確かめる）
func may_order(_who: int) -> bool:
	return state == S.ORDER


func set_character_menu(on: bool) -> void:
	if on and (state not in [S.ORDER, S.PREP] or local_player() == null):
		return
	character_open = on
	help_open = false
	hud.character_picker.set_open(on)
	_grab_mouse(not on and state == S.PREP)


# ---- 参加者 ----

@rpc("any_peer", "call_remote", "reliable")
func h_hello() -> void:
	if not Net.is_host():
		return
	var who := Net.sender()
	adhesive.sync_to(who)
	var used: Array = _roster.map(func(r: Array) -> int: return r[1])
	var idx := 0
	while idx in used:
		idx += 1
	_roster.append([who, idx % PLAYER_CASTS.size()])
	ev.rpc("roster", [_roster])
	ev.rpc_id(who, "takes", [takes, selected])
	ev.rpc_id(who, "order", [order, buying])
	ev.rpc_id(who, "absent", [_absent_kinds()])
	ev.rpc_id(who, "state", [state])
	if replaying:
		ev.rpc_id(who, "replay_casts", [_replay_casts()])
	for p: RigidBody3D in props.values():
		if p.kind == "carton":
			ev.rpc_id(who, "carton", [p.pid, p.opened])
		if p.holder != 0:
			ev.rpc_id(who, "hold", [p.holder, p.pid, _hold_snapshot(players.get(p.holder), p)])
	# 入ってきた人へ、次の同期で全部の物を送り直す（爆弾の火薬の数などが、すぐ届くように）
	_full_sync = 0
	# じかに点火した爆弾の、最後のひと溜めの最中なら、残りの秒数を知らせる（導火線の火は bomb_kit.gd が配る）
	if fx.fuse >= 0.0:
		ev.rpc_id(who, "fuse", [fx.pid, fx.fuse, fx.fuse_total])


func _on_peer_left(id: int) -> void:
	if not Net.is_host():
		return
	for p: RigidBody3D in props.values():
		if p.holder == id:
			host_release(p)
		if "operator" in p and p.operator == id:
			p.operator = 0
	_roster = _roster.filter(func(r: Array) -> bool: return r[0] != id)
	ev.rpc("roster", [_roster])


func _apply_roster() -> void:
	var ids: Array = []
	for r: Array in _roster:
		ids.append(r[0])
		if not players.has(r[0]):
			var pl: CharacterBody3D = Player.new()
			pl.game = self
			pl.peer_id = r[0]
			pl.is_local = r[0] == Net.my_id()
			pl.name = "P%d" % r[0]
			pl.setup(PLAYER_CASTS[r[1]])
			pl.position = SPAWN + Vector3(0, 0, (float(r[1]) - 1.5) * 1.3)
			pl.aim_yaw = -PI * 0.5     # 軽トラのほうを向く
			add_child(pl)
			players[r[0]] = pl
		else:
			players[r[0]].set_cast(PLAYER_CASTS[r[1]])
	for id: int in players.keys():
		if not id in ids:
			players[id].queue_free()
			players.erase(id)


@rpc("any_peer", "call_local", "reliable")
func h_select_cast(index: int) -> void:
	if not Net.is_host() or state not in [S.ORDER, S.PREP] or index < 0 or index >= PLAYER_CASTS.size():
		return
	var who := Net.sender()
	for r: Array in _roster:
		if r[0] == who:
			r[1] = index
			ev.rpc("roster", [_roster])
			return


@rpc("any_peer", "call_remote", "unreliable")
func rx_player(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	var pl: Node = players.get(multiplayer.get_remote_sender_id())
	if pl and not pl.is_local:
		pl.apply_net(pos, body_yaw, a_yaw, a_pitch, h_dist, h_yaw, h_pitch, anim_name)


# ---- 各参加者の操作（ホストへの依頼） ----

func send_player_state(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	rx_player.rpc(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name)


# 制作モードの移動・旅程パケットとは分け、既存の8引数APIを保つ。
func send_hold_controls(dist: float, yaw: float, pitch: float, offset: Vector3, roll: float, revision: int) -> void:
	rx_hold_controls.rpc(dist, yaw, pitch, offset, roll, revision)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rx_hold_controls(dist: float, yaw: float, pitch: float, offset: Vector3, roll: float, revision: int) -> void:
	var pl: Node = players.get(multiplayer.get_remote_sender_id())
	if pl != null and not pl.is_local:
		pl.apply_hold_controls(dist, yaw, pitch, offset, roll, revision)

# 持った物を回している最中か（player.hold_turning）を、ほかの人の画面とホストへ知らせる
func send_hold_turning(on: bool) -> void:
	rx_hold_turning.rpc(on)


@rpc("any_peer", "call_remote", "reliable")
func rx_hold_turning(on: bool) -> void:
	var pl: Node = players.get(multiplayer.get_remote_sender_id())
	if pl != null and not pl.is_local:
		pl.hold_turning = on


# 転がして運ぶ物を持ち上げているか（player.hold_raise）を、ほかの人の画面とホストへ知らせる
func send_hold_raise(on: bool) -> void:
	rx_hold_raise.rpc(on)


@rpc("any_peer", "call_remote", "reliable")
func rx_hold_raise(on: bool) -> void:
	var pl: Node = players.get(multiplayer.get_remote_sender_id())
	if pl != null and not pl.is_local:
		pl.hold_raise = on


# 垂れている物の「いまの向き」を、持ち方の基準に写す（ホスト）。掴んだ点の場所は変えない。
# こうしておくと、回し始めた瞬間の目標の向きが、いまの向きと同じになる
func hold_rebase(pl: Node, prop: RigidBody3D) -> void:
	var view_turn := hold_frame(prop, hold_view_anchor(pl).basis)
	var spun: Basis = view_turn * Basis.from_euler(Vector3(pl.hold_pitch, pl.hold_yaw, pl.hold_roll)) * view_turn.inverse()
	var grip: Vector3 = prop.hold_transform * prop.hold_grip_local
	var facing: Basis = (spun.inverse() * prop.global_basis).orthonormalized()
	prop.hold_transform = Transform3D(facing, grip - facing * prop.hold_grip_local)


func act_dash_dust(foot: int = -1) -> void:
	h_dash_dust.rpc_id(1, foot)


@rpc("any_peer", "call_local", "reliable")
func h_dash_dust(foot: int = -1) -> void:
	if not Net.is_host() or replaying or state not in [S.PREP, S.COUNTDOWN, S.TAKE]:
		return
	var pl: Node = players.get(Net.sender())
	if pl == null or pl.held != 0 or pl.operating != 0:
		return
	var pos: Vector3 = pl.global_position
	if foot >= 0:
		pos = pl.vis.foot_position("L" if foot == 0 else "R")
		pos.y = pl.global_position.y
	host_ev("dash_dust", [pos, pl.vis.global_basis.z.normalized(), foot])


func _show_dash_dust(pos: Vector3, direction: Vector3, foot: int = -1) -> void:
	_spawn_dash_dust(pos, direction, dash_dust_style, 1.0, foot >= 0)


func _spawn_dash_dust(pos: Vector3, direction: Vector3, style: String, size: float = 1.0, trail: bool = false, runner_id: int = 0) -> Node3D:
	if RUN_FX.has(style):
		var fx: Node3D = RUN_FX[style].new()
		add_child(fx)
		fx.global_position = pos
		fx.runner = players.get(runner_id) if players.has(runner_id) else _nearest_player(pos)
		fx.burst(direction, size, trail)
		return fx
	var dust: Node3D = SculptedDust.new() if style == "sculpted" else (KenneyDust.new() if style == "kenney" else ToonDust.new())
	add_child(dust)
	dust.global_position = pos
	if style == "sculpted":
		dust.burst(direction, size * (0.48 if trail else 1.22), trail)
	else:
		dust.burst(direction, size)
	return dust


func _nearest_player(pos: Vector3) -> Node3D:
	var best: Node3D = null
	for pl: Node3D in players.values():
		if best == null or pl.global_position.distance_squared_to(pos) < best.global_position.distance_squared_to(pos):
			best = pl
	return best


func _clear_dash_dust() -> void:
	for dust in get_tree().get_nodes_in_group("dash_dust"):
		if is_ancestor_of(dust):
			dust.queue_free()


func act_grab(pid: int, local_grip: Variant = null) -> void:
	h_grab.rpc_id(1, pid, local_grip)


func act_hold_command(command: String, amount: float = 0.0) -> void:
	h_hold_command.rpc_id(1, command, amount)


func hold_hint() -> String:
	return "左クリック 置く ／ 右ドラッグ 回す ／ Q・E 傾ける ／ ホイール 奥行き ／ R 起こす ／ G 起こして手元へ ／ N 力を抜く（垂らす）・台車は床から離す"


func act_release() -> void:
	h_release.rpc_id(1)





func act_operate(pid: int, on: bool) -> void:
	h_operate.rpc_id(1, pid, on)


func act_aim(pid: int, a: float, b: float, c: float) -> void:
	h_aim.rpc_id(1, pid, a, b, c)


func act_toggle_carton(pid: int) -> void:
	h_toggle_carton.rpc_id(1, pid)


@rpc("any_peer", "call_local", "reliable")
func h_toggle_carton(pid: int) -> void:
	if not Net.is_host() or replaying or state not in [S.PREP, S.TAKE]:
		return
	var p: Node = props.get(pid)
	var who := Net.sender()
	var pl: Node = players.get(who)
	if p == null or p.kind != "carton" or p.absent or pl == null or p.holder not in [0, who]:
		return
	if p.holder != who and pl.reach_base().distance_to(p.center_global()) > Player.REACH:
		return
	# 中身が口からはみ出している箱は、ふたが閉まらない（cargo_kit.gd）
	var kit: Variant = get("cargo_kit")
	if p.opened and kit != null and kit.lid_blocked(p):
		ev.rpc_id(who, "toast", ["中身がはみ出していて、ふたが閉まらない", 1])
		ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	host_ev("carton", [pid, not p.opened])


func act_use() -> void:
	h_use.rpc_id(1)


func act_dolly(pid: int, v: Vector3) -> void:
	h_dolly.rpc_id(1, pid, v)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).physical_keycode
	if character_open:
		hud.character_picker.handle_key(key)
		get_viewport().set_input_as_handled()
		return
	if key == KEY_C:
		set_character_menu(true)
		return
	if key == KEY_TAB:
		help_open = not help_open
		return
	if help_open:
		return
	if ordering():
		var opt: Dictionary = OPTIONS[order_cursor]
		var have: int = order.get(opt["id"], 0)
		match key:
			KEY_UP, KEY_W:
				order_cursor = posmod(order_cursor - 1, OPTIONS.size())
			KEY_DOWN, KEY_S:
				order_cursor = posmod(order_cursor + 1, OPTIONS.size())
			KEY_SPACE:
				h_order_set.rpc_id(1, opt["id"], 0 if have >= int(opt["max"]) else have + 1)
			KEY_RIGHT, KEY_D:
				h_order_set.rpc_id(1, opt["id"], have + 1)
			KEY_LEFT, KEY_A:
				h_order_set.rpc_id(1, opt["id"], have - 1)
			KEY_ENTER, KEY_KP_ENTER:
				h_order_confirm.rpc_id(1)
		return
	if state == S.RESULT:
		match key:
			KEY_ENTER, KEY_KP_ENTER:
				h_deliver.rpc_id(1, selected)
			KEY_SPACE:
				h_retake.rpc_id(1)
			KEY_R:
				h_replay.rpc_id(1, selected)
			KEY_LEFT:
				h_select.rpc_id(1, selected - 1)
			KEY_RIGHT:
				h_select.rpc_id(1, selected + 1)
	elif state == S.DELIVERED:
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			h_next.rpc_id(1)
	elif state == S.REPLAY:
		if key in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_R]:
			h_stop_replay.rpc_id(1)
	else:
		match key:
			KEY_T:
				if state == S.TAKE:
					h_take.rpc_id(1)
				else:
					hud.show_toast("カチンコを持って F で本番開始", Hud.YELLOW)
			KEY_1:
				h_cue.rpc_id(1, 1)
			KEY_2:
				h_cue.rpc_id(1, 2)
			KEY_3:
				h_cue.rpc_id(1, 3)
			KEY_B:
				h_standby.rpc_id(1)
			KEY_F9:
				h_sample.rpc_id(1)
			KEY_ESCAPE:
				_grab_mouse(false)


# ---- ホストの処理：物を持つ・積む・機材 ----

# [中心の目標, yaw, 足元の高さ, pitch, 完全なBasis, 選んだ表面点の目標]
func hold_view_anchor(pl: CharacterBody3D) -> Transform3D:
	# SpringArmの衝突によるカメラ距離変更は物を跳ねさせない。視点の基準は頭。
	var height: Vector3 = pl.head.position if pl.head != null else Vector3(0, 1.85, 0)
	return Transform3D(Basis.from_euler(Vector3(pl.aim_pitch, pl.aim_yaw, 0.0)), pl.global_position + height)


# 持った物の向きの基準：視点の向きそのまま（左右も上下も）。視点を動かすと、物も同じだけ向きを変えるので、
# 画面の中での物の向きは変わらない。倒れないようにしてある物・転がして運ぶ物は、左右の向きだけ追う
func hold_frame(prop: RigidBody3D, view: Basis) -> Basis:
	if prop.rolls or prop.axis_lock_angular_x:
		return Basis(Vector3.UP, view.get_euler().y)
	return view.orthonormalized()


func hold_target(holder: int, prop: RigidBody3D) -> Variant:
	var pl: CharacterBody3D = players.get(holder)
	if pl == null:
		return null
	if prop.hold_reference_valid:
		var anchor := hold_view_anchor(pl)
		# 自分の支持物を動かした速度を、手の目標へ循環させない。
		if not holding_support(pl, prop):
			# 掴んだ点は、視点から見た位置関係のまま視線について動く（上下にも左右にも）。
			# 物の向きも、視点と同じだけ変わる（左右も上下も）。画面の中での物の向きは変わらない。
			var grip_then: Vector3 = prop.hold_transform * prop.hold_grip_local
			var grip_now: Vector3 = anchor * (prop.hold_view_transform.affine_inverse() * grip_then)
			var turned: Basis = hold_frame(prop, anchor.basis) * hold_frame(prop, prop.hold_view_transform.basis).inverse()
			var facing: Basis = (turned * prop.hold_transform.basis).orthonormalized()
			prop.hold_transform = Transform3D(facing, grip_now - facing * prop.hold_grip_local)
		# 遠ざける・近づけるは、いま見ている向きに沿って動かす
		prop.hold_forward = -anchor.basis.z
		prop.hold_view_transform = anchor
		prop.hold_player_position = pl.global_position
		# 手で回す：視点から見たままの向き（player.gd の spin_hold）。角度3つは、視線の左右の向きを基準にした回転。
		# 体ごと向きを変えると、回した分も一緒について回る
		var view_turn := hold_frame(prop, anchor.basis)
		var basis: Basis = (view_turn * Basis.from_euler(Vector3(pl.hold_pitch, pl.hold_yaw, pl.hold_roll)) * view_turn.inverse() * prop.hold_transform.basis).orthonormalized()
		var point: Vector3 = prop.hold_transform * prop.hold_grip_local + anchor.basis * pl.hold_offset + prop.hold_forward * (pl.hold_dist - 1.6)
		var pos: Vector3 = point + basis * (prop.center - prop.hold_grip_local)
		var angles: Vector3 = basis.get_euler()
		return [pos, angles.y, pl.global_position.y, angles.x, basis, point]
	return _carry_target(pl, prop)


# 便利な手元の配置は、Gで引き寄せたときだけ使用する。
func _carry_target(pl: CharacterBody3D, prop: RigidBody3D, basis_override: Variant = null) -> Array:
	if prop.has_method("carry_target"):
		return prop.carry_target(pl)
	var fwd: Vector3 = pl.flat_forward() if prop.kind == "spot" or prop.rolls else pl.aim_forward()
	var pitch: float = 0.0 if prop.axis_lock_angular_x else pl.hold_pitch
	var basis: Basis = basis_override if basis_override is Basis else Basis.from_euler(Vector3(pitch, pl.aim_yaw + pl.hold_yaw + prop.carry_yaw, 0))
	# 手から持ち物の手前の面までを合わせる。回転しても、大きい箱が体へ入り込まない。
	var depth: float = (basis.inverse() * fwd).abs().dot(prop.half)
	var grip: Vector3 = pl.vis.grip_pos(prop.kind in pl.vis.ONE_HAND_PROPS)
	var pos: Vector3 = grip + fwd * (depth + maxf(0.0, pl.hold_dist - 1.6))
	return [pos, pl.aim_yaw + pl.hold_yaw + prop.carry_yaw, pl.global_position.y, pitch]


func holding_support(pl: CharacterBody3D, prop: RigidBody3D) -> bool:
	# ホスト上の参加者の身体は補間なので、接触一覧だけに依存しない。
	var feet: Vector3 = pl.global_position
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.12, feet - Vector3.UP * 0.32, 1 | 2 | 4)
	ray.exclude = [pl.get_rid()]
	ray.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is RigidBody3D or not "pid" in hit.collider:
		return false
	# 足元へ持ち込んだ物の内部ヒット（法線ゼロ）や側面は足場ではない。
	# ここで衝突を戻すと、体の押し出しと保持目標の追従が循環して震える。
	if hit.normal.dot(pl.up_direction) < cos(pl.floor_max_angle) or hit.position.y > feet.y + 0.03:
		return false
	var support: RigidBody3D = hit.collider
	return support == prop or (adhesive != null and adhesive.connected_to(prop.pid, support.pid))


# その物（や、接着でつながった物）の上に、誰かが立っているか
func crew_on(prop: RigidBody3D) -> bool:
	for pl: CharacterBody3D in players.values():
		if holding_support(pl, prop):
			return true
	return false


func update_hold_collision(pl: CharacterBody3D) -> void:
	if pl.held != 0:
		_hold_exception(pl, pl.held, true)


func _reset_hold_controls(pl: Node) -> void:
	if pl == null:
		return
	pl.hold_dist = 1.6
	pl.hold_yaw = 0.0
	pl.hold_pitch = 0.0
	pl.hold_roll = 0.0
	pl.hold_offset = Vector3.ZERO


func _hold_snapshot(pl: Node, prop: Node) -> Dictionary:
	if pl == null:
		return {}
	return {"transform":prop.hold_transform,"player_position":prop.hold_player_position,"forward":prop.hold_forward,
		"view_transform":prop.hold_view_transform,"grip_local":prop.hold_grip_local,
		"lifted":prop.hold_lifted,"dist":pl.hold_dist,"yaw":pl.hold_yaw,"pitch":pl.hold_pitch,
		"roll":pl.hold_roll,"offset":pl.hold_offset,"revision":pl.hold_revision}


func _apply_hold_snapshot(pl: Node, pid: int, data: Dictionary) -> void:
	_reset_hold_controls(pl)
	pl.hold_revision = int(data.get("revision", pl.hold_revision + 1))
	if pid == 0 or not props.has(pid):
		return
	var prop: Node = props[pid]
	prop.hold_transform = data.get("transform", prop.global_transform)
	prop.hold_view_transform = data.get("view_transform", hold_view_anchor(pl))
	prop.hold_grip_local = data.get("grip_local", prop.center)
	prop.hold_player_position = data.get("player_position", pl.global_position)
	prop.hold_forward = data.get("forward", pl.aim_forward())
	prop.hold_reference_valid = true
	prop.hold_lifted = data.get("lifted", false)
	pl.hold_dist = float(data.get("dist", 1.6))
	pl.hold_yaw = float(data.get("yaw", 0.0))
	pl.hold_pitch = float(data.get("pitch", 0.0))
	pl.hold_roll = float(data.get("roll", 0.0))
	pl.hold_offset = data.get("offset", Vector3.ZERO)


@rpc("any_peer", "call_local", "reliable")
func h_hold_command(command: String, amount: float = 0.0) -> void:
	if not Net.is_host() or replaying or input_locked or state not in [S.PREP, S.COUNTDOWN, S.TAKE]:
		return
	var who := Net.sender()
	var pl: CharacterBody3D = players.get(who)
	var prop := _held_by(who)
	if pl == null or prop == null or command not in ["upright", "pull", "lift"] or not is_finite(amount):
		return
	if holding_support(pl, prop):
		ev.rpc_id(who, "toast", ["自分の足場です。降りてから起こす・持ち上げる・引き寄せる", 0])
		return
	var target: Array = hold_target(who, prop)
	var basis: Basis = target[4]
	var goal := Transform3D(basis, target[0] - basis * prop.center)
	if command == "upright":
		var facing := -basis.z
		facing.y = 0.0
		var yaw: float = atan2(-facing.x, -facing.z) if facing.length_squared() > 0.001 else pl.aim_yaw
		var bounds := AABB(prop.center - prop.half, prop.half * 2.0)
		var bottom: float = (goal * bounds).position.y
		goal.basis = Basis(Vector3.UP, yaw)
		goal.origin = target[0] - goal.basis * prop.center
		goal.origin.y += bottom - (goal * bounds).position.y
	elif command == "lift":
		if prop.rolls and not prop.hold_lifted:
			goal.origin.y = prop.global_position.y
		goal.origin.y += clampf(amount, -0.25, 0.25)
		prop.hold_lifted = true
		prop.gravity_scale = 0.0
	else:
		# 従来の起こして手元へ運ぶ目標を一度だけ設定し、その後の調整を残す。
		_reset_hold_controls(pl)
		var carry: Array = _carry_target(pl, prop)
		goal.basis = Basis.from_euler(Vector3(carry[3], carry[1], 0.0))
		var forward: Vector3 = pl.flat_forward() if prop.kind == "spot" or prop.rolls else pl.aim_forward()
		var offset: Vector3 = goal.basis * (prop.hold_grip_local - prop.center)
		var point: Vector3 = carry[0] + forward * offset.dot(forward)
		goal.origin = point - goal.basis * prop.hold_grip_local
		if prop.has_method("carry_target"):
			goal.origin = carry[0] - goal.basis * prop.center
		if prop.rolls and not prop.hold_lifted:
			var bounds := AABB(prop.center - prop.half, prop.half * 2.0)
			goal.origin.y += (prop.global_transform * bounds).position.y - (goal * bounds).position.y
		else:
			goal.origin.y = maxf(goal.origin.y, pl.global_position.y + 0.03)
	prop.hold_transform = goal
	prop.hold_view_transform = hold_view_anchor(pl)
	prop.hold_player_position = pl.global_position
	_reset_hold_controls(pl)
	pl.hold_revision += 1
	host_ev("hold_adjust", [who, prop.pid, _hold_snapshot(pl, prop)])


func _held_by(who: int) -> RigidBody3D:
	for p: RigidBody3D in props.values():
		if p.holder == who:
			return p
	return null


@rpc("any_peer", "call_local", "reliable")
func h_grab(pid: int, local_grip: Variant = null) -> void:
	if not Net.is_host() or replaying or not props.has(pid):
		return
	var who := Net.sender()
	var p: RigidBody3D = props[pid]
	if local_grip != null:
		if not local_grip is Vector3 or not local_grip.is_finite():
			return
		if not AABB(p.center - p.half, p.half * 2.0).grow(0.12).has_point(local_grip):
			return
	if p.immovable or p.absent or _held_by(who) != null:
		return
	if p.holder != 0:
		# カチンコは奪い合える（持った直後の1秒は取られない）
		var now := Time.get_ticks_msec() / 1000.0
		if p.kind != "clapper" or p.holder == who or now - p.grab_time < 1.0 or state == S.COUNTDOWN:
			return
		ev.rpc_id(p.holder, "toast", ["カチンコを取られた！", 1])
		host_release(p)
	if "operator" in p and p.operator != 0:
		return
	if p.fixed:
		ev.rpc_id(who, "toast", [fixed_note(p), 0])
		return
	var stuck := grab_block(p)
	if stuck != "":
		ev.rpc_id(who, "toast", [stuck, 0])
		return
	if p.rider_of != 0:
		host_unload(p)
	p.set_holder(who, local_grip)
	p.grab_time = Time.get_ticks_msec() / 1000.0
	var pl: Node = players.get(who)
	_reset_hold_controls(pl)
	if pl != null:
		pl.hold_revision += 1
	host_ev("hold", [who, pid, _hold_snapshot(pl, p)])
	host_ev("sfx", ["pickup", p.global_position])


# 固定してある物を持とうとしたときに出す文
func fixed_note(_p: Node) -> String:
	return "動かせないセットです"


# その物を持ち上げられない理由（""＝持てる）。制作モードでは、ロープがしっかり押さえている物（production_main.gd）
func grab_block(_p: Node) -> String:
	return ""


@rpc("any_peer", "call_local", "reliable")
func h_release() -> void:
	if not Net.is_host():
		return
	var p := _held_by(Net.sender())
	if p:
		host_release(p)


func host_release(p: RigidBody3D) -> void:
	var who: int = p.holder
	p.set_holder(0)
	var pl: Node = players.get(who)
	_reset_hold_controls(pl)
	if pl != null:
		pl.hold_revision += 1
	host_ev("hold", [who, 0, {"revision":pl.hold_revision if pl != null else 0}])
	host_ev("sfx", ["drop", p.global_position])
	_try_load(p)


# 手を離した場所が荷台の上なら積載として記録する。置き方は物理に任せる。
func _try_load(p: RigidBody3D) -> void:
	if p.deck_top >= 0.0 or p.fixed or p.rider_of != 0 or p.absent:
		return
	for d: RigidBody3D in props.values():
		if d.has_method("can_board") and not d.can_board():
			continue
		if d.deck_top < 0.0 or d == p or d.absent or d.global_basis.y.y < 0.8:
			continue
		var c: Vector3 = d.global_transform.affine_inverse() * p.center_global()
		if absf(c.x - d.deck_c.x) < d.deck_half.x and absf(c.z - d.deck_c.y) < d.deck_half.y and c.y > d.deck_top - 0.25 and c.y < d.deck_top + 2.2:
			_set_rider(p, d, d.global_transform.affine_inverse() * p.global_transform)
			return


# F の補助だけが置き場所を探す。手で置くときは向きも位置も変えない。
# 持っている位置を荷台の中へ寄せて置く。そこに低い荷物があって、物の真ん中がその上に来るなら、上に積む。
# 高い所（背の高い物の上）や、荷物のふちに引っかかる置き方になるときは、近くの床の空きへ置く。
# 床の空きがどこにも無ければ積まない（false）。高く積みたいときは、手で置けばいい。
# stack が false なら、ほかの荷物の上には重ねない（届け物を置くとき。床の空きだけを探す）
func host_load(p: RigidBody3D, d: RigidBody3D, stack: bool = true) -> bool:
	var to_deck: Transform3D = d.global_transform.affine_inverse()
	var local: Transform3D = to_deck * p.global_transform
	var bounds: AABB = local * body_bounds(p)
	var offset: Vector3 = bounds.get_center() - local.origin
	var extent: Vector3 = bounds.size * 0.5
	var mx: float = maxf(d.deck_half.x - extent.x - LOAD_EDGE, 0.0)
	var mz: float = maxf(d.deck_half.y - extent.z - LOAD_EDGE, 0.0)
	var want := Vector2(clampf(bounds.get_center().x, d.deck_c.x - mx, d.deck_c.x + mx), clampf(bounds.get_center().z, d.deck_c.y - mz, d.deck_c.y + mz))
	# 先に載っている荷物の箱（荷台のローカル座標）
	var loaded: Array[AABB] = []
	for r: RigidBody3D in props.values():
		if r.rider_of == d.pid and r != p and not r.absent:
			loaded.append((to_deck * r.global_transform) * body_bounds(r))
	var height: float = _load_height(p, d, local, offset, extent, want, loaded, true) if stack else NAN
	if is_nan(height):
		# 近い順に、荷台の床の空きを探す。等間隔の点に加えて、壁ぎわと、床に置いてある荷物のすぐ隣も試す（すき間なく並ぶ）。
		# 物の大きさは決め打ちしない（箱が大きくなっても、数が増えても、同じ探し方で置ける）
		var xs: Array[float] = _load_steps(d.deck_c.x - mx, d.deck_c.x + mx)
		var zs: Array[float] = _load_steps(d.deck_c.y - mz, d.deck_c.y + mz)
		for box: AABB in loaded:
			if box.position.y - d.deck_top > 0.25:
				continue      # 上に重ねてある荷物は、下の荷物と同じ所に候補ができるので省く
			for x: float in [box.position.x - extent.x - 0.03, box.end.x + extent.x + 0.03]:
				if absf(x - d.deck_c.x) <= mx:
					xs.append(x)
			for z: float in [box.position.z - extent.z - 0.03, box.end.z + extent.z + 0.03]:
				if absf(z - d.deck_c.y) <= mz:
					zs.append(z)
		var spots: Array[Vector2] = []
		for x: float in xs:
			for z: float in zs:
				spots.append(Vector2(x, z))
		spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(want) < b.distance_squared_to(want))
		for spot: Vector2 in spots:
			height = _load_height(p, d, local, offset, extent, spot, loaded, false)
			if not is_nan(height):
				want = spot
				break
		if is_nan(height):
			return false
	local.origin = Vector3(want.x - offset.x, height, want.y - offset.z)
	var world: Transform3D = d.global_transform * local
	var who: int = p.holder
	p.restore([world.origin,Quaternion(world.basis.orthonormalized()),false])
	_set_rider(p, d, local)
	if who != 0:
		host_ev("hold",[who,0])
	host_ev("sfx", ["load", p.global_position])
	return true


# 荷台のその位置（箱の中心の x,z）に置くときの、物の原点の高さ（荷台のローカル座標）。置けなければ NAN。
# 壁や別の物に当たるなら、当たらなくなるまで少しずつ上げる（幅の広い物は側板の上へ）。
# 先に載っている荷物と重なる場所は、stack が true で、物の真ん中がその荷物の上に来るときだけ（上に積む）。
# ふちだけが重なる置き方は、傾いて落ちるのでしない。物の底が荷台の床から LOAD_HIGH 以上になる置き方もしない
func _load_height(p: RigidBody3D, d: RigidBody3D, local: Transform3D, offset: Vector3, extent: Vector3, at: Vector2, loaded: Array[AABB], stack: bool) -> float:
	var top: float = d.deck_top
	var supported := true      # 物の真ん中が、いちばん高い荷物（無ければ床）に載るか
	# 荷台の壁の間に収まらない物（幅の広い板・大きなセット）は、側板の上に渡して置く。
	# 両端を側板が支えるので、下の荷物との重なりは見ない（当たらない高さまで上げるだけ）
	var bridges: bool = extent.x > d.deck_half.x - LOAD_EDGE or extent.z > d.deck_half.y - LOAD_EDGE
	if not bridges:
		for box: AABB in loaded:
			if absf(box.get_center().x - at.x) < box.size.x * 0.5 + extent.x + 0.02 and absf(box.get_center().z - at.y) < box.size.z * 0.5 + extent.z + 0.02:
				if not stack:
					return NAN
				if box.end.y > top:
					top = box.end.y
					supported = absf(box.get_center().x - at.x) < box.size.x * 0.5 - 0.03 and absf(box.get_center().z - at.y) < box.size.z * 0.5 - 0.03
	if not supported:
		return NAN
	var t := local
	t.origin = Vector3(at.x - offset.x, top - (offset.y - extent.y) + 0.03, at.y - offset.z)
	var bottom: float = top + 0.03 - d.deck_top       # 物の底の、荷台の床からの高さ
	while bottom < LOAD_HIGH:
		if _cargo_space_clear(p, d.global_transform * t):
			return t.origin.y
		t.origin.y += 0.1
		bottom += 0.1
	return NAN


# 荷台に載っている物が、荷台の壁の間に収まっていないか（側板の上に渡して載っているだけ）
func overhangs(p: RigidBody3D, d: RigidBody3D) -> bool:
	var box: AABB = (d.global_transform.affine_inverse() * p.global_transform) * body_bounds(p)
	return box.size.x * 0.5 > d.deck_half.x - LOAD_EDGE or box.size.z * 0.5 > d.deck_half.y - LOAD_EDGE


# from から to までを、LOAD_GRID 以下の間隔で等分した値（両端を含む）
func _load_steps(from: float, to: float) -> Array[float]:
	var out: Array[float] = []
	var n: int = maxi(1, ceili((to - from) / LOAD_GRID))
	if to - from < 0.01:
		out.append(from)
		return out
	for i in n + 1:
		out.append(lerpf(from, to, float(i) / float(n)))
	return out


# 当たり判定を全部囲む箱（その物のローカル座標）。
# center / half は「見た目の中心」なので、背の高いスタンドの先だけを指している物がある（月など）。
# 荷台や地面に置く高さは、実際に物に当たる範囲で決める
func body_bounds(p: Node3D) -> AABB:
	var out := AABB()
	var found := false
	var to_local: Transform3D = p.global_transform.affine_inverse()
	for cs: CollisionShape3D in p.find_children("*", "CollisionShape3D", true, false):
		if cs.disabled or cs.shape == null:
			continue
		var box: AABB = (to_local * cs.global_transform) * _shape_bounds(cs.shape)
		out = out.merge(box) if found else box
		found = true
	return out if found else AABB(p.center - p.half, p.half * 2.0)


func _shape_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		return AABB(Vector3(-cyl.radius, -cyl.height * 0.5, -cyl.radius), Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0))
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -r, Vector3.ONE * r * 2.0)
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		return AABB(Vector3(-cap.radius, -cap.height * 0.5, -cap.radius), Vector3(cap.radius * 2.0, cap.height, cap.radius * 2.0))
	return shape.get_debug_mesh().get_aabb()


func _cargo_space_clear(p: RigidBody3D, at: Transform3D) -> bool:
	var space := get_world_3d().direct_space_state
	for shape: CollisionShape3D in p.find_children("*","CollisionShape3D",true,false):
		if shape.disabled or shape.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = at * (p.global_transform.affine_inverse() * shape.global_transform)
		query.collision_mask = p.collision_mask
		query.exclude = [p.get_rid()]
		if not space.intersect_shape(query,1).is_empty():
			return false
	return true


func _set_rider(p: RigidBody3D, d: RigidBody3D, local: Transform3D) -> void:
	p.ride_local = local
	p.rider_of = d.pid
	p.set_fixed(false)
	p.sleeping = false


func host_unload(p: RigidBody3D) -> void:
	var d: RigidBody3D = props.get(p.rider_of)
	p.rider_of = 0
	p._apply_freeze()
	if d:
		p.remove_collision_exception_with(d)
		d.remove_collision_exception_with(p)


@rpc("any_peer", "call_local", "reliable")
func h_operate(pid: int, on: bool) -> void:
	if not Net.is_host() or not props.has(pid):
		return
	var who := Net.sender()
	var p: RigidBody3D = props[pid]
	if not "operator" in p:
		return
	if on:
		if p.operator != 0 or p.holder != 0 or _held_by(who) != null:
			return
		p.operator = who
		host_ev("operate", [who, pid])
	elif p.operator == who:
		_stop_operating(p)


func _stop_operating(p: RigidBody3D) -> void:
	var who: int = p.operator
	p.operator = 0
	if p.kind == "camera":
		p.dolly = Vector3.ZERO
	host_ev("operate", [who, 0])


@rpc("any_peer", "call_local", "unreliable_ordered")
func h_aim(pid: int, a: float, b: float, c: float) -> void:
	if not Net.is_host() or replaying or not props.has(pid):
		return
	var p: RigidBody3D = props[pid]
	if not "operator" in p or p.operator != Net.sender():
		return
	if p.kind == "camera":
		p.aim(a, b, -c * 3.0)
	else:
		p.aim(a, b, int(c))


@rpc("any_peer", "call_local", "unreliable_ordered")
func h_dolly(pid: int, v: Vector3) -> void:
	if not Net.is_host() or not props.has(pid):
		return
	var p: RigidBody3D = props[pid]
	if p.kind == "camera" and p.operator == Net.sender():
		p.dolly = v.limit_length(1.0)


# ---- ホストの処理：依頼と軽トラ ----

# カメラの映像（右上のモニター）を見られるか。制作モードでは、確認用モニターのそばか、小型モニター持ちだけ
func can_see_monitor() -> bool:
	return true

# 会社のカメラと、作品に採用するカメラを分ける。通常モードは一台だけ。
func program_camera() -> Node:
	return film

func select_program_camera(_pid: int) -> void:
	pass


# 何も持たずに左クリックしたときの、世界の中の押せる物（制作モードのアップグレード画面など）
func world_click() -> bool:
	return false


# 会社の機材（カメラ・ライト・カチンコ）を荷台に載せて届けるか。
# 制作モードでは載せない（会社の機材置き場に並べておき、出発するといっしょに現場へ運ばれる）
func gear_on_bed() -> bool:
	return true


# 買う値段。くり返し使える物は借りる値段の BUY_TIMES 倍、使い切りの物は値段そのまま
func buy_price(opt: Dictionary) -> int:
	return int(opt["cost"]) * (1 if opt.get("used_up", false) else BUY_TIMES)


# どちらの財布から払うか（"budget"＝依頼の制作費 / "savings"＝会社の貯金）。
# 借り物と使い切りの物は制作費、買って会社の持ち物にする物は貯金。払う財布を変えるなら、ここを直す
func pays_from(opt: Dictionary, bought: bool) -> String:
	return "savings" if bought and not opt.get("used_up", false) else "budget"


# 制作費から払う額（借り物と、使い切りの物）
func order_cost(o: Dictionary = order, b: Dictionary = buying) -> int:
	return _cost_from("budget", o, b)


# 会社の貯金から払う額（買って持ち物にする物）
func savings_cost(o: Dictionary = order, b: Dictionary = buying) -> int:
	return _cost_from("savings", o, b)


func _cost_from(purse: String, o: Dictionary, b: Dictionary) -> int:
	var total := 0
	for opt: Dictionary in OPTIONS:
		var n := int(o.get(opt["id"], 0))
		# 借りられない物（使い切りの物）は、数を選んだ分を「買った」として数える
		if n > 0 and pays_from(opt, not opt.get("rent", true)) == purse:
			total += int(opt["cost"]) * n
		if int(b.get(opt["id"], 0)) > 0 and pays_from(opt, true) == purse:
			total += buy_price(opt)
	return total


# 会社がもう持っている物か（買った物）。撮影だけモードには無い。制作モードは production_main.gd が上書きする
func owns(_id: String) -> bool:
	return false


# 買えるか（撮影だけモードには会社の貯金が無いので、買えない）
func can_buy(_opt: Dictionary) -> bool:
	return false


# いまの発注で使える制作費と、買い物に使える貯金
func order_budget() -> int:
	return BUDGET


func order_savings() -> int:
	return 0


# その品を、いくつまで注文できるか
func order_max(opt: Dictionary, _o: Dictionary = order, _b: Dictionary = buying) -> int:
	return int(opt["max"])


func _budget_short() -> String:
	return "制作費が足りない（%d コインまで）" % order_budget()


func _absent_kinds() -> Array:
	var gone: Array = []
	for opt: Dictionary in OPTIONS:
		if int(order.get(opt["id"], 0)) == 0 and not owns(opt["id"]):
			gone.append_array(opt["kinds"])
	return gone


@rpc("any_peer", "call_local", "reliable")
func h_order_set(id: String, count: int) -> void:
	_order_change(Net.sender(), id, count, false)


# 買う／買うのをやめる。発注を決めると会社の持ち物になり、次の依頼からは最初から在る
@rpc("any_peer", "call_local", "reliable")
func h_order_buy(id: String, on: bool) -> void:
	_order_change(Net.sender(), id, 1 if on else 0, true)


# 注文を1つ変える（ホスト）。buy＝買うほうを変える。借りると買うは、どちらか片方だけ
func _order_change(who: int, id: String, count: int, buy: bool) -> void:
	if not Net.is_host() or not may_order(who):
		return
	for opt: Dictionary in OPTIONS:
		if opt["id"] != id:
			continue
		var item := str(opt["name"]).trim_prefix("借りる")
		if owns(id):
			ev.rpc_id(who, "toast", ["%s は、もう会社が持っている" % item, 0])
			return
		var next: Dictionary = order.duplicate()
		var next_b: Dictionary = buying.duplicate()
		if buy:
			if not can_buy(opt):
				return
			if count > 0:
				next_b[id] = 1
				next[id] = 0
			else:
				next_b.erase(id)
		else:
			next[id] = maxi(count, 0)
			if int(next[id]) > 0:
				next_b.erase(id)
		# 火薬の袋には爆弾が要る（借りる・買う・もう持っている、のどれでもよい）
		if int(next.get("fx", 0)) == 0 and not next_b.has("fx") and not owns("fx"):
			if id in ["refill", "fuse"] and int(next.get(id, 0)) > 0:
				ev.rpc_id(who, "toast", ["火薬の袋には爆弾が必要", 1])
				return
			next["refill"] = 0
			next["fuse"] = 0
		for other: Dictionary in OPTIONS:
			if next.has(other["id"]):
				next[other["id"]] = mini(int(next[other["id"]]), order_max(other, next, next_b))
		if order_cost(next, next_b) > order_budget():
			ev.rpc_id(who, "toast", [_budget_short(), 1])
			ev.rpc_id(who, "sfx", ["ui_fail", null])
			return
		if savings_cost(next, next_b) > order_savings():
			ev.rpc_id(who, "toast", ["会社の貯金が足りない（%s を買うには %d コイン）" % [item, buy_price(opt)], 1])
			ev.rpc_id(who, "sfx", ["ui_fail", null])
			return
		order = next
		buying = next_b
		ev.rpc("order", [order, buying])
		ev.rpc("sfx", ["ui_select" if Sfx.has_sound("ui_select") else "pickup", null])


@rpc("any_peer", "call_local", "reliable")
func h_order_confirm() -> void:
	if not Net.is_host() or state != S.ORDER:
		return
	_apply_order()
	_set_state(S.PREP)
	host_ev("sfx", ["ui_ok", null])
	if gear_on_bed():
		host_ev("toast", ["軽トラが着いた。搬入口の荷台から機材を降ろそう（Tab であそびかた）", 0])


# 借りていない物を現場から外し、会社の機材と借りた物を軽トラと搬入口に並べる
func _apply_order() -> void:
	if adhesive != null: adhesive.clear()
	ev.rpc("absent", [_absent_kinds()])
	for p: RigidBody3D in props.values():
		if p.holder != 0:
			host_release(p)
		if "operator" in p and p.operator != 0:
			_stop_operating(p)
		if p.absent:
			if p.rider_of != 0:
				host_unload(p)
			p.linear_velocity = Vector3.ZERO
			p.angular_velocity = Vector3.ZERO
			p.global_position = Vector3(float(p.pid) * 3.0, -60.0, 0.0)
	# 撮影だけモード：量り済みの火薬が入っている（制作モードは空で届き、袋から注ぐ。production_main.gd が上書きする）
	fx.charges = 1 + int(order.get("refill", 0))
	fx.powder = fx.STANDARD
	fx.douse()
	var here: Array = []
	for pid: int in props:
		if not props[pid].absent:
			here.append(props[pid])
	_place_deliveries(here)
	for a: CharacterBody3D in actors:
		a.set_state(a.St.STANDBY)
	host_ev("slate", [1, "idle"])


# 届いた物を、届く場所（軽トラの荷台・搬入口のそば）に置く。list：置く物（物のIDの小さい順）
func _place_deliveries(list: Array) -> void:
	var bed := {"camera": [[Vector2(-0.34, -0.12), 0.0]], "spot": [[Vector2(0.34, -0.12), PI], [Vector2(-0.34, -0.92), PI]],
		"fx": [[Vector2(0.34, -0.8), PI]], "clapper": [[Vector2(0.36, -1.4), PI]], "rose": [[Vector2(-0.05, -1.5), 0.0]]}
	if not gear_on_bed():
		# 制作モード：会社の機材は荷台に載せない。置いた場所のままにする（並べ直すのは production_flow.gd）
		for kind: String in ["camera", "spot", "clapper"]:
			bed.erase(kind)
	var bay := {"dolly": [[Vector3(12.4, 0, 3.6), 0.0]], "balcony": [[Vector3(10.2, 0, 10.4), PI]], "window": [[Vector3(13.6, 0, 10.9), PI]],
		"sandbag": [[Vector3(12.0, 0, 8.6), 0.0], [Vector3(12.0, 0, 9.05), 0.0], [Vector3(12.5, 0, 8.8), 0.6]]}
	var used := {}
	for p: RigidBody3D in list:
		var n: int = used.get(p.kind, 0)
		if bed.has(p.kind) and n < (bed[p.kind] as Array).size():
			used[p.kind] = n + 1
			var slot: Array = bed[p.kind][n]
			_deliver_to_bed(p, Transform3D(Basis(Vector3.UP, slot[1]), Vector3(slot[0].x, truck.deck_top, slot[0].y)))
		elif bay.has(p.kind) and n < (bay[p.kind] as Array).size():
			used[p.kind] = n + 1
			p.restore([bay[p.kind][n][0], Quaternion(Vector3.UP, bay[p.kind][n][1]), false])


# 荷台の決まった場所（荷台から見た置き方）に載せる
func _deliver_to_bed(p: RigidBody3D, local: Transform3D) -> void:
	var world: Transform3D = truck.global_transform * local
	p.restore([world.origin, Quaternion(world.basis.orthonormalized()), false])
	_set_rider(p, truck, local)


# いま爆発を出せる場所（火薬の入った爆弾か、近い爆炎の書割）。無ければ null
func boom_point() -> Variant:
	if not fx.absent and (fx.loaded() or state != S.TAKE):
		return fx.burst_point()
	var flat := _pick_boom()
	if flat:
		return burst_spot(flat)
	return null if fx.absent else fx.burst_point()


# 爆弾のほかに爆発を出せる物：爆炎の書割と、爆発役にした物。二人にいちばん近い物を選ぶ
func _pick_boom() -> RigidBody3D:
	var mid: Vector3 = (actors[0].global_position + actors[1].global_position) * 0.5
	var best: RigidBody3D = null
	for b: RigidBody3D in props.values():
		if b == fx or b.absent or b.holder != 0 or judge.role_of(b) != "boom":
			continue
		if b.kind == "boomflat" and b.global_basis.y.y < 0.7:
			continue
		if best == null or b.global_position.distance_to(mid) < best.global_position.distance_to(mid):
			best = b
	return best


# 爆発が出る場所。専用の物は自分で決める。見立てた物は、その物の真ん中
func burst_spot(b: Node3D) -> Vector3:
	return b.burst_point() if b.has_method("burst_point") else b.center_global()


# 爆発役にした物の合図（制作モードで上書きする）。専用の書割なら何もしない
func host_cast_boom(_b: RigidBody3D) -> bool:
	return false


# ---- ホストの処理：本番の進行 ----

func _set_state(s: int) -> void:
	host_ev("state", [s])


@rpc("any_peer", "call_local", "reliable")
func h_use() -> void:
	if not Net.is_host():
		return
	var p := _held_by(Net.sender())
	if p and p.kind == "clapper":
		_take_or_cut(Net.sender())


@rpc("any_peer", "call_local", "reliable")
func h_take() -> void:
	if Net.is_host():
		_take_or_cut(Net.sender())


func _take_or_cut(who: int) -> void:
	if state == S.TAKE:
		_cut()
	elif state == S.PREP:
		if takes.size() >= MAX_TAKES:
			ev.rpc_id(who, "toast", ["テイクを使い切った。納品するテイクを選ぶ", 1])
			return
		for p: RigidBody3D in props.values():
			if p.holder != 0 and p.kind != "clapper":
				host_release(p)
		_layout = capture()["p"]
		_layout_glue = adhesive.snapshot()
		_layout_riders = {}
		for p: RigidBody3D in props.values():
			if p.rider_of != 0:
				_layout_riders[p.pid] = [p.rider_of, p.ride_local]
		host_ev("slate", [takes.size() + 1, "ready"])
		for a: CharacterBody3D in actors:
			a.set_state(a.St.STANDBY)
		host_ev("music", ["music_tension"])
		countdown_t = 3.0
		_beep = 3
		host_ev("sfx", ["countdown", null])
		_set_state(S.COUNTDOWN)


func _begin_take() -> void:
	judge.reset()
	fx.douse()
	reunion_cued = false
	take_t = 0.0
	_auto_cut = -1.0
	_rec_frames = []
	_rec_events = []
	_rec_t = 0.0
	for a: CharacterBody3D in actors:
		a.set_state(a.St.IDLE)
	_set_state(S.TAKE)
	host_ev("camera_program",[program_camera().pid])
	host_ev("music", [""])
	host_ev("slate", [takes.size() + 1, "clap"])
	host_ev("sfx", ["clap", null])
	host_ev("sfx", ["countdown_go", null])


func _cut() -> void:
	fx.douse()
	var res: Array = judge.results()
	var ok: Array = judge.passed()
	_take_data.append({"frames": _rec_frames, "events": _rec_events, "dur": take_t})
	takes.append({"results": res, "passed": ok, "dur": take_t})
	selected = takes.size() - 1
	for p: RigidBody3D in props.values():
		if "operator" in p and p.operator != 0:
			_stop_operating(p)
		if p.holder != 0:
			host_release(p)
	host_ev("music", [""])
	host_ev("slate", [takes.size(), "cut"])
	host_ev("sfx", ["clap", null])
	host_ev("takes", [takes, selected])
	_set_state(S.RESULT)
	host_ev("sfx", ["ui_ok" if not false in ok else "ui_fail", null])


@rpc("any_peer", "call_local", "reliable")
func h_cue(n: int) -> void:
	if not Net.is_host() or not (state == S.TAKE or state == S.PREP):
		return
	match n:
		1:
			for a: CharacterBody3D in actors:
				if a.st in [a.St.STANDBY, a.St.IDLE]:
					a.set_state(a.St.CONFESS)
			host_ev("sfx", ["cue", null])
			host_ev("music", ["music_tension" if judge.story == "kaiju" else "music_confession"])
			if judge.story == "kaiju":
				host_ev("sfx", ["roar", actors[0]._monster_pos()])
		2:
			if fx.fuse >= 0.0:
				return
			if not fx.absent and (fx.loaded() or state == S.PREP):
				# 合図で鳴らす道（撮影だけモードと自動確認）。制作モードでは、導火線の先に火を付ける
				fx.ignite(fx.FUSE_SEC)
				host_ev("sfx", ["countdown", fx.global_position])
			else:
				var flat := _pick_boom()
				if flat == null:
					host_ev("sfx", ["explosion_fizzle", null])
					host_ev("toast", ["爆発を出せない（爆弾に火薬が無い・爆炎の書割も立っていない）", 1])
					return
				if host_cast_boom(flat):
					return
				var pos: Vector3 = flat.burst_point()
				var counted := true
				if state == S.TAKE:
					counted = judge.on_burst(pos, flat.pid)
				host_ev("pop", [flat.pid])
				host_ev("burst", [pos, 0.0])
				host_ev("sfx", ["explosion", pos])
				if state == S.TAKE:
					if not counted:
						host_ev("toast", ["告白が撮れる前に爆発した！（順序が違う）", 1])
					for a: CharacterBody3D in actors:
						if a.global_position.distance_to(pos) < 9.0:
							a.knock(Vector3(0, 3.2, 0))
		3:
			reunion_cued = true
			for a: CharacterBody3D in actors:
				if a.st == a.St.FLINCH:
					a.after_flinch = a.St.REUNION_MOVE
				elif a.st != a.St.REUNION_HOLD:
					a.set_state(a.St.REUNION_MOVE)
			host_ev("sfx", ["cue", null])
			host_ev("music", ["music_reunion"])


# 爆弾が爆発した（導火線の火が口金に届いた・じかに点火した）。
# 入っている火薬の量で、爆風の強さと広さが、とぎれなく変わる（少し＝小さな爆発 / 袋1つ全部＝セットごと吹き飛ぶ）
func host_burst(box: RigidBody3D) -> void:
	var pos: Vector3 = box.burst_point()
	var real: bool = state == S.TAKE and box.loaded()
	var power: float = box.blast()
	var counted := true
	if real:
		counted = judge.on_burst(pos, box.pid)
		if judge.boom_src == box.pid and judge.boom_power == 0:
			judge.boom_power = box.stage()
	host_ev("burst", [pos, power if real else 0.0])
	host_ev("sfx", ["explosion" if real else "explosion_fizzle", pos])
	if not real:
		host_ev("toast", ["テスト発火（本番では周りを吹き飛ばす）" if state != S.TAKE else "火薬が入っていない。ポンと鳴っただけ", 0])
		return
	box.spend()
	if not counted:
		host_ev("toast", ["告白が撮れる前に爆発した！（順序が違う）", 1])
	var src: Vector3 = box.global_position + Vector3(0, 0.3, 0)
	var reach := 8.0 * power
	for p: RigidBody3D in props.values():
		if p == box or p.immovable or p.absent:
			continue
		var d: Vector3 = p.center_global() - src
		var dist := d.length()
		if dist > reach:
			continue
		var fall := pow(1.0 - dist / reach, 1.5)
		if p.rider_of != 0:
			host_unload(p)
		if p.fixed and dist < 3.0 * power:
			p.set_fixed(false)
		if p.fixed:
			continue
		if p.holder != 0:
			host_release(p)
		var dir := (d.normalized() + Vector3(0, 0.5, 0)).normalized()
		p.sleeping = false
		p.apply_central_impulse(dir * 11.0 * power * fall * minf(p.mass, 10.0))
		p.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * fall * minf(p.mass, 6.0))
	var actor_reach := 6.0 * power
	for a: CharacterBody3D in actors:
		var da: Vector3 = a.global_position + Vector3(0, 0.8, 0) - src
		if da.length() < actor_reach:
			var f2 := pow(1.0 - da.length() / actor_reach, 1.3)
			a.knock((da.normalized() * 9.0 * f2 + Vector3(0, 4.5 * f2, 0)) * power)


func host_condition_met(i: int) -> void:
	host_ev("met", [i])


# テイクの長さ（秒）。制作モードの、場面の列を持つ依頼では、フィルム1本ぶんになる（production_main.gd が上書きする）
func take_limit() -> float:
	return TAKE_SEC


# 本番中に、フィルムを止めているか（カット割りの依頼の場転。production_main.gd が上書きする）。
# 止めている間は、テイクの時計・記録・採点が進まない。見返しでは、止める前と回し直したあとが、つながって流れる
func take_held() -> bool:
	return false


@rpc("any_peer", "call_local", "reliable")
func h_standby() -> void:
	if Net.is_host() and state == S.PREP:
		for a: CharacterBody3D in actors:
			a.set_state(a.St.STANDBY)
		host_ev("music", [""])


@rpc("any_peer", "call_local", "reliable")
func h_select(i: int) -> void:
	if Net.is_host() and state == S.RESULT and not takes.is_empty():
		selected = clampi(i, 0, takes.size() - 1)
		host_ev("takes", [takes, selected])


@rpc("any_peer", "call_local", "reliable")
func h_retake() -> void:
	if not Net.is_host() or state != S.RESULT:
		return
	if takes.size() >= MAX_TAKES:
		ev.rpc_id(Net.sender(), "toast", ["テイクを使い切った。納品するテイクを選ぶ", 1])
		return
	_back_to_prep()


func _back_to_prep() -> void:
	var left: int = fx.charges
	var loaded: float = fx.powder
	for pid: int in _layout:
		if props.has(pid) and not props[pid].absent and not props[pid].immovable:
			props[pid].restore(_layout[pid])
	adhesive.restore(_layout_glue)
	for pid: int in _layout_riders:
		var r: Array = _layout_riders[pid]
		if props.has(pid) and props.has(r[0]):
			_set_rider(props[pid], props[r[0]], r[1])
	fx.charges = left
	fx.powder = loaded
	for a: CharacterBody3D in actors:
		a.set_state(a.St.STANDBY)
	host_ev("slate", [takes.size() + 1, "idle"])
	_set_state(S.PREP)


@rpc("any_peer", "call_local", "reliable")
func h_deliver(i: int) -> void:
	if not Net.is_host() or state != S.RESULT or i < 0 or i >= takes.size():
		return
	selected = i
	var ok: bool = not false in takes[i]["passed"]
	host_ev("takes", [takes, selected])
	host_ev("delivered", [ok])
	_set_state(S.DELIVERED)
	host_ev("sfx", ["success_fanfare" if ok else "ui_fail", null])


@rpc("any_peer", "call_local", "reliable")
func h_next() -> void:
	if not Net.is_host() or state != S.DELIVERED:
		return
	takes = []
	_take_data = []
	selected = 0
	host_ev("takes", [takes, selected])
	for a: CharacterBody3D in actors:
		a.set_state(a.St.STANDBY)
	_set_state(S.ORDER)


# ---- 見返し ----

@rpc("any_peer", "call_local", "reliable")
func h_replay(i: int) -> void:
	if not Net.is_host() or state != S.RESULT or i < 0 or i >= _take_data.size():
		return
	_replay = _take_data[i]
	if (_replay["frames"] as Array).size() < 2:
		return
	_replay_glue = adhesive.snapshot()
	adhesive.drop_joints()
	_program_before_replay = program_camera().pid
	replay_t = 0.0
	_replay_i = 0
	_replay_ev = 0
	_set_playback(true)
	_set_state(S.REPLAY)
	host_ev("replay_casts", [_replay_casts()])


@rpc("any_peer", "call_local", "reliable")
func h_stop_replay() -> void:
	if Net.is_host() and state == S.REPLAY:
		_end_replay()


func _replay_casts() -> Dictionary:
	var casts := {}
	var recorded: Dictionary = _replay["frames"][0][1]["pl"]
	for id: int in recorded:
		if (recorded[id] as Array).size() >= 5:
			casts[id] = recorded[id][4]
	return casts


func _end_replay() -> void:
	_set_playback(false)
	host_ev("camera_program",[_program_before_replay])
	ev.rpc("roster", [_roster])
	host_ev("silence", [])
	_set_state(S.RESULT)
	adhesive.restore(_replay_glue)


func _set_playback(on: bool) -> void:
	for p: RigidBody3D in props.values():
		p.set_playback(on)
	for a: CharacterBody3D in actors:
		a.playback = on


func _replay_step(delta: float) -> void:
	replay_t += delta
	var frames: Array = _replay["frames"]
	while _replay_i < frames.size() - 2 and float(frames[_replay_i + 1][0]) <= replay_t:
		_replay_i += 1
	var fa: Array = frames[_replay_i]
	var fb: Array = frames[_replay_i + 1]
	var w := clampf((replay_t - float(fa[0])) / maxf(float(fb[0]) - float(fa[0]), 0.001), 0.0, 1.0)
	var wa: Dictionary = fa[1]
	var wb: Dictionary = fb[1]
	adhesive.show_recorded(wa.get("glue",{}))
	for pid: int in wa["p"]:
		if props.has(pid) and wb["p"].has(pid):
			props[pid].apply_state(_blend(wa["p"][pid], wb["p"][pid], w), true)
	for i in actors.size():
		actors[i].apply_state(_blend(wa["a"][i], wb["a"][i], w), true)
	for id: int in wa["pl"]:
		var body: Node = replay_doubles.get(id, players.get(id))
		if body != null and wb["pl"].has(id):
			body.apply_state(_blend(wa["pl"][id], wb["pl"][id], w))
	var evs: Array = _replay["events"]
	while _replay_ev < evs.size() and float(evs[_replay_ev][0]) <= replay_t:
		ev.rpc(evs[_replay_ev][1], evs[_replay_ev][2])
		_replay_ev += 1
	if replay_t >= float(_replay["dur"]) + 0.3:
		_end_replay()


func _blend(a: Array, b: Array, w: float) -> Array:
	var out: Array = []
	for i in a.size():
		var x: Variant = a[i]
		if x is Vector3:
			out.append((x as Vector3).lerp(b[i], w))
		elif x is Quaternion:
			out.append((x as Quaternion).slerp(b[i], w))
		elif x is float:
			out.append(lerp_angle(x, b[i], w) if absf(x) <= TAU else lerpf(x, b[i], w))
		else:
			out.append(x)
	return out


func capture() -> Dictionary:
	var w := {"p": {}, "a": [], "pl": {}}
	for pid: int in props:
		w["p"][pid] = props[pid].get_state()
	for a: CharacterBody3D in actors:
		(w["a"] as Array).append(a.get_state())
	for id: int in players:
		w["pl"][id] = players[id].get_state()
	w["glue"] = adhesive.snapshot()
	return w


@rpc("authority", "call_remote", "unreliable")
func rx_world(p: Dictionary, a: Array, mounts: Dictionary = {}) -> void:
	for pid: int in mounts:
		if not props.has(pid):
			continue
		var prop: Node = props[pid]
		var carrier: int = mounts[pid][0]
		if prop.rider_of != carrier and prop.rider_of != 0:
			host_unload(prop)
		if carrier != 0 and props.has(carrier):
			_set_rider(prop,props[carrier],mounts[pid][1])
	for pid: int in p:
		if props.has(pid):
			props[pid].apply_state(p[pid])
	for i in mini(a.size(), actors.size()):
		actors[i].apply_state(a[i])


@rpc("authority", "call_remote", "unreliable")
func rx_live(l: Dictionary, tt: float, rt: float, cd: float) -> void:
	live = l
	take_t = tt
	replay_t = rt
	countdown_t = cd


func _physics_process(delta: float) -> void:
	if not Net.is_host():
		return
	if state == S.COUNTDOWN:
		countdown_t -= delta
		if int(ceil(countdown_t)) < _beep and countdown_t > 0.0:
			_beep = int(ceil(countdown_t))
			host_ev("sfx", ["countdown", null])
		if countdown_t <= 0.0:
			_begin_take()
	elif state == S.TAKE and not take_held():
		judge.tick(delta)
		take_t += delta
		_rec_t -= delta
		if _rec_t <= 0.0:
			_rec_t = 0.05
			_rec_frames.append([take_t, capture()])
		if not false in judge.passed() and _auto_cut < 0.0:
			_auto_cut = take_t + 3.0
		if take_t >= take_limit() or (_auto_cut > 0.0 and take_t >= _auto_cut):
			_cut()
	elif state == S.REPLAY:
		_replay_step(delta)

	_live_t -= delta
	if _live_t <= 0.0:
		_live_t = 0.2
		_update_live()
		if Net.has_peers():
			rx_live.rpc(live, take_t, replay_t, countdown_t)
	_sync_t -= delta
	if _sync_t <= 0.0 and Net.has_peers():
		_sync_t = 0.05
		_send_world()


# 動いた物だけを小分けにして送る（1通が大きいと届きにくくなるため）。約1秒ごとに全部を送り直す
func _send_world() -> void:
	_full_sync -= 1
	var full := _full_sync <= 0
	if full:
		_full_sync = 20
	var acts: Array = []
	for a: CharacterBody3D in actors:
		acts.append(a.get_state())
	var chunk := {}
	var mounts := {}
	var sent := false
	for pid: int in props:
		var st: Array = props[pid].network_state() if props[pid].has_method("network_state") else props[pid].get_state()
		var mount: Array = [props[pid].rider_of,props[pid].ride_local]
		var packet: Array = [st,mount]
		if not _last_sent.has(pid) or _last_sent[pid] != packet:
			_settle_resend[pid] = SETTLE_RESENDS
		elif not full:
			# 止まった直後は、同じ状態をあと数回送る。止まった瞬間の知らせは1通きりなので、それが届かないと、
			# 次の全部送りまで、相手の画面では古い場所のままになる
			var again: int = _settle_resend.get(pid, 0)
			if again <= 0:
				continue
			_settle_resend[pid] = again - 1
		_last_sent[pid] = packet
		chunk[pid] = st
		mounts[pid] = mount
		if chunk.size() >= 7:
			rx_world.rpc(chunk, acts, mounts)
			chunk = {}
			mounts = {}
			sent = true
	if not chunk.is_empty() or not sent:
		rx_world.rpc(chunk, acts, mounts)


# 画面に出す3場面の名前と作品名（制作モードでは依頼ごとに変わる）
func scene_titles() -> Array:
	return ["告白（高低差・城・明るさ）", "背後で大爆発", "爆発のあと再会"]


# 合図1・2・3の呼び名
func cue_names() -> Array:
	return ["告白", "爆発", "再会"]


func film_title() -> String:
	return "月下の城と大爆発"


func _update_live() -> void:
	var h: Array = []
	if state == S.PREP or state == S.COUNTDOWN:
		judge.frame = judge.look()
		h = judge.setup_problems(judge.frame)
		live["passed"] = [false, false, false]
	elif state == S.TAKE and not judge.frame.is_empty():
		live["passed"] = judge.passed()
		h = judge.take_hints(reunion_cued)
	elif not takes.is_empty():
		live["passed"] = takes[selected]["passed"]
	live["hints"] = h
	# 爆発を出せるか（量り済みの残り回数。袋から注ぐ制作モードでは、入っていれば 1）
	live["charges"] = -1 if fx.absent else (fx.charges if fx.charges > 0 else (1 if fx.loaded() else 0))


# ---- 全員への知らせ ----

func host_ev(n: String, a: Array) -> void:
	if state == S.TAKE and not take_held() and (n in REC_EVENTS or hooks.records(n)):
		_rec_events.append([take_t, n, a])
	ev.rpc(n, a)


@rpc("authority", "call_local", "reliable")
func ev(n: String, a: Array) -> void:
	# 仕組みの合図は、持ち主の仕組みへ渡す（feature_hooks.gd）
	if hooks.event(n, a):
		return
	match n:
		"camera_program":
			select_program_camera(int(a[0]))
		"state":
			_clear_dash_dust()
			state = a[0]
			if character_open and state not in [S.ORDER, S.PREP]:
				set_character_menu(false)
			replaying = state == S.REPLAY
			film.tally.visible = state == S.TAKE
			_grab_mouse(state != S.RESULT and state != S.DELIVERED and state != S.ORDER)
		"carton":
			if props.has(a[0]) and props[a[0]].kind == "carton":
				props[a[0]].opened = a[1]
		"replay_casts":
			for id: int in a[0]:
				if players.has(id):
					players[id].set_cast(a[0][id])
		"roster":
			_roster = a[0]
			_apply_roster()
		"takes":
			takes = a[0]
			selected = a[1]
		"delivered":
			delivered_ok = a[0]
		"hold":
			var pl: Node = players.get(a[0])
			if pl:
				_hold_exception(pl, pl.held, false)
				pl.held = a[1]
				_apply_hold_snapshot(pl, pl.held, a[2] if a.size() > 2 else {})
				_hold_exception(pl, pl.held, true)
		"hold_adjust":
			var pl: Node = players.get(a[0])
			if pl != null and pl.held == a[1]:
				_apply_hold_snapshot(pl, pl.held, a[2])
		"operate":
			var pl2: Node = players.get(a[0])
			if pl2:
				pl2.operating = a[1]
		"sfx":
			Sfx.play(a[0], a[1])
		"music":
			if a[0] == "":
				Sfx.stop_music()
			else:
				Sfx.play_music(a[0])
		"silence":
			Sfx.silence_all()
		"slate":
			clapper.set_take(a[0])
			if a[1] != "idle":
				hud.show_slate(a[1], a[0])
			if a[1] == "clap" or a[1] == "cut":
				clapper.clap()
		"order":
			order = a[0]
			buying = a[1] if a.size() > 1 else {}
		"absent":
			for p: RigidBody3D in props.values():
				# しまってある物（箱の中・人の体の中）は、消えたままにする
				p.set_absent(p.kind in a[0] or p.stored_in != 0)
		"pop":
			if props.has(a[0]):
				props[a[0]].pop()
		"fuse":
			# 爆弾にじかに火が付いた（秒数が0以下なら、火が消えた）。最後のひと溜めは爆弾が自分で見せる
			if props.has(a[0]):
				props[a[0]].show_fuse(float(a[1]) if a.size() > 1 else float(props[a[0]].FUSE_SEC), float(a[2]) if a.size() > 2 else -1.0)
		"dash_dust":
			_show_dash_dust(a[0], a[1], a[2] if a.size() > 2 else -1)
		"burst":
			_show_burst(a[0], a[1])
		"toast":
			hud.show_toast(a[0], Hud.RED if a[1] == 1 else Hud.YELLOW)
		"met":
			hud.show_toast("%s　OK！" % scene_titles()[a[0]], Hud.GREEN, 2.0)
			Sfx.play("ui_ok")


func _hold_exception(pl: Node, pid: int, on: bool) -> void:
	if pid == 0 or not props.has(pid):
		return
	var exempt: bool = on and not holding_support(pl, props[pid])
	if props[pid].get_collision_exceptions().has(pl) == exempt:
		return
	if exempt:
		props[pid].add_collision_exception_with(pl)
		pl.add_collision_exception_with(props[pid])
	else:
		props[pid].remove_collision_exception_with(pl)
		pl.remove_collision_exception_with(props[pid])


# 架空の爆発の見た目。power が 0 のときは小さなテスト発火
# power：0＝煙だけ（書割・見立て・空撃ち）/ 1＝ふつうの爆発 / それより小さい・大きい＝入れた火薬の量しだい（0.5〜2.0）
func _show_burst(pos: Vector3, power: float) -> void:
	var big: bool = power > 0.0
	# 見た目の大きさは、爆風の広さほどは増やさない（袋1つ全部でも、画面がしばらく煙だけにならないように）
	var look := 0.55 + 0.45 * power if power < 1.0 else 1.0 + (power - 1.0) * 0.55
	VfxExplosion.spawn(self, pos, 3.2 * look if big else 0.9, 1.25, big)
	if big and not replaying:
		var me: Node = local_player()
		if me:
			var d: Vector3 = me.global_position + Vector3(0, 0.8, 0) - pos
			var reach := 7.0 * power
			if d.length() < reach:
				me.knock((d.normalized() * 8.0 * (1.0 - d.length() / reach) + Vector3(0, 3, 0)) * power)


# ---- 確認画面の文面 ----

func panel_bbcode() -> String:
	if state == S.ORDER:
		return _order_bbcode()
	if takes.is_empty():
		return ""
	var t: Dictionary = takes[selected]
	var out := ""
	if state == S.DELIVERED:
		if delivered_ok:
			out += "[b][color=#7fff99]納品完了！[/color][/b]\n依頼どおりのクライマックスが撮れた。\n会社報酬　%d コイン　（制作費の残り %d コインは精算）\n\n" % [REWARD, BUDGET - order_cost()]
		else:
			out += "[b][color=#ff7366]納品したが、注文に届かなかった[/color][/b]\n報酬はなし。次の依頼の制作費は確保されている。\n\n"
	else:
		out += "[b]テイク %d の確認[/b]　（%.0f秒）\n\n" % [selected + 1, t["dur"]]
	for r: Dictionary in t["results"]:
		var mark := "[color=#7fff99]✔[/color]" if r["ok"] else "[color=#ff7366]✘[/color]"
		out += "%s　%s\n　　[color=#c8ccd8]%s[/color]\n" % [mark, r["title"], r["detail"]]
	out += "\n"
	if state == S.DELIVERED:
		out += "[color=#ffdb59][Enter][/color] 次の撮影へ"
		return out
	var row := ""
	for i in takes.size():
		var marks := ""
		for ok: bool in takes[i]["passed"]:
			marks += "✔" if ok else "✘"
		var cell := "テイク%d %s" % [i + 1, marks]
		row += ("[color=#ffdb59]▶ %s[/color]　" % cell) if i == selected else ("　%s　" % cell)
	out += row + "\n\n"
	out += "[color=#ffdb59][R][/color] 見返す　[color=#ffdb59][Enter][/color] このテイクを納品　"
	if takes.size() < MAX_TAKES:
		out += "[color=#ffdb59][Space][/color] 撮り直す（あと%d回）" % (MAX_TAKES - takes.size())
	else:
		out += "撮り直しは残っていない"
	if takes.size() > 1:
		out += "\n[color=#ffdb59][←][→][/color] テイクを選ぶ"
	return out


# ---- 見本のセット（F9）。置き方の一例を一瞬で組む ----

func _order_bbcode() -> String:
	var used := order_cost()
	var out := "[b][color=#ffdb59]依頼　月下の城と大爆発[/color][/b]\n"
	out += "[color=#c8ccd8]「月夜の城のバルコニーで愛を誓う二人。直後、背後で大爆発。\nそれでも駆け寄り、感動の再会。制作費は %d コインです」[/color]\n\n" % BUDGET
	out += "[b]軽トラに積んでもらう物[/b]　　使う %d ／ 残り [color=%s]%d[/color] コイン\n" % [used, "#7fff99" if used <= BUDGET else "#ff7366", BUDGET - used]
	for i in OPTIONS.size():
		var o: Dictionary = OPTIONS[i]
		var n: int = order.get(o["id"], 0)
		var box := ("[color=#7fff99]■[/color]" if n > 0 else "□") if int(o["max"]) == 1 else ("[color=#7fff99]×%d[/color]" % n if n > 0 else "×0")
		var line := "%s　%s　%d" % [box, o["name"], o["cost"]]
		if i == order_cursor:
			out += "[color=#ffdb59]▶ %s[/color]\n　　　[color=#c8ccd8]%s[/color]\n" % [line, o["desc"]]
		else:
			out += "　 %s\n" % line
	out += "\n[color=#c8ccd8]無料：会社の機材（カメラ・ライト2台・カチンコ）は荷台に載っている。\n廃材置き場の廃板・足場・書割・月・爆炎の書割も自由に使える。[/color]\n\n"
	out += "[color=#ffdb59][↑][↓][/color] 選ぶ　[color=#ffdb59][Space][/color] 入れる／外す　[color=#ffdb59][Enter][/color] この内容で現場へ"
	return out


@rpc("any_peer", "call_local", "reliable")
func h_sample() -> void:
	if not Net.is_host() or state != S.PREP:
		return
	var has := {}
	for q: RigidBody3D in props.values():
		if not q.absent:
			has[q.kind] = true
	var plan := {"flat": [Vector3(-2.4, 0, -2.4), Vector3(2.4, 0, -2.4)], "moon": [Vector3(3.6, 0, -5.8)],
		"spot": [Vector3(-3.6, 0, 2.6), Vector3(3.6, 0, 2.6)], "clapper": [Vector3(1.3, 0.05, 8.8)]}
	var mark_a := Vector3(0, 0.92, -3.0)
	if has.has("balcony"):
		plan["balcony"] = [Vector3(0, 0, -3.0)]
		plan["window"] = [Vector3(0, 0, -4.1)]
		plan["plywood"] = [Vector3(3.2, 0, -4.3), Vector3(5.0, 0, -4.3)]
	else:
		# 借りていなければ、足場と廃板で城を作る
		plan["riser"] = [Vector3(0, 0, -3.0)]
		plan["plywood"] = [Vector3(-0.8, 0, -3.75), Vector3(0.8, 0, -3.75)]
		mark_a = Vector3(0, 0.97, -3.0)
	if has.has("fx"):
		plan["fx"] = [Vector3(-2.7, 0, -6.4)]
	else:
		plan["boomflat"] = [Vector3(-2.7, 0, -4.4)]
	if has.has("dolly"):
		plan["dolly"] = [Vector3(0, 0, 6.2)]
		for p: RigidBody3D in props.values():
			if p.kind == "dolly":
				plan["camera"] = [Vector3(0, p.deck_top, 6.2)]
				break
	else:
		plan["camera"] = [Vector3(0, 0, 6.2)]
	var used := {}
	for pid: int in props:
		var p: RigidBody3D = props[pid]
		if plan.has(p.kind) and not p.absent:
			var n: int = used.get(p.kind, 0)
			if n < (plan[p.kind] as Array).size():
				used[p.kind] = n + 1
				var yaw := PI if p.kind == "spot" or p.kind == "dolly" else 0.0
				p.restore([plan[p.kind][n], Quaternion(Vector3.UP, yaw), false])
	actors[0].mark.restore([mark_a, Quaternion.IDENTITY, false])
	actors[1].mark.restore([Vector3(1.5, 0.05, -1.0), Quaternion.IDENTITY, false])
	for d: RigidBody3D in props.values():
		if d.kind == "dolly" and not d.absent:
			_set_rider(film, d, d.global_transform.affine_inverse() * film.global_transform)
			break
	_aim_camera(Vector3(0.5, 1.55, -2.6), 50.0)
	_aim_spot(spots[0], Vector3(0, 2.25, -3.0))
	_aim_spot(spots[1], Vector3(1.5, 1.2, -1.0))
	for a: CharacterBody3D in actors:
		a.set_state(a.St.STANDBY)
	host_ev("sfx", ["fix", null])
	host_ev("toast", ["見本のセットを組んだ。カチンコを持って F で本番、1→2→3 で合図", 0])


func _aim_camera(point: Vector3, fov: float) -> void:
	var d: Vector3 = film.global_basis.inverse() * (point - (film.global_position + Vector3(0, film.HEAD_Y, 0)))
	film.cam_yaw = atan2(-d.x, -d.z)
	film.cam_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	film.fov = fov


func _aim_spot(rig: RigidBody3D, point: Vector3) -> void:
	var d: Vector3 = rig.global_basis.inverse() * (point - (rig.global_position + Vector3(0, rig.HEAD_Y, 0)))
	rig.pan = atan2(d.x, d.z)
	rig.tilt = atan2(d.y, Vector2(d.x, d.z).length())
	rig.level = 2
