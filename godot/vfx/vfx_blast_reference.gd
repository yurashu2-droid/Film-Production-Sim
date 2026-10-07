extends "res://vfx/vfx_base.gd"
# Reference: user video Desktop 2026.10.08 / LeLu Stylized Explosions.
# Fireball: bright belly rolls up into crown -> incandescent cracks at 1.95s.
# Stem: fuel ends at root -> neck is swallowed upward. Ground: outward rolling lobes cool into root.
var _noise:ImageTexture
var _ball:MeshInstance3D
var _stem:MeshInstance3D
var _ground:Array[MeshInstance3D]=[]
var _ground_tongues:Node3D
static func spawn(parent:Node,ground:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	fx.top_level=true
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size)
	return fx
func _surface(mesh:Mesh,name:String)->MeshInstance3D:
	var mi:=MeshInstance3D.new()
	mi.mesh=mesh
	mi.material_override=Lib.material(name,{"noise_texture":_noise})
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin=8
	add_child(mi)
	return mi
func start(size:float)->void:
	life=3.6
	var field:=FastNoiseLite.new()
	field.seed=31
	field.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field.frequency=0.02
	field.fractal_type=FastNoiseLite.FRACTAL_FBM
	field.fractal_octaves=3
	field.fractal_lacunarity=2.3
	field.fractal_gain=0.55
	var image:=field.get_seamless_image(128,128)
	image.generate_mipmaps()
	_noise=ImageTexture.create_from_image(image)
	scale=Vector3.ONE*maxf(0.05,size)
	var sphere:=SphereMesh.new()
	sphere.radius=1
	sphere.height=2
	sphere.radial_segments=64
	sphere.rings=32
	_ball=_surface(sphere,"reference_fireball")
	param(_ball,"flow_texture",Lib.flow_noise())
	param(_ball,"flame_texture",Lib.tex("firepanningcyl45.png"))
	_stem=_surface(_stem_mesh(),"reference_stem")
	for i in 8:
		var n:=_surface(sphere,"reference_ground")
		param(n,"flow_texture",Lib.flow_noise())
		param(n,"seed",float(i)*1.73)
		n.rotation.y=-float(i)*TAU/8
		_ground.append(n)
	_ground_tongues=preload('res://vfx/vfx_reference_ground_tongues.gd').new()
	add_child(_ground_tongues)
	_pose(0)
func _tick(_delta:float)->void:
	_pose(age)
func _pose(t:float)->void:
	var g:=ease_out(clampf(t/0.2,0,1))
	var pressure:=maxf(0.004,g)*(1+maxf(0,t-0.65)*0.12)
	# Pressure reaches its radius before buoyancy lifts the crown clear of the floor.
	var height:=lerpf(0.35,3.2,smoothstep(0.0,0.35,t))+clampf((t-0.2)/0.45,0,1)*0.8+maxf(t-0.65,0)*0.28
	_ball.visible=t>0 and t<2.35
	param(_ball,"phase",t)
	param(_ball,"pressure",pressure)
	param(_ball,"height",height)
	param(_ball,"remaining",1-clampf((t-1.95)/0.4,0,1))
	_stem.visible=t>0.03 and t<2.35
	param(_stem,"phase",t)
	param(_stem,"height",maxf(0.1,height-1.2*pressure))
	var stop:=clampf((t-1.9)/0.45,0,1)
	param(_stem,"start",stop*(height-1.2*pressure))
	param(_stem,"width",g*pow(1-stop,0.7))
	_ground_tongues.pose(t)
	for i in _ground.size():
		var dt:=maxf(0,t-float(i%3)*0.025)
		var gn:=ease_out(clampf(dt/0.24,0,1))
		var exit:=clampf((dt-2.0-float(i%3)*0.08)/0.55,0,1)
		var n:=_ground[i]
		n.visible=dt>0 and exit<1
		var a:=float(i)*TAU/8
		n.position=Vector3(cos(a),0,sin(a))*(0.4+gn*1.6+maxf(dt-0.3,0)*0.4)
		param(n,"phase",dt)
		param(n,"pressure",maxf(0.003,gn)*(0.8+0.15*sin(i*1.2))*(1+minf(dt,1.7)*0.22))
		param(n,"supply",1-exit)
static func _stem_mesh()->ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 24:
		for i in 48:
			for q in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j),Vector2(i+1,j+1),Vector2(i,j+1)]:
				var uv:Vector2=q/Vector2(48,24)
				st.set_uv(uv)
				st.add_vertex(Vector3(cos(uv.x*TAU),uv.y,sin(uv.x*TAU)))
	st.generate_normals()
	return st.commit()



