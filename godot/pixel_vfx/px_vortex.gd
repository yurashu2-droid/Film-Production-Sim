extends "res://pixel_vfx/px_base.gd"
# 巻昇。足元の空気が太い巻込みへ入り、先肩→遅腹の圧力が上へ進む。
# .0–1.2: 根元の片肩が入り、芯より外房が先に上昇。1.2–2.8: 二度目の腹が追う。
# 2.8以降: 根元から供給が終わり、外→中→芯の末尾が上へ抜ける。寿命穴0。
# 開いた3層の曲面で体を構成。形・中心・肩の時刻が放出素材とともに移る。12fps/5色/Grid。
const COLORS := [Vector3(.012,.08,.09),Vector3(.025,.32,.30),Vector3(.05,.85,.62),Vector3(.47,1.65,1.15),Vector3(2.3,2.9,2.5)]
var _surfaces: Array[MeshInstance3D] = []
var _light: OmniLight3D

static func spawn(parent: Node, pos: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

func start(size: float) -> void:
	life=5.0
	var mesh := _grid(64,64)
	for mode in 2:
		for k in 9:
			var mi := MeshInstance3D.new()
			mi.mesh=mesh
			mi.material_override=material("px_vortex_flow",COLORS,{"layer":float(k%3),"stream":float(k/3),"mode":float(mode),"size":size})
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.custom_aabb=AABB(Vector3(-4,-1,-4)*size,Vector3(8,6,8)*size)
			add_child(mi)
			_surfaces.append(mi)
	_light=lamp(COLORS[3],5*size)
	_light.position=Vector3(0,.5,0)*size
	_step(0)
static func _grid(nx: int, ny: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in ny:
		for x in nx:
			for d in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((x+d.x)/float(nx),(y+d.y)/float(ny))
				st.set_uv(uv)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(uv.x,uv.y,0))
	return st.commit()

func _step(t: float) -> void:
	for mi in _surfaces:
		param(mi,"phase",t)
	_light.light_energy=1.2*smoothstep(.2,.7,t)*(1.0-smoothstep(3.8,4.3,t))


