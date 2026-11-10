extends Node
## 1日目の講師の案内（docs/production/tutorial-cm.md の「講師は、一度に1つだけ教える」）。
## 宅配の箱（features/delivery_box.gd）を開けて、講師のあいさつが済んだあと、紹介動画を納品するまで：
##   ・講師（青いホログラム）が、次に使う物・行く場所のそばへ先に行って立つ。その物・場所には、青い輪と矢印が出る
##   ・言うのは、いまやる事を1つだけ（画面の下の字幕）。できたら次を言う。しばらく進まなければ、同じ事をもう一度言う
##   ・画面の下の案内の先頭にも、いまやる事を1枚だけ出す
##   ・順番を飛ばしても進む（先に済ませた事は、済みとして数える）
##   ・本番中は、場面が変わるたびにひとこと。撮れないままなら、何が足りないか（採点の理由そのまま）を言う
## 教えるのは、操作と流れだけ。何を城に見立てるか・どこに置けばよく映るか、は言わない。
## 何の番か（step）は、全員が自分の画面で、そろって届いている状態（依頼の段階・物の場所・役・場面）から決める。
## 撮れない理由だけは、ホストが決めて全員に送る（理由を数えているのはホストだけ）。
## 講師・輪・矢印は、映画には映らない（制作班にだけ見える層）。ふつうに遊ぶときの1日目だけ（確認では force を立てる）
const CastVisual := preload("res://scripts/cast_visual.gd")
const HOLO := preload("res://shaders/hologram.gdshader")
const CREW_LAYER := 1 << 11          # 映画には映らない層（film_camera.gd と同じ番号）
const BLUE := Color(0.3, 0.7, 1.0)
const TEACHER := "06"                # 講師の見た目（宅配の箱の講師と同じ）
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
	"script": "事務所の机の上に、台本がある。\n持ってきて、撮る場所のそばに置く",
	"role": "主役の社長は、あなた。\n何も持たず、何も見ずに Y",
	"take": "カチンコを持って F で本番。\n鳴らしたら、カメラの前へ走る！",
	"scene0": "1カット目、社員紹介。\nカメラに近づいて、胸から上を大きく映す",
	"scene1": "2カット目。お城が後ろに映るように、\n少し下がって立つ",
	"scene2": "3カット目、爆発。\n何があっても、動じない！",
	"scene3": "最後。会社の名前を書いた看板の前に、\n全員集合！",
	"hold0": "カット！　カメラを次の人へ寄せ直して、\n台本のそばで 1 を押す",
	"hold1": "カット！　止まっている間に、次の用意。\nできたら、台本のそばで 1 を押す",
	"hold2": "カット！　次は爆発。書割が後ろに映るかを見て、\n台本のそばで 1",
	"hold3": "最後は看板。段ボール箱を Shift+F でたたんで、\nスプレーで社名を書く。立てたら、1",
	"deliver": "撮れた！　『このテイクを納品』を選べば、\nネットに上がる",
	"bye": "以上！　あとは、バズるのを待つだけ。\n……たぶん",
}
# 画面の下の案内に出す、いまやる事（本番中は出さない。場面の知らせが出る）
const TASK := {
	"board": "掲示板で、自分の会社の依頼を受けよう",
	"boxes": "段ボールを2つ、青い影の所に積もう",
	"camera": "積んだ段ボールの上に、カメラを載せよう",
	"castle": "城の板を、奥の青い影に立てよう",
	"blast": "爆炎の書割を、城のとなりの影に立てよう",
	"script": "机の上の台本を、撮る場所のそばに置こう",
	"role": "何も持たず、何も見ずに Y で、社長の役に入ろう",
	"take": "カチンコを持って F で本番",
}
# 本番の前に、この順で教える（済んでいない最初の物が、いまの番）
const PREP := ["boxes", "camera", "castle", "blast", "script", "role"]
# もとの案内のうち、いまやる事と重なる文（これを含む札は外して、いまやる事の札に替える）
const REPLACED := ["今日の依頼を選ぼう", "青い影に合わせて置こう", "軽トラへ運ぼう"]

var game: Node
var force := false                   # 自動確認でも出す
var on := false                      # いま案内している
var step := ""                       # 何の番か（SAY の名前。"" なら、いまは言う事が無い）
var said := ""                       # いま出しているせりふ
var teacher: Node3D
var marker: Node3D                   # 目当ての青い輪と矢印
var _ring: MeshInstance3D
var _arrow: MeshInstance3D
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
var _glide: Tween
var _t := 0.0


func setup() -> void:
	_build()


func _build() -> void:
	teacher = Node3D.new()
	teacher.name = "GuideTeacher"
	teacher.visible = false
	game.add_child(teacher)
	_vis = CastVisual.new()
	_vis.name = "Look"
	teacher.add_child(_vis)
	_vis.setup(TEACHER)
	_vis.scale = Vector3.ONE * TEACHER_SCALE
	for mesh: GeometryInstance3D in _vis.find_children("*", "GeometryInstance3D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = HOLO
		mesh.material_override = mat
		mesh.layers = CREW_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mat)
	# 目当て：床の青い輪と、その上で上下する矢印
	marker = Node3D.new()
	marker.name = "GuideMarker"
	marker.visible = false
	game.add_child(marker)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(BLUE.r, BLUE.g, BLUE.b, 0.8)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.58
	torus.rings = 40
	torus.ring_segments = 8
	_ring.mesh = torus
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.28
	cone.bottom_radius = 0.0
	cone.height = 0.5
	cone.radial_segments = 4
	_arrow.mesh = cone
	# 遠くからでも場所が分かるように、細い光の柱を立てる
	var beam := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 7.0
	pole.radial_segments = 6
	beam.mesh = pole
	beam.position.y = 2.6 + 3.5
	var faint := glow.duplicate() as StandardMaterial3D
	faint.albedo_color = Color(BLUE.r, BLUE.g, BLUE.b, 0.3)
	beam.material_override = faint
	beam.layers = CREW_LAYER
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(beam)
	for part: MeshInstance3D in [_ring, _arrow]:
		part.material_override = glow
		part.layers = CREW_LAYER
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(part)
	_ring.position.y = 0.04
	# せりふは画面の下の字幕（宅配の箱の講師と同じ見た目）
	_subs = CanvasLayer.new()
	_subs.name = "GuideSubtitles"
	_subs.layer = 20
	add_child(_subs)
	_label = Label.new()
	_label.add_theme_font_override("font", game.font)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.16, 0.95))
	_label.add_theme_constant_override("outline_size", 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -170
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subs.add_child(_label)


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
	_label.text = "" if said == "" else "バズ山「%s」" % said
	_label.visible = said != "" and not game.ui_blocking()
	_place()


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
	if ok:
		_done[id] = true
	return ok


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
			if _holding(["applebox"]):
				return spot
			# 影の所にまだ無い段ボール
			var far: Node3D = null
			var far_d := INF
			for p: Variant in game.props.values():
				var prop := p as Node3D
				if prop == null or str(prop.get("kind")) != "applebox" or bool(prop.get("absent")) or int(prop.get("holder")) != 0:
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
		"take":
			var clap: Node3D = game.clapper
			return clap.global_position if clap != null and int(clap.holder) == 0 else Vector3.INF
	return Vector3.INF


# 講師と、輪・矢印を、いまの番の目当てへ
func _place() -> void:
	var flow: Node = game.production
	var at := target()
	marker.visible = at != Vector3.INF and not game.ui_blocking()
	if at != Vector3.INF:
		var floor_y := 0.0
		marker.global_position = Vector3(at.x, floor_y, at.z)
		_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 4.0))
		_arrow.position.y = maxf(at.y, 0.0) + 1.7 + 0.14 * sin(_t * 3.0)
		_arrow.rotation.y = _t * 1.5
	# 目当てが無い番（役に入る・本番中など）は、カメラの影のわきに立つ
	var guides: Node = game.hooks.feature("holo_guides")
	var base: Vector3 = at if at != Vector3.INF else flow.HOME_SET + (guides.CAM_AT if guides != null else Vector3(0, 0, 5)) + Vector3(0.9, 0.0, 0.6)
	var stand := Vector3(base.x, 0.0, base.z) + BESIDE
	if _stand == Vector3.INF or stand.distance_to(_stand) > 1.4:
		_go(stand)
	# いつも、自分のほうを向く
	var me: Node3D = game.local_player() as Node3D
	if me != null:
		var d: Vector3 = me.global_position - teacher.global_position
		if Vector2(d.x, d.z).length() > 0.3:
			teacher.rotation.y = lerp_angle(teacher.rotation.y, atan2(d.x, d.z), 0.15)


# 講師が、ふわっと浮いて、その場所へ先に行く
func _go(stand: Vector3) -> void:
	var first := _stand == Vector3.INF
	_stand = stand
	if _glide != null:
		_glide.kill()
	if first or not is_inside_tree():
		teacher.global_position = stand
		return
	var from := teacher.global_position
	var sec := clampf(from.distance_to(stand) / 9.0, 0.35, 1.4)
	_glide = create_tween()
	_glide.tween_method(func(t: float) -> void: teacher.global_position = from.lerp(stand, t) + Vector3(0.0, sin(t * PI) * 0.7, 0.0), 0.0, 1.0, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---- 出る・言う・消える ----

func _appear() -> void:
	step = ""
	_stand = Vector3.INF
	teacher.visible = true
	# 箱の上から現れる
	var box: Node = game.hooks.feature("delivery_box")
	if box != null and box.box != null and bool(box.box.visible):
		teacher.global_position = box.box.global_position + Vector3(0.0, 0.7, 0.0)
		_stand = teacher.global_position
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
	if _glide != null:
		_glide.kill()
	if not teacher.visible:
		return
	if not is_inside_tree():
		teacher.visible = false
		return
	var out := create_tween()
	out.tween_method(_fade, 1.0, 0.0, 0.6)
	out.tween_callback(teacher.hide)


func _fade(v: float) -> void:
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("strength", v)


func _say(words: String) -> void:
	if words == "":
		return
	said = words
	_line_t = 0.0
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
		_say("まだ撮れていない！\n" + str(a[0]))


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
