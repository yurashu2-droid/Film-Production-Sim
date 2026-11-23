extends "res://vfx/vfx_base.gd"
# 念力（サイコキネシス）：手の届かない物を、念でつかんで動かしている間じゅう出す演出。
# 念力は「見えない力」なので、縄や棘のような物を足さず、力がかかった結果を見せる：
#   ・つかんだ物の輪郭そのものが、念の膜（オーラ）になって沸く／ゆらぐ。膜は穴のない1枚の面（物の後ろにある）
#   ・念波：手から物へ向けて弧「）））」が飛び立ち、途中で細って切れる。届いた頃に、物の輪郭から波紋が外へ広がる
#   ・物のまわりの景色が、波紋に押されてゆがむ
#   ・手と物に、同じ質感の膜が同じ拍で出る（だれが何を持っているかが分かる）
# 参考：『モブサイコ100』の念動力（輪郭に沿ってギザギザに沸く色のオーラ）、アニメ『ポケットモンスター』のサイコキネシス
#       （対象が同じ色の光に包まれる）、漫画の念波の描き方（弧が相手へ飛ぶ）、『AKIRA』『CONTROL』（空間のゆがみで力を見せる）。
# 普段使いの決まり：物そのものは隠さない（膜は物の後ろに描く。輪郭の外にはみ出す部分だけ、壁や床に隠れないよう手前の奥行きで比べる）。止めている間は細く静かに・拍もゆっくり、動かした時だけ大きく速く。
#                 手で直接持てる近さでは出さない。光らせすぎない（淡い塗り。加算ではない）。
#
# 素材：        念（見えない力）。見えるのは、力が触れている輪郭と、伝わる波だけ
# どこから来る： 手から。弧になって物へ飛び、物を包む膜になる
# 先に動く部分： 最初の弧（手 → 物。0.14 秒）
# 遅れて追う部分：膜（つかんだ点から物の反対側へ包んでいく）／波紋（弧が届くたびに遅れて広がる）／
#                動かした時の膜（動く向きの後ろ側が、遅れて長く伸びる）
# 形の変化：     0.00 手のまわりに膜が弾け、最初の弧が物へ飛ぶ
#                0.14 弧が届き、つかんだ点から膜が物を包んでいく。最初の波紋が広がる（0.44 で包み終わる）
#                保持：ゆっくりした拍で弧が飛び、届くたびに波紋が出る。膜のふちは沸き続ける。動かすと拍が速まり、膜が後ろへなびく
#                近づける：手が物に届く近さになると、全部が薄れて消える（手で持っているだけになる）
# 終わり（release。手へは戻さない）：
#   手の膜   … 供給が止まり、手首の側から抜ける。最後の小さな波紋が1つ出る
#   飛んでいる弧 … そのまま進んで細って切れ、届いた頃に最後の波紋になる（手へは戻らない）
#   物の膜   … つかんだ点の側から反対側へ抜ける（0.06〜0.3 秒）
#   波紋     … 最後の1本が、いつもより遠くまで広がる。進むほど細り、途中で弧に切れて消える（0.1〜0.65 秒）
#
# 見た目の型（STYLES）：mix 掛け合わせ ／ nenpa 念波（静か）／ yuragi ゆらぎ。膜は、いちばん外のふちより内側を全部塗る（穴を開けない）

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const FPS := 12.0                 # ギザギザを描き替える速さ（コマ打ち）。波・ゆらぎ・物への追従は毎フレーム
const GROW := 0.14                # 最初の弧が手から物へ届くまで（秒）
const WRAP := 0.3                 # 膜が物を包み終わるまで（弧が届いてから。秒）
const TINT := Color(0.5, 0.3, 1.0)    # 色を渡さなかった時の念の色（紫）
const NEAR := 0.25                # 手から物までがこの近さ（m）なら出さない
const FAR := 0.7                  # この遠さ（m）で、いつもの濃さになる
const RING_SEC := 0.75            # 波紋1本の寿命
const WAVE_GAP := 0.16             # 念波の弧どうしの遅れ（届くまでの時間に対する割合）
const WAVE_SHOWN := 0.55           # 念波の弧が見えている区間（道のりに対する割合。その先は見えないまま進む）
const OUTLINE_META := &"psychic_outline"
const DIRS := 14                  # 外形を測る向きの数（軸6＋斜め8）

# aura  ：膜。[いつもの太さm, 沸いて伸びる長さm, ギザギザ(1)〜ゆらゆら(0), ギザギザの数/m, 上を長くする割合, 色ずれm, もやの濃さ, 波紋の濃さ, 波紋の届く距離m, ゆがみ]
# pulse ：手から飛ぶ弧。[太さm, ギザギザ(1)か なめらか(0)か, 止めている時の間隔(秒), 動かしている時の間隔(秒)]
# thread：手と物をつなぐ薄いもやの筋。[太さm, 濃さ]。空なら出さない
const STYLES := {
	"nenpa": {
		"aura": [0.012, 0.03, 0.0, 9.0, 0.3, 0.0, 0.0, 1.0, 0.4, 0.7],
		"pulse": [0.03, 0.0, 1.0, 0.36], "thread": [],
	},
	"yuragi": {
		"aura": [0.016, 0.075, 0.0, 9.0, 0.9, 0.008, 0.55, 0.5, 0.36, 1.2],
		"pulse": [0.045, 0.0, 1.2, 0.45], "thread": [0.3, 0.3],
	},
	"mix": {
		"aura": [0.018, 0.075, 0.55, 10.0, 0.6, 0.011, 0.25, 0.9, 0.36, 0.55],
		"pulse": [0.032, 0.5, 1.0, 0.34], "thread": [],
	},
}

var target: Node3D                # つかんでいる物
var _style: Dictionary = STYLES["mix"]
var _layers := 1
var _tint := Vector3(0.5, 0.3, 1.0)
var _center_local := Vector3.ZERO     # 物の外形の箱（物のローカル）
var _half := Vector3.ONE * 0.3
var _size := 1.0                      # 物の大きさに合わせた倍率
var _aura: MeshInstance3D             # 物の膜
var _hand_auras: Array[MeshInstance3D] = []
var _thread: MeshInstance3D
var _pulses: Array = []               # 飛んでいる念波：[弧の帯3本, 生まれた時刻, 届くまでの秒, 向き, 開き, 回る速さ, 波紋を出したか]
var _rings: Array[float] = [-9.0, -9.0, -9.0]     # 物の波紋が生まれた時刻（3本まで）
var _hand_rings: Array[float] = [-9.0, -9.0, -9.0]
var _next_ring := 0
var _next_pulse := 0.0
var _hands := PackedVector3Array()
var _grip := Vector3.ZERO
var _fed := false
var _mid := Vector3.ZERO              # 弧の通り道の腹（ばねで遅れて追う）
var _mid_v := Vector3.ZERO
var _prev_center := Vector3.ZERO
var _prev_turn := Quaternion.IDENTITY
var _drift := Vector3.ZERO            # 物の動き（なめらかにした速さ）
var _started := false
var _activity := 0.0                  # どれだけ動かしているか（0〜1）
var _reach := 1.0                     # 手から遠いか（0＝手で持てる近さ、1＝遠い）
var _boil := 0.0
var _spark := 0.0
var _released := -1.0                 # 離した時刻（負＝つかんでいる）
var _rng := RandomNumberGenerator.new()


# prop の見た目（その下の MeshInstance3D）に念力をまとわせる。毎コマ hold() で手とつかんだ点を渡し、離したら release()。
# opts：style（STYLES の名前）／tint（Color。念の色）／layers（描画の層。制作班だけに見せるなら 1 << 11）／
#       center・half（物の外形の箱。物のローカル。省くとメッシュから測る）
static func attach(parent: Node, prop: Node3D, opts: Dictionary = {}) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.start(prop, opts)
	return fx


func start(prop: Node3D, opts: Dictionary) -> void:
	life = 0.0
	target = prop
	process_priority = 50             # 手（骨）と物が動いた後に追う
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_style = STYLES.get(opts.get("style", "mix"), STYLES["mix"])
	_layers = int(opts.get("layers", 1))
	var tint: Color = opts.get("tint", TINT)
	var top := maxf(maxf(tint.r, tint.g), maxf(tint.b, 0.001))
	_tint = Vector3(tint.r, tint.g, tint.b) / top
	_rng.seed = hash(prop.get_instance_id())
	var sources: Array = []
	_collect(prop, sources)
	var outline := _outline_points(sources)
	if opts.has("center") and opts.has("half"):
		_center_local = opts["center"]
		_half = opts["half"]
	else:
		_measure(sources)
	_size = clampf((prop.global_basis * _half).length() / 0.45, 0.6, 1.5)
	_aura = _build_aura(outline, false)
	for i in 2:
		_hand_auras.append(_build_aura(PackedVector3Array([Vector3.ZERO]), true))
	_build_thread()


# 毎コマ呼ぶ：手の場所（1つか2つ）と、物をつかんだ点（どちらもワールド座標）
func hold(hands: PackedVector3Array, grip: Vector3) -> void:
	if hands.is_empty():
		return
	_hands = hands
	_grip = grip
	_fed = true


# 離す：供給を止める。飛んでいる弧が物へ届き、最後の波紋が広がり切ってから、自分で片付く
func release() -> void:
	if _released < 0.0:
		_released = age


func holding() -> bool:
	return _released < 0.0


func _collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).visible:
			continue
		# ふつうの層（1）に見えている物だけ。制作班だけに見せる札などには付けない
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null and ((child as MeshInstance3D).layers & 1) != 0:
			out.append(child)
		_collect(child, out)


func _measure(sources: Array) -> void:
	if sources.is_empty():
		return
	var to_local := target.global_transform.affine_inverse()
	var box := AABB()
	for i in sources.size():
		var src: MeshInstance3D = sources[i]
		var part: AABB = (to_local * src.global_transform) * src.get_aabb()
		box = part if i == 0 else box.merge(part)
	_center_local = box.get_center()
	_half = box.size * 0.5


static func _dir(i: int) -> Vector3:
	if i < 6:
		var axis := Vector3.ZERO
		axis[i / 2] = 1.0 if i % 2 == 0 else -1.0
		return axis
	var c := i - 6
	return Vector3(1.0 if c & 1 else -1.0, 1.0 if c & 2 else -1.0, 1.0 if c & 4 else -1.0).normalized()


# メッシュの外形を表す点：14 の向きそれぞれで、いちばん外にある頂点（メッシュのローカル）。メッシュごとに一度だけ測る
static func _mesh_extremes(mesh: Mesh) -> PackedVector3Array:
	# 測った結果は、メッシュ自身に覚えさせる（static 変数に持つと、終了時に「使用中の資源」の警告が増える）
	if mesh.has_meta(OUTLINE_META):
		return mesh.get_meta(OUTLINE_META)
	var best := PackedVector3Array()
	var far := PackedFloat32Array()
	best.resize(DIRS)
	far.resize(DIRS)
	far.fill(-INF)
	var dirs: Array[Vector3] = []
	for d in DIRS:
		dirs.append(_dir(d))
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# 細かいメッシュは頂点を間引いて調べる（つかんだ瞬間に止まらないように）
		var stride := maxi(1, verts.size() / 1200)
		for i in range(0, verts.size(), stride):
			var v := verts[i]
			for d in DIRS:
				var along := v.dot(dirs[d])
				if along > far[d]:
					far[d] = along
					best[d] = v
	if far[0] == -INF:
		best = PackedVector3Array()
	mesh.set_meta(OUTLINE_META, best)
	return best


# 物の外形を表す点（物のローカル。16 個まで）。部品ごとの点を合わせて、もう一度いちばん外の点を選ぶ
func _outline_points(sources: Array) -> PackedVector3Array:
	var to_local := target.global_transform.affine_inverse()
	var all := PackedVector3Array()
	for src: MeshInstance3D in sources:
		var part: Transform3D = to_local * src.global_transform
		for p: Vector3 in _mesh_extremes(src.mesh):
			all.append(part * p)
	var out := PackedVector3Array()
	if all.is_empty():
		return out
	for d in DIRS:
		var dir := _dir(d)
		var pick := all[0]
		for p: Vector3 in all:
			if p.dot(dir) > pick.dot(dir):
				pick = p
		if not out.has(pick):
			out.append(pick)
	return out


# 膜の板を1枚作る。outline＝外形を表す点。hand＝手のまわりの小さな膜か
func _build_aura(outline: PackedVector3Array, hand: bool) -> MeshInstance3D:
	var a: Array = _style["aura"]
	var pts := PackedVector3Array()
	pts.resize(16)
	for i in 16:
		pts[i] = outline[mini(i, outline.size() - 1)] if not outline.is_empty() else Vector3.ZERO
	var k := 0.5 if hand else _size
	var m: ShaderMaterial = Lib.material("psychic_aura", {
		"noise_tex": Lib.noise("soft"), "pts": pts, "pt_count": clampi(outline.size(), 1, 16),
		"pad": 0.055 if hand else 0.0, "band": float(a[0]) * (0.7 if hand else 1.0), "amp": float(a[1]) * k,
		"jag": a[2], "teeth": float(a[3]) * (2.2 if hand else 1.0 / _size), "rise": a[4], "split": float(a[5]) * (0.6 if hand else 1.0),
		"haze": a[6], "haze_reach": 0.26 * k, "ring_gain": a[7], "ring_reach": float(a[8]) * (0.4 if hand else _size),
		"ring_width": 0.014 * (0.7 if hand else 1.0), "warp": a[9],
		"color": _shade(0.0, 0.95), "color_core": _shade(0.6, 1.25), "opacity": 0.0,
		"color_a": Vector3(1.0, 0.35, 0.8), "color_b": Vector3(0.3, 0.85, 1.0),
	})
	m.render_priority = 0 if hand else 1
	var quad := MeshInstance3D.new()
	quad.mesh = Lib.quad()
	quad.material_override = m
	quad.layers = _layers
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.top_level = true
	quad.custom_aabb = AABB(Vector3.ONE * -3.0, Vector3.ONE * 6.0)
	quad.visible = false
	add_child(quad)
	return quad


func _build_thread() -> void:
	var row: Array = _style["thread"]
	if row.is_empty():
		return
	_thread = Ribbon.new()
	var m: ShaderMaterial = Lib.material("psychic_thread", {
		"noise_tex": Lib.noise("soft"), "seed": _rng.randf(), "width": row[0], "soft": 1.0,
		"color": _shade(0.1, 0.95), "opacity": 0.0, "head": 0.0, "near_fade": 1.0,
	})
	m.render_priority = 3
	_thread.material_override = m
	_thread.layers = _layers
	add_child(_thread)


# 念の色：white で白へ寄せ、bright で明るさを決める
func _shade(white: float, bright: float) -> Vector3:
	return _tint.lerp(Vector3.ONE, white) * bright


func _tick(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		queue_free()
		return
	var xf := target.get_global_transform_interpolated()
	var center := xf * _center_local
	if not _fed:
		_hands = PackedVector3Array([center + Vector3(0, -0.2, 1.2)])
		_grip = center
	var hand := Vector3.ZERO
	for h: Vector3 in _hands:
		hand += h / _hands.size()
	var turn := Quaternion(xf.basis.orthonormalized())
	if not _started or center.distance_to(_prev_center) > 6.0:
		# 出した直後と、物が別の場所へ置き直された時：遅れの計算をやり直す
		_started = true
		_prev_center = center
		_prev_turn = turn
		_mid = _rest_mid(hand, center)
		_mid_v = Vector3.ZERO
		_drift = Vector3.ZERO
	var step := maxf(delta, 0.0001)
	var velocity := (center - _prev_center) / step
	var want := clampf(velocity.length() / 2.2 + _prev_turn.angle_to(turn) / step / 3.5, 0.0, 1.0)
	_activity = move_toward(_activity, want, delta * (9.0 if want > _activity else 1.6))
	# 膜のなびきは、動きより少し遅れて追い、止まると遅れて戻る
	_drift = _drift.lerp(velocity, clampf(delta * 7.0, 0.0, 1.0))
	_prev_center = center
	_prev_turn = turn
	_reach = smoothstep(NEAR, FAR, _gap(xf, hand))
	_boil += delta * lerpf(0.35, 0.9, _activity)
	_spark += delta * FPS * lerpf(0.6, 1.0, _activity)
	var gone := age - _released if _released >= 0.0 else -1.0
	var radius := (xf.basis * _half).length()
	_send_pulses(hand, center, radius, delta, gone)
	_place_object(xf, center, radius, gone)
	_place_hands(gone)
	_place_thread(hand, center, gone)
	if gone >= 0.35 and _pulses.is_empty() and age - float(_rings.max()) > RING_SEC:
		queue_free()


# 手から、物の外形の箱までの距離（m）
func _gap(xf: Transform3D, hand: Vector3) -> float:
	var local := xf.affine_inverse() * hand - _center_local
	var out := (local.abs() - _half).max(Vector3.ZERO)
	return (xf.basis * out).length()


func _rest_mid(hand: Vector3, to: Vector3) -> Vector3:
	# 通り道の腹は少し上へ浮く（定規で引いた直線にしない）
	return (hand + to) * 0.5 + Vector3.UP * hand.distance_to(to) * 0.06


func _ring(list: Array[float]) -> void:
	list[_next_ring % 3] = age
	_next_ring += 1


func _ring_progress(list: Array[float], seconds: float) -> Vector3:
	return Vector3((age - list[0]) / seconds, (age - list[1]) / seconds, (age - list[2]) / seconds)


# 念波：手から物へ飛ぶ弧。止めている間はゆっくり、動かすと間隔が詰まる。届いたら、物の輪郭から波紋が出る
func _send_pulses(hand: Vector3, center: Vector3, radius: float, delta: float, gone: float) -> void:
	var row: Array = _style["pulse"]
	# 通り道の腹は、ばねで遅れて追う：物を振ると遅れてたわみ、少し揺れ戻す
	var length := hand.distance_to(center)
	var rest := _rest_mid(hand, center)
	_mid_v += ((rest - _mid) * 70.0 - _mid_v * 9.0) * delta
	_mid += _mid_v * delta
	var lag := _mid - rest
	if lag.length() > length * 0.45:
		_mid = rest + lag.normalized() * length * 0.45
	if gone < 0.0 and age >= _next_pulse and _reach > 0.3:
		var first := _next_pulse <= 0.0
		_next_pulse = age + lerpf(float(row[2]), float(row[3]), _activity) * _rng.randf_range(0.85, 1.15)
		var arcs: Array = []
		for n in 3:
			var r: MeshInstance3D = Ribbon.new()
			var m: ShaderMaterial = Lib.material("psychic_thread", {
				"noise_tex": Lib.noise("soft"), "seed": _rng.randf(), "width": float(row[0]) * (1.0 - n * 0.2), "cut": 0.15, "stretch": 0.5,
				"color": _shade(0.15, 1.0), "color_core": _shade(0.7, 1.3), "opacity": 0.0, "head": 0.0, "near_fade": 1.0,
			})
			m.render_priority = 4
			r.material_override = m
			r.layers = _layers
			add_child(r)
			arcs.append(r)
		# 最初の1本は速く届く。あとは距離に応じた速さで飛ぶ
		var seconds := GROW if first else clampf(length / 7.0, 0.22, 0.5)
		_pulses.append([arcs, age, seconds, _rng.randf() * TAU, _rng.randf_range(3.4, 4.5), _rng.randf_range(-2.0, 2.0), false])
		_ring(_hand_rings)
	# 物の手前の面へ届く（物の前を横切らない）
	var goal := center - (center - hand).normalized() * minf(radius * 0.7, length * 0.4)
	var ctrl := 2.0 * _mid - (hand + center) * 0.5
	var i := 0
	while i < _pulses.size():
		var p: Array = _pulses[i]
		if gone >= 0.0:
			# 離した後：飛んでいる分は、倍の速さで物へ届く（余韻を長引かせない）
			p[1] = float(p[1]) - delta
		var lead: float = (age - float(p[1])) / float(p[2])
		if lead >= 1.0 and not p[6]:
			# 先頭の弧が届いた：物の輪郭から波紋が出る
			p[6] = true
			_ring(_rings)
		if lead >= 1.0 + WAVE_GAP * 2.0:
			for arc: Node in p[0]:
				arc.queue_free()
			_pulses.remove_at(i)
			continue
		i += 1
		for n in 3:
			# 弧の列「）））」：後ろの弧ほど小さく、遅れて同じ道を飛ぶ
			var arc: MeshInstance3D = p[0][n]
			var k := lead - n * WAVE_GAP
			# 弧が見えるのは、道のりの前半だけ。進むほど細り、切れて消える（物の手前を線が横切らない）。
			# 波そのものは見えないまま進み、届いた時に物の輪郭の波紋になる
			arc.visible = k > 0.0 and k < WAVE_SHOWN and _reach > 0.05
			if not arc.visible:
				continue
			var e := pow(k, 0.85)
			var at := hand.lerp(ctrl, e).lerp(ctrl.lerp(goal, e), e)
			var ahead := (hand.lerp(ctrl, e + 0.02).lerp(ctrl.lerp(goal, e + 0.02), e + 0.02) - at).normalized()
			var side := ahead.cross(Vector3.UP)
			side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
			var lift := side.cross(ahead)
			# 手の大きさで生まれ、手から離れた分だけ広がる（手を頂点にして物を包む円すいの上）
			var wide := maxf(0.07, minf(radius, 0.7) * 1.15 * e)
			var spent := k / WAVE_SHOWN
			var from: float = float(p[3]) + float(p[5]) * (age - float(p[1])) + n * 0.5
			var points := PackedVector3Array()
			for j in 15:
				var a := from + float(p[4]) * j / 14.0
				var r := wide * (1.0 + float(row[1]) * 0.2 * (1.0 if j % 2 == 0 else -1.0))
				# 弧は、進む向きの後ろへ少し反る（皿の形）
				points.append(at + (side * cos(a) + lift * sin(a)) * r - ahead * wide * 0.3 * sin(PI * j / 14.0))
			arc.draw(points)
			param(arc, "head", clampf(k / 0.1, 0.0, 1.0))
			param(arc, "width", float(row[0]) * (1.0 - n * 0.2) * (1.0 - 0.75 * spent))
			param(arc, "cut", lerpf(0.15, 0.62, spent * spent))
			param(arc, "opacity", 0.9 * _reach)
			param(arc, "phase", age * 0.8)


# 物の膜
func _place_object(xf: Transform3D, center: Vector3, radius: float, gone: float) -> void:
	var a: Array = _style["aura"]
	# 板の余白：遠くの物は帯と波紋を太く描く（シェーダー側。2.2 倍まで）ので、その分まで取る
	var reach_m := (float(a[1]) * _size * 2.6 + float(a[8]) * _size) * 2.2 + 0.15
	var gain := _reach * lerpf(0.75, 1.0, _activity)
	# 包む：つかんだ点から外へ。抜ける：つかんだ点の側から外へ
	var span := radius * 2.0 + reach_m + 0.3
	var reveal := lerpf(0.0, span, ease_out(clampf((age - GROW) / WRAP, 0.0, 1.0)))
	var drain := lerpf(-0.3, span, clampf((gone - 0.06) / 0.24, 0.0, 1.0)) if gone >= 0.0 else -1.0
	_aura.visible = _reach > 0.01 and age >= GROW
	_aura.global_position = center
	var m := _aura.material_override as ShaderMaterial
	m.set_shader_parameter("body", xf)
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("extent", radius + reach_m)
	m.set_shader_parameter("back", radius + 0.05)
	# 輪郭の外にはみ出す部分は、物の手前側の奥行きで比べる：壁や床にくっつけても隠れない（手のオーラは、手を隠さないよう後ろのまま）
	m.set_shader_parameter("front", radius)
	m.set_shader_parameter("grip", _grip)
	m.set_shader_parameter("reveal", reveal)
	m.set_shader_parameter("drain", drain)
	m.set_shader_parameter("opacity", 0.92 * gain)
	m.set_shader_parameter("amp", float(a[1]) * _size * lerpf(0.75, 1.5, _activity))
	m.set_shader_parameter("frame", _spark)
	m.set_shader_parameter("boil", _boil)
	m.set_shader_parameter("trail_world", _drift.limit_length(3.0) / 3.0)
	m.set_shader_parameter("rings", _ring_progress(_rings, RING_SEC))


# 手の膜：物と同じ質感を、小さく
func _place_hands(gone: float) -> void:
	for i in _hand_auras.size():
		var quad := _hand_auras[i]
		quad.visible = i < _hands.size() and _reach > 0.05
		if not quad.visible:
			continue
		var at := _hands[i]
		quad.global_position = at
		var m := quad.material_override as ShaderMaterial
		m.set_shader_parameter("body", Transform3D(Basis.IDENTITY, at))
		m.set_shader_parameter("center", at)
		m.set_shader_parameter("extent", 0.6)
		m.set_shader_parameter("back", 0.1)
		# 手首の側（体の側）から抜ける
		m.set_shader_parameter("grip", at + (at - _grip).normalized() * 0.12)
		m.set_shader_parameter("reveal", lerpf(0.0, 0.6, ease_out(clampf(age / 0.12, 0.0, 1.0))))
		m.set_shader_parameter("drain", lerpf(-0.3, 0.6, clampf(gone / 0.18, 0.0, 1.0)) if gone >= 0.0 else -1.0)
		m.set_shader_parameter("opacity", 0.92 * _reach * lerpf(0.8, 1.0, _activity))
		m.set_shader_parameter("frame", _spark + i * 3.0)
		m.set_shader_parameter("boil", _boil + i * 0.37)
		m.set_shader_parameter("rings", _ring_progress(_hand_rings, 0.4))


# 手と物をつなぐ、薄いもやの筋（型による。供給が止まると、手の側から物へ流れ切る）
func _place_thread(hand: Vector3, center: Vector3, gone: float) -> void:
	if _thread == null:
		return
	var tail := clampf(gone / 0.2, 0.0, 1.0) if gone >= 0.0 else 0.0
	_thread.visible = _reach > 0.01 and tail < 1.0
	if not _thread.visible:
		return
	var row: Array = _style["thread"]
	var ctrl := 2.0 * _mid - (hand + center) * 0.5
	var points := PackedVector3Array()
	for p in 16:
		var k := float(p) / 15.0
		points.append(hand.lerp(ctrl, k).lerp(ctrl.lerp(center, k), k))
	_thread.draw(points)
	var m := _thread.material_override as ShaderMaterial
	m.set_shader_parameter("head", clampf(age / GROW, 0.0, 1.0))
	m.set_shader_parameter("tail", tail)
	m.set_shader_parameter("phase", age * lerpf(0.35, 1.0, _activity))
	m.set_shader_parameter("stretch", maxf(hand.distance_to(center) * 0.3, 0.2))
	m.set_shader_parameter("cut", lerpf(0.42, 0.3, _activity))
	m.set_shader_parameter("opacity", float(row[1]) * _reach * lerpf(0.7, 1.0, _activity))
