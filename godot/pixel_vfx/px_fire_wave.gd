extends "res://pixel_vfx/px_base.gd"
# Pixel三連火炎波。既存炎の縦の燃焼を、床の左右へ伝わる三対の波へ変えた独自案。
# 供給は中央の床。先行する前肩を、低く厚い腹と上の遅い舌が追う。
# .25/.90/1.55 三連放出／1〜2.8 肩が伸びて腹が巻き返す／3〜4.35 舌が供給元から切れ昇る。
# 外の暗赤は低い燃焼、中の橙は肩の移流、短い白は先に熱を消費。
# 燃料停止後に下の接続から切れて、上の部分だけが別々に昇る。寿命ノイズ穴0層。
const COLORS:=[Vector3(.07,.015,.01),Vector3(.6,.07,.015),Vector3(2.0,.43,.04),Vector3(4.0,1.6,.14),Vector3(6.0,5.3,3.0)]
const BEATS:=[.25,.90,1.55]
var _size:=1.0
var _waves:Array=[]
var _root:Array=[]
var _light:OmniLight3D
static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx
func start(size:float)->void:
	size*=1.6  # 人（1.7m）に対して主役が小さすぎたので、既定の大きさを上げた（size=1.0 で人と同じくらいの見せ場になる）
	_size=size
	life=5.1
	for n in 3:
		var pair:Array=[]
		for sign_dir in [-1.0,1.0]:
			var layers:Array=[]
			for k in 3:
				var m:=MeshInstance3D.new()
				m.material_override=material("px_surge_flow",COLORS,{"layer":float(k),"seed":n*.77+sign_dir*.3+k*.4,"res":Vector2(15,17),"lane_count":1.0})
				m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				m.extra_cull_margin=7.0
				add_child(m)
				layers.append(m)
			pair.append(layers)
		_waves.append(pair)
	for k in 3:
		var m:=quad(material("px_surge_ground",COLORS,{"seed":k*.24,"mode":1}),Vector2.ONE*(2.0-k*.3)*size)
		m.rotation.x=-PI/2.0
		m.position.y=(.018+k*.004)*size
		_root.append(m)
	_light=lamp(COLORS[3],8.0*size)
	_light.position.y=.65*size
	_step(0.0)
func _step(t:float)->void:
	for n in 3:
		for side in 2:
			var sign_dir:float=-1.0 if side==0 else 1.0
			for k in 3:
				var q:float=t-BEATS[n]-k*.055
				var m:MeshInstance3D=_waves[n][side][k]
				m.visible=q>0.0 and q<2.45-k*.10
				if not m.visible:continue
				var pts:=PackedVector3Array()
				var widths:=PackedFloat32Array()
				for i in 26:
					var u:=float(i)/25.0
					var local_age:=maxf(0.0,q-(1.0-u)*.76)
					var x:=sign_dir*(.28+local_age*1.72)
					var crest_u:=.78+.065*sin(q*2.8+n*.7)
					var shoulder:=exp(-pow((u-crest_u)/.19,2.0))
					var tongue:=pow(maxf(0.0,sin(u*PI*3.0+.25*sin(q*3.0+n))),2.0)
					var detached:=maxf(q-1.26-k*.05-u*.37,0.0)
					var front_fuel:=1.0-smoothstep(1.30,1.86,q)
					var y:=.06+.13*sin(u*PI)+(.49+.06*n)*shoulder*front_fuel
					y+=.09*sin(local_age*5.0+u*5.5)*shoulder*front_fuel
					y+=detached*(.47+tongue*.60)+detached*detached*.24
					x+=sign_dir*detached*(.39+u*.47)
					var z:=sin(u*6.0+local_age*3.5+n)*.14+(k-1)*.12
					pts.append(Vector3(x,y,z)*_size)
					var belly:=.32+.78*exp(-pow((u-(.48+.08*sin(q*2.0)))/.28,2.0))+.22*shoulder
					var end:=pow(maxf(0.0,sin(u*PI)),.4)
					var separated:=lerpf(1.0,tongue,smoothstep(.06,.27,detached))
					widths.append(belly*end*separated*smoothstep(.0,.16,local_age)*(1.0-smoothstep(.25,.68,detached)))
				m.mesh=_sheet(pts,widths,[.60,.39,.15][k]*_size,q,sign_dir)
				param(m,"phase",t)
				param(m,"eaten",smoothstep(1.30+k*.04,2.30-k*.05,q))
				param(m,"cooled",smoothstep(1.45,2.35,q))
	var fuel:=0.0
	for beat:float in BEATS:fuel+=maxf(0.0,1.0-absf(t-beat-.3)/.55)
	for k in 3:
		_root[k].visible=t>.10 and t<3.0-k*.13
		param(_root[k],"spread",.50+.25*minf(fuel,1.0))
		param(_root[k],"cooled",smoothstep(2.1,2.9,t))
		param(_root[k],"sweep",smoothstep(2.30+k*.09,2.95,t))
	_light.light_energy=(fuel*2.3+.3*(1.0-smoothstep(2.0,3.4,t)))*_size
func _sheet(points:PackedVector3Array,widths:PackedFloat32Array,width:float,t:float,sign_dir:float)->ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:Array=[]
	for i in points.size():
		var u:=float(i)/float(points.size()-1)
		var row:=PackedVector3Array()
		for j in 8:
			var v:=float(j)/7.0*2.0-1.0
			var w:=width*widths[i]
			var a:=v*PI*.68
			var flow_bulge:=1.0+.13*sin(v*4.0+u*7.0-t*4.0)
			row.append(points[i]+Vector3(v*w*.065*sign_dir,cos(a)*w*.36*flow_bulge,sin(a)*w*flow_bulge))
		rows.append(row)
	for i in points.size()-1:
		for j in 7:
			for c:Array in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
				st.set_uv(Vector2(float(c[1])/7.0,float(c[0])/float(points.size()-1)))
				st.add_vertex(rows[c[0]][c[1]])
	st.generate_normals()
	return st.commit()
