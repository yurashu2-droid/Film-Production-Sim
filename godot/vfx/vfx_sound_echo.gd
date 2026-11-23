extends "res://vfx/vfx_base.gd"
# 音の反響。参考：音圧の伝播と反射／漫画の短い擬音の肩。ゲーム向けの可視化。
# 供給：左の一点から短い音圧。先行する角張る肩を、遅い外側の弧が追う。
# .3〜1.3: 左→右へ伝播／1.3〜1.8: 見えない右境界で中心が止まり上下が折れる／
# 1.8〜2.8: 短く分裂した弱い返波／2.8〜3.6: さらに小さい二度目の反響。
# 内側の短い白クリームは先に進み抜け、ミントは上へ、青外層は遅れて上へ流出。
# 各角度の到着時差と反射履歴で形を変える。固定した輪のコピーや鏡像ではない。
# 三層の恒常的な空隙。寿命ノイズ穴消し0層。音声はラボ側で付ける。
var _size:=1.0
var _frame:=-1
var _waves: Array=[]

static func spawn(parent: Node, ground: Vector3, size: float=1.0)->Node3D:
	var fx: Node3D=new()
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size)
	preload("res://vfx/vfx_sound_score.gd").attach(fx,"sound_echo")
	return fx

func start(size: float)->void:
	_size=size
	life=5.1
	for wave in 3:
		var layers: Array=[]
		for k in 3:
			var m:=MeshInstance3D.new()
			m.material_override=Lib.material("sound_echo_flow",{"color":[Vector3(.12,.29,.36),Vector3(.42,.75,.68),Vector3(1.45,1.34,.96)][k]*(1.0-wave*.21),"seed":float(k)*2.14+wave*.65,"sparse":[-.05,-.16,.38][k]})
			m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
			layers.append(m)
		_waves.append(layers)
	_pose(0.0)

func _tick(_delta:float)->void:
	_pose(age)

func _pose(t:float)->void:
	var frame:=int(t*30.0)
	if frame==_frame:return
	_frame=frame
	for wave in 3:
		for k in 3:
			var m:MeshInstance3D=_waves[wave][k]
			var start:float=[.25,1.31,2.68][wave]+k*.04
			var stop:float=[1.83,3.11,4.50][wave]+(.1 if k==0 else -.06*k)
			var q:=t-start
			m.visible=q>0.0 and t<stop
			if not m.visible:continue
			var pts:=PackedVector3Array()
			var widths:=PackedFloat32Array()
			for i in 36:
				var u:=float(i)/35.0
				var a:=lerpf(-1.14,1.09,u)
				var front:float=q-absf(a)*[.12,.21,.17][wave]
				var travel:=maxf(front,0.0)
				var height:float=[1.28,.86,.56][wave]
				var x:float
				if wave==0:
					x=-2.10+3.6*minf(travel,1.0)
					# Center reaches first; the late shoulders wrap the boundary.
					x-=smoothstep(1.0,1.45,travel)*(.32+.33*absf(a))
				elif wave==1:
					x=1.50-2.65*travel + .27*sin(a*3.0+travel*3.5)*smoothstep(.08,.6,travel)
				else:
					x=-1.65+1.92*travel+.15*sin(a*4.0-travel*4.0)
				var lift:=maxf(t-([1.42,2.57,3.55][wave]-k*.065),0.0)
				var curl:float=sin(a*2.0+travel*2.7)*[.11,.20,.16][wave]
				var y:float=1.52+sin(a)*height+lift*lift*.95+curl
				var z:float=cos(a)*[.86,.58,.40][wave]+k*.17+sin(travel*3.0+a*3.0)*.10
				x+=cos(a)*(.28+sin(travel*4.2+a)*.14)*(1.0 if wave!=1 else -1.0)+k*.045
				# The forward shoulder sharpens, the return folds at two unequal heights.
				x+=sin(a*2.8)*.25*sin(travel*2.3)+exp(-a*a*8.0)*.19*cos(travel*3.0)
				if wave==1: x+=.32*absf(a)*sin(a*3.4+travel*2.5)
				pts.append(Vector3(x,y,z)*_size)
				var shoulder:=.34+.80*exp(-pow((u-(.70-.10*sin(travel*3.0)))/.20,2.0))
				var end:=pow(maxf(0.0,sin(u*PI)),.65)
				var exiting:=1.0-smoothstep(.38,.85,lift)
				# Different arrival times leave only the moving shoulder after supply stops.
				var supplied:=smoothstep(.0,.14,front)
				var split:=1.0
				if wave==1: split=.28+.72*absf(sin(a*2.7+travel*1.8))
				var short_core:=1.0
				if k==2: short_core=smoothstep(.18,.35,u)*(1.0-smoothstep(.71,.84,u))
				widths.append(maxf(.001,shoulder*end*exiting*supplied*split*short_core))
			m.mesh=_pressure_sheet(pts,widths,[.72,.46,.19][k]*(1.0-wave*.24)*_size,t,k,wave)
			param(m,"phase",t)

# Open curved pressure surfaces. Width is the short transported shoulder, not
# a closed tube/ring. Local arrival compresses the middle before the shoulders.
func _pressure_sheet(pts:PackedVector3Array,widths:PackedFloat32Array,width:float,t:float,k:int,wave:int)->ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:Array=[]
	for i in pts.size():
		var u:=float(i)/float(pts.size()-1)
		var row:PackedVector3Array=PackedVector3Array()
		for j in 8:
			var v:=float(j)/7.0*2.0-1.0
			var lean:=.32*sin(u*4.8-t*2.0+k*.7)
			var compression:=1.0
			if wave==0:compression=1.0-.40*smoothstep(1.1,1.5,t)*(1.0-absf(u-.5)*1.5)
			var shoulder:=width*widths[i]*compression
			var direction:=1.0 if wave!=1 else -1.0
			var p:Vector3=pts[i]+Vector3(v*shoulder*direction, v*lean*shoulder, .25*(1.0-v*v)*shoulder+v*.20*shoulder)
			row.append(p)
		rows.append(row)
	for i in pts.size()-1:
		for j in 7:
			for ij:Array in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
				st.set_uv(Vector2(float(ij[1])/7.0,float(ij[0])/float(pts.size()-1)))
				st.add_vertex(rows[ij[0]][ij[1]])
	st.generate_normals()
	return st.commit()
