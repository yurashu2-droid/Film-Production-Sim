extends "res://vfx/vfx_base.gd"
# Bridson, Hourihan & Nordenstam: Curl Noise (SIGGRAPH 2007).
# One gas volume: pressure impulse -> toroidal roll -> exhausted buoyant outflow.
# Parcels sample a shared velocity/density field, never render separate sphere meshes.
const COUNT := 32
const STEP := 1.0/120.0
var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _sim := 0.0
var _material: ShaderMaterial
var _volume: MeshInstance3D
static func spawn(parent:Node,ground:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	fx.top_level=true
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size)
	return fx
func start(size:float)->void:
	life=3.6
	scale=Vector3.ONE*maxf(0.05,size)
	_volume=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=Vector3(12,11,12)
	_volume.mesh=box
	_volume.position.y=5.3
	_material=Lib.material("blast_flow_volume")
	_volume.material_override=_material
	_volume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_volume)
	for i in COUNT:
		# Four material streams, eight emission samples along each moving stream.
		var stream := i/8
		var a:=float(stream)*1.5708+0.18*sin(i*1.7)
		_pos.append(Vector3(cos(a)*0.24,0.35+0.12*sin(i*1.7),sin(a)*0.24))
		var impulse: float = [11.0,8.0,13.0,6.0][stream]
		_vel.append(Vector3(cos(a)*impulse,[8.0,12.0,6.0,9.0][stream],sin(a)*impulse))
	_upload()
func _tick(_delta:float)->void:
	while _sim+STEP<=age+0.00001:
		_sim+=STEP
		_advect(STEP)
	_upload()
func _advect(dt:float)->void:
	for i in COUNT:
		var born:=birth(i)
		if _sim<born:continue
		var p:=_pos[i]
		var r:=maxf(0.05,Vector2(p.x,p.z).length())
		var radial:=Vector3(p.x/r,0,p.z/r)
		var tangent:=Vector3(-radial.z,0,radial.x)
		var center_h:=1.25+_sim*0.65+maxf(0,_sim-0.9)*1.7
		var roll:=exp(-maxf(0,_sim-0.65)*1.0)
		var vr:=-(p.y-center_h)*4.8*roll
		var vy:=(r-2.0)*4.8*roll+lerpf(0.6,3.4,smoothstep(0.65,1.3,_sim))
		var flow:=radial*vr+Vector3.UP*vy+tangent*(2.2+sin(p.y*1.5+_sim)*1.2)*roll
		# Shared smooth curl shear bends the entire plume, rather than random vertex jitter.
		flow+=Vector3(2.0*sin(p.y*1.4-_sim*1.5),0.75*cos(p.x*1.3+p.z),1.2*cos(p.y*1.2-_sim))*1.0
		var parcel_age:=_sim-born
		var entrain:=clampf((parcel_age-0.15)/0.25,0,1)
		_vel[i]=_vel[i].lerp(flow,dt*(0.7+entrain*5.5))
		_pos[i]+=_vel[i]*dt
		if _pos[i].y<0.2:
			_pos[i].y=0.2
			_vel[i].y=maxf(_vel[i].y,1.4)
func _upload()->void:
	var parcels:=PackedVector4Array()
	var motion:=PackedVector4Array()
	for i in COUNT:
		var born:=birth(i)
		var dt:=_sim-born
		var density:=0.0
		if dt>=0:
			density=(1-exp(-dt*32))*exp(-maxf(dt-0.65,0)*0.95)
			density*=1-smoothstep(2.6,3.4,_sim)
		var p:=_pos[i]-Vector3(0,5.3,0)
		parcels.append(Vector4(p.x,p.y,p.z,density))
		var v:=_vel[i]
		motion.append(Vector4(v.x,v.y,v.z,1-smoothstep(0.25,1.35,maxf(0,dt))))
	_material.set_shader_parameter("parcels",parcels)
	_material.set_shader_parameter("motion",motion)
	_material.set_shader_parameter("phase",_sim)

static func birth(i:int)->float:
	# A compact impulse, followed by a smaller delayed feed rather than a long inflation.
	return float(i%8)*0.04+float(i/8)*0.025


