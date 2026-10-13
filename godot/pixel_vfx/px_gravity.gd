extends "res://pixel_vfx/px_base.gd"
# 引力返し。周囲の異時刻の流入が中心へ落ち込み、短い圧縮を経て接線方向へ放出。
# .0–1.0: 5方向の供給が順に落ちる。1.0–1.6: 肩が合流し圧縮、腹が遅れて到着。
# 1.2–3.2: 二波の流入と先行素材の返しが交差。3.2–4.4: 最後の素材が外へ去る。
# 常設ringなし、3薄層/5色/Grid/12fps、寿命noise穴0。有限cohortの移送が輪郭を作る。
const COLORS := [Vector3(.055,.014,.105),Vector3(.25,.035,.43),Vector3(.85,.11,1.15),Vector3(1.7,.65,1.8),Vector3(3.0,2.5,2.75)]
var _surfaces: Array[MeshInstance3D] = []
var _light: OmniLight3D

static func spawn(parent: Node, pos: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D=new()
	parent.add_child(fx)
	fx.global_position=pos
	fx.start(size)
	return fx

func start(size: float) -> void:
	size*=1.6  # 人（1.7m）に対して主役が小さすぎたので、既定の大きさを上げた（size=1.0 で人と同じくらいの見せ場になる）
	life=5.2
	var mesh := _grid(20,80)
	for stream in 5:
		for k in 3:
			var mi := MeshInstance3D.new()
			mi.mesh=mesh
			mi.material_override=material("px_gravity_flow",COLORS,{"layer":float(k),"stream":float(stream),"size":size})
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.custom_aabb=AABB(Vector3(-4,-1,-4)*size,Vector3(8,6,8)*size)
			add_child(mi)
			_surfaces.append(mi)
	_light=lamp(COLORS[3],5*size)
	_light.position=Vector3(0,.45,0)*size
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
	var hit := exp(-pow((t-1.34)/.23,2.0))+exp(-pow((t-2.43)/.21,2.0))+exp(-pow((t-3.02)/.18,2.0))
	_light.light_energy=1.8*hit
