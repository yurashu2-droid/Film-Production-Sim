extends "res://vfx/vfx_base.gd"
# 竜巻。ユーザーの参考画像（青い竜巻）と、その構造の読み解きに沿って組む。
#   本体   同じ軸の殻を5層。1層ごとはすき間だらけで、外は暗く、中心ほど明るい。回る速さも層ごとに違う
#   根元   本体とは別の動きをする、太く詰まった低い帯（逆回り・脈打つ）と、地面すれすれの跳ね
#   地面   渦の模様を3枚、大きさ・回る向き・速さを変えて重ねる。細い波紋が広がっては消える
#   破片   暗い欠片が渦に巻かれて昇る
#   出入り 層ごとに時刻をずらす。芯から立ち上がり、外側から順に消える。地面の模様も1枚ずつ遅れて閉じる（急に消えない）
# 素材：LeLu's Noise Pack（noise_wo14 / marblenoise_tiled / vfx_spiral07）。回転はなめらかなほうが渦に見えるので、コマ打ちにしない。

const LAYERS := 5
const FUNNEL := [[0.0, 0.16], [0.18, 0.3], [0.5, 0.56], [0.8, 0.84], [1.0, 1.0]]
const SKIRT := [[0.0, 1.5], [0.2, 1.05], [0.55, 0.62], [1.0, 0.34]]
const LIP := [[0.0, 1.25], [1.0, 1.95]]
# 外 → 中心。[半径の割合, すき間の多さ, 回る速さ, 昇る速さ]
const SHELLS := [
	[1.3, 0.63, 0.4, 0.2],
	[1.08, 0.61, 0.6, 0.32],
	[0.86, 0.59, 0.85, 0.45],
	[0.62, 0.56, 1.15, 0.6],
	[0.38, 0.52, 1.5, 0.8],
]
# 外 → 中心の色と、各層の明るい筋。最後は根元と地面に使う強い色
const PALETTES := {
	"blue": [Vector3(0.015, 0.03, 0.22), Vector3(0.04, 0.16, 0.85), Vector3(0.12, 0.55, 2.4), Vector3(0.5, 2.0, 5.0), Vector3(2.4, 5.0, 8.0), Vector3(1.2, 4.0, 8.0)],
	"crimson": [Vector3(0.16, 0.005, 0.02), Vector3(0.75, 0.03, 0.05), Vector3(2.4, 0.16, 0.1), Vector3(6.0, 1.3, 0.4), Vector3(10.0, 8.0, 6.0), Vector3(9.0, 3.0, 0.8)],
	"ink": [Vector3(0.3, 0.07, 0.0), Vector3(0.62, 0.17, 0.01), Vector3(1.0, 0.3, 0.02), Vector3(1.2, 0.48, 0.08), Vector3(1.6, 1.3, 1.0), Vector3(1.25, 0.5, 0.1)],
}

var _size := 1.0
var _hold := 2.5
var _colors: Array = []
var _shells: Array[MeshInstance3D] = []
var _skirt: MeshInstance3D
var _lip: MeshInstance3D
var _ground: Array[MeshInstance3D] = []
var _ripples: Array[MeshInstance3D] = []
var _flecks: MultiMesh
var _light: OmniLight3D


# 光らないインクの色の組（外 → 中心、最後は根元と地面用）
static func ink_palette(ink: Vector3) -> Array:
	return [ink * 0.3, ink * 0.55, ink * 0.85, ink * 1.1, ink * 0.5 + Vector3(0.8, 0.8, 0.8), ink * 1.15]


static func spawn(parent: Node, ground: Vector3, size: float = 1.0, seconds: float = 2.5, palette: Variant = "blue") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size, seconds, palette)
	return fx


func start(size: float, seconds: float, palette: Variant) -> void:
	_size = size
	_hold = seconds
	_colors = palette if palette is Array else PALETTES.get(palette, PALETTES["blue"])
	life = 0.6 + seconds + 1.7
	for i in LAYERS:
		var ratio: float = SHELLS[i][0]
		var profile: Array = []
		for p: Array in FUNNEL:
			profile.append([p[0], p[1] * ratio])
		var shell := _wisp(Lib.tube_mesh(profile, 36, 26), i)
		param(shell, "cut", SHELLS[i][1])
		param(shell, "speed_a", Vector2(SHELLS[i][2], SHELLS[i][3]))
		param(shell, "speed_b", Vector2(-SHELLS[i][2] * 0.4, SHELLS[i][3] * 1.3))
		param(shell, "color", _colors[i])
		param(shell, "color_inner", _colors[mini(i + 1, LAYERS - 1)])
		param(shell, "tip", 0.17)
		_shells.append(shell)
	# 根元：太く詰まった帯。本体と逆に、ゆっくり回す
	_skirt = _wisp(Lib.tube_mesh(SKIRT, 36, 10), 7)
	_tune(_skirt, {"scale_a": Vector2(1.0, 0.35), "shear": 0.5, "speed_a": Vector2(-0.35, 0.18), "cut": 0.5, "inner": 0.2, "top_thin": 0.3, "sway": 0.0, "color": _colors[2], "color_inner": _colors[3]})
	_lip = _wisp(Lib.tube_mesh(LIP, 36, 6), 9)
	_tune(_lip, {"scale_a": Vector2(3.0, 0.5), "shear": 0.3, "speed_a": Vector2(1.2, 0.9), "cut": 0.66, "top_thin": 0.35, "sway": 0.0, "color": _colors[3], "color_inner": _colors[4]})
	# 地面：渦を3枚、大きさ・向き・色を変えて重ねる
	for i in 3:
		var swirl := MeshInstance3D.new()
		swirl.mesh = Lib.quad()
		var tone: Vector3 = [_colors[1], _colors[2], _colors[5]][i]
		var bright: Vector3 = [_colors[2], _colors[3], _colors[4]][i]
		swirl.material_override = Lib.material("stamp", {
			"shape": Lib.tex("vfx_spiral07.jpg"), "cut": [0.16, 0.26, 0.4][i], "core_cut": [0.4, 0.5, 0.62][i],
			"color": Color(tone.x, tone.y, tone.z, 1.0), "core_color": Color(bright.x, bright.y, bright.z, 1.0),
		})
		swirl.rotation.x = -PI / 2.0
		swirl.position.y = 0.02 + i * 0.012
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(swirl)
		_ground.append(swirl)
	for i in 1:
		var ring := sprite(1, Color(1, 1, 1, 1), 0.1, false)
		ring.rotation.x = -PI / 2.0
		ring.position.y = 0.07
		_ripples.append(ring)
	# 破片：渦に巻かれて昇る、暗い欠片
	var shard := Lib.material("spark", {"tint": (_colors[0] as Vector3) * 0.6})
	_flecks = MultiMesh.new()
	_flecks.transform_format = MultiMesh.TRANSFORM_3D
	_flecks.mesh = Lib.cloud_mesh(2)
	_flecks.instance_count = 20
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _flecks
	holder.material_override = shard
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-6, 0, -6) * size, Vector3(12, 9, 12) * size)
	add_child(holder)
	var glow: Vector3 = _colors[5]
	_light = lamp(Color(glow.x, glow.y, glow.z) / maxf(glow.x, maxf(glow.y, glow.z)), 12.0 * size)
	_light.position.y = 1.5 * size
	_tick(0.0)


func _wisp(mesh: Mesh, seed_index: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Lib.material("wisp", {
		"mask_a": Lib.tex("noise_wo14.png"), "mask_b": Lib.noise("soft"), "seed": seed_index * 0.37,
	})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-3, -0.5, -3), Vector3(6, 2, 6))
	add_child(mi)
	return mi


static func _tune(node: MeshInstance3D, values: Dictionary) -> void:
	for key: String in values:
		param(node, key, values[key])


func _tick(_delta: float) -> void:
	var t := age
	var out := t - 0.6 - _hold                # 消えはじめからの秒数
	var height := 5.2 * _size
	var radius := 1.55 * _size
	# 本体：芯（内側）から先に立ち上がり、外側から先に消える。1層ごとに 0.12 秒ずらす
	for i in LAYERS:
		var shell := _shells[i]
		var rise := ease_out(clampf((t - (LAYERS - 1 - i) * 0.09) / 0.45, 0.0, 1.0))
		var gone := clampf((out - i * 0.14) / 0.6, 0.0, 1.0)
		shell.visible = rise > 0.0 and gone < 1.0
		# 層ごとに高さを変える。外は低く、芯がいちばん高く突き出る（てっぺんが一直線に揃わない）
		shell.scale = Vector3(radius * (1.0 + 0.25 * gone), height * (0.8 + 0.085 * i) * (1.0 + 0.2 * gone), radius * (1.0 + 0.25 * gone))
		shell.position.y = gone * gone * 1.2 * _size
		param(shell, "phase", t)
		param(shell, "grow", rise)
		param(shell, "eaten", gone * gone * (3.0 - 2.0 * gone))
	# 根元：脈打ちながら逆回り。本体が消えたあとに、遅れてしぼむ
	var seat := ease_out(clampf(t / 0.3, 0.0, 1.0))
	var sink := clampf((out - 0.55) / 0.5, 0.0, 1.0)
	var beat := 1.0 + 0.07 * sin(t * 7.0)
	_skirt.visible = sink < 1.0
	_skirt.scale = Vector3(radius * 0.95 * beat * seat, 1.25 * _size * seat * (1.0 - 0.6 * sink), radius * 0.95 * beat * seat)
	param(_skirt, "phase", t)
	param(_skirt, "eaten", sink * 0.9)
	_lip.visible = sink < 1.0
	_lip.scale = Vector3(radius * (0.9 + 0.12 * sin(t * 5.0 + 1.0)) * seat, 0.45 * _size * (1.0 - sink), radius * (0.9 + 0.12 * sin(t * 5.0 + 1.0)) * seat)
	param(_lip, "phase", t)
	param(_lip, "eaten", sink)
	# 地面の渦：大きい暗い渦から順に現れる。消えるときは縮めず、1枚ごとに別の消え方を、時刻をずらして使う
	#   0 大きい暗い渦：回転が速まり、腕が細って千切れる ／ 1 中の渦：ぐるっと一周ぬぐわれる ／ 2 明るい小さい渦：外へ振り出されながら薄れる
	for i in _ground.size():
		var swirl := _ground[i]
		var open := ease_out(clampf((t - i * 0.14) / 0.4, 0.0, 1.0))
		var shut := clampf((out + 0.1 - [0.55, 0.25, 0.0][i]) / [0.75, 0.6, 0.5][i], 0.0, 1.0)
		swirl.visible = open > 0.0 and shut < 1.0
		swirl.scale = Vector3.ONE * _size * [7.2, 5.4, 3.4][i] * lerpf(0.4, 1.0, open) * (1.0 + (0.9 * shut if i == 2 else 0.0))
		param(swirl, "spin", t * [1.6, -2.6, 4.2][i] + i + (shut * shut * 5.0 if i == 0 else 0.0))
		param(swirl, "cut", [0.16, 0.26, 0.4][i] + (shut * 0.75 if i != 1 else shut * 0.2))
		param(swirl, "sweep", shut if i == 1 else 0.0)
		param(swirl, "sweep_from", t * 0.4)
	# 波紋：2つがずれて、広がっては消える
	var glow: Vector3 = _colors[5]
	for i in _ripples.size():
		var ring := _ripples[i]
		var cycle := fposmod(t * 0.9 + i * 0.5, 1.0)
		ring.visible = out < 0.3
		ring.scale = Vector3.ONE * _size * lerpf(2.0, 7.5, ease_out(cycle))
		param(ring, "ring_width", lerpf(0.08, 0.02, cycle))
		param(ring, "color", Color(glow.x, glow.y, glow.z, (1.0 - cycle) * 0.3 * seat * (1.0 - clampf(out / 0.3, 0.0, 1.0))))
	# 破片：らせんで昇る。消えるときは外へ投げ出され、1つずつ縮む
	for i in _flecks.instance_count:
		var cycle := fposmod(t * (0.45 + 0.02 * (i % 5)) + i * 0.137, 1.0)
		var away := clampf((out - (i % 7) * 0.08) / 0.5, 0.0, 1.0)
		var a := i * 2.4 + t * (3.0 + (i % 3)) + cycle * 3.0
		var r := (0.5 + 1.5 * cycle + 2.2 * away) * radius / 1.55
		var dia := (0.07 + 0.09 * fposmod(i * 0.61, 1.0)) * sin(cycle * PI) * (1.0 - away) * minf(t / 0.4, 1.0) * _size
		var pos := Vector3(cos(a) * r, (0.2 + cycle * 4.6) * _size, sin(a) * r)
		_flecks.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(t * 4.0 + i, i * 1.3, t * 3.0)) * Basis.from_scale(Vector3(1.0, 0.35, 1.6) * maxf(dia, 0.0001)), pos))
	var alive := 1.0 - clampf(out / 0.9, 0.0, 1.0)
	_light.light_energy = 5.0 * _size * seat * alive
