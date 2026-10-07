extends "res://vfx/vfx_base.gd"
# Yellowstone NPS How Geysers Work: pressure accumulates, then water unloads.
# https://www.nps.gov/features/yell/tours/fountainpaint/geyser_works.htm
# Column supply stops -> crown folds/falls as sheets -> outward thinning ripples.
# No noise holes; all silhouettes are evolving water trajectories.
var _size := 1.0
var _parts: Array[MeshInstance3D] = []
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
	for i in 5:
		var part := MeshInstance3D.new()
		part.mesh = ImmediateMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://vfx/shaders/motif_geyser.gdshader")
		part.material_override = mat
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)
		_parts.append(part)
	_tick(0)
func _surface(q: float, a: float, crown: bool) -> Vector3:
	var rise := smoothstep(0.52,1.22,age)
	var stop := smoothstep(1.52,2.7,age)
	var h := 3.6*rise*(1.0-stop)
	var radius := 0.32+0.10*sin(q*17.0-age*9.0)+0.05*sin(a*5.0+q*8.0-age*3.0)
	var bend := Vector3(0.25*sin(q*3.5+age*2.3)*q,0,0.18*sin(q*5.0-age*2.0)*q)
	if not crown:
		return (Vector3(cos(a)*radius,h*q+0.06,sin(a)*radius)+bend)*_size
	var release := maxf(0,age-1.02)
	var travel := q*(0.8+release*1.6)
	var scallop := sin(a*5.0+0.3)*0.30+sin(a*3.0-age*2.0)*0.27
	var y := 3.6*rise+sin(q*PI)*(0.52+scallop)-q*q*(0.65+release*release*2.3)-maxf(0,age-1.75)*(2.3+sin(a*5.0)*0.9)
	var r := 0.3+travel*(1+scallop)+sin(q*6.0-release*4.0)*0.12*q
	return Vector3(cos(a)*r+0.16*sin(age*2),maxf(0.065,y),sin(a)*r)*_size
func _tick(_delta: float) -> void:
	for i in 5:
		var m := _parts[i].mesh as ImmediateMesh
		m.clear_surfaces()
		param(_parts[i],"phase",age)
		if i<2:
			if age<(0.52 if i==0 else 1.02) or age> (2.7 if i==0 else 2.85):continue
			m.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in 26:
				for k in 40:
					# Crown has broad curved lips separated by scalloped openings, never bead balls.
					if i==1 and j>10 and k%8<3:continue
					for c in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
						var q: float = (j+c.x)/26.0
						var a: float = (k+c.y)/40.0*TAU
						if i==1 and j>10:
							var center: float = (floor(float(k)/8.0)*8.0+5.5)/40.0*TAU
							a = lerpf(a,center,smoothstep(0.42,1.0,q)*0.52)
						var p := _surface(q,a,i==1)
						var dq := _surface(minf(q+0.01,1),a,i==1)-_surface(maxf(q-0.01,0),a,i==1)
						var da := _surface(q,a+0.01,i==1)-_surface(q,a-0.01,i==1)
						m.surface_set_normal(da.cross(dq).normalized())
						m.surface_set_uv(Vector2(q,a/TAU))
						m.surface_add_vertex(p)
			m.surface_end()
		else:
			var born := 0.0 if i==2 else 2.35+float(i-3)*0.3
			var dt := age-born
			var duration := 0.6 if i==2 else 1.2
			if dt<0 or dt>duration:continue
			m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for k in 81:
				var a: float = float(k)/80*TAU
				var r := (0.35+dt*(0.36 if i==2 else 2.0))*(1+0.035*sin(a*5))
				var width := (0.15 if i==2 else 0.20)*(1-dt/duration)
				for side in [-1,1]:
					m.surface_set_normal(Vector3.UP)
					m.surface_set_uv(Vector2(float(k)/80,float(side+1)/2))
					m.surface_add_vertex(Vector3(cos(a)*(r+width*side),0.03+sin(dt*PI/duration)*0.035,sin(a)*(r+width*side))*_size)
			m.surface_end()





