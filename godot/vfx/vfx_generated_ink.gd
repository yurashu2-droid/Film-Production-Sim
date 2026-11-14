extends "res://vfx/vfx_base.gd"
# 生成墨金流渦: 素材は墨と液体金。画像生成4素材の本物alphaを流路/拍/着地に使う。
# .0–.55: 足元で供給を溜める。先頭 .52秒から巻き上がり、後の腹は遅れて追う。
# .55–1.95: 放出時刻ごとの速度/首/曲率が違う2流路×4薄層。毎frame継ぎ目なく再構築。
# 1.67–3.04: 生成16frameの弾ける拍を3つの曲面と時差で接続。最大拍は約2.05。
# 1.45で供給停止。金は上側の接線へ先に抜け、白芯は短拍のみ。墨は重力落下。
# 着地点は同じ素材の軌道から計算、splash染みへ。染みは横方向へ吸われる前線で乾く。
# .0–5.3: 素材の移送と有限cohortの出口。寿命noise穴0。固体scale/固定板伸縮なし。
const FLOW := preload("res://vfx/shaders/generated_ink_flow.gdshader")
const STAIN := preload("res://vfx/shaders/generated_ink_stain.gdshader")
const BURST := preload("res://vfx/shaders/generated_ink_burst.gdshader")
const ASSETS := "res://assets/vfx/generated_ink/"
const SUPPLY := 1.45
var _size := 1.0
var _flows: Array = []
var _stains: Array = []
var _bursts: Array = []
var _light: OmniLight3D
static var _images: Dictionary = {}

static func spawn(parent: Node, pos: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

static func _texture(name: String) -> Texture2D:
	if not _images.has(name):
		var im := Image.load_from_file(ProjectSettings.globalize_path(ASSETS+name+".png"))
		im.generate_mipmaps()
		_images[name]=ImageTexture.create_from_image(im)
	return _images[name] as Texture2D

func _surface(shader: Shader, image_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("image",_texture(image_name))
	if shader==FLOW or shader==STAIN:
		mat.set_shader_parameter("relief",_texture("height"))
		mat.set_shader_parameter("normal_tex",_texture("normal"))
		mat.set_shader_parameter("ao_tex",_texture("ao"))
		mat.set_shader_parameter("roughness_tex",_texture("roughness"))
	mi.material_override=mat
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func start(size: float) -> void:
	_size=size
	life=6.0
	for j in 2:
		var row: Array = []
		for k in 4:
			var mi := _surface(FLOW,"ink" if k<2 else "gold")
			param(mi,"layer",float(k))
			param(mi,"seed",float(j)*.37)
			row.append(mi)
		_flows.append(row)
	for j in 2:
		for index in 5:
			var e := .04+float(index)/4.0*1.36
			var landing_time := _landing_time(j,e)
			var point := _curve(j,e,landing_time,0)
			var mi := _surface(STAIN,"splash")
			mi.mesh=_ground_patch(point,1.03+.12*sin(index*2.0+j),float(j)*1.8+index*.7)
			param(mi,"seed",float(index+j*5)*.13)
			_stains.append([mi,landing_time])
	for j in 3:
		var mi := _surface(BURST,"burst_4x4")
		_bursts.append(mi)
	_light=lamp(Color(1.0,.55,.15),5.5*size)
	_light.position=Vector3(0,1.0,0)*size
	_tick(0)

func _landing_time(j: int,e: float) -> float:
	var launch := .52+e*.76+float(j)*.105
	var v := 3.75+e*.38
	return launch+(v+sqrt(v*v+4.0*1.72*.08))/(2.0*1.72)

func _curve(j: int,e: float,t: float,k: int) -> Vector3:
	var launch := .52+e*.76+float(j)*.105
	var q := maxf(t-launch,0.0)
	var a := float(j)*3.67-q*3.2+e*.57
	var r := .30+.53*sin(minf(q,1.5)*1.8)+.18*e
	var head := exp(-pow((e-.20)/.22,2.0))
	var belly := exp(-pow((e-.91)/.26,2.0))
	r+=.18*head*sin(q*2.0)-.12*belly
	var p := Vector3(cos(a)*r,.08+(3.75+e*.38)*q-1.72*q*q,sin(a)*r)
	p.x+=.20*sin(e*5.4+q*3.0)*q
	p.z+=.12*cos(e*4.5-q*2.1)*q
	var blast := maxf(t-2.05,0.0)
	p+=Vector3(-.48 if j==0 else .62,0,.22 if j==0 else -.38)*blast*minf(q,.9)
	if k>=2 and q>.65:
		var s := q-.65
		var a0 := float(j)*3.67-.65*3.2+e*.57
		p=Vector3(cos(a0)*r, .08+(3.75+e*.38)*.65-1.72*.65*.65,sin(a0)*r)
		p+=Vector3(-sin(a0),.25,cos(a0))*s*1.45
	if t<launch:
		p.y=.075+.14*e+.10*sin(e*5.0+t*4.5)
	return p

func _flow_mesh(j: int,k: int,t: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := minf(t,SUPPLY)
	var points: Array[Vector3] = []
	var emissions: Array[float] = []
	for n in 33:
		var e := top*float(n)/32.0
		var q := t-(.52+e*.76+float(j)*.105)
		# Gold takes a short tangential outlet before the ink shoulder overturns.
		if (k<2 and t>=_landing_time(j,e)) or (k>=2 and q>.98):
			continue
		points.append(_curve(j,e,t,k))
		emissions.append(e)
	if points.size()<2:
		return ArrayMesh.new()
	for n in range(points.size()-1):
		var tangent := (points[mini(n+1,points.size()-1)]-points[maxi(n-1,0)]).normalized()
		if tangent.length_squared()<.01:tangent=Vector3.UP
		var side := tangent.cross(Vector3.FORWARD).normalized()
		if side.length_squared()<.01:side=tangent.cross(Vector3.RIGHT).normalized()
		var up := tangent.cross(side).normalized()
		var tangent2 := (points[mini(n+2,points.size()-1)]-points[n]).normalized()
		if tangent2.length_squared()<.01:tangent2=tangent
		var side2 := tangent2.cross(Vector3.FORWARD).normalized()
		if side2.length_squared()<.01:side2=side
		var up2 := tangent2.cross(side2).normalized()
		for x in 10:
			for d: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var idx := n+int(d.y)
				var e := emissions[idx]
				var u := (float(x)+d.x)/10.0
				var q := maxf(t-(.52+e*.76+float(j)*.105),0.0)
				var neck := exp(-pow((e-.63)/.12,2.0))
				var shoulder := exp(-pow((e-.31)/.25,2.0))
				var radius := (.25+.37*shoulder+.19*sin(e*2.1))*(1.0-.43*neck)
				radius*=minf(.30+q*.90,1.0)
				if k==1:radius*=.70
				elif k==2:radius*=.35
				elif k==3:radius*=.13
				var a := (u-.5)*4.35+float(k)*.38+q*.35
				var s := side if d.y<.5 else side2
				var h := up if d.y<.5 else up2
				var p := points[idx]+s*cos(a)*radius+h*sin(a)*radius*.70
				st.set_normal((s*cos(a)+h*sin(a)).normalized())
				st.set_uv(Vector2(u,1.0-e/SUPPLY))
				st.set_color(Color(q,e,t,1))
				st.add_vertex(p*_size)
	st.generate_tangents()
	return st.commit()

func _ground_patch(center: Vector3,extent: float,yaw: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 12:
		for x in 12:
			for d: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((x+d.x)/12.0,(y+d.y)/12.0)
				var p := Vector3((uv.x-.5)*extent*2.0,.019,(uv.y-.5)*extent*1.7).rotated(Vector3.UP,yaw)
				p.x+=.07*sin(uv.y*8.0+yaw)
				p.z+=.06*sin(uv.x*7.0)
				p+=Vector3(center.x,0,center.z)
				st.set_normal(Vector3.UP)
				st.set_uv(uv)
				st.add_vertex(p*_size)
	st.generate_tangents()
	return st.commit()

func _burst_mesh(j: int,t: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q := t-(1.67+float(j)*.045)
	var yaw := .3+float(j)*2.19
	for y in 18:
		for x in 18:
			for d: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((x+d.x)/18.0,(y+d.y)/18.0)
				var v := 1.0-uv.y
				var shoulder := sin(v*PI)
				var p := Vector3((uv.x-.5)*2.65,v*2.65,.28*sin(uv.x*PI)*shoulder)
				p.x+=.25*sin(v*5.0-q*4.2+float(j))*shoulder
				p.z+=.16*sin(v*7.0+q*3.0+float(j))*shoulder
				p=p.rotated(Vector3.UP,yaw)+Vector3(-.16+.16*j,.02,.02)
				st.set_uv(uv)
				st.set_normal(Vector3.FORWARD.rotated(Vector3.UP,yaw))
				st.add_vertex(p*_size)
	return st.commit()

func _tick(_delta: float) -> void:
	var t := age
	for j in 2:
		for k in 4:
			var mi: MeshInstance3D=_flows[j][k]
			mi.mesh=_flow_mesh(j,k,t)
			param(mi,"phase",t)
	for entry in _stains:
		param(entry[0],"wet_age",t-float(entry[1]))
	for j in 3:
		var mi: MeshInstance3D=_bursts[j]
		mi.mesh=_burst_mesh(j,t)
		param(mi,"local_age",t-(1.67+float(j)*.045))
		param(mi,"layer",float(j))
	_light.light_energy=.75*exp(-pow((t-2.05)/.17,2.0))

