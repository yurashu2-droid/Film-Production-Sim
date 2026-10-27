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
## それっぽさの段（新しい8役だけ：おばけ・ケーキ・酒場・回転草・料理・コンロ・カツ丼・宇宙船）。build() の lv で決める。
##   1 = 手書きの立て札だけ / 2 = ひと手間（札なしで分かる、手作りの部品を1〜2つ） / 3 = 本気（2 に部品と細かい所を足す）
## いまはゲームでは 3（build() の標準）。らしさ（grade）と結びつけるなら、production_main.gd の build() 呼び出しで lv を渡す。
## 見本の並べ撮り：tests/cast_dress_levels_shot.gd
var level := 3
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


func build(p: Node3D, r: String, g: int, fnt: Font, seed_id: int, side := 0, fit_style := true, lv := 3) -> void:
	fit = fit_style
	level = clampi(lv, 1, 3)
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
		# 17〜28 の依頼の役（2026-10-27）：隕石は大岩と同じ飾り、屋敷は玄関と同じ飾り
		"meteor": _bigrock()
		"manor": _door()
		# この8役は、それっぽさの段（level）で飾りを変える。1 は手書きの立て札
		"ghost": _leveled("おばけ", _ghost)
		"cake": _leveled("ケーキ", _cake)
		"saloon": _leveled("酒場", _saloon)
		"tumble": _leveled("回転草", _tumble)
		"dish": _leveled("料理", _dish)
		"stove": _leveled("コンロ", _stove)
		"katsudon": _leveled("カツ丼", _katsudon)
		"rocket": _leveled("宇宙船", _rocket)
		_: _sign(r, _top(0, 0))


func _leveled(text: String, dress: Callable) -> void:
	if level <= 1:
		_sign(text, _top(0, 0))
	else:
		dress.call()


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


# ---- それっぽさの段のある役（2 = ひと手間、3 = 本気） ----

const SHEET := Color(0.95, 0.95, 0.92)    # 白い布
const CREAM := Color(0.98, 0.96, 0.9)
const WOOD := Color(0.56, 0.37, 0.21)
const WOOD_DARK := Color(0.33, 0.21, 0.12)
const FLAME := Color(1.0, 0.55, 0.12)
const FLAME_IN := Color(1.0, 0.88, 0.35)


# おばけ：白いシーツをかぶせて、黒い目を2つ（2）。すそをぎざぎざに切って、口と、たれた手（3）
func _ghost() -> void:
	var e := _hull()
	var a: float = e[0] * 1.06 + 0.01
	var b: float = e[1] * 1.06 + 0.01
	var top := _c.y + _h.y
	var low := _c.y - _h.y * (0.5 if level >= 3 else 0.6)
	var tall := top - low
	var flare := 1.15
	# 頭：ふくらんだ布（半球）
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 20
	dome.rings = 8
	var head := _mesh(dome, SHEET, Vector3(_c.x, top - 0.002, _c.z))
	head.scale = Vector3(a, minf(a, b) * 0.75 + u * 0.2, b)
	add_child(head)
	# すそ：下へ広がる筒
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = flare
	tube.height = tall
	tube.radial_segments = 20
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var skirt := _mesh(tube, SHEET, Vector3(_c.x, (top + low) * 0.5, _c.z))
	skirt.scale = Vector3(a, 1, b)
	add_child(skirt)
	# 目：たての黒い楕円（布の上、頭のすぐ下）
	var er := clampf(minf(a * 0.3, tall * 0.12), 0.03, 0.2)
	var ey := top - er * 1.4
	for s: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		var dot := _mesh(_sphere(er), INK)
		dot.scale = Vector3(0.75, 1.15, 0.25)
		eye.add_child(dot)
		_put(eye, _on_sheet(s * 0.36, ey, a, b, low, tall, flare))
	if level < 3:
		return
	# 口：まるく開いた口
	var mouth := Node3D.new()
	var hole := _mesh(_sphere(er * 0.8), INK)
	hole.scale = Vector3(0.9, 1.2, 0.25)
	mouth.add_child(hole)
	_put(mouth, _on_sheet(0.0, ey - er * 2.6, a, b, low, tall, flare))
	# すそ：ぎざぎざに切った布（長さを変えて、波打たせる）
	var n := 16
	for i in n:
		var t := TAU * (float(i) + 0.5) / float(n)
		var p := Vector3(_c.x + cos(t) * a * flare, low + 0.004, _c.z + sin(t) * b * flare)
		var out := Vector3(cos(t) / (a * flare), 0, sin(t) / (b * flare)).normalized()
		var side := Vector3.UP.cross(out)
		var w := TAU * sqrt((a * a + b * b) * 0.5) * flare / float(n) * 1.25
		var hang := tall * (0.22 if i % 2 == 0 else 0.14)
		var flap := _mesh(_prism(Vector3(w, hang, 0.01)), SHEET)
		flap.transform = Transform3D(Basis(-side, Vector3.DOWN, out), p + Vector3.DOWN * hang * 0.5)
		add_child(flap)
	# 手：両脇に、たれた布のふくらみ
	for s: float in [-1.0, 1.0]:
		var hand := Node3D.new()
		var lump := _mesh(_sphere(er * 1.8), SHEET, Vector3(0, -er * 0.8, er * 0.3))
		lump.scale = Vector3(0.55, 1.5, 0.7)
		lump.rotation.z = -s * 0.35
		hand.add_child(lump)
		var y := ey - tall * 0.25
		var k := clampf((top - y) / tall, 0.0, 1.0)
		var r := lerpf(1.0, flare, k)
		_put(hand, [Vector3(_c.x + s * a * r, y, _c.z), Vector3(s, 0, 0)])


# シーツの表の点（正面の向き）：横の割合 fx、高さ y。[位置, 外向き]
func _on_sheet(fx: float, y: float, a: float, b: float, low: float, tall: float, flare: float) -> Array:
	var k := clampf(1.0 - (y - low) / tall, 0.0, 1.0)
	var r := lerpf(1.0, flare, k)
	var x := fx * a * r
	var z := b * r * sqrt(maxf(1.0 - fx * fx, 0.0))
	var out := Vector3(x / (a * a), 0, z / (b * b)).normalized()
	return [Vector3(_c.x + x, y, _c.z + z) + out * 0.004, out]


# 物のまわりを光線で測って、物をすっぽり包む楕円の半径 [x, z]（飾りの向き）
func _hull() -> Array:
	var pts: Array = []
	for fy: float in [0.8, 0.3, -0.2, -0.6]:
		for p: Array in _ring(fy, 12):
			pts.append(p[0])
	var ax := 0.01
	var az := 0.01
	for p: Vector3 in pts:
		ax = maxf(ax, absf(p.x - _c.x))
		az = maxf(az, absf(p.z - _c.z))
	var k := 1.0
	for p: Vector3 in pts:
		k = maxf(k, Vector2((p.x - _c.x) / ax, (p.z - _c.z) / az).length())
	return [ax * k, az * k]


# ケーキ：上のふちに生クリームをぐるり、ろうそく3本（2）。ろうそくに火、クリームにいちご、横にたれるピンクの糖衣、根元にもクリーム（3）
func _cake() -> void:
	var n := 10
	var r := clampf(minf(_h.x, _h.z) * 0.16, u * 0.12, u * 0.3)
	for i in n:
		var t := TAU * (float(i) + 0.5) / float(n)
		var puff := Node3D.new()
		var cream := _mesh(_sphere(r), CREAM, Vector3(0, 0, r * 0.5))
		cream.scale = Vector3(1, 1, 0.8)
		puff.add_child(cream)
		puff.add_child(_mesh(_cone(r * 0.55, r * 0.7, 6), CREAM, Vector3(0, 0, r * 1.2), Vector3(PI * 0.5, 0, 0)))
		if level >= 3 and i % 2 == 0:
			puff.add_child(_strawberry(r * 0.75, Vector3(0, 0, r * 1.45)))
		_put(puff, _top(cos(t) * 0.78, sin(t) * 0.78))
	var hues := [Color(0.95, 0.5, 0.65), Color(0.45, 0.7, 0.95), Color(0.98, 0.85, 0.35)]
	var spots := [Vector2(-0.32, 0.1), Vector2(0.0, -0.22), Vector2(0.32, 0.1)]
	var tall := clampf(_h.y * 0.9, u * 0.5, u * 1.0)
	for i in spots.size():
		var candle := Node3D.new()
		candle.add_child(_along(_cyl(r * 0.28, tall), hues[i]))
		var wick := _mesh(_cyl(r * 0.06, r * 0.3), INK, Vector3(0, 0, tall + r * 0.15), Vector3(PI * 0.5, 0, 0))
		candle.add_child(wick)
		if level >= 3:
			# 細いしま
			for k in 3:
				candle.add_child(_mesh(_cyl(r * 0.3, tall * 0.07), CREAM, Vector3(0, 0, tall * (0.25 + 0.25 * k)), Vector3(PI * 0.5, 0, 0)))
			var fire := _mesh(_sphere(r * 0.42), FLAME, Vector3(0, 0, tall + r * 0.7), Vector3.ZERO, 2.5)
			fire.scale = Vector3(0.75, 0.75, 1.6)
			candle.add_child(fire)
			var core := _mesh(_sphere(r * 0.24), FLAME_IN, Vector3(0, 0, tall + r * 0.6), Vector3.ZERO, 3.0)
			core.scale = Vector3(0.8, 0.8, 1.5)
			candle.add_child(core)
		_put(candle, _top(spots[i].x, spots[i].y))
	if level < 3:
		return
	# 横にたれる、ピンクの糖衣
	var size := Vector2(_h.x * 2.1, maxf(_h.y * 1.6, u * 0.8))
	_decal(_tex("drip"), size, _front(0, 0.45))
	for s: float in [-1.0, 1.0]:
		_decal(_tex("drip"), Vector2(_h.z * 2.1, size.y), _side(s, 0.45, 0))
	# 根元：しぼり出したクリームの粒
	for p: Array in _ring(-0.82, 18, r * 0.2):
		if p[2]:
			continue   # 脚のすき間など、当たらなかった所には付けない（宙に浮くので）
		var bead := _mesh(_sphere(r * 0.55), CREAM, p[0])
		add_child(bead)


func _strawberry(r: float, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = at
	var berry := _mesh(_sphere(r), Color(0.88, 0.12, 0.15), Vector3(0, 0, r * 0.8))
	berry.scale = Vector3(0.9, 0.9, 1.1)
	g.add_child(berry)
	g.add_child(_mesh(_star(r * 0.7), Color(0.25, 0.55, 0.2), Vector3(0, 0, r * 1.85)))
	return g


# 酒場：正面の上に、西部の店の「見せかけの正面」（大きな板の看板）、入口に腰の高さの両開きの戸（2）。
# 看板に板目とジョッキの絵、戸の上に小さなひさし、両脇にランプ（3）
func _saloon() -> void:
	var w := _h.x * 1.9
	var tall := clampf(_h.y * 0.55, u * 1.0, u * 3.5)
	var below := _h.y * 0.18
	var board := Node3D.new()
	var mid := Vector3(0, tall * 0.5 - below, 0.016)
	board.add_child(_mesh(_box(Vector3(w, tall, 0.025)), WOOD, mid))
	board.add_child(_mesh(_box(Vector3(w * 0.45, tall * 0.22, 0.025)), WOOD, Vector3(0, tall * 1.11 - below, 0.016)))
	# ふちどり（濃い木）
	for k: float in [-1.0, 1.0]:
		board.add_child(_mesh(_box(Vector3(w, tall * 0.07, 0.01)), WOOD_DARK, mid + Vector3(0, k * tall * 0.465, 0.016)))
		board.add_child(_mesh(_box(Vector3(w * 0.035, tall, 0.01)), WOOD_DARK, mid + Vector3(k * w * 0.4825, 0, 0.016)))
	if level >= 3:
		# 板目
		for k in 3:
			board.add_child(_mesh(_box(Vector3(w * 0.93, 0.006, 0.006)), WOOD_DARK, mid + Vector3(0, tall * (-0.25 + 0.25 * k), 0.031)))
		# ジョッキの絵（黄色いビール、白い泡、取っ手）
		var m := tall * 0.48
		var mug := Node3D.new()
		mug.position = mid + Vector3(0, -tall * 0.02, 0.036)
		mug.add_child(_mesh(_box(Vector3(m * 0.7, m, 0.008)), Color(0.98, 0.72, 0.15)))
		for fx: float in [-0.22, 0.0, 0.22]:
			var foam := _mesh(_sphere(m * 0.2), CREAM, Vector3(fx * m, m * 0.52, 0.004))
			foam.scale = Vector3(1, 0.8, 0.3)
			mug.add_child(foam)
		mug.add_child(_mesh(_torus(m * 0.14, m * 0.24), Color(0.92, 0.9, 0.85), Vector3(m * 0.4, 0, 0), Vector3(PI * 0.5, 0, 0)))
		board.add_child(mug)
	_put(board, _front(0, 0.82))
	# 両開きの戸（よろい戸の板つき）。蝶番の側から、少し手前へ開いている
	var ww := _h.x * 0.34
	var hh := _h.y * 0.55
	for s: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		var pivot := Node3D.new()
		pivot.rotation.y = s * 0.55
		wing.add_child(pivot)
		var c := Vector3(-s * ww * 0.5, 0, 0.012)
		pivot.add_child(_mesh(_box(Vector3(ww, hh, 0.02)), WOOD, c))
		for k in 4:
			pivot.add_child(_mesh(_box(Vector3(ww * 0.8, hh * 0.06, 0.008)), WOOD_DARK, c + Vector3(0, hh * (-0.3 + 0.18 * k), 0.013)))
		# 上の端は、内側が低い弓なり
		var cap := _mesh(_sphere(ww * 0.5), WOOD, c + Vector3(0, hh * 0.5, 0))
		cap.scale = Vector3(1, 0.35, 0.04 / ww)
		pivot.add_child(cap)
		_put(wing, _front(s * 0.34, -0.3))
	if level < 3:
		return
	# 戸の上のひさし
	var awning := Node3D.new()
	var slope := Node3D.new()
	slope.rotation.x = -0.5
	awning.add_child(slope)
	slope.add_child(_mesh(_box(Vector3(_h.x * 0.95, u * 0.4, 0.015)), WOOD_DARK, Vector3(0, -u * 0.2, 0.01)))
	_put(awning, _front(0, 0.3))
	# 両脇のランプ（腕木の先に、ともる玉）
	for s: float in [-1.0, 1.0]:
		var lamp := Node3D.new()
		lamp.add_child(_along(_cyl(u * 0.025, u * 0.3), WOOD_DARK))
		lamp.add_child(_mesh(_sphere(u * 0.13), Color(1.0, 0.8, 0.4), Vector3(0, -u * 0.06, u * 0.32), Vector3.ZERO, 2.0))
		lamp.add_child(_mesh(_cone(u * 0.14, u * 0.1, 8), INK, Vector3(0, u * 0.1, u * 0.32)))
		_put(lamp, _front(s * 0.7, -0.05))


# 回転草：茶色い針金を、物のまわりにゆるく巻いた輪（2）。輪を増やして形をゆがめ、小枝を突き出す（3）
func _tumble() -> void:
	var hues := [Color(0.5, 0.36, 0.2), Color(0.63, 0.49, 0.28), Color(0.42, 0.3, 0.17)]
	var n := 7 if level < 3 else 14
	var e := _h * 1.08
	for i in n:
		var ring := _torus(1.0 - 0.025, 1.0 + 0.025)
		ring.rings = 40
		ring.ring_segments = 5
		var spin := Basis.from_euler(Vector3(_rng.randf_range(0, TAU), _rng.randf_range(0, TAU), _rng.randf_range(0, TAU)))
		var k := 1.0 if level < 3 else _rng.randf_range(0.9, 1.15)
		var loop := _mesh(ring, hues[i % hues.size()])
		loop.transform = Transform3D(Basis.from_scale(e * k) * spin, _c)
		add_child(loop)
	if level < 3:
		return
	for i in 16:
		var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1), _rng.randf_range(-1, 1)).normalized()
		var base := _c + v * e
		var tip := base + (v + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, 0.5), _rng.randf_range(-0.5, 0.5))).normalized() * u * _rng.randf_range(0.35, 0.7)
		add_child(_rod(base - v * u * 0.1, tip, u * 0.022, hues[i % hues.size()]))


# 料理：下に白いお皿、上から湯気（綿）（2）。お皿のふちに青い線、付け合わせ（パセリとレモン）、ナイフとフォーク、湯気を増やす（3）
func _dish() -> void:
	var a := _h.x * 1.3 + u * 0.35
	var b := _h.z * 1.3 + u * 0.35
	var y := _c.y - _h.y
	var th := clampf(u * 0.1, 0.01, 0.03)
	var plate := Node3D.new()
	plate.position = Vector3(_c.x, y, _c.z)
	var disc := _mesh(_cyl(1.0, th), Color(0.97, 0.97, 0.95), Vector3(0, th * 0.5 + 0.002, 0))
	disc.scale = Vector3(a, 1, b)
	plate.add_child(disc)
	var rim := _torus(1.0 - 0.06, 1.0)
	rim.ring_segments = 8
	rim.rings = 36
	var lip := _mesh(rim, Color(0.98, 0.98, 0.97), Vector3(0, th + 0.002, 0))
	lip.scale = Vector3(a, th * 8.0, b)
	plate.add_child(lip)
	if level >= 3:
		var line := _torus(0.86, 0.9)
		line.rings = 36
		var blue := _mesh(line, Color(0.2, 0.35, 0.75), Vector3(0, th + 0.003, 0))
		blue.scale = Vector3(a, 0.3, b)
		plate.add_child(blue)
	add_child(plate)
	var wisps := [Vector2(-0.3, 0.0), Vector2(0.25, 0.2)]
	if level >= 3:
		wisps.append(Vector2(0.05, -0.3))
	for at: Vector2 in wisps:
		_put(_steam(), _top(at.x, at.y))
	if level < 3:
		return
	# 付け合わせ：お皿の手前の右に、パセリとレモン
	var top := y + th + 0.004
	for i in 4:
		var leaf := _mesh(_sphere(u * 0.13), Color(0.2, 0.5, 0.18), Vector3(_c.x + a * 0.72 + _rng.randf_range(-1, 1) * u * 0.1, top + u * 0.05, _c.z + b * 0.55 + _rng.randf_range(-1, 1) * u * 0.1))
		leaf.scale = Vector3(1, 0.6, 1)
		add_child(leaf)
	var lemon := _mesh(_prism(Vector3(u * 0.45, u * 0.25, u * 0.12)), Color(0.98, 0.88, 0.25), Vector3(_c.x - a * 0.7, top + u * 0.12, _c.z + b * 0.6), Vector3(0, 0.6, 0))
	add_child(lemon)
	# ナイフとフォーク：お皿の両脇の床
	var silver := Color(0.78, 0.8, 0.83)
	var span := clampf(b * 1.3, u * 1.0, u * 4.0)
	for s: float in [-1.0, 1.0]:
		var x := _c.x + s * (a + u * 0.35)
		add_child(_mesh(_box(Vector3(u * 0.12, 0.012, span)), silver, Vector3(x, y + 0.008, _c.z + b * 0.1)))
		if s < 0.0:
			for k in 3:
				add_child(_mesh(_box(Vector3(u * 0.025, 0.01, span * 0.22)), silver, Vector3(x + (float(k) - 1.0) * u * 0.05, y + 0.008, _c.z + b * 0.1 - span * 0.6)))


# 湯気：白い綿を、ゆらゆらと縦に重ねる（面の外向き +z へのびる）
func _steam() -> Node3D:
	var g := Node3D.new()
	var phase := _rng.randf_range(0, TAU)
	for k in 5:
		var t := float(k)
		var puff := _mesh(_sphere(u * (0.17 - 0.022 * t)), Color(0.96, 0.96, 0.97), Vector3(sin(phase + t * 1.3) * u * 0.14, 0, u * (0.15 + 0.27 * t)))
		g.add_child(puff)
	return g


# コンロ：上に黒い五徳の輪を2つ、正面につまみ（2）。青い火、鉄の五徳の棒、つまみの台と赤い印（3）
func _stove() -> void:
	var br := clampf(minf(_h.x * 0.36, _h.z * 0.6), u * 0.3, u * 1.3)
	var tube := br * 0.14
	for s: float in [-1.0, 1.0]:
		var burner := Node3D.new()
		burner.add_child(_mesh(_torus(br - tube * 2.0, br), Color(0.1, 0.1, 0.1), Vector3(0, 0, tube), Vector3(PI * 0.5, 0, 0)))
		var cap := _mesh(_cyl(br * 0.35, tube * 1.5), Color(0.2, 0.2, 0.22), Vector3(0, 0, tube * 0.75), Vector3(PI * 0.5, 0, 0))
		burner.add_child(cap)
		if level >= 3:
			for k in 12:
				var t := TAU * float(k) / 12.0
				var fire := _mesh(_cone(br * 0.09, br * 0.32, 5), Color(0.3, 0.55, 1.0), Vector3(cos(t) * br * 0.45, sin(t) * br * 0.45, tube * 1.5 + br * 0.16), Vector3(PI * 0.5, 0, 0), 2.5)
				burner.add_child(fire)
			for k in 4:
				var bar := _mesh(_box(Vector3(br * 2.1, tube * 0.8, tube * 0.8)), Color(0.18, 0.18, 0.2), Vector3(0, 0, tube * 2.4), Vector3(0, 0, PI * 0.25 * k))
				burner.add_child(bar)
		_put(burner, _top(s * 0.48, 0.0))
	var kr := clampf(u * 0.14, 0.015, 0.06)
	var lift := 0.0
	if level >= 3:
		var panel := Node3D.new()
		panel.add_child(_mesh(_box(Vector3(_h.x * 1.6, kr * 3.4, 0.012)), Color(0.72, 0.74, 0.77), Vector3(0, 0, 0.006)))
		_put(panel, _front(0, 0.6))
		lift = 0.012
	for s: float in [-1.0, 1.0]:
		var knob := Node3D.new()
		var stem := _along(_cyl(kr, kr * 0.9), Color(0.1, 0.1, 0.1))
		stem.position.z += lift
		knob.add_child(stem)
		knob.add_child(_mesh(_box(Vector3(kr * 0.25, kr * 1.4, 0.006)), Color(0.85, 0.15, 0.12) if level >= 3 else Color(0.9, 0.9, 0.9), Vector3(0, 0, lift + kr * 0.9 + 0.003)))
		_put(knob, _front(s * 0.48, 0.6))


# カツ丼：丼のふち（濃い赤の輪）と、上にふわっと卵とじ（2）。卵の上にカツの切り身と三つ葉、丼に金の線、割りばし（3）
func _katsudon() -> void:
	var rim_fy := _rim_fy()
	var pts := _ring(rim_fy, 18, u * 0.03)
	var rim_r := clampf(u * 0.07, 0.008, 0.03)
	_hoop(pts, rim_r, Color(0.45, 0.08, 0.06))
	var ra := 0.01
	var rb := 0.01
	for p: Array in pts:
		ra = maxf(ra, absf((p[0] as Vector3).x - _c.x))
		rb = maxf(rb, absf((p[0] as Vector3).z - _c.z))
	var rim_y: float = (pts[0][0] as Vector3).y
	var heap := maxf(u * 0.22, _h.y * 0.13)
	var egg := _mesh(_sphere(1.0), Color(0.98, 0.8, 0.28), Vector3(_c.x, rim_y, _c.z))
	egg.scale = Vector3(ra * 0.97, heap, rb * 0.97)
	add_child(egg)
	if level < 3:
		# 白身のところ
		for i in 3:
			var white := _mesh(_sphere(u * 0.16), Color(0.99, 0.96, 0.85), Vector3(_c.x + _rng.randf_range(-0.5, 0.5) * ra, rim_y + heap * 0.8, _c.z + _rng.randf_range(-0.5, 0.5) * rb))
			white.scale = Vector3(1, 0.3, 1)
			add_child(white)
		return
	# カツ：切り身を5枚、少しずつ傾けて並べる
	var sw := ra * 0.28
	for i in 5:
		var x := (float(i) - 2.0) * sw * 1.2
		var slice := _mesh(_box(Vector3(sw * 0.9, heap * 0.45, rb * 1.0)), Color(0.78, 0.5, 0.2), Vector3(_c.x + x, rim_y + heap * 0.98, _c.z - rb * 0.05), Vector3(0, 0, -0.18))
		add_child(slice)
		# 切り口：白い身の線
		add_child(_mesh(_box(Vector3(sw * 0.06, heap * 0.3, rb * 0.95)), Color(0.97, 0.92, 0.8), Vector3(_c.x + x + sw * 0.43, rim_y + heap * 0.92, _c.z - rb * 0.05), Vector3(0, 0, -0.18)))
		# 卵がかかったところ（ところどころ）
		if i % 2 == 1:
			var drip := _mesh(_sphere(sw * 0.4), Color(0.99, 0.85, 0.35), Vector3(_c.x + x, rim_y + heap * 1.18, _c.z + _rng.randf_range(-0.3, 0.3) * rb))
			drip.scale = Vector3(1, 0.25, 1.6)
			add_child(drip)
	# 三つ葉
	for i in 3:
		var leaf := Node3D.new()
		leaf.add_child(_mesh(_star(u * 0.14), Color(0.25, 0.6, 0.22), Vector3(0, 0, 0.004)))
		var at := Vector3(_c.x + (float(i) - 1.0) * ra * 0.3, rim_y + heap * 1.3, _c.z + rb * 0.25)
		leaf.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), at)
		add_child(leaf)
	# 丼の金の線
	_hoop(_ring(rim_fy - 0.3, 18, u * 0.01), rim_r * 0.45, Color(0.9, 0.72, 0.25), 0.3)
	# 割りばし：ふちに渡して置く
	for k: float in [-1.0, 1.0]:
		var x := _c.x + ra * 0.62 + k * u * 0.05
		add_child(_rod(Vector3(x, rim_y + rim_r * 1.5 + heap * 0.5, _c.z - rb * 1.0), Vector3(x + u * 0.08, rim_y + rim_r * 1.5, _c.z + rb * 1.0 + u * 0.6), u * 0.03, Color(0.9, 0.78, 0.55)))


# 宇宙船：てっぺんに赤いとんがり、下の4方に羽（2）。丸窓、赤い帯、根元から噴き出す炎と煙（3）
func _rocket() -> void:
	var red := Color(0.86, 0.15, 0.12)
	var rr := clampf(minf(_h.x, _h.z) * 0.85, u * 0.3, u * 1.6)
	var nose := Node3D.new()
	nose.add_child(_along(_cone(rr, rr * 2.4, 12), red))
	if level >= 3:
		nose.add_child(_mesh(_cyl(rr * 1.03, rr * 0.2), Color(0.85, 0.86, 0.9), Vector3(0, 0, rr * 0.1), Vector3(PI * 0.5, 0, 0)))
	_put(nose, _top(0, 0))
	var fin_out := clampf(maxf(_h.x, _h.z) * 0.9, u * 0.5, u * 2.0)
	var fin_tall := _h.y * 0.55
	for i in 4:
		var a := TAU * float(i) / 4.0
		var fin := Node3D.new()
		fin.add_child(_mesh(_prism(Vector3(fin_out, fin_tall, 0.035), 0.0), red, Vector3(0, 0, fin_out * 0.5 - 0.005), Vector3(0, -PI * 0.5, 0)))
		_put(fin, _around(a, -0.5))
	if level < 3:
		return
	# 丸窓
	var wr := clampf(_girth(0.4) * 0.6, u * 0.2, u * 0.9)
	var win := Node3D.new()
	win.add_child(_mesh(_torus(wr * 0.78, wr), Color(0.8, 0.82, 0.86), Vector3(0, 0, wr * 0.11), Vector3(PI * 0.5, 0, 0)))
	var glass := _mesh(_sphere(wr * 0.8), Color(0.45, 0.75, 0.95), Vector3(0, 0, 0.004), Vector3.ZERO, 0.6)
	glass.scale = Vector3(1, 1, 0.12)
	win.add_child(glass)
	win.add_child(_mesh(_sphere(wr * 0.18), Color(0.95, 0.98, 1.0), Vector3(-wr * 0.3, wr * 0.3, wr * 0.1), Vector3.ZERO, 0.8))
	_put(win, _front(0, 0.4))
	# 赤い帯
	_hoop(_ring(-0.1, 20, u * 0.02), clampf(u * 0.08, 0.01, 0.04), red)
	# 根元：外へ吹き出す紙の炎と、綿の煙
	for i in 8:
		var a := TAU * float(i) / 8.0
		var jet := Node3D.new()
		var lean := Node3D.new()
		lean.rotation.x = 0.45
		jet.add_child(lean)
		var big := 1.0 if i % 2 == 0 else 0.7
		lean.add_child(_along(_cone(u * 0.4, u * 1.6 * big, 4), FLAME, 1.6))
		lean.add_child(_along(_cone(u * 0.22, u * 1.0 * big, 4), FLAME_IN, 2.2))
		_put(jet, _around(a, -0.86))
	for i in 10:
		var a := TAU * (float(i) + 0.3) / 10.0
		var d := Vector3(cos(a), 0, sin(a))
		var puff := _mesh(_sphere(u * _rng.randf_range(0.3, 0.45)), Color(0.88, 0.88, 0.86), Vector3(_c.x, _c.y - _h.y + u * 0.12, _c.z) + Vector3(d.x * (_h.x + u * 1.1), 0, d.z * (_h.z + u * 1.1)))
		puff.scale = Vector3(1, 0.65, 1)
		add_child(puff)


# 胴のふちの高さ（割合）：上から下へ測って、胴の太さ（真ん中の高さ）に届いた所。かごの取っ手のような細い物は飛ばす
func _rim_fy() -> float:
	var body := _girth(0.2)
	var fy := 0.92
	while fy > 0.2:
		if _girth(fy) >= body * 0.75:
			return fy
		fy -= 0.08
	return 0.5


# 高さ fy での、中心からの平均の距離（水平）
func _girth(fy: float) -> float:
	var sum := 0.0
	var pts := _ring(fy, 8)
	for p: Array in pts:
		var d: Vector3 = (p[0] as Vector3) - _c
		sum += Vector2(d.x, d.z).length()
	return sum / float(pts.size())


# 物のまわりを、高さ fy でぐるりと光線で測った点（飾りの向き）。点は面から lift だけ外へ。[位置, 外向き（水平）, 当たらなかった] の並び
func _ring(fy: float, n: int, lift := 0.0) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * float(i) / float(n)
		var hit := _around(a, fy)
		var miss := hit.size() > 2
		var nrm: Vector3 = hit[1]
		nrm.y = 0.0
		if nrm.length() < 0.2:
			nrm = Vector3(cos(a), 0, sin(a))
		nrm = nrm.normalized()
		out.append([(hit[0] as Vector3) + nrm * lift, nrm, miss])
	return out


# 点を順につないだ輪（細い棒と、つなぎ目の玉）
func _hoop(pts: Array, r: float, col: Color, glow := 0.0) -> void:
	for i in pts.size():
		var a: Vector3 = pts[i][0]
		var b: Vector3 = pts[(i + 1) % pts.size()][0]
		add_child(_rod(a, b, r, col, glow))
		add_child(_mesh(_sphere(r), col, a, Vector3.ZERO, glow))


# a から b への棒（飾りの向きのまま置く）
func _rod(a: Vector3, b: Vector3, r: float, col: Color, glow := 0.0) -> MeshInstance3D:
	var d := b - a
	var mi := _mesh(_cyl(r, maxf(d.length(), 0.001)), col, (a + b) * 0.5, Vector3.ZERO, glow)
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi


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
	return [Vector3(c.x + d.x * h.x, y, c.z + d.z * h.z), d, true]   # 3つめ：当たらなかった（外形の箱の面）


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
		var flat := 0
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if grid.has(n) and (grid[n][0] as Vector3).dot(out) <= depth + u * 0.25:
				flat += 1
		if flat >= 2:
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
		"drip":
			# 上からたれる、ピンクの糖衣（長さのちがうしずく）
			var pink := Color(0.98, 0.7, 0.78)
			_rect(img, Rect2(0, 0, 128, 30), pink)
			var drops := [44.0, 70.0, 52.0, 84.0, 58.0, 76.0, 48.0]
			for i in drops.size():
				var x := 9.0 + float(i) * 18.3
				_seg(img, Vector2(x, 24), Vector2(x, drops[i]), 5.0, pink)
				_disc(img, Vector2(x, drops[i]), 6.5, pink)
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
