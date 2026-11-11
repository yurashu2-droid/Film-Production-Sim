extends Control
## 講師や箱の「せりふ」の出し方（features/day1_guide.gd・features/delivery_box.gd が使う）。
## 2026-11-11：青い字に黒いふちの字幕は、世界に合っていない・手抜きに見える（ユーザー）ので、作り直した。
## 型は4つ。project.godot の ui/guide_speech_style（無ければ banner）。起動の引数 --speech-style=tape でも替えられる：
##   banner：画面の上の決まった場所に出る、斜めに切った墨色の帯（2026-11-12 ユーザーが選んだ型。ゲームのUIらしい形）。
##           細い線の枠・左に差し色の棒と話し手の印・小さな名前・せりふ。字にふちは付けない。出るときは横から滑り込み、字は順に出る
##   bubble：通販番組ふうの吹き出し。話している物（ドローン・箱）の画面上の場所へ寄って、しっぽが指す。
##           話している物が画面の外なら、画面の下の真ん中に出る（読み落とさない）
##   tape  ：教材ビデオの字幕。下に黒い帯、白い字、左に赤い名札、右に「教材ビデオ」の印
##   film  ：映画の字幕。黒い帯に白い字だけ
## 使う側は label（見えない控えの Label）に、今までどおり text・visible・modulate.a を入れる。ここが毎コマ、それを見た目に写す。
## 映画には映らない（画面の上に描くだけ）
const INK := Color(0.12, 0.08, 0.05)
const RED := Color(0.9, 0.16, 0.12)
const YELLOW := Color(1.0, 0.88, 0.2)
const PAPER := Color(1.0, 0.98, 0.93)
const HUD_ROOM := 190.0              # 画面の下の案内（操作の札）に重ならないよう、空けておく高さ
const TAIL_MAX := 260.0              # しっぽが届く長さ。これより遠ければ、しっぽは出さない

var label: Label                     # 使う側が書く控え（見えない）
var anchor: Node3D                   # 話している物。null なら、画面の下の真ん中
var anchor_up := 0.35                # 話している物の、どれだけ上を指すか（m）
var shaky := 0.0                     # 吹き出しの震え（箱の中の声）。px
var style := "banner"
var _name := ""                      # 帯に出す名前と肩書き
var _tag := ""
var _accent := Color(0.38, 0.75, 1.0)
var _head: Font
var _body: Font
var _since := 0.0                    # いまのせりふが出てからの秒数
var _last := ""
var _speaker := ""
var _board: PanelContainer           # 吹き出し（bubble）か、帯の中身（tape・film）
var _text: Label
var _tab: PanelContainer
var _tail: Polygon2D
var _tail_edge: Line2D
var _band: ColorRect
var _at := Vector2.INF
var _shown := false


static func pick_style() -> String:
	var s := str(ProjectSettings.get_setting("ui/guide_speech_style", "banner"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--speech-style="):
			s = arg.get_slice("=", 1)
	return s if s in ["banner", "bubble", "tape", "film"] else "banner"


# who：名札に書く名前。muted：箱の中の声など、くすんだ色にする
func setup(font: Font, who: String, muted: bool = false) -> void:
	_speaker = who
	style = pick_style()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.position = Vector2(-9000, -9000)
	label.self_modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_text = Label.new()
	_text.add_theme_font_override("font", font)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style == "banner":
		# 名札は「肩書き 名前」。箱の中の声のように、誰か分からない声は「？？？」
		var parts := who.split(" ", false)
		_name = "？？？" if muted else str(parts[parts.size() - 1])
		_tag = who if muted else (str(parts[0]) if parts.size() > 1 else "")
		_accent = Color(0.67, 0.69, 0.74) if muted else Color(0.38, 0.75, 1.0)
		_head = load("res://assets/fonts/DelaGothicOne-Regular.ttf")
		var body := FontVariation.new()
		body.base_font = load("res://assets/fonts/NotoSansJP-VF.ttf")
		body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		_body = body
	elif style == "bubble":
		_build_bubble(font, muted)
	else:
		_build_band(font, muted)
	visible = false


# ---- banner：自分で描く ----

func _draw() -> void:
	if style != "banner" or label == null or label.text == "":
		return
	var screen := get_viewport_rect().size
	var k := screen.y / 720.0
	var ink := Color(0.063, 0.07, 0.094)
	var white := Color(0.965, 0.953, 0.918)
	var w := 780.0 * k
	var h := 98.0 * k
	var lean := 22.0 * k
	# 出るとき：左から滑り込む
	var slide := 1.0 - clampf(_since / 0.16, 0.0, 1.0)
	slide = slide * slide
	var o := Vector2((screen.x - w) * 0.5 - 36.0 * k * slide, 92.0 * k)
	var fade := 1.0 - slide
	var quad := func(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
		return PackedVector2Array([o + Vector2(x0 + lean * (1.0 - 2.0 * y0 / h), y0), o + Vector2(x1 + lean * (1.0 - 2.0 * y0 / h), y0), o + Vector2(x1 + lean * (1.0 - 2.0 * y1 / h), y1), o + Vector2(x0 + lean * (1.0 - 2.0 * y1 / h), y1)])
	# 影・地・差し色の棒
	var shade: PackedVector2Array = quad.call(0.0, w, 0.0, h)
	for i in shade.size():
		shade[i] += Vector2(0, 7.0 * k)
	draw_colored_polygon(shade, Color(0, 0, 0, 0.3 * fade))
	draw_colored_polygon(quad.call(0.0, w, 0.0, h), Color(ink.r, ink.g, ink.b, 0.88 * fade))
	draw_colored_polygon(quad.call(-16.0 * k, -4.0 * k, 0.0, h), Color(_accent.r, _accent.g, _accent.b, fade))
	# 細い線の枠（内側に1本）
	var frame: PackedVector2Array = quad.call(8.0 * k, w - 8.0 * k, 6.0 * k, h - 6.0 * k)
	frame.append(frame[0])
	draw_polyline(frame, Color(white.r, white.g, white.b, 0.55 * fade), maxf(1.0, 1.4 * k), true)
	# 話し手の印（差し色の斜めの四角に、人の影）
	draw_colored_polygon(quad.call(34.0 * k, 112.0 * k, 16.0 * k, h - 16.0 * k), Color(_accent.r, _accent.g, _accent.b, fade))
	var c := o + Vector2(73.0 * k, h * 0.5)
	draw_circle(c + Vector2(0, -8.0 * k), 13.0 * k, Color(ink.r, ink.g, ink.b, fade))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-22.0 * k, 30.0 * k), c + Vector2(-16.0 * k, 12.0 * k), c + Vector2(0, 7.0 * k), c + Vector2(16.0 * k, 12.0 * k), c + Vector2(22.0 * k, 30.0 * k)]), Color(ink.r, ink.g, ink.b, fade))
	# 名前（小さく、字間を空けて）と肩書き、その下の細い線
	var x := o.x + 138.0 * k
	var name_size := int(15.0 * k)
	var pen := x
	for ch: String in _name:
		draw_string(_head, Vector2(pen, o.y + 31.0 * k), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(_accent.r, _accent.g, _accent.b, fade))
		pen += _head.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x + 2.5 * k
	pen += 10.0 * k
	for ch: String in _tag:
		draw_string(_body, Vector2(pen, o.y + 30.0 * k), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * k), Color(white.r, white.g, white.b, 0.6 * fade))
		pen += _body.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * k)).x + 2.0 * k
	draw_line(Vector2(x, o.y + 40.0 * k), Vector2(o.x + w - 40.0 * k, o.y + 40.0 * k), Color(white.r, white.g, white.b, 0.24 * fade), maxf(1.0, k))
	# せりふ：字は順に出る（1秒に 45 字）
	var left := int(_since * 45.0)
	var row := 0
	for words: String in label.text.split("\n"):
		var part := words.substr(0, maxi(left, 0))
		left -= words.length()
		draw_string(_body, Vector2(x, o.y + (62.0 + 23.0 * float(row)) * k), part, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * k), Color(white.r, white.g, white.b, fade))
		row += 1
	# 小さな記号：右上の三本線、右下の三角（言い終えたら、ゆっくり上下する）
	for i in 3:
		var sx := o.x + w - 30.0 * k + float(i) * 8.0 * k
		draw_line(Vector2(sx, o.y + 14.0 * k), Vector2(sx - 6.0 * k, o.y + 26.0 * k), Color(white.r, white.g, white.b, 0.65 * fade), maxf(1.0, 1.4 * k), true)
	if left >= 0:
		var bob := sin(_since * 5.0) * 2.0 * k
		var t := Vector2(o.x + w - 62.0 * k, o.y + h - 26.0 * k + bob)
		draw_colored_polygon(PackedVector2Array([t, t + Vector2(12.0 * k, 0), t + Vector2(6.0 * k, 9.0 * k)]), Color(_accent.r, _accent.g, _accent.b, fade))


func _build_bubble(font: Font, muted: bool) -> void:
	_board = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.9, 0.88, 0.84) if muted else PAPER
	box.border_color = INK
	box.set_border_width_all(4)
	box.set_corner_radius_all(22)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 22
	box.content_margin_bottom = 16
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 2
	box.shadow_offset = Vector2(5, 6)
	_board.add_theme_stylebox_override("panel", box)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	_text.add_theme_font_size_override("font_size", 25)
	_text.add_theme_color_override("font_color", INK)
	_text.add_theme_constant_override("line_spacing", 4)
	_board.add_child(_text)
	# しっぽ（吹き出しの下から、話している物へ）
	_tail = Polygon2D.new()
	_tail.color = box.bg_color
	add_child(_tail)
	_tail_edge = Line2D.new()
	_tail_edge.width = 4.0
	_tail_edge.default_color = INK
	_tail_edge.joint_mode = Line2D.LINE_JOINT_ROUND
	_tail_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_tail_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_tail_edge)
	_tab = _name_tab(font, muted)
	_tab.rotation = -0.05
	add_child(_tab)


func _build_band(font: Font, muted: bool) -> void:
	_band = ColorRect.new()
	_band.color = Color(0, 0, 0, 0.82 if style == "tape" else 0.9)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_text.add_theme_font_size_override("font_size", 26)
	_text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8) if muted else Color.WHITE)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_band.add_child(_text)
	if style == "tape":
		_tab = _name_tab(font, muted)
		add_child(_tab)
		var mark := Label.new()
		mark.name = "TapeMark"
		mark.add_theme_font_override("font", font)
		mark.add_theme_font_size_override("font_size", 15)
		mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		mark.text = "▶ 教材ビデオ 第1巻"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_band.add_child(mark)
		mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		mark.offset_right = -18
		mark.offset_top = 8


func _name_tab(font: Font, muted: bool) -> PanelContainer:
	var tab := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.34, 0.32) if muted else RED
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	tab.add_theme_stylebox_override("panel", box)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := Label.new()
	words.add_theme_font_override("font", font)
	words.add_theme_font_size_override("font_size", 17)
	words.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86) if muted else YELLOW)
	words.text = _speaker
	tab.add_child(words)
	return tab


func _process(delta: float) -> void:
	if label == null:
		return
	var show := label.visible and label.text != ""
	visible = show
	if not show:
		_shown = false
		_last = ""
		return
	modulate.a = label.modulate.a
	if style == "banner":
		if label.text != _last:
			_last = label.text
			_since = 0.0
		_since += delta
		queue_redraw()
		_shown = true
		return
	_text.text = label.text
	var screen := get_viewport_rect().size
	if style == "bubble":
		_place_bubble(delta, screen)
	else:
		var h := 104.0
		_band.position = Vector2(0, screen.y - HUD_ROOM - h + 40.0)
		_band.size = Vector2(screen.x, h)
		if _tab != null:
			_tab.position = Vector2(28, _band.position.y - 16)
	_shown = true


func _place_bubble(delta: float, screen: Vector2) -> void:
	var size := _board.get_combined_minimum_size()
	_board.size = size
	var tip := Vector2.INF           # しっぽの先（話している物の、画面上の場所）
	var cam := get_viewport().get_camera_3d()
	if anchor != null and is_instance_valid(anchor) and anchor.is_visible_in_tree() and cam != null:
		var point := anchor.global_position + Vector3(0, anchor_up, 0)
		if not cam.is_position_behind(point):
			var p := cam.unproject_position(point)
			if Rect2(Vector2(30, 30), screen - Vector2(60, 60)).has_point(p):
				tip = p
	var want := Vector2((screen.x - size.x) * 0.5, screen.y - HUD_ROOM - size.y)
	if tip != Vector2.INF:
		want = Vector2(tip.x - size.x * 0.5, tip.y - size.y - 46.0)
		want.x = clampf(want.x, 18.0, maxf(18.0, screen.x - size.x - 18.0))
		want.y = clampf(want.y, 64.0, maxf(64.0, screen.y - HUD_ROOM - size.y))
	# 出た瞬間は、その場所に出す。あとは、なめらかに寄る（話している物が動いても、字が跳ねない）
	_at = want if not _shown or _at == Vector2.INF else _at.lerp(want, 1.0 - exp(-10.0 * delta))
	var at := _at
	if shaky > 0.0:
		at += Vector2(randf_range(-shaky, shaky), randf_range(-shaky, shaky))
	_board.position = at
	_tab.position = at + Vector2(16, -15)
	var foot := Vector2(clampf(tip.x if tip != Vector2.INF else 0.0, at.x + 44.0, at.x + size.x - 44.0), at.y + size.y - 5.0)
	var tail_on := tip != Vector2.INF and tip.y > foot.y + 14.0 and foot.distance_to(tip) < TAIL_MAX
	_tail.visible = tail_on
	_tail_edge.visible = tail_on
	if tail_on:
		var end := foot.lerp(tip, 0.82)
		var l := foot + Vector2(-15, 0)
		var r := foot + Vector2(15, 0)
		_tail.polygon = PackedVector2Array([l, r, end])
		_tail_edge.points = PackedVector2Array([l + Vector2(0, 3), end, r + Vector2(0, 3)])
