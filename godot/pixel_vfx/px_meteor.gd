extends "res://pixel_vfx/px_base.gd"
# Pixel流星落とし。既存Pixel炎の5色/12fpsと墨の龍の先行肩・後続履歴を参考にした独自案。
# 熱流は左上から斜めに降り、厚い先頭を細い首と火尾が追う。
# .2〜1.2 先頭降下／1.7 接地で圧力を側方へ渡す／2.0〜3.7 短い火舌が前へ抜け昇る。
# 外の赤は遅い尾→接地、中の橙は衝撃の腕→上へ、短い白は先に地表へ消費。
# 主形は放出履歴/局所重力で変わる。寿命ノイズ穴0層。立方体は固体の小石だけ。
const COLORS := [Vector3(.07,.015,.01),Vector3(.6,.07,.015),Vector3(2.0,.43,.04),Vector3(4.0,1.6,.14),Vector3(6.0,5.3,3.0)]
var _size:=1.0
var _body:Array=[]
var _jets:Array=[]
var _ground:Array=[]
var _rocks:MultiMesh
var _light:OmniLight3D
static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx
func start(size:float)->void:
	size*=1.4  # 人（1.7m）に対して主役が小さすぎたので、既定の大きさを上げた（size=1.0 で人と同じくらいの見せ場になる）
	_size=size
	life=4.8
	for k in 3:
		_body.append(_layer(k,k*.47))
		var row:Array=[]
		for j in 4:row.append(_layer(k,j*.72+k*.31))
		_jets.append(row)
		var ground:=quad(material("px_surge_ground",COLORS,{"seed":k*.23,"mode":0}),Vector2.ONE*4.2*size)
		ground.rotation.x=-PI/2.0
		ground.position=Vector3(.85,.022+k*.005,.2)*size
		_ground.append(ground)
	_rocks=voxels(10,6.0*size)
	_light=lamp(COLORS[3],9.0*size)
	_step(0.0)
func _layer(k:int,seed:float)->MeshInstance3D:
	var m:=MeshInstance3D.new()
	m.material_override=material("px_surge_flow",COLORS,{"layer":float(k),"seed":seed})
	m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin=5.0
	add_child(m)
	return m
func _head(t:float)->Vector3:
	var q:=maxf(t-.2,0.0)
	var y:=4.1-1.90*q-0.56*q*q
	return Vector3(-2.45+2.2*q,maxf(-.6,y),-.65+.55*q+.13*sin(q*4.0))*_size
func _step(t:float)->void:
	for k in 3:
		var m:MeshInstance3D=_body[k]
		var front:=t-k*.035
		var tail:=maxf(.20,front-.68)
		m.visible=t>.20 and front<2.47 and tail<1.78
		if m.visible:
			var points:=PackedVector3Array()
			var widths:=PackedFloat32Array()
			for i in 28:
				var u:=float(i)/27.0
				var parcel:=lerpf(tail,minf(front,2.42),u)
				var p:=_head(parcel)
				p.z+=sin(parcel*8.0+k)*.045*_size
				points.append(p.snapped(Vector3.ONE*.045*_size))
				widths.append((.13+.92*exp(-pow((u-.79)/.17,2.0)))*pow(maxf(0.0,sin(u*PI)),.35))
			m.mesh=_tube(points,[.57,.35,.15][k]*_size,widths)
			param(m,"phase",t)
	for k in 3:
		for j in 4:
			var m:MeshInstance3D=_jets[k][j]
			var q:=t-1.72-j*.08-k*.035
			m.visible=q>0.0 and q<1.67-k*.11
			if not m.visible:continue
			var pts:=PackedVector3Array()
			var widths:=PackedFloat32Array()
			var a:=float(j)*1.70+.20
			for i in 24:
				var u:=float(i)/23.0
				var parcel:=maxf(0.0,q-(1.0-u)*.38)
				var reach:=.2+parcel*(1.42+.13*j)
				var p:=Vector3(.85+cos(a)*reach,.10+sin(u*PI)*.43+parcel*.75, .20+sin(a)*reach)
				p.y+=maxf(0.0,parcel-.50)*maxf(0.0,parcel-.50)*.75
				pts.append(p*_size)
				widths.append(pow(maxf(sin(u*PI),0.0),.55)*(1.0-smoothstep(1.10,1.61,parcel)))
			m.mesh=_tube(pts,[.28,.18,.07][k]*_size,widths)
			param(m,"phase",t)
			param(m,"cooled",smoothstep(.7,1.5,q))
	for k in 3:
		var q:=t-1.72-k*.09
		_ground[k].visible=q>0.0 and t<4.25-k*.03
		param(_ground[k],"spread",minf(.9,.12+q*.46))
		param(_ground[k],"sweep",smoothstep(3.45+k*.08,4.22,t))
		param(_ground[k],"cooled",smoothstep(2.7,4.0,t))
	for i in 10:
		var q:=t-1.75-i*.018
		var active:=q>=0.0 and q<1.9
		var p:=Vector3(.85,0.09,.2)
		if active:
			var a:=i*2.4
			p+=Vector3(cos(a)*(1.3+.1*(i%3)),1.7+.14*(i%4),sin(a)*1.6)*q+Vector3.DOWN*3.3*q*q
			if p.y<.07:p.y=.07
		put(_rocks,i,p*_size,.11*_size if active else 0.0,COLORS[0],0.0,.065*_size)
	_light.position=_head(minf(t,1.75))
	_light.position.y=maxf(.4*_size,_light.position.y)
	_light.light_energy=_size*(2.4 if t<1.72 else 6.0)*(smoothstep(.2,.5,t))*(1.0-smoothstep(2.4,3.6,t))
func _tube(points:PackedVector3Array,radius:float,profile:PackedFloat32Array)->ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:Array=[]
	for i in points.size():
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var across:=tangent.cross(Vector3.BACK).normalized()
		if across.length_squared()<.1:across=Vector3.RIGHT
		var depth:=tangent.cross(across).normalized()
		var row:=PackedVector3Array()
		for j in 11:
			var a:=float(j)/10.0*TAU
			var shoulder:=1.0+.14*sin(a*3.0-float(i)*.33-age*3.5)
			row.append(points[i]+(across*cos(a)+depth*sin(a))*radius*profile[i]*shoulder)
		rows.append(row)
	for i in points.size()-1:
		for j in 10:
			for c:Array in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
				st.set_uv(Vector2(float(c[1])/10.0,float(c[0])/float(points.size()-1)))
				st.add_vertex(rows[c[0]][c[1]])
	st.generate_normals()
	return st.commit()
