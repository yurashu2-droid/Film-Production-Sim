extends Node
## ゴミ袋・ブルーシートの包み：持って振ると、中にしまってある物がひとつ出てくる（ゴミ袋＝小道具 / 包み＝大道具）。
##   ・廃材置き場に、いつも置いてある（日替わりの廃材ではない。置き場所は production_yard_slots.gd の BAG_SPOTS）。
##   ・振り方：持ったまま、左右に何度か振る（向きを SHAKE_TURNS 回切り返す）。または F。
##   ・出てくるのは、production_scrap.gd の "bag" の物のうち、まだしまってある物から、くじで1つ。
##     ゴミ袋からは小道具（"small"）、包みからは大道具（"large"）。持っている人の前に転がり出る。
##   ・1日に出せる数は、袋ごとに決まっている（PER_DAY）。空になると、しぼむ。次の日には、また詰まっている。
##   ・出した物は、会社へ戻って次の日になると、また袋の中にしまわれる（production_flow.gd の restock）。
## 決めるのはホスト。出た物は "stash" の合図で全員の画面に現れ、袋の残りは "junk" の合図で配る
const Prop := preload("res://scripts/prop.gd")
const Flow := preload("res://scripts/production_flow.gd")
const Yard := preload("res://scripts/production_yard.gd")
const Slots := preload("res://scripts/production_yard_slots.gd")

const BAG_OF := {"trashbag": "small", "tarpbundle": "large"}     # 袋の種類 → 出てくる物（production_scrap.gd の "bag"）
const PER_DAY := {"trashbag": 4, "tarpbundle": 2}                # 1日に出せる数（袋ひとつにつき）
const LABELS := {"trashbag": "ゴミ袋（振ると小道具が出る）", "tarpbundle": "ブルーシートの包み（振ると大道具が出る）"}
const SHORT := {"trashbag": "ゴミ袋", "tarpbundle": "ブルーシートの包み"}
const SHAKE_TURNS := 3          # 左右に振り返す回数
const SHAKE_WINDOW := 1.2       # この秒数のうちに振り返せば「振った」
const SHAKE_SPEED := 2.2        # これより速く向きを変えたときだけ数える（ラジアン/秒。ゆっくり見回すのは振ったことにしない）
const SHAKE_GAP := 1.0          # 出たあと、次に振って出せるまで（秒）。振り続けると、1秒に1個ずつ出る

var game: Node
var bags: Array = []                 # 袋（物）
var left: Dictionary = {}            # 袋の物のID → 今日あと何個出せるか
var _rng := RandomNumberGenerator.new()
var _last_yaw := NAN
var _sign := 0
var _turns: Array = []
var _gap := 0.0
var _wobble: Dictionary = {}         # 袋の物のID → 揺れの残り（秒）
var _noise := FastNoiseLite.new()    # 袋の見た目のふくらみ・色むら


func setup() -> void:
	_rng.randomize()
	_noise.frequency = 1.4
	for kind: String in ["tarpbundle", "trashbag"]:
		for spot: Vector2 in (Slots.BAG_SPOTS.get(kind, []) as Array):
			bags.append(_spawn(kind, Yard.to_world(spot, 0.06)))
	if Net.is_host() and game.production != null:
		for b: RigidBody3D in bags:
			game.production._home_layout[b.pid] = b.get_state()
		_refill()


func _spawn(kind: String, at: Vector3) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = kind
	p.label = LABELS[kind]
	var root := Node3D.new()
	var size: Vector3
	# 袋ごとに、ふくらみ方を少し変える
	_noise.seed = 11 + bags.size() * 7
	if kind == "trashbag":
		p.mass = 2.0
		size = Vector3(0.54, 0.62, 0.54)
		root.add_child(_trash_mesh())
	else:
		p.mass = 6.0
		size = Vector3(1.1, 0.62, 0.78)
		for part: MeshInstance3D in _tarp_meshes():
			root.add_child(part)
	p.visual = root
	p.add_child(root)
	p.center = Vector3(0, size.y * 0.5, 0)
	p.half = size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	game.stage._shape(p, p.center, size * 0.95, false)
	return game.stage._register(p, at, 0.0)


# ---- 見た目（ローポリ。面ごとに色を少し変え、角ばった面のまま） ----

# ゴミ袋：ひとつながりの胴（底は平ら、上はすぼまって口になり、しわが寄る）と、口に食い込む結び目と、結んだ端（耳）2つ。
# 結び目と耳も胴と同じ面・同じ色の、ひとつの形にする（浮いて見えないように）
func _trash_mesh() -> MeshInstance3D:
	var light := Color("2b3038")
	var dark := Color("1c2026")
	var profile := [[0.0, 0.17], [0.03, 0.22], [0.12, 0.26], [0.24, 0.27], [0.35, 0.235], [0.43, 0.16], [0.49, 0.085], [0.53, 0.045], [0.56, 0.035]]
	var seg := 14
	var rings: Array = []
	for row: Array in profile:
		var y: float = row[0]
		var r: float = row[1]
		var ring: Array = []
		for k in seg:
			var ang := TAU * float(k) / float(seg)
			var dir := Vector3(cos(ang), 0, sin(ang))
			var bump := 1.0 + 0.09 * _noise.get_noise_3d(dir.x * 2.0, y * 4.0, dir.z * 2.0)
			# 口のまわりは、絞ったしわ（角度で太い・細いをくり返す）
			var pinch := clampf((y - 0.4) / 0.13, 0.0, 1.0)
			bump *= 1.0 + 0.22 * pinch * (1.0 if k % 2 == 0 else -1.0)
			ring.append(dir * r * bump + Vector3(0, y, 0))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			_tri(st, rings[i][k], rings[i][k2], rings[i + 1][k], light, dark)
			_tri(st, rings[i][k2], rings[i + 1][k2], rings[i + 1][k], light, dark)
	for k in seg:
		_tri(st, rings[0][(k + 1) % seg], rings[0][k], Vector3.ZERO, light, dark)
	var knot_at := Vector3(0, 0.57, 0)
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.11
	ball.radial_segments = 7
	ball.rings = 4
	_add_prim(st, ball, Transform3D(Basis.from_scale(Vector3(1.1, 0.8, 1.0)), knot_at), light, dark)
	for side: float in [-1.0, 1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.012
		cone.bottom_radius = 0.045
		cone.height = 0.13
		cone.radial_segments = 5
		cone.rings = 1
		# 根元（円柱の下の端）が結び目の真ん中に来るように置き、外へ倒す。平たいビニールの端
		var tilt := side * 0.7
		var basis := Basis(Vector3.BACK, -tilt) * Basis.from_scale(Vector3(1.0, 1.0, 0.45))
		_add_prim(st, cone, Transform3D(basis, knot_at + Vector3(sin(tilt), cos(tilt), 0) * 0.055), light, dark)
	return _mesh(st, 0.45)


# ブルーシートの包み：ふくらんだ包みと、表面に沿って巻いたロープ2本
func _tarp_meshes() -> Array:
	var radii := Vector3(0.55, 0.31, 0.39)
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 2.0
	base.radial_segments = 16
	base.rings = 10
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, index.size(), 3):
		_tri(st, _tarp_point(verts[index[t]], radii), _tarp_point(verts[index[t + 1]], radii), _tarp_point(verts[index[t + 2]], radii),
			Color("2f68d0"), Color("1d4796"))
	var out: Array = [_mesh(st, 0.6)]
	# ロープ：包みの表面の点を輪にたどり、少し外へ浮かせた管にする（表面から離れない）
	for x: float in [-0.26, 0.24]:
		var ring: Array = []
		var a := clampf(x / radii.x, -0.95, 0.95)
		for k in 20:
			var ang := TAU * float(k) / 20.0
			var pt := _tarp_point(Vector3(a, sqrt(1.0 - a * a) * cos(ang), sqrt(1.0 - a * a) * sin(ang)), radii)
			var away := (pt - Vector3(pt.x, radii.y * 0.82, 0)).normalized()
			ring.append(pt + away * 0.012)
		out.append(_tube(ring, 0.04, Color("d9a441")))
	return out


# 包みの表面の点（球の向き → ノイズでふくらませ、底をつぶして平らにする）
func _tarp_point(v: Vector3, radii: Vector3) -> Vector3:
	var dir := v.normalized() if v.length() > 0.0001 else Vector3.UP
	var bump := 1.0 + 0.12 * _noise.get_noise_3dv(dir * 1.5)
	var pt := dir * bump * radii
	pt.y = maxf(pt.y, -radii.y * 0.82)
	return pt + Vector3(0, radii.y * 0.82, 0)


# 輪になった点の列を、四角い断面の管にする（ローポリのロープ）
func _tube(points: Array, width: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var sections: Array = []
	for i in n:
		var pt: Vector3 = points[i]
		var fwd: Vector3 = (points[(i + 1) % n] - points[(i - 1 + n) % n]).normalized()
		var side := fwd.cross(Vector3.RIGHT).normalized()
		if side.length() < 0.1:
			side = Vector3.UP
		var up := side.cross(fwd).normalized()
		var h := width * 0.5
		sections.append([pt + side * h + up * h, pt - side * h + up * h, pt - side * h - up * h, pt + side * h - up * h])
	for i in n:
		var s0: Array = sections[i]
		var s1: Array = sections[(i + 1) % n]
		for k in 4:
			var k2 := (k + 1) % 4
			_tri(st, s0[k], s0[k2], s1[k], color, color.darkened(0.15))
			_tri(st, s0[k2], s1[k2], s1[k], color, color.darkened(0.15))
	var mi := _mesh(st, 0.95)
	(mi.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return mi


# 球・円柱などを、角ばった面にして同じ形に足す
func _add_prim(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, light: Color, dark: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, index.size(), 3):
		_tri(st, xf * verts[index[t]], xf * verts[index[t + 1]], xf * verts[index[t + 2]], light, dark)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, light: Color, dark: Color) -> void:
	var mid := (a + b + c) / 3.0
	var col := light.lerp(dark, clampf(0.5 + _noise.get_noise_3dv(mid * 5.0), 0.0, 1.0))
	var n := (c - a).cross(b - a).normalized()      # Godot の面は時計回り。外向きの法線にする
	for v: Vector3 in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


func _mesh(st: SurfaceTool, rough: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true          # 上の色は見たままの色（sRGB）で書いてある
	mat.roughness = rough
	mi.material_override = mat
	return mi


func _bag(p: Node) -> bool:
	return p != null and BAG_OF.has(str(p.kind))


# ---- 振る（自分の画面で数えて、ホストへ頼む） ----

func hook_f(me: Node) -> bool:
	var held: Node = game.props.get(me.held) if me.held != 0 else null
	if not _bag(held) or game.production == null:
		return false
	h_shake.rpc_id(1, int(held.pid))
	_wobble[int(held.pid)] = 0.4
	return true


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	var held: Node = game.props.get(me.held) if me.held != 0 else null
	if not _bag(held):
		return {}
	var n := int(left.get(int(held.pid), 0))
	var what := "小道具" if held.kind == "trashbag" else "大道具"
	var line := ("左右に振る・F　中から%sが出る（今日はあと %d 個）" % [what, n]) if n > 0 else "空っぽ（明日になると、また詰まっている）"
	return {"keys_all": line + "\n" + str(game.hold_hint())}


func _process(delta: float) -> void:
	_gap = maxf(0.0, _gap - delta)
	_show_wobble(delta)
	var me: Node = game.local_player() if game.has_method("local_player") else null
	var held: Node = game.props.get(me.held) if me != null and me.held != 0 else null
	if not _bag(held) or game.production == null:
		_last_yaw = NAN
		_sign = 0
		_turns.clear()
		return
	var yaw: float = me.aim_yaw
	if is_nan(_last_yaw):
		_last_yaw = yaw
		return
	var speed := angle_difference(_last_yaw, yaw) / maxf(delta, 0.001)
	_last_yaw = yaw
	var now := Time.get_ticks_msec() / 1000.0
	if absf(speed) > SHAKE_SPEED:
		var sg := 1 if speed > 0.0 else -1
		if sg != _sign:
			# 出たすぐあとの振りは数えない（振り終わりの余りで、もう1個出ないように）
			if _sign != 0 and _gap <= 0.0:
				_turns.append(now)
				_wobble[int(held.pid)] = 0.25
			_sign = sg
	_turns = _turns.filter(func(t: float) -> bool: return now - t < SHAKE_WINDOW)
	if _turns.size() >= SHAKE_TURNS and _gap <= 0.0:
		_turns.clear()
		_gap = SHAKE_GAP
		h_shake.rpc_id(1, int(held.pid))


# 振っている袋を、見た目だけ少し揺らす（自分の画面）
func _show_wobble(delta: float) -> void:
	for pid: int in _wobble.keys():
		var t: float = float(_wobble[pid]) - delta
		var bag: Node = game.props.get(pid)
		if bag == null or bag.visual == null:
			_wobble.erase(pid)
			continue
		if t <= 0.0:
			_wobble.erase(pid)
			bag.visual.rotation = Vector3.ZERO
		else:
			_wobble[pid] = t
			bag.visual.rotation = Vector3(0, 0, sin(t * 40.0) * 0.18)


# ---- 中身を出す（ホスト） ----

@rpc("any_peer", "call_local", "reliable")
func h_shake(bag_pid: int) -> void:
	var who := Net.sender()
	var bag: Node = game.props.get(bag_pid)
	var pl: Node3D = game.players.get(who)
	if not Net.is_host() or game.replaying or not _bag(bag) or pl == null or bag.holder != who or game.production == null:
		return
	if int(left.get(bag_pid, 0)) <= 0:
		game.ev.rpc_id(who, "toast", ["%sは空っぽ。明日になると、また詰まっている" % SHORT[bag.kind], 0])
		return
	var flow: Node = game.production
	var pool: Array = (flow.stash as Array).filter(func(pid: int) -> bool:
		return game.props.has(pid) and Flow.bag_of(str(game.props[pid].kind)) == BAG_OF[bag.kind])
	if pool.is_empty():
		game.ev.rpc_id(who, "toast", ["%sの中は、もう何も入っていない" % SHORT[bag.kind], 0])
		return
	var item: RigidBody3D = game.props[pool[_rng.randi_range(0, pool.size() - 1)]]
	var hidden: Array = (flow.stash as Array).duplicate()
	hidden.erase(item.pid)
	game.host_ev("stash", [hidden])
	_pop_out(item, bag, pl)
	left[bag_pid] = int(left[bag_pid]) - 1
	game.host_ev("junk", [left])
	game.host_ev("sfx", ["drop", item.global_position])
	game.ev.rpc_id(who, "toast", ["%sから「%s」が出てきた" % [SHORT[bag.kind], item.label], 0])


# 持っている人の前（袋の先）へ出す。小道具は袋の口から転がり出て、大道具は足元にどさっと出る
func _pop_out(item: RigidBody3D, bag: Node3D, pl: Node3D) -> void:
	var dir: Vector3 = bag.global_position - pl.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else -pl.global_transform.basis.z
	var face := Quaternion(Vector3.UP, atan2(-dir.x, -dir.z))
	var reach := 0.45 + maxf(float(item.half.x), float(item.half.z))
	var at: Vector3 = bag.global_position + dir * reach
	at.y = pl.global_position.y + (0.35 if BAG_OF[bag.kind] == "small" else 0.04)
	item.restore([at, face, false])
	if BAG_OF[bag.kind] == "small":
		item.linear_velocity = dir * 1.2 + Vector3.UP * 1.0


# 依頼主が用意する物（features/job_props.gd）を、袋から出さずに、廃材置き場の空いている所へ置く（ホスト）。
# 今日は出ていない日替わりの廃材の置き場所から、まわりに物の無い所を選ぶ。どこも空いていなければ、包みのそば
func deliver(item: RigidBody3D) -> void:
	var need := maxf(float(item.half.x), float(item.half.z)) + 0.5
	var spots: Array = []
	for kind: String in Slots.SLOTS:
		for local: Vector2 in (Slots.SLOTS[kind] as Array):
			spots.append(Yard.to_world(local, 0.05))
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(Yard.CENTER) < b.distance_squared_to(Yard.CENTER))
	var at := Vector3.INF
	for spot: Vector3 in spots:
		var clear := true
		for p: Node in game.props.values():
			if p == item or p.absent or p.kind == "mark":
				continue
			var reach := need + maxf(float(p.half.x), float(p.half.z))
			var d: Vector3 = p.global_position - spot
			d.y = 0.0
			if d.length() < reach:
				clear = false
				break
		if clear:
			at = spot
			break
	if at == Vector3.INF:
		var tarp: Node3D = bags[0] if not bags.is_empty() else null
		at = (tarp.global_position + Vector3(0, 0, need + 0.8)) if tarp != null else Yard.to_world(Vector2(0, 8), 0.05)
	at.y = Yard.CENTER.y + 0.05
	item.restore([at, Quaternion(Vector3.UP, PI * 0.5), false])


# ---- 袋の残り（全員の画面） ----

func _refill() -> void:
	left = {}
	for b: Node in bags:
		left[int(b.pid)] = int(PER_DAY[b.kind])
	game.host_ev("junk", [left])


# 次の日：袋は、また詰まっている（出した物は restock でしまわれる）
func hook_office_ready() -> void:
	if Net.is_host():
		_refill()


func hook_events() -> Array:
	return ["junk"]


func hook_event(_n: String, a: Array) -> void:
	left = (a[0] as Dictionary).duplicate()
	for b: Node in bags:
		# 空になった袋は、しぼんで低くなる
		if b.visual != null:
			b.visual.scale = Vector3(1.0, 1.0 if int(left.get(int(b.pid), 0)) > 0 else 0.55, 1.0)


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "junk", [left])
