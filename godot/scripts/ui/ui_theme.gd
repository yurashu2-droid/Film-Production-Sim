extends RefCounted
# 画面まわりの見た目を一か所にまとめる。
#   const UI := preload("res://scripts/ui/ui_theme.gd")
#
# 方針（飾りを足すより、引く）
#   ・色は「黒に近い面」「紙の白」「合図の黄」の3つ。赤は録画と警告、緑は成立だけ。
#   ・面は平らに。枠は細い1本か、無し。傾き・ギザギザ・硬い影・スタンプ風の二重枠は使わない。
#   ・文字で階層を作る。同梱の Noto Sans JP を太さ違いで使い、どのPCでも同じに見せる。
#   ・カチンコの縞は、タイトルと本番のカチンコだけに取っておく。

const INK := Color("0e0f11")          # いちばん暗い面・紙の上の文字
const BOARD := Color("121316")        # 板
const BOARD_2 := Color("1d1f24")      # 板の上の一段明るい面
const CLAP_WHITE := Color("f4f1ea")   # 板の上の文字
const PAPER := Color("f4f1ea")        # 紙
const PAPER_SHADE := Color("dedad0")
const KRAFT := Color("e6e2d8")        # 以前の段ボール色。いまは紙より少し沈んだ明るい面
const KRAFT_DARK := Color("bdb8ac")
const TAPE := Color("ffcc00")         # 合図の黄。主ボタンと、いま大事な1か所だけ
const TAPE_HI := Color("ffdb4d")
const TAPE_DARK := Color("d9a900")
const MASKING := Color("e6e2d8")      # 小さな札の地（明るい面の上の文字は INK）
const STAMP_RED := Color("e5392d")    # 録画・警告
const RED_DARK := Color("8e1f18")
const OK_GREEN := Color("2fb36a")     # 成立
const GREEN_LIGHT := Color("7be3a2")
const MUTED := Color("9a9ca3")        # 補足の文字
const LINE := Color(1, 1, 1, 0.10)    # 板の上の細い線
const SHADOW := Color(0, 0, 0, 0.28)

const FONT_PATH := "res://assets/fonts/NotoSansJP-VF.ttf"
const WEIGHTS := {"body": 500, "bold": 700, "display": 900, "hand": 700, "light": 400}

static var _fonts: Dictionary = {}
static var _textures: Dictionary = {}
static var _base: Font


# ---- フォント（同梱の Noto Sans JP 可変フォントを、太さ違いで使う） ----

static func fnt(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var weight: int = WEIGHTS.get(kind, 500)
	var out: Font
	if _base == null and ResourceLoader.exists(FONT_PATH):
		_base = load(FONT_PATH)
	if _base != null:
		var fv := FontVariation.new()
		fv.base_font = _base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		if kind == "display":
			fv.spacing_glyph = -1
		out = fv
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Noto Sans JP", "Yu Gothic UI", "Meiryo", "BIZ UDGothic", "sans-serif"])
		sf.font_weight = weight
		out = sf
	_fonts[kind] = out
	return out


static func label(text: String, size: int, color: Color = CLAP_WHITE, kind: String = "body", outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", fnt(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		# 3Dの上に直接載る文字だけ、薄い縁で読めるようにする
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func recolor(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color)


# ---- 面 ----

# 平らな面。太い枠・暗い縁取り・硬い影の指定は、細い線と柔らかい影に読み替える
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 4, mx: int = 14, my: int = 10, shadow: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	var dark_edge: bool = border.a > 0.0 and border.get_luminance() < 0.2
	var light_bg: bool = bg.a > 0.5 and bg.get_luminance() > 0.45
	if bw > 0 and border.a > 0.0 and not (dark_edge and light_bg):
		s.border_color = LINE if dark_edge else Color(border, minf(border.a, 0.55))
		s.set_border_width_all(1)
	s.set_corner_radius_all(clampi(radius, 4, 8))
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	if shadow != Vector2.ZERO and bg.a > 0.5:
		s.shadow_color = SHADOW
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 3)
	return s


static func kind_box(kind: String, mx: int = 18, my: int = 14) -> StyleBoxFlat:
	var s: StyleBoxFlat
	match kind:
		"paper":
			s = box(PAPER, Color(0, 0, 0, 0), 0, 6, mx, my, Vector2(0, 3))
		"kraft":
			s = box(KRAFT, Color(0, 0, 0, 0), 0, 6, mx, my, Vector2(0, 3))
		"tape":
			s = box(TAPE, Color(0, 0, 0, 0), 0, 4, mx, my)
		"red":
			s = box(STAMP_RED, Color(0, 0, 0, 0), 0, 4, mx, my)
		"clear":
			s = box(Color(INK, 0.62), Color(0, 0, 0, 0), 0, 6, mx, my)
		_:
			s = box(Color(BOARD, 0.90), LINE, 1, 6, mx, my, Vector2(0, 3))
	return s


# 面つきの入れ物。stripe>0 のときは、左上に短い黄色の見出し線を引く（以前の縞の帯の代わり）
static func panel(kind: String = "slate", stripe: float = 0.0, _taped: bool = true, mx: int = 18, my: int = 14) -> TapedPanel:
	var p := TapedPanel.new()
	p.kind = kind
	p.stripe_h = stripe
	p.set_box(kind_box(kind, mx, my), my)
	return p


# ボタン。tape=主（黄） / paper=明るい面 / slate・kraft=枠だけ / red=警告
static func style_button(b: BaseButton, kind: String = "tape", size: int = 22, tall: int = 46) -> void:
	var mx := 18
	var my := 8
	var ink := INK
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var press: StyleBoxFlat
	match kind:
		"paper":
			normal = box(PAPER, Color(0, 0, 0, 0), 0, 4, mx, my)
			hover = box(Color.WHITE, Color(0, 0, 0, 0), 0, 4, mx, my)
			press = box(PAPER_SHADE, Color(0, 0, 0, 0), 0, 4, mx, my)
		"kraft":
			normal = box(KRAFT, Color(0, 0, 0, 0), 0, 4, mx, my)
			hover = box(Color.WHITE, Color(0, 0, 0, 0), 0, 4, mx, my)
			press = box(KRAFT_DARK, Color(0, 0, 0, 0), 0, 4, mx, my)
		"slate":
			ink = CLAP_WHITE
			normal = box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.28), 1, 4, mx, my)
			hover = box(Color(1, 1, 1, 0.12), TAPE, 1, 4, mx, my)
			hover.border_color = TAPE
			press = box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.28), 1, 4, mx, my)
		"red":
			ink = CLAP_WHITE
			normal = box(STAMP_RED, Color(0, 0, 0, 0), 0, 4, mx, my)
			hover = box(Color("f0584c"), Color(0, 0, 0, 0), 0, 4, mx, my)
			press = box(RED_DARK, Color(0, 0, 0, 0), 0, 4, mx, my)
		_:
			normal = box(TAPE, Color(0, 0, 0, 0), 0, 4, mx, my)
			hover = box(TAPE_HI, Color(0, 0, 0, 0), 0, 4, mx, my)
			press = box(TAPE_DARK, Color(0, 0, 0, 0), 0, 4, mx, my)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 4, mx, my))
	var focus := box(Color(0, 0, 0, 0), CLAP_WHITE, 1, 4, mx, my)
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.7)
	b.add_theme_stylebox_override("focus", focus)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_font_override("font", fnt("bold"))
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, tall)


static func style_line_edit(e: LineEdit, size: int = 22) -> void:
	var normal := box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.28), 1, 4, 14, 9)
	var focus := box(Color(1, 1, 1, 0.10), TAPE, 1, 4, 14, 9)
	focus.border_color = TAPE
	e.add_theme_stylebox_override("normal", normal)
	e.add_theme_stylebox_override("focus", focus)
	e.add_theme_stylebox_override("read_only", box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.15), 1, 4, 14, 9))
	e.add_theme_color_override("font_color", CLAP_WHITE)
	e.add_theme_color_override("font_uneditable_color", MUTED)
	e.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.38))
	e.add_theme_color_override("caret_color", TAPE)
	e.add_theme_color_override("selection_color", Color(TAPE, 0.4))
	e.add_theme_font_override("font", fnt("body"))
	e.add_theme_font_size_override("font_size", size)


# 子孫まで、マウスを素通りさせる（カードの上のラベルがクリックを奪わない）
static func ignore_mouse(n: Node) -> void:
	# 押せる物（ボタンや ClickBox）自身は止めない。中の飾りだけマウスを素通しにする
	if n is Control and not n is BaseButton and not n is LineEdit and not n is ScrollContainer and not n.has_signal("pressed"):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


static func make_theme(base_size: int = 20) -> Theme:
	var t := Theme.new()
	t.default_font = fnt("body")
	t.default_font_size = base_size
	t.set_color("font_color", "Label", CLAP_WHITE)
	t.set_stylebox("normal", "Button", box(TAPE, Color(0, 0, 0, 0), 0, 4, 18, 8))
	t.set_stylebox("hover", "Button", box(TAPE_HI, Color(0, 0, 0, 0), 0, 4, 18, 8))
	t.set_stylebox("pressed", "Button", box(TAPE_DARK, Color(0, 0, 0, 0), 0, 4, 18, 8))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 4, 18, 8))
	var focus := box(Color(0, 0, 0, 0), CLAP_WHITE, 1, 4, 18, 8)
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.7)
	t.set_stylebox("focus", "Button", focus)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_font("font", "Button", fnt("bold"))
	t.set_stylebox("normal", "LineEdit", box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.28), 1, 4, 14, 9))
	var le_focus := box(Color(1, 1, 1, 0.10), TAPE, 1, 4, 14, 9)
	le_focus.border_color = TAPE
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", CLAP_WHITE)
	t.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.38))
	t.set_color("caret_color", "LineEdit", TAPE)
	t.set_stylebox("panel", "TooltipPanel", box(Color(INK, 0.96), LINE, 1, 4, 12, 8))
	t.set_color("font_color", "TooltipLabel", CLAP_WHITE)
	t.set_font_size("font_size", "TooltipLabel", 16)
	var grab := box(Color(1, 1, 1, 0.28), Color(0, 0, 0, 0), 0, 4, 3, 3)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.45), Color(0, 0, 0, 0), 0, 4, 3, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(TAPE, Color(0, 0, 0, 0), 0, 4, 3, 3))
	t.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 4, 3, 3))
	return t


# ---- 画像ぬきで作る小さな絵 ----

static func vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	return tex


static func radial_gradient(center: Color, edge: Color, radius: float = 0.5) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, center)
	g.set_color(1, edge)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.5 - radius)
	tex.width = 256
	tex.height = 256
	return tex


# 斜め縞の ImageTexture（進み具合の棒などをタイルで塗る）
static func stripe_texture(a: Color, b: Color) -> ImageTexture:
	var key := "stripe_%s_%s" % [a.to_html(), b.to_html()]
	if _textures.has(key):
		return _textures[key]
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 32:
			image.set_pixel(x, y, a if (x + y) % 32 < 16 else b)
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = tex
	return tex


# 斜め縞を矩形の中だけに描く（カチンコ用）
static func draw_stripes(c: CanvasItem, r: Rect2, a: Color, b: Color, period: float = 30.0, offset: float = 0.0) -> void:
	c.draw_rect(r, a)
	var h := r.size.y
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var x := r.position.x - h - fposmod(offset, period)
	while x < r.end.x:
		var poly := PackedVector2Array([Vector2(x + h, r.position.y), Vector2(x + h + period * 0.5, r.position.y),
			Vector2(x + period * 0.5, r.end.y), Vector2(x, r.end.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, rect_poly):
			c.draw_colored_polygon(piece, b)
		x += period


static func tape_polygon(local: Rect2, _teeth: float = 5.0) -> PackedVector2Array:
	return PackedVector2Array([local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)])


# 色つきの札。傾けず、角を少し丸めた平らな四角で描く
static func draw_tape(c: CanvasItem, center: Vector2, tape_size: Vector2, col: Color, _tilt: float = 0.0, _shadow: bool = true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	sb.anti_aliasing = true
	sb.draw(c.get_canvas_item(), Rect2(center - tape_size * 0.5, tape_size))


static func draw_crew(c: CanvasItem, pos: Vector2, s: float, col: Color, _beret: Color = STAMP_RED) -> void:
	# 以前の人形アイコンの代わりに、小さな丸だけを置く
	c.draw_circle(pos, 6.0 * s, col)


static func draw_outlined_text(c: CanvasItem, f: Font, pos: Vector2, text: String, size: int, col: Color, _edge: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT, _offset: Vector2 = Vector2(3, 3)) -> void:
	c.draw_string(f, pos, text, align, width, size, col)


# 現れるとき：短く、弾ませない
static func pop_on_show(c: Control, lift: float = 0.0) -> void:
	c.visibility_changed.connect(func() -> void:
		if c.visible and c.is_inside_tree():
			pop(c, lift))


static func pop(c: Control, _lift: float = 0.0) -> void:
	if c.has_meta("pop_tween"):
		var old: Variant = c.get_meta("pop_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	c.set_meta("pop_tween", tw)


# ---------------------------------------------------------------------------
# 部品
# ---------------------------------------------------------------------------

# 面つきの入れ物（名前は以前のまま）。中身は普通の子として入れる
class TapedPanel extends PanelContainer:
	var sb: StyleBoxFlat
	var kind := "slate"
	var tapes: Array = []        # 互換のために残す。描かない
	var stripe_h := 0.0
	var stripe_a := Color("0e0f11")
	var stripe_b := Color("f4f1ea")
	var stripe_phase := 0.0

	func _init() -> void:
		resized.connect(queue_redraw)

	func set_box(s: StyleBoxFlat, _top_margin: int = -1) -> void:
		sb = s
		var e := StyleBoxEmpty.new()
		e.content_margin_left = s.content_margin_left
		e.content_margin_right = s.content_margin_right
		e.content_margin_top = s.content_margin_top
		e.content_margin_bottom = s.content_margin_bottom
		add_theme_stylebox_override("panel", e)
		queue_redraw()

	func _draw() -> void:
		if sb != null:
			sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		# stripe_h は互換のために受けるだけで、飾りの線は引かない


# 色つきの札に文字（ヒント・お知らせ・小さな見出し）
class Tape extends Control:
	var text := ""
	var size_px := 22
	var color := Color("ffcc00")
	var ink := Color("0e0f11")
	var tilt := 0.0              # 互換のために残す。傾けない
	var pad := Vector2(14, 5)
	var kind := "bold"
	var min_w := 0.0
	var shadow := true

	func setup(t: String, px: int, col: Color, ink_col: Color, _tilt_deg: float = 0.0, font_kind: String = "display") -> Tape:
		text = t
		size_px = px
		color = col
		ink = ink_col
		kind = "bold" if font_kind in ["display", "hand"] else font_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fit()
		return self

	func set_text(t: String) -> void:
		if t == text:
			return
		text = t
		_fit()
		queue_redraw()

	func set_colors(col: Color, ink_col: Color) -> void:
		if col == color and ink_col == ink:
			return
		color = col
		ink = ink_col
		queue_redraw()

	func _fit() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt(kind)
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		custom_minimum_size = Vector2(maxf(ts.x + pad.x * 2.0, min_w), ts.y + pad.y * 2.0)

	func _draw() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt(kind)
		ui.draw_tape(self, size * 0.5, size, color)
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		var baseline := (size.y - ts.y) * 0.5 + f.get_ascent(size_px)
		draw_string(f, Vector2(0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, ink)


# 小さな種別の札（細い枠に文字）。以前のゴム印の代わり
class Stamp extends Control:
	var text := ""
	var size_px := 28
	var color := Color("e5392d")
	var tilt := 0.0
	var alpha := 1.0
	var kind := "bold"
	var appear := 1.0:
		set(v):
			appear = v
			queue_redraw()

	func setup(t: String, px: int, col: Color, _tilt_deg: float = 0.0, _font_kind: String = "display") -> Stamp:
		text = t
		size_px = px
		color = col
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fit()
		return self

	func set_text(t: String) -> void:
		if t == text:
			return
		text = t
		_fit()
		queue_redraw()

	func _fit() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt(kind)
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		custom_minimum_size = Vector2(ts.x + 20.0, ts.y + 8.0)

	func pop() -> void:
		appear = 0.0
		var tw := create_tween()
		tw.tween_property(self, "appear", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt(kind)
		var col := Color(color, alpha * clampf(appear, 0.0, 1.0))
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), Rect2(Vector2(1, 1), size - Vector2(2, 2)))
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		draw_string(f, Vector2(0, (size.y - ts.y) * 0.5 + f.get_ascent(size_px)), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, col)


# 場面の成立を示す丸。成立すると黄で塗って、チェックを入れる
class ShotBox extends Control:
	var on := false
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(v: bool, animate: bool = true) -> void:
		if v == on:
			return
		on = v
		if on and animate and is_inside_tree():
			progress = 0.0
			var tw := create_tween()
			tw.tween_property(self, "progress", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			progress = 1.0 if on else 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := 10.0
		if progress <= 0.0:
			draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 1.6, true)
			return
		var p := clampf(progress, 0.0, 1.0)
		draw_circle(c, r * (0.6 + 0.4 * p), Color("ffcc00"))
		var a := c + Vector2(-4.6, 0.2)
		var b := c + Vector2(-1.2, 3.6)
		var d := c + Vector2(5.0, -3.6)
		var ink := Color("0e0f11")
		draw_line(a, a.lerp(b, clampf(p * 2.0, 0.0, 1.0)), ink, 2.4, true)
		if p > 0.5:
			draw_line(b, b.lerp(d, (p - 0.5) * 2.0), ink, 2.4, true)


# 斜め縞の帯（カチンコと、移動中の道だけに使う）
class StripeBar extends Control:
	var a := Color("0e0f11")
	var b := Color("f4f1ea")
	var period := 30.0
	var speed := 0.0
	var phase := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 18.0
		clip_contents = true

	func setup(col_a: Color, col_b: Color, height: float, scroll: float = 0.0) -> StripeBar:
		a = col_a
		b = col_b
		custom_minimum_size.y = height
		speed = scroll
		set_process(speed != 0.0)
		return self

	func _process(delta: float) -> void:
		phase += delta * speed
		queue_redraw()

	func _draw() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		ui.draw_stripes(self, Rect2(Vector2.ZERO, size), a, b, size.y * 1.4, phase)


# ---------------------------------------------------------------------------
# 追加の小物（画面の整理で足した部品。上の定義は変えていない）
# ---------------------------------------------------------------------------

static var _over_font: Font
static var _key_regex: RegEx

const KEY_PATTERN := "^(\\[[^\\]]+\\]|WASD|Shift|Space|Tab|Esc|Enter|F\\d+|[A-Z]|[0-9](・[0-9])*|[0-9]〜[0-9]|[A-Z]・\\S+|↑↓|←→|[←→↑↓])$"


# 字間をあけた小見出し用のフォント
static func over_font() -> Font:
	if _over_font == null:
		var fv := FontVariation.new()
		fv.base_font = fnt("bold")
		fv.spacing_glyph = 2
		_over_font = fv
	return _over_font


# 小見出し（ORDER・CHECK など）。13px・字間あき・補足色。見出しの上に置く
static func overline(text: String, color: Color = MUTED) -> Label:
	var l := label(text, 13, color, "bold")
	l.add_theme_font_override("font", over_font())
	return l


# 細い区切り線
static func hairline(vertical: bool = false, color: Color = LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# 縦の余白
static func gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# 内側のカード：一段明るい面と1pxの線。hover は黄の線
static func card_box(hover: bool = false, mx: int = 16, my: int = 12) -> StyleBoxFlat:
	var s := box(BOARD_2, LINE, 1, 6, mx, my)
	if hover:
		s.border_color = TAPE
	return s


# 選んでいる行：白6%の面と、左の2pxの黄色
static func cursor_box(mx: int = 12, my: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.06)
	s.border_color = TAPE
	s.border_width_left = 2
	s.set_corner_radius_all(4)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s


static func is_key_token(token: String) -> bool:
	if _key_regex == null:
		_key_regex = RegEx.new()
		_key_regex.compile(KEY_PATTERN)
	return _key_regex.search(token) != null


# 「F 開く」「WASD 移動」のような1区切りを、キーキャップ＋説明に組む
static func key_item(segment: String, px: int = 15, outline: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var run: Array[String] = []
	for word: String in segment.split(" ", false):
		if is_key_token(word):
			if not run.is_empty():
				row.add_child(_key_text(" ".join(run), px, outline))
				run.clear()
			row.add_child(KeyCap.new().setup(Keybinds.shown(word.trim_prefix("[").trim_suffix("]"))))
		else:
			run.append(word)
	if not run.is_empty():
		row.add_child(_key_text(" ".join(run), px, outline))
	return row


static func _key_text(text: String, px: int, outline: bool) -> Label:
	var l := label(text, px, CLAP_WHITE, "body", outline)
	if outline:
		l.add_theme_constant_override("outline_size", 3)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


# 細い枠だけのキーキャップ（面は塗らない）
class KeyCap extends Control:
	var text := ""
	var size_px := 13
	var line := Color(1, 1, 1, 0.35)
	var ink := Color("f4f1ea")

	func setup(t: String, px: int = 13, line_col: Color = Color(1, 1, 1, 0.35), ink_col: Color = Color("f4f1ea")) -> KeyCap:
		text = t
		size_px = px
		line = line_col
		ink = ink_col
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt("bold")
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		custom_minimum_size = Vector2(maxf(ts.x + 14.0, 22.0), 22.0)
		return self

	func _draw() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt("bold")
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = line
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		draw_string(f, Vector2(0, (size.y - ts.y) * 0.5 + f.get_ascent(size_px)), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, ink)


# 小さな丸（箇条書きの点・成否の点・充填の残り）
class Dot extends Control:
	var color := Color("ffcc00")
	var diameter := 6.0

	func setup(col: Color, d: float = 6.0) -> Dot:
		color = col
		diameter = d
		custom_minimum_size = Vector2(d, d)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func set_color(col: Color) -> void:
		if col != color:
			color = col
			queue_redraw()

	func _draw() -> void:
		draw_circle(size * 0.5, diameter * 0.5, color)


# 成否の印：緑のチェックの丸／赤のバツの丸
class StatusMark extends Control:
	var ok := true

	func setup(v: bool, d: float = 26.0) -> StatusMark:
		ok = v
		custom_minimum_size = Vector2(d, d)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.5
		var col := Color("2fb36a") if ok else Color("e5392d")
		draw_circle(c, r, Color(col, 0.16))
		draw_arc(c, r, 0.0, TAU, 40, col, 1.6, true)
		var k := r / 13.0
		var mark := Color("7be3a2") if ok else Color("ff8a80")
		if ok:
			draw_polyline(PackedVector2Array([c + Vector2(-5.0, 0.5) * k, c + Vector2(-1.5, 4.0) * k, c + Vector2(5.5, -3.8) * k]), mark, 2.2, true)
		else:
			draw_line(c + Vector2(-4.2, -4.2) * k, c + Vector2(4.2, 4.2) * k, mark, 2.2, true)
			draw_line(c + Vector2(4.2, -4.2) * k, c + Vector2(-4.2, 4.2) * k, mark, 2.2, true)


# 細い進み具合の棒
class ThinBar extends Control:
	var value := 0.0
	var max_value := 1.0
	var fill := Color("f4f1ea")

	func _init() -> void:
		custom_minimum_size.y = 4.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, m: float, col: Color = Color("f4f1ea")) -> void:
		if v == value and m == max_value and col == fill:
			return
		value = v
		max_value = m
		fill = col
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		var p := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
		if p > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * p, size.y)), fill)


# 面つきでクリックできる入れ物（行・カード・テイクの札）。hover と選択中の面を持つ
class ClickBox extends PanelContainer:
	signal pressed
	signal hovered
	var sb_normal: StyleBox
	var sb_hover: StyleBox
	var sb_active: StyleBox
	var active := false
	var enabled := true
	var _over := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func set_styles(normal: StyleBox, hover: StyleBox = null, act: StyleBox = null) -> void:
		sb_normal = normal
		sb_hover = hover if hover != null else normal
		sb_active = act if act != null else sb_hover
		_apply()

	func set_active(v: bool) -> void:
		if v == active:
			return
		active = v
		_apply()

	func _apply() -> void:
		var s: StyleBox = sb_normal
		if active:
			s = sb_active
		elif _over and enabled:
			s = sb_hover
		if s != null:
			add_theme_stylebox_override("panel", s)

	func _gui_input(event: InputEvent) -> void:
		if enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _on_enter() -> void:
		_over = true
		hovered.emit()
		_apply()
		if enabled:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _on_exit() -> void:
		_over = false
		_apply()


# 右端にキーキャップを持つボタン（見返す [R] など）
class KeyButton extends Button:
	var cap: KeyCap

	func setup(t: String, key: String, kind: String = "slate", px: int = 17, tall: int = 44) -> KeyButton:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		text = t
		focus_mode = Control.FOCUS_NONE
		ui.style_button(self, kind, px, tall)
		if key != "":
			var ink: Color = ui.INK if kind == "tape" else ui.CLAP_WHITE
			cap = KeyCap.new().setup(key, 13, Color(ink, 0.5), ink)
			add_child(cap)
			cap.size = cap.custom_minimum_size
			for style_name: String in ["normal", "hover", "pressed", "disabled"]:
				var sbx: StyleBoxFlat = get_theme_stylebox(style_name)
				sbx.content_margin_right += cap.custom_minimum_size.x + 8.0
			resized.connect(_place_cap)
		return self

	func set_enabled(v: bool) -> void:
		disabled = not v
		if cap != null:
			cap.modulate.a = 1.0 if v else 0.35

	func _place_cap() -> void:
		if cap != null:
			cap.position = Vector2(size.x - cap.size.x - 12.0, (size.y - cap.size.y) * 0.5)
