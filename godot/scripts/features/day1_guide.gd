extends Node
## 1日目の講師の案内（docs/production/tutorial-cm.md の「講師は、一度に1つだけ教える」）。
## 宅配の箱（features/delivery_box.gd）を開けて、講師のあいさつが済んだあと、紹介動画を納品するまで：
##   ・小型のドローン（scripts/holo_drone.gd）が、次に使う物・行く場所のそばへ先に飛んで行く。
##     講師（青いホログラム）は、ドローンが真下に映す像（少し遅れてついて来る）。目当ての物・場所は、ドローンのライトが照らす
##   ・言うのは、いまやる事を1つだけ（吹き出し。scripts/guide_speech.gd）。できたら次を言う。しばらく進まなければ、同じ事をもう一度言う
##   ・画面の下の案内の先頭にも、いまやる事を1枚だけ出す
##   ・順番を飛ばしても進む（先に済ませた事は、済みとして数える）
##   ・本番中は、場面が変わるたびにひとこと。撮れないままなら、何が足りないか（採点の理由そのまま）を言う
## 教えるのは、操作と流れだけ。何を城に見立てるか・どこに置けばよく映るか、は言わない。
## 何の番か（step）は、全員が自分の画面で、そろって届いている状態（依頼の段階・物の場所・役・場面）から決める。
## 撮れない理由だけは、ホストが決めて全員に送る（理由を数えているのはホストだけ）。
## 講師・輪・矢印は、映画には映らない（制作班にだけ見える層）。ふつうに遊ぶときの1日目だけ（確認では force を立てる）
const TeacherVisual := preload("res://scripts/buzzyama_visual.gd")
const HOLO := preload("res://shaders/hologram.gdshader")
const Drone := preload("res://scripts/holo_drone.gd")
const Speech := preload("res://scripts/guide_speech.gd")
const CREW_LAYER := 1 << 11          # 映画には映らない層（film_camera.gd と同じ番号）
const BLUE := Color(0.3, 0.7, 1.0)
const TEACHER := "BZ"                # 講師の見た目（サングラスのモアイ。宅配の箱の講師と同じ）
const TEACHER_SCALE := 0.62
const LINE_SEC := 5.5                # 1つのせりふを見せる秒数
const AGAIN_SEC := 30.0              # 進まないまま、これだけたったら、同じ事をもう一度言う
const HINT_SEC := 9.0                # 本番中、撮れないままこれだけたったら、足りない事を言う（ホスト）
const BESIDE := Vector3(1.1, 0.0, 0.5)       # 講師が立つ所（目当ての物・場所から）
const SCRIPT_NEAR := 8.0             # 台本が、撮る場所からこの距離までにあれば、置いたと数える
# 講師のせりふ（何の番か → 言う事）
const SAY := {
	"board": "まず、そこの掲示板。\n自分の会社の動画の依頼を、自分で受ける",
	"boxes": "カメラの台を作る。段ボールを2つ、\n青い影の所に積みなさい",
	"camera": "その上に、カメラを載せる。\n三脚？　成功してから買いなさい",
	"castle": "次は、お城。その板を、\n奥の青い影に立てる",
	"blast": "爆発は、この板で十分。\n城のとなりの影に立てる",
	"sign_paint": "最後のカットは、会社の看板。\nスプレー缶で、段ボール板に会社の名前を書く",
	"sign_stand": "書いた看板を、城のとなりに立てかける。\n表を、カメラのほうへ",
	"script": "事務所の机の上に、台本がある。\n持ってきて、撮る場所のそばに置く",
	"role": "主役の社長は、あなた。\n何も持たず、何も見ずに Y",
	"act": "本番の前に、決めポーズの練習。\nZ で、ポーズ！",
	"take": "カチンコを持って F で本番。\n鳴らしたら、カメラの前へ走る！",
	"scene0": "1カット目、社員紹介。\nカメラに近づいて、胸から上を大きく映す",
	"scene1": "2カット目。お城が後ろに映るように、\n少し下がって立つ",
	"scene2": "3カット目、爆発。\n何があっても、動じない！",
	"scene3": "最後。会社の名前を書いた看板の前に、\n全員集合！",
	"hold0": "カット！　でも、まだ続く。\nカメラを次の人へ寄せ直して、台本のそばで 1",
	"hold1": "カット！　まだ続く。止まっている間に、次の用意。\nできたら、台本のそばで 1",
	"hold2": "カット！　次は爆発。書割が後ろに映るかを見て、\n台本のそばで 1",
	"hold3": "最後は、看板の前に全員集合。\n看板が映るかを見て、台本のそばで 1",
	"deliver": "撮れた！　『このテイクを納品』を選べば、\nネットに上がる",
	"retake": "まだ途中で終わっている！　4カット全部撮れたら、\n今日の撮影はおしまい。Space で撮り直す",
	"bye": "以上！　あとは、バズるのを待つだけ。\n……たぶん",
}
# 画面の下の案内に出す、いまやる事（本番中は出さない。場面の知らせが出る）
const TASK := {
	"board": "掲示板で、自分の会社の依頼を受けよう",
	"boxes": "段ボールを2つ、青い影の所に積もう（持ったまま ホイールで、近づける・離す）",
	"camera": "積んだ段ボールの上に、カメラを載せよう（F2 で一人称にすると、載せやすい）",
	"castle": "城の板を、奥の青い影に立てよう（持ったまま 右ドラッグで、向きを回す）",
	"blast": "爆炎の書割を、城のとなりの影に立てよう",
	"sign_paint": "スプレー缶を持って、段ボール板に会社の名前を書こう（F を押している間、吹く）",
	"sign_stand": "書いた看板を、城のとなりに立てかけよう（表をカメラへ）",
	"script": "机の上の台本を、撮る場所のそばに置こう",
	"role": "何も持たず、何も見ずに Y で、社長の役に入ろう",
	"act": "Z で決めポーズを1回やってみよう（H で、ほかの演技を選べる）",
	"take": "カチンコを持って F で本番",
	"hold0": "フィルムは止まっているだけ。次の用意をして、台本のそばで 1（まだ続く）",
	"hold1": "フィルムは止まっているだけ。次の用意をして、台本のそばで 1（まだ続く）",
	"hold2": "フィルムは止まっているだけ。次の用意をして、台本のそばで 1（まだ続く）",
	"hold3": "看板がカメラに映るかを見て、台本のそばで 1（これが最後のカット）",
	"retake": "まだ途中のテイク。Space で撮り直して、4カット続けて撮ろう",
}
# 本番の前に、この順で教える（済んでいない最初の物が、いまの番）
const PREP := ["boxes", "camera", "castle", "blast", "sign_paint", "sign_stand", "script", "role", "act"]
const SIGN_AT := Vector3(-1.9, 0.0, -2.3)    # 看板を立てかける所（撮る場所の中心から。城の、爆炎の書割と反対のとなり）
const SIGN_PAINTED := 0.02                   # 描いたと数える、塗った所の割合（features/signboard.gd の PAINTED と同じ）
# もとの案内のうち、いまやる事と重なる文（これを含む札は外して、いまやる事の札に替える）
const REPLACED := ["今日の依頼を選ぼう", "青い影に合わせて置こう", "軽トラへ運ぼう"]

var game: Node
var force := false                   # 自動確認でも出す
var on := false                      # いま案内している
var step := ""                       # 何の番か（SAY の名前。"" なら、いまは言う事が無い）
var said := ""                       # いま出しているせりふ
var teacher: Node3D
var marker: Node3D                   # 目当ての場所（照らすのは、ドローンのライト）
var drone: Node3D                    # 講師を映すドローン（scripts/holo_drone.gd）
var _speech: Control                 # せりふの吹き出し（scripts/guide_speech.gd）
var _fade_v := 1.0                   # 出てくる・消えるときの、像の濃さ
var _vis: Node3D
var _mats: Array[ShaderMaterial] = []
var _subs: CanvasLayer
var _label: Label
var _done := {}                      # 済んだ番（一度済んだら、戻さない）
var _line_t := 0.0
var _same_t := 0.0                   # 同じ番のまま、たった秒数
var _hint_t := 0.0
var _ended := false                  # 最後のあいさつまで済んだ
var _stand := Vector3.INF            # 講師が向かっている所
var _t := 0.0


func setup() -> void:
	_build()


func _build() -> void:
	teacher = Node3D.new()
	teacher.name = "GuideTeacher"
	teacher.visible = false
	game.add_child(teacher)
	_vis = TeacherVisual.new()
	_vis.name = "Look"
	teacher.add_child(_vis)
	_vis.setup(TEACHER)
	_vis.scale = Vector3.ONE * TEACHER_SCALE
	for mesh: GeometryInstance3D in _vis.find_children("*", "GeometryInstance3D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = HOLO
		_vis.holo_dress(mesh, mat)
		mesh.material_override = mat
		mesh.layers = CREW_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mat)
	# 目当ての場所（見た目は無い。ここを、ドローンのライトが照らす：光の筒と、床の光の輪）
	marker = Node3D.new()
	marker.name = "GuideMarker"
	marker.visible = false
	game.add_child(marker)
	drone = Drone.new()
	drone.name = "GuideDrone"
	drone.visible = false
	game.add_child(drone)
	# せりふは、ドローンへ寄る吹き出し（宅配の箱の講師と同じ見た目）
	_subs = CanvasLayer.new()
	_subs.name = "GuideSubtitles"
	_subs.layer = 20
	add_child(_subs)
	_speech = Speech.new()
	_subs.add_child(_speech)
	_speech.setup(game.font, "講師 バズ山")
	_speech.set_portrait("buzzyama")
	_speech.anchor = drone
	_label = _speech.label


# いま案内する回か：1日目の紹介動画で、箱を開けて、講師のあいさつが済んだあと
func wanted() -> bool:
	var flow: Node = game.production
	if flow == null or _ended or not (bool(flow.daily) or force) or int(flow.day) > 1:
		return false
	var box: Node = game.hooks.feature("delivery_box")
	if box == null or not bool(box.opened) or bool(box.talking()):
		return false
	return int(flow.phase) == 0 or bool(flow.job().get("debut", false))


func _process(delta: float) -> void:
	_t += delta
	var want := wanted()
	if want != on:
		on = want
		if on:
			_appear()
		else:
			_leave()
	if not on:
		return
	var now := _now()
	if now != step:
		step = now
		_same_t = 0.0
		_hint_t = 0.0
		_say(str(SAY.get(step, "")))
	else:
		_same_t += delta
		if _same_t >= AGAIN_SEC and TASK.has(step):
			_same_t = 0.0
			_say(str(SAY[step]))
	_host_hint(delta)
	# せりふは、決まった秒数で消す。メニューを開いている間は隠す
	if said != "":
		_line_t += delta
		if _line_t >= LINE_SEC:
			said = ""
			_vis.play("idle", 0.2)
			if step == "bye":
				_ended = true      # 最後のひとことを言い終えたら、消える
	_label.text = said
	_label.visible = said != "" and not game.ui_blocking()
	_place(delta)


# ---- 何の番か ----

func _now() -> String:
	var flow: Node = game.production
	var st: int = int(game.state)
	var S: Dictionary = game.S
	match int(flow.phase):
		0:
			return "board"
		1, 2, 3:
			return ""          # 会社の前で撮る依頼は、受けるとすぐ撮影の準備に入る（ここは通らない）
		5:
			return "bye"
	var beats: Node = game.get("beats")
	if st == int(S.RESULT):
		# 全部の場面が撮れていないテイク（途中でカットした・フィルムが切れた）：納品ではなく、撮り直しを案内する
		var takes: Array = game.takes
		var got: Array = takes[clampi(int(game.selected), 0, takes.size() - 1)]["passed"] if not takes.is_empty() else []
		if (got.is_empty() or false in got) and takes.size() < int(game.MAX_TAKES):
			return "retake"
		return "deliver"
	if st in [int(S.REPLAY), int(S.DELIVERED), int(S.ORDER)]:
		return ""
	if beats != null and bool(beats.active()) and bool(beats.holding):
		return "hold%d" % int(beats.next_scene)
	if st in [int(S.COUNTDOWN), int(S.TAKE)]:
		return "scene%d" % (int(beats.scene) if beats != null else 0)
	for id: String in PREP:
		if not _is_done(id):
			return id
	return "take"


# その番が済んだか（一度済んだら、あとで物を動かしても、戻さない）
func _is_done(id: String) -> bool:
	if _done.has(id):
		return true
	var ok := false
	var flow: Node = game.production
	var guides: Node = game.hooks.feature("holo_guides")
	match id:
		"boxes":
			# 三脚があれば、段ボールの台は要らない（青い影も出ない）
			ok = guides != null and not (guides.guides as Array).is_empty() and (not _has_guide(guides, "box1") or bool(guides.done("box1")))
		"camera", "castle", "blast":
			ok = guides != null and bool(guides.done(id))
		"script":
			var book: Node3D = flow.script_prop
			ok = book != null and (int(book.holder) != 0 or book.global_position.distance_to(flow.site_center()) < SCRIPT_NEAR)
		"role":
			var stand: Node = game.hooks.feature("stand_ins")
			ok = stand != null and str((stand.holders as Array)[0][0]) != ""
		"act":
			# 役に入ったあと、自分で決めポーズを 1 回やった（言わないと絶対に分からない操作なので、本番の前に 1 回やらせる）
			var me: Node = game.local_player()
			ok = me != null and bool(me.performance_active())
		"sign_paint":
			ok = _sign_board(false) != null
		"sign_stand":
			ok = _sign_board(true) != null
	if ok:
		_done[id] = true
	return ok


# 何か描いてある板（段ボール板・カンペ・等身大パネル）。standing なら、誰も持っていなくて、撮る場所のそばで立っている物だけ
func _sign_board(standing: bool) -> Node3D:
	var cards: Node = game.get("cue_cards")
	if cards == null:
		return null
	var flow: Node = game.production
	for b: Variant in (cards.boards as Dictionary).values():
		var board := b as Node3D
		if board == null or bool(board.get("absent")) or not board.has_method("painted") or float(board.painted()) < SIGN_PAINTED:
			continue
		if standing:
			var c: Vector3 = flow.site_center()
			if int(board.get("holder")) != 0 or board.global_basis.y.normalized().y < 0.6 or Vector2(board.global_position.x - c.x, board.global_position.z - c.z).length() > 9.0:
				continue
		return board
	return null


func _has_guide(guides: Node, gname: String) -> bool:
	for g: Dictionary in guides.guides:
		if str(g["name"]) == gname:
			return true
	return false


# ---- 目当て（講師が立つ所・輪と矢印を出す所） ----

# その種類の物のうち、いちばん近い物（誰も持っていない・しまっていない物）
func _nearest(kind: String, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p: Variant in game.props.values():
		var prop := p as Node3D
		if prop == null or str(prop.get("kind")) != kind or bool(prop.get("absent")) or int(prop.get("holder")) != 0:
			continue
		var d := prop.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = prop
	return best


# 自分が、その種類の物を持っているか
func _holding(kinds: Array) -> bool:
	var me: Node = game.local_player()
	if me == null or int(me.held) == 0 or not game.props.has(me.held):
		return false
	return str(game.props[me.held].kind) in kinds


# いまの番の目当ての場所（無ければ Vector3.INF）。持っていく物は、手に持つまでは物、持ったら置く所
func target() -> Vector3:
	var flow: Node = game.production
	var guides: Node = game.hooks.feature("holo_guides")
	var o: Vector3 = flow.HOME_SET
	match step:
		"board":
			return flow.Office.CONTRACT_POINT
		"boxes":
			var spot: Vector3 = o + guides.CAM_AT
			if _holding(["carton"]):
				return spot
			# 影の所にまだ無い段ボール箱（ふたを閉じてある物。開いた箱は、上に物が載らないので、指さない）
			var far: Node3D = null
			var far_d := INF
			for p: Variant in game.props.values():
				var prop := p as Node3D
				if prop == null or str(prop.get("kind")) != "carton" or bool(prop.get("absent")) or int(prop.get("holder")) != 0 or bool(prop.get("opened")):
					continue
				if Vector2(prop.global_position.x - spot.x, prop.global_position.z - spot.z).length() < 0.9:
					continue
				var me: Node3D = game.local_player() as Node3D
				var d := prop.global_position.distance_to(me.global_position if me != null else spot)
				if d < far_d:
					far_d = d
					far = prop
			return far.global_position if far != null else spot
		"camera":
			var film: Node3D = game.film
			return o + guides.CAM_AT if film == null or int(film.holder) != 0 else film.global_position
		"castle":
			var flat := _nearest("flat", o)
			return o + guides.CASTLE_AT if flat == null or _holding(["flat"]) else flat.global_position
		"blast":
			var boom := _nearest("boomflat", o)
			return o + guides.FLAT_AT if boom == null or _holding(["boomflat"]) else boom.global_position
		"script":
			var book: Node3D = flow.script_prop
			return o + guides.CAM_AT + Vector3(1.8, 0.0, 0.6) if book == null or int(book.holder) != 0 else book.global_position
		"sign_paint":
			# スプレー缶を持つまでは缶、持ったら段ボール板
			if _holding(["spray_paint"]):
				var sheet := _nearest("cardboard", o)
				return sheet.global_position if sheet != null else Vector3.INF
			var can := _nearest("spray_paint", o)
			return can.global_position if can != null else Vector3.INF
		"sign_stand":
			var board := _sign_board(false)
			var me: Node = game.local_player()
			if board == null:
				return Vector3.INF
			return o + SIGN_AT if me != null and int(me.held) == int(board.get("pid")) else board.global_position
		"take":
			var clap: Node3D = game.clapper
			return clap.global_position if clap != null and int(clap.holder) == 0 else Vector3.INF
	return Vector3.INF


# 講師と、輪・矢印を、いまの番の目当てへ
func _place(delta: float) -> void:
	var flow: Node = game.production
	var at := target()
	marker.visible = at != Vector3.INF and not game.ui_blocking()
	if at != Vector3.INF:
		marker.global_position = Vector3(at.x, 0.0, at.z)
	drone.aim(marker.global_position if marker.visible else Vector3.INF)
	# 目当てが無い番（役に入る・本番中など）は、カメラの影のわきに立つ
	var guides: Node = game.hooks.feature("holo_guides")
	var base: Vector3 = at if at != Vector3.INF else flow.HOME_SET + (guides.CAM_AT if guides != null else Vector3(0, 0, 5)) + Vector3(0.9, 0.0, 0.6)
	var stand := Vector3(base.x, 0.0, base.z) + BESIDE
	if _stand == Vector3.INF or stand.distance_to(_stand) > 1.4:
		_go(stand)
	# 講師の像は、ドローンの真下。少し遅れてついて来て、飛んでいる間は乱れる
	var under: Vector3 = drone.under()
	var lag := teacher.global_position.distance_to(under)
	teacher.global_position = under if lag > 9.0 or not is_inside_tree() else teacher.global_position.lerp(under, 1.0 - exp(-7.0 * delta))
	var moving := clampf(float(drone.moving) + lag * 0.5, 0.0, 1.0)
	_vis.set("moving", clampf(lag * 2.5, 0.0, 1.0))      # 像が動いている間は、小石に縄を引かれて揺れながら歩く
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", _fade_v * (1.0 - 0.55 * moving))
		m.set_shader_parameter("flicker", 0.35 + 0.6 * moving)
	# いつも、自分のほうを向く
	var me: Node3D = game.local_player() as Node3D
	if me != null:
		var d: Vector3 = me.global_position - teacher.global_position
		if Vector2(d.x, d.z).length() > 0.3:
			teacher.rotation.y = lerp_angle(teacher.rotation.y, atan2(d.x, d.z), 0.15)


# ドローンが、その場所へ先に飛んで行く（講師の像は、あとからついて来る）
func _go(stand: Vector3) -> void:
	var first := _stand == Vector3.INF
	_stand = stand
	drone.fly_to(stand, first)
	if first:
		teacher.global_position = stand


# ---- 出る・言う・消える ----

func _appear() -> void:
	step = ""
	_stand = Vector3.INF
	teacher.visible = true
	drone.visible = true
	# 箱の中から、ドローンが飛び立つ
	var box: Node = game.hooks.feature("delivery_box")
	if box != null and box.box != null and bool(box.box.visible):
		var from: Vector3 = box.box.global_position
		teacher.global_position = Vector3(from.x, 0.0, from.z)
		drone.global_position = from + Vector3(0.0, 0.6, 0.0)
		# 箱の講師を映していたドローンが残っていれば、それを引き継ぐ（同じ場所から、同じ 1 台に見えるように）
		var prev: Node3D = box.get("drone") as Node3D
		if prev != null and prev.visible:
			drone.global_position = prev.global_position
			prev.visible = false
			var under: Vector3 = prev.under()
			teacher.global_position = Vector3(under.x, 0.0, under.z)
		# 引き継いだ時は、講師が映っていた所（箱の前）から始める。箱の上へ戻らない
		_stand = teacher.global_position
		drone.fly_to(_stand)
	_fade(0.0)
	if is_inside_tree():
		create_tween().tween_method(_fade, 0.0, 1.0, 0.5)
	else:
		_fade(1.0)
	_vis.set_face("happy")


func _leave() -> void:
	step = ""
	said = ""
	_label.visible = false
	marker.visible = false
	drone.aim(Vector3.INF)
	if not teacher.visible:
		drone.visible = false
		return
	if not is_inside_tree():
		teacher.visible = false
		drone.visible = false
		return
	# 像が消えてから、ドローンは空へ飛び去る
	var out := create_tween()
	out.tween_method(_fade, 1.0, 0.0, 0.6)
	out.tween_callback(teacher.hide)
	out.tween_callback(func() -> void: drone.fly_to(drone.under() + Vector3(0.0, 14.0, -6.0)))
	out.tween_interval(2.2)
	out.tween_callback(drone.hide)


func _fade(v: float) -> void:
	_fade_v = v
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", v)


func _say(words: String) -> void:
	if words == "":
		return
	said = words
	_line_t = 0.0
	# 顔の絵の表情：叱る（撮れていない・三脚をねだるな）／得意げ（うまくいった・送り出す）／驚く（爆発）／ふだん
	var look := "normal"
	if words.begins_with("まだ撮れていない") or step == "camera":
		look = "stern"
	elif step == "retake":
		look = "troubled"
	elif step in ["take", "deliver", "bye", "role", "act"]:
		look = "happy"
	elif step == "scene2":
		look = "surprised"
	elif step.begins_with("hold"):
		look = "troubled" if step == "hold3" else "normal"
	_speech.face = look
	_vis.play("ORDER", 0.15, true)
	Sfx.play("ui_select", teacher.global_position, -8.0)


# 本番中、いまの場面が撮れないままなら、何が足りないかを全員に言う（ホスト。理由は、採点が数えている物そのまま）
func _host_hint(delta: float) -> void:
	if not Net.is_host() or not step.begins_with("scene"):
		return
	var beats: Node = game.get("beats")
	if beats == null or int(game.state) != int(game.S.TAKE):
		return
	var i := int(beats.scene)
	if i < 0 or i >= (beats.lit as Array).size() or bool(beats.lit[i]) or i >= (beats.why as Array).size():
		return
	_hint_t += delta
	if _hint_t < HINT_SEC:
		return
	_hint_t = 0.0
	var reason := str(beats._top_reason(i))
	if reason != "":
		game.host_ev("guide_say", [reason])


func hook_events() -> Array:
	return ["guide_say"]


func hook_event(n: String, a: Array) -> void:
	if n == "guide_say" and on:
		# "raw" が付いていれば、そのまま言う（本番の途中でカットしかけた時。production_main.gd の _take_or_cut）
		_say(str(a[0]) if a.size() > 1 and str(a[1]) == "raw" else "まだ撮れていない！\n" + str(a[0]))


# 画面の下の案内：いまやる事を、先頭に1枚出す（もとの案内のうち、同じ事を言っている札は外す）
func hook_hud(_me: Node, _label_text: String, keys: String) -> Dictionary:
	if not on or not TASK.has(step):
		return {}
	var lines: Array = []
	for line: String in keys.split("\n"):
		var kept: Array = []
		for part: String in line.split(" ／ "):
			var dup := false
			for old: String in REPLACED:
				dup = dup or part.contains(old)
			if not dup and part.strip_edges() != "":
				kept.append(part)
		if not kept.is_empty():
			lines.append(" ／ ".join(kept))
	var rest := "\n".join(lines)
	return {"keys_all": str(TASK[step]) + (" ／ " + rest if rest != "" else "")}
