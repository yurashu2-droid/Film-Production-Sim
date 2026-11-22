extends RefCounted
## Coordinates are in the shared world's space; this root remains at the origin.
## 拠点の事務所・駐車場・道・敷地の小物。見た目は production_look.gd の Batch でマテリアルごとにまとめる。
##   ・事務所は屋根なしのまま（三人称カメラが入る）。入口の隙間 x 69.85..74.15（z=4）はそのまま
##   ・小物は実体のある部品に当たり判定を付ける。入口・積込口・機材置場・道路の通路は空ける
##   ・文字の看板・路面の文字は置かない（浮いた文字は使わない）。札は板と色と絵記号（Look.picto）だけ。
##     例外は、書割の社屋の社名（CompanyNameSign）。そのまま出す（会社の名前として呼ぶのは、入口の上に掛けた段ボールの看板。features/company_sign.gd）
const Look := preload("res://scripts/production_look.gd")
const Foliage := preload("res://scripts/foliage.gd")
const VENDING_MODEL := preload("res://assets/production/scrap/S059_vending_machine_jp.glb")
const ALL := 63
const GROUND := 55
const FACADE := 23
# 事務所の正面の「書割の社屋」（2階建てに見える正面だけの板）。事務所の中にいる人の視点からは、この層を映さない
# （屋根の無い事務所に三人称のカメラが入るため。features/office_facade.gd）。撮影カメラには、いつでも映る
const FACADE_LAYER := 1 << 14

const CONTRACT_POINT := Vector3(72, 0, 1.5)
const TRUCK_POINT := Vector3(82, 0, 18)
const SPAWN_POINT := Vector3(72, 0.1, 5)
const ROAD_END := 81.0
# 機材置き場（軽トラの北東の囲い。x, z, 幅, 奥行き）。会社の機材をここに並べておく。
# 並べ方は production_flow.gd の GEAR_HOME。出発すると、機材はいっしょに現場へ運ばれる
const GEAR_YARD := Rect2(82.0, 11.75, 4.0, 3.7)
# 監督の机（窓口の机の上）。のぞき箱と、発注の電話の置き場所。物そのものは production_director.gd が作る
const DESK_TOP := 0.96
const PEEP_BOX := Vector3(70.95, 0.96, 0.14)
const ORDER_PHONE := Vector3(71.9, 0.96, 0.3)

const TEAL := Color("4e777c")
const CREAM := Color("d4c4a1")
const WOOD := Color("94704a")
const RUST := Color("8f5943")
const PAPER := Color("e8ddbf")


static func build(parent: Node3D, font: Font) -> Node3D:
	var root := Node3D.new()
	root.name = "ProductionOffice"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_ground(root, rng)
	var office := Look.Batch.new()
	_office(office, root)
	office.build(root, "OfficeBuilding")
	_facade(root, font)
	_lot(root, rng)
	var road := Look.Batch.new()
	_road(road)
	_road_gate(road, root)
	road.build(root, "RoadDressing")
	return root


static func P(c: Color, rough := 0.85, metal := 0.0) -> Look.Tint:
	return Look.plain(c, rough, metal)


# 同じ高さに並ぶ窓の上下と間を板で組み、開口の深さを板厚で出す。
static func _window_wall(b: Look.Batch, mat: Look.Tint, wall: Rect2, z: float, depth: float,
		centers: Array, opening_y: float, opening: Vector2) -> void:
	var low := opening_y - opening.y * 0.5
	var high := opening_y + opening.y * 0.5
	b.boxp(mat, Vector3(wall.get_center().x, (wall.position.y + low) * 0.5, z),
			Vector3(wall.size.x, low - wall.position.y, depth), ALL)
	b.boxp(mat, Vector3(wall.get_center().x, (high + wall.end.y) * 0.5, z),
			Vector3(wall.size.x, wall.end.y - high, depth), ALL)
	var left := wall.position.x
	for x: float in centers:
		var right := x - opening.x * 0.5
		b.boxp(mat, Vector3((left + right) * 0.5, opening_y, z),
				Vector3(right - left, opening.y, depth), ALL)
		left = x + opening.x * 0.5
	b.boxp(mat, Vector3((left + wall.end.x) * 0.5, opening_y, z),
			Vector3(wall.end.x - left, opening.y, depth), ALL)


static func _seated_window(b: Look.Batch, frame: Look.Tint, glass: Look.Tint, center: Vector3,
		opening: Vector2, border: float, depth: float) -> void:
	for side: float in [-1.0, 1.0]:
		b.boxp(frame, center + Vector3(side * (opening.x - border) * 0.5, 0, 0),
				Vector3(border, opening.y, depth), ALL)
		b.boxp(frame, center + Vector3(0, side * (opening.y - border) * 0.5, 0),
				Vector3(opening.x - 2.0 * border, border, depth), ALL)
	b.boxp(glass, center - Vector3(0, 0, depth * 0.22),
			Vector3(opening.x - 2.0 * border, opening.y - 2.0 * border, 0.014), ALL)


# 棒に沿った箱。Batch.xf も適用されるので、倒して置く背景小物にも使える。
static func _solid_bar(b: Look.Batch, p: Vector3, q: Vector3, thickness: Vector2) -> void:
	var delta := q - p
	var up := Vector3.UP if absf(delta.normalized().y) < 0.99 else Vector3.RIGHT
	b.solid(Transform3D(Basis.looking_at(delta, up), (p + q) * 0.5), Vector3(thickness.x, thickness.y, delta.length()))


# 中央をふさがない12角の輪。タイヤ・車輪・縁の、厚みのある部材だけを作る。
static func _ring(b: Look.Batch, material: Look.Tint, at: Transform3D, radius: float, thickness: float, collides: bool) -> void:
	for k in 12:
		var a := TAU * k / 12.0
		var next := TAU * (k + 1) / 12.0
		var p := at * Vector3(cos(a) * radius, 0, sin(a) * radius)
		var q := at * Vector3(cos(next) * radius, 0, sin(next) * radius)
		b.bar(material, p, q, thickness, ALL)
		if collides:
			_solid_bar(b, p, q, Vector2(thickness, thickness))


# ---- 地面：コンクリートの敷地、駐車場のアスファルト、道、白線、染み、水たまり ----

static func _ground(root: Node3D, rng: RandomNumberGenerator) -> void:
	var g := Look.Batch.new()
	g.no_shadow = true
	# 車道の床を歩道と門のところまで通す。
	var road_end := ROAD_END
	g.solidp(Vector3(62, -0.2, 11), Vector3(60, 0.4, 50))
	g.solidp(Vector3(80, -0.21, (33.0 + road_end) * 0.5), Vector3(13, 0.4, road_end - 33.0))
	g.quad_up(Look.mat("concrete", Color("9a958a")), 32.0, 92.0, -14.0, 36.0, 0.0)
	var asp := Look.mat("asphalt", Color("45494c"))
	g.quad_up(asp, 74.0, 86.0, 11.5, 24.0, 0.010)
	g.quad_up(asp, 73.5, 86.5, 24.0, road_end + 8.0, 0.010)
	# 新しい舗装の継ぎはぎ（色の違う長方形）
	var patch := Look.mat("asphalt", Color("2e3133"))
	g.quad_up(patch, 79.0, 83.5, 33.2, 35.0, 0.0115)
	g.quad_up(patch, 75.2, 77.0, 52.0, 56.5, 0.0115)
	g.quad_up(Look.mat("concrete", Color("8c887c")), 38.0, 45.0, -5.0, -1.6, 0.004)
	g.quad_up(Look.mat("concrete", Color("b2ad9f")), 84.0, 90.5, 6.0, 9.6, 0.004)
	# 事務所の前の歩道（敷石）
	var paving := Look.mat("paving", Color("aca698"))
	g.quad_up(paving, 63.0, 81.0, 4.3, 6.7, 0.012)
	g.quad_up(paving, 70.4, 73.6, 6.7, 9.2, 0.012)
	g.quad_up(Look.mat("concrete", Color("c4bfb1")), 63.0, 81.0, 6.7, 6.95, 0.013)
	# 道の脇の歩道。見える段差に床を合わせる（区道の出口は空ける）
	var side := Look.Batch.new()
	side.no_shadow = true
	# 西側の歩道は、区道（ward_lot.gd）の出口のところで切れる
	for sd: Array in [[72.725, 73.55, 45.6], [86.45, 87.275, 36.4]]:
		side.quad_up(paving, sd[0], sd[1], sd[2], road_end, 0.12)
		side.solidp(Vector3((sd[0] + sd[1]) * 0.5, 0.06, (sd[2] + road_end) * 0.5), Vector3(sd[1] - sd[0], 0.12, road_end - sd[2]))
		var edge_x: float = sd[0] if sd[0] > 80.0 else sd[1]
		var curb := Look.mat("concrete", Color("d6d1c4"))
		var curb_len: float = road_end - sd[2]
		var count := ceili(curb_len / 1.5)
		var section := curb_len / count
		for k in count:
			side.boxp(curb, Vector3(edge_x, 0.06, sd[2] + section * (k + 0.5)),
					Vector3(0.12, 0.12, section - 0.012), GROUND)
		var gutter_x := edge_x + (0.115 if edge_x < 80.0 else -0.115)
		var gutter := Look.mat("concrete", Color("62656a"))
		side.quad_up(gutter, gutter_x - 0.08, gutter_x + 0.08, sd[2], road_end, 0.0122)
		var iron := P(Color("666b6d"), 0.62, 0.5)
		for z: float in [sd[2] + 4.2, (sd[2] + road_end) * 0.5 + 2.0, 78.3]:
			side.quad_up(P(Color("2b2e31")), gutter_x - 0.078, gutter_x + 0.078, z - 0.22, z + 0.22, 0.013)
			for rib in 8:
				side.boxp(iron, Vector3(gutter_x, 0.014, z - 0.19 + rib * 0.054),
						Vector3(0.154, 0.008, 0.024), GROUND)
	# 白線・黄線（かすれた塗装）
	var white := Look.mat("paint", Color("ece6d2"))
	var cream := Look.mat("paint", Color("e6d9a4"))
	var yellow := Look.mat("paint", Color("e0b43a"))
	# 社用車の駐車枠。北東の角は、機材置き場の囲いに譲る
	var yard0: Vector2 = GEAR_YARD.position
	var yard1: Vector2 = GEAR_YARD.end
	g.strip(cream, Vector3(77.3, 0, 13.4), Vector3(77.3, 0, 22.8), 0.12, 0.018)
	g.strip(cream, Vector3(83.2, 0, yard1.y + 1.35), Vector3(83.2, 0, 22.8), 0.12, 0.018)
	g.strip(cream, Vector3(77.3, 0, 13.4), Vector3(yard0.x - 0.15, 0, 13.4), 0.12, 0.018)
	# 機材置き場の黄色い囲い
	for edge: Array in [[yard0, Vector2(yard1.x, yard0.y)], [Vector2(yard0.x, yard1.y), yard1], [yard0, Vector2(yard0.x, yard1.y)], [Vector2(yard1.x, yard0.y), yard1]]:
		g.strip(yellow, Vector3(edge[0].x, 0, edge[0].y), Vector3(edge[1].x, 0, edge[1].y), 0.12, 0.019)
	g.strip(white, Vector3(74.4, 0, 12.0), Vector3(74.4, 0, 81.0), 0.14, 0.018)
	g.strip(white, Vector3(85.6, 0, 12.0), Vector3(85.6, 0, 81.0), 0.14, 0.018)
	for z in range(31, 75, 8):
		g.strip(cream, Vector3(80, 0, z), Vector3(80, 0, z + 3.2), 0.16, 0.018)
	# 横断歩道と停止線
	for k in 12:
		var cx := 74.5 + k * 1.0
		g.strip(white, Vector3(cx, 0, 27.0), Vector3(cx, 0, 29.6), 0.5, 0.018)
	g.strip(white, Vector3(80.0, 0, 25.9), Vector3(86.2, 0, 25.9), 0.4, 0.018)
	# 直進の矢印
	g.poly_out(white, [Vector3(83.0 - 0.12, 0.018, 36.6), Vector3(83.0 + 0.12, 0.018, 36.6), Vector3(83.0 + 0.12, 0.018, 38.4), Vector3(83.0 - 0.12, 0.018, 38.4)], Vector3.UP)
	g.poly_out(white, [Vector3(83.0 - 0.5, 0.018, 38.4), Vector3(83.0 + 0.5, 0.018, 38.4), Vector3(83.0, 0.018, 39.9)], Vector3.UP)
	# 荷物の積み込み場所の黄色い囲い（門の前）
	g.strip(yellow, Vector3(66.5, 0, 11.6), Vector3(70.5, 0, 11.6), 0.14, 0.014)
	# 染み・タイヤ跡・水たまり
	var stain := Look.mat("stain")
	for s: Array in [[79.4, 17.4, 0.55, 0.4, 0.2, 0.014], [82.3, 19.6, 0.4, 0.3, 1.0, 0.014], [78.6, 21.0, 0.3, 0.25, 0.4, 0.014],
			[80.0, 40.0, 1.4, 0.8, 0.3, 0.014], [77.0, 61.0, 1.8, 0.9, 1.1, 0.014], [84.0, 49.0, 1.2, 0.7, 0.7, 0.014],
			[61.8, 15.8, 1.6, 1.1, 0.2, 0.006], [68.4, 12.5, 0.9, 0.6, 0.9, 0.006], [49.0, -6.5, 1.6, 1.0, 0.5, 0.006],
			[85.5, 3.0, 1.3, 0.8, 0.1, 0.006], [72.0, 7.4, 1.1, 0.7, 0.4, 0.006]]:
		g.blob(stain, Vector3(s[0], s[5], s[1]), s[2] * 1.7, s[3] * 1.7, s[4], rng, 16, 0.1)
	for k in 4:
		var tx := 78.2 + k * 1.6
		g.blob(stain, Vector3(tx, 0.0145, 26.0 + k * 0.4), 0.22, 1.7, 0.08 * k, rng, 12, 0.08)
	# 路面のひび（細長い暗い帯）
	var crack := P(Color("2c2e30"), 0.9)
	_crack(g, crack, Vector3(41.0, 0.0045, -9.0), 5.0, rng)
	_crack(g, crack, Vector3(56.0, 0.0045, 0.5), 3.2, rng)
	_crack(g, crack, Vector3(88.0, 0.0045, 14.0), 4.0, rng)
	_crack(g, crack, Vector3(70.0, 0.0045, 28.0), 3.6, rng)
	_crack(g, crack, Vector3(79.0, 0.0115, 45.0), 4.4, rng)
	var wet := Look.mat("puddle")
	for p: Array in [[68.6, 25.5, 1.7, 0.9, 0.1, 0.0075], [62.4, 9.4, 1.3, 0.8, 0.5, 0.0075], [81.2, 29.9, 1.4, 0.7, 0.2, 0.0155],
			[56.0, -9.0, 2.0, 1.0, 0.3, 0.0075], [86.5, 30.6, 0.9, 0.5, 0.9, 0.0075], [76.0, 47.0, 2.2, 0.9, 0.0, 0.0155], [89.0, 20.0, 1.4, 0.8, 0.5, 0.0075]]:
		g.blob(wet, Vector3(p[0], p[5], p[1]), p[2], p[3], p[4], rng, 16, 0.22)
	# マンホール・排水溝
	var iron := Look.plain(Color("45484b"), 0.5, 0.6)
	var iron_l := Look.plain(Color("6a6e70"), 0.45, 0.6)
	for m: Array in [[70.6, 0.0075, 22.0], [79.0, 0.0155, 43.0], [83.0, 0.0155, 66.0], [56.5, 0.0075, 14.0], [40.0, 0.0075, 31.0]]:
		g.blob(iron_l, Vector3(m[0], m[1] + 0.001, m[2]), 0.52, 0.52, 0.0, null, 18)
		g.blob(iron, Vector3(m[0], m[1] + 0.003, m[2]), 0.44, 0.44, 0.0, null, 18)
	for d: Array in [[73.2, 0.0155, 30.0], [86.8, 0.0155, 30.0], [73.9, 0.0155, 60.0], [86.1, 0.0155, 51.0]]:
		g.boxp(iron, Vector3(d[0], d[1] + 0.01, d[2]), Vector3(0.5, 0.02, 1.2), ALL)
		for k in 5:
			g.boxp(iron_l, Vector3(d[0], d[1] + 0.022, d[2] - 0.45 + k * 0.225), Vector3(0.4, 0.008, 0.05), ALL)
	# 駐車スペースの輪止め
	g.boxp(Look.mat("concrete", Color("d5d0c2")), Vector3(80.2, 0.07, 13.8), Vector3(2.0, 0.12, 0.22), ALL)
	g.solidp(Vector3(80.2, 0.07, 13.8), Vector3(2.0, 0.12, 0.22))
	# 敷地の外周の雑草
	for k in 70:
		var edge := rng.randi() % 3
		var wp := Vector3.ZERO
		match edge:
			0:
				wp = Vector3(rng.randf_range(32.5, 91.5), 0.0, -13.9)
			1:
				wp = Vector3(rng.randf_range(32.5, 72.0), 0.0, 35.9)
			_:
				wp = Vector3(91.9, 0.0, rng.randf_range(-13.0, 35.0))
		if absf(wp.x - 80.0) < 8.0 and wp.z > 30.0:
			continue
		var dry := rng.randf() * 0.5
		Foliage.tuft(g, wp + Vector3(rng.randf_range(-0.1, 0.1), 0, 0), rng.randf_range(0.25, 0.5), rng, dry)
		if rng.randf() < 0.6:
			Foliage.tuft(g, wp + Vector3(rng.randf_range(0.15, 0.35), 0, rng.randf_range(-0.1, 0.1)), rng.randf_range(0.15, 0.3), rng, dry)
	# 積み込み口の目印の黒黄の縞
	var hazard := Look.mat("paint", Color("e0b43a"))
	g.strip(P(Color("26282a"), 0.9), Vector3(64.7, 0, 12.8), Vector3(64.7, 0, 19.2), 0.55, 0.0075)
	for k in 12:
		var z0 := 12.9 + k * 0.52
		g.poly_out(hazard, [Vector3(64.45, 0.0105, z0), Vector3(64.95, 0.0105, z0 + 0.22), Vector3(64.95, 0.0105, z0 + 0.4), Vector3(64.45, 0.0105, z0 + 0.18)], Vector3.UP)
	# 事務所から駐車場への通り道に、踏まれてできた汚れ
	for k in 6:
		var t := k / 5.0
		g.blob(stain, Vector3(lerpf(72.6, 79.0, t), 0.006, lerpf(8.0, 16.0, t)), 1.5, 0.55, 0.9, rng, 12, 0.15)
	_slab_shades(g)
	_joint_weeds(g)
	g.build(root, "BaseGround")
	side.build(root, "RoadSidewalk")


# 雑草も色むらも置かない場所：事務所の中、事務所の前の歩道、駐車場と道
static func _bare(p: Vector3) -> bool:
	for r: Rect2 in [Rect2(64.3, -8.6, 15.4, 13.0), Rect2(62.8, 4.2, 18.4, 5.2), Rect2(73.4, 11.3, 13.3, 25.0)]:
		if r.grow(0.2).has_point(Vector2(p.x, p.z)):
			return true
	return false


# 敷地のコンクリートの目地（2.5m ごと。テクスチャの継ぎ目と同じ位置）から生えた雑草
static func _joint_weeds(g: Look.Batch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 515
	for n in 190:
		var on_x := rng.randf() < 0.5
		var p := Vector3(2.5 * rng.randi_range(13, 36), 0.0, rng.randf_range(-13.5, 35.5)) if on_x \
				else Vector3(rng.randf_range(32.5, 91.5), 0.0, 2.5 * rng.randi_range(-5, 14))
		if _bare(p):
			continue
		for i in rng.randi_range(1, 3):
			var along := rng.randf_range(-0.3, 0.3)
			Foliage.tuft(g, p + (Vector3(0, 0, along) if on_x else Vector3(along, 0, 0)), rng.randf_range(0.12, 0.26), rng, rng.randf() * 0.6)


# 敷石の色むら：目地で区切られた 2.5m 角を、いくつか色違いにする（同じテクスチャなので継ぎ目はそろう）
static func _slab_shades(g: Look.Batch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 616
	var shades := [Color("a8a397"), Color("8b877d"), Color("a19a8b"), Color("928f87")]
	for n in 60:
		var x := 2.5 * rng.randi_range(13, 35)
		var z := 2.5 * rng.randi_range(-5, 13)
		if _bare(Vector3(x + 1.25, 0, z + 1.25)) or _bare(Vector3(x, 0, z)) or _bare(Vector3(x + 2.5, 0, z + 2.5)):
			continue
		g.quad_up(Look.mat("concrete", shades[n % shades.size()]), x + 0.05, x + 2.45, z + 0.05, z + 2.45, 0.002)


static func _crack(g: Look.Batch, m: Look.Tint, from: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var p := from
	var a := rng.randf() * TAU
	var step := length / 7.0
	for k in 7:
		a += rng.randf_range(-0.6, 0.6)
		var q := p + Vector3(cos(a), 0, sin(a)) * step
		g.strip(m, p, q, 0.045, from.y)
		p = q


# ---- 事務所の建物（屋根なし） ----

static func _office(b: Look.Batch, root: Node3D) -> void:
	var plaster := Look.mat("plaster", CREAM)
	var teal := Look.mat("plaster", TEAL)
	var wood := Look.mat("wood", WOOD)
	var wood_d := Look.mat("wood", Color("6f5236"))
	var rust := Look.mat("plaster", RUST)
	var paper := P(PAPER)
	var trim := P(Color("efe7d2"), 0.8)
	# 床：板張り。奥の柄がわかるよう、少し暗めの木
	b.quad_up(Look.mat("floor", Color("c9a574")), 65.0, 79.0, -8.0, 4.0, 0.015)
	# 壁（当たり判定は従来どおり）
	b.boxp(plaster, Vector3(72, 1.65, -8), Vector3(14, 3.3, 0.24), ALL)
	b.solidp(Vector3(72, 1.65, -8), Vector3(14, 3.3, 0.24))
	for x: float in [65.0, 79.0]:
		b.boxp(plaster, Vector3(x, 1.2, -2), Vector3(0.24, 2.4, 12), ALL)
		b.solidp(Vector3(x, 1.2, -2), Vector3(0.24, 2.4, 12))
	for x: float in [67.5, 76.5]:
		b.boxp(teal, Vector3(x, 0.75, 4), Vector3(5, 1.5, 0.24), ALL)
		b.solidp(Vector3(x, 0.75, 4), Vector3(5, 1.5, 0.24))
		var window_centers := [x - 1.6, x, x + 1.6]
		var opening := Vector2(1.2, 0.62)
		_window_wall(b, plaster, Rect2(x - 2.5, 1.5, 5.0, 0.9), 4.0, 0.1,
				window_centers, 1.95, opening)
		# 幅木・腰の見切り・笠木（前の壁）
		b.boxp(trim, Vector3(x, 1.52, 4.0), Vector3(5.04, 0.08, 0.3), ALL)
		b.boxp(trim, Vector3(x, 2.43, 4.0), Vector3(5.04, 0.1, 0.22), ALL)
		b.boxp(Look.mat("concrete", Color("d8d2c2")), Vector3(x, 0.07, 4.0), Vector3(5.04, 0.14, 0.3), ALL)
		# 縁日の窓：すりガラス風の小窓が3つ
		for wx: float in window_centers:
			_seated_window(b, trim, Look.mat("glass"), Vector3(wx, 1.95, 4.0), opening, 0.065, 0.068)
	for x: float in [69.85, 74.15]:
		b.boxp(wood, Vector3(x, 1.6, 4), Vector3(0.16, 3.2, 0.3), ALL)
		b.solidp(Vector3(x, 1.6, 4), Vector3(0.16, 3.2, 0.3))
	# 壁の上の笠木（側面と奥）
	b.boxp(trim, Vector3(72, 3.36, -8), Vector3(14.2, 0.1, 0.4), ALL)
	for x: float in [65.0, 79.0]:
		b.boxp(trim, Vector3(x, 2.45, -2), Vector3(0.38, 0.1, 12.2), ALL)
	# 内側の幅木と腰壁
	var skirt := Look.mat("wood", Color("5e4630"))
	b.boxp(skirt, Vector3(72, 0.08, -7.86), Vector3(13.76, 0.16, 0.05), ALL)
	b.boxp(skirt, Vector3(65.14, 0.08, -2), Vector3(0.05, 0.16, 11.76), ALL)
	b.boxp(skirt, Vector3(78.86, 0.08, -2), Vector3(0.05, 0.16, 11.76), ALL)
	for wp: Array in [[67.45, 4.65], [76.55, 4.65]]:
		b.boxp(skirt, Vector3(wp[0], 0.08, 3.86), Vector3(4.7, 0.16, 0.05), ALL)
	b.boxp(teal, Vector3(72, 0.6, -7.86), Vector3(13.76, 1.0, 0.03), ALL)
	b.boxp(teal, Vector3(65.14, 0.6, -2), Vector3(0.03, 1.0, 11.76), ALL)
	b.boxp(teal, Vector3(78.86, 0.6, -2), Vector3(0.03, 1.0, 11.76), ALL)
	b.boxp(trim, Vector3(72, 1.13, -7.85), Vector3(13.76, 0.06, 0.07), ALL)
	b.boxp(trim, Vector3(65.15, 1.13, -2), Vector3(0.07, 0.06, 11.76), ALL)
	b.boxp(trim, Vector3(78.85, 1.13, -2), Vector3(0.07, 0.06, 11.76), ALL)
	# 入口のたたき・ドアマット
	b.boxp(Look.mat("concrete", Color("b9b4a6")), Vector3(72, 0.025, 4.0), Vector3(4.3, 0.05, 0.9), ALL)
	b.boxp(Look.mat("rug", Color("cfd6cc")), Vector3(72, 0.04, 4.9), Vector3(1.6, 0.03, 0.9), ALL)
	# 縞のひさし（左右の壁の上だけ。扉とカメラの視線は空ける）
	for ax: float in [67.45, 76.55]:
		_awning(b, ax, 4.35, 4.3)
	# 入口まわり：旗の連なりと壁のランプ
	_bunting(b, Vector3(65.2, 2.78, 4.45), Vector3(69.7, 3.0, 4.45))
	_bunting(b, Vector3(74.3, 3.0, 4.45), Vector3(78.8, 2.78, 4.45))
	var lamp := Look.mat("lit", Color("ffe3a0"))
	var iron := P(Color("33373a"), 0.6, 0.4)
	for lx: float in [69.55, 74.45]:
		b.boxp(iron, Vector3(lx, 2.7, 4.3), Vector3(0.1, 0.1, 0.3), ALL)
		b.boxp(lamp, Vector3(lx, 2.6, 4.45), Vector3(0.22, 0.2, 0.22), ALL)
	# 扉の横の、掛け札の板（吊り紐つき）
	b.boxp(wood_d, Vector3(69.7, 1.3, 4.22), Vector3(0.45, 0.22, 0.03), FACADE)
	b.bar(P(Color("3a3f44"), 0.7), Vector3(69.55, 1.41, 4.22), Vector3(69.7, 1.52, 4.2), 0.012)
	b.bar(P(Color("3a3f44"), 0.7), Vector3(69.85, 1.41, 4.22), Vector3(69.7, 1.52, 4.2), 0.012)
	# 窓口の机と大きな掲示板
	b.boxp(wood, Vector3(72, 0.907, 0.05), Vector3(3.8, 0.106, 1.4), ALL)
	b.boxp(wood_d, Vector3(72, 0.826, 0.05), Vector3(3.68, 0.056, 1.28), ALL)
	b.solidp(Vector3(72, 0.88, 0.05), Vector3(3.8, 0.16, 1.4))
	for x: float in [70.5, 73.5]:
		b.boxp(teal, Vector3(x, 0.49, 0.05), Vector3(0.25, 0.70, 1.1), ALL)
		b.boxp(wood_d, Vector3(x, 0.07, 0.05), Vector3(0.22, 0.14, 0.95), ALL)
		b.solidp(Vector3(x, 0.42, 0.05), Vector3(0.25, 0.84, 1.1))
	b.boxp(teal, Vector3(72, 0.49, 0.56), Vector3(2.8, 0.70, 0.10), ALL)
	# 掲示板の芯材を上下の桟と側枠で抱かせる。
	b.boxp(wood, Vector3(72, 1.65, -0.72), Vector3(3.93, 1.93, 0.08), ALL)
	for side: float in [-1.0, 1.0]:
		b.boxp(wood_d, Vector3(72 + side * 2.005, 1.65, -0.72), Vector3(0.09, 2.1, 0.16), ALL)
		b.boxp(wood_d, Vector3(72, 1.65 + side * 1.006, -0.72), Vector3(3.93, 0.087, 0.16), ALL)
	b.solidp(Vector3(72, 1.65, -0.72), Vector3(4.1, 2.1, 0.16))
	b.boxp(Look.mat("plaster", Color("42645b")), Vector3(72, 1.65, -0.61), Vector3(3.88, 1.9, 0.04), ALL)
	for i in range(3):
		b.boxp(P(Color("e5d5a5")), Vector3(70.75 + i * 1.25, 1.45, -0.56), Vector3(0.95, 0.78, 0.02), ALL)
	# 掲示板の画びょうと貼り紙
	for k in 6:
		b.boxp(P([Color("c4503a"), Color("d9a441"), Color("7aa6c2")][k % 3]), Vector3(70.2 + k * 0.38, 0.85 + (k % 2) * 0.12, -0.57), Vector3(0.28, 0.2, 0.012), ALL)
	# 机の上：電気スタンド・書類・マグカップ（西側は、のぞき箱と電話のために空けてある）
	_desk_things(b)
	# 椅子（待合）
	for i in range(3):
		_chair(b, Vector3(66.3, 0, -5.3 + i * 2), [TEAL, RUST, Color("7f8352")][i], 0.1 * (i - 1))
	# 書類の棚
	b.boxp(wood, Vector3(76.7, 0.5, -5.9), Vector3(2.3, 1, 1.2), ALL)
	b.solidp(Vector3(76.7, 0.5, -5.9), Vector3(2.3, 1, 1.2))
	for i in range(4):
		b.boxp(P(Color("e8ddbf")), Vector3(76.3 + i * 0.13, 1.04 + i * 0.028, -5.9), Vector3(0.9, 0.028, 0.6), ALL)
	b.boxp(wood, Vector3(68.2, 1.7, -7.81), Vector3(2.1, 1.3, 0.08), ALL)
	for x: float in [67.45, 68.95]:
		b.box(P(Color("b8a76e")), Transform3D(Basis(Vector3.BACK, 0.2), Vector3(x, 1.7, -7.7)), Vector3(0.18, 1.5, 0.025), ALL)
	# 西の壁と、奥の壁の上の段は、空けておく：納品した作品のポスターが、1枚ずつ貼られていく（features/office_wall.gd）
	# フィルム缶とクラッパーの棚（東の壁）
	b.boxp(wood_d, Vector3(78.6, 1.45, 0.4), Vector3(0.5, 0.06, 2.4), ALL)
	b.boxp(wood_d, Vector3(78.6, 1.95, 0.4), Vector3(0.5, 0.06, 2.4), ALL)
	for k in 6:
		var rz := -0.5 + k * 0.38
		b.cylp(P(Color("8c9094"), 0.5, 0.6), Vector3(78.6, 1.48, 0.4 + rz), 0.17, 0.12, 12)
		b.cylp(P(Color("2c2f33"), 0.6, 0.2), Vector3(78.6, 1.6, 0.4 + rz), 0.05, 0.01, 8)
	b.boxp(P(Color("2d3035")), Vector3(78.62, 2.2, 0.0), Vector3(0.3, 0.3, 0.55), ALL)
	for k in 4:
		b.boxp(P(Color("f0ead6")), Vector3(78.6, 2.36, -0.17 + k * 0.12), Vector3(0.28, 0.03, 0.06), ALL)
	b.boxp(P(Color("c4503a")), Vector3(78.5, 2.05, 1.2), Vector3(0.3, 0.2, 0.3), ALL)
	# 敷物（机の前）。ケーブルとテープ
	b.box(Look.mat("rug"), Transform3D(Basis.IDENTITY, Vector3(72, 0.022, 1.9)), Vector3(5.4, 0.02, 3.4), ALL)
	var cable := P(Color("2a2c2e"), 0.5)
	b.bar(cable, Vector3(73.9, 0.03, 0.8), Vector3(75.0, 0.03, 1.4), 0.04)
	b.bar(cable, Vector3(75.0, 0.03, 1.4), Vector3(77.3, 0.03, 0.9), 0.04)
	b.bar(cable, Vector3(77.3, 0.03, 0.9), Vector3(78.7, 0.03, 0.4), 0.04)
	b.boxp(P(Color("e0b43a")), Vector3(75.6, 0.026, 1.15), Vector3(0.1, 0.01, 0.8), ALL)
	# 観葉植物
	_plant(b, Vector3(65.75, 0, 3.3), 1.0, Color("b8643f"))
	_plant(b, Vector3(78.3, 0, 3.3), 0.9, Color("4e777c"))
	_plant(b, Vector3(65.8, 0, -7.3), 1.2, Color("9a7a4a"))
	_plant(b, Vector3(69.5, 0, 4.75), 0.85, Color("b8643f"))
	_plant(b, Vector3(74.5, 0, 4.75), 0.75, Color("d9a441"))
	# 外側：エアコンの室外機・ガスメーター・配管
	b.boxp(P(Color("c8ccce"), 0.6, 0.3), Vector3(68.5, 0.45, -8.55), Vector3(0.95, 0.9, 0.45), GROUND)
	b.cylp(P(Color("3a3f44")), Vector3(68.5, 0.9, -8.55), 0.3, 0.03, 10)
	b.boxp(P(Color("93989a"), 0.6, 0.4), Vector3(76.0, 0.8, -8.3), Vector3(0.5, 0.7, 0.2), GROUND)
	b.cylp(P(Color("3a3f44"), 0.7, 0.3), Vector3(76.4, 0.0, -8.3), 0.07, 3.4, 8)
	b.boxp(P(Color("3a3f44"), 0.7, 0.3), Vector3(75.0, 3.22, -8.3), Vector3(1.8, 0.14, 0.14), ALL)
	# 駐車場・廃材置き場・スタジオへ向かう矢印看板（文字は書かず、矢印の絵だけ）
	_sign(b, root, Vector3(76.8, 0, 6.5), TEAL, 1.0, "truck")
	_sign(b, root, Vector3(66.5, 0, 12.2), RUST, -1.0, "box")
	_sign(b, root, Vector3(87, 0, 33), TEAL, 1.0, "movie_camera")
	# 事務所の明かり（従来のまま）
	var light := OmniLight3D.new()
	light.position = Vector3(72, 3, -2)
	light.light_color = Color("ffe2a5")
	light.light_energy = 1.2
	light.omni_range = 13
	light.shadow_enabled = false
	root.add_child(light)


# ---- 書割の社屋：事務所の正面に立てた、2階建てに見える「正面だけ」の板 ----
# 表は、2階の窓・社名の看板・カチンコの飾りのある、ちゃんとした社屋。裏は、ベニヤ板と斜めの支え（映画のセットと同じ作り）。
# 低い壁の事務所が「柵で囲った場所」に見えないように、通りとCMの画に、建物の顔を作る
static func _facade(root: Node3D, font: Font) -> void:
	var b := Look.Batch.new()
	var wall := Look.mat("plaster", Color("e6d9bb"))
	var band := Look.mat("plaster", TEAL)
	var trim := P(Color("f3ecd9"), 0.8)
	var glass := P(Color("2f4766"), 0.15, 0.4)       # 外から見た窓：紺色、少し映り込む
	var lit := Look.mat("lit", Color("ffd58a"))
	var iron := P(Color("33373a"), 0.6, 0.4)
	var ply := Look.mat("wood", Color("caa877"))
	var lumber := Look.mat("wood", Color("9c7a52"))
	var z := 4.0                         # 前の壁と同じ面
	var y0 := 2.48                       # 1階の壁の上から
	var y1 := 6.5                        # てっぺん
	var mid := (y0 + y1) * 0.5
	# 壁と、1階と2階の境の帯、両端の付け柱
	var windows := [66.7, 69.3, 74.7, 77.3]
	var opening := Vector2(1.72, 1.42)
	_window_wall(b, wall, Rect2(64.8, y0, 14.4, y1 - y0), z, 0.16, windows, 3.85, opening)
	b.solidp(Vector3(72, mid, z), Vector3(14.4, y1 - y0, 0.16))
	b.boxp(band, Vector3(72, 2.62, z + 0.06), Vector3(14.6, 0.24, 0.3), ALL)
	# 両端の木の柱（2本の柱に桟を渡す。左にはつたが絡む）
	var post := Look.mat("wood", Color("8a5a32"))
	for x: float in [64.95, 79.05]:
		for dx: float in [-0.2, 0.2]:
			b.boxp(post, Vector3(x + dx, mid + 0.1, z + 0.12), Vector3(0.14, y1 - y0 + 0.2, 0.16), ALL)
		for k in 8:
			b.boxp(post, Vector3(x, y0 + 0.3 + k * 0.5, z + 0.12), Vector3(0.5, 0.07, 0.1), ALL)
	# 2階の窓（1つだけ明かりが点いている。誰かが残業している）
	var frame := Look.mat("wood", Color("8a5a32"))
	for i in windows.size():
		var wx: float = windows[i]
		_seated_window(b, frame, lit if i == 2 else glass, Vector3(wx, 3.85, z + 0.013), opening, 0.09, 0.092)
		b.boxp(frame, Vector3(wx, 3.85, z + 0.016), Vector3(0.065, 1.24, 0.061), ALL)
		b.boxp(frame, Vector3(wx, 3.9, z + 0.016), Vector3(1.54, 0.06, 0.061), ALL)
		b.boxp(frame, Vector3(wx, 3.11, z + 0.093), Vector3(1.9, 0.09, 0.18), ALL)
		b.boxp(frame, Vector3(wx, 4.62, z + 0.063), Vector3(1.86, 0.1, 0.095), ALL)
	# 室外機と配管（2階の窓の下）
	_outdoor_ac(b, Vector3(77.3, 2.98, z + 0.34))
	b.bar(P(Color("e8e2d2"), 0.7), Vector3(77.75, 3.1, z + 0.2), Vector3(78.6, 3.1, z + 0.12), 0.05)
	b.bar(P(Color("e8e2d2"), 0.7), Vector3(78.6, 3.1, z + 0.12), Vector3(78.6, 2.5, z + 0.12), 0.05)
	# 社名の看板（枠つき）と、照らすランプ3つ
	b.boxp(trim, Vector3(72, 5.45, z + 0.1), Vector3(12.0, 1.2, 0.08), ALL)
	b.boxp(Look.mat("plaster", Color("97392b")), Vector3(72, 5.45, z + 0.15), Vector3(11.7, 0.95, 0.04), ALL)
	b.boxp(Look.mat("plaster", Color("7a2c22")), Vector3(72, 5.45, z + 0.13), Vector3(11.84, 1.06, 0.03), ALL)
	for lx: float in [68.0, 72.0, 76.0]:
		b.bar(iron, Vector3(lx, 6.25, z + 0.1), Vector3(lx, 6.35, z + 0.7), 0.04)
		b.boxp(iron, Vector3(lx, 6.3, z + 0.75), Vector3(0.28, 0.12, 0.2), ALL)
		b.boxp(lit, Vector3(lx, 6.23, z + 0.75), Vector3(0.22, 0.03, 0.14), ALL)
	# 軒下の木の持ち送り（笠木の下に、小さな梁が並ぶ）
	for k in 9:
		var bx: float = 65.6 + k * 1.6
		b.boxp(post, Vector3(bx, y1 - 0.12, z + 0.3), Vector3(0.14, 0.14, 0.5), ALL)
		b.bar(post, Vector3(bx, y1 - 0.5, z + 0.1), Vector3(bx, y1 - 0.18, z + 0.46), 0.07)
	# 雨どい（右の柱の内側を、上から下まで）
	var pipe := P(Color("9aa0a2"), 0.6, 0.3)
	b.cylp(pipe, Vector3(78.45, y0, z + 0.16), 0.05, y1 - y0 - 0.1, 8)
	b.boxp(pipe, Vector3(78.45, y1 - 0.12, z + 0.2), Vector3(0.3, 0.1, 0.18), ALL)
	# つた：左の柱を登って、壁の上の端へ広がり、少し垂れる
	var vz := z + 0.22
	Foliage.ivy(b, [Vector3(64.9, y0, vz), Vector3(65.15, y0 + 1.4, vz), Vector3(64.95, y1 - 0.7, vz), Vector3(65.6, y1 - 0.15, vz),
			Vector3(66.9, y1 - 0.2, vz), Vector3(67.8, y1 - 0.45, vz)], Vector3.BACK, 70, Vector3(64.9, 1, 4))
	Foliage.ivy(b, [Vector3(66.2, y1 - 0.2, vz), Vector3(66.35, y1 - 1.0, vz), Vector3(66.2, y1 - 1.5, vz)], Vector3.BACK, 14, Vector3(66.2, 1, 4))
	# 右柱から、撮影機の印を入れた看板を吊るす。
	b.boxp(iron, Vector3(79.25, 4.69, z + 0.215), Vector3(0.14, 0.31, 0.115), ALL)
	b.boxp(iron, Vector3(79.75, 4.75, z + 0.25), Vector3(1.3, 0.07, 0.07), ALL)
	b.bar(iron, Vector3(79.2, 4.35, z + 0.25), Vector3(79.95, 4.74, z + 0.25), 0.04)
	for cx: float in [79.6, 80.2]:
		b.bar(iron, Vector3(cx, 4.72, z + 0.25), Vector3(cx, 4.42, z + 0.25), 0.022, ALL)
		b.boxp(iron, Vector3(cx, 4.43, z + 0.25), Vector3(0.065, 0.082, 0.085), ALL)
	b.boxp(band, Vector3(79.9, 4.16, z + 0.25), Vector3(0.86, 0.54, 0.066), ALL)
	for side: float in [-1.0, 1.0]:
		var face := Basis(Vector3.UP, PI if side < 0 else 0.0)
		Look.picto(root, Transform3D(face, Vector3(79.9, 4.16, z + 0.25 + side * 0.034)),
				"movie_camera", Vector2(0.39, 0.39), FACADE_LAYER)
	# てっぺん：笠木と、真ん中のカチンコの飾り
	b.boxp(trim, Vector3(72, y1 + 0.08, z + 0.05), Vector3(14.9, 0.18, 0.46), ALL)
	b.boxp(P(Color("26272b"), 0.7), Vector3(72, y1 + 0.55, z), Vector3(2.4, 0.75, 0.14), ALL)
	for k in 5:
		b.box(P(Color("f4f1ea") if k % 2 == 0 else Color("26272b"), 0.7), Transform3D(Basis(Vector3.BACK, 0.5), Vector3(71.0 + k * 0.5, y1 + 1.06, z)), Vector3(0.42, 0.2, 0.14), ALL)
	b.box(P(Color("26272b"), 0.7), Transform3D(Basis(Vector3.BACK, 0.12), Vector3(72, y1 + 1.04, z - 0.02)), Vector3(2.5, 0.28, 0.1), ALL)
	# 裏：合板を桟の上で継ぎ、下の腰壁へ斜材の荷重を戻す。
	for k in 12:
		var panel_x := 65.4 + k * 1.2
		for span: Vector2 in [Vector2(y0, 4.9), Vector2(4.9, y1)]:
			b.boxp(ply, Vector3(panel_x, (span.x + span.y) * 0.5, z - 0.095),
					Vector3(1.191, span.y - span.x - 0.006, 0.032), ALL)
		if k < 11:
			b.boxp(lumber, Vector3(panel_x + 0.6, mid, z - 0.135), Vector3(0.047, y1 - y0, 0.054), ALL)
	var bracket := P(Color("52534b"), 0.58, 0.45)
	for x: float in [66.0, 69.5, 74.5, 78.0]:
		var heel := Vector3(x, y0 + 0.13, z - 1.42)
		b.bar(lumber, Vector3(x, y1 - 0.4, z - 0.14), heel, 0.1)
		b.bar(lumber, heel, Vector3(x, y0 + 0.13, z - 0.14), 0.09)
		b.bar(lumber, heel, Vector3(x, 1.42, z - 0.13), 0.09)
		for p: Vector3 in [heel, Vector3(x, 1.42, z - 0.13), Vector3(x, y1 - 0.4, z - 0.14)]:
			b.boxp(bracket, p, Vector3(0.16, 0.16, 0.09), ALL)
	for yy: float in [3.3, 4.9]:
		b.boxp(lumber, Vector3(72, yy, z - 0.15), Vector3(14.2, 0.09, 0.06), ALL)
	var front := Look.Batch.new()
	_bench(front, Vector3(67.6, 0, 6.05), 0.0)
	_drum(front, Vector3(78.55, 0, 5.15), Color("a4532c"))
	_bike(front, Vector3(79.9, 0, 5.4), 0.0, Color("7f8352"))
	front.build(root, "OfficeFrontDressing")
	var out := b.build(root, "OfficeFacade")
	for node: Node in out.find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = FACADE_LAYER
	# 表の社名（会社の名前。プレイヤーがスプレーで書き直す。features/spray_sign.gd）。ほかの文字は置かない
	var sign := Look.label(root, Transform3D(Basis.IDENTITY, Vector3(72, 5.43, z + 0.18)), "格安アクション映画制作班", 0.011, 72, Color("f6e7c4"), font, false)
	sign.layers = FACADE_LAYER
	sign.name = "CompanyNameSign"


static func _outdoor_ac(b: Look.Batch, p: Vector3) -> void:
	var case := P(Color("c8ccce"), 0.58, 0.15)
	var iron := P(Color("555d61"), 0.56, 0.45)
	b.boxp(case, p - Vector3(0, 0, 0.04), Vector3(0.9, 0.50, 0.23), ALL)
	for side: float in [-1.0, 1.0]:
		b.boxp(case, p + Vector3(0, side * 0.224, 0.114), Vector3(0.90, 0.052, 0.091), ALL)
		b.boxp(case, p + Vector3(side * 0.421, 0, 0.114), Vector3(0.058, 0.396, 0.091), ALL)
		var mount := p + Vector3(side * 0.30, -0.27, 0)
		b.boxp(iron, mount, Vector3(0.07, 0.045, 0.53), ALL)
		b.boxp(iron, mount + Vector3(0, -0.1, -0.247), Vector3(0.07, 0.26, 0.035), ALL)
		b.bar(iron, mount + Vector3(0, -0.013, 0.12), mount + Vector3(0, -0.17, -0.24), 0.033, ALL)
	b.boxp(case, p + Vector3(0.29, 0, 0.115), Vector3(0.21, 0.396, 0.091), ALL)
	var fan := p + Vector3(-0.09, 0, 0.082)
	var axis := Basis(Vector3.RIGHT, PI * 0.5)
	b.cyl(P(Color("333b3d")), Transform3D(axis, fan), 0.186, 0.012, 20)
	for k in 5:
		var vane := Basis(Vector3.BACK, TAU * k / 5.0)
		b.box(iron, Transform3D(vane, fan + vane * Vector3(0.067, 0.035, 0.018)),
				Vector3(0.13, 0.062, 0.014), ALL)
	b.cyl(iron, Transform3D(axis, fan + Vector3(0, 0, 0.026)), 0.037, 0.022, 12)
	for r: float in [0.063, 0.112, 0.161, 0.19]:
		_ring(b, case, Transform3D(axis, fan + Vector3(0, 0, 0.065)), r, 0.011, false)
	for side: float in [-1.0, 1.0]:
		b.bar(case, fan + Vector3(-0.187, side * 0.037, 0.065),
				fan + Vector3(0.187, side * 0.037, 0.065), 0.011, ALL)


static func _desk_things(b: Look.Batch) -> void:
	var y := 0.96
	# 電気スタンド
	b.cylp(P(Color("2f3438"), 0.5, 0.5), Vector3(73.3, y, 0.1), 0.12, 0.04, 10)
	b.bar(P(Color("2f3438"), 0.5, 0.5), Vector3(73.3, y + 0.04, 0.1), Vector3(73.15, y + 0.5, 0.0), 0.03)
	b.bar(P(Color("2f3438"), 0.5, 0.5), Vector3(73.15, y + 0.5, 0.0), Vector3(72.95, y + 0.62, -0.1), 0.03)
	b.cyl(P(Color("d9a441"), 0.5, 0.3), Transform3D(Basis(Vector3.BACK, 0.7), Vector3(72.95, y + 0.64, -0.1)), 0.04, 0.2, 10, 0.12)
	b.boxp(Look.mat("lit", Color("fff1c0")), Vector3(72.84, y + 0.54, -0.1), Vector3(0.1, 0.03, 0.1), ALL)
	# 書類・マグカップ・印鑑。机の西側（のぞき箱と電話：PEEP_BOX・ORDER_PHONE）には置かない
	for k in 3:
		b.boxp(P(PAPER), Vector3(73.5, y + 0.015 + k * 0.03, -0.32), Vector3(0.5, 0.03, 0.36), ALL)
	b.cylp(P(Color("c4503a"), 0.5), Vector3(70.36, y, 0.52), 0.06, 0.1, 10)
	b.cylp(P(Color("c4503a"), 0.4), Vector3(72.4, y, 0.35), 0.03, 0.07, 8)
	b.boxp(P(Color("2d3035")), Vector3(72.4, y + 0.1, -0.05), Vector3(0.5, 0.2, 0.1), ALL)


static func _awning(b: Look.Batch, cx: float, z0: float, width: float) -> void:
	var tealc := P(Color("4e777c"), 0.9)
	var creamc := P(Color("efe3c0"), 0.9)
	var metal := P(Color("505659"), 0.6, 0.4)
	var n := 8
	var w := width / n
	var back_z := z0 - 0.15
	var front_z := z0 + 1.0
	for k in n:
		var x0 := cx - width * 0.5 + k * w
		var m := tealc if k % 2 == 0 else creamc
		var rear := Vector3(x0, 2.62, back_z)
		var mid := Vector3(x0, 2.305, lerpf(back_z, front_z, 0.5))
		var tip := Vector3(x0, 2.06, front_z)
		var across := Vector3(w, 0, 0)
		for span: Array in [[rear, mid], [mid, tip]]:
			var a: Vector3 = span[0]
			var c: Vector3 = span[1]
			var sail := [a, a + across, c + across, c]
			b.poly_out(m, sail, Vector3.UP)
			b.poly_out(m, sail, Vector3.DOWN)
		# 帆の前端を巻いて留め、前垂れの縁はストライプごとに緩くたわませる。
		var side := Vector3(0, -0.135, 0.023)
		var hanging := [tip, tip + across, tip + across + side,
				tip + across * 0.5 + side + Vector3(0, -0.036, 0.006), tip + side]
		b.poly_out(m, hanging, Vector3.BACK)
		b.poly_out(m, hanging, Vector3.FORWARD)
	b.boxp(metal, Vector3(cx, 2.602, back_z), Vector3(width + 0.04, 0.042, 0.058), ALL)
	b.boxp(metal, Vector3(cx, 2.031, front_z - 0.016), Vector3(width, 0.038, 0.041), ALL)
	for sx: float in [cx - width * 0.5 + 0.1, cx + width * 0.5 - 0.1]:
		var nose := Vector3(sx, 2.031, front_z - 0.016)
		b.boxp(metal, Vector3(sx, 1.77, 4.05), Vector3(0.11, 0.19, 0.045), ALL)
		b.bar(metal, Vector3(sx, 1.77, 4.07), nose, 0.033, ALL)
		b.bar(metal, Vector3(sx, 2.59, back_z), nose, 0.027, ALL)


# 三角旗の連なり（2点間に少したるませる）
static func _bunting(b: Look.Batch, p: Vector3, q: Vector3) -> void:
	var cols := [Color("c4503a"), Color("e8c24a"), Color("4e777c"), Color("efe3c0"), Color("7aa6c2")]
	var rope := P(Color("3a3f44"), 0.7)
	var prev := p
	var n := 10
	for k in range(1, n + 1):
		var t := float(k) / n
		var cur := p.lerp(q, t)
		cur.y -= 0.28 * 4.0 * t * (1.0 - t)
		b.bar(rope, prev, cur, 0.02)
		var mid := (prev + cur) * 0.5
		var flag := [mid + Vector3(-0.17, 0, 0), mid + Vector3(0.17, 0, 0), mid + Vector3(0, -0.34, 0)]
		b.poly_out(P(cols[k % cols.size()], 0.9), flag, Vector3(0, 0, 1))
		prev = cur


static func _poster(b: Look.Batch, pos: Vector3, yaw: float, size: Vector2, bg: Color, fg: Color, art: int) -> void:
	var fwd := Basis(Vector3.UP, yaw)
	b.box(P(Color("efe6cc"), 0.9), Transform3D(fwd, pos), Vector3(size.x + 0.08, size.y + 0.08, 0.02), ALL)
	b.box(P(bg, 0.9), Transform3D(fwd, pos + fwd * Vector3(0, 0, 0.012)), Vector3(size.x, size.y, 0.012), ALL)
	# 絵：月・火・山のどれか
	var ap := pos + fwd * Vector3(0, size.y * 0.12, 0.022)
	match art:
		0:
			b.cyl(P(fg, 0.8), Transform3D(fwd * Basis(Vector3.RIGHT, PI * 0.5), ap + fwd * Vector3(0.15, 0.1, 0.0)), size.x * 0.2, 0.012, 14)
			b.extrude(P(fg.darkened(0.55), 0.9), Transform3D(fwd, ap + fwd * Vector3(-0.1, -size.y * 0.25, 0.0)), [Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0.0, 0.35)], 0.015)
		1:
			b.extrude(P(fg, 0.8), Transform3D(fwd, ap + fwd * Vector3(0, -0.15, 0.0)), [Vector2(-0.3, 0), Vector2(0.3, 0), Vector2(0.12, 0.3), Vector2(0.0, 0.18), Vector2(-0.12, 0.34)], 0.015)
		2:
			b.extrude(P(fg.darkened(0.3), 0.8), Transform3D(fwd, ap + fwd * Vector3(0, -0.2, 0.0)), [Vector2(-0.38, 0), Vector2(0.38, 0), Vector2(0.2, 0.5), Vector2(0.0, 0.3), Vector2(-0.2, 0.55)], 0.015)
		_:
			b.box(P(fg, 0.8), Transform3D(fwd, ap), Vector3(size.x * 0.7, 0.02, 0.014), ALL)
	# 題名の代わりに、下に太い帯と細い帯（刷った色の帯）
	b.box(P(fg, 0.85), Transform3D(fwd, pos + fwd * Vector3(0, -size.y * 0.33, 0.014)), Vector3(size.x * 0.72, size.y * 0.075, 0.004), ALL)
	b.box(P(fg.darkened(0.25), 0.85), Transform3D(fwd, pos + fwd * Vector3(0, -size.y * 0.43, 0.014)), Vector3(size.x * 0.5, size.y * 0.025, 0.004), ALL)


static func _chair(b: Look.Batch, pos: Vector3, color: Color, yaw: float) -> void:
	var seat := P(color)
	var leg := P(Color("53534e"), 0.6, 0.4)
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	b.box(seat, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(0.8, 0.12, 0.85), ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(0.8, 0.12, 0.85))
	b.box(seat, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, -0.35)), Vector3(0.8, 0.9, 0.1), ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, -0.35)), Vector3(0.8, 0.9, 0.1))
	for x: float in [-0.29, 0.29]:
		for z: float in [-0.29, 0.29]:
			b.box(leg, at * Transform3D(Basis.IDENTITY, Vector3(x, 0.23, z)), Vector3(0.08, 0.46, 0.08), ALL)
			b.solid(at * Transform3D(Basis.IDENTITY, Vector3(x, 0.23, z)), Vector3(0.08, 0.46, 0.08))


static func _plant(b: Look.Batch, pos: Vector3, s: float, pot: Color) -> void:
	b.cylp(P(pot, 0.7), pos, 0.28 * s, 0.4 * s, 10, 0.22 * s)
	b.solidp(pos + Vector3(0, 0.2 * s, 0), Vector3(0.44, 0.4, 0.44) * s)
	b.cylp(P(Color("3a2a20"), 0.95), pos + Vector3(0, 0.4 * s, 0), 0.22 * s, 0.02, 10)
	Foliage.bush(b, pos + Vector3(0, 0.72 * s, 0), 0.34 * s)


# 矢印看板。arrow：+1 で右（+x）、−1 で左を指す絵を、板の表（+z）にぴったり貼る
static func _sign(b: Look.Batch, root: Node3D, pos: Vector3, color: Color, arrow: float, destination: String) -> void:
	var metal := P(Color("555c5b"), 0.63, 0.32)
	for x: float in [-0.57, 0.57]:
		var foot := pos + Vector3(x, 0.05, 0)
		b.boxp(Look.mat("concrete", Color("aaa394")), foot, Vector3(0.21, 0.10, 0.23), ALL)
		b.boxp(metal, pos + Vector3(x, 0.75, 0), Vector3(0.08, 1.5, 0.08), ALL)
		b.solidp(pos + Vector3(x, 0.75, 0), Vector3(0.08, 1.5, 0.08))
	var board := pos + Vector3(0, 1.41, 0)
	b.boxp(metal, board, Vector3(1.65, 0.61, 0.078), ALL)
	b.solidp(board, Vector3(1.65, 0.61, 0.10))
	for side: float in [-1.0, 1.0]:
		var face := Basis(Vector3.UP, PI if side < 0.0 else 0.0)
		b.boxp(P(color, 0.74), board + Vector3(0, 0, side * 0.041), Vector3(1.58, 0.54, 0.008), ALL)
		var target := board + face * Vector3(-0.36, 0, 0.0458)
		if destination == "box":
			b.box(P(Color("efe3c0")), Transform3D(face, target),
					Vector3(0.38, 0.38, 0.004), ALL)
			target += face.z * 0.0028
		Look.picto(root, Transform3D(face, target), destination, Vector2(0.36, 0.36))
		var flip := Basis(Vector3.BACK, PI) if arrow * side < 0.0 else Basis.IDENTITY
		Look.picto(root, Transform3D(face * flip, board + face * Vector3(0.32, 0, 0.0458)),
				"arrow", Vector2(0.53, 0.43))


# ---- 敷地の小物（部品に沿った当たり判定。脚の間や機材の開口部はふさがない） ----

static func _lot(root: Node3D, rng: RandomNumberGenerator) -> void:
	# 場所ごとに別メッシュにして、見えない場所は描かないようにする（Batch ごとに視錐台で間引かれる）
	var zones: Array = []
	var b := Look.Batch.new()
	zones.append(b)
	# 北西：区の清掃事務所の車庫（差し掛け小屋とフォークリフト。粗大ごみを運ぶ）。ここから西は区の土地（ward_lot.gd）
	_shed(b, 38.0, 60.0, -13.8, -9.5)
	_forklift(b, Vector3(50.5, 0, -4.4), 0.45, Color("3f8a5a"))
	# 清掃車庫の札を屋根下の梁に固定する。
	var garage_sign := Vector3(49.0, 2.84, -9.40)
	for x: float in [-0.67, 0.67]:
		b.boxp(P(Color("555c5b"), 0.6, 0.4), garage_sign + Vector3(x, 0.15, -0.04),
				Vector3(0.065, 0.24, 0.10), ALL)
	b.boxp(P(Color("e6e4d5"), 0.64), garage_sign, Vector3(1.66, 0.41, 0.035), ALL)
	b.boxp(P(Color("2f7d4f"), 0.68), garage_sign + Vector3(0.22, 0, 0.018), Vector3(0.94, 0.10, 0.006), ALL)
	Look.picto(root, Transform3D(Basis.IDENTITY, garage_sign + Vector3(-0.5, 0, 0.0184)),
			"bag", Vector2(0.30, 0.30))
	_pallet_stack(b, Vector3(44.0, 0, -5.9), 0.1, 4, true)
	_pallet_stack(b, Vector3(45.4, 0, -6.1), -0.2, 2, false)
	for k in 5:
		_cone(b, Vector3(39.5 + k * 1.1, 0, -1.6 + (k % 2) * 0.25))
	for k in 6:
		_drum(b, Vector3(57.5 + (k % 3) * 0.65, 0, -5.2 + (k / 3) * 0.65), [Color("3b6ea5"), Color("c4503a"), Color("d9a441")][k % 3])
	_tires(b, Vector3(35.4, 0, -5.4), 3)
	_tires(b, Vector3(36.5, 0, -4.8), 2)

	_tree(b, Vector3(33.9, 0, -2.0), 1.2)
	b = Look.Batch.new()
	zones.append(b)
	# 北：事務所の裏手（ごみ置き場と資材）
	_dumpster(b, Vector3(68.4, 0, -12.2), 0.0, Color("4c7a58"))
	_dumpster(b, Vector3(70.8, 0, -12.2), 0.05, Color("3f6290"))
	_cardboard_pile(b, Vector3(75.0, 0, -12.2), rng)
	_crate_stack(b, Vector3(79.6, 0, -12.0), rng)
	for k in 4:
		_drum(b, Vector3(84.2 + (k % 2) * 0.65, 0, -12.4 + (k / 2) * 0.65), [Color("c4503a"), Color("3b6ea5")][k % 2])
	_pipes(b, Vector3(88.2, 0, -11.2))
	b = Look.Batch.new()
	zones.append(b)
	# 東：自販機・ベンチ・自転車置き場・植え込み
	_vending(b, Vector3(79.62, 0, -2.7), PI * 0.5, Color("c4503a"), root)
	_vending(b, Vector3(79.62, 0, -1.55), PI * 0.5, Color("3b6ea5"), root)
	_bench(b, Vector3(83.0, 0, -2.1), -PI * 0.5)
	_bin(b, Vector3(81.5, 0, -4.3))
	for k in 3:
		_bike(b, Vector3(82.8, 0, 5.4 + k * 0.95), 0.0, [Color("c4503a"), Color("3b6ea5"), Color("d9a441")][k])
	_bike_rack(b, Vector3(83.5, 0, 5.4))
	_planter(b, Vector3(67.6, 0, 5.15), 3.2, 9)
	_planter(b, Vector3(76.6, 0, 5.15), 3.2, 9)
	_tree(b, Vector3(89.6, 0, 3.6), 1.4)
	_tree(b, Vector3(90.2, 0, -8.5), 1.2)
	_tree(b, Vector3(64.4, 0, 8.6), 1.2)
	# 班の照明（出しっぱなし）。書割の立てかけの横
	_light_stand(b, Vector3(88.9, 0, -1.4), 0.5)
	_light_stand(b, Vector3(87.7, 0, 4.6), 2.0)
	for k in 5:
		_flat(b, Vector3(91.35, 0, -0.5 + k * 1.15), k)
	_light_stand(b, Vector3(88.0, 0, 1.6), 2.4)
	_light_stand(b, Vector3(88.4, 0, 3.0), 2.8)
	b = Look.Batch.new()
	zones.append(b)
	# 事務所と駐車場のあいだ
	_bulletin(b, Vector3(69.2, 0, 9.8))
	_lamp_post(b, Vector3(64.0, 0, 6.4), root, true)
	_lamp_post(b, Vector3(84.2, 0, 11.0), root, true)
	_lamp_post(b, Vector3(70.4, 0, 33.5), root, false)
	_bench(b, Vector3(71.2, 0, 30.4), PI)
	_tree(b, Vector3(68.4, 0, 31.8), 1.5)
	for k in 3:
		_crate(b, Vector3(64.6 + k * 1.05, 0.0, 33.0), Vector3(0.9, 0.7, 0.9), 0.1 * k)
	_crate(b, Vector3(65.65, 0.7, 33.0), Vector3(0.8, 0.6, 0.8), 0.4)
	for k in 4:
		_cone(b, Vector3(72.6, 0, 24.5 + k * 0.9))
	b = Look.Batch.new()
	zones.append(b)
	# 南：生け垣と照明、パレットとパイプ
	for k in 5:
		if k != 1:            # 区の入口（ward_lot.gd）の前は空ける
			_planter(b, Vector3(36.5 + k * 5.4, 0, 35.2), 4.0)
	_pallet_stack(b, Vector3(33.2, 0, 32.0), 0.0, 5, true)
	_pallet_stack(b, Vector3(34.6, 0, 32.2), 0.1, 3, false)
	_pipes(b, Vector3(58.5, 0, 33.8))
	_tires(b, Vector3(52.0, 0, 33.8), 4)
	_lamp_post(b, Vector3(35.75, 0, 31.6), root, false)   # 区の門（x 39..45）と看板の前は空ける
	_lamp_post(b, Vector3(57.0, 0, 31.6), root, false)
	_bike(b, Vector3(66.0, 0, 35.0), 0.0, Color("7f8352"))
	b = Look.Batch.new()
	zones.append(b)
	# 東の端：荷物と照明
	_pallet_stack(b, Vector3(90.2, 0, 12.6), 1.57, 3, true)
	_pallet_stack(b, Vector3(90.3, 0, 14.0), 1.57, 2, true)
	for k in 5:
		_drum(b, Vector3(90.6, 0, 22.5 + (k % 2) * 0.62 + (k / 2) * 0.0 + (k / 3) * 0.9), [Color("d9a441"), Color("4e777c")][k % 2])
	_tree(b, Vector3(90.4, 0, 31.4), 1.3)
	_tires(b, Vector3(89.8, 0, 26.6), 3)
	for k in 3:
		_cone(b, Vector3(88.9, 0, 28.6 + k * 0.7))
	for i in zones.size():
		(zones[i] as Look.Batch).build(root, "Lot%d" % i)


# 差し掛け小屋：波板の屋根と柱、下に棚と作業台
static func _shed(b: Look.Batch, x0: float, x1: float, zb: float, zf: float) -> void:
	var post := P(Color("6b5a48"), 0.9)
	var roof := Look.mat("metal", Color("8f9ea0"))
	var galvanized := P(Color("7e8b8f"), 0.55, 0.45)
	var n := int((x1 - x0) / 5.5) + 1
	for k in n + 1:
		var x := x0 + k * (x1 - x0) / n
		b.boxp(post, Vector3(x, 1.8, zb + 0.15), Vector3(0.16, 3.6, 0.16), GROUND)
		b.solidp(Vector3(x, 1.8, zb + 0.15), Vector3(0.16, 3.6, 0.16))
		b.boxp(post, Vector3(x, 1.5, zf), Vector3(0.16, 3.0, 0.16), GROUND)
		b.solidp(Vector3(x, 1.5, zf), Vector3(0.16, 3.0, 0.16))
		for end_z: float in [zb + 0.15, zf]:
			b.boxp(galvanized, Vector3(x, 0.095, end_z), Vector3(0.24, 0.19, 0.23), GROUND)
			b.boxp(galvanized, Vector3(x, 0.025, end_z), Vector3(0.3, 0.05, 0.3), GROUND)
		b.bar(post, Vector3(x, 3.63, zb + 0.12), Vector3(x, 3.04, zf + 0.43), 0.12, ALL)
		b.bar(post, Vector3(x, 2.58, zf), Vector3(x, 3.105, zf - 0.65), 0.072, ALL)
	for span: Vector2 in [Vector2(3.59, zb + 0.15), Vector2(3.04, zf)]:
		b.boxp(post, Vector3((x0 + x1) * 0.5, span.x, span.y),
				Vector3(x1 - x0 + 0.42, 0.14, 0.15), ALL)
	var top := [Vector3(x0 - 0.4, 3.78, zb), Vector3(x1 + 0.4, 3.78, zb), Vector3(x1 + 0.4, 3.12, zf + 0.5), Vector3(x0 - 0.4, 3.12, zf + 0.5)]
	b.poly_out(roof, top, Vector3.UP)
	var under: Array = []
	for p: Vector3 in top:
		under.append(p + Vector3(0, -0.08, 0))
	b.poly_out(P(Color("5f6a6c"), 0.8), under, Vector3.DOWN)
	var roof_from := Vector3((x0 + x1) * 0.5, 3.74, zb)
	var roof_to := Vector3((x0 + x1) * 0.5, 3.08, zf + 0.5)
	_solid_bar(b, roof_from, roof_to, Vector2(x1 - x0 + 0.8, 0.08))
	b.boxp(galvanized, Vector3((x0 + x1) * 0.5, 3.075, zf + 0.44),
			Vector3(x1 - x0 + 0.8, 0.074, 0.11), ALL)
	var ribs := roundi((x1 - x0 + 0.8) / 0.24)
	for i in ribs:
		var x := lerpf(x0 - 0.38, x1 + 0.38, (float(i) + 0.5) / ribs)
		b.bar(galvanized, Vector3(x, 3.786, zb), Vector3(x, 3.126, zf + 0.51), 0.026, ALL)
	# 棚と資材
	var wood := Look.mat("wood", Color("a8845a"))
	for sx: float in [x0 + 1.2, x0 + 4.4]:
		for sy: float in [0.4, 1.2, 2.0]:
			b.boxp(wood, Vector3(sx + 1.6, sy, zb + 0.9), Vector3(3.2, 0.06, 0.8), ALL)
			b.solidp(Vector3(sx + 1.6, sy, zb + 0.9), Vector3(3.2, 0.06, 0.8))
		for ox: float in [0.0, 3.2]:
			b.boxp(wood, Vector3(sx + ox, 1.1, zb + 0.9), Vector3(0.08, 2.2, 0.8), ALL)
			b.solidp(Vector3(sx + ox, 1.1, zb + 0.9), Vector3(0.08, 2.2, 0.8))
		for sy: float in [0.4, 1.2, 2.0]:
			for k in 3:
				b.boxp(P([Color("c9a46c"), Color("b88a56"), Color("d6b27a")][k]), Vector3(sx + 0.6 + k * 1.0, sy + 0.25, zb + 0.9), Vector3(0.8, 0.44, 0.6), GROUND)
				b.solidp(Vector3(sx + 0.6 + k * 1.0, sy + 0.25, zb + 0.9), Vector3(0.8, 0.44, 0.6))
	# 角材の山
	for k in 5:
		b.boxp(Look.mat("wood", Color("c49a62")), Vector3(x0 + 11.0, 0.12 + k * 0.1, zb + 1.8), Vector3(3.0, 0.08, 0.2 + (k % 2) * 0.05), GROUND)
		b.boxp(Look.mat("wood", Color("b58c57")), Vector3(x0 + 11.0, 0.22 + k * 0.1, zb + 2.1), Vector3(3.0, 0.08, 0.2), GROUND)
	b.boxp(Look.mat("wood", Color("c49a62")), Vector3(x0 + 11.0, 0.6, zb + 1.95), Vector3(3.1, 0.5, 0.7), GROUND)
	b.solidp(Vector3(x0 + 11.0, 0.44, zb + 1.95), Vector3(3.1, 0.82, 0.7))
	# 作業台と万力
	var bx := x1 - 3.0
	b.boxp(Look.mat("wood", Color("94704a")), Vector3(bx, 0.9, zb + 1.2), Vector3(2.4, 0.1, 0.9), GROUND)
	b.solidp(Vector3(bx, 0.9, zb + 1.2), Vector3(2.4, 0.1, 0.9))
	for lx: float in [-1.1, 1.1]:
		for lz: float in [-0.35, 0.35]:
			b.boxp(P(Color("33373a"), 0.6, 0.4), Vector3(bx + lx, 0.45, zb + 1.2 + lz), Vector3(0.08, 0.9, 0.08), GROUND)
			b.solidp(Vector3(bx + lx, 0.45, zb + 1.2 + lz), Vector3(0.08, 0.9, 0.08))
	b.boxp(P(Color("b5412f"), 0.5, 0.3), Vector3(bx + 0.7, 1.0, zb + 1.2), Vector3(0.2, 0.14, 0.2), GROUND)
	b.boxp(P(Color("5b6a73"), 0.5, 0.4), Vector3(bx - 0.4, 0.97, zb + 1.1), Vector3(0.3, 0.04, 0.5), GROUND)
	# はしご
	b.bar(P(Color("c8a96a")), Vector3(x1 - 0.6, 0.0, zb + 0.5), Vector3(x1 - 0.6, 3.1, zb + 0.15), 0.07)
	b.bar(P(Color("c8a96a")), Vector3(x1 - 0.1, 0.0, zb + 0.5), Vector3(x1 - 0.1, 3.1, zb + 0.15), 0.07)
	for lx: float in [x1 - 0.6, x1 - 0.1]:
		_solid_bar(b, Vector3(lx, 0.0, zb + 0.5), Vector3(lx, 3.1, zb + 0.15), Vector2(0.07, 0.07))
	for k in 8:
		var yy := 0.3 + k * 0.38
		b.bar(P(Color("c8a96a")), Vector3(x1 - 0.6, yy, zb + 0.46 - yy * 0.1), Vector3(x1 - 0.1, yy, zb + 0.46 - yy * 0.1), 0.04)


static func _forklift(b: Look.Batch, pos: Vector3, yaw: float, paint := Color("d9a441")) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	var body := P(paint, 0.6)
	var dark := P(Color("33373a"), 0.6, 0.4)
	var tire := P(Color("202224"), 0.9)
	b.box(body, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.2)), Vector3(1.05, 0.7, 1.7), GROUND)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.2)), Vector3(1.05, 0.7, 1.7))
	b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -1.1)), Vector3(1.0, 0.8, 0.3), GROUND)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -1.1)), Vector3(1.0, 0.8, 0.3))
	# 後部カウンターウェイトの面と排熱スリット、左右の乗降ステップ。
	b.box(body, at * Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0, 0.81, -0.96)), Vector3(0.99, 0.24, 0.42), ALL)
	for k in 4:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(-0.3 + k * 0.2, 0.66, -1.256)), Vector3(0.12, 0.25, 0.012), ALL)
	for sx: float in [-1.0, 1.0]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.58, 0.38, -0.3)), Vector3(0.19, 0.08, 0.48), ALL)
		b.box(P(Color("f4cf6a")), at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.45, 0.85, 0.57)), Vector3(0.14, 0.13, 0.05), ALL)
	b.box(P(Color("2d3035")), at * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -0.5)), Vector3(0.7, 0.12, 0.6), GROUND)
	b.box(P(Color("2d3035")), at * Transform3D(Basis.IDENTITY, Vector3(0, 1.3, -0.72)), Vector3(0.7, 0.55, 0.1), GROUND)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 1.3, -0.72)), Vector3(0.7, 0.55, 0.1))
	b.bar(dark, at * Vector3(0, 0.9, 0.18), at * Vector3(0, 1.38, 0.32), 0.05)
	_ring(b, dark, at * Transform3D(Basis(Vector3.RIGHT, 0.28), Vector3(0, 1.4, 0.32)), 0.16, 0.02, false)
	for sx: float in [-0.5, 0.5]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx, 1.55, 0.25)), Vector3(0.07, 1.8, 0.07), GROUND)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx, 1.55, -0.85)), Vector3(0.07, 1.8, 0.07), GROUND)
		for z: float in [0.25, -0.85]:
			b.solid(at * Transform3D(Basis.IDENTITY, Vector3(sx, 1.55, z)), Vector3(0.07, 1.8, 0.07))
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.7, 0.9, 0.78)), Vector3(0.08, 1.8, 0.1), GROUND)
		b.solid(at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.7, 0.9, 0.78)), Vector3(0.08, 1.8, 0.1))
		var guide := P(Color("626c70"), 0.48, 0.55)
		b.box(guide, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.281, 0.96, 0.81)), Vector3(0.044, 1.64, 0.076), ALL)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.31, 0.96, 0.857)), Vector3(0.075, 1.64, 0.022), ALL)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.35, 0.1, 1.0)), Vector3(0.12, 0.05, 1.0), ALL)
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.35, 0.27, 0.89)), Vector3(0.12, 0.34, 0.08), ALL)
		b.box(guide, at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.269, 0.3, 0.867)), Vector3(0.105, 0.27, 0.065), ALL)
		b.solid(at * Transform3D(Basis.IDENTITY, Vector3(sx * 0.7, 0.1, 1.0)), Vector3(0.12, 0.05, 1.0))
		for wz: float in [0.35, -0.85]:
			b.cyl(tire, at * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 1.2 + 0.1, 0.28, wz)), 0.28, 0.2, 12, -1.0, true, true)
			b.solid(at * Transform3D(Basis.IDENTITY, Vector3(sx * 1.2, 0.28, wz)), Vector3(0.2, 0.53, 0.53))
			b.cyl(dark, at * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 1.2 + (0.14 if sx > 0 else -0.1), 0.28, wz)), 0.12, 0.04, 10, -1.0, true, true)
	b.box(body, at * Transform3D(Basis.IDENTITY, Vector3(0, 2.5, -0.3)), Vector3(1.15, 0.06, 1.2), GROUND)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 2.5, -0.3)), Vector3(1.15, 0.06, 1.2))
	b.box(Look.mat("lit", Color("ffb040")), at * Transform3D(Basis.IDENTITY, Vector3(0, 2.62, -0.3)), Vector3(0.16, 0.12, 0.16), GROUND)
	b.box(P(Color("c9a46c")), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 1.2)), Vector3(0.7, 0.5, 0.5), GROUND)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 1.2)), Vector3(0.7, 0.5, 0.5))
	for x: float in [-0.21, 0.21]:
		b.box(P(Color("e2c391")), at * Transform3D(Basis.IDENTITY, Vector3(x, 0.655, 1.2)), Vector3(0.12, 0.01, 0.5), ALL)
	# マスト上端と下端の横桟、昇降台、後ろから伸びるシリンダー。
	for y: float in [0.17, 1.74]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(0, y, 0.769)), Vector3(0.68, 0.085, 0.095), ALL)
	for y: float in [0.23, 0.40]:
		b.box(dark, at * Transform3D(Basis.IDENTITY, Vector3(0, y, 0.886)), Vector3(0.76, 0.077, 0.065), ALL)
	b.cyl(dark, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.18, 0.733)), 0.061, 0.96, 12)
	b.cyl(P(Color("aebbc1"), 0.32, 0.72), at * Transform3D(Basis.IDENTITY, Vector3(0, 1.13, 0.733)), 0.031, 0.59, 12)


static func _pallet(b: Look.Batch, at: Transform3D, y: float) -> void:
	var w := Look.mat("wood", Color("cfa56a"))
	var end := P(Color("a47b49"), 0.9)
	for k in 5:
		var plank_z := -0.33 + k * 0.165
		b.box(w, at * Transform3D(Basis.IDENTITY, Vector3(0, y + 0.13, plank_z)), Vector3(1.194, 0.025, 0.14), GROUND)
		for x: float in [-0.598, 0.598]:
			b.box(end, at * Transform3D(Basis.IDENTITY, Vector3(x, y + 0.13, plank_z)), Vector3(0.004, 0.025, 0.14), ALL)
	for k in 3:
		b.box(w, at * Transform3D(Basis.IDENTITY, Vector3(0, y + 0.075, -0.33 + k * 0.33)), Vector3(1.2, 0.09, 0.09), GROUND)
		b.box(w, at * Transform3D(Basis.IDENTITY, Vector3(0, y + 0.012, -0.33 + k * 0.33)), Vector3(1.2, 0.025, 0.1), GROUND)


static func _pallet_stack(b: Look.Batch, pos: Vector3, yaw: float, n: int, loaded: bool) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	var deck_y := n * 0.143
	for k in n:
		_pallet(b, at, k * 0.143)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, deck_y * 0.5, 0)), Vector3(1.2, deck_y, 0.8))
	if loaded:
		_pallet_carton(b, at, Vector3(-0.279, deck_y, 0), Vector3(0.54, 0.46, 0.68), Color("b58b55"))
		_pallet_carton(b, at, Vector3(0.279, deck_y, 0), Vector3(0.54, 0.46, 0.68), Color("c29b66"))
		_pallet_carton(b, at, Vector3(0.03, deck_y + 0.46, 0.015), Vector3(0.65, 0.26, 0.49), Color("ccaa77"))


static func _pallet_carton(b: Look.Batch, at: Transform3D, floor: Vector3, size: Vector3, color: Color) -> void:
	var center := floor + Vector3.UP * size.y * 0.5
	var box := at * Transform3D(Basis.IDENTITY, center)
	b.box(P(color, 0.91), box, size, ALL)
	b.solid(box, size)
	var tape := P(color.lightened(0.26), 0.68)
	b.box(tape, at * Transform3D(Basis.IDENTITY, floor + Vector3(0, size.y, 0)),
			Vector3(0.066, 0.003, size.z + 0.002), ALL)
	for side: float in [-1.0, 1.0]:
		b.box(tape, at * Transform3D(Basis.IDENTITY, floor + Vector3(0, size.y - 0.038, side * size.z * 0.5)),
				Vector3(0.066, 0.076, 0.004), ALL)
	b.box(P(Color("dbcfb3")), at * Transform3D(Basis.IDENTITY, center + Vector3(0.13, 0, size.z * 0.5)),
			Vector3(0.105, 0.068, 0.003), ALL)


static func _crate(b: Look.Batch, pos: Vector3, size: Vector3, yaw: float) -> void:
	var w := Look.mat("wood", Color("b58c57"))
	var d := Look.mat("wood", Color("8a6a43"))
	var at := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, size.y * 0.5, 0))
	b.box(d, at, Vector3(size.x - 0.05, size.y - 0.04, size.z - 0.05), GROUND)
	b.solid(at, size)
	var plank_h := (size.y - 0.035) / 3.0
	for k in 3:
		var y := -size.y * 0.5 + 0.018 + plank_h * (k + 0.5)
		for side: float in [-1.0, 1.0]:
			b.box(w, at * Transform3D(Basis.IDENTITY, Vector3(0, y, side * (size.z - 0.028) * 0.5)),
					Vector3(size.x, plank_h - 0.006, 0.03), ALL)
			b.box(w, at * Transform3D(Basis.IDENTITY, Vector3(side * (size.x - 0.029) * 0.5, y, 0)),
					Vector3(0.03, plank_h - 0.006, size.z - 0.06), ALL)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(d, at * Transform3D(Basis.IDENTITY, Vector3(sx * (size.x * 0.5 - 0.04), 0, sz * (size.z * 0.5 - 0.04))), Vector3(0.09, size.y + 0.02, 0.09), GROUND)
	b.box(d, at * Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0)), Vector3(size.x + 0.03, 0.06, size.z + 0.03), GROUND)


static func _crate_stack(b: Look.Batch, pos: Vector3, rng: RandomNumberGenerator) -> void:
	_crate(b, pos, Vector3(1.0, 0.8, 0.8), 0.1)
	_crate(b, pos + Vector3(1.1, 0, 0.1), Vector3(0.9, 0.7, 0.8), -0.1)
	_crate(b, pos + Vector3(0.45, 0.8, 0.0), Vector3(0.8, 0.7, 0.7), 0.3)


static func _cardboard_pile(b: Look.Batch, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var cols := [Color("c9a46c"), Color("b98a55"), Color("d6b27a"), Color("c09a60")]
	for k in 3:
		for j in 2 - (k / 2):
			var p := pos + Vector3(j * 0.95 + (0.5 if k == 1 else 0.0), k * 0.5, 0)
			var at := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)), p + Vector3(0, 0.25, 0))
			b.box(P(cols[(k + j) % 4], 0.95), at, Vector3(0.9, 0.5, 0.7), GROUND)
			b.solid(at, Vector3(0.9, 0.5, 0.7))
			b.box(P(Color("e0cda0"), 0.9), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.255, 0)), Vector3(0.12, 0.01, 0.7), ALL)
			b.box(P(Color("e0cda0"), 0.9), at * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.353)), Vector3(0.12, 0.5, 0.008), ALL)
			b.box(P(PAPER), at * Transform3D(Basis.IDENTITY, Vector3(-0.23, 0.04, 0.36)), Vector3(0.24, 0.16, 0.01), ALL)


static func _drum(b: Look.Batch, pos: Vector3, c: Color) -> void:
	b.cyl(P(c, 0.54, 0.15), Transform3D(Basis.IDENTITY, pos), 0.29, 0.882, 12, -1.0, false)
	b.solidp(pos + Vector3(0, 0.44, 0), Vector3(0.51, 0.88, 0.51))
	for y: float in [0.18, 0.64]:
		b.cylp(P(c.darkened(0.2), 0.45, 0.4), pos + Vector3(0, y, 0), 0.298, 0.05, 12)
	_ring(b, P(c.darkened(0.26), 0.54, 0.18), Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.875, 0)), 0.285, 0.026, false)
	b.cylp(P(c.darkened(0.25), 0.52, 0.18), pos + Vector3(0, 0.858, 0), 0.281, 0.012, 12)
	for cap: Vector3 in [Vector3(0.12, 0.87, 0.04), Vector3(-0.19, 0.87, -0.08)]:
		b.cylp(P(Color("51565a"), 0.52, 0.62), pos + cap, 0.035 if cap.x > 0.0 else 0.021, 0.012, 8)


static func _cone(b: Look.Batch, pos: Vector3) -> void:
	b.boxp(P(Color("2d3035"), 0.8), pos + Vector3(0, 0.015, 0), Vector3(0.38, 0.03, 0.38), GROUND)
	b.cylp(P(Color("e8672f"), 0.6), pos + Vector3(0, 0.03, 0), 0.17, 0.7, 8, 0.045)
	b.cylp(P(Color("f1ece0"), 0.6), pos + Vector3(0, 0.3, 0), 0.128, 0.16, 8, 0.1)
	b.solidp(pos + Vector3(0, 0.015, 0), Vector3(0.38, 0.03, 0.38))
	b.solidp(pos + Vector3(0, 0.21, 0), Vector3(0.23, 0.36, 0.23))
	b.solidp(pos + Vector3(0, 0.54, 0), Vector3(0.12, 0.3, 0.12))


static func _tires(b: Look.Batch, pos: Vector3, n: int) -> void:
	for k in n:
		var at := Transform3D(Basis.IDENTITY, pos + Vector3(0.02 * (k % 2), k * 0.2 + 0.1, 0))
		_ring(b, P(Color("2a2c2e"), 0.95), at, 0.265, 0.19, true)
		_ring(b, P(Color("34383a"), 0.9), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.081, 0)), 0.26, 0.025, false)
		for j in 18:
			var a := j * TAU / 18.0
			var shoulder := Vector3(cos(a) * 0.35, 0.022 * (1 - 2 * (j % 2)), sin(a) * 0.35)
			b.box(P(Color("222426"), 0.95), at * Transform3D(Basis(Vector3.UP, -a), shoulder),
					Vector3(0.022, 0.083, 0.050), ALL)


static func _pipes(b: Look.Batch, pos: Vector3) -> void:
	var cols := [Color("d8d4c4"), Color("5b8fb0"), Color("d8d4c4")]
	for row in 3:
		for k in 4 - row:
			var p := pos + Vector3(0, 0.16 + row * 0.28, (k + row * 0.5) * 0.3)
			b.cyl(P(cols[row], 0.5), Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(1.5, 0, 0)), 0.14, 3.0, 10, -1.0, true, true)
			# 穴を見せる端面。束の下と上を別の箱にして、外形から大きくはみ出さない。
			b.cyl(P(Color("343c40"), 0.95), Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(1.505, 0, 0)), 0.11, 0.004, 10, -1.0, true, true)
			b.cyl(P(Color("343c40"), 0.95), Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(-1.501, 0, 0)), 0.11, 0.004, 10, -1.0, true, true)
			b.solidp(p, Vector3(3.0, 0.25, 0.25))
	b.boxp(P(Color("6b5a48")), pos + Vector3(-1.2, 0.3, 0.5), Vector3(0.08, 0.6, 1.4), GROUND)
	b.boxp(P(Color("6b5a48")), pos + Vector3(1.0, 0.3, 0.5), Vector3(0.08, 0.6, 1.4), GROUND)
	for x: float in [-1.2, 1.0]:
		b.solidp(pos + Vector3(x, 0.3, 0.5), Vector3(0.08, 0.6, 1.4))


static func _light_stand(b: Look.Batch, pos: Vector3, yaw: float) -> void:
	var dark := P(Color("2a2d31"), 0.5, 0.5)
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	for k in 3:
		var a := TAU * k / 3.0
		b.bar(dark, at * Vector3(0, 1.5, 0), at * Vector3(cos(a) * 0.65, 0.0, sin(a) * 0.65), 0.04)
		_solid_bar(b, at * Vector3(0, 1.5, 0), at * Vector3(cos(a) * 0.65, 0.0, sin(a) * 0.65), Vector2(0.04, 0.04))
		b.bar(dark, at * Vector3(0, 0.77, 0), at * Vector3(cos(a) * 0.37, 0.64, sin(a) * 0.37), 0.021, ALL)
		b.box(dark, at * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.65, 0.026, sin(a) * 0.65)),
				Vector3(0.10, 0.05, 0.07), ALL)
	b.bar(dark, at * Vector3(0, 0.0, 0), at * Vector3(0, 1.9, 0), 0.05)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Vector3(0.05, 1.9, 0.05))
	var head := at * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 2.0, 0.0))
	b.box(dark, head * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.05)), Vector3(0.42, 0.36, 0.24), ALL)
	b.solid(head, Vector3(0.42, 0.36, 0.34))
	for s: float in [-1.0, 1.0]:
		b.box(dark, head * Transform3D(Basis.IDENTITY, Vector3(s * 0.187, 0, 0.122)), Vector3(0.046, 0.36, 0.10), ALL)
		b.box(dark, head * Transform3D(Basis.IDENTITY, Vector3(0, s * 0.158, 0.122)), Vector3(0.33, 0.044, 0.10), ALL)
		var mount := at * Vector3(s * 0.24, 1.96, 0)
		b.bar(dark, at * Vector3(s * 0.24, 1.81, 0), mount, 0.031, ALL)
		b.cyl(P(Color("849095"), 0.5, 0.5), Transform3D(at.basis * Basis(Vector3.BACK, -s * PI * 0.5),
				mount - at.basis.x * s * 0.012), 0.036, 0.03, 10)
	b.bar(dark, at * Vector3(-0.24, 1.81, 0), at * Vector3(0.24, 1.81, 0), 0.032, ALL)
	b.box(Look.mat("lit", Color("fff3c8")), head * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.106)),
			Vector3(0.313, 0.264, 0.023), ALL)
	for sx: float in [-0.25, 0.25]:
		b.box(dark, at * Transform3D(Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.UP, sx * 1.4), Vector3(sx, 2.0, 0.28)), Vector3(0.02, 0.34, 0.18), ALL)


static func _dumpster(b: Look.Batch, pos: Vector3, yaw: float, c: Color) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	var body := P(c, 0.55, 0.15)
	var trim := P(c.darkened(0.26), 0.54, 0.2)
	var steel := P(Color("515b60"), 0.54, 0.55)
	var rubber := P(Color("24272a"), 0.92)
	b.extrude(body, at, [Vector2(-0.83, 0.23), Vector2(0.83, 0.23), Vector2(0.94, 1.15),
			Vector2(-0.94, 1.15)], 0.99)
	b.box(trim, at * Transform3D(Basis.IDENTITY, Vector3(0, 1.125, 0)), Vector3(1.94, 0.07, 1.04), ALL)
	for side: float in [-1.0, 1.0]:
		var lid := at * Transform3D(Basis(Vector3.BACK, -side * 0.12), Vector3(side * 0.47, 1.187, 0))
		b.box(trim, lid, Vector3(0.94, 0.06, 1.06), ALL)
		b.cyl(steel, at * Transform3D(Basis(Vector3.BACK, -PI * 0.5),
				Vector3(side * 0.48 - 0.117, 1.19, -0.528)), 0.036, 0.234, 10)
		b.bar(steel, lid * Vector3(-0.105, 0.055, 0.42), lid * Vector3(0.105, 0.055, 0.42), 0.025, ALL)
		for x: float in [-0.105, 0.105]:
			b.bar(steel, lid * Vector3(x, 0.018, 0.42), lid * Vector3(x, 0.055, 0.42), 0.022, ALL)
		for z: float in [-0.38, 0.38]:
			var wheel := Vector3(side * 0.69, 0.098, z)
			b.cyl(rubber, at * Transform3D(Basis(Vector3.BACK, -PI * 0.5), wheel - Vector3(0.043, 0, 0)),
					0.098, 0.086, 12, -1.0, true, true)
			b.box(steel, at * Transform3D(Basis.IDENTITY, wheel + Vector3(side * 0.056, 0.083, 0)),
					Vector3(0.032, 0.17, 0.107), ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), Vector3(1.9, 1.2, 1.0))


static func _vending(b: Look.Batch, pos: Vector3, yaw: float, c: Color, root: Node3D) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	# 採用済みの日本型自販機。プロップ生成/ID登録を通さず、固定の背景として置く。
	# 元モデルは Y上、正面+Z。商品窓・投入口・受取口のある形を、従来の外寸へ合わせる。
	var model := VENDING_MODEL.instantiate() as Node3D
	model.name = "OfficeVending"
	root.add_child(model)
	model.transform = at * Transform3D(Basis.IDENTITY.scaled(Vector3(0.9 / 0.82, 1.86 / 1.5, 0.78 / 0.655)), Vector3(0, 0, -0.0375 * 0.78 / 0.655))
	# 既存の棚と取出口を使い、商品窓だけ枠の内側に透明板をはめる。
	var glazing := MeshInstance3D.new()
	glazing.name = "DisplayGlazing"
	var pane := BoxMesh.new()
	pane.size = Vector3(0.630, 0.632, 0.003)
	glazing.mesh = pane
	glazing.position = Vector3(-0.05, 1.11, 0.314)
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(0.75, 0.88, 0.91, 0.13)
	clear.roughness = 0.12
	glazing.material_override = clear
	glazing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null and material.resource_name.contains("cobalt"):
				var painted := material.duplicate() as StandardMaterial3D
				painted.albedo_color = c
				mesh.set_surface_override_material(surface, painted)
	model.add_child(glazing)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.93, 0)), Vector3(0.9, 1.86, 0.78))


static func _bench(b: Look.Batch, pos: Vector3, yaw: float) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	var w := Look.mat("wood", Color("a8845a"))
	var iron := P(Color("33373a"), 0.6, 0.5)
	for k in 3:
		b.box(w, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.46, -0.16 + k * 0.16)), Vector3(1.6, 0.05, 0.14), GROUND)
		b.box(w, at * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.78 + k * 0.14, -0.28)), Vector3(1.6, 0.1, 0.04), ALL)
		b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.46, -0.16 + k * 0.16)), Vector3(1.6, 0.05, 0.14))
		b.solid(at * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.78 + k * 0.14, -0.28)), Vector3(1.6, 0.1, 0.04))
	for sx: float in [-0.7, 0.7]:
		b.box(iron, at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.23, 0)), Vector3(0.06, 0.46, 0.5), GROUND)
		b.box(iron, at * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(sx, 0.7, -0.28)), Vector3(0.06, 0.6, 0.05), GROUND)
		b.solid(at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.23, 0)), Vector3(0.06, 0.46, 0.5))
		b.solid(at * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(sx, 0.7, -0.28)), Vector3(0.06, 0.6, 0.05))
		# 座板を支える鋼の桟、地面に載る足、木を留めるボルト。
		b.box(iron, at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.41, 0)), Vector3(0.08, 0.06, 0.52), ALL)
		b.box(iron, at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.035, 0)), Vector3(0.18, 0.07, 0.56), ALL)
		for z: float in [-0.16, 0, 0.16]:
			b.cyl(P(Color("adae9c"), 0.45, 0.7), at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.487, z)), 0.014, 0.006, 6)
		b.box(iron, at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.465, -0.246)), Vector3(0.12, 0.065, 0.057), ALL)
		b.box(P(Color("292d30")), at * Transform3D(Basis.IDENTITY, Vector3(sx, 0.012, 0)),
				Vector3(0.17, 0.024, 0.50), ALL)
	b.box(iron, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.24, -0.16)), Vector3(1.4, 0.05, 0.05), ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(0, 0.24, -0.16)), Vector3(1.4, 0.05, 0.05))


static func _bin(b: Look.Batch, pos: Vector3) -> void:
	b.cyl(P(Color("5a6a70"), 0.50, 0.4), Transform3D(Basis.IDENTITY, pos), 0.24, 0.714, 16, -1.0, false)
	b.solidp(pos + Vector3(0, 0.35, 0), Vector3(0.43, 0.7, 0.43))
	var iron := P(Color("33373a"), 0.5, 0.4)
	var lining := P(Color("3d4749"), 0.73, 0.25)
	b.cylp(lining, pos + Vector3(0, 0.22, 0), 0.21, 0.035, 16)
	for i in 16:
		var theta := TAU * i / 16.0
		var next := TAU * (i + 1) / 16.0
		var a := Vector3(cos(theta), 0, sin(theta))
		var d := Vector3(cos(next), 0, sin(next))
		var mouth := pos + Vector3.UP * 0.714
		b.poly_out(iron, [mouth + a * 0.24, mouth + d * 0.24,
				mouth + d * 0.207, mouth + a * 0.207], Vector3.UP)
		b.poly_out(lining, [mouth + a * 0.207, mouth + d * 0.207, pos + d * 0.207 + Vector3.UP * 0.25,
				pos + a * 0.207 + Vector3.UP * 0.25], -(a + d))
	for k in 10:
		var a := TAU * k / 10.0
		b.box(iron, Transform3D(Basis(Vector3.UP, -a), pos + Vector3(cos(a) * 0.235, 0.36, sin(a) * 0.235)), Vector3(0.018, 0.61, 0.025), ALL)
	for sx: float in [-1.0, 1.0]:
		b.boxp(iron, pos + Vector3(sx * 0.26, 0.57, 0), Vector3(0.08, 0.1, 0.12), ALL)


static func _bike(b: Look.Batch, pos: Vector3, yaw: float, c: Color) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), pos)
	var tire := P(Color("202224"), 0.9)
	var frame := P(c, 0.4, 0.5)
	var steel := P(Color("b9c2c5"), 0.4, 0.8)
	for wx: float in [-0.5, 0.5]:
		var wheel := at * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.34, 0))
		_ring(b, tire, wheel, 0.31, 0.06, true)
		_ring(b, steel, wheel, 0.275, 0.016, false)
		for j in 8:
			var a := TAU * j / 8.0
			b.bar(steel, wheel.origin, wheel * Vector3(cos(a) * 0.275, 0, sin(a) * 0.275), 0.005)
		b.cyl(steel, wheel, 0.035, 0.07, 8, -1.0, true, true)
	var bb := at * Vector3(0.0, 0.34, 0)
	var seat := at * Vector3(-0.2, 0.84, 0)
	var head := at * Vector3(0.38, 0.9, 0)
	b.bar(frame, bb, seat, 0.035)
	b.bar(frame, bb, head, 0.035)
	b.bar(frame, seat, head, 0.035)
	b.bar(frame, at * Vector3(-0.5, 0.34, 0), bb, 0.03)
	b.bar(frame, at * Vector3(-0.5, 0.34, 0), seat, 0.03)
	var crown := at * Vector3(0.42, 0.76, 0)
	b.bar(frame, head, crown, 0.044, ALL)
	for s: float in [-1.0, 1.0]:
		b.bar(frame, crown, at * Vector3(0.5, 0.34, s * 0.054), 0.029, ALL)
		b.bar(frame, seat, at * Vector3(-0.5, 0.34, s * 0.05), 0.022, ALL)
		var pedal := at * Vector3(s * 0.075, 0.34 - s * 0.095, s * 0.16)
		b.bar(steel, at * Vector3(0, 0.34, s * 0.085), pedal, 0.019, ALL)
		b.box(tire, Transform3D(at.basis, pedal), Vector3(0.061, 0.018, 0.083), ALL)
	var axle := at.basis * Basis(Vector3.RIGHT, PI * 0.5)
	b.cyl(steel, Transform3D(axle, at * Vector3(0, 0.34, -0.085)), 0.064, 0.17, 12, -1.0, true, true)
	var chain := P(Color("464b4e"), 0.55, 0.55)
	for yy: float in [0.291, 0.389]:
		b.bar(chain, at * Vector3(0, yy, -0.083), at * Vector3(-0.5, 0.34 + (yy - 0.34) * 0.5, -0.083), 0.012, ALL)
	for pair: Array in [[bb, seat], [bb, head], [seat, head], [at * Vector3(-0.5, 0.34, 0), bb], [at * Vector3(-0.5, 0.34, 0), seat], [head, at * Vector3(0.5, 0.34, 0)]]:
		_solid_bar(b, pair[0], pair[1], Vector2(0.04, 0.04))
	b.bar(tire, at * Vector3(0.36, 0.98, -0.28), at * Vector3(0.36, 0.98, 0.28), 0.03)
	_solid_bar(b, at * Vector3(0.36, 0.98, -0.28), at * Vector3(0.36, 0.98, 0.28), Vector2(0.03, 0.03))
	b.bar(steel, head, at * Vector3(0.36, 0.98, 0), 0.035)
	b.box(tire, at * Transform3D(Basis.IDENTITY, Vector3(-0.22, 0.88, 0)), Vector3(0.22, 0.05, 0.12), ALL)
	b.solid(at * Transform3D(Basis.IDENTITY, Vector3(-0.22, 0.88, 0)), Vector3(0.22, 0.05, 0.12))
	b.box(P(Color("c8ccce"), 0.5, 0.5), at * Transform3D(Basis.IDENTITY, Vector3(-0.5, 0.55, 0)), Vector3(0.3, 0.04, 0.3), ALL)


static func _bike_rack(b: Look.Batch, pos: Vector3) -> void:
	var iron := P(Color("7a8084"), 0.4, 0.6)
	b.bar(iron, pos + Vector3(0, 0.0, -0.2), pos + Vector3(0, 0.0, 3.0), 0.05)
	_solid_bar(b, pos + Vector3(0, 0.025, -0.2), pos + Vector3(0, 0.025, 3.0), Vector2(0.05, 0.05))
	for k in 4:
		for side: float in [-1.0, 1.0]:
			var z := k * 0.95 + side * 0.075
			var a := pos + Vector3(-0.43, 0.025, z)
			var d := pos + Vector3(0.23, 0.025, z)
			var top_a := a + Vector3(0.14, 0.34, 0)
			var top_d := d + Vector3(-0.06, 0.34, 0)
			for pair: Array in [[a, top_a], [top_a, top_d], [top_d, d]]:
				b.bar(iron, pair[0], pair[1], 0.029, ALL)
				_solid_bar(b, pair[0], pair[1], Vector2(0.029, 0.029))


static func _planter(b: Look.Batch, pos: Vector3, len: float, flowers := 0) -> void:
	var concrete := Look.mat("concrete", Color("c4bfb0"))
	b.boxp(concrete, pos + Vector3(0, 0.216, 0), Vector3(len - 0.05, 0.432, 0.55), GROUND)
	b.solidp(pos + Vector3(0, 0.25, 0), Vector3(len, 0.5, 0.6))
	for side: float in [-1.0, 1.0]:
		b.boxp(concrete, pos + Vector3(0, 0.455, side * 0.266), Vector3(len, 0.09, 0.068), ALL)
		b.boxp(concrete, pos + Vector3(side * (len - 0.075) * 0.5, 0.455, 0),
				Vector3(0.075, 0.09, 0.463), ALL)
	b.boxp(P(Color("3a2a20"), 0.95), pos + Vector3(0, 0.436, 0), Vector3(len - 0.14, 0.019, 0.47), ALL)
	Foliage.hedge(b, pos + Vector3(0, 0.445, 0), Vector3(len - 0.25, 0.65, 0.5), flowers)


static func _tree(b: Look.Batch, pos: Vector3, s: float) -> void:
	Foliage.tree(b, pos, s)
	# 葉は通し、幹と植えますだけを実体にする。幹の傾きは Foliage.tree と同じ seed。
	var rng := Foliage._rng(pos)
	var fork := pos + Vector3(rng.randf_range(-0.12, 0.12) * s, 1.6 * s, rng.randf_range(-0.12, 0.12) * s)
	_solid_bar(b, pos + Vector3(0, 0.1 * s, 0), fork, Vector2(0.24, 0.24) * s)
	b.solidp(pos + Vector3(0, 0.07, 0), Vector3(1.3 * s, 0.14, 1.3 * s))


# 斜めに立てかけた書割（石壁・空・丘）
static func _flat(b: Look.Batch, pos: Vector3, k: int) -> void:
	var lean := Basis(Vector3.BACK, -0.17)
	var at := Transform3D(Basis(Vector3.UP, 0.0) * lean, pos + Vector3(-0.1 * (k % 2), 1.35, 0))
	var m: Look.Tint
	match k % 4:
		0:
			m = Look.mat("block", Color("a8aeb2"))
		1:
			m = P(Color("8ec0e0"), 0.9)
		2:
			m = P(Color("7aab68"), 0.9)
		_:
			m = Look.mat("block", Color("c8b896"))
	b.box(m, at, Vector3(0.05, 2.7, 1.0), ALL)
	b.solid(at, Vector3(0.05, 2.7, 1.0))
	var wood := Look.mat("wood", Color("8a6a43"))
	for zz: float in [-0.453, 0.453]:
		b.box(wood, at * Transform3D(Basis.IDENTITY, Vector3(0.051, 0, zz)), Vector3(0.052, 2.66, 0.071), ALL)
		var heel := pos + Vector3(0.30, 0.037, zz)
		b.bar(wood, at * Vector3(0.05, 0.67, zz), heel, 0.045, ALL)
		b.boxp(wood, heel, Vector3(0.24, 0.064, 0.105), ALL)
	for yy: float in [-1.27, 0.05, 1.27]:
		b.box(wood, at * Transform3D(Basis.IDENTITY, Vector3(0.051, yy, 0)), Vector3(0.053, 0.064, 0.94), ALL)
	if k % 4 == 0:
		for t in 3:
			b.box(m, at * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, -0.3 + t * 0.3)), Vector3(0.05, 0.26, 0.2), ALL)


static func _bulletin(b: Look.Batch, pos: Vector3) -> void:
	var post := Look.mat("wood", Color("7a5a3c"))
	for x: float in [-0.85, 0.85]:
		var bracket := P(Color("585c5b"), 0.62, 0.40)
		b.boxp(bracket, pos + Vector3(x, 0.024, 0), Vector3(0.22, 0.048, 0.22), GROUND)
		b.boxp(bracket, pos + Vector3(x, 0.11, 0), Vector3(0.15, 0.18, 0.15), GROUND)
		for y: float in [1.01, 1.90]:
			b.boxp(post, pos + Vector3(x, y, 0), Vector3(0.22, 0.082, 0.115), ALL)
	b.boxp(post, pos + Vector3(-0.85, 1.1, 0), Vector3(0.12, 2.2, 0.12), GROUND)
	b.solidp(pos + Vector3(-0.85, 1.1, 0), Vector3(0.12, 2.2, 0.12))
	b.boxp(post, pos + Vector3(0.85, 1.1, 0), Vector3(0.12, 2.2, 0.12), GROUND)
	b.solidp(pos + Vector3(0.85, 1.1, 0), Vector3(0.12, 2.2, 0.12))
	b.extrude(Look.mat("wood", Color("6b4a30")), Transform3D(Basis.IDENTITY, pos + Vector3(0, 2.2, 0)), [Vector2(-1.1, 0), Vector2(1.1, 0), Vector2(0, 0.45)], 0.6)
	b.boxp(Look.mat("wood", Color("b58a58")), pos + Vector3(0, 1.45, 0.02), Vector3(1.6, 1.05, 0.06), ALL)
	b.boxp(Look.mat("wood", Color("7a5a3c")), pos + Vector3(0, 1.45, 0.0), Vector3(1.72, 1.17, 0.04), ALL)
	b.solidp(pos + Vector3(0, 1.45, 0.02), Vector3(1.72, 1.17, 0.1))
	var cols := [Color("efe6cc"), Color("e8c24a"), Color("8ec0e0"), Color("e8a28a")]
	for k in 6:
		b.boxy(P(cols[k % 4], 0.9), pos + Vector3(-0.55 + (k % 3) * 0.55, 1.2 + (k / 3) * 0.5, 0.06), Vector3(0.42, 0.34, 0.01), 0.0, ALL)


static func _lamp_post(b: Look.Batch, pos: Vector3, root: Node3D, with_light: bool) -> void:
	var iron := P(Color("2f3438"), 0.5, 0.5)
	b.cylp(iron, pos, 0.1, 0.4, 8, 0.07)
	b.cylp(iron, pos + Vector3(0, 0.4, 0), 0.06, 4.8, 8, 0.05)
	b.solidp(pos + Vector3(0, 0.2, 0), Vector3(0.16, 0.4, 0.16))
	b.solidp(pos + Vector3(0, 2.8, 0), Vector3(0.1, 4.8, 0.1))
	b.bar(iron, pos + Vector3(0, 5.15, 0), pos + Vector3(0.7, 5.35, 0), 0.06)
	b.boxp(iron, pos + Vector3(0.85, 5.38, 0), Vector3(0.6, 0.1, 0.28), ALL)
	_solid_bar(b, pos + Vector3(0, 5.15, 0), pos + Vector3(0.7, 5.35, 0), Vector2(0.06, 0.06))
	b.solidp(pos + Vector3(0.85, 5.38, 0), Vector3(0.6, 0.1, 0.28))
	b.boxp(Look.mat("lit", Color("ffe8b0")), pos + Vector3(0.85, 5.31, 0), Vector3(0.5, 0.04, 0.2), ALL)
	if with_light:
		var l := OmniLight3D.new()
		l.position = pos + Vector3(0.85, 5.0, 0)
		l.light_color = Color("ffe0a8")
		l.light_energy = 0.35
		l.omni_range = 7.0
		l.shadow_enabled = false
		root.add_child(l)


# ---- 道の演出：壁のポスター・落書き・街灯・信号 ----

static func _road(b: Look.Batch) -> void:
	var cols := [Color("2f4b6e"), Color("a8442e"), Color("46704f"), Color("8a6940")]
	# 柱と柱の間だけに、塀の面に接する掲示物を残す。
	var bays := [[48.08, 56.78, 65.48, 74.18], [45.62, 53.87, 62.13, 74.51]]
	for side in 2:
		var x := 72.730 if side == 0 else 87.270
		var yaw := PI * 0.5 if side == 0 else -PI * 0.5
		for k in 4:
			var i := (k + side) % cols.size()
			_poster(b, Vector3(x, 1.50, bays[side][k]), yaw, Vector2(0.9, 1.25),
					cols[i], Color("f6efd2"), i)
	# 街灯（歩道に立ち、道の上へ腕を伸ばす）
	var iron := P(Color("2f3438"), 0.5, 0.5)
	for side in 2:
		var px := 73.12 if side == 0 else 86.88
		var dirx := 1.0 if side == 0 else -1.0
		for k in 4:
			var z := 41.0 + k * 12.0 + side * 6.0
			b.cylp(iron, Vector3(px, 0.12, z), 0.09, 0.35, 8, 0.07)
			b.cylp(iron, Vector3(px, 0.47, z), 0.06, 5.3, 8, 0.05)
			b.solidp(Vector3(px, 0.295, z), Vector3(0.15, 0.35, 0.15))
			b.solidp(Vector3(px, 3.12, z), Vector3(0.1, 5.3, 0.1))
			b.bar(iron, Vector3(px, 5.65, z), Vector3(px + dirx * 1.1, 5.9, z), 0.06)
			_solid_bar(b, Vector3(px, 5.65, z), Vector3(px + dirx * 1.1, 5.9, z), Vector2(0.06, 0.06))
			b.boxp(iron, Vector3(px + dirx * 1.35, 5.92, z), Vector3(0.6, 0.1, 0.28), ALL)
			b.solidp(Vector3(px + dirx * 1.35, 5.92, z), Vector3(0.6, 0.1, 0.28))
			b.boxp(Look.mat("lit", Color("ffe8b0")), Vector3(px + dirx * 1.35, 5.85, z), Vector3(0.5, 0.04, 0.2), ALL)
	# 信号機（道の奥、手前を向く）
	var sp := Vector3(86.7, 0.12, 73.0)
	b.cylp(iron, sp, 0.07, 4.2, 8, 0.06)
	b.solidp(sp + Vector3(0, 2.1, 0), Vector3(0.12, 4.2, 0.12))
	b.boxp(P(Color("2d3035"), 0.5, 0.2), sp + Vector3(0, 4.55, 0), Vector3(0.36, 1.0, 0.3), ALL)
	b.solidp(sp + Vector3(0, 4.55, 0), Vector3(0.36, 1.0, 0.3))
	for k in 3:
		var lc: Color = [Color("e84a3a"), Color("e8c24a"), Color("4ec27a")][k]
		var m: Look.Tint = Look.mat("lit", lc) if k == 2 else P(lc.darkened(0.6), 0.4)
		b.boxp(m, sp + Vector3(0, 4.85 - k * 0.3, -0.16), Vector3(0.22, 0.22, 0.03), ALL)
	# 止まれの標識（敷地の出口、道へ出る側へ向く）。赤い八角の板（文字は書かない）
	var stop := Vector3(72.9, 0.0, 26.4)
	b.cylp(iron, stop, 0.04, 2.3, 6)
	b.solidp(stop + Vector3(0, 1.15, 0), Vector3(0.07, 2.3, 0.07))
	b.cyl(P(Color("c4382a"), 0.4), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, PI / 8.0), stop + Vector3(0, 2.4, 0.0)), 0.42, 0.03, 8)
	b.solidp(stop + Vector3(0, 2.4, 0.015), Vector3(0.64, 0.68, 0.03))
	# 道の入口のボラード
	for bx: float in [73.8, 86.2]:
		b.cylp(P(Color("e8c24a"), 0.5), Vector3(bx, 0.0, 24.4), 0.09, 0.8, 8)
		b.solidp(Vector3(bx, 0.4, 24.4), Vector3(0.15, 0.8, 0.15))
		b.cylp(P(Color("2d3035"), 0.5), Vector3(bx, 0.45, 24.4), 0.095, 0.1, 8)


static func _road_gate(b: Look.Batch, root: Node3D) -> void:
	var z := ROAD_END - 0.16
	var steel := P(Color("586b68"), 0.58, 0.4)
	var base := Look.mat("concrete", Color("aaa99a"))
	var pier := Look.mat("block", Color("b8af9c"))
	# 門柱と袖壁を既存の両脇の塀につなぐ。
	for side: float in [-1.0, 1.0]:
		var post_x := 80.0 + side * 4.19
		var post := Vector3(post_x, 1.39, z)
		b.boxp(base, post, Vector3(0.42, 2.78, 0.49), ALL)
		b.solidp(post, Vector3(0.42, 2.78, 0.49))
		b.boxp(base, post + Vector3(0, 1.42, 0), Vector3(0.52, 0.10, 0.58), ALL)
		var wing := Vector3(80.0 + side * 5.86, 1.29, z)
		b.boxp(pier, wing, Vector3(3.26, 2.58, 0.29), ALL)
		b.solidp(wing, Vector3(3.26, 2.58, 0.29))
		b.boxp(base, wing + Vector3(0, 1.32, 0), Vector3(3.26, 0.10, 0.38), ALL)
		var inner := 80.0 + side * 0.045
		var outer := 80.0 + side * 4.04
		var mid := (inner + outer) * 0.5
		var span := absf(outer - inner)
		for y: float in [0.21, 1.48, 2.52]:
			b.boxp(steel, Vector3(mid, y, z), Vector3(span, 0.075, 0.08), ALL)
		for k in 15:
			var x := lerpf(inner, outer, float(k) / 14.0)
			b.boxp(steel, Vector3(x, 1.365, z), Vector3(0.049, 2.31, 0.07), ALL)
		b.bar(steel, Vector3(outer, 0.24, z + 0.037), Vector3(inner, 2.48, z + 0.037), 0.046, ALL)
		for y: float in [0.39, 2.33]:
			b.boxp(steel, Vector3(post_x - side * 0.105, y, z - 0.045),
					Vector3(0.24, 0.115, 0.072), ALL)
			b.cylp(steel, Vector3(outer, y - 0.082, z - 0.04), 0.043, 0.164, 12)
		b.solidp(Vector3(mid, 1.32, z), Vector3(span + 0.065, 2.52, 0.13))
	# 閉じた扉の合わせ目に閂と、桟に取り付けた進入禁止札。
	b.boxp(steel, Vector3(80.0, 1.45, z - 0.054), Vector3(0.39, 0.09, 0.082), ALL)
	var plate := Vector3(79.4, 1.48, z - 0.051)
	b.boxp(P(Color("e6e4d5"), 0.68), plate, Vector3(0.52, 0.46, 0.024), ALL)
	Look.picto(root, Transform3D(Basis(Vector3.UP, PI), plate + Vector3(0, 0, -0.0128)),
			"no_entry", Vector2(0.34, 0.34))
