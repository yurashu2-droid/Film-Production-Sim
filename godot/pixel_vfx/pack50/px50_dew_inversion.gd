extends "res://pixel_vfx/px_base.gd"
# 露の反転 / dew inversion. Original gesture: a single dew strand slips over
# a surface, rolls back at contact, hands momentum to ONE thin forward wave.
# One main material process + one support. No glyph, rings or particles.
# 0.1s intake, 1.25s impact, 1.6s curled shoulder, 2.2s sheet handoff.
# The strand tail empties forward; the sheet drains along the floor by 4.2s.
const DEW := preload("res://pixel_vfx/pack50/shaders/dew_inversion.gdshader")
const TONES := [Vector3(.014,.038,.07),Vector3(.055,.22,.34),Vector3(.2,.8,1.05),Vector3(.9,2.2,2.45),Vector3(3.7,4.6,4.4)]
var _scale := 1.0
var _strand: Array[MeshInstance3D] = []
var _wave: MeshInstance3D
var _light: OmniLight3D

static func spawn(parent: Node,pos: Vector3,size: float=1.0,variant: String="dew_inversion") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size,variant)
	return fx

func start(size: float,_variant: String) -> void:
	_scale=size
	life=4.8
	for layer in 3:
		var mi := MeshInstance3D.new()
		mi.material_override=_mat(layer,0)
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin=4.0
		add_child(mi)
		_strand.append(mi)
	_wave=MeshInstance3D.new()
	_wave.material_override=_mat(1,1)
	_wave.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wave.extra_cull_margin=4.0
	add_child(_wave)
	_light=lamp(TONES[3],6.0*size)
	_light.position=Vector3(.5,.65,0)*size
	_step(0.0)

func _mat(layer: int,mode: int) -> ShaderMaterial:
	var m:=ShaderMaterial.new()
	m.shader=DEW
	for i in 5: m.set_shader_parameter("pal_%d"%i,TONES[i]*[.28,.52,.9][layer])
	m.set_shader_parameter("layer",float(layer))
	m.set_shader_parameter("mode",mode)
	return m

func _step(t: float) -> void:
	for layer in 3:
		var dt:=t-.12-layer*.055
		var head:=dt/2.15
		var tail:=head-.40
		_strand[layer].visible=dt>0.0 and tail<1.02
		if _strand[layer].visible:
			_strand[layer].mesh=_strand_mesh(maxf(tail,0.0),head,layer,t)
			param(_strand[layer],"phase",t+layer*.13)
	var w:=(t-1.62)/2.2
	_wave.visible=w>0.0 and w<1.0
	if _wave.visible:
		_wave.mesh=_wave_mesh(w,t)
		param(_wave,"phase",t)
	_light.light_energy=clampf((t-.8)/.6,0.0,1.0)*(1.0-clampf((t-3.4)/.6,0.0,1.0))*.8

func _point(u: float,t: float) -> Vector3:
	var p:=_raw_point(u,t)
	# Contact transfers the last material into the surface, before a bright spear can remain.
	p.y-=maxf(u-.96,0.0)*.8
	return p*Vector3(3.8,2.2,1.4)+Vector3(1.2,0,0)

func _raw_point(u: float,t: float) -> Vector3:
	if u<.42:
		var v:=u/.42
		return Vector3(-1.3+v*.88,1.25*(1.0-v*v)+.06,sin(v*PI)*.10)
	if u<.82:
		var a:=(u-.42)/.40*PI*1.48
		return Vector3(-.42+sin(a)*.62,.07+(1.0-cos(a))*.47,sin(a*.7)*.20+sin(a)*sin(a/1.48)*.45)
	var v:=(u-.82)/.5
	return Vector3(-1.04+v*2.5,.56*pow(maxf(1.0-v,0.0),2.0)+.045,-.024*(1.0-v))

func _strand_mesh(u0: float,u1: float,layer: int,t: float) -> ArrayMesh:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var ids:=PackedInt32Array()
	const N:=28
	const SIDES:=14
	for j in N+1:
		var q:=float(j)/N
		var u:=lerpf(u0,u1,q)
		var p:=_point(u,t)
		var tangent:=(_point(u+.002,t)-_point(u-.002,t)).normalized()
		var side:=tangent.cross(Vector3.FORWARD).normalized()
		var up:=tangent.cross(side).normalized()
		var radius:float=[.25,.16,.07][layer]*pow(sin(q*PI),.65)*(1.0+.18*sin(u*12.0-t*3.0))*clampf((1.30-u)/.3,0.0,1.0)
		for k in SIDES+1:
			var a:=float(k)/SIDES*TAU
			var n:=side*cos(a)+up*sin(a)
			vertices.append((p+n*radius+Vector3(0,layer*.012,layer*.016))*_scale)
			normals.append(n)
			uvs.append(Vector2(float(k)/SIDES,q))
	for j in N:
		for k in SIDES:
			var a:=j*(SIDES+1)+k
			ids.append_array(PackedInt32Array([a,a+SIDES+1,a+1,a+1,a+SIDES+1,a+SIDES+2]))
	return _mesh(vertices,normals,uvs,ids)

func _wave_mesh(w: float,t: float) -> ArrayMesh:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var ids:=PackedInt32Array()
	const N:=24
	const C:=12
	var front:=w*2.7
	var back:=maxf(front-.78+maxf(w-.62,0.0)*2.1,0.0)
	for j in N+1:
		var q:=float(j)/N
		var x:=lerpf(back,front,q)
		for k in C+1:
			var v:=float(k)/C
			var z:=(v-.5)*1.45*sin(q*PI)*(.6+.4*sin(w*PI))
			var y:=.032+sin(q*PI)*.24*(1.0-w)+.025*sin(v*TAU+t*2.0)-maxf(w-.8,0.0)*.40
			vertices.append(Vector3(-.4+x*1.28,y*1.3,z*1.7)*_scale)
			normals.append(Vector3.UP)
			uvs.append(Vector2(v,q))
	for j in N:
		for k in C:
			var a:=j*(C+1)+k
			ids.append_array(PackedInt32Array([a,a+C+1,a+1,a+1,a+C+1,a+C+2]))
	return _mesh(vertices,normals,uvs,ids)

func _mesh(vertices: PackedVector3Array,normals: PackedVector3Array,uvs: PackedVector2Array,ids: PackedInt32Array) -> ArrayMesh:
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=ids
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
