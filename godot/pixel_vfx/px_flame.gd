extends "res://pixel_vfx/px_base.gd"
# ドット絵の炎。3枚の層（奥：粗く暗い／中：本体／手前：小さく明るい芯）を重ね、本物の光で地面を照らす。
# 火の粉はボクセル。消すと、炎がしぼみ、ドット絵の煙玉が3つ昇って薄れる。
# seconds が 0 以下なら extinguish() を呼ぶまで燃え続ける。

var _size := 1.0
var _colors: Array = []
var _layers: Array[MeshInstance3D] = []
var _glow: MeshInstance3D
var _embers: MultiMesh
var _light: OmniLight3D
var _fuel := 0.0
var _dying := false


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, seconds: float = -1.0, palette_name: String = "fire") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, seconds, palette_name)
	return fx


func start(size: float, seconds: float, palette_name: String) -> void:
	_size = size
	_colors = palette(palette_name)
	life = 0.0
	# [解像度, 大きさ, 昇る速さ, 色の明るさ, 手前へ寄せる量]
	for layer: Array in [[30.0, 1.3, 6.0, 0.5, -0.08], [48.0, 1.0, 9.0, 1.0, 0.0], [26.0, 0.55, 13.0, 1.5, 0.08]]:
		var tones: Array = []
		for c: Vector3 in _colors:
			tones.append(c * float(layer[3]))
		var mat := material("px_fire", tones, {"res": layer[0], "rise": layer[2], "seed": randf() * 20.0, "nudge": float(layer[4]) * size, "fuel": 0.0})
		var mi := quad(mat, Vector2(1.3, 1.7) * size * float(layer[1]), Vector3(0, 0.82 * size * float(layer[1]), 0))
		_layers.append(mi)
	var mid: Vector3 = _colors[2]
	_glow = quad(material("px_blob", [], {"mode": 2, "res": 20.0, "lie_flat": true, "color": mid * 0.5}), Vector2.ONE * 2.6 * size)
	_glow.rotation.x = -PI / 2.0
	_glow.position.y = 0.02
	_embers = voxels(10, 4.0 * size)
	_light = lamp(mid, 6.0 * size)
	_light.position.y = 0.7 * size
	over(0.0, 0.3, func(k: float) -> void: _fuel = k)
	if seconds > 0.0:
		at(seconds, extinguish)
	_step(0.0)


func extinguish() -> void:
	if _dying:
		return
	_dying = true
	over(age, 0.45, func(k: float) -> void: _fuel = 1.0 - k)
	# 煙玉：3つ、時刻をずらして昇り、網点で薄れる
	for i in 3:
		at(age + 0.3 + i * 0.16, func() -> void:
			var puff := quad(material("px_blob", [], {"mode": 0, "res": 14.0, "seed": randf() * 9.0}), Vector2.ONE * (0.55 - 0.1 * i) * _size)
			var from := Vector3(randf_range(-0.15, 0.15), 0.5 + 0.15 * i, 0) * _size
			var born := age
			over(born, 0.9, func(k: float) -> void:
				var kk := floorf(k * 10.0) / 10.0
				puff.position = from + Vector3(0.08 * sin(kk * 6.0), kk * 1.3, 0) * _size
				param(puff, "fade", kk)
			)
			at(born + 0.92, puff.queue_free)
		)
	life = age + 2.0


func _step(t: float) -> void:
	for mi in _layers:
		param(mi, "phase", t)
		param(mi, "fuel", _fuel)
		mi.visible = _fuel > 0.02
	var mid: Vector3 = _colors[3]
	for i in _embers.instance_count:
		var cycle := fposmod(t * 0.55 + i * 0.1, 1.0)
		var pos := Vector3(sin(i * 2.4 + cycle * 3.0) * 0.3, 0.3 + cycle * 2.0, cos(i * 1.7 + cycle * 2.0) * 0.3) * _size
		put(_embers, i, pos, 0.07 * _size * (1.0 - cycle) * (1.0 if _fuel > 0.5 and not _dying else 0.0), mid, 2.0, 0.05 * _size)
	param(_glow, "fade", 1.0 - _fuel * (0.8 + 0.2 * sin(t * 20.0)))
	_light.light_energy = 2.2 * _size * _fuel * (0.8 + 0.2 * sin(t * 31.0) * sin(t * 13.0))
