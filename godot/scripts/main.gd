extends Node3D
# 進行の中心。P2P（参加者の1人がホスト）方式が前提。
#   act_*  : 各参加者が押した操作。ホストへ依頼として送るだけ
#   h_*    : ホストが依頼を受けて実行する
#   ev     : ホストから全員への知らせ（音・状態・演出）
# ソロは「相手のいないホスト」なので、同じ経路をそのまま通る。

const Stage := preload("res://scripts/stage.gd")
const Player := preload("res://scripts/player.gd")
const Judge := preload("res://scripts/judge.gd")
const Hud := preload("res://scripts/hud.gd")

const S := {"PREP": 0, "COUNTDOWN": 1, "TAKE": 2, "RESULT": 3, "REPLAY": 4, "DELIVERED": 5, "ORDER": 6}
const TAKE_SEC := 60.0
const MAX_TAKES := 3
const REWARD := 1200
const PLAYER_CASTS := ["M02", "04", "09", "03"]
const REC_EVENTS := ["sfx", "music", "burst", "fuse", "pop"]
const SPAWN := Vector3(9.5, 0.1, 6.5)     # 搬入口の前
const BUDGET := 600
const FREE_FIXES := 4           # 固定用品を借りないときに固定できる数
# 軽トラに積んでもらう物（借りる・買う）。値段は企画書の仮の値
const OPTIONS := [
	{"id": "balcony", "name": "借りるバルコニー一式", "desc": "バルコニーとアーチ窓の壁。置くだけで城になる", "cost": 360, "max": 1, "kinds": ["balcony", "window"]},
	{"id": "fx", "name": "効果機（爆発）", "desc": "合図で本物の爆風が出る。1回分つき", "cost": 360, "max": 1, "kinds": ["fx"]},
	{"id": "refill", "name": "効果機の充填", "desc": "撮り直し用に1回分ずつ追加（効果機が必要）", "cost": 40, "max": 2, "kinds": []},
	{"id": "dolly", "name": "台車", "desc": "荷物運びと、カメラを載せての移動撮影", "cost": 80, "max": 1, "kinds": ["dolly"]},
	{"id": "fix", "name": "固定用品", "desc": "サンドバッグ3個。固定できる数が4か所から無制限に", "cost": 60, "max": 1, "kinds": ["sandbag"]},
	{"id": "rose", "name": "造花（約束のバラ）", "desc": "告白の小道具。無くても撮れる", "cost": 20, "max": 1, "kinds": ["rose"]},
]

var font: Font
var stage: Node3D
var hud: CanvasLayer
var judge: RefCounted

var props: Dictionary = {}
var actors: Array = []
var spots: Array = []
var moons: Array = []
var players: Dictionary = {}
var film: RigidBody3D
var fx: RigidBody3D
var clapper: RigidBody3D
var truck: RigidBody3D
var booms: Array = []
var order: Dictionary = {}      # 借りた物（id → 数）
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
var help_open := false
var input_locked := false      # 自動確認中は手元の入力を受けない
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
var _live_t := 0.0
var _auto_cut := -1.0
var _beep := 0
var _headless := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
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
	stage.build()
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	hud.build()
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
		"run": KEY_SHIFT, "jump": KEY_SPACE, "operate": KEY_F, "fix": KEY_G, "rot_left": KEY_Q, "rot_right": KEY_E}
	for n: String in keys:
		if not InputMap.has_action(n):
			InputMap.add_action(n)
			var e := InputEventKey.new()
			e.physical_keycode = keys[n]
			InputMap.action_add_event(n, e)


func _grab_mouse(on: bool) -> void:
	if _headless:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func local_player() -> Node:
	return players.get(Net.my_id())


func ui_blocking() -> bool:
	return state == S.RESULT or state == S.DELIVERED or state == S.REPLAY or state == S.ORDER or help_open or input_locked


# ---- 参加者 ----

@rpc("any_peer", "call_remote", "reliable")
func h_hello() -> void:
	if not Net.is_host():
		return
	var who := Net.sender()
	var used: Array = _roster.map(func(r: Array) -> int: return r[1])
	var idx := 0
	while idx in used:
		idx += 1
	_roster.append([who, idx % PLAYER_CASTS.size()])
	ev.rpc("roster", [_roster])
	ev.rpc_id(who, "takes", [takes, selected])
	ev.rpc_id(who, "order", [order])
	ev.rpc_id(who, "absent", [_absent_kinds()])
	ev.rpc_id(who, "state", [state])
	for p: RigidBody3D in props.values():
		if p.holder != 0:
			ev.rpc_id(who, "hold", [p.holder, p.pid])


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
	for id: int in players.keys():
		if not id in ids:
			players[id].queue_free()
			players.erase(id)


@rpc("any_peer", "call_remote", "unreliable")
func rx_player(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	var pl: Node = players.get(multiplayer.get_remote_sender_id())
	if pl and not pl.is_local:
		pl.apply_net(pos, body_yaw, a_yaw, a_pitch, h_dist, h_yaw, h_pitch, anim_name)


# ---- 各参加者の操作（ホストへの依頼） ----

func act_grab(pid: int) -> void:
	h_grab.rpc_id(1, pid)


func act_release() -> void:
	h_release.rpc_id(1)


func act_fix(pid: int) -> void:
	h_fix.rpc_id(1, pid)


func act_operate(pid: int, on: bool) -> void:
	h_operate.rpc_id(1, pid, on)


func act_aim(pid: int, a: float, b: float, c: float) -> void:
	h_aim.rpc_id(1, pid, a, b, c)


func act_use() -> void:
	h_use.rpc_id(1)


func act_dolly(pid: int, v: Vector3) -> void:
	h_dolly.rpc_id(1, pid, v)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).physical_keycode
	if key == KEY_TAB:
		help_open = not help_open
		return
	if help_open:
		return
	if state == S.ORDER:
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


# ---- ホストの処理：物を持つ・固定する・機材 ----

# プレイヤーが持っている物の行き先。[中心の目標, 向き, 足元の高さ]
func hold_target(holder: int, prop: RigidBody3D) -> Variant:
	var pl: CharacterBody3D = players.get(holder)
	if pl == null:
		return null
	var fwd: Vector3 = pl.flat_forward() if prop.kind == "spot" or prop.rolls else pl.aim_forward()
	var pitch: float = 0.0 if prop.axis_lock_angular_x else pl.hold_pitch
	var basis := Basis.from_euler(Vector3(pitch, pl.aim_yaw + pl.hold_yaw + prop.carry_yaw, 0))
	# 手から持ち物の手前の面までを合わせる。回転しても、大きい箱が体へ入り込まない。
	var depth: float = (basis.inverse() * fwd).abs().dot(prop.half)
	var grip: Vector3 = pl.vis.grip_pos(prop.kind in pl.vis.ONE_HAND_PROPS)
	var pos: Vector3 = grip + fwd * (depth + maxf(0.0, pl.hold_dist - 1.6))
	return [pos, pl.aim_yaw + pl.hold_yaw + prop.carry_yaw, pl.global_position.y, pitch]


func _held_by(who: int) -> RigidBody3D:
	for p: RigidBody3D in props.values():
		if p.holder == who:
			return p
	return null


@rpc("any_peer", "call_local", "reliable")
func h_grab(pid: int) -> void:
	if not Net.is_host() or replaying or not props.has(pid):
		return
	var who := Net.sender()
	var p: RigidBody3D = props[pid]
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
		ev.rpc_id(who, "toast", ["固定されている（Gで外す）", 0])
		return
	if p.rider_of != 0:
		host_unload(p)
	p.set_holder(who)
	p.grab_time = Time.get_ticks_msec() / 1000.0
	host_ev("hold", [who, pid])
	host_ev("sfx", ["pickup", p.global_position])


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
	host_ev("hold", [who, 0])
	host_ev("sfx", ["drop", p.global_position])
	_try_load(p)


# 手を離した物が台車の荷台の上なら載せる
func _try_load(p: RigidBody3D) -> void:
	if p.deck_top >= 0.0 or p.fixed or p.rider_of != 0 or p.absent:
		return
	for d: RigidBody3D in props.values():
		if d.deck_top < 0.0 or d == p or d.absent or d.global_basis.y.y < 0.8:
			continue
		var c: Vector3 = d.global_transform.affine_inverse() * p.center_global()
		if absf(c.x - d.deck_c.x) < d.deck_half.x and absf(c.z - d.deck_c.y) < d.deck_half.y and c.y > d.deck_top - 0.25 and c.y < d.deck_top + 2.2:
			host_load(p, d)
			return


func host_load(p: RigidBody3D, d: RigidBody3D) -> void:
	var local: Transform3D = d.global_transform.affine_inverse() * p.global_transform
	var top: float = d.deck_top
	for r: RigidBody3D in props.values():
		if r.rider_of == d.pid and r != p:
			var o: Vector3 = r.ride_local.origin
			if absf(o.x - local.origin.x) < r.half.x + p.half.x and absf(o.z - local.origin.z) < r.half.z + p.half.z:
				top = maxf(top, o.y + r.half.y * 2.0)
	var mx: float = maxf(d.deck_half.x - 0.1, 0.05)
	var mz: float = maxf(d.deck_half.y - 0.16, 0.05)
	var at := Vector3(clampf(local.origin.x, d.deck_c.x - mx, d.deck_c.x + mx), top, clampf(local.origin.z, d.deck_c.y - mz, d.deck_c.y + mz))
	_set_rider(p, d, Transform3D(Basis(Vector3.UP, local.basis.get_euler().y), at))
	host_ev("sfx", ["thump", p.global_position])


func _set_rider(p: RigidBody3D, d: RigidBody3D, local: Transform3D) -> void:
	p.ride_local = local
	p.rider_of = d.pid
	p.linear_velocity = Vector3.ZERO
	p.angular_velocity = Vector3.ZERO
	p._apply_freeze()
	p.add_collision_exception_with(d)
	d.add_collision_exception_with(p)


func host_unload(p: RigidBody3D) -> void:
	var d: RigidBody3D = props.get(p.rider_of)
	p.rider_of = 0
	p._apply_freeze()
	if d:
		p.remove_collision_exception_with(d)
		d.remove_collision_exception_with(p)


@rpc("any_peer", "call_local", "reliable")
func h_fix(pid: int) -> void:
	if not Net.is_host() or replaying or not props.has(pid):
		return
	var who := Net.sender()
	var p: RigidBody3D = props[pid]
	if p.immovable or p.absent or (p.holder != 0 and p.holder != who):
		return
	if not p.fixed and int(order.get("fix", 0)) == 0:
		var n := 0
		for q: RigidBody3D in props.values():
			if q.fixed and not q.immovable and not q.absent:
				n += 1
		if n >= FREE_FIXES:
			ev.rpc_id(who, "toast", ["固定できるのは%dか所まで（固定用品を借りていない）" % FREE_FIXES, 1])
			return
	if p.holder == who:
		host_release(p)
	if p.rider_of != 0:
		ev.rpc_id(who, "toast", ["台車に載っている物は固定できない", 0])
		return
	p.set_fixed(not p.fixed)
	host_ev("sfx", ["fix" if p.fixed else "unfix", p.global_position])


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

func order_cost(o: Dictionary = order) -> int:
	var total := 0
	for opt: Dictionary in OPTIONS:
		total += int(opt["cost"]) * int(o.get(opt["id"], 0))
	return total


func _absent_kinds() -> Array:
	var gone: Array = []
	for opt: Dictionary in OPTIONS:
		if int(order.get(opt["id"], 0)) == 0:
			gone.append_array(opt["kinds"])
	return gone


@rpc("any_peer", "call_local", "reliable")
func h_order_set(id: String, count: int) -> void:
	if not Net.is_host() or state != S.ORDER:
		return
	var who := Net.sender()
	for opt: Dictionary in OPTIONS:
		if opt["id"] != id:
			continue
		var next: Dictionary = order.duplicate()
		next[id] = clampi(count, 0, int(opt["max"]))
		if int(next.get("fx", 0)) == 0:
			if id == "refill" and int(next[id]) > 0:
				ev.rpc_id(who, "toast", ["充填には効果機が必要", 1])
				return
			next["refill"] = 0
		if order_cost(next) > BUDGET:
			ev.rpc_id(who, "toast", ["制作費が足りない（%d コインまで）" % BUDGET, 1])
			ev.rpc_id(who, "sfx", ["ui_fail", null])
			return
		order = next
		ev.rpc("order", [order])
		ev.rpc("sfx", ["pickup", null])


@rpc("any_peer", "call_local", "reliable")
func h_order_confirm() -> void:
	if not Net.is_host() or state != S.ORDER:
		return
	_apply_order()
	_set_state(S.PREP)
	host_ev("sfx", ["ui_ok", null])
	host_ev("toast", ["軽トラが着いた。搬入口の荷台から機材を降ろそう（Tab であそびかた）", 0])


# 借りていない物を現場から外し、会社の機材と借りた物を軽トラと搬入口に並べる
func _apply_order() -> void:
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
	fx.charges = 1 + int(order.get("refill", 0))
	fx.fuse = -1.0
	var bed := {"camera": [[Vector2(-0.34, -0.12), 0.0]], "spot": [[Vector2(0.34, -0.12), PI], [Vector2(-0.34, -0.92), PI]],
		"fx": [[Vector2(0.34, -0.8), PI]], "clapper": [[Vector2(0.36, -1.4), PI]], "rose": [[Vector2(-0.05, -1.5), 0.0]]}
	var bay := {"dolly": [[Vector3(12.4, 0, 3.6), 0.0]], "balcony": [[Vector3(10.2, 0, 10.4), PI]], "window": [[Vector3(13.6, 0, 10.9), PI]],
		"sandbag": [[Vector3(12.0, 0, 8.6), 0.0], [Vector3(12.0, 0, 9.05), 0.0], [Vector3(12.5, 0, 8.8), 0.6]]}
	var used := {}
	for pid: int in props:
		var p: RigidBody3D = props[pid]
		if p.absent:
			continue
		var n: int = used.get(p.kind, 0)
		if bed.has(p.kind) and n < (bed[p.kind] as Array).size():
			used[p.kind] = n + 1
			var slot: Array = bed[p.kind][n]
			var local := Transform3D(Basis(Vector3.UP, slot[1]), Vector3(slot[0].x, truck.deck_top, slot[0].y))
			var world: Transform3D = truck.global_transform * local
			p.restore([world.origin, Quaternion(world.basis.orthonormalized()), false])
			_set_rider(p, truck, local)
		elif bay.has(p.kind) and n < (bay[p.kind] as Array).size():
			used[p.kind] = n + 1
			p.restore([bay[p.kind][n][0], Quaternion(Vector3.UP, bay[p.kind][n][1]), false])
	for a: CharacterBody3D in actors:
		a.set_state(a.St.STANDBY)
	host_ev("slate", [1, "idle"])


# いま爆発を出せる場所（効果機か、近い爆炎の書割）。無ければ null
func boom_point() -> Variant:
	if not fx.absent and (fx.charges > 0 or state != S.TAKE):
		return fx.burst_point()
	var flat := _pick_boom()
	if flat:
		return flat.burst_point()
	return null if fx.absent else fx.burst_point()


func _pick_boom() -> RigidBody3D:
	var mid: Vector3 = (actors[0].global_position + actors[1].global_position) * 0.5
	var best: RigidBody3D = null
	for b: RigidBody3D in booms:
		if b.absent or b.holder != 0 or b.global_basis.y.y < 0.7:
			continue
		if best == null or b.global_position.distance_to(mid) < best.global_position.distance_to(mid):
			best = b
	return best


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
	fx.fuse = -1.0
	reunion_cued = false
	take_t = 0.0
	_auto_cut = -1.0
	_rec_frames = []
	_rec_events = []
	_rec_t = 0.0
	for a: CharacterBody3D in actors:
		a.set_state(a.St.IDLE)
	_set_state(S.TAKE)
	host_ev("music", [""])
	host_ev("slate", [takes.size() + 1, "clap"])
	host_ev("sfx", ["clap", null])
	host_ev("sfx", ["countdown_go", null])


func _cut() -> void:
	fx.fuse = -1.0
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
			host_ev("music", ["music_confession"])
		2:
			if fx.fuse >= 0.0:
				return
			if not fx.absent and (fx.charges > 0 or state == S.PREP):
				if state == S.TAKE:
					fx.charges -= 1
				fx.fuse = fx.FUSE_SEC
				host_ev("fuse", [fx.pid])
				host_ev("sfx", ["countdown", fx.global_position])
			else:
				var flat := _pick_boom()
				if flat == null:
					host_ev("sfx", ["explosion_fizzle", null])
					host_ev("toast", ["爆発を出せない（効果機の残りなし・爆炎の書割も立っていない）", 1])
					return
				var pos: Vector3 = flat.burst_point()
				var counted := true
				if state == S.TAKE:
					counted = judge.on_burst(pos)
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


# 効果機の溜めが終わった
func host_burst(box: RigidBody3D) -> void:
	var pos: Vector3 = box.burst_point()
	var real: bool = state == S.TAKE
	var counted := true
	if real:
		counted = judge.on_burst(pos)
	host_ev("burst", [pos, 1.0 if real else 0.0])
	host_ev("sfx", ["explosion" if real else "explosion_fizzle", pos])
	if not real:
		host_ev("toast", ["テスト発火（本番では周りを吹き飛ばす）", 0])
		return
	if not counted:
		host_ev("toast", ["告白が撮れる前に爆発した！（順序が違う）", 1])
	var src: Vector3 = box.global_position + Vector3(0, 0.3, 0)
	for p: RigidBody3D in props.values():
		if p == box or p.immovable or p.absent:
			continue
		var d: Vector3 = p.center_global() - src
		var dist := d.length()
		if dist > 8.0:
			continue
		var fall := pow(1.0 - dist / 8.0, 1.5)
		if p.rider_of != 0:
			host_unload(p)
		if p.fixed and dist < 3.0:
			p.set_fixed(false)
		if p.fixed:
			continue
		if p.holder != 0:
			host_release(p)
		var dir := (d.normalized() + Vector3(0, 0.5, 0)).normalized()
		p.sleeping = false
		p.apply_central_impulse(dir * 11.0 * fall * minf(p.mass, 10.0))
		p.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * fall * minf(p.mass, 6.0))
	for a: CharacterBody3D in actors:
		var da: Vector3 = a.global_position + Vector3(0, 0.8, 0) - src
		if da.length() < 6.0:
			var f2 := pow(1.0 - da.length() / 6.0, 1.3)
			a.knock(da.normalized() * 9.0 * f2 + Vector3(0, 4.5 * f2, 0))


func host_condition_met(i: int) -> void:
	host_ev("met", [i])


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
	for pid: int in _layout:
		if props.has(pid) and not props[pid].absent and not props[pid].immovable:
			props[pid].restore(_layout[pid])
	for pid: int in _layout_riders:
		var r: Array = _layout_riders[pid]
		if props.has(pid) and props.has(r[0]):
			_set_rider(props[pid], props[r[0]], r[1])
	fx.charges = left
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
	replay_t = 0.0
	_replay_i = 0
	_replay_ev = 0
	_set_playback(true)
	_set_state(S.REPLAY)


@rpc("any_peer", "call_local", "reliable")
func h_stop_replay() -> void:
	if Net.is_host() and state == S.REPLAY:
		_end_replay()


func _end_replay() -> void:
	_set_playback(false)
	host_ev("silence", [])
	_set_state(S.RESULT)


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
	for pid: int in wa["p"]:
		if props.has(pid) and wb["p"].has(pid):
			props[pid].apply_state(_blend(wa["p"][pid], wb["p"][pid], w), true)
	for i in actors.size():
		actors[i].apply_state(_blend(wa["a"][i], wb["a"][i], w), true)
	for id: int in wa["pl"]:
		if players.has(id) and wb["pl"].has(id):
			players[id].apply_state(_blend(wa["pl"][id], wb["pl"][id], w))
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
	return w


@rpc("authority", "call_remote", "unreliable")
func rx_world(p: Dictionary, a: Array) -> void:
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
	elif state == S.TAKE:
		judge.tick(delta)
		take_t += delta
		_rec_t -= delta
		if _rec_t <= 0.0:
			_rec_t = 0.05
			_rec_frames.append([take_t, capture()])
		if not false in judge.passed() and _auto_cut < 0.0:
			_auto_cut = take_t + 3.0
		if take_t >= TAKE_SEC or (_auto_cut > 0.0 and take_t >= _auto_cut):
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
	var sent := false
	for pid: int in props:
		var st: Array = props[pid].get_state()
		if not full and _last_sent.has(pid) and _last_sent[pid] == st:
			continue
		_last_sent[pid] = st
		chunk[pid] = st
		if chunk.size() >= 10:
			rx_world.rpc(chunk, acts)
			chunk = {}
			sent = true
	if not chunk.is_empty() or not sent:
		rx_world.rpc(chunk, acts)


func _update_live() -> void:
	var h: Array = []
	if state == S.PREP or state == S.COUNTDOWN:
		judge.frame = judge.look()
		h = judge.setup_problems(judge.frame)
		live["passed"] = [false, false, false]
	elif state == S.TAKE and not judge.frame.is_empty():
		var ok: Array = judge.passed()
		live["passed"] = ok
		if not ok[0]:
			h = judge.problems(judge.frame)
			if not judge.frame["castle"]:
				h.append("城のセットが映っていない")
			if not judge.frame["height"]:
				h.append("高低差が足りない")
			if h.is_empty() and not actors[0].is_confessing():
				h.append("[1] で告白の合図")
		elif not ok[1]:
			h = judge.problems(judge.frame, false)
			if not judge.frame["fx_in"]:
				h.append("効果機（爆発）が画面に入っていない")
			elif not judge.frame["fx_behind"]:
				h.append("爆発が二人より手前にある")
			if h.is_empty():
				h.append("[2] で爆発の合図")
		elif not ok[2]:
			h = judge.problems(judge.frame)
			if not reunion_cued:
				h.append("[3] で再会の合図")
	elif not takes.is_empty():
		live["passed"] = takes[selected]["passed"]
	live["hints"] = h
	live["charges"] = -1 if fx.absent else fx.charges


# ---- 全員への知らせ ----

func host_ev(n: String, a: Array) -> void:
	if state == S.TAKE and n in REC_EVENTS:
		_rec_events.append([take_t, n, a])
	ev.rpc(n, a)


@rpc("authority", "call_local", "reliable")
func ev(n: String, a: Array) -> void:
	match n:
		"state":
			state = a[0]
			replaying = state == S.REPLAY
			film.tally.visible = state == S.TAKE
			_grab_mouse(state != S.RESULT and state != S.DELIVERED and state != S.ORDER)
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
				pl.hold_yaw = 0.0
				pl.hold_pitch = 0.0
				_hold_exception(pl, pl.held, true)
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
		"absent":
			for p: RigidBody3D in props.values():
				p.set_absent(p.kind in a[0])
		"pop":
			if props.has(a[0]):
				props[a[0]].pop()
		"fuse":
			if props.has(a[0]):
				props[a[0]].show_fuse()
		"burst":
			_show_burst(a[0], a[1])
		"toast":
			hud.show_toast(a[0], Hud.RED if a[1] == 1 else Hud.YELLOW)
		"met":
			hud.show_toast("%s　OK！" % judge.TITLES[a[0]], Hud.GREEN, 2.0)
			Sfx.play("ui_ok")


func _hold_exception(pl: Node, pid: int, on: bool) -> void:
	if pid == 0 or not props.has(pid):
		return
	if on:
		props[pid].add_collision_exception_with(pl)
		pl.add_collision_exception_with(props[pid])
	else:
		props[pid].remove_collision_exception_with(pl)
		pl.remove_collision_exception_with(props[pid])


# 架空の爆発の見た目。power が 0 のときは小さなテスト発火
func _show_burst(pos: Vector3, power: float) -> void:
	var big: bool = power > 0.0
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.75, 0.25, 0.95)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.12)
	m.emission_energy_multiplier = 9.0
	ball.material_override = m
	root.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 60.0 if big else 10.0
	light.omni_range = 20.0 if big else 6.0
	root.add_child(light)
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.amount = 90 if big else 20
	parts.lifetime = 1.8
	parts.direction = Vector3.UP
	parts.spread = 75.0
	parts.initial_velocity_min = 4.0 if big else 1.5
	parts.initial_velocity_max = 11.0 if big else 3.0
	parts.gravity = Vector3(0, -6, 0)
	parts.scale_amount_min = 0.25
	parts.scale_amount_max = 0.7
	var pm := SphereMesh.new()
	pm.radius = 0.25
	pm.height = 0.5
	pm.radial_segments = 8
	pm.rings = 4
	parts.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.5, 0.1)
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.4, 0.05)
	pmat.emission_energy_multiplier = 7.0
	parts.material_override = pmat
	root.add_child(parts)
	parts.emitting = true
	var size := 7.0 if big else 1.6
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * size, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color", Color(0.9, 0.25, 0.05, 0.0), 1.5).set_delay(0.25)
	tw.tween_property(light, "light_energy", 0.0, 1.3)
	tw.chain().tween_callback(root.queue_free).set_delay(0.8)
	if big and not replaying:
		var me: Node = local_player()
		if me:
			var d: Vector3 = me.global_position + Vector3(0, 0.8, 0) - pos
			if d.length() < 7.0:
				me.knock(d.normalized() * 8.0 * (1.0 - d.length() / 7.0) + Vector3(0, 3, 0))


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
