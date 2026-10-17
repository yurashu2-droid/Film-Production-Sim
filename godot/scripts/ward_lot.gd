extends RefCounted
## 敷地を「区の土地」と「映画制作班の土地」に分ける（西半分が区、東半分が班）。
##   ・区の土地：粗大ごみ置き場（dump_dressing.gd）と、清掃事務所の車庫（フォークリフト・資材。production_office.gd の北西）
##   ・境のフェンス（区の緑の網）：北の塀から南の塀まで。門の前だけ板が外れて倒れていて、班はそこから勝手に入る
##   ・南の区道：塀の外に通りを通し、区の入口（引き戸の門）とゴミ集積所を面させる。住民もゴミ収集車も来る場所に見せる
##   ・ゴミ収集車：区の入口の内側に停めてある
## 遊びの道のり（廃材の置き場所・軽トラまで）は変えない。破れ目は大きな物を運べる幅にしてある
const Look := preload("res://scripts/production_look.gd")
const Dump := preload("res://scripts/dump_dressing.gd")

const FENCE_X := 62.85                  # 境のフェンス（この西が区の土地）
const FENCE_Z := Vector2(-14.2, 36.25)  # 北の塀から南の塀まで
const GAP_Z := Vector2(7.0, 21.0)       # 破れ目（廃材置き場の門の前から、段ボール置き場の西まで。物を並べて詰める場所を空けておく）
const GATE_X := Vector2(39.6, 44.2)     # 南の塀に開けた区の入口
const WALL_Z := 36.4                    # 南の塀
const STREET_Z := Vector2(36.55, 44.5)  # 区道（車道）。その南に歩道
const STREET_X := Vector2(31.6, 73.6)   # 西の高い塀から、今の道まで
const GREEN := Color("2f7d4f")
const WARD := "みどり区"


static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "WardLot"
	parent.add_child(root)
	var font := Look.font()
	var b := Look.Batch.new()
	_fence(b, root, font)
	_gate(b, root, font)
	_truck(b, root, font, Transform3D(Basis(Vector3.UP, PI), Vector3(47.9, 0.0, 33.45)))
	_street_solids(b)
	b.build(root, "WardLot")
	var street := Look.Batch.new()
	street.no_shadow = true
	_street(street, root, font)
	street.build(root, "WardStreet")
	# 通りのゴミ集積所（区の入口の西、塀の外）
	var bags := Look.Batch.new()
	Dump.street_point(bags, root, font, Vector3(35.6, 0.0, 37.45), WALL_Z + 0.13)
	bags.build(root, "WardStreetBags")
	return root


# ---- 境のフェンス ----

static func _fence(b: Look.Batch, root: Node3D, font: Font) -> void:
	var post := Look.plain(Color("3f6b4a"), 0.5, 0.4)
	var mesh := Look.Tint.new(Dump.net_mat(), Color("4f8a5f"))
	var h := 1.8
	var step := 2.0
	var z := FENCE_Z.x
	while z < FENCE_Z.y - 0.05:
		var z2 := minf(z + step, FENCE_Z.y)
		var open := z2 > GAP_Z.x and z < GAP_Z.y
		var mid := (z + z2) * 0.5
		if not open:
			# 網の板（両面に網目）と上下の枠。当たり判定は板ごとの薄い箱
			b.boxp(mesh, Vector3(FENCE_X, h * 0.5 + 0.05, mid), Vector3(0.02, h - 0.1, z2 - z - 0.06), Look.Batch.ALL)
			for y: float in [0.06, h]:
				b.boxp(post, Vector3(FENCE_X, y, mid), Vector3(0.05, 0.05, z2 - z), Look.Batch.ALL)
			b.solidp(Vector3(FENCE_X, h * 0.5, mid), Vector3(0.12, h, z2 - z))
		if z <= GAP_Z.x or z >= GAP_Z.y:
			b.boxp(post, Vector3(FENCE_X, h * 0.5 + 0.05, z), Vector3(0.07, h + 0.1, 0.07), Look.Batch.GROUND)
		b.boxp(Look.mat("concrete", Color("a8a59a")), Vector3(FENCE_X, 0.08, z), Vector3(0.3, 0.16, 0.3), Look.Batch.GROUND)
		z = z2
	# 破れ目：網の板が2枚、倒れている（1枚は斜めに立てかけて）。切れた針金
	var lying := Transform3D(Basis(Vector3.BACK, PI * 0.5 - 0.06) * Basis(Vector3.UP, 0.12), Vector3(FENCE_X - 0.9, 0.06, GAP_Z.x + 4.2))
	b.box(mesh, lying, Vector3(0.02, 1.7, 1.94), Look.Batch.ALL)
	b.solid(lying, Vector3(0.05, 1.7, 1.94))
	b.box(post, lying * Transform3D(Basis.IDENTITY, Vector3(0, 0.85, 0)), Vector3(0.05, 0.05, 1.94), Look.Batch.ALL)
	var lean := Transform3D(Basis(Vector3.BACK, 0.55), Vector3(FENCE_X - 0.55, 0.78, GAP_Z.y - 1.3))
	b.box(mesh, lean, Vector3(0.02, 1.7, 1.94), Look.Batch.ALL)
	b.solid(lean, Vector3(0.05, 1.7, 1.94))
	b.box(post, lean * Transform3D(Basis.IDENTITY, Vector3(0, 0.85, 0)), Vector3(0.05, 0.05, 1.94), Look.Batch.ALL)
	for zz: float in [GAP_Z.x, GAP_Z.y]:
		for k in 3:
			var y := 0.4 + k * 0.5
			b.bar(Look.plain(Color("8d9396"), 0.4, 0.7), Vector3(FENCE_X, y, zz), Vector3(FENCE_X + 0.05, y - 0.15, zz + (0.25 if zz < 12.0 else -0.25)), 0.012)
	# 区の札（班の側＝東へ向けて）。破れ目の脇には「破損中」の札
	for zz: float in [-6.0, 4.0, 27.0]:
		_plate(b, root, font, Vector3(FENCE_X + 0.03, 1.2, zz), WARD + "　管理地", "関係者以外　立入禁止")
	_plate(b, root, font, Vector3(FENCE_X + 0.03, 1.2, GAP_Z.y + 1.1), "フェンス破損中", "修理の予定です　" + WARD)
	# 班が床に貼った、養生テープの矢印（破れ目へ）
	var tape := Look.plain(Color("e8e0c8"), 0.8)
	var ax := FENCE_X + 2.2
	b.boxp(tape, Vector3(ax, 0.02, 15.5), Vector3(1.6, 0.004, 0.09), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.box(tape, Transform3D(Basis(Vector3.UP, s * 0.6), Vector3(ax - 0.62, 0.021, 15.5 + s * 0.17)), Vector3(0.45, 0.004, 0.09), Look.Batch.ALL)
	var l := Look.label(root, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(ax + 0.35, 0.024, 15.5)), "近道（班）", 0.0028, 64, Color("3a3a3a"), font, false)
	l.modulate = Color(0.25, 0.25, 0.25, 0.85)


# 区の札（白地に緑の帯）。東（班の側）を向く
static func _plate(b: Look.Batch, root: Node3D, font: Font, p: Vector3, head: String, body: String) -> void:
	var face := Basis(Vector3.UP, PI * 0.5)
	b.box(Look.plain(Color("f4f2ea"), 0.6), Transform3D(face, p), Vector3(0.62, 0.42, 0.012), Look.Batch.ALL)
	b.box(Look.plain(GREEN, 0.6), Transform3D(face, p + Vector3(0.008, 0.15, 0)), Vector3(0.62, 0.12, 0.006), Look.Batch.ALL)
	Look.label(root, Transform3D(face, p + Vector3(0.013, 0.15, 0)), head, 0.0016, 64, Color.WHITE, font, false)
	Look.label(root, Transform3D(face, p + Vector3(0.009, -0.05, 0)), body, 0.0011, 64, Color("1f2a24"), font, false)


# ---- 南の塀の、区の入口（引き戸の門。閉まっている） ----

static func _gate(b: Look.Batch, root: Node3D, font: Font) -> void:
	var steel := Look.plain(Color("8d9396"), 0.4, 0.6)
	var w := GATE_X.y - GATE_X.x
	var cx := (GATE_X.x + GATE_X.y) * 0.5
	var z := WALL_Z
	for x: float in [GATE_X.x + 0.15, GATE_X.y - 0.15]:
		b.boxp(Look.mat("concrete", Color("bdb9b0")), Vector3(x, 1.0, z), Vector3(0.3, 2.0, 0.3), Look.Batch.ALL)
	# 引き戸：上下の枠と縦の格子
	for y: float in [0.12, 1.55]:
		b.boxp(steel, Vector3(cx, y, z), Vector3(w - 0.3, 0.06, 0.06), Look.Batch.ALL)
	var n := int((w - 0.3) / 0.14)
	for k in n + 1:
		b.boxp(steel, Vector3(GATE_X.x + 0.15 + k * (w - 0.3) / n, 0.83, z), Vector3(0.025, 1.43, 0.025), Look.Batch.ALL)
	for k in 6:
		var wx := GATE_X.x + 0.4 + k * (w - 0.8) / 5.0
		b.cyl(Look.plain(Color("26282a"), 0.8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.06, z - 0.04)), 0.05, 0.08, 8)
	b.solidp(Vector3(cx, 1.0, z), Vector3(w, 2.0, 0.3))
	# 門柱の看板（通りの側＝南を向く）
	var sp := Vector3(GATE_X.y + 1.3, 1.45, z + 0.14)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), sp, Vector3(1.9, 0.95, 0.03), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), sp + Vector3(0, 0.34, 0.017), Vector3(1.9, 0.26, 0.01), Look.Batch.ALL)
	_text(root, sp + Vector3(0, 0.34, 0.025), WARD + "　清掃事務所", 0.0024, Color.WHITE, font)
	_text(root, sp + Vector3(0, 0.06, 0.025), "粗大ごみの持ち込み", 0.0026, Color("1f2a24"), font)
	_text(root, sp + Vector3(0, -0.2, 0.025), "毎週土曜　9時〜12時", 0.0021, Color("1f2a24"), font)


# ---- ゴミ収集車（パッカー車）。at の +X が前 ----

static func _truck(b: Look.Batch, root: Node3D, font: Font, at: Transform3D) -> void:
	var white := Look.plain(Color("eef0ec"), 0.48)
	var green := Look.plain(GREEN, 0.5)
	var dark := Look.plain(Color("2b2e31"), 0.64)
	var glass := Look.plain(Color("304957"), 0.18)
	var tire := Look.plain(Color("25282a"), 0.84)
	var steel := Look.plain(Color("a7adb0"), 0.38, 0.8)
	var lamp := Look.plain(Color("e0e6d8"), 0.22)
	# はしご状の車台。車体の下は空け、タイヤだけ地面まで届く。
	for zz: float in [-0.65, 0.65]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, zz)), Vector3(6.0, 0.3, 0.18), Look.Batch.ALL)
		b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, zz)), Vector3(6.0, 0.3, 0.18))
	for xx: float in [-1.9, -1.0, 2.1]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(xx, 0.46, 0)), Vector3(0.15, 0.15, 1.9), Look.Batch.ALL)
		b.solid(at * Transform3D(Basis.IDENTITY, Vector3(xx, 0.46, 0)), Vector3(0.15, 0.15, 1.9))
	# 前窓を傾けたキャブオーバー。屋根、ドア枠、段差のあるバンパー。
	b.extrude(white, at, [Vector2(1.5, 0.65), Vector2(3.0, 0.65), Vector2(3.0, 1.58), Vector2(2.85, 2.18), Vector2(1.62, 2.28), Vector2(1.5, 2.1)], 2.0)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(2.23, 1.39, 0)), Vector3(1.46, 1.48, 2.0))
	b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(2.22, 2.28, 0)), Vector3(1.32, 0.08, 2.06), Look.Batch.ALL)
	b.box(glass, at * Transform3D(Basis(Vector3.BACK, 0.245), Vector3(2.94, 1.84, 0)), Vector3(0.035, 0.54, 1.76), Look.Batch.ALL)
	b.box(white, at * Transform3D(Basis(Vector3.BACK, 0.245), Vector3(2.96, 1.84, 0)), Vector3(0.04, 0.56, 0.045), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		var side := s * 1.008
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(2.18, 1.51, side)), Vector3(1.1, 1.25, 0.015), Look.Batch.ALL)
		b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(2.18, 1.5, side + s * 0.009)), Vector3(1.04, 1.19, 0.015), Look.Batch.ALL)
		b.box(glass, at * Transform3D(Basis.IDENTITY, Vector3(2.19, 1.85, side + s * 0.02)), Vector3(0.89, 0.49, 0.018), Look.Batch.ALL)
		b.box(green, at * Transform3D(Basis.IDENTITY, Vector3(2.18, 1.14, side + s * 0.02)), Vector3(1.04, 0.28, 0.018), Look.Batch.ALL)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(1.83, 1.49, side + s * 0.035)), Vector3(0.17, 0.035, 0.025), Look.Batch.ALL)
		b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(2.34, 0.59, s * 1.07)), Vector3(0.7, 0.07, 0.24), Look.Batch.ALL)
		b.bar(dark, at * Vector3(2.71, 1.89, s * 1.02), at * Vector3(2.72, 1.89, s * 1.25), 0.035)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(2.72, 1.83, s * 1.27)), Vector3(0.12, 0.23, 0.07), Look.Batch.ALL)
	b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(3.015, 1.09, 0)), Vector3(0.035, 0.3, 1.12), Look.Batch.ALL)
	for yy: float in [1.0, 1.09, 1.18]:
		b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(3.04, yy, 0)), Vector3(0.025, 0.026, 1.0), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.box(lamp, at * Transform3D(Basis.IDENTITY, Vector3(3.025, 1.08, s * 0.76)), Vector3(0.045, 0.22, 0.32), Look.Batch.ALL)
		b.box(Look.plain(Color("d68d30"), 0.28), at * Transform3D(Basis.IDENTITY, Vector3(3.027, 1.3, s * 0.84)), Vector3(0.048, 0.09, 0.14), Look.Batch.ALL)
	b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(3.07, 0.79, 0)), Vector3(0.19, 0.18, 2.1), Look.Batch.ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(3.07, 0.79, 0)), Vector3(0.19, 0.18, 2.1))
	b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(3.174, 0.8, 0)), Vector3(0.025, 0.12, 0.3), Look.Batch.ALL)
	# 小さな回転灯は不透明な台の上に載る。
	b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(2.15, 2.34, 0)), Vector3(0.24, 0.04, 0.76), Look.Batch.ALL)
	b.box(Look.plain(Color("e9a83b"), 0.24), at * Transform3D(Basis.IDENTITY, Vector3(2.15, 2.42, 0)), Vector3(0.21, 0.12, 0.7), Look.Batch.ALL)
	# 曲面を折り板で表現したパッカー箱。屋根の傾斜も薄い当たり判定で追う。
	b.extrude(green, at * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.35, 0.7, 0)), [Vector2(-1.05, 0.0), Vector2(1.05, 0.0), Vector2(1.05, 1.5), Vector2(0.75, 1.95), Vector2(-0.75, 1.95), Vector2(-1.05, 1.5)], 3.6)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 1.45, 0)), Vector3(3.6, 1.5, 2.1))
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 2.4, 0)), Vector3(3.6, 0.5, 1.5))
	for s: float in [-1.0, 1.0]:
		b.solid(at * Transform3D(Basis(Vector3.RIGHT, s * 0.59), Vector3(-0.35, 2.425, s * 0.9)), Vector3(3.6, 0.04, 0.54))
		b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 1.55, s * 1.055)), Vector3(3.56, 0.32, 0.02), Look.Batch.ALL)
		for xx: float in [-1.78, 1.12]:
			b.box(green, at * Transform3D(Basis.IDENTITY, Vector3(xx, 1.47, s * 1.08)), Vector3(0.07, 1.4, 0.06), Look.Batch.ALL)
		b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(-0.4, 0.86, s * 1.075)), Vector3(2.5, 0.06, 0.035), Look.Batch.ALL)
	# 後端の投入口は、左右の厚い頬・上の枠・底の受け皿で囲う。口を箱で埋めない。
	var intake := Basis(Vector3.BACK, -0.3)
	for s: float in [-1.0, 1.0]:
		var cheek := at * Transform3D(intake, Vector3(-2.48, 1.35, s * 0.98))
		b.box(white, cheek, Vector3(0.82, 1.65, 0.16), Look.Batch.ALL)
		b.solid(cheek, Vector3(0.82, 1.65, 0.16))
		b.box(Look.plain(Color("b74b32"), 0.36), at * Transform3D(Basis.IDENTITY, Vector3(-2.95, 0.96, s * 0.83)), Vector3(0.06, 0.16, 0.12), Look.Batch.ALL)
		b.bar(dark, at * Vector3(-1.98, 1.0, s * 1.1), at * Vector3(-2.4, 2.02, s * 1.1), 0.085)
	b.box(white, at * Transform3D(intake, Vector3(-2.23, 2.12, 0)), Vector3(0.82, 0.17, 1.85), Look.Batch.ALL)
	b.solid(at * Transform3D(intake, Vector3(-2.23, 2.12, 0)), Vector3(0.82, 0.17, 1.85))
	b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(-2.32, 1.34, 0)), Vector3(0.08, 1.15, 1.78), Look.Batch.ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-2.32, 1.34, 0)), Vector3(0.08, 1.15, 1.78))
	b.box(steel, at * Transform3D(Basis(Vector3.BACK, -0.12), Vector3(-2.67, 0.72, 0)), Vector3(0.8, 0.14, 1.82), Look.Batch.ALL)
	b.solid(at * Transform3D(Basis(Vector3.BACK, -0.12), Vector3(-2.67, 0.72, 0)), Vector3(0.8, 0.14, 1.82))
	# タイヤは肉厚の黒い外周と、奥まった金属のハブ。軸方向の中心を左右でそろえる。
	for wx: float in [2.1, -1.0, -1.9]:
		for s: float in [-1.0, 1.0]:
			var hub := Vector3(wx, 0.45, s * 1.02)
			var wheel_basis := Basis(Vector3.RIGHT, PI * 0.5)
			b.cyl(tire, at * Transform3D(wheel_basis, hub + Vector3(0, 0, 0.16)), 0.45, 0.32, 16, -1.0, true, true)
			b.solid(at * Transform3D(Basis.IDENTITY, hub), Vector3(0.82, 0.84, 0.32))
			b.cyl(steel, at * Transform3D(wheel_basis, hub + Vector3(0, 0, s * 0.166 + 0.018)), 0.25, 0.036, 12, -1.0, true, true)
			b.cyl(dark, at * Transform3D(wheel_basis, hub + Vector3(0, 0, s * 0.19 + 0.018)), 0.095, 0.036, 10, -1.0, true, true)
	# 荷箱の横の文字（両側）
	for s: float in [-1.0, 1.0]:
		var face := at.basis * Basis(Vector3.UP, 0.0 if s > 0.0 else PI)
		var p := at * Vector3(-0.35, 1.55, s * 1.075)
		Look.label(root, Transform3D(face, p), WARD + "　清掃事務所", 0.0042, 64, GREEN, font, false)


# ---- 南の区道（車道と歩道、白線、止まれ） ----

static func _street(b: Look.Batch, root: Node3D, font: Font) -> void:
	b.quad_up(Look.mat("asphalt", Color("4a4e50")), STREET_X.x, STREET_X.y, STREET_Z.x, STREET_Z.y, 0.008)
	var paving := Look.mat("paving", Color("aca698"))
	b.quad_up(paving, STREET_X.x, STREET_X.y - 0.9, STREET_Z.y, STREET_Z.y + 1.1, 0.12)
	b.boxp(Look.mat("concrete", Color("d6d1c4")), Vector3((STREET_X.x + STREET_X.y - 0.9) * 0.5, 0.06, STREET_Z.y), Vector3(STREET_X.y - 0.9 - STREET_X.x, 0.12, 0.12), Look.Batch.GROUND)
	var white := Look.mat("paint", Color("ece6d2"))
	b.strip(white, Vector3(STREET_X.x, 0, STREET_Z.x + 0.35), Vector3(STREET_X.y - 1.2, 0, STREET_Z.x + 0.35), 0.12, 0.016)
	b.strip(white, Vector3(STREET_X.x, 0, STREET_Z.y - 0.3), Vector3(STREET_X.y - 1.2, 0, STREET_Z.y - 0.3), 0.12, 0.016)
	# 今の道へ出る手前の、止まれの線と文字
	b.strip(white, Vector3(STREET_X.y - 1.6, 0, STREET_Z.x + 0.4), Vector3(STREET_X.y - 1.6, 0, STREET_Z.y - 0.35), 0.4, 0.017)
	Look.label(root, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(STREET_X.y - 3.4, 0.022, (STREET_Z.x + STREET_Z.y) * 0.5)), "止まれ", 0.014, 128, Color("ece6d2"), font, false)


# 歩けない場所に落ちないよう、床と、通りの南と西の見えない壁。今の道（x 73.5 から東）の床とは重ねず、高さも道の床にそろえる。
# 当たり判定は、フェンスなどと同じ体（WardLot）に入れている。別の体に分けてもよい
# （体の数・作る順が変わっても、荷台のロープの確認 carton_rope_test.gd の結果は変わらない）
static func _street_solids(b: Look.Batch) -> void:
	# 歩道の上面 y=0.12 に合わせる。道路の床の上へ薄く重ねる。
	b.solidp(Vector3((STREET_X.x + STREET_X.y - 0.9) * 0.5, 0.055, STREET_Z.y + 0.55), Vector3(STREET_X.y - 0.9 - STREET_X.x, 0.13, 1.1))
	var x1 := 73.45
	b.solidp(Vector3((STREET_X.x + x1) * 0.5, -0.21, (STREET_Z.x + STREET_Z.y + 1.1) * 0.5), Vector3(x1 - STREET_X.x, 0.4, STREET_Z.y + 1.1 - STREET_Z.x))
	b.solidp(Vector3((STREET_X.x + 72.75) * 0.5, 1.5, STREET_Z.y + 1.2), Vector3(72.75 - STREET_X.x, 3.0, 0.2))
	b.solidp(Vector3(STREET_X.x - 0.1, 1.5, (STREET_Z.x + STREET_Z.y) * 0.5), Vector3(0.2, 3.0, STREET_Z.y - STREET_Z.x + 1.2))


static func _text(root: Node3D, p: Vector3, words: String, pixel: float, c: Color, font: Font) -> Label3D:
	return Look.label(root, Transform3D(Basis.IDENTITY, p), words, pixel, 64, c, font, false)
