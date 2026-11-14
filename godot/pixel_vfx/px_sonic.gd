extends "res://pixel_vfx/px_base.gd"
# 素材：三打の有限長音圧波。先頭の広い肩が右へ先行し、遅れる腹が首で繋がる。
# .35s初打/1.15sやや低い第二打/2.10s短い最終打。1.0s肩のせり上がり、1.8s腹が割れ、2.7s尾が離れる。
# 各打撃の供給は短い。外の疎い圧力膜が速く、内の腹は遅れ、短い白芯は前面へ運ばれる。
# 円を拡縮せず、中心線・幅・前後窓を12fpsで再構築。寿命ノイズ穴0層。気体cubeなし。
const COLORS := [Vector3(.07,.045,.11),Vector3(.26,.19,.34),Vector3(.70,.48,.30),Vector3(1.40,1.00,.64),Vector3(2.65,2.55,2.13)]
const STRIKES := [.35,1.15,2.10]
var _size:=1.0
var _waves:Array=[]
var _light:OmniLight3D

static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

func start(size:float)->void:
	_size=size
	life=5.3
	for i in 3:
		var layers:Array=[]
		for k in 3:
			var mi:=MeshInstance3D.new()
			mi.material_override=material("px_sonic",COLORS,{"seed":float(i)*1.13+float(k)*.29,"layer":float(k)})
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin=3.0
			add_child(mi)
			layers.append(mi)
		_waves.append(layers)
	_light=lamp(COLORS[3],7.0*size)
	_light.position.y=1.0*size
	_step(0.0)

func _step(t:float)->void:
	_light.light_energy=0.0
	for i in 3:
		var dt:float=t-STRIKES[i]
		_light.light_energy+=.85*_size*exp(-maxf(dt,0.0)*5.0) if dt>=0.0 else 0.0
		for k in 3:
			var mi:MeshInstance3D=_waves[i][k]
			var elapsed:=dt-float(k)*.045
			mi.visible=elapsed>0.0 and elapsed<2.2
			if not mi.visible:
				continue
			var rate:=2.05+float(i)*.17
			var front:=elapsed*rate
			var tail:=maxf(0.0,front-(1.31 if i!=2 else .93))
			mi.mesh=_wave_mesh(i,k,t,tail,front)
			param(mi,"phase",t)

func _wave_mesh(i:int,k:int,t:float,tail:float,front:float)->ArrayMesh:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var elapsed:float=t-STRIKES[i]-float(k)*.045
	var leading:=clampf(elapsed/.40,0.0,1.0)
	var cleared:=clampf((elapsed-1.10)/1.10,0.0,1.0)
	for j in 23:
		var v:=float(j)/22.0
		var u:=lerpf(cleared,leading,v)
		var shoulder:=clampf(.29+elapsed*(.39+float(i)*.025),.29,.94)
		var belly:=.14+elapsed*.20
		var radius:=.73*exp(-pow((u-shoulder)/.19,2.0))+.39*exp(-pow((u-belly)/.14,2.0))+.065
		radius*=pow(sin(PI*v),.24)
		if k==2:
			radius*=exp(-pow((u-shoulder)/.13,2.0))
		var ratio:float=[1.0,.72,.19][k]
		# Pressure forms an OPEN crest, with its middle lagging the high shoulder.
		# The lower supply window clears while the crest keeps travelling forward.
		var lag:=.84*pow(sin(PI*u),2.0)+.35*sin(u*6.4-elapsed*2.6+float(i))*sin(PI*u)
		var center:=Vector3(front-lag,.13+u*(2.30+float(i)*.17)+.16*sin(u*8.0+elapsed*2.6),-.28+float(i)*.27+.19*cos(u*3.1+elapsed))
		center.y+=.30*smoothstep(2.8,4.6,t)
		center.z-=.65*smoothstep(2.8,4.6,t)
		center*= _size
		for s in 5:
			var a:=float(s)/4.0
			var point:=center+(Vector3.RIGHT*(a*2.0-1.0)*radius*ratio+Vector3.BACK*(sin(a*PI)*.16+float(k)*.045))*_size
			vertices.append(point.snapped(Vector3.ONE*.065*_size))
			normals.append(Vector3.BACK)
			uv.append(Vector2(a,u))
	for j in 22:
		for s in 4:
			var n:=j*5+s
			indices.append_array(PackedInt32Array([n,n+5,n+1,n+1,n+5,n+6]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
