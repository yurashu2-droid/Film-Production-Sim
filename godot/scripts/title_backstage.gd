extends RefCounted
# タイトル背景の書割。表の絵と裏の木組みを別の面にする。
# 静的な背景だけを作り、ゲームの小道具・物理・メニューには触れない。

static var _wood: StandardMaterial3D
static var _plywood: StandardMaterial3D
static var _cutout_shader: Shader

static func building(parent: Node3D, size: Vector2, face: Material, at: Vector3, yaw: float, floor_support: bool) -> Node3D:
	var root := _root(parent,"CityScenicFlat",at,yaw)
	# 正面の窓は元のBoxMeshのUVを維持し、裏面だけ生の板で覆う。
	var backing := _box(root,Vector3(0,size.y*0.5,0),Vector3(size.x,size.y,0.1),face)
	backing.name = "PaintedPlywood"
	_quad(root,size,_timber(true),Vector3(0,size.y*0.5,-0.053),true)
	_frame(root,size.x*0.94,size.y,0.0,floor_support)
	return root

static func flame(parent: Node3D, size: Vector2, face: StandardMaterial3D, at: Vector3, yaw: float, roll: float = 0.0) -> Node3D:
	var root := _root(parent,"FlameScenicFlat",at,yaw)
	# 紙の表裏に同じ炎を描かず、裏は切り抜いたベニヤの色を見せる。
	var front := face.duplicate() as StandardMaterial3D
	front.cull_mode = BaseMaterial3D.CULL_BACK
	_quad(root,size,front,Vector3(0,size.y*0.5,0.035),false)
	if _cutout_shader == null:
		_cutout_shader = Shader.new()
		_cutout_shader.code = """shader_type spatial;
render_mode cull_back;
uniform sampler2D silhouette : filter_linear;
void fragment() {
	vec4 shape = texture(silhouette, vec2(1.0 - UV.x, UV.y));
	float grain = sin(UV.y * 145.0 + sin(UV.x * 9.0) * 2.0) * 0.015;
	ALBEDO = vec3(0.32, 0.215, 0.125) + vec3(grain);
	ROUGHNESS = 0.95;
	ALPHA = shape.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	var back := ShaderMaterial.new()
	back.shader = _cutout_shader
	back.set_shader_parameter("silhouette",face.albedo_texture)
	_quad(root,size,back,Vector3(0,size.y*0.5,-0.035),true)
	_frame(root,size.x*0.48,size.y*0.71,size.y*0.12,true)
	root.rotation.z = roll
	return root

static func _root(parent: Node3D, label: String, at: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	return root

static func _timber(plywood: bool = false) -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.64,0.43,0.23)
		_wood.roughness = 0.94
		_plywood = StandardMaterial3D.new()
		_plywood.albedo_color = Color(0.30,0.205,0.125)
		_plywood.roughness = 0.97
	return _plywood if plywood else _wood

static func _quad(root: Node3D, size: Vector2, material: Material, at: Vector3, backwards: bool) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.material_override = material
	mesh.position = at
	mesh.rotation.y = PI if backwards else 0.0
	root.add_child(mesh)

static func _box(root: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	root.add_child(mesh)
	return mesh

static func _beam(root: Node3D, start: Vector3, end: Vector3) -> void:
	var mesh := _box(root,(start+end)*0.5,Vector3(0.09,start.distance_to(end),0.075),_timber())
	mesh.quaternion = Quaternion(Vector3.UP,(end-start).normalized())

static func _frame(root: Node3D, width: float, height: float, base: float, support: bool) -> void:
	var lo := base+0.12
	var hi := base+height-0.12
	var half := width*0.5
	var z := -0.18
	for x: float in [-half,half]:
		# 横から見たときだけ、薄い書割の背後の角材の奥行きが覗く。
		_box(root,Vector3(x,(lo+hi)*0.5,z),Vector3(0.075,hi-lo,0.25),_timber())
	for y: float in [lo,(lo+hi)*0.5,hi]:
		_beam(root,Vector3(-half,y,z-0.035),Vector3(half,y,z-0.035))
	_beam(root,Vector3(-half,lo,z-0.065),Vector3(half,hi,z-0.065))
	if not support: return
	# 元の書割を支える三角脚。
	var depth := clampf(height*0.45,0.85,1.5)
	for x: float in [-half*0.8,half*0.8]:
		_beam(root,Vector3(x,0.06,-0.08),Vector3(x,0.06,-depth))
		_beam(root,Vector3(x,base+height*0.72,-0.12),Vector3(x,0.06,-depth))
