extends "res://pixel_vfx/px_base.gd"
# ボクセルの爆発。立方体の粒がマス目に沿って球状に弾け、白 → 黄 → 橙 → 赤 → 煤と冷めながら、段階的に縮んで消える。
# 立方体には本物の陰影が付き、自分でも光る。ドット絵の閃光と、地面を走る輪が添う。
#   0〜2コマ   ドット絵の閃光
#   本体       64個の粒が、遅れをずらして外へ。熱いうちは強く光る
#   破片       小さな粒が放物線で飛び、地面で1回はねる
#   輪         地面のドット絵の輪が広がり、区画ごとに点滅して消える
#   煙         灰色の粒が遅れて昇り、段階的に縮む
# ground_drop は中心から地面までの距離。

const SHELL := 64
const DEBRIS := 18
const SMOKE := 10

var _size := 1.0
var _drop := 1.0
var _colors: Array = []
var _cubes: MultiMesh
var _seeds: Array = []
var _flash: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, ground_drop: float = 1.0, palette_name: String = "fire") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, ground_drop, palette_name)
	return fx


func start(size: float, ground_drop: float, palette_name: String) -> void:
	_size = size
	_drop = ground_drop
	_colors = palette(palette_name)
	life = 2.4
	_cubes = voxels(SHELL + DEBRIS + SMOKE, 9.0 * size)
	for i in SHELL:
		var y := 1.0 - 2.0 * (i + 0.5) / SHELL
		var ring := sqrt(1.0 - y * y)
		var a := i * 2.39996
		# [向き, 遅れ, 届く距離, 大きさ, 寿命]
		_seeds.append([Vector3(cos(a) * ring, y * 0.8 + 0.15, sin(a) * ring).normalized(), randf_range(0.0, 0.12), randf_range(1.1, 2.7), randf_range(0.22, 0.5), randf_range(0.55, 1.05)])
	for i in DEBRIS:
		_seeds.append([Vector3(randf_range(-1, 1), randf_range(0.5, 1.6), randf_range(-1, 1)).normalized() * randf_range(4.0, 8.5), 0.0, 0.0, randf_range(0.1, 0.2), randf_range(0.9, 1.5)])
	for i in SMOKE:
		_seeds.append([Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7)), randf_range(0.3, 0.6), randf_range(1.2, 2.2), randf_range(0.3, 0.55), randf_range(1.0, 1.5)])
	_flash = quad(material("px_blob", [], {"mode": 1, "res": 18.0, "color": Vector3(10, 10, 9)}), Vector2.ONE * 4.2 * size)
	_ring = quad(material("px_polar", _colors, {"mode": 0, "res": 56.0, "inner": 0.72, "outer": 0.98, "spin": 2.0, "bands": 8.0, "density": 0.75}), Vector2.ONE)
	_ring.rotation.x = -PI / 2.0
	_ring.position.y = -ground_drop + 0.03
	_light = lamp(_colors[3], 11.0 * size)
	_step(0.0)


func _step(t: float) -> void:
	var grid := 0.13 * _size
	_flash.visible = t < 2.0 / FPS
	_light.light_energy = 12.0 * _size * pow(maxf(0.0, 1.0 - t / 1.0), 2.0)
	# 輪：コマごとに広がり、後半は区画ごとに点滅して消える
	var spread := ease_out(clampf(t / 0.5, 0.0, 1.0))
	_ring.visible = t < 0.95
	_ring.scale = Vector3.ONE * _size * lerpf(1.0, 8.0, spread)
	param(_ring, "phase", t)
	param(_ring, "fill", 1.0 - smoothstep(0.35, 0.95, t))
	for i in SHELL:
		var s: Array = _seeds[i]
		var k: float = (t - float(s[1])) / float(s[4])
		if k < 0.0 or k >= 1.0:
			put(_cubes, i, Vector3.ZERO, 0.0, Vector3.ONE, 0.0, grid)
			continue
		var reach: float = float(s[2]) * ease_out(minf(k * 2.4, 1.0)) + k * 0.4
		# 冷めていく色。熱いうちだけ強く光る
		var tone: Vector3 = _colors[4]
		if k > 0.14:
			tone = _colors[3]
		if k > 0.3:
			tone = _colors[2]
		if k > 0.48:
			tone = _colors[1]
		if k > 0.66:
			tone = Vector3(0.16, 0.13, 0.12)
		var shrink: float = [1.0, 1.0, 1.0, 0.66, 0.33][mini(int(k * 5.0), 4)]
		put(_cubes, i, (s[0] as Vector3) * reach * _size + Vector3.UP * k * 0.5 * _size, float(s[3]) * shrink * _size, tone, 1.2 if k < 0.66 else 0.0, grid)
	for j in DEBRIS:
		var i := SHELL + j
		var s: Array = _seeds[i]
		var k: float = t / float(s[4])
		var pos: Vector3 = (s[0] as Vector3) * t * _size + Vector3.DOWN * 7.0 * t * t * _size
		# 地面より下へ行ったら、小さくはね返す
		var under := -_drop - pos.y
		if under > 0.0:
			pos.y = -_drop + minf(under * 0.35, 0.5 * _size)
		put(_cubes, i, pos, float(s[3]) * _size * (1.0 if k < 0.7 else (0.5 if k < 0.85 else 0.0)) * (1.0 if t > 1.0 / FPS and k < 1.0 else 0.0), _colors[2] if k < 0.4 else Vector3(0.14, 0.11, 0.1), 1.0 if k < 0.4 else 0.0, grid * 0.5)
	for j in SMOKE:
		var i := SHELL + DEBRIS + j
		var s: Array = _seeds[i]
		var k: float = (t - float(s[1])) / float(s[4])
		var shrink: float = [0.6, 1.0, 1.0, 0.66, 0.33][clampi(int(k * 5.0), 0, 4)]
		put(_cubes, i, (s[0] as Vector3) * _size + Vector3.UP * (0.3 + float(s[2]) * k) * _size, float(s[3]) * shrink * _size * (1.0 if k >= 0.0 and k < 1.0 else 0.0), Vector3(0.22, 0.2, 0.2) * (1.0 + 0.3 * (j % 3)), 0.0, grid)
