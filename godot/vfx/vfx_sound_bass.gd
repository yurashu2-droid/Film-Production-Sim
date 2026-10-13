extends "res://vfx/vfx_base.gd"
# 低音の三打。素材は圧縮空気、終わりは供給元から前へ空になり、上肩が抜ける。
# 供給: 床の低い圧力。先行: 曲がった前縁。遅れ: 肩の凹みと薄い後続層。
# 0.55: 左肩の強い短打。1.05: 低く右へ偏る短打。1.65–2.05: 完全な間。
# 2.05: 一番広く重い打撃。中央の凹みが左右へ走り、腹の空気が遅れて追う。
# 各打は形状と寿命が違う。輪の拡縮ではなく、局所波面・凹み・厚みが伝播する。
# 第三打の終わり: 白い圧縮芯は3.0までに前へ抜ける。青い腹は3.8に供給停止。
# 紫の外層だけは遅い上向きの空気へ移り、足→肩へ密度が抜け4.95に空になる。
# 参考: 極光の返しの励起伝播構造を、低音の短い圧縮と長い第三打へ作り分け。
const PRESSURE := preload("res://vfx/shaders/sound_bass_pressure.gdshader")
var _layers: Array[MeshInstance3D] = []

static func spawn(parent: Node, ground: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size)
	preload("res://vfx/vfx_sound_score.gd").attach(fx,"sound_bass")
	return fx

func start(size: float) -> void:
	life=5.6
	var mesh := _grid()
	for hit in 3:
		for slot in 6:
			var k := slot%3
			var packet := slot/3
			var mi := MeshInstance3D.new()
			mi.mesh=mesh
			var mat := ShaderMaterial.new()
			mat.shader=PRESSURE
			mat.set_shader_parameter("layer",float(k))
			mat.set_shader_parameter("hit",float(hit))
			mat.set_shader_parameter("packet",float(packet))
			mat.set_shader_parameter("size",size)
			mat.set_shader_parameter("grain",Lib.noise("soft"))
			mi.material_override=mat
			mi.custom_aabb=AABB(Vector3(-4,-1,-4)*size,Vector3(8,8,8)*size)
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_layers.append(mi)
	_tick(0.0)

static func _grid() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 26:
		for x in 64:
			for d in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((x+d.x)/64.0,(y+d.y)/26.0)
				st.set_uv(uv)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(uv.x,uv.y,0))
	return st.commit()

func _tick(_delta: float) -> void:
	for mi in _layers:
		param(mi,"phase",age)
