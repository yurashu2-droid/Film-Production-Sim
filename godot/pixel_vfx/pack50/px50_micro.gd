extends "res://pixel_vfx/px_base.gd"
# Ten small effects: each follows a different force, path and material handoff.
const FLOW:=preload("res://pixel_vfx/pack50/shaders/micro_flow.gdshader")
const SEAL:=preload("res://pixel_vfx/pack50/shaders/micro_seal.gdshader")
const VAPOR:=preload("res://pixel_vfx/pack50/shaders/micro_vapor.gdshader")
const LIQUID:=preload("res://pixel_vfx/pack50/shaders/micro_liquid.gdshader")
const CONFIGS:={
	"strike_snap":["fire",2.4,5,.04,.38],
	"ricochet_skip":["gold",3.1,3,.07,.55],
	"heal_sprout":["toxic",3.8,4,.12,.9],
	"mana_tick":["arcane",3.4,3,.1,.75],
	"frost_touch":["ice",3.5,4,.04,.78],
	"ember_contact":["fire",3.8,4,.12,.65],
	"poison_drop":["toxic",3.7,4,.03,.68],
	"dust_step":["dust",3.2,5,.04,.55],
	"rune_ping":["gold",3.6,3,.07,.75],
	"charge_seed":["arcane",4.1,5,.02,.98]
}
const DUST:=[Vector3(.06,.035,.015),Vector3(.22,.14,.08),Vector3(.55,.34,.17),Vector3(1.1,.76,.35),Vector3(2.3,1.8,1.1)]
var _variant:=""
var _colors:Array=[]
var _lanes:Array=[]
var _seals:Array[MeshInstance3D]=[]
var _lamp:OmniLight3D
var _size:=1.0
var _config:Array=[]

static func spawn(parent:Node,pos:Vector3,size:float=1.0,variant:String="strike_snap")->Node3D:
	var fx=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size,variant)
	return fx

func start(size:float,variant:String)->void:
	assert(CONFIGS.has(variant),"Unknown micro preset "+variant)
	_variant=variant
	_config=CONFIGS[variant]
	_size=size
	life=_config[1]
	_colors=DUST if _config[0]=="dust" else palette(_config[0])
	_colors=_colors.map(func(c):return c*.58)
	for j in int(_config[2]):
		var layers:Array=[]
		for k in 3:
			var mat=ShaderMaterial.new()
			mat.shader=VAPOR if variant=="dust_step" else (LIQUID if variant=="poison_drop" else FLOW)
			for c in 5:mat.set_shader_parameter("pal_%d"%c,_colors[c])
			mat.set_shader_parameter("layer",float(k))
			mat.set_shader_parameter("seed",float(j)*1.73+float(k)*.41)
			mat.set_shader_parameter("style",2.0 if variant=="dust_step" else (1.0 if variant=="frost_touch" else 0.0))
			var mi=MeshInstance3D.new()
			mi.material_override=mat
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin=3.0
			add_child(mi)
			layers.append(mi)
		_lanes.append(layers)
	if variant in ["heal_sprout","mana_tick","poison_drop","rune_ping","charge_seed"]:
		var seal_count=1 if variant in ["heal_sprout","poison_drop"] else (2 if variant=="mana_tick" else 3)
		for k in seal_count:
			var mat=_seal_material()
			for c in 5:mat.set_shader_parameter("pal_%d"%c,_colors[c]*[.35,.65,.85][k])
			mat.set_shader_parameter("offset",float(k)*.23)
			var seal_kind=3.0 if variant=="heal_sprout" else (2.0 if variant=="poison_drop" else (4.0 if variant=="charge_seed" else float(k%2)))
			mat.set_shader_parameter("kind",seal_kind)
			var mi=quad(mat,Vector2.ONE*(.74+.13*k)*size)
			mi.rotation.x=-PI/2
			mi.position.y=(.015+.03*k)*size
			_seals.append(mi)
	_lamp=lamp(_colors[3],3.5*size)
	_lamp.position.y=.40*size
	_step(0)

func _seal_material()->ShaderMaterial:
	var mat=ShaderMaterial.new()
	mat.shader=SEAL
	return mat

func _start(j:int)->float:
	var stagger=float(_config[3])
	match _variant:
		"ricochet_skip":return [.0,.52,.91][j]
		"heal_sprout":return [.02,.21,.64,.98][j]
		"charge_seed":return [.0,.14,.39,.83,1.26][j]
		"poison_drop":return [.0,.73,.90,1.14][j]
	return stagger*j+(float(j%3)*.035)

func _duration(j:int)->float:
	match _variant:
		"strike_snap":return .31+.055*(j%2)
		"ricochet_skip":return .61-.085*j
		"dust_step":return .89+float(j%2)*.11
		"rune_ping":return 1.1+float(j)*.08
		"charge_seed":return 1.35 if j<4 else .91
	return float(_config[4])+float(j%2)*.11

func _point(j:int,q:float,t:float)->Vector3:
	var a=float(j)*TAU/float(_config[2])+.18
	var radial=Vector3(cos(a),0,sin(a))
	match _variant:
		"strike_snap":
			var forward=pow(q,.72+.08*(j%3))
			var sweep=Vector3(-radial.z,0,radial.x)*sin(q*PI)*(.10+.055*j)
			return Vector3(0,.55,0)+radial*(forward*(1.05+.09*j))+sweep+Vector3.UP*(sin(q*PI)*(.12+.12*(j%3))-.12*q*q)+Vector3(0,0,sin(q*5.0+t*5.0)*.055)
		"ricochet_skip":
			var sign_y=1.0 if j==0 else -1.0
			return Vector3(-.85+q*1.9,.22+sin(q*PI)*(.65-.18*j)+sign_y*.09*sin(q*5),float(j-1)*.15+sin(q*4)*.10)
		"heal_sprout":
			return radial*sin(q*PI)*(.23+.04*j)+Vector3.UP*(.06+q*1.10)+Vector3(.09*sin(q*7+t*2),0,.06*cos(q*4))
		"mana_tick":
			var angle=q*TAU*1.15+float(j)*2.10
			var r=.32*(1.0-.3*q)
			return Vector3(cos(angle)*r,.08+q*1.30,sin(angle)*r)
		"frost_touch":
			return radial*(q*.8)+Vector3.UP*(.12+q*.23+sin(q*PI)*(.25+.12*sin(t*4+j)))
		"ember_contact":
			return radial*(sin(q*PI)*.23)+Vector3.UP*(.02+q*(.81+.12*j))+Vector3(.1*sin(q*5+t*3),0,.09*cos(q*6+j))
		"poison_drop":
			if j==0:return Vector3(.12*sin(q*3),1.12*(1-q*q),.03)
			return radial*q*.65+Vector3.UP*(.06+sin(q*PI)*.44)
		"dust_step":
			return Vector3(-.25+q*(.40+.08*j),.025+q*.68+sin(q*PI)*.12,(j-2)*.17+sin(q*4.5+j)*.10+q*.12*sin(float(j)))
		"rune_ping":
			var angle=q*PI*1.7+float(j)*2.10+t*.32
			return Vector3(cos(angle)*(.42+.08*j),.10+q*.35,sin(angle)*(.42+.08*j))
		"charge_seed":
			if j==4:return Vector3(-.08+q*.18,.26+q*1.28,sin(q*6)*.1)
			var angle=a-q*TAU*.70
			var r=.71*(1-q)+.07
			return Vector3(cos(angle)*r,.28+sin(q*PI)*.26,sin(angle)*r)
	return Vector3.ZERO

func _step(t:float)->void:
	if _lanes.is_empty():return
	for j in _lanes.size():
		var begin=_start(j)
		var travel=_duration(j)
		var release=_release()
		for k in 3:
			var tt=t-float(k)*.038
			var lo=maxf(0.0,(tt-begin-release)/travel)
			var hi=minf(1.0,(tt-begin)/travel)
			var mi:MeshInstance3D=_lanes[j][k]
			mi.visible=hi>lo and tt>begin and lo<1.0
			if not mi.visible:continue
			mi.mesh=_tube(j,k,lo,hi,tt)
			param(mi,"phase",tt)
			param(mi,"cooling",clampf((lo-.45)*1.8,0,1))
	for k in _seals.size():
		var seal=_seals[k]
		param(seal,"phase",t)
		var seal_birth=.7 if _variant=="poison_drop" else 0.0
		param(seal,"opened",clampf((t-seal_birth-float(k)*.07)/.32,0,1))
		param(seal,"radius",minf(.91,.19+maxf(0,t-seal_birth)*.39) if _variant=="poison_drop" else .74)
		param(seal,"swept",clampf((t-(life-1.4)-float(k)*.17)/.75,0,1))
		seal.visible=t>seal_birth and t<float(life)-.2
	var light_end=life-.2 if not _seals.is_empty() else (1.9 if _variant in ["frost_touch","ember_contact","ricochet_skip"] else 1.15)
	_lamp.light_energy=(0.0 if _variant=="dust_step" else .75)*_size*(1.0-smoothstep(light_end-.45,light_end,t))*(.72+.28*sin(t*8)*sin(t*8))

func _release()->float:
	if _variant in ["heal_sprout","rune_ping"]:return .62
	return .26 if _variant=="strike_snap" else (.54 if _variant in ["dust_step","frost_touch"] else .40)

func _tube(j:int,k:int,lo:float,hi:float,t:float)->ArrayMesh:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts:Array[Vector3]=[]
	var uvs:Array[Vector2]=[]
	for r in 19:
		var v=float(r)/18.0
		var q=lerpf(lo,hi,v)
		var p=_point(j,q,t)*_size
		var tangent=(_point(j,minf(q+.006,1),t)-_point(j,maxf(q-.006,0),t)).normalized()
		var side=tangent.cross(Vector3.FORWARD).normalized()
		if side.length()<.5:side=tangent.cross(Vector3.UP).normalized()
		var up=side.cross(tangent).normalized()
		# The profile belongs to material emitted at a specific time. It is not
		# re-normalized over the remaining segment as the tail gets consumed.
		var emitted=clampf((t-_start(j)-q*_duration(j))/_release(),0,1)
		var shoulder=pow(maxf(sin(emitted*PI),0.0),.65)
		var neck=.40+.60*pow(.5+.5*sin(emitted*TAU*1.6-q*5.0+j),2)
		var width=[.17,.10,.035][k]*shoulder*neck*(1.0-.5*smoothstep(.55,1.0,q))*_size
		# Dust is a spreading, sheared cloud with several advected shoulders.
		# Its density never uses a bright spark head or a stretched capsule.
		if _variant=="dust_step":
			width=[.28,.22,.14][k]*(.55+.45*pow(sin(emitted*8.0-q*2.4+j)*.5+.5,2))*shoulder*(.65+q*.7)*_size
			p+=Vector3(.06*sin(q*11+t*2+j),.07*sin(q*8-t*3+j),.10*sin(q*7+t*2))*_size
		elif _variant=="frost_touch":width*=1.45
		elif _variant=="poison_drop":
			width=[.16,.09,.03][k]*pow(maxf(sin(emitted*PI),0.0),.55)*(1.0-.50*q)*_size
		if _variant=="charge_seed" and j==4:width*=1.20
		for x in 11:
			var u=float(x)/10.0
			var theta=u*TAU
			var swell=1.0+.2*sin(theta*3-q*8+t*4.0+float(j))
			pts.append((p+(side*cos(theta)+up*sin(theta))*width*swell).snapped(Vector3.ONE*.012*_size))
			uvs.append(Vector2(u,emitted))
	for r in 18:
		for x in 10:
			var a=r*11+x
			for ix in [a,a+1,a+11,a+1,a+12,a+11]:
				st.set_uv(uvs[ix])
				st.set_color(Color(lerpf(lo,hi,float(ix/11)/18.0),0,0,1))
				st.add_vertex(pts[ix])
	st.generate_normals()
	return st.commit()

