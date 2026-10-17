extends Node
## 1日目の始まり（docs/production/tutorial-cm.md）：事務所に、代金引換の宅配の箱がひとつ届いている。
##   ・始まった時点の貯金は 1,000,600 コイン（ふだんの 600 ＋ 情報商材の代金 100万）
##   ・箱を見て F で開けると、代金が引き落とされて、貯金の数字がくるくる減る（600 だけ残る）
##   ・開いた箱から、情報商材の講師（青いホログラム）が出てきて、短く話す。話の途中で F を押すと、次へ飛ばせる
##   ・開けないまま依頼を受けたり、買い物をしたりしても、そこで箱が開く（払わずに 100万を使うことはできない）
## ふつうに遊ぶときの1日目だけ（自動確認の中では出さない。確認は start() で始める）。
## 決めるのはホスト（開けた・引き落とした）。箱・講師・数字の動きは、全員の画面
const Carton := preload("res://scripts/carton.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
const HOLO := preload("res://shaders/hologram.gdshader")
const CREW_LAYER := 1 << 11          # 映画には映らない層（film_camera.gd と同じ番号）
const PRICE := 1000000               # 情報商材の代金
const AT := Vector3(73.1, 0.0, 3.3)  # 箱を置く所（事務所の中。起きた所の目の前、机の手前）
const YAW := -0.35
const SIZE := 2.3                    # 箱の見た目の拡大率（段ボール箱の素材。ふつうの段ボール箱は 2.6）
const REACH := 1.8                   # この距離まで近づくと、F で開けられる
const TEACHER := "06"                # 講師の見た目（キャラの素材を、青いホログラムにする）
const TEACHER_SCALE := 0.62
const LINE_SEC := 4.2                # 1つのせりふを見せる秒数
const LINES := [
	"お買い上げ、ありがとうございます！\n代金引換、100万コイン、たしかに",
	"わたくし、講師のバズ山です。\nこの教材で、あなたの会社も絶対バズる！",
	"機材が無い？\n成功者は、機材に頼らない！",
	"カメラは、段ボールに載せれば十分。\n三脚は……成功してから買いなさい",
	"まずは、そこの掲示板で\n自分の会社の動画の依頼を受けること",
	"事務所の前に、青い影を映しておきます。\n物を、影に合わせて置くだけ！",
	"撮れたら、ネットに上げる。\nそれで、バズります。たぶん",
]

var game: Node
var on := false                      # この会社の1日目で、箱が届いている
var opened := false                  # 箱を開けた（代金を払った）
var line := -1                       # いま話しているせりふ（-1＝話していない）
var box: StaticBody3D
var _flaps: Array[Node3D] = []
var _teacher: Node3D
var _vis: Node3D
var _bubble: Label3D
var _mats: Array[ShaderMaterial] = []
var _line_t := 0.0
var _levels0 := ""                   # 箱を開ける前の会社の段階（買い物をしたら、そこで開く）
var _roll: Tween
var _top_y := 0.5                    # 箱の上の高さ（箱の中）


func setup() -> void:
	var flow: Node = game.production
	on = flow != null and bool(flow.daily) and int(flow.day) <= 1
	_build()
	box.visible = on
	_set_solid(on)
	if on and Net.is_host():
		start()


# 箱を届ける（ホスト。ふつうに遊ぶときは setup から。確認では、ここを呼ぶ）
func start() -> void:
	var flow: Node = game.production
	on = true
	opened = false
	box.visible = true
	_set_solid(true)
	_close_flaps()
	if Net.is_host():
		flow.wallet = int(flow.START_WALLET) + PRICE
		var hud: Node = game.get("production_hud")
		if hud != null:
			hud.set("_last_wallet", -1)    # 届いた額は、増えた知らせ（＋の浮き文字）を出さずに見せる
		_levels0 = str(flow.levels)
		game.production_sync.rpc(flow.snapshot())


func _build() -> void:
	box = StaticBody3D.new()
	box.name = "DeliveryBox"
	box.position = AT
	box.rotation.y = YAW
	game.add_child(box)
	var model: Node3D = Carton.closed_model(SIZE)
	box.add_child(model)
	for side: String in ["Front", "Right", "Back", "Left"]:
		_flaps.append(model.find_child("Flap" + side, true, false) as Node3D)
	# 箱の外形（閉じた箱の見た目から測る）。当たり判定と、送り状を貼る面に使う
	var body := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = box.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		body = bb if first else body.merge(bb)
		first = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# 本体の見た目の外形は、手前に余分に出ている（閉じたふたの写しの分）。奥行きは、奥の面から真ん中までの2倍にする
	var front := -body.position.z
	shape.size = Vector3(body.size.x, body.size.y, front * 2.0) * 0.97
	cs.shape = shape
	cs.position = Vector3(body.get_center().x, body.get_center().y, 0.0)
	box.add_child(cs)
	# 送り状：箱の正面（起きた所のほう）に貼った紙
	var paper := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(body.size.x * 0.62, body.size.y * 0.5)
	paper.mesh = quad
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.97, 0.95, 0.88)
	pm.roughness = 0.9
	paper.material_override = pm
	paper.position = Vector3(body.get_center().x + body.size.x * 0.06, body.position.y + body.size.y * 0.45, front + 0.004)
	paper.rotation.z = 0.04
	box.add_child(paper)
	var slip := Label3D.new()
	slip.text = "代金引換　1,000,000 コイン\n絶対バズる！\n会社紹介動画メソッド\n（DVD・投影機つき）"
	slip.font = game.font
	slip.font_size = 48
	slip.outline_size = 0
	slip.pixel_size = quad.size.x * 0.9 / (48.0 * 14.0)    # いちばん長い行（約14文字分）が、紙の幅に収まる
	slip.modulate = Color(0.12, 0.1, 0.1)
	slip.position = paper.position + Vector3(0, 0, 0.003)
	slip.rotation.z = paper.rotation.z
	box.add_child(slip)
	_top_y = body.end.y
	# 講師（青いホログラム）。箱が開くまでは、箱の中に隠しておく
	_teacher = Node3D.new()
	_teacher.name = "Teacher"
	_teacher.visible = false
	box.add_child(_teacher)
	_vis = CastVisual.new()
	_vis.name = "Look"
	_teacher.add_child(_vis)
	_vis.setup(TEACHER)
	_vis.scale = Vector3.ONE * TEACHER_SCALE
	_vis.rotation.y = PI * 0.12
	for mesh: GeometryInstance3D in _vis.find_children("*", "GeometryInstance3D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = HOLO
		mesh.material_override = mat
		mesh.layers = CREW_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mat)
	_bubble = Label3D.new()
	_bubble.font = game.font
	_bubble.font_size = 56
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.02, 0.08, 0.2, 0.9)
	_bubble.modulate = Color(0.75, 0.92, 1.0)
	_bubble.pixel_size = 0.0017
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.layers = CREW_LAYER
	_bubble.position = Vector3(0, _top_y + 0.85, 0)
	_teacher.add_child(_bubble)


func _set_solid(solid: bool) -> void:
	for c: Node in box.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not solid)


func _close_flaps() -> void:
	for i in _flaps.size():
		_flap(i, 0.0)


# 箱のふたの開き具合（0＝閉じている・1＝開いている。carton.gd と同じ開き方）
func _flap(i: int, amount: float) -> void:
	var flap: Node3D = _flaps[i]
	if flap == null:
		return
	var t := smoothstep(0.0, 1.0, clampf(amount * 1.25 - (0.0 if i in [0, 2] else 0.25), 0.0, 1.0))
	var angle: float = lerpf(Carton.CLOSED[i], Carton.OPEN[i], t)
	if i in [0, 2]:
		flap.rotation.x = angle
	else:
		flap.rotation.z = angle


func _process(delta: float) -> void:
	var flow: Node = game.production
	if flow == null or not on:
		return
	if int(flow.day) > 1:
		# 2日目からは、箱は片づけてある
		on = false
		box.visible = false
		_set_solid(false)
		return
	if Net.is_host() and not opened and (int(flow.phase) != 0 or str(flow.levels) != _levels0):
		host_open()
	if line >= 0:
		_line_t += delta
		if _line_t >= LINE_SEC:
			_say(line + 1)


func near(me: Node) -> bool:
	if not on or me == null:
		return false
	var d: Vector3 = (me as Node3D).global_position - box.global_position
	return Vector2(d.x, d.z).length() < REACH


func hook_f(me: Node) -> bool:
	if not near(me):
		return false
	if not opened:
		if me.held != 0:
			return false
		h_open.rpc_id(1)
		return true
	if line >= 0:
		_say(line + 1)        # せりふを飛ばす（自分の画面だけ）
		return true
	return false


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	if not near(me):
		return {}
	if not opened and me.held == 0:
		return {"keys": "F 宅配の箱を開ける（代金引換）"}
	if line >= 0:
		return {"keys": "F 講師の話を飛ばす"}
	return {}


@rpc("any_peer", "call_local", "reliable")
func h_open() -> void:
	if Net.is_host():
		host_open()


# 箱を開けて、代金を払う（ホスト）
func host_open() -> void:
	var flow: Node = game.production
	if opened or not on:
		return
	game.host_ev("box_open", [int(flow.wallet)])
	# 払える分だけ引き落とす（開ける前に買い物をしていても、貯金はマイナスにしない）
	flow.wallet = maxi(0, int(flow.wallet) - PRICE)
	game.production_sync.rpc(flow.snapshot())


func hook_events() -> Array:
	return ["box_open", "box_state"]


func hook_event(n: String, a: Array) -> void:
	match n:
		"box_open":
			_open(int(a[0]), true)
		"box_state":
			on = bool(a[0])
			box.visible = on
			_set_solid(on)
			if bool(a[1]):
				_open(0, false)


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "box_state", [on, opened])


# 箱が開く（全員の画面）。show：ふたが開き、数字が減り、講師が出てくる。false なら開いた形だけ（あとから入った人）
func _open(before: int, show: bool) -> void:
	opened = true
	_set_solid(true)
	if not show:
		for i in _flaps.size():
			_flap(i, 1.0)
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		for i in _flaps.size():
			_flap(i, v), 0.0, 1.0, 0.45)
	Sfx.play("ui_open", box.global_position)
	Sfx.play("coin_drain", null)
	_roll_wallet(before, maxi(0, before - PRICE))
	_teacher.visible = true
	_teacher.position = Vector3(0, -0.6, 0)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", 0.0)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(_teacher, "position:y", _top_y * 0.5, 1.0).set_delay(0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_method(_fade, 0.0, 1.0, 0.8).set_delay(0.5)
	rise.chain().tween_callback(_say.bind(0))
	_bubble.text = ""


# 画面の貯金の数字を、払う前の額から、払ったあとの額まで、くるくる減らす
func _roll_wallet(from: int, to: int) -> void:
	var hud: Node = game.get("production_hud")
	if hud == null or not ("wallet_shown" in hud):
		return
	if _roll != null:
		_roll.kill()
	hud.wallet_shown = from
	_roll = create_tween()
	_roll.tween_interval(0.35)
	_roll.tween_method(func(v: float) -> void: hud.wallet_shown = int(round(v)), float(from), float(to), 1.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_roll.tween_interval(0.4)
	_roll.tween_callback(func() -> void: hud.wallet_shown = -1)


func _fade(v: float) -> void:
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", v)
	_bubble.modulate.a = v


# 次のせりふ（最後まで話したら、講師は消える）
func _say(i: int) -> void:
	_line_t = 0.0
	if i >= LINES.size():
		line = -1
		_bubble.text = ""
		var out := create_tween()
		out.tween_method(_fade, 1.0, 0.0, 0.6)
		out.tween_callback(func() -> void: _teacher.visible = false)
		return
	line = i
	_bubble.text = LINES[i]
	_vis.play("ORDER" if i % 2 == 0 else "idle", 0.15, true)
	_vis.set_face("happy")
	Sfx.play("ui_select", box.global_position, -8.0)
