extends Node3D
# 凹凸を焼き込んだ立体煙。蹴り出しは塊→裂けた小片、走行中は小さな接地煙。
# メッシュ・材質を共有し、1つの煙につき2描画。停止・コマ送りは物理刻みに追従。
const LIFETIME := 1.22
static var puff_mesh: ArrayMesh
static var body_material: ShaderMaterial
static var ink_material: ShaderMaterial
var age := 0.0
var lifetime := LIFETIME
var _size := 1.0
var _trail := false
var _cores := 8
var _count := 20
var _body: MultiMesh
var _ink: MultiMesh

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("dash_dust")

func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	_size = size
	_trail = trail
	_cores = 3 if trail else 8
	_count = _cores * 2 + (1 if trail else 4)
	lifetime = 0.84 if trail else LIFETIME
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	if flat.length_squared() < 0.01:
		flat = Vector3.FORWARD
	rotation.y = atan2(-flat.x, -flat.z)
	_build_resources()
	_body = _make_cloud(body_material)
	_ink = _make_cloud(ink_material)
	_update_puffs()

static func _radius(n: Vector3) -> float:
	# 大きい房と小さい房を非対称に重ねる。球の輪郭をそのまま使わない。
	return 0.5 * (1.0 + 0.22 * sin(n.x * 4.0 + n.y * 1.3) * cos(n.z * 3.5 - 0.4) + 0.13 * sin(n.y * 5.0 + n.z * 1.1) + 0.04 * cos(n.x * 6.0 - n.z * 4.0))

static func _build_resources() -> void:
	if puff_mesh != null:
		return
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 32
	sphere.rings = 18
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in points.size():
		var n := points[i].normalized()
		var u := n.cross(Vector3.UP).normalized() if absf(n.y) < 0.95 else n.cross(Vector3.RIGHT).normalized()
		var v := n.cross(u).normalized()
		var a := (n + u * 0.002).normalized()
		var b := (n + v * 0.002).normalized()
		var point := n * _radius(n)
		normals[i] = (a * _radius(a) - point).cross(b * _radius(b) - point).normalized()
		points[i] = point
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	puff_mesh = ArrayMesh.new()
	puff_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	body_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
varying vec3 dust_normal;
void vertex() { dust_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
 float n = dot(normalize(dust_normal), normalize(vec3(-0.4, 0.9, 0.3)));
 vec3 shade = mix(vec3(0.72, 0.55, 0.35), vec3(0.91, 0.79, 0.58), smoothstep(-0.26, -0.19, n));
 ALBEDO = mix(shade, vec3(1.0, 0.93, 0.77), smoothstep(0.48, 0.55, n));
}
"""
	body_material.shader = shader
	ink_material = ShaderMaterial.new()
	var ink_shader := Shader.new()
	ink_shader.code = """shader_type spatial;
render_mode unshaded, cull_front;
void vertex() { VERTEX *= 1.022; }
void fragment() { ALBEDO = vec3(0.52, 0.40, 0.27); }
"""
	ink_material.shader = ink_shader

func _make_cloud(material: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = _count
	mm.mesh = puff_mesh
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return mm

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	elif _body:
		_update_puffs()

func _update_puffs() -> void:
	var pace := 1.35 if _trail else 1.0
	for i in _count:
		var parent := i % _cores
		var side := -1.0 if parent % 2 == 0 else 1.0
		var rank := float(parent / 2)
		var seed := float(parent) * 2.399
		var t := maxf(0.0, age * pace - rank * 0.025)
		var grow := 1.0 - pow(1.0 - clampf(t / 0.16, 0.0, 1.0), 3.0)
		var roll := 1.0 - exp(-t * 3.0)
		var pos := Vector3(side * (0.09 + rank * 0.045 + roll * 0.26), 0.08 + rank * 0.052 + roll * (0.20 + rank * 0.055), 0.10 + rank * 0.16 + roll * (0.40 + rank * 0.07))
		var diameter := (0.46 + 0.065 * sin(seed) + rank * 0.032) * grow
		var shape := Vector3(lerpf(1.35, 1.05, roll), lerpf(0.38, 0.95, roll), lerpf(0.85, 1.30, roll))
		if i < _cores:
			# 大きな塊は薄く引き伸ばされ、その間に別の小片が剥がれる。
			var erode := smoothstep(0.38 + rank * 0.04, 0.99 + rank * 0.035, t)
			diameter *= 1.0 - erode
			shape.x *= 1.0 + erode * 0.5
			shape.y *= 1.0 - erode * 0.35
		else:
			var peel := maxf(0.0, t - 0.27 - rank * 0.03)
			var born := smoothstep(0.0, 0.16, peel)
			var dissolve := 1.0 - smoothstep(0.35, 0.76, peel)
			diameter = (0.22 + 0.055 * sin(seed + 1.0)) * born * dissolve
			pos += Vector3(side * (0.16 + peel * 0.26), 0.08 + peel * 0.23, peel * 0.32)
			shape = Vector3(1.25, 0.8 + born * 0.3, 0.9)
		if i >= _cores * 2:
			# 蹴った方向に沿う低い筋。煙の房より先に短く伸びて消える。
			var j := float(i - _cores * 2)
			var kick := 1.0 - exp(-age * 15.0)
			diameter = (1.0 - smoothstep(0.10, 0.30, age)) * smoothstep(0.0, 0.04, age)
			shape = Vector3(0.08, 0.035, 0.16 + kick * 0.44)
			pos = Vector3((j - 1.5) * 0.13, 0.035, 0.12 + kick * (0.4 + j * 0.07))
		pos *= _size
		var dims := shape * diameter * _size
		pos.y = maxf(pos.y, dims.y * 0.43)
		var angles := Vector3(0.0, side * 0.1, 0.0) if i >= _cores * 2 else Vector3(t * 0.55 + seed * 0.13, seed, side * roll * 0.65)
		var basis := Basis.from_euler(angles).scaled(dims.max(Vector3.ONE * 0.00001))
		var tr := Transform3D(basis, pos)
		_body.set_instance_transform(i, tr)
		_ink.set_instance_transform(i, tr)
