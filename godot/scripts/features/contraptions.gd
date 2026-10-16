extends Node
## 仕掛け（連鎖して動く装置の部品）。会社の備品として、滑車・押しボタン・点火トーチを置く（はさみの隣）。
## 数字やキーで決めず、ゲームの中の物をつなぐ・切る・燃やす。組み合わせ方は決めない（プレイヤーが考える）。
##   ・結ぶ：ロープの束を持って、物・壁・柱・手すりを見て F で端を結ぶ。もう一方の物を見て F で結ぶ（そのときの長さで張る）。
##     途中で滑車を見て F なら、ロープは滑車に掛かって向きを変える（何個でも）。床には結ばない。
##     結んだロープは、引っぱるだけ（押さない）：重りをぶら下げる・台車を引く・倒れる物を支える。
##     束を持って、結んだロープを見て F でほどく（束に巻き戻る）。束の長さは、荷台のロープ・導火線と同じ1本（bomb_kit.gd の stock）
##   ・火：手ぶらで、結んだロープを見て F で火を付ける。少しして、そこで焼き切れる（重りが落ちる・引かれていた物が走り出す）。
##     燃えている導火線の先・燃えているロープ・点火トーチの炎が触れても、火が移る。爆発のそばのロープは、その場で切れる。はさみでも切れる
##   ・滑車（クランプ付き）：持って、壁・柱・物を見て F で、そこに留める（物に留めたら、その物と一緒に動く）。留めた滑車を見て F で外す
##   ・押しボタン（呼び鈴）：上に物が載る・落ちてくる・人が踏む・手ぶらで F、でチンと鳴り、ケーブルでつないだ装置が動く。
##     つなぐ：ボタンを持って装置を見て F（装置を持ってボタンを見ても同じ。もう一度で外す）。装置は、点火トーチと爆弾（すぐ爆発する）
##   ・点火トーチ：合図が来ると（手ぶらで F でも）、先から数秒、本物の炎が出る。炎の先にある、結んだロープ・導火線の先・
##     こぼれた火薬・爆弾の口に火が移る
##   ・目覚まし時計：手ぶらで F を押すたびに、ねじを巻く（巻くほど長く。文字盤の赤い針が、残りを指す）。針が上に戻ると鳴って、
##     ケーブルでつないだ装置が動く（押しボタンと同じ。つなぎ方も同じ）。役を演じている間に、仕掛けを動かせる
## 決めるのはホスト。ロープの張り（引く力）は、ホストだけが毎コマ計算する。
## 結び目・長さ・燃えている所・留めた滑車・ケーブル・炎は、"rig" の合図で全員へ配る（本番中は記録にも残り、見返しでも焼き切れる・鳴る・燃える）
const Prop := preload("res://scripts/prop.gd")
const VfxFire := preload("res://vfx/vfx_fire.gd")

const CREW_LAYER := 1 << 11
const ROPE_COLOR := Color(0.80, 0.66, 0.40)          # 会社のロープの色（cargo_coils.gd と同じ）
const CABLE_COLOR := Color(0.12, 0.12, 0.13)
const THICK := 0.02                                  # ロープの太さ（半径）。導火線と同じ
const KNOT := 0.02                                   # 結ぶときに足す、ゆるみ
const BURN_SEC := 1.6                                # 火が付いてから、焼き切れるまで
const FLAME_SEC := 3.0                               # 点火トーチの炎が出ている長さ
const FLAME_REACH := 0.45                            # 炎の先から、これだけの所まで火が移る
const SPREAD := 0.1                                  # 燃えている所・導火線の先から、これだけの所まで火が移る
const BLAST_CUT := 1.6                               # 爆発（力1）で、その場で切れるロープの距離
const AIM := 0.08                                    # 結んだロープを狙う太さ（視線からの離れ）
const PART_AIM := 0.22                               # 滑車・ボタン・トーチを狙う太さ
const CABLE_MAX := 14.0                              # ケーブルの長さ。これより離すと抜ける
const BETA := 0.25                                   # ロープの伸びを、1コマにこれだけの割合で戻す
const MAX_PULL := 40.0                               # 1コマに加える引きの上限（N・s）
const PRESS_MASS := 0.3                              # ボタンを押せる、いちばん軽い物（kg）
const PRESS_GAP := 0.5                               # 押してから、次に押せるまで（秒）
# 会社の備品の置き場所（はさみの隣の作業台の前の床）[種類, 場所, 向き]
const HOME := [
	["pulley", Vector3(70.15, 0.05, 18.45), 0.3], ["pulley", Vector3(70.15, 0.05, 18.95), 0.3],
	["buzzer", Vector3(69.45, 0.05, 18.5), 0.0], ["buzzer", Vector3(69.45, 0.05, 19.0), 0.0],
	["igniter", Vector3(68.85, 0.05, 18.55), 0.4], ["igniter", Vector3(68.85, 0.05, 19.05), 0.4],
	["timer", Vector3(68.25, 0.05, 18.8), 0.3],
]
# 部品の作り方 [ラベル, 素材, 重さ, 拡大]
const PARTS := {
	"pulley": ["滑車（クランプ付き）", "P081_c_clamp", 1.2, 2.0],
	"buzzer": ["押しボタン（呼び鈴）", "P085_desk_bell", 1.5, 2.6],
	"igniter": ["点火トーチ", "P030_fake_torch", 0.8, 1.4],
	"timer": ["目覚まし時計", "P044_alarm_clock", 0.6, 2.2],
}
const TRIGGERS := ["buzzer", "timer"]               # 鳴ると、ケーブルでつないだ装置が動く物
const WIND_STEP := 5.0                               # 目覚まし時計：F 1回で巻ける秒数
const WIND_MAX := 60.0                               # 目覚まし時計：巻ける上限（針が1周）
const DIAL_AT := Vector3(0, 0.107, 0.056)            # 目覚まし時計の文字盤の真ん中（素材から見た位置）
const WHEEL_AT := Vector3(0, 0.095, 0)               # 滑車の車の中心（物から見た位置）。ロープはここを通る
const WHEEL_R := 0.085
const CLAMP_LIFT := 0.2                              # クランプは、車の上に載せる
const TORCH_HEAD := Vector3(0, 0.62, 0)              # トーチの炎が出る所

var game: Node
var parts: Array = []                                # 備品（物）
var rows: Dictionary = {}                            # 結んだロープ：番号 → {a, b, via, len, fire, burn, cut}
var pending: Dictionary = {}                         # 結んでいる途中（参加者のID → {a, via}）
var mounts: Dictionary = {}                          # 留めた滑車：物のID → [留めた先の物のID（0＝壁など）, 留めた先から見た置き方]
var wires: Dictionary = {}                           # ケーブル：ボタンの物のID → [装置の物のID, ...]
var flames: Dictionary = {}                          # 炎が出ているトーチ：物のID → 残り秒
var timers: Dictionary = {}                          # 巻いてある目覚まし時計：物のID → 鳴るまでの残り秒
var _next := 1
var _pressed: Dictionary = {}                        # ホスト：ボタンが押されているか（物のID → 次に押せるまでの秒。負＝離れている）
var _rolling: Dictionary = {}                        # ホスト：引かれて転がしている台車（物のID → [元の摩擦, 残り秒]）
var _before_take := {}
var _live := {}
var _playback := false
var _send_t := 0.0
var _dirty := false
var _was_held := false                               # ホスト：前のコマで、場転でフィルムを止めていたか
# 見た目
var _ropes: MultiMeshInstance3D
var _cables: MultiMeshInstance3D
var _knots: MultiMeshInstance3D
var _sparks: Dictionary = {}                         # ロープの番号 → 火花
var _fx: Dictionary = {}                             # トーチの物のID → 炎
var _mark: MeshInstance3D


func setup() -> void:
	for row: Array in HOME:
		parts.append(_spawn(str(row[0]), row[1], float(row[2])))
	_ropes = _tubes(ROPE_COLOR, THICK, 0.15)
	_cables = _tubes(CABLE_COLOR, 0.012, 0.0)
	_knots = _tubes(ROPE_COLOR.darkened(0.15), THICK * 2.2, 0.1)
	# 狙った所の目印（制作班にだけ見える）
	_mark = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.07
	ring.rings = 12
	ring.ring_segments = 6
	_mark.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 1.0, 0.75)
	mat.no_depth_test = true
	_mark.material_override = mat
	_mark.layers = CREW_LAYER
	_mark.visible = false
	add_child(_mark)
	if Net.is_host() and game.production != null:
		for p: RigidBody3D in parts:
			game.production._home_layout[p.pid] = p.get_state()


# 備品を1つ作る（全員の画面で、同じ順に。物のIDがそろう）
func _spawn(kind: String, pos: Vector3, yaw: float) -> RigidBody3D:
	var spec: Array = PARTS[kind]
	var p: RigidBody3D = Prop.new()
	p.kind = kind
	p.label = str(spec[0])
	p.mass = float(spec[2])
	var root := Node3D.new()
	var model: Node3D = (load("res://assets/props/%s.glb" % spec[1]) as PackedScene).instantiate()
	model.scale = Vector3.ONE * float(spec[3])
	root.add_child(model)
	if kind == "pulley":
		model.position.y = CLAMP_LIFT
		_add_wheel(root)
	if kind == "timer":
		_add_dial_hand(model)
	p.visual = root
	p.add_child(root)
	var box: AABB = game.stage.merged_aabb(root)
	p.center = box.get_center()
	p.half = box.size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	game.stage._shape(p, box.get_center(), box.size * 0.97, false)
	return game.stage._register(p, pos, yaw)


# 滑車の車（溝のある鉄の車）と、クランプへつなぐ金具
func _add_wheel(root: Node3D) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.64, 0.68)
	steel.metallic = 0.7
	steel.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.21, 0.23)
	dark.roughness = 0.6
	for side: float in [-1.0, 1.0]:
		var disc := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = WHEEL_R
		c.bottom_radius = WHEEL_R
		c.height = 0.012
		c.radial_segments = 20
		disc.mesh = c
		disc.material_override = steel
		disc.rotation.x = PI * 0.5
		disc.position = WHEEL_AT + Vector3(0, 0, side * 0.014)
		root.add_child(disc)
	var groove := MeshInstance3D.new()
	var g := CylinderMesh.new()
	g.top_radius = WHEEL_R * 0.78
	g.bottom_radius = WHEEL_R * 0.78
	g.height = 0.018
	g.radial_segments = 20
	groove.mesh = g
	groove.material_override = dark
	groove.rotation.x = PI * 0.5
	groove.position = WHEEL_AT
	root.add_child(groove)
	# 車を挟む金具（両側の板）と、クランプへの軸
	for side: float in [-1.0, 1.0]:
		var plate := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.05, WHEEL_R + 0.07, 0.008)
		plate.mesh = b
		plate.material_override = steel
		plate.position = WHEEL_AT + Vector3(0, (WHEEL_R + 0.07) * 0.5 - 0.01, side * 0.026)
		root.add_child(plate)
	var shank := MeshInstance3D.new()
	var s := CylinderMesh.new()
	s.top_radius = 0.012
	s.bottom_radius = 0.012
	s.height = CLAMP_LIFT - WHEEL_AT.y - 0.02
	shank.mesh = s
	shank.material_override = steel
	shank.position = Vector3(0, (CLAMP_LIFT + WHEEL_AT.y) * 0.5 + 0.03, 0)
	root.add_child(shank)


# 目覚まし時計の、残りを指す赤い針（文字盤の真ん中が軸。巻いていなければ真上）
func _add_dial_hand(model: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "TimerHand"
	pivot.position = DIAL_AT
	model.add_child(pivot)
	var bar := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.006, 0.058, 0.004)
	bar.mesh = b
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.86, 0.16, 0.12)
	red.roughness = 0.5
	bar.material_override = red
	bar.position = Vector3(0, 0.026, 0)
	pivot.add_child(bar)


func _tubes(color: Color, radius: float, glow: float) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	tube.material = mat
	mm.mesh = tube
	mm.instance_count = 512
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-600, -100, -600), Vector3(1200, 300, 1200))
	mmi.top_level = true
	add_child(mmi)
	return mmi


# ---- 場所の計算 ----

func _prop(pid: int) -> RigidBody3D:
	var p: Variant = game.props.get(pid)
	return p if p is RigidBody3D and not p.absent else null


# ロープの端の場所。端は [物のID（0＝壁など）, 物から見た位置（0なら世界の位置）]
func _end_at(end: Array) -> Vector3:
	var pid := int(end[0])
	if pid == 0:
		return end[1]
	var p := _prop(pid)
	return p.global_transform * (end[1] as Vector3) if p != null else end[1]


func _wheel(pid: int) -> Vector3:
	var p := _prop(pid)
	return p.global_transform * WHEEL_AT if p != null else Vector3.ZERO


# ロープの道すじ：端 → 滑車の車 → … → 端
func _path(row: Dictionary) -> PackedVector3Array:
	var pts := PackedVector3Array([_end_at(row["a"])])
	for pid: int in row["via"]:
		pts.append(_wheel(pid))
	pts.append(_end_at(row["b"]))
	return pts


static func _length(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


static func _point_at(pts: PackedVector3Array, s: float) -> Vector3:
	var left := s
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		if left <= d or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(left / maxf(d, 0.0001), 0.0, 1.0))
		left -= d
	return pts[pts.size() - 1]


# その点に、いちばん近いロープの上の所 [道のり, 距離]
static func _nearest(pts: PackedVector3Array, q: Vector3) -> Array:
	var best := [0.0, INF]
	var run := 0.0
	for i in pts.size() - 1:
		var seg := pts[i + 1] - pts[i]
		var d := seg.length()
		var t := clampf((q - pts[i]).dot(seg) / maxf(d * d, 0.000001), 0.0, 1.0)
		var dist := q.distance_to(pts[i] + seg * t)
		if dist < float(best[1]):
			best = [run + d * t, dist]
		run += d
	return best


# 視線に、いちばん近いロープの上の所 [道のり, 視線からの離れ, 手前からの距離, 場所]
static func _nearest_ray(pts: PackedVector3Array, from: Vector3, dir: Vector3) -> Array:
	var best := [0.0, INF, 0.0, Vector3.ZERO]
	var run := 0.0
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		var steps := maxi(2, int(d / 0.05))
		for k in steps + 1:
			var t := float(k) / float(steps)
			var p := pts[i].lerp(pts[i + 1], t)
			var along := (p - from).dot(dir)
			if along < 0.2:
				continue
			var off := (p - from - dir * along).length()
			if off < float(best[1]):
				best = [run + d * t, off, along, p]
		run += d
	return best


# ---- 狙う（自分の画面） ----

func _view(me: Node) -> Array:
	var cam: Camera3D = me.get("cam")
	if cam == null:
		return []
	return [cam.global_position, -cam.global_basis.z]


func _reach_ok(me: Node, at: Vector3) -> bool:
	return at.distance_to(me.reach_base() + Vector3(0, 1.0, 0)) <= game.Player.REACH + 0.8


# 視線の先の面 {point, normal, pid（0＝壁など）}。持っている物と束はよける。何も無ければ {}
func _aim_surface(me: Node) -> Dictionary:
	var view := _view(me)
	if view.is_empty():
		return {}
	var skip: Array[RID] = []
	if me.held != 0 and game.props.has(me.held):
		skip.append((game.props[me.held] as CollisionObject3D).get_rid())
	skip.append(me.get_rid())
	var q := PhysicsRayQueryParameters3D.create(view[0], view[0] + (view[1] as Vector3) * 9.0, Prop.L_WORLD | Prop.L_PROP | Prop.L_THIN)
	q.exclude = skip
	var hit: Dictionary = me.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not _reach_ok(me, hit["position"]):
		return {}
	var node: Node = hit["collider"]
	while node != null and not ("pid" in node):
		node = node.get_parent()
	var pid := 0
	if node != null and node is RigidBody3D:
		if node.absent or node.kind in ["mark", "truck"]:
			return {}
		pid = int(node.pid)
	return {"point": hit["position"], "normal": hit["normal"], "pid": pid}


# 視線の先にある部品（滑車・ボタン・トーチ）。見ていなければ null
func _aim_part(me: Node, kinds: Array) -> RigidBody3D:
	var view := _view(me)
	if view.is_empty():
		return null
	var best: RigidBody3D = null
	var best_off := INF
	for p: RigidBody3D in parts:
		if p.absent or not (p.kind in kinds) or p.pid == me.held:
			continue
		var c: Vector3 = p.center_global()
		var along := (c - (view[0] as Vector3)).dot(view[1])
		if along < 0.2 or not _reach_ok(me, c):
			continue
		# 遠くから見るほど、狙いの幅を広くする（三人称の視点は、体より後ろの高い所にある）
		var off := (c - (view[0] as Vector3) - (view[1] as Vector3) * along).length()
		if off < PART_AIM + 0.02 * along and off < best_off:
			best = p
			best_off = off
	# 爆弾も装置（ケーブルの行き先）
	if "fx" in kinds and game.get("fx") != null and not game.fx.absent and game.fx.pid != me.held and me.target == game.fx:
		return game.fx
	return best


func _aim_row(me: Node) -> Dictionary:
	var view := _view(me)
	if view.is_empty():
		return {}
	var best := {}
	for id: int in rows:
		if bool(rows[id]["cut"]):
			continue
		var hit := _nearest_ray(_path(rows[id]), view[0], view[1])
		if float(hit[1]) > AIM + 0.02 * float(hit[2]) or not _reach_ok(me, hit[3]):
			continue
		if best.is_empty() or float(hit[1]) < float(best["off"]):
			best = {"row": id, "s": hit[0], "off": hit[1], "point": hit[3]}
	return best


func _is_coil(p: Node) -> bool:
	return p != null and game.cargo_kit != null and game.cargo_kit.is_coil(p) and game.cargo_kit.coil_id(p) == 0


func _usable() -> bool:
	return game.production != null and not game.replaying and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE]


# 先に F を受ける仕組み（荷台のロープ・爆弾の道具）が、何かをするか。するなら、こちらは何もしない
func _others_busy(me: Node) -> bool:
	if game.cargo_kit != null and not (str(game.cargo_kit.f_action(me).get("do", "rope")) in ["rope"]):
		return true
	if game.bomb_kit != null and not (str(game.bomb_kit.f_action(me).get("do", "coil")) in ["coil", "scissors"]):
		return true
	return false


# いま F を押すと起きること。{"do": 種類, ...}。関係なければ {}
func f_action(me: Node) -> Dictionary:
	if me == null or me.operating != 0 or not _usable() or _others_busy(me):
		return {}
	var held: RigidBody3D = game.props.get(me.held) if me.held != 0 else null
	var mine: bool = pending.has(int(me.peer_id))
	if held != null and _is_coil(held):
		var row := _aim_row(me)
		if not row.is_empty() and not mine:
			row["do"] = "untie"
			return row
		var pulley := _aim_part(me, ["pulley"])
		if pulley != null:
			return {"do": "via" if mine else "tie", "pid": pulley.pid, "point": _wheel(pulley.pid), "pulley": true}
		var at := _aim_surface(me)
		if at.is_empty() or (int(at["pid"]) == 0 and (at["normal"] as Vector3).y > 0.7):
			return {"do": "hold_rope"} if mine else {}
		if int(at["pid"]) == held.pid:
			return {}
		at["do"] = "tie"
		return at
	if held != null and held.kind == "pulley":
		var at := _aim_surface(me)
		if at.is_empty() or (int(at["pid"]) == 0 and (at["normal"] as Vector3).y > 0.7):
			return {}
		at["do"] = "mount"
		return at
	if held != null and held.kind in TRIGGERS:
		var dev := _aim_part(me, ["igniter", "fx"])
		return {"do": "wire", "bell": held.pid, "dev": dev.pid, "point": dev.center_global()} if dev != null else {}
	if held != null and (held.kind == "igniter" or held == game.get("fx")):
		var bell := _aim_part(me, TRIGGERS)
		return {"do": "wire", "bell": bell.pid, "dev": held.pid, "point": bell.center_global()} if bell != null else {}
	if held != null and game.bomb_kit != null and held == game.bomb_kit.scissors:
		var snip := _aim_row(me)
		if not snip.is_empty():
			snip["do"] = "cut"
		return snip
	if held != null:
		return {}
	var row := _aim_row(me)
	if not row.is_empty():
		row["do"] = "fire"
		return row
	var part := _aim_part(me, ["pulley", "buzzer", "igniter", "timer"])
	if part != null:
		if part.kind == "timer":
			return {"do": "wind", "pid": part.pid, "point": part.center_global()}
		if part.kind == "pulley" and mounts.has(part.pid):
			return {"do": "unmount", "pid": part.pid, "point": part.center_global()}
		if part.kind == "buzzer":
			return {"do": "press", "pid": part.pid, "point": part.center_global()}
		if part.kind == "igniter":
			return {"do": "light", "pid": part.pid, "point": part.global_transform * TORCH_HEAD}
	return {}


func hook_f(me: Node) -> bool:
	var act := f_action(me)
	match str(act.get("do", "")):
		"tie":
			if bool(act.get("pulley", false)):
				h_tie.rpc_id(1, int(act["pid"]), _wheel(int(act["pid"])), true)
			else:
				h_tie.rpc_id(1, int(act["pid"]), act["point"], false)
		"via":
			h_via.rpc_id(1, int(act["pid"]))
		"untie":
			h_untie.rpc_id(1, int(act["row"]))
		"fire":
			h_fire.rpc_id(1, int(act["row"]), float(act["s"]))
		"cut":
			h_cut.rpc_id(1, int(act["row"]), float(act["s"]))
		"mount":
			h_mount.rpc_id(1, int(me.held), act["point"], act["normal"], int(act["pid"]))
		"unmount":
			h_unmount.rpc_id(1, int(act["pid"]))
		"wire":
			h_wire.rpc_id(1, int(act["bell"]), int(act["dev"]))
		"press":
			h_press.rpc_id(1, int(act["pid"]))
		"wind":
			h_wind.rpc_id(1, int(act["pid"]))
		"light":
			h_flame.rpc_id(1, int(act["pid"]))
		"hold_rope":
			game.hud.show_toast("ロープの先を結ぶ物（物・壁・柱・手すり）を見て F。束を手放すと、やめる", game.hud.YELLOW)
		_:
			return false
	return true


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	var act := f_action(me)
	var put: String = ("\n" + str(game.hold_hint())) if me.held != 0 else ""
	_show_mark(act)
	match str(act.get("do", "")):
		"tie":
			if pending.has(int(me.peer_id)):
				return {"keys_all": "F もう一方の端を結ぶ" + put}
			return {"label": "滑車" if bool(act.get("pulley", false)) else _label, "keys_all": "F ロープの端を結ぶ（仕掛け）" + put}
		"via":
			return {"label": "滑車", "keys_all": "F 滑車にロープを掛ける" + put}
		"hold_rope":
			return {"keys_all": "ロープの先を結ぶ物を見て F" + put}
		"untie":
			return {"label": "結んだロープ", "keys_all": "F ほどく" + put}
		"fire":
			return {"label": "結んだロープ", "keys_all": "F 火を付ける（焼き切れる）"}
		"cut":
			return {"label": "結んだロープ", "keys_all": "F 切る" + put}
		"mount":
			return {"keys_all": "F 滑車をここに留める" + put}
		"unmount":
			return {"label": "滑車", "keys_all": "F 外す"}
		"wire":
			var on: bool = (wires.get(int(act["bell"]), []) as Array).has(int(act["dev"]))
			return {"keys_all": ("F ケーブルを抜く" if on else "F ケーブルでつなぐ") + put}
		"press":
			return {"label": "押しボタン", "keys_all": "F 押す\n左クリック 持つ"}
		"wind":
			return {"label": "目覚まし時計", "keys_all": "F ねじを巻く（巻くほど長く）\n左クリック 持つ"}
		"light":
			return {"label": "点火トーチ", "keys_all": "F 炎を出す（ためし）\n左クリック 持つ"}
	return {}


func _show_mark(act: Dictionary) -> void:
	if _mark == null:
		return
	_mark.visible = act.has("point") and str(act.get("do", "")) in ["tie", "via", "untie", "fire", "cut", "mount"]
	if _mark.visible:
		_mark.global_position = act["point"]
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_mark.look_at(cam.global_position, Vector3.UP, true)
			_mark.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# ---- ホスト：決める ----

func _host_ok() -> bool:
	return Net.is_host() and not _playback and _usable()


func _say(who: int, text: String, bad: bool) -> void:
	if who != 0:
		game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])


func _holding_coil(who: int) -> bool:
	var pl: Node = game.players.get(who)
	return pl != null and pl.held != 0 and _is_coil(game.props.get(pl.held))


func _near(who: int, at: Vector3) -> bool:
	var pl: Node = game.players.get(who)
	return pl != null and at.distance_to(pl.reach_base() + Vector3(0, 1.0, 0)) <= game.Player.REACH + 1.5


func _stock() -> float:
	return float(game.bomb_kit.stock) if game.bomb_kit != null else 0.0


func _use(amount: float) -> void:
	if game.bomb_kit == null:
		return
	game.bomb_kit.stock = clampf(float(game.bomb_kit.stock) - amount, 0.0, float(game.bomb_kit.COIL_M))
	game.bomb_kit._dirty = true


# 端の記録：物なら、その物から見た位置
func _end_of(pid: int, at: Vector3) -> Array:
	var p := _prop(pid)
	return [pid, p.global_transform.affine_inverse() * at] if p != null else [0, at]


# 束を持って F：端を結ぶ。結んでいる途中なら、もう一方を結んで張る
@rpc("any_peer", "call_local", "reliable")
func h_tie(pid: int, at: Vector3, on_wheel: bool) -> void:
	var who := Net.sender()
	if not _host_ok() or not at.is_finite() or not _holding_coil(who) or not _near(who, at):
		return
	if pid != 0 and _prop(pid) == null:
		return
	var end: Array = [pid, WHEEL_AT] if on_wheel and pid != 0 else _end_of(pid, at)
	if not pending.has(who):
		if _stock() < 0.3:
			_say(who, "束のロープを使い切った", true)
			return
		pending[who] = {"a": end, "via": []}
		_say(who, "結んだ。もう一方の端を結ぶ物を見て F（滑車を見て F なら、滑車に掛ける）", false)
		game.host_ev("sfx", ["fix", at])
		_changed()
		return
	var row := {"a": pending[who]["a"], "b": end, "via": (pending[who]["via"] as Array).duplicate(), "len": 0.0, "fire": -1.0, "burn": 0.0, "cut": false}
	if int(end[0]) == int(row["a"][0]) and row["via"].is_empty() and _end_at(end).distance_to(_end_at(row["a"])) < 0.15:
		pending.erase(who)
		_say(who, "結ぶのをやめた", false)
		_changed()
		return
	if host_add_row(row["a"], row["b"], row["via"]) == 0:
		_say(who, "束のロープが足りない", true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	pending.erase(who)
	game.host_ev("sfx", ["fix", at])
	_say(who, "張った。手ぶらで見て F で火を付ける・束を持って見て F でほどく", false)
	_changed()


# ロープを1本張る（ホスト）。長さは、いまの道すじ＋結び目のゆるみ。束が足りなければ 0
func host_add_row(a: Array, b: Array, via: Array) -> int:
	var row := {"a": a, "b": b, "via": via.duplicate(), "len": 0.0, "fire": -1.0, "burn": 0.0, "cut": false}
	var need := _length(_path(row)) + KNOT
	if need > _stock():
		return 0
	row["len"] = need
	_use(need)
	var id := _next
	rows[id] = row
	_next += 1
	_changed()
	return id


# 結んでいる途中のロープを、滑車に掛ける
@rpc("any_peer", "call_local", "reliable")
func h_via(pid: int) -> void:
	var who := Net.sender()
	var p := _prop(pid)
	if not _host_ok() or p == null or p.kind != "pulley" or not pending.has(who) or not _near(who, _wheel(pid)):
		return
	var via: Array = pending[who]["via"]
	if not via.is_empty() and int(via[via.size() - 1]) == pid:
		return
	via.append(pid)
	game.host_ev("sfx", ["fix", _wheel(pid)])
	_changed()


@rpc("any_peer", "call_local", "reliable")
func h_untie(id: int) -> void:
	var who := Net.sender()
	if not _host_ok() or not rows.has(id) or not _holding_coil(who):
		return
	var row: Dictionary = rows[id]
	if not bool(row["cut"]):
		_use(-float(row["len"]))
	rows.erase(id)
	game.host_ev("sfx", ["unfix", _point_at(_path(row), 0.0)])
	_changed()


# 手ぶらで F：そこに火を付ける
@rpc("any_peer", "call_local", "reliable")
func h_fire(id: int, s: float) -> void:
	var who := Net.sender()
	if not _host_ok() or not rows.has(id) or not is_finite(s):
		return
	if not _near(who, _point_at(_path(rows[id]), s)):
		_say(who, "火が届かない。ロープに近づく", true)
		return
	host_ignite(id, s)


# はさみで切る
@rpc("any_peer", "call_local", "reliable")
func h_cut(id: int, s: float) -> void:
	var who := Net.sender()
	var pl: Node = game.players.get(who)
	if not _host_ok() or not rows.has(id) or not is_finite(s) or pl == null or game.bomb_kit == null or pl.held != game.bomb_kit.scissors.pid:
		return
	host_snap(id, s)


# そこに火を付ける（ホスト。どこからでも呼べる：手・導火線・トーチ・燃えているロープ）
func host_ignite(id: int, s: float) -> void:
	var row: Dictionary = rows.get(id, {})
	if row.is_empty() or bool(row["cut"]) or float(row["fire"]) >= 0.0:
		return
	row["fire"] = clampf(s, 0.0, float(row["len"]))
	row["burn"] = BURN_SEC
	game.host_ev("sfx", ["fuse", _point_at(_path(row), s)])
	_changed()


# そこで切れる（ホスト）
func host_snap(id: int, s: float) -> void:
	var row: Dictionary = rows.get(id, {})
	if row.is_empty() or bool(row["cut"]):
		return
	var pts := _path(row)
	row["cut"] = true
	row["fire"] = clampf(s, 0.0, _length(pts))
	row["burn"] = 0.0
	row["drop"] = _drops(pts, float(row["fire"]))
	game.host_ev("sfx", ["unfix", _point_at(pts, s)])
	_changed()


# 切れたロープの垂れ下がる長さ [端 a の側, 端 b の側]（滑車に掛かっていた分は、滑り落ちる）
func _drops(pts: PackedVector3Array, s: float) -> Array:
	var total := _length(pts)
	return [clampf(s, 0.0, 1.6), clampf(total - s, 0.0, 1.6)]


# 滑車を持って F：見ている面（壁・柱・物）に留める
@rpc("any_peer", "call_local", "reliable")
func h_mount(pid: int, at: Vector3, normal: Vector3, onto: int) -> void:
	var who := Net.sender()
	var p := _prop(pid)
	if not _host_ok() or p == null or p.kind != "pulley" or p.holder != who or not at.is_finite() or not normal.is_finite() or not _near(who, at):
		return
	if onto != 0 and (_prop(onto) == null or onto == pid):
		return
	game.host_release(p)
	host_mount(p, at, normal.normalized(), _prop(onto) if onto != 0 else null)
	_say(who, "滑車を留めた。ロープの束を持って滑車を見て F で、ロープを掛ける（見て F で外す）", false)


# 滑車を、その面に留める（ホスト）。壁なら背を壁に付けて車が下、上向きの面なら立てて置く
func host_mount(p: RigidBody3D, at: Vector3, normal: Vector3, onto: RigidBody3D) -> void:
	var basis: Basis
	var pos: Vector3
	if absf(normal.y) < 0.7:
		var out := Vector3(normal.x, 0.0, normal.z).normalized()
		basis = Basis(out, Vector3.UP, out.cross(Vector3.UP))
		pos = at + out * 0.13 - Vector3(0, CLAMP_LIFT + 0.12, 0)
	else:
		basis = Basis(Vector3.UP, p.global_rotation.y)
		pos = at + (Vector3.ZERO if normal.y > 0.0 else Vector3(0, -(CLAMP_LIFT + 0.27), 0))
	var place := Transform3D(basis.orthonormalized(), pos)
	if onto != null:
		p.add_collision_exception_with(onto)
		onto.add_collision_exception_with(p)
		mounts[p.pid] = [onto.pid, onto.global_transform.affine_inverse() * place]
	else:
		mounts[p.pid] = [0, place]
	p.restore([place.origin, place.basis.get_rotation_quaternion(), true])
	game.host_ev("sfx", ["fix", at])
	_changed()


@rpc("any_peer", "call_local", "reliable")
func h_unmount(pid: int) -> void:
	var who := Net.sender()
	var p := _prop(pid)
	if not _host_ok() or p == null or not mounts.has(pid) or not _near(who, p.center_global()):
		return
	host_unmount(p)


func host_unmount(p: RigidBody3D) -> void:
	var m: Array = mounts.get(p.pid, [])
	if not m.is_empty() and int(m[0]) != 0 and _prop(int(m[0])) != null:
		var onto := _prop(int(m[0]))
		p.remove_collision_exception_with(onto)
		onto.remove_collision_exception_with(p)
	mounts.erase(p.pid)
	p.set_fixed(false)
	p.sleeping = false
	game.host_ev("sfx", ["unfix", p.global_position])
	_changed()


# ボタンと装置を、ケーブルでつなぐ・抜く
@rpc("any_peer", "call_local", "reliable")
func h_wire(bell: int, dev: int) -> void:
	var who := Net.sender()
	var b := _prop(bell)
	var d := _prop(dev)
	if not _host_ok() or b == null or d == null or not (b.kind in TRIGGERS) or not (d.kind == "igniter" or d == game.get("fx")):
		return
	if b.holder != who and d.holder != who:
		return
	var list: Array = wires.get(bell, [])
	if list.has(dev):
		list.erase(dev)
		_say(who, "ケーブルを抜いた", false)
	else:
		list.append(dev)
		_say(who, "ケーブルでつないだ。%sと、%s" % ["ボタンが押される" if b.kind == "buzzer" else "時計が鳴る", "トーチの炎が出る" if d.kind == "igniter" else "爆弾が爆発する"], false)
	wires[bell] = list
	game.host_ev("sfx", ["fix", d.global_position])
	_changed()


@rpc("any_peer", "call_local", "reliable")
func h_press(bell: int) -> void:
	var who := Net.sender()
	var b := _prop(bell)
	if not _host_ok() or b == null or b.kind != "buzzer" or not _near(who, b.center_global()):
		return
	host_ring(b)


# 手ぶらで F：目覚まし時計のねじを巻く（巻くたびに WIND_STEP 秒。針が1周まで）
@rpc("any_peer", "call_local", "reliable")
func h_wind(pid: int) -> void:
	var who := Net.sender()
	var t := _prop(pid)
	if not _host_ok() or t == null or t.kind != "timer" or not _near(who, t.center_global()):
		return
	timers[pid] = minf(float(timers.get(pid, 0.0)) + WIND_STEP, WIND_MAX)
	game.host_ev("sfx", ["fix", t.global_position])
	_changed()


@rpc("any_peer", "call_local", "reliable")
func h_flame(pid: int) -> void:
	var who := Net.sender()
	var t := _prop(pid)
	if not _host_ok() or t == null or t.kind != "igniter" or not _near(who, t.center_global()):
		return
	host_flame(t)


# ボタンが鳴る（ホスト）：つないだ装置が動く
func host_ring(b: RigidBody3D) -> void:
	_pressed[b.pid] = PRESS_GAP
	game.host_ev("rig_ring", [b.pid])
	for dev: int in wires.get(b.pid, []):
		var d := _prop(dev)
		if d == null:
			continue
		if d.kind == "igniter":
			host_flame(d)
		elif d == game.get("fx"):
			_blow(d)


func host_flame(t: RigidBody3D) -> void:
	if flames.has(t.pid):
		flames[t.pid] = FLAME_SEC
		return
	flames[t.pid] = FLAME_SEC
	game.host_ev("sfx", ["whoosh_soft", t.global_transform * TORCH_HEAD])
	_changed()


# ケーブルの合図で、爆弾がすぐ爆発する（導火線がつないであれば、導火線に火が付く）
func _blow(bomb: RigidBody3D) -> void:
	var bk: Node = game.bomb_kit
	if bk == null or bomb.fuse >= 0.0:
		return
	var cord: Node3D = bk.bomb_cord()
	if cord != null:
		_light_cord(cord, 1)
		return
	if game.state == game.S.TAKE and not bomb.loaded():
		game.host_ev("toast", ["ボタンが押された！ ……が、爆弾に火薬が入っていない", 1])
		return
	if bomb.ignite(bomb.FUSE_SEC):
		game.host_ev("toast", ["ボタンが押された！ 爆発する！", 1])


# 導火線の端に火を付ける（ホスト。bomb_kit.gd の h_light と同じ決まり。根元が爆弾につながっている側には付かない）
func _light_cord(cord: Node3D, end: int) -> void:
	var bk: Node = game.bomb_kit
	if cord.burning or (end == 0 and cord.a_body != null):
		return
	var at: Vector3 = cord.tip() if end == 1 else cord.root()
	cord.b_body = null
	if end == 0:
		cord.flip()
		if bk._rg() != null:
			bk._rg().host_flipped(0, cord.id)
	cord.burning = true
	cord.wake()
	game.host_ev("sfx", ["fuse", at])
	bk._broadcast(true)


# ---- ホスト：毎コマ ----

func _physics_process(delta: float) -> void:
	if game == null or game.production == null:
		return
	if Net.is_host() and not _playback and not game.replaying:
		_host_tick(delta)
		_note_resume()
	_tick_fire(delta)


# 場転のあと、フィルムを回し直した瞬間：止めている間に結んだ・留めた・つないだ物を、見返しの記録に残し直す
# （止めている間の合図は記録されないので、そのままだと、見返しでは次の変化まで映らない）
func _note_resume() -> void:
	var held: bool = game.state == game.S.TAKE and game.take_held()
	if _was_held and not held and game.state == game.S.TAKE:
		game._rec_events.append([float(game.take_t), "rig", [snapshot()]])
	_was_held = held


func _host_tick(delta: float) -> void:
	# 留めた滑車：留めた物と一緒に動く
	for pid: int in mounts.keys():
		var p := _prop(pid)
		var m: Array = mounts[pid]
		if p == null:
			mounts.erase(pid)
			_changed()
			continue
		if p.holder != 0 or not p.fixed:
			host_unmount(p)
			continue
		if int(m[0]) != 0:
			var onto := _prop(int(m[0]))
			if onto == null:
				host_unmount(p)
				continue
			p.global_transform = onto.global_transform * (m[1] as Transform3D)
	# 結んでいる途中：束を手放したら、やめる
	for who: int in pending.keys():
		if not _holding_coil(who):
			pending.erase(who)
			_changed()
	# ロープの端の物が無くなったら、ほどける
	for id: int in rows.keys():
		var row: Dictionary = rows[id]
		for end: Array in [row["a"], row["b"]]:
			if int(end[0]) != 0 and _prop(int(end[0])) == null:
				if not bool(row["cut"]):
					_use(-float(row["len"]))
				rows.erase(id)
				_changed()
				break
	# 引く
	for id: int in rows:
		if not bool(rows[id]["cut"]):
			_pull(rows[id], delta)
	# 引かれていない台車は、もとの止まりやすさに戻す
	for pid: int in _rolling.keys():
		_rolling[pid][1] = float(_rolling[pid][1]) - delta
		if float(_rolling[pid][1]) <= 0.0:
			var p := _prop(pid)
			if p != null and p.holder == 0 and p.physics_material_override != null:
				p.physics_material_override.friction = float(_rolling[pid][0])
			_rolling.erase(pid)
	_host_fire(delta)
	_host_buttons(delta)
	# 目覚まし時計：針が上に戻ったら鳴る
	for pid: int in timers.keys():
		var t := _prop(pid)
		timers[pid] = float(timers[pid]) - delta
		if t == null or float(timers[pid]) <= 0.0:
			timers.erase(pid)
			if t != null:
				host_ring(t)
			_changed()
	_send_t -= delta
	if _dirty and _send_t <= 0.0:
		_broadcast()


# ロープの張り：道すじが長さより伸びていれば、端の物（と、留めていない滑車）を、ロープの向きへ引く。押しはしない
func _pull(row: Dictionary, delta: float) -> void:
	var pts := _path(row)
	var over := _length(pts) - float(row["len"])
	if over <= 0.0:
		return
	var n := pts.size()
	var items: Array = []        # [物, 点, 引く向き]
	items.append([_end_body(row["a"]), pts[0], (pts[1] - pts[0]).normalized()])
	var via: Array = row["via"]
	for k in via.size():
		var at := pts[k + 1]
		items.append([_via_body(int(via[k])), at, (pts[k] - at).normalized() + (pts[k + 2] - at).normalized()])
	items.append([_end_body(row["b"]), pts[n - 1], (pts[n - 2] - pts[n - 1]).normalized()])
	var rate := 0.0
	var k_sum := 0.0
	for it: Array in items:
		var body: RigidBody3D = it[0]
		if body == null:
			continue
		var r: Vector3 = (it[1] as Vector3) - body.global_position
		var dir: Vector3 = it[2]
		rate -= (body.linear_velocity + body.angular_velocity.cross(r)).dot(dir)
		var rn := r.cross(dir)
		var inv_i := Basis.IDENTITY.scaled(Vector3.ZERO)
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state != null:
			inv_i = state.inverse_inertia_tensor
		k_sum += dir.length_squared() / maxf(body.mass, 0.05) + rn.dot(inv_i * rn)
	if k_sum <= 0.0:
		return
	var lam := clampf((rate + minf(over, 0.3) * BETA / delta) / k_sum, 0.0, MAX_PULL)
	if lam <= 0.0:
		return
	for it: Array in items:
		var body: RigidBody3D = it[0]
		if body == null:
			continue
		body.sleeping = false
		body.apply_impulse((it[2] as Vector3) * lam, (it[1] as Vector3) - body.global_position)
		if body.rolls:
			_roll(body)


# 引ける物（自由に動く物）。持っている・固定した・動かせない物は、引かれない（壁と同じ）
func _end_body(end: Array) -> RigidBody3D:
	var p := _prop(int(end[0])) if int(end[0]) != 0 else null
	if p == null or p.freeze or p.holder != 0 or p.immovable:
		return null
	return p


# 滑車：留めてあれば、留めた先の物が引かれる。留めていなければ、滑車そのものが引かれる（動く滑車）
func _via_body(pid: int) -> RigidBody3D:
	if mounts.has(pid):
		var m: Array = mounts[pid]
		return _end_body([int(m[0]), Vector3.ZERO]) if int(m[0]) != 0 else null
	return _end_body([pid, Vector3.ZERO])


# 引かれている台車は、車輪で転がる（置いてある台車は、ふだん止まりやすくしてある）
func _roll(body: RigidBody3D) -> void:
	if body.physics_material_override == null:
		return
	if not _rolling.has(body.pid):
		_rolling[body.pid] = [body.physics_material_override.friction, 0.0]
	body.physics_material_override.friction = 0.05
	_rolling[body.pid][1] = 0.6


# 火：燃えている所は、時間がたつと焼き切れる。導火線の先・トーチの炎・燃えている所が触れたロープに、火が移る
func _host_fire(delta: float) -> void:
	var sources: Array = []          # 火のある所 [場所, 届く距離]
	for id: int in rows.keys():
		var row: Dictionary = rows[id]
		if bool(row["cut"]) or float(row["fire"]) < 0.0:
			continue
		row["burn"] = float(row["burn"]) - delta
		var pts := _path(row)
		sources.append([_point_at(pts, float(row["fire"])), SPREAD])
		if float(row["burn"]) <= 0.0:
			host_snap(id, float(row["fire"]))
	var bk: Node = game.bomb_kit
	if bk != null:
		for cord: Node3D in bk.cords.values():
			if cord.burning and cord.length > 0.02:
				sources.append([cord.tip(), SPREAD])
	for pid: int in flames.keys():
		flames[pid] = float(flames[pid]) - delta
		var t := _prop(pid)
		if t == null or float(flames[pid]) <= 0.0:
			flames.erase(pid)
			_changed()
			continue
		var head: Vector3 = t.global_transform * TORCH_HEAD
		sources.append([head, FLAME_REACH])
		_torch_reach(head)
	for id: int in rows.keys():
		var row: Dictionary = rows[id]
		if bool(row["cut"]) or float(row["fire"]) >= 0.0:
			continue
		var pts := _path(row)
		for src: Array in sources:
			var hit := _nearest(pts, src[0])
			if float(hit[1]) <= float(src[1]):
				host_ignite(id, float(hit[0]))
				break


# トーチの炎：導火線の端・こぼれた火薬・爆弾の口に、火が移る
func _torch_reach(head: Vector3) -> void:
	var bk: Node = game.bomb_kit
	if bk == null:
		return
	for cord: Node3D in bk.cords.values():
		if cord.burning:
			continue
		if cord.tip().distance_to(head) <= FLAME_REACH:
			_light_cord(cord, 1)
		elif cord.root().distance_to(head) <= FLAME_REACH:
			_light_cord(cord, 0)
	bk._touch_spills(head, FLAME_REACH * 0.6, 0.0)
	var bomb: RigidBody3D = game.get("fx")
	if bomb != null and not bomb.absent and bomb.holder == 0 and bomb.mouth().distance_to(head) <= FLAME_REACH + 0.1 and bk.bomb_cord() == null:
		_blow(bomb)


# ボタン：上に物が載っている・人が乗っていると、押されている。押された瞬間に鳴る
func _host_buttons(delta: float) -> void:
	for p: RigidBody3D in parts:
		if p.kind != "buzzer":
			continue          # 載る・踏むで鳴るのは、押しボタンだけ
		var gap := float(_pressed.get(p.pid, -1.0))
		if gap > 0.0:
			_pressed[p.pid] = gap - delta
		if p.absent or p.holder != 0 or p.global_basis.y.y < 0.6:
			continue
		var down := _weighed(p)
		var was := gap > -0.5            # 押されたまま（または、鳴ったすぐあと）
		if down and not was:
			host_ring(p)
		elif not down and gap <= 0.0:
			_pressed[p.pid] = -1.0
		elif down and gap <= 0.0:
			_pressed[p.pid] = 0.0        # 押されたまま：離れるまで、鳴らない


func _weighed(bell: RigidBody3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(bell.half.x * 1.5, 0.12, bell.half.z * 1.5)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(bell.global_basis.orthonormalized(), bell.global_transform * Vector3(0, bell.half.y * 2.0 + 0.03, 0))
	q.collision_mask = Prop.L_PROP | Prop.L_CHAR
	q.exclude = [bell.get_rid()]
	for hit: Dictionary in bell.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var body: Object = hit["collider"]
		if body is CharacterBody3D:
			return true
		if body is RigidBody3D and "pid" in body and not body.absent and body.mass >= PRESS_MASS and body.holder == 0:
			return true
	return false


# ---- 同期と記録（"rig" の合図） ----

func snapshot() -> Dictionary:
	var p := {}
	for who: int in pending:
		p[who] = (pending[who] as Dictionary).duplicate(true)
	return {"rows": rows.duplicate(true), "pending": p, "mounts": mounts.duplicate(true), "wires": wires.duplicate(true), "flames": flames.duplicate(), "timers": timers.duplicate(), "next": _next}


func _changed() -> void:
	_dirty = true
	_send_t = minf(_send_t, 0.0)


func _broadcast() -> void:
	_dirty = false
	_send_t = 0.25
	game.host_ev("rig", [snapshot()])


func hook_events() -> Array:
	return ["rig", "rig_ring"]


func hook_rec_events() -> Array:
	return ["rig", "rig_ring"]


func hook_event(n: String, a: Array) -> void:
	if n == "rig":
		if not Net.is_host() or _playback or game.replaying:
			_apply(a[0])
	elif n == "rig_ring":
		_ring_seen(int(a[0]))


func _apply(data: Dictionary) -> void:
	rows = (data.get("rows", {}) as Dictionary).duplicate(true)
	pending = (data.get("pending", {}) as Dictionary).duplicate(true)
	mounts = (data.get("mounts", {}) as Dictionary).duplicate(true)
	wires = (data.get("wires", {}) as Dictionary).duplicate(true)
	flames = (data.get("flames", {}) as Dictionary).duplicate()
	timers = (data.get("timers", {}) as Dictionary).duplicate()
	_next = int(data.get("next", _next))


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "rig", [snapshot()])


# ホストが前の状態へ戻す（撮り直し・見返しの終わり）。束の長さも、戻した分だけ合わせる
func _restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var before := _in_use()
	for pid: int in mounts.keys():
		if not (data.get("mounts", {}) as Dictionary).has(pid) and _prop(pid) != null:
			host_unmount(_prop(pid))
	_apply(data)
	_use(_in_use() - before)
	for pid: int in mounts:
		var m: Array = mounts[pid]
		var p := _prop(pid)
		var onto := _prop(int(m[0])) if int(m[0]) != 0 else null
		if p != null and onto != null:
			p.add_collision_exception_with(onto)
			onto.add_collision_exception_with(p)
	_broadcast()


func _in_use() -> float:
	var total := 0.0
	for row: Dictionary in rows.values():
		total += float(row["len"])
	return total


func hook_take_ready() -> void:
	_before_take = snapshot()


func hook_take_start() -> void:
	game._rec_events.append([0.0, "rig", [snapshot()]])


func hook_retake() -> void:
	if Net.is_host():
		_restore(_before_take)


func hook_playback(on: bool) -> void:
	if on:
		_live = snapshot()
		_playback = true
	else:
		_playback = false
		_restore(_live)


# 帰社：ロープは全部ほどいて束へ戻し（焼けた分は戻らない）、滑車を外し、ケーブルを抜く。部品は置き場所へ戻る（production_flow.gd）
func hook_return_office() -> void:
	if not Net.is_host():
		return
	for p: RigidBody3D in parts:
		if mounts.has(p.pid):
			host_unmount(p)
	for row: Dictionary in rows.values():
		if not bool(row["cut"]):
			_use(-float(row["len"]))
	rows.clear()
	pending.clear()
	wires.clear()
	flames.clear()
	timers.clear()
	_broadcast()


# 爆発：そばの結んだロープは、その場で切れる
func hook_core_event(n: String, a: Array) -> void:
	if n != "burst" or not Net.is_host() or _playback or game.replaying:
		return
	var pos: Vector3 = a[0]
	var reach := BLAST_CUT * maxf(float(a[1]) if a.size() > 1 else 0.0, 0.6)
	for id: int in rows.keys():
		if bool(rows[id]["cut"]):
			continue
		var hit := _nearest(_path(rows[id]), pos)
		if float(hit[1]) <= reach:
			host_snap(id, float(hit[0]))


# ---- 全員の画面：見た目 ----

# 燃えている所の時計（全員の画面で進める。ホストの決めた状態が届くたびに、そろう）
func _tick_fire(delta: float) -> void:
	if Net.is_host() and not _playback and not game.replaying:
		return
	for row: Dictionary in rows.values():
		if not bool(row["cut"]) and float(row["fire"]) >= 0.0:
			row["burn"] = maxf(0.0, float(row["burn"]) - delta)
	for pid: int in flames.keys():
		flames[pid] = float(flames[pid]) - delta
		if float(flames[pid]) <= 0.0:
			flames.erase(pid)
	for pid: int in timers.keys():
		timers[pid] = maxf(0.0, float(timers[pid]) - delta)


func _ring_seen(pid: int) -> void:
	var b := _prop(pid)
	if b == null:
		return
	if b.kind == "timer":
		# 目覚まし時計：ジリリと鳴って、小刻みに震える
		Sfx.play("phone_ring", b.global_position)
		var tw: Tween = (b.visual as Node3D).create_tween()
		for i in 8:
			tw.tween_property(b.visual, "rotation:z", 0.06 if i % 2 == 0 else -0.06, 0.05)
		tw.tween_property(b.visual, "rotation:z", 0.0, 0.05)
		return
	Sfx.play("cue", b.global_position)
	var knob: Node3D = b.visual.find_child("P085_button_004", true, false)
	var stem: Node3D = b.visual.find_child("P085_button_stem_003", true, false)
	for n: Node3D in [knob, stem]:
		if n == null:
			continue
		var y := n.position.y
		var tw := n.create_tween()
		tw.tween_property(n, "position:y", y - 0.012, 0.05)
		tw.tween_property(n, "position:y", y, 0.12)


func _process(_delta: float) -> void:
	if game == null or _ropes == null:
		return
	var tubes: Array[Transform3D] = []
	var knots: Array[Transform3D] = []
	for id: int in rows:
		var row: Dictionary = rows[id]
		var pts := _path(row)
		knots.append(_dot(pts[0]))
		knots.append(_dot(pts[pts.size() - 1]))
		if bool(row["cut"]):
			_dangle(pts[0], float((row.get("drop", [0.5, 0.5]) as Array)[0]), tubes)
			_dangle(pts[pts.size() - 1], float((row.get("drop", [0.5, 0.5]) as Array)[1]), tubes)
		else:
			_sag(pts, float(row["len"]), tubes)
	# 結んでいる途中：結んだ端から、束を持った手まで
	for who: int in pending:
		var pl: Node = game.players.get(who)
		if pl == null or pl.held == 0 or not game.props.has(pl.held):
			continue
		var row: Dictionary = pending[who]
		var pts := PackedVector3Array([_end_at(row["a"])])
		for pid: int in row["via"]:
			pts.append(_wheel(pid))
		pts.append((game.props[pl.held] as RigidBody3D).center_global())
		knots.append(_dot(pts[0]))
		_sag(pts, _length(pts) * 1.04, tubes)
	_fill(_ropes, tubes)
	_fill(_knots, knots)
	var cables: Array[Transform3D] = []
	for bell: int in wires:
		var b := _prop(bell)
		for dev: int in wires[bell]:
			var d := _prop(dev)
			if b == null or d == null:
				continue
			var a: Vector3 = b.global_position + Vector3(0, 0.03, 0)
			var z: Vector3 = d.global_position + Vector3(0, 0.03, 0)
			_sag(PackedVector3Array([a, z]), a.distance_to(z) * 1.08, cables, minf(a.y, z.y) + 0.012)
	_fill(_cables, cables)
	_show_dials()
	_show_sparks()
	_show_flames()


func _dot(at: Vector3) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3(1.0, 0.05, 1.0)), at)


# ひもを、たるみ付きの折れ線にする（たるみは、区間の長さに比べて配る）。floor_y より下へは垂れない
func _sag(pts: PackedVector3Array, length: float, out: Array[Transform3D], floor_y: float = -INF) -> void:
	var span := _length(pts)
	var slack := maxf(0.0, length - span)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := a.distance_to(b)
		var extra := slack * d / maxf(span, 0.0001)
		var h := sqrt(3.0 * d * extra / 8.0)
		var steps := clampi(int(d / 0.12), 1, 24) if h > 0.01 else 1
		var prev := a
		for k in range(1, steps + 1):
			var t := float(k) / float(steps)
			var p := a.lerp(b, t) + Vector3.DOWN * (4.0 * h * t * (1.0 - t))
			p.y = maxf(p.y, floor_y)
			_seg(prev, p, out)
			prev = p


# 切れたひもの垂れ：結び目から真下へ。床に着いたら、その先は床に寝る
func _dangle(from: Vector3, length: float, out: Array[Transform3D]) -> void:
	if length < 0.05:
		return
	var floor_y := from.y - length
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.05, 0), from + Vector3(0, -length - 0.1, 0), Prop.L_WORLD | Prop.L_PROP)
	var world: World3D = get_viewport().find_world_3d() if get_viewport() != null else null
	var space: PhysicsDirectSpaceState3D = world.direct_space_state if world != null else null
	if space != null:
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			floor_y = (hit["position"] as Vector3).y + THICK
	var low := Vector3(from.x, maxf(floor_y, from.y - length), from.z)
	_seg(from, low, out)
	var rest := length - (from.y - low.y)
	if rest > 0.05:
		_seg(low, low + Vector3(rest * 0.7, 0, rest * 0.7), out)


func _seg(a: Vector3, b: Vector3, out: Array[Transform3D]) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var y := d / l
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	out.append(Transform3D(Basis(x, y * l, z), (a + b) * 0.5))


func _fill(mmi: MultiMeshInstance3D, list: Array[Transform3D]) -> void:
	var mm := mmi.multimesh
	var n := mini(list.size(), mm.instance_count)
	for i in n:
		mm.set_instance_transform(i, list[i])
	mm.visible_instance_count = n


# 目覚まし時計の赤い針：残りの秒数だけ、真上から時計回りに傾ける（1周＝WIND_MAX 秒）
func _show_dials() -> void:
	for p: RigidBody3D in parts:
		if p.kind != "timer":
			continue
		var hand: Node3D = p.visual.find_child("TimerHand", true, false)
		if hand != null:
			hand.rotation.z = -TAU * float(timers.get(p.pid, 0.0)) / WIND_MAX


# 燃えている所の火花（導火線と同じ形）
func _show_sparks() -> void:
	var want := {}
	for id: int in rows:
		var row: Dictionary = rows[id]
		if not bool(row["cut"]) and float(row["fire"]) >= 0.0:
			want[id] = _point_at(_path(row), float(row["fire"]))
	for id: int in _sparks.keys():
		if not want.has(id):
			(_sparks[id] as Node).queue_free()
			_sparks.erase(id)
	for id: int in want:
		if not _sparks.has(id):
			_sparks[id] = _spark()
		(_sparks[id] as Node3D).global_position = want[id]
		var light: OmniLight3D = (_sparks[id] as Node3D).get_child(1)
		light.light_energy = 2.4 + randf() * 1.6


func _spark() -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	var ember := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	ember.mesh = dot
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.45)
	ember.material_override = glow
	root.add_child(ember)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.25)
	light.omni_range = 3.2
	light.light_energy = 3.0
	root.add_child(light)
	var sparks := CPUParticles3D.new()
	sparks.amount = 18
	sparks.lifetime = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.2
	sparks.gravity = Vector3(0, -5.0, 0)
	var bit := SphereMesh.new()
	bit.radius = 0.016
	bit.height = 0.032
	bit.radial_segments = 4
	bit.rings = 2
	bit.material = glow
	sparks.mesh = bit
	root.add_child(sparks)
	return root


# トーチの炎（vfx/vfx_fire.gd）
func _show_flames() -> void:
	for pid: int in _fx.keys():
		if not flames.has(pid) or _prop(pid) == null:
			var fx: Node = _fx[pid]
			if is_instance_valid(fx):
				fx.extinguish()
			_fx.erase(pid)
	for pid: int in flames:
		var t := _prop(pid)
		if t == null:
			continue
		if not _fx.has(pid) or not is_instance_valid(_fx[pid]):
			_fx[pid] = VfxFire.spawn(self, t.global_transform * TORCH_HEAD, 0.32, -1.0)
		(_fx[pid] as Node3D).global_position = t.global_transform * TORCH_HEAD
