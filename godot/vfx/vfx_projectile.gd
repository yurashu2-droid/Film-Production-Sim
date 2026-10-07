extends "res://vfx/vfx_base.gd"
# 飛び道具。解説動画「VFX Anatomy: Projectile」の分け方で組む。
#   溜め（予兆）→ 発射の閃き（短く）→ 頭・軌跡・補助 → 着弾（進行方向へ強く、外へも散る）
# 動きは 速さ（travel 秒）・経路（arc で曲げる）・緩急（ease）の3つで決める。
#
# opts:
#   palette  "fire" / "arcane" / "venom" / "thunder"      色の組
#   size     1.0     頭の大きさ
#   travel   0.6     届くまでの秒数（短いほど速い）
#   buildup  0.45    溜めの秒数。弱い弾は 0 でよい
#   ease     "linear" / "in"（溜めてから加速）/ "out"（飛び出して減速）
#   arc      Vector3 経路の中間点をずらす量。ゼロなら直線
#   hit      true    false なら届いた先で何にも当たらず消える

const Ribbon := preload("res://vfx/vfx_ribbon.gd")

const PALETTES := {
	"fire": {"core": Color(10, 8.5, 5), "main": Color(7, 2.0, 0.25), "tail": Color(2.5, 0.25, 0.02), "smoke": Color(0.26, 0.2, 0.17)},
	"arcane": {"core": Color(7, 9.5, 10), "main": Color(0.7, 2.8, 8), "tail": Color(1.6, 0.25, 3.5), "smoke": Color(0.2, 0.22, 0.36)},
	"venom": {"core": Color(8, 10, 4.5), "main": Color(1.2, 6, 0.5), "tail": Color(0.1, 1.5, 0.6), "smoke": Color(0.18, 0.28, 0.16)},
	"thunder": {"core": Color(10, 9.5, 6), "main": Color(7, 4.6, 0.5), "tail": Color(4, 1.0, 0.05), "smoke": Color(0.26, 0.24, 0.16)},
}
const TRAIL_SEC := 0.26

signal impacted(pos: Vector3, direction: Vector3)

var _pal: Dictionary
var _size := 1.0
var _from: Vector3
var _to: Vector3
var _ctrl: Vector3
var _travel := 0.6
var _ease := "linear"
var _hit := true
var _launch_at := 0.0
var _flying := false
var _head: Node3D
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _shed: GPUParticles3D
var _trail: MeshInstance3D
var _history: Array = []     # [位置, 時刻]。新しい順
var _light: OmniLight3D
var _next_ring := 0.0


static func fire(parent: Node, from: Vector3, to: Vector3, opts: Dictionary = {}) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true      # 子の座標をそのままワールド座標として扱う
	parent.add_child(fx)
	fx.start(from, to, opts)
	return fx


func start(from: Vector3, to: Vector3, opts: Dictionary) -> void:
	_pal = PALETTES[opts.get("palette", "fire")]
	_size = opts.get("size", 1.0)
	_travel = opts.get("travel", 0.6)
	_ease = opts.get("ease", "linear")
	_hit = opts.get("hit", true)
	_from = from
	_to = to
	_ctrl = (from + to) * 0.5 + (opts.get("arc", Vector3.ZERO) as Vector3)
	_launch_at = opts.get("buildup", 0.45)
	life = _launch_at + _travel + 1.3
	_light = lamp(Color(_pal["main"].r, _pal["main"].g, _pal["main"].b) / maxf(_pal["main"].r, maxf(_pal["main"].g, _pal["main"].b)), 5.0 * _size)
	_light.position = from
	if _launch_at > 0.0:
		_build_up()
	at(_launch_at, _launch)


# 溜め：光の粒が集まり、輪が縮み、芯が育つ。これから撃つと知らせる。
func _build_up() -> void:
	var sec := _launch_at
	var main: Color = _pal["main"]
	var charge := sprite(0, _pal["core"], 0.1)
	charge.position = _from
	var ring := sprite(1, main, 0.1)
	ring.position = _from
	param(ring, "ring_width", 0.12)
	over(0.0, sec, func(k: float) -> void:
		charge.scale = Vector3.ONE * _size * lerpf(0.15, 1.1, k * k) * (0.9 + 0.1 * sin(age * 70.0))
		ring.scale = Vector3.ONE * _size * lerpf(3.2, 0.5, k)
		param(ring, "color", Color(main.r, main.g, main.b, k))
		_light.light_energy = 4.0 * _size * k * k
	)
	at(sec, func() -> void:
		charge.queue_free()
		ring.queue_free()
	)
	var gather := emit(Lib.particles(Lib.quad(), Lib.material("glow"), Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE,
		"emission_sphere_radius": 1.1 * _size,
		"direction": Vector3.UP,
		"spread": 180.0,
		"initial_velocity_min": 0.0,
		"initial_velocity_max": 0.0,
		"gravity": Vector3.ZERO,
		"radial_velocity_min": -3.4 * _size,
		"radial_velocity_max": -3.0 * _size,
		"scale_min": 0.06 * _size,
		"scale_max": 0.12 * _size,
		"scale_curve": Lib.curve([[0.0, 0.0], [0.3, 1.0], [1.0, 0.4]]),
		"color": main,
	}), 14, 0.32, false), 0.0, _from)
	at(maxf(sec - 0.3, 0.0), func() -> void: gather.emitting = false)


# 発射：一瞬だけ光って、主役をすぐ弾に渡す
func _launch() -> void:
	var dir := _tangent(0.0)
	var main: Color = _pal["main"]
	var flash := sprite(2, _pal["core"], _size)
	flash.position = _from
	over(age, 0.09, func(k: float) -> void:
		flash.scale = Vector3.ONE * _size * lerpf(1.0, 2.6, k)
		param(flash, "color", Color(_pal["core"].r, _pal["core"].g, _pal["core"].b, 1.0 - k))
	)
	at(age + 0.1, flash.queue_free)
	_ring(_from, dir, 0.4, 2.0, 0.16)
	# 前へ吹く火花と、後ろへ少しだけ散る粒
	emit(Lib.particles(Lib.streak_mesh(), Lib.material("spark"), Lib.process({
		"direction": dir,
		"spread": 22.0,
		"initial_velocity_min": 6.0 * _size,
		"initial_velocity_max": 14.0 * _size,
		"damping_min": 20.0 * _size,
		"damping_max": 30.0 * _size,
		"gravity": Vector3.ZERO,
		"particle_flag_align_y": true,
		"scale_min": 0.2 * _size,
		"scale_max": 0.45 * _size,
		"scale_curve": Lib.curve([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": Lib.ramp([[0.0, _pal["core"]], [1.0, main]]),
	}), 14, 0.22), 0.0, _from)
	emit(Lib.particles(Lib.quad(), Lib.material("glow"), Lib.process({
		"direction": -dir,
		"spread": 45.0,
		"initial_velocity_min": 2.0 * _size,
		"initial_velocity_max": 5.0 * _size,
		"gravity": Vector3.ZERO,
		"scale_min": 0.06 * _size,
		"scale_max": 0.12 * _size,
		"scale_curve": Lib.curve([[0.0, 1.0], [1.0, 0.0]]),
		"color": main,
	}), 8, 0.18), 0.0, _from)

	# 頭：白い芯 ＋ 光のにじみ ＋ 後ろへ流れるオーラ
	_head = Node3D.new()
	add_child(_head)
	_head.position = _from
	_core = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 8
	_core.mesh = ball
	_core.material_override = Lib.material("spark", {"tint": Vector3(_pal["core"].r, _pal["core"].g, _pal["core"].b)})
	_core.scale = Vector3.ONE * 0.3 * _size
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_core)
	_halo = sprite(0, Color(main.r, main.g, main.b, 0.9), 1.3 * _size)
	_halo.reparent(_head, false)
	var aura := MeshInstance3D.new()
	aura.mesh = ball
	aura.material_override = Lib.material("orb", {"noise_texture": Lib.noise("soft"), "color": main})
	aura.scale = Vector3(0.62, 0.62, 1.5) * _size
	aura.position.z = 0.36 * _size
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(aura)
	# 補助：頭からこぼれる粒。軌跡をもう一本足す役も兼ねる
	_shed = Lib.particles(Lib.quad(), Lib.material("glow"), Lib.process({
		"direction": Vector3.UP,
		"spread": 180.0,
		"initial_velocity_min": 0.3 * _size,
		"initial_velocity_max": 1.4 * _size,
		"gravity": Vector3.ZERO,
		"scale_min": 0.05 * _size,
		"scale_max": 0.12 * _size,
		"scale_curve": Lib.curve([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": Lib.ramp([[0.0, main], [1.0, _pal["tail"]]]),
	}), 18, 0.4, false)
	_head.add_child(_shed)
	_shed.emitting = true
	# 軌跡：通った所に帯を残し、尾へ向かって細らせて千切る
	_trail = Ribbon.new()
	_trail.material_override = Lib.material("ribbon", {
		"noise_texture": Lib.noise("soft"),
		"width": 0.55 * _size,
		"color_head": main,
		"color_tail": _pal["tail"],
		"core_color": Vector3(_pal["core"].r, _pal["core"].g, _pal["core"].b),
	})
	add_child(_trail)
	_launch_at = age
	_next_ring = age + 0.06
	_flying = true


func _tick(_delta: float) -> void:
	if _flying:
		var k := clampf((age - _launch_at) / _travel, 0.0, 1.0)
		var e := k
		if _ease == "in":
			e = pow(k, 2.4)
		elif _ease == "out":
			e = 1.0 - pow(1.0 - k, 2.4)
		var pos := _point(e)
		var dir := _tangent(e)
		_head.global_transform = Transform3D(Basis.looking_at(dir, Vector3.RIGHT if absf(dir.y) > 0.99 else Vector3.UP), pos)
		_core.scale = Vector3.ONE * _size * (0.3 + 0.04 * sin(age * 90.0))
		_light.position = pos
		_light.light_energy = 4.0 * _size
		if _history.is_empty() or (_history[0][0] as Vector3).distance_squared_to(pos) > 0.0004:
			_history.push_front([pos, age])
		if age >= _next_ring and k < 0.95:
			_next_ring = age + 0.11
			_ring(pos, dir, 0.3, 1.5, 0.22)
		if k >= 1.0:
			_land(pos, dir)
	if _trail:
		while not _history.is_empty() and age - _history[-1][1] > TRAIL_SEC:
			_history.pop_back()
		var points := PackedVector3Array()
		for h: Array in _history:
			points.append(h[0])
		_trail.draw(points)


# 着弾。当たらなかった時も、役目を終えたと分かる小さな消え方をさせる。
func _land(pos: Vector3, dir: Vector3) -> void:
	_flying = false
	_shed.emitting = false
	var main: Color = _pal["main"]
	var core: Color = _pal["core"]
	if not _hit:
		over(age, 0.18, func(k: float) -> void:
			_head.scale = Vector3.ONE * maxf(1.0 - k, 0.01)
			_head.visible = k < 1.0
			_light.light_energy = 4.0 * _size * (1.0 - k)
		)
		return
	_head.visible = false
	impacted.emit(pos, dir)
	var flash := sprite(2, core, _size)
	param(flash, "toward_camera", _size * 1.3)
	flash.position = pos
	over(age, 0.12, func(k: float) -> void:
		flash.scale = Vector3.ONE * _size * lerpf(1.0, 2.6, ease_out(k))
		param(flash, "color", Color(core.r, core.g, core.b, 1.0 - k * k))
	)
	at(age + 0.13, flash.queue_free)
	over(age, 0.35, func(k: float) -> void: _light.light_energy = 14.0 * _size * (1.0 - k) * (1.0 - k))
	_ring(pos, dir, 0.3, 3.0, 0.26)
	var air := sprite(1, main, _size)
	air.position = pos
	over(age, 0.2, func(k: float) -> void:
		air.scale = Vector3.ONE * _size * lerpf(0.2, 2.2, ease_out(k))
		param(air, "ring_width", lerpf(0.3, 0.05, k))
		param(air, "color", Color(main.r, main.g, main.b, 1.0 - k))
	)
	at(age + 0.21, air.queue_free)
	# 進んできた向きへ突き抜ける火花
	emit(Lib.particles(Lib.streak_mesh(), Lib.material("spark"), Lib.process({
		"direction": dir,
		"spread": 60.0,
		"initial_velocity_min": 4.0 * _size,
		"initial_velocity_max": 11.0 * _size,
		"damping_min": 4.0,
		"damping_max": 8.0,
		"gravity": Vector3(0, -9, 0),
		"particle_flag_align_y": true,
		"scale_min": 0.15 * _size,
		"scale_max": 0.4 * _size,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.5, 0.7], [1.0, 0.0]]),
		"lifetime_randomness": 0.4,
		"color_ramp": Lib.ramp([[0.0, core], [0.4, main], [1.0, _pal["tail"]]]),
	}), 24, 0.5), 0.0, pos)
	# 手前へはね返る煙のかたまり
	var smoke: Color = _pal["smoke"]
	emit(Lib.particles(Lib.cloud_mesh(0), Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "edge_color": Vector3(main.r, main.g, main.b) * 0.6}), Lib.process({
		"direction": -dir,
		"spread": 85.0,
		"initial_velocity_min": 1.2 * _size,
		"initial_velocity_max": 3.2 * _size,
		"damping_min": 5.0 * _size,
		"damping_max": 8.0 * _size,
		"gravity": Vector3(0, 0.6, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.3 * _size,
		"scale_max": 0.55 * _size,
		"scale_curve": Lib.curve([[0.0, 0.3], [0.2, 1.0], [1.0, 0.8]]),
		"color_ramp": Lib.ramp([[0.0, core], [0.15, main], [0.4, Color(smoke.r, smoke.g, smoke.b, 1)], [1.0, Color(smoke.r, smoke.g, smoke.b, 0)]]),
	}), 7, 0.7), 0.0, pos)


# 進行方向に垂直な輪を置いて、広げながら消す
func _ring(pos: Vector3, dir: Vector3, from_size: float, to_size: float, sec: float) -> void:
	var main: Color = _pal["main"]
	var ring := sprite(1, main, 0.1, false)
	param(ring, "ring_width", 0.16)
	face(ring, pos, dir, _size * from_size)
	over(age, sec, func(k: float) -> void:
		face(ring, pos, dir, _size * lerpf(from_size, to_size, ease_out(k)))
		param(ring, "color", Color(main.r, main.g, main.b, 1.0 - k))
	)
	at(age + sec + 0.01, ring.queue_free)


func _point(t: float) -> Vector3:
	return _from.lerp(_ctrl, t).lerp(_ctrl.lerp(_to, t), t)


func _tangent(t: float) -> Vector3:
	var d := (_ctrl - _from) * (1.0 - t) + (_to - _ctrl) * t
	return d.normalized() if d.length_squared() > 0.000001 else Vector3.FORWARD
