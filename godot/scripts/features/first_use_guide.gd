extends Node
## 自分が初めて触れた道具だけを、いま試せる操作と一緒にバズ山が案内する。

const Keys := preload("res://scripts/keybinds.gd")
const SAVE := "user://buzzyama_lessons.cfg"
const CREW_LAYER := 1 << 11
const TIP_TIME := 5.2
const READ_TIME := 2.2
const TIP_GAP := 1.1
const LOOK_TIME := 0.72
const ARRIVAL_TIME := 2.8
const DAY_ONE_LESSONS := ["carton", "script", "clapper", "spray"]
const ROTATE := "持ったら、右クリックを押したままマウスを動かす！\nほら、その場で回してみなさい。"
const HELD := {
	"carton": ["carton", "段ボールは F でふたを開ける。\n小物を持って開いた箱を見れば、F でしまえるぞ。"],
	"trashbag": ["bags", "その袋を持ったまま左右に振る。\nうまくいかなければ F でも中身が出るぞ。"],
	"tarpbundle": ["bags", "包みを持ったまま左右に振る。\nF でも中の大道具を出せるぞ。"],
	"script": ["script", "台本は持って F で開ける。\n場面と配役を、仲間にも伝えなさい。"],
	"cue_card": ["cue_card", "F でカンペに書く。\n読み手のほうへ表を向けて見せるのだ。"],
	"clapper": ["clapper", "このカチンコを持って F で本番！\n今の画が撮れたら、台本のそばで次の合図だ。"],
	"glue": ["glue", "F で接着剤を塗って、点同士を合わせる。\n回ってしまうなら、離れた場所も留めるのだ。"],
	"rope": ["rope", "ロープの先を結ぶ場所を見て F。\n荷台では、荷物の上を通って反対側に結ぶ。"],
	"pulley": ["pulley", "掛けたい場所を見て F で滑車を留める。\nロープを持って滑車に掛ければ、力の向きが変わる。"],
	"harness": ["harness", "吊りたい人を見て F で着せる。\nロープの端は、背中の金具に結ぶのだ。"],
	"scrap_fan": ["fan", "床に置いて F で回してみなさい。\n正面の軽い物が動くぞ。"],
	"timer": ["timer", "F で時計を巻くと、鳴るまでの時間が延びる。\nケーブルでつないだ機材を、鳴ったときに動かせる。"],
	"buzzer": ["buzzer", "押しボタンは機材とケーブルでつなぐ。\nこれで、離れた場所から仕掛けを動かせるぞ。"],
	"igniter": ["igniter", "トーチは F で火を出せる。\nつないだボタンや時計からも動かせるぞ。"],
	"nightgel": ["nightgel", "これを持ってカメラを見て F。\n映像は夜になる。役者の顔にはライトを忘れるな！"],
	"slowray": ["slowray", "F で光線を出す。\n遅くなるのは光を浴びている人と物だけだ。"],
	"spray_paint": ["spray", "段ボール板に向けて F を押している間、色が出る。\n試しに会社の名前を書いてみなさい。"],
	"standin": ["standin", "このパネルを持ったまま Y で、代役を決められる。\n誰も入っていない役に使ってみなさい。"],
	"powdersack": ["powder", "火薬は爆弾の口の上で F を押して入れる。\n口を外すと床にこぼれるぞ。"],
}
const TARGETS := {
	"monitor": ["monitor", "モニターを右クリック。\n3台の映像を見比べて、使うカメラを選びなさい。"],
	"lift_cart": ["lift", "カメラを台に載せたら、台を見て F。\nカメラごと高さを変えて撮れるぞ。"],
	"crane": ["crane", "荷物をロープで結んで、塔の滑車に掛ける。\n反対の端を引けば、持ち上げられるぞ。"],
	"fx": ["bomb", "爆弾の口にロープを F で結ぶと導火線になる。\n火を付けるのは、離れた導火線の先からだ。"],
}

var game: Node
var force := false  # テストでは設定を読み書きしない
var _seen := {}
var _guide: Node
var _active := ""
var _left := 0.0
var _elapsed := 0.0
var _gap := 0.0
var _arrival_age := 0.0
var _active_context := ""
var _candidate_context := ""
var _candidate_age := 0.0
var _rotation_prop: Node3D
var _attempt_pid := 0
var _start_spin := Quaternion.IDENTITY
var _arrow: MeshInstance3D


func setup() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE) == OK and file.has_section("completed"):
		for id: String in file.get_section_keys("completed"):
			if file.get_value("completed", id, false):
				_seen[id] = true


func _process(delta: float) -> void:
	var flow: Node = game.get("production")
	if flow == null or not (flow.daily or force):
		return
	if _guide == null:
		_guide = game.hooks.feature("day1_guide")
	if _guide == null:
		return
	_gap = maxf(0.0, _gap - delta)
	_arrival_age = _arrival_age + delta if flow.phase == 4 and not flow.shoots_home() else 0.0
	var me: Node = game.local_player()
	# 案内を待たずに目的の画面を開けた人には、次から開き方を重ねて言わない。
	if game.monitor_popup != null and game.monitor_popup.opened and not _seen.has("monitor"):
		_remember("monitor")
	if flow.phase == 2 and game.ordering() and not _seen.has("order"):
		_remember("order")
	if me == null or me.down > 0.0 or game.ui_blocking() or game.state != game.S.PREP:
		_finish()
		_track("", delta)
		return
	if flow.day <= 1 and not force and not _guide.on:
		return
	if me.held == 0:
		_attempt_pid = 0
	var lesson := _lesson(me, flow)
	var context: String = lesson.get("context", "")
	_track(context, delta)
	if _active == "rotate":
		if not is_instance_valid(_rotation_prop) or me.held != _rotation_prop.pid:
			_finish()
		elif _spin(me).angle_to(_start_spin) > 0.20:
			_remember("rotate")
			_arrow.hide()
			_active = "rotated"
			_left = 1.5
			_guide.show_field_tip("そう、その向き！ 左クリックで置けるぞ。", _guide._field_focus, _guide._field_stand)
	elif _active != "" and _active != "rotated" and context != _active_context:
		_finish()
	if _active != "":
		_left -= delta
		_elapsed += delta
		if _active == "rotate" and is_instance_valid(_rotation_prop):
			var radius: float = clampf(maxf(_rotation_prop.half.x, _rotation_prop.half.z) + 0.20, 0.38, 1.25)
			_arrow.global_position = _rotation_prop.center_global() + Vector3.UP * minf(_rotation_prop.half.y + 0.26, 1.2)
			_arrow.scale = Vector3.ONE * radius
			_arrow.rotate_y(delta * 1.65)
		if _left > 0.0:
			return
		_finish()
		return
	if lesson.is_empty() or _gap > 0.0 or _candidate_age < float(lesson.get("delay", LOOK_TIME)):
		return
	var id: String = lesson.id
	if id == "rotate":
		if _spin(me).angle_to(Quaternion.IDENTITY) > 0.20:
			_remember(id) # 説明が出る前にできたなら、その操作はもう知っている。
		else:
			_start_rotation(me, game.props[me.held])
	elif not _seen.has(id):
		_active = id
		_active_context = context
		_elapsed = 0.0
		_left = TIP_TIME
		_guide.show_field_tip(Keys.translate(lesson.line), lesson.focus, _teacher_stand(me))


func _track(context: String, delta: float) -> void:
	if _candidate_context != context:
		_candidate_context = context
		_candidate_age = 0.0
	elif context != "":
		_candidate_age += delta


func _lesson(me: Node3D, flow: Node) -> Dictionary:
	var held: Node3D = game.props.get(me.held)
	if held != null:
		if not _seen.has("rotate") and held.pid != _attempt_pid and me.operating == 0:
			return _cue("rotate", ROTATE, _nearby_focus(me), held.pid, 0.55)
		return _held_tip(held, me, flow)
	var operating: Node3D = game.props.get(me.operating)
	if operating != null:
		if operating.kind == "camera":
			return _cue("camera", "マウスでカメラの向き、ホイールでズーム。\nまず役者に寄ってみなさい。離れるのは F。", operating.global_position, operating.pid, 0.22)
		elif operating.kind == "spot":
			return _cue("light", "マウスで光の向き、ホイールで明るさ。\nまず役者の顔に当ててみなさい。離れるのは F。", operating.global_position, operating.pid, 0.22)
		return {}
	if me.target != null:
		var entry: Array = TARGETS.get(me.target.get("kind"), [])
		if not entry.is_empty() and not _seen.has(entry[0]):
			if entry[0] != "monitor" or (game.camera_switcher.allowed() and game.camera_switcher.nearby(me)):
				return _cue(entry[0], entry[1], me.target.global_position, me.target.pid)
	var station: String = game.station() if flow.phase == 2 else ""
	if station == "packing" and (me.target == null or me.target == game.truck):
		return _cue("depart", "会社のカメラやライトは自動で届く。\n全員が軽トラに集まったら、手ぶらで F だ。", flow.HOME_TRUCK)
	var desk_order: bool = game.director != null and game.director.aimed() == "order"
	if flow.phase == 2 and flow.orderer == 0 and (station == "order" or desk_order):
		return _cue("order", "ここで F を押すと機材の発注だ。\n借りるなら制作費、買うなら会社の貯金を使う。", _nearby_focus(me))
	if _arrival_age >= ARRIVAL_TIME and _arrival_age < 12.0 and me.global_position.distance_to(game.SPAWN) < 6.0:
		return _cue("arrival", "荷物を降ろしたら、辺りも見てみなさい。\n現地の小道具が撮影に使えるぞ。", game.SPAWN, 0, 0.0)
	return {}


func _held_tip(prop: Node3D, me: Node3D, flow: Node) -> Dictionary:
	var focus := _nearby_focus(me)
	if flow.phase == 2 and not _seen.has("pack") and me.global_position.distance_to(flow.HOME_TRUCK) < 4.5:
		return _cue("pack", "その小道具を持ったまま F。\n空いている荷台の床に積めるぞ。", focus, prop.pid)
	if prop.kind.begins_with("bgcan_"):
		return _cue("backdrop", "この缶を持ってカメラを見て F。\n緑の布を撮ると、その緑が背景に変わるぞ。", focus, prop.pid)
	var entry: Array = HELD.get(prop.kind, [])
	if entry.is_empty() or (flow.day <= 1 and _guide.on and entry[0] in DAY_ONE_LESSONS):
		return {}
	return _cue(entry[0], entry[1], focus, prop.pid, 0.45)


func _cue(id: String, line: String, focus: Vector3, pid: int = 0, delay: float = LOOK_TIME) -> Dictionary:
	return {"id": id, "line": line, "focus": focus, "context": "%s:%d" % [id, pid], "delay": delay}


func _start_rotation(me: Node3D, prop: Node3D) -> void:
	if _arrow == null:
		_arrow = _build_arrow()
		game.add_child(_arrow)
	_active = "rotate"
	_elapsed = 0.0
	_left = TIP_TIME + 1.0
	_rotation_prop = prop
	_attempt_pid = prop.pid
	_start_spin = _spin(me)
	_arrow.global_position = prop.center_global() + Vector3.UP * minf(prop.half.y + 0.26, 1.2)
	_arrow.show()
	_guide.show_field_tip(ROTATE, _nearby_focus(me), _teacher_stand(me))


func _nearby_focus(me: Node3D) -> Vector3:
	var forward: Vector3 = me.flat_forward()
	return me.global_position + forward * 2.1 + forward.cross(Vector3.UP) * 0.75


func _teacher_stand(me: Node3D) -> Vector3:
	var forward: Vector3 = me.flat_forward()
	var side := forward.cross(Vector3.UP)
	var origin := me.global_position + Vector3.UP * 1.1
	var space := me.get_world_3d().direct_space_state
	for sign in [1.0, -1.0]:
		var spot: Vector3 = me.global_position + forward * 1.5 + side * (1.65 * sign)
		var query := PhysicsRayQueryParameters3D.create(origin, spot + Vector3.UP * 1.1, 1 | 2)
		if space.intersect_ray(query).is_empty():
			return Vector3(spot.x, 0.0, spot.z)
	return Vector3.INF


func _spin(me: Node) -> Quaternion:
	return Basis.from_euler(Vector3(me.hold_pitch, me.hold_yaw, me.hold_roll)).get_rotation_quaternion()


func _finish() -> void:
	if _active == "":
		return
	if _active not in ["rotate", "rotated"] and _elapsed >= READ_TIME:
		_remember(_active)
	_active = ""
	_active_context = ""
	_gap = TIP_GAP
	_rotation_prop = null
	if _arrow != null:
		_arrow.hide()
	_guide.close_field_tip()


func _remember(id: String) -> void:
	_seen[id] = true
	if force:
		return
	var file := ConfigFile.new()
	for key: String in _seen:
		file.set_value("completed", key, true)
	file.save(SAVE)


func _build_arrow() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 32:
		var theta := 4.5 * i / 31.0
		var direction := Vector3(cos(theta), 0, sin(theta))
		mesh.surface_add_vertex(direction * 0.93)
		mesh.surface_add_vertex(direction * 1.07)
	mesh.surface_end()
	var end := Vector3(cos(4.5), 0, sin(4.5))
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_add_vertex(end * 0.76)
	mesh.surface_add_vertex(end * 1.24)
	mesh.surface_add_vertex(end + Vector3(-end.z, 0, end.x) * 0.30)
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color("80cfff")
	var model := MeshInstance3D.new()
	model.name = "GuideRotationArrow"
	model.mesh = mesh
	model.material_override = mat
	model.layers = CREW_LAYER
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return model
