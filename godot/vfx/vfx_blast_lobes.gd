extends "res://vfx/vfx_base.gd"
# Reference: supplied Explosions VFX PREMIUM PACK; Wind Waker's rolling smoke.
# Exit: cap opens into seven smoke rolls, each curls inward then contracts upward.
const Ribbon := preload("res://vfx/vfx_ribbon.gd")
var _size := 1.0
var _frame := -1
var cap: MeshInstance3D
var stem: MeshInstance3D
var lobes: Array[MeshInstance3D] = []
var dust: Array[MeshInstance3D] = []
var arcs: Array[MeshInstance3D] = []
var tongues: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var flash: MeshInstance3D
var light: OmniLight3D
static func spawn(parent: Node, ground: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	return fx
func surface(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = Lib.material("blast_lobes_surface")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
func band(width: float) -> MeshInstance3D:
	var node: MeshInstance3D = Ribbon.new()
	node.material_override = Lib.material("blast_lobes_stroke", {"width": width * _size})
	add_child(node)
	return node
func start(size: float) -> void:
	_size = maxf(size, 0.05)
	life = 3.75
	cap = surface(_revolve(false))
	stem = surface(_revolve(true))
	for i in 7:
		lobes.append(surface(Lib.cloud_mesh(i % 3)))
	for i in 12:
		dust.append(surface(Lib.cloud_mesh(i % 3)))
	for i in 4:
		arcs.append(band(0.16))
	for i in 16:
		tongues.append(band(0.35))
	for i in 22:
		sparks.append(band(0.085))
	flash = sprite(2, Color(10,7,2), _size)
	flash.position.y = _size * 0.7
	param(flash,"toward_camera",_size * 1.5)
	light = lamp(Color(1,0.4,0.08), _size * 12)
	_pose(0.0)
func _tick(_delta: float) -> void:
	var f := int(age * 15.0)
	if f != _frame:
		_frame = f
		_pose(float(f) / 15.0)
func heat(node: MeshInstance3D, t: float) -> void:
	param(node,"heat",clampf(1.0-t,0,1))
	param(node,"phase",age)
func _pose(t: float) -> void:
	var grow := ease_out(clampf((t-0.02)/0.32,0,1)) * (1.0+minf(t,1.8)*0.19)
	var split := clampf((t-0.78)/0.42,0,1)
	cap.visible = t > 0.03 and t < 1.2
	cap.position.y = (0.55+2.5*minf(grow,1)+t*0.6)*_size
	cap.scale = Vector3(2.25,4.6,2.1)*_size*maxf(0.01,grow)*(1.0-split)
	heat(cap,(t-0.7)/0.55)
	stem.visible = t > 0.03 and t < 1.35
	stem.scale = Vector3(1.25,maxf(0.01,cap.position.y/_size),1.15)*_size*maxf(0.01,1.0-clampf((t-0.75)/0.6,0,1))
	heat(stem,(t-0.6)/0.6)
	for i in lobes.size():
		var n := lobes[i]
		var a := float(i)*TAU/7.0
		var end_start := 1.48+float(i)*0.16
		var k := clampf((t-end_start)/0.95,0,1)
		var opening := ease_out(clampf((t-0.68)/0.55,0,1))
		n.visible = t >= 0.68 and k < 0.85
		var dir := Vector3(cos(a),0,sin(a))
		var radius := 1.05+opening*0.95 - sin(k*PI)*0.65
		var y := 3.35 + 0.18*sin(a*3.0) + opening*0.65+k*1.1
		n.position = (dir*radius+Vector3.UP*y)*_size
		var s := maxf(0.002,1.0-pow(k,1.7))
		n.scale = Vector3(2.65*s*s,2.45*s*(1.0+k),2.4*s*s)*_size*opening
		n.rotation = Vector3(k*2.7,a,-k*1.3)
		param(n,"curl",k)
		param(n,"opacity",1.0-clampf((k-0.45)/0.38,0,1))
		heat(n,(t-0.72)/0.62)
	for i in dust.size():
		var n := dust[i]
		var a := float(i)*2.39996
		var k := clampf((t-0.72-float(i%3)*0.08)/1.0,0,1)
		var g := ease_out(clampf(t/0.35,0,1))
		n.visible = t > 0.03 and k < 1.0
		n.position = (Vector3(cos(a),0,sin(a))*(0.35+g*1.9+k*1.8)+Vector3.UP*(0.5*(1-k)+0.04))*_size
		n.scale = Vector3(1.25+k*1.2,1.15*pow(1-k,2),1.2*(1-k))*_size*g
		n.rotation.y = -a
		heat(n,(t-0.35)/0.55)
	flash.visible = t < 0.14
	flash.scale = Vector3.ONE*_size*(0.5+4.5*ease_out(clampf(t/0.14,0,1)))
	param(flash,"color",Color(10,7,2,maxf(0,1-t/0.14)))
	light.light_energy = _size*26.0*pow(maxf(0,1-t/1.2),2)
	for i in arcs.size():
		var n := arcs[i]
		var k := clampf((t-0.8-float(i)*0.04)/0.55,0,1)
		n.visible = t > 0.12 and k < 1
		var pts := PackedVector3Array()
		var radius := 1.8+4.2*ease_out(clampf((t-0.12)/1.2,0,1))
		for j in 30:
			var q := float(j)/29
			var a := float(i)*TAU/4+(k+(1-k)*q)*1.45
			pts.append(global_position+Vector3(cos(a)*radius,2.3+t*0.65,sin(a)*radius)*_size)
		n.draw(pts)
		param(n,"heat",1.0)
		param(n,"thin",1-k)
	for i in tongues.size():
		var n := tongues[i]
		var dt := t-float(i%4)*0.04
		var k := clampf(dt/1.15,0,1)
		n.visible = dt > 0 and k < 1
		var a := float(i)*2.39996
		var dir := Vector3(cos(a),0,sin(a))
		var stretch := ease_out(clampf(k*3,0,1))*(1-pow(k,2))
		var pts := PackedVector3Array()
		for j in 10:
			var q := float(j)/9
			var p := dir*(0.2+(1-q)*(1.7+_hash(i)*2.3)*stretch)
			p.y = 0.07+(1-q)*(0.5+_hash(i+8)*2.0)*sin(k*PI)+sin(q*PI)*k*0.5
			pts.append(global_position+p*_size)
		n.draw(pts)
		param(n,"heat",1-k)
		param(n,"thin",pow(1-k,0.7))
	for i in sparks.size():
		var n := sparks[i]
		var dt := t-0.18-_hash(i)*0.18
		var duration := 0.7+_hash(i+2)*0.65
		n.visible = dt > 0 and dt < duration
		if not n.visible: continue
		var pts := PackedVector3Array()
		for j in 7:
			var old := maxf(0,dt-float(j)/6*0.16*(1-dt/duration))
			pts.append(global_position+spark_position(i,old)*_size)
		n.draw(pts)
		param(n,"heat",1-dt/duration)
		param(n,"thin",1-dt/duration)
func spark_position(i: int, t: float) -> Vector3:
	var a := float(i)*2.39996
	var distance := (2.5+_hash(i)*3.0)*(1-exp(-1.4*t))/1.4
	return Vector3(cos(a)*distance,0.65+(3.8+_hash(i+3)*3.0)*t-5.5*t*t,sin(a)*distance)

static func _revolve(stem: bool) -> ArrayMesh:
	var rings := 18
	var sides := 64
	var points := PackedVector3Array()
	var uv := PackedVector2Array()
	for j in range(rings + 1):
		var v := float(j) / rings
		for i in range(sides + 1):
			var u := float(i) / sides
			var a := u * TAU
			var r := 0.17 + 0.13 * sin(v * PI) + 0.35 * pow(v, 4) if stem else pow(sin(v * PI), 0.55)
			r = maxf(r, 0.008)
			var lobe := 1.0 + 0.065 * sin(a * 7.0 + v * 4.0) + 0.025 * sin(a * 13.0 - v * 7.0)
			var y := v if stem else (v - 0.5) * 0.9 + 0.035 * sin(a * 6.0) * sin(v * PI)
			points.append(Vector3(cos(a) * r * lobe + (0.08 * sin(v * 4) if stem else 0.0), y, sin(a) * r * lobe))
			uv.append(Vector2(u, v))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings:
		for i in sides:
			var a := j * (sides + 1) + i
			var b := a + sides + 1
			for id in [a, a + 1, b, a + 1, b + 1, b]:
				st.set_uv(uv[id])
				st.add_vertex(points[id])
	st.generate_normals()
	return st.commit()

static func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 127.1 + 31.7) * 43758.5453, 1.0)

