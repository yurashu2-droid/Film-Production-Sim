extends "res://vfx/vfx_base.gd"
# Image relief becomes actual lighting maps and vertex displacement on advected liquid.
const DIR := "res://assets/vfx/ai_methods/"
const SURFACE := preload("res://vfx/shaders/gen_material.gdshader")
static var maps: Dictionary = {}
static var relief: Image
var streams: Array[MeshInstance3D] = []
var puddles: Array[MeshInstance3D] = []
var mats: Array[ShaderMaterial] = []
const STARTS := [.0,.32,.91,1.53]
const DURATIONS := [1.72,1.28,1.51,1.02]

static func spawn(parent: Node3D, pos: Vector3, size: float=1.0) -> Node3D:
	var effect=load("res://vfx/vfx_gen_material.gd").new()
	effect.position=pos
	effect.scale=Vector3.ONE*size
	parent.add_child(effect)
	return effect

static func texture_file(name: String) -> Texture2D:
	if not maps.has(name):
		var im=Image.load_from_file(ProjectSettings.globalize_path(DIR+name+".png"))
		maps[name]=ImageTexture.create_from_image(im)
	return maps[name]

func _ready() -> void:
	life=6.4
	if relief==null:
		relief=Image.load_from_file(ProjectSettings.globalize_path(DIR+"material_height.png"))
		relief.resize(128,128,Image.INTERPOLATE_BILINEAR)
	for i in 4:
		var mat=ShaderMaterial.new()
		mat.shader=SURFACE
		mat.set_shader_parameter("height_map",texture_file("material_height"))
		mat.set_shader_parameter("normal_map",texture_file("material_normal"))
		mat.set_shader_parameter("ao_map",texture_file("material_ao"))
		mat.set_shader_parameter("rough_map",texture_file("material_roughness"))
		mat.set_shader_parameter("gilding",float(i)*.18)
		mats.append(mat)
		for collection in [streams,puddles]:
			var mi=MeshInstance3D.new()
			mi.material_override=mat
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			collection.append(mi)
	_tick(0)

func path(u: float,i: int) -> Vector3:
	var turn=float(i)*1.65+.3
	var radial=Vector3(cos(turn),0,sin(turn))
	var lateral=Vector3(-sin(turn),0,cos(turn))
	var h=2.1+float(i%2)*.65
	var released=age-u*(1.20+float(i)*.09)
	var envelope=sin(u*PI)
	var bend=sin(released*4.3+float(i)*1.7-u*3.2)
	return radial*(u*2.65-.4+envelope*bend*.26)+Vector3.UP*(.1+envelope*(h+.34*sin(released*5.4)))+lateral*(sin(u*PI*1.4)*.48+envelope*cos(released*3.8)*.38)

func scalar(u:float,v:float) -> float:
	return relief.get_pixel(posmod(int(u*127),128),posmod(int(v*127),128)).r

func _tick(_delta:float) -> void:
	for i in 4:
		mats[i].set_shader_parameter("clock",age)
		var elapsed=age-STARTS[i]
		var travel=1.20+float(i)*.09
		var lo=maxf(0.0,(elapsed-DURATIONS[i])/travel)
		var hi=minf(1.0,elapsed/travel)
		streams[i].visible=hi>lo and elapsed>=0 and lo<1
		if streams[i].visible:streams[i].mesh=jet_mesh(lo,hi,i)
		var landing=STARTS[i]+travel
		var wet=clampf((age-landing)/.7,0.0,1.0)
		var drain=clampf((age-4.1-float(i)*.23)/.7,0.0,1.0)
		puddles[i].visible=wet>0.0 and drain<1.0
		if puddles[i].visible:puddles[i].mesh=pool_mesh(i,wet,drain)

func jet_mesh(lo:float,hi:float,i:int) -> ArrayMesh:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows=32
	var sides=16
	var vertices: Array[Vector3]=[]
	var uv: Array[Vector2]=[]
	for r in rows+1:
		var q=float(r)/rows
		var u=lerpf(lo,hi,q)
		var center=path(u,i)
		var tangent=(path(minf(u+.002,1.0),i)-path(maxf(u-.002,0.0),i)).normalized()
		var side=tangent.cross(Vector3.FORWARD).normalized()
		var up=side.cross(tangent).normalized()
		var emission_age=age-u*(1.20+float(i)*.09)-STARTS[i]
		var feed=sin(clampf(emission_age/DURATIONS[i],0,1)*PI)
		var neck=smoothstep(0.0,.07,q)*(1.0-smoothstep(.93,1.0,q))
		var pulse=.76+.24*sin(emission_age*11.0+float(i)*1.9)
		var width=(.19+.14*feed)*neck*pulse*(1.0-.32*u)
		for k in sides+1:
			var v=float(k)/sides
			var theta=v*TAU
			var crest=(scalar(u-age*.17,v)-.5)*.07
			var flutter=1.0+.09*sin(theta*3.0-u*13.0+age*4.5)
			vertices.append(center+(side*cos(theta)+up*sin(theta))*(width+crest*neck)*flutter)
			uv.append(Vector2(u,v))
	for r in rows:
		for k in sides:
			var a=r*(sides+1)+k
			for index in [a,a+1,a+sides+1,a+1,a+sides+2,a+sides+1]:
				st.set_uv(uv[index]);st.add_vertex(vertices[index])
	st.generate_normals();st.generate_tangents()
	return st.commit()

func pool_mesh(i:int,wet:float,drain:float) -> ArrayMesh:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center=path(1.0,i)
	center.y=.02-.16*drain
	var radius=.78*sqrt(wet)
	for j in 48:
		var a=float(j)/48*TAU
		var b=float(j+1)/48*TAU
		var ra=radius*(1.0+.12*sin(a*3+float(i))+.06*cos(a*7))
		var rb=radius*(1.0+.12*sin(b*3+float(i))+.06*cos(b*7))
		for p in [center+Vector3.UP*.045,center+Vector3(cos(a)*ra,0,sin(a)*ra),center+Vector3(cos(b)*rb,0,sin(b)*rb)]:
			st.set_uv(Vector2(p.x-center.x,p.z-center.z)*.5+Vector2.ONE*.5)
			st.add_vertex(p)
	st.generate_normals();st.generate_tangents()
	return st.commit()

