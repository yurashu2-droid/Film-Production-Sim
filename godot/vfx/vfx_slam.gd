extends "res://vfx/vfx_base.gd"
# ドカン着地。地面を叩いた瞬間に、漫画の衝撃マークが弾け、ひび割れが走り、煙玉が輪になって転がり出る。
# 参考：『ワンパンマン』の着地で割れる地面、『ギルティギア』のヒットマーク、アメコミの「POW」の描き文字。
#   0〜2コマ   衝撃マーク（白いぎざぎざ）と閃光。ここだけ光る
#   0〜3コマ   ひび割れが中心から外へ走る。最初は焼けた橙、冷めて黒い線になる
#   1コマ〜    煙玉が低く外へ押し出され、連番で三日月に欠けて消える。小石と、地面を払う線
#   終わり     ひびが外側から中心へ閉じる。最後に残るのは中心の黒い点で、それも消える
# 素材：LeLu's Noise Pack（vfx_ex1d / vfx_hit22 / cracks336 / smoke_flipbook_n7）。15コマ/秒。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const FPS := 15.0
const INK := Color(0.07, 0.05, 0.04, 1.0)
const HOT := Color(7.0, 2.2, 0.15, 1.0)
# 煙玉の振り付け：[遅れ(秒), 向き(横, 上, 奥), 進む距離, 大きさ, 秒数]。大3つ → 間を埋める中 → 遅れて小
const SMOKE := [
	[0.07, Vector3(1.0, 0.08, 0.2), 1.5, 1.5, 1.1],
	[0.07, Vector3(-0.9, 0.08, 0.5), 1.45, 1.4, 1.2],
	[0.07, Vector3(0.1, 0.08, -1.0), 1.4, 1.3, 1.05],
	[0.13, Vector3(0.6, 0.1, 0.9), 1.9, 1.05, 1.0],
	[0.13, Vector3(-0.8, 0.1, -0.7), 1.95, 1.0, 0.95],
	[0.13, Vector3(0.9, 0.1, -0.7), 2.0, 0.95, 0.9],
	[0.13, Vector3(-0.3, 0.1, 1.0), 1.85, 1.1, 1.0],
	[0.2, Vector3(1.0, 0.3, 0.6), 2.5, 0.65, 0.75],
	[0.2, Vector3(-1.0, 0.3, 0.1), 2.6, 0.6, 0.8],
	[0.2, Vector3(0.2, 0.5, -1.0), 2.4, 0.6, 0.7],
	[0.27, Vector3(-0.5, 0.9, -0.3), 1.6, 0.5, 0.6],
	[0.27, Vector3(0.4, 1.1, 0.3), 1.8, 0.45, 0.6],
]

var _size := 1.0
var _frame := -1
var _mark: MeshInstance3D
var _star: MeshInstance3D
var _cracks: MeshInstance3D
var _strokes: Array = []     # [帯, 始点, 曲げる点, 終点, 寿命]


static func spawn(parent: Node, ground: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 2.9
	_cracks = _stamp("cracks336.png", {"cut": 0.22, "core_cut": 2.0, "reveal": 0.0})
	_cracks.rotation.x = -PI / 2.0
	_cracks.position.y = 0.02
	_cracks.scale = Vector3.ONE * 5.2 * size
	_mark = _stamp("vfx_ex1d.jpg", {"cut": 0.4, "core_cut": 2.0, "billboard": true, "toward_camera": size, "color": Color(1.5, 1.45, 1.2, 1.0)})
	_mark.position.y = 0.7 * size
	_star = _stamp("vfx_hit22.jpg", {"cut": 0.3, "core_cut": 0.75, "billboard": true, "toward_camera": size * 1.2, "color": Color(8, 4.5, 0.6, 1.0), "core_color": Color(10, 9.5, 7, 1.0)})
	_star.position.y = 0.7 * size
	var light := lamp(Color(1.0, 0.75, 0.4), 9.0 * size)
	light.position.y = size
	over(0.0, 0.35, func(k: float) -> void: light.light_energy = 14.0 * size * (1.0 - k) * (1.0 - k))
	var smoke: Node3D = Puffs.new()
	add_child(smoke)
	smoke.start(SMOKE, size, Color(1, 1, 1))
	# 小石：コマ打ちで放物線
	var pebbles := emit(Lib.particles(Lib.cloud_mesh(1), Lib.material("spark", {"tint": Vector3(0.2, 0.15, 0.11)}), Lib.process({
		"direction": Vector3.UP,
		"spread": 62.0,
		"initial_velocity_min": 3.0 * size,
		"initial_velocity_max": 7.5 * size,
		"gravity": Vector3(0, -15, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.05 * size,
		"scale_max": 0.13 * size,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]]),
	}), 14, 0.9), 0.0, Vector3(0, 0.1, 0))
	pebbles.fixed_fps = int(FPS)
	pebbles.interpolate = false
	pebbles.fract_delta = false
	# 地面を払う線：外へ走って、先が少し浮く
	for i in 7:
		var a := i * TAU / 7.0 + randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var from := global_position + out * 0.5 * size + Vector3(0, 0.05, 0)
		var reach := randf_range(1.8, 3.2) * size
		var to := from + out * reach + Vector3(0, randf_range(0.1, 0.5) * size, 0)
		var r: MeshInstance3D = Ribbon.new()
		r.material_override = Lib.material("stroke", {"width": randf_range(0.05, 0.1) * size, "color": Color(1.3, 1.2, 1.0, 0.95)})
		add_child(r)
		_strokes.append([r, from, from + out * reach * 0.7, to, randf_range(0.22, 0.34)])
	_pose(0.0)


func _stamp(file_name: String, params: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	var all := {"shape": Lib.tex(file_name), "color": INK, "core_color": INK}
	all.merge(params, true)
	mi.material_override = Lib.material("stamp", all)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _tick(_delta: float) -> void:
	for s: Array in _strokes:
		var k: float = age / s[4]
		var points := PackedVector3Array()
		if k < 1.0:
			var head := ease_out(clampf((k - 0.35) / 0.65, 0.0, 1.0))
			var tail := ease_out(clampf(k / 0.55, 0.0, 1.0))
			if tail - head > 0.02:
				for p in 9:
					var t := lerpf(head, tail, float(p) / 8.0)
					points.append((s[1] as Vector3).lerp(s[2], t).lerp((s[2] as Vector3).lerp(s[3], t), t))
		s[0].draw(points)
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	# 衝撃マーク：1コマ目で最大、2〜3コマ目で少し回って縮む
	_mark.visible = t < 0.2
	_mark.scale = Vector3.ONE * _size * (3.4 if t < 0.07 else (3.0 if t < 0.14 else 2.2))
	param(_mark, "spin", 0.0 if t < 0.07 else 0.18)
	param(_mark, "cut", 0.4 if t < 0.14 else 0.62)
	_star.visible = t < 0.07
	_star.scale = Vector3.ONE * _size * 3.2
	# ひび割れ：走る → 冷める → 外から閉じる
	param(_cracks, "reveal", ease_out(clampf(t / 0.2, 0.0, 1.0)))
	var cool := smoothstep(0.1, 0.75, t)
	var c := HOT.lerp(INK, cool)
	param(_cracks, "color", c)
	param(_cracks, "core_color", c)
	param(_cracks, "hide", smoothstep(1.9, 2.75, t))
	_cracks.visible = t < 2.8
