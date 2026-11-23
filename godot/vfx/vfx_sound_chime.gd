extends "res://vfx/vfx_base.gd"
# 素材：高い打音で空気に立つ共鳴膜。先行は倍音の腹、遅れは暗い外膜。
# 0.50s主打撃→0.83s高い倍音→1.40s二音目→2.25s短い装飾音。
# 0.8s 上の肩が開く／1.5s 干渉の腹が上へ移る／2.3s 首で二股になり結び直す。
# 3.1sから間。外膜は先に前方へ剥がれ、真珠色が上へ流れ、短い白芯が最後に同方向へ出る。
# 曲線と局所幅を毎フレーム再構築。静的レーザー・棒・音符なし。寿命穴消し0層。
const STRIKES := [0.50, 0.83, 1.40, 2.25]
const ENDS := [4.62, 4.30, 4.84, 5.04]
const RATIOS := [1.0, 0.60, 0.16]
const COLORS := [Vector3(0.065, 0.041, 0.16), Vector3(0.62, 0.71, 0.80), Vector3(1.5, 1.42, 1.26)]
var _size := 1.0
var _packets: Array = []

static func spawn(parent: Node, ground: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	preload("res://vfx/vfx_sound_score.gd").attach(fx, "sound_chime")
	return fx

func start(size: float) -> void:
	_size = size
	life = 5.6
	for i in 4:
		var layers: Array = []
		for k in 3:
			var mi := MeshInstance3D.new()
			var color: Vector3 = COLORS[k]
			if k == 1:
				color = Vector3(0.70, 0.59, 0.80) if i % 2 == 0 else Vector3(0.40, 0.77, 0.84)
			mi.material_override = Lib.material("sound_chime_flow", {"grain": Lib.tex("noise_wo14.png"), "tint": color, "seed": float(i) * 0.77 + float(k) * 0.26, "sparsity": 0.63 if k == 0 else 0.56, "shine": 0.18 if k == 0 else 0.35})
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			layers.append(mi)
		_packets.append(layers)
	_pose(0.0)

func _tick(_delta: float) -> void:
	_pose(age)

func _pose(t: float) -> void:
	for i in 4:
		var dt: float = t - STRIKES[i]
		var ring := maxf(dt, 0.0)
		var release := smoothstep(3.12 + float(i) * 0.16, ENDS[i], t)
		for k in 3:
			var mi: MeshInstance3D = _packets[i][k]
			var ending: float = ENDS[i] - (0.22 if k == 0 else (0.10 if k == 1 else 0.0))
			# A finite material train travels through the medium. Its tail follows
			# the leading crest after a short strike; no full-height S is held.
			var rate := 0.66 + float(i) * 0.065
			var front := maxf(0.0, dt * rate)
			var packet_length := (0.62 if i % 2 == 0 else 0.47) - float(k) * 0.035
			var tail := maxf(0.0, front - packet_length)
			mi.visible = dt > 0.0 and tail + 0.01 < front and t < ending
			if not mi.visible:
				continue
			var points := PackedVector3Array()
			var widths := PackedFloat32Array()
			var tempo := 2.30 + float(i) * 0.47
			for j in 27:
				var v := float(j) / 26.0
				var u := lerpf(tail, front, v)
				var phase := u * (7.6 + float(i) * 0.61) - ring * tempo * 0.48 + float(i) * 1.19
				# Unequal harmonics move interference shoulders/neck instead of equalizer bars.
				var anti := sin(phase) * 0.72 + sin(u * 10.9 + ring * (tempo * 0.73) + float(i)) * 0.24
				var quiver := 0.035 * sin(ring * (21.0 + float(i) * 2.0) - u * 8.0) * exp(-ring * 1.1)
				var x := anti * (0.56 + 0.24 * sin(phase * 0.67)) + quiver
				var y := 0.10 + u * 3.15 + 0.14 * sin(phase * 1.4) * sin(PI * v)
				var z := -0.62 + float(i) * 0.38 + 0.30 * cos(phase * 0.78 + float(i))
				# Supply clears bottom first. Existing wave crests move forward and upward.
				x += release * (0.50 + float(i) * 0.15)
				y += release * release * (1.55 + float(i) * 0.18)
				z -= release * (1.22 + float(i) * 0.12)
				points.append(Vector3(x, y, z + float(k) * 0.055) * _size)
				var shoulder := 0.62 + 0.17 * sin(ring * tempo + float(i))
				var belly := 0.11 + 0.88 * exp(-pow((v - shoulder) / 0.19, 2.0))
				belly += 0.44 * exp(-pow((v - 0.20 - 0.08 * sin(ring * 3.5)) / 0.11, 2.0))
				var neck := 1.0 - 0.69 * exp(-pow((v - 0.40 - 0.06 * sin(ring * tempo)) / 0.075, 2.0))
				var edge := pow(sin(PI * v), 0.33)
				# The white core exists only in a short moving antinode.
				var core := 1.0
				if k == 2:
					core = exp(-pow((v - shoulder) / 0.085, 2.0))
				widths.append(maxf(0.003, edge * belly * neck * core))
			mi.mesh = _shell(points, widths, (0.62 - float(i) * 0.025) * RATIOS[k] * _size)
			param(mi, "phase", t * (1.0 + float(i) * 0.09) + float(k) * 0.27)

func _shell(points: PackedVector3Array, widths: PackedFloat32Array, radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var side := Vector3.RIGHT
	for j in points.size():
		var tangent := (points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)]).normalized()
		if j == 0:
			side = tangent.cross(Vector3.BACK).normalized()
		else:
			side = (side - tangent * side.dot(tangent)).normalized()
		var depth := tangent.cross(side).normalized()
		for s in 9:
			var a := float(s) / 8.0 * TAU
			vertices.append(points[j] + (side * cos(a) + depth * sin(a) * 0.53) * radius * widths[j])
			uv.append(Vector2(float(s) / 8.0, float(j) / float(points.size() - 1)))
	for j in points.size() - 1:
		for s in 8:
			var n := j * 9 + s
			indices.append_array(PackedInt32Array([n, n + 9, n + 1, n + 1, n + 9, n + 10]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
