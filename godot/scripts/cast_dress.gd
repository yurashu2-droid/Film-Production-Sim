extends Node3D
## 見立ての飾り：役を付けた物に、その役らしい紙や布の飾りを付ける（安い映画の手：便器に目玉を貼れば怪獣、丸い物に顔を描けば月）。
## 文字の札の代わり。映画にも映る（制作班だけの層にしない）。形にしにくい役（階段）は、手書きの立て札にする。
## 役との相性が悪い物（らしさ ★1）は、飾りが少し曲がって付く（数字は出さない。上映会で分かる）。
## 飾りの場所は、物の当たり判定の表面を光線で探す（外形の箱の面に貼ると、宙に浮くので）。
## 顔（目・顔・ライトなど、正面に付く物）は、役を付けた人が見ていた側に付ける（face：0 = 物の +z、1 = +x、2 = -z、3 = -x）。
## fit = true（標準）：貼る場所を、狙った所のまわりを細かく光線で調べて、いちばん手前の面から選ぶ（格子のすき間・くぼみを避ける）。
## 顔・窓・ひび・つた・きらきらのような平たい飾りは、デカール（物に投影して描く）にして、曲面に沿わせる。飛び出す飾り（角・旗・炎）は立体のまま。
## 物の子として付く（物と一緒に動き、箱に入れて隠れれば一緒に隠れる）。production_main.gd の _sync_cast_dress が付け外しする。

var role := ""
var grade := 2
var face := 0
var fit := true                  # 改良版（標準。場所を細かく選ぶ・平たい飾りはデカール）。false は前の方式（くらべる用。tests/cast_dress_compare.gd）
var prop: Node3D
var font: Font
var u := 0.1                     # 飾りの大きさの単位（m）。物の大きさから決める
var f := 0.1                     # 顔の部品の大きさの単位（m）。正面の面の大きさから決める
var _c := Vector3.ZERO           # 飾りから見た物の中心（顔の側を +z にした向き）
var _h := Vector3.ONE            # 飾りから見た物の外形の半分
var _rng := RandomNumberGenerator.new()
var _mats := {}

const PAPER := Color(0.78, 0.62, 0.42)     # 段ボール
const INK := Color(0.12, 0.1, 0.1)


func build(p: Node3D, r: String, g: int, fnt: Font, seed_id: int, side := 0, fit_style := true) -> void:
	fit = fit_style
	prop = p
	role = r
	grade = g
	font = fnt
	face = posmod(side, 4)
	_rng.seed = seed_id * 7919 + r.hash()
	# 物の中心を軸に、顔の側が +z に来るよう回した向きで、飾りを組む
	var turn := Basis(Vector3.UP, float(face) * PI * 0.5)
	_c = p.center
	transform = Transform3D(turn, _c - turn * _c)
	var h: Vector3 = p.half
	_h = Vector3(h.z, h.y, h.x) if face % 2 == 1 else h
	u = clampf(maxf(_h.x, _h.z) * 0.5, 0.08, 0.5)
	# 顔の大きさ：平たい物（パイなど）は、顔をてっぺんに描くので、上の面の大きさから
	f = clampf((minf(_h.x, _h.z) if _flat() else minf(_h.x, _h.y)) * 0.7, 0.07, 0.45)
	match role:
		"monster": _monster()
		"moon": _moon()
		"castle": _castle()
		"city": _city()
		"boom": _boom()
		"ruins": _ruins()
		"relic": _relic()
		"bigrock": _bigrock()
		"door": _door()
		"xmas": _xmas()
		"bike": _bike()
		"woods": _woods()
		"ship": _ship()
		"sea": _sea()
		"roof": _roof()
		"agent": _agent()
		"steps": _sign("階段", _top(0, 0))
		"summit": _summit()
		"noodle": _noodle()
		"kettle": _kettle()
		"car": _car()
		"street": _street()
		"pit": _pit()
		# 17〜28 の依頼の役（2026-10-27）：隕石は大岩と同じ飾り。ほかは手書きの立て札
		"meteor": _bigrock()
		"manor": _door()
		"ghost": _sign("おばけ", _top(0, 0))
		"cake": _sign("ケーキ", _top(0, 0))
		"saloon": _sign("酒場", _top(0, 0))
		"tumble": _sign("回転草", _top(0, 0))
		"dish": _sign("料理", _top(0, 0))
		"stove": _sign("コンロ", _top(0, 0))
		"katsudon": _sign("カツ丼", _top(0, 0))
		"rocket": _sign("宇宙船", _top(0, 0))
		_: _sign(r, _top(0, 0))


# ---- 役ごとの飾り ----

# 怪獣：ぎょろ目と角と牙
func _monster() -> void:
	for s: float in [-1.0, 1.0]:
		_put(_eye(f * 0.55), _face(0.35 * s, 0.55))
		var horn := Node3D.new()
		var tilt := Node3D.new()
		tilt.rotation.y = s * 0.35
		horn.add_child(tilt)
		tilt.add_child(_along(_cone(u * 0.22, u * 0.9, 6), Color(0.93, 0.88, 0.74)))
		_put(horn, _top(0.45 * s, 0.3))
	for fx: float in [-0.22, 0.0, 0.22]:
		var tooth := Node3D.new()
		tooth.add_child(_mesh(_prism(Vector3(f * 0.22, f * 0.3, f * 0.06)), Color(0.97, 0.97, 0.94), Vector3(0, 0, f * 0.03), Vector3(0, 0, PI)))
		_put(tooth, _face(fx, 0.1))


# 月：にっこり顔と、ほっぺ
func _moon() -> void:
	if fit:
		_decal(_tex("moon_face"), Vector2(f * 1.7, f * 1.7), _face(0, 0.1))
		return
	for s: float in [-1.0, 1.0]:
		_put(_dot(f * 0.13, INK), _face(0.3 * s, 0.3))
		_put(_dot(f * 0.17, Color(0.98, 0.6, 0.62)), _face(0.5 * s, 0.0))
	for i in 5:
		var t := (float(i) - 2.0) / 2.0
		_put(_dot(f * 0.08, INK), _face(t * 0.3, -0.1 - 0.18 * (1.0 - t * t)))


# 城：てっぺんの縁にぎざぎざの城壁、真ん中に旗
func _castle() -> void:
	for at: Vector2 in [Vector2(-0.8, -0.8), Vector2(0, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0), Vector2(0.8, 0), Vector2(-0.8, 0.8), Vector2(0, 0.8), Vector2(0.8, 0.8)]:
		var block := Node3D.new()
		block.add_child(_mesh(_box(Vector3(u * 0.6, u * 0.6, u * 0.6)), Color(0.66, 0.64, 0.6), Vector3(0, 0, u * 0.25)))
		_put(block, _top(at.x, at.y))
	_put(_flag(u * 2.2, Color(0.85, 0.15, 0.15)), _top(0, 0))


# 街：正面に、明かりのついた窓
func _city() -> void:
	if fit:
		_decal(_tex("windows"), Vector2(_h.x * 1.5, _h.y * 1.5), _front(0, 0), 0.8)
		return
	for fy: float in [0.5, 0.0, -0.5]:
		for fx: float in [-0.5, 0.0, 0.5]:
			_put(_window(Vector2(u * 0.35, u * 0.45)), _front(fx, fy))


# 爆発：上に、紙の炎
func _boom() -> void:
	var spots := [Vector2(0, 0), Vector2(-0.4, 0.2), Vector2(0.4, -0.2), Vector2(0.2, 0.45), Vector2(-0.3, -0.4)]
	var tall := [2.0, 1.4, 1.5, 1.1, 1.2]
	var hues := [Color(0.92, 0.18, 0.1), Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.2), Color(1.0, 0.55, 0.1), Color(0.92, 0.18, 0.1)]
	for i in spots.size():
		var flame := Node3D.new()
		var lean := Node3D.new()
		lean.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25), 0)
		flame.add_child(lean)
		lean.add_child(_along(_cone(u * 0.32, u * float(tall[i]), 4), hues[i], 0.6))
		_put(flame, _top(spots[i].x, spots[i].y))


# 遺跡：つたと、ひび
func _ruins() -> void:
	if fit:
		for i in 3:
			_decal(_tex("ivy"), Vector2(u * 1.9, u * 1.9), _front(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.5, 0.7)))
		for i in 2:
			_decal(_tex("crack"), Vector2(u * 1.0, u * 1.0), _front(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)))
		return
	for i in 7:
		var leaf := _dot(u * _rng.randf_range(0.2, 0.32), Color(0.25, 0.5, 0.2).lerp(Color(0.4, 0.62, 0.25), _rng.randf()))
		_put(leaf, _front(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.6, 0.8)))
	for i in 3:
		_put(_crack(), _front(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)))


# 秘宝：金のきらきら
func _relic() -> void:
	for i in 3:
		_put(_kira(u * 0.6), _front(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.2, 0.7)))
	for i in 2:
		_put(_kira(u * 0.5), _top(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)))
	for i in 3:
		_put(_dot(u * 0.2, Color(0.95, 0.75, 0.2), 0.3), _top(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)))


# 大岩：ごつごつと、ひび
func _bigrock() -> void:
	for i in 5:
		var bump := Node3D.new()
		var lump := _mesh(_sphere(u * 0.35), Color(0.66, 0.62, 0.55))
		lump.scale = Vector3(1.2, 1.0, 0.45)
		bump.add_child(lump)
		_put(bump, _top(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)))
	for i in 3:
		if fit:
			_decal(_tex("crack"), Vector2(u * 1.0, u * 1.0), _front(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)))
		else:
			_put(_crack(), _front(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)))


# 玄関：ドアノブと、小窓と、表札
func _door() -> void:
	var knob := Node3D.new()
	knob.add_child(_along(_cyl(u * 0.06, u * 0.18), Color(0.8, 0.65, 0.25)))
	knob.add_child(_mesh(_sphere(u * 0.18), Color(0.85, 0.7, 0.25), Vector3(0, 0, u * 0.22)))
	_put(knob, _front(0.6, -0.05))
	if fit:
		_decal(_tex("door"), Vector2(_h.x * 1.7, _h.y * 1.8), _front(0, 0))
		return
	var glass := Node3D.new()
	glass.add_child(_mesh(_box(Vector3(u * 0.95, u * 0.65, 0.006)), Color(0.35, 0.25, 0.18), Vector3(0, 0, 0.003)))
	glass.add_child(_mesh(_box(Vector3(u * 0.8, u * 0.5, 0.006)), Color(0.7, 0.85, 0.95), Vector3(0, 0, 0.007)))
	_put(glass, _front(0, 0.6))
	var plate := Node3D.new()
	plate.add_child(_mesh(_box(Vector3(u * 0.7, u * 0.22, 0.008)), Color(0.95, 0.93, 0.86), Vector3(0, 0, 0.004)))
	_put(plate, _front(0, 0.3))


# ツリー：てっぺんの星と、飾りの玉
func _xmas() -> void:
	var star := Node3D.new()
	var stand := _mesh(_star(u * 0.55), Color(1.0, 0.85, 0.2), Vector3(0, 0, u * 0.5), Vector3(PI * 0.5, 0, 0), 1.2)
	star.add_child(stand)
	_put(star, _top(0, 0))
	var hues := [Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.9), Color(0.95, 0.78, 0.2), Color(0.85, 0.85, 0.9)]
	for i in 6:
		_put(_dot(u * 0.2, hues[i % hues.size()], 0.2), _front(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.6, 0.6)))
	for s: float in [-1.0, 1.0]:
		_put(_dot(u * 0.2, hues[(2 + int(s)) % hues.size()], 0.2), _side(s, _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4)))


# 自転車：両脇に車輪、上にハンドル
func _bike() -> void:
	var r := clampf(_h.y * 0.45, u * 0.5, u * 1.4)
	var fy := -1.0 + r / maxf(_h.y, 0.01)
	for s: float in [-1.0, 1.0]:
		for fz: float in [-0.55, 0.55]:
			_put(_wheel(r), _side(s, fy, fz))
	var bar := Node3D.new()
	bar.add_child(_along(_cyl(u * 0.04, u * 0.5), Color(0.75, 0.75, 0.78)))
	bar.add_child(_mesh(_cyl(u * 0.04, u * 1.3), Color(0.15, 0.15, 0.15), Vector3(0, 0, u * 0.5), Vector3(0, 0, PI * 0.5)))
	_put(bar, _top(0, 0.7))


# 森：上に紙の木、正面に葉っぱ
func _woods() -> void:
	for at: Vector2 in [Vector2(-0.5, 0.2), Vector2(0.45, -0.3), Vector2(0.1, 0.55)]:
		var tree := Node3D.new()
		tree.add_child(_along(_cyl(u * 0.07, u * 0.4), Color(0.45, 0.3, 0.18)))
		var low := _along(_cone(u * 0.42, u * 0.75, 7), Color(0.2, 0.5, 0.25))
		low.position.z += u * 0.45
		tree.add_child(low)
		var high := _along(_cone(u * 0.3, u * 0.6, 7), Color(0.28, 0.6, 0.3))
		high.position.z += u * 0.85
		tree.add_child(high)
		_put(tree, _top(at.x, at.y))
	for i in 4:
		_put(_dot(u * 0.25, Color(0.3, 0.55, 0.25)), _front(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.4, 0.6)))


# 船：帆柱と帆と、小さな旗
func _ship() -> void:
	var mast := Node3D.new()
	mast.add_child(_along(_cyl(u * 0.05, u * 3.0), Color(0.55, 0.4, 0.25)))
	# 帆：三角の布を、前後の向き（物の z）に張る
	var sail := _mesh(_prism(Vector3(u * 1.4, u * 2.2, 0.012), 0.0), Color(0.97, 0.95, 0.88))
	sail.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	sail.position = Vector3(0, u * 0.72, u * 1.65)
	mast.add_child(sail)
	mast.add_child(_mesh(_box(Vector3(u * 0.5, 0.01, u * 0.28)), Color(0.85, 0.15, 0.15), Vector3(u * 0.25, 0, u * 2.85)))
	_put(mast, _top(0, 0))


# 海：根元をぐるりと、青い波
func _sea() -> void:
	for i in 12:
		var a := TAU * float(i) / 12.0
		var wave := Node3D.new()
		var blob := _mesh(_sphere(u * 0.42), Color(0.2, 0.45, 0.85) if i % 2 == 0 else Color(0.35, 0.65, 0.95))
		blob.scale = Vector3(1.5, 0.7, 0.5)
		wave.add_child(blob)
		wave.add_child(_mesh(_sphere(u * 0.12), Color(0.96, 0.98, 1.0), Vector3(_rng.randf_range(-0.2, 0.2) * u, u * 0.28, u * 0.12)))
		_put(wave, _around(a, -0.75))


# 屋上：給水タンクとアンテナ
func _roof() -> void:
	var tank := Node3D.new()
	tank.add_child(_along(_cyl(u * 0.4, u * 0.7), Color(0.7, 0.72, 0.74)))
	_put(tank, _top(-0.45, -0.4))
	var aerial := Node3D.new()
	aerial.add_child(_along(_cyl(u * 0.025, u * 1.8), Color(0.6, 0.6, 0.62)))
	for k: float in [1.2, 1.55]:
		aerial.add_child(_mesh(_cyl(u * 0.02, u * 0.8), Color(0.6, 0.6, 0.62), Vector3(0, 0, u * k), Vector3(0, 0, PI * 0.5)))
	_put(aerial, _top(0.5, 0.3))


# 追っ手：サングラスとネクタイ
func _agent() -> void:
	for s: float in [-1.0, 1.0]:
		var lens := Node3D.new()
		var glass := _mesh(_sphere(f * 0.24), Color(0.05, 0.05, 0.07))
		glass.scale = Vector3(1.3, 0.8, 0.3)
		lens.add_child(glass)
		_put(lens, _face(0.25 * s, 0.55))
	var bridge := Node3D.new()
	bridge.add_child(_mesh(_box(Vector3(f * 0.3, f * 0.05, 0.01)), Color(0.05, 0.05, 0.07), Vector3(0, 0, 0.01)))
	_put(bridge, _face(0, 0.58))
	var tie := Node3D.new()
	tie.add_child(_mesh(_box(Vector3(f * 0.14, f * 0.12, 0.012)), Color(0.08, 0.1, 0.2), Vector3(0, 0, 0.008)))
	tie.add_child(_mesh(_prism(Vector3(f * 0.25, f * 0.7, 0.01)), Color(0.08, 0.1, 0.2), Vector3(0, -f * 0.4, 0.008), Vector3(0, 0, PI)))
	_put(tie, _face(0, 0.1))


# 頂上：雪をかぶせて、旗を立てる
func _summit() -> void:
	var snow := Node3D.new()
	var cap := _mesh(_sphere(maxf(_h.x, _h.z) * 0.5), Color(0.92, 0.95, 1.0))
	cap.scale = Vector3(1, 1, 0.35)
	snow.add_child(cap)
	_put(snow, _top(0, 0))
	var hit := _top(0.15, 0.1)
	hit[0] = (hit[0] as Vector3) + (hit[1] as Vector3) * maxf(_h.x, _h.z) * 0.15
	_put(_flag(u * 1.8, Color(0.9, 0.2, 0.2)), hit)


# カップ麺：割りばしと、赤い帯
func _noodle() -> void:
	for k: float in [-1.0, 1.0]:
		var chop := Node3D.new()
		var lean := Node3D.new()
		lean.rotation = Vector3(0.25, 0.2 * k, 0)
		chop.add_child(lean)
		lean.add_child(_along(_cyl(u * 0.025, u * 1.6), Color(0.88, 0.75, 0.52)))
		_put(chop, _top(0.15 + 0.06 * k, 0))
	var band := Node3D.new()
	band.add_child(_mesh(_box(Vector3(u * 1.1, u * 0.38, 0.01)), Color(0.85, 0.12, 0.12), Vector3(0, 0, 0.005)))
	band.add_child(_label("めん", u * 0.7, Color(1, 1, 0.95), Vector3(0, 0, 0.012)))
	_put(band, _front(0, 0.3))


# やかん：横に注ぎ口、上に取っ手
func _kettle() -> void:
	var spout := Node3D.new()
	var up := Node3D.new()
	up.rotation.x = -0.6
	spout.add_child(up)
	up.add_child(_along(_cone(u * 0.16, u * 0.9, 8, u * 0.07), Color(0.75, 0.76, 0.78)))
	_put(spout, _side(1.0, 0.0, 0.0))
	var grip := Node3D.new()
	var ring := _mesh(_torus(u * 0.36, u * 0.46), Color(0.1, 0.1, 0.1), Vector3.ZERO, Vector3(0, 0, PI * 0.5))
	grip.add_child(ring)
	_put(grip, _top(0, 0))


# 車：ライトの目、ナンバー、四つの車輪
func _car() -> void:
	for s: float in [-1.0, 1.0]:
		var lamp := Node3D.new()
		var bulb := _mesh(_sphere(f * 0.2), Color(1.0, 0.92, 0.55), Vector3.ZERO, Vector3.ZERO, 1.5)
		bulb.scale = Vector3(1, 1, 0.45)
		lamp.add_child(bulb)
		_put(lamp, _front(0.55 * s, 0.05))
	var plate := Node3D.new()
	plate.add_child(_mesh(_box(Vector3(u * 0.6, u * 0.25, 0.01)), Color(0.96, 0.96, 0.92), Vector3(0, 0, 0.005)))
	_put(plate, _front(0, -0.5))
	var r := clampf(_h.y * 0.4, u * 0.4, u * 1.2)
	var fy := -1.0 + r / maxf(_h.y, 0.01)
	for s: float in [-1.0, 1.0]:
		for fz: float in [-0.6, 0.6]:
			_put(_wheel(r), _side(s, fy, fz))


# 街並み：しま模様のひさしと、明かりのついた窓
func _street() -> void:
	var awning := Node3D.new()
	var slope := Node3D.new()
	slope.rotation.x = -0.6
	awning.add_child(slope)
	for i in 5:
		slope.add_child(_mesh(_box(Vector3(u * 0.3, u * 0.5, 0.01)), Color(0.85, 0.15, 0.15) if i % 2 == 0 else Color(0.97, 0.95, 0.9), Vector3((float(i) - 2.0) * u * 0.3, -u * 0.25, 0.01)))
	_put(awning, _front(0, 0.75))
	for s: float in [-1.0, 1.0]:
		if fit:
			_decal(_tex("window1"), Vector2(u * 0.6, u * 0.7), _front(0.4 * s, -0.15), 0.8)
		else:
			_put(_window(Vector2(u * 0.4, u * 0.5)), _front(0.4 * s, -0.15))


# 穴：上の面に、黒い穴を描く（入れ物なら底が真っ暗になって深く見える。平たい板なら、絵に描いた穴）
func _pit() -> void:
	# 物の向きでなく、世界の上向きで「上の面」を探す（段ボール板を寝かせて床に置いても、上の面に穴を描く）
	var up := _up_here()
	_up0 = up
	var ext := absf(up.x) * _h.x + absf(up.y) * _h.y + absf(up.z) * _h.z
	var hit := _cast(_c + up * (ext + 0.6), _c - up * (ext + 0.6))
	if hit.is_empty():
		hit = [_c + up * ext, up]
	# 穴の大きさ：上から見た、短いほうの辺くらい
	var sizes := [_h.x, _h.y, _h.z]
	if absf(up.x) > 0.7:
		sizes = [_h.y, _h.z]
	elif absf(up.y) > 0.7:
		sizes = [_h.x, _h.z]
	elif absf(up.z) > 0.7:
		sizes = [_h.x, _h.y]
	var r := minf(float(sizes[0]), float(sizes[1])) * 1.8
	_decal(_tex("hole"), Vector2(r, r), hit)


var _up0 := Vector3.UP


# 飾りから見た、いまの世界の上向き
func _up_here() -> Vector3:
	return ((prop.global_basis * transform.basis).inverse() * Vector3.UP).normalized()


# 作った時から、物が大きく向きを変えたか（穴は、寝かせ直したら描き直す。production_main.gd の _sync_cast_dress）
func turned() -> bool:
	return prop != null and _up_here().angle_to(_up0) > 0.6


# ---- 部品 ----

# ぎょろ目（白目と黒目）
func _eye(r: float) -> Node3D:
	var g := Node3D.new()
	var white := _mesh(_sphere(r), Color(0.98, 0.98, 0.96), Vector3(0, 0, r * 0.2))
	white.scale = Vector3(1, 1, 0.55)
	g.add_child(white)
	var pupil := _mesh(_sphere(r * 0.45), INK, Vector3(_rng.randf_range(-0.25, 0.25) * r, -r * 0.2, r * 0.5))
	pupil.scale = Vector3(1, 1, 0.5)
	g.add_child(pupil)
	return g


# 貼り付けた丸いシール（平たい玉）
func _dot(r: float, col: Color, glow := 0.0) -> Node3D:
	var g := Node3D.new()
	var d := _mesh(_sphere(r), col, Vector3.ZERO, Vector3.ZERO, glow)
	d.scale = Vector3(1, 1, 0.35)
	g.add_child(d)
	return g


# 明かりのついた窓（暗い枠つき）
func _window(size: Vector2) -> Node3D:
	var g := Node3D.new()
	g.add_child(_mesh(_box(Vector3(size.x * 1.25, size.y * 1.2, 0.006)), Color(0.22, 0.2, 0.22), Vector3(0, 0, 0.003)))
	g.add_child(_mesh(_box(Vector3(size.x, size.y, 0.006)), Color(1.0, 0.86, 0.45), Vector3(0, 0, 0.007), Vector3.ZERO, 0.8))
	return g


# ひび（黒い細い線）
func _crack() -> Node3D:
	var g := Node3D.new()
	var a := _rng.randf_range(-1.2, 1.2)
	g.add_child(_mesh(_box(Vector3(u * 0.55, u * 0.04, 0.006)), Color(0.15, 0.13, 0.12), Vector3(0, 0, 0.003), Vector3(0, 0, a)))
	g.add_child(_mesh(_box(Vector3(u * 0.35, u * 0.035, 0.006)), Color(0.15, 0.13, 0.12), Vector3(cos(a) * u * 0.3, sin(a) * u * 0.3, 0.003), Vector3(0, 0, a + 0.8)))
	return g


# きらきら（十字の光）
func _kira(size: float) -> Node3D:
	var g := Node3D.new()
	g.add_child(_mesh(_box(Vector3(size, size * 0.12, 0.008)), Color(1.0, 0.88, 0.35), Vector3(0, 0, 0.005), Vector3.ZERO, 1.5))
	g.add_child(_mesh(_box(Vector3(size * 0.12, size, 0.008)), Color(1.0, 0.88, 0.35), Vector3(0, 0, 0.006), Vector3.ZERO, 1.5))
	return g


# 旗（さおの先に、布）
func _flag(tall: float, col: Color) -> Node3D:
	var g := Node3D.new()
	g.add_child(_along(_cyl(u * 0.04, tall), Color(0.55, 0.42, 0.3)))
	g.add_child(_mesh(_box(Vector3(u * 0.8, 0.012, u * 0.5)), col, Vector3(u * 0.4, 0, tall - u * 0.28)))
	return g


# 車輪（黒いタイヤと、銀の十字）
func _wheel(r: float) -> Node3D:
	var g := Node3D.new()
	g.add_child(_mesh(_torus(r * 0.72, r), Color(0.08, 0.08, 0.08), Vector3(0, 0, r * 0.12), Vector3(PI * 0.5, 0, 0)))
	g.add_child(_mesh(_box(Vector3(r * 1.5, r * 0.08, 0.01)), Color(0.75, 0.75, 0.78), Vector3(0, 0, r * 0.12)))
	g.add_child(_mesh(_box(Vector3(r * 0.08, r * 1.5, 0.01)), Color(0.75, 0.75, 0.78), Vector3(0, 0, r * 0.12)))
	return g


# 手書きの立て札（形にしにくい役）：段ボールの板を棒で立てて、表と裏に役の名前を書く
func _sign(text: String, hit: Array) -> void:
	var g := Node3D.new()
	g.add_child(_along(_cyl(u * 0.04, u * 1.3), Color(0.6, 0.45, 0.28)))
	var board := Node3D.new()
	board.position = Vector3(0, 0, u * 1.3 + u * 0.45)
	board.rotation.x = PI * 0.5        # 板の面を、物の正面へ向ける
	g.add_child(board)
	board.add_child(_mesh(_box(Vector3(u * 1.7, u * 0.9, 0.012)), PAPER))
	for face: float in [1.0, -1.0]:
		var l := _label(text, u * 1.4, INK, Vector3(0, 0, 0.008 * face))
		l.rotation.y = 0.0 if face > 0.0 else PI
		board.add_child(l)
	_put(g, hit)


func _label(text: String, width: float, col: Color, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if font != null:
		l.font = font
	l.font_size = 64
	l.pixel_size = width / (64.0 * maxf(text.length(), 1))
	l.outline_size = 0
	l.modulate = col
	l.double_sided = false
	l.position = at
	return l


# ---- 貼る場所：物の当たり判定の表面を探す（飾りの向きで、-1..1 の割合） ----

# 正面（顔の側。飾りの +z の面）
func _front(fx: float, fy: float) -> Array:
	var c := _c
	var h := _h
	if fit:
		var at := Vector3(c.x + h.x * fx, c.y + h.y * fy, c.z + h.z + 0.6)
		var best := _probe(at, Vector3(0, 0, -(h.z * 2.0 + 1.2)), Vector3(h.x * 0.18, 0, 0), Vector3(0, h.y * 0.18, 0), Vector3.BACK)
		if not best.is_empty():
			return best
	for k: float in [1.0, 0.6, 0.3]:
		var p := Vector3(c.x + h.x * fx * k, c.y + h.y * fy * k, c.z + h.z + 0.6)
		var hit := _cast(p, p - Vector3(0, 0, h.z * 2.0 + 1.2))
		if not hit.is_empty():
			return hit
	return [Vector3(c.x + h.x * fx, c.y + h.y * fy, c.z + h.z), Vector3.BACK]


# 顔の場所：ふつうは正面。平たい物（高さが奥行きよりずっと低い。パイ・皿など）は、てっぺんに上向きに描く（fy の上が奥）
func _face(fx: float, fy: float) -> Array:
	return _top(fx, -fy) if _flat() else _front(fx, fy)


func _flat() -> bool:
	return _h.y < _h.z * 0.6


# てっぺん
func _top(fx: float, fz: float) -> Array:
	var c := _c
	var h := _h
	if fit:
		var at := Vector3(c.x + h.x * fx, c.y + h.y + 0.6, c.z + h.z * fz)
		var best := _probe(at, Vector3(0, -(h.y * 2.0 + 1.2), 0), Vector3(h.x * 0.18, 0, 0), Vector3(0, 0, h.z * 0.18), Vector3.UP)
		if not best.is_empty():
			return best
	for k: float in [1.0, 0.6, 0.3, 0.0]:
		var p := Vector3(c.x + h.x * fx * k, c.y + h.y + 0.6, c.z + h.z * fz * k)
		var hit := _cast(p, p - Vector3(0, h.y * 2.0 + 1.2, 0))
		if not hit.is_empty():
			return hit
	return [Vector3(c.x + h.x * fx, c.y + h.y, c.z + h.z * fz), Vector3.UP]


# 横（s = 1 で +x の面、-1 で -x の面）
func _side(s: float, fy: float, fz: float) -> Array:
	var c := _c
	var h := _h
	if fit:
		var at := Vector3(c.x + s * (h.x + 0.6), c.y + h.y * fy, c.z + h.z * fz)
		var best := _probe(at, Vector3(-s * (h.x * 2.0 + 1.2), 0, 0), Vector3(0, h.y * 0.18, 0), Vector3(0, 0, h.z * 0.18), Vector3(s, 0, 0))
		if not best.is_empty():
			return best
	for k: float in [1.0, 0.6, 0.3]:
		var p := Vector3(c.x + s * (h.x + 0.6), c.y + h.y * fy * k, c.z + h.z * fz * k)
		var hit := _cast(p, p - Vector3(s * (h.x * 2.0 + 1.2), 0, 0))
		if not hit.is_empty():
			return hit
	return [Vector3(c.x + s * h.x, c.y + h.y * fy, c.z + h.z * fz), Vector3(s, 0, 0)]


# まわり（角度 a の向きから、中心へ。fy は高さの割合）
func _around(a: float, fy: float) -> Array:
	var c := _c
	var h := _h
	var d := Vector3(cos(a), 0, sin(a))
	var y := c.y + h.y * fy
	var p := Vector3(c.x + d.x * (h.x + 0.6), y, c.z + d.z * (h.z + 0.6))
	var hit := _cast(p, Vector3(c.x, y, c.z))
	if not hit.is_empty():
		return hit
	return [Vector3(c.x + d.x * h.x, y, c.z + d.z * h.z), d]


# 改良版の場所選び：狙った所のまわり（5×5）に光線を打つ。
# 狙った所の点が、まわりと続いた面の上（上下左右のうち2つ以上が同じくらいの深さ）なら、そのまま使う（トイレのタンクのような段差で、手前の別の面へ飛ばない）。
# 狙った所が、すき間（当たらない）や穴の奥なら、外向きの面のうち、いちばん手前の層から、狙った所にいちばん近い点を選ぶ。どれにも当たらなければ空
func _probe(at: Vector3, ray: Vector3, a: Vector3, b: Vector3, out: Vector3) -> Array:
	var hits: Array = []
	var grid := {}
	for i in range(-2, 3):
		for j in range(-2, 3):
			var p := at + a * float(i) + b * float(j)
			var hit := _cast(p, p + ray)
			if not hit.is_empty() and (hit[1] as Vector3).dot(out) > 0.45:
				hits.append(hit)
				grid[Vector2i(i, j)] = hit
	if hits.is_empty():
		return []
	if grid.has(Vector2i.ZERO):
		var depth: float = (grid[Vector2i.ZERO][0] as Vector3).dot(out)
		var level := 0
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if grid.has(n) and (grid[n][0] as Vector3).dot(out) <= depth + u * 0.25:
				level += 1
		if level >= 2:
			return grid[Vector2i.ZERO]
	var front := -INF
	for hit: Array in hits:
		front = maxf(front, (hit[0] as Vector3).dot(out))
	var best: Array = []
	var near := INF
	for hit: Array in hits:
		var pos: Vector3 = hit[0]
		if pos.dot(out) < front - u * 0.35:
			continue
		var off := (pos - at) - out * (pos - at).dot(out)
		if off.length() < near:
			near = off.length()
			best = hit
	return best


# 物の当たり判定にだけ当たる光線（ほかの物は、よけて先へ）。飾りから見た [位置, 面の向き]
func _cast(from_l: Vector3, to_l: Vector3) -> Array:
	if not prop.is_inside_tree() or prop.collision_layer == 0:
		return []
	# 飾りの向き → 物 → 世界
	var xf: Transform3D = prop.global_transform * transform
	var space := prop.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(xf * from_l, xf * to_l, prop.collision_layer)
	var skip: Array[RID] = []
	for i in 6:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return []
		if hit["collider"] == prop:
			var inv := xf.affine_inverse()
			return [inv * (hit["position"] as Vector3), (inv.basis * (hit["normal"] as Vector3)).normalized()]
		skip.append(hit["rid"])
	return []


# 部品を、表面に貼る。部品の +z が面の外向き、+y がなるべく上
func _put(piece: Node3D, hit: Array) -> void:
	var z: Vector3 = (hit[1] as Vector3).normalized()
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	piece.transform = Transform3D(Basis(x, z.cross(x), z), hit[0])
	if grade <= 0:
		# 役に合わない物は、飾りが曲がって付く（あわてて貼った感じ）
		piece.rotate_object_local(Vector3.BACK, _rng.randf_range(0.18, 0.35) * (1.0 if _rng.randf() < 0.5 else -1.0))
	add_child(piece)


# ---- デカール（改良版）：物に投影して描く。曲面に沿う。面に対して横向きの所（地面・横の面）には描かない ----

func _decal(tex: Texture2D, size: Vector2, hit: Array, glow := 0.0) -> void:
	var g := Node3D.new()
	var d := Decal.new()
	d.texture_albedo = tex
	if glow > 0.0:
		d.texture_emission = tex
		d.emission_energy = glow
	# 奥行き：面の凸凹を拾えるだけ（外側の空気の分は、隣の物に描かないよう短く）
	d.size = Vector3(size.x, clampf(minf(_h.z, _h.x) * 1.2, 0.1, 0.8), size.y)
	d.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))   # デカールの -y を、面の内向きへ
	d.normal_fade = 0.45
	d.upper_fade = 0.15
	d.lower_fade = 0.15
	g.add_child(d)
	_put(g, hit)


static var _textures := {}


# 飾りの絵（透明の地に描く。一度描いたら使い回す）
static func _tex(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.12, 0.1, 0.1)
	match key:
		"moon_face":
			_disc(img, Vector2(40, 50), 7, ink)
			_disc(img, Vector2(88, 50), 7, ink)
			for i in 8:
				var a0 := deg_to_rad(25.0 + 130.0 * float(i) / 8.0)
				var a1 := deg_to_rad(25.0 + 130.0 * float(i + 1) / 8.0)
				_seg(img, Vector2(64, 58) + Vector2(cos(a0), sin(a0)) * 30.0, Vector2(64, 58) + Vector2(cos(a1), sin(a1)) * 30.0, 3.0, ink)
			_disc(img, Vector2(26, 76), 11, Color(0.98, 0.55, 0.6, 0.75))
			_disc(img, Vector2(102, 76), 11, Color(0.98, 0.55, 0.6, 0.75))
		"windows":
			for row in 3:
				for col in 3:
					_window_px(img, Rect2(10 + col * 39, 8 + row * 40, 30, 32))
		"window1":
			_window_px(img, Rect2(14, 10, 100, 108))
		"ivy":
			var pts := [Vector2(20, 120), Vector2(36, 90), Vector2(30, 62), Vector2(52, 40), Vector2(70, 18), Vector2(96, 10)]
			for i in pts.size() - 1:
				_seg(img, pts[i], pts[i + 1], 2.5, Color(0.22, 0.38, 0.15))
			var leaves := [Vector2(26, 104), Vector2(46, 92), Vector2(22, 74), Vector2(44, 58), Vector2(64, 44), Vector2(56, 24), Vector2(82, 22), Vector2(100, 6), Vector2(34, 44)]
			for i in leaves.size():
				_disc(img, leaves[i], 9.0 + float(i % 3) * 2.0, Color(0.25, 0.5, 0.2).lerp(Color(0.42, 0.65, 0.26), float(i % 4) / 3.0))
		"crack":
			var line := [Vector2(14, 30), Vector2(40, 46), Vector2(52, 72), Vector2(80, 80), Vector2(96, 108), Vector2(118, 116)]
			for i in line.size() - 1:
				_seg(img, line[i], line[i + 1], 3.0, Color(0.13, 0.11, 0.1))
			_seg(img, Vector2(52, 72), Vector2(44, 100), 2.0, Color(0.13, 0.11, 0.1))
			_seg(img, Vector2(80, 80), Vector2(104, 62), 2.0, Color(0.13, 0.11, 0.1))
		"kira":
			for y in n:
				for x in n:
					var dx := absf(float(x) - 63.5)
					var dy := absf(float(y) - 63.5)
					var v := maxf(1.0 - (dx / 60.0 + dy / 9.0), 1.0 - (dx / 9.0 + dy / 60.0))
					if v > 0.0:
						img.set_pixel(x, y, Color(1.0, 0.98, 0.8, clampf(v * 3.0, 0.0, 1.0)))
		"hole":
			# まん中ほど暗い楕円と、ふちの土の色
			for y in n:
				for x in n:
					var q := Vector2((float(x) - 63.5) / 60.0, (float(y) - 63.5) / 60.0)
					var dist := q.length()
					if dist > 1.0:
						continue
					var rim := smoothstep(0.78, 0.98, dist)
					var deep := Color(0.03, 0.025, 0.02).lerp(Color(0.36, 0.27, 0.18), rim)
					img.set_pixel(x, y, Color(deep.r, deep.g, deep.b, clampf((1.0 - dist) * 25.0, 0.0, 1.0)))
		"door":
			var wood := Color(0.36, 0.24, 0.16)
			_rect(img, Rect2(4, 4, 120, 6), wood)
			_rect(img, Rect2(4, 118, 120, 6), wood)
			_rect(img, Rect2(4, 4, 6, 120), wood)
			_rect(img, Rect2(118, 4, 6, 120), wood)
			_rect(img, Rect2(36, 16, 56, 34), wood)
			_rect(img, Rect2(40, 20, 48, 26), Color(0.7, 0.85, 0.95))
			_rect(img, Rect2(44, 58, 40, 12), Color(0.95, 0.93, 0.86))
			_rect(img, Rect2(22, 80, 84, 3), wood)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func _window_px(img: Image, r: Rect2) -> void:
	_rect(img, r, Color(0.22, 0.2, 0.22))
	var pane := r.grow(-3.0)
	_rect(img, pane, Color(1.0, 0.86, 0.45))
	_rect(img, Rect2(pane.get_center().x - 1, pane.position.y, 2, pane.size.y), Color(0.22, 0.2, 0.22))
	_rect(img, Rect2(pane.position.x, pane.get_center().y - 1, pane.size.x, 2), Color(0.22, 0.2, 0.22))


static func _rect(img: Image, r: Rect2, col: Color) -> void:
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	_shape(img, Rect2(c - Vector2(r + 1, r + 1), Vector2(r * 2 + 2, r * 2 + 2)), func(q: Vector2) -> float: return r - q.distance_to(c), col)


static func _seg(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(w + 1.0)
	_shape(img, box, func(q: Vector2) -> float:
		var t := clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		return w - q.distance_to(a.lerp(b, t)), col)


# 形の内側までの距離（正なら内側）で、ふちをなめらかに塗り重ねる
static func _shape(img: Image, box: Rect2, inside: Callable, col: Color) -> void:
	for y in range(maxi(int(box.position.y), 0), mini(int(box.end.y) + 1, img.get_height())):
		for x in range(maxi(int(box.position.x), 0), mini(int(box.end.x) + 1, img.get_width())):
			var cover := clampf(float(inside.call(Vector2(x + 0.5, y + 0.5))) + 0.5, 0.0, 1.0) * col.a
			if cover <= 0.0:
				continue
			var under := img.get_pixel(x, y)
			var a := cover + under.a * (1.0 - cover)
			var rgb := (Color(col.r, col.g, col.b) * cover + Color(under.r, under.g, under.b) * under.a * (1.0 - cover)) / maxf(a, 0.001)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))


# ---- 形と色 ----

func _mesh(mesh: Mesh, col: Color, at := Vector3.ZERO, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, glow)
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# 縦長の形（円柱・円すい）を、面の外向き（+z）へ立てる。根元が面に付く
func _along(mesh: PrimitiveMesh, col: Color, glow := 0.0) -> MeshInstance3D:
	var tall: float = mesh.get("height")
	return _mesh(mesh, col, Vector3(0, 0, tall * 0.5), Vector3(PI * 0.5, 0, 0), glow)


func _mat(col: Color, glow: float) -> StandardMaterial3D:
	var key := "%s/%.2f" % [col.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


func _cyl(r: float, tall: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = tall
	m.radial_segments = 8
	m.rings = 1
	return m


func _cone(r: float, tall: float, sides := 8, tip := 0.0) -> CylinderMesh:
	var m := _cyl(r, tall)
	m.top_radius = tip
	m.radial_segments = sides
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _prism(size: Vector3, apex := 0.5) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = apex
	return m


func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	return m


# 五つ角の星（平ら。xy の面）
func _star(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a0 := PI * 0.5 + TAU * float(i) / 10.0
		var a1 := PI * 0.5 + TAU * float(i + 1) / 10.0
		var r0 := r if i % 2 == 0 else r * 0.45
		var r1 := r if (i + 1) % 2 == 0 else r * 0.45
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0))
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0))
	return st.commit()
