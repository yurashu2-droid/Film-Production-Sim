extends "res://pixel_vfx/px_base.gd"
# 素材：薄い氷面。下左からひびが走る→破断時差→重力落下→着地した縁から融水へ。
# 先行は白いひび、遅れは青い面と落下片。0.4s枝が走る/1.0s左端が剥がれる/1.6s上端が傾く。
# 白いひびは先に途切れ、外面は落下回転、内面は着地後に地表膜へ。融水は下流へ排出。
# 12fps・5色・3薄層。立方体の縮小消去と寿命ノイズ穴消しは使わない。
const COLORS := [Vector3(.035,.06,.20),Vector3(.09,.24,.54),Vector3(.17,.58,.87),Vector3(.66,1.35,1.68),Vector3(2.7,3.0,2.8)]
var _size:=1.0
var _parts:Array=[]
var _light:OmniLight3D

static func spawn(parent:Node,pos:Vector3,size:float=1.0)->Node3D:
	var fx:Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

func start(size:float)->void:
	_size=size
	life=5.0
	for row in 3:
		for col in 4:
			var i:=row*4+col
			var layers:Array=[]
			for k in 3:
				var mi:=quad(material("px_ice_break",COLORS,{"seed":float(i)*1.73,"layer":float(k)}),Vector2(.62,.91)*size)
				layers.append(mi)
			_parts.append({"from":Vector3((float(col)-1.5)*.64,.49+float(row)*.91,float(i%3)*.025)*size,"break":.78+float(col)*.095+float(row)*.19,"layers":layers,"row":row,"index":i})
	_light=lamp(COLORS[3],6.0*size)
	_light.position=Vector3(0,1.0,.25)*size
	_step(0.0)

func _step(t:float)->void:
	_light.light_energy=.7*_size*(1.0-smoothstep(1.8,2.8,t))
	for data:Dictionary in _parts:
		var i:int=data["index"]
		var from:Vector3=data["from"]
		var elapsed:=maxf(0.0,t-float(data["break"]))
		var falltime:=sqrt(maxf(from.y/_size-.08,0.01)/3.8)
		var contact:=elapsed-falltime
		for k in 3:
			var mi:MeshInstance3D=data["layers"][k]
			var dt:=maxf(0.0,elapsed-float(k)*.03)
			var place:=from+Vector3((.22 if i%2==0 else -.18)*dt,.12*dt-3.8*dt*dt,.18*dt)*_size
			place.y=maxf(.085*_size,place.y)
			var melt:=clampf((contact-.75-float(k)*.06)/(.94+float(i%3)*.14),0.0,1.0)
			mi.visible=t>.04 and melt<.99 and not (k==2 and contact>.08)
			mi.position=(place+Vector3(0,0,float(k)*.027*_size)).snapped(Vector3.ONE*.045*_size)
			mi.rotation=Vector3(-minf(dt*1.2,.8),float(i%3-1)*dt*.7,float(i%2*2-1)*dt*.65)
			if contact>0.0:
				# Contact converts each slab into a downstream film, never uniform shrinking.
				mi.rotation=Vector3(-PI/2.0,0,float(i)*.17)
				mi.position.y=(.025+float(k)*.009)*_size
				mi.position.x+=(contact*.30)*_size
				mi.mesh=_film(i,contact,k)
			param(mi,"crack",clampf((t-.08-float(i)*.021)/.48,0.0,1.0))
			param(mi,"melt",melt)
			param(mi,"water",1.0 if contact>0.0 else 0.0)
			param(mi,"phase",t)

func _film(i:int,t:float,k:int)->ArrayMesh:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for j in 7:
		var v:=float(j)/6.0
		var center:=Vector3(.11*sin(v*7.0+float(i)),(v-.5)*(.91+minf(t,.8)*.4),0)
		var w:=(.28+.08*sin(v*5.0+float(i)))*(1.0-float(k)*.16)
		for s in 2:
			vertices.append((center+Vector3((float(s)*2.0-1.0)*w,0,0))*_size)
			normals.append(Vector3.BACK)
			uv.append(Vector2(float(s),v))
	for j in 6:
		var n:=j*2
		indices.append_array(PackedInt32Array([n,n+2,n+1,n+1,n+2,n+3]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
