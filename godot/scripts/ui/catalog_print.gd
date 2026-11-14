class_name CatalogPrint
extends RefCounted
## 安い印刷物（通販カタログ・折り込みチラシ）の部品。
##   ・赤ペンの丸（少し歪んだ手描きの楕円。描き始めと終わりが少し重なる）  pen_ellipse / PenRing
##   ・星形・丸形の飾り（「送料無料」「最安」など）                        Badge
##   ・切り取り線（点線とはさみ）                                         dashed / CutLine
##   ・罫線の引かれた1行（注文はがき・注文票）                            RuledRow
## 使う所：production_display.gd（事務所の奥の、会社の備品の通販カタログ）と order_catalog.gd（機材レンタルのチラシ）

const RED := Color("d63a26")        # 印刷の赤
const PEN := Color("c8352b")        # 赤ペン
const INK := Color("1c1a17")        # 印刷の黒
const SOFT := Color("4a453d")       # 薄い墨（説明の字）
const YELLOW := Color("ffd43b")     # 星の黄


static func font(kind: String) -> Font:
	return FilmSet.font(kind)


# rect を囲む赤ペンの楕円。seed で形が決まる（毎コマ同じ形）。progress 0〜1 で描きかけ
static func pen_ellipse(ci: CanvasItem, rect: Rect2, seed: int, color: Color = PEN, width: float = 3.0, progress: float = 1.0) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var tilt := rng.randf_range(-0.06, 0.06)
	var start := rng.randf_range(-2.4, -1.8)          # 左上あたりから描きはじめる
	var c := rect.get_center()
	var rx := rect.size.x * 0.5
	var ry := rect.size.y * 0.5
	var turn := TAU * 1.07 * p                        # 一周より少し描きすぎて、始まりと重なる
	var n := maxi(8, int(80.0 * p))
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var a := start + turn * t
		var wob := 1.0 + 0.035 * sin(a * 2.0 + ph1) + 0.022 * sin(a * 3.0 + ph2)
		var drift := 1.0 + 0.055 * t * p                # ペンが外へ流れて、終わりが始まりの外を通る
		pts.append(c + Vector2(cos(a) * rx * wob * drift, sin(a) * ry * wob * drift).rotated(tilt))
	ci.draw_polyline(pts, color, width, true)
	# インクのむら：少しずらした細い線をうすく重ねる
	var thin := PackedVector2Array()
	for q in pts:
		thin.append(q + Vector2(0.7, 0.5))
	ci.draw_polyline(thin, Color(color, 0.45), width * 0.5, true)


# 星形（とげの長さを少しずつ変えて、手で切ったような形）
static func burst_points(c: Vector2, r: float, spikes: int = 14, inner: float = 0.74, seed: int = 0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := -PI * 0.5 + float(i) * PI / float(spikes)
		var rr := r * (1.0 if i % 2 == 0 else inner) * rng.randf_range(0.93, 1.04)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 1.5, dash: float = 8.0, gap: float = 6.0) -> void:
	var len := a.distance_to(b)
	if len <= 0.0:
		return
	var d := (b - a) / len
	var t := 0.0
	while t < len:
		ci.draw_line(a + d * t, a + d * minf(t + dash, len), color, width)
		t += dash + gap


# 複数行の字を、中心に合わせて描く
static func draw_centered(ci: CanvasItem, f: Font, center: Vector2, text: String, px: int, color: Color, line_h: float = 1.08) -> void:
	var lines := text.split("\n")
	var h := float(px) * line_h
	var top := center.y - h * float(lines.size()) * 0.5
	for i in lines.size():
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var base := top + h * float(i) + (h - float(px)) * 0.5 + f.get_ascent(px) * 0.92
		ci.draw_string(f, Vector2(center.x - w * 0.5, base), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


# ---- 赤ペンの丸。囲みたい物の上に重ねる（大きさは囲む物に合わせ、pad だけはみ出して描く） ----
class PenRing extends Control:
	var on := false
	var seed := 1
	var pad := Vector2(6, 5)
	var width := 3.0
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(v: bool, animate: bool = true) -> void:
		if v == on:
			return
		on = v
		if on and animate and is_inside_tree():
			progress = 0.0
			var tw := create_tween()
			tw.tween_property(self, "progress", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			progress = 1.0 if on else 0.0

	func _draw() -> void:
		if progress > 0.0:
			CatalogPrint.pen_ellipse(self, Rect2(-pad, size + pad * 2.0), seed, CatalogPrint.PEN, width, progress)


# ---- 星形・丸形の飾り。字は中に描く。置き場（ただの Control）の中で、回して置く ----
class Badge extends Control:
	var text := ""
	var shape := "star"              # star / round
	var fill := Color("ffd43b")
	var ink := Color("d63a26")
	var px := 16
	var seed := 3
	var face: Font                   # 字の書体（無ければステンシル）

	func setup(t: String, kind: String, diameter: float, text_px: int, fill_col: Color, ink_col: Color, tilt_deg: float = 0.0) -> Badge:
		text = t
		shape = kind
		px = text_px
		fill = fill_col
		ink = ink_col
		size = Vector2(diameter, diameter)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		rotation = deg_to_rad(tilt_deg)
		seed = absi(t.hash()) % 1000
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if shape == "round":
			draw_circle(c, r, fill)
			draw_arc(c, r - 4.0, 0.0, TAU, 48, ink, 1.6, true)
		else:
			draw_colored_polygon(CatalogPrint.burst_points(c, r, 14, 0.76, seed), fill)
		CatalogPrint.draw_centered(self, face if face != null else CatalogPrint.font("stencil"), c, text, px, ink)


# ---- 罫線の引かれた1行（はがき・注文票）。下に線を引く ----
class RuledRow extends HBoxContainer:
	var line := Color(0.84, 0.43, 0.4, 0.8)
	var dotted := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 6)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y - 1.0
		if dotted:
			CatalogPrint.dashed(self, Vector2(0, y), Vector2(size.x, y), line, 1.2, 3.0, 3.0)
		else:
			draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.2)


# ---- 縦の切り取り線（点線と、はさみの印） ----
class CutLine extends Control:
	var color := Color(0.1, 0.09, 0.08, 0.6)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(26, 0)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var x := size.x * 0.5
		CatalogPrint.dashed(self, Vector2(x, 0), Vector2(x, size.y), color, 1.6, 9.0, 6.0)
		# はさみ（2つの輪と、交わる刃）
		var y := 40.0
		for s: float in [-1.0, 1.0]:
			draw_arc(Vector2(x + 5.0 * s, y + 10.0), 4.2, 0.0, TAU, 16, color.darkened(0.2), 1.8, true)
			draw_line(Vector2(x + 3.0 * s, y + 6.0), Vector2(x - 3.0 * s, y - 12.0), color.darkened(0.2), 2.0, true)
