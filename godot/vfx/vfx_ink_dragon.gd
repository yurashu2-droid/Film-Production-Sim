extends "res://vfx/vfx_base.gd"
# 墨の龍。地面の陣の穴から墨色の体が湧き出し、螺旋に巻き上がり、頭が弧を描いて空へ抜ける。
# 質感は黒雷と同じ：薄い殻を三層重ね、外は墨のように暗く、内へ金・白熱へ明るく。跳ねながら流れ、尾から引き抜かれて消える。
#
# 素材：        墨（外は黒、内は金、芯は白熱）
# どこから来る： 地面の陣（二重の輪）の中心。地下から湧く（地下は床に隠れる）
# 先に動く部分： 頭。解析的な曲線 _head(t) を進む（螺旋 → 空へ抜ける）
# 遅れて追う部分：体（頭が 2 秒かけて通った道を、そのままなぞる）／ひげ（頭の少し後ろの道を、外へ開いて流れる）
# 形の変化：
#   0〜0.8秒   陣が開く。頭が地面から出る。体は地下から続く
#   0.8〜2.6秒 螺旋に巻き上がる（半径は少し締まり、ゆるく波打つ）。体は太く、尾は細い
#   2.6秒〜    頭が外へ開きながら空へ加速して抜ける。体は一本の長い筋へ伸びる
# 終わり（層ごとに別の行き先）：
#   体   層ごとに違う：外の墨が先にほつれ（2.6〜3.6秒）、金が続き（2.9〜4.0秒）、白い芯が最後に空へ抜ける（3.2〜4.3秒）。墨のしずくが陣へ落ちる
#   陣   落ちた墨で色が墨へ沈み（3.0〜3.7秒）、回りながら扇形に食われる。外の輪は時計回り（3.8〜4.7秒）、内の輪は模様がちぎれてから反対側から（3.9〜4.9秒）
#   ひげ 体より先に、すき間（cut）を増やしてほどける（3.0〜3.6秒）
#   陣   外の輪が先、内の輪が少し遅れて、外から欠ける（3.4〜4.4秒）
# 作り方：
#   体は Lib.path_tube の一本の筒。頭が通った時刻の位置を、体の各点に当てる（_head(t - 遅れ)）。
#   太さは profile で点ごとに指定（尾が細い → 中が太い → 頭が最も太く、鼻先で細る）。
#   電気の跳ねは 15 コマ/秒で変わる小さなずれ。形そのものは毎コマなめらかに動く。
# 参考：水墨画の龍（墨の濃淡と、雲を割って昇る姿）。

const HISTORY := 2.6
const BODY_POINTS := 72
const WHISK_POINTS := 14
const BODY_R := 0.5
const WHISK_R := 0.2
const REBUILD := 30.0
# [外の色, 内の色, cut, inner, 半径の比]。外から内へ
const INK := [
	[Vector3(0.03, 0.025, 0.03), Vector3(0.20, 0.15, 0.10), 0.68, 0.72, 1.0],
	[Vector3(1.0, 0.5, 0.08), Vector3(2.4, 1.3, 0.3), 0.6, 0.4, 0.5],
	[Vector3(3.0, 2.8, 2.2), Vector3(6.0, 5.6, 4.6), 0.5, 0.14, 0.2],
]

var _size := 1.0
var _frame := -1
var _body: Array = []         # [殻, 半径の比, 基本の cut]
var _whiskers: Array = []     # [{"sign", "seed", "layers"}]
var _rings: Array[MeshInstance3D] = []
var _glow: MeshInstance3D
var _drops: MultiMeshInstance3D
var _drop_data: Array = []     # [落ちはじめ, 出る位置, 初速]
var _light: OmniLight3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 5.4
	_rings.append(_disc("vfx_spiral07.jpg", 0.25, Color(1.2, 0.7, 0.15, 1.0), Color(2.6, 2.0, 1.1, 1.0)))
	_rings.append(_disc("vfx_spiral07.jpg", 0.3, Color(0.8, 0.45, 0.1, 1.0), Color(1.8, 1.3, 0.7, 1.0)))
	_body = _make_layers(0.0, 0.0, 0.0)
	for sg in [-1.0, 1.0]:
		_whiskers.append({"sign": sg, "seed": 31 + int(sg * 7.0), "layers": _make_layers(5.0 + sg, 0.3, 0.5)})
	_glow = sprite(0, Color(2.6, 1.8, 0.6, 1.0), 0.5 * size)
	_light = lamp(Color(1.0, 0.75, 0.35), 9.0 * size)
	# 墨のしずく：体がほつれる間に、体から離れて陣へ落ちる（落ちた所は染みになる）
	var dm := SphereMesh.new()
	dm.radius = 0.07
	dm.height = 0.16
	dm.radial_segments = 8
	dm.rings = 4
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.02, 0.018, 0.02)
	dm.material = ink
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 16
	mm.mesh = dm
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in 16:
		var launch := 2.7 + float(i) * 0.07 + randf() * 0.05
		var u := randf_range(0.05, 0.6)
		var from := _head(launch - (1.0 - u) * HISTORY)
		if from.y < 0.4 * size:
			from.y = 0.4 * size + randf() * 0.5
		_drop_data.append([launch, from, Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), randf_range(-0.4, 0.4)) * size])
	_pose(0.0)


# 頭の位置。t<0 は地下（床に隠れる）。t が進むと螺旋に巻き上がり、2.6 秒から空へ加速して抜ける
func _head(t: float) -> Vector3:
	var u := maxf(t, 0.0)
	var ang := 2.4 * t + 0.4 * sin(1.1 * t)
	var rad := 1.2 - 0.35 * smoothstep(0.0, 2.2, u) + 0.15 * sin(2.3 * u)
	var h := 2.6 * (1.0 - exp(-0.8 * t)) + 0.3 * sin(1.7 * u)
	if t > 2.6:
		var e := t - 2.6
		h += 6.0 * e * e
		rad *= 1.0 + 0.6 * e
	return Vector3(cos(ang) * rad, h, sin(ang) * rad) * _size


# 殻を三層（体・ひげ共通）
func _make_layers(seed_base: float, tip: float, top_thin: float) -> Array:
	var out: Array = []
	for k in 3:
		var row: Array = INK[k]
		var layer := Lib.wisp_layer(ArrayMesh.new(), k, 3, row[0], row[1], {
			"tip": tip, "top_thin": top_thin, "sway": 0.0, "ripple": 0.04,
			"cut": row[2], "inner": row[3], "seed": seed_base + float(k) * 0.37,
			"speed_a": Vector2(0.5, 3.0), "speed_b": Vector2(0.0, 4.0), "scale_a": Vector2(2.0, 0.5),
		})
		add_child(layer)
		out.append([layer, float(row[4]), float(row[2])])
	return out


# 円盤（地面に寝かせた絵）
func _disc(file: String, cut: float, color: Color, core: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	mi.material_override = Lib.material("stamp", {
		"shape": Lib.tex(file), "cut": cut, "core_cut": 0.7,
		"color": color, "core_color": core, "reveal": 0.0,
	})
	mi.rotation.x = -PI / 2.0
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# 太さ：尾は細く、中ほどで太り、頭が最も太く、鼻先で細る。u は 0（尾）〜 1（頭）
static func _profile(u: float) -> float:
	var tail := pow(smoothstep(0.0, 0.45, u), 0.7)
	var head := 1.0 + 0.4 * smoothstep(0.55, 0.9, u) - 0.5 * smoothstep(0.92, 1.0, u)
	return maxf(0.03, tail * head)


# 決まった入力から、0〜1の乱数を作る
static func _rnd(sd: int, i: int, step: int) -> float:
	return fposmod(sin(float(sd) * 12.9898 + float(i) * 78.233 + float(step) * 37.719) * 43758.5453, 1.0)


func _jag(sd: int, i: int, step: int, amp: float) -> Vector3:
	return Vector3(_rnd(sd, i, step) - 0.5, _rnd(sd + 3, i, step) - 0.5, _rnd(sd + 7, i, step) - 0.5) * amp


func _tick(_delta: float) -> void:
	_pose(age)


# 体とひげを作り直す（30 コマ/秒。電気の跳ねは 15 コマ/秒で変わる）
func _rebuild(t: float, step: int) -> void:
	var pts := PackedVector3Array()
	var prof := PackedFloat32Array()
	for i in BODY_POINTS:
		var u := float(i) / (BODY_POINTS - 1)
		var p := _head(t - (1.0 - u) * HISTORY)
		pts.append(p + _jag(7, i, step, 0.04 * _size * smoothstep(0.0, 0.3, u)))
		prof.append(_profile(u))
	for pair: Array in _body:
		var layer: MeshInstance3D = pair[0]
		layer.mesh = Lib.path_tube(pts, float(pair[1]) * BODY_R * _size, 0.0, 10, prof)
	for w: Dictionary in _whiskers:
		var sg: float = w["sign"]
		var wp := PackedVector3Array()
		var wprof := PackedFloat32Array()
		for j in WHISK_POINTS:
			var v := float(j) / (WHISK_POINTS - 1)
			var tt := t - v * 1.0
			var ang := 2.4 * tt + 0.4 * sin(1.1 * tt)
			var radial := Vector3(cos(ang), 0.0, sin(ang))
			var p := _head(tt) + (radial * sg * (0.25 + 1.1 * v) + Vector3.UP * 0.25 * sin(v * 6.0 + t * 4.0)) * _size
			wp.append(p + _jag(int(w["seed"]), j, step, 0.05 * _size))
			wprof.append(1.0 - 0.9 * v)
		for pair: Array in w["layers"]:
			var layer: MeshInstance3D = pair[0]
			layer.mesh = Lib.path_tube(wp, float(pair[1]) * WHISK_R * _size, 0.0, 8, wprof)


func _pose(t: float) -> void:
	var frame := int(t * REBUILD)
	if frame != _frame:
		_frame = frame
		_rebuild(t, frame / 2)
	# 体：尾から引き抜く
	# 体の終わりは層ごとに違う：外の墨が先にほつれて（cut が上がり、尾から欠ける）、金は少し遅れ、白い芯が最後に空へ抜ける
	var starts := [2.6, 2.9, 3.2]
	var ends := [3.6, 4.0, 4.3]
	for k in _body.size():
		var pair: Array = _body[k]
		var layer: MeshInstance3D = pair[0]
		param(layer, "eaten", smoothstep(float(starts[k]), float(ends[k]), t))
		param(layer, "phase", t)
		if k == 0:
			param(layer, "cut", lerpf(float(pair[2]), 1.0, smoothstep(2.7, 3.5, t)))
	# ひげ：体より先にほどける
	var loosen := smoothstep(3.0, 3.6, t)
	for w: Dictionary in _whiskers:
		for pair: Array in w["layers"]:
			var layer: MeshInstance3D = pair[0]
			param(layer, "phase", t)
			param(layer, "cut", lerpf(float(pair[2]), 1.0, loosen))
	# 頭の光と灯り
	var head := _head(t)
	_glow.position = head
	_glow.visible = t < 3.8
	_light.position = head
	_light.light_energy = 5.0 * _size * ease_out(clampf(t / 0.6, 0.0, 1.0)) * (1.0 - smoothstep(3.0, 4.2, t))
	# 墨のしずく：放物線で落ち、陣に着くと消える
	var mm := _drops.multimesh
	for i in 16:
		var d: Array = _drop_data[i]
		var tau := t - float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0 and tau < 2.0:
			var p: Vector3 = (d[1] as Vector3) + (d[2] as Vector3) * tau + Vector3(0.0, -4.5 * _size * tau * tau, 0.0)
			if p.y > 0.03:
				xf = Transform3D(Basis.from_scale(Vector3.ONE * _size), p)
		mm.set_instance_transform(i, xf)
	# 陣：開き、逆向きに回り、外から欠ける（縮めない）
	var open := ease_out(clampf(t / 0.8, 0.0, 1.0))
	for i in _rings.size():
		var ring := _rings[i]
		ring.visible = t < 5.0
		ring.scale = Vector3.ONE * _size * lerpf(0.5, 3.4 + 0.8 * float(i), open)
		param(ring, "reveal", open)
		# 墨が染みる：陣の色が墨色へ沈み、乾くように外から欠ける
		var soak := smoothstep(3.0, 3.7, t)
		var base: Color = [Color(1.2, 0.7, 0.15, 1.0), Color(0.8, 0.45, 0.1, 1.0)][i]
		var tint := base.lerp(Color(0.05, 0.04, 0.04, 1.0), soak)
		(ring.material_override as ShaderMaterial).set_shader_parameter("color", tint)
		(ring.material_override as ShaderMaterial).set_shader_parameter("core_color", tint.lerp(Color(0.1, 0.08, 0.06, 1.0), soak))
		param(ring, "spin", (-1.0 if i == 0 else 1.0) * t * (0.8 + 0.4 * float(i)))
		# 終わり：回転は止めない。外の輪は扇形にぬぐわれ、内の輪は模様がちぎれてから逆向きにぬぐわれる（円を縮めない）
		if i == 0:
			param(ring, "sweep", smoothstep(3.8, 4.7, t))
		else:
			param(ring, "sweep_from", 0.5)
			param(ring, "cut", lerpf(0.3, 1.0, smoothstep(3.9, 4.6, t)))
			param(ring, "sweep", smoothstep(4.2, 4.9, t))
