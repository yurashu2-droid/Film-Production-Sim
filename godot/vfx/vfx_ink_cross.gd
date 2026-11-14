extends "res://vfx/vfx_base.gd"
# 墨の交差流。参考：水墨の払い／対向する噴流の巻き返し。再現作品ではない。
# 素材・供給：左右の床から短く噴出する墨。先行する厚い肩を細い首と尾が追う。
# .4〜1.1: 左が先に斜めへ／1.1〜1.9: 遅れた右が交差で左を奥へ押す／
# 2.0〜3.5: 供給停止が根元から伝わり、各放出時刻の墨が重力で別々に落ちる。
# 外の墨→落下、灰色の内流→少し遅い落下、短い金白の圧力→交差から上へ抜ける。
# 滴は解析的な着地点に染みを作り、染みは床の斜め毛細管へ順に吸収される。
# 三層は永久の縦方向空隙。寿命ノイズ穴消し0層。全形の拡縮／並進ではない。
const HISTORY := 1.05
var _size := 1.0
var _frame := -1
var _jets: Array = []
var _drops: Array = []
var _stains: Array = []
var _impulse: Array = []

static func spawn(parent: Node, ground: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	return fx

func start(size: float) -> void:
	_size = size
	life = 5.4
	for jet in 2:
		var layers: Array = []
		for k in 3:
			var m := MeshInstance3D.new()
			m.material_override = Lib.material("ink_cross_flow", {"color": [Vector3(.018,.016,.021),Vector3(.065,.061,.055),Vector3(.20,.19,.17)][k], "sheen": [Vector3(.07,.065,.055),Vector3(.18,.17,.15),Vector3(.63,.61,.55)][k],"density": [.35,.32,.60][k],"seed":jet*1.3+k*.38})
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			param(m,"grain_texture",Lib.noise("soft"))
			add_child(m)
			layers.append(m)
		_jets.append(layers)
	# Detached liquid parcels have exact analytic contacts, each with its own stain.
	for i in 10:
		var jet := i % 2
		var launch := 2.12 + float(i)*.037
		var p := _head(1.42+float(i%7)*.08,jet)
		var v := Vector3((1.0 if jet==0 else -1.0)*(.21+.05*(i%3)), .12+.07*(i%4), sin(float(i)*2.1)*.35)*_size
		var hit := (v.y+sqrt(v.y*v.y+2.0*7.2*_size*p.y))/(7.2*_size)
		var landing := p+v*hit+Vector3.DOWN*3.6*_size*hit*hit
		landing.y=.018*_size
		var mesh := SphereMesh.new()
		mesh.radius=.055
		mesh.height=.13
		mesh.radial_segments=8
		mesh.rings=4
		var drop := MeshInstance3D.new()
		drop.mesh=mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color=Color(.022,.020,.023)
		mat.roughness=.38
		drop.material_override=mat
		add_child(drop)
		_drops.append([drop,launch,p,v,hit])
		var stain := _stain(landing, .62+float(i%3)*.12, float(i)*.83)
		_stains.append([stain,launch+hit, float(i)*.021])
	for jet in 2:
		var root := Vector3(-1.95 if jet==0 else 1.95,.014,.26 if jet==0 else -.24)*_size
		_stains.append([_stain(root,1.25,jet*2.1),.12+jet*.28,jet*.08])
	for k in 3:
		var m := MeshInstance3D.new()
		m.material_override=Lib.material("ink_cross_flow",{"color":[Vector3(.22,.13,.04),Vector3(.83,.51,.16),Vector3(1.9,1.7,1.3)][k],"sheen":[Vector3(.5,.3,.08),Vector3(1.7,1.1,.35),Vector3(2.7,2.5,2.1)][k],"density":.57,"seed":k*.42})
		param(m,"grain_texture",Lib.noise("soft"))
		add_child(m)
		_impulse.append(m)
	_pose(0.0)

func _stain(p: Vector3, width: float, seed: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh=Lib.quad()
	m.material_override=Lib.material("ink_cross_stain",{"seed":seed,"spread":0.0})
	m.position=p
	m.rotation=Vector3(-PI/2.0,seed*.7,0.0)
	m.scale=Vector3(width*_size, width*.68*_size,1.0)
	m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

# The second head is late and off-axis; the first stream is curled by its collision.
func _head(t: float, jet: int) -> Vector3:
	var q := maxf(t,0.0)
	var sg := 1.0 if jet==0 else -1.0
	var x := -sg*1.95 + sg*3.0*smoothstep(0.0,1.35,q)
	var y := 2.58*sin(minf(q/2.75,1.0)*PI*.87)
	var z := (.23 if jet==0 else -.27)+.2*sin(q*3.0+jet)
	var curl := smoothstep(1.25,2.25,q)
	x += -sg*.88*curl*sin((q-1.25)*2.0)
	y += (.44 if jet==0 else -.10)*curl
	z += (1.05 if jet==0 else -.45)*curl
	return Vector3(x,maxf(y,.025),z)*_size

func _tick(_delta: float) -> void:
	_pose(age)

func _pose(t: float) -> void:
	var frame := int(t*30.0)
	if frame != _frame:
		_frame=frame
		for jet in 2:
			var local := t-.18-jet*.34
			for k in 3:
				var m: MeshInstance3D = _jets[jet][k]
				var tail := maxf(0.0,local-HISTORY)
				var front := minf(local,2.10+k*.045)
				m.visible=front>tail+.015 and local<3.45+k*.08
				if not m.visible: continue
				var pts := PackedVector3Array()
				var widths := PackedFloat32Array()
				for i in 36:
					var u := float(i)/35.0
					var parcel := lerpf(tail,front,u)
					var p := _head(parcel,jet)
					# Later material is displaced more by the other jet; then falls.
					var fall := maxf(0.0,local-2.12-k*.045)+maxf(0.0,parcel-1.3)*.05
					p.y=maxf(.018*_size,p.y-3.5*_size*fall*fall)
					p.z+=sin(parcel*8.0+k*.7)*.035*_size + (1.0 if jet==0 else -1.0)*fall*.24*_size
					p.x+=sin(parcel*5.2+k*1.6)*.07*_size*smoothstep(.0,.3,u)
					pts.append(p)
					var shoulder := .19 + .85*exp(-pow((u-.78)/.18,2.0))
					var ends := sin(PI*u)
					widths.append(maxf(.012, shoulder*pow(maxf(ends,0.0),.35)*(1.0-smoothstep(.6,.98,fall))))
				m.mesh=Lib.path_tube(pts,[.61,.35,.12][k]*_size,0.0,9,widths)
				param(m,"phase",local)
				param(m,"impulse",(1.0-smoothstep(1.63,1.94,t))*smoothstep(1.25,1.48,t))
		for k in 3:
			var m: MeshInstance3D=_impulse[k]
			var q:=t-1.35-k*.035
			m.visible=q>0.0 and q<.6
			if m.visible:
				var pts:=PackedVector3Array()
				var widths:=PackedFloat32Array()
				for i in 15:
					var u:=float(i)/14.0
					var a:=q-.18+u*.18
					pts.append(Vector3(.03+a*1.0,2.30+a*2.3,.23+a*.5)*_size)
					widths.append(pow(maxf(0.0,sin(u*PI)),.5))
				m.mesh=Lib.path_tube(pts,[.14,.08,.03][k]*_size,0.0,8,widths)
				param(m,"phase",t)
	for data: Array in _drops:
		var drop: MeshInstance3D=data[0]
		var q:=t-float(data[1])
		drop.visible=q>=0.0 and q<float(data[4])
		if drop.visible:
			drop.position=data[2]+data[3]*q+Vector3.DOWN*3.6*_size*q*q
			drop.scale=Vector3(.8,1.0+q*.55,.8)*_size
	for data: Array in _stains:
		var stain: MeshInstance3D=data[0]
		var q:=t-float(data[1])
		stain.visible=q>0.0 and t<4.94+float(data[2])*.3
		param(stain,"spread",smoothstep(0.0,.22,q))
		param(stain,"wick",smoothstep(3.75+float(data[2]),4.84+float(data[2])*.3,t)*1.6)
