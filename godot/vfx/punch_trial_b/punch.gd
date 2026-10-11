extends "res://vfx/vfx_base.gd"
# 素材：拳から押し出される、暖色の漫画の衝撃記号。comic_impact の塗りと茶の輪郭を参照。
# 先行：0.10sに太い不揃いの肩、0.16s以降は先端が+Xへ押し出される。
# 追従：橙の後層は遅れて伸び、クリームの芯が短く前方へ抜ける。
# 形：0.04sは短い振り抜き、0.10〜0.18sは尖ったヒット、0.20〜0.45sは肩が倒れ尾が追う。
# 終わり：0.40sから根元の供給を切る。橙/黄/芯を時差で前へ抜き、4裂片は減速し落下して短く抜ける。
var _paint_shader: Shader
var _layers: Array[MeshInstance3D] = []
var _chips: Array[MeshInstance3D] = []
var _windup: MeshInstance3D
var _dir := Vector3.RIGHT
var _size := 1.0

static func spawn(parent: Node, pos: Vector3, size: float = 1.0, direction: Vector3 = Vector3.RIGHT) -> Node3D:
	var fx = load("res://vfx/punch_trial_b/punch.gd").new()
	parent.add_child(fx)
	fx.global_position = pos
	fx._size = size
	fx._dir = direction.normalized() if direction.length_squared() > 0.001 else Vector3.RIGHT
	fx._build()
	return fx

func _paint(kind: int, tint: Vector3, phase: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	node.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _paint_shader
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("phase", phase)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _build() -> void:
	life = 1.04
	_paint_shader = ResourceLoader.load("res://vfx/punch_trial_b/paint.gdshader", "Shader", ResourceLoader.CACHE_MODE_IGNORE) as Shader
	_layers.append(_paint(0, Vector3(1.0, 0.43, 0.09), 0.075))
	_layers.append(_paint(0, Vector3(1.0, 0.78, 0.24), 0.0))
	_layers.append(_paint(3, Vector3(1.0, 0.94, 0.71), -0.20))
	_windup = _paint(1, Vector3(1.0, 0.71, 0.24), 0.0)
	for i in 4:
		_chips.append(_paint(2, Vector3(1.0, 0.68 + i * 0.055, 0.22 + i * 0.055), i * 0.43))
	_tick(0.0)

func _tick(_delta: float) -> void:
	var t := age
	_windup.visible = t > 0.0 and t < 0.095
	_windup.position = _dir * lerpf(-0.52, -0.12, clampf(t / 0.09, 0, 1)) * _size
	_windup.scale = Vector3(0.55, 0.26, 1) * _size
	param(_windup, "clock", t)
	param(_windup, "eaten", lerpf(-1.1, 1.1, smoothstep(0.06, 0.095, t)))
	for i in _layers.size():
		var node := _layers[i]
		var born := 0.075 + i * 0.010
		var stop := 0.48 + i * 0.07
		node.visible = t >= born and t < stop
		var spread := smoothstep(born, born + 0.035, t)
		var follow := smoothstep(0.17 + i * 0.024, 0.40 + i * 0.024, t)
		var width := [1.36, 1.22, 0.67][i] as float
		node.scale = Vector3(width * lerpf(0.24, 1.0, spread), width * lerpf(0.30, 1.0, spread), 1.0) * _size
		# 根元カットの最中も流出方向へ進む。切れた芯を同じ位置に置き去りにしない。
		var release_travel := maxf(t - 0.36, 0.0) * (0.52 + i * 0.08)
		node.position = (_dir * (-0.05 + i * 0.038 + 0.40 * follow + release_travel) + Vector3.UP * (-0.045 + i * 0.045 + 0.025 * sin(t * 9 + i))) * _size
		param(node, "clock", t)
		param(node, "eaten", lerpf(-1.1, 1.1, smoothstep(0.34 + i * 0.04, stop, t)))
		param(node, "lean", follow)
	for i in _chips.size():
		var node := _chips[i]
		var born := 0.29 + i * 0.026
		var end := 0.69 + i * 0.056
		var q := maxf(t - born, 0.0)
		var a := [0.70, 2.42, 4.27, 5.47][i] as float
		var radial := Vector3(0, sin(a), cos(a))
		var travel := (1.0 - exp(-q * 5.0)) / 5.0
		node.position = (_dir * (0.24 + 1.12 * travel) + radial * (0.31 + 0.85 * travel) + Vector3.DOWN * (0.62 * q * q)) * _size
		node.scale = Vector3(0.30 - i * 0.015, 0.22, 1.0) * _size
		node.visible = t >= born and t < end
		param(node, "clock", q)
		param(node, "lean", q * 2.0)
		param(node, "eaten", lerpf(-1.1, 1.1, smoothstep(end - 0.15, end, t)))
