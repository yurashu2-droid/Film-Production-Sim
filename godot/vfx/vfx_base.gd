extends Node3D
# 使い捨てエフェクトの土台。時刻で予約して進め、寿命が来たら自分で消える。
# ツリーの一時停止に従うので、停止・コマ送りでも一緒に止まる。
const Lib := preload("res://vfx/vfx_lib.gd")

var age := 0.0
var life := 1.0           # 0 以下なら消えない（出しっぱなしの炎や煙）
var _cues: Array = []     # [時刻, Callable]
var _spans: Array = []    # [開始, 長さ, Callable(0〜1)]


func _init() -> void:
	add_to_group("vfx")


# time 秒たったら一度だけ呼ぶ
func at(time: float, what: Callable) -> void:
	_cues.append([time, what])


# start から length 秒のあいだ、進み具合 0〜1 を渡して毎フレーム呼ぶ
func over(start: float, length: float, what: Callable) -> void:
	_spans.append([start, length, what])


func _process(delta: float) -> void:
	age += delta
	var i := 0
	while i < _cues.size():
		if age >= _cues[i][0]:
			var cue: Callable = _cues[i][1]
			_cues.remove_at(i)
			cue.call()
		else:
			i += 1
	i = 0
	while i < _spans.size():
		var span: Array = _spans[i]
		if age < span[0]:
			i += 1
			continue
		var k := clampf((age - span[0]) / span[1], 0.0, 1.0)
		(span[2] as Callable).call(k)
		if k >= 1.0:
			_spans.remove_at(i)
		else:
			i += 1
	_tick(delta)
	if life > 0.0 and age >= life:
		queue_free()


func _tick(_delta: float) -> void:
	pass


static func ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


# 光る板（0: 丸い光、1: 輪、2: 閃光）
func sprite(shape: int, color: Color, size: float, billboard: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	mi.material_override = Lib.material("glow", {"shape": shape, "color": color, "billboard": billboard})
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func param(node: GeometryInstance3D, key: String, value: Variant) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter(key, value)


# 粒子を足して、delay 秒後に出す
func emit(p: GPUParticles3D, delay: float = 0.0, offset: Vector3 = Vector3.ZERO) -> GPUParticles3D:
	add_child(p)
	p.position = offset
	if delay <= 0.0:
		p.emitting = true
	else:
		at(age + delay, func() -> void: p.emitting = true)
	return p


func lamp(color: Color, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = reach
	light.light_energy = 0.0
	add_child(light)
	return light


# dir に垂直な向きで板を置く（衝撃波の輪など）
static func face(node: Node3D, pos: Vector3, dir: Vector3, size: float) -> void:
	var up := Vector3.RIGHT if absf(dir.normalized().y) > 0.99 else Vector3.UP
	node.global_transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3.ONE * size), pos)
