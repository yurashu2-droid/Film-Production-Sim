extends Node3D
## 見立ての飾り：役を付けた物に、その役らしい紙や布の飾りを付ける（安い映画の手：便器に目玉を貼れば怪獣、丸い物に顔を描けば月）。
## 文字の札の代わり。映画にも映る（制作班だけの層にしない）。形にしにくい役（階段）は、手書きの立て札にする。
## 役との相性が悪い物（らしさ ★1）は、飾りが少し曲がって付く（数字は出さない。上映会で分かる）。
## 飾りの場所は、物の当たり判定の表面を光線で探す（外形の箱の面に貼ると、宙に浮くので）。
## 顔（目・顔・ライトなど、正面に付く物）は、役を付けた人が見ていた側に付ける（face：0 = 物の +z、1 = +x、2 = -z、3 = -x）。
## 物の子として付く（物と一緒に動き、箱に入れて隠れれば一緒に隠れる）。production_main.gd の _sync_cast_dress が付け外しする。

var role := ""
var grade := 2
var face := 0
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


func build(p: Node3D, r: String, g: int, fnt: Font, seed_id: int, side := 0) -> void:
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
		_put(_crack(), _front(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)))


# 玄関：ドアノブと、小窓と、表札
func _door() -> void:
	var knob := Node3D.new()
	knob.add_child(_along(_cyl(u * 0.06, u * 0.18), Color(0.8, 0.65, 0.25)))
	knob.add_child(_mesh(_sphere(u * 0.18), Color(0.85, 0.7, 0.25), Vector3(0, 0, u * 0.22)))
	_put(knob, _front(0.6, -0.05))
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
		_put(_window(Vector2(u * 0.4, u * 0.5)), _front(0.4 * s, -0.15))


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
