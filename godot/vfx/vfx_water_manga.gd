extends "res://vfx/vfx_base.gd"
# 漫画の水しぶき。上から大きなしずくが落ち、地面で弾けて、水の舌が外へ立ち上がり、倒れ、地面へ戻る。
# 体はすべて水の殻（wisp）を3層重ねる。外は暗く・すき間が多く、内へ明るく、芯は白く詰まっている。
# 白い塊と黒い輪郭は使わない。集中線は残す（本数 10）。
#
# 素材：水（しずくと水の舌。wisp の殻を3層）
# どこから来る：上から落ちる一粒。舌は着地点（中心）から外へ伸びる
# 先に動く部分：しずくの頭。舌は先端が根元より先に外へ進む
# 遅れて追う部分：しずくの尾、舌の根元、白い粒
# 形の変化（着地からの時刻）
#   0〜0.35秒   舌が根元から立ち上がる（中心線の高さが 0 → 最大）
#   0〜0.9秒    舌の先端が外へ伸び、根元は 0.3 秒遅れて続く
#   0.8〜1.3秒  舌が外へ倒れ、高さが下がる
# 終わり（層ごとに別の消え方。時刻もずらす）
#   外（暗い青）  先端から根元へ後退して、地面へ戻る（1.0〜1.5秒）
#   中（明るい青）根元の位置のまま細って消える（1.1〜1.7秒）
#   芯（白）      根元側から抜けて、先端の一点が地面に残って消える（1.2〜1.9秒）
# しずく：落下中は縦に伸び、尾が後ろに引く。着地で消える（0〜0.72秒）
# 白い粒：放物線で飛び、地面へ落ちる（0.72〜2.7秒）
# 集中線：着地の直後に一本ずつ出て、内側から別々の時刻に消える（〜2.4秒）
# 水たまりの波紋：3.4秒まで。段ごとに消える
# 参考：少年漫画の水しぶき（衝撃の瞬間に飛沫が立ち、集中線で衝撃を見せる）。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const T0 := 0.72               # 着地の時刻
const TONGUES := 6             # 水の舌（6〜8本）
const LINES := 10              # 集中線
const DROPS := 14              # 白い粒
const GRAVITY := 7.0
const CTRL := 7                # 舌の中心線の制御点の数
const SIDES := 14
# 水の殻 3 層。[濃い色, 明るい色, cut, inner]。外（暗く、すき間が多い）→ 芯（白く詰まっている）
const LAYERS := [
	[Vector3(0.04, 0.22, 0.9), Vector3(0.12, 0.55, 1.5), 0.80, 0.50],
	[Vector3(0.18, 0.70, 2.0), Vector3(0.70, 2.20, 3.4), 0.66, 0.30],
	[Vector3(0.90, 2.20, 3.0), Vector3(3.00, 4.40, 4.8), 0.50, 0.14],
]
const LAYER_RADIUS := [1.0, 0.65, 0.3]                         # 内の層ほど細い
const LAYER_MODE := ["tip", "thin", "tip"]                     # 層ごとの終わり方（下の _tongue_pts を見る）
const LAYER_WINDOW := [[1.0, 1.5], [1.1, 1.7], [1.2, 1.9]]     # 着地からの時刻
const TONGUE_RADIUS := 0.9     # 外の層の半径（m）。細いと刃に見えた（PLAYBOOK 1章）
const TONGUE_Y := 0.1
const FALL_MIN := 0.6          # しずくが止まる高さ（地面すれすれ）

var _size := 1.0
var _drop_heads: Array = []    # 層ごとのしずくの頭（球）
var _drop_tails: Array = []    # 層ごとのしずくの尾（筒）
var _tongues: Array = []       # [向き(XZ), 高さ, 長さ, 遅れ, [層ごとの MeshInstance3D]]
var _lines: Array = []         # [リボン, 角度, 遅れ]
var _drops: MultiMeshInstance3D
var _drop_data: Array = []     # [発射時刻, 初速]
var _ring: MeshInstance3D
var _light: OmniLight3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 4.8
	# しずく：球の頭と、後ろに引く尾。どちらも水の殻を3層
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 1.0
	head_mesh.height = 2.0
	head_mesh.radial_segments = 20
	head_mesh.rings = 10
	for l in LAYERS.size():
		var head := _layer(head_mesh, l, {"tip": 0.0, "top_thin": 0.0, "sway": 0.0, "ripple": 0.03})
		add_child(head)
		_drop_heads.append(head)
		var tail := _layer(ArrayMesh.new(), l, {"tip": 0.2, "top_thin": 0.4, "sway": 0.0, "ripple": 0.05})
		add_child(tail)
		_drop_tails.append(tail)
	# 水の舌：着地点から外へ、放射状に。層ごとに別の筒
	for j in TONGUES:
		var a := TAU * float(j) / TONGUES + randf_range(-0.2, 0.2)
		var mis: Array = []
		for l in LAYERS.size():
			# 太い筒は模様が粗くなり、べた塗りに見える。周方向を細かくして、斜めの筋で穴を作る
			var mi := _layer(ArrayMesh.new(), l, {"tip": 0.2, "top_thin": 0.3, "sway": 0.0, "ripple": 0.05, "seed": l * 0.37 + j * 0.91, "scale_a": Vector2(1.1, 0.35), "shear": 1.0})
			add_child(mi)
			mis.append(mi)
		_tongues.append([Vector3(cos(a), 0.0, sin(a)), randf_range(0.5, 0.9), randf_range(1.4, 2.0), randf_range(0.0, 0.12), mis])
	# 集中線：飛沫の中心から放射状に、画面に向く平面で
	for k in LINES:
		var r: MeshInstance3D = Ribbon.new()
		r.material_override = Lib.material("stroke", {"width": randf_range(0.04, 0.1) * size, "color": Color(1.05, 1.1, 1.15, 0.9)})
		add_child(r)
		# [リボン, 角度, 遅れ, 長さの最大（m）, 曲がり（m）]。長さと曲がりは1本ずつ違えて、棒に見せない
		_lines.append([r, TAU * float(k) / LINES + randf() * 0.2, randf_range(0.0, 0.3), randf_range(1.0, 2.0), randf_range(-0.35, 0.35)])
	# 白い粒（直径 0.16m 以下の単純な球）
	var dm := SphereMesh.new()
	dm.radius = 0.08
	dm.height = 0.16
	dm.radial_segments = 8
	dm.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = DROPS
	mm.mesh = dm
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.material_override = Lib.material("water_ball", {"noise_texture": Lib.noise("soft"), "body": Vector3(0.9, 0.97, 1.0), "deep": Vector3(0.5, 0.6, 0.7), "rim": Vector3(1.0, 1.0, 1.0)})
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in DROPS:
		var a := randf() * TAU
		_drop_data.append([randf() * 0.25, Vector3(cos(a) * randf_range(0.8, 2.0) * size, randf_range(2.0, 4.0) * size, sin(a) * 0.3 * size)])
	# 水たまりの波紋
	_ring = MeshInstance3D.new()
	_ring.mesh = Lib.quad()
	_ring.material_override = Lib.material("stamp", {"shape": Lib.noise("soft"), "cut": 0.4, "core_cut": 0.7,
		"color": Color(0.35, 0.7, 1.2, 1.0), "core_color": Color(0.8, 1.2, 1.6, 1.0), "reveal": 0.0})
	_ring.rotation.x = -PI / 2.0
	_ring.position.y = 0.02
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_light = lamp(Color(0.7, 0.9, 1.0), 8.0 * size)
	_light.position.y = 1.0 * size
	_pose(0.0)


# 水の殻を1層作る。色と cut は層の番号から、呼ぶ側の指定（extra）が優先する。
# 呼び出し後、子の範囲を上下に広く取る（既定の範囲だと、高い所のしずくが描かれない）。
func _layer(mesh: Mesh, l: int, extra: Dictionary) -> MeshInstance3D:
	var cfg: Array = LAYERS[l]
	var params := {"cut": cfg[2], "inner": cfg[3], "seed": l * 0.37 + 0.2}
	params.merge(extra, true)
	var mi := Lib.wisp_layer(mesh, l, LAYERS.size(), cfg[0], cfg[1], params)
	mi.custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 8.0, 8.0))
	return mi


func _tick(_delta: float) -> void:
	_pose(age)


func _pose(t: float) -> void:
	var since := t - T0
	# しずく：重く落ちて、縦に伸びる。着地で消える
	var falling := t < T0
	var speed := 18.0 * t
	var fall := maxf(FALL_MIN * _size, 5.0 * _size - 0.5 * 18.0 * _size * t * t) if falling else 0.0
	var head_pos := Vector3(0.0, fall, 0.0)
	var tail_len := (0.6 + 0.05 * speed) * _size
	for l in LAYERS.size():
		var rad: float = LAYER_RADIUS[l]
		var hd: MeshInstance3D = _drop_heads[l]
		hd.visible = falling
		hd.position = head_pos
		hd.scale = Vector3(0.26, 0.3 + 0.02 * speed, 0.26) * _size * rad
		param(hd, "phase", t)
		var tl: MeshInstance3D = _drop_tails[l]
		tl.visible = falling
		if falling:
			var pts := PackedVector3Array([head_pos, head_pos + Vector3(0.0, tail_len * 0.5, 0.0), head_pos + Vector3(0.0, tail_len, 0.0)])
			tl.mesh = Lib.path_tube(pts, 0.2 * _size * rad, 0.95)
		param(tl, "phase", t)
	# 水の舌：層ごとに中心線を作り直して、筒を張る
	for entry: Array in _tongues:
		var tau: float = since - float(entry[3])
		var mis: Array = entry[4]
		for l in LAYERS.size():
			var mi: MeshInstance3D = mis[l]
			var pts := _tongue_pts(entry, tau, l)
			mi.visible = pts.size() > 0
			if mi.visible:
				var r: float = TONGUE_RADIUS * _size * LAYER_RADIUS[l] * _thin(l, tau)
				mi.mesh = Lib.path_tube(pts, r, 0.85)
			param(mi, "phase", t)
	# 集中線：一本ずつ出て、外側から先に、別々の時刻に消える
	var c := Vector3(0.0, 1.0 * _size, 0.0)
	for entry: Array in _lines:
		var r: MeshInstance3D = entry[0]
		var a: float = entry[1]
		var delay: float = entry[2]
		var length: float = entry[3]
		var bend: float = entry[4]
		var head := clampf((since - 0.02 - delay * 0.5) / 0.12, 0.0, 1.0)
		var tail := clampf((since - delay - 0.45) / 0.45, 0.0, 1.0)
		r.visible = head > tail
		var dir := Vector3(cos(a), sin(a), 0.0)
		var side := Vector3(-sin(a), cos(a), 0.0)
		var pts := PackedVector3Array()
		for k in 6:
			var s := lerpf(tail, head, float(k) / 5.0)
			# 外へ伸び、根元より先端のほうが外へ寄る。中ほどで横へ少し曲げる
			pts.append(global_position + c + (dir * lerpf(1.7, 1.7 + length, s) + side * bend * sin(PI * s)) * _size)
		r.draw(pts)
	# 白い粒
	var mm := _drops.multimesh
	for i in DROPS:
		var d: Array = _drop_data[i]
		var tau := since - float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0 and tau < 2.0:
			var v: Vector3 = d[1]
			var p := Vector3(0.0, 0.3 * _size, 0.0) + v * tau + Vector3(0.0, -0.5 * GRAVITY * _size * tau * tau, 0.0)
			if p.y > 0.0:
				xf = Transform3D(Basis.IDENTITY, p)
		mm.set_instance_transform(i, xf)
	# 波紋：広がって、段ごとに消える
	_ring.visible = false   # 波紋は出さない（薄れが効かず、終わりに平らな円盤が残るため。報告に残す）
	_ring.scale = Vector3.ONE * _size * lerpf(0.6, 3.0, ease_out(clampf(since / 0.4, 0.0, 1.0)))
	param(_ring, "reveal", ease_out(clampf(since / 0.3, 0.0, 1.0)))
	var ring_fade := 1.0 - smoothstep(2.3, 3.2, since)
	param(_ring, "color", Color(0.35, 0.7, 1.2, ring_fade))
	param(_ring, "core_color", Color(0.8, 1.2, 1.6, ring_fade))
	param(_ring, "sweep", 0.0)
	_light.light_energy = 4.0 * _size * (1.0 - smoothstep(0.0, 1.2, since)) * (1.0 if since > 0.0 else 0.0)


# 水の舌の中心線（着地からの時刻 tau、層 l）。見えない時は空の配列を返す。
# 立ち上がり（高さ）と外への伸び（半径）を別々に動かす。先端は根元より先に伸びる。
# 層ごとの終わり方：外は先端から後退（"tip"）、中は根元の位置で細る（"thin"、_thin で扱う）、
# 芯は根元側から抜ける（"root"）。
func _tongue_pts(entry: Array, tau: float, l: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if tau <= 0.0:
		return pts
	var win: Array = LAYER_WINDOW[l]
	var k: float = smoothstep(win[0], win[1], tau)
	var s0 := 0.0
	var s1 := 1.0
	match LAYER_MODE[l]:
		"tip":
			s1 = 1.0 - k
		"root":
			s0 = k
	# 窓を過ぎた層は、どの型でも残さない（"thin" は s1 が 1 のままなので、ここで切らないと平たい棘が残る）
	if k >= 1.0 or s1 - s0 < 0.05:
		return pts
	var dir: Vector3 = entry[0]
	var peak: float = entry[1]
	var reach_max: float = entry[2]
	var lift: float = ease_out(clampf(tau / 0.35, 0.0, 1.0)) * (1.0 - smoothstep(0.8, 1.3, tau)) * peak * _size
	var ctrl := PackedVector3Array()
	for i in CTRL:
		var s := lerpf(s0, s1, float(i) / (CTRL - 1))
		var reach := ease_out(clampf((tau - 0.3 * (1.0 - s)) / 0.6, 0.0, 1.0))
		var r := (0.15 + 0.1 * s + reach_max * s * reach) * _size
		var h := lift * sin(PI * s)
		ctrl.append(dir * r + Vector3(0.0, TONGUE_Y * _size + h, 0.0))
	return Lib.smooth_path(ctrl, 3)


# 層ごとの太さの倍率（"thin" の層だけ、終わりに向かって細る）
func _thin(l: int, tau: float) -> float:
	if LAYER_MODE[l] == "thin":
		var win: Array = LAYER_WINDOW[l]
		return 1.0 - 0.85 * smoothstep(win[0], win[1], tau)
	return 1.0
