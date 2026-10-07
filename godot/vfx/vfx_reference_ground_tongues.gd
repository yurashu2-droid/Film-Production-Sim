extends Node3D
# Thick tapered gas streams: crest propagates root -> curved crown -> detached ascending tongue.
var _tongues:Array[MeshInstance3D]=[]
func _init()->void:
	var shape:=_shape()
	for i in 8:
		var n:=MeshInstance3D.new()
		n.mesh=shape
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://vfx/shaders/reference_ground_tongue.gdshader")
		mat.set_shader_parameter("seed",float(i)*1.71)
		mat.set_shader_parameter("flame_texture",load("res://assets/vfx/lelu_noise/firepanningcyl45.png"))
		n.material_override=mat
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.extra_cull_margin=6
		var a:=float(i)*TAU/8.0
		n.rotation.y=-a
		n.position=Vector3(cos(a),0,sin(a))*2.0
		n.position.y=0.32
		add_child(n)
		_tongues.append(n)
func pose(t:float)->void:
	for i in _tongues.size():
		var leading:=i==0 or i==3 or i==5
		var dt:=t-(0.035 if leading else 0.17+float(i%3)*0.075)
		var departure:=clampf((dt-1.65-float(i%3)*0.08)/0.7,0,1)
		var n:=_tongues[i]
		n.visible=dt>0 and departure<1
		var mat:=n.material_override as ShaderMaterial
		var a:=float(i)*TAU/8.0
		n.position=Vector3(cos(a),0,sin(a))*(0.4+2.0*(1.0-pow(1.0-clampf(maxf(dt,0)/0.24,0,1),3.0))+maxf(dt-0.3,0)*0.4)
		n.position.y=0.32
		mat.set_shader_parameter("lead",1.0 if leading else 0.0)
		mat.set_shader_parameter("phase",maxf(0,dt))
		mat.set_shader_parameter("detach",departure)
static func _shape()->ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 24:
		for i in 12:
			for q in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j),Vector2(i+1,j+1),Vector2(i,j+1)]:
				var uv:Vector2=q/Vector2(12,24)
				st.set_uv(uv)
				st.add_vertex(Vector3(cos(uv.x*TAU),uv.y,sin(uv.x*TAU)))
	st.generate_normals()
	return st.commit()

