extends "res://vfx/vfx_base.gd"
# 手描きの連番で動くトゥーンの煙玉を、振り付けどおりに置く部品。
# 連番そのものが「丸い煙 → 欠ける → 三日月 → 消える」なので、消え方をノイズの穴に頼らない。
# plan は [[遅れ(秒), 向き(横, 上, 奥), 進む距離, 大きさ, 秒数], ...]。
# 素材：LeLu's Noise Pack の smoke_flipbook_n7.png（assets/vfx/lelu_noise/SOURCE.md）

const FPS := 15.0
const FRAMES := 16.0

var _plan: Array = []
var _size := 1.0
var _tint := Color.WHITE
var _frame := -1
var _mm: MultiMesh


static func spawn(parent: Node, pos: Vector3, plan: Array, size: float = 1.0, tint: Color = Color.WHITE) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(plan, size, tint)
	return fx


func start(plan: Array, size: float, tint: Color) -> void:
	_plan = plan
	_size = size
	_tint = tint
	life = 0.1
	for p: Array in plan:
		life = maxf(life, float(p[0]) + float(p[4]) + 0.1)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = Lib.quad()
	_mm.instance_count = plan.size()
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _mm
	holder.material_override = Lib.material("flipbook", {"sheet": Lib.tex("smoke_flipbook_n7.png")})
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -8.0 * size, Vector3.ONE * 16.0 * size)
	add_child(holder)
	_pose(0.0)


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(now: float) -> void:
	for i in _plan.size():
		var p: Array = _plan[i]
		var t: float = now - float(p[0])
		var k: float = t / float(p[4])
		var dia := 0.0001
		var pos := Vector3.ZERO
		var shot := 0.0
		if t >= 0.0 and k < 1.0:
			var travel := ease_out(clampf(t / 0.32, 0.0, 1.0))
			var pop := lerpf(0.5, 1.15, t / 0.07) if t < 0.07 else (lerpf(1.15, 1.0, (t - 0.07) / 0.12) if t < 0.19 else 1.0)
			dia = float(p[3]) * _size * pop
			pos = (p[1] as Vector3).normalized() * float(p[2]) * _size * travel + Vector3.UP * 0.2 * t * _size
			pos.y = maxf(pos.y, dia * 0.42)
			# 最初の4コマは丸い煙のまま少し保ち、そのあと欠けていく
			shot = floor(clampf(k * 1.15 - 0.15, 0.0, 0.999) * FRAMES)
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * dia), pos))
		_mm.set_instance_color(i, _tint)
		_mm.set_instance_custom_data(i, Color(shot, 0, 0, 0))
