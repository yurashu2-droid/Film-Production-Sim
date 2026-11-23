extends RefCounted
# 持てる物の「見た目」と「当たり判定」を見比べるための共通の道具。
# 写真を撮る道具（tools/collider_shots.gd）と自動確認（tests/collider_fit_test.gd）から使う。
# ゲーム本編からは使わない。
#
# 使い方：
#   var fixture := Audit.Fixture.new(); root.add_child(fixture)
#   var stage := Audit.new_stage(fixture)
#   var body := Audit.make(stage, "rock", Vector3.ZERO)
#   var faces := Audit.visual_faces(body)      # 見た目の三角形（物のローカル座標）
#   var list := Audit.shapes(body)             # 当たり判定の形
#   var report := Audit.measure(body)          # 外形の比べ方と、升目での比べ方をまとめた結果

const Stage := preload("res://scripts/stage.gd")
const Prop := preload("res://scripts/prop.gd")
const Scrap := preload("res://scripts/production_scrap.gd")
const Truck := preload("res://scripts/truck.gd")
const FilmCamera := preload("res://scripts/film_camera.gd")
const SpotRig := preload("res://scripts/spot_rig.gd")
const Clapper := preload("res://scripts/clapper.gd")
const FxBox := preload("res://scripts/fx_box.gd")
const BoomFlat := preload("res://scripts/boom_flat.gd")
const PowderSack := preload("res://scripts/powder_sack.gd")
const ProductionProp := preload("res://scripts/production_prop.gd")
const MovieProp := preload("res://scripts/production_movie_prop.gd")
const ScriptProp := preload("res://scripts/production_script_prop.gd")
const MonitorProp := preload("res://scripts/production_monitor_prop.gd")
const CueCard := preload("res://scripts/cue_card.gd")
const StandIn := preload("res://scripts/standin_panel.gd")
const PropShapes := preload("res://scripts/prop_shapes.gd")

# stage.gd の DEFS に無い、作り方が別の物
const BUILT := ["plywood", "riser", "moon", "truck", "truck_van", "camera", "spot", "clapper", "fx", "powdersack", "boomflat",
	"lift_cart", "cleaning_cart", "dragon_skull", "witch_cauldron", "tomato_monster"]
const BUILT_LAST := ["script", "monitor", "cue_card", "standin"]


# ゲーム本体の代わり。物を作るのに要る最小限だけ持つ
class Fixture extends Node3D:
	var props: Dictionary = {}
	var moons: Array = []
	var players: Dictionary = {}
	var font: Font
	var replaying := false
	var adhesive: Node = null


static func new_stage(fixture: Node3D) -> Node3D:
	if fixture.font == null:
		fixture.font = load("res://assets/fonts/NotoSansJP-VF.ttf") if ResourceLoader.exists("res://assets/fonts/NotoSansJP-VF.ttf") else ThemeDB.fallback_font
	var stage: Node3D = Stage.new()
	stage.game = fixture
	fixture.add_child(stage)
	return stage


# 確かめる種類の一覧（立ち位置の印は、ただの円盤なので入れない）
static func kinds() -> Array[String]:
	var out: Array[String] = []
	for kind: String in Stage.DEFS:
		out.append(kind)
	for kind: String in BUILT:
		out.append(kind)
	for item: Dictionary in Scrap.ITEMS:
		out.append(String(item["kind"]))
	for kind: String in BUILT_LAST:
		out.append(kind)
	return out


# その種類の物を1つ作って、stage に登録する
static func make(stage: Node3D, kind: String, at: Vector3) -> RigidBody3D:
	if Stage.DEFS.has(kind):
		return stage.spawn(kind, at)
	var body: RigidBody3D
	match kind:
		"plywood":
			return stage.spawn_plywood(at, 0.0)
		"riser":
			return stage.spawn_riser(at, 0.0)
		"moon":
			return stage.spawn_moon(at, 0.0)
		"truck", "truck_van":
			body = Truck.new()
			body.build()
			if kind == "truck_van":
				body.set_vehicle("van")
		"camera":
			body = FilmCamera.new()
			body.build()
		"spot":
			body = SpotRig.new()
			body.build()
		"clapper":
			body = Clapper.new()
			body.game = stage.game
			body.build()
		"fx":
			body = FxBox.new()
			body.build()
		"powdersack":
			body = PowderSack.new()
			body.build()
		"boomflat":
			body = BoomFlat.new()
			body.build()
		"lift_cart", "cleaning_cart":
			body = ProductionProp.new()
			body.build_model(kind)
		"script":
			body = ScriptProp.new()
			body.build_model()
		"monitor":
			body = MonitorProp.new()
			body.build_model()
		"cue_card":
			body = CueCard.new()
			body.build()
		"standin":
			body = StandIn.new()
			body.build()
		_:
			body = MovieProp.new()
			body.build_model(kind)
	return stage._register(body, at, 0.0)


# 表（prop_shapes.gd）の寸法に掛かっている倍率（stage.gd の scale、廃材置き場の size）。
# 表の座標で書いた点を、いまの物の座標へ直すのに使う
static func table_scale(kind: String) -> float:
	if Stage.DEFS.has(kind):
		return float((Stage.DEFS[kind] as Dictionary).get("scale", 1.0))
	var item := Scrap.find(kind)
	var base := PropShapes.base_size(kind)
	if not item.is_empty() and base > 0.0:
		return float(item["size"]) / base
	return 1.0


# 物を置く床（確かめる用）
static func add_floor(fixture: Node3D, size: float = 600.0) -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Prop.L_WORLD
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position = Vector3(size * 0.4, -0.5, size * 0.4)
	floor_body.add_child(shape)
	fixture.add_child(floor_body)
	return floor_body


# 床に置いて放し、動かず・倒れず・震えないことを数で見る（床は add_floor で先に作っておく）。
# 4秒待ってから、1.5秒のあいだのいちばん速い動きを測る。物ごとの結果を、bodies と同じ順で返す：
#   {"moved": 横のずれ(m), "height": 高さ(m), "tilt": 傾き(度), "turned": 向きの変化(度), "speed": 速さ, "spin": 回転, "asleep": 眠ったか, "ok": 落ち着いたか}
static func settle(tree: SceneTree, bodies: Array) -> Array:
	var start: Array = []
	for body: RigidBody3D in bodies:
		if not body.get("immovable"):
			body.position.y = 0.03
			body.set_fixed(false)
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.sleeping = false
		start.append(body.global_transform)
	for i in 240:
		await tree.physics_frame
	var fastest: Array = []
	var spin: Array = []
	for body: RigidBody3D in bodies:
		fastest.append(0.0)
		spin.append(0.0)
	for i in 90:
		await tree.physics_frame
		for j in bodies.size():
			fastest[j] = maxf(fastest[j], (bodies[j] as RigidBody3D).linear_velocity.length())
			spin[j] = maxf(spin[j], (bodies[j] as RigidBody3D).angular_velocity.length())
	var out: Array = []
	for j in bodies.size():
		var body: RigidBody3D = bodies[j]
		var from: Transform3D = start[j]
		var moved := Vector2(body.global_position.x - from.origin.x, body.global_position.z - from.origin.z).length()
		var tilt := rad_to_deg(acos(clampf(body.global_basis.y.normalized().y, -1.0, 1.0)))
		var turned := rad_to_deg(absf(wrapf(body.global_basis.get_euler().y - from.basis.get_euler().y, -PI, PI)))
		var ok: bool = moved < 0.05 and tilt < 3.0 and turned < 3.0 and absf(body.global_position.y) < 0.08 and fastest[j] < 0.05 and spin[j] < 0.15
		out.append({"moved": moved, "height": body.global_position.y, "tilt": tilt, "turned": turned, "speed": fastest[j], "spin": spin[j], "asleep": body.sleeping, "ok": ok})
	return out


# ---- 座標と、見えているかどうか ----

# node の座標を body の座標へ直す変換
static func to_body(node: Node3D, body: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != body:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func shown(node: Node, body: Node) -> bool:
	var n: Node = node
	while n != null and n != body:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


# ---- 見た目 ----

# 見た目のメッシュの一覧（見えている物だけ）：[{"node": MeshInstance3D, "xf": 物のローカルへの変換}]
static func visual_meshes(body: Node3D) -> Array:
	var out: Array = []
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not shown(mi, body) or mi.has_meta("collider_debug"):
			continue
		out.append({"node": mi, "xf": to_body(mi, body)})
	return out


# 見た目の三角形（物のローカル座標、3点ずつ）
static func visual_faces(body: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for item: Dictionary in visual_meshes(body):
		var xf: Transform3D = item["xf"]
		var faces: PackedVector3Array = (item["node"] as MeshInstance3D).mesh.get_faces()
		var base := out.size()
		out.resize(base + faces.size())
		for i in faces.size():
			out[base + i] = xf * faces[i]
	return out


static func points_aabb(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var lo := points[0]
	var hi := points[0]
	for p: Vector3 in points:
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo, hi - lo)


# ---- 当たり判定 ----

# 当たり判定の形の一覧：[{"shape", "xf"（物のローカル）, "thin"（人だけが当たる薄い物）, "off"（いまは無効）, "node"}]
static func shapes(body: Node3D) -> Array:
	var out: Array = []
	for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
		if cs.shape == null:
			continue
		var owner_body := cs.get_parent() as CollisionObject3D
		var thin: bool = owner_body != null and owner_body != body and owner_body.collision_layer == Prop.L_THIN
		out.append({"shape": cs.shape, "xf": to_body(cs, body), "thin": thin, "off": cs.disabled, "node": cs})
	return out


# 形そのものの箱（形のローカル座標）
static func shape_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		return AABB(Vector3(-cyl.radius, -cyl.height * 0.5, -cyl.radius), Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0))
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -r, Vector3.ONE * r * 2.0)
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		return AABB(Vector3(-cap.radius, -cap.height * 0.5, -cap.radius), Vector3(cap.radius * 2.0, cap.height, cap.radius * 2.0))
	return shape.get_debug_mesh().get_aabb()


# 形の表面の点（形のローカル座標）。外形をきっちり測るのに使う（回した円柱の角を、箱の角で測らないため）
static func shape_points(shape: Shape3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * 0.5
		for x: float in [-1.0, 1.0]:
			for y: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					out.append(h * Vector3(x, y, z))
	elif shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		for i in 24:
			var a := TAU * float(i) / 24.0
			for y: float in [-0.5, 0.5]:
				out.append(Vector3(cos(a) * cyl.radius, y * cyl.height, sin(a) * cyl.radius))
	elif shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		for i in 12:
			var lat := PI * (float(i) + 0.5) / 12.0 - PI * 0.5
			for j in 24:
				var lon := TAU * float(j) / 24.0
				out.append(Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * r)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			out.append(axis * r)
			out.append(axis * -r)
	elif shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var straight := maxf(cap.height * 0.5 - cap.radius, 0.0)
		for i in 12:
			var lat := PI * (float(i) + 0.5) / 12.0 - PI * 0.5
			for j in 24:
				var lon := TAU * float(j) / 24.0
				var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * cap.radius
				p.y += straight if p.y >= 0.0 else -straight
				out.append(p)
		out.append(Vector3(0, cap.height * 0.5, 0))
		out.append(Vector3(0, -cap.height * 0.5, 0))
	else:
		var box := shape_bounds(shape)
		for i in 8:
			out.append(box.get_endpoint(i))
	return out


# 当たり判定を全部囲む箱（物のローカル座標）。with_thin＝薄い物も入れる / with_off＝無効の形も入れる
static func shapes_aabb(list: Array, with_thin: bool = true, with_off: bool = false) -> AABB:
	var points := PackedVector3Array()
	for item: Dictionary in list:
		if (item["thin"] and not with_thin) or (item["off"] and not with_off):
			continue
		var xf: Transform3D = item["xf"]
		for p: Vector3 in shape_points(item["shape"]):
			points.append(xf * p)
	return points_aabb(points)


# 点（形のローカル座標）が形の中にあるか
static func inside(shape: Shape3D, p: Vector3) -> bool:
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * 0.5
		return absf(p.x) <= h.x and absf(p.y) <= h.y and absf(p.z) <= h.z
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		return absf(p.y) <= cyl.height * 0.5 and p.x * p.x + p.z * p.z <= cyl.radius * cyl.radius
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return p.length_squared() <= r * r
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var straight := maxf(cap.height * 0.5 - cap.radius, 0.0)
		var q := Vector3(p.x, p.y - clampf(p.y, -straight, straight), p.z)
		return q.length_squared() <= cap.radius * cap.radius
	return shape_bounds(shape).has_point(p)


# 形の種類の名前（報告用）
static func shape_name(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "箱"
	if shape is CylinderShape3D:
		return "円柱"
	if shape is SphereShape3D:
		return "球"
	if shape is CapsuleShape3D:
		return "カプセル"
	return shape.get_class()


# ---- 升目に分けて比べる ----

# 見た目と当たり判定を小さな升目に分けて、重なり方を数える。
#   over ＝当たるのに、近くに見た目が無い升目の割合（当たり判定の升目の数に対して）。大ざっぱな箱ほど大きい
#   under＝見えるのに、近くに当たり判定が無い升目の割合（見た目の升目の数に対して）
#   over_l / under_l＝その体積（リットル）
# 見た目は「中身が詰まっている」ものとして数える（外から回り込めない所は中身）。床があるので、下からは回り込まない。
# tol（メートル）以内のずれは数えない。
static func voxel_compare(faces: PackedVector3Array, list: Array, cells: int = 40, tol: float = -1.0) -> Dictionary:
	var out := {"cell": 0.0, "vis": 0, "col": 0, "over": 0.0, "under": 0.0, "over_l": 0.0, "under_l": 0.0, "vis_l": 0.0, "col_l": 0.0}
	if faces.is_empty():
		return out
	var all := points_aabb(faces)
	var live: Array = []
	for item: Dictionary in list:
		if not item["off"]:
			live.append(item)
	if not live.is_empty():
		all = all.merge(shapes_aabb(live))
	var longest_side := maxf(all.size.x, maxf(all.size.y, all.size.z))
	var cell := maxf(longest_side / float(cells), 0.012)
	if tol < 0.0:
		# 許すずれ：大きい物は6cm、小さい物は大きさの3.5%（2cmまで）
		tol = clampf(longest_side * 0.035, 0.02, 0.06)
	var pad := 2
	var origin := all.position - Vector3(cell * pad, 0.0, cell * pad)
	var nx := int(ceil(all.size.x / cell)) + pad * 2 + 1
	var ny := int(ceil(all.size.y / cell)) + pad + 1
	var nz := int(ceil(all.size.z / cell)) + pad * 2 + 1
	var n := nx * ny * nz
	var inv := 1.0 / cell
	# 1) 見た目の表面が通る升目
	var surf := PackedByteArray()
	surf.resize(n)
	var step := cell * 0.6
	var count := faces.size() / 3
	for t in count:
		var a := faces[t * 3]
		var ab := faces[t * 3 + 1] - a
		var ac := faces[t * 3 + 2] - a
		var longest := maxf(ab.length(), maxf(ac.length(), (ab - ac).length()))
		var div := maxi(1, int(ceil(longest / step)))
		var k := 1.0 / float(div)
		for i in div + 1:
			var row := a + ab * (float(i) * k)
			for j in div + 1 - i:
				var p := (row + ac * (float(j) * k) - origin) * inv
				var x := clampi(int(p.x), 0, nx - 1)
				var y := clampi(int(p.y), 0, ny - 1)
				var z := clampi(int(p.z), 0, nz - 1)
				surf[(y * nz + z) * nx + x] = 1
	# 2) 外から回り込める升目に印を付ける（残りが中身）
	var outside := PackedByteArray()
	outside.resize(n)
	var stack := PackedInt32Array()
	stack.resize(n)
	var sp := 0
	var start := ((ny - 1) * nz) * nx
	outside[start] = 1
	stack[sp] = start
	sp += 1
	var layer := nx * nz
	while sp > 0:
		sp -= 1
		var idx := stack[sp]
		var x := idx % nx
		var rest := idx / nx
		var z := rest % nz
		var y := rest / nz
		if x > 0 and outside[idx - 1] == 0 and surf[idx - 1] == 0:
			outside[idx - 1] = 1
			stack[sp] = idx - 1
			sp += 1
		if x < nx - 1 and outside[idx + 1] == 0 and surf[idx + 1] == 0:
			outside[idx + 1] = 1
			stack[sp] = idx + 1
			sp += 1
		if z > 0 and outside[idx - nx] == 0 and surf[idx - nx] == 0:
			outside[idx - nx] = 1
			stack[sp] = idx - nx
			sp += 1
		if z < nz - 1 and outside[idx + nx] == 0 and surf[idx + nx] == 0:
			outside[idx + nx] = 1
			stack[sp] = idx + nx
			sp += 1
		if y > 0 and outside[idx - layer] == 0 and surf[idx - layer] == 0:
			outside[idx - layer] = 1
			stack[sp] = idx - layer
			sp += 1
		if y < ny - 1 and outside[idx + layer] == 0 and surf[idx + layer] == 0:
			outside[idx + layer] = 1
			stack[sp] = idx + layer
			sp += 1
	var solid := PackedByteArray()
	solid.resize(n)
	var vis := 0
	for i in n:
		if outside[i] == 0:
			solid[i] = 1
			vis += 1
	# 3) 当たり判定の中にある升目
	var col := PackedByteArray()
	col.resize(n)
	var fine := cell * 0.5
	for item: Dictionary in live:
		var shape: Shape3D = item["shape"]
		var xf: Transform3D = item["xf"]
		var box := shape_bounds(shape)
		var sx := maxi(1, int(ceil(box.size.x / fine)))
		var sy := maxi(1, int(ceil(box.size.y / fine)))
		var sz := maxi(1, int(ceil(box.size.z / fine)))
		for iy in sy + 1:
			for iz in sz + 1:
				for ix in sx + 1:
					# 形の表面ちょうどの点は、少し内側へ寄せてから升目に入れる（隣の升目へはみ出さないように）
					var local := (box.position + box.size * Vector3(float(ix) / sx, float(iy) / sy, float(iz) / sz)) * 0.998
					if not inside(shape, local):
						continue
					var p := (xf * local - origin) * inv
					col[(clampi(int(p.y), 0, ny - 1) * nz + clampi(int(p.z), 0, nz - 1)) * nx + clampi(int(p.x), 0, nx - 1)] = 1
	var hit := 0
	for i in n:
		hit += col[i]
	# 4) 少しのずれは許して、重ならない升目を数える
	var reach := maxi(1, int(round(tol / cell)))
	var near_vis := _dilate(solid, nx, ny, nz, reach)
	var near_col := _dilate(col, nx, ny, nz, reach)
	var over := 0
	var under := 0
	for i in n:
		if col[i] != 0 and near_vis[i] == 0:
			over += 1
		if solid[i] != 0 and near_col[i] == 0:
			under += 1
	var litre := cell * cell * cell * 1000.0
	out["cell"] = cell
	out["vis"] = vis
	out["col"] = hit
	out["over"] = float(over) / float(maxi(hit, 1))
	out["under"] = float(under) / float(maxi(vis, 1))
	out["over_l"] = float(over) * litre
	out["under_l"] = float(under) * litre
	out["vis_l"] = float(vis) * litre
	out["col_l"] = float(hit) * litre
	return out


static func _moved(points: PackedVector3Array, xf: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = xf * points[i]
	return out


# 印の付いた升目を、まわり reach 升ぶん広げる
static func _dilate(src: PackedByteArray, nx: int, ny: int, nz: int, reach: int) -> PackedByteArray:
	var n := nx * ny * nz
	var layer := nx * nz
	var a := PackedByteArray()
	a.resize(n)
	for i in n:
		if src[i] != 0:
			var x := i % nx
			for d in range(maxi(-reach, -x), mini(reach, nx - 1 - x) + 1):
				a[i + d] = 1
	var b := PackedByteArray()
	b.resize(n)
	for i in n:
		if a[i] != 0:
			var z := (i / nx) % nz
			for d in range(maxi(-reach, -z), mini(reach, nz - 1 - z) + 1):
				b[i + d * nx] = 1
	var c := PackedByteArray()
	c.resize(n)
	for i in n:
		if b[i] != 0:
			var y := i / layer
			for d in range(maxi(-reach, -y), mini(reach, ny - 1 - y) + 1):
				c[i + d * layer] = 1
	return c


# ---- まとめて測る ----

# その物の見た目と当たり判定の比べ方をまとめる。
#   vis / col      ：見た目・当たり判定（無効の形は除く）を囲む箱
#   solid          ：物にも当たる形だけを囲む箱（薄い物を除く）
#   lo / hi        ：当たり判定の箱が、見た目の箱からどれだけ出ているか（＋）・足りないか（−）。面ごと（x,y,z）
#   count / thin / off：形の数（物にも当たる形・薄い物・いまは無効）
#   center_off     ：center と見た目の箱の中心のずれ / half_off：half と見た目の箱の半分のずれ
static func measure(body: Node3D, with_voxels: bool = true, cells: int = 40) -> Dictionary:
	var faces := visual_faces(body)
	var list := shapes(body)
	var vis := points_aabb(faces)
	var col := shapes_aabb(list)
	var solid := shapes_aabb(list, false)
	var count := 0
	var thin := 0
	var off := 0
	for item: Dictionary in list:
		if item["off"]:
			off += 1
		elif item["thin"]:
			thin += 1
		else:
			count += 1
	var out := {"kind": String(body.get("kind")), "vis": vis, "col": col, "solid": solid, "count": count, "thin": thin, "off": off,
		"lo": col.position - vis.position, "hi": col.end - vis.end, "tris": faces.size() / 3,
		"center_off": (body.get("center") as Vector3) - vis.get_center(), "half_off": (body.get("half") as Vector3) - vis.size * 0.5}
	out["lo"] = vis.position - col.position       # ＋＝当たり判定が見た目より外へ出ている
	if with_voxels:
		out["vox"] = voxel_compare(faces, list, cells)
	return out
