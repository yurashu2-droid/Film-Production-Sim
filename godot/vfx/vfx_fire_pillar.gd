extends "res://vfx/vfx_base.gd"
# 火柱。地面の渦が回りはじめ、柱が一気に噴き上がり、燃え続け、最後は根元からちぎれて昇りながら細って消える。
# 参考：『NARUTO』の火遁、『鬼滅の刃』炎の呼吸の塗り分けた炎、『ゼルダの伝説 ブレス オブ ザ ワイルド』の上昇気流。
#   溜め    地面の渦（橙）が回りながら広がり、小さな炎が舐める
#   噴出    柱が下から上へ立ち上がる。出だしは細長く伸び、すぐ太さが戻る。煙玉が地面を外へ押される
#   継続    外側（橙〜赤、ゆっくり）と芯（白〜黄、速く逆回り）の2層が流れ昇る。火の筋が螺旋で昇る
#   終わり  根元から上へ食われ、ちぎれた柱が昇りながら細る。渦は縮みながら冷めて黒い焦げ跡になり、中心へ消える
# 炎は明るさを4段に切って塗る。素材：LeLu's Noise Pack（firepanningcyl45 / vfx_spiral07 / noise_wo14 / smoke_flipbook_n7）。15コマ/秒。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const FPS := 15.0
const BUILD := 0.4          # 溜めの秒数
const RISE := 0.2           # 立ち上がりの秒数
const END := 0.6            # ちぎれて消える秒数
const SHAPE := [[0.0, 1.0], [0.1, 0.72], [0.45, 0.6], [0.8, 0.5], [1.0, 0.1]]
const SKIRT := [
	[0.0, Vector3(1.0, 0.06, 0.3), 1.9, 1.1, 0.85],
	[0.0, Vector3(-0.8, 0.06, 0.7), 1.8, 1.0, 0.9],
	[0.0, Vector3(-0.5, 0.06, -1.0), 1.9, 1.05, 0.8],
	[0.07, Vector3(0.7, 0.06, -0.8), 2.3, 0.8, 0.75],
	[0.07, Vector3(0.1, 0.06, 1.0), 2.4, 0.75, 0.8],
	[0.07, Vector3(-1.0, 0.06, -0.1), 2.3, 0.8, 0.7],
]

var _size := 1.0
var _hold := 2.0
var _frame := -1
var _outer: MeshInstance3D
var _inner: MeshInstance3D
var _swirl: MeshInstance3D
var _light: OmniLight3D
var _streaks: Array[MeshInstance3D] = []
var _puffed := false
static var _mesh: ArrayMesh


static func spawn(parent: Node, ground: Vector3, size: float = 1.0, seconds: float = 2.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size, seconds)
	return fx


func start(size: float, seconds: float) -> void:
	_size = size
	_hold = seconds
	life = BUILD + seconds + END + 0.9
	if _mesh == null:
		_mesh = Lib.tube_mesh(SHAPE, 32, 28)
	var flame := Lib.tex("firepanningcyl45.png")
	_outer = _layer(flame, {"density": 1.15})
	_inner = _layer(flame, {
		"flame_scale": Vector2(1.0, 0.35), "flame_speed": Vector2(-0.22, 2.1), "noise_speed": Vector2(0.2, 1.3), "density": 1.2,
		"color_edge": Vector3(5.0, 1.4, 0.1), "color_mid": Vector3(7.0, 4.2, 0.5), "color_hot": Vector3(9.0, 8.0, 5.0), "color_core": Vector3(10.0, 10.0, 9.0),
	})
	_swirl = MeshInstance3D.new()
	_swirl.mesh = Lib.quad()
	_swirl.material_override = Lib.material("stamp", {"shape": Lib.tex("vfx_spiral07.jpg"), "cut": 0.22, "core_cut": 0.5})
	_swirl.rotation.x = -PI / 2.0
	_swirl.position.y = 0.03
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)
	_light = lamp(Color(1.0, 0.5, 0.15), 14.0 * size)
	_light.position.y = 1.5 * size
	for i in 6:
		var r: MeshInstance3D = Ribbon.new()
		r.material_override = Lib.material("stroke", {"width": randf_range(0.06, 0.12) * size, "color": Color(7.0, 3.5, 0.4, 1.0)})
		add_child(r)
		_streaks.append(r)
	_pose(0.0)


func _layer(flame: Texture2D, params: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var all := {"flame": flame, "noise_texture": Lib.tex("noise_wo14.png")}
	all.merge(params, true)
	mi.material_override = Lib.material("flow", all)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 2, 4))
	add_child(mi)
	return mi


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	var up := t - BUILD                      # 噴出からの秒数
	var out := t - BUILD - _hold             # 消えはじめからの秒数
	var rise := ease_out(clampf(up / RISE, 0.0, 1.0))
	var gone := clampf(out / END, 0.0, 1.0)
	# 柱：溜めの間は根元で小さく舐める。噴出で伸び、終わりは根元から食われて昇る
	var grow := 0.07 * smoothstep(0.0, BUILD, t) + 0.93 * rise if up < 0.0 or rise < 1.0 else 1.0
	var stretch := 1.0 + 0.3 * maxf(0.0, 1.0 - up / 0.3) if up > 0.0 else 1.0
	var radius := 1.15 * _size * (1.0 - 0.28 * maxf(0.0, 1.0 - up / 0.3) if up > 0.0 else 0.8) * (1.0 - 0.55 * gone)
	var height := 6.5 * _size * stretch
	for i in 2:
		var layer: MeshInstance3D = [_outer, _inner][i]
		var slim := 1.0 if i == 0 else 0.58
		layer.visible = gone < 1.0
		layer.scale = Vector3(radius * slim, height * (1.0 if i == 0 else 0.86), radius * slim)
		layer.position.y = gone * gone * 2.4 * _size
		param(layer, "phase", t)
		param(layer, "grow", grow)
		param(layer, "eaten", gone * gone * (3.0 - 2.0 * gone))
	# 地面の渦：広がる → 回り続ける → 縮みながら冷めて焦げ跡に → 中心へ消える
	var spread := ease_out(clampf(t / BUILD, 0.0, 1.0))
	var cold := smoothstep(0.0, 0.7, gone)
	_swirl.scale = Vector3.ONE * _size * lerpf(1.0, 5.2, spread) * (1.0 - 0.45 * gone)
	param(_swirl, "spin", -t * 5.0)
	param(_swirl, "color", Color(4.5, 1.1, 0.08, 1.0).lerp(Color(0.06, 0.04, 0.03, 1.0), cold))
	param(_swirl, "core_color", Color(8.0, 5.0, 1.0, 1.0).lerp(Color(0.1, 0.06, 0.04, 1.0), cold))
	param(_swirl, "hide", smoothstep(0.0, 0.85, clampf((out - END * 0.6) / 0.8, 0.0, 1.0)))
	_swirl.visible = out < END * 0.6 + 0.8
	_light.light_energy = 9.0 * _size * (0.25 * spread + 0.75 * rise) * (1.0 - gone) * (0.85 + 0.15 * sin(t * 40.0))
	# 噴出の瞬間に、煙玉が地面を外へ押される
	if up >= 0.0 and not _puffed:
		_puffed = true
		var skirt: Node3D = Puffs.new()
		add_child(skirt)
		skirt.start(SKIRT, _size, Color(1.0, 0.8, 0.62))
	# 火の筋：柱のまわりを螺旋で昇る。コマごとに位置を進める
	for i in _streaks.size():
		var points := PackedVector3Array()
		var cycle := fposmod((up + i * 0.31) / 0.8, 1.0)
		if up > 0.05 and gone < 0.4:
			for p in 8:
				var q := cycle - float(p) * 0.045
				if q < 0.0:
					continue
				var a := i * 1.05 + q * 5.0
				var r := (1.5 - 0.7 * q) * _size
				points.append(global_position + Vector3(cos(a) * r, (0.2 + q * 5.6) * _size, sin(a) * r))
		_streaks[i].draw(points)
