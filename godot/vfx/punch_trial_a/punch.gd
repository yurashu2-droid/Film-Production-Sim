extends "res://vfx/vfx_base.gd"
# 素材：古典カートゥーンの不揃いな殴打記号。comic_impact の暖色と茶の輪郭を起点にする。
# 供給：拳の短い振り抜き。先行：黄の肩と先端。追従：橙の根元、クリームの短い芯。
# 形：0.06前触れの湾曲 → 0.10-0.16放射の肩が時間差で張る → 0.20-0.42先端が横へ逃げる。
# 終わり：0.43橙の根元から切れる、0.47黄の肩が前進し裂ける、0.53芯が遅れて抜ける。
# 0.44以降の外片は速度を落とし、落下しながら斜めの短い筆先へ擦り切れる。
const MARK_PATH := "res://vfx/punch_trial_a/mark.gdshader"
var _mark_shader: Shader
var _layers: Array[MeshInstance3D] = []
var _pieces: Array[MeshInstance3D] = []
var _size := 1.0
var _axis := Vector3.RIGHT
var _up := Vector3.UP
var _cross := Vector3.BACK

static func spawn(parent: Node, pos: Vector3, size: float = 1.0, direction: Vector3 = Vector3.RIGHT) -> Node3D:
	var effect := new()
	parent.add_child(effect)
	effect.global_position = pos
	effect._size = size
	effect._axis = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.RIGHT
	effect._up = Vector3.UP if absf(effect._axis.y) < 0.95 else Vector3.BACK
	effect._cross = effect._axis.cross(effect._up).normalized()
	effect._up = effect._cross.cross(effect._axis).normalized()
	effect.life = 1.05
	effect._build()
	effect._tick(0.0)
	return effect

func _build() -> void:
	# Read dedicated shader source on construction: hot reload of the parent alone keeps cached Shader resources.
	_mark_shader = Shader.new()
	_mark_shader.code = FileAccess.get_file_as_string(MARK_PATH)
	var colors := [Vector3(1.0, 0.39, 0.085), Vector3(1.35, 0.94, 0.25), Vector3(1.45, 1.29, 0.85)]
	for i in 3:
		var node := _mark(colors[i], float(i) * 0.11, false)
		node.scale = Vector3.ONE * _size * [1.40, 1.22, 0.74][i]
		_layers.append(node)
	for i in 4:
		var node := _mark(colors[i % 2], float(i) * 1.8, true)
		node.scale = Vector3.ONE * _size * [0.30, 0.26, 0.22, 0.27][i]
		_pieces.append(node)

func _mark(fill: Vector3, phase: float, fragment: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = Lib.quad()
	var mat := ShaderMaterial.new()
	mat.shader = _mark_shader
	mat.set_shader_parameter("fill_color", fill)
	mat.set_shader_parameter("phase", phase)
	mat.set_shader_parameter("piece", fragment)
	mat.set_shader_parameter("world_axis", _axis)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _tick(_delta: float) -> void:
	for i in _layers.size():
		var t := age - float(i) * 0.014
		var node := _layers[i]
		node.visible = t >= 0.018 and t < 0.75 + float(i) * 0.024
		var push: float = 0.13 + maxf(t - 0.12, 0.0) * [0.34, 0.55, 0.63][i] + maxf(t - 0.43, 0.0) * 0.42
		node.position = (_axis * (push + float(i) * 0.035) + _up * (float(i) * 0.016)) * _size
		param(node, "age", t)
		param(node, "phase", float(i) * 0.045)
		param(node, "layer_index", float(i))
	for i in _pieces.size():
		var elapsed := age - (0.43 + float(i) * 0.026)
		var node := _pieces[i]
		node.visible = elapsed >= 0.0 and elapsed < 0.33 + float(i) * 0.018
		var a: float = [0.72, 2.58, 4.1, 5.45][i]
		var radial := _up * sin(a) + _cross * cos(a)
		var drift := 0.11 * (1.0 - exp(-maxf(elapsed, 0.0) * 6.0))
		node.position = (_axis * (0.31 + 0.46 * elapsed - 0.34 * elapsed * elapsed) + radial * (0.38 + drift) - _up * 1.65 * elapsed * elapsed) * _size
		param(node, "age", elapsed)
		param(node, "phase", a + elapsed * [1.0, -1.2, 0.8, -0.8][i])
