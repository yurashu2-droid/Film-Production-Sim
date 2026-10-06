extends Node3D
# 接地した蹴り出しで1回だけ。9粒・2描画、透明描画や影・物理判定なし。
const LIFETIME := 0.68
const COUNT := 9
const ORIGINS: Array[Vector3] = [Vector3(-0.18, 0.09, 0.12), Vector3(0.16, 0.10, 0.10), Vector3(-0.27, 0.18, 0.32), Vector3(0.25, 0.15, 0.34), Vector3(-0.12, 0.25, 0.52), Vector3(0.11, 0.30, 0.50), Vector3(-0.30, 0.30, 0.64), Vector3(0.30, 0.27, 0.70), Vector3(0.0, 0.37, 0.76)]
const DIAMETERS: Array[float] = [0.36, 0.39, 0.48, 0.45, 0.50, 0.47, 0.32, 0.31, 0.28]
static var puff_mesh: SphereMesh
static var puff_material: ShaderMaterial
static var ink_material: ShaderMaterial
var age := 0.0
var _size := 1.0
var _body: MultiMesh
var _ink: MultiMesh

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("dash_dust")

func burst(direction: Vector3, size: float = 1.0) -> void:
	_size = size
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	if flat.length_squared() < 0.01:
		flat = Vector3.FORWARD
	rotation.y = atan2(-flat.x, -flat.z)
	if puff_mesh == null:
		puff_mesh = SphereMesh.new()
		puff_mesh.radius = 0.5
		puff_mesh.height = 1.0
		puff_mesh.radial_segments = 24
		puff_mesh.rings = 12
		puff_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode unshaded;
varying vec3 puff_normal;
void vertex() { puff_normal = NORMAL; }
void fragment() {
 float n = dot(normalize(puff_normal), normalize(vec3(-0.5, 0.9, 0.4)));
 ALBEDO = n > 0.45 ? vec3(0.98, 0.91, 0.75) : (n > -0.25 ? vec3(0.83, 0.70, 0.50) : vec3(0.58, 0.44, 0.29));
}
"""
		puff_material.shader = shader
		ink_material = ShaderMaterial.new()
		var ink_shader := Shader.new()
		ink_shader.code = """shader_type spatial;
render_mode unshaded, cull_front;
void vertex() { VERTEX *= 1.055; }
void fragment() { ALBEDO = vec3(0.27, 0.22, 0.18); }
"""
		ink_material.shader = ink_shader
	_body = _make_cloud(puff_material)
	_ink = _make_cloud(ink_material)
	_update_puffs()

func _make_cloud(material: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = COUNT
	mm.mesh = puff_mesh
	var mesh := MultiMeshInstance3D.new()
	mesh.multimesh = mm
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mm

func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
	elif _body:
		_update_puffs()

func _update_puffs() -> void:
	for i in COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		var rank := float(i / 2)
		var delay := rank * 0.012
		var t := maxf(0.0, age - delay)
		# 小さく潰れて生まれ、弾けて膨らみ、後ろへ転がりながら縮む。
		var grow := 1.0 - pow(1.0 - clampf(t / 0.12, 0.0, 1.0), 3.0)
		var shrink := 1.0 - smoothstep(0.28 + rank * 0.015, 0.59 + rank * 0.015, t)
		var diameter := DIAMETERS[i] * grow * shrink * _size
		var pos: Vector3 = (ORIGINS[i] + Vector3(side * t * 0.32, t * (0.26 + rank * 0.035), t * (0.6 + rank * 0.10))) * _size
		pos.y = maxf(pos.y, diameter * 0.36)
		var squash := lerpf(0.45, 0.95, grow)
		var b := Basis.IDENTITY.scaled(Vector3(diameter, diameter * squash, diameter))
		var tr := Transform3D(b, pos)
		_body.set_instance_transform(i, tr)
		_ink.set_instance_transform(i, tr)
