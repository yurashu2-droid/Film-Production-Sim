extends "res://vfx/vfx_base.gd"
# 素材：加圧された墨。亀裂→上昇する薄い杯→不揃いな五本の舌→落水膜→吸収。
# 先行：噴流の腹・金の流路。遅れ：黒い厚い縁と下流の膜。
# 0.55s 一本の肩が先に開く。1.2s 三本目の首が移り、1.8s 高い舌が巻き返す。
# 3.0s 供給停止。金は先に出口へ運ばれ、黒の先端は重力で落ち続ける。
# 層の出口：白3.0→4.36 / 金3.0→4.53 / 黒3.0→4.70。地表膜は5.18まで下流へ吸収。
# 描画は毎フレーム22x12の連続した薄い殻。寿命ノイズ穴消しは0層。

const DIRECTIONS := [-0.4, 0.77, 2.42, 3.55, 4.88]
const DELAYS := [0.0, 0.17, 0.43, 0.11, 0.62]
const HEIGHTS := [3.30, 2.64, 3.06, 2.3, 3.38]
const TRAVEL := [1.62, 1.49, 1.68, 1.42, 1.70]
const WIDTHS := [1.02, 0.92, 1.08, 0.88, 0.97]
const RATIOS := [1.0, 0.24, 0.075]
const COLORS := [Vector3(0.018, 0.013, 0.023), Vector3(0.72, 0.43, 0.09), Vector3(1.9, 1.72, 1.29)]
var _size := 1.0
var _tongues: Array = []
var _films: Array = []

static func spawn(parent: Node, ground: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	return fx

func start(size: float) -> void:
	_size = size
	life = 5.7
	for i in 5:
		var layers: Array = []
		for k in 3:
			layers.append(_layer(COLORS[k], float(i) * 0.67 + float(k) * 0.31, 0.68 if k == 0 else 0.65, 0.0 if k == 0 else 0.10))
		_tongues.append(layers)
		_films.append(_layer(Vector3(0.026, 0.018, 0.032), float(i) * 0.7, 0.56, 0.0))
	_pose(0.0)

func _layer(color: Vector3, seed: float, cut: float, shine: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = Lib.material("ink_bloom_flow", {"grain": Lib.tex("noise_wo14.png"), "soft_grain": Lib.noise("soft"), "tint": color, "seed": seed, "sparsity": cut, "shine": shine})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _tick(_delta: float) -> void:
	_pose(age)

# Each point is a material parcel at a different flight age, not a scaled flower.
func _point(i: int, u: float, t: float, k: int) -> Vector3:
	var flight: float = TRAVEL[i]
	var launch := t - u * flight
	var a: float = DIRECTIONS[i] + 0.32 * sin(launch * 2.1 + float(i)) * u
	a += (0.82 if i % 2 == 0 else -0.68) * smoothstep(0.46, 0.94, u)
	# Broad open shoulder, then a rolled-over lip that bends under the shoulder.
	var radius := 0.11 + 2.04 * smoothstep(0.03, 0.60, u)
	radius -= 0.54 * sin(smoothstep(0.56, 0.96, u) * PI)
	radius += 0.35 * smoothstep(0.80, 1.0, u)
	radius += 0.26 * sin(u * 6.1 + launch * 2.7 + float(i)) * sin(PI * u)
	var crest: float = HEIGHTS[i] * (1.0 + 0.13 * sin(launch * 3.2 + float(i)))
	var h := 0.035 + crest * sin(minf(u / 0.57, 1.0) * PI * 0.5)
	if u > 0.57:
		var fall := (u - 0.57) / 0.43
		h = 0.035 + crest * (1.0 - fall * fall)
	# Late parcels topple past the crest; the high front never folds back to the source.
	h -= 0.38 * smoothstep(2.9, 3.65, t) * smoothstep(0.45, 0.95, u)
	h = maxf(0.035, h)
	return Vector3(cos(a) * radius, h, sin(a) * radius + float(k) * 0.045) * _size

func _pose(t: float) -> void:
	for i in 5:
		for k in 3:
			var mi: MeshInstance3D = _tongues[i][k]
			var travel: float = TRAVEL[i] - float(k) * 0.17
			var front := clampf((t - DELAYS[i]) / travel, 0.0, 1.0)
			var tail := clampf((t - 3.0) / travel, 0.0, 1.0)
			mi.visible = front > tail + 0.008 and t < 3.0 + travel
			if mi.visible:
				var points := PackedVector3Array()
				var widths := PackedFloat32Array()
				for j in 22:
					var v := float(j) / 21.0
					var u := lerpf(tail, front, v)
					points.append(_point(i, u, t, k))
					var shoulder := 0.71 + 0.49 * exp(-pow((u - (0.51 + 0.20 * sin(t * 2.4 + float(i)))) / 0.20, 2.0))
					var edge := pow(sin(PI * v), 0.13)
					var accent := 1.0
					if k > 0:
						accent = 0.07 + 0.93 * exp(-pow((u - (0.39 + 0.30 * sin(t * 1.6 + float(i)))) / 0.25, 2.0))
					widths.append(maxf(0.005, shoulder * edge * (0.70 + 0.44 * sin(PI * u)) * accent))
				mi.mesh = _shell(points, widths, WIDTHS[i] * RATIOS[k] * _size, 0.43)
				param(mi, "phase", t + float(k) * 0.31)
		# Impact transforms each airborne tongue into an uneven downstream film.
		var film: MeshInstance3D = _films[i]
		var supplied := clampf((t - 1.40 - DELAYS[i]) / 0.65, 0.0, 1.0)
		var absorbed := clampf((t - 4.35 - float(i) * 0.07) / 0.54, 0.0, 1.0)
		film.visible = supplied > absorbed + 0.01
		if film.visible:
			var p := PackedVector3Array()
			var w := PackedFloat32Array()
			for j in 15:
				var v := float(j) / 14.0
				var u := lerpf(absorbed, supplied, v)
				var a: float = DIRECTIONS[i] + 0.18 * sin(u * 4.0 + float(i))
				var r := 0.4 + u * 2.7 + 0.13 * maxf(t - 2.0, 0.0)
				p.append(Vector3(cos(a) * r, 0.026 + float(i) * 0.002, sin(a) * r) * _size)
				w.append(maxf(0.008, sin(PI * v) * (0.5 + 0.26 * sin(u * 7.0 + t))))
			film.mesh = _shell(p, w, 0.58 * _size, 0.018)
			param(film, "phase", t * 0.32)

func _shell(points: PackedVector3Array, widths: PackedFloat32Array, radius: float, depth_ratio: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var side := Vector3.RIGHT
	for j in points.size():
		var tangent := (points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)]).normalized()
		if j == 0:
			side = tangent.cross(Vector3.UP).normalized()
			if side.length_squared() < 0.01:
				side = Vector3.RIGHT
		else:
			side = (side - tangent * side.dot(tangent)).normalized()
		var depth := tangent.cross(side).normalized()
		for s in 13:
			var a := float(s) / 12.0 * TAU
			vertices.append(points[j] + (side * cos(a) + depth * sin(a) * depth_ratio) * radius * widths[j])
			uv.append(Vector2(float(s) / 12.0, float(j) / float(points.size() - 1)))
	for j in points.size() - 1:
		for s in 12:
			var n := j * 13 + s
			indices.append_array(PackedInt32Array([n, n + 13, n + 1, n + 1, n + 13, n + 14]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
