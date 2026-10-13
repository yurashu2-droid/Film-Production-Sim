extends Node
## 監督の机：事務所の机の上の「のぞき箱」（参考スライド）と、発注の電話。
##
## 役割は、窓のメニューでは選ばない。「どこにいて、何をのぞいているか」で決まる。
##   ・のぞき箱を見て F：箱の中の参考スライド（何が欲しいかの絵）が、画面いっぱいに見える。
##     のぞいている間は、まわりの世界が見えない。現物を見られるのは、集めに行った人だけ。
##     声（外のボイスチャット）で「こういう形の物ある？」と聞くしかない。
##   ・のぞけるのは一度に1人（決めるのはホスト。production_flow.gd の peeper）。やめれば、ほかの人がのぞける。
##     のぞいている人のキャラは、箱に顔を寄せた姿勢で止まる。ほかの人から見て「あの人が監督だ」と分かる。
##   ・使えるのは、依頼を受けてから出発するまで（会社にいる間）。
##   ・電話を見て F：その人の画面にだけ、発注の画面が開く（production_main.gd の h_open_order）。
## スライドの中身は production_slides.gd が決め、絵は scripts/ui/slide_view.gd が描く。
## 机の上の物は持ち運べない（物のIDを持たない、ただの置物。照準は自分で調べる）。
## モデルは、小道具の素材（P018 黒電話・P019 双眼鏡・P056 フィルムリール）を、形を変えずに使う。箱の本体だけ、単純な形で組む。
## 出どころ：`小道具大道具(仮)/film_crew_small_props_P001-P025_v01 (1).zip` の `exports/`（P018・P019）と、
## `film_crew_small_props_P051-P075_v01.zip` の `exports/`（P056）。中身は変えず、大きさだけ変えている（電話 1.15倍・双眼鏡 1.5倍・リール 1.15倍）。
## 付属の `README_ja.md` と `LICENSE.txt` を確認（今回のゲーム用に作られたオリジナル素材。外部素材は不使用。編集・再利用可）。
const SlideView := preload("res://scripts/ui/slide_view.gd")
const DeskPose := preload("res://scripts/peep_pose.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
const Office := preload("res://scripts/production_office.gd")

const DESK_EDGE := 0.75                             # 机の、入口側のふち（z）
const BOX_AT := Office.PEEP_BOX                     # のぞき箱（机の上）。のぞき口は入口側（+Z）を向く
const EYE_AT := BOX_AT + Vector3(0, 0.31, 0.44)     # のぞき口（顔を寄せる所）
const PHONE_AT := Office.ORDER_PHONE                # 電話（のぞき箱のとなり）
const NEAR := 7.0                                   # 机からこれより遠い人は、照準を調べない
const AIM_REACH := 3.8                              # 手の届く距離（player.gd の REACH と同じ）
const STEP_UP := 1.6                                # 机の物にここまで寄れば、そちらを向くだけで使える
const FACE_GAP := 0.14                              # 目から、のぞき口まで（顔の厚み）
const HEAD_SINK := 0.22                             # 頭が、のぞき口の面より先へ入ってよい深さ。これより入る大きな頭は、そのぶん下がって立つ
const NAMES := {"peep": "のぞき箱（参考スライド）", "phone": "発注の電話"}

var game: Node
var flow: Node
var view: CanvasLayer
var _root: Node3D
var _aim := ""                  # いま照準が合っている机の物（"peep" / "phone" / ""）
var _mine := false              # 自分がのぞいているか
var _lamp: StandardMaterial3D
var _handset: Array = []        # 電話の受話器の部品（発注中は、持ち上げて見えなくする）
var _tops := {}                 # キャラの種類 → 背の高さ（m）
var _reaches := {}              # キャラの種類 → 前かがみのとき、頭がいちばん前へ出る距離（m）


func setup() -> void:
	flow = game.production
	_root = Node3D.new()
	_root.name = "DirectorDesk"
	flow._office_root.add_child(_root)
	_build_peep_box()
	_build_phone()
	view = SlideView.new()
	view.name = "SlideView"
	add_child(view)
	view.build(game)


# ---- 使えるか・誰が使っているか ----

# のぞき箱を使える時か（依頼を受けてから出発するまで）
func open_hours() -> bool:
	return flow != null and flow.phase == 2 and game.state == game.S.PREP and not flow.slides.is_empty()


# 自分がのぞいている最中か（その間は、歩けず、まわりも見えない）
func peeping() -> bool:
	return _mine


# いま照準が合っている机の物
func aimed() -> String:
	return _aim


# 机の物の名前と、いまの様子（照準を合わせたときに出す）
func thing_label(which: String) -> String:
	var text: String = NAMES.get(which, "")
	var user: int = _user(which)
	if user != 0 and user != Net.my_id():
		text += "（使用中）"
	return text


# 操作の案内（""＝いまは使えない）
func thing_keys(which: String) -> String:
	var me: Node = game.local_player()
	if me == null or _user(which) != 0:
		return ""
	if me.held != 0:
		return "手ぶらで F"
	return "F のぞく" if which == "peep" else "F 発注する"


# その机の物を、いま使っている人（参加者のID。0＝空いている）
func _user(which: String) -> int:
	return int(flow.peeper) if which == "peep" else int(flow.orderer)


# ---- 操作 ----

# 机の物を見て F。ここで受けたら true
func handle_f(me: Node) -> bool:
	if _aim == "" or me == null or me.operating != 0:
		return false
	var user: int = _user(_aim)
	if user != 0 and user != me.peer_id:
		game.hud.show_toast("%s は、いま使用中" % NAMES[_aim], game.Hud.YELLOW)
		Sfx.play("ui_fail", null, -6.0)
		return true
	if me.held != 0:
		game.hud.show_toast("手に持っている物を置いてから", game.Hud.YELLOW)
		return true
	if _aim == "peep":
		game.h_peep.rpc_id(1, true)
	else:
		game.h_open_order.rpc_id(1)
	return true


# のぞいている間の入力：左右で送る、F・Esc・歩こうとする、でやめる。受けたら true
func handle_input(event: InputEvent) -> bool:
	if not _mine or game.input_locked:
		return false
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return true
		match (event as InputEventKey).physical_keycode:
			KEY_A, KEY_LEFT:
				view.step(-1)
			KEY_D, KEY_RIGHT:
				view.step(1)
			KEY_F, KEY_ESCAPE, KEY_W, KEY_S, KEY_UP, KEY_DOWN, KEY_SPACE:
				stop()
		return true
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_DOWN:
					view.step(1)
				MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP:
					view.step(-1)
		return true
	return event is InputEventMouseMotion


# のぞくのをやめる
func stop() -> void:
	if _mine:
		game.h_peep.rpc_id(1, false)


# ---- 毎コマ ----

func _physics_process(_delta: float) -> void:
	_aim = _find_aim()


func _find_aim() -> String:
	var found: String = _find_desk()
	# 仲間（段ボール頭）の頭の道具箱を見ているときは、そちらが先（F は「頭から取り出す」になる。cast_talent.gd）
	if found != "" and game.talent != null and game.talent.crew_aimed(game.local_player()) != 0:
		return ""
	return found


# 照準の先にある机の物（""＝無い）
func _find_desk() -> String:
	var me: Node3D = game.local_player()
	if me == null or me.cam == null or flow == null or flow.phase != 2 or game.state != game.S.PREP:
		return ""
	if _mine or me.operating != 0 or game.ui_blocking():
		return ""
	if me.global_position.distance_to(BOX_AT) > NEAR:
		return ""
	var from: Vector3 = me.cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - me.cam.global_basis.z * 9.0, 1 | 2 | 4 | 16)
	var skip: Array[RID] = []
	if me.held != 0 and game.props.has(me.held):
		skip.append((game.props[me.held] as CollisionObject3D).get_rid())
	query.exclude = skip
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var body: Object = hit["collider"]
		if body is StaticBody3D and (body as Node).has_meta("desk_thing"):
			if (hit["position"] as Vector3).distance_to(me.global_position + Vector3(0, 1.0 + me.neck, 0)) > AIM_REACH:
				return ""
			return str((body as Node).get_meta("desk_thing"))
	# 机のすぐ前に立って、その物のほうを向いていれば、照準が少し外れていても使える
	# （机の上の物は小さく、後ろからの視点では、入口の看板に隠れることもある）。ほかの物を狙っているときは、そちらが先
	if me.target != null:
		return ""
	var best := ""
	var nearest := STEP_UP
	for thing: String in ["peep", "phone"]:
		var to: Vector3 = (BOX_AT if thing == "peep" else PHONE_AT) - me.global_position
		to.y = 0.0
		if to.length() < nearest and to.normalized().dot(me.flat_forward()) > 0.75:
			best = thing
			nearest = to.length()
	return best


func _process(_delta: float) -> void:
	if flow == null:
		return
	var me: Node = game.local_player()
	var mine: bool = me != null and flow.phase == 2 and int(flow.peeper) == me.peer_id
	if mine != _mine:
		_mine = mine
		if mine:
			_begin(me)
		else:
			view.close()
			Sfx.play("ui_back", null, -4.0)
	if _mine:
		view.sync(flow.slides, flow.JOBS)
	_sync_poses()
	# ランプ：誰かがのぞいている間は、明るく灯る
	if _lamp != null:
		_lamp.emission_energy_multiplier = 3.2 if int(flow.peeper) != 0 else 0.9
	# 受話器：発注中は、持ち上げてある
	var calling: bool = _desk_caller() != 0
	for part: Node3D in _handset:
		part.visible = not calling


# のぞき始めた：箱の前に立って、顔を寄せる
func _begin(me: Node) -> void:
	var stand: Vector3 = stand_point(me)
	me.global_position = stand
	me.velocity = Vector3.ZERO
	me.aim_yaw = 0.0
	me.aim_pitch = -0.2
	me.vis.rotation.y = PI
	if me.has_method("cancel_performance"):
		me.cancel_performance()
	view.open(flow.slides, flow.JOBS)
	Sfx.play("ui_open", null, -4.0)


# その人が、のぞくときに立つ所。背の高さに合わせて、顔がのぞき口に来る距離にする
func stand_point(pl: Node) -> Vector3:
	var reach: float = sin(lean_of(pl)) * (_eye_height(pl) - _pivot_height(pl))
	# 頭の大きなキャラ（段ボール頭）は、頭が箱へめり込まないよう、そのぶん下がって立つ
	var back: float = maxf(0.0, _head_reach(pl) - (reach + FACE_GAP) - HEAD_SINK)
	return Vector3(EYE_AT.x, 0.05, maxf(DESK_EDGE + 0.36, EYE_AT.z + reach + FACE_GAP + back))


# のぞいているとき、その人の頭が、のぞき口の面より先へどれだけ入るか（m。負＝届いていない）
func head_sink(pl: Node) -> float:
	return _head_reach(pl) - (stand_point(pl).z - EYE_AT.z)


# 前かがみになったとき、頭のあたり（背の6割より上）が、体の軸からいちばん前へ出る距離（m）。
# キャラの形（頂点）から測る。重いので、キャラの種類ごとに1回だけ
func _head_reach(pl: Node) -> float:
	var vis: Node3D = pl.vis
	if not _reaches.has(vis.tag):
		var lean: float = lean_of(pl)
		var pivot: float = _pivot_height(pl)
		var head_from: float = _eye_height(pl) / 0.8 * 0.6
		var to_vis: Transform3D = vis.global_transform.affine_inverse()
		var far := 0.0
		for mesh: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null or mesh.mesh == null:
				continue
			var place: Transform3D = to_vis * mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for point: Vector3 in points:
					# キャラの素材は、前が +Z。上体を lean だけ倒すと、高い所ほど前へ出る
					var at: Vector3 = place * point
					if at.y > head_from:
						far = maxf(far, at.z * cos(lean) + (at.y - pivot) * sin(lean))
		_reaches[vis.tag] = far
	return float(_reaches[vis.tag])


# その人が、のぞき口の高さまで顔を下げるのに、上体を倒す角度
func lean_of(pl: Node) -> float:
	var pivot: float = _pivot_height(pl)
	var span: float = maxf(_eye_height(pl) - pivot, 0.2)
	return acos(clampf((EYE_AT.y - pivot) / span, 0.72, 0.985))


func _eye_height(pl: Node) -> float:
	var vis: Node3D = pl.vis
	if not _tops.has(vis.tag):
		var top := 0.0
		for mesh: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				top = maxf(top, mesh.get_aabb().end.y * CastVisual.SCALE)
		_tops[vis.tag] = top if top > 0.5 else 1.6
	return float(_tops[vis.tag]) * 0.8


func _pivot_height(pl: Node) -> float:
	var skel: Skeleton3D = pl.vis.skel
	var body: int = skel.find_bone("BODY")
	return skel.get_bone_global_rest(body).origin.y * CastVisual.SCALE if body >= 0 else 0.45


# 電話のそばで発注している人（外のレンタルのカウンターで開いた人は、数えない）
func _desk_caller() -> int:
	var who: int = _user("phone")
	if who == 0 or flow.phase != 2 or not game.players.has(who):
		return 0
	return who if (game.players[who] as Node3D).global_position.distance_to(PHONE_AT) < 2.6 else 0


# 机の物を使っている人の姿勢を、全員の画面で付ける・外す
func _sync_poses() -> void:
	var caller: int = _desk_caller()
	for id: int in game.players:
		var pl: Node = game.players[id]
		var mode := ""
		if flow.phase == 2 and id == int(flow.peeper):
			mode = "peep"
		elif id == caller:
			mode = "phone"
		var skel: Skeleton3D = pl.vis.skel
		var pose: Node = skel.get_node_or_null("DeskPose")
		if mode == "":
			if pose != null:
				skel.remove_child(pose)
				pose.queue_free()
			continue
		if pose == null:
			pose = DeskPose.new()
			pose.name = "DeskPose"
			skel.add_child(pose)
		pose.mode = mode
		pose.lean = lean_of(pl)


# ---- 机の上の物を作る ----

# のぞき箱：木の箱に、のぞき口（双眼鏡）・フィルムリール・ランプの小屋・差し込んだスライド
func _build_peep_box() -> void:
	var box := Node3D.new()
	box.name = "PeepBox"
	box.position = BOX_AT
	_root.add_child(box)
	var wood := Color("8a6240")
	var dark := Color("2a2622")
	var brass := Color("c9a24a")
	for x: float in [-0.21, 0.21]:
		for z: float in [-0.22, 0.18]:
			_block(box, Vector3(x, 0.03, z), Vector3(0.06, 0.06, 0.06), dark)
	_block(box, Vector3(0, 0.27, -0.02), Vector3(0.52, 0.42, 0.5), wood)
	_block(box, Vector3(0, 0.485, -0.02), Vector3(0.56, 0.025, 0.54), Color("6b4a2e"))
	_block(box, Vector3(0, 0.065, -0.02), Vector3(0.56, 0.025, 0.54), Color("6b4a2e"))
	# のぞき口：黒いひさしと、双眼鏡（接眼の側を、のぞく人へ向ける）
	_block(box, Vector3(0, 0.31, 0.26), Vector3(0.44, 0.26, 0.07), dark)
	var eyes := _model(box, "P019_binoculars", Vector3(0, 0.215, 0.25), 1.5)
	eyes.rotation = Vector3(0.16, PI, 0)
	# 横のフィルムリール
	var reel := _model(box, "P056_film_reel", Vector3(0.30, 0.12, -0.06), 1.15)
	reel.rotation.y = PI * 0.5
	_block(box, Vector3(0.27, 0.29, -0.06), Vector3(0.05, 0.05, 0.05), brass)
	# 上：ランプの小屋（光が漏れる）と、差し込んだスライド
	_block(box, Vector3(-0.1, 0.56, -0.12), Vector3(0.2, 0.13, 0.2), dark)
	_block(box, Vector3(-0.1, 0.65, -0.12), Vector3(0.09, 0.06, 0.09), dark)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color("ffe9b0")
	_lamp.emission_enabled = true
	_lamp.emission = Color("ffd27a")
	_lamp.emission_energy_multiplier = 0.9
	for side: float in [-1.0, 1.0]:
		var slit := _block(box, Vector3(-0.1 + side * 0.101, 0.56, -0.12), Vector3(0.006, 0.07, 0.12), Color.WHITE)
		slit.material_override = _lamp
	var glow := _block(box, Vector3(-0.1, 0.56, -0.019), Vector3(0.12, 0.07, 0.006), Color.WHITE)
	glow.material_override = _lamp
	_block(box, Vector3(0.13, 0.515, -0.04), Vector3(0.2, 0.04, 0.32), dark)
	for i in 6:
		var card := _block(box, Vector3(0.13, 0.575, -0.16 + i * 0.048), Vector3(0.15, 0.11, 0.008), Color("efe6cc"))
		card.rotation.x = -0.12
		_block(card, Vector3(0, 0.005, 0.005), Vector3(0.1, 0.07, 0.002), Color("26272b"))
	# 正面の札
	_block(box, Vector3(0, 0.13, 0.232), Vector3(0.3, 0.07, 0.006), Color("efe6cc"))
	var plate := Label3D.new()
	plate.text = "参考スライド"
	plate.font = game.font
	plate.font_size = 64
	plate.pixel_size = 0.00065
	plate.modulate = Color("26272b")
	plate.outline_size = 0
	plate.position = Vector3(0, 0.13, 0.237)
	box.add_child(plate)
	_solid(box, "peep", Vector3(0, 0.33, 0.07), Vector3(0.62, 0.66, 0.78))


# 電話：黒電話と、となりのカタログ
func _build_phone() -> void:
	var desk := Node3D.new()
	desk.name = "OrderPhone"
	desk.position = PHONE_AT
	_root.add_child(desk)
	var phone := _model(desk, "P018_rotary_phone", Vector3.ZERO, 1.15)
	for part: Node in phone.find_children("*", "MeshInstance3D", true, false):
		if "receiver" in part.name or "earpiece" in part.name:
			_handset.append(part)
	# カタログ（発注の冊子）
	var book := Node3D.new()
	book.position = Vector3(-0.42, 0, 0.02)
	book.rotation.y = 0.22
	desk.add_child(book)
	_block(book, Vector3(0, 0.014, 0), Vector3(0.26, 0.028, 0.34), Color("efe6cc"))
	_block(book, Vector3(0, 0.031, 0), Vector3(0.27, 0.006, 0.35), Color("f2c230"))
	_block(book, Vector3(0, 0.035, -0.09), Vector3(0.27, 0.002, 0.08), Color("26272b"))
	var title := Label3D.new()
	title.text = "レンタル"
	title.font = game.font
	title.font_size = 64
	title.pixel_size = 0.00075
	title.modulate = Color("f4f1ea")
	title.outline_size = 0
	title.position = Vector3(0, 0.0375, -0.09)
	title.rotation.x = -PI * 0.5
	book.add_child(title)
	_solid(desk, "phone", Vector3(-0.16, 0.16, 0.0), Vector3(0.92, 0.32, 0.46))


func _model(parent: Node3D, file: String, at: Vector3, size: float) -> Node3D:
	var model: Node3D = (load("res://assets/props/%s.glb" % file) as PackedScene).instantiate()
	model.position = at
	model.scale = Vector3.ONE * size
	parent.add_child(model)
	return model


func _block(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


# 当たり判定（歩く人・置いた物が通り抜けない）。照準を調べるときの目印にもなる
func _solid(parent: Node3D, thing: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	body.set_meta("desk_thing", thing)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
