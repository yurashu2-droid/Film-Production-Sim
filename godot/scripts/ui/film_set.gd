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


# 塗りのむら（筆の跡）：縦に近い薄い筋。札の上に重ねて、のっぺりさせない（継ぎ目の出ない大きさで1枚）
static func brush() -> ImageTexture:
	if _brush != null:
		return _brush
	var img := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	for i in 70:
		var x := rng.randf_range(0, 128)
		var w := rng.randf_range(1.0, 4.0)
		var a := rng.randf_range(0.03, 0.09)
		var light := rng.randf() < 0.5
		var slant := rng.randf_range(-0.12, 0.12)
		for y in 64:
			var xx := x + slant * float(y)
			for dx in int(ceil(w)):
				var px := int(xx) + dx
				if px >= 0 and px < 128:
					var c := img.get_pixel(px, y)
					var add := Color(1, 1, 1, a) if light else Color(0, 0, 0, a)
					img.set_pixel(px, y, c.blend(add))
	_brush = ImageTexture.create_from_image(img)
	return _brush


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
		# 枠の中を少しだけ暗く（明るい景色の上でも白い字が読めるように）
		RenderingServer.canvas_item_add_rect(item, r.grow(-4), Color(0.04, 0.05, 0.06, 0.32))
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
		RenderingServer.canvas_item_add_texture_rect(item, face, FilmSet.brush().get_rid(), false)
		var a := face.position
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([a, a + Vector2(face.size.x, 0), face.end, a + Vector2(0, face.size.y)]),
			PackedColorArray([Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.04), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.05)]))


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
	if UI.is_key_token(word):
		return word.trim_prefix("[").trim_suffix("]")
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
		var key := _key_of(word)
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
