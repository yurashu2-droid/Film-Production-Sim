extends "res://vfx/vfx_base.gd"
# スプラトゥーン風のインク。光らせず、濃い色と白い照りで「ぬるっとした塊」に見せる。
# 参考：『スプラトゥーン』のシューターの着弾、スプラッシュボム、スペシャルのトルネード。
#   "splash"   着弾：艶のある塊が冠のように輪になって跳ね上がる ＋ 細い筋 ＋ 地面の水たまり
#   "bomb"     ボム：3回ふくらんで弾け、大きな塊・滴・細い筋が速さを変えて全方向へ飛ぶ
#   "tornado"  竜巻：重ねた層の竜巻（vfx_tornado.gd）をインクの色で回し、滴を振り飛ばし続ける
# 空中のインクは、模様を貼った殻ではなく、艶のある丸い塊の集まりで作る（殻は破れた紙に見えた）。水たまりは厚みと照りを描く（splat シェーダー）。
# 滴は1つずつ放物線で飛ばし、落ちた場所に小さな水たまりを作る。
# 終わり：水たまりは乾いて、ふちが外から中心へ引いていく（穴を開けて消さない）。インクは動きがなめらかなほうが合うので、コマ打ちにしない。

const INKS := {
	"orange": Vector3(1.0, 0.3, 0.02),
	"blue": Vector3(0.12, 0.2, 1.0),
	"pink": Vector3(1.0, 0.07, 0.4),
	"green": Vector3(0.38, 1.0, 0.06),
}
const G := 16.0
const Tornado := preload("res://vfx/vfx_tornado.gd")

var _size := 1.0
var _ink := Vector3.ONE
var _dry_at := 1.7
var _drops: Array = []       # [生まれる時刻, 出発点, 初速, 直径, 落ちるまでの秒数]
var _puddles: Array = []     # [板, 現れる時刻, 広がる秒数, 乾きはじめる時刻]
var _mm: MultiMesh


static func spawn(parent: Node, ground: Vector3, kind: String = "splash", size: float = 1.0, ink: String = "orange") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(kind, size, ink)
	return fx


func start(kind: String, size: float, ink: String) -> void:
	_size = size
	_ink = INKS.get(ink, INKS["orange"])
	match kind:
		"bomb":
			_bomb()
		"tornado":
			_tornado()
		_:
			_splash()
	# 滴は1回の描画でまとめて出す
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 14
	ball.rings = 7
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = ball
	_mm.instance_count = _drops.size()
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _mm
	holder.material_override = Lib.material("ink", {"color": _ink})
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-14, -1, -14) * size, Vector3(28, 16, 28) * size)
	add_child(holder)
	_tick(0.0)


# ---- 3つの演出 ----

func _splash() -> void:
	life = 2.7
	_dry_at = 1.6
	_puddle(Vector3.ZERO, 2.7, 0.0, 0.2)
	# 真ん中の塊：つぶれて水たまりに沈む
	var blob := _blob()
	over(0.0, 0.26, func(k: float) -> void:
		blob.scale = Vector3(lerpf(0.9, 2.1, ease_out(k)), lerpf(1.0, 0.05, k), lerpf(0.9, 2.1, ease_out(k))) * _size
	)
	at(0.27, blob.queue_free)
	# 冠：艶のある塊が輪になって跳ね上がる（上へ大きく、外へ少し）。筒の殻ではなく、ひと粒ずつの塊で作る
	for i in 11:
		var a := i * TAU / 11.0 + randf_range(-0.15, 0.15)
		var out := Vector3(cos(a), 0, sin(a))
		_drop(0.0, out * 0.35 + Vector3.UP * 0.15, out * randf_range(1.6, 2.8) + Vector3.UP * randf_range(4.5, 6.8), randf_range(0.26, 0.44))
	# 細い筋：速く遠くへ飛ぶ小さな滴
	for i in 10:
		var a := randf() * TAU
		_drop(0.02, Vector3(0, 0.2, 0), Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 8.5) + Vector3.UP * randf_range(2.0, 5.5), randf_range(0.07, 0.13))


func _bomb() -> void:
	life = 3.8
	_dry_at = 2.7
	var fuse := 0.66
	# 溜め：3回、だんだん大きくふくらむ。最後は白っぽく
	var blob := _blob()
	blob.position.y = 0.4 * _size
	over(0.0, fuse, func(k: float) -> void:
		var beat := fmod(k * 3.0, 1.0)
		var swell := 0.7 + 0.25 * floorf(k * 3.0) + 0.35 * sin(beat * PI)
		blob.scale = Vector3(swell * (1.0 + 0.2 * sin(beat * PI)), swell * (1.0 - 0.15 * sin(beat * PI)), swell * (1.0 + 0.2 * sin(beat * PI))) * _size
		param(blob, "color", _ink.lerp(Vector3(1.6, 1.6, 1.6), 0.6 if k > 0.86 else 0.0))
	)
	at(fuse, blob.queue_free)
	# 破裂：真ん中の大きな塊が横へつぶれ広がる
	var mass := _blob()
	mass.visible = false
	at(fuse, func() -> void: mass.visible = true)
	over(fuse, 0.32, func(k: float) -> void:
		mass.position.y = lerpf(0.6, 0.1, k) * _size
		mass.scale = Vector3(lerpf(1.6, 4.6, ease_out(k)), lerpf(2.0, 0.08, k * k), lerpf(1.6, 4.6, ease_out(k))) * _size
	)
	at(fuse + 0.33, mass.queue_free)
	_puddle(Vector3.ZERO, 4.7, fuse, 0.25)
	# 大きな塊・ふつうの滴・細い筋の3種類を、速さを変えて飛ばす（大きいものほど遅く近く）
	for i in 14:
		var a := i * 2.39996
		var up := randf_range(0.25, 1.0)
		_drop(fuse, Vector3(0, 0.5, 0), (Vector3(cos(a), 0, sin(a)) * (1.0 - up * 0.6) + Vector3.UP * up).normalized() * randf_range(4.0, 8.0), randf_range(0.45, 0.85))
	for i in 26:
		var a := i * 2.39996 + 1.0
		var up := randf_range(0.15, 1.0)
		_drop(fuse, Vector3(0, 0.5, 0), (Vector3(cos(a), 0, sin(a)) * (1.0 - up * 0.6) + Vector3.UP * up).normalized() * randf_range(6.0, 12.5), randf_range(0.16, 0.4))
	for i in 12:
		var a := randf() * TAU
		_drop(fuse, Vector3(0, 0.5, 0), (Vector3(cos(a), 0, sin(a)) + Vector3.UP * randf_range(0.2, 0.8)).normalized() * randf_range(9.0, 15.0), randf_range(0.07, 0.12))


func _tornado() -> void:
	life = 4.6
	_dry_at = 3.6
	var spin := 2.6         # 回っている秒数
	# 本体は重ねた層の竜巻（vfx_tornado.gd）を、光らないインクの色で使う
	var twister: Node3D = Tornado.new()
	add_child(twister)
	twister.start(_size * 0.8, 2.0, Tornado.ink_palette(_ink))
	_puddle(Vector3.ZERO, 3.3, 0.1, 1.4)
	# 振り飛ばされる滴：漏斗の表面から、回る向きへ
	for i in 34:
		var born := 0.3 + (spin - 0.2) * float(i) / 34.0
		var a := born * 9.0 + i
		var h := randf_range(0.5, 3.4)
		var out := Vector3(cos(a), 0, sin(a))
		_drop(born, out * (0.3 + h * 0.3) + Vector3.UP * h, Vector3(-out.z, 0, out.x) * randf_range(3.5, 7.5) + out * randf_range(1.0, 3.0) + Vector3.UP * randf_range(0.5, 3.5), randf_range(0.12, 0.3))


# ---- 部品 ----

func _blob() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.cloud_mesh(0)
	mi.material_override = Lib.material("ink", {"color": _ink})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# 滴を1つ予約する。落ちる場所に小さな水たまりも予約する。
func _drop(born: float, from: Vector3, velocity: Vector3, dia: float) -> void:
	var fall := (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * G * from.y)) / G
	_drops.append([born, from * _size, velocity * _size, dia * _size, fall])
	var land := from + velocity * fall
	_puddle(Vector3(land.x, 0, land.z), dia * 2.6, born + fall, 0.12)


func _puddle(at_local: Vector3, radius: float, born: float, grow_sec: float) -> void:
	var quad := MeshInstance3D.new()
	quad.mesh = Lib.quad()
	quad.material_override = Lib.material("splat", {
		"noise_texture": Lib.noise("soft"), "color": _ink, "spread": 0.0, "seed": Vector2(randf(), randf()), "arm": 1.0 if radius > 1.5 else 0.3,
	})
	quad.rotation.x = -PI / 2.0
	quad.position = at_local * _size + Vector3(0, 0.02 + _puddles.size() * 0.0015, 0)
	quad.scale = Vector3.ONE * radius * 2.0 * _size
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.visible = false
	add_child(quad)
	# 小さい水たまりから先に乾く
	_puddles.append([quad, born, grow_sec, _dry_at - 0.35 + minf(radius, 3.0) * 0.12])


func _tick(_delta: float) -> void:
	for i in _drops.size():
		var d: Array = _drops[i]
		var t: float = age - d[0]
		var tr := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO)
		if t >= 0.0 and t < d[4]:
			var vel: Vector3 = (d[2] as Vector3) + Vector3.DOWN * G * _size * t
			var pos: Vector3 = (d[1] as Vector3) + (d[2] as Vector3) * t + Vector3.DOWN * 0.5 * G * _size * t * t
			var long := 1.0 + minf(vel.length() / _size * 0.11, 1.5)
			var dia: float = d[3] * minf(t / 0.05, 1.0)
			var look := Basis.looking_at(vel.normalized(), Vector3.RIGHT if absf(vel.normalized().y) > 0.98 else Vector3.UP)
			tr = Transform3D(look * Basis.from_scale(Vector3(dia, dia, dia * long)), pos)
		_mm.set_instance_transform(i, tr)
	for p: Array in _puddles:
		var quad: MeshInstance3D = p[0]
		quad.visible = age >= p[1]
		if quad.visible:
			param(quad, "spread", ease_out(clampf((age - p[1]) / p[2], 0.0, 1.0)))
			param(quad, "recede", smoothstep(0.0, 1.0, clampf((age - p[3]) / 0.9, 0.0, 1.0)))
