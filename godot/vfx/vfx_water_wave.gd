extends "res://vfx/vfx_base.gd"
# 大波（北斎『神奈川沖浪裏』の型）。海から波の面が立ち上がり、頂きが前へ巻いて、爪のような飛沫が伸びる。
# 波は奥行き方向に5本並べた中心線の「面」。本ごとに巻く時刻（0.08秒ずつ）と高さ（±10%）をずらす。
# 各本は三層の殻（Lib.path_tube ＋ wisp）。中心線は毎コマ作り直すので、節のつなぎ目は出ない。
# 崩れは頂きが前へ落ちて着水し、その点から低いしぶきの舌が前へ走る。本体は根元側へ引き戻して、上から消える。
#   素材：水（すき間だらけの薄い殻を3層重ねる。固体の筒は使わない）
#   どこから来る：海（y=0）から、奥行きの5本がずれながら立ち上がる
#   先に動く部分：頂き（巻いて、前へ落ちる）
#   遅れて追う部分：本体（根元へ引き戻される）／しぶきの舌（着水点から前へ走る）／本ごとの時刻（0.08秒ずつ）
#   形の変化：
#     0〜1.4秒    立ち上がり（波の壁。中心線の高さが増える）
#     1.4〜2.2秒  頂きが前へ巻く
#     2.2〜3.4秒  巻いたまま止まる。頂きから飛沫が飛ぶ
#     3.4〜4.2秒  頂きが前へ落ちて着水し、着水点から低い舌が前へ伸びる。本体は低くなる
#   終わり：層ごとに、外の層から上端を根元へ引き戻す（grow。4.0〜4.6秒）。
#           次に cut を上げて外から順にほどける（4.5〜4.9秒）。舌は前へ走ったあと、本ごとに少しずつずれて消える（4.7〜5.0秒）。
#           寿命は 5.6 秒。水たまりの波紋は段ごとに消える。
# 参考：『神奈川沖浪裏』（葛飾北斎）。頂きの巻きと、爪のような先端の形。
# 15コマ/秒。

const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const FPS := 15.0
const RISE_END := 1.4
const CURL_START := 1.4
const CURL_END := 2.2
const HOLD_END := 3.4
const FALL_END := 4.2
const RETREAT_START := 3.9    # 上端が根元へ引き戻される開始（層ごとに 0.1 秒ずらす）。life 5.6 の L-0.9 = 4.7 までに本体は空にする
const RETREAT_LEN := 0.3
const DISSOLVE_START := 4.2   # cut を上げて、外の層からほどけ始める（層ごとに 0.06 秒ずらす）
const DISSOLVE_LEN := 0.3
const TONGUE_START := 3.6     # 舌が走り出す時刻（本ごとに 0.03 秒ずらす）
const TONGUE_LEN := 1.6       # 舌の長さ（大きさ1のとき）
const TONGUE_END := 3.9       # 舌を根元へ引き戻し始める時刻（本ごとに 0.03 秒ずらす）。L-1.4 = 4.2 までに舌は空にする
const DROPS := 22
const GRAVITY := 7.0
const SIDES := 14
const LINE_Z := [-1.6, -0.8, 0.0, 0.8, 1.6]          # 奥行き方向に並べた5本の z（m）
const LINE_DELAY := 0.14                              # 本ごとの時刻のずれ（秒）。崩れの時刻は半分のずれにする（下の pose 参照）
const LINE_HEIGHT := [0.66, 0.73, 0.8, 0.87, 0.94]    # 本ごとの高さ（±18%）
const LINE_REACH := [0.75, 0.9, 1.0, 0.9, 0.75]       # 本ごとの舌の長さ（割合）
# 立ち上がりの中心線（XY 平面、単位は m。y=0 が海面）。巻いた後、落ちた後も同じ点数にそろえる
const SHAPE_RISE := [Vector3(-1.6, 0, 0), Vector3(-1.25, 1.0, 0), Vector3(-0.7, 2.2, 0), Vector3(0.1, 3.1, 0), Vector3(0.9, 3.5, 0), Vector3(1.4, 3.1, 0), Vector3(1.55, 2.5, 0), Vector3(1.2, 2.2, 0)]
const SHAPE_CURL := [Vector3(-1.6, 0, 0), Vector3(-1.25, 1.0, 0), Vector3(-0.6, 2.3, 0), Vector3(0.4, 3.3, 0), Vector3(1.4, 3.5, 0), Vector3(2.2, 3.0, 0), Vector3(2.35, 2.2, 0), Vector3(1.85, 1.9, 0)]
const SHAPE_FALL := [Vector3(-1.6, 0, 0), Vector3(-1.3, 0.9, 0), Vector3(-0.7, 1.9, 0), Vector3(0.2, 2.5, 0), Vector3(1.2, 2.4, 0), Vector3(2.0, 1.8, 0), Vector3(2.5, 0.9, 0), Vector3(2.6, 0.3, 0)]
# 舌の形（着水点を根元に、前へ伸びる。割合）
const TONGUE_SHAPE := [Vector3(0.0, 0.0, 0), Vector3(0.35, 0.22, 0), Vector3(0.8, 0.2, 0), Vector3(1.3, 0.02, 0)]
# 三層：[太さ(m), 濃い色, 内の色, cut, inner]。外ほど濃く、内ほど明るい。inner は外ほど大きく（白い所を減らす）
const LAYERS := [
	[0.85, Vector3(0.04, 0.22, 0.9), Vector3(0.12, 0.55, 1.5), 0.7, 0.5],
	[0.55, Vector3(0.18, 0.7, 2.0), Vector3(0.7, 2.2, 3.4), 0.6, 0.3],
	[0.26, Vector3(0.9, 2.2, 3.0), Vector3(3.0, 4.4, 4.8), 0.5, 0.14],
]
# 舌の二層：[太さ(m), 濃い色, 内の色, cut, inner]
const TONGUE_LAYERS := [
	[0.26, Vector3(0.12, 0.55, 1.5), Vector3(0.7, 2.2, 3.4), 0.55, 0.3],
	[0.14, Vector3(0.9, 2.2, 3.0), Vector3(3.0, 4.4, 4.8), 0.45, 0.14],
]

var _size := 1.0
var _frame := -1
var _lines: Array = []         # 本ごとに、三層の MeshInstance3D の配列
var _tongues: Array = []       # 本ごとに、舌の二層の MeshInstance3D の配列
var _drops: MultiMeshInstance3D
var _drop_data: Array = []     # [発射の遅れ, 出る位置の番号, 初速]
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
	life = 5.6
	for j in LINE_Z.size():
		var rows: Array = []
		for i in LAYERS.size():
			var layer: Array = LAYERS[i]
			var mi := Lib.wisp_layer(ArrayMesh.new(), i, LAYERS.size(), layer[1], layer[2], {
				"tip": 0.0, "top_thin": 0.25, "sway": 0.0, "ripple": 0.06, "cut": layer[3], "inner": layer[4], "scale_a": Vector2(2.0, 0.4),
				"seed": i * 0.5 + j * 0.23,
			})
			add_child(mi)
			rows.append(mi)
		_lines.append(rows)
	for j in LINE_Z.size():
		var rows: Array = []
		for i in TONGUE_LAYERS.size():
			var layer: Array = TONGUE_LAYERS[i]
			var mi := Lib.wisp_layer(ArrayMesh.new(), i, TONGUE_LAYERS.size(), layer[1], layer[2], {
				"tip": 0.0, "top_thin": 0.0, "sway": 0.0, "ripple": 0.04, "cut": layer[3], "inner": layer[4],
				"seed": 2.0 + i * 0.4 + j * 0.31,
			})
			add_child(mi)
			mi.visible = false
			rows.append(mi)
		_tongues.append(rows)
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.07
	drop_mesh.height = 0.14
	drop_mesh.radial_segments = 10
	drop_mesh.rings = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = DROPS
	mm.mesh = drop_mesh
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.material_override = Lib.material("water_ball", {"noise_texture": Lib.noise("soft"), "wobble": 0.02})
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in DROPS:
		_drop_data.append([randf() * 1.4, randi() % 4, Vector3(randf_range(0.8, 2.2), randf_range(0.5, 2.5), randf_range(-0.4, 0.4)) * size])
	_ring = MeshInstance3D.new()
	_ring.mesh = Lib.quad()
	_ring.material_override = Lib.material("stamp", {"shape": Lib.tex("vfx_ex1d.jpg"), "cut": 0.35, "core_cut": 0.7,
		"color": Color(0.6, 1.4, 2.6, 1.0), "core_color": Color(2.2, 3.4, 4.4, 1.0), "reveal": 0.0})
	_ring.rotation.x = -PI / 2.0
	_ring.position.y = 0.02
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_light = lamp(Color(0.6, 0.9, 1.0), 12.0 * size)
	_light.position.y = 1.6 * size
	# 白い泡：着水点に、煙玉で砕けた泡を置く（寿命は 4.8 秒までに終わり、親の寿命 5.6 - 0.6 より前に消える）
	for j in LINE_Z.size():
		var plan: Array = []
		for k in 6:
			var b := TAU * float(k) / 6.0 + float(j) * 0.4
			plan.append([3.7 + float(j) * 0.04 + float(k) * 0.05, Vector3(cos(b), 0.5, sin(b)), 0.5 + 0.15 * float(k % 2), 0.35 + 0.08 * float(k % 3), 0.7])
		var foam: Node3D = Puffs.new()
		foam.rise = 0.3
		add_child(foam)
		foam.position = Vector3(2.6 * size, 0.0, LINE_Z[j] * size)
		foam.start(plan, size, Color.WHITE)
		foam.recolor(Vector3(1.25, 1.3, 1.35), Vector3(0.7, 0.8, 0.9), Vector3(0.3, 0.4, 0.5))
	_pose(0.0)


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	var n := SHAPE_RISE.size()
	var center_ctrl := PackedVector3Array()
	var landings := PackedVector3Array()
	# 奥行きの5本：本ごとに時刻をずらし、高さを変えて、同じ形の繰り返しに見せない
	for j in LINE_Z.size():
		var tl := maxf(t - LINE_DELAY * float(j), 0.0)
		var rise := ease_out(clampf(tl / RISE_END, 0.0, 1.0))
		var curl := smoothstep(CURL_START, CURL_END, tl)
		var fall := smoothstep(HOLD_END, FALL_END, t - LINE_DELAY * 0.5 * float(j))
		# 着水の後、本体は海へ沈んで溶ける（根元へ引き戻さない。REVIEW）
		var sink := smoothstep(FALL_END, FALL_END + 0.8, t - LINE_DELAY * 0.5 * float(j))
		var sway := sin(tl * 2.2) * 0.06 * clampf((tl - CURL_END) / 0.4, 0.0, 1.0)
		var ctrl := PackedVector3Array()
		for i in n:
			var p: Vector3 = (SHAPE_RISE[i] as Vector3).lerp(SHAPE_CURL[i], curl).lerp(SHAPE_FALL[i], fall)
			p.y *= LINE_HEIGHT[j] * rise * (1.0 - 0.3 * fall) * (1.0 - 0.6 * sink)
			p.x += sway * float(i) / float(n - 1)
			p.z = LINE_Z[j]
			ctrl.append(p * _size)
		if j == 2:
			center_ctrl = ctrl
		landings.append(ctrl[ctrl.size() - 1])
		var path := Lib.smooth_path(ctrl, 6)
		var squeeze := 0.4 + 0.6 * rise
		var rows: Array = _lines[j]
		for i in LAYERS.size():
			var mi: MeshInstance3D = rows[i]
			mi.mesh = Lib.path_tube(path, float(LAYERS[i][0]) * _size * squeeze, 0.55, SIDES)
			param(mi, "phase", t)
			# cut を上げて、外の層からほどく
			# 本体は根元へ引き戻さない（REVIEW：海へ溶ける）。沈みと cut のほどけで消す
			param(mi, "grow", 1.0)
			var dis := smoothstep(DISSOLVE_START + 0.1 * i, DISSOLVE_START + 0.1 * i + DISSOLVE_LEN, t)
			var base_cut: float = LAYERS[i][3]
			param(mi, "cut", base_cut + (1.0 - base_cut) * dis)
			mi.visible = dis < 1.0
	# 着水点から前へ走る低い舌。本ごとに少しずつずらす
	for j in LINE_Z.size():
		var rows: Array = _tongues[j]
		var start := TONGUE_START + 0.03 * float(j)
		var reach := ease_out(clampf((t - start) / 0.4, 0.0, 1.0)) * float(LINE_REACH[j])
		# 舌は先端から着水点へ引き戻すのと同時に cut を 1.0 まで上げ切る。本体より先に空にする
		var ret := smoothstep(TONGUE_END + 0.03 * j, TONGUE_END + 0.03 * j + 0.2, t)
		var dis := smoothstep(TONGUE_END + 0.03 * j, TONGUE_END + 0.03 * j + 0.2, t)
		var root: Vector3 = landings[j]
		var pts := PackedVector3Array()
		for k in TONGUE_SHAPE.size():
			pts.append(root + (TONGUE_SHAPE[k] as Vector3) * TONGUE_LEN * maxf(reach, 0.04) * _size)
		var tpath := Lib.smooth_path(pts, 5)
		for i in TONGUE_LAYERS.size():
			var mi: MeshInstance3D = rows[i]
			mi.visible = t >= start and dis < 1.0
			if mi.visible:
				mi.mesh = Lib.path_tube(tpath, float(TONGUE_LAYERS[i][0]) * _size, 0.8, SIDES)
				param(mi, "phase", t)
				param(mi, "grow", 1.0 - ret)
				var base_cut: float = TONGUE_LAYERS[i][3]
				param(mi, "cut", base_cut + (1.0 - base_cut) * dis)
	# 水たまりの波紋
	_ring.visible = false   # 波紋は出さない（薄れが効かず、平らな円盤が残るため。報告に残す）
	_ring.scale = Vector3.ONE * _size * lerpf(1.2, 3.4, ease_out(clampf((t - 0.4) / 1.6, 0.0, 1.0)))
	param(_ring, "reveal", ease_out(clampf((t - 0.4) / 1.0, 0.0, 1.0)))
	param(_ring, "spin", t * 0.4)
	param(_ring, "cut", lerpf(0.35, 1.0, smoothstep(FALL_END - 0.6, FALL_END + 0.3, t)))
	param(_ring, "sweep", smoothstep(FALL_END - 0.3, FALL_END + 0.6, t))
	var rise_g := ease_out(clampf(t / RISE_END, 0.0, 1.0))
	_light.light_energy = 6.0 * _size * rise_g * (1.0 - smoothstep(FALL_END, FALL_END + 0.8, t))
	# 飛沫：中央の本の頂きから、巻ききったあと放物線で飛ぶ
	var mm := _drops.multimesh
	for i in DROPS:
		var d: Array = _drop_data[i]
		var tau := t - (CURL_END + 0.1 + float(d[0]))
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0 and tau < 2.5:
			var from := center_ctrl[mini(3 + int(d[1]), center_ctrl.size() - 1)]
			var v: Vector3 = d[2]
			var p := from + v * tau + Vector3(0.0, -0.5 * GRAVITY * _size * tau * tau, 0.0)
			if p.y > 0.0:
				xf = Transform3D(Basis.IDENTITY, p)
		mm.set_instance_transform(i, xf)
