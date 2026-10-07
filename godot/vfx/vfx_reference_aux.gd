extends "res://vfx/vfx_base.gd"
# User video: the expanding orange pressure collar comes after the fireball,
# then shearing packets of hot material take over as the body breaks down.
const Embers := preload("res://vfx/vfx_ember_stream.gd")
var _wave: MeshInstance3D
var _light: OmniLight3D
var _unit := 1.0

static func spawn(parent:Node, ground:Vector3, size:float=1.0)->Node3D:
	var fx:Node3D=new()
	fx.top_level=true
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size)
	return fx

func start(size:float)->void:
	_unit=maxf(size,0.05)
	life=4.5
	_wave=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=0.85
	ring.outer_radius=1.15
	ring.rings=96
	ring.ring_segments=16
	_wave.mesh=ring
	_wave.material_override=Lib.material("reference_wave")
	_wave.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wave.scale=Vector3.ONE*_unit
	# The source collar opens diagonally around the crown rather than lying on the floor.
	_wave.rotation=Vector3(deg_to_rad(32),0,0.09)
	_wave.custom_aabb=AABB(Vector3(-10,-2,-10),Vector3(20,4,20))
	add_child(_wave)
	_light=lamp(Color(1,0.46,0.065),16*_unit)
	_light.position.y=2*_unit
	Embers.spawn(self,global_position,_unit,{
		"delay":2.02,"origin":Vector3(0,3.8,0),"origin_spread":2.2,
		"drag":2.2,"gravity":2.8,"upward_scale":0.48,
	})
	_tick(0)

func _tick(_delta:float)->void:
	var t:=age
	var dt:=t-0.43
	_wave.visible=dt>0 and t<2.45
	if _wave.visible:
		var radius:=1.9+6.1*ease_out(clampf(dt/2.0,0,1))
		_wave.position.y=(4.0+dt*0.40)*_unit
		param(_wave,"radius",radius)
		param(_wave,"width",0.45*(1-smoothstep(1.65,2.45,t)))
		param(_wave,"phase",t)
		param(_wave,"fade",1-smoothstep(1.8,2.45,t))
	_light.light_energy=10*_unit*(1-exp(-t*15))*(1-smoothstep(1.96,2.45,t))
