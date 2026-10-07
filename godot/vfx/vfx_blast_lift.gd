extends "res://vfx/vfx_base.gd"
# Reference: user supplied Premium Pack mushroom and Desktop explosion clip.
# Exit: incandescent mass cools into a rising narrow smoke column; grounded lobes empty in order.
const Mushroom := preload("res://vfx/vfx_mushroom.gd")
const Ribbon := preload("res://vfx/vfx_ribbon.gd")
var _size := 1.0
var _frame := -1
var _cap: MeshInstance3D
var _stem: MeshInstance3D
var _wave: MeshInstance3D
var _puffs: MultiMesh
var _jets: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []
var _flash: MeshInstance3D
var _light: OmniLight3D
static func spawn(parent: Node, ground: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	return fx
func _surface(mesh: Mesh, shader: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = Lib.material(shader)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n
func start(size: float) -> void:
	_size = maxf(0.05,size)
	life = 3.8
	_cap = _surface(Mushroom._revolve(false),"blast_lift_surface")
	_stem = _surface(Mushroom._revolve(true),"blast_lift_surface")
	for n in [_cap,_stem]: param(n,"noise_texture",Lib.noise("soft"))
	var torus := TorusMesh.new()
	torus.inner_radius=0.94
	torus.outer_radius=1.06
	torus.rings=64
	torus.ring_segments=12
	_wave = _surface(torus,"blast_lift_wave")
	_puffs = MultiMesh.new()
	_puffs.transform_format=MultiMesh.TRANSFORM_3D
	_puffs.use_colors=true
	_puffs.mesh=Lib.cloud_mesh(1)
	_puffs.instance_count=16
	var holder := MultiMeshInstance3D.new()
	holder.multimesh=_puffs
	holder.material_override=Lib.material("blast_lift_puff")
	holder.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)
	for i in 18:
		var n: MeshInstance3D = Ribbon.new()
		n.material_override=Lib.material("blast_lift_stroke")
		add_child(n)
		_jets.append(n)
	for i in 28:
		var n: MeshInstance3D = Ribbon.new()
		n.material_override=Lib.material("blast_lift_stroke")
		add_child(n)
		_sparks.append(n)
	_flash=sprite(2,Color(10,7,2),_size)
	_flash.position.y=0.7*_size
	param(_flash,"toward_camera",1.5*_size)
	_light=lamp(Color(1,0.4,0.08),12*_size)
	_pose(0.0)
static func _hash(i:int)->float:
	return fposmod(sin(float(i)*127.1+31.7)*43758.5453,1.0)
func _tick(_delta:float)->void:
	var f:=int(age*15.0)
	if f!=_frame:
		_frame=f
		_pose(float(f)/15.0)
func _pose(t:float)->void:
	var grow:=ease_out(clampf((t-0.02)/0.32,0,1))*(1+minf(t,1.8)*0.19)
	var cool:=clampf((t-0.78)/0.65,0,1)
	var stream:=clampf((t-0.9)/1.2,0,1)
	var drain:=clampf((t-2.1)/1.45,0,1)
	_cap.visible=t>0.04 and drain<1
	_cap.position=Vector3(0.12*sin(t*2),(0.55+2.5*minf(grow,1)+t*0.6+stream*0.45+drain*0.9)*_size,0)
	_cap.scale=Vector3(2.25,(4.6+stream*0.8),2.1)*_size*maxf(0.04,grow)
	_stem.visible=t>0.04 and t<2.35
	_stem.scale=Vector3(1.25,maxf(0.04,_cap.position.y/_size),1.15)*_size
	for n in [_cap,_stem]:
		param(n,"phase",t)
		param(n,"heat",1-cool)
		param(n,"stream",stream)
		param(n,"thin",maxf(0.001,(1-stream*0.48)))
	param(_stem,"thin",maxf(0.001,1-clampf((t-1.2)/1.15,0,1)))
	_wave.visible=t>=0.3 and t<1.95
	var w:=maxf(0,t-0.3)
	var radius:=1.8+4.2*ease_out(clampf(w/1.65,0,1))
	_wave.position.y=(2.3+w)*_size
	_wave.scale=Vector3(radius,radius*0.55,radius)*_size
	param(_wave,"phase",t)
	param(_wave,"thickness",pow(1-clampf((w-0.45)/1.2,0,1),2))
	_flash.visible=t<0.14
	_flash.scale=Vector3.ONE*_size*(0.5+4.5*ease_out(clampf(t/0.14,0,1)))
	param(_flash,"color",Color(10,7,2,maxf(0,1-t/0.14)))
	_light.light_energy=26*_size*pow(maxf(0,1-t/1.4),2)
	for i in 16:
		var a:=i*2.39996
		var dir:=Vector3(cos(a),0,sin(a))
		var dt:=maxf(0,t-0.03*(i%3))
		var g:=ease_out(clampf(dt/0.3,0,1))
		var exit:=clampf((dt-1.5-0.07*i)/0.62,0,1)
		var pos:=dir*(0.3+1.8*g+dt*0.55+exit*0.5)
		pos.y=0.35+g*(0.15+_hash(i)*0.3)-exit*0.2
		var s:=Vector3(2.64,1.72,2.42)*(0.6+_hash(i+8)*0.65)*maxf(0.001,g)
		s*=Vector3((1+exit*0.4)*pow(1-exit,0.6),pow(1-exit,1.7),pow(1-exit,1.1))
		var hot:=Color(4.5,0.22+_hash(i)*0.12,0.008)
		var col:=Color(0.3,0.22,0.17).lerp(hot,1-clampf((dt-0.78)/0.65,0,1))
		col.a=1
		_puffs.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(0,a,0)).scaled(s*_size),pos*_size))
		_puffs.set_instance_color(i,col)
	for i in _jets.size():
		var dt:=t-0.04*(i%4)
		var duration:=1.35+_hash(i)*0.5
		var n:=_jets[i]
		n.visible=dt>0 and dt<duration
		if not n.visible: continue
		var k:=dt/duration
		var a:=i*2.39996+0.2
		var dir:=Vector3(cos(a),0,sin(a))
		var len:=(1.4+_hash(i+13)*2.5)*ease_out(clampf(k*2.7,0,1))
		var cut:=clampf((k-0.35)/0.65,0,1)
		var pts:=PackedVector3Array()
		for j in 9:
			var q:=lerpf(cut,1.0,float(j)/8)
			var p:=dir*(len*q+0.18)
			p.y=0.08+(0.3+_hash(i+21)*3.2)*sin(q*PI*0.8)+cut*1.6+sin(q*5+i+k*4)*cut*0.35
			pts.append(global_position+p*_size)
		n.draw(pts)
		param(n,"width",_size*(0.22+0.27*_hash(i+4))*pow(1-cut,1.2))
		param(n,"color",Vector3(7,2.8,0.2).lerp(Vector3(1.2,0.12,0.01),k))
		param(n,"phase",t)
	for i in _sparks.size():
		var dt:=t-(0.12+_hash(i+37)*0.25)
		var end:=0.8+_hash(i)*0.65
		var n:=_sparks[i]
		n.visible=dt>0 and dt<end and _spark_pos(i,dt).y>0.08
		if not n.visible: continue
		var pts:=PackedVector3Array()
		for j in 7:
			pts.append(global_position+_spark_pos(i,maxf(0,dt-float(j)/6*minf(dt,0.11)))*_size)
		n.draw(pts)
		var k:=dt/end
		param(n,"width",_size*0.095*pow(1-k,0.8))
		param(n,"color",Vector3(10,8,4).lerp(Vector3(3,0.4,0.05),k))
		param(n,"phase",t)
static func _spark_pos(i:int,t:float)->Vector3:
	var a:=i*2.39996
	var velocity:=Vector3(cos(a),0,sin(a))*(3+_hash(i+2)*4)
	var drag:=(1-exp(-2*t))/2
	return velocity*drag+Vector3(0,0.65+(4+_hash(i+5)*5)*drag-4.7*t*t,0)


