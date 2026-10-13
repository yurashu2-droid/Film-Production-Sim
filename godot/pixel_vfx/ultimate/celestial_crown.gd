extends Node3D
# 星海の戴冠門 / upper architecture. Original astronomical coronation motif.
# Emissive inscriptions assemble from fragments; finite light packets feed the portal.
# Crown/glyph strokes drain forward; petal shoulders unfurl then depart upward;
# aurora material retains its emission coordinate while it rises and dilutes.
# Clock contract: setup(size), update(seconds). No autonomous process or shader TIME.
const SHADER := preload("res://pixel_vfx/ultimate/shaders/crown_light.gdshader")
const GOLD := Color(1.0, 0.65, 0.21)
const TEAL := Color(0.11, 0.74, 0.79)
const BLUE := Color(0.16, 0.33, 0.81)
const VIOLET := Color(0.57, 0.22, 0.83)
var _size := 1.0
var _nodes: Array[MeshInstance3D] = []
var _verts := PackedVector3Array()
var _uv := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

func setup(size: float) -> void:
	_size = maxf(size, 0.01)
	for i in 7:
		var n := MeshInstance3D.new()
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("mode", 1 if i == 6 else 0)
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.extra_cull_margin = 3.0 * _size
		add_child(n)
		_nodes.append(n)
	update(0.0)

func update(seconds: float) -> void:
	if _nodes.is_empty(): return
	var t := floorf(maxf(seconds, 0.0) * 24.0) / 24.0
	for i in 7:
		_verts.clear(); _uv.clear(); _colors.clear(); _indices.clear()
		match i:
			0: _crown(t)
			1: _banners(t)
			2: _keys(t)
			3: _star_map(t)
			4: _petals(t)
			5: _comets(t)
			6: _aurora(t)
		var n := _nodes[i]
		n.visible = not _verts.is_empty()
		if not n.visible: continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = _verts
		a[Mesh.ARRAY_TEX_UV] = _uv
		a[Mesh.ARRAY_COLOR] = _colors
		a[Mesh.ARRAY_INDEX] = _indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		n.mesh = mesh
		n.material_override.set_shader_parameter("phase", t)

func _ease(x: float) -> float:
	var q := clampf(x, 0, 1)
	return q * q * (3.0 - 2.0 * q)

func _ribbon(points: PackedVector3Array, widths: PackedFloat32Array, col: Color, facing := Vector3.BACK, uv_window := Vector2(0,1)) -> void:
	if points.size() < 2 or col.a < 0.002: return
	var base := _verts.size()
	for j in points.size():
		var tangent := points[mini(j+1, points.size()-1)] - points[maxi(j-1, 0)]
		var cross_dir := tangent.cross(facing).normalized()
		if cross_dir.length_squared() < 0.01: cross_dir = Vector3.RIGHT
		var side := cross_dir * widths[j]
		_verts.append((points[j] - side) * _size)
		_verts.append((points[j] + side) * _size)
		var material_u := lerpf(uv_window.x,uv_window.y,float(j) / (points.size()-1))
		_uv.append(Vector2(material_u, 0))
		_uv.append(Vector2(material_u, 1))
		_colors.append(col); _colors.append(col)
	for j in points.size()-1:
		var q := base+j*2
		_indices.append_array(PackedInt32Array([q,q+1,q+2,q+2,q+1,q+3]))

func _stroke(a: Vector3, b: Vector3, width: float, col: Color, open: float = 1.0, close: float = 0.0) -> void:
	var hi := clampf(open,0,1)
	var lo := clampf(close,0,1)
	if hi <= lo: return
	var points := PackedVector3Array()
	var widths := PackedFloat32Array()
	for i in 7:
		var u := lerpf(lo, hi, float(i)/6.0)
		points.append(a.lerp(b,u))
		widths.append(width * (0.78 + 0.22 * sin(u*PI)))
	_ribbon(points,widths,col,Vector3.BACK,Vector2(lo,hi))

func _crown(t: float) -> void:
	# Arc stones ignite in mirrored cohorts; the moving ignition bead bridges each seam.
	for j in 19:
		var begin := 5.7 + absf(j-9)*0.13
		var opening := _ease((t-begin)/0.55)
		var draining := _ease((t-16.35-absf(j-9)*0.11)/0.85)
		if opening <= 0 or draining >= 1: continue
		var pts := PackedVector3Array()
		var widths := PackedFloat32Array()
		for k in 9:
			var u := lerpf(draining, opening, float(k)/8)
			var a := .13*PI + (j+u*.83)/19.0*.74*PI
			var pulse := sin(t*1.45-a*2.0)*.04
			pts.append(Vector3(cos(a)*(3.92+pulse),5.12+sin(a)*2.04,-.72+sin(a*3.0)*.22))
			widths.append(.087 if j%3 != 0 else .135)
		_ribbon(pts,widths,GOLD,Vector3.BACK,Vector2(draining,opening))
		if j%3 == 0:
			var a := .13*PI+(j+.43)/19.0*.74*PI
			var p := Vector3(cos(a)*4.06,5.12+sin(a)*2.17,-.68)
			var offset := Vector3(cos(a)*.20,sin(a)*.29,0)
			_stroke(p-offset*.2,p+offset,.035,TEAL,opening,draining)
			if j == 9:
				for side in [-1.0, 1.0]:
					var tip := p+Vector3(side*.31,.46,-.08)
					_stroke(p+Vector3(side*.04,.02,0),tip,.053,GOLD,opening,draining)
					_stroke(tip,tip+Vector3(-side*.20,-.02,.10),.046,TEAL,opening,draining)

func _banners(t: float) -> void:
	# Six readable inscriptions, each assembled from separated angular strokes in depth.
	for side in [-1.0,1.0]:
		for row in 3:
			var base_t := 7.4+row*.48+(0.17 if side>0 else 0.0)
			for stroke in 5:
				var show := _ease((t-base_t-stroke*.09)/.5)
				var drain := _ease((t-17.1-row*.23-stroke*.065)/.7)
				if show <= 0 or drain >= 1: continue
				var travel := (1.0-show)*.72+drain*.95
				var p := Vector3(side*(4.02+row*.20),4.95-row*.96+travel,-.72+row*.62+sin(t*.80-row)*.08)
				var a := Vector3.ZERO
				var b := Vector3.ZERO
				if row == 0:
					match stroke:
						0: a=Vector3(-.24,.07,0);b=Vector3(0,.28,0)
						1: a=Vector3(0,.28,0);b=Vector3(.24,.07,0)
						2: a=Vector3(.24,.07,0);b=Vector3(0,-.13,0)
						3: a=Vector3(-.24,.07,0);b=Vector3(-.10,-.07,0)
						4: a=Vector3(0,-.13,0);b=Vector3(0,-.32,0)
				elif row == 1:
					match stroke:
						0: a=Vector3(-.19,.26,0);b=Vector3(-.19,-.26,0)
						1: a=Vector3(-.19,.26,0);b=Vector3(.22,.26,0)
						2: a=Vector3(-.19,.04,0);b=Vector3(.12,.04,0)
						3: a=Vector3(-.19,-.26,0);b=Vector3(.22,-.26,0)
						4: a=Vector3(.22,-.26,0);b=Vector3(.22,-.08,0)
				else:
					match stroke:
						0: a=Vector3(-.22,.26,0);b=Vector3(.08,.26,0)
						1: a=Vector3(.08,.26,0);b=Vector3(.08,.02,0)
						2: a=Vector3(.08,.02,0);b=Vector3(-.10,.02,0)
						3: a=Vector3(-.10,.02,0);b=Vector3(-.10,-.25,0)
						4: a=Vector3(-.10,-.25,0);b=Vector3(.23,-.25,0)
				a.x*=side;b.x*=side
				a*=1.55;b*=1.55
				a.z+=a.x*side*.65;b.z+=b.x*side*.65
				_stroke(p+a,p+b,.061,TEAL.lerp(GOLD,float(row)/5),show,drain)

func _keys(t: float) -> void:
	# Split diamonds fly inward and latch at a different depth; each then releases a tooth upward.
	for j in 5:
		var begin := 9.0+j*.31
		var opening := _ease((t-begin)/.85)
		var departing := _ease((t-16.7-j*.19)/1.25)
		if opening <= 0 or departing >= 1: continue
		var a := .22*PI+j*.14*PI
		var p := Vector3(cos(a)*3.20,5.27+sin(a)*1.08,.42+cos(a*2)*.36)
		var points := [Vector3(0,.28,0),Vector3(.23,0,0),Vector3(0,-.28,0),Vector3(-.23,0,0)]
		for edge in 4:
			var assemble := _ease((t-begin-edge*.07)/.6)
			var leave := _ease((t-16.7-j*.19-edge*.08)/1.0)
			var delta := Vector3((edge-1.5)*(1-assemble)*.43,leave*(.80+edge*.18),leave*.32)
			_stroke(p+points[edge]+delta,p+points[(edge+1)%4]+delta,.067,GOLD,assemble,leave)
		_stroke(p+Vector3(0,-.29,0),p+Vector3(0,-.68,0),.034,BLUE,opening,departing)

func _star_point(j: int,t: float) -> Vector3:
	var a := .12*PI+j*.095*PI
	return Vector3(cos(a)*(4.30+.12*sin(j*2.1)),6.0+sin(a)*(1.31+.16*cos(j*1.7)),-1.55+sin(j*2.3)*.42+sin(t*.4+j)*.035)

func _star_map(t: float) -> void:
	# Stars precede the links: triangulation happens around the rim, never across the void.
	for j in 9:
		var birth := 10.0+j*.12
		var show := _ease((t-birth)/.30)
		var exit := _ease((t-18.0-j*.11)/.7)
		if show <= 0 or exit >= 1: continue
		var a := _star_point(j,t)+Vector3(0,exit*.50,-exit*.25)
		var b := _star_point(j+1,t)+Vector3(0,exit*.50,-exit*.25)
		_stroke(a,b,.032,BLUE.lerp(TEAL,.35),show,_ease((t-17.9-j*.11)/.65))
		_stroke(a+Vector3(-.12,0,0),a+Vector3(.12,0,0),.032,GOLD,show,exit)
		_stroke(a+Vector3(0,-.13,0),a+Vector3(0,.13,0),.032,GOLD,show,exit)
		if j%2 == 0:
			_stroke(a,b+Vector3(0,-.36,-.30),.015,VIOLET,show,exit)

func _petals(t: float) -> void:
	# Broad shoulders unfurl with a root-to-tip lag, then peel into rising narrow filaments.
	for side in [-1.0,1.0]:
		for j in 4:
			var begin := 10.55+j*.20+(0.10 if side>0 else 0.0)
			var opened := _ease((t-begin)/1.1)
			var release := _ease((t-16.0-j*.28)/2.0)
			if opened <= 0 or release >= 1: continue
			var pts := PackedVector3Array()
			var widths := PackedFloat32Array()
			var root_out := _ease((t-16.0-j*.28)/1.95)
			for k in 23:
				var u := lerpf(root_out,1.0,float(k)/22)
				var unfold := _ease((t-begin-u*.65)/.75)
				var up := release*(.25+u*1.40)
				var span := (1.40+j*.12)*unfold
				pts.append(Vector3(side*(2.80+u*span+release*(.20+u*.55)),4.30-j*.31+sin(u*PI)*(.54+j*.08)+up,-.48-j*.35+sin(u*PI*1.6-t*.65+j)*u*.23))
				widths.append(pow(sin(u*PI),.85)*(.23+j*.028)*unfold*(1-release*.35))
			var col := VIOLET.lerp(TEAL,float(j)/4)
			col.a=.62*(1-release*.65)
			_ribbon(pts,widths,col,Vector3.BACK,Vector2(root_out,1.0))

func _comet_path(j: int, q: float, emitted: float) -> Vector3:
	var side := -1.0 if j%2 == 0 else 1.0
	var y := 2.2+float(j%3)*1.18
	return Vector3(side*(4.9-2.55*q),y+sin(q*PI)*(.78+float(j%2)*.33),.65+cos(q*PI*1.3+j)*.60+sin(emitted*1.6)*.1)

func _comets(t: float) -> void:
	# Twelve finite supply windows, material samples move independently; no scaled head mesh.
	for j in 12:
		var birth := 4.1+j*.91
		var duration := 1.0+float(j%3)*.14
		var feed := .40
		var hi := clampf((t-birth)/duration,0,1)
		var lo := clampf((t-birth-feed)/duration,0,1)
		if hi<=lo: continue
		for layer in 2:
			var pts := PackedVector3Array()
			var widths := PackedFloat32Array()
			for k in 19:
				var q := lerpf(lo,hi,float(k)/18)
				var emitted := clampf((t-birth-q*duration)/feed,0,1)
				var p := _comet_path(j,q,emitted)
				p.y+=sin(emitted*TAU*1.2-q*4)*.10*(1-q)
				pts.append(p+Vector3(0,0,layer*.035))
				widths.append((.125 if layer==0 else .045)*pow(sin(emitted*PI),.75)*(1-.55*q))
			_ribbon(pts,widths,TEAL if layer==0 else GOLD)

func _aurora(t: float) -> void:
	# A late sparse veil is emitted behind the crown; old material rises farther and spreads.
	for j in 5:
		var birth := 11.2+j*.33
		var duration := 3.0
		var feed := 4.3
		var hi := clampf((t-birth)/duration,0,1)
		var lo := clampf((t-birth-feed)/duration,0,1)
		if hi<=lo: continue
		var pts := PackedVector3Array()
		var widths := PackedFloat32Array()
		for k in 29:
			var q := lerpf(lo,hi,float(k)/28)
			var emitted := clampf((t-birth-q*duration)/feed,0,1)
			var x := (j-2)*1.04
			pts.append(Vector3(x+sin(q*5-emitted*4+j)*(.12+q*.32),5.75+q*2.1,-1.80+sin(q*4+j*.8)*.38))
			widths.append((.62+q*.32)*pow(sin(emitted*PI),.7)*pow(1-q,.65))
		var color := TEAL.lerp(VIOLET,float(j)/4)
		color.a=.75
		_ribbon(pts,widths,color)
