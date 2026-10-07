extends "res://vfx/vfx_base.gd"
# 参考：ユーザー提供「Explosions VFX (PREMIUM PACK)」の右上のキノコ雲、中央の土砂爆発、下段の小爆発。
# mushroom は提供動画の白熱火球・くびれた火柱・上部炎輪・地面の炎房。
# soil/mini は参考画像の従来版。大爆発は動画用の本体と圧力波・飛散物を組み合わせる。
const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Reference := preload("res://vfx/vfx_blast_reference.gd")
const Aux := preload("res://vfx/vfx_reference_aux.gd")
const FPS := 15.0
var _size := 1.0
var _kind := "mushroom"
var _frame := -1
var _cap: MeshInstance3D
var _stem: MeshInstance3D
var _puffs: MultiMesh
var _jets: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _flash: MeshInstance3D
var _light: OmniLight3D
var _wave: MeshInstance3D
var _embers: MultiMesh
static var _cap_mesh: ArrayMesh
static var _stem_mesh: ArrayMesh

static func spawn(parent: Node, ground: Vector3, size: float = 1.0, kind: String = "mushroom") -> Node3D:
	if kind == "mushroom":
		var core := Reference.spawn(parent, ground, size)
		core.life = 4.5
		Aux.spawn(core, ground, size)
		return core
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size, kind)
	return fx

func start(size: float, kind: String) -> void:
	_size = maxf(size, 0.05)
	_kind = kind
	life = 3.5 if kind == "mushroom" else 2.7
	if _cap_mesh == null:
		_cap_mesh = _revolve(false)
		_stem_mesh = _revolve(true)
	_cap = _surface(_cap_mesh, false)
	_stem = _surface(_stem_mesh, true)
	_wave = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.06
	torus.rings = 64
	torus.ring_segments = 12
	_wave.mesh = torus
	_wave.material_override = Lib.material("blast_wave")
	_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wave)
	_puffs = MultiMesh.new()
	_puffs.transform_format = MultiMesh.TRANSFORM_3D
	_puffs.use_colors = true
	_puffs.mesh = Lib.cloud_mesh(1)
	_puffs.instance_count = 24
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _puffs
	holder.material_override = Lib.material("cloud", {
		"dissolve_texture": Lib.noise("cells"), "shadow_tint": Vector3(0.54, 0.3, 0.17),
		"highlight_tint": Vector3(1.6, 5.0, 1.0) if kind == "mushroom" else Vector3(1.25, 1.15, 1.03), "edge_color": Vector3(2.4, 0.3, 0.02),
	})
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-7, 0, -7) * _size, Vector3(14, 10, 14) * _size)
	add_child(holder)
	for i in 28:
		var jet: MeshInstance3D = Ribbon.new()
		jet.material_override = Lib.material("blast_stroke", {"width": _size * (0.22 + 0.27 * _hash(i + 4))})
		add_child(jet)
		_jets.append(jet)
	for i in 3:
		var ring: MeshInstance3D = Ribbon.new()
		ring.material_override = Lib.material("blast_stroke", {"width": _size * 0.1, "shock": true})
		add_child(ring)
		_rings.append(ring)
	_flash = sprite(2, Color(10, 7, 2), _size)
	_flash.position.y = 0.7 * _size
	param(_flash, "toward_camera", _size * 1.5)
	_light = lamp(Color(1, 0.4, 0.08), _size * 12)
	_light.position.y = _size
	_embers = MultiMesh.new()
	_embers.transform_format = MultiMesh.TRANSFORM_3D
	_embers.use_colors = true
	_embers.mesh = Lib.streak_mesh()
	_embers.instance_count = 18
	var sparks := MultiMeshInstance3D.new()
	sparks.multimesh = _embers
	sparks.material_override = Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "flat_style": true})
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.custom_aabb = AABB(Vector3(-7, 0, -7) * _size, Vector3(14, 10, 14) * _size)
	add_child(sparks)
	_pose(0.0)

func _surface(mesh: Mesh, stem: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Lib.material("blast_surface", {"noise_texture": Lib.noise("soft"), "stem": stem})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# 傘は平たいドーム、柱はくびれた漏斗。ランダムな球の集合ではなく一続きのシルエット。
static func _revolve(stem: bool) -> ArrayMesh:
	var rings := 18
	var sides := 64
	var points := PackedVector3Array()
	var uv := PackedVector2Array()
	for j in range(rings + 1):
		var v := float(j) / rings
		for i in range(sides + 1):
			var u := float(i) / sides
			var a := u * TAU
			var r := 0.17 + 0.13 * sin(v * PI) + 0.35 * pow(v, 4) if stem else pow(sin(v * PI), 0.55)
			r = maxf(r, 0.008)
			var lobe := 1.0 + 0.065 * sin(a * 7.0 + v * 4.0) + 0.025 * sin(a * 13.0 - v * 7.0)
			var y := v if stem else (v - 0.5) * 0.9 + 0.035 * sin(a * 6.0) * sin(v * PI)
			points.append(Vector3(cos(a) * r * lobe + (0.08 * sin(v * 4) if stem else 0.0), y, sin(a) * r * lobe))
			uv.append(Vector2(u, v))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings:
		for i in sides:
			var a := j * (sides + 1) + i
			var b := a + sides + 1
			for id in [a, a + 1, b, a + 1, b + 1, b]:
				st.set_uv(uv[id])
				st.add_vertex(points[id])
	st.generate_normals()
	return st.commit()

static func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 127.1 + 31.7) * 43758.5453, 1.0)

func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(float(frame) / FPS)

func _pose(t: float) -> void:
	var mini := _kind == "mini"
	var soil := _kind == "soil"
	var video := not mini and not soil
	var grow := ease_out(clampf((t - 0.04) / 0.43, 0, 1))
	var cool := clampf((t - 0.68) / 0.85, 0, 1)
	var decay := clampf((t - 1.65) / 1.5, 0, 1)
	if video:
		grow = ease_out(clampf((t - 0.02) / 0.32, 0, 1)) * (1 + minf(t, 1.8) * 0.19)
		cool = 0.0
		decay = clampf((t - 1.65) / 0.57, 0, 1)
	_cap.visible = not mini and not soil and t > 0.04 and decay < 1
	_stem.visible = _cap.visible and t < (2.1 if video else 1.7)
	_cap.position = Vector3(0.12 * sin(t * 2), (0.6 + 3.0 * grow + maxf(t - 0.6, 0) * 0.6) * _size, 0)
	_cap.scale = Vector3(2.65, 3.0, 2.4) * _size * maxf(0.04, grow) * (1.0 + decay * 0.32)
	if video:
		_cap.position.y = (0.55 + 2.5 * minf(grow, 1) + t * 0.6) * _size
		_cap.scale = Vector3(2.25, 4.6, 2.1) * _size * maxf(0.04, grow) * (1.0 + decay * 0.16)
		_cap.rotation.y = t * 0.12
	_stem.scale = Vector3(1.25, maxf(0.04, _cap.position.y / _size), 1.15) * _size
	for node: MeshInstance3D in [_cap, _stem]:
		param(node, "phase", t)
		param(node, "heat", 1.0 - cool)
		param(node, "remaining", 1.0 - decay)
		param(node, "flame_rise", 0.08 + minf(t, 1.8) * 0.4 if video else 0.25)
	_wave.visible = video and t >= 0.3 and t < 1.95
	if _wave.visible:
		var wave_age := t - 0.3
		var radius := 1.8 + 4.2 * ease_out(clampf(wave_age / 1.65, 0, 1))
		_wave.position.y = (2.3 + wave_age * 1.0) * _size
		_wave.scale = Vector3(radius, radius * 0.55, radius) * _size
		_wave.rotation.z = 0.06 * sin(t * 2)
		param(_wave, "phase", t)
		param(_wave, "remaining", 1 - clampf((wave_age - 1.1) / 0.5, 0, 1))
	_flash.visible = t < 0.14
	_flash.scale = Vector3.ONE * _size * (0.5 + 4.5 * ease_out(clampf(t / 0.14, 0, 1)))
	param(_flash, "color", Color(10, 7, 2, maxf(0, 1 - t / 0.14)))
	_light.light_energy = _size * 26.0 * pow(maxf(0, 1 - t / (2.2 if video else 1.1)), 2)
	for i in 24:
		var a := i * 2.39996
		var dir := Vector3(cos(a), 0, sin(a))
		var delay := 0.03 * (i % 3)
		var dt := maxf(0, t - delay)
		var g := ease_out(clampf(dt / 0.3, 0, 1))
		var remain := 1.0 - clampf((dt - (1.1 if mini else 1.7)) / 0.85, 0, 1)
		var radius := (0.4 + 1.35 * g + dt * 0.4) * (0.5 + 0.5 * _hash(i))
		var pos := dir * radius
		var scale3 := Vector3(1.2, 0.65, 1.1) * (0.6 + _hash(i + 8) * 0.65) * maxf(0.01, g) * (0.65 + remain * 0.35)
		pos.y = 0.2 + dt * 0.23
		if video and i < 16:
			var inflate := 1.0 + minf(dt, 1.8) * 0.6
			pos = dir * (0.3 + 1.8 * g + dt * 0.55)
			pos.y = 0.35 + g * (0.15 + _hash(i) * 0.3)
			scale3 *= Vector3(2.2, 2.65, 2.2) * inflate
			remain = 1 - clampf((dt - 1.7 - _hash(i) * 0.15) / 0.45, 0, 1)
		if soil and i >= 10:
			pos = dir * (0.25 + g * (0.6 + _hash(i)))
			pos.y = 0.3 + g * (float(i - 10) / 4.5) + maxf(dt - 0.4, 0) * 0.3
			scale3 = Vector3(1, 1.25, 1) * maxf(0.01, g) * (0.9 + _hash(i))
		elif mini:
			pos *= 0.3
			pos.y += 0.3 + g * (0.25 + _hash(i + 9) * 0.65)
			scale3 *= 1.4
		elif i >= 16:
			# 小房が傘の縁で巻き返り、冷却後は上へほぐれていく。
			var roll := t * 2 + i
			pos = dir * (grow * 1.95 + sin(roll) * 0.13 + decay * 0.8)
			pos.y = _cap.position.y / _size - 0.8 + cos(roll) * 0.24 + decay * 0.65
			scale3 = Vector3(1.2, 0.8, 1) * maxf(0.01, grow) * (0.7 + _hash(i) * 0.25)
			remain = 1.0 - clampf((dt - 2.15) / 0.9, 0, 1)
			if video:
				pos = dir * (minf(grow, 1.4) * 1.5 + sin(roll) * 0.18)
				pos.y = _cap.position.y / _size - 1.0 + sin(roll) * 0.2
				scale3 *= 1.25
				remain = 1 - clampf((dt - 1.65) / 0.65, 0, 1)
		var heat := 1.0 - clampf((dt - 0.24 - _hash(i) * 0.28) / 0.75, 0, 1)
		if video:
			heat = 1.0
		var hot := Color(6.5, 2.4 + _hash(i) * 1.6, 0.16)
		if video:
			hot = Color(4.5, 0.22 + _hash(i) * 0.12, 0.008)
		var color := Color(0.24, 0.16, 0.11).lerp(hot, heat)
		color.a = remain
		_puffs.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(i * 0.2, a, i * 0.3)).scaled(scale3 * _size), pos * _size))
		_puffs.set_instance_color(i, color)
	for i in _jets.size():
		var a := i * 2.39996 + 0.2
		var dt := t - 0.04 * (i % 4)
		var duration := (1.1 if video else 0.6) + _hash(i) * 0.4
		var jet: MeshInstance3D = _jets[i]
		jet.visible = dt > 0 and dt < duration
		if not jet.visible:
			continue
		var k := dt / duration
		var dir := Vector3(cos(a), 0, sin(a))
		var length := (1.4 + _hash(i + 13) * 2.5) * ease_out(clampf(k * 2.7, 0, 1))
		if mini:
			length *= 0.45
		var height := (0.3 + _hash(i + 21) * 2.0) * sin(k * PI * 0.8)
		if video:
			height *= 1.6
		if mini:
			height *= 0.7
		var pts := PackedVector3Array()
		for j in 8:
			var q := float(j) / 7
			var p := dir * (length * (1 - q) + 0.18)
			p.y = 0.07 + height * pow(1 - q, 1.7) + sin(q * 9 + i) * 0.06
			pts.append(global_position + p * _size)
		jet.draw(pts)
		param(jet, "remaining", pow(1 - k, 0.5))
	for i in _rings.size():
		var ring: MeshInstance3D = _rings[i]
		ring.visible = not mini and t > 0.06 and t < 0.7
		if not ring.visible:
			continue
		var pts := PackedVector3Array()
		var radius := (0.8 + 4.5 * ease_out(clampf(t / 0.7, 0, 1))) * _size
		for j in 26:
			var a := i * TAU / 3 + float(j) / 25 * 1.75
			var r := radius * (1 + 0.025 * sin(a * 9))
			pts.append(global_position + Vector3(cos(a) * r, 0.04 * _size, sin(a) * r))
		ring.draw(pts)
		param(ring, "remaining", 1 - t / 0.7)
	for i in _embers.instance_count:
		var born := 1.65 + _hash(i + 37) * 0.3
		var dt := t - born
		var remain := 1.0 - clampf(dt / (1.1 + _hash(i) * 0.6), 0, 1)
		var dir := Vector3(cos(i * 2.4), 0, sin(i * 2.4))
		var p := dir * (0.7 + maxf(dt, 0) * (1.0 + _hash(i) * 2))
		p.y = 1.0 + _hash(i + 3) * 2.2 + dt * 1.0 - dt * dt * 1.3
		var velocity := (dir * 1.5 + Vector3.UP * (1.0 - dt * 2.6)).normalized()
		var axis := Basis.looking_at(velocity, Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI / 2)
		var s := 0.28 + _hash(i + 18) * 0.28
		var scale3 := Vector3(3.0, s, 3.0) * _size * sqrt(maxf(0.0001, remain))
		_embers.set_instance_transform(i, Transform3D(axis * Basis.from_scale(scale3), p * _size))
		_embers.set_instance_color(i, Color(8 * remain, 3.8 * remain, 0.3 * remain, 1 if video and dt >= 0 and remain > 0.02 and p.y > 0.08 else 0))
