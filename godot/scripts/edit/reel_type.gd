extends Control
## 編集の台本（edit/reel_build.gd）の字を描く。スクリーンの絵（features/premiere.gd の _film）の上に、features/editors.gd が 3 枚重ねる：
##   normal：ふつうに載せる字（名匠の明朝・ゴシック、ド派手の 1 字ずつ飛んでくる字）
##   diff  ：絵との差で焼き込む字（名前・同じ言葉の壁）。材質は editors.gd が付ける
##   mask  ：字の形の窓（字の中だけ、絵が見える）。このノードが「子だけを切り抜く」形で、子に絵を持つ
## 決まり（ユーザー 2026-11-13）：字の下に、帯・板を敷かない。既定の書体に黒い縁も付けない。読みにくい所は、やわらかい影と、絵の下の方をなだらかに暗く
const UI := preload("res://scripts/ui/ui_theme.gd")
const MINCHO := "res://assets/fonts/ShipporiMincho-ExtraBold.ttf"
const DELA := "res://assets/fonts/DelaGothicOne-Regular.ttf"
const KINDS := {
	"normal": ["t_title", "t_name", "t_lower", "t_build", "t_big", "t_note", "t_end", "t_sub", "t_ng", "k_slam"],
	"diff": ["k_burn", "k_wall"],
	"mask": ["k_mask"],
}

var mode := "normal"
var items: Array = []            # [種類, 文, 出てからの秒, 消えるまでの秒, おまけ]
var _mincho: Font
var _dela: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mincho = load(MINCHO) if ResourceLoader.exists(MINCHO) else UI.fnt("display")
	_dela = load(DELA) if ResourceLoader.exists(DELA) else UI.fnt("display")


# いま出す字を受け取る（自分の担当の種類だけ）。出す物があれば true
func show_items(list: Array) -> bool:
	items = list.filter(func(it: Array) -> bool: return str(it[0]) in KINDS[mode])
	queue_redraw()
	return not items.is_empty()


# 絵が映っている所（16:9。スクリーンの左右に余りがある）
func picture() -> Rect2:
	var w := size.y * 16.0 / 9.0
	return Rect2((size.x - w) * 0.5, 0.0, w, size.y)


static func _out3(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func _rand(text: String, i: int, salt: int) -> float:
	return float(hash([text, i, salt]) % 1000) / 999.0


# やわらかい影を付けて 1 行。pos は、字の左下（ベースライン）
func _line(font: Font, pos: Vector2, text: String, px: int, color: Color, shade: float = 0.5) -> void:
	if shade > 0.0:
		var dark := Color(0, 0, 0, shade * 0.11 * color.a)
		for r: float in [3.0, 6.0, 10.0]:
			for k in 8:
				draw_string(font, pos + Vector2.from_angle(TAU * float(k) / 8.0) * r + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, dark)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _width(font: Font, text: String, px: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


# 幅に収まる字の大きさ
func _fit(font: Font, text: String, want: float, cap: int) -> int:
	return clampi(int(100.0 * want / maxf(_width(font, text, 100), 1.0)), 12, cap)


func _centered(font: Font, text: String, px: int, cx: float, y: float, color: Color, shade: float = 0.5) -> void:
	_line(font, Vector2(cx - _width(font, text, px) * 0.5, y), text, px, color, shade)


# 字の間を空けて、真ん中そろえで 1 行
func _spaced(font: Font, text: String, px: int, cx: float, y: float, gap: float, color: Color) -> void:
	var total := 0.0
	for i in text.length():
		total += _width(font, text[i], px) + (gap if i < text.length() - 1 else 0.0)
	var x := cx - total * 0.5
	for i in text.length():
		_line(font, Vector2(x, y), text[i], px, color, 0.6)
		x += _width(font, text[i], px) + gap


func _draw() -> void:
	var pic := picture()
	var cx := pic.position.x + pic.size.x * 0.5
	var h := pic.size.y
	var w := pic.size.x
	for it: Array in items:
		var kind := str(it[0])
		var text := str(it[1])
		var t := float(it[2])
		var left := float(it[3])
		var extra := int(it[4])
		var fade := minf(clampf(t / 0.3, 0.0, 1.0), clampf(left / 0.25, 0.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		match kind:
			"t_title":
				_spaced(_mincho, text, 54, cx, h * 0.64, lerpf(22.0, 9.0, _out3(t / 1.3)), Color(1, 1, 1, fade))
			"t_name":
				# 右下（左下は、依頼主の顔・再生数の札・ふきだしと重なる）。右から少し滑り込む。右のふちに、細い黄色い線
				var right := pic.position.x + w * 0.93 + (1.0 - _out3(t / 0.25)) * 18.0
				var y := h * 0.86
				draw_rect(Rect2(right + 11.0, y - 27.0, 3.0, 32.0), Color(UI.TAPE, fade))
				_line(UI.fnt("bold"), Vector2(right - _width(UI.fnt("bold"), text, 30), y), text, 30, Color(1, 1, 1, fade), 0.7)
			"t_lower":
				_line(_mincho, Vector2(pic.position.x + w * 0.93 - _width(_mincho, text, 46), h * 0.86), text, 46, Color(1, 1, 1, fade), 0.7)
			"t_build":
				_centered(_mincho, text, 64, cx, h * 0.8, Color(1, 1, 1, clampf(t / 0.2, 0.0, 1.0)), 0.7)
			"t_big":
				var s := lerpf(1.3, 1.0, _out3(t / 0.22)) + 0.025 * t
				var px := _fit(_mincho, text, w * 0.62, 190)
				draw_set_transform(Vector2(cx, h * 0.5), 0.0, Vector2(s, s))
				_centered(_mincho, text, px, 0.0, float(px) * 0.36, Color(1, 1, 1, clampf(left / 0.12, 0.0, 1.0)), 0.8)
			"t_note":
				_centered(UI.fnt("body"), text, 26, cx, h * 0.9, Color(1, 1, 1, fade * 0.92), 0.8)
			"t_end":
				var pop := 1.0 - 0.4 * exp(-9.0 * t) * cos(14.0 * t)
				var px := _fit(UI.fnt("display"), text, w * 0.7, 96)
				draw_set_transform(Vector2(cx, h * 0.74), -0.02, Vector2(pop, pop))
				_centered(UI.fnt("display"), text, px, 0.0, float(px) * 0.36, Color(UI.TAPE, clampf(left / 0.2, 0.0, 1.0)), 0.9)
			"t_sub":
				_centered(UI.fnt("bold"), text, 30, cx, h * 0.89, Color(1, 1, 1, fade), 0.8)
			"t_ng":
				var x := pic.position.x + w * 0.6
				_line(UI.fnt("display"), Vector2(x, h * 0.36), "NG", 46, Color(UI.TAPE, fade), 0.0)
				_line(UI.fnt("body"), Vector2(x, h * 0.36 + 44.0), text, 23, Color(1, 1, 1, fade * 0.9), 0.0)
			"k_slam":
				_slam(text, t, left, extra, cx, h, w)
			"k_burn":
				var px := _fit(_dela, text, w * 0.8, 280)
				var s := lerpf(1.5, 1.0, _out3(t / 0.1))
				draw_set_transform(Vector2(cx, h * 0.52), -0.05, Vector2(s, s))
				_centered(_dela, text, px, 0.0, float(px) * 0.36, Color.WHITE, 0.0)
			"k_wall":
				var px := 112
				var step := _width(_dela, text, px) + 90.0
				for row in 3:
					var dir := 1.0 if (row + extra) % 2 == 0 else -1.0
					var shift := fposmod(dir * (t * 430.0 + float(row) * 137.0), step)
					var y := h * (0.2 + 0.31 * float(row)) + float(px) * 0.36
					var x := pic.position.x - step + shift
					while x < pic.position.x + w:
						draw_string(_dela, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
						x += step
			"k_mask":
				var px := _fit(_dela, text, w * 0.92, 430)
				var s := 1.0 + 0.05 * t
				draw_set_transform(Vector2(cx, h * 0.5), 0.0, Vector2(s, s))
				_centered(_dela, text, px, 0.0, float(px) * 0.36, Color.WHITE, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 1 字ずつ飛んでくる。extra：0 黄 ／ 1 白で、最後に吹き飛ぶ ／ 2 締めの名前（黄・少し小さく）
func _slam(text: String, t: float, left: float, extra: int, cx: float, h: float, w: float) -> void:
	var px := _fit(_dela, text, w * (0.7 if extra == 2 else 0.86), 250)
	var total := _width(_dela, text, px)
	var x := cx - total * 0.5
	var color: Color = Color.WHITE if extra == 1 else UI.TAPE
	for i in text.length():
		var ch := text[i]
		var cw := _width(_dela, ch, px)
		var p := clampf((t - 0.055 * float(i)) / 0.12, 0.0, 1.0)
		if p > 0.0:
			var e := _out3(p)
			var s := lerpf(2.7, 1.0, e)
			var rot := lerpf((_rand(text, i, 1) - 0.5) * 1.2, (_rand(text, i, 2) - 0.5) * 0.1, e)
			var pos := Vector2(x + cw * 0.5, h * 0.52 + (_rand(text, i, 3) - 0.5) * 22.0)
			var alpha := p
			if extra == 1 and left < 0.22:
				var q := 1.0 - left / 0.22
				pos += Vector2.from_angle(TAU * _rand(text, i, 4)) * q * q * 620.0
				rot += q * 2.2 * (1.0 if _rand(text, i, 5) > 0.5 else -1.0)
				alpha = 1.0 - q
			draw_set_transform(pos, rot, Vector2(s, s))
			_line(_dela, Vector2(-cw * 0.5, float(px) * 0.36), ch, px, Color(color, alpha), 0.9)
		x += cw
