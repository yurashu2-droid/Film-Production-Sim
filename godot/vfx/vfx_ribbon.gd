extends MeshInstance3D
# 点の列（ワールド座標）に沿う帯。幅は ribbon シェーダーが画面に向けて広げる。

var _mesh := ImmediateMesh.new()


func _init() -> void:
	mesh = _mesh
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 3.0


# points[0] が先頭（UV.x = 0）、最後が尾（UV.x = 1）
func draw(points: PackedVector3Array) -> void:
	_mesh.clear_surfaces()
	var n := points.size()
	if n < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var along := points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]
		var tangent := along.normalized() if along.length_squared() > 0.0000001 else Vector3.UP
		for side in 2:
			_mesh.surface_set_normal(tangent)
			_mesh.surface_set_uv(Vector2(float(i) / float(n - 1), side))
			_mesh.surface_add_vertex(points[i])
	_mesh.surface_end()
