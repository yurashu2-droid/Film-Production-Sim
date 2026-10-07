extends "res://vfx/vfx_base.gd"
# 気合のオーラ。足元から風が押し出され、小石が浮き、体を包む炎のようなオーラが点滅しながら点く。最後は瞬いて、下から上へ抜けて消える。
# 参考：『ドラゴンボール』の気を溜めるオーラと浮く小石、『HUNTER×HUNTER』の練。
#   溜め    煙玉が足元から外へ押され、小石が浮きはじめる。オーラは「点く・消える・点く」で入る
#   継続    外側（濃い色、ゆっくり）と内側（明るい芯、速い）の2層が流れ昇る。稲妻がときどき走り、白い風の線が昇る
#   終わり  2回瞬き、根元から上へ抜けて消える。浮いていた小石は落ちて、着地で消える
# follow を入れると、その相手について行く。
# 素材：LeLu's Noise Pack（firepanningcyl45 / liquidvertical_wave / smoke_flipbook_n7）。12コマ/秒。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const Lightning := preload("res://vfx/vfx_lightning.gd")
const FPS := 12.0
const BUILD := 0.5
const END := 0.5
const SHAPE := [[0.0, 0.55], [0.12, 0.85], [0.42, 1.0], [0.72, 0.66], [1.0, 0.04]]
const ROCKS := 9
const PALETTES := {
	"gold": [Vector3(10, 9.5, 7), Vector3(8, 5.5, 0.9), Vector3(5.5, 2.6, 0.15), Vector3(2.6, 0.8, 0.04)],
	"crimson": [Vector3(10, 8, 7), Vector3(8, 2.2, 0.8), Vector3(5, 0.5, 0.15), Vector3(2.0, 0.08, 0.06)],
	"azure": [Vector3(8, 9.5, 10), Vector3(2.2, 5.5, 9), Vector3(0.5, 2.2, 6.5), Vector3(0.15, 0.6, 3.0)],
}
const GUST := [
	[0.0, Vector3(1.0, 0.05, 0.2), 1.5, 0.75, 0.7],
	[0.0, Vector3(-0.9, 0.05, 0.6), 1.5, 0.7, 0.75],
	[0.0, Vector3(-0.3, 0.05, -1.0), 1.45, 0.72, 0.7],
	[0.08, Vector3(0.8, 0.05, -0.7), 1.9, 0.55, 0.6],
	[0.08, Vector3(0.2, 0.05, 1.0), 1.9, 0.55, 0.65],
	[0.08, Vector3(-1.0, 0.05, -0.2), 1.85, 0.5, 0.6],
]

var follow: Node3D
var _size := 1.0
var _hold := 2.5
var _frame := -1
var _colors: Array = []
var _layers: Array[MeshInstance3D] = []
var _rocks: MultiMesh
var _rock_seed: Array = []      # [角度, 距離, 浮く高さ, 大きさ]
var _crackles: Array[MeshInstance3D] = []
var _winds: Array[MeshInstance3D] = []
var _light: OmniLight3D
static var _mesh: ArrayMesh


static func spawn(parent: Node, ground: Vector3, size: float = 1.0, seconds: float = 2.5, palette: String = "gold") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size, seconds, palette)
	return fx


func start(size: float, seconds: float, palette: String) -> void:
	_size = size
	_hold = seconds
	_colors = PALETTES.get(palette, PALETTES["gold"])
	life = BUILD + seconds + END + 0.8
	if _mesh == null:
		_mesh = Lib.tube_mesh(SHAPE, 32, 24)
	# 筒の奥側の面だけを描く。手前の面を描くと中の人物が隠れてしまう
	var behind := Shader.new()
	behind.code = Lib.shader("flow").code.replace("cull_disabled", "cull_front")
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = Lib.material("flow", {
			"flame": Lib.tex("firepanningcyl45.png"),
			"noise_texture": Lib.tex("liquidvertical_wave.png"),
			"flame_scale": Vector2(1.0, 0.4) if i == 0 else Vector2(1.0, 0.3),
			"flame_speed": Vector2(0.08, 1.0) if i == 0 else Vector2(-0.2, 1.7),
			"noise_scale": Vector2(2.0, 0.6),
			"noise_speed": Vector2(-0.1, 0.5) if i == 0 else Vector2(0.15, 0.9),
			"density": 0.92 if i == 0 else 1.05,
			"tip_fade": 2.2,
			"wobble": 0.07,
			"color_core": _colors[1] if i == 0 else _colors[0],
			"color_hot": _colors[2] if i == 0 else _colors[1],
			"color_mid": _colors[3] if i == 0 else _colors[2],
			"color_edge": (_colors[3] as Vector3) * 0.55 if i == 0 else _colors[3],
		})
		(mi.material_override as ShaderMaterial).shader = behind
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 2, 4))
		add_child(mi)
		_layers.append(mi)
	# 浮く小石：輪郭つきの暗い塊
	var stone := Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "shadow_tint": Vector3(0.55, 0.5, 0.5)})
	stone.next_pass = Lib.material("cloud_ink", {"dissolve_texture": Lib.noise("cells"), "ink": Vector3(0.05, 0.04, 0.03), "thickness": 0.06})
	_rocks = MultiMesh.new()
	_rocks.transform_format = MultiMesh.TRANSFORM_3D
	_rocks.use_colors = true
	_rocks.mesh = Lib.cloud_mesh(2)
	_rocks.instance_count = ROCKS
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _rocks
	holder.material_override = stone
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-4, 0, -4) * size, Vector3(8, 6, 8) * size)
	add_child(holder)
	for i in ROCKS:
		_rock_seed.append([i * 2.39996 + randf_range(-0.3, 0.3), randf_range(0.95, 1.7), randf_range(0.35, 1.9), randf_range(0.1, 0.22)])
	var bright: Vector3 = _colors[1]
	for i in 2:
		var bolt: MeshInstance3D = Ribbon.new()
		bolt.material_override = Lib.material("ribbon", {
			"noise_texture": Lib.noise("soft"), "width": 0.08 * size, "color_head": Color(bright.x, bright.y, bright.z), "color_tail": Color(bright.x, bright.y, bright.z),
			"core_color": _colors[0], "core": 0.3, "taper": 0.5, "erosion": 0.0,
		})
		add_child(bolt)
		_crackles.append(bolt)
	for i in 4:
		var wind: MeshInstance3D = Ribbon.new()
		wind.material_override = Lib.material("stroke", {"width": randf_range(0.03, 0.055) * size})
		add_child(wind)
		_winds.append(wind)
	_light = lamp(Color(bright.x, bright.y, bright.z) / maxf(bright.x, maxf(bright.y, bright.z)), 7.0 * size)
	_light.position.y = size
	var gust: Node3D = Puffs.new()
	add_child(gust)
	gust.start(GUST, size, Color(1, 1, 1))
	_pose(0.0)


func _tick(_delta: float) -> void:
	if is_instance_valid(follow):
		global_position = follow.global_position
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	var out := t - BUILD - _hold
	var gone := clampf(out / END, 0.0, 1.0)
	# 点き方・消え方：コマ単位で瞬かせる
	var lit := true
	if t < BUILD:
		lit = [false, true, false, true, true, true][mini(int(t * FPS), 5)]
	elif out > -4.0 / FPS and out < 0.0:
		lit = [false, true, false, true][clampi(int((out + 4.0 / FPS) * FPS), 0, 3)]
	var swell := ease_out(clampf(t / BUILD, 0.0, 1.0))
	for i in _layers.size():
		var layer := _layers[i]
		var slim := 1.0 if i == 0 else 0.72
		layer.visible = lit and gone < 1.0
		layer.scale = Vector3(1.05 * slim, 3.1 * (1.0 + 0.6 * gone), 1.05 * slim) * _size * lerpf(0.6, 1.0, swell) * (1.0 + 0.04 * sin(t * 9.0))
		param(layer, "phase", t)
		param(layer, "eaten", gone)
	_light.light_energy = (3.0 * _size * swell * (1.0 - gone)) if lit else 0.0
	# 小石：浮く → 漂う → 落ちる
	for i in ROCKS:
		var rock: Array = _rock_seed[i]
		var lift := ease_out(clampf((t - 0.1 - i * 0.03) / 0.7, 0.0, 1.0))
		var y: float = rock[2] * lift + 0.08 * sin(t * 2.4 + i)
		if out > 0.0:
			y = maxf(rock[2] - 9.0 * out * out, 0.0)
		var landed := out > 0.0 and y <= 0.0
		var dia: float = rock[3] * (0.0001 if landed or lift <= 0.0 else 1.0)
		var a: float = rock[0] + t * 0.35
		var pos := Vector3(cos(a) * rock[1], y + rock[3] * 0.4, sin(a) * rock[1]) * _size
		_rocks.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(t * 1.3 + i, i * 1.7, t * 0.9)) * Basis.from_scale(Vector3.ONE * dia * _size), pos))
		_rocks.set_instance_color(i, Color(0.2, 0.17, 0.15, 1.0))
	# 稲妻：ときどき体の横を走る
	for bolt in _crackles:
		var points := PackedVector3Array()
		if lit and gone <= 0.0 and t > BUILD and randf() < 0.4:
			var a := randf() * TAU
			var from := global_position + Vector3(cos(a) * 0.7, randf_range(0.2, 1.4), sin(a) * 0.7) * _size
			points = Lightning._bolt(from, from + Vector3(randf_range(-0.5, 0.5), randf_range(0.5, 1.3), randf_range(-0.5, 0.5)) * _size, 0.24, 3)
		bolt.draw(points)
	# 白い風の線：螺旋で昇る
	for i in _winds.size():
		var points := PackedVector3Array()
		var cycle := fposmod((t + i * 0.27) / 0.7, 1.0)
		if lit and gone <= 0.0 and t > 0.15:
			for p in 8:
				var q := cycle - float(p) * 0.05
				if q < 0.0:
					continue
				var a := i * 1.6 + q * 3.2
				var r := (1.25 - 0.55 * q) * _size
				points.append(global_position + Vector3(cos(a) * r, (0.1 + q * 3.0) * _size, sin(a) * r))
		_winds[i].draw(points)
