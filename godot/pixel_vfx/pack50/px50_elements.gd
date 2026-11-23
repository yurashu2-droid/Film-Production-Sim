extends "res://pixel_vfx/px_base.gd"
# Native Pixel x Real elements. Reference: px_portal's spaced depth and HDR floor.
# Material is supplied in finite packets, head first, delayed shoulder and tail.
# Each packet travels onward after the source stops; no whole-body scale tween.
# Aurora: folded magnetic current -> three rising curves -> upper escape.
# Vent/ember: pressure -> broad branching tongues -> hot tips rise and cool.
# Sand: low intake -> clockwise shoulder -> descending sediment currents.
# Water: lifted throat -> folded lip -> gravity -> staggered floor ripples.
# Breath: source pulse -> expanding asymmetric lobes -> upper/to-ground outlet.
# Ink: pressure neck -> whipping fork -> gravity drain and dark sector stain.
# Holy/tether: local glyph supply -> spiral/two anchor branches -> outward purge.
# Wind: pressure front -> paired shearing shoulders -> onward passing tail.
# Rain/leaves: drop/eddy -> contact/release -> expanding ripple/falling leaves.

const FLOW := preload("res://pixel_vfx/pack50/shaders/elements_flow.gdshader")
const VAPOR := preload("res://pixel_vfx/pack50/shaders/elements_vapor.gdshader")
const GROUND := preload("res://pixel_vfx/pack50/shaders/elements_ground.gdshader")
const VARIANTS := ["aurora_spiral", "volcanic_vent", "sand_maelstrom", "ember_surge", "waterfall_fold", "poison_breath", "frost_breath", "ink_whip", "holy_spring", "ember_dash", "ether_tether", "wind_cleave", "rain_contact", "leaf_swirl"]
const LIVES := [6.2,5.8,6.0,5.0,5.6,5.2,5.2,5.4,5.8,4.8,5.8,4.9,3.8,4.2]
const SUPPLY := [3.3,2.4,3.0,2.1,2.5,2.1,2.1,2.5,2.9,1.9,2.9,2.0,0.9,1.7]
const TRAVEL := [2.1,2.5,2.2,2.1,2.6,2.2,2.2,2.1,2.0,1.6,2.0,2.0,0.65,1.8]
var _variant := "aurora_spiral"
var _index := 0
var _size := 1.0
var _streams: Array[Dictionary] = []
var _floor: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _tones: Array = []
var _leaf_bits: MultiMesh

static func spawn(parent: Node, pos: Vector3, size: float = 1.0, variant: String = "aurora_spiral") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, variant)
	return fx

func start(size: float, variant: String) -> void:
	_variant = variant if variant in VARIANTS else "aurora_spiral"
	_index = VARIANTS.find(_variant)
	_size = size
	life = LIVES[_index]
	var pname := "ice"
	if _index in [1,3,9]: pname = "fire"
	if _index in [2,8]: pname = "gold"
	if _index in [5,13]: pname = "toxic"
	if _index in [0,10]: pname = "arcane"
	_tones = palette(pname).duplicate()
	if _index == 0:
		_tones = [Vector3(0.016,0.04,0.075),Vector3(0.03,0.34,0.21),Vector3(0.08,1.3,0.85),Vector3(0.8,3.0,2.8),Vector3(3.0,5.5,4.2)]
	if _index == 7:
		_tones = [Vector3(0.006,0.004,0.02),Vector3(0.018,0.016,0.055),Vector3(0.07,0.04,0.13),Vector3(0.36,0.25,0.5),Vector3(1.8,1.5,2.0)]
	if _index == 2:
		_tones = [Vector3(0.08,0.04,0.018),Vector3(0.24,0.12,0.04),Vector3(0.66,0.36,0.13),Vector3(1.1,0.78,0.34),Vector3(2.6,1.8,0.7)]
	if _index == 13:
		_tones = [Vector3(0.012,0.035,0.006),Vector3(0.08,0.2,0.026),Vector3(0.2,0.55,0.055),Vector3(0.6,1.3,0.16),Vector3(1.9,2.3,0.5)]
	if _index == 11:
		_tones = [Vector3(0.025,0.05,0.09),Vector3(0.12,0.24,0.34),Vector3(0.45,0.75,0.85),Vector3(1.2,1.8,2.0),Vector3(3.7,4.0,4.1)]
	var count := 9 if _index not in [10,12,13] else 6
	if _index == 12: count = 3
	if _index == 9: count = 6
	if _index in [5,6]: count = 7
	for packet in count:
		var birth: float = 0.12 + float(packet) / float(count-1) * SUPPLY[_index]
		if _index == 9: birth = 0.12+float(packet/2)*0.73+(packet%2)*0.095
		if _index == 12: birth = 0.12+packet*0.22
		for layer in 3:
			var m := ShaderMaterial.new()
			m.shader = VAPOR if _index in [5,6] else FLOW
			for c in 5:
				m.set_shader_parameter("pal_%d" % c,_tones[c] * [0.16,0.37,0.85][layer])
			m.set_shader_parameter("layer",float(layer))
			m.set_shader_parameter("seed",packet*0.37+layer*0.83)
			m.set_shader_parameter("density",[0.28,0.36,0.48][layer])
			m.set_shader_parameter("grid",72.0+layer*8.0 if _index == 2 else 28.0+layer*8.0)
			m.set_shader_parameter("granular",_index == 2)
			if _index == 13:
				for c in 5: m.set_shader_parameter("pal_%d"%c,Vector3(.06,.1,.08)*(c+1)*[.16,.25,.33][layer])
			var mi := MeshInstance3D.new()
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 8.0
			add_child(mi)
			_streams.append({"node":mi,"birth":birth+layer*0.055,"strand":packet%3,"packet":packet,"layer":layer})
	for i in 3:
		var mat := ShaderMaterial.new()
		mat.shader = GROUND
		for c in 5: mat.set_shader_parameter("pal_%d" % c,_tones[c]*[0.22,0.32,0.16][i])
		mat.set_shader_parameter("mode",_ground_mode(i))
		if _index in [5,6]:
			for c in 5: mat.set_shader_parameter("pal_%d"%c,_tones[c]*0.07)
		if _index == 8 and i == 2: mat.set_shader_parameter("mode",5)
		if _index == 1:
			mat.set_shader_parameter("mode",3 if i == 0 else (4 if i == 1 else 11))
			if i == 0:
				for c in 5: mat.set_shader_parameter("pal_%d"%c,Vector3(0.014+c*0.01,0.011+c*0.006,0.02+c*0.005))
		mat.set_shader_parameter("seed",i*0.271)
		mat.set_shader_parameter("radius",0.72-i*0.16)
		var q := quad(mat,Vector2.ONE*(3.1 if _index not in [12,13] else 1.5)*size)
		q.rotation.x = -PI/2.0
		q.position.y = (0.025+i*0.008)*size
		if _index == 10:
			q.position.x = (i-1)*1.55*size
			q.scale = Vector3.ONE*0.46
		elif _index in [3,5,6,9,11]:
			q.position.x = lerpf(-1.7,1.9,float(i)/2.0)*size
			q.scale = Vector3.ONE*0.58
		elif _index in [4,7,12]: q.position.x = (1.3 if _index != 12 else 0.0)*size
		_floor.append(q)
	for i in 2:
		var light := lamp(_tones[3],(7.0 if _index not in [12,13] else 3.0)*size)
		light.position = Vector3(-0.6+i*1.4,0.65,0.0)*size
		_lights.append(light)
	if _index == 13:
		_leaf_bits = voxels(12,5.0*size)
		var leaf_arrays := []
		leaf_arrays.resize(Mesh.ARRAY_MAX)
		leaf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.65,0,0),Vector3(0,0.12,0.9),Vector3(0.65,0,0),Vector3(0,0,-0.9),Vector3(0,0.17,0)])
		leaf_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,4,1,2,4,2,3,4,3,0,4,4,1,0,4,2,1,4,3,2,4,0,3])
		var leaf_mesh := ArrayMesh.new()
		leaf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,leaf_arrays)
		_leaf_bits.mesh = leaf_mesh
	_step(0.0)

func _step(t: float) -> void:
	for data in _streams:
		var mi: MeshInstance3D = data.node
		var elapsed: float = t-data.birth
		var layer: int = data.layer
		var dur: float = TRAVEL[_index]+layer*0.09
		var head := elapsed/dur*1.22
		var packet_length := 0.34 if _index not in [0,2,8,10] else 0.46
		if _index == 2: packet_length = 0.30
		if _index == 10: packet_length = 0.62
		if _index == 12: packet_length = 0.12
		if _index == 9: packet_length = 0.27
		if _index in [5,6]: packet_length = 0.28
		if _index == 3: packet_length = 0.25
		var tail := head-packet_length
		mi.visible = elapsed > 0.0 and tail < 1.0 and head > 0.0
		if not mi.visible: continue
		var lower := maxf(tail,0.0)
		var upper := head
		var width: float = [0.43,0.29,0.115][layer]
		if _index in [0,1,2]: width *= 1.4
		if _index in [5,6]: width *= 1.15
		if _index == 3: width *= 1.75
		if _index in [12,13]: width *= 0.32
		mi.mesh = _tube(lower,upper,width,int(data.strand),layer,t,float(data.packet))
		param(mi,"phase",t+layer*0.17)
		# Heat travels toward exit; dark material remains readable when it cools.
		var cooling := clampf((head-0.77)*1.7,0.0,1.0)
		param(mi,"heat",1.0-cooling*(0.72 if _index in [1,3,9] else 0.26))
	for i in 3:
		var ground := _floor[i]
		var begin := 0.06+i*0.09
		if _index in [4,7]: begin = 1.35+i*0.13
		if _index == 12: begin = 0.65+i*0.22
		ground.visible = t > begin and _index != 13
		param(ground,"phase",t+i*0.15)
		var ending: float = LIVES[_index]-1.15+i*0.12
		param(ground,"sweep",clampf((t-ending)/0.7,0.0,1.0))
		# Rain/water ripple advances outward; never contracts at exit.
		if _index in [4,12]:
			param(ground,"radius",minf(0.92,0.24+maxf(t-begin,0.0)*(0.42 if _index == 12 else 0.22)-i*0.07))
	for i in 2:
		var energy := clampf(t/0.45,0.0,1.0)*(1.0-clampf((t-life+1.2)/0.9,0.0,1.0))
		_lights[i].light_energy = energy*(1.5 if _index not in [7,12,13] else 0.6)*(0.85+0.15*sin(t*5.0+i))
	if _leaf_bits != null:
		for i in 12:
			var release := 0.2+i*0.12
			var dt := t-release
			var a := i*2.399+dt*3.5
			var r := 0.3+maxf(dt,0.0)*0.27
			var y := 0.16+sin(clampf(dt/2.4,0.0,1.0)*PI)*0.94
			var active := dt > 0.0 and dt < 2.4
			put(_leaf_bits,i,Vector3(cos(a)*r,y,sin(a)*r)*_size,0.14*_size if active else 0.0,_tones[2+i%2],0.6,0.04*_size)
			var leaf_transform := _leaf_bits.get_instance_transform(i)
			leaf_transform.basis = Basis.from_euler(Vector3(sin(dt*3.0+i)*0.7,a,dt*2.0)).scaled(Vector3.ONE*0.14*_size if active else Vector3.ONE*0.0001)
			_leaf_bits.set_instance_transform(i,leaf_transform)

# Physical labels are legacy; floor marks follow material and no longer all ring.
func _ground_mode(i: int) -> int:
	match _index:
		0: return 9 # magnetic intake tracks
		2: return 7 # sand lee fan
		3,9: return 6 # warm tracks
		5,6: return 8 # deposited mist, no ring
		7: return 3 # ink stain
		8: return 2 # healing glyph; third plate has cross
		10: return 10 # paired anchor keys
		11: return 12 # ground shear
	return 1

func _point(u: float, strand: int, t: float, packet: float) -> Vector3:
	var s := float(strand)-1.0
	var sway := sin(t*2.0-u*8.0+packet*0.4)
	match _index:
		0:
			var a := u*TAU*1.4-t*0.45+s*0.75
			var r := 0.45+sin(u*PI)*1.15+s*0.18
			return Vector3(cos(a)*r,0.15+u*3.7,sin(a)*r)
		1:
			return Vector3(s*(0.2+u*1.3)+sway*u*0.38,0.12+u*3.35,sin(u*7.0+t+s)*u*0.6)
		2:
			var a := u*TAU*1.8+t*0.65+s*0.7
			var r := 0.55+u*1.6
			return Vector3(cos(a)*r,0.15+sin(u*PI)*2.2*(1.0-u*0.42),sin(a)*r)
		3: return Vector3(-1.8+u*4.0,0.18+sin(u*PI)*0.55+u*u*2.15,s*0.33+sway*u*0.4)
		4: return Vector3(-1.1+u*2.4,0.12+sin(u*PI)*2.85,s*0.3+sin(u*6.0+t)*0.2)
		5: return Vector3(-1.7+u*3.8,0.55+u*0.85+sway*u*0.2,s*(0.15+u*0.55)+sin(u*5.0+t)*u*0.28)
		6: return Vector3(-1.7+u*3.8,0.7+sin(u*PI)*0.6-u*0.45,s*(0.12+u*0.5)+sin(u*8.0-t)*0.24)
		7: return Vector3(-1.4+sin(u*2.2)*3.3,0.3+sin(u*PI)*1.8-u*u*0.28,s*0.4+sin(u*8.0-t*0.8)*u*0.5)
		8:
			var a := u*TAU*1.5+t*0.55+s*0.8
			return Vector3(cos(a)*(0.8-u*0.36),0.08+u*3.0,sin(a)*(0.8-u*0.36))
		9: return Vector3(-2.1+u*4.7,0.18+u*0.5+sin(u*PI)*s*0.18,s*(0.16+sin(u*PI)*0.35)+sway*0.1)
		10:
			if int(packet)%2 == 1: u = 1.0-u
			var a := u*TAU+t*0.65+s*1.2
			return Vector3(-1.55+u*3.1,0.85+sin(u*PI)*(0.65+s*0.3)+sin(a)*0.18,cos(a)*(0.18+sin(u*PI)*0.55))
		11: return Vector3(-1.9+u*4.2,0.12+sin(u*PI)*(1.65+s*0.6),s*(0.25+sin(u*PI)*0.42)+sin(u*5.0+t)*0.2)
		12: return Vector3(s*0.16*(1.0-u),2.1*(1.0-u),s*0.12)
		13:
			var a := u*TAU*1.7+t+s
			return Vector3(cos(a)*(0.25+u*0.6),0.08+sin(u*PI)*1.25,sin(a)*(0.25+u*0.6))
	return Vector3.ZERO

func _tube(u0: float,u1: float,width: float,strand: int,layer: int,t: float,packet: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var LONG := 26 if _index in [5,6] else 15
	var SIDES := 24 if _index in [5,6] else 10
	for j in LONG+1:
		var q := float(j)/LONG
		var u := lerpf(u0,u1,q)
		var p := _point(u,strand,t,packet)
		var tangent := (_point(u+0.003,strand,t,packet)-_point(u-0.003,strand,t,packet)).normalized()
		var side := tangent.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.1: side = tangent.cross(Vector3.RIGHT).normalized()
		var up := tangent.cross(side).normalized()
		var shoulder := pow(sin(q*PI),0.52)
		var local := width*(0.07+0.93*shoulder)*(0.77+0.23*sin(u*19.0-t*4.0+packet))
		# The actual material continues beyond the path end and narrows at its outlet.
		local *= clampf((1.5-u)/0.48,0.11,1.0)
		if _index in [5,6]: local *= 0.94+0.06*sin(q*TAU*2.0+packet+t)
		if _index in [5,6]: local *= 0.75+u*0.4
		if _index in [1,3,9]: local *= 1.05-u*0.62
		for k in SIDES+1:
			var a := float(k)/SIDES*TAU+layer*0.22+u*0.4
			var n := side*cos(a)+up*sin(a)
			var cross_width := local*(1.0+(0.055 if _index in [5,6] else 0.19)*sin(a*3.0+u*14.0-t*3.0))
			vertices.append((p+n*cross_width+Vector3(0,layer*0.035,layer*0.048))*_size)
			normals.append(n)
			uv.append(Vector2(float(k)/SIDES,q))
	for j in LONG:
		for k in SIDES:
			var a := j*(SIDES+1)+k
			indices.append_array(PackedInt32Array([a,a+SIDES+1,a+1,a+1,a+SIDES+1,a+SIDES+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
