extends "res://vfx/vfx_base.gd"
# 水の斬撃（水の呼吸風）。水の糸が四方から一点に集まって構え、三度の振りで水の弧が走る。
# 素材：水。弧は薄い殻（wisp）を三層、濃い青 → 水色 → 白い芯の順に、同じ道筋へ重ねた帯。奥行きは縮めてある。
# どこから来る：四方から伸びる水の糸が、刃の起点（弧の左上）へ集まる。
# 先に動く部分：弧の頭。振りごとに弧の上を進み、先端は舌の形に欠ける。
# 遅れて追う部分：弧の尾。頭が進んだ後を、層ごとに違う遅れで追う。
# 形の変化（時刻）：
#   0.0〜0.7秒        糸が四方から起点へ集まり、中心へ縮む
#   振りごと s〜s+d   頭が弧の上を進む。尾は s+0.25d（芯）・s+0.3d（中）・s+0.4d（外）から追う
#   s+d〜s+d+0.6      外の層だけ、振りの向きへ少し伸びる（地面より上で止まる角度まで）
#   s+d+0.5〜s+d+1.4  外の層が細る（ほどける）。太い塊のまま千切れて小片にはしない
# 終わり（層ごとに行き先を変える）：
#   芯（白）    振りの終わりの直後、尾に追いつかれて消える
#   中（水色）  振りの終わりから少し後、尾に追いつかれて消える。水滴の出どころ
#   外（濃い青）進行方向へ流れて細り、尾に追いつかれて消える
#   水滴      弧の外へはじけ、速さに合わせて尾を引き、放物線で飛ぶ。地面に届くと消える
# 参考：『鬼滅の刃』水の呼吸（流れる水の弧で大きく斬る動き）。
# 周1の修正：二つ目の弧が地面の下を通っていたのを、地面より上になる位置と角度に直した。
#   外の層の伸びが地面に届いて平らな板に見えていたので、伸ばす角度を減らした。

const DROPS_PER_CUT := 6
const GRAVITY := 10.0     # 水滴の落下。弧の高さから数十センチの飛び方で地面に届かせ、空中に残さない
const THREADS := 4
const ARC_POINTS := 18
const ARC_SIDES := 14
const FLATTEN := 0.25     # 奥行き（z）を縮めて、弧を刃の厚みにする
const TAPER := -0.4       # 負の値で、頭（先）を尾より太くする
# [開始, 振りの長さ, 弧の中心の高さ, 半径, 始めの角度(度), 終わりの角度(度)]。どの弧も地面（y=0）より上を通す
const CUTS := [
	[0.7, 0.4, 2.0, 1.7, 150.0, -30.0],
	[1.45, 0.4, 1.2, 1.5, 15.0, 165.0],
	[2.3, 0.5, 1.8, 2.0, 170.0, 10.0],
]
# 層（外 → 芯）：[太さ(m), 濃い色, 内の色, cut, inner, 尾の遅れ(振りの長さ倍), 尾が追いつく秒数, 振りの先へ伸びる角度(度), 絵の大きさ, 先端の舌]
# 絵の大きさは、x（周り）を細かく・y（弧の上）を粗くして、弧に沿う筋にする（大きな塊にすると板に見える）
const LAYERS := [
	[0.50, Vector3(0.04, 0.22, 0.9), Vector3(0.12, 0.55, 1.5), 0.70, 0.70, 0.40, 0.80, 25.0, Vector2(1.8, 0.28), 0.2],
	[0.36, Vector3(0.18, 0.70, 2.0), Vector3(0.70, 2.20, 3.4), 0.60, 0.30, 0.30, 0.50, 0.0, Vector2(2.0, 0.35), 0.1],
	[0.18, Vector3(0.90, 2.20, 3.0), Vector3(3.00, 4.40, 4.8), 0.50, 0.14, 0.25, 0.25, 0.0, Vector2(2.4, 0.40), 0.0],
]

var _size := 1.0
var _arcs: Array = []         # [CUTS の一つ, 層の MeshInstance3D の配列]
var _threads: Array = []      # 構えの水の糸
var _drops: MultiMeshInstance3D
var _drop_data: Array = []    # [発射時刻, 発射位置, 初速]（陣の座標）
var _profile := PackedFloat32Array()   # 弧の太さの割合。両端を細らせ、開いた筒の端が平らな板に見えないようにする


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 5.4
	_profile = _ends(ARC_POINTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for ci in CUTS.size():
		var c: Array = CUTS[ci]
		var layers: Array = []
		for li in LAYERS.size():
			var layer: Array = LAYERS[li]
			var mi := Lib.wisp_layer(ArrayMesh.new(), li, LAYERS.size(), layer[1], layer[2], {
				"cut": layer[3], "inner": layer[4], "scale_a": layer[8], "shear": 1.0 if li == 0 else 0.8,
				"tip": layer[9], "top_thin": 0.2, "sway": 0.0, "ripple": 0.03, "seed": ci * 1.3 + li * 0.5,
			})
			mi.scale = Vector3(1.0, 1.0, FLATTEN)
			mi.custom_aabb = AABB(Vector3(-4, -1, -3), Vector3(8, 6, 6))
			add_child(mi)
			layers.append(mi)
		_arcs.append([c, layers])
	for i in THREADS:
		var th := Lib.wisp_layer(ArrayMesh.new(), 2, 3, Vector3(0.10, 0.50, 1.40), Vector3(0.60, 1.40, 2.20), {
			"tip": 0.0, "top_thin": 0.0, "sway": 0.0, "ripple": 0.03, "cut": 0.40, "inner": 0.30, "seed": 5.0 + i * 0.7,
		})
		th.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
		th.visible = false
		add_child(th)
		_threads.append(th)
	# 水滴：弧の頭が通った所から、弧の外へ飛ぶ。小さい球を速さに合わせて伸ばす
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.07
	drop_mesh.height = 0.14
	drop_mesh.radial_segments = 10
	drop_mesh.rings = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = DROPS_PER_CUT * CUTS.size()
	mm.mesh = drop_mesh
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.material_override = Lib.material("water_ball", {"noise_texture": Lib.noise("soft"), "wobble": 0.02})
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for c: Array in CUTS:
		for j in DROPS_PER_CUT:
			# 発射の位置は弧の上で無作為にする（等間隔だと、飛んだ水滴が弧の形の列になる）
			var u := rng.randf()
			var p := _arc_point(c, u)
			var a := deg_to_rad(lerpf(float(c[4]), float(c[5]), u))
			var outward := Vector3(cos(a), sin(a), 0.0)
			var tangent := Vector3(-sin(a), cos(a), 0.0) * signf(float(c[5]) - float(c[4]))
			# 向きと発射時刻をばらし、弧の形のまま一列に並ばないようにする
			var vel := tangent * rng.randf_range(0.3, 0.6) * size + outward * rng.randf_range(0.8, 1.8) * size + Vector3(rng.randf_range(-0.4, 0.4) * size, rng.randf_range(0.2, 1.0) * size, rng.randf_range(-0.6, 0.6) * size)
			_drop_data.append([float(c[0]) + float(c[1]) * u * 0.7 + rng.randf_range(0.0, 0.15), p, vel, rng.randf_range(0.6, 1.3)])
	_pose(0.0)


# 弧の上の一点（陣の座標）。u は 0（始め）〜 1（終わり）。u が 1 を超えると振りの先へ伸びる。bulge は外への膨らみ（m）
func _arc_point(c: Array, u: float, bulge: float = 0.0) -> Vector3:
	var a := deg_to_rad(lerpf(float(c[4]), float(c[5]), u))
	var r := (float(c[3]) + bulge) * _size
	return Vector3(cos(a) * r, float(c[2]) * _size + sin(a) * r, 0.0)


# 弧の太さの割合（n 点）。尾は点から太る（0 → 0.3 で全幅）、先端は 0.2 まで細る。頭側は TAPER のとおり太い
func _ends(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		var s := float(i) / (n - 1)
		out.append(smoothstep(0.0, 0.3, s) * (1.0 + 0.1 * s) * lerpf(1.0, 0.2, smoothstep(0.75, 1.0, s)))
	return out


# 層の窓 [尾, 頭, 外へのふくらみ(m), cut, 太さの倍率]。振りの終わりの後は外の層だけ、振りの先へ少し伸び、細っていく
func _window(c: Array, layer: Array, t: float) -> Array:
	var since := t - float(c[0])
	var dur := float(c[1])
	var sweep := absf(float(c[5]) - float(c[4]))
	var flow := float(layer[7])
	var out_k := ease_out(clampf((since - dur) / 0.6, 0.0, 1.0)) if flow > 0.0 else 0.0
	var head := ease_out(clampf(since / dur, 0.0, 1.0)) + flow * out_k / sweep
	var tail_raw := clampf((since - dur * float(layer[5])) / float(layer[6]), 0.0, 1.0)
	var unravel := smoothstep(dur + 0.5, dur + 1.4, since) if flow > 0.0 else 0.0
	var cut := lerpf(float(layer[3]), 0.9, unravel)
	var thin := lerpf(1.0, 0.45, unravel)
	return [head * tail_raw, head, 0.35 * out_k, cut, thin]


func _tick(_delta: float) -> void:
	_pose(age)


func _pose(t: float) -> void:
	_pose_threads(t)
	# 三度の振り：層ごとに窓を作り、弧の上の一部を筒にして描く
	for entry: Array in _arcs:
		var c: Array = entry[0]
		var layers: Array = entry[1]
		for li in layers.size():
			var mi: MeshInstance3D = layers[li]
			var layer: Array = LAYERS[li]
			var w := _window(c, layer, t)
			mi.visible = w[1] - w[0] > 0.01
			if not mi.visible:
				continue
			var pts := PackedVector3Array()
			for j in ARC_POINTS:
				pts.append(_arc_point(c, lerpf(w[0], w[1], float(j) / (ARC_POINTS - 1)), w[2]))
			mi.mesh = Lib.path_tube(pts, float(layer[0]) * _size * float(w[4]), TAPER, ARC_SIDES, _profile)
			param(mi, "phase", t)
			param(mi, "cut", w[3])
	# 水滴：速さに合わせて細長く伸ばし、地面に届いたら消す
	var mm := _drops.multimesh
	for i in _drop_data.size():
		var d: Array = _drop_data[i]
		var tau := t - float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0 and tau < 2.5:
			var vel: Vector3 = d[2]
			var p: Vector3 = (d[1] as Vector3) + vel * tau + Vector3(0.0, -0.5 * GRAVITY * _size * tau * tau, 0.0)
			var v := vel + Vector3(0.0, -GRAVITY * _size * tau, 0.0)
			if p.y > 0.05 and v.length() > 0.01:
				var dir := v.normalized()
				var up := Vector3.RIGHT if absf(dir.y) > 0.99 else Vector3.UP
				var stretch := 1.0 + 2.4 * minf(v.length() / (3.0 * _size), 1.0)
				xf = Transform3D(Basis.looking_at(dir, up).scaled(Vector3(0.9, 0.9, stretch) * _size * float(d[3])), p)
		mm.set_instance_transform(i, xf)


# 構え：糸が四方から、最初の刃の起点へ集まる。糸は根元が太く、起点へ細る
func _pose_threads(t: float) -> void:
	var start_point := _arc_point(CUTS[0], 0.0)
	var head := ease_out(clampf(t / 0.7, 0.0, 1.0))
	var tail := clampf((t - 0.1) / 0.6, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.7, 0.95, t)
	for i in _threads.size():
		var th: MeshInstance3D = _threads[i]
		th.visible = head > tail and fade > 0.02
		if not th.visible:
			continue
		var dir := Vector3(cos(i * PI * 0.5 + 0.6), sin(i * PI * 0.5 + 0.6), 0.0)
		var from := start_point + dir * 2.6 * _size
		var pts := PackedVector3Array()
		for k in 14:
			var u := lerpf(tail, head, float(k) / 13.0)
			pts.append(from.lerp(start_point, u) + Vector3(0.0, sin(u * PI) * 0.5 * _size, 0.0))
		th.mesh = Lib.path_tube(pts, 0.07 * _size * fade, 0.5, 10)
		param(th, "phase", t)
