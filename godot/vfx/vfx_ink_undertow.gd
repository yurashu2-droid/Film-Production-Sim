extends "res://vfx/vfx_base.gd"
# 墨の寄せ波。三本の太い墨舌を、別時刻・別圧力で地面から送り出す。
# 素材: 墨。出口: 古い先頭が先へ落ち、遅い腹が追って着地し、同じ着地点に染み。
# 供給は左0.05 / 中0.27 / 右0.54秒から。それぞれ1.15–1.55秒で止まる。
# 先行: 早く押された唇。追従: 新しい低い腹。圧力の増加で後の材料が前へ出る。
# 0–0.7: 低い腹→太い左舌。0.7–1.8: 先頭が巻き下がり、中/右の腹が立つ。
# 1.8–3.8: 供給は空、古い腹から時間差で地面へ落ちる。縮小や引き戻しなし。
# 金は2.6までに前へ抜け、白熱は短い先頭だけ。黒は重力で染みへ。5.2に乾燥完了。
# 参考: 実見した墨龍mid/endの黒い広い筆跡、細い金の脈。波面を連結しない。
const SURFACE := preload("res://vfx/shaders/ink_undertow_surface.gdshader")
const SOAK := preload("res://vfx/shaders/ink_undertow_soak.gdshader")
const OFFSETS := [0.05,0.27,0.54]
const ENDS := [1.15,1.40,1.55]
var _size := 1.0
var _tongues: Array = []
var _drops: MultiMeshInstance3D
var _landings: Array = []
var _stains: Array[MeshInstance3D] = []

static func spawn(parent: Node, ground: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size)
	return fx

func start(size: float) -> void:
	_size=size
	life=5.8
	for j in 3:
		var rows: Array = []
		for k in 4:
			var mi := MeshInstance3D.new()
			mi.mesh=ArrayMesh.new()
			var mat := ShaderMaterial.new()
			mat.shader=SURFACE
			mat.set_shader_parameter("layer",float(k))
			mat.set_shader_parameter("seed",float(j)*0.37)
			mat.set_shader_parameter("grain",Lib.noise("soft"))
			mi.material_override=mat
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			rows.append(mi)
		_tongues.append(rows)
	var sphere := SphereMesh.new()
	sphere.radius=0.048
	sphere.height=0.11
	sphere.radial_segments=8
	sphere.rings=4
	var black := StandardMaterial3D.new()
	black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color=Color(.012,.009,.014)
	sphere.material=black
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=sphere
	mm.instance_count=30
	_drops=MultiMeshInstance3D.new()
	_drops.multimesh=mm
	_drops.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in 30:
		var j := i%3
		var f := float(i/3)/9.0
		var emitted := float(OFFSETS[j])+f*(float(ENDS[j])-float(OFFSETS[j]))
		var launch := emitted+0.90+0.12*sin(i*2.0)
		var from := _material(j,emitted,launch)
		var velocity := _velocity(j,emitted,launch)+Vector3(.16*sin(i*3.0),0,.12*cos(i*2.0))
		var duration := (velocity.y+sqrt(velocity.y*velocity.y+8.8*maxf(from.y-.028,0.0)))/4.4
		var landing := from+velocity*duration+Vector3(0,-2.2*duration*duration,0)
		landing.y=.024
		_landings.append([launch,from,velocity,duration])
		var stain := MeshInstance3D.new()
		stain.mesh=Lib.quad()
		stain.rotation.x=-PI/2
		stain.position=landing*size
		stain.scale=Vector3(.66+.14*sin(i*2.0),.48+.12*cos(i*3.0),1)*size
		var mat := ShaderMaterial.new()
		mat.shader=SOAK
		mat.set_shader_parameter("arrival",launch+duration)
		mat.set_shader_parameter("seed",float(i)*.71)
		mat.set_shader_parameter("grain",Lib.noise("soft"))
		stain.material_override=mat
		stain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stain)
		_stains.append(stain)
	_tick(0)

# A material parcel retains its emission time; older parcels fall while new supply rises.
static func _material(j: int, emitted: float, t: float) -> Vector3:
	var tau := maxf(0,t-emitted)
	var local := emitted-float(OFFSETS[j])
	var vy := 4.0+0.85*sin(local*2.7+float(j)*.8)
	var vz := 0.82+0.68*smoothstep(.0,1.10,local)
	var x := (float(j)-1.0)*1.25+sin(local*4.0+j*.9)*.22
	x+=sin(local*3.4+j*1.6)*tau*.24
	var y := .05+vy*tau-2.2*tau*tau
	var z := -.70+vz*tau+.18*sin(local*3.4)*tau
	return Vector3(x,y,z)

static func _velocity(j: int, emitted: float, t: float) -> Vector3:
	return (_material(j,emitted,t+.001)-_material(j,emitted,t))/.001

func _tick(_delta: float) -> void:
	for j in 3:
		var newest := minf(age,float(ENDS[j]))
		var oldest := maxf(float(OFFSETS[j]),age-2.35)
		var pts := PackedVector3Array()
		var profiles := PackedFloat32Array()
		for n in 40:
			var u := float(n)/39.0
			var emitted := lerpf(newest,oldest,u)
			var p := _material(j,emitted,age)
			var width := smoothstep(.03,.24,age-emitted)
			width*=smoothstep(.01,.24,p.y)
			width*=pow(maxf(0,sin(u*PI)),.38)
			width*=.78+.24*sin(u*6.3+age*2.0+j)
			pts.append(p*_size)
			profiles.append(maxf(.015,width))
		for k in 4:
			var mi: MeshInstance3D = _tongues[j][k]
			mi.visible=newest>oldest and age>float(OFFSETS[j])
			if mi.visible:
				var radii := [.58,.43,.24,.10]
				mi.mesh=Lib.path_tube(pts,float(radii[k])*_size,0,10,profiles)
				param(mi,"phase",age)
	for mi in _stains:
		param(mi,"phase",age)
	for i in _landings.size():
		var d: Array = _landings[i]
		var tau := age-float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO)
		if tau>=0 and tau<float(d[3]):
			var p: Vector3 = d[1]+d[2]*tau+Vector3(0,-2.2*tau*tau,0)
			xf=Transform3D(Basis.from_scale(Vector3(.9,1.25,.9)*_size),p*_size)
		_drops.multimesh.set_instance_transform(i,xf)
