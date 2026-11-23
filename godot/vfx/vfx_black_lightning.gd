extends "res://vfx/vfx_base.gd"
# 黒雷（黒閃の派生）。黒い芯に赤いふちの稲妻を、五つの型で出す。
#   burst   本体：六本の稲妻が中心から放射。最初の2コマに白い閃光と画面の反転
#   vortex  渦の黒雷：竜巻に巻きつく螺旋の稲妻を三本。区間ごとの板を、両端を固定してつないで作る
#   ground  地を這う黒雷：地面の亀裂から稲妻が四方へ這い、亀裂が赤黒く残ってから消える
#   flame   赤黒い炎：稲妻の代わりに、炎の舌が立ち上がり、先からちぎれる（wisp の殻）
#   flash   一閃：太い黒い筋を一本。0.6秒で走り抜け、白い閃光と画面の反転を伴う
# 作り方（共通）：
#   稲妻は折れ線の筒で作らない。固形の棒に見えた（PLAYBOOK の稲妻の項）。
#   arc シェーダーの板の上で、流れるノイズから線を取り出して描く。芯は黒（乗算済みアルファで背景を隠す）、ふちは赤。
#   電気の跳ねは 15 コマ/秒（flash は 30）。光り直しのたびに seed を変えて、形を跳ばせる。
#   消え方は根元から先へ（eaten）。先端は戻さない（grow を下げない）。外の板が先、白い副流が最後。
# 参考：『呪術廻戦』の黒閃（黒い稲妻と赤い縁）。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const RED := Vector3(4.2, 0.14, 0.07)
const WHITE_HOT := Vector3(4.0, 3.6, 3.2)
const WHITE_CORE := Vector3(1.6, 1.5, 1.4)
const HELIX_SEGS := 14        # 螺旋一本あたりの区間の数
const HELIX_TURNS := 2.0      # 螺旋の巻き数
const TIMING := {
	"burst": {"fps": 15.0, "life": 2.7, "grow": 0.16, "hold": 0.75, "fade": 0.4, "restrike": 0.2},
	"vortex": {"fps": 15.0, "life": 3.9, "grow": 0.6, "hold": 1.6, "fade": 0.7, "restrike": 0.0},
	"ground": {"fps": 15.0, "life": 3.5, "grow": 0.22, "hold": 0.9, "fade": 0.45, "restrike": 0.25},
	"flame": {"fps": 15.0, "life": 3.7, "grow": 0.5, "hold": 1.6, "fade": 1.0, "restrike": 0.0},
	"flash": {"fps": 30.0, "life": 1.6, "grow": 0.06, "hold": 0.35, "fade": 0.3, "restrike": 0.0},
}
# 炎の舌の三層（wisp）。[暗い色, 明るい色, cut（大きいほどすき間が多い）, inner（大きいほど白い所が減る）, 半径の比]
const LAYERS := [
	[Vector3(0.02, 0.0, 0.0), Vector3(0.2, 0.02, 0.01), 0.8, 0.68, 1.0],
	[Vector3(0.9, 0.05, 0.02), Vector3(2.0, 0.25, 0.1), 0.58, 0.4, 0.6],
	[Vector3(2.6, 1.9, 1.5), Vector3(6.0, 5.2, 4.8), 0.5, 0.14, 0.25],
]

var _kind := "burst"
var _size := 1.0
var _timing: Dictionary = {}
var _bolts: Array = []        # 稲妻ごと：{"delay", "bands"（板の一覧）と、型ごとの情報}
var _frame := -1
var _flip: MeshInstance3D
var _flash: MeshInstance3D
var _cracks: MeshInstance3D
var _light: OmniLight3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, kind: String = "burst") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, kind)
	return fx


func start(size: float, kind: String) -> void:
	_size = size
	_kind = kind
	_timing = TIMING[kind]
	life = float(_timing["life"])
	_flip = MeshInstance3D.new()
	_flip.mesh = Lib.quad()
	var flip_mat := Lib.material("invert")
	flip_mat.render_priority = -100
	_flip.material_override = flip_mat
	_flip.scale = Vector3.ONE * 120.0
	_flip.extra_cull_margin = 1000.0
	_flip.visible = false
	add_child(_flip)
	_flash = sprite(2, Color(10, 10, 10), (1.6 if kind == "flash" else 2.6) * size)
	_flash.visible = false
	if kind == "ground":
		_cracks = MeshInstance3D.new()
		_cracks.mesh = Lib.quad()
		_cracks.material_override = Lib.material("stamp", {
			"shape": Lib.tex("cracks336.png"), "cut": 0.3, "core_cut": 2.0, "reveal": 0.0,
			"color": Color(0.9, 0.12, 0.05, 1.0), "core_color": Color(0.05, 0.02, 0.02, 1.0),
		})
		_cracks.rotation.x = -PI / 2.0
		_cracks.position.y = 0.02
		_cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cracks)
	_light = lamp(Color(1.0, 0.25, 0.1), 9.0 * size)
	_light.position.y = 1.0 * size
	_make_bolts()
	_pose(0.0)


# 型ごとに、稲妻の本数・向き・長さ・出る遅れを決める
func _make_bolts() -> void:
	match _kind:
		"burst":
			for i in 6:
				var a := TAU * float(i) / 6.0 + 0.3
				_add_ray(Vector3.ZERO, Vector3(cos(a), randf_range(0.35, 0.8), sin(a)), randf_range(2.6, 3.4) * _size, 0.02 * float(i), false)
		"ground":
			for i in 6:
				var a := TAU * float(i) / 6.0 + 0.5
				_add_ray(Vector3(0.0, 0.05, 0.0), Vector3(cos(a), 0.0, sin(a)), randf_range(3.0, 3.8) * _size, 0.03 * float(i), false)
		"vortex":
			for i in 3:
				_add_helix(i, float(i) * TAU / 3.0 + randf() * 0.4, 0.04 * float(i))
		"flash":
			_add_ray(Vector3.ZERO, Vector3(cos(0.4), sin(0.4), 0.0), 3.6 * _size, 0.0, true)
		_:
			for i in 6:
				var a := TAU * float(i) / 6.0
				_add_flame(i, Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5) * _size, randf_range(2.6, 3.4) * _size, 0.04 * float(i), 0.48)


# 直線の稲妻（根元から先へ伸びる一本）。太い黒い本流に、細く白熱する副流を重ねる。一閃は本流だけ
func _add_ray(root: Vector3, dir: Vector3, reach: float, delay: float, single: bool) -> void:
	var d := dir.normalized()
	var sd := randf() * 50.0
	var bands: Array = []
	bands.append(_band({
		"noise_texture": Lib.noise("soft"), "width": reach * (0.4 if single else 0.36),
		"thickness": 0.3 if single else 0.12, "forks": 2.0, "variation": 0.4, "frequency": 0.8 if single else 1.2,
		"speed": 1.4, "morph": 1.0, "rim_color": RED, "glow": 0.1, "core_part": 0.85, "seed": sd,
	}, root, root + d * reach))
	if not single:
		bands.append(_band({
			"noise_texture": Lib.noise("soft"), "width": reach * 0.5, "thickness": 0.05, "forks": 1.0,
			"variation": 0.6, "frequency": 1.6, "speed": 2.2, "morph": 1.8,
			"core_color": WHITE_CORE, "rim_color": WHITE_HOT, "glow": 0.1, "seed": sd + 9.0,
		}, root, root + d * reach))
	_bolts.append({"delay": delay, "bands": bands})


# 螺旋の稲妻（竜巻に巻きつく一本）。区間ごとの板を、両端を固定してつなぐ。隣の区間と点で一致し、継ぎ目は出ない
func _add_helix(strand: int, phase0: float, delay: float) -> void:
	var sd := randf() * 50.0
	var bands: Array = []
	for s in HELIX_SEGS:
		bands.append(_band({
			"noise_texture": Lib.noise("soft"), "width": 0.32 * _size, "thickness": 0.34, "forks": 2.0,
			"variation": 0.9, "frequency": 2.4, "speed": 1.2, "morph": 0.9, "rim_color": RED, "glow": 0.12, "core_part": 0.85,
			"pin_end": true, "taper": 0.0, "seed": sd + float(s) * 0.37,
		}, Vector3.ZERO, Vector3.ZERO))
	_bolts.append({"delay": delay, "bands": bands, "seed": sd, "phase0": phase0,
		"reach": 3.6 * _size, "radius": [0.42, 0.5, 0.58][strand] * _size,
		"turns": [2.0, 2.3, 1.7][strand], "spin": [2.4, 2.9, 2.0][strand], "k": [1.0, 1.2, 0.85][strand]})


# 板を一枚作る。a から b まで、板の中で稲妻の線が描かれる（arc シェーダー）
func _band(params: Dictionary, a: Vector3, b: Vector3) -> Dictionary:
	var r: MeshInstance3D = Ribbon.new()
	var mat := Lib.material("arc", params)
	r.material_override = mat
	add_child(r)
	r.draw(PackedVector3Array([a, b]))
	return {"ribbon": r, "mat": mat, "base": float(params["seed"]), "a": a, "b": b}


# 炎の舌（wisp の三層の筒）。根元から立ち上がり、先からちぎれる
func _add_flame(index: int, root: Vector3, reach: float, delay: float, radius: float) -> void:
	var layers: Array = []
	for k in 3:
		var s: Array = LAYERS[k]
		# 赤黒い炎：外は黒、中は暗い赤、芯は赤橙（白く飛ばすと普通の炎になる）
		var dark: Vector3 = s[0]
		var light: Vector3 = s[1]
		if k == 1:
			light = Vector3(1.4, 0.2, 0.08)
		elif k == 2:
			dark = Vector3(1.6, 0.5, 0.25)
			light = Vector3(2.6, 1.2, 0.7)
		var layer := Lib.wisp_layer(ArrayMesh.new(), k, 3, dark, light, {
			"tip": 0.5, "top_thin": 0.45, "sway": 0.0, "ripple": 0.04,
			"cut": s[2], "inner": s[3], "seed": float(index) * 1.3 + float(k) * 0.37,
			"speed_a": Vector2(0.4, 5.5), "speed_b": Vector2(0.0, 3.2), "scale_a": Vector2(1.5, 0.4),
		})
		add_child(layer)
		layers.append([layer, float(s[4])])
	_bolts.append({"delay": delay, "layers": layers, "seed": index * 17 + 3,
		"root": root, "reach": reach, "radius": radius})


func _tick(_delta: float) -> void:
	var frame := int(age * float(_timing["fps"]))
	if frame != _frame:
		_frame = frame
		if _kind == "flame":
			for b: Dictionary in _bolts:
				if age >= float(b["delay"]):
					_rebuild(b, frame, age)
	_pose(age)


func _pose(t: float) -> void:
	match _kind:
		"flame":
			_pose_flame(t)
		"vortex":
			_pose_helix(t)
		_:
			_pose_rays(t)
	if _cracks != null:
		_cracks.visible = t < 2.7
		_cracks.scale = Vector3.ONE * _size * lerpf(0.5, 4.5, ease_out(clampf(t / 0.5, 0.0, 1.0)))
		param(_cracks, "reveal", ease_out(clampf(t / 0.5, 0.0, 1.0)))
		# cut は 1.05 まで上げる。1.0 だと、絵の一番明るい画素（v == 1.0）が点々になって残る
		param(_cracks, "cut", lerpf(0.3, 1.05, smoothstep(1.5, 2.3, t)))
		param(_cracks, "sweep", smoothstep(1.9, 2.7, t))
	var impact := _kind == "burst" or _kind == "flash"
	_flip.visible = impact and t >= 0.0 and t < 0.13
	_flash.visible = impact and t >= 0.0 and t < 0.12
	_light.light_energy = 4.0 * _size * (1.0 - clampf(t / life, 0.0, 1.0)) + (12.0 * _size if _flash.visible else 0.0)


# 直線の稲妻：根元から伸びて、供給が止まると根元から先へ消える。光り直しのたびに形が跳ぶ
func _pose_rays(t: float) -> void:
	var fps: float = _timing["fps"]
	var step_t: float = floor(t * fps) / fps
	var grow_time: float = _timing["grow"]
	var hold: float = _timing["hold"]
	var fade: float = _timing["fade"]
	var restrike: float = _timing["restrike"]
	for b: Dictionary in _bolts:
		var since := t - float(b["delay"])
		var bands: Array = b["bands"]
		for li in bands.size():
			var band: Dictionary = bands[li]
			var r: MeshInstance3D = band["ribbon"]
			var mat: ShaderMaterial = band["mat"]
			r.visible = since >= 0.0
			if not r.visible:
				continue
			# 本流と副流は同じ時刻に根元から消える。終わりほど速く進めて、先端の小片を宙に残さない
			var gone := pow(clampf((since - hold) / fade, 0.0, 1.0), 1.6)
			r.visible = gone < 1.0
			var up := ease_out(clampf(since / grow_time, 0.0, 1.0))
			mat.set_shader_parameter("reveal", 1.5 * up)
			mat.set_shader_parameter("eaten", gone * 1.25 if gone > 0.0 else -1.0)
			# 千切れた先端は、進んだ向きへ少しずつ伸ばして流す（根元は動かさない）
			var pa: Vector3 = band["a"]
			var pb: Vector3 = band["b"]
			r.draw(PackedVector3Array([pa, pa.lerp(pb, 1.0 + 0.25 * gone)]))
			mat.set_shader_parameter("phase", step_t)
			var sd := float(band["base"])
			if restrike > 0.0:
				sd += floor(since / restrike) * 3.7
			mat.set_shader_parameter("seed", sd)


# 螺旋の稲妻：根元から立ち上がり、供給が止まると根元から上へ消える。点は 15 コマ/秒で跳ねる
func _pose_helix(t: float) -> void:
	var fps: float = _timing["fps"]
	var step := int(floor(t * fps))
	var step_t := float(step) / fps
	var grow_time: float = _timing["grow"]
	var hold: float = _timing["hold"]
	var fade: float = _timing["fade"]
	for b: Dictionary in _bolts:
		var since := t - float(b["delay"])
		if since < 0.0:
			continue
		var bands: Array = b["bands"]
		var pts := PackedVector3Array()
		for i in HELIX_SEGS + 1:
			pts.append(_helix_point(b, i, step, step_t, _stretch(b, since)))
		var grow_f := clampf(since / grow_time, 0.0, 1.0) * float(HELIX_SEGS)
		var eat_f := pow(clampf((since - hold * float(b["k"])) / (fade * float(b["k"])), 0.0, 1.0), 1.6) * float(HELIX_SEGS)
		for i in HELIX_SEGS:
			var band: Dictionary = bands[i]
			var r: MeshInstance3D = band["ribbon"]
			var mat: ShaderMaterial = band["mat"]
			var reveal := clampf(grow_f - float(i), 0.0, 1.0)
			var eaten := clampf((eat_f - float(i) + (_rnd(int(b["seed"]), i, 0) - 0.5) * 0.5) * 1.25, 0.0, 1.0)
			r.visible = reveal > 0.0 and eaten < 1.0
			if not r.visible:
				continue
			r.draw(PackedVector3Array([pts[i], pts[i + 1]]))
			mat.set_shader_parameter("reveal", 1.5 if reveal >= 1.0 else reveal)
			mat.set_shader_parameter("eaten", eaten if eaten > 0.0 else -1.0)
			mat.set_shader_parameter("phase", step_t)


# 消えた分だけ、螺旋の上半分を上へ伸ばす。根元から消えても、上が宙にぶら下がらず、上へ流れて消える
func _stretch(b: Dictionary, since: float) -> float:
	var p: float = pow(clampf((since - float(_timing["hold"]) * float(b["k"])) / (float(_timing["fade"]) * float(b["k"])), 0.0, 1.0), 1.6)
	return 1.0 + 0.35 * p


# 螺旋の i 番目の点。下が太く、上へ細る。上へ向かって回り、点は毎コマ少しだけ跳ねる
func _helix_point(b: Dictionary, i: int, step: int, step_t: float, stretch: float) -> Vector3:
	var u := float(i) / HELIX_SEGS
	var ang := float(b["phase0"]) + step_t * float(b["spin"]) + u * TAU * float(b["turns"])
	var r := float(b["radius"]) * (1.0 - 0.45 * u)
	if i > 0 and i < HELIX_SEGS:
		r *= 1.0 + (_rnd(int(b["seed"]), i, step) - 0.5) * 0.6
	var lift := (_rnd(int(b["seed"]) + 5, i, step) - 0.5) * 0.3 if (i > 0 and i < HELIX_SEGS) else 0.0
	return Vector3(cos(ang) * r, u * float(b["reach"]) * stretch + lift, sin(ang) * r)


# 炎の舌：根元から立ち上がり、供給が止まると根元から先へ消える（層ごとに少しずつ遅れる）
func _pose_flame(t: float) -> void:
	var grow_time: float = _timing["grow"]
	var hold: float = _timing["hold"]
	var fade: float = _timing["fade"]
	for b: Dictionary in _bolts:
		var since := t - float(b["delay"])
		var up := ease_out(clampf(since / grow_time, 0.0, 1.0))
		var layers: Array = b["layers"]
		for li in layers.size():
			var pair: Array = layers[li]
			var layer: MeshInstance3D = pair[0]
			var gone := clampf((since - hold - 0.1 * float(li)) / fade, 0.0, 1.0)
			layer.visible = since >= 0.0 and up > 0.01 and gone < 1.0
			param(layer, "grow", up)
			# wisp の根元の境界は eaten × 1.35 なので、0.74 で根元の全域が消え切る。そのまま渡すと 0.74 付近で一斉に消えるため、0.74 を掛けて連続的に食われるようにする
			param(layer, "eaten", gone * 0.74)
			param(layer, "phase", t)


# 炎の舌の筒を作り直す（電気ではないので、コマごとに形が揺れる）
func _rebuild(b: Dictionary, step: int, t: float) -> void:
	var pts := _tongue(b, step, t)
	if pts.size() < 2:
		return
	var layers: Array = b["layers"]
	for pair: Array in layers:
		var layer: MeshInstance3D = pair[0]
		layer.mesh = Lib.path_tube(pts, float(pair[1]) * float(b["radius"]) * _size, 1.0, 10)


# 炎の舌：根元から立ち上がり、横へ揺れ、節ごとにちらつく
func _tongue(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var sd: int = b["seed"]
	var reach: float = b["reach"]
	var root: Vector3 = b["root"]
	var n := 16
	# 消えた分だけ上へ流す：根元が食われた後も、上の舌は昇りながら消える（宙に止まらない）
	var lift := clampf((t - float(b["delay"]) - float(_timing["hold"])) / float(_timing["fade"]), 0.0, 1.0) * 0.6 * reach * _size
	for i in n + 1:
		var u := float(i) / n
		var h := u * reach
		var sway := sin(h * 2.6 + t * 5.0 + float(sd)) * 0.3 * h * _size
		var jag := (_rnd(sd, i, step) - 0.5) * 0.25 * _size
		pts.append(root + Vector3(sway + jag, h + lift * u, jag * 0.6))
	return pts


# 決まった入力から、0〜1の乱数を作る（同じ条件なら同じ値）
static func _rnd(sd: int, i: int, step: int) -> float:
	return fposmod(sin(float(sd) * 12.9898 + float(i) * 78.233 + float(step) * 37.719) * 43758.5453, 1.0)
