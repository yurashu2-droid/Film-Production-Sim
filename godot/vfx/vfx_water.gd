extends "res://vfx/vfx_base.gd"
# 水柱（水の竜）。地面の水たまりに波紋が広がり、水が渦を巻いて一本の柱に立ち上がる。
# 柱の周りを水しぶきが螺旋で昇り、頂点から水滴が放物線を描いてはじける。最後は柱が根元から崩れて水たまりへ戻る。
# 参考：『NARUTO』水遁・水龍弾（水が竜の形に伸びて回る）、『鬼滅の刃』水の呼吸（流れる水の弧で軌道を描く）。
#   溜め    水たまりの波紋が広がり、回りはじめる
#   噴出    柱が下から立ち上がる。出だしは細く伸び、すぐ太さが戻る。水滴が頂点から弾ける
#   継続    3層の殻（外＝濃い青 → 内＝白い水）が逆向きに流れ昇る。螺旋のしぶきも昇る
#   終わり  柱が根元から崩れて水たまりへ戻る。波紋は外側から段ごとに消える。水滴は地面へ落ちて消える
# 水は薄い殻を重ねて作る（wisp）。水滴は一粒ずつ振り付ける。15コマ/秒。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const FPS := 15.0
const BUILD := 0.35         # 溜めの秒数（波紋が広がる）
const RISE := 0.3           # 立ち上がりの秒数
const FALL := 0.55          # 崩れて戻る秒数
const GRAVITY := 7.0
const DROPS := 26
const TALL := 5.6           # 柱の高さ（m）
const SHAPE := [[0.0, 0.55], [0.2, 0.95], [0.55, 0.7], [0.85, 0.5], [1.0, 0.18]]

var _size := 1.0
var _hold := 2.0
var _frame := -1
var _layers: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _streaks: Array[MeshInstance3D] = []
var _drops: MultiMeshInstance3D
var _drop_data: Array = []     # [発射時刻, 発射位置, 初速]
var _light: OmniLight3D
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
	life = BUILD + RISE + seconds + FALL + 2.0
	if _mesh == null:
		_mesh = Lib.tube_mesh(SHAPE, 32, 28)
	# 外（濃い青・すき間多め・ゆっくり）→ 内（白い水・詰まって速い）。芯は細く残す
	var tones: Array = [
		[Vector3(0.04, 0.22, 0.9), Vector3(0.12, 0.55, 1.5)],
		[Vector3(0.18, 0.7, 2.0), Vector3(0.7, 2.2, 3.4)],
		[Vector3(0.9, 2.2, 3.0), Vector3(3.0, 4.4, 4.8)],
	]
	var extras: Array = [
		{"cut": 0.7, "top_thin": 0.35, "tip": 0.25, "sway": 0.2, "ripple": 0.12, "scale_a": Vector2(1.0, 0.35), "shear": 0.5},
		{"cut": 0.6, "top_thin": 0.3, "tip": 0.3, "sway": 0.14, "ripple": 0.1, "shear": -0.5},
		{"cut": 0.5, "top_thin": 0.3, "tip": 0.4, "sway": 0.1, "ripple": 0.08, "shear": 0.8},
	]
	for i in 3:
		var pair: Array = tones[i]
		var layer := Lib.wisp_layer(_mesh, i, 3, pair[0], pair[1], extras[i])
		add_child(layer)
		_layers.append(layer)
	# 水たまりの波紋：2本。逆向きに回り、段ごとに消える
	for i in 2:
		var ring := MeshInstance3D.new()
		ring.mesh = Lib.quad()
		ring.material_override = Lib.material("stamp", {
			"shape": Lib.tex("vfx_spiral07.jpg"), "cut": 0.3 + 0.1 * i, "core_cut": 0.7,
			"color": Color(0.5, 1.6, 3.0, 1.0), "core_color": Color(2.5, 4.0, 5.0, 1.0),
		})
		ring.rotation.x = -PI / 2.0
		ring.position.y = 0.03 + 0.01 * i
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	# 螺旋のしぶき：光らない白青の細い線が柱に巻きついて昇る
	for i in 5:
		var r: MeshInstance3D = Ribbon.new()
		r.material_override = Lib.material("stroke", {"width": randf_range(0.05, 0.09) * size, "color": Color(0.8, 1.9, 2.6, 1.0)})
		add_child(r)
		_streaks.append(r)
	# 水滴：一粒ずつ放物線で飛ばす（MultiMesh）
	var sphere := SphereMesh.new()
	sphere.radius = 0.09 * size
	sphere.height = 0.18 * size
	sphere.radial_segments = 10
	sphere.rings = 5
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.albedo_color = Color(0.6, 1.0, 1.0)
	sphere.material = drop_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = DROPS
	mm.mesh = sphere
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in DROPS:
		var a := randf() * TAU
		var dir := Vector3(cos(a), 0.0, sin(a))
		var launch := BUILD * 0.5 + RISE * 0.5 + randf() * (RISE + seconds)
		var start_pos := dir * 0.9 * size + Vector3(0, randf_range(0.6, 4.6) * size, 0)
		var vel := dir * randf_range(0.8, 2.2) * size + Vector3(0, randf_range(0.6, 3.2) * size, 0)
		_drop_data.append([launch, start_pos, vel])
	_light = lamp(Color(0.45, 0.85, 1.0), 11.0 * size)
	_light.position.y = 1.5 * size
	_pose(0.0)


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	var up := t - BUILD                          # 立ち上がりからの秒数
	var fall := t - BUILD - RISE - _hold         # 崩れはじめからの秒数
	var rise := ease_out(clampf(up / RISE, 0.0, 1.0))
	var gone := clampf(fall / FALL, 0.0, 1.0)
	var spread := ease_out(clampf(t / BUILD, 0.0, 1.0))
	# 柱：噴出の瞬間だけ少し伸びて戻る。崩れは根元から上へ戻っていく
	var stretch := 1.0 + 0.12 * maxf(0.0, 1.0 - up / 0.25)
	# 崩れるときは高さも縮めて、上の塊が宙に残らないように水たまりへ沈める
	var height := TALL * _size * rise * stretch * (1.0 - 0.8 * gone)
	var radius := _size * (0.75 + 0.25 * rise) * (1.0 - 0.2 * gone)
	for i in _layers.size():
		var layer := _layers[i]
		var slim: float = [1.0, 0.8, 0.6][i]
		layer.visible = rise > 0.0 and gone < 1.0
		layer.scale = Vector3(radius * slim, height * [1.0, 0.92, 0.85][i], radius * slim)
		param(layer, "phase", t)
		# 崩れは上から根元へ引き戻す（根元から食うと、上の塊が切り離されて宙に浮く）
		param(layer, "grow", rise * (1.0 - gone * gone * (3.0 - 2.0 * gone)))
		param(layer, "eaten", 0.0)
	# 波紋：広がる → 回り続ける → 段ごとに消える（縮めて消さない）
	for i in _rings.size():
		var ring := _rings[i]
		var grown := ease_out(clampf((t - 0.15 * i) / (BUILD + RISE), 0.0, 1.0))
		ring.scale = Vector3.ONE * _size * lerpf(0.5, 4.2 + 1.2 * i, grown)
		param(ring, "spin", -t * (4.0 - 2.0 * i))
		param(ring, "hide", smoothstep(0.0, 0.85, clampf((fall - FALL * 0.5 - 0.2 * i) / 0.8, 0.0, 1.0)))
		ring.visible = fall < FALL + 1.2 + 0.2 * i
	# 螺旋のしぶき：柱に巻きついて昇り、崩れはじめると止まる
	for i in _streaks.size():
		var points := PackedVector3Array()
		var cycle := fposmod((up + i * 0.23) / 0.9, 1.0)
		if up > 0.05 and gone < 0.3:
			for p in 9:
				var q := cycle - float(p) * 0.05
				if q < 0.0:
					continue
				var a := i * 1.2 + q * 6.0 + t * 0.5
				var r := (1.2 - 0.5 * q) * _size * (1.0 - 0.4 * gone)
				points.append(global_position + Vector3(cos(a) * r, (0.4 + q * 5.2) * _size, sin(a) * r))
		_streaks[i].draw(points)
	# 水滴：発射のあと放物線で飛び、地面より下へ落ちたら隠す
	var mm := _drops.multimesh
	for i in DROPS:
		var d: Array = _drop_data[i]
		var tau := t - float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0:
			var p: Vector3 = (d[1] as Vector3) + (d[2] as Vector3) * tau + Vector3(0.0, -0.5 * GRAVITY * _size * tau * tau, 0.0)
			if p.y > 0.0:
				xf = Transform3D(Basis.IDENTITY, p)
		mm.set_instance_transform(i, xf)
	_light.light_energy = 8.0 * _size * (0.3 * spread + 0.7 * rise) * (1.0 - gone) * (0.9 + 0.1 * sin(t * 30.0))
