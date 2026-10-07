extends "res://pixel_vfx/px_base.gd"
# ドット絵のポータル。ドット絵の輪を4枚、奥へずらして重ねる（本物の奥行きがあるので、見る角度で層がずれる）。
# 外の輪は粗く暗くゆっくり、内の輪は細かく明るく速い。1枚おきに逆回り。いちばん奥は、星のまたたく闇。
# ふちをボクセルが回り、色の光で床を照らす。
#   開く   奥の闇から順に、1枚ずつ弾むように広がる
#   閉じる 外の輪から順に、区画ごとに点滅して消える。最後に闇が縮み、星がひとつ瞬く
# 立った向き（+Z を向く）で出る。寝かせたいときは、出したあとで回す。

# 外 → 内：[解像度, 内径, 外径, 回る速さ, 奥へずらす量, 色の明るさ]
const RINGS := [
	[40.0, 0.66, 0.99, 0.7, 0.0, 0.45],
	[52.0, 0.52, 0.88, -1.1, -0.14, 0.7],
	[60.0, 0.38, 0.74, 1.6, -0.28, 1.0],
	[64.0, 0.22, 0.58, -2.3, -0.42, 1.35],
]
const ORBIT := 14

var _size := 1.0
var _hold := 3.0
var _colors: Array = []
var _rings: Array[MeshInstance3D] = []
var _void: MeshInstance3D
var _star: MeshInstance3D
var _bits: MultiMesh
var _light: OmniLight3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, seconds: float = 3.0, palette_name: String = "arcane") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, seconds, palette_name)
	return fx


func start(size: float, seconds: float, palette_name: String) -> void:
	_size = size
	_hold = seconds
	_colors = palette(palette_name)
	life = 0.7 + seconds + 1.3
	for i in RINGS.size():
		var r: Array = RINGS[i]
		var tones: Array = []
		for c: Vector3 in _colors:
			tones.append(c * float(r[5]))
		var mi := quad(material("px_polar", tones, {"mode": 0, "res": r[0], "inner": r[1], "outer": r[2], "spin": r[3], "seed": i * 3.7, "density": 0.5 + 0.08 * i}), Vector2.ONE * 3.2 * size)
		mi.position.z = float(r[4]) * size
		_rings.append(mi)
	_void = quad(material("px_polar", _colors, {"mode": 2, "res": 36.0, "outer": 0.62}), Vector2.ONE * 3.2 * size)
	_void.position.z = -0.56 * size
	_star = quad(material("px_blob", [], {"mode": 1, "res": 16.0, "color": _colors[4]}), Vector2.ONE * 1.6 * size)
	_star.visible = false
	_bits = voxels(ORBIT, 4.0 * size)
	_light = lamp(_colors[3], 8.0 * size)
	_light.position.z = 0.6 * size
	_step(0.0)


func _step(t: float) -> void:
	var out := t - 0.7 - _hold
	# 開く：奥から順に、行き過ぎてから戻る
	var deep := clampf(t / 0.25, 0.0, 1.0)
	_void.scale = Vector3.ONE * (deep * (1.0 - clampf((out - 0.6) / 0.3, 0.0, 1.0)))
	_void.visible = _void.scale.x > 0.02
	param(_void, "phase", t)
	for i in _rings.size():
		var ring := _rings[i]
		var open := clampf((t - 0.08 - (3 - i) * 0.1) / 0.3, 0.0, 1.0)
		var bounce := 1.0 + 0.18 * sin(open * PI) if open < 1.0 else 1.0
		ring.scale = Vector3.ONE * maxf(ease_out(open) * bounce, 0.001)
		ring.visible = open > 0.0
		param(ring, "phase", t)
		# 閉じる：外の輪から順に、区画ごとに点滅して消える
		param(ring, "fill", 1.0 - clampf((out - i * 0.16) / 0.4, 0.0, 1.0))
	# ふちを回るボクセル
	var live := clampf(t / 0.6, 0.0, 1.0) * (1.0 - clampf(out / 0.5, 0.0, 1.0))
	for i in ORBIT:
		var a := i * TAU / ORBIT + t * (0.9 if i % 2 == 0 else -0.6)
		var r := (1.62 + 0.12 * sin(t * 3.0 + i)) * _size
		put(_bits, i, Vector3(cos(a) * r, sin(a) * r, 0.1 * _size * sin(i * 1.7)), (0.08 + 0.05 * (i % 3)) * _size * live, _colors[3], 1.5, 0.06 * _size)
	_light.light_energy = 3.0 * _size * live * (0.85 + 0.15 * sin(t * 9.0))
	# 最後に星がひとつ瞬く
	var blink := int(roundf((out - 0.92) * FPS))
	_star.visible = blink == 0 or blink == 1
	_star.scale = Vector3.ONE * (1.0 if blink == 0 else 0.5)
