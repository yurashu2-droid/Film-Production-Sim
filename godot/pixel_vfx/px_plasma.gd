extends "res://pixel_vfx/px_base.gd"
# Pixel圧縮プラズマ。5色/12fpsと、先頭の太い肩・短い遅れ尾を参考にした独自案。
# 左の電荷を曲がる供給路へ圧縮し、短い頭を右へ発射する。
# .0〜1.1 圧力の巻き込み／1.1〜2.18 頭が先行、首が遅れる／2.18〜4.1 進行方向を保った着弾と上方流出。
# 外の青は側方の短い肩へ、中のミントは前へ湾曲、白芯は最初に放出先へ消費。
# 完成物体の拡縮でなく材料の供給履歴を組み直す。寿命ノイズ穴0層。vfx依存なし。
const COLORS:=[Vector3(.018,.018,.10),Vector3(.065,.12,.42),Vector3(.12,.62,1.2),Vector3(.70,1.8,1.6),Vector3(5.0,4.9,3.8)]
var _size:=1.0
var _charge:Array=[]
var _body:Array=[]
var _impact:Array=[]
var _light:OmniLight3D
static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx
func start(size:float)->void:
	size*=2.0  # 人（1.7m）に対して主役が小さすぎたので、既定の大きさを上げた（size=1.0 で人と同じくらいの見せ場になる）
	_size=size
	life=4.9
	for k in 3:
		_charge.append(_layer(k,k*.73))
		_body.append(_layer(k,k*.43+2.0))
		var row:Array=[]
		for j in 2:row.append(_layer(k,4.0+j*.85+k*.3))
		_impact.append(row)
	_light=lamp(COLORS[3],8.0*size)
	_step(0.0)
func _layer(k:int,seed:float)->MeshInstance3D:
	var m:=MeshInstance3D.new()
	m.material_override=material("px_surge_flow",COLORS,{"layer":float(k),"seed":seed,"res":Vector2(18,14)})
	m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin=5.0
	add_child(m)
	return m
func _head(t:float)->Vector3:
	var q:=maxf(0.0,t-1.10)
	return Vector3(-1.85+3.30*q,1.40+.22*sin(q*4.0)+maxf(q-1.08,0.0)*.38,.14*sin(q*5.0))*_size
func _step(t:float)->void:
	for k in 3:
		var m:MeshInstance3D=_charge[k]
		m.visible=t>.02 and t<1.70-k*.055
		if m.visible:
			var pts:=PackedVector3Array()
			var widths:=PackedFloat32Array()
			for i in 30:
				var u:=float(i)/29.0
				var parcel:=maxf(0.0,t-(1.0-u)*.70)
				var angle:=parcel*6.0+k*.17
				var rad:=.47+.16*sin(parcel*4.5+u*2.0)
				var exit:=maxf(t-1.06-.04*k,0.0)*(u*.5+.5)
				var p:=Vector3(-1.88+cos(angle)*rad+exit*2.3,1.35+sin(angle)*rad+exit*.55,sin(angle+u*2.0)*.27)
				pts.append(p*_size)
				widths.append(pow(maxf(0.0,sin(u*PI)),.5)*smoothstep(.0,.15,parcel))
			m.mesh=_tube(pts,[.25,.16,.065][k]*_size,widths)
			param(m,"phase",t)
			param(m,"eaten",smoothstep(1.10+k*.025,1.69-k*.03,t))
	for k in 3:
		var m:MeshInstance3D=_body[k]
		var front:=t-k*.035
		var history:=.33+.065*sin(maxf(0.0,t-1.1)*4.0)
		var tail:=maxf(1.10,front-history)
		m.visible=front>1.10 and front<2.84-k*.06
		if m.visible:
			var pts:=PackedVector3Array()
			var widths:=PackedFloat32Array()
			for i in 28:
				var u:=float(i)/27.0
				var parcel:=lerpf(tail,front,u)
				var p:=_head(parcel)
				p.y+=sin(parcel*9.0+k*.6)*.035*_size
				p.z+=sin(parcel*6.0+u*4.0)*.08*_size
				pts.append(p.snapped(Vector3.ONE*.045*_size))
				var shoulder:=.12+1.02*exp(-pow((u-(.77+.055*sin(t*5.0)))/.18,2.0))
				widths.append(shoulder*pow(maxf(0.0,sin(u*PI)),.3)*(1.0-smoothstep(2.20,2.76,parcel)))
			m.mesh=_tube(pts,[.65,.39,.13][k]*_size,widths)
			param(m,"phase",t)
	for k in 3:
		for j in 2:
			var m:MeshInstance3D=_impact[k][j]
			var q:=t-2.18-j*.09-k*.04
			m.visible=q>0.0 and q<1.9-k*.12
			if not m.visible:continue
			var pts:=PackedVector3Array()
			var widths:=PackedFloat32Array()
			var sg:=1.0 if j==0 else -1.0
			for i in 25:
				var u:=float(i)/24.0
				var parcel:=maxf(0.0,q-(1.0-u)*.37)
				var curl:=sin(u*PI)*(.24+.06*sin(parcel*5.0))
				var p:=Vector3(1.60+parcel*1.55+u*.72,1.48+sg*curl+parcel*.53+maxf(parcel-.50,0.0)*u*.32,sg*(.06+parcel*.12)*sin(u*PI))
				p.z+=sin(parcel*7.0+u*4.0)*.05
				pts.append(p*_size)
				widths.append(pow(maxf(0.0,sin(u*PI)),.6)*(1.0-smoothstep(.82,1.73,parcel))*(1.0-.22*u))
			m.mesh=_tube(pts,[.26,.16,.055][k]*_size,widths)
			param(m,"phase",t)
			param(m,"eaten",smoothstep(.88+k*.045,1.82-k*.03,q))
			param(m,"cooled",smoothstep(.70,1.70,q))
	_light.position=_head(minf(t,2.18))
	_light.light_energy=_size*(1.2*smoothstep(.0,1.0,t)+4.5*maxf(0.0,1.0-absf(t-2.23)/.55))*(1.0-smoothstep(3.2,4.2,t))
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
			var shoulder:=1.0+.16*sin(a*3.0-float(i)*.35-age*4.0)
			row.append(points[i]+(across*cos(a)+depth*sin(a))*radius*profile[i]*shoulder)
		rows.append(row)
	for i in points.size()-1:
		for j in 10:
			for c:Array in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
				st.set_uv(Vector2(float(c[1])/10.0,float(c[0])/float(points.size()-1)))
				st.add_vertex(rows[c[0]][c[1]])
	st.generate_normals()
	return st.commit()
