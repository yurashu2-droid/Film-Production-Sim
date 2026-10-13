extends Control
## 確認用モニターの枠の印を、画面の上のモニター（右上のカメラ映像・モニター係の画面）にも同じ形で出す。
##   ランプ：場面の数だけ並ぶ。撮れた場面が点く
##   目盛り：フィルムの残り。使った分だけ、右から消えていく
## 数字は出さない。場面の列を持つ依頼（production_beats.gd）のときだけ使う。
## 置き物のモニター（production_monitor_prop.gd）も、同じ数・同じ色で作る。
const TICKS := 18                       # 目盛りの数（フィルム1本を等分する）
const LOW_TICKS := 3                    # 残りがこの数以下になると、目盛りが赤くなる
const LAMP_OFF := Color("59616b")
const LAMP_ON := Color("5fe0a8")
const TICK_ON := Color("e9e2cf")
const TICK_LOW := Color("ef5146")
const TICK_OFF := Color("3d434b")

var lamps: Array = []
var film := 1.0


# 目盛りのうち、まだ残っている数
static func ticks_left(frac: float) -> int:
	return clampi(ceili(clampf(frac, 0.0, 1.0) * TICKS - 0.0001), 0, TICKS)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 12)


func set_marks(new_lamps: Array, frac: float) -> void:
	if new_lamps == lamps and ticks_left(frac) == ticks_left(film):
		return
	lamps = new_lamps.duplicate()
	film = frac
	queue_redraw()


func _draw() -> void:
	if lamps.is_empty():
		return
	var h := size.y
	var r := h * 0.42
	# 左：ランプ
	var x := r + 1.0
	for on: Variant in lamps:
		draw_circle(Vector2(x, h * 0.5), r, LAMP_ON if bool(on) else LAMP_OFF)
		x += r * 2.0 + 5.0
	# 右：フィルムの目盛り
	var left := ticks_left(film)
	var from := x + 8.0
	var room := maxf(size.x - from, 10.0)
	var step := room / TICKS
	var w := maxf(step - 2.0, 1.0)
	for i in TICKS:
		var color := TICK_OFF
		if i < left:
			color = TICK_LOW if left <= LOW_TICKS else TICK_ON
		draw_rect(Rect2(from + step * i, h * 0.22, w, h * 0.56), color)
