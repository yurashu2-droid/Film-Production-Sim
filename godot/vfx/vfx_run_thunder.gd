extends "res://vfx/vfx_base.gd"
# 雷の疾走。走者を「飛び道具の頭」と見立て、飛び道具と同じ分け方で組む（vfx_projectile.gd と同じ部品・同じ色の組）。
#   発射＝蹴り出し：閃光、進行方向に垂直な輪、後ろへ吹く火花、地面の放電（短く。主役は走者に渡す）
#   頭＝走者：体を包んで後ろへ流れるオーラ、胸の光、体を這う放電
#   軌跡：腰から伸びる帯（尾へ向かって細り、千切れる）＋ その上を走る稲妻
#   補助：こぼれる光の粒、一定間隔で置いていく輪、着地ごとの足元の放電
#   終わり：止まるとオーラがしぼみ、軌跡が尾から消える
# 参考：『鬼滅の刃』善逸の霹靂一閃、『HUNTER×HUNTER』キルアの神速。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Lightning := preload("res://vfx/vfx_lightning.gd")
const Projectile := preload("res://vfx/vfx_projectile.gd")
const FEED_SEC := 0.6
const TRAIL_SEC := 0.32
const FPS := 15.0          # 稲妻の形を作り直す速さ
const RING_GAP := 0.2

var runner: Node3D
var bare := false          # true でオーラ・胸の光・帯を外す（スミアと重ねる時。vfx_run_volt.gd が使う）
var _pal: Dictionary = Projectile.PALETTES["thunder"]
var _size := 1.0
var _tall := 1.6
var _fed_until := 0.0
var _power := 0.0          # 0〜1。走っている間 1 へ、止まると 0 へ
var _frame := -1
var _prev: Vector3
var _forward := Vector3.FORWARD
var _next_ring := 0.0
var _history: Array = []   # [腰の位置, 時刻]。新しい順
var _head: Node3D
var _aura: MeshInstance3D
var _halo: MeshInstance3D
var _shed: GPUParticles3D
var _light: OmniLight3D
var _trail: MeshInstance3D
var _bolt: MeshInstance3D          # 軌跡の上を走る稲妻の本流
var _shadow: MeshInstance3D        # 本流に重なる、別の形の細い稲妻
var _forks: Array[MeshInstance3D] = []     # 本流から分かれる枝
var _crackles: Array[MeshInstance3D] = []
var _arcs: Array = []      # [帯, 始点, 終点, 消える時刻]


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	add_to_group("dash_dust")
	var pos := global_position
	for other in get_tree().get_nodes_in_group("run_thunder"):
		if other.runner == runner and not other.is_queued_for_deletion():
			other.feed(direction, size, trail, pos)
			queue_free()
			return
	if not is_instance_valid(runner):
		queue_free()
		return
	add_to_group("run_thunder")
	life = 0.0
	top_level = true
	global_transform = Transform3D.IDENTITY     # 子の座標をそのままワールド座標として扱う
	_size = size
	_tall = float(runner.get("vis").get("height")) if runner.get("vis") else 1.6
	_prev = runner.global_position
	_forward = Vector3(direction.x, 0, direction.z).normalized()
	var main: Color = _pal["main"]
	# 頭
	_head = Node3D.new()
	add_child(_head)
	_aura = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 20
	ball.rings = 10
	_aura.mesh = ball
	_aura.material_override = Lib.material("orb", {"noise_texture": Lib.noise("soft"), "color": main, "speed": 4.5, "cut": 0.66})
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_aura)
	_halo = sprite(0, Color(main.r, main.g, main.b, 0.22), 0.1)
	_halo.reparent(_head, false)
	_shed = Lib.particles(Lib.quad(), Lib.material("glow"), Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.35 * size,
		"direction": Vector3.UP,
		"spread": 180.0,
		"initial_velocity_min": 0.3 * size,
		"initial_velocity_max": 1.6 * size,
		"gravity": Vector3.ZERO,
		"scale_min": 0.04 * size,
		"scale_max": 0.11 * size,
		"scale_curve": Lib.curve([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": Lib.ramp([[0.0, _pal["core"]], [0.3, main], [1.0, _pal["tail"]]]),
	}), 22, 0.4, false)
	_head.add_child(_shed)
	_light = lamp(Color(1.0, 0.85, 0.4), 4.5 * size)
	_light.reparent(_head, false)
	for i in 3:
		_crackles.append(_ribbon(0.05, 0.6, 0.0))
	# 軌跡
	_trail = _ribbon(0.4, 0.9, 1.25)
	param(_trail, "core", 0.12)
	_bolt = _ribbon(0.1, 0.6, 0.0)
	param(_bolt, "color_head", _pal["core"])
	_shadow = _ribbon(0.045, 0.5, 0.0)
	for i in 3:
		_forks.append(_ribbon(0.06, 0.9, 0.0))
	if bare:
		_aura.visible = false
		_halo.visible = false
		_trail.visible = false
	feed(direction, size, trail, pos)


func feed(direction: Vector3, _feed_size: float, trail: bool, pos: Vector3) -> void:
	_fed_until = age + FEED_SEC
	var back := -Vector3(direction.x, 0, direction.z).normalized()
	var ground := pos + Vector3(0, 0.06, 0)
	var main: Color = _pal["main"]
	var core: Color = _pal["core"]
	# 足元から散る放電。蹴り出しは全方向へ長く、一歩ごとは後ろへ短く
	for i in (7 if not trail else 3):
		var turn := randf_range(-PI, PI) if not trail else randf_range(-1.2, 1.2)
		var reach := (randf_range(0.9, 2.0) if not trail else randf_range(0.4, 0.9)) * _size
		_arcs.append([_ribbon(0.07, 0.8, 0.0), ground, ground + back.rotated(Vector3.UP, turn) * reach, age + (0.22 if not trail else 0.13)])
	var flash := sprite(2, core, 0.1)
	flash.position = ground + Vector3(0, 0.1, 0) if trail else pos + Vector3(0, 0.55 * _tall, 0)
	var big := (0.8 if trail else 2.6) * _size
	if not trail:
		param(flash, "toward_camera", 0.8 * _size)
	over(age, 0.1, func(k: float) -> void:
		flash.scale = Vector3.ONE * big * lerpf(0.5, 1.0, ease_out(k))
		param(flash, "color", Color(core.r, core.g, core.b, 1.0 - k))
	)
	at(age + 0.11, flash.queue_free)
	if trail:
		return
	# 発射：輪がひとつ弾け、火花が後ろへ吹く
	_ring(pos + Vector3(0, 0.55 * _tall, 0), -back, 0.5, 2.6, 0.2)
	emit(Lib.particles(Lib.streak_mesh(), Lib.material("spark"), Lib.process({
		"direction": back + Vector3(0, 0.35, 0),
		"spread": 40.0,
		"initial_velocity_min": 4.0 * _size,
		"initial_velocity_max": 10.0 * _size,
		"damping_min": 8.0,
		"damping_max": 14.0,
		"gravity": Vector3(0, -6, 0),
		"particle_flag_align_y": true,
		"scale_min": 0.14 * _size,
		"scale_max": 0.34 * _size,
		"scale_curve": Lib.curve([[0.0, 1.0], [1.0, 0.0]]),
		"lifetime_randomness": 0.4,
		"color_ramp": Lib.ramp([[0.0, core], [0.5, main], [1.0, _pal["tail"]]]),
	}), 18, 0.32), 0.0, pos + Vector3(0, 0.4 * _tall, 0))


func _tick(delta: float) -> void:
	var alive := is_instance_valid(runner)
	var feeding := alive and age < _fed_until
	var speed := 0.0
	if alive:
		var move := runner.global_position - _prev
		_prev = runner.global_position
		move.y = 0.0
		speed = move.length() / maxf(delta, 0.0001)
		if speed > 0.5:
			_forward = move.normalized()
	_power = move_toward(_power, 1.0 if feeding and speed > 2.5 else 0.0, delta * (5.0 if feeding else 3.5))
	var chest := _prev + Vector3(0, 0.55 * _tall, 0)
	# 頭：走者に重ね、進む向きへ向ける
	_head.global_transform = Transform3D(Basis.looking_at(_forward, Vector3.UP), chest)
	_head.visible = _power > 0.02
	_aura.scale = Vector3(0.7, 0.85 * _tall, 2.0) * _size * maxf(_power, 0.01)
	_aura.position.z = 0.62 * _size
	_halo.scale = Vector3.ONE * 1.2 * _size * maxf(_power, 0.01) * (0.92 + 0.08 * sin(age * 70.0))
	_shed.emitting = _power > 0.5
	_light.light_energy = 2.5 * _size * _power
	if feeding:
		var hip := _prev + Vector3(0, 0.5 * _tall, 0)
		if _history.is_empty() or (_history[0][0] as Vector3).distance_squared_to(hip) > 0.0004:
			_history.push_front([hip, age])
		if _power > 0.7 and age >= _next_ring:
			_next_ring = age + RING_GAP
			_ring(chest, _forward, 0.4, 1.5, 0.22)
	while not _history.is_empty() and age - _history[-1][1] > TRAIL_SEC:
		_history.pop_back()
	# 軌跡の帯は毎フレームなめらかに。稲妻だけコマ打ちで作り直す
	var path := PackedVector3Array()
	for h: Array in _history:
		path.append(h[0])
	_trail.draw(path)
	var frame := int(age * FPS)
	if frame == _frame:
		return
	_frame = frame
	# 本流：折れ点の間隔も振れ幅も不揃いにし、折れ点の間をさらに細かく折る（大きな折れ＋小さな震え）
	var zigzag := PackedVector3Array()
	var n := path.size()
	if n >= 2:
		var stops: Array[float] = [0.0]
		while stops[-1] < 1.0:
			stops.append(minf(stops[-1] + randf_range(0.1, 0.34), 1.0))
		var knots := PackedVector3Array()
		for k in stops.size():
			var t := stops[k]
			var swing := (1.0 if (k + _frame) % 2 == 0 else -1.0) * randf_range(0.25, 1.0)
			var shake := Vector3(randf_range(-0.35, 0.35), swing, randf_range(-0.35, 0.35)) * (0.07 + 0.26 * t) * _size if k > 0 else Vector3.ZERO
			knots.append(path[mini(roundi(t * (n - 1)), n - 1)] + shake)
		for k in knots.size() - 1:
			var piece: PackedVector3Array = Lightning._bolt(knots[k], knots[k + 1], 0.16, 2)
			if k > 0:
				piece.remove_at(0)
			zigzag.append_array(piece)
	_bolt.draw(zigzag)
	# 数コマに一度、太く明るく光り直す。それ以外は明るさをばらつかせる
	var surge := randf() < 0.22
	param(_bolt, "width", (0.2 if surge else randf_range(0.07, 0.12)) * _size)
	param(_bolt, "fade", 1.0 if surge else randf_range(0.5, 0.95))
	# 影の一本：別の形の細い稲妻を重ね、出たり消えたりさせる
	var shadow := PackedVector3Array()
	if n >= 2 and randf() < 0.65:
		shadow = Lightning._bolt(path[0], path[n - 1] + Vector3(randf_range(-0.2, 0.2), randf_range(-0.45, 0.45), randf_range(-0.2, 0.2)) * _size, 0.2, 4)
	_shadow.draw(shadow)
	# 枝：本流の途中から、後ろ斜めへ短く分かれる
	for fork in _forks:
		var twig := PackedVector3Array()
		if zigzag.size() >= 4 and _power > 0.3 and randf() < (0.9 if surge else 0.55):
			var from := zigzag[randi_range(1, zigzag.size() - 2)]
			var out := (-_forward * randf_range(0.3, 0.8) + Vector3(randf_range(-0.4, 0.4), randf_range(-0.7, 0.7), randf_range(-0.4, 0.4))) * randf_range(0.5, 1.1) * _size
			twig = Lightning._bolt(from, from + out, 0.24, 3)
		fork.draw(twig)
	# 体を這う放電：体のあたりの2点を結ぶ短い稲妻を、出したり消したりする
	for crackle in _crackles:
		var spark := PackedVector3Array()
		if _power > 0.5 and randf() < 0.6:
			var a := chest + Vector3(randf_range(-0.3, 0.3), randf_range(-0.45, 0.4) * _tall, randf_range(-0.3, 0.3)) * _size
			var b := a + Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * _size
			spark = Lightning._bolt(a, b, 0.25, 3)
		crackle.draw(spark)
	var at_arc := 0
	while at_arc < _arcs.size():
		var arc: Array = _arcs[at_arc]
		if age >= arc[3]:
			(arc[0] as Node).queue_free()
			_arcs.remove_at(at_arc)
			continue
		var points: PackedVector3Array = Lightning._bolt(arc[1], arc[2], 0.22, 3)
		for j in points.size():
			points[j].y = maxf(points[j].y, (arc[1] as Vector3).y - 0.02)
		arc[0].draw(points)
		at_arc += 1
	if not feeding and _power <= 0.0 and _history.is_empty() and _arcs.is_empty():
		queue_free()


# 進行方向に垂直な輪を置いて、広げながら消す（飛び道具と同じ）
func _ring(pos: Vector3, dir: Vector3, from_size: float, to_size: float, sec: float) -> void:
	var main: Color = _pal["main"]
	var ring := sprite(1, main, 0.1, false)
	param(ring, "ring_width", 0.14)
	face(ring, pos, dir, _size * from_size)
	over(age, sec, func(k: float) -> void:
		face(ring, pos, dir, _size * lerpf(from_size, to_size, ease_out(k)))
		param(ring, "color", Color(main.r, main.g, main.b, 1.0 - k))
	)
	at(age + sec + 0.01, ring.queue_free)


func _ribbon(width: float, taper: float, erosion: float) -> MeshInstance3D:
	var r: MeshInstance3D = Ribbon.new()
	r.material_override = Lib.material("ribbon", {
		"noise_texture": Lib.noise("soft"),
		"width": width * _size,
		"color_head": _pal["main"],
		"color_tail": _pal["tail"],
		"core_color": Vector3(_pal["core"].r, _pal["core"].g, _pal["core"].b),
		"core": 0.3,
		"taper": taper,
		"erosion": erosion,
	})
	add_child(r)
	return r
