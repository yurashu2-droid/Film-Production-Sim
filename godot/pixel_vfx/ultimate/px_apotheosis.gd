extends Node3D
# 星海の戴冠門: twenty subordinate systems answer a single opening iris.
# 0–3 s: a quiet map; 3–7: converging supply; 7–12: unlocking;
# 12–16: crowned release; 16–21.3: material-specific departure; 22: empty.
# No shader uses TIME. 24 authored poses/s keep the long flow readable.
signal finished
const FIELD=preload("res://pixel_vfx/ultimate/shaders/apotheosis_gate.gdshader")
@export var auto_start:=true
@export var effect_size:=1.0
@export var playback_speed:=1.0
@export var free_on_finish:=true
var age:=0.0
var life:=22.0
var _tick:=-1
var _done:=false
var _parts:Array[Node3D]=[]
var _gates:Array[MeshInstance3D]=[]
var _lights:Array[OmniLight3D]=[]

static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx=new()
	fx.auto_start=false
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

func _ready()->void:
	add_to_group("vfx")
	add_to_group("pixel_vfx")
	if auto_start:start(effect_size)

func start(size:float=1.0)->void:
	for child in get_children():child.free()
	_parts.clear();_gates.clear();_lights.clear()
	effect_size=maxf(.05,size)
	age=0.0;_tick=-1;_done=false;visible=true
	var surface=_grid()
	# Every draw layer serves this same main iris, not extra decoration counts.
	for n in 6:
		var node=MeshInstance3D.new()
		node.mesh=surface
		var mat=ShaderMaterial.new()
		mat.shader=FIELD
		mat.set_shader_parameter("mode",[0,1,0,2,1,3][n])
		mat.set_shader_parameter("layer",float(n))
		node.material_override=mat
		node.position=Vector3(0,3,-.20*n)*effect_size
		node.scale=Vector3.ONE*5.8*effect_size
		node.extra_cull_margin=3.0*effect_size
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node);_gates.append(node)
	for path in ["celestial_floor","celestial_crown","celestial_flows"]:
		var script=load("res://pixel_vfx/ultimate/%s.gd"%path)
		if script!=null:
			var node=script.new()
			add_child(node)
			node.setup(effect_size)
			_parts.append(node)
	for n in 3:
		var light=OmniLight3D.new()
		light.light_color=[Color("54bccc"),Color("8769d0"),Color("e5bc6a")][n]
		light.omni_range=9.0*effect_size
		light.position=Vector3((n-1)*3.0,1.4,1)*effect_size
		light.light_energy=0
		add_child(light);_lights.append(light)
	pose(0)

func _grid()->ArrayMesh:
	var vertices=PackedVector3Array()
	var uv=PackedVector2Array()
	var indices=PackedInt32Array()
	for y in 41:
		for x in 41:
			var p=Vector2(float(x)/40,float(y)/40)
			vertices.append(Vector3(p.x-.5,.5-p.y,0));uv.append(p)
	for y in 40:
		for x in 40:
			var a=y*41+x
			indices.append_array(PackedInt32Array([a,a+41,a+1,a+1,a+41,a+42]))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _process(delta:float)->void:
	if _done:return
	age+=maxf(delta,0)*maxf(playback_speed,0)
	var tick=int(age*24)
	if tick!=_tick:
		_tick=tick
		pose(float(tick)/24)
	if age>=life:
		_done=true
		finished.emit()
		if free_on_finish:queue_free()

func pose(t:float)->void:
	for n in _gates.size():
		var node=_gates[n]
		var born=5.0+n*.23
		var opened=clampf((t-born)/2.0,0,1)
		var close_time=17.1+(5-n)*.28
		var closed=clampf((t-close_time)/1.65,0,1)
		var charge=smoothstep(9.5,12.8,t)*(1-smoothstep(14.1,16.5,t))
		var mat=node.material_override as ShaderMaterial
		mat.set_shader_parameter("phase",t)
		mat.set_shader_parameter("opened",opened)
		mat.set_shader_parameter("closed",closed)
		mat.set_shader_parameter("charge",charge)
		node.visible=opened>0 and closed<1
		node.position=Vector3(sin(t*.6-n*.55)*.055,3+sin(t*.8-n)*.04+closed*.24,-.2*n-.28*charge)*effect_size
		node.rotation.z=sin(t*.45-n*.6)*.035
	for part in _parts:part.update(t)
	for n in _lights.size():
		var supply=smoothstep(2.0+n*.45,5.5+n*.3,t)
		var decay=1-smoothstep(17+n*.7,20+n*.4,t)
		var impact=exp(-pow((t-12.8)/.13,2))*.6
		_lights[n].light_energy=(1.0+impact+.18*sin(t*2+n))*supply*decay

func stop()->void:
	_done=true
	visible=false
	for light in _lights:light.light_energy=0
