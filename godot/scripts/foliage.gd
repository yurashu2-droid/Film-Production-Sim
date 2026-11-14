extends RefCounted
## 木と植え込み：丸い芯のまわりに、葉の形に抜いた板（葉の房）を重ねる。
## 板の法線は茂み全体の中心から外向きにそろえて、板の集まりをひとかたまりのふわっとした茂みに見せる
## （参考：Dear Passengers・PEAK の木。輪郭は葉でぎざぎざ、陰影はまるい）。
## 色は下・中・上の3色で、高さに合わせて染める（下は青みの濃い緑、上は日の当たる黄緑）。
const Look := preload("res://scripts/production_look.gd")

const GREENS := {
	"street": [Color("3d6a3a"), Color("6aa04a"), Color("b2d462")],
	"hedge": [Color("2f5a34"), Color("4f8840"), Color("8dbd55")],
	"young": [Color("44703a"), Color("74a84a"), Color("bcd66a")],
}
const FLOWERS := [Color("e86a5a"), Color("f2efe2"), Color("f0b33c"), Color("e58bb0")]


# 街路樹：幹が途中で分かれ、枝先ごとに茂みが付く。s は大きさ（1 でおよそ高さ 4m）
static func tree(b: Look.Batch, pos: Vector3, s: float, kind := "street") -> void:
	var rng := _rng(pos)
	var greens: Array = GREENS.get(kind, GREENS["street"])
	var bark := Look.mat("wood", Color("6f5a44"))
	# 根元の植えます（低い縁石と土）
	pit(b, pos, 1.3 * s)
	# 幹：少し傾けて立て、途中で枝に分かれる
	var fork := pos + Vector3(rng.randf_range(-0.12, 0.12) * s, 1.6 * s, rng.randf_range(-0.12, 0.12) * s)
	_limb(b, bark, pos, fork, 0.16 * s, 0.11 * s)
	for k in 3:
		var a := rng.randf() * TAU
		_limb(b, bark, pos + Vector3(0, 0.25 * s, 0), pos + Vector3(cos(a) * 0.3 * s, 0.0, sin(a) * 0.3 * s), 0.07 * s, 0.03 * s)
	var center := pos + Vector3(0, 3.0 * s, 0)
	var clumps: Array = []
	var top := pos + Vector3(rng.randf_range(-0.2, 0.2) * s, 3.55 * s, rng.randf_range(-0.2, 0.2) * s)
	clumps.append([top, 1.0 * s])
	_limb(b, bark, fork, top.lerp(fork, 0.45), 0.1 * s, 0.05 * s)
	var sides := 3 + rng.randi() % 2
	var a0 := rng.randf() * TAU
	for k in sides:
		var a := a0 + TAU * k / sides + rng.randf_range(-0.3, 0.3)
		var c := pos + Vector3(cos(a) * 1.0 * s, rng.randf_range(2.45, 2.9) * s, sin(a) * 1.0 * s)
		clumps.append([c, rng.randf_range(0.78, 0.92) * s])
		_limb(b, bark, fork, c.lerp(fork, 0.3), 0.08 * s, 0.04 * s)
	var lo := pos.y + 1.7 * s
	var hi := pos.y + 4.5 * s
	for cl: Array in clumps:
		_clump(b, rng, cl[0], cl[1], center, greens, lo, hi, 0.5 * s)


# 植え込み：長い箱形の茂み（中心 pos は茂みの底の中心、size は幅・高さ・奥行き）。flowers で花を散らす
static func hedge(b: Look.Batch, pos: Vector3, size: Vector3, flowers := 0, kind := "hedge") -> void:
	var rng := _rng(pos)
	var greens: Array = GREENS.get(kind, GREENS["hedge"])
	var n := maxi(int(size.x / 0.7), 1)
	var r := size.z * 0.55
	var lo := pos.y
	var hi := pos.y + size.y * 1.1
	for k in n:
		var x := -size.x * 0.5 + size.x * (k + 0.5) / n
		var c := pos + Vector3(x + rng.randf_range(-0.08, 0.08), size.y * 0.55, rng.randf_range(-0.04, 0.04))
		# 法線は茂みの芯の線（横長）から外向き：まるい箱の茂みに見える
		var from := Vector3(c.x, pos.y + size.y * 0.25, pos.z)
		var stretch := Vector3(size.x / n * 0.5 / r * 1.3, size.y * 0.5 / r, 1.0)
		_clump(b, rng, c, r * rng.randf_range(0.92, 1.05), from, greens, lo, hi, 0.24, stretch, 24, 0.6)
	var petal := Look.plain(Color.WHITE, 0.8)
	for k in flowers:
		var p := pos + Vector3(rng.randf_range(-0.48, 0.48) * size.x, size.y * rng.randf_range(0.75, 1.02), rng.randf_range(-0.45, 0.45) * size.z)
		var col: Color = FLOWERS[rng.randi() % FLOWERS.size()]
		b.boxy(Look.Tint.new(petal.mat, col), p, Vector3(0.09, 0.05, 0.09), rng.randf() * PI, Look.Batch.ALL)
		b.boxp(Look.Tint.new(petal.mat, Color("f6d65a")), p + Vector3(0, 0.03, 0), Vector3(0.035, 0.02, 0.035), Look.Batch.ALL)


# 生け垣のアーチ：門形の芯の線（2本の足と、上の半円）に沿って茂みを並べる。
# pos は足元の中央、w は芯の線の半分の幅（足の中心の x）、h は半円の中心の高さ、r は茂みの太さ、depth は奥行きの半分
static func hedge_arch(b: Look.Batch, pos: Vector3, w: float, h: float, r: float, depth: float, kind := "hedge") -> void:
	var rng := _rng(pos)
	var greens: Array = GREENS.get(kind, GREENS["hedge"])
	var step := r * 1.15
	var spine: Array = []
	for side in [-1.0, 1.0]:
		var n := maxi(int((h - r * 0.8) / step), 1)
		for k in n:
			spine.append(pos + Vector3(side * w, r * 0.8 + (h - r * 0.8) * k / n, 0))
	var arcs := maxi(int(PI * w / step), 2)
	for k in arcs + 1:
		var a := PI * k / arcs
		spine.append(pos + Vector3(cos(a) * w, h + sin(a) * w, 0))
	var stretch := Vector3(1.0, 1.0, depth / r)
	for c: Vector3 in spine:
		var at := c + Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04), rng.randf_range(-0.03, 0.03)) * r * 2.0
		_clump(b, rng, at, r * rng.randf_range(0.95, 1.08), at, greens, pos.y, pos.y + h + w + r, r * 0.85, stretch, 28, 0.6)


# 木の植えます：低い縁石で囲んだ土と、草の房
static func pit(b: Look.Batch, pos: Vector3, w: float) -> void:
	var curb := Look.mat("concrete", Color("bdb7a6"))
	var h := w * 0.5
	for k in 4:
		var side := Vector3.RIGHT.rotated(Vector3.UP, PI * 0.5 * k)
		b.box(curb, Transform3D(Basis(Vector3.UP, PI * 0.5 * k), pos + side * (h - 0.06) + Vector3(0, 0.07, 0)), Vector3(0.12, 0.14, w), Look.Batch.GROUND)
	b.boxp(Look.plain(Color("4a3a2c"), 1.0), pos + Vector3(0, 0.05, 0), Vector3(w - 0.2, 0.1, w - 0.2), Look.Batch.ALL)
	var rng := _rng(pos + Vector3(0.5, 0, 0.5))
	for k in 6:
		tuft(b, pos + Vector3(rng.randf_range(-h + 0.2, h - 0.2), 0.1, rng.randf_range(-h + 0.2, h - 0.2)), rng.randf_range(0.18, 0.3), rng)


# 小さな茂み（鉢植え・足元の草むら）。c は茂みの中心、r は半径
static func bush(b: Look.Batch, c: Vector3, r: float, kind := "young") -> void:
	var rng := _rng(c)
	var greens: Array = GREENS.get(kind, GREENS["young"])
	_clump(b, rng, c, r, c - Vector3(0, r * 0.4, 0), greens, c.y - r, c.y + r, r * 0.42, Vector3(1.0, 0.9, 1.0), int(14 + r * 30), 0.6)


# 草の房：縦の板を3枚、60度ずつ回して交差させる（どこから見ても房に見える）。h は高さ、dry で枯れ色に寄せる
static func tuft(b: Look.Batch, pos: Vector3, h: float, rng: RandomNumberGenerator, dry := 0.0) -> void:
	var grass := Look.mat("grass")
	var greens: Array = GREENS["young"]
	var col := (greens[1] as Color).lerp(greens[2], rng.randf()).lerp(Color("b9a85a"), dry)
	var yaw := rng.randf() * PI
	var lean := Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized()
	for k in 3:
		var a := yaw + PI / 3.0 * k
		var rt := Vector3(cos(a), 0, sin(a)) * h * 0.6
		var ut := lean * h * 0.5
		b.card(grass, pos + ut, rt, ut, (Vector3.UP + Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * 0.3).normalized(), col.darkened(rng.randf_range(0.0, 0.1)))


# つた：壁（外向き wall）に沿って点の列 path をたどる細いつると、そのまわりの葉。seed_pos で形が決まる
static func ivy(b: Look.Batch, path: Array, wall: Vector3, leaves: int, seed_pos: Vector3) -> void:
	var rng := _rng(seed_pos)
	var vine := Look.mat("wood", Color("5a4a32"))
	for k in path.size() - 1:
		b.bar(vine, path[k], path[k + 1], 0.03)
	var greens: Array = GREENS["young"]
	var leaf := Look.mat("leaf")
	var w := wall.normalized()
	var along := w.cross(Vector3.UP).normalized()
	for k in leaves:
		var f := rng.randf() * (path.size() - 1)
		var i := mini(int(f), path.size() - 2)
		var p: Vector3 = (path[i] as Vector3).lerp(path[i + 1], f - i)
		p += along * rng.randf_range(-0.3, 0.3) + Vector3.UP * rng.randf_range(-0.25, 0.25) + w * rng.randf_range(0.02, 0.12)
		var face := (w + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		var side := face.cross(Vector3.UP).normalized()
		var up := side.cross(face)
		var spin := rng.randf() * TAU
		var half := rng.randf_range(0.17, 0.27)
		var rt := (side * cos(spin) + up * sin(spin)) * half
		var ut := (up * cos(spin) - side * sin(spin)) * half
		b.card(leaf, p, rt, ut, (w + Vector3(0, 0.35, 0)).normalized(), _shade(greens, rng.randf(), rng, 0.05))


# ひとかたまりの茂み：暗い芯と、表面に重ねた葉の板。stretch で芯と板の散らばりを縦横に伸ばす
static func _clump(b: Look.Batch, rng: RandomNumberGenerator, c: Vector3, r: float, from: Vector3, greens: Array, lo: float, hi: float,
		half: float, stretch := Vector3(1.0, 0.85, 1.0), count := -1, core := 0.78) -> void:
	var core_col := (greens[0] as Color).lerp(greens[1], 0.35)
	b.lump(Look.Tint.new(Look.mat("foliage").mat, core_col), c, stretch * r * core, from, rng, 0.4)
	var leaf := Look.mat("leaf")
	var n := count if count > 0 else int(46.0 * r * r / (half * half) * 0.3)
	for k in n:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
		var deep := rng.randf() < 0.2
		var p := c + d * stretch * r * (rng.randf_range(0.5, 0.7) if deep else rng.randf_range(0.78, 1.0))
		# 板の向き：外向きから少し傾け、向きの回転はばらばらに
		var face := (d + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.2, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		var side := face.cross(Vector3.UP if absf(face.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := side.cross(face)
		var spin := rng.randf() * TAU
		var rt := (side * cos(spin) + up * sin(spin)) * half * rng.randf_range(0.85, 1.2)
		var ut := (up * cos(spin) - side * sin(spin)) * rt.length()
		var nrm := ((p - from).normalized() + d * 0.3).normalized()
		b.card(leaf, p, rt, ut, nrm, _shade(greens, (p.y - lo) / maxf(hi - lo, 0.01), rng, 0.25 if deep else 0.0))


# 高さ t（0 下 .. 1 上）の色。奥の葉は暗く、1枚ごとに少しばらつかせる
static func _shade(greens: Array, t: float, rng: RandomNumberGenerator, dark: float) -> Color:
	var tt := clampf(t + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	var col: Color = (greens[0] as Color).lerp(greens[1], tt * 2.0) if tt < 0.5 else (greens[1] as Color).lerp(greens[2], (tt - 0.5) * 2.0)
	col = col.darkened(dark + rng.randf_range(0.0, 0.08))
	return Color.from_hsv(wrapf(col.h + rng.randf_range(-0.012, 0.012), 0.0, 1.0), col.s, col.v)


# 枝・幹（p から q へ、太さ r0 から r1 へ細る）
static func _limb(b: Look.Batch, m: Look.Tint, p: Vector3, q: Vector3, r0: float, r1: float) -> void:
	var d := q - p
	if d.length() < 0.01:
		return
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	b.cyl(m, Transform3D(Basis(x, y, z), p), r0, d.length(), 7, r1, false)


# 置き場所ごとに決まった乱数（毎回同じ形になる）
static func _rng(pos: Vector3) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)))
	return rng
