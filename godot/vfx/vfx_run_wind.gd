extends "res://vfx/vfx_base.gd"
# 走りの風の線。光らない白い曲線が、体のまわりから後ろへ弧を描いて流れる。
# 線は「先頭から描かれ、先頭から消える」ので、後ろへ払った筆の跡のように見える。
# 走者ひとりにつき1つだけ生かし、蹴り出しや着地の合図が来るたびに延命する。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const FEED_SEC := 0.6
const FPS := 12.0          # 線を足す・描き替える速さ（コマ打ち）
const POINTS := 10

var runner: Node3D
var _size := 1.0
var _tall := 1.6
var _fed_until := 0.0
var _frame := -1
var _prev: Vector3
var _forward := Vector3.FORWARD
var _speed := 0.0
var _kick := false
var _strokes: Array = []    # [帯, 始点, 曲げる点, 終点, 生まれた時刻, 寿命]。点は走者からの位置


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	add_to_group("dash_dust")
	for other in get_tree().get_nodes_in_group("run_wind"):
		if other.runner == runner and not other.is_queued_for_deletion():
			other.feed(direction, size, trail, global_position)
			queue_free()
			return
	if not is_instance_valid(runner):
		queue_free()
		return
	add_to_group("run_wind")
	life = 0.0
	_size = size
	_tall = float(runner.get("vis").get("height")) if runner.get("vis") else 1.6
	_prev = runner.global_position
	_forward = Vector3(direction.x, 0, direction.z).normalized()
	feed(direction, size, trail, global_position)


func feed(_direction: Vector3, _feed_size: float, trail: bool, pos: Vector3) -> void:
	_fed_until = age + FEED_SEC
	if not is_instance_valid(runner):
		return
	if not trail:
		_kick = true
		return
	# 着地：足元から後ろへ、くるっと巻き上がる短い線
	var foot := pos - runner.global_position + Vector3(0, 0.05, 0)
	var side := _forward.cross(Vector3.UP)
	for i in 2:
		var lean := side * randf_range(-0.3, 0.3)
		var end := foot - _forward * randf_range(0.5, 0.9) * _size + lean + Vector3(0, randf_range(0.25, 0.5), 0) * _size
		_add(foot, foot - _forward * randf_range(0.5, 0.8) * _size + lean * 0.3, end, randf_range(0.025, 0.045), randf_range(0.22, 0.3))


func _tick(delta: float) -> void:
	var alive := is_instance_valid(runner)
	if alive:
		var move := runner.global_position - _prev
		_prev = runner.global_position
		move.y = 0.0
		_speed = move.length() / maxf(delta, 0.0001)
		if _speed > 0.5:
			_forward = move.normalized()
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		if alive and age < _fed_until:
			if _kick:
				_kick = false
				for i in 7:
					_flow(randf_range(1.3, 2.4), randf_range(0.04, 0.075))
			elif _speed > 3.0:
				for i in randi_range(2, 3):
					_flow(randf_range(0.7, 1.7), randf_range(0.02, 0.05))
	# 線は走者について行く。描く範囲だけを毎フレーム進める
	var i := 0
	while i < _strokes.size():
		var s: Array = _strokes[i]
		var k: float = (age - s[4]) / s[5]
		if k >= 1.0:
			(s[0] as Node).queue_free()
			_strokes.remove_at(i)
			continue
		var head := ease_out(clampf((k - 0.35) / 0.65, 0.0, 1.0))     # 消えていく側
		var tail := ease_out(clampf(k / 0.55, 0.0, 1.0))              # 伸びていく側
		var points := PackedVector3Array()
		for p in POINTS:
			var t := lerpf(head, tail, float(p) / (POINTS - 1))
			points.append(_prev + (s[1] as Vector3).lerp(s[2], t).lerp((s[2] as Vector3).lerp(s[3], t), t))
		s[0].draw(points if tail - head > 0.02 else PackedVector3Array())
		i += 1
	if _strokes.is_empty() and age >= _fed_until:
		queue_free()


# 体のまわりから後ろへ流れる、ゆるい弧の線を1本足す
func _flow(length: float, width: float) -> void:
	var side := _forward.cross(Vector3.UP)
	var from := Vector3(0, randf_range(0.12, 1.0) * _tall, 0) + side * randf_range(-0.45, 0.45) * _size - _forward * randf_range(0.05, 0.35) * _size
	var to := from - _forward * length * _size + Vector3(0, randf_range(-0.3, 0.3), 0) * _size
	var bend := Vector3(0, randf_range(-0.45, 0.45), 0) * _size + side * randf_range(-0.25, 0.25) * _size
	_add(from, (from + to) * 0.5 + bend, to, width, randf_range(0.2, 0.34))


func _add(from: Vector3, bend: Vector3, to: Vector3, width: float, seconds: float) -> void:
	var r: MeshInstance3D = Ribbon.new()
	r.material_override = Lib.material("stroke", {"width": width * _size})
	add_child(r)
	_strokes.append([r, from, bend, to, age, seconds])
