extends RefCounted
## 打ち合わせの絵コンテ。「どんな画を撮るか」だけを鉛筆の線で見せる。
## 何を使うかは制作班が決める（見立て）ので、城・怪獣・街・爆発は「？」の影で描き、完成写真は見せない。
##   Storyboard.texture("kaiju", 0) → 1枚目の絵（キャッシュする）
## 絵は SVG を組み立てて描く（画像ファイルは持たない）。直すときは下の _castle / _kaiju の座標を変える。
const W := 480
const H := 270
const PAPER := "#f6f2e6"
const PENCIL := "#2f2f35"
const SOFT := "#8d897e"
const SHADE := "#dcd6c6"
const RED := "#c8503c"
const LIGHT := "#f3e6a8"

static var _cache := {}


static func texture(story: String, index: int) -> Texture2D:
	var key := "%s_%d" % [story, index]
	if not _cache.has(key):
		var img := Image.new()
		var err := img.load_svg_from_string(svg(story, index), 2.0)
		_cache[key] = ImageTexture.create_from_image(img) if err == OK else null
	return _cache[key]


static func svg(story: String, index: int) -> String:
	var body := ""
	if story == "kaiju5":
		# 5場面の完全版（production_flow.gd の JOBS の board）
		body = [_kaiju5_1(), _kaiju_1(), _kaiju5_3(), _kaiju5_4(), _kaiju5_5()][clampi(index, 0, 4)]
	elif story == "travel":
		# 旅する二人（場所が変わる4カット）：城の門 → 月夜の丘 → 爆発 → 寄りで決め
		body = [_castle_1(), _travel_2(), _castle_2(), _castle_3()][clampi(index, 0, 3)]
	elif story == "trap":
		# 転がる大岩・予告編：動くカメラ → 上から落ちる罠 → 大岩に追われる → 寄りで決め
		body = [_trap_1(), _trap_2(), _trap_3(), _castle_3()][clampi(index, 0, 3)]
	elif story == "kaiju":
		body = [_kaiju_1(), _kaiju_2(), _kaiju_3()][clampi(index, 0, 2)]
	else:
		body = [_castle_1(), _castle_2(), _castle_3()][clampi(index, 0, 2)]
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><rect width="%d" height="%d" fill="%s"/>%s<rect x="3" y="3" width="%d" height="%d" fill="none" stroke="%s" stroke-width="3"/></svg>' % [W, H, W, H, W, H, PAPER, body, W - 6, H - 6, PENCIL]


# ---- 部品 ----

static func _line(points: Array, color: String = PENCIL, width: float = 3.5, dash: String = "") -> String:
	var pts: Array = []
	for p: Vector2 in points:
		pts.append("%.1f,%.1f" % [p.x, p.y])
	return '<polyline points="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"%s/>' % [" ".join(pts), color, width, (' stroke-dasharray="%s"' % dash) if dash != "" else ""]


# 「まだ決まっていない物」の影：薄い塗りと点線のふち
static func _ghost(path: String) -> String:
	return '<path d="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round" stroke-dasharray="9 7"/>' % [path, SHADE, SOFT]


static func _question(at: Vector2, s: float, color: String = PENCIL) -> String:
	return '<g transform="translate(%.1f %.1f) scale(%.2f)"><path d="M -11,-14 C -11,-32 13,-32 13,-15 C 13,-4 1,-5 1,8" fill="none" stroke="%s" stroke-width="6" stroke-linecap="round"/><circle cx="1" cy="21" r="4.2" fill="%s"/></g>' % [at.x, at.y, s, color, color]


static func _ground(y: float) -> String:
	return _line([Vector2(10, y), Vector2(W - 10, y)], SOFT, 2.0)


static func _arrow(from: Vector2, to: Vector2, both: bool = false) -> String:
	var out := _line([from, to], RED, 3.0)
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	out += _line([to - d * 11 + n * 7, to, to - d * 11 - n * 7], RED, 3.0)
	if both:
		out += _line([from + d * 11 + n * 7, from, from + d * 11 - n * 7], RED, 3.0)
	return out


# 棒人間。at＝足もと、s＝大きさ、pose＝立ち方、flip＝左右を反転
static func _fig(at: Vector2, s: float, pose: String, flip: bool = false, lean: float = 0.0) -> String:
	var arms: Array = [[Vector2(0, -58), Vector2(-9, -46), Vector2(-13, -34)], [Vector2(0, -58), Vector2(9, -46), Vector2(13, -34)]]
	var legs: Array = [[Vector2(0, -28), Vector2(-7, -13), Vector2(-11, 0)], [Vector2(0, -28), Vector2(7, -13), Vector2(11, 0)]]
	match pose:
		"scared":
			arms = [[Vector2(0, -58), Vector2(-18, -60), Vector2(-15, -80)], [Vector2(0, -58), Vector2(18, -60), Vector2(15, -80)]]
		"cheer":
			arms = [[Vector2(0, -58), Vector2(-13, -72), Vector2(-24, -93)], [Vector2(0, -58), Vector2(13, -72), Vector2(24, -93)]]
		"reach_up":
			arms = [[Vector2(0, -58), Vector2(-14, -70), Vector2(-27, -89)], [Vector2(0, -58), Vector2(-9, -50), Vector2(-19, -45)]]
		"reach_down":
			arms = [[Vector2(0, -58), Vector2(-9, -46), Vector2(-12, -34)], [Vector2(0, -58), Vector2(16, -49), Vector2(31, -38)]]
		"reach":
			arms = [[Vector2(0, -58), Vector2(-8, -46), Vector2(-10, -34)], [Vector2(0, -58), Vector2(15, -54), Vector2(29, -56)]]
		"run":
			arms = [[Vector2(0, -58), Vector2(-17, -52), Vector2(-24, -64)], [Vector2(0, -58), Vector2(12, -46), Vector2(24, -50)]]
			legs = [[Vector2(0, -28), Vector2(-17, -18), Vector2(-27, -2)], [Vector2(0, -28), Vector2(13, -15), Vector2(27, -10)]]
		"walk":
			arms = [[Vector2(0, -58), Vector2(-10, -47), Vector2(-17, -37)], [Vector2(0, -58), Vector2(9, -47), Vector2(16, -38)]]
			legs = [[Vector2(0, -28), Vector2(-9, -14), Vector2(-16, 0)], [Vector2(0, -28), Vector2(9, -14), Vector2(15, -1)]]
	var parts := '<ellipse cx="0" cy="1" rx="19" ry="4.5" fill="%s"/>' % SHADE
	var body := '<circle cx="0" cy="-78" r="11" fill="%s" stroke="%s" stroke-width="4"/>' % [PAPER, PENCIL]
	body += _line([Vector2(0, -67), Vector2(0, -28)], PENCIL, 4.5)
	for limb: Array in arms + legs:
		body += _line(limb, PENCIL, 4.5)
	return '<g transform="translate(%.1f %.1f) scale(%.2f %.2f)">%s<g transform="rotate(%.1f)">%s</g></g>' % [at.x, at.y, -s if flip else s, s, parts, lean, body]


# びっくりの線（頭の上の3本）
static func _startle(at: Vector2, s: float = 1.0) -> String:
	return _line([at + Vector2(-9, 0) * s, at + Vector2(-14, -11) * s], RED, 2.5) + _line([at, at + Vector2(0, -14) * s], RED, 2.5) + _line([at + Vector2(9, 0) * s, at + Vector2(14, -11) * s], RED, 2.5)


# ギザギザの爆発の形
static func _burst_path(c: Vector2, outer: float, inner: float, spikes: int = 11) -> String:
	var d := ""
	for i in spikes * 2:
		var r := outer * (0.86 + 0.14 * sin(i * 2.3)) if i % 2 == 0 else inner
		var a := float(i) / (spikes * 2) * TAU - PI * 0.5
		d += ("M" if i == 0 else "L") + " %.1f,%.1f " % [c.x + cos(a) * r, c.y + sin(a) * r * 0.86]
	return d + "Z"


# ---- 怪獣映画 ----

static func _kaiju_1() -> String:
	var out := _ground(222)
	# 奥：街（まだ決まっていない物）
	for box: Array in [[292, 150, 40, 72], [338, 126, 36, 96], [380, 160, 48, 62], [433, 142, 30, 80]]:
		out += _ghost("M %d,%d h %d v %d h -%d Z" % [box[0], box[1], box[2], box[3], box[2]])
	out += _question(Vector2(356, 172), 0.75, SOFT)
	# 見上げる二人
	out += _fig(Vector2(268, 232), 0.52, "scared", true)
	out += _fig(Vector2(300, 236), 0.52, "scared", true)
	out += _startle(Vector2(268, 178), 0.8) + _startle(Vector2(300, 182), 0.8)
	# 手前：怪獣（まだ決まっていない物）。画面からはみ出すくらい大きく
	out += _ghost("M 22,270 C 10,150 40,52 120,40 C 205,30 240,104 232,176 C 228,214 238,246 244,270 Z")
	out += _question(Vector2(128, 150), 2.3)
	# 怪獣のほうが大きい
	out += _arrow(Vector2(254, 258), Vector2(254, 48), true)
	out += _arrow(Vector2(470, 220), Vector2(470, 128), true)
	return out


static func _kaiju_2() -> String:
	var out := _ground(238)
	out += _ghost(_burst_path(Vector2(318, 112), 104, 56))
	out += _question(Vector2(318, 112), 1.7)
	for y: int in [212, 224]:
		out += _line([Vector2(252, y), Vector2(292, y)], SOFT, 2.0)
	out += _fig(Vector2(130, 240), 0.98, "run", false, -13.0)
	out += _fig(Vector2(214, 244), 0.92, "run", false, -13.0)
	out += _arrow(Vector2(96, 262), Vector2(34, 262))
	return out


static func _kaiju_3() -> String:
	var out := _ground(228)
	# 倒れた怪獣
	out += _ghost("M 30,228 C 26,170 90,138 170,146 C 236,152 280,186 276,228 Z")
	out += _question(Vector2(140, 196), 1.3)
	for eye: Vector2 in [Vector2(214, 186), Vector2(242, 196)]:
		out += _line([eye + Vector2(-6, -6), eye + Vector2(6, 6)], PENCIL, 3.0) + _line([eye + Vector2(-6, 6), eye + Vector2(6, -6)], PENCIL, 3.0)
	out += _fig(Vector2(338, 236), 0.95, "cheer")
	out += _fig(Vector2(408, 238), 0.95, "cheer")
	out += _startle(Vector2(338, 128)) + _startle(Vector2(408, 130))
	return out


# ---- 怪獣映画・完全版（5場面）。2場面目は、上の _kaiju_1 と同じ絵 ----

# 「これは映さない」の印：赤い丸に、斜めの線
static func _ban(c: Vector2, r: float) -> String:
	var k := r * 0.7071
	return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="6"/>' % [c.x, c.y, r, RED] + _line([c + Vector2(-k, -k), c + Vector2(k, k)], RED, 6.0)


# 「これは、そのまま」の印：赤い丸
static func _keep(c: Vector2, r: float) -> String:
	return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="5"/>' % [c.x, c.y, r, RED]


# 傾いた箱（倒れていく街）
static func _tipped_box(c: Vector2, w: float, h: float, degrees: float) -> String:
	return '<g transform="rotate(%.1f %.1f %.1f)">%s</g>' % [degrees, c.x, c.y, _ghost("M %.1f,%.1f h %.1f v %.1f h -%.1f Z" % [c.x - w * 0.5, c.y - h * 0.5, w, h, w])]


# 曲がった矢印（倒れる向き）
static func _swing(from: Vector2, via: Vector2, to: Vector2) -> String:
	var out := '<path d="M %.1f,%.1f Q %.1f,%.1f %.1f,%.1f" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % [from.x, from.y, via.x, via.y, to.x, to.y, RED]
	var d := (to - via).normalized()
	var n := Vector2(-d.y, d.x)
	return out + _line([to - d * 11 + n * 7, to, to - d * 11 - n * 7], RED, 3.0)


# 倒れた怪獣の、ばってんの目
static func _dead_eyes(eyes: Array) -> String:
	var out := ""
	for eye: Vector2 in eyes:
		out += _line([eye + Vector2(-6, -6), eye + Vector2(6, 6)], PENCIL, 3.0) + _line([eye + Vector2(-6, 6), eye + Vector2(6, -6)], PENCIL, 3.0)
	return out


# 1：街を歩いてくる。怪獣は、まだ映さない
static func _kaiju5_1() -> String:
	var out := _ground(232)
	for box: Array in [[292, 138, 44, 94], [344, 112, 40, 120], [392, 150, 54, 82]]:
		out += _ghost("M %d,%d h %d v %d h -%d Z" % [box[0], box[1], box[2], box[3], box[2]])
	out += _question(Vector2(364, 170), 0.8, SOFT)
	# まだ出番でない怪獣：映してはいけない
	out += _ghost("M -6,270 C -16,172 6,96 52,90 C 100,88 116,146 110,200 C 108,230 116,252 120,270 Z")
	out += _question(Vector2(54, 178), 1.2, SOFT)
	out += _ban(Vector2(56, 176), 52)
	# 歩いてくる二人
	out += _fig(Vector2(182, 242), 0.86, "walk")
	out += _fig(Vector2(240, 246), 0.86, "walk")
	out += _arrow(Vector2(156, 262), Vector2(268, 262))
	return out


# 3：怪獣の技。逃げる二人の背後で爆発。街は倒れ、怪獣は立ったまま
static func _kaiju5_3() -> String:
	var out := _ground(238)
	out += _ghost(_burst_path(Vector2(292, 104), 92, 50))
	out += _question(Vector2(292, 104), 1.5)
	# 倒れていく街
	out += _tipped_box(Vector2(240, 194), 40, 84, -30.0)
	out += _tipped_box(Vector2(340, 196), 44, 78, 34.0)
	out += _swing(Vector2(226, 142), Vector2(198, 150), Vector2(190, 188))
	out += _swing(Vector2(354, 144), Vector2(382, 152), Vector2(390, 190))
	# 立ったままの怪獣
	out += _ghost("M 420,238 C 412,190 424,152 446,150 C 470,152 480,192 474,238 Z")
	out += _question(Vector2(447, 200), 0.7, SOFT)
	out += _keep(Vector2(447, 124), 17)
	# 逃げる二人
	out += _fig(Vector2(88, 240), 0.92, "run", false, -13.0)
	out += _fig(Vector2(150, 244), 0.88, "run", false, -13.0)
	out += _arrow(Vector2(70, 262), Vector2(20, 262))
	return out


# 4：怪獣が、ひとりでに倒れる。倒す人は映さない
static func _kaiju5_4() -> String:
	var out := _ground(232)
	# 立っていた怪獣（点線）から、倒れた怪獣へ
	out += '<path d="M 156,232 C 146,150 166,86 210,82 C 258,82 272,150 264,232 Z" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="9 7"/>' % SOFT
	out += _ghost("M 240,232 C 236,186 290,160 360,166 C 418,172 456,198 454,232 Z")
	out += _question(Vector2(338, 204), 1.1)
	out += _dead_eyes([Vector2(402, 196), Vector2(428, 206)])
	out += _swing(Vector2(244, 80), Vector2(336, 78), Vector2(378, 148))
	# 倒す人：映ってはいけない
	out += _fig(Vector2(92, 238), 0.8, "reach")
	out += _ban(Vector2(92, 190), 46)
	return out


# 5：勝利。倒れた怪獣の前の二人を、寄りで
static func _kaiju5_5() -> String:
	var out := _ground(212)
	out += _ghost("M 34,212 C 38,166 116,146 212,150 C 324,154 440,176 444,212 Z")
	out += _dead_eyes([Vector2(388, 180), Vector2(416, 190)])
	# 手前に、大きく映る二人（ひざから下は、画面の外）
	out += _fig(Vector2(176, 290), 1.72, "cheer")
	out += _fig(Vector2(306, 290), 1.72, "cheer")
	# 寄りの印：四隅の枠と、内へ向かう矢印
	for corner: Vector2 in [Vector2(22, 22), Vector2(458, 22), Vector2(22, 248), Vector2(458, 248)]:
		var sx := 1.0 if corner.x < W * 0.5 else -1.0
		var sy := 1.0 if corner.y < H * 0.5 else -1.0
		out += _line([corner + Vector2(36 * sx, 0), corner, corner + Vector2(0, 36 * sy)], RED, 4.0)
		out += _arrow(corner + Vector2(14 * sx, 14 * sy), corner + Vector2(44 * sx, 38 * sy))
	return out


# ---- 城の告白 ----

static func _castle_wall(x: float, top: float, bottom: float) -> String:
	# 胸壁のある壁の影
	var d := "M %.0f,%.0f L %.0f,%.0f " % [x, bottom, x, top]
	var step := 26.0
	for i in 5:
		var x0 := x + step * i
		d += "L %.0f,%.0f L %.0f,%.0f " % [x0 + step * 0.5, top, x0 + step * 0.5, top + 16]
		if i < 4:
			d += "L %.0f,%.0f L %.0f,%.0f " % [x0 + step, top + 16, x0 + step, top]
	return d + "L %.0f,%.0f L %.0f,%.0f Z" % [x + step * 4.5, top, x + step * 4.5, bottom]


# 月夜の丘：丘の上の二人が、大きな月（？）を見上げる。前の場所の城は映さない（赤い斜線）
static func _travel_2() -> String:
	var out := _line([Vector2(6, 238), Vector2(150, 206), Vector2(300, 196), Vector2(474, 222)], PENCIL, 3.5)
	out += '<circle cx="330" cy="82" r="52" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="9 7"/>' % PENCIL
	out += _question(Vector2(330, 108), 1.6)
	out += _fig(Vector2(170, 204), 0.82, "reach_up")
	out += _fig(Vector2(214, 202), 0.82, "reach_up", true)
	# 前の場面の城（映さない）
	out += _ghost(_castle_wall(28, 120, 200))
	out += _ban(Vector2(66, 160), 34)
	return out


# 遺跡に踏み込む二人と、二人と一緒に進むカメラ（何に載せるか・どう動かすかは描かない）
static func _trap_1() -> String:
	var out := _ground(238)
	out += _ghost("M 340,238 L 340,96 Q 405,40 470,96 L 470,238 Z")
	out += _question(Vector2(405, 160), 1.5)
	out += _fig(Vector2(236, 242), 0.9, "walk")
	out += _fig(Vector2(290, 244), 0.9, "walk")
	# カメラ（三脚）と、進む向き
	out += _line([Vector2(92, 238), Vector2(100, 176), Vector2(108, 238)], PENCIL, 3.0)
	out += _line([Vector2(100, 238), Vector2(100, 176)], PENCIL, 3.0)
	out += '<rect x="78" y="146" width="46" height="30" rx="4" fill="%s" stroke="%s" stroke-width="3.5"/>' % [PAPER, PENCIL]
	out += '<rect x="124" y="152" width="16" height="18" fill="%s" stroke="%s" stroke-width="3"/>' % [PAPER, PENCIL]
	out += _arrow(Vector2(70, 118), Vector2(176, 118))
	out += _arrow(Vector2(222, 132), Vector2(318, 132))
	return out


# 足元でカチリ。立ち止まった二人のそばに、頭の上から何かが落ちてくる
static func _trap_2() -> String:
	var out := _ground(238)
	out += _fig(Vector2(190, 242), 0.92, "scared")
	out += _fig(Vector2(340, 242), 0.92, "scared", true)
	out += _startle(Vector2(190, 140)) + _startle(Vector2(340, 140))
	out += _line([Vector2(265, 8), Vector2(265, 28)], SOFT, 2.5, "6 5") + _line([Vector2(265, 38), Vector2(265, 54)], SOFT, 2.5, "6 5")
	out += _ghost("M 236,56 L 294,56 L 294,104 L 236,104 Z")
	out += _question(Vector2(265, 84), 0.95)
	out += _arrow(Vector2(265, 114), Vector2(265, 182))
	return out


# 逃げる二人の後ろから、大きな丸い何かが転がって迫る（何を転がすか・どう転がすかは描かない）
static func _trap_3() -> String:
	var out := _ground(238)
	out += _ghost("M 70,160 a 78,78 0 1,0 156,0 a 78,78 0 1,0 -156,0 Z")
	out += _question(Vector2(148, 162), 1.8)
	for k in 3:
		out += _line([Vector2(40 - k * 6, 128 + k * 34), Vector2(14 - k * 6, 128 + k * 34)], SOFT, 3.0)
	out += _arrow(Vector2(236, 118), Vector2(312, 118))
	out += _fig(Vector2(330, 242), 0.95, "run", false, -12.0)
	out += _fig(Vector2(408, 244), 0.92, "run", false, -12.0)
	out += _startle(Vector2(330, 140)) + _startle(Vector2(408, 142))
	return out


static func _castle_1() -> String:
	var out := '<path d="M 478,6 L 300,96 L 392,250 L 478,250 Z" fill="%s" opacity="0.55"/>' % LIGHT
	out += _ground(238)
	out += _ghost(_castle_wall(34, 78, 238))
	out += _question(Vector2(92, 164), 1.9)
	# 月（無くても撮れる）
	out += '<circle cx="230" cy="52" r="24" fill="none" stroke="%s" stroke-width="2.5" stroke-dasharray="7 6"/>' % SOFT
	# 高い所に立つ人と、見上げる人
	out += '<rect x="262" y="170" width="84" height="68" fill="%s" stroke="%s" stroke-width="3.5"/>' % [PAPER, PENCIL]
	out += _line([Vector2(262, 170), Vector2(346, 238)], SOFT, 1.5) + _line([Vector2(346, 170), Vector2(262, 238)], SOFT, 1.5)
	out += _fig(Vector2(304, 170), 0.82, "reach_down")
	out += _fig(Vector2(406, 240), 0.82, "reach_up")
	out += _arrow(Vector2(446, 236), Vector2(446, 106), true)
	return out


static func _castle_2() -> String:
	var out := _ground(238)
	out += _ghost(_castle_wall(20, 96, 238))
	out += _ghost(_burst_path(Vector2(300, 106), 108, 58))
	out += _question(Vector2(300, 106), 1.7)
	out += _fig(Vector2(238, 242), 0.95, "reach")
	out += _fig(Vector2(342, 242), 0.95, "reach", true)
	out += _startle(Vector2(238, 136)) + _startle(Vector2(342, 136))
	return out


static func _castle_3() -> String:
	var out := _ground(238)
	out += _ghost(_castle_wall(20, 96, 238))
	# 晴れていく煙
	for puff: Array in [[330, 96, 34], [372, 80, 26], [300, 66, 22], [402, 110, 20]]:
		out += '<circle cx="%d" cy="%d" r="%d" fill="none" stroke="%s" stroke-width="2.5" stroke-dasharray="6 6"/>' % [puff[0], puff[1], puff[2], SOFT]
	out += _fig(Vector2(262, 242), 0.98, "reach")
	out += _fig(Vector2(318, 242), 0.98, "reach", true)
	# 近づいた二人
	out += '<path d="M 290,116 c -9,-13 -27,-2 -15,12 l 15,14 l 15,-14 c 12,-14 -6,-25 -15,-12 Z" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % RED
	out += _arrow(Vector2(196, 262), Vector2(236, 262)) + _arrow(Vector2(384, 262), Vector2(344, 262))
	return out
