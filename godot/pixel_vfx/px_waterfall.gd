extends "res://pixel_vfx/px_base.gd"
# 段瀑。素材は水、上から放出→先頭が落下→床の舌へ同じ放出時刻を引き継ぐ。
# .0–.9: 左・中・右の先頭が時差で落ちる。腹は圧力の後から太る。
# .9–2.7: 不揃いな肩と首が下へ運ばれ、着地から三方向の水舌へ。
# 2.7–3.7: 供給終了、上が先に空になり最後の腹が着地。3.7–4.3: 舌が外へ抜ける。
# 3薄層/5色/12fps/Grid。寿命noise穴0、流路を戻さず、固体cubeで本体を作らない。
const COLORS := [Vector3(.025,.06,.18),Vector3(.055,.25,.60),Vector3(.12,.83,1.40),Vector3(.58,1.70,2.40),Vector3(2.2,3.0,3.4)]
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
	var mesh := _grid(24,64)
	for stream in 3:
		for mode in 2:
			for k in 3:
				var mi := MeshInstance3D.new()
				mi.mesh=mesh
				mi.material_override=material("px_waterfall_flow",COLORS,{"layer":float(k),"stream":float(stream),"mode":float(mode),"size":size})
				mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.custom_aabb=AABB(Vector3(-4,-1,-4)*size,Vector3(8,6,8)*size)
				add_child(mi)
				_surfaces.append(mi)
	_light=lamp(COLORS[3],5*size)
	_light.position=Vector3(0,.6,0)*size
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
	_light.light_energy=1.3*smoothstep(.5,1.2,t)*(1.0-smoothstep(3.8,4.3,t))
