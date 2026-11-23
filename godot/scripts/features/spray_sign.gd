extends Node
## 看板づくり（段ボールとスプレー）：
##   ・段ボール板：空の段ボール箱を見て Shift+F で、たたんで平らな板にする（箱は段ボール置き場の奥へ戻る）。
##     はじめから2枚、段ボール置き場のとなりに置いてある
##   ・立てる：板はそのままだと倒れる。接着剤で箱馬などに貼ると、立ったままになる（接着は adhesive.gd）
##   ・スプレー缶（黒・赤）：持って F を押している間、狙った段ボール板の表に色を吹く（手描き。字はガタガタになる）
##   ・字は打ち込まない。看板に何と書くかは、吹く人が手で書く（名前を聞く画面も、下書きも出さない）。
##     描いた板を事務所の入口の上の金具に掛けると、その看板の絵が会社の名前になる（features/company_sign.gd）
##   ・描いた板は、カンペ・等身大パネルと同じ「描ける物」（cue_cards.gd の boards）。看板の判定（signboard.gd）にも、そのまま数える
## 決めるのはホスト（たたむ・吹いた点）。吹いた絵は cue_cards.gd の rx_draw で全員へ配る
const Sheet := preload("res://scripts/cardboard_sheet.gd")
const Can := preload("res://scripts/spray_can.gd")
const Boxes := preload("res://scripts/cargo_boxes.gd")
const SHOWN := 2                 # はじめから出ている板
const SPARE := 4                 # たたむと出てくる板（地下にしまってある）
const COLORS := [["黒", Color(0.08, 0.08, 0.09)], ["赤", Color(0.82, 0.13, 0.1)]]
const REACH := 3.0               # 板から、これより遠いと吹けない
const SPREAD_NEAR := 4.5         # 吹いた跡の広がり（ガウスの幅。ピクセル）：缶の口が板に近い時
const SPREAD_FAR := 22.0         # 　　　　　　　　　　　　　　　　　　　　　　：遠い時（1.5m 以上）
const SEND_EVERY := 0.06
const FOLD_REACH := 4.0
const HISS_DB := -22.0           # 吹いている間のシューッという音（小さめ。2026-10-20 大きすぎると言われた）

var game: Node
var sheets: Array = []           # 段ボール板（全部）
var cans: Array = []             # スプレー缶
var spare: Array = []            # ホスト：まだ地下にしまってある板（物のID）
var _pending := PackedVector2Array()
var _pending_pid := 0
var _spreads := PackedFloat32Array()
var _mists := {}                 # 缶の物のID → {"inner", "outer", "until", "target", "can", "grow", "cut"}（霧。全員の画面）
var _noise: NoiseTexture2D
const CONE_SHADER := preload("res://shaders/spray_cone.gdshader")
var _send_t := 0.0
var _hiss_t := 0.0


func setup() -> void:
	var cards: Node = game.cue_cards
	var yard: Rect2 = Boxes.YARD
	for i in SHOWN + SPARE:
		var s: RigidBody3D = Sheet.new()
		s.build()
		var at := Vector3(yard.position.x + yard.size.x + 0.9, 0.03, yard.position.y + 0.3 + float(i) * 1.0)
		if i >= SHOWN:
			at = Vector3(300.0 + float(i) * 2.0, -60.0, 40.0)
		cards._register(s, at, 0.0)
		# 表を上にして寝かせておく（しまってある板は、地下で止めておく）
		var st: Array = s.get_state()
		st[1] = Quaternion(Vector3.RIGHT, -PI * 0.5)
		st[2] = i >= SHOWN
		s.restore(st)
		game.production._home_layout[s.pid] = s.get_state()
		sheets.append(s)
		if i >= SHOWN:
			spare.append(s.pid)
	for k in COLORS.size():
		var can: RigidBody3D = Can.new()
		can.build(str(COLORS[k][0]), COLORS[k][1])
		game.stage._register(can, Vector3(yard.position.x + yard.size.x + 0.45 + float(k) * 0.22, 0.03, yard.position.y - 0.35), 0.0)
		game.production._home_layout[can.pid] = can.get_state()
		cans.append(can)
	_build_mist()


# ---- たたむ（Shift+F） ----

func hook_key(event: InputEvent, me: Node) -> bool:
	if not Keybinds.pressed(event, "operate"):
		return false
	if _held_can(me) != null:
		return true                  # 缶を持っている間の F は、吹く（_process で見る）。ほかの F の使い道へは回さない
	if not event.shift_pressed or me.held != 0:
		return false
	var box: Node = me.target
	if not _foldable(box):
		return false
	h_fold.rpc_id(1, box.pid)
	return true


func _foldable(box: Node) -> bool:
	if box == null or box.kind != "carton" or box.absent or box.holder != 0 or not box.opened:
		return false
	var kit: Node = game.get("cargo_kit")
	return kit == null or (kit.boxes.box_items(box) as Array).is_empty()


@rpc("any_peer", "call_local", "reliable")
func h_fold(box_pid: int) -> void:
	if not Net.is_host():
		return
	var who := Net.sender()
	var me: Node3D = game.players.get(who)
	var box: Node = game.props.get(box_pid)
	if me == null or not _foldable(box) or game.state not in [game.S.PREP, game.S.TAKE] or game.replaying:
		return
	if (box as Node3D).global_position.distance_to(me.global_position) > FOLD_REACH:
		return
	if spare.is_empty():
		game.ev.rpc_id(who, "toast", ["もう、たためる板が無い（板は %d 枚まで）" % sheets.size(), 1])
		return
	var at: Vector3 = (box as Node3D).global_position
	var yaw: float = (box as Node3D).global_rotation.y
	# 箱は段ボール置き場の奥へ（しまった箱は、cargo_kit.gd が、また置き場へ出す）
	var flow: Node = game.production
	var hidden: Array = (flow.stash as Array).duplicate()
	if box_pid not in hidden:
		hidden.append(box_pid)
	game.host_ev("stash", [hidden])
	var parked: Array = box.get_state()
	parked[0] = Vector3(float(box_pid) * 3.0, -60.0, 0.0)
	box.restore(parked)
	var sheet: RigidBody3D = game.props[spare.pop_front()]
	var st: Array = sheet.get_state()
	st[0] = at + Vector3(0, 0.03, 0)
	st[1] = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, -PI * 0.5)
	st[2] = false
	sheet.restore(st)
	game.host_ev("sfx", ["fix", at])
	game.ev.rpc_id(who, "toast", ["段ボール箱をたたんで、板にした。スプレーで描ける（立てるなら、接着剤で箱馬などに貼る）", 0])


# 帰社のあと：使った板は、地下へしまい直す（はじめの2枚だけが出ている）。事務所の前に掛けてある看板の板は、そのまま
func hook_office_ready() -> void:
	spare = []
	var sign: Node = game.hooks.feature("company_sign")
	for i in sheets.size():
		if i < SHOWN:
			continue
		var s: RigidBody3D = sheets[i]
		if sign != null and sign.in_use(s):
			continue
		game.production._let_go(s)
		var st: Array = s.get_state()
		st[0] = Vector3(300.0 + float(i) * 2.0, -60.0, 40.0)
		st[2] = true
		s.restore(st)
		spare.append(s.pid)


# ---- 吹く（缶を持って F を押している間） ----

func _held_can(me: Node) -> RigidBody3D:
	if me == null or me.held == 0:
		return null
	for can: RigidBody3D in cans:
		if can.pid == me.held:
			return can
	return null


func _process(delta: float) -> void:
	var me: Node = game.local_player()
	var can := _held_can(me)
	var on: bool = can != null and Input.is_action_pressed("operate") and not game.ui_blocking() \
		and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE] and not game.replaying
	var now := Time.get_ticks_msec() / 1000.0
	if on:
		_hiss_t -= delta
		if _hiss_t <= 0.0:
			_hiss_t = 0.26
			Sfx.play("spray_hiss", can.nozzle_global(), HISS_DB)
		var hit := _aim(me)
		var target: Vector3 = hit["at"] if not hit.is_empty() else can.nozzle_global() - me.cam.global_basis.z * 1.2
		_mist_at(can, target, now + 0.08)
		if not hit.is_empty():
			var sheet: RigidBody3D = hit["sheet"]
			if _pending_pid != sheet.pid:
				_flush(can)
				_pending_pid = sheet.pid
			var px: Variant = sheet.pixel_at(sheet.to_local(hit["at"]))
			if px != null and (_pending.is_empty() or (px as Vector2).distance_to(_pending[_pending.size() - 1]) > 1.5):
				_pending.append(px)
				_spreads.append(spread_for(can.nozzle_global().distance_to(hit["at"])))
	_send_t -= delta
	if _send_t <= 0.0 or _pending.size() >= 24 or not on:
		_send_t = SEND_EVERY
		_flush(can)
	_update_mist(now)


# 缶の口から板までの距離 → 広がり（ガウスの幅。ピクセル）。近いと細く濃い・遠いと太く薄い
static func spread_for(distance: float) -> float:
	return lerpf(SPREAD_NEAR, SPREAD_FAR, clampf((distance - 0.15) / 1.35, 0.0, 1.0))


# 狙っている段ボール板の表の点。{"sheet", "at"}（無ければ空）
func _aim(me: Node) -> Dictionary:
	var from: Vector3 = me.cam.global_position
	var to: Vector3 = from - me.cam.global_basis.z * 12.0          # 後ろからの視点でも届く長さ（吹けるかは、板と体の近さで決める）
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4 | 16)
	q.exclude = [me.get_rid()]
	var held: Node = game.props.get(me.held)
	if held != null:
		q.exclude.append(held.get_rid())
	var hit: Dictionary = me.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit["collider"] in sheets):
		return {}
	var sheet: RigidBody3D = hit["collider"]
	if (hit["position"] as Vector3).distance_to(me.global_position + Vector3.UP) > REACH:
		return {}
	return {"sheet": sheet, "at": hit["position"]}


func _flush(can: RigidBody3D) -> void:
	if _pending.is_empty() or _pending_pid == 0:
		_pending = PackedVector2Array()
		_spreads = PackedFloat32Array()
		return
	if can != null:
		h_spray.rpc_id(1, _pending_pid, _pending, _spreads, can.pid)
	_pending = PackedVector2Array()
	_spreads = PackedFloat32Array()


@rpc("any_peer", "call_local", "reliable")
func h_spray(pid: int, points: PackedVector2Array, spreads: PackedFloat32Array, can_pid: int) -> void:
	if not Net.is_host() or points.is_empty() or points.size() > 32 or spreads.size() != points.size():
		return
	var who := Net.sender()
	var me: Node3D = game.players.get(who)
	var sheet: RigidBody3D = game.props.get(pid)
	var can: RigidBody3D = game.props.get(can_pid)
	if me == null or sheet == null or not (sheet in sheets) or can == null or not (can in cans) or can.holder != who or sheet.absent:
		return
	if game.replaying or game.state not in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE]:
		return
	if sheet.center_global().distance_to(me.global_position) > REACH + 1.5:
		return
	var clean := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in points.size():
		var p: Vector2 = points[i]
		if not is_finite(p.x) or not is_finite(p.y) or not is_finite(spreads[i]):
			return
		clean.append(p.clamp(Vector2.ZERO, Vector2(sheet.res - Vector2i.ONE)))
		widths.append(clampf(spreads[i], SPREAD_NEAR, SPREAD_FAR))
	rx_spray.rpc(pid, clean, widths, can.paint, randi(), sheet.revision + 1, can_pid)


# 吹いた跡を描く（全員の画面。粒のまき方は、ホストが決めた seed で同じになる）。吹いている人以外の画面では、霧も出す
@rpc("authority", "call_local", "reliable")
func rx_spray(pid: int, points: PackedVector2Array, spreads: PackedFloat32Array, color: Color, seed: int, version: int, can_pid: int) -> void:
	var sheet: RigidBody3D = game.props.get(pid)
	if sheet == null or not (sheet in sheets):
		return
	sheet.spray(points, spreads, color, seed)
	sheet.revision = version
	var can: RigidBody3D = game.props.get(can_pid)
	var me: Node = game.local_player()
	if can != null and can in cans and (me == null or me.held != can_pid) and not points.is_empty():
		_mist_at(can, sheet.world_at(points[points.size() - 1]), Time.get_ticks_msec() / 1000.0 + SEND_EVERY * 2.5)


# ---- 霧（缶ごとに：霧の円すい2枚。内は濃く速く・外は薄く広く） ----
# 円すい：口から板まで張る霧。模様が口から板へ流れる。吹き始めは口から先へ伸び、止めると口の側から切れて板の方へ抜ける

func _build_mist() -> void:
	# 霧の模様（円すいのシェーダーで流す）
	var fn := FastNoiseLite.new()
	fn.frequency = 0.04
	fn.fractal_octaves = 3
	_noise = NoiseTexture2D.new()
	_noise.width = 128
	_noise.height = 128
	_noise.seamless = true
	_noise.noise = fn


func _mist_for(can: RigidBody3D) -> Dictionary:
	if _mists.has(can.pid):
		return _mists[can.pid]
	var inner := _cone(1.1, 2.8)                           # 内の円すい：細く濃く、速く流れる
	var outer := _cone(0.6, 1.7)                           # 外の円すい：太く薄く、ゆっくり
	var m := {"inner": inner, "outer": outer, "until": 0.0, "target": Vector3.ZERO, "grow": 0.0, "cut": 1.0}
	_mists[can.pid] = m
	return m


# 霧の円すい：側面だけの円すい（口が細く、板の側が太い）。大きさは毎コマ、口から板までに合わせる
func _cone(density: float, flow: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.25          # 根元も少し太くする（細いと、濃い線に見える）
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 6
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = CONE_SHADER
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("flow", flow)
	mat.set_shader_parameter("noise", _noise)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	game.add_child(mi)
	return mi


# この缶の霧を、until（秒）まで、target へ向けて出す
func _mist_at(can: RigidBody3D, target: Vector3, until: float) -> void:
	var m := _mist_for(can)
	m["until"] = maxf(float(m["until"]), until)
	m["target"] = target
	m["can"] = can


func _update_mist(now: float) -> void:
	var dt := get_process_delta_time()
	for pid: int in _mists:
		var m: Dictionary = _mists[pid]
		var can: RigidBody3D = m.get("can")
		var alive: bool = can != null and is_instance_valid(can)
		var on: bool = alive and now < float(m["until"])
		# 吹き始めは口から先へ伸び、止めると口の側から切れて、残りが板の方へ抜ける
		if on:
			m["cut"] = 0.0
			m["grow"] = minf(1.0, float(m["grow"]) + dt / 0.08)
		else:
			m["cut"] = minf(1.2, float(m["cut"]) + dt / 0.22)
			if float(m["cut"]) >= 1.2:
				m["grow"] = 0.0
		var showing: bool = alive and float(m["cut"]) < 1.2
		for key: String in ["inner", "outer"]:
			(m[key] as MeshInstance3D).visible = showing
		if not alive:
			continue
		var from: Vector3 = can.nozzle_global()
		var to: Vector3 = m["target"]
		var dir := to - from
		var length := dir.length()
		if length < 0.05:
			continue
		var up := dir / length
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up)
		# 円すいの広がり：ノズルの開き（片側およそ10度）。外の円すいは少し太い
		var spread := 0.025 + length * 0.17
		for key: String in ["inner", "outer"]:
			var cone: MeshInstance3D = m[key]
			var r := spread * (0.7 if key == "inner" else 1.25)
			# 物の y＋0.5 が口（細い方）になるように、口から板へ向かう向きを −y にする
			cone.global_transform = Transform3D(Basis(side * r, -up * length, fwd * r), from + dir * 0.5)
			var mat: ShaderMaterial = cone.mesh.material
			mat.set_shader_parameter("paint", can.paint)
			mat.set_shader_parameter("grow", float(m["grow"]))
			mat.set_shader_parameter("cut", float(m["cut"]))


# ---- 画面の案内 ----

func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	if _held_can(me) != null:
		return {"keys": "F（押している間） 段ボール板にスプレーを吹く"}
	if me.held == 0 and _foldable(me.target):
		return {"tail": "　[Shift+F] たたんで板にする", "keys": "Shift+F 段ボール箱をたたんで、板にする"}
	return {}
