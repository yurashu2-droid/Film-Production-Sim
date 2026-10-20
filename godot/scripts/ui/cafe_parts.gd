class_name CafeParts
extends RefCounted
## 打ち合わせ（喫茶店のテーブル）の物：テーブル・コーヒーカップ・ポラロイド写真・吹き出し・絵コンテの紙・御伝票・判子。
## どれも絵は _draw で描く（画像ファイルは持たない）。使うのは ui/briefing.gd
const INK := Color("2a2622")
const INK_SOFT := Color("5d5850")
const PRINT_RED := Color("a8392c")      # 伝票に刷ってある字と線
const STAMP_RED := Color("c8322a")


# 角の丸い四角の外周（左上から時計回り）
static func rounded(r: Rect2, radius: float, seg: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var centers := [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
	for k in 4:
		var start := PI + float(k) * PI * 0.5
		for i in seg + 1:
			var a := start + float(i) / float(seg) * PI * 0.5
			pts.append((centers[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


# ---- 喫茶店のテーブル：木の天板（まん中が明るい）と、暗い縁 ----
class Table extends Control:
	var top := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if top.size.x < 10.0:
			return
		var radius := 22.0
		# 影
		for k in 4:
			var g := float(k) * 6.0
			draw_colored_polygon(CafeParts.rounded(Rect2(top.position + Vector2(-g, 14.0 - g * 0.3), top.size + Vector2(g * 2.0, g * 2.0)), radius + g), Color(0, 0, 0, 0.16))
		# 縁（暗い木）
		draw_colored_polygon(CafeParts.rounded(top, radius), Color("2e1b0f"))
		# 天板：明るいまん中から縁へ暗く（扇形に色を付けて、丸い光にする）
		var face := top.grow(-10.0)
		var outline := CafeParts.rounded(face, radius - 8.0)
		var light := face.position + face.size * Vector2(0.42, 0.32)
		var c_mid := Color("8a5a34")
		var c_edge := Color("5b3820")
		var reach := face.size.length() * 0.62
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			draw_polygon(PackedVector2Array([light, a, b]), PackedColorArray([c_mid, c_mid.lerp(c_edge, clampf(a.distance_to(light) / reach, 0.0, 1.0)), c_mid.lerp(c_edge, clampf(b.distance_to(light) / reach, 0.0, 1.0))]))
		# 木目：ゆるく波打つ細い線（間隔と濃さは、毎回同じ乱数で）
		var rng := RandomNumberGenerator.new()
		rng.seed = 4021
		var y := face.position.y + 6.0
		while y < face.end.y - 4.0:
			var pts := PackedVector2Array()
			var amp := rng.randf_range(1.0, 4.0)
			var freq := rng.randf_range(0.004, 0.011)
			var phase := rng.randf() * TAU
			var inset := 6.0 if (y - face.position.y > radius and face.end.y - y > radius) else radius
			var x := face.position.x + inset
			while x <= face.end.x - inset:
				pts.append(Vector2(x, y + sin(x * freq + phase) * amp))
				x += 24.0
			var dark := rng.randf() < 0.7
			draw_polyline(pts, Color(0.12, 0.06, 0.02, rng.randf_range(0.06, 0.16)) if dark else Color(1, 0.85, 0.6, rng.randf_range(0.03, 0.07)), rng.randf_range(1.0, 2.2), true)
			y += rng.randf_range(7.0, 19.0)
		# 縁の内側の、細い明るい線（面取り）
		draw_polyline(outline + PackedVector2Array([outline[0]]), Color(1, 0.86, 0.66, 0.18), 2.0, true)
		# 端を少し暗く（天板の照り返しが届かない所）
		draw_polyline(outline + PackedVector2Array([outline[0]]), Color(0, 0, 0, 0.22), 10.0, true)


# ---- コーヒーカップ（上から見た）：受け皿・白いカップ・コーヒー・取っ手 ----
class Cup extends Control:
	var handle_angle := 0.6
	var spoon := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(4, 7), r * 0.98, Color(0, 0, 0, 0.32))
		draw_circle(c, r, Color("d6cebd"))
		draw_circle(c, r * 0.94, Color("ece6d8"))
		draw_arc(c, r * 0.8, 0.0, TAU, 48, Color(0, 0, 0, 0.06), 2.0, true)
		# スプーン（受け皿の上）
		if spoon:
			var d := Vector2(cos(handle_angle + 2.2), sin(handle_angle + 2.2))
			var p0 := c + d * r * 0.48
			var p1 := c + d * r * 0.98
			draw_line(p0 + Vector2(2, 3), p1 + Vector2(2, 3), Color(0, 0, 0, 0.18), r * 0.06, true)
			draw_line(p0, p1, Color("b9bec3"), r * 0.055, true)
			draw_circle(p0, r * 0.075, Color("c9ced3"))
		# 取っ手
		var hd := Vector2(cos(handle_angle), sin(handle_angle))
		var hp := c + hd * r * 0.66
		draw_line(c + hd * r * 0.5 + Vector2(3, 4), hp + hd * r * 0.12 + Vector2(3, 4), Color(0, 0, 0, 0.22), r * 0.17, true)
		draw_line(c + hd * r * 0.5, hp + hd * r * 0.12, Color("f4f0e6"), r * 0.15, true)
		# カップ
		draw_circle(c + Vector2(3, 5), r * 0.6, Color(0, 0, 0, 0.25))
		draw_circle(c, r * 0.6, Color("f6f2e9"))
		draw_arc(c, r * 0.6, 0.0, TAU, 48, Color(0, 0, 0, 0.12), 1.5, true)
		draw_circle(c, r * 0.49, Color("2f1c0f"))
		draw_circle(c, r * 0.47, Color("3b2414"))
		draw_arc(c, r * 0.42, 0.0, TAU, 40, Color("5a3a20", 0.55), r * 0.04, true)
		# コーヒーの面の照り
		draw_arc(c, r * 0.33, PI * 1.05, PI * 1.45, 10, Color(1, 1, 1, 0.22), r * 0.05, true)


# ---- ポラロイド写真の中身：背景の色と、依頼主の顔 ----
class Photo extends Control:
	var tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
			PackedColorArray([Color("b7c9d8"), Color("b7c9d8"), Color("d8c4a6"), Color("d8c4a6")]))
		if tex != null:
			var ts := tex.get_size()
			var k := minf(s.x / ts.x, s.y / ts.y)
			var d := ts * k
			draw_texture_rect(tex, Rect2((s - d) * Vector2(0.5, 1.0), d), false)
		# 写真の色あせ（うすい黄ばみ）
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.92, 0.7, 0.08))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.25), false, 1.0)


# 紙の物（ポラロイドの台紙・絵コンテの紙・伝票）：影を落とした平らな紙
class PaperStyle extends StyleBox:
	var paper := Color("fbfaf5")
	var drop := 6.0

	func _init(col: Color = Color("fbfaf5"), pad_x: float = 10.0, pad_top: float = 10.0, pad_bottom: float = 10.0) -> void:
		paper = col
		content_margin_left = pad_x
		content_margin_right = pad_x
		content_margin_top = pad_top
		content_margin_bottom = pad_bottom

	func _draw(item: RID, r: Rect2) -> void:
		for k in 3:
			var g := float(k) * 2.0
			RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(-g + 2.0, drop - g * 0.5), r.size + Vector2(g * 2.0, g * 2.0)), Color(0, 0, 0, 0.16 / (k + 1.0)))
		RenderingServer.canvas_item_add_rect(item, r, paper)
		# 紙の地のむら
		RenderingServer.canvas_item_add_texture_rect_region(item, r, FilmSet.brush().get_rid(), FilmSet.paint_region(r), Color(1, 1, 1, 0.22))


# ---- 吹き出し：角の丸いクリーム色、左上にしっぽ（写真の依頼主から出る） ----
class BubbleStyle extends StyleBox:
	var fill := Color("fffbe8")

	func _init() -> void:
		content_margin_left = 18
		content_margin_right = 18
		content_margin_top = 14
		content_margin_bottom = 14

	func _draw(item: RID, r: Rect2) -> void:
		var tail := PackedVector2Array([r.position + Vector2(40, 1), r.position + Vector2(56, -16), r.position + Vector2(70, 1)])
		var body := CafeParts.rounded(r, 16.0)
		var shadow := Transform2D(0.0, Vector2(3, 6))
		RenderingServer.canvas_item_add_polygon(item, shadow * body, PackedColorArray([Color(0, 0, 0, 0.28)]))
		RenderingServer.canvas_item_add_polygon(item, shadow * tail, PackedColorArray([Color(0, 0, 0, 0.28)]))
		RenderingServer.canvas_item_add_polygon(item, body, PackedColorArray([fill]))
		RenderingServer.canvas_item_add_polygon(item, tail, PackedColorArray([fill]))


# ---- 伝票の罫線（破線・点線） ----
class Rule extends Control:
	var color := Color(0, 0, 0, 0.35)
	var dash := 6.0
	var gap := 4.0
	var thick := 1.5

	func _init(col: Color = Color(0, 0, 0, 0.35), dash_len: float = 6.0, gap_len: float = 4.0, w: float = 1.5) -> void:
		color = col
		dash = dash_len
		gap = gap_len
		thick = w
		custom_minimum_size.y = maxf(4.0, w + 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 0.0
		var y := size.y * 0.5
		while x < size.x:
			draw_rect(Rect2(x, y - thick * 0.5, minf(dash, size.x - x), thick), color)
			x += dash + gap


static func _ring_text(ci: CanvasItem, c: Vector2, lines: Array, px: int, col: Color) -> void:
	var f := FilmSet.font("mincho")
	var lh := f.get_height(px) * 0.98
	var top := c.y - lh * lines.size() * 0.5
	for i in lines.size():
		var w := f.get_string_size(str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(f, Vector2(c.x - w * 0.5, top + lh * i + f.get_ascent(px)), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


# ---- 判子（押すと引き受ける）：赤い丸い朱肉の面。乗せると少し持ち上がる ----
class Hanko extends Button:
	var words := ["引受", "ます"]

	func _init() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
		resized.connect(func() -> void: pivot_offset = size * 0.5)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 6.0
		var hover := is_hovered() and not disabled
		var down := get_draw_mode() in [Button.DRAW_PRESSED, Button.DRAW_HOVER_PRESSED]
		var lift := 2.0 if down else (9.0 if hover else 6.0)
		draw_circle(c + Vector2(lift * 0.5, lift), r, Color(0, 0, 0, 0.38))
		# 判子の胴（横から見える厚み）と、朱の面
		draw_circle(c + Vector2(0, 3), r, Color("7c1712"))
		var red := CafeParts.STAMP_RED.lightened(0.08) if hover else CafeParts.STAMP_RED
		draw_circle(c, r, red)
		draw_circle(c + Vector2(-r * 0.18, -r * 0.22), r * 0.62, Color(1, 1, 1, 0.07))
		draw_arc(c, r - 9.0, 0.0, TAU, 64, Color("fbe9dc"), 4.0, true)
		draw_arc(c, r - 15.0, 0.0, TAU, 64, Color("fbe9dc", 0.7), 1.5, true)
		CafeParts._ring_text(self, c, words, int(r * 0.42), Color("fbe9dc"))


# ---- 判子の跡（伝票に残る赤い印）：かすれのある輪と字 ----
class Mark extends Control:
	var words := ["引受", "ます"]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(func() -> void: pivot_offset = size * 0.5)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		var ink := Color(CafeParts.STAMP_RED, 0.86)
		# 輪は、すこしずつ濃さの違う弧でつなぐ（朱肉のかすれ）
		var n := 28
		for i in n:
			var a0 := float(i) / n * TAU
			var a1 := float(i + 1) / n * TAU + 0.02
			var fade := 0.55 + 0.45 * absf(sin(float(i) * 2.3 + 0.7))
			draw_arc(c, r - 3.0, a0, a1, 4, Color(ink, ink.a * fade), 5.0, true)
		draw_arc(c, r - 10.0, 0.0, TAU, 56, Color(ink, 0.6), 1.5, true)
		CafeParts._ring_text(self, c, words, int(r * 0.42), ink)
