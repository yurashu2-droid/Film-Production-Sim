extends RefCounted
# 会社の拠点に置く「廃材置き場」と、まわりの景色。
#   ・ユーザー作成の廃材置き場（L01）とコンテナ（L03）を、そのままの形で置く
#   ・部品が千個以上あるので、同じ材質どうしを1つにまとめて描画を軽くする
#   ・歩ける床・囲い・棚など大きい物にだけ当たり判定を付ける（細かい廃材は素通り）
#   ・拠点のまわりを倉庫と塀で囲み、地平線が見えないようにする

const Slots := preload("res://scripts/production_yard_slots.gd")
const Dump := preload("res://scripts/dump_dressing.gd")
const Ward := preload("res://scripts/ward_lot.gd")
const Look := preload("res://scripts/production_look.gd")

const YARD_PATH := "res://assets/stage/yard/dirty_yard_seed_41.glb"
const CONTAINER_PATH := "res://assets/stage/yard/L03_Container_Staged.glb"
const CENTER := Vector3(48.0, 0.03, 16.0)     # ヤードの中心（ワールド）
const YAW := PI * 0.5                         # 入口（ローカル+Z）を東の軽トラ側へ向ける
const CONTAINER_LOCAL := Vector3(11.0, 0.0, -8.0)


static func xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, YAW), CENTER)


# ヤードのローカル座標(x,z)を、ワールドの位置にする
static func to_world(local: Vector2, y: float = 0.08) -> Vector3:
	var p := xform() * Vector3(local.x, 0.0, local.y)
	p.y = CENTER.y + y
	return p


# 種類ごとの置き場所（ワールド）。同じ種類は順番に使う
static func home_slots() -> Dictionary:
	var out := {}
	for kind: String in Slots.SLOTS:
		var pts: Array = []
		for p: Vector2 in Slots.SLOTS[kind]:
			pts.append(to_world(p))
		out[kind] = pts
	return out


static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ScrapYard"
	parent.add_child(root)
	if ResourceLoader.exists(YARD_PATH):
		var src: Node3D = (load(YARD_PATH) as PackedScene).instantiate()
		# 門の扉2枚だけは別にして、開け閉めできるようにする
		# 店の看板と通路の白線は外し、となりの区の粗大ごみ置き場に見せる（dump_dressing.gd）
		_place(root, _merge(src, func(nm: String, box: AABB) -> bool: return _leaf(nm, box) == 0 and not Dump.hidden_part(nm), 0.9), xform())
		_gate(root, src)
		src.free()
	if ResourceLoader.exists(CONTAINER_PATH):
		var box_src: Node3D = (load(CONTAINER_PATH) as PackedScene).instantiate()
		_place(root, _merge(box_src, func(_nm: String, _box: AABB) -> bool: return true, 0.6), xform() * Transform3D(Basis.IDENTITY, CONTAINER_LOCAL))
		box_src.free()
	Dump.build(root, xform())
	Ward.build(root)
	_surroundings(root)
	return root


# 門の扉の部品か（0=ちがう / -1=左の扉 / 1=右の扉）。柱と蝶番は動かさない
static func _leaf(nm: String, box: AABB) -> int:
	if not nm.begins_with("gate"):
		return 0
	if nm.contains("stile") or nm.contains("top bottom") or nm.contains("wire") or nm.contains("diagonal brace"):
		return -1 if box.get_center().x < 0.0 else 1
	return 0


# 門：モデルでは開いた形なので、蝶番を軸に回して閉じる。閉じている間は見えない壁でふさぐ
static func _gate(root: Node3D, src: Node3D) -> void:
	for side: int in [-1, 1]:
		var hinge := Vector3(-3.0 if side < 0 else 2.95, 0.0, 11.97)
		var pivot := Node3D.new()
		pivot.name = "GateL" if side < 0 else "GateR"
		pivot.transform = xform() * Transform3D(Basis.IDENTITY, hinge)
		root.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = _merge(src, func(nm: String, box: AABB) -> bool: return _leaf(nm, box) == side, 99.0)[0]
		mi.position = -hinge
		pivot.add_child(mi)
	var block := StaticBody3D.new()
	block.name = "GateBlock"
	block.collision_layer = 1
	block.collision_mask = 0
	block.transform = xform() * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 12.0))
	root.add_child(block)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 2.4, 0.3)
	cs.shape = bs
	block.add_child(cs)
	set_gate(root, 0.0)


# 門の開き（0=閉じている、1=開いている）
static func set_gate(root: Node3D, open: float) -> void:
	for side: int in [-1, 1]:
		var pivot := root.get_node_or_null("GateL" if side < 0 else "GateR") as Node3D
		if pivot:
			pivot.basis = xform().basis * Basis(Vector3.UP, -side * PI * 0.5 * (1.0 - open))
	Dump.set_lock(root, open)
	var block := root.get_node_or_null("GateBlock") as StaticBody3D
	if block:
		var shut := open < 0.6
		var shape := block.get_child(0) as CollisionShape3D
		if shape.disabled == shut:
			shape.set_deferred("disabled", not shut)


# 門の前（ワールド）。目印や案内に使う
static func gate_point() -> Vector3:
	return to_world(Vector2(0.0, 13.0), 0.0)


# モデルの部品を、材質ごとに1つのメッシュへまとめる。大きい部品からは当たり判定の面も集める
# 戻り値：[ArrayMesh, 当たり判定の面]
static func _merge(src: Node3D, keep: Callable, min_solid: float) -> Array:
	var tools := {}          # 材質 → SurfaceTool
	var faces := PackedVector3Array()
	var stack: Array = [[src, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D and node != src:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).visible:
			var mi := node as MeshInstance3D
			var mesh := mi.mesh
			var box: AABB = t * mesh.get_aabb()
			if keep.call(String(node.name).to_lower(), box):
				for s in mesh.get_surface_count():
					var mat: Material = mi.get_active_material(s)
					if not tools.has(mat):
						var st := SurfaceTool.new()
						st.begin(Mesh.PRIMITIVE_TRIANGLES)
						tools[mat] = st
					(tools[mat] as SurfaceTool).append_from(mesh, s, t)
				if maxf(box.size.x, maxf(box.size.y, box.size.z)) >= min_solid:
					var f := mesh.get_faces()
					for v: Vector3 in f:
						faces.append(t * v)
		for c in node.get_children():
			stack.push_back([c, t])
	var merged := ArrayMesh.new()
	for mat: Material in tools:
		var st: SurfaceTool = tools[mat]
		st.commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, mat)
	return [merged, faces]


static func _place(root: Node3D, made: Array, at: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = at
	root.add_child(body)
	var mi_out := MeshInstance3D.new()
	mi_out.mesh = made[0]
	body.add_child(mi_out)
	var faces: PackedVector3Array = made[1]
	if not faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)


# ---- まわりの景色：倉庫と塀で囲んで、地平線を隠す ----
# 見た目は production_look.gd の Batch でマテリアルごとにまとめる。当たり判定は塀の箱だけ（建物は塀の外で届かない）。
# 建物は「正面(+Z)」をローカルに作り、置く向きだけ回す。西側（x<31.4）は撮影現場の敷地なので何も建てない。

const SIGNS := ["第三倉庫", "資材置場", "搬入口", "共栄物流", "丸山工業", "中古建材", "映像機材", "格安市場", "部品センター", "冷凍倉庫", "松田運送", "B棟"]


static func _surroundings(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var dress := Node3D.new()
	dress.name = "Surroundings"
	root.add_child(dress)
	# 塀（当たり判定つき）
	var walls := Look.Batch.new()
	_perimeter(walls, dress)
	walls.build(dress, "Walls")
	# 敷地の外の地面（建物の足元）
	var ground := Look.Batch.new()
	ground.no_shadow = true
	ground.quad_up(Look.mat("asphalt", Color("4a4e50")), 31.4, 132.0, -40.0, 100.0, -0.2)
	ground.build(dress, "OuterGround")
	# 北・東・南・道沿い・突き当たりの建物。向きは「敷地のほうへ正面」
	_row(dress, "RowNorth", Vector3(31.6, 0, -21.0), Vector3.RIGHT, 106.0, 0.0, rng)
	_row(dress, "RowEast", Vector3(99.0, 0, -18.0), Vector3.BACK, 40.0, -PI * 0.5, rng)
	# 南の列と道の西の列は、区道（ward_lot.gd）の分だけ下げる
	_row(dress, "RowSouth", Vector3(31.6, 0, 50.2), Vector3.RIGHT, 62.0, PI, rng)
	_row(dress, "RoadWest", Vector3(66.5, 0, 47.0), Vector3.BACK, 90.0, PI * 0.5, rng)
	_row(dress, "RoadEast", Vector3(93.7, 0, 38.0), Vector3.BACK, 90.0, -PI * 0.5, rng)
	_row(dress, "RowFar", Vector3(58.0, 0, 94.5), Vector3.RIGHT, 112.0, PI, rng)
	_skyline(dress, rng)
	_poles(dress)


# 塀：ブロック塀＋柱＋笠木。西は撮影現場側の高い塀（波板）
static func _perimeter(b: Look.Batch, dress: Node3D) -> void:
	_wall(b, Vector3(62.0, 1.4, -14.4), Vector3(60.4, 2.8, 0.25))
	_wall(b, Vector3(92.4, 1.4, 11.0), Vector3(0.25, 2.8, 50.4))
	# 南の塀：区の入口（ward_lot.gd の引き戸の門）のところだけ開ける
	var gx: Vector2 = Ward.GATE_X
	_wall(b, Vector3((31.5 + gx.x) * 0.5, 1.4, 36.4), Vector3(gx.x - 31.5, 2.8, 0.25))
	_wall(b, Vector3((gx.y + 72.5) * 0.5, 1.4, 36.4), Vector3(72.5 - gx.y, 2.8, 0.25))
	_wall(b, Vector3(89.9, 1.4, 36.4), Vector3(5.0, 2.8, 0.25))
	# 道の両脇の塀。西側は、区道の出口（z 36.4〜45.6）を開ける
	_wall(b, Vector3(72.6, 1.3, 63.3), Vector3(0.25, 2.6, 35.4))
	_wall(b, Vector3(87.4, 1.3, 58.0), Vector3(0.25, 2.6, 46.0))
	# 西の高い塀：波板と鉄骨の柱。撮影現場側へは何も出さない
	var sheet := Look.mat("metal", Color("8f9aa0"))
	var post := Look.mat("concrete", Color("74777a"))
	b.boxp(sheet, Vector3(31.4, 3.5, 11.0), Vector3(0.5, 7.0, 51.0), Look.Batch.ALL)
	b.solidp(Vector3(31.4, 3.5, 11.0), Vector3(0.5, 7.0, 51.0))
	b.boxp(Look.mat("concrete", Color("8a8d8f")), Vector3(31.4, 7.12, 11.0), Vector3(0.5, 0.25, 51.0), Look.Batch.ALL)
	for z in range(-12, 37, 4):
		b.boxp(post, Vector3(31.77, 3.5, z), Vector3(0.22, 7.0, 0.3), Look.Batch.GROUND)
	# 下の塗り帯と大きな看板（敷地側の面だけ）
	b.boxp(Look.plain(Color("55797c"), 0.8), Vector3(31.69, 0.9, 11.0), Vector3(0.06, 1.8, 51.0), Look.Batch.GROUND)
	b.boxp(Look.plain(Color("e9dcb4"), 0.8), Vector3(31.69, 4.9, 16.0), Vector3(0.06, 1.7, 9.6), Look.Batch.GROUND)
	Look.label(dress, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(31.74, 4.9, 16.0)), "清掃事務所", 0.011, 128, Color("2f7d4f"))
	b.boxp(Look.plain(Color("e9dcb4"), 0.8), Vector3(31.69, 4.9, -4.0), Vector3(0.06, 1.7, 9.6), Look.Batch.GROUND)
	Look.label(dress, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(31.74, 4.9, -4.0)), "搬入口", 0.011, 128, Color("a85a3f"))


static func _wall(b: Look.Batch, c: Vector3, size: Vector3) -> void:
	var m := Look.mat("block", Color("b8af9c"))
	var low := Look.mat("block", Color("5f8082"))
	var cap := Look.mat("concrete", Color("bdb9b0"))
	var along_x := size.x > size.z
	var len := size.x if along_x else size.z
	var th := size.z if along_x else size.x
	b.boxp(m, c, size, Look.Batch.ALL)
	b.solidp(c, size)
	# 足元の青緑の塗り帯と笠木
	var band := Vector3(len, 0.8, th + 0.04) if along_x else Vector3(th + 0.04, 0.8, len)
	b.boxp(low, Vector3(c.x, 0.4, c.z), band, Look.Batch.GROUND)
	var capsz := Vector3(len + 0.1, 0.14, th + 0.22) if along_x else Vector3(th + 0.22, 0.14, len + 0.1)
	b.boxp(cap, Vector3(c.x, c.y + size.y * 0.5 + 0.07, c.z), capsz, Look.Batch.ALL)
	# 4mごとの柱
	var n := int(len / 4.0)
	for k in n + 1:
		var t := -len * 0.5 + 0.3 + k * (len - 0.6) / maxf(float(n), 1.0)
		var psz := Vector3(0.5, size.y + 0.1, th + 0.18) if along_x else Vector3(th + 0.18, size.y + 0.1, 0.5)
		var ppos := Vector3(c.x + t, c.y + 0.05, c.z) if along_x else Vector3(c.x, c.y + 0.05, c.z + t)
		b.boxp(cap, ppos, psz, Look.Batch.GROUND)


# 建物を一列に並べる。start：列の中心線の始点、dir：進む向き、yaw：正面を敷地へ向ける回転
static func _row(dress: Node3D, nm: String, start: Vector3, dir: Vector3, end_coord: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var b := Look.Batch.new()
	var t := 0.0
	var pos := start
	var limit := end_coord - (start.x if absf(dir.x) > 0.5 else start.z)
	var idx := 0
	while t < limit:
		var w := rng.randf_range(9.0, 16.0)
		if t + w > limit + 4.0:
			break
		var h := rng.randf_range(7.5, 13.5)
		if rng.randf() < 0.22:
			h = rng.randf_range(14.0, 17.5)
		var d := 9.0
		var back := rng.randf_range(0.0, 1.2)
		var c := pos + dir * (t + w * 0.5)
		# 奥行きの中心を後ろへずらす（正面を揃えすぎない）。正面はローカル+Z
		var face_dir := Vector3(sin(yaw), 0.0, cos(yaw))
		c -= face_dir * back
		var at := Transform3D(Basis(Vector3.UP, yaw), c)
		_warehouse(b, dress, at, Vector3(w, h, d), rng.randi() % 6, rng)
		t += w + rng.randf_range(0.3, 1.2)
		idx += 1
	b.xf = Transform3D.IDENTITY
	b.build(dress, nm)


# 窓・看板・配管・屋根設備のある倉庫1棟（ローカル：正面が +Z、原点は足元の中心）
static func _warehouse(b: Look.Batch, dress: Node3D, at: Transform3D, size: Vector3, style: int, rng: RandomNumberGenerator) -> void:
	b.xf = at
	var w := size.x
	var h := size.y
	var d := size.z
	var hz := d * 0.5
	var wall: Look.Tint
	var accent: Color
	match style:
		0:
			wall = Look.mat("metal", Color("9ab8b0"))
			accent = Color("e8c24a")
		1:
			wall = Look.mat("metal", Color("d8c08e"))
			accent = Color("3f6f78")
		2:
			wall = Look.mat("block", Color("e6dcc6"))
			accent = Color("c0553d")
		3:
			wall = Look.mat("block", Color("c8806a"))
			accent = Color("f0e6cc")
		4:
			wall = Look.mat("metal", Color("9aaecc"))
			accent = Color("f0b64a")
		_:
			wall = Look.mat("block", Color("b4c4ae"))
			accent = Color("d65a3c")
	var concrete := Look.mat("concrete", Color("9a9a96"))
	var trim := Look.plain(Color("e6e2d6"), 0.8)
	var acc := Look.plain(accent, 0.75)
	var dark := Look.plain(Color("3a3f44"), 0.7, 0.3)
	b.boxp(wall, Vector3(0, h * 0.5, 0), Vector3(w, h, d), Look.Batch.GROUND)
	b.boxp(concrete, Vector3(0, 0.5, 0), Vector3(w + 0.12, 1.0, d + 0.12), Look.Batch.GROUND)
	# 軒（屋根の縁）。切妻屋根のものは三角の屋根を載せる
	b.boxp(Look.mat("concrete", Color("85888a")), Vector3(0, h + 0.15, 0), Vector3(w + 0.5, 0.3, d + 0.5), Look.Batch.ALL)
	var gable := style % 3 == 0 and w < 13.5
	if gable:
		var rise := minf(2.4, w * 0.2)
		b.extrude(Look.mat("metal", Color("6d7378")), Transform3D(Basis.IDENTITY, Vector3(0, h + 0.3, 0)),
				[Vector2(-w * 0.5 - 0.3, 0.0), Vector2(w * 0.5 + 0.3, 0.0), Vector2(0.0, rise)], d + 0.5)
	# 帯の色（会社の塗り分け）
	b.boxp(acc, Vector3(0, h * 0.5 + 0.2, hz + 0.03), Vector3(w + 0.04, 0.5, 0.06), Look.Batch.FACADE)
	# 窓の列
	var rows := [h - 2.2]
	if h > 10.5:
		rows.append(h - 5.4)
	var n := maxi(int((w - 1.6) / 2.7), 1)
	var gap := (w - 1.6) / float(n)
	for ry: float in rows:
		for k in n:
			var x := -w * 0.5 + 0.8 + gap * (k + 0.5)
			var lit := rng.randf() < 0.14
			_window(b, x, ry, hz, trim, lit)
	# 看板（色あせた塗装の文字）
	var words: String = SIGNS[rng.randi() % SIGNS.size()]
	var sw := minf(w - 1.6, 1.25 * words.length() + 1.0)
	var sy := h * 0.5 + 1.8 if h > 9.0 else h * 0.5 + 1.4
	var sx := rng.randf_range(-(w - sw) * 0.4, (w - sw) * 0.4)
	b.boxp(Look.plain(Color("efe6cc"), 0.8), Vector3(sx, sy, hz + 0.06), Vector3(sw, 1.4, 0.12), Look.Batch.FACADE)
	b.boxp(trim, Vector3(sx, sy + 0.72, hz + 0.09), Vector3(sw + 0.1, 0.06, 0.18), Look.Batch.FACADE)
	var em := minf(1.05, (sw - 0.6) / maxf(words.length(), 1.0))
	Look.label(dress, at * Transform3D(Basis.IDENTITY, Vector3(sx, sy, hz + 0.13)), words, em / 128.0, 128, accent.darkened(0.3))
	# 配管：縦の雨どいと軒どい
	var px := w * 0.5 - 0.55
	b.cylp(dark, Vector3(-px, 0.0, hz + 0.16), 0.09, h - 0.1, 8)
	b.cylp(dark, Vector3(px, 0.0, hz + 0.16), 0.09, h - 0.1, 8)
	b.cyl(dark, Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-w * 0.5 - 0.2, h - 0.06, hz + 0.26)), 0.1, w + 0.4, 8)
	# 壁の照明（足元の看板灯）
	var lamp := Look.mat("lit", Color("ffe3a0"))
	for lx: float in [-w * 0.3, w * 0.3]:
		b.boxp(dark, Vector3(lx, 4.6, hz + 0.18), Vector3(0.5, 0.12, 0.3), Look.Batch.FACADE)
		b.boxp(lamp, Vector3(lx, 4.52, hz + 0.2), Vector3(0.36, 0.05, 0.2), Look.Batch.FACADE)
	# 荷揚げ用の梁（屋根の縁から突き出す）
	if style % 2 == 1 and w > 10.0 and not gable:
		var hx := rng.randf_range(-w * 0.3, w * 0.3)
		b.boxp(dark, Vector3(hx, h + 0.55, hz + 0.3), Vector3(0.22, 0.22, 2.6), Look.Batch.ALL)
		b.cylp(dark, Vector3(hx, h - 1.6, hz + 1.4), 0.03, 2.1, 5)
		b.boxp(dark, Vector3(hx, h - 1.7, hz + 1.4), Vector3(0.3, 0.12, 0.3), Look.Batch.ALL)
	if not gable:
		_roof(b, w, h, d, rng)
	# 道に面した側のシャッター
	if rng.randf() < 0.7:
		var sxx := rng.randf_range(-w * 0.25, w * 0.25)
		b.boxp(Look.mat("shutter", Color("c7c9c4")), Vector3(sxx, 2.0, hz + 0.05), Vector3(4.0, 4.0, 0.1), Look.Batch.FACADE)
		b.boxp(trim, Vector3(sxx, 4.12, hz + 0.08), Vector3(4.3, 0.24, 0.16), Look.Batch.FACADE)


static func _window(b: Look.Batch, x: float, y: float, hz: float, trim: Look.Tint, lit: bool) -> void:
	b.boxp(trim, Vector3(x, y, hz + 0.04), Vector3(1.7, 1.2, 0.08), Look.Batch.FACADE)
	b.boxp(Look.mat("lit", Color("ffd98a")) if lit else Look.mat("glass"), Vector3(x, y, hz + 0.085), Vector3(1.5, 1.0, 0.04), Look.Batch.FACADE)
	b.boxp(trim, Vector3(x, y, hz + 0.1), Vector3(0.06, 1.0, 0.03), Look.Batch.FACADE)
	b.boxp(trim, Vector3(x, y - 0.66, hz + 0.1), Vector3(1.95, 0.09, 0.22), Look.Batch.FACADE)


# 平らな屋根の上：室外機・換気口・給水タンク・アンテナ
static func _roof(b: Look.Batch, w: float, h: float, d: float, rng: RandomNumberGenerator) -> void:
	var y := h + 0.3
	var grey := Look.plain(Color("b8bcbc"), 0.6, 0.3)
	var dark := Look.plain(Color("3a3f44"), 0.7, 0.3)
	var xr := maxf(w * 0.5 - 1.4, 0.5)
	var zr := maxf(d * 0.5 - 1.4, 0.5)
	for k in rng.randi_range(1, 3):
		var p := Vector3(rng.randf_range(-xr, xr), y, rng.randf_range(-zr, zr))
		b.boxp(grey, p + Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 1.0), Look.Batch.GROUND)
		b.cylp(dark, p + Vector3(0, 0.9, 0), 0.38, 0.04, 10)
	for k in rng.randi_range(1, 2):
		var p := Vector3(rng.randf_range(-xr, xr), y, rng.randf_range(-zr, zr))
		b.cylp(grey, p, 0.17, 1.3, 8)
		b.cylp(grey, p + Vector3(0, 1.3, 0), 0.34, 0.3, 8, 0.0)
	if rng.randf() < 0.3:
		var p := Vector3(rng.randf_range(-xr, xr), y, rng.randf_range(-zr, zr))
		for lx: float in [-0.7, 0.7]:
			for lz: float in [-0.7, 0.7]:
				b.boxp(dark, p + Vector3(lx, 0.6, lz), Vector3(0.1, 1.2, 0.1), Look.Batch.GROUND)
		b.cylp(Look.mat("metal", Color("9aa6aa")), p + Vector3(0, 1.2, 0), 1.0, 1.8, 12)
		b.cylp(dark, p + Vector3(0, 3.0, 0), 1.08, 0.5, 12, 0.0)
	elif rng.randf() < 0.5:
		var p := Vector3(rng.randf_range(-xr, xr), y, rng.randf_range(-zr, zr))
		b.cylp(dark, p, 0.03, 4.0, 5)
		b.boxp(dark, p + Vector3(0, 3.4, 0), Vector3(1.4, 0.04, 0.04), Look.Batch.ALL)
		b.boxp(dark, p + Vector3(0, 3.8, 0), Vector3(1.0, 0.04, 0.04), Look.Batch.ALL)


# 遠くの高いビル（霧でかすむ）：窓の格子の絵だけ。西（撮影現場側）には置かない
static func _skyline(dress: Node3D, rng: RandomNumberGenerator) -> void:
	var b := Look.Batch.new()
	b.no_shadow = true
	var tints := [Color("c9d1d6"), Color("d6cfc2"), Color("b9c4cc"), Color("cfc6c0")]
	var spots: Array = []
	var x := 36.0
	while x < 132.0:
		spots.append(Vector3(x, 0.0, -48.0 - rng.randf_range(0.0, 10.0)))
		x += rng.randf_range(11.0, 17.0)
	var z := -30.0
	while z < 100.0:
		spots.append(Vector3(124.0 + rng.randf_range(0.0, 8.0), 0.0, z))
		z += rng.randf_range(12.0, 17.0)
	x = 34.0
	while x < 58.0:
		spots.append(Vector3(x, 0.0, 62.0 + rng.randf_range(0.0, 8.0)))
		x += rng.randf_range(11.0, 15.0)
	x = 52.0
	while x < 132.0:
		spots.append(Vector3(x, 0.0, 113.0 + rng.randf_range(0.0, 8.0)))
		x += rng.randf_range(11.0, 16.0)
	for s: Vector3 in spots:
		var tw := rng.randf_range(9.0, 15.0)
		var th := rng.randf_range(18.0, 34.0)
		var td := rng.randf_range(9.0, 14.0)
		var tint: Color = tints[rng.randi() % tints.size()]
		b.boxp(Look.mat("tower", tint), s + Vector3(0, th * 0.5, 0), Vector3(tw, th, td), Look.Batch.GROUND)
		b.boxp(Look.plain(Color("8b8f92"), 0.8), s + Vector3(0, th + 0.2, 0), Vector3(tw + 0.4, 0.4, td + 0.4), Look.Batch.GROUND)
		if rng.randf() < 0.6:
			b.boxp(Look.plain(Color("a9adb0"), 0.7, 0.3), s + Vector3(rng.randf_range(-2, 2), th + 1.1, rng.randf_range(-2, 2)), Vector3(2.4, 1.4, 2.0), Look.Batch.GROUND)
	# 煙突（赤白）と給水塔：空の輪郭に変化をつける
	var red := Look.plain(Color("b9543f"), 0.8)
	var white := Look.plain(Color("ece6d6"), 0.8)
	var base := Vector3(40.0, 0.0, -36.0)
	for k in 6:
		b.cylp(red if k % 2 == 0 else white, base + Vector3(0, k * 4.6, 0), 1.0 - k * 0.04, 4.6, 12, 1.0 - (k + 1) * 0.04)
	var tank := Vector3(112.0, 0.0, 6.0)
	var steel := Look.plain(Color("9aa4a8"), 0.6, 0.3)
	for lx: float in [-1.6, 1.6]:
		for lz: float in [-1.6, 1.6]:
			b.boxp(steel, tank + Vector3(lx, 6.0, lz), Vector3(0.25, 12.0, 0.25), Look.Batch.GROUND)
	b.cylp(Look.plain(Color("c7573f"), 0.7), tank + Vector3(0, 12.0, 0), 3.0, 4.2, 16)
	b.cylp(steel, tank + Vector3(0, 16.2, 0), 3.1, 1.6, 16, 0.0)
	b.build(dress, "Skyline")


# 電柱と電線：北側の塀の外と道沿い。垂れた電線で空に線を引く
static func _poles(dress: Node3D) -> void:
	var b := Look.Batch.new()
	b.no_shadow = true
	var wood := Look.plain(Color("6e5a46"), 0.9)
	var dark := Look.plain(Color("34383c"), 0.7)
	var ins := Look.plain(Color("5a8f8c"), 0.4)
	var line: Array = []
	for k in 6:
		line.append(Vector3(38.0 + k * 11.0, 0.0, -15.4))
	_pole_line(b, line, wood, dark, ins)
	var east: Array = []
	for k in 6:
		east.append(Vector3(72.0, 0.0, 49.0 + k * 9.0))
	_pole_line(b, east, wood, dark, ins)
	var west: Array = []
	for k in 6:
		west.append(Vector3(88.0, 0.0, 44.0 + k * 9.0))
	_pole_line(b, west, wood, dark, ins)
	# 道をまたぐ電線
	for k in 4:
		var z := 49.0 + k * 9.0 + 4.5
		_wire(b, Vector3(72.0, 8.3, z), Vector3(88.0, 8.3, z), 0.7, dark)
	b.build(dress, "Poles")


static func _pole_line(b: Look.Batch, pts: Array, wood: Look.Tint, dark: Look.Tint, ins: Look.Tint) -> void:
	for p: Vector3 in pts:
		b.cylp(wood, p, 0.15, 9.8, 8, 0.11)
		b.boxp(wood, p + Vector3(0, 9.0, 0), Vector3(2.4, 0.13, 0.13), Look.Batch.ALL)
		b.boxp(wood, p + Vector3(0, 8.4, 0), Vector3(1.6, 0.11, 0.11), Look.Batch.ALL)
		for ox: float in [-1.0, 0.0, 1.0]:
			b.cylp(ins, p + Vector3(ox, 9.06, 0), 0.06, 0.22, 6)
		# 変圧器
		b.cylp(dark, p + Vector3(0.3, 6.4, 0.2), 0.3, 0.8, 8)
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var c: Vector3 = pts[k + 1]
		for ox: float in [-1.0, 0.0, 1.0]:
			_wire_lateral(b, a + Vector3(0, 9.15, 0), c + Vector3(0, 9.15, 0), ox, 0.9, dark)
		_wire_lateral(b, a + Vector3(0, 8.45, 0), c + Vector3(0, 8.45, 0), 0.0, 0.7, dark)


# 柱の並びに直交する向きへ ox ずらした電線
static func _wire_lateral(b: Look.Batch, p: Vector3, q: Vector3, ox: float, sag: float, m: Look.Tint) -> void:
	var dir := (q - p).normalized()
	var side := Vector3.UP.cross(dir).normalized() * ox
	_wire(b, p + side, q + side, sag, m)


# 垂れ下がる電線（細い箱を連ねる）
static func _wire(b: Look.Batch, p: Vector3, q: Vector3, sag: float, m: Look.Tint) -> void:
	var seg := 6
	var prev := p
	for k in range(1, seg + 1):
		var t := float(k) / seg
		var cur := p.lerp(q, t)
		cur.y -= sag * 4.0 * t * (1.0 - t)
		var len := prev.distance_to(cur)
		if len > 0.01:
			var basis := Basis.looking_at(cur - prev, Vector3.UP)
			b.box(m, Transform3D(basis, (prev + cur) * 0.5), Vector3(0.05, 0.05, len + 0.02), 15)
		prev = cur
