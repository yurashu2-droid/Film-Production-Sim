extends "res://vfx/vfx_base.gd"
# 元の飛散墨を、その座標・速度・黒/金/短白のまま発散させる受け渡し部品。
# 追加の煙柱を作らず、四つの流路×三anchorの材料だけを有限時間運ぶ。
# 0–.045: 元流路との受け渡し。初期形状はconfigure_sourcesの位置に一致。
# .045–.38: 継承速度を減速しながら前へ。先の肩と遅い首が横に分かれる。
# .20–.70: 元の墨の縁と後端だけが横へほぐれ、各流路が時間差で供給を使い切る。
# 外黒は.7まで、金は.31まで、白は.12まで。墨の短い飛散を主役にする。
# 灰色への塗り替え・浮力柱・寿命穴消し無し。
const SMOKE := preload("res://vfx/shaders/ink_after_smoke.gdshader")
var _sheets: Array[MeshInstance3D] = []
var _size := 1.0

static func spawn(parent: Node, origin: Vector3, drift: Vector3, size: float=1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position=origin
	fx.start(drift,size)
	return fx

func start(drift: Vector3, size: float) -> void:
	_size=size
	life=2.2
	for k in 3:
		var mi := MeshInstance3D.new()
		var mat := ShaderMaterial.new()
		mat.shader=SMOKE
		mat.set_shader_parameter("layer",float(k))
		mat.set_shader_parameter("size",size)
		mat.set_shader_parameter("grain",Lib.noise("soft"))
		mi.material_override=mat
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_sheets.append(mi)
	# A standalone default; the parent replaces it with the real material immediately.
	var points: Array[PackedVector3Array] = []
	var velocities: Array[PackedVector3Array] = []
	for k in 3:
		var ps := PackedVector3Array()
		var vs := PackedVector3Array()
		for j in 4:
			for a in 3:
				ps.append(Vector3(float(a)*.45,float(j)*.29-.34,(j%2*2-1)*.14))
				vs.append(Vector3(1.8+j*.4,-.55+sin(j*.7)*.8,cos(j)*.65)+drift)
		points.append(ps)
		velocities.append(vs)
	configure_sources(points,velocities,[Vector3(.018,.014,.02),Vector3(.72,.32,.04),Vector3(2.5,2.1,1.4)],[Vector3(.16,.12,.09),Vector3(2.1,1.1,.20),Vector3(4.2,3.8,2.8)])
	_tick(0)

# Every point/velocity is already local to origin and divided by helper size.
# Order is flow0 anchors0,.5,1, then flow1..3; no synthetic second source is added.
func configure_sources(points: Array[PackedVector3Array], velocities: Array[PackedVector3Array], shades: Array, hots: Array) -> void:
	assert(points.size()==3 and velocities.size()==3 and shades.size()==3 and hots.size()==3)
	for k in 3:
		assert(points[k].size()==12 and velocities[k].size()==12)
		var low: Vector3 = points[k][0]
		var high: Vector3 = low
		for i in 12:
			var p: Vector3 = points[k][i]
			var to: Vector3 = p+velocities[k][i]*.25
			low=low.min(p).min(to)
			high=high.max(p).max(to)
		var bounds := AABB(low-Vector3.ONE*1.30,high-low+Vector3.ONE*2.60)
		var mi := _sheets[k]
		var box := BoxMesh.new()
		box.size=bounds.size*_size
		mi.mesh=box
		mi.position=bounds.get_center()*_size
		mi.custom_aabb=AABB(-box.size*.5,box.size)
		param(mi,"bounds_center",bounds.get_center())
		param(mi,"ray_step",bounds.size.length()/48.0)
		param(mi,"sources",points[k])
		param(mi,"velocities",velocities[k])
		param(mi,"shade",shades[k])
		param(mi,"hot",hots[k])

func _tick(_delta: float) -> void:
	for k in 3:
		var mi := _sheets[k]
		mi.visible=age>0.001 and age<float([.73,.33,.14][k])
		param(mi,"phase",age)
