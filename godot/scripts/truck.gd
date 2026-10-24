extends "res://scripts/prop.gd"
# 搬入口に停まっている軽トラ。荷台に機材を積んで届く。動かせない。
# 車の段階が上がると「ロケバン」に替わる（set_vehicle）。荷台の数値と当たり判定も一緒に替わる。

# 道路とキャラクターに対して存在感を出す。見た目・荷台・当たり判定を同じ倍率に揃える。
const VEHICLE_SCALE := 1.55
var _travel_state := -1
var _cargo_panels: Array = []

const KEI_GLB := "res://assets/stage/kei_truck.glb"
const VAN_GLB := "res://assets/stage/location_van.glb"
# バンの元モデルは全長5.41m×幅2.26m×高さ2.29m。駐車枠（x76..84, z13..23）と現場の駐車位置に収めるため0.9倍にする
# → 全長およそ4.87m、幅2.04m（ミラー込み）、高さ2.06m
const VAN_SCALE := 0.9
const VAN_HATCH_DEG := 95.0   # 後ろのハッチを開ける角度（元モデルの全開）

var vehicle := "kei"          # "kei" | "van"
var _installed := ""          # 実際に組み上がっている車種（空=まだ何も組んでいない）
var _shapes: Array = []
# ロープを掛けるフック（車体から見た位置。実寸）。荷物の上にロープを渡して、端をここに結ぶ（cargo_kit.gd）
var hooks: Array[Vector3] = []
var rope_ceiling := 3.0       # ロープを投げて渡すとき、これより上は越えない（車体から見た高さ）


func build() -> void:
	kind = "truck"
	mass = 800.0
	immovable = true
	hold_min = 3.0
	_install("kei")


# 軽トラ/ロケバンを切り替える。誰が・いつ呼んでも安全で、同じ車種なら何もしない。
# すでに荷台に載っている物は、荷台の高さの差だけ上下にずらす（はみ出す物は荷台の中へ寄せる）
func set_vehicle(which: String) -> void:
	if which != "kei" and which != "van":
		return
	if which == _installed:
		return
	_install(which)


func _install(which: String) -> void:
	_travel_state = -1
	var old_top: float = deck_top if _installed != "" else -1.0
	var old_c := deck_c
	var old_half := deck_half
	_installed = which
	vehicle = which
	if visual != null:
		remove_child(visual)
		visual.queue_free()
		visual = null
	if which == "van":
		_setup_van()
	else:
		_setup_kei()
	_scale_vehicle()
	add_child(visual)
	_build_hooks()
	# 当たり判定は物理の処理中に触れないので、木に入っているときは後回しにする
	if is_inside_tree():
		_rebuild_shapes.call_deferred()
	else:
		_rebuild_shapes()
	if old_top >= 0.0:
		_reseat_riders(old_top, old_c, old_half)


func _setup_kei() -> void:
	label = "軽トラ"
	center = Vector3(0, 0.9, 0)
	half = Vector3(0.9, 0.9, 1.73)
	deck_top = 0.67
	deck_half = Vector2(0.66, 0.92)
	deck_c = Vector2(0, -0.72)
	visual = (load(KEI_GLB) as PackedScene).instantiate()
	_seal_windows(visual)
	# 後ろのあおりを倒して、荷下ろしできる状態にしておく
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X", true, false)
	if tail:
		tail.rotate_object_local(Vector3.RIGHT, -PI * 0.5)


func _setup_van() -> void:
	label = "ロケバン"
	center = Vector3(0, 1.03, 0)
	half = Vector3(0.95, 1.03, 2.44)
	# 荷室の床（ゴムの床）の上面は元モデルで高さ約0.6m。そこから後ろ～運転席の背もたれの手前まで空ける
	deck_top = 0.55
	deck_half = Vector2(0.74, 1.575)
	deck_c = Vector2(0, -0.725)
	var model := (load(VAN_GLB) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * VAN_SCALE
	_adjust_van_wheel(model)
	_seal_windows(model)
	_van_floor_pan(model)
	visual = Node3D.new()
	visual.add_child(model)
	# 荷物が見えるように、後ろのハッチとスライドドアを開け、座席・棚（荷室の改装部分）は外す
	var conv: Node3D = model.find_child("CREW_CONVERSION_ROOT", true, false)
	if conv:
		conv.visible = false
	var hatch: Node3D = model.find_child("REAR_HATCH_PIVOT", true, false)
	if hatch:
		hatch.rotation_degrees.x = VAN_HATCH_DEG
	var slide: Node3D = model.find_child("SLIDING_DOOR_ROOT", true, false)
	if slide:
		slide.position += Vector3(0.13, 0.0, -1.45)
	_van_supports(model, hatch)


# ハッチのガスステーを、開いたハッチの取り付け点へ向け直す（見た目だけ）
func _adjust_van_wheel(model: Node3D) -> void:
	var part: MeshInstance3D = model.find_child("ASSEMBLY_LOCATION_VAN_ROOT",true,false)
	if part == null: return
	var source: ArrayMesh = part.mesh
	var mesh := ArrayMesh.new()
	var region := AABB(Vector3(-0.69,1.16,1.84),Vector3(0.41,0.34,0.32))
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var material: Material = source.surface_get_material(surface)
		if material.resource_name.begins_with("Polymer"):
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				if region.has_point(vertices[i]): vertices[i].z -= 0.30
			arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,material)
	part.mesh = mesh

func _van_supports(model: Node3D, hatch: Node3D) -> void:
	if hatch == null:
		return
	for side in ["L", "R"]:
		var support: Node3D = model.find_child("HATCH_GAS_SUPPORT_" + side, true, false)
		var piston: Node3D = model.find_child("HATCH_GAS_PISTON_" + side, true, false)
		var end: Node3D = model.find_child("HATCH_SUPPORT_END_" + side, true, false)
		if support == null or piston == null or end == null:
			continue
		var to: Vector3 = hatch.transform * end.position - support.position
		var length := to.length()
		if length < 0.3:
			continue
		support.basis = Basis.looking_at(to.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		piston.position.y = (0.25 + length) * 0.5
		piston.scale.y = maxf(0.02, length - 0.25)


# ── 窓ガラスまわりのゴム縁 ──
# 元のモデルは、ガラスが窓穴より一回り小さく、角も丸いので、ガラスと車体の間から向こうが見える。
# ガラスごとに、縁から少し内側に重なり、窓穴の縁の下まで届く黒いゴムの枠を作って、その隙間をふさぐ。
# 枠の外側は、ガラスの長い辺をまっすぐ延ばした角のある形にする（丸い角の外の三角の隙間も埋まる）。
# 枠はガラスの部品の子にするので、ドアやハッチと一緒に動く。大きさはモデルの単位（あとで車ごと拡大される）
const SEAL_INSET := 0.012    # ガラスの縁から内側へ重ねる幅
const SEAL_MARGIN := 0.05    # ガラスの外へ張り出す幅（窓穴の縁の下まで）

func _seal_windows(model: Node) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var rubber: Material = null
		var panes: Array = []
		for surface in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(surface)
			if material == null:
				continue
			var mat_name := material.resource_name.to_lower()
			if mat_name.contains("seal") or (rubber == null and mat_name.contains("polymer")):
				rubber = material
			if mat_name.contains("glass") and not mat_name.contains("headlamp") and not mat_name.contains("defog"):
				panes.append(surface)
		if panes.is_empty():
			continue
		var seal_mat := _seal_material(rubber)
		for surface: int in panes:
			for piece: PackedVector3Array in _glass_pieces(mi.mesh.surface_get_arrays(surface)):
				var seal := _seal_mesh(piece)
				if seal == null:
					continue
				var node := MeshInstance3D.new()
				node.name = "WindowSeal"
				node.mesh = seal
				node.material_override = seal_mat
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mi.add_child(node)


func _seal_material(base: Material) -> Material:
	var mat: StandardMaterial3D
	if base is StandardMaterial3D:
		mat = (base as StandardMaterial3D).duplicate()
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.07, 0.075, 0.085)
		mat.roughness = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# ガラスの面を、つながった1枚ずつに分ける。返すのは、1枚ぶんの三角形の頂点（3つずつ）
func _glass_pieces(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty():
		for i in verts.size():
			index.append(i)
	# 同じ位置の頂点（法線違いで分かれている）を1つにまとめてから、三角形でつなぐ
	var key_of := {}
	var vid := PackedInt32Array()
	vid.resize(verts.size())
	for i in verts.size():
		var key := Vector3i((verts[i] * 10000.0).round())
		if not key_of.has(key):
			key_of[key] = key_of.size()
		vid[i] = key_of[key]
	# 小関数の中から書き換えるので、参照で渡る Array にする（Packed は値渡しで、書き換えが外に届かない）
	var parent: Array[int] = []
	for i in key_of.size():
		parent.append(i)
	var find := func(a: int) -> int:
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	for t in range(0, index.size(), 3):
		var a: int = find.call(vid[index[t]])
		for k in [1, 2]:
			var b: int = find.call(vid[index[t + k]])
			if a != b:
				parent[b] = a
	var groups := {}
	for t in range(0, index.size(), 3):
		var root: int = find.call(vid[index[t]])
		if not groups.has(root):
			groups[root] = PackedVector3Array()
		var tri: PackedVector3Array = groups[root]
		tri.append(verts[index[t]])
		tri.append(verts[index[t + 1]])
		tri.append(verts[index[t + 2]])
		groups[root] = tri
	var pieces: Array = []
	for tri: PackedVector3Array in groups.values():
		var area := 0.0
		for t in range(0, tri.size(), 3):
			area += (tri[t + 1] - tri[t]).cross(tri[t + 2] - tri[t]).length() * 0.5
		# 板の表と裏を数えるので、窓1枚（0.05㎡以上）なら面積はその倍
		if area > 0.1:
			pieces.append(tri)
	return pieces


func _seal_mesh(tri: PackedVector3Array) -> ArrayMesh:
	# 面の向き：いちばん大きい三角形の向きにそろえて足す（表と裏で打ち消さないように）
	var biggest := Vector3.ZERO
	for t in range(0, tri.size(), 3):
		var c := (tri[t + 1] - tri[t]).cross(tri[t + 2] - tri[t])
		if c.length_squared() > biggest.length_squared():
			biggest = c
	var n := Vector3.ZERO
	var center := Vector3.ZERO
	for t in range(0, tri.size(), 3):
		var c := (tri[t + 1] - tri[t]).cross(tri[t + 2] - tri[t])
		n += c if c.dot(biggest) >= 0.0 else -c
	for p in tri:
		center += p
	center /= float(tri.size())
	n = n.normalized()
	var u := (Vector3.UP.cross(n) if absf(n.y) < 0.9 else Vector3.RIGHT.cross(n)).normalized()
	var v := n.cross(u)
	var flat := PackedVector2Array()
	var depth := PackedFloat32Array()
	for p in tri:
		var d := p - center
		flat.append(Vector2(d.dot(u), d.dot(v)))
		depth.append(d.dot(n))
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	if hull.size() < 3:
		return null
	if _signed_area(hull) < 0.0:
		hull.reverse()
	# 曲がったガラス（前の窓）でも縁に沿うよう、枠の奥行きは、いちばん近いガラスの頂点に合わせる
	var hull_depth := PackedFloat32Array()
	for h in hull:
		var best := 1e9
		var at := 0.0
		for i in flat.size():
			var dd := flat[i].distance_squared_to(h)
			if dd < best:
				best = dd
				at = depth[i]
		hull_depth.append(at)
	var outer := _seal_outline(hull)
	# 中心から放射状に、ガラスの縁（内側）と枠の外形（外側）を結んで帯にする
	var angles: Array[float] = []
	for p in hull:
		angles.append(p.angle())
	for p in outer:
		angles.append(p.angle())
	for i in 96:
		angles.append(-PI + TAU * i / 96.0)
	angles.sort()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_in: Array[Vector3] = []
	var ring_out: Array[Vector3] = []
	var last := -10.0
	for a in angles:
		if a - last < 0.0005:
			continue
		last = a
		var dir := Vector2.from_angle(a)
		var hit_in := _ray_polygon(hull, dir)
		var hit_out := _ray_polygon(outer, dir)
		if hit_in.x <= 0.0 or hit_out.x <= 0.0:
			continue
		var edge := int(hit_in.y)
		var d := lerpf(hull_depth[edge], hull_depth[(edge + 1) % hull.size()], hit_in.z)
		var p_in := dir * maxf(hit_in.x - SEAL_INSET, hit_in.x * 0.5)
		var p_out := dir * maxf(hit_out.x, hit_in.x + 0.005)
		ring_in.append(center + u * p_in.x + v * p_in.y + n * d)
		ring_out.append(center + u * p_out.x + v * p_out.y + n * d)
	var count := ring_in.size()
	if count < 3:
		return null
	st.set_normal(n)
	for i in count:
		var j := (i + 1) % count
		st.add_vertex(ring_in[i])
		st.add_vertex(ring_out[i])
		st.add_vertex(ring_out[j])
		st.add_vertex(ring_in[i])
		st.add_vertex(ring_out[j])
		st.add_vertex(ring_in[j])
	return st.commit()


func _signed_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return s * 0.5


# 枠の外形：ガラスの外形（凸包）の長い辺をまっすぐ延ばし、隣どうしの交点を角にして、SEAL_MARGIN だけ外へ広げる
func _seal_outline(hull: PackedVector2Array) -> PackedVector2Array:
	var count := hull.size()
	var fallback := PackedVector2Array()
	for p in hull:
		fallback.append(p + p.normalized() * SEAL_MARGIN)
	# いちばん大きく曲がる頂点から数え始める（まっすぐな辺の途中で切らない）
	var start := 0
	var sharpest := -1.0
	for i in count:
		var e0 := (hull[i] - hull[(i - 1 + count) % count]).normalized()
		var e1 := (hull[(i + 1) % count] - hull[i]).normalized()
		var turn := absf(e0.angle_to(e1))
		if turn > sharpest:
			sharpest = turn
			start = i
	var lines: Array = []   # [向き, 外向きの法線, 外へ出す量]
	var i := 0
	while i < count:
		var a := hull[(start + i) % count]
		var first := (hull[(start + i + 1) % count] - a).normalized()
		var j := i + 1
		while j < count:
			var e := (hull[(start + j + 1) % count] - hull[(start + j) % count]).normalized()
			if absf(first.angle_to(e)) > deg_to_rad(20.0):
				break
			j += 1
		var b := hull[(start + j) % count]
		if a.distance_to(b) >= 0.1:
			var dir := (b - a).normalized()
			var nrm := Vector2(dir.y, -dir.x)
			var off := -1e9
			for p in hull:
				off = maxf(off, p.dot(nrm))
			if lines.is_empty() or absf((lines[-1][0] as Vector2).angle_to(dir)) > deg_to_rad(8.0):
				lines.append([dir, nrm, off + SEAL_MARGIN])
		i = j
	if lines.size() >= 2 and absf((lines[-1][0] as Vector2).angle_to(lines[0][0])) <= deg_to_rad(8.0):
		lines.pop_back()
	if lines.size() < 3:
		return fallback
	var radius := 0.0
	for p in hull:
		radius = maxf(radius, p.length())
	var outline := PackedVector2Array()
	for k in lines.size():
		var l0: Array = lines[k]
		var l1: Array = lines[(k + 1) % lines.size()]
		var turn := (l0[0] as Vector2).angle_to(l1[0])
		if turn <= 0.0 or turn > deg_to_rad(160.0):
			return fallback
		# 2本の直線 p·n0 = o0, p·n1 = o1 の交点
		var n0: Vector2 = l0[1]
		var n1: Vector2 = l1[1]
		var det := n0.x * n1.y - n0.y * n1.x
		if absf(det) < 1e-5:
			return fallback
		var o0: float = l0[2]
		var o1: float = l1[2]
		var corner := Vector2((o0 * n1.y - o1 * n0.y) / det, (n0.x * o1 - n1.x * o0) / det)
		if corner.length() > radius * 2.0 + 0.2:
			return fallback
		outline.append(corner)
	return outline


# 原点から dir 方向の半直線が凸多角形の辺に当たる所：(距離, 辺の番号, 辺の上の割合)。当たらなければ距離は -1
func _ray_polygon(poly: PackedVector2Array, dir: Vector2) -> Vector3:
	var best := Vector3(-1.0, 0.0, 0.0)
	for i in poly.size():
		var a := poly[i]
		var e := poly[(i + 1) % poly.size()] - a
		var den := dir.cross(e)
		if absf(den) < 1e-9:
			continue
		var t := a.cross(e) / den
		var s := a.cross(dir) / den
		if t > 0.0 and s >= -1e-4 and s <= 1.0001 and (best.x < 0.0 or t < best.x):
			best = Vector3(t, float(i), clampf(s, 0.0, 1.0))
	return best


# ── ロケバンの床下 ──
# 荷室のゴムの床は細い板の組み合わせで、壁ぎわ・タイヤハウスの前後に隙間があり、地面とタイヤが車内から見える。
# 床のすぐ下に黒い床板（フロアパン）を張ってふさぐ。後ろのタイヤハウスの所だけは、タイヤが通るので左右を空ける。
# 見た目だけで当たり判定は無い（荷台の当たり判定は _rebuild_shapes のまま）。モデルの単位で、モデルの子にする
func _van_floor_pan(model: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.075, 0.08, 0.09)
	mat.roughness = 0.9
	var y0 := 0.545           # 床板の下面
	var y1 := 0.583           # 床板の上面（ゴムの床の裏 0.585 のすぐ下）
	var rear := -2.62         # 荷室のいちばん後ろ（ゴムの床の後端 -2.64 の少し内側）
	var front := 0.95         # 荷室の前（運転席の後ろ。ゴムの床の幅広い所の前端 0.9 の少し前）
	var arch_z := -1.605      # 後ろのタイヤの中心
	var arch_half := 0.365    # タイヤハウスの外側の丸み（半径0.43）が床の高さで切れる幅
	var pan := Node3D.new()
	pan.name = "FloorPan"
	model.add_child(pan)
	var add := func(x0: float, x1: float, z0: float, z1: float) -> void:
		var box := BoxMesh.new()
		box.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
		var part := MeshInstance3D.new()
		part.mesh = box
		part.material_override = mat
		part.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
		pan.add_child(part)
	# 真ん中：タイヤハウスの内側の壁（x=±0.71）まで
	add.call(-0.72, 0.72, rear, front)
	# 左右：壁（x=±0.925）まで。タイヤハウスの所は空ける
	for side: float in [-1.0, 1.0]:
		var x0 := 0.70 * side
		var x1 := 0.925 * side
		add.call(minf(x0, x1), maxf(x0, x1), rear, arch_z - arch_half)
		add.call(minf(x0, x1), maxf(x0, x1), arch_z + arch_half, front)
	# タイヤハウスの丸い屋根（x=±0.73まで）と内側の板（x=±0.715）の間の細い隙間に、丸い帯をかぶせる
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.428            # 丸い屋根の上面（半径0.425）のすぐ外
	var steps := 24
	for side: float in [-1.0, 1.0]:
		var xa := 0.70 * side
		var xb := 0.745 * side
		for k in steps:
			var a0 := PI * k / steps
			var a1 := PI * (k + 1) / steps
			var p0 := Vector3(0, 0.347 + sin(a0) * r, arch_z + cos(a0) * r)
			var p1 := Vector3(0, 0.347 + sin(a1) * r, arch_z + cos(a1) * r)
			band.set_normal(Vector3(0, sin(a0), cos(a0)))
			band.add_vertex(p0 + Vector3(xa, 0, 0))
			band.add_vertex(p0 + Vector3(xb, 0, 0))
			band.add_vertex(p1 + Vector3(xb, 0, 0))
			band.add_vertex(p0 + Vector3(xa, 0, 0))
			band.add_vertex(p1 + Vector3(xb, 0, 0))
			band.add_vertex(p1 + Vector3(xa, 0, 0))
	var band_mat := mat.duplicate() as StandardMaterial3D
	band_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arch := MeshInstance3D.new()
	arch.name = "WheelArchSeam"
	arch.mesh = band.commit()
	arch.material_override = band_mat
	pan.add_child(arch)


func _rebuild_shapes() -> void:
	for s: Node in _shapes:
		if is_instance_valid(s):
			if s.get_parent() == self:
				remove_child(s)
			s.queue_free()
	_shapes.clear()
	if _installed == "van":
		# 荷室の床・車体の下
		_box(Vector3(0, 0.27, -0.01), Vector3(1.8, 0.54, 4.86))
		# 荷室の左右の壁。右（スライドドア側）は、ドアの開口部ぶん（z -0.53..0.79）を空けて、横からも荷物を狙える
		# 壁と屋根の高さは見た目どおり。後ろ側は壁も屋根も作らない（後ろから荷物を狙え、手を伸ばせる）
		_box(Vector3(-0.84, 1.245, -0.725), Vector3(0.12, 1.41, 3.15))
		_box(Vector3(0.84, 1.245, -1.415), Vector3(0.12, 1.41, 1.77))
		# 運転席とボンネット
		_box(Vector3(0, 0.975, 1.425), Vector3(1.8, 1.95, 1.15))
		_box(Vector3(0, 0.575, 2.21), Vector3(1.8, 1.15, 0.42))
	else:
		_box(Vector3(0, 0.88, 1.0), Vector3(1.7, 1.76, 1.45))
		_box(Vector3(0, 0.44, -0.72), Vector3(1.5, 0.44, 1.95))
	_build_cargo_walls()


func _scale_vehicle() -> void:
	visual.scale *= VEHICLE_SCALE
	center *= VEHICLE_SCALE
	half *= VEHICLE_SCALE
	deck_top *= VEHICLE_SCALE
	deck_half *= VEHICLE_SCALE
	deck_c *= VEHICLE_SCALE


func _box(c: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size * VEHICLE_SCALE
	cs.shape = b
	cs.position = c * VEHICLE_SCALE
	add_child(cs)
	_shapes.append(cs)
	return cs


# 荷台の高さが変わった分だけ、載っている物をずらす（production_prop の昇降荷台と同じ）。
# 横の位置は、新しい荷台に収まるならそのまま、はみ出すなら中へ寄せる
func _reseat_riders(old_top: float, _old_c: Vector2, _old_half: Vector2) -> void:
	if game == null:
		return
	var dy := deck_top - old_top
	var mx := maxf(deck_half.x - 0.1, 0.05)
	var mz := maxf(deck_half.y - 0.16, 0.05)
	for r: RigidBody3D in game.props.values():
		if r == self or r.rider_of != pid:
			continue
		var o: Vector3 = r.ride_local.origin
		o.x = clampf(o.x, deck_c.x - mx, deck_c.x + mx)
		o.z = clampf(o.z, deck_c.y - mz, deck_c.y + mz)
		o.y += dy
		r.ride_local.origin = o
		if is_inside_tree() and r.is_inside_tree():
			r.global_transform = global_transform * r.ride_local


# 荷台の側板と可動パネル。モデルの比率を変えずに、当たり判定を揃える。
func _build_cargo_walls() -> void:
	_cargo_panels.clear()
	if "vehicle" in self and get("vehicle") == "van":
		_box(Vector3(0,2.015,-0.725),Vector3(1.8,0.09,3.15))
		_add_cargo_panel("REAR_HATCH_PIVOT",Vector3(0,-0.80,0),Vector3(1.70,1.58,0.09))
		_add_cargo_panel("SLIDING_DOOR_ROOT",Vector3(0,0.67,0.06),Vector3(0.09,1.77,1.46))
	else:
		for side in [-1.0,1.0]:
			_box(Vector3(side*0.713,0.807,-0.72),Vector3(0.085,0.29,1.91))
		_box(Vector3(0,0.807,0.22),Vector3(1.45,0.29,0.07))
		# 鳥居の空いている部分は塞がず、柱と上の桟だけを支える。
		for side in [-1.0,1.0]:
			_box(Vector3(side*0.665,1.35,0.22),Vector3(0.06,0.8,0.06))
		_box(Vector3(0,1.725,0.22),Vector3(1.39,0.06,0.06))
		_add_cargo_panel("TAILGATE_HINGE_X",Vector3(0,0.143,-0.006),Vector3(1.45,0.29,0.05))


func _panel_transform(panel: Node3D) -> Transform3D:
	var at := Transform3D.IDENTITY
	var node := panel
	while node != self:
		at = node.transform * at
		node = node.get_parent() as Node3D
	return at


func _add_cargo_panel(part: String, c: Vector3, size: Vector3) -> void:
	var panel: Node3D = visual.find_child(part,true,false)
	if panel == null: return
	var at := _panel_transform(panel)
	var shape := _box(Vector3.ZERO,size*at.basis.get_scale().abs()/VEHICLE_SCALE)
	shape.transform = Transform3D(at.basis.orthonormalized(),at*c)
	_cargo_panels.append([shape,panel,c])


func _update_cargo_panels() -> void:
	for panel: Array in _cargo_panels:
		# 車種切り替え中は、古いモデルを外してから衝突を作り直す。
		if not is_instance_valid(panel[1]) or not is_ancestor_of(panel[1]):
			continue
		var at := _panel_transform(panel[1])
		panel[0].transform = Transform3D(at.basis.orthonormalized(),at*(panel[2] as Vector3))


# ロープを掛けるフックの場所を決める（hooks）。
#   軽トラ：モデルに元からあるロープフック（左右のあおりの下に5つずつ並んだ、亜鉛めっきの金具）の位置に合わせる。
#           いちばん後ろの物が、荷台の後ろの角。前は、鳥居の柱に1つずつ足す（ここはモデルに金具が無いので、板と輪を付ける）
#   ロケバン：モデルに金具が無いので、荷室の中の左右の壁（床から少し上）に、板と輪を付ける。スライドドアの開く所には付けない
# どのフックにも、目印の黄色い輪を下げる（どこに結べるか、見て分かるように）。
# あおり（後ろの板）の真下には付けない：モデルにも金具が無く、停まっている間は板が倒れていて、走り出すと起きるので、
# ロープが板を通り抜けてしまう
func _build_hooks() -> void:
	var before := get_node_or_null("RopeHooks")
	if before != null:
		remove_child(before)
		before.queue_free()
	hooks.clear()
	var s := VEHICLE_SCALE
	var out_dirs: Array[Vector3] = []
	var plates: Array[bool] = []          # 板も付けるか（モデルに金具が無い所）
	if _installed == "van":
		rope_ceiling = 1.97 * s - 0.1
		for z: float in [-2.0, -1.1, -0.2, 0.6]:
			hooks.append(Vector3(-0.78 * s + 0.035, deck_top + 0.32, z * s))
			out_dirs.append(Vector3.RIGHT)
			plates.append(true)
		for z: float in [-2.0, -1.1]:
			hooks.append(Vector3(0.78 * s - 0.035, deck_top + 0.32, z * s))
			out_dirs.append(Vector3.LEFT)
			plates.append(true)
	else:
		rope_ceiling = deck_top + 2.6
		for side: float in [-1.0, 1.0]:
			for z: float in [-1.57, -1.21, -0.79, -0.37, 0.045]:
				hooks.append(Vector3(side * (0.78 * s + 0.02), 0.648 * s, z * s))
				out_dirs.append(Vector3(side, 0, 0))
				plates.append(false)
		for side: float in [-1.0, 1.0]:
			hooks.append(Vector3(side * 0.665 * s, 1.22 * s, 0.19 * s - 0.035))
			out_dirs.append(Vector3.FORWARD)
			plates.append(true)
	var root := Node3D.new()
	root.name = "RopeHooks"
	add_child(root)
	var zinc := StandardMaterial3D.new()
	zinc.albedo_color = Color(0.88, 0.74, 0.22)
	zinc.metallic = 0.55
	zinc.roughness = 0.45
	for i in hooks.size():
		var facing: Vector3 = out_dirs[i]
		var across: Vector3 = Vector3.UP.cross(facing).normalized()
		var hook := Node3D.new()
		hook.name = "Hook%d" % i
		# 輪の軸を、壁に沿った横向きにする（輪が壁から突き出して見える）
		hook.transform = Transform3D(Basis(facing, across, facing.cross(across)), hooks[i])
		root.add_child(hook)
		if plates[i]:
			var plate := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(0.014, 0.13, 0.11)
			plate.mesh = slab
			plate.material_override = zinc
			plate.position = Vector3(-0.03, 0, 0)
			hook.add_child(plate)
		var ring := MeshInstance3D.new()
		var loop := TorusMesh.new()
		loop.inner_radius = 0.028 if plates[i] else 0.022
		loop.outer_radius = 0.046 if plates[i] else 0.036
		loop.rings = 14
		loop.ring_segments = 8
		ring.mesh = loop
		ring.material_override = zinc
		if not plates[i]:
			# モデルの金具に下げた輪：金具の先から、少し下に垂れる
			ring.position = Vector3(0.0, 0.0, -0.03)
		hook.add_child(ring)


# 腰の支点とハンドルは車体ローカル座標。先頭の乗員が運転、次の乗員が助手席。
func seat(index: int) -> Dictionary:
	var van: bool = "vehicle" in self and get("vehicle") == "van"
	var base_scale := VEHICLE_SCALE * (0.9 if van else 1.0)
	var hip := Vector3(0.367,0.82,0.84)
	var wheel := Vector3(0.367,1.075,1.11)
	var radius := 0.169
	if van:
		hip = Vector3(-0.51,1.07,1.42)
		wheel = Vector3(-0.482,1.4325,1.75)
		radius = 0.195
	if index == 1:
		hip.x *= -1.0
	elif index >= 2:
		hip = Vector3(-0.40 if index % 2 == 0 else 0.40, 0.85 if van else 0.79, -0.75)
	return {"hip":hip*base_scale, "wheel":wheel*base_scale, "radius":radius*base_scale, "roof":(1.96 if van else 1.70)*base_scale if index < 2 else 10.0}

func set_traveling(value: bool) -> void:
	if _travel_state == int(value): return
	_travel_state = int(value)
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X",true,false)
	if tail: tail.rotation.x = 0.0 if value else -PI*0.5
	var hatch: Node3D = visual.find_child("REAR_HATCH_PIVOT",true,false)
	if hatch: hatch.rotation_degrees.x = 0.0 if value else 95.0
	var slide: Node3D = visual.find_child("SLIDING_DOOR_ROOT",true,false)
	if slide: slide.position = Vector3(0.927,0.625,0.08) + (Vector3.ZERO if value else Vector3(0.13,0,-1.45))
	_update_cargo_panels()
	if hatch and has_method("_van_supports"): call("_van_supports",hatch.get_parent(),hatch)

func drive_to(point: Vector3) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = point

func _ready() -> void:
	super._ready()
	set_fixed(true)
