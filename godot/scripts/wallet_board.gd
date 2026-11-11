extends Control
## お金が大きく動くときに、画面の真ん中へ出す数字の板（features/delivery_box.gd の代金引換で使う）。
## 2026-11-12：ただ字を出すだけ・既定の字に黒いふち、は安く見える（ユーザー）ので、作り直した。
##   ・字にふちは付けない。字の後ろだけ、やわらかく暗くして読ませる
##   ・上に小さな見出し（字間を空ける）と細い線、真ん中に等幅の太い数字、下に朱色の斜めの帯（引かれる額）
##   ・数字は、変わった桁だけが縦に流れる（桁ごとに回って落ちていくように見える）
## 使う側は text（「1,000,600」のような字）を入れ、debit_a（朱色の帯の濃さ）を動かす。大きさは size、消えるときは modulate.a
const INK := Color(0.063, 0.07, 0.094)
const WHITE := Color(0.965, 0.953, 0.918)
const RED := Color(0.93, 0.29, 0.23)

var caption := ""
var debit_label := ""
var debit := ""
var debit_a := 0.0:
	set(v):
		debit_a = v
		queue_redraw()
var text := "":
	set(v):
		if v == text:
			return
		# 変わった桁に、流れる勢いを付ける（右からそろえて比べる）
		var before := text
		text = v
		var spins: Array = []
		for i in v.length():
			var j := before.length() - (v.length() - i)
			var changed := j < 0 or before[j] != v[i]
			var old: float = _spin[_spin.size() - (v.length() - i)] if _spin.size() - (v.length() - i) >= 0 else 0.0
			spins.append(1.0 if changed and v[i] != "," else old)
		_spin = spins
		queue_redraw()
var _spin: Array = []                # 桁ごとの、流れている強さ（1 → 0）
var _num: Font
var _small: Font
var _scrim: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := FontVariation.new()
	num.base_font = load("res://assets/fonts/MPLUS1Code-VF.ttf")
	num.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	_num = num
	var small := FontVariation.new()
	small.base_font = load("res://assets/fonts/NotoSansJP-VF.ttf")
	small.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	_small = small
	# 字の後ろの、やわらかい暗がり（真ん中が濃く、外へ消える）
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.04, 0.06, 0.72))
	g.set_color(1, Color(0.03, 0.04, 0.06, 0.0))
	g.add_point(0.55, Color(0.03, 0.04, 0.06, 0.5))
	_scrim = GradientTexture2D.new()
	_scrim.gradient = g
	_scrim.fill = GradientTexture2D.FILL_RADIAL
	_scrim.fill_from = Vector2(0.5, 0.5)
	_scrim.fill_to = Vector2(1.0, 0.5)
	_scrim.width = 256
	_scrim.height = 128


func _process(delta: float) -> void:
	if not visible:
		return
	var moving := false
	for i in _spin.size():
		if float(_spin[i]) > 0.0:
			_spin[i] = maxf(0.0, float(_spin[i]) - delta * 7.0)
			moving = true
	if moving:
		queue_redraw()


func _spaced(font: Font, at: Vector2, words: String, font_size: int, color: Color, gap: float, measure: bool = false) -> float:
	var pen := at.x
	for ch: String in words:
		if not measure:
			draw_string(font, Vector2(pen, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		pen += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + gap
	return pen - at.x - gap


func _draw() -> void:
	if _num == null:
		return
	var k := size.y / 300.0
	var cx := size.x * 0.5
	draw_texture_rect(_scrim, Rect2(Vector2(cx - 430.0 * k, -40.0 * k), Vector2(860.0 * k, 380.0 * k)), false)
	# 見出しと細い線、真ん中の小さな三角
	var cap := int(15.0 * k)
	var w := _spaced(_small, Vector2.ZERO, caption, cap, WHITE, 6.0 * k, true)
	_spaced(_small, Vector2(cx - w * 0.5, 44.0 * k), caption, cap, Color(WHITE.r, WHITE.g, WHITE.b, 0.82), 6.0 * k)
	var rule := Color(WHITE.r, WHITE.g, WHITE.b, 0.36)
	draw_line(Vector2(cx - 230.0 * k, 64.0 * k), Vector2(cx - 22.0 * k, 64.0 * k), rule, maxf(1.0, k))
	draw_line(Vector2(cx + 22.0 * k, 64.0 * k), Vector2(cx + 230.0 * k, 64.0 * k), rule, maxf(1.0, k))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 6.0 * k, 60.0 * k), Vector2(cx + 6.0 * k, 60.0 * k), Vector2(cx, 69.0 * k)]), RED)
	# 数字：等幅。変わった桁は、下へ流れて薄くなり、上から次の数字が入ってくる
	var fs := int(84.0 * k)
	var unit_fs := int(20.0 * k)
	var cell := _num.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var comma := _num.get_string_size(",", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := 0.0
	for ch: String in text:
		total += comma if ch == "," else cell
	var unit_w := _small.get_string_size("コイン", HORIZONTAL_ALIGNMENT_LEFT, -1, unit_fs).x
	var pen := cx - (total + 10.0 * k + unit_w) * 0.5
	var base := 158.0 * k
	for i in text.length():
		var ch := text[i]
		var spin: float = float(_spin[i]) if i < _spin.size() else 0.0
		if ch == "," or spin <= 0.0:
			draw_string(_num, Vector2(pen, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WHITE)
		else:
			var drop := spin * 26.0 * k
			draw_string(_num, Vector2(pen, base + drop), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(WHITE.r, WHITE.g, WHITE.b, 1.0 - 0.45 * spin))
			draw_string(_num, Vector2(pen, base + drop - 74.0 * k), str((int(ch) + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(WHITE.r, WHITE.g, WHITE.b, 0.07 * spin))
		pen += comma if ch == "," else cell
	draw_string(_small, Vector2(pen + 10.0 * k, base - 2.0 * k), "コイン", HORIZONTAL_ALIGNMENT_LEFT, -1, unit_fs, Color(WHITE.r, WHITE.g, WHITE.b, 0.85))
	# 引かれる額：朱色の斜めの帯。出るときは、左から伸びる
	if debit_a > 0.0:
		var y0 := 196.0 * k
		var y1 := 238.0 * k
		var half := 190.0 * k
		var lean := 12.0 * k
		var grow := half * 2.0 * clampf(debit_a, 0.0, 1.0)
		var left := cx - half
		draw_colored_polygon(PackedVector2Array([Vector2(left + lean, y0), Vector2(left + grow + lean, y0), Vector2(left + grow - lean, y1), Vector2(left - lean, y1)]), Color(RED.r, RED.g, RED.b, clampf(debit_a * 1.5, 0.0, 1.0)))
		if debit_a > 0.6:
			var a := clampf((debit_a - 0.6) / 0.4, 0.0, 1.0)
			_spaced(_small, Vector2(left + 22.0 * k, y0 + 27.0 * k), debit_label, int(15.0 * k), Color(INK.r, INK.g, INK.b, a), 3.0 * k)
			var ds := int(26.0 * k)
			var dw := _num.get_string_size(debit, HORIZONTAL_ALIGNMENT_LEFT, -1, ds).x
			draw_string(_num, Vector2(cx + half - 20.0 * k - dw, y0 + 31.0 * k), debit, HORIZONTAL_ALIGNMENT_LEFT, -1, ds, Color(INK.r, INK.g, INK.b, a))
