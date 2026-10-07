extends "res://pixel_vfx/px_base.gd"
# ボクセルの転送（出現）。足元にドット絵の魔法陣が開き、光の柱が立ち、散らばった立方体が下から順に集まって人の形を組む。
# 組み上がった瞬間に閃光。そのあと立方体は上から順にほどけて消える（ここで本物のキャラクターを見せる想定）。
#   signal materialized  組み上がった瞬間。ここでキャラクターを表示する
#   魔法陣   同心の線・回る目盛り。最後は区画ごとに点滅して消える
#   光の柱   マスの列ごとに高さと速さが違う。最後は列がひとつずつ消える
# pos は足元。height は組み上げる体の高さ。

signal materialized

const BUILD := 0.45        # 立方体が集まりはじめる時刻
const READY := 1.55        # 組み上がる時刻

var _size := 1.0
var _colors: Array = []
var _rune: MeshInstance3D
var _beam: MeshInstance3D
var _flash: MeshInstance3D
var _body: MultiMesh
var _cells: Array = []     # [組み上がる位置, 出発する位置, 着く時刻]
var _grid := 0.14
var _tall := 1.7
var _light: OmniLight3D
var _fired := false


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, height: float = 1.7, palette_name: String = "ice") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, height, palette_name)
	return fx


func start(size: float, height: float, palette_name: String) -> void:
	_size = size
	_tall = height * size
	_grid = 0.14 * size
	_colors = palette(palette_name)
	life = 3.0
	_rune = quad(material("px_polar", _colors, {"mode": 1, "res": 64.0, "spin": 1.0}), Vector2.ONE * 3.0 * size)
	_rune.rotation.x = -PI / 2.0
	_rune.position.y = 0.03
	_beam = quad(material("px_beam", _colors, {"res": Vector2(22.0, 72.0), "seed": randf() * 9.0}), Vector2(1.5 * size, _tall * 1.9), Vector3(0, _tall * 0.95, 0))
	_flash = quad(material("px_blob", [], {"mode": 1, "res": 18.0, "color": Vector3(10, 10, 10)}), Vector2.ONE * 3.4 * size)
	_flash.position.y = _tall * 0.55
	_flash.visible = false
	# 人の形（カプセル）をマス目で埋める位置を作る
	var radius := 0.3 * size
	var y := _grid * 0.5
	while y < _tall:
		var round_off := minf(minf(y, _tall - y) / radius, 1.0)
		var reach := radius * sqrt(clampf(1.0 - pow(1.0 - round_off, 2.0), 0.0, 1.0))
		var x := -radius
		while x <= radius + 0.001:
			var z := -radius
			while z <= radius + 0.001:
				if Vector2(x, z).length() <= reach + 0.001:
					var far := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized() * randf_range(1.6, 3.4) * size
					_cells.append([Vector3(x, y, z), Vector3(x, y, z) + far, BUILD + y / _tall * 0.75 + randf_range(0.0, 0.2)])
				z += _grid
			x += _grid
		y += _grid
	_body = voxels(_cells.size(), 6.0 * size)
	_light = lamp(_colors[3], 7.0 * size)
	_light.position.y = _tall * 0.5
	_step(0.0)


func _step(t: float) -> void:
	# 魔法陣：開いて回り、最後は区画ごとに点滅して消える
	var open := ease_out(clampf(t / 0.3, 0.0, 1.0))
	_rune.scale = Vector3.ONE * maxf(open, 0.001)
	param(_rune, "phase", t)
	param(_rune, "fill", 1.0 - clampf((t - 2.25) / 0.6, 0.0, 1.0))
	# 光の柱：立ち上がり、組み上がったあと列がひとつずつ消える
	_beam.visible = t > 0.18 and t < 2.5
	param(_beam, "phase", t)
	param(_beam, "grow", ease_out(clampf((t - 0.18) / 0.3, 0.0, 1.0)))
	param(_beam, "close", clampf((t - READY - 0.25) / 0.6, 0.0, 1.0))
	# 立方体：遠くから飛んできて、下の段から順に収まる。組み上がったら、上の段から順にほどける
	var flashing := t >= READY and t < READY + 2.0 / FPS
	for i in _cells.size():
		var c: Array = _cells[i]
		var home: Vector3 = c[0]
		var arrive: float = c[2]
		var k := clampf((t - (arrive - 0.35)) / 0.35, 0.0, 1.0)
		var leave := clampf((t - (READY + 0.2 + (1.0 - home.y / _tall) * 0.45)) / 0.18, 0.0, 1.0)
		var undone: float = [1.0, 0.66, 0.33, 0.0][mini(int(leave * 3.99), 3)]
		var dia: float = _grid * 0.92 * (0.0 if k <= 0.0 else 1.0) * undone
		var tone: Vector3 = _colors[4] if flashing else (_colors[3] if k < 1.0 else _colors[1 + (i % 2)])
		put(_body, i, (c[1] as Vector3).lerp(home, ease_out(k)), dia, tone, (1.5 if flashing else 0.5) if flashing or k < 1.0 else 0.08, _grid if k >= 1.0 else _grid * 0.5)
	_flash.visible = flashing
	_light.light_energy = (10.0 if flashing else 2.5) * _size * open * (1.0 - clampf((t - 2.2) / 0.5, 0.0, 1.0))
	if t >= READY and not _fired:
		_fired = true
		materialized.emit()
