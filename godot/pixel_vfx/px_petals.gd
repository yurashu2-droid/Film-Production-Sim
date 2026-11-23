extends "res://pixel_vfx/px_base.gd"
# 素材：花芯が放した薄い花弁。先に風を受ける先端、遅れて折れる腹と付け根。
# .3s芯から最初の弁/.9s異なる高さで二群が分かれる/1.8s折れ目が先端から腹へ移る。
# 全体の輪を作らず、違う放出時刻と風でねじれる。2.3sから全弁が同じ突風で風下へ流出。
# 外の縁は早い風、中の腹は遅れた風、短い芯は更に遅れて追う。寿命穴消し0層。
const COLORS := [Vector3(.16,.035,.045),Vector3(.50,.11,.16),Vector3(.95,.31,.30),Vector3(1.46,.70,.56),Vector3(2.1,1.52,1.10)]
const ANGLES := [-.2,.65,2.0,3.55,4.20,5.62,1.45,3.08]
const DELAYS := [.16,.35,.62,.82,1.04,1.27,1.48,1.70]
var _size:=1.0
var _petals:Array=[]
var _light:OmniLight3D

static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

func start(size:float)->void:
	size*=1.5  # 人（1.7m）に対して主役が小さすぎたので、既定の大きさを上げた（size=1.0 で人と同じくらいの見せ場になる）
	_size=size
	life=5.0
	for i in 8:
		var layers:Array=[]
		for k in 3:
			var mi:=MeshInstance3D.new()
			mi.material_override=material("px_petals",COLORS,{"seed":float(i),"layer":float(k)})
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin=3.0
			add_child(mi)
			layers.append(mi)
		_petals.append(layers)
	_light=lamp(COLORS[3],5.0*size)
	_light.position.y=.4*size
	_step(0.0)

func _wind(dt:float,i:int)->Vector3:
	var a:float=ANGLES[i]
	var open:=1.0-exp(-maxf(dt,0.0)*4.0)
	var gust:=maxf(dt+DELAYS[i]-2.3,0.0)
	var x:=cos(a)*.61*open+dt*.65+gust*gust*1.85
	var y:=.12+open*(.65+float(i%3)*.44)+.27*sin(dt*(2.0+float(i)*.09)+a)-dt*.10
	# The common gust carries every finite petal diagonally toward +X / -Z.
	var z:=sin(a)*.56*open+.31*sin(dt*1.7+a)*open-gust*gust*.60
	return Vector3(x,maxf(y,.12),z)*_size

func _step(t:float)->void:
	_light.light_energy=.60*_size*(1.0-smoothstep(1.75,2.55,t))
	for i in 8:
		var dt:float=t-DELAYS[i]
		for k in 3:
			var mi:MeshInstance3D=_petals[i][k]
			var lag:=float(k)*.075
			mi.visible=dt>lag and dt<4.60+lag
			if not mi.visible:
				continue
			mi.mesh=_petal_mesh(i,k,dt-lag)
			param(mi,"phase",t)

func _petal_mesh(i:int,k:int,dt:float)->ArrayMesh:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var length:=.78+float(i%3)*.12
	var ratio:float=[1.0,.74,.30][k]
	var unfurl:=1.0-exp(-dt*5.0)
	# Keep the finite petal length under the common accelerating gust.
	# The tip still samples newer wind than the belly, but its delay shortens as transport speeds up.
	var gust_age:=maxf(dt+DELAYS[i]-2.3,0.0)
	var wind_delay:=.26/(1.0+gust_age*2.3)
	for j in 17:
		var u:=float(j)/16.0
		var local_age:=maxf(dt-(1.0-u)*wind_delay,0.0)
		var center:=_wind(local_age,i)
		var curl:=sin(u*4.8-dt*3.0+float(i))
		center+=Vector3((u-.5)*length,.15*curl*unfurl,.10*cos(u*5.0+dt*2.0+float(i)))*_size
		var side:=Vector3(.12*sin(dt+float(i)),.80*cos(dt*1.5+float(i)),.60*sin(dt*1.5+float(i))).normalized()
		var width:=(.24+float(i%2)*.045)*pow(sin(PI*u),.62)*ratio*unfurl*_size
		for s in 3:
			var v:=float(s)/2.0
			var bend:=Vector3.UP*(1.0-pow(v*2.0-1.0,2.0))*.15*curl*_size
			var point:=center+side*(v*2.0-1.0)*width+bend+Vector3(0,0,float(k)*.022*_size)
			vertices.append(point.snapped(Vector3.ONE*.045*_size))
			normals.append(Vector3.BACK)
			uv.append(Vector2(v,u))
	for j in 16:
		for s in 2:
			var n:=j*3+s
			indices.append_array(PackedInt32Array([n,n+3,n+1,n+1,n+3,n+4]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
