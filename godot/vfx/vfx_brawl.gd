extends "res://vfx/vfx_base.gd"
# どたばた乱闘雲。煙の中の打撃が、雲全体の伸び縮み・拳・筆の軌跡として見える。
# 参考：『トムとジェリー』の乱闘雲、『ルーニー・テューンズ』タズの回転。
# 回転の参考映像：WB Kids「Tasmanian Meltdown」 https://www.youtube.com/watch?v=NhJcOYZotiw
# このゲームの輪郭つき土煙、12fpsのスミア、風の筆線を、同じ打撃の振り付けに従わせる。
# 小さな溜め → 集まる雲 → 3発の殴り合い → ひと縮み → 決着の破裂 → 小房へ裂けて消える。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const FPS := 12.0
const COUNT := 18
const BREAK_AT := 23.0 / FPS
const SAND := Color(1.15, 0.97, 0.68)
# [時刻, 拳の方向]。打撃はランダムではなく、交互の方向と違う間隔で振り付ける。
const HITS := [
	[7.0 / FPS, Vector3(1.0, 0.12, 0.4)],
	[12.0 / FPS, Vector3(-0.85, 0.55, 0.3)],
	[17.0 / FPS, Vector3(0.45, 0.65, 0.75)],
]

var _size := 1.0
var _frame := -1
var _cloud: MultiMesh
var _brushes: Array[MeshInstance3D] = []
var _fists: Array[Node3D] = []
var _hits: Array[MeshInstance3D] = []


# pos は接地点。役者や当たり判定を変更しない、撮影用の独立したエフェクト。
static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 3.25
	var cells := Lib.noise("cells")
	var mat := Lib.material("cloud", {
		"dissolve_texture": cells,
		"shadow_tint": Vector3(0.65, 0.53, 0.46),
		"highlight_tint": Vector3(1.16, 1.12, 1.05),
		"shadow_threshold": 0.0,
	})
	mat.next_pass = Lib.material("cloud_ink", {
		"dissolve_texture": cells, "ink": Vector3(0.28, 0.17, 0.09), "thickness": 0.035,
	})
	_cloud = MultiMesh.new()
	_cloud.transform_format = MultiMesh.TRANSFORM_3D
	_cloud.use_colors = true
	_cloud.mesh = Lib.cloud_mesh(0)
	_cloud.instance_count = COUNT
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _cloud
	holder.material_override = mat
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-4, 0, -4) * size, Vector3(8, 5, 8) * size)
	add_child(holder)
	# 幅の違う筆線。太いものは煙の流れ、細いものは手足の速さを表す。
	for i in 6:
		var brush: MeshInstance3D = Ribbon.new()
		brush.material_override = Lib.material("stroke", {
			"width": (0.19 if i < 3 else 0.045) * size,
			"color": Color(1.35, 1.22, 0.92, 1.0) if i < 3 else Color(0.44, 0.25, 0.1, 1.0),
		})
		add_child(brush)
		_brushes.append(brush)
	for i in HITS.size():
		_fists.append(_mitten())
	for i in 4:
		var hit := MeshInstance3D.new()
		hit.mesh = Lib.quad()
		hit.material_override = Lib.material("comic_impact", {"turn": i * 0.73})
		if i == 3:
			param(hit, "toward_camera", 1.2 * size)
		hit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hit)
		_hits.append(hit)
	_pose(0.0)


# 小さなぬいぐるみのミトン。雲から一瞬顔を出し、打撃の方向を読み取らせる。
func _mitten() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.19, 0.075)
	mat.roughness = 1.0
	mat.next_pass = Lib.material("cloud_ink", {
		"dissolve_texture": Lib.noise("cells"), "ink": Vector3(0.15, 0.07, 0.03), "thickness": 0.025,
	})
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	for part: Array in [
		[Vector3(0, 0, -0.13), Vector3(0.46, 0.38, 0.48)],
		[Vector3(0.18, -0.06, -0.11), Vector3(0.19, 0.2, 0.27)],
		[Vector3(0, 0, 0.19), Vector3(0.21, 0.2, 0.48)],
	]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = sphere
		mesh.material_override = mat
		mesh.position = part[0]
		mesh.scale = part[1]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	return root


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	var gather := ease_out(clampf(t / 0.3, 0.0, 1.0))
	var swell := ease_out(clampf((t - 0.26) / 0.18, 0.0, 1.0))
	var squeeze := smoothstep(1.72, BREAK_AT, t)
	var release := maxf(t - BREAK_AT, 0.0)
	var scatter := ease_out(clampf(release / 0.68, 0.0, 1.0))
	var vanish := 1.0 - smoothstep(0.38, 1.18, release)
	var kick := Vector3.ZERO
	var punch := 0.0
	for hit: Array in HITS:
		var since: float = t - hit[0]
		if since >= 0.0 and since < 0.3:
			var force := exp(-since * 11.0)
			kick += (hit[1] as Vector3).normalized() * force * 0.24
			punch += force
	var deform := Basis.IDENTITY
	if kick.length_squared() > 0.00001:
		var axis := Basis.looking_at(kick.normalized(), Vector3.UP)
		deform = axis * Basis.from_scale(Vector3(1.0 - punch * 0.14, 1.0 - punch * 0.1, 1.0 + punch * 0.5)) * axis.inverse()
	# 同じ雲の房を、集まる塊→回転する塊→外へ飛ぶ小房へと作り替える。
	for i in COUNT:
		var ring := i / 6
		var phi := i * 2.39996 + maxf(t - 0.3, 0.0) * (8.0 + ring * 1.1)
		var outward := Vector3(cos(phi), 0.0, sin(phi))
		var radius := (0.58 + ring * 0.11) * lerpf(2.0, 1.0, gather) * (1.0 - squeeze * 0.3)
		var y := (0.38 + ring * 0.36) * lerpf(0.28, 1.0, swell) * (1.0 - squeeze * 0.35)
		var pos := deform * (outward * radius + Vector3.UP * y) + kick
		var dia := (0.82 + 0.12 * sin(i * 3.7)) * lerpf(0.24, 1.0, swell)
		dia *= 1.0 + punch * 0.12
		var dims := Vector3(0.9 + punch * 0.25, 1.0 - squeeze * 0.5, 1.28 + swell * 0.3) * dia
		if release > 0.0:
			# 破裂後は回転を止め、決着の瞬間の向きを維持して放射状に飛ばす。
			phi = i * 2.39996 + (BREAK_AT - 0.3) * (8.0 + ring * 1.1)
			outward = Vector3(cos(phi), 0, sin(phi))
			pos = outward * (0.54 + scatter * (1.3 + ring * 0.3))
			pos.y = y + sin(clampf(release / 1.18, 0.0, 1.0) * PI) * (0.4 + ring * 0.23)
			dims = Vector3(1.0, 0.85, lerpf(1.9, 0.8, scatter)) * dia * vanish
		pos *= _size
		dims *= _size
		pos.y = maxf(pos.y, dims.y * 0.38)
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var shape := Basis.looking_at(outward if release > 0.0 else tangent, Vector3.UP)
		shape = shape * Basis(Vector3.FORWARD, sin(i * 1.7 + t * 3.0) * 0.24)
		if release <= 0.0:
			shape = deform * shape
		_cloud.set_instance_transform(i, Transform3D(shape.scaled(dims.max(Vector3.ONE * 0.0001)), pos))
		var tone := 0.93 + 0.07 * (i % 3)
		_cloud.set_instance_color(i, Color(SAND.r * tone, SAND.g * tone, SAND.b * tone, 1.0 - smoothstep(0.55, 1.12, release)))
	_draw_brushes(t, swell, squeeze)
	_draw_hits(t)


func _draw_brushes(t: float, swell: float, squeeze: float) -> void:
	for i in _brushes.size():
		var points := PackedVector3Array()
		if t > 0.26 and t < BREAK_AT:
			var start := t * 10.0 + i * 2.15
			var radius := (1.05 + (i % 3) * 0.13) * swell * (1.0 - squeeze * 0.25)
			var height := 0.38 + (i % 3) * 0.38
			for p in 16:
				var k := float(p) / 15.0
				var angle := start - k * (2.0 if i < 3 else 1.25)
				var pos := Vector3(cos(angle) * radius, height + (k - 0.5) * 0.34, sin(angle) * radius)
				points.append(global_position + pos * _size)
		elif t >= BREAK_AT and t < BREAK_AT + 0.3:
			var k := (t - BREAK_AT) / 0.3
			var out := Vector3(cos(i * 1.07), 0.14 + (i % 2) * 0.18, sin(i * 1.07))
			for p in 10:
				var along := lerpf(k * 2.8, 0.65 + ease_out(k) * 2.8, float(p) / 9.0)
				points.append(global_position + (Vector3(0, 0.7, 0) + out * along) * _size)
		_brushes[i].draw(points)


func _draw_hits(t: float) -> void:
	for i in HITS.size():
		var k: float = (t - HITS[i][0]) / 0.25
		var out: Vector3 = (HITS[i][1] as Vector3).normalized()
		var fist := _fists[i]
		fist.visible = k >= 0.0 and k < 1.0
		if fist.visible:
			var extend := pow(sin(k * PI), 0.55)
			fist.transform = Transform3D(Basis.looking_at(out, Vector3.UP).scaled(Vector3.ONE * _size), (Vector3(0, 0.8, 0) + out * (0.75 + extend * 0.8)) * _size)
		var hit := _hits[i]
		hit.visible = k >= 0.08 and k < 0.84
		if hit.visible:
			hit.position = (Vector3(0, 0.8, 0) + out * 1.96) * _size
			hit.scale = Vector3.ONE * _size * maxf(0.01, sin((k - 0.08) / 0.76 * PI)) * 1.1
	var final := _hits[3]
	var end_k := (t - BREAK_AT) / 0.25
	final.visible = end_k >= 0.0 and end_k < 1.0
	if final.visible:
		final.position = Vector3(0, 1.35, 0) * _size
		final.scale = Vector3.ONE * _size * lerpf(2.3, 0.1, pow(end_k, 0.65))
