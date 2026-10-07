extends "res://vfx/vfx_base.gd"
# Motif: opposing fruit-wall fibres store torque, then explosively disperse seeds.
# Smithsonian NMNH / Plant Press: explosive-fossil-fruit-found-buried-beneath-ancient-indian-lava-flows
# Five closed valves peel from tip to root, recoil into curls, then settle folded.
# No noise dissolution; shell curvature and width change locally, not node scale.
const LENGTH_STEPS := 42
const WIDTH_STEPS := 6
var _size := 1.0
var _valves: Array[MeshInstance3D] = []
var _seeds: Array[MeshInstance3D] = []
var _seed_mat: StandardMaterial3D

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx := new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx

func start(size: float) -> void:
	_size = size
	life = 4.4
	for i in 5:
		var shell := MeshInstance3D.new()
		shell.mesh = ImmediateMesh.new()
		shell.material_override = Lib.material("motif_seed_shell")
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.extra_cull_margin = 5.0*size
		add_child(shell)
		_valves.append(shell)
	_seed_mat = StandardMaterial3D.new()
	_seed_mat.albedo_color = Color(0.62,0.28,0.04)
	_seed_mat.roughness = 0.32
	for i in 9:
		var seed := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.09*size
		mesh.height = 0.29*size
		mesh.radial_segments = 10
		mesh.rings = 5
		seed.mesh = mesh
		seed.material_override = _seed_mat
		seed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seed)
		_seeds.append(seed)
	_tick(0)

func _tick(_delta: float) -> void:
	for i in 5:
		_draw_valve(i)
	for i in 9:
		var seed := _seeds[i]
		var t := age-(0.72+float(i%3)*0.047)
		seed.visible = t>=0 and t<2.65
		if not seed.visible: continue
		var a := float(i)*2.39996+0.35
		var velocity := Vector3(cos(a)*(3.8+float(i%2)),4.1+float(i%3)*0.6,sin(a)*(3.8+float(i%2)))
		var p := Vector3(0,2.15,0)+velocity*(1.0-exp(-t*1.2))/1.2+Vector3.DOWN*3.9*t*t
		if p.y<0.09:
			var landing := (velocity.y+sqrt(velocity.y*velocity.y+4.0*3.9*2.06))/7.8
			var bounce := maxf(t-landing,0)
			p.y=0.09+maxf(0,sin(bounce*9.0))*0.24*exp(-bounce*5.0)
		seed.position=p*_size
		seed.rotation=Vector3(t*7.0+i,t*3.5,0.6+t*4.0)
		# Solid seeds sink after their bounce, rather than turning into glowing particles.
		if t>2.25: seed.position.y -= (t-2.25)*_size

func _draw_valve(index: int) -> void:
	var mesh := _valves[index].mesh as ImmediateMesh
	mesh.clear_surfaces()
	var growth := smoothstep(0.02,0.40,age)
	if growth<0.002: return
	var delay := 0.64+float(index)*0.028
	var release := age-delay
	var a := float(index)*TAU/5.0+0.28
	var outward := Vector3(cos(a),0,sin(a))
	var sideways := Vector3(-sin(a),0,cos(a))
	var centres: Array[Vector3] = [Vector3(0,0.12,0)]
	var widths: Array[float] = [0.0]
	var heading: Array[Vector3] = [Vector3.UP]
	var peel_front := clampf(release/0.36,0,1.3)
	var rebound := exp(-maxf(release-0.40,0)*2.2)*sin(maxf(release-0.40,0)*11.0)*0.33
	var fold := smoothstep(2.3,3.6,age)
	for j in range(1,LENGTH_STEPS+1):
		var u := float(j)/LENGTH_STEPS
		var peel := smoothstep(1.0-u-0.08,1.0-u+0.13,peel_front)
		var closed_angle := atan(0.88*PI*cos(PI*u)/2.55)
		var open_angle := 0.42+u*(4.3+float(index)*0.18)+rebound*sin(u*PI)+fold*u*2.8
		var angle := lerpf(closed_angle,open_angle,peel)
		var twist := peel*sin(u*3.1-release*2.5)*0.26*u
		var direction := (Vector3.UP*cos(angle)+outward*sin(angle)+sideways*twist).normalized()
		var step := 3.6/float(LENGTH_STEPS)*growth
		centres.append(centres[-1]+direction*step)
		heading.append(direction)
		var w := 0.69*pow(maxf(sin(PI*u),0),0.72)
		w *= 1.0-0.45*peel*u
		w *= 1.0-0.88*fold*pow(u,0.65)
		widths.append(w)
	var settle := smoothstep(1.65,3.45,age)
	var sink := smoothstep(3.55,4.20,age)*0.70
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in LENGTH_STEPS:
		for k in WIDTH_STEPS:
			for cell in [[j,k],[j+1,k],[j+1,k+1],[j,k],[j+1,k+1],[j,k+1]]:
				var l: int = cell[0]
				var v := float(cell[1])/WIDTH_STEPS
				var u := float(l)/LENGTH_STEPS
				var centre := centres[l]
				var lift := smoothstep(0.27,0.58,release)*(1.0-smoothstep(1.4,2.6,age))
				centre += outward*(settle*(0.42+0.12*index)+lift*0.45)
				centre.y += lift*0.9-settle*0.38-sink
				var width := widths[l]
				var bow := sin(v*PI)*0.19*width
				var normal := heading[l].cross(sideways).normalized()
				var point := centre+sideways*(v-0.5)*width*2.0+normal*bow
				mesh.surface_set_normal(normal)
				mesh.surface_set_uv(Vector2(u,v))
				mesh.surface_add_vertex(point*_size)
	mesh.surface_end()
	param(_valves[index],"fade",1.0-smoothstep(4.03,4.3,age))
