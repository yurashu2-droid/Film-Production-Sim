class_name FilmSet
extends RefCounted
## 撮影現場の物でできた画面の部品（2026-10-20 にユーザーと決めた見た目。見本は tools/trailer/ui_patterns.html）：
##   ・依頼の板 ＝ 35mm フィルムの切れ端（上下に送り穴）           FilmStyle
##   ・知らせ   ＝ AD が掲げるスケッチブックのカンペ（上にリング）   KanpeStyle
##   ・上の帯   ＝ 撮影カメラの画面の四隅の枠（STBY ／ REC）        CamStyle
##   ・操作の案内 ＝ 色を塗った段ボールの札を、角材で下から持ち上げる  signs()
##   ・狙った物の名前 ＝ 黄色い付箋                                  tag_style()
## 書体：手書き（Yusei Magic）・ステンシル（Dela Gothic One）・明朝（Shippori Mincho）・等幅（M PLUS 1 Code）。
## どれも OFL（assets/fonts/*-OFL.txt）。無い環境では、ふつうの書体（ui_theme.gd の fnt）で代わりに出す
const UI := preload("res://scripts/ui/ui_theme.gd")
const FONTS := {
	"marker": "res://assets/fonts/YuseiMagic-Regular.ttf",
	"stencil": "res://assets/fonts/DelaGothicOne-Regular.ttf",
	"mincho": "res://assets/fonts/ShipporiMincho-ExtraBold.ttf",
	"mono": "res://assets/fonts/MPLUS1Code-VF.ttf",
}
# 段ボールの札の色（事務所の日よけ・旗と同じ）。[塗り, 字]
const PAINTS := {
	"teal": [Color("2f8c8a"), Color("fbf3e2")],
	"mustard": [Color("e5b23a"), Color("1d1a14")],
	"tomato": [Color("d75a42"), Color("fff4e4")],
	"cream": [Color("f1e8d4"), Color("1d1a14")],
	"sky": [Color("6fa9d8"), Color("10233a")],
}
# キー → 札の色（操作ごとに色を決めておくと、字を読まなくても色で覚えられる）
const KEY_PAINT := {"F": "teal", "左": "mustard", "右": "sky", "Tab": "cream", "K": "tomato", "Y": "tomato", "T": "mustard", "1・2・3": "sky", "B": "sky"}
const KRAFT_EDGE := Color("c99d66")
const MARKER_INK := Color("151515")
const MARKER_RED := Color("de3328")

static var _fonts := {}
static var _brush: ImageTexture


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var out: Font = null
	var path: String = FONTS.get(kind, "")
	if path != "" and ResourceLoader.exists(path):
		var base: Font = load(path)
		if kind == "mono":
			var fv := FontVariation.new()
			fv.base_font = base
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
			out = fv
		else:
			out = base
	if out == null:
		out = UI.fnt("bold")
	_fonts[kind] = out
	return out


static func label(text: String, px: int, color: Color, kind: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# 塗りむら：ペンキをローラーで塗ったような、ぼんやりした濃淡（線は入れない）。継ぎ目の出ない1枚を作り、
# 札ごとに、その一部を切り出して使う（paint_region）。同じ柄が並ばないように
static func brush() -> ImageTexture:
	if _brush != null:
		return _brush
	var size := 512
	var big := FastNoiseLite.new()
	big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	big.frequency = 0.008
	big.fractal_octaves = 3
	big.seed = 20261021
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fine.frequency = 0.09
	fine.seed = 7
	var a: Image = big.get_seamless_image(size, size)
	var b: Image = fine.get_seamless_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			# 大きなむら（塗りの厚い・薄い）と、細かいざらつき（段ボールの地の凸凹）
			var v := (a.get_pixel(x, y).r - 0.5) * 0.9 + (b.get_pixel(x, y).r - 0.5) * 0.25
			img.set_pixel(x, y, Color(1, 1, 1, v * 0.22) if v > 0.0 else Color(0, 0, 0, -v * 0.22))
	_brush = ImageTexture.create_from_image(img)
	return _brush


# 札ごとに違う切り出し位置（札の場所と大きさから決める。毎コマ同じなので、ちらつかない）
static func paint_region(r: Rect2) -> Rect2:
	var h := absi(hash(Vector2i(int(r.position.x), int(r.position.y)) + Vector2i(int(r.size.x), int(r.size.y)) * 7))
	var size := 512.0
	var w := minf(r.size.x, size * 0.9)
	var hh := minf(r.size.y, size * 0.9)
	return Rect2(Vector2(float(h % 397) / 397.0 * (size - w), float((h / 397) % 389) / 389.0 * (size - hh)), Vector2(w, hh))


static func _shadow(item: RID, r: Rect2, drop: float, alpha: float) -> void:
	for k in 3:
		var grow := float(k) * 1.5
		RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(-grow, drop - grow * 0.5), r.size + Vector2(grow * 2.0, grow * 2.0)), Color(0, 0, 0, alpha / (k + 1.5)))


# ---- 依頼の板：35mm フィルムの切れ端 ----
class FilmStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 22
		content_margin_right = 22
		content_margin_top = 24
		content_margin_bottom = 22

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 6.0, 0.45)
		RenderingServer.canvas_item_add_rect(item, r, Color("21170f"))
		# 斜めのうすい光（フィルムの艶）
		var a := r.position
		var w := r.size.x
		var h := r.size.y
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([a, a + Vector2(w * 0.45, 0), a + Vector2(w * 0.3, h), a + Vector2(0, h)]),
			PackedColorArray([Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.03)]))
		# 送り穴（上下）
		var hole := Vector2(11, 7)
		var x := r.position.x + 8.0
		while x + hole.x < r.end.x - 6.0:
			RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(x, r.position.y + 5.0), hole), Color("efe2c6", 0.9))
			RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(x, r.end.y - 5.0 - hole.y), hole), Color("efe2c6", 0.9))
			x += 22.0


# ---- 知らせ：スケッチブックのカンペ ----
class KanpeStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 26
		content_margin_right = 26
		content_margin_top = 30
		content_margin_bottom = 16

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 7.0, 0.38)
		RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(0, 3), r.size), Color("d9d5cb"))
		RenderingServer.canvas_item_add_rect(item, r, Color("fcfbf7"))
		# リング（上の縁をまたぐ）と、紙の穴
		var x := r.position.x + 18.0
		while x < r.end.x - 18.0:
			RenderingServer.canvas_item_add_circle(item, Vector2(x + 3.0, r.position.y + 11.0), 2.6, Color(0.23, 0.23, 0.23, 0.55))
			RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(x, r.position.y - 9.0), Vector2(6, 19)), Color("9aa1a8"))
			RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(x + 4.0, r.position.y - 9.0), Vector2(2, 19)), Color("c9ced3"))
			x += 26.0


# ---- 上の帯：撮影カメラの画面の四隅の枠 ----
class CamStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 26
		content_margin_right = 26
		content_margin_top = 10
		content_margin_bottom = 10

	func _draw(item: RID, r: Rect2) -> void:
		# 枠の中は塗らない（字には黒いふちを付けて読めるようにする）
		var L := 18.0
		var t := 3.0
		var c := Color(1, 1, 1, 0.95)
		var sh := Color(0, 0, 0, 0.55)
		for pass_i in 2:
			var off := Vector2(1, 1) if pass_i == 0 else Vector2.ZERO
			var col := sh if pass_i == 0 else c
			var p := r.position + off
			var e := r.end + off
			for corner in [[p, Vector2(1, 1)], [Vector2(e.x, p.y), Vector2(-1, 1)], [Vector2(p.x, e.y), Vector2(1, -1)], [e, Vector2(-1, -1)]]:
				var at: Vector2 = corner[0]
				var d: Vector2 = corner[1]
				RenderingServer.canvas_item_add_rect(item, Rect2(at, Vector2(L * d.x, t * d.y)).abs(), col)
				RenderingServer.canvas_item_add_rect(item, Rect2(at, Vector2(t * d.x, L * d.y)).abs(), col)


# ---- 段ボールの札（色を塗った面、縁に段ボールの地） ----
class CardStyle extends StyleBox:
	var paint := Color("2f8c8a")

	func _init(col: Color = Color("2f8c8a")) -> void:
		paint = col
		content_margin_left = 8
		content_margin_right = 14
		content_margin_top = 5
		content_margin_bottom = 5

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 5.0, 0.4)
		RenderingServer.canvas_item_add_rect(item, r, FilmSet.KRAFT_EDGE)
		RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(0, r.size.y - 3.0), Vector2(r.size.x, 3.0)), Color("a57946"))
		var face := r.grow(-3.0)
		RenderingServer.canvas_item_add_rect(item, face, paint)
		RenderingServer.canvas_item_add_texture_rect_region(item, face, FilmSet.brush().get_rid(), FilmSet.paint_region(face))
		var a := face.position
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([a, a + Vector2(face.size.x, 0), face.end, a + Vector2(0, face.size.y)]),
			PackedColorArray([Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.04), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.05)]))


# ---- Esc のメニュー：クリップボードに挟んだ紙 ----
class ClipboardStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 40
		content_margin_right = 40
		content_margin_top = 62
		content_margin_bottom = 34

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 9.0, 0.5)
		# 板（茶色のハードボード）
		RenderingServer.canvas_item_add_rect(item, r, Color("8a5d36"))
		RenderingServer.canvas_item_add_rect(item, r.grow(-3), Color("a06f43"))
		RenderingServer.canvas_item_add_texture_rect_region(item, r.grow(-3), FilmSet.brush().get_rid(), FilmSet.paint_region(r))
		# 紙
		var paper := Rect2(r.position + Vector2(16, 30), r.size - Vector2(32, 44))
		RenderingServer.canvas_item_add_rect(item, Rect2(paper.position + Vector2(2, 3), paper.size), Color(0, 0, 0, 0.25))
		RenderingServer.canvas_item_add_rect(item, paper, Color("f8f5ec"))
		# 金具（上のまん中）
		var cw := minf(150.0, r.size.x * 0.4)
		var clip := Rect2(Vector2(r.get_center().x - cw * 0.5, r.position.y + 8), Vector2(cw, 34))
		RenderingServer.canvas_item_add_rect(item, Rect2(clip.position + Vector2(0, 3), clip.size), Color(0, 0, 0, 0.35))
		RenderingServer.canvas_item_add_rect(item, clip, Color("b9bec3"))
		RenderingServer.canvas_item_add_rect(item, Rect2(clip.position + Vector2(0, clip.size.y - 6), Vector2(cw, 6)), Color("8d9399"))
		RenderingServer.canvas_item_add_rect(item, Rect2(clip.position + Vector2(cw * 0.35, -8), Vector2(cw * 0.3, 10)), Color("9aa1a8"))


# ボタンを、色を塗った段ボールの札にする（Esc のメニューなど）。乗せると少し明るく、押すと沈む
static func style_sign_button(b: Button, paint_name: String, px: int = 20, tall: int = 46) -> void:
	var paint: Array = PAINTS[paint_name]
	var normal := CardStyle.new(paint[0])
	var hover := CardStyle.new((paint[0] as Color).lightened(0.12))
	var press := CardStyle.new((paint[0] as Color).darkened(0.12))
	# キーの札（UI.KeyButton の cap）が右端に付く札は、その分だけ右を空ける
	var cap: Variant = b.get("cap")
	var right := 16.0 + ((cap as Control).custom_minimum_size.x + 10.0 if cap is Control else 0.0)
	for s: StyleBox in [normal, hover, press]:
		s.content_margin_left = 16
		s.content_margin_right = right
		s.content_margin_top = 6
		s.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover_pressed", press)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_font_override("font", font("marker"))
	b.add_theme_font_size_override("font_size", px)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, paint[1])
	b.custom_minimum_size.y = tall


# ---- Tab の撮影の手引き：1画面に収める（流れ＝フィルムのコマ、操作＝段ボールの札、コツ＝カンペ） ----
const HELP_FLOW := [
	["依頼を選ぶ", "事務所の掲示板で F"],
	["廃材を集める", "使えそうな物を探す"],
	["見立てる", "Y で役を決める"],
	["軽トラに積む", "荷台のそばで F"],
	["現場で組む", "仕掛けを組んで練習"],
	["本番・試写会", "カチンコで本番"],
]
const HELP_KEYS := ["WASD 移動", "Shift 走る", "Space ジャンプ",
	"左クリック 持つ・置く", "右クリック 押したまま回す", "ホイール 持つ距離",
	"Q・E 傾ける", "R 起こす", "G 手元へ",
	"N 力を抜く", "F 使う・開く", "Y 役を決める",
	"Z 演技", "H 演技を選ぶ", "1・2・3 合図",
	"T カット", "右クリック 画面を閉じる", "Esc メニュー",
	"C キャラクター", "F2 視点", "右クリック モニターを開く"]
const HELP_TIPS := [
	"物の〔属性〕が役に合うほど、ギャラが増える",
	"同じ属性の物を別の役に使うと、コンボ",
	"依頼主の好みは、机ののぞき箱でわかる",
	"借り物は制作費から。余りは会社の貯金に",
	"3本ごとに家賃。払えないと倒産",
	"荷台に積みすぎると、道中で落ちる",
]


static func help_board() -> VBoxContainer:
	var board := VBoxContainer.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_theme_constant_override("separation", 18)
	# 題と、閉じ方
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(head)
	var title := label("撮影の手引き", 40, Color("fbf3e2"), "marker")
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	head.add_child(title)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(fill)
	# 閉じる札（マウスで押せる。Tab でも閉じる）。押した時の動きは、作った側（production_hud.gd）がつなぐ
	var close := Button.new()
	close.name = "Close"
	close.text = "閉じる（%s）" % Keybinds.label("help")
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_sign_button(close, "cream", 18, 40)
	head.add_child(close)
	# 流れ：フィルムのコマ
	var film := PanelContainer.new()
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film.add_theme_stylebox_override("panel", FilmStyle.new())
	board.add_child(film)
	var frames := HBoxContainer.new()
	frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frames.add_theme_constant_override("separation", 10)
	film.add_child(frames)
	for i in HELP_FLOW.size():
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color("2e2318")
		fs.border_color = Color(0.96, 0.91, 0.81, 0.45)
		fs.set_border_width_all(2)
		fs.set_corner_radius_all(6)
		fs.content_margin_left = 12
		fs.content_margin_right = 12
		fs.content_margin_top = 10
		fs.content_margin_bottom = 12
		frame.add_theme_stylebox_override("panel", fs)
		frame.custom_minimum_size.x = 168
		frames.add_child(frame)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		frame.add_child(col)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", 8)
		col.add_child(top)
		top.add_child(label(str(i + 1), 18, Color("ffd66b"), "mono"))
		top.add_child(label(HELP_FLOW[i][0], 19, Color("fff4dc"), "mincho"))
		var note := label(HELP_FLOW[i][1], 14, Color("d8c8a4"), "marker")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 144
		col.add_child(note)
	# 下の段：操作（札）と、コツ（カンペ）
	var lower := HBoxContainer.new()
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.add_theme_constant_override("separation", 30)
	board.add_child(lower)
	var keys := VBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("separation", 12)
	lower.add_child(keys)
	var kt := label("操作", 24, Color("fbf3e2"), "marker")
	kt.add_theme_constant_override("outline_size", 5)
	kt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	keys.add_child(kt)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	keys.add_child(grid)
	var last := ""
	for i in HELP_KEYS.size():
		var seg: String = HELP_KEYS[i]
		var name := paint_for(seg, i)
		if name == last:
			name = ["teal", "mustard", "tomato", "sky", "cream"][(["teal", "mustard", "tomato", "sky", "cream"].find(name) + 1) % 5]
		last = name
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", CardStyle.new(PAINTS[name][0]))
		card.add_child(_sign_content(seg, PAINTS[name][1], 16))
		grid.add_child(card)
	var tips := PanelContainer.new()
	tips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tips.add_theme_stylebox_override("panel", KanpeStyle.new())
	tips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tips.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lower.add_child(tips)
	var tl := VBoxContainer.new()
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_constant_override("separation", 6)
	tips.add_child(tl)
	tl.add_child(label("コツ", 24, MARKER_RED, "marker"))
	for line: String in HELP_TIPS:
		var l := label("・" + line, 17, MARKER_INK, "marker")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 380
		tl.add_child(l)
	return board


# ---- 依頼の掲示板：映画館のロビーの「近日撮影」の壁。依頼1件が額縁入りのポスター1枚 ----
# 壁：赤いビロード。上に電球の並んだ看板の帯（文字は、作る側が載せる）
class WallStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 36
		content_margin_right = 36
		content_margin_top = 26
		content_margin_bottom = 26

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 10.0, 0.55)
		var a := r.position
		var w := r.size.x
		var h := r.size.y
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([a, a + Vector2(w, 0), a + Vector2(w, h), a + Vector2(0, h)]),
			PackedColorArray([Color("5e1b1e"), Color("5e1b1e"), Color("2f0c0e"), Color("2f0c0e")]))
		# ビロードのひだ（縦の、ゆるい濃淡）
		var x := 0.0
		var k := 0
		while x < w:
			var fold := 26.0 + float((k * 37) % 19)
			RenderingServer.canvas_item_add_rect(item, Rect2(a + Vector2(x, 0), Vector2(fold * 0.5, h)), Color(0, 0, 0, 0.12 if k % 2 == 0 else 0.0))
			x += fold
			k += 1
		# 金の縁
		RenderingServer.canvas_item_add_rect(item, Rect2(a, Vector2(w, 4)), Color("c99c43"))
		RenderingServer.canvas_item_add_rect(item, Rect2(a + Vector2(0, h - 4), Vector2(w, 4)), Color("8a6a24"))


# ポスターの絵（依頼の種類ごと）。台本の種類：castle＝月夜の城、kaiju＝街に立つ怪獣、trap＝転がる大岩、debut＝会社の紹介（星）
class PosterArt extends Control:
	var kind := "castle"
	var variant := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 150)

	func _draw() -> void:
		var s := size
		var hue := float(variant % 5) * 0.035
		match kind:
			"debut":
				draw_rect(Rect2(Vector2.ZERO, s), Color("1f1f1f"))
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y * 0.38), Vector2(0, s.y * 0.72)]), Color("ffd43b"))
				_star(Vector2(s.x * 0.72, s.y * 0.24), s.x * 0.16, Color("e2352b"))
				for i in 3:
					draw_rect(Rect2(Vector2(s.x * (0.12 + 0.26 * i), s.y * 0.66), Vector2(s.x * 0.16, s.y * 0.34)), Color(0.08, 0.08, 0.08))
					draw_circle(Vector2(s.x * (0.2 + 0.26 * i), s.y * 0.62), s.x * 0.07, Color(0.08, 0.08, 0.08))
			"kaiju":
				_sky(Color.from_hsv(0.36 + hue, 0.35, 0.28), Color.from_hsv(0.12 + hue, 0.3, 0.72))
				var m := PackedVector2Array()
				for p: Vector2 in [Vector2(0.3, 1.0), Vector2(0.26, 0.6), Vector2(0.1, 0.5), Vector2(0.2, 0.38), Vector2(0.34, 0.34), Vector2(0.36, 0.12),
						Vector2(0.52, 0.02), Vector2(0.6, 0.14), Vector2(0.62, 0.3), Vector2(0.8, 0.4), Vector2(0.72, 0.52), Vector2(0.66, 0.6), Vector2(0.7, 1.0)]:
					m.append(Vector2(s.x * (0.12 + p.x * 0.76), s.y * (0.12 + p.y * 0.88)))
				draw_colored_polygon(m, Color("10170f"))
				draw_circle(Vector2(s.x * 0.53, s.y * 0.2), s.x * 0.022, Color("ffd43b"))
				_town(Color("0b0f0a"))
			"trap":
				_sky(Color.from_hsv(0.08 + hue, 0.55, 0.32), Color.from_hsv(0.1 + hue, 0.45, 0.82))
				draw_colored_polygon(PackedVector2Array([Vector2(0, s.y * 0.7), Vector2(s.x, s.y * 0.52), Vector2(s.x, s.y), Vector2(0, s.y)]), Color("2b1a0e"))
				draw_circle(Vector2(s.x * 0.62, s.y * 0.48), s.x * 0.26, Color("3a2a1c"))
				draw_arc(Vector2(s.x * 0.62, s.y * 0.48), s.x * 0.18, 0.6, 2.2, 12, Color(0, 0, 0, 0.35), s.x * 0.03)
				for i in 3:
					draw_line(Vector2(s.x * (0.25 - i * 0.05), s.y * (0.38 + i * 0.1)), Vector2(s.x * (0.05 - i * 0.03), s.y * (0.38 + i * 0.1)), Color(1, 1, 1, 0.5), 2.0)
				draw_circle(Vector2(s.x * 0.18, s.y * 0.66), s.x * 0.05, Color("1a0f08"))
			_:
				# 同じ城の映画でも、ポスターごとに空の色・月の位置・城の形を変える（並べたときに見分けられるように）
				var skies := [[Color("0f1d3a"), Color("f08a2e")], [Color("2a1240"), Color("e86a8a")], [Color("0d3438"), Color("e8c84a")], [Color("1b1530"), Color("7fb3e8")]]
				var sky: Array = skies[variant % skies.size()]
				_sky(sky[0], sky[1])
				var mx: float = [0.5, 0.28, 0.72, 0.38][variant % 4]
				var mr: float = [0.13, 0.1, 0.16, 0.12][variant % 4]
				draw_circle(Vector2(s.x * mx, s.y * 0.22), s.x * mr * 1.3, Color(1, 0.95, 0.75, 0.15))
				draw_circle(Vector2(s.x * mx, s.y * 0.22), s.x * mr, Color("fff4cf"))
				var shapes := [
					[Vector2(0, 1), Vector2(0, 0.4), Vector2(0.14, 0.4), Vector2(0.14, 0.2), Vector2(0.24, 0.2), Vector2(0.24, 0.45), Vector2(0.4, 0.45),
						Vector2(0.4, 0.1), Vector2(0.52, 0.1), Vector2(0.52, 0.45), Vector2(0.7, 0.45), Vector2(0.7, 0.25), Vector2(0.82, 0.25), Vector2(0.82, 0.5), Vector2(1, 0.5), Vector2(1, 1)],
					[Vector2(0, 1), Vector2(0, 0.55), Vector2(0.2, 0.55), Vector2(0.2, 0.3), Vector2(0.28, 0.12), Vector2(0.36, 0.3), Vector2(0.36, 0.55), Vector2(0.64, 0.55),
						Vector2(0.64, 0.3), Vector2(0.72, 0.12), Vector2(0.8, 0.3), Vector2(0.8, 0.55), Vector2(1, 0.55), Vector2(1, 1)],
					[Vector2(0, 1), Vector2(0.1, 0.62), Vector2(0.3, 0.6), Vector2(0.38, 0.35), Vector2(0.38, 0.05), Vector2(0.46, 0.0), Vector2(0.54, 0.05), Vector2(0.54, 0.35),
						Vector2(0.62, 0.6), Vector2(0.9, 0.62), Vector2(1, 1)],
				]
				var c := PackedVector2Array()
				for p: Vector2 in shapes[variant % shapes.size()]:
					c.append(Vector2(s.x * (0.12 + p.x * 0.76), s.y * (0.58 + p.y * 0.42)))
				draw_colored_polygon(c, Color("0b0a10"))

	func _sky(top: Color, bottom: Color) -> void:
		var s := size
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([top, top, bottom, bottom]))

	func _town(col: Color) -> void:
		var s := size
		var x := 0.0
		var i := 0
		while x < s.x:
			var bw := s.x * (0.09 + float((i * 7) % 5) * 0.02)
			var bh := s.y * (0.1 + float((i * 11) % 7) * 0.025)
			draw_rect(Rect2(Vector2(x, s.y - bh), Vector2(bw, bh)), col)
			x += bw + 2.0
			i += 1

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var ang := -PI * 0.5 + float(i) * PI / 5.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, col)


# ポスターの額縁（金）。乗せると、額縁が光る
static func frame_style(lit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("161214")
	s.border_color = Color("ffe7a8") if lit else Color("b38a3a")
	s.set_border_width_all(6 if lit else 7)
	s.shadow_color = Color(1.0, 0.82, 0.45, 0.55) if lit else Color(0, 0, 0, 0.55)
	s.shadow_size = 18 if lit else 8
	s.shadow_offset = Vector2.ZERO if lit else Vector2(0, 6)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


# ---- 開いて使う画面を、紙にする（依頼の掲示板・発注・積み込み確認・テイク確認・精算・キャラ選び など） ----
# 元は暗い板の上に白い字で作ってある画面を、あとから紙に塗り替える：
#   板 → 紙（PaperStyle）／ 白い字 → ペンの黒 ／ 灰色の字 → 薄い墨 ／ 黄の字 → 濃い黄土
#   暗い札（中の小さな板・カード）→ 薄い紙の札 ／ ボタン → 段ボールの札（黄＝主、赤＝警告、ほか＝クリーム）
# あとから足される行（作り直す一覧など）も、足された時に塗り替える（paperize で登録した画面の中だけ）
class PaperStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 34
		content_margin_right = 34
		content_margin_top = 30
		content_margin_bottom = 26

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 8.0, 0.45)
		RenderingServer.canvas_item_add_rect(item, r, Color("f7f3e9"))
		RenderingServer.canvas_item_add_texture_rect_region(item, r, FilmSet.brush().get_rid(), FilmSet.paint_region(r), Color(1, 1, 1, 0.35))

const PAPER_INK_SOFT := Color("5d5850")
static var _paper_roots: Array = []
static var _watching := false


static func paperize(root: Control) -> void:
	if root == null:
		return
	if root is PanelContainer:
		if "sb" in root:
			root.set("sb", null)
		root.add_theme_stylebox_override("panel", PaperStyle.new())
	_paper_roots.append(root)
	_ink_tree(root, root)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not _watching:
		_watching = true
		tree.node_added.connect(_on_node_added)


static func _on_node_added(n: Node) -> void:
	if not (n is Control):
		return
	_paper_roots = _paper_roots.filter(func(r: Variant) -> bool: return is_instance_valid(r))
	for r: Control in _paper_roots:
		if r.is_ancestor_of(n):
			_ink_node.call_deferred(n, r)       # 作った側が色や文字を入れ終わってから
			return


static func _ink_tree(n: Node, root: Control) -> void:
	_ink_node(n, root)
	for c in n.get_children():
		_ink_tree(c, root)


static func _paper_card(border_alpha: float = 0.18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("efe8d8")
	s.border_color = Color(0.1, 0.08, 0.05, border_alpha)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func _paper_color(c: Color) -> Color:
	if c.a < 0.05:
		return c
	if c.s < 0.25 and c.v > 0.75:
		return MARKER_INK                       # 白い字
	if c.s < 0.25 and c.v > 0.45:
		return PAPER_INK_SOFT                   # 灰色の字
	if c.s >= 0.4 and c.h > 0.09 and c.h < 0.2:
		return Color("a8740c")                  # 黄の字
	if c.s >= 0.4 and c.h > 0.25 and c.h < 0.5:
		return Color("1e8a4a")                  # 緑の字
	return c


static func _ink_node(n: Node, root: Control) -> void:
	if not is_instance_valid(n) or n.has_meta("papered"):
		return
	n.set_meta("papered", true)
	if n is Label:
		var l := n as Label
		l.add_theme_color_override("font_color", _paper_color(l.get_theme_color("font_color")))
		l.add_theme_constant_override("outline_size", 0)
		if l.get_theme_font_size("font_size") >= 26:
			l.add_theme_font_override("font", font("marker"))
	elif n is RichTextLabel:
		(n as RichTextLabel).add_theme_color_override("default_color", MARKER_INK)
	elif n is Button:
		var b := n as Button
		var px := b.get_theme_font_size("font_size")
		var tall := int(maxf(b.custom_minimum_size.y, 36.0))
		var sb := b.get_theme_stylebox("normal")
		var paint := "cream"
		if sb is StyleBoxFlat:
			var c: Color = (sb as StyleBoxFlat).bg_color
			if c.s > 0.5 and c.h > 0.09 and c.h < 0.2:
				paint = "mustard"
			elif c.s > 0.5 and (c.h < 0.05 or c.h > 0.95):
				paint = "tomato"
		style_sign_button(b, paint, px, tall)
	elif n.has_method("set_styles"):
		# 押せるカード（UI.ClickBox）
		var normal := _paper_card()
		var hover := _paper_card(0.35)
		hover.bg_color = Color("f6efdc")
		var chosen := _paper_card(1.0)
		chosen.border_color = MARKER_INK
		chosen.set_border_width_all(2)
		chosen.bg_color = Color("fff6d6")
		n.call("set_styles", normal, hover, chosen)
	elif n is PanelContainer and n != root:
		if "sb" in n:
			n.set("sb", null)
		var old := (n as PanelContainer).get_theme_stylebox("panel")
		var card := _paper_card()
		if old != null:
			card.content_margin_left = old.content_margin_left
			card.content_margin_right = old.content_margin_right
			card.content_margin_top = old.content_margin_top
			card.content_margin_bottom = old.content_margin_bottom
		(n as PanelContainer).add_theme_stylebox_override("panel", card)
	elif n is ColorRect and n != root:
		var cr := n as ColorRect
		if (cr.size.x <= 2.0 or cr.size.y <= 2.0 or cr.custom_minimum_size.x <= 2.0 or cr.custom_minimum_size.y <= 2.0) and cr.color.v > 0.5:
			cr.color = Color(0, 0, 0, 0.15)                 # 細い区切りの線
	if "ink" in n and n.get("ink") is Color:
		n.set("ink", MARKER_INK)
	if "line" in n and n.get("line") is Color:
		n.set("line", Color(0, 0, 0, 0.35))
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()


# ---- お金：コインのマーク（金色の丸、ふちと内側の輪） ----
class CoinMark extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(c + Vector2(1, 1.5), r, Color(0, 0, 0, 0.45))
		draw_circle(c, r, Color("b8860b"))
		draw_circle(c, r - 1.6, Color("f2c230"))
		draw_arc(c, r * 0.58, 0.0, TAU, 20, Color("c9971a"), 1.6, true)
		draw_arc(c, r - 2.6, PI * 1.05, PI * 1.6, 8, Color(1, 1, 1, 0.6), 1.4, true)


# ---- 狙った物の名前：黄色い付箋 ----
static func tag_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("fff36b")
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


# ---- 操作の案内：段ボールの札を、角材で持ち上げる ----
# 札1枚（と、その下の角材）。札の裏を通る角材は、この箱の _draw で札より先に描く（だから札の裏に来る）
class Post extends VBoxContainer:
	var lift := 10.0
	var sign: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 0)
		resized.connect(func() -> void:
			pivot_offset = Vector2(size.x * 0.5, size.y)
			queue_redraw())

	func _draw() -> void:
		if sign == null:
			return
		var w := 8.0
		var cx := size.x * 0.5
		var top := sign.size.y * 0.2
		var r := Rect2(cx - w * 0.5, top, w, size.y - top + 2.0)
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
		draw_rect(r, Color("d5a86e"))
		draw_rect(Rect2(r.position + Vector2(w * 0.76, 0), Vector2(w * 0.24, r.size.y)), Color(0.27, 0.16, 0.06, 0.42))
		# 木目（間隔も濃さもばらばらの数本。繰り返さない）
		for g in [[0.12, 0.28], [0.3, 0.14], [0.48, 0.22], [0.63, 0.12]]:
			draw_rect(Rect2(r.position + Vector2(w * g[0], 0), Vector2(1, r.size.y)), Color(0.47, 0.27, 0.12, g[1]))
		# 札のすぐ下に、札の影
		var y0 := sign.size.y
		draw_polygon(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y0 + 8), Vector2(r.position.x, y0 + 8)]),
			PackedColorArray([Color(0.16, 0.09, 0.03, 0.5), Color(0.16, 0.09, 0.03, 0.5), Color(0.16, 0.09, 0.03, 0), Color(0.16, 0.09, 0.03, 0)]))


# 操作の案内の1区切り（"F 荷台に積む" など）→ 札の中身。キーは黒く塗った四角にステンシルの字
static func _sign_content(segment: String, ink: Color, px: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var run: Array[String] = []
	var flush := func() -> void:
		if not run.is_empty():
			var l := label(" ".join(run), px, ink, "marker")
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(l)
			run.clear()
	for word: String in segment.split(" ", false):
		var key := _key_of(word)
		if key != "":
			flush.call()
			row.add_child(_chip(key, px))
		else:
			run.append(word)
	flush.call()
	return row


static func _key_of(word: String) -> String:
	if word == "左クリック":
		return "左"
	if word == "右クリック":
		return "右"
	if word == "ホイール":
		return "ホイール"
	if UI.is_key_token(word):
		return Keybinds.shown(word.trim_prefix("[").trim_suffix("]"))
	return ""


static func _chip(key: String, px: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.07, 0.06, 0.88)
	s.set_corner_radius_all(2)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", s)
	var l := label(key, maxi(10, px - 3), Color("fbf3e2"), "stencil")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = px - 2
	chip.add_child(l)
	return chip


# 札の色：最初のキーで決める（決まっていないキーは、順に回す）
static func paint_for(segment: String, index: int) -> String:
	for word: String in segment.split(" ", false):
		var key := word if UI.is_key_token(word) else _key_of(word)     # 色は、初期のキー名で決める（キーを替えても色は同じ）
		if KEY_PAINT.has(key):
			return KEY_PAINT[key]
	return ["sky", "tomato", "mustard", "teal"][index % 4]


# 札の並び。segments は "F 荷台に積む" のような区切り。dim は控えめに出す区切り（あそびかた など）
static func signs(segments: Array, dim: Array = [], px: int = 17) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var last := ""
	for i in segments.size():
		var seg: String = segments[i]
		var small := seg in dim
		var name := paint_for(seg, i)
		if name == last:                       # となりの札と同じ色にしない
			var order := ["teal", "mustard", "tomato", "sky", "cream"]
			name = order[(order.find(name) + 1) % order.size()]
		last = name
		var paint: Array = PAINTS[name]
		var post := Post.new()
		post.size_flags_vertical = Control.SIZE_SHRINK_END
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", CardStyle.new(paint[0]))
		card.add_child(_sign_content(seg, paint[1], px - (3 if small else 0)))
		post.add_child(card)
		post.sign = card
		# 傾きと高さは、文から決める（出し直すたびに揺れないように）
		var h := absi(seg.hash())
		post.lift = 14.0 + float(h % 3) * 5.0 - (5.0 if small else 0.0)
		var spacer := Control.new()
		spacer.custom_minimum_size.y = post.lift
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		post.add_child(spacer)
		post.rotation = deg_to_rad(float(h % 7 - 3) * 1.1)
		# 箱（HBox）は中の物の傾きを消してしまうので、ただの置き場（slot）に入れて、置き場の大きさだけを札に合わせる
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size_flags_vertical = Control.SIZE_SHRINK_END
		slot.add_child(post)
		post.resized.connect(func() -> void:
			slot.custom_minimum_size = post.size
			post.position = Vector2.ZERO)
		row.add_child(slot)
	return row
