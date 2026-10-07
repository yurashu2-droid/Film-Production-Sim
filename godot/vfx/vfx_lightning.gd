extends "res://vfx/vfx_base.gd"
# 落雷。細い先行放電が空から降りてきて（予兆）、地面に届いた瞬間に太い本流が走り、
# 明滅しながら消える。地面には輪・火花・這う放電・小さな煙を残す。
# pos は落ちる地点。size は太さと地面の広がり、height は稲妻の高さ（m）。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")

const LEAD := 0.2                 # 先行放電が降りてくる秒数
const BLUE := Color(3, 5, 13)
# 本流の明るさの移り変わり（再放電で2回光り直す）
const FLICKER: Array[float] = [1.0, 1.0, 0.25, 0.9, 0.9, 0.2, 0.7, 0.5, 0.3, 0.15, 0.0]
const FLICKER_SEC := 0.42
const ARC_SEC := 0.45

var _size := 1.0
var _base: Vector3
var _path: PackedVector3Array
var _bolts: Array[MeshInstance3D] = []     # 本流と枝
var _shapes: Array[PackedVector3Array] = []
var _arcs: Array[MeshInstance3D] = []
var _arc_dirs: Array[Vector3] = []
var _step := -1
var _arc_tick := 0


static func strike(parent: Node, pos: Vector3, size: float = 1.0, height: float = 14.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, height)
	return fx


func start(size: float, height: float) -> void:
	_size = size
	_base = global_position
	life = 1.7
	var top := _base + Vector3(randf_range(-0.25, 0.25) * height, height, randf_range(-0.25, 0.25) * height)
	_path = _bolt(top, _base, 0.16, 5)
	# 予兆：細く暗い筋が降りてきて、落ちる地点がうっすら光る
	var leader := _ribbon(0.09 * size, Color(2, 3, 8, 0.7), 0.0)
	leader.draw(_path)
	var spot := sprite(0, BLUE, 0.1, false)
	spot.position.y = 0.05
	spot.rotation.x = -PI / 2.0
	over(0.0, LEAD, func(k: float) -> void:
		param(leader, "reveal", k)
		param(leader, "fade", 0.6 + 0.4 * sin(age * 120.0))
		spot.scale = Vector3.ONE * size * lerpf(0.4, 2.4, k)
		param(spot, "color", Color(BLUE.r, BLUE.g, BLUE.b, k * 0.6))
	)
	at(LEAD, func() -> void:
		leader.queue_free()
		_strike(spot)
	)


func _strike(spot: MeshInstance3D) -> void:
	var t0 := age
	# 本流と、途中から分かれる枝
	_add_bolt(_path, 0.6 * _size, 0.0)
	for i in 3:
		var from := _path[randi_range(7, 24)]
		var reach := (from.y - _base.y) * randf_range(0.35, 0.6)
		var out := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU) * reach * 0.6 + Vector3.DOWN * reach * 0.7
		_add_bolt(_bolt(from, from + out, 0.2, 4), 0.26 * _size, 0.9)
	var light := lamp(Color(0.7, 0.8, 1.0), 22.0 * _size)
	light.position.y = 2.0
	over(t0, FLICKER_SEC, func(k: float) -> void:
		var step := mini(int(k * FLICKER.size()), FLICKER.size() - 1)
		if step != _step:
			# 光り直すたびに、形を少しだけ変える
			if _step >= 0 and FLICKER[step] > FLICKER[_step]:
				for j in _bolts.size():
					_bolts[j].draw(_jitter(_shapes[j], 0.12 * _size))
			_step = step
		for bolt in _bolts:
			param(bolt, "fade", FLICKER[step])
		light.light_energy = 40.0 * _size * FLICKER[step]
	)
	at(t0 + FLICKER_SEC + 0.01, func() -> void:
		for bolt in _bolts:
			bolt.queue_free()
		_bolts.clear()
		light.queue_free()
	)

	# 着地点：閃光、地面を走る輪、跳ね上がる火花
	var flash := sprite(2, Color(6, 7, 10), _size)
	flash.position.y = 0.6
	param(flash, "toward_camera", _size * 2.2)
	over(t0, 0.14, func(k: float) -> void:
		flash.scale = Vector3.ONE * _size * lerpf(2.0, 4.5, ease_out(k))
		param(flash, "color", Color(6, 7, 10, 1.0 - k * k))
	)
	at(t0 + 0.15, flash.queue_free)
	var wave := sprite(1, BLUE, _size, false)
	wave.position.y = 0.06
	wave.rotation.x = -PI / 2.0
	over(t0, 0.35, func(k: float) -> void:
		wave.scale = Vector3.ONE * _size * lerpf(0.4, 5.5, ease_out(k))
		param(wave, "ring_width", lerpf(0.25, 0.05, k))
		param(wave, "color", Color(BLUE.r, BLUE.g, BLUE.b, 1.0 - k))
	)
	at(t0 + 0.36, wave.queue_free)
	over(t0, 0.9, func(k: float) -> void:
		spot.scale = Vector3.ONE * _size * lerpf(3.2, 2.0, k)
		param(spot, "color", Color(BLUE.r, BLUE.g, BLUE.b, pow(1.0 - k, 2.0)))
	)
	emit(Lib.particles(Lib.streak_mesh(), Lib.material("spark"), Lib.process({
		"direction": Vector3.UP,
		"spread": 75.0,
		"initial_velocity_min": 4.0 * _size,
		"initial_velocity_max": 11.0 * _size,
		"gravity": Vector3(0, -12, 0),
		"damping_min": 1.0,
		"damping_max": 3.0,
		"particle_flag_align_y": true,
		"scale_min": 0.15 * _size,
		"scale_max": 0.4 * _size,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.6, 0.7], [1.0, 0.0]]),
		"lifetime_randomness": 0.5,
		"color_ramp": Lib.ramp([[0.0, Color(9, 10, 12)], [0.4, Color(2, 4, 11)], [1.0, Color(0.3, 0.5, 3)]]),
	}), 40, 0.7), 0.0, Vector3(0, 0.1, 0))
	# 地面を這う放電。_tick で数コマごとに形を作り直して、ちらつかせる
	for i in 5:
		_arcs.append(_ribbon(0.12 * _size, BLUE, 0.7))
		_arc_dirs.append(Vector3.RIGHT.rotated(Vector3.UP, TAU * (i + randf() * 0.7) / 5.0) * randf_range(1.3, 2.7) * _size)
	at(t0 + ARC_SEC, func() -> void:
		for arc in _arcs:
			arc.queue_free()
		_arcs.clear()
	)
	# 焦げた地面から上がる煙
	emit(Lib.particles(Lib.cloud_mesh(1), Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "edge_color": Vector3(1.0, 2.0, 6.0)}), Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.3 * _size,
		"direction": Vector3.UP,
		"spread": 35.0,
		"initial_velocity_min": 0.8 * _size,
		"initial_velocity_max": 1.8 * _size,
		"damping_min": 1.0,
		"damping_max": 2.0,
		"gravity": Vector3(0, 0.4, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.4 * _size,
		"scale_max": 0.7 * _size,
		"scale_curve": Lib.curve([[0.0, 0.3], [0.3, 1.0], [1.0, 0.9]]),
		"color_ramp": Lib.ramp([[0.0, Color(4, 6, 12, 1)], [0.12, Color(0.35, 0.4, 0.6, 1)], [0.5, Color(0.26, 0.28, 0.36, 0.85)], [1.0, Color(0.22, 0.23, 0.3, 0)]]),
	}), 6, 1.1), 0.05, Vector3(0, 0.3 * _size, 0))


func _tick(_delta: float) -> void:
	if _arcs.is_empty():
		return
	_arc_tick += 1
	if _arc_tick % 3 != 1:
		return
	for i in _arcs.size():
		var to := _base + _arc_dirs[i] * randf_range(0.6, 1.0)
		var points := _bolt(_base + Vector3(0, 0.08, 0), to + Vector3(0, 0.08, 0), 0.14, 3)
		for j in points.size():
			points[j].y = maxf(points[j].y, _base.y + 0.04)
		_arcs[i].draw(points)
		param(_arcs[i], "fade", randf_range(0.4, 1.0))


func _ribbon(width: float, color: Color, taper: float) -> MeshInstance3D:
	var r: MeshInstance3D = Ribbon.new()
	r.material_override = Lib.material("ribbon", {
		"noise_texture": Lib.noise("soft"),
		"width": width,
		"color_head": color,
		"color_tail": color,
		"core_color": Vector3(10, 10, 11),
		"core": 0.3,
		"taper": taper,
		"erosion": 0.0,
	})
	add_child(r)
	return r


func _add_bolt(shape: PackedVector3Array, width: float, taper: float) -> void:
	var r := _ribbon(width, BLUE, taper)
	r.draw(shape)
	_bolts.append(r)
	_shapes.append(shape)


# 2点の間を、中点をずらしながら細かく折っていく（稲妻のぎざぎざ）
static func _bolt(a: Vector3, b: Vector3, rough: float, levels: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var amp := a.distance_to(b) * rough
	for level in levels:
		var next := PackedVector3Array()
		for i in pts.size() - 1:
			next.append(pts[i])
			next.append((pts[i] + pts[i + 1]) * 0.5 + Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * amp)
		next.append(pts[pts.size() - 1])
		pts = next
		amp *= 0.52
	return pts


static func _jitter(shape: PackedVector3Array, amount: float) -> PackedVector3Array:
	var out := shape.duplicate()
	for i in range(1, out.size() - 1):
		out[i] += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * amount
	return out
