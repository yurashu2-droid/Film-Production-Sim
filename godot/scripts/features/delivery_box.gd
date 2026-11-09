extends Node
## 1日目の始まり（docs/production/tutorial-cm.md）：空っぽの事務所に、代金引換の宅配の箱が落ちてくる。
##   ・始まった時点の貯金は 1,000,600 コイン（ふだんの 600 ＋ 情報商材の代金 100万）
##   ・動けるようになって少しすると、起きた所の目の前に、箱が空から落ちてくる（事務所は屋根なし）。ほこりが立ち、画面が少し揺れる
##   ・落ちた箱は、開けるまでガタガタ動く。中からこもった声がして、ふたのすき間から青い光がもれる。
##     放っておくと、だんだん必死になる。みんなが離れると、いちばん近い人のほうへ跳ねてついて来る
##   ・箱を見て F で開けると、ふたが弾けて、代金が引き落とされる。
##     貯金の数字が画面の真ん中に大きく出て、くるくる減り、貯金の表示の所へ戻っていく（600 だけ残る）
##   ・開いた箱から、情報商材の講師（青いホログラム）が出てきて、短く話す。話の途中で F を押すと、次へ飛ばせる
##   ・開けないまま依頼を受けたり、買い物をしたりしても、そこで箱が開く（払わずに 100万を使うことはできない）
## ふつうに遊ぶときの1日目だけ（自動確認の中では出さない。確認は start() で始める。start(true) なら、落ちてくる所から）。
## 決めるのはホスト（落とす・跳ねる先・開けた・引き落とした）。箱・講師・数字の動きは、全員の画面。ガタガタと中の声は、各自の画面
const Carton := preload("res://scripts/carton.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
const Dust := preload("res://scripts/toon_dust.gd")
const HOLO := preload("res://shaders/hologram.gdshader")
const CREW_LAYER := 1 << 11          # 映画には映らない層（film_camera.gd と同じ番号）
const PRICE := 1000000               # 情報商材の代金
const AT := Vector3(73.1, 0.0, 3.3)  # 箱が落ちる所（事務所の中。起きた所の目の前、机の手前）
const YAW := -0.35
const SIZE := 2.3                    # 箱の見た目の拡大率（段ボール箱の素材。ふつうの段ボール箱は 2.6）
const REACH := 1.8                   # この距離まで近づくと、F で開けられる
const HEAR := 14.0                   # この距離までなら、講師のせりふ・箱の中の声が字幕で出る
const TEACHER := "06"                # 講師の見た目（キャラの素材を、青いホログラムにする）
const TEACHER_SCALE := 0.62
const LINE_SEC := 4.2                # 1つのせりふを見せる秒数
const LINES := [
	"お買い上げ、ありがとうございます！\n代金引換、100万コイン、たしかに",
	"わたくし、講師のバズ山です。\nこの教材で、あなたの会社も絶対バズる！",
	"機材が無い？\n成功者は、機材に頼らない！",
	"カメラは、段ボールに載せれば十分。\n三脚は……成功してから買いなさい",
	"まず、会社の看板を作りなさい。\n段ボールをたたんで、接着剤でつなぐ",
	"スプレーで社名を書いて、\n事務所の入口の上の金具に掛ける",
	"看板が掛かったら、そこの掲示板で\n自分の会社の動画の依頼を受けること",
	"事務所の前に、青い影を映しておきます。\n物を、影に合わせて置くだけ！",
	"撮れたら、ネットに上げる。\nそれで、バズります。たぶん",
]
# ---- 落ちてくる ----
const DROP_WAIT := 2.2               # 動けるようになってから、箱が落ち始めるまでの秒数（空っぽの事務所を見せる間）
const DROP_H := 11.0                 # 落ち始める高さ
const DROP_SEC := 0.8                # 落ちるのにかかる秒数
const SHAKE_REACH := 14.0            # この距離までの人の画面が、落ちた拍子に揺れる
# ---- 開けるまで、落ち着かない ----
const URGENT_SEC := 45.0             # 落ちてからこの秒数で、いちばん必死になる
const MUTTER_SEC := 3.4              # 箱の中の声を1つ見せる秒数
const MUTTER_GAP := 2.2              # 次の声までの間（必死になると短くなる）
const MUTTER_NEAR := 3.2             # この距離に人がいると、その人に呼びかける
# 箱の中の声：誰も近くにいないとき（上から順に。最後まで行ったら、FAR_LOOP から繰り返す）
const FAR := [
	"……もしもーし？",
	"あのー、届いてますよー",
	"開けてくださーい",
	"中、暗いんですけど！",
	"代金引換なんで、開けてもらわないと困るんです！",
	"ちょっと！　聞こえてますよね！？",
	"100万コインの教材ですよ！　放っておく人、います！？",
	"開けて！　開けてってば！",
]
const FAR_LOOP := 3
# 箱の中の声：すぐそばに人がいるとき
const NEAR := [
	"あっ、誰かいる！　開けて開けて！",
	"そこ！　そこのあなた！　ふたを開けるだけ！",
	"近い近い！　もう、開けるだけですよ！",
]
# 箱の中の声：跳ねて追いかけるとき
const CHASE := [
	"待って待って！",
	"置いていかないで！",
	"どこ行くんですか！",
]
# ---- ついて来る ----
const FOLLOW_FAR := 4.5              # いちばん近い人がこれより遠いと、追いかけ始める
const FOLLOW_WAIT := 3.0             # 離れてから、追いかけ始めるまでの秒数
const HOP_REST := 0.9                # 続けて跳ねるときの間
const HOP_LEN := 1.5                 # 1回で跳ねる距離
const HOP_STOP := 2.2                # 人にここまで近づいたら、止まる
const HOP_SEC := 0.42                # 1回跳ねるのにかかる秒数
const HOP_HIGH := 0.55               # 跳ねる高さ

var game: Node
var on := false                      # この会社の1日目で、箱が届く
var landed := false                  # 箱が落ちてきて、床にある
var opened := false                  # 箱を開けた（代金を払った）
var line := -1                       # いま話しているせりふ（-1＝話していない）
var box: StaticBody3D
var _model: Node3D                   # 箱の見た目（ガタガタは、ここだけを動かす。当たり判定は動かさない）
var _pos0 := Vector3.ZERO
var _rot0 := Vector3.ZERO
var _scale0 := Vector3.ONE
var _flaps: Array[Node3D] = []
var _glow: OmniLight3D               # ふたのすき間からもれる青い光
var _teacher: Node3D
var _vis: Node3D
var _bubble: Label                  # せりふの字幕（画面の下。空中の吹き出しは出さない）
var _mutter: Label                  # 箱の中の声の字幕
var _big: Label                     # 引き落としの間、画面の真ん中に出す大きな数字
var _big_sub: Label
var _subs: CanvasLayer
var _mats: Array[ShaderMaterial] = []
var _line_t := 0.0
var _levels0 := ""                   # 箱を開ける前の会社の段階（買い物をしたら、そこで開く）
var _roll: Tween
var _top_y := 0.5                    # 箱の上の高さ（箱の中）
var _await_drop := false             # 落とすのを待っている（ホスト）
var _wait := 0.0
var _moving := false                 # 落ちている・跳ねている途中
var _rest := AT                      # 箱が止まる所（落ちる所・跳ねた先）
var _motion: Tween
var _shiver: Tween
var _glow_tw: Tween
var _since := 0.0                    # 落ちてからの秒数（必死さ）
var _rattle_t := 0.0
var _mutter_t := 0.0
var _far_i := 0
var _near_i := 0
var _chase_i := 0
var _away_t := 0.0                   # みんなが離れている秒数（ホスト）
var _chasing := false
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO


func setup() -> void:
	var flow: Node = game.production
	on = flow != null and bool(flow.daily) and int(flow.day) <= 1
	_build()
	# 箱は、落ちてくるまで見えない（あとから入った人は、ホストから今の様子を受け取る。hook_sync）
	box.visible = false
	_set_solid(false)
	if on and Net.is_host():
		start(true)


# 箱を届ける（ホスト。ふつうに遊ぶときは setup から、落ちてくる所から始める。確認では、ここを呼ぶ）
#   drop：true なら、動けるようになって少ししてから、空から落ちてくる。false なら、はじめから床に置いてある
func start(drop: bool = false) -> void:
	var flow: Node = game.production
	on = true
	opened = false
	line = -1
	_teacher.visible = false
	_bubble.text = ""
	_mutter.text = ""
	_big.visible = false
	_rest = AT
	_kill_motion()
	_close_flaps()
	if Net.is_host():
		flow.wallet = int(flow.START_WALLET) + PRICE
		var hud: Node = game.get("production_hud")
		if hud != null:
			hud.set("_last_wallet", -1)    # 届いた額は、増えた知らせ（＋の浮き文字）を出さずに見せる
		_levels0 = str(flow.levels)
		game.production_sync.rpc(flow.snapshot())
	if drop:
		landed = false
		_await_drop = true
		_wait = 0.0
		box.visible = false
		_set_solid(false)
	else:
		_await_drop = false
		_place(AT)


func _build() -> void:
	box = StaticBody3D.new()
	box.name = "DeliveryBox"
	box.position = AT
	box.rotation.y = YAW
	game.add_child(box)
	var model: Node3D = Carton.closed_model(SIZE)
	box.add_child(model)
	_model = model
	_pos0 = model.position
	_rot0 = model.rotation
	_scale0 = model.scale
	for side: String in ["Front", "Right", "Back", "Left"]:
		_flaps.append(model.find_child("Flap" + side, true, false) as Node3D)
	# 箱の外形（閉じた箱の見た目から測る）。当たり判定と、送り状を貼る面に使う
	var body := AABB()
	var first := true
	var lid_top := 0.0               # 閉じたふたの上の高さ（箱の本当の高さ）
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = box.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		body = bb if first else body.merge(bb)
		first = false
		if String(mi.name).begins_with("Lid"):
			lid_top = maxf(lid_top, bb.end.y)
	# 全部の部品の外形は、手前と上に余分に出ている（ふたの破れ目の部品の分）。
	# 奥行きは、奥の面から真ん中までの2倍、高さは、閉じたふたの上まで
	var front := -body.position.z
	if lid_top <= 0.0:
		lid_top = body.end.y * 0.5
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(body.size.x, lid_top, front * 2.0) * 0.97
	cs.shape = shape
	cs.position = Vector3(body.get_center().x, lid_top * 0.5, 0.0)
	box.add_child(cs)
	# 送り状：箱の正面（起きた所のほう）に貼った紙。箱の見た目に付ける（ガタガタと一緒に動く）
	var paper := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(body.size.x * 0.62, lid_top * 0.66)
	paper.mesh = quad
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.97, 0.95, 0.88)
	pm.roughness = 0.9
	paper.material_override = pm
	box.add_child(paper)
	paper.position = Vector3(body.get_center().x + body.size.x * 0.06, lid_top * 0.5, front + 0.004)
	paper.rotation.z = 0.04
	paper.reparent(model, true)
	# 送り状の字は、紙の絵として書き込む（SubViewport に書いて、紙の面のテクスチャにする。空中に字を浮かせない）
	var vp := SubViewport.new()
	vp.name = "SlipInk"
	vp.size = Vector2i(512, maxi(int(512.0 * quad.size.y / quad.size.x), 64))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	box.add_child(vp)
	var sheet := ColorRect.new()
	sheet.color = Color(0.97, 0.95, 0.88)
	sheet.size = Vector2(vp.size)
	vp.add_child(sheet)
	var words := Label.new()
	words.text = "代金引換　1,000,000 コイン\n絶対バズる！\n会社紹介動画メソッド\n（DVD・投影機つき）"
	words.add_theme_font_override("font", game.font)
	# いちばん長い行（約14文字分）が紙の幅に、4行が紙の高さに収まる大きさ
	words.add_theme_font_size_override("font_size", int(minf(vp.size.x * 0.86 / 14.0, vp.size.y * 0.86 / (4.0 * 1.4))))
	words.add_theme_color_override("font_color", Color(0.12, 0.1, 0.1))
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.size = Vector2(vp.size)
	vp.add_child(words)
	pm.albedo_color = Color.WHITE
	pm.albedo_texture = vp.get_texture()
	_top_y = lid_top
	# 箱の中の投影機の光：ふたの下の青く光る面と、まわりを照らす明かり。ふたが浮いたすき間から見える
	var slit := MeshInstance3D.new()
	slit.name = "Glow"
	var plane := QuadMesh.new()
	plane.size = Vector2(body.size.x * 0.9, front * 2.0 * 0.9)
	slit.mesh = plane
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.45, 0.8, 1.0)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	slit.material_override = sm
	slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slit.rotation.x = -PI * 0.5
	slit.position = Vector3(body.get_center().x, lid_top * 0.8, 0.0)
	box.add_child(slit)
	_glow = OmniLight3D.new()
	_glow.name = "GlowLight"
	_glow.light_color = Color(0.3, 0.65, 1.0)
	_glow.omni_range = 3.4
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	_glow.position = Vector3(body.get_center().x, lid_top + 0.2, 0.0)
	box.add_child(_glow)
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
	# せりふは画面の下の字幕（箱の近くにいる人の画面だけ）
	_subs = CanvasLayer.new()
	_subs.name = "TeacherSubtitles"
	_subs.layer = 20
	add_child(_subs)
	_bubble = _subtitle(26, Color(0.85, 0.95, 1.0), Color(0.02, 0.06, 0.16, 0.95))
	# 箱の中の声は、講師のせりふより小さく、くすんだ色で（こもって聞こえる）
	_mutter = _subtitle(22, Color(0.72, 0.78, 0.84), Color(0.05, 0.06, 0.08, 0.9))
	_mutter.visible = false
	# 引き落としの大きな数字（画面の真ん中の上寄り）と、その下の但し書き
	_big = Label.new()
	_big.name = "BigWallet"
	_big.add_theme_font_override("font", game.font)
	_big.add_theme_font_size_override("font_size", 92)
	_big.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	_big.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 0.95))
	_big.add_theme_constant_override("outline_size", 18)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.visible = false
	_subs.add_child(_big)
	_big_sub = Label.new()
	_big_sub.add_theme_font_override("font", game.font)
	_big_sub.add_theme_font_size_override("font_size", 30)
	_big_sub.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	_big_sub.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02, 0.95))
	_big_sub.add_theme_constant_override("outline_size", 10)
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_sub.text = "代金引換　−1,000,000 コイン"
	_big.add_child(_big_sub)


# 画面の下の字幕を1つ作る
func _subtitle(font_size: int, color: Color, outline: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", game.font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_bottom = -170
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subs.add_child(label)
	return label


func _set_solid(solid: bool) -> void:
	for c: Node in box.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not solid)


func _close_flaps() -> void:
	_crack(0.0)


# 4枚のふたを、同じ開き具合にする
func _crack(amount: float) -> void:
	for i in _flaps.size():
		_flap(i, amount)


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
		_kill_motion()
		box.visible = false
		_bubble.visible = false
		_mutter.visible = false
		_big.visible = false
		_set_solid(false)
		return
	# 字幕は、声が届く所にいる人の画面にだけ出す（メニューを開いている間は隠す）
	var me: Node3D = game.local_player() as Node3D
	var hears: bool = me != null and me.global_position.distance_to(box.global_position) < HEAR and not game.ui_blocking()
	_bubble.visible = _teacher.visible and hears
	_mutter.visible = landed and not opened and hears and _mutter.text != ""
	if Net.is_host():
		if not opened and (int(flow.phase) != 0 or str(flow.levels) != _levels0):
			host_open()
		elif _await_drop:
			# 画面が見えて、動けるようになってから数える（タイトルからの切り替えの間は待つ）
			if bool(game.get("startup_complete")) and not bool(game.get("input_locked")):
				_wait += delta
				if _wait >= DROP_WAIT:
					_await_drop = false
					game.host_ev("box_drop", [])
		elif landed and not opened and not _moving:
			_host_follow(delta)
	if landed and not opened and not _moving:
		_restless(delta, me)
	if line >= 0:
		_line_t += delta
		if _line_t >= LINE_SEC:
			_say(line + 1)


func near(me: Node) -> bool:
	if not on or not landed or me == null:
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
	_await_drop = false
	game.host_ev("box_open", [int(flow.wallet)])
	# 払える分だけ引き落とす（開ける前に買い物をしていても、貯金はマイナスにしない）
	flow.wallet = maxi(0, int(flow.wallet) - PRICE)
	game.production_sync.rpc(flow.snapshot())


func hook_events() -> Array:
	return ["box_open", "box_state", "box_drop", "box_hop"]


func hook_event(n: String, a: Array) -> void:
	match n:
		"box_drop":
			_drop()
		"box_hop":
			_hop(a[0] as Vector3)
		"box_open":
			_open(int(a[0]), true)
		"box_state":
			# あとから入った人：箱が届いているか・開いているか・もう落ちてきたか・どこにあるか
			on = bool(a[0])
			_kill_motion()
			if on and a.size() > 3 and bool(a[2]):
				_place(a[3] as Vector3)
			else:
				landed = false
				box.visible = false
				_set_solid(false)
			if on and bool(a[1]):
				_open(0, false)


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		# 落ちている・跳ねている途中に入った人には、止まる所にもう在る形で渡す
		game.ev.rpc_id(who, "box_state", [on, opened, landed or _moving, _rest])


# ---- 落ちてくる・跳ねる ----

# 動きを止めて、箱の見た目を元の形に戻す
func _kill_motion() -> void:
	for tw: Tween in [_motion, _shiver]:
		if tw != null:
			tw.kill()
	_motion = null
	_shiver = null
	_moving = false
	if _model != null:
		_model.position = _pos0
		_model.rotation = _rot0
		_model.scale = _scale0


# 箱を、床のその場所に置く（落ちる動きなし）
func _place(at: Vector3) -> void:
	_kill_motion()
	_rest = at
	box.position = at
	box.rotation = Vector3(0.0, YAW, 0.0)
	box.visible = true
	_set_solid(true)
	_settle()


# 床に止まった：ここから、開けるまで落ち着かない
func _settle() -> void:
	box.position = _rest
	landed = true
	_moving = false
	_set_solid(true)
	_since = 0.0
	_rattle_t = 0.9
	_mutter_t = 1.6
	_far_i = 0
	_away_t = 0.0
	_chasing = false
	_pulse(0.0)


# 空から落ちてくる（全員の画面）
func _drop() -> void:
	_await_drop = false
	_kill_motion()
	_moving = true
	landed = false
	_rest = AT
	box.position = AT + Vector3(0.0, DROP_H, 0.0)
	box.rotation = Vector3(0.0, YAW, 0.0)
	box.visible = true
	_set_solid(false)
	_pulse(0.0)
	_model.rotation = _rot0 + Vector3(0.5, 0.0, -0.35)       # 傾いたまま落ちてきて、床でまっすぐになる
	Sfx.play("whoosh", AT + Vector3(0.0, 2.0, 0.0), -3.0)
	_motion = create_tween()
	_motion.tween_property(box, "position:y", AT.y, DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.parallel().tween_property(_model, "rotation", _rot0, DROP_SEC)
	_motion.tween_callback(_thud.bind(1.0))
	# つぶれて、少し跳ねて、止まる
	_motion.tween_property(_model, "scale", _scale0 * Vector3(1.14, 0.76, 1.14), 0.06)
	_motion.tween_property(_model, "scale", _scale0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.parallel().tween_property(box, "position:y", AT.y + 0.3, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.tween_property(box, "position:y", AT.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.tween_callback(_thud.bind(0.3))
	_motion.tween_callback(_settle)


# 床に当たった拍子：音・ほこり・青い光・画面の揺れ（power：1＝落ちてきた・小さいほど軽い）
func _thud(power: float) -> void:
	var at: Vector3 = box.global_position
	at.y = _rest.y
	Sfx.play("thump", at, lerpf(-10.0, 0.0, power))
	if power > 0.6:
		Sfx.play("drop", at, -2.0)
	# ほこりは、四方へ（蹴り出しの土ぼこりを、向きを変えて4つ）
	var puffs := 4 if power > 0.6 else 2
	for k in puffs:
		var turn := TAU * float(k) / float(puffs) + YAW
		var dust: Node3D = Dust.new()
		game.add_child(dust)
		dust.global_position = at + Vector3(sin(turn), 0.0, cos(turn)) * 0.25
		dust.burst(Vector3(sin(turn), 0.0, cos(turn)), lerpf(0.6, 1.25, power))
	_pulse(3.0 * power)
	var me: Node3D = game.local_player() as Node3D
	if me != null and me.global_position.distance_to(at) < SHAKE_REACH:
		_shake(0.1 * power)


# いま映しているカメラを、少しの間だけ揺らす（自分の画面だけ）
func _shake(power: float) -> void:
	if power < 0.02:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var tw := cam.create_tween()
	for k in 6:
		var amount := power * (1.0 - float(k) / 6.0)
		tw.tween_property(cam, "h_offset", randf_range(-amount, amount), 0.04)
		tw.parallel().tween_property(cam, "v_offset", randf_range(-amount, amount), 0.04)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


# 青い光が、ぱっと強くなって、元へ戻る
func _pulse(energy: float) -> void:
	if _glow_tw != null:
		_glow_tw.kill()
	var base := 0.9 if _teacher.visible else (0.0 if opened or not landed else 0.25)
	_glow.light_energy = maxf(energy, base)
	if not is_inside_tree() or energy <= base:
		return
	_glow_tw = create_tween()
	_glow_tw.tween_property(_glow, "light_energy", base, 0.55)


# 開けるまで、ガタガタ動いて、中から声がする（各自の画面）
func _restless(delta: float, me: Node3D) -> void:
	_since += delta
	var urge := clampf(_since / URGENT_SEC, 0.0, 1.0)
	_rattle_t -= delta
	if _rattle_t <= 0.0:
		_rattle_t = lerpf(2.6, 0.9, urge) * randf_range(0.8, 1.2)
		_rattle(lerpf(0.6, 1.0, urge))
	_mutter_t -= delta
	if _mutter_t <= 0.0:
		if _mutter.text != "":
			_mutter.text = ""
			_mutter_t = lerpf(MUTTER_GAP, 0.7, urge)
		else:
			_speak(me)


# 箱の中の声を1つ出す（そばに人がいれば、その人へ）
func _speak(me: Node3D) -> void:
	var close := false
	if me != null:
		var d: Vector3 = me.global_position - box.global_position
		close = Vector2(d.x, d.z).length() < MUTTER_NEAR
	var words: String
	# はじめの2つ（「もしもーし？」「届いてますよー」）は、そばに人がいても、そのまま言う（起きた所は、箱のすぐそば）
	if close and _far_i >= 2:
		words = NEAR[_near_i % NEAR.size()]
		_near_i += 1
	else:
		words = FAR[_far_i]
		_far_i = _far_i + 1 if _far_i + 1 < FAR.size() else FAR_LOOP
	_voice(words)
	_rattle(1.0 if close else 0.8)


func _voice(words: String) -> void:
	_mutter.text = "箱の中から「%s」" % words
	_mutter_t = MUTTER_SEC


# ガタッと動く：左右に揺れて少し浮き、ふたが浮いて、青い光がもれる
func _rattle(power: float) -> void:
	if _shiver != null:
		_shiver.kill()
	var tilt := 0.075 * power
	_shiver = create_tween()
	for k in 4:
		var side := 1.0 if k % 2 == 0 else -1.0
		_shiver.tween_property(_model, "rotation", _rot0 + Vector3(randf_range(-tilt, tilt) * 0.6, 0.0, side * tilt), 0.055)
		_shiver.parallel().tween_property(_model, "position:y", _pos0.y + (0.06 * power if k % 2 == 0 else 0.0), 0.055)
	_shiver.tween_property(_model, "rotation", _rot0, 0.07)
	_shiver.parallel().tween_property(_model, "position:y", _pos0.y, 0.07)
	_shiver.parallel().tween_method(_crack, 0.24 * power, 0.0, 0.3)
	_crack(0.24 * power)
	_pulse(1.6 * power)
	Sfx.play("bump", box.global_position, lerpf(-14.0, -6.0, power))


# みんなが離れたら、いちばん近い人のほうへ跳ねてついて来る（ホスト。事務所にいる間だけ）
func _host_follow(delta: float) -> void:
	var flow: Node = game.production
	if int(flow.phase) != 0:
		return
	var who: Node3D = _nearest()
	if who == null:
		return
	var to: Vector3 = who.global_position - box.global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= HOP_STOP + 0.3:
		_chasing = false
		_away_t = 0.0
		return
	if not _chasing and dist < FOLLOW_FAR:
		_away_t = 0.0
		return
	_away_t += delta
	if _away_t < (HOP_REST if _chasing else FOLLOW_WAIT):
		return
	_away_t = 0.0
	_chasing = true
	var step := minf(HOP_LEN, dist - HOP_STOP)
	var target: Vector3 = box.global_position + to / dist * step
	if step > 0.3 and _clear(box.global_position, target):
		game.host_ev("box_hop", [target])


func _nearest() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p: Variant in game.players.values():
		var pl := p as Node3D
		if pl == null or not is_instance_valid(pl):
			continue
		var d: Vector3 = pl.global_position - box.global_position
		var flat := Vector2(d.x, d.z).length()
		if flat < best_d:
			best_d = flat
			best = pl
	return best


# 跳ねる先まで、何にもぶつからず、床の高さも同じか
func _clear(from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = box.get_world_3d().direct_space_state
	var ahead: Vector3 = (to - from).normalized() * 0.7       # 箱の幅の分だけ、先まで見る
	for h: float in [0.3, 0.9]:
		var ray := PhysicsRayQueryParameters3D.create(from + Vector3(0.0, h, 0.0), to + ahead + Vector3(0.0, h, 0.0))
		ray.exclude = [box.get_rid()]
		if not space.intersect_ray(ray).is_empty():
			return false
	var down := PhysicsRayQueryParameters3D.create(to + Vector3(0.0, 1.0, 0.0), to + Vector3(0.0, -0.6, 0.0))
	down.exclude = [box.get_rid()]
	var hit: Dictionary = space.intersect_ray(down)
	return not hit.is_empty() and absf((hit["position"] as Vector3).y - from.y) < 0.15


# ひと跳ねして、その先に止まる（全員の画面）
func _hop(target: Vector3) -> void:
	if opened:
		return
	_kill_motion()
	_moving = true
	box.visible = true
	_hop_from = box.position
	_hop_to = target
	_rest = target
	_voice(CHASE[_chase_i % CHASE.size()])
	_chase_i += 1
	Sfx.play("whoosh_soft", box.global_position, -8.0)
	_motion = create_tween()
	_motion.tween_method(_hop_at, 0.0, 1.0, HOP_SEC)
	_motion.tween_callback(_thud.bind(0.35))
	_motion.tween_callback(_hop_end)


func _hop_at(t: float) -> void:
	box.position = _hop_from.lerp(_hop_to, t) + Vector3(0.0, sin(t * PI) * HOP_HIGH, 0.0)
	_model.rotation = _rot0 + Vector3(sin(t * PI) * 0.22, 0.0, 0.0)


func _hop_end() -> void:
	box.position = _hop_to
	_model.rotation = _rot0
	_moving = false
	_rattle_t = 0.5


# ---- 開く ----

# 箱が開く（全員の画面）。show：ふたが弾け、数字が減り、講師が出てくる。false なら開いた形だけ（あとから入った人）
func _open(before: int, show: bool) -> void:
	# 落ちてくる前・落ちている途中・跳ねている途中に開いたら、止まる所に置いてから開ける
	if not landed or _moving:
		_place(_rest)
	_kill_motion()
	opened = true
	_await_drop = false
	_mutter.text = ""
	_set_solid(true)
	if not show:
		_crack(1.0)
		_pulse(0.0)
		return
	# ふたが弾けて、箱がぽんと膨らみ、青い光があふれる
	var tw := create_tween()
	tw.tween_method(_crack, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shiver = create_tween()
	_shiver.tween_property(_model, "scale", _scale0 * Vector3(1.1, 0.92, 1.1), 0.07)
	_shiver.tween_property(_model, "scale", _scale0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("ui_open", box.global_position)
	Sfx.play("whoosh_soft", box.global_position, -4.0)
	Sfx.play("coin_drain", null)
	_roll_wallet(before, maxi(0, before - PRICE))
	_teacher.visible = true
	_teacher.position = Vector3(0, -0.6, 0)
	_pulse(6.0)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", 0.0)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(_teacher, "position:y", _top_y * 0.95, 1.0).set_delay(0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_method(_fade, 0.0, 1.0, 0.8).set_delay(0.5)
	rise.chain().tween_callback(_say.bind(0))
	_bubble.text = ""


# 貯金の数字を、払う前の額から、払ったあとの額まで、くるくる減らす。
# 箱のそばにいる人の画面には、真ん中に大きく出してから、貯金の表示の所へ飛ばす（どこに出ているかを覚える）
func _roll_wallet(from: int, to: int) -> void:
	var hud: Node = game.get("production_hud")
	if hud == null or not ("wallet_shown" in hud):
		return
	if _roll != null:
		_roll.kill()
	var me: Node3D = game.local_player() as Node3D
	_big.visible = me != null and me.global_position.distance_to(box.global_position) < HEAR
	var view: Vector2 = _big.get_viewport_rect().size
	_big.size = Vector2(1000.0, 120.0)
	_big.position = Vector2((view.x - 1000.0) * 0.5, view.y * 0.2)
	_big.scale = Vector2.ONE
	_big.modulate.a = 1.0
	_big_sub.size = Vector2(1000.0, 44.0)
	_big_sub.position = Vector2(0.0, 124.0)
	_big_sub.modulate.a = 0.0
	_show_wallet(float(from))
	_roll = create_tween()
	_roll.tween_interval(0.35)
	_roll.tween_property(_big_sub, "modulate:a", 1.0, 0.15)
	_roll.parallel().tween_method(_show_wallet, float(from), float(to), 1.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_roll.tween_interval(0.4)
	_roll.tween_callback(_wallet_done)
	_roll.tween_interval(0.25)
	_roll.tween_method(_fly_big, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_roll.tween_callback(_big.hide)


func _show_wallet(v: float) -> void:
	var hud: Node = game.get("production_hud")
	var n := int(round(v))
	if hud != null:
		hud.wallet_shown = n
		_big.text = str(hud.coins(n))


# 減り終わった：貯金の表示を、ふだんの数え方へ戻す。大きな数字は、ここから貯金の表示の所へ飛ぶ
func _wallet_done() -> void:
	var hud: Node = game.get("production_hud")
	if hud == null:
		return
	hud.wallet_shown = -1
	_fly_from = _big.position
	_fly_to = _big.position
	var num: Control = hud.get("_wallet_num") as Control
	if num != null:
		_fly_to = num.global_position


func _fly_big(t: float) -> void:
	var s := lerpf(1.0, 0.22, t)
	_big.scale = Vector2(s, s)
	# 縮んだ数字の真ん中が、貯金の表示の所へ行くように
	var centre: Vector2 = (_fly_from + _big.size * 0.5).lerp(_fly_to, t)
	_big.position = centre - _big.size * 0.5 * s
	_big.modulate.a = 1.0 - t * t * t
	_big_sub.modulate.a = 1.0 - t


func _fade(v: float) -> void:
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", v)
	_bubble.modulate.a = v


func _teacher_gone() -> void:
	_teacher.visible = false
	_pulse(0.0)


# 次のせりふ（最後まで話したら、講師は消える）
func _say(i: int) -> void:
	_line_t = 0.0
	if i >= LINES.size():
		line = -1
		_bubble.text = ""
		var out := create_tween()
		out.tween_method(_fade, 1.0, 0.0, 0.6)
		out.tween_callback(_teacher_gone)
		return
	line = i
	_bubble.text = "バズ山「%s」" % LINES[i]
	_vis.play("ORDER" if i % 2 == 0 else "idle", 0.15, true)
	_vis.set_face("happy")
	Sfx.play("ui_select", box.global_position, -8.0)
