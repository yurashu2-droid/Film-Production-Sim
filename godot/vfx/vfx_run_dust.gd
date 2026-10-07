extends "res://vfx/vfx_base.gd"
# 蹴り上げの土ぼこり。輪郭線つきの塊が「ポポポン」と順に弾け、後ろへ尾を引いて巻き上がり、縮みながら穴が開いて消える。
# 参考：『ゼルダの伝説 風のタクト』の丸く巻いて縮む煙、『ギルティギア』のダッシュで地を這う土煙、輪郭つきの塊で描くアニメの土煙。
# 塊は乱数でばらまかず、ひとつずつ「いつ・どこへ・どの大きさで」を振り付ける（形を設計するため）。
#   蹴り出し：大きな塊3つ ＋ 上へ巻き上がる尾 ＋ 地面を横へ這うすそ ＋ 跳ねる小石 ＋ 踏み込みの線 ＋ 地面を払う線
#   一歩ごと：小さな塊4つ、小石、線が1本
# 出だしは進む向きに伸び、止まると丸く戻る（伸び縮み）。動きは 15コマ/秒 のコマ打ち。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const SAND := Color(0.95, 0.75, 0.45)
const FPS := 15.0
const POINTS := 9
# 蹴り出しの振り付け：[遅れ(コマ), 向き(横, 上, 後ろ), 進む距離, 直径, 秒数]
const KICK := [
	[0, Vector3(0.0, 0.35, 1.0), 0.55, 0.66, 0.85],
	[0, Vector3(-0.45, 0.25, 0.9), 0.5, 0.52, 0.75],
	[0, Vector3(0.5, 0.3, 0.85), 0.55, 0.5, 0.8],
	[1, Vector3(0.1, 0.7, 1.0), 1.0, 0.44, 0.75],
	[1, Vector3(-0.2, 0.95, 1.0), 1.35, 0.36, 0.7],
	[2, Vector3(0.15, 1.2, 0.95), 1.7, 0.28, 0.62],
	[3, Vector3(-0.05, 1.5, 0.8), 2.0, 0.2, 0.52],
	[1, Vector3(-1.0, 0.05, 0.45), 0.85, 0.3, 0.55],
	[1, Vector3(1.0, 0.05, 0.4), 0.9, 0.28, 0.55],
	[2, Vector3(-1.0, 0.08, 0.1), 1.25, 0.2, 0.45],
	[2, Vector3(1.0, 0.08, 0.15), 1.2, 0.21, 0.45],
	[2, Vector3(0.3, 0.2, 1.0), 1.35, 0.3, 0.6],
]
const STEP := [
	[0, Vector3(0.0, 0.4, 1.0), 0.3, 0.34, 0.5],
	[0, Vector3(-0.6, 0.2, 0.8), 0.32, 0.24, 0.42],
	[1, Vector3(0.5, 0.75, 1.0), 0.55, 0.2, 0.42],
	[1, Vector3(0.1, 1.1, 0.9), 0.75, 0.14, 0.36],
]

var runner: Node3D          # 使わないが、他の走りの演出と同じ約束で受け取る
var _size := 1.0
var _frame := -1
var _basis := Basis.IDENTITY     # 横・上・後ろ
var _plan: Array = []
var _spin: Array[float] = []
var _mm: MultiMesh
var _strokes: Array = []    # [帯, 始点, 曲げる点, 終点, 寿命]


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	add_to_group("dash_dust")
	var back := -Vector3(direction.x, 0, direction.z).normalized()
	if back.length_squared() < 0.01:
		back = Vector3.BACK
	var side := back.cross(Vector3.UP)
	_basis = Basis(side, Vector3.UP, back)
	_size = size * 1.2
	_plan = STEP if trail else KICK
	life = 0.7 if trail else 1.15

	# 塊：1回の描画で全部出す。輪郭線は next_pass で重ねる
	var cells := Lib.noise("cells")
	var mat := Lib.material("cloud", {
		"dissolve_texture": cells,
		"shadow_tint": Vector3(0.7, 0.58, 0.55),
		"highlight_tint": Vector3(1.22, 1.2, 1.12),
		"shadow_threshold": 0.0,
	})
	mat.next_pass = Lib.material("cloud_ink", {"dissolve_texture": cells})
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = Lib.cloud_mesh(0)
	_mm.instance_count = _plan.size()
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _mm
	holder.material_override = mat
	holder.top_level = true
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(global_position - Vector3.ONE * 4.0, Vector3.ONE * 8.0)
	add_child(holder)
	for i in _plan.size():
		_spin.append(randf_range(0.0, TAU))
	_pose()

	# 小石：暗い粒が放物線で跳ねる
	var pebbles := emit(Lib.particles(Lib.cloud_mesh(1), Lib.material("spark", {"tint": Vector3(0.3, 0.2, 0.12)}), Lib.process({
		"direction": back + Vector3(0, 0.9, 0),
		"spread": 38.0,
		"initial_velocity_min": 2.0 * size,
		"initial_velocity_max": (3.0 if trail else 5.0) * size,
		"gravity": Vector3(0, -13, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.035 * size,
		"scale_max": 0.07 * size,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.75, 1.0], [1.0, 0.0]]),
	}), 2 if trail else 9, 0.5), 0.0, Vector3(0, 0.05, 0))
	pebbles.fixed_fps = int(FPS)
	pebbles.interpolate = false
	pebbles.fract_delta = false

	var foot := global_position + Vector3(0, 0.04, 0)
	# 地面を払う線：後ろへ伸びて、先が少し巻き上がる
	for i in (1 if trail else 4):
		var lean := side * randf_range(-0.5, 0.5) * size
		var reach := randf_range(0.9, 1.8) * size * (0.5 if trail else 1.0)
		var to := foot + back * reach + lean + Vector3(0, randf_range(0.15, 0.45) * size, 0)
		_stroke(foot + lean * 0.3, foot + back * reach * 0.75 + lean * 0.5, to, randf_range(0.035, 0.065), randf_range(0.2, 0.3))
	if trail:
		return
	# 踏み込みの線：足元から後ろ斜め上へ、短い線が放射状に2コマだけ出る
	for i in 6:
		var out := (back * randf_range(0.5, 1.0) + Vector3.UP * randf_range(0.15, 1.0) + side * randf_range(-0.8, 0.8)).normalized()
		var from := foot + out * 0.25 * size
		var to := foot + out * randf_range(0.6, 1.05) * size
		_stroke(from, (from + to) * 0.5, to, randf_range(0.04, 0.07), 0.14)


func _stroke(from: Vector3, bend: Vector3, to: Vector3, width: float, seconds: float) -> void:
	var r: MeshInstance3D = Ribbon.new()
	r.material_override = Lib.material("stroke", {"width": width * _size, "color": Color(1.2, 1.08, 0.86, 0.95)})
	add_child(r)
	_strokes.append([r, from, bend, to, seconds])


func _tick(_delta: float) -> void:
	for s: Array in _strokes:
		var k: float = age / s[4]
		var points := PackedVector3Array()
		if k < 1.0:
			var head := ease_out(clampf((k - 0.35) / 0.65, 0.0, 1.0))
			var tail := ease_out(clampf(k / 0.55, 0.0, 1.0))
			if tail - head > 0.02:
				for p in POINTS:
					var t := lerpf(head, tail, float(p) / (POINTS - 1))
					points.append((s[1] as Vector3).lerp(s[2], t).lerp((s[2] as Vector3).lerp(s[3], t), t))
		s[0].draw(points)
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose()


# 塊をコマごとに置き直す
func _pose() -> void:
	var now := maxf(_frame, 0) / FPS
	for i in _plan.size():
		var plan: Array = _plan[i]
		var t: float = now - plan[0] / FPS
		var k: float = t / plan[4]
		if t < 0.0 or k >= 1.0:
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), global_position))
			_mm.set_instance_color(i, Color(SAND.r, SAND.g, SAND.b, 1.0))
			continue
		var dir: Vector3 = (_basis * (plan[1] as Vector3)).normalized()
		var travel := ease_out(clampf(t / 0.3, 0.0, 1.0))
		# 弾けて少し行き過ぎ、戻り、後半で縮む
		var pop := lerpf(0.35, 1.2, t / 0.07) if t < 0.07 else (lerpf(1.2, 1.0, (t - 0.07) / 0.13) if t < 0.2 else 1.0)
		var shrink := 1.0 - pow(smoothstep(0.5, 1.0, k), 1.5)
		var dia: float = plan[3] * _size * pop * shrink
		# 出だしは進む向きへ伸ばし、止まるにつれて丸く戻す
		var long := 1.0 + 0.7 * (1.0 - travel)
		var thin := 1.0 - 0.28 * (1.0 - travel)
		var look := Basis.looking_at(dir, Vector3.RIGHT if absf(dir.y) > 0.98 else Vector3.UP)
		var shape: Basis = look * Basis(Vector3.FORWARD, _spin[i] + t * 2.2) * Basis.from_scale(Vector3(thin, thin, long) * maxf(dia, 0.0001))
		var reach: float = plan[2]
		var pos: Vector3 = global_position + dir * reach * _size * travel + Vector3.UP * 0.22 * t * _size
		pos.y = maxf(pos.y, global_position.y + dia * 0.36)
		_mm.set_instance_transform(i, Transform3D(shape, pos))
		var tone := 1.08 - 0.05 * (i % 3)
		_mm.set_instance_color(i, Color(SAND.r * tone, SAND.g * tone, SAND.b * tone, 1.0 - smoothstep(0.68, 1.0, k) * 0.9))
