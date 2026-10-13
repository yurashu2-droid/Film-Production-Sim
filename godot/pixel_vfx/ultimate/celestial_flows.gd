extends Node3D
# Seven peripheral material systems. Every strip is sampled in emission time:
# shoulders travel with material; a stopped source drains forward, never rewinds.
# Left heat rises/dilutes, right water folds into the gate, rear weave drains upward,
# electrical branches transmit, pressure exits in depth, tongues detach upward,
# and falling star condensate returns to the ground. No lifetime noise holes.
const FLOW := preload("res://pixel_vfx/ultimate/shaders/flows_material.gdshader")
const COUNTS := [11, 9, 7, 9, 3, 10, 23]
const STARTS := [2.6, 3.5, 6.0, 7.0, 10.1, 12.0, 15.0]
const STEPS := [.68, .88, 1.15, .79, 1.65, .49, .17]
const TRAVEL := [2.55, 2.05, 3.15, .68, 1.65, 2.3, 2.4]
const FEED := [1.55, 1.50, 1.25, .19, .24, .65, .065]
var _nodes: Array[MeshInstance3D] = []
var _scale := 1.0

func setup(size: float) -> void:
	_scale = size
	for role in 7:
		for layer in 3:
			var n := MeshInstance3D.new()
			var mat := ShaderMaterial.new()
			mat.shader = FLOW
			mat.set_shader_parameter("role", role)
			mat.set_shader_parameter("layer", layer)
			n.material_override = mat
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.extra_cull_margin = 10.0 * size
			add_child(n)
			_nodes.append(n)
	update(0.0)

func update(t: float) -> void:
	var pose := floorf(t * 12.0) / 12.0
	for role in 7:
		for layer in 3:
			var n := _nodes[role * 3 + layer]
			var mesh := _build(role, layer, pose)
			n.visible = mesh != null
			if mesh != null:
				n.mesh = mesh
			(n.material_override as ShaderMaterial).set_shader_parameter("phase", pose)

func _point(role: int, j: int, q: float, born: float) -> Vector3:
	var a := float(j) * 1.73
	match role:
		0: # Buoyant heat folds climb the left buttress and uncurl above its shoulder.
			return Vector3(-4.8 + 2.6*q + .43*sin(q*8.0+a)*sin(q*PI), .18 + 3.1*pow(q,.72)+.35*sin(q*PI), 1.2 + .65*sin(q*5.0+a*.2)-.85*q)
		1: # Water is first carried inward, then falls through the receiver lip.
			return Vector3(4.6-2.48*q+.28*sin(q*7.0+a)*sin(q*PI), 3.9+sin(q*PI)*.82-1.3*q*q, 1.45+.55*cos(q*4.0+a)-.75*q)
		2: # Rear spiral is an incomplete helix, kept behind the aperture.
			var theta := -1.5 + q*5.7 + sin(born*.43)*.4
			return Vector3(cos(theta)*(3.75+.3*sin(q*8.0+a)), 3.0+sin(theta)*3.05, -1.3-.4*cos(theta)+.45*q)
		3: # A travelling leader followed by a late split, never a complete rigid bolt.
			var side := -1.0 if j%2==0 else 1.0
			var segment := q*12.0
			var zig := lerpf(sin(floorf(segment)*7.1+a), sin(ceilf(segment)*7.1+a), fmod(segment,1.0))
			return Vector3(side*(3.4-1.7*q)+zig*.20*sin(q*PI), 1.1+4.5*q+.1*sin(q*14.0+a), .2+.65*sin(q*PI+a))
		4: # Expanding arc pushed forward out of the opening, tilted by material age.
			var theta := born * 2.9
			return Vector3(cos(theta)*(1.1+2.2*q), 3.0+sin(theta)*(1.1+2.2*q), -.4+3.0*q)
		5: # Gold tongues detach, curl sideways and rise above the crown.
			return Vector3(sin(a)*2.2+.65*sin(q*4.6+a)*q, 4.8+2.9*q, -.5+.55*cos(a)+.6*q)
		6: # Rain accelerates under gravity and arcs outward toward floor receivers.
			var sx := sin(a)*2.55
			return Vector3(sx+(1.1 if sx>0 else -1.1)*q+.2*sin(q*5.0+a), 6.1*(1.0-q*q)+.10, .55+cos(a)*1.6+1.2*q)
	return Vector3.ZERO

func _width(role: int, layer: int, q: float, emission: float, j: int) -> float:
	var shoulder := pow(maxf(0.0,sin(emission*PI)),.6)
	var neck := .43+.57*pow(.5+.5*sin(emission*8.8+float(j)*1.3-q*2.8),2.0)
	var base: float = [.70,.56,.33,.19,.20,.32,.26][role]
	var depth: float = [1.0,.63,.28][layer]
	var evolution := 1.0
	if role==0: evolution = .55+q*1.5
	if role==1: evolution = 1.3-.83*q
	if role==3: evolution = .5+.5*sin(q*PI)
	if role==5: evolution = 1.15-.94*q
	if role==6: evolution = .82-.20*q
	return base*depth*shoulder*neck*evolution

func _build(role: int, layer: int, t: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var inds := PackedInt32Array()
	for j in COUNTS[role]:
		var birth: float = STARTS[role]+float(j)*STEPS[role]
		# A light syncopation changes spacing while preserving readable causal beats.
		if j%3==2: birth += .12
		var travel: float = TRAVEL[role]*(1.0+.07*sin(float(j)*2.3))
		var feed: float = FEED[role]
		var lo := maxf(0.0,(t-birth-feed)/travel)
		var hi := minf(1.0,(t-birth)/travel)
		if hi<=lo or lo>=1.0: continue
		if role==4:
			_append_pressure(verts,normals,uvs,colors,inds,j,layer,lo,hi,t-birth)
			continue
		_append_strip(verts,normals,uvs,colors,inds,role,j,layer,lo,hi,t,birth,travel,feed,0)
		if role==3 and hi>.44:
			_append_strip(verts,normals,uvs,colors,inds,role,j,layer,maxf(lo,.43),hi,t,birth,travel,feed,1)
	if verts.is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=inds
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _append_strip(v: PackedVector3Array,n: PackedVector3Array,uv: PackedVector2Array,c: PackedColorArray,idx: PackedInt32Array,role: int,j: int,layer: int,lo: float,hi: float,t: float,birth: float,travel: float,feed: float,branch: int) -> void:
	var offset := v.size()
	const ROWS := 22
	const COLS := 6
	for row in ROWS+1:
		var q := lerpf(lo,hi,float(row)/ROWS)
		var emission := clampf((t-birth-q*travel)/feed,0.0,1.0)
		var point := _point(role,j,q,birth)
		var tangent := (_point(role,j,q+.002,birth)-point).normalized()
		if branch==1:
			point += Vector3((q-.43)*2.1,.0,(q-.43)*1.5)
		var across := tangent.cross(Vector3.FORWARD).normalized()
		if across.length_squared()<.1: across=Vector3.RIGHT
		var width := _width(role,layer,q,emission,j)*(1.0 if branch==0 else .62)
		for col in COLS+1:
			var u := float(col)/COLS
			var cross_pos := (u-.5)*2.0
			if role==0:
				cross_pos += sin(emission*9.5+q*4.0+j)*sin(u*PI)*.3
			if role==1:
				cross_pos += sin(emission*5.5-q*3.0)*sin(u*PI)*.2
			var bulge := sin(u*PI)*width*.65
			var rip := sin(emission*12.0+q*7.0+j)*width*.13
			var p := point+across*cross_pos*width+Vector3(0,0,bulge+layer*.035+rip)
			v.append(p*_scale)
			n.append(Vector3(0,0,1))
			uv.append(Vector2(u,emission+float(j)*2.0))
			c.append(Color(q,emission,float(branch),1.0))
	for row in ROWS:
		for col in COLS:
			var p := offset+row*(COLS+1)+col
			idx.append_array(PackedInt32Array([p,p+1,p+COLS+1,p+1,p+COLS+2,p+COLS+1]))

func _append_pressure(v: PackedVector3Array,n: PackedVector3Array,uv: PackedVector2Array,c: PackedColorArray,idx: PackedInt32Array,j: int,layer: int,lo: float,hi: float,age: float) -> void:
	# Pressure reads as broad broken annular membranes, not copies of the supply ribbons.
	for sector in 3:
		var offset := v.size()
		for row in 33:
			var a := float(row)/32*1.85+sector*TAU/3+float(j)*.53+age*.12
			for col in 5:
				var q := lerpf(lo,hi,float(col)/4)
				var bend := sin(a*4.0-q*7.0+j)*.24+sin(a*7.0+q*9.0)*.08
				var r := 1.65+q*3.7+layer*.055+bend*sin(q*PI)
				var p := Vector3(cos(a)*r,3.4+sin(a)*r*.58,-.4+q*4.3+sin(a*3-q*5.0)*.30)
				v.append(p*_scale); n.append(Vector3.FORWARD)
				uv.append(Vector2(float(col)/4,float(row)/32))
				c.append(Color(q,float(row)/32,0,1))
		for row in 32:
			for col in 4:
				var p := offset+row*5+col
				idx.append_array(PackedInt32Array([p,p+1,p+5,p+1,p+6,p+5]))
