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
	b.box(post, lying * Transform3D(Basis.IDENTITY, Vector3(0, 0.85, 0)), Vector3(0.05, 0.05, 1.94), Look.Batch.ALL)
	var lean := Transform3D(Basis(Vector3.BACK, 0.55), Vector3(FENCE_X - 0.55, 0.78, GAP_Z.y - 1.3))
	b.box(mesh, lean, Vector3(0.02, 1.7, 1.94), Look.Batch.ALL)
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
	var white := Look.plain(Color("eef0ec"), 0.45, 0.1)
	var green := Look.plain(GREEN, 0.5, 0.1)
	var dark := Look.plain(Color("2b2e31"), 0.6, 0.3)
	var glass := Look.plain(Color("2f4766"), 0.12, 0.4)
	var tire := Look.plain(Color("1e2022"), 0.9)
	# 車台と運転席
	b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0)), Vector3(6.0, 0.3, 1.8), Look.Batch.ALL)
	b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(2.25, 1.45, 0)), Vector3(1.5, 1.7, 2.0), Look.Batch.ALL)
	b.box(glass, at * Transform3D(Basis.IDENTITY, Vector3(3.01, 1.8, 0)), Vector3(0.03, 0.7, 1.8), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.box(glass, at * Transform3D(Basis.IDENTITY, Vector3(2.45, 1.8, s * 1.005)), Vector3(0.9, 0.6, 0.03), Look.Batch.ALL)
	b.box(green, at * Transform3D(Basis.IDENTITY, Vector3(2.25, 0.95, 0)), Vector3(1.52, 0.35, 2.02), Look.Batch.ALL)
	b.box(Look.plain(Color("c9ced0"), 0.4, 0.5), at * Transform3D(Basis.IDENTITY, Vector3(3.02, 0.85, 0)), Vector3(0.06, 0.3, 1.9), Look.Batch.ALL)
	b.box(Look.mat("lit", Color("ffb040")), at * Transform3D(Basis.IDENTITY, Vector3(2.4, 2.36, 0)), Vector3(0.25, 0.12, 0.9), Look.Batch.ALL)
	# 荷箱（上が丸い）と、後ろの投入口
	b.extrude(green, at * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.35, 0.7, 0)), [Vector2(-1.05, 0.0), Vector2(1.05, 0.0), Vector2(1.05, 1.5), Vector2(0.75, 1.95), Vector2(-0.75, 1.95), Vector2(-1.05, 1.5)], 3.6)
	b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 1.55, 0)), Vector3(3.62, 0.32, 2.12), Look.Batch.ALL)
	b.box(white, at * Transform3D(Basis(Vector3.BACK, -0.35), Vector3(-2.45, 1.25, 0)), Vector3(0.9, 1.7, 2.1), Look.Batch.ALL)
	b.box(dark, at * Transform3D(Basis(Vector3.BACK, -0.35), Vector3(-2.82, 0.95, 0)), Vector3(0.1, 0.8, 1.7), Look.Batch.ALL)
	for wx: float in [2.1, -1.0, -1.9]:
		for s: float in [-1.0, 1.0]:
			b.cyl(tire, at * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.45, s * 0.92)), 0.45, 0.3, 14, -1.0, true, true)
	# 荷箱の横の文字（両側）
	for s: float in [-1.0, 1.0]:
		var face := at.basis * Basis(Vector3.UP, 0.0 if s > 0.0 else PI)
		var p := at * Vector3(-0.35, 1.55, s * 1.07)
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
# 当たり判定は、フェンスと同じ体にまとめる（体を1つ増やすだけで物理の計算の順が変わり、荷台のロープの揺れ方が変わるため）
static func _street_solids(b: Look.Batch) -> void:
	var x1 := 73.45
	b.solidp(Vector3((STREET_X.x + x1) * 0.5, -0.21, (STREET_Z.x + STREET_Z.y + 1.1) * 0.5), Vector3(x1 - STREET_X.x, 0.4, STREET_Z.y + 1.1 - STREET_Z.x))
	b.solidp(Vector3((STREET_X.x + 72.75) * 0.5, 1.5, STREET_Z.y + 1.2), Vector3(72.75 - STREET_X.x, 3.0, 0.2))
	b.solidp(Vector3(STREET_X.x - 0.1, 1.5, (STREET_Z.x + STREET_Z.y) * 0.5), Vector3(0.2, 3.0, STREET_Z.y - STREET_Z.x + 1.2))


static func _text(root: Node3D, p: Vector3, words: String, pixel: float, c: Color, font: Font) -> Label3D:
	return Look.label(root, Transform3D(Basis.IDENTITY, p), words, pixel, 64, c, font, false)
