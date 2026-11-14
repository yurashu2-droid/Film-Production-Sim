extends Node
## 夜用フィルター（青いゲル。撮影の「擬似夜景」＝昼に撮って、青く暗く写す昔からの手）。会社の備品として、仕掛けの道具の隣に置く。
##   ・持って、撮影カメラを見て F で付ける（もう一度で外す）。付けたカメラの映像だけが、青く暗い夜になる（月夜の場面に）。
##     目で見ている現場は昼のまま。付けたカメラの上には、制作班にだけ見える「夜用」の札が出る。
##   ・明るさの判定（役者の顔が暗い、など）は、光の当たり方で決めるので、フィルターでは変わらない
## 決めるのはホスト。どのカメラに付いているかは "night" の合図で全員へ配る（本番中は記録にも残り、見返し・試写会でも夜に映る）
const Prop := preload("res://scripts/prop.gd")
const CREW_LAYER := 1 << 11
const HOME_AT := Vector3(68.3, 0.05, 19.55)
const SCALE := 2.4

var game: Node
var gel: RigidBody3D
var night: Dictionary = {}                 # フィルターを付けた撮影カメラ（物のID → true）
var _env: Environment
var _live := {}


func setup() -> void:
	var p: RigidBody3D = Prop.new()
	p.kind = "nightgel"
	p.label = "夜用フィルター（青いゲル）"
	p.mass = 0.4
	var model: Node3D = (load("res://assets/props/P077_gel_swatches.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * SCALE
	p.visual = model
	p.add_child(model)
	var box: AABB = game.stage.merged_aabb(model)
	box = AABB(box.position * SCALE, box.size * SCALE)
	p.center = box.get_center()
	p.half = box.size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	game.stage._shape(p, box.get_center(), box.size * 0.97, false)
	gel = game.stage._register(p, HOME_AT, 0.4)
	if Net.is_host() and game.production != null:
		game.production._home_layout[gel.pid] = gel.get_state()


func _cameras() -> Array:
	return game.props.values().filter(func(p: Node) -> bool: return p.kind == "camera" and not p.absent)


func _aimed_camera(me: Node) -> Node:
	var t: Node = me.target
	return t if t != null and t.kind == "camera" and not t.absent else null


# ---- 自分の操作 ----

func hook_f(me: Node) -> bool:
	if gel == null or me.held != gel.pid or game.production == null:
		return false
	var cam := _aimed_camera(me)
	if cam == null:
		return false
	h_toggle.rpc_id(1, int(cam.pid))
	return true


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	# フィルターを付けたカメラを狙うと、名前の横に出す（カメラの上の札は出さない）
	if gel == null or me.held != gel.pid:
		var aimed := _aimed_camera(me)
		if aimed != null and night.has(int(aimed.pid)):
			return {"tail": "　（夜用フィルター付き）"}
		return {}
	var cam := _aimed_camera(me)
	if cam == null:
		return {"keys": "撮影カメラを見て F 夜用フィルターを付ける"}
	return {"keys_all": ("F 夜用フィルターを外す" if night.has(int(cam.pid)) else "F 夜用フィルターを付ける（映像が青く暗い夜になる）") + "\n" + str(game.hold_hint())}


@rpc("any_peer", "call_local", "reliable")
func h_toggle(cam_pid: int) -> void:
	var who := Net.sender()
	var cam: Node = game.props.get(cam_pid)
	var pl: Node = game.players.get(who)
	if not Net.is_host() or game.replaying or cam == null or cam.kind != "camera" or pl == null or gel.holder != who:
		return
	if pl.reach_base().distance_to(cam.center_global()) > game.Player.REACH + 2.0:
		return
	var next: Dictionary = night.duplicate()
	if next.has(cam_pid):
		next.erase(cam_pid)
		game.ev.rpc_id(who, "toast", ["夜用フィルターを外した（昼に映る）", 0])
	else:
		next[cam_pid] = true
		game.ev.rpc_id(who, "toast", ["夜用フィルターを付けた。このカメラの映像は、青く暗い夜になる", 0])
	game.host_ev("sfx", ["fix", cam.global_position])
	game.host_ev("night", [next])


# ---- 全員の画面：付けたカメラの映像を夜にする ----

func hook_events() -> Array:
	return ["night"]


func hook_rec_events() -> Array:
	return ["night"]


func hook_event(_n: String, a: Array) -> void:
	night = (a[0] as Dictionary).duplicate()
	_apply()


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "night", [night])


func hook_take_start() -> void:
	game._rec_events.append([0.0, "night", [night.duplicate()]])


func hook_playback(on: bool) -> void:
	if on:
		_live = night.duplicate()
	else:
		game.host_ev("night", [_live])


# 帰社したら、フィルターは外す
func hook_return_office() -> void:
	if Net.is_host() and not night.is_empty():
		game.host_ev("night", [{}])


func _apply() -> void:
	for cam: Node in _cameras():
		var on: bool = night.has(int(cam.pid))
		var vc: Camera3D = cam.get("view_cam")
		if vc != null:
			vc.environment = _night_env(vc) if on else null


# 擬似夜景：世界の空と光をそのまま使い、映像だけを暗く・青く・色を浅くする
func _night_env(vc: Camera3D) -> Environment:
	if _env != null:
		return _env
	var base: Environment = vc.get_world_3d().environment if vc.get_world_3d() != null else null
	_env = base.duplicate() if base != null else Environment.new()
	_env.adjustment_enabled = true
	_env.adjustment_brightness = 0.45
	_env.tonemap_exposure = _env.tonemap_exposure * 0.7
	_env.adjustment_contrast = 1.18
	_env.adjustment_saturation = 0.55
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.0, 0.01, 0.04))
	ramp.add_point(0.5, Color(0.05, 0.1, 0.24))
	ramp.set_color(1, Color(0.6, 0.72, 0.95))
	var lut := GradientTexture1D.new()
	lut.gradient = ramp
	_env.adjustment_color_correction = lut
	return _env
