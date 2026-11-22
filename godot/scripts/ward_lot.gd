extends RefCounted
## 敷地を「区の土地」と「映画制作班の土地」に分ける（西半分が区、東半分が班）。
##   ・区の土地：粗大ごみ置き場（dump_dressing.gd）と、清掃事務所の車庫（フォークリフト・資材。production_office.gd の北西）
##   ・境のフェンス（区の緑の網）：北の塀から南の塀まで。ヤードの金網の穴の前だけ板が外れて倒れていて、班はそこから勝手に入る
##     （ヤードの本当の入口は南の区道の側。会社の側には入口が無く、金網をペンチで切った穴がある。dump_dressing.gd）
##   ・南の区道：塀の外に通りを通し、区の入口（引き戸の門）とゴミ集積所を面させる。住民もゴミ収集車も来る場所に見せる
##   ・文字の看板は置かない。札は板と色の帯と絵記号（Look.picto）だけ
##   ・ゴミ収集車：区の入口の内側に停めてある
## 遊びの道のり（廃材の置き場所・軽トラまで）は変えない。破れ目は大きな物を運べる幅にしてある
const Look := preload("res://scripts/production_look.gd")
const Dump := preload("res://scripts/dump_dressing.gd")

const FENCE_X := 62.85                  # 境のフェンス（この西が区の土地）
const FENCE_Z := Vector2(-14.2, 36.25)  # 北の塀から南の塀まで
const GAP_Z := Vector2(7.0, 21.0)       # 破れ目（廃材置き場の金網の穴の前から、段ボール置き場の西まで。物を並べて詰める場所を空けておく）
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
	var b := Look.Batch.new()
	_fence(b, root)
	_gate(b, root)
	_truck(b, Transform3D(Basis(Vector3.UP, PI), Vector3(47.9, 0.0, 33.45)))
	_street_solids(b)
	b.build(root, "WardLot")
	var street := Look.Batch.new()
	street.no_shadow = true
	_street(street)
	street.build(root, "WardStreet")
	# 通りのゴミ集積所（区の入口の西、塀の外）
	var bags := Look.Batch.new()
	Dump.street_point(bags, root, Vector3(35.6, 0.0, 37.45), WALL_Z + 0.13)
	bags.build(root, "WardStreetBags")
	return root


# ---- 境のフェンス ----

static func _fence(b: Look.Batch, root: Node3D) -> void:
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
	# 区の札（班の側＝東へ向けて）。白地に緑の帯と、進入禁止の絵
	for zz: float in [-6.0, 4.0, 27.0]:
		_plate(b, root, Vector3(FENCE_X + 0.03, 1.2, zz))


# 区の札（白地に緑の帯、進入禁止の絵）。東（班の側）を向く。針金で網に留める
static func _plate(b: Look.Batch, root: Node3D, p: Vector3) -> void:
	var face := Basis(Vector3.UP, PI * 0.5)
	b.box(Look.plain(Color("f4f2ea"), 0.6), Transform3D(face, p), Vector3(0.62, 0.42, 0.012), Look.Batch.ALL)
	b.box(Look.plain(GREEN, 0.6), Transform3D(face, p + Vector3(0.008, 0.15, 0)), Vector3(0.62, 0.12, 0.006), Look.Batch.ALL)
	for dz: float in [-0.27, 0.27]:
		for dy: float in [-0.17, 0.17]:
			b.bar(Look.plain(Color("c9cfd1"), 0.35, 0.8), p + Vector3(0.008, dy, dz), p + Vector3(-0.03, dy, dz), 0.006)
	Look.picto(root, Transform3D(face, p + Vector3(0.0068, -0.05, 0)), "no_entry", Vector2(0.26, 0.26))


# ---- 南の塀の、区の入口（引き戸の門。閉まっている） ----

static func _gate(b: Look.Batch, root: Node3D) -> void:
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
	# 門柱の看板（通りの側＝南を向く）：緑の帯と、ごみ袋の絵（区の清掃事務所の入口）
	var sp := Vector3(GATE_X.y + 1.3, 1.45, z + 0.14)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), sp, Vector3(1.9, 0.95, 0.03), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), sp + Vector3(0, 0.34, 0.017), Vector3(1.9, 0.26, 0.01), Look.Batch.ALL)
	Look.picto(root, Transform3D(Basis.IDENTITY, sp + Vector3(0, -0.1, 0.0158)), "bag", Vector2(0.5, 0.5))


# ---- ゴミ収集車（パッカー車）。at の +X が前 ----

static func _truck(b: Look.Batch, at: Transform3D) -> void:
	var white := Look.plain(Color("eef0ec"), 0.48)
	var green := Look.plain(GREEN, 0.5)
	var dark := Look.plain(Color("2b2e31"), 0.64)
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
	_truck_cab_shell(b, at, white, green)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(2.23, 1.39, 0)), Vector3(1.46, 1.48, 2.0))
	b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(2.22, 2.28, 0)), Vector3(1.32, 0.08, 2.06), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(1.83, 1.49, s * 1.009)), Vector3(0.17, 0.035, 0.025), Look.Batch.ALL)
		b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(2.34, 0.59, s * 1.07)), Vector3(0.7, 0.07, 0.24), Look.Batch.ALL)
		b.bar(dark, at * Vector3(2.79, 1.89, s * 0.99), at * Vector3(2.72, 1.89, s * 1.25), 0.035)
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
	# 荷箱の断面。肩を二段で折り、側板と屋根の間に細い反射面を作る。
	var shell := [Vector2(-0.99, 0), Vector2(0.99, 0), Vector2(1.05, 0.10),
			Vector2(1.05, 1.43), Vector2(0.98, 1.66), Vector2(0.79, 1.90),
			Vector2(0.66, 1.95), Vector2(-0.66, 1.95), Vector2(-0.79, 1.90),
			Vector2(-0.98, 1.66), Vector2(-1.05, 1.43), Vector2(-1.05, 0.10)]
	var crosswise := Basis(Vector3.UP, PI * 0.5)
	b.extrude(green, at * Transform3D(crosswise, Vector3(-0.35, 0.7, 0)), shell, 3.6)
	var frame := Look.plain(Color("376b4d"), 0.55)
	for xx: float in [-2.09, 1.37]:
		b.extrude(frame, at * Transform3D(crosswise.scaled(Vector3(1, 1.005, 1.022)),
				Vector3(xx, 0.7, 0)), shell, 0.09)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 1.45, 0)), Vector3(3.6, 1.5, 2.1))
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 2.4, 0)), Vector3(3.6, 0.5, 1.5))
	for s: float in [-1.0, 1.0]:
		b.solid(at * Transform3D(Basis(Vector3.RIGHT, s * 0.59), Vector3(-0.35, 2.425, s * 0.9)), Vector3(3.6, 0.04, 0.54))
		b.box(white, at * Transform3D(Basis.IDENTITY, Vector3(-0.35, 1.55, s * 1.053)), Vector3(3.38, 0.20, 0.008), Look.Batch.ALL)
		for yy: float in [1.14, 1.98]:
			b.extrude(frame, at * Transform3D(Basis.IDENTITY, Vector3(0, yy, s * 1.062)),
					[Vector2(-1.98, -0.034), Vector2(1.19, -0.034), Vector2(1.28, 0),
					Vector2(1.19, 0.034), Vector2(-1.98, 0.034), Vector2(-2.03, 0)], 0.034)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(-1.42, 0.92, s * 0.99)), Vector3(1.96, 0.075, 0.26), Look.Batch.ALL)
	_truck_hopper(b, at, white, dark, steel)
	# タイヤは肉厚の黒い外周と、奥まった金属のハブ。軸方向の中心を左右でそろえる。
	for wx: float in [2.1, -1.0, -1.9]:
		for s: float in [-1.0, 1.0]:
			var hub := Vector3(wx, 0.45, s * 1.02)
			var wheel_basis := Basis(Vector3.RIGHT, s * PI * 0.5)
			b.cyl(tire, at * Transform3D(wheel_basis, hub - Vector3(0, 0, s * 0.16)), 0.415, 0.045, 20, 0.45, false, true)
			b.cyl(tire, at * Transform3D(wheel_basis, hub - Vector3(0, 0, s * 0.115)), 0.45, 0.23, 20, -1.0, false)
			b.cyl(tire, at * Transform3D(wheel_basis, hub + Vector3(0, 0, s * 0.115)), 0.45, 0.045, 20, 0.415)
			b.solid(at * Transform3D(Basis.IDENTITY, hub), Vector3(0.82, 0.84, 0.32))
			b.cyl(steel, at * Transform3D(wheel_basis, hub + Vector3(0, 0, s * 0.161)), 0.26, 0.031, 16, 0.23)
			b.cyl(dark, at * Transform3D(wheel_basis, hub + Vector3(0, 0, s * 0.193)), 0.16, 0.014, 14)
			b.cyl(steel, at * Transform3D(wheel_basis, hub + Vector3(0, 0, s * 0.208)), 0.086, 0.031, 10)


static func _truck_cab_shell(b: Look.Batch, at: Transform3D, paint: Look.Tint, stripe: Look.Tint) -> void:
	var cab := [Vector2(1.5, 0.65), Vector2(3.0, 0.65), Vector2(3.0, 1.58),
			Vector2(2.85, 2.18), Vector2(1.62, 2.28), Vector2(1.5, 2.1)]
	var side_opening := [Vector2(1.69, 1.62), Vector2(2.68, 1.62), Vector2(2.77, 1.71),
			Vector2(2.68, 2.065), Vector2(1.76, 2.14), Vector2(1.69, 2.07)]
	for edge in cab.size():
		if edge == 2:
			continue # フロントガラスの開口がある面は下で作る。
		var p: Vector2 = cab[edge]
		var q: Vector2 = cab[(edge + 1) % cab.size()]
		b.poly_out(paint, [at * Vector3(p.x, p.y, -1), at * Vector3(q.x, q.y, -1),
				at * Vector3(q.x, q.y, 1), at * Vector3(p.x, p.y, 1)],
				at.basis * Vector3(q.y - p.y, p.x - q.x, 0))
	for s: float in [-1.0, 1.0]:
		var side := cab.map(func(p: Vector2) -> Vector3: return Vector3(p.x, p.y, s))
		var opening := side_opening.map(func(p: Vector2) -> Vector3: return Vector3(p.x, p.y, s))
		_truck_glazing(b, at, side, opening, Vector3(0, 0, s), paint)
		# 白い側板に塗装した帯。立体の枠からは離す。
		var z := s * 1.001
		b.poly_out(stripe, [at * Vector3(1.66, 1.00, z), at * Vector3(2.70, 1.00, z),
				at * Vector3(2.70, 1.28, z), at * Vector3(1.66, 1.28, z)], at.basis * Vector3(0, 0, s))
		# 傾斜は X = 3 - (Y - 1.58) / 4。中央には車体色の支柱を残す。
		var windshield_panel := [Vector3(3.0, 1.58, 0), Vector3(3.0, 1.58, s),
				Vector3(2.85, 2.18, s), Vector3(2.85, 2.18, 0)]
		var windshield_opening := [Vector3(2.98, 1.66, s * 0.033), Vector3(2.98, 1.66, s * 0.88),
				Vector3(2.86875, 2.105, s * 0.86), Vector3(2.86875, 2.105, s * 0.033)]
		_truck_glazing(b, at, windshield_panel, windshield_opening, Vector3(1, 0.25, 0).normalized(), paint)


static func _truck_glazing(b: Look.Batch, at: Transform3D, panel: Array, opening: Array,
		local_normal: Vector3, paint: Look.Tint) -> void:
	var edge_paint := Look.plain(Color("a5b3b3"), 0.58)
	var rubber := Look.plain(Color("252f34"), 0.86)
	var glass := Look.plain(Color("304957"), 0.18)
	var normal := at.basis * local_normal
	var cutout := opening.map(func(p: Vector3) -> Vector3: return at * p)
	var center := Vector3.ZERO
	for p: Vector3 in cutout:
		center += p
	center /= cutout.size()
	var rim: Array[Vector3] = []
	var pane: Array[Vector3] = []
	for p: Vector3 in cutout:
		rim.append(p.move_toward(center, 0.035) - normal * 0.046)
		pane.append(p.move_toward(center, 0.064) - normal * 0.051)
	for i in cutout.size():
		var j := (i + 1) % cutout.size()
		b.poly_out(paint, [at * panel[i], at * panel[j], cutout[j], cutout[i]], normal)
		# 折り返しの板金、その奥のパッキン、さらに内側のガラス。
		b.poly_out(edge_paint, [cutout[i], cutout[j], rim[j], rim[i]], normal)
		b.poly_out(rubber, [rim[i], rim[j], pane[j], pane[i]], normal)
	b.poly_out(glass, pane, normal)


static func _truck_hopper(b: Look.Batch, at: Transform3D, white: Look.Tint, dark: Look.Tint, steel: Look.Tint) -> void:
	var liner := Look.plain(Color("535b53"), 0.78, 0.25)
	var blade := Look.plain(Color("727971"), 0.69, 0.25)
	var amber := Look.plain(Color("d88b34"), 0.38)
	var red := Look.plain(Color("a8392b"), 0.38)
	var cheek_profile := [Vector2(-3.02, 0.67), Vector2(-3.04, 0.88), Vector2(-2.65, 2.08),
			Vector2(-2.44, 2.27), Vector2(-2.03, 2.36), Vector2(-2.03, 0.74)]
	var collision_slope := Basis(Vector3.BACK, -0.3)
	for s: float in [-1.0, 1.0]:
		b.extrude(white, at * Transform3D(Basis.IDENTITY, Vector3(0, 0, s * 0.975)), cheek_profile, 0.19)
		b.solid(at * Transform3D(collision_slope, Vector3(-2.48, 1.35, s * 0.98)), Vector3(0.82, 1.65, 0.16))
		# 縁から奥へ絞った側板。投入口から受け皿と押し板が見える。
		b.poly_out(liner, [at * Vector3(-3.02, 0.81, s * 0.88), at * Vector3(-2.61, 2.07, s * 0.88),
				at * Vector3(-2.15, 1.97, s * 0.72), at * Vector3(-2.28, 0.63, s * 0.72)],
				at.basis * Vector3(0, 0, -s))
		var low := Vector3(-1.90, 0.99, s * 1.08)
		var high := Vector3(-2.45, 2.05, s * 1.09)
		var pivot := low.lerp(high, 0.67)
		b.bar(dark, at * low, at * pivot, 0.105, Look.Batch.ALL)
		b.bar(steel, at * pivot, at * high, 0.055, Look.Batch.ALL)
		for mount: Vector3 in [low, high]:
			b.box(dark, at * Transform3D(Basis.IDENTITY, mount), Vector3(0.18, 0.18, 0.10), Look.Batch.ALL)
			b.cyl(steel, at * Transform3D(Basis(Vector3.RIGHT, s * PI * 0.5),
					mount + Vector3(0, 0, s * 0.052)), 0.049, 0.021, 10)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(-3.035, 0.76, s * 0.99)), Vector3(0.10, 0.23, 0.21), Look.Batch.ALL)
		b.box(red, at * Transform3D(Basis.IDENTITY, Vector3(-3.091, 0.71, s * 0.99)), Vector3(0.022, 0.084, 0.16), Look.Batch.ALL)
		b.box(amber, at * Transform3D(Basis.IDENTITY, Vector3(-3.091, 0.814, s * 0.99)), Vector3(0.022, 0.064, 0.16), Look.Batch.ALL)
	var cap_profile := [Vector2(-2.69, 2.03), Vector2(-2.68, 2.16), Vector2(-2.50, 2.29),
			Vector2(-2.06, 2.37), Vector2(-2.06, 2.05)]
	b.extrude(white, at, cap_profile, 1.85)
	b.extrude(dark, at, [Vector2(-2.61, 2.05), Vector2(-2.16, 2.06),
			Vector2(-2.16, 1.94), Vector2(-2.54, 1.98)], 1.64)
	# 折れた板で漏斗の底を組み、入口の擦れやすい縁に鋼材を巻く。
	b.extrude(liner, at, [Vector2(-3.06, 0.75), Vector2(-3.04, 0.86), Vector2(-2.93, 0.88),
			Vector2(-2.57, 0.72), Vector2(-2.57, 0.64)], 1.77)
	b.extrude(liner, at, [Vector2(-2.57, 0.64), Vector2(-2.57, 0.72),
			Vector2(-2.29, 0.69), Vector2(-2.29, 0.60)], 1.77)
	b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(-3.041, 0.85, 0)), Vector3(0.085, 0.075, 1.79), Look.Batch.ALL)
	b.extrude(blade, at, [Vector2(-2.57, 1.89), Vector2(-2.18, 1.96), Vector2(-2.17, 1.11),
			Vector2(-2.30, 1.14), Vector2(-2.48, 1.59)], 1.48)
	b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(-2.258, 1.13, 0)), Vector3(0.12, 0.065, 1.49), Look.Batch.ALL)
	b.extrude(liner, at, [Vector2(-2.49, 0.66), Vector2(-2.24, 1.18),
			Vector2(-2.13, 1.18), Vector2(-2.13, 0.65)], 1.50)
	b.solid(at * Transform3D(collision_slope, Vector3(-2.23, 2.12, 0)), Vector3(0.82, 0.17, 1.85))
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-2.32, 1.34, 0)), Vector3(0.08, 1.15, 1.78))
	b.solid(at * Transform3D(Basis(Vector3.BACK, -0.12), Vector3(-2.67, 0.72, 0)), Vector3(0.8, 0.14, 1.82))


# ---- 南の区道（車道と歩道、白線、止まれ） ----

static func _street(b: Look.Batch) -> void:
	b.quad_up(Look.mat("asphalt", Color("4a4e50")), STREET_X.x, STREET_X.y, STREET_Z.x, STREET_Z.y, 0.008)
	var paving := Look.mat("paving", Color("aca698"))
	b.quad_up(paving, STREET_X.x, STREET_X.y - 0.9, STREET_Z.y, STREET_Z.y + 1.1, 0.12)
	b.boxp(Look.mat("concrete", Color("d6d1c4")), Vector3((STREET_X.x + STREET_X.y - 0.9) * 0.5, 0.06, STREET_Z.y), Vector3(STREET_X.y - 0.9 - STREET_X.x, 0.12, 0.12), Look.Batch.GROUND)
	var white := Look.mat("paint", Color("ece6d2"))
	b.strip(white, Vector3(STREET_X.x, 0, STREET_Z.x + 0.35), Vector3(STREET_X.y - 1.2, 0, STREET_Z.x + 0.35), 0.12, 0.016)
	b.strip(white, Vector3(STREET_X.x, 0, STREET_Z.y - 0.3), Vector3(STREET_X.y - 1.2, 0, STREET_Z.y - 0.3), 0.12, 0.016)
	# 今の道へ出る手前の、止まれの線
	b.strip(white, Vector3(STREET_X.y - 1.6, 0, STREET_Z.x + 0.4), Vector3(STREET_X.y - 1.6, 0, STREET_Z.y - 0.35), 0.4, 0.017)


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
