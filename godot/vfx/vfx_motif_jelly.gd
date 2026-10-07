extends "res://vfx/vfx_base.gd"
# MBARI comb-jelly biooptics: rainbow comb rows are diffraction, not emitted rainbow light.
# Creative membrane wave: pressure travels crown -> skirt -> delayed trailing tissue.
# Exit: membrane 2.8s folds inward/up; combs 3.0s sweep upward; tendrils 3.1s reel in, no noise holes.
const MAT := preload("res://vfx/shaders/motif_jelly.gdshader")
var _body: MeshInstance3D
var _tails: MeshInstance3D
var _size := 1.0

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx := new()
	fx.top_level = true
	fx.position = pos
	fx._size = size
	fx.life = 3.75
	parent.add_child(fx)
	fx._build()
	return fx

func _build() -> void:
	_body = _surface(64, 32, 0)
	_tails = _surface(14, 48, 1)
	_tick(0.0)

func _surface(nx: int, ny: int, kind: int) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var lanes := 7 if kind == 1 else 1
	var columns := 2 if kind == 1 else nx
	for lane in lanes:
		var base := vertices.size()
		for y in range(ny + 1):
			for x in range(columns + 1):
				var u := float(x)/columns
				if kind == 1: u = (float(lane) + u*0.9999)/7.0
				vertices.append(Vector3(u, float(y)/ny, 0))
				uv.append(Vector2(u, float(y)/ny))
		for y in ny:
			if kind == 0 and y < 6: continue
			for x in columns:
				var a := base + y * (columns + 1) + x
				indices.append_array(PackedInt32Array([a,a+1,a+columns+1,a+1,a+columns+2,a+columns+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.extra_cull_margin = 10.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = MAT
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("size", _size)
	mi.material_override = material
	add_child(mi)
	return mi

func _tick(_delta: float) -> void:
	if _body == null: return
	for mi in [_body, _tails]:
		(mi.material_override as ShaderMaterial).set_shader_parameter("age", age)




