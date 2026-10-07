extends "res://vfx/vfx_base.gd"
# NASA Parker Solar Probe switchbacks: reconnecting magnetic loops / recoil.
# https://www.nasa.gov/science-research/heliophysics/switchbacks-science-explaining-parker-solar-probes-magnetic-puzzle/
# Exit: hot loops drain to their two feet after reconnecting; ejecta cools in flight.
var _size := 1.0
var _bands: Array[MeshInstance3D] = []
static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx
func start(size: float) -> void:
	_size = size
	life = 4.4
	for i in 3:
		var band := MeshInstance3D.new()
		band.mesh = ImmediateMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://vfx/shaders/motif_solar.gdshader")
		band.material_override = mat
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
		_bands.append(band)
	_tick(0)
func _point(q: float, i: int, t: float) -> Vector3:
	var grow := smoothstep(0.0, 0.9, t-float(i)*0.16)
	var recoil := smoothstep(1.85,3.65,t)
	# Reconnected legs drain along the curved route to their own feet.
	# Contracting height alone leaves a squashed copy of the whole arch.
	q = q*(1.0-recoil) if q<0.5 else 1.0-(1.0-q)*(1.0-recoil)
	var s := -1.0 if i == 0 else 1.0
	var h := sin(q*PI)
	var join := smoothstep(1.05,1.6,t)
	var x := s*(0.82*cos(q*TAU)+0.52)*(1.0-join*h*0.63)+join*sin(q*TAU)*sin((t-1.45)*3.4)*0.8*h
	var y := 0.10+h*(3.7+0.55*sin(q*TAU+t*3.0)+join*s*sin(q*TAU)*0.65)*grow
	var z := s*sin(q*TAU)*0.72*h+sin(q*PI*3.0-t*3.0)*0.20*h
	return Vector3(x,y,z*(1.0-recoil))*_size
func _tick(_delta: float) -> void:
	for i in 3:
		var mesh_band := _bands[i].mesh as ImmediateMesh
		mesh_band.clear_surfaces()
		var heat := 1.0-smoothstep(2.1,3.9,age)
		if i < 2:
			if age < i*0.16 or age>3.95: continue
			param(_bands[i],"heat",heat)
			param(_bands[i],"phase",age)
			mesh_band.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in 58:
				if age>1.85 and j in [28,29]: continue
				for k in 10:
					for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
						var q: float = (j+corner.x)/58.0
						var a: float = (k+corner.y)/10.0*TAU
						var p := _point(q,i,age)
						var tangent := (_point(minf(q+0.006,1),i,age)-_point(maxf(q-0.006,0),i,age)).normalized()
						var side := tangent.cross(Vector3.FORWARD).normalized()
						var normal := side*cos(a)+tangent.cross(side)*sin(a)
						var width := (0.10+0.26*pow(maxf(0.0,sin(q*PI)),1.4)+0.10*sin(q*16.0-age*7.0))*smoothstep(0,0.5,age-i*0.16)*(1.0-smoothstep(3.1,3.95,age))
						mesh_band.surface_set_uv(Vector2(q,a/TAU))
						mesh_band.surface_set_normal(normal)
						mesh_band.surface_add_vertex(p+(side*cos(a)+tangent.cross(side)*sin(a)*0.35)*maxf(width,0.005)*_size)
			mesh_band.surface_end()
		else:
			var dt := age-1.52
			if dt<0 or dt>1.05: continue
			param(_bands[i],"heat",1.0-smoothstep(0.2,0.82,dt))
			param(_bands[i],"phase",age)
			mesh_band.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for j in 22:
				var q: float = j/21.0
				var emitted := q*0.28
				var d := maxf(0.0,dt-emitted)
				var p := Vector3(0.4+d*3.0,3.2+d*4.6-d*d*4.8,sin(d*4)*0.2)
				var width := sin(q*PI)*(0.52+0.22*sin(q*8-age*7))*(1-smoothstep(0.4,0.82,dt))
				for side in [-1,1]:
					mesh_band.surface_set_uv(Vector2(q,float(side+1)/2))
					mesh_band.surface_add_vertex((p+Vector3(-0.7,0.7,0)*width*side)*_size)
			mesh_band.surface_end()


