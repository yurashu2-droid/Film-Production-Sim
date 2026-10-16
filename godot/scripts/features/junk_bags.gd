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


func setup() -> void:
	_rng.randomize()
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
	if kind == "trashbag":
		p.mass = 2.0
		size = Vector3(0.5, 0.62, 0.46)
		root.add_child(_blob(Vector3(0.25, 0.3, 0.23), Color("2a2e35"), Color("3d434c"), 0.35, 11))
		var knot := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.12
		knot.mesh = ball
		knot.position = Vector3(0, 0.64, 0)
		knot.material_override = _plain(Color("2a2e35"), 0.35)
		root.add_child(knot)
		for side: float in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.005
			cone.bottom_radius = 0.045
			cone.height = 0.13
			ear.mesh = cone
			ear.position = Vector3(side * 0.06, 0.7, 0)
			ear.rotation = Vector3(0, 0, -side * 0.7)
			ear.material_override = _plain(Color("2a2e35"), 0.35)
			root.add_child(ear)
	else:
		p.mass = 6.0
		size = Vector3(1.1, 0.62, 0.78)
		root.add_child(_blob(Vector3(0.55, 0.31, 0.39), Color("2b63c9"), Color("1d4796"), 0.6, 29))
		# 縛ってある黄色いロープ（2本）
		for x: float in [-0.25, 0.25]:
			var band := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.96
			torus.outer_radius = 1.04
			band.mesh = torus
			band.rotation = Vector3(0, 0, PI * 0.5)
			band.position = Vector3(x, 0.31, 0)
			band.scale = Vector3(0.33, 0.6, 0.41)
			band.material_override = _plain(Color("d8b04a"), 0.8)
			root.add_child(band)
	p.visual = root
	p.add_child(root)
	p.center = Vector3(0, size.y * 0.5, 0)
	p.half = size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	game.stage._shape(p, p.center, size * 0.95, false)
	return game.stage._register(p, at, 0.0)


# 丸くふくらんだ袋：球をノイズで少しへこませ、下を平らにする。面ごとに色を少し変える
func _blob(radii: Vector3, light: Color, dark: Color, rough: float, seed_value: int) -> MeshInstance3D:
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 2.0
	base.radial_segments = 16
	base.rings = 10
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.4
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var moved := PackedVector3Array()
	moved.resize(verts.size())
	for i in verts.size():
		var dir: Vector3 = verts[i].normalized() if verts[i].length() > 0.0001 else Vector3.UP
		var bump := 1.0 + 0.12 * noise.get_noise_3dv(dir * 1.5)
		var v := dir * bump * radii
		v.y = maxf(v.y, -radii.y * 0.82)          # 置いた袋の底は、つぶれて平ら
		moved[i] = v + Vector3(0, radii.y * 0.82, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, index.size(), 3):
		var a := moved[index[t]]
		var b := moved[index[t + 1]]
		var c := moved[index[t + 2]]
		var mid := (a + b + c) / 3.0
		var col := light.lerp(dark, clampf(0.5 + noise.get_noise_3dv(mid * 4.0), 0.0, 1.0))
		var n := (c - a).cross(b - a).normalized()      # Godot の面は時計回り。外向きの法線にする
		for v: Vector3 in [a, b, c]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = rough
	mi.material_override = mat
	return mi


func _plain(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat


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
