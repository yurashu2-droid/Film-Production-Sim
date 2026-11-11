extends Control
## 講師や箱の「せりふ」の出し方（features/day1_guide.gd・features/delivery_box.gd が使う）。
## 2026-11-11：青い字に黒いふちの字幕は、世界に合っていない・手抜きに見える（ユーザー）ので、作り直した。
## 型は3つ。project.godot の ui/guide_speech_style（無ければ bubble）。起動の引数 --speech-style=tape でも替えられる：
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
var style := "bubble"
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
	var s := str(ProjectSettings.get_setting("ui/guide_speech_style", "bubble"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--speech-style="):
			s = arg.get_slice("=", 1)
	return s if s in ["bubble", "tape", "film"] else "bubble"


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
	if style == "bubble":
		_build_bubble(font, muted)
	else:
		_build_band(font, muted)
	visible = false


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
		return
	_text.text = label.text
	modulate.a = label.modulate.a
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
