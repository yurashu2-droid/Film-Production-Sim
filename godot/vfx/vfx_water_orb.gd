extends "res://vfx/vfx_base.gd"
# 水玉の魔法陣（例1）。陣が地面に開き、泡が一粒ずつ浮かび上がって陣の周りを回る。
# 泡は一本の水の糸でつながってから玉へ吸い込まれ、玉は集まった数に比例して大きくなる。
# 玉は三層の殻（外 1.0 / 中 0.65 / 芯 0.3）。すき間から奥の層が見える。
#   素材：水（薄い殻を層にして重ねる。固体の球は使わない）
#   どこから来る：地面の陣の周りに、泡が一粒ずつ生まれる
#   先に動く部分：玉の外の層（はじける時に外から広がる）
#   遅れて追う部分：泡と糸（一粒ずつ遅れて玉へ入る）／芯（はじけた後で上へ抜ける）
#   形の変化：
#     0.3〜2.2秒  泡が一粒ずつ生まれ、陣の周りを回る
#     2.6〜4.4秒  泡が糸でつながり、玉へ吸い込まれる。入ってくる側が膨らむ
#     4.4〜5.0秒  玉が落ち着いて横に広く・縦に低くなり、はじける直前に縦へ伸びる
#   終わり：外の層は cut を上げながら広がって薄れる（5.0〜5.8秒）。
#           中の層は外より遅れて薄れる（5.1〜6.0秒）。芯は上へ抜けて消える（5.25〜6.25秒）。
#           水滴は地面へ落ちて消える。寿命は 7.2 秒。
#   0〜0.9秒    陣が中心から開く。二重の輪がゆっくり逆向きに回る
# 水は固体の球を使わず、「すき間だらけの薄い殻」を層にして作る（wisp）。外は濃い青、内は白い水。
# 全体の大きさは SCALE 倍（玉の半径 約1.36m、泡の直径 約0.55m）。

const SCALE := 1.6          # 全体の大きさ（陣・玉・泡・水滴の飛び方に掛ける）
const BUBBLES := 9
const BIRTH_FIRST := 0.3
const BIRTH_LAST := 2.2
const MERGE := 2.6          # 最初の泡が糸でつながり始める時刻
const GATHER_STEP := 0.07   # 泡が一粒ずつ集まり始める間隔
const LINK := 0.25          # 糸がつながるまで
const ABSORB := 1.0         # 糸が縮みながら玉へ吸い込まれるまで
const BURST := 5.0          # はじける時刻
const LIFE := BURST + 2.2
const BALL_R := 0.85        # 玉の半径（大きさ 1.0 のとき。SCALE を掛けて使う）
const BULGE := 0.16         # 入ってくる泡の側へふくらむ量（玉の半径に対する割合）
const DROPS := 36
const GRAVITY := 7.0
const CENTER_Y := 1.5
const THREAD_DARK := Vector3(0.12, 0.55, 1.5)
const THREAD_LIGHT := Vector3(3.0, 4.4, 4.8)
# 玉の殻：外 → 内の順。
# [濃い色, 内の色, cut（大きいほどすき間が多い）, 回る速さ, inner（大きいほど白い所が減る）,
#  半径（玉に対する割合）, はじけの遅れ(秒), はじけの長さ(秒), 広がり, 上へ抜ける量, 泡の側へふくらむ割合]
const BALL_SHELLS := [
	[Vector3(0.02, 0.1, 0.5), Vector3(0.08, 0.35, 1.1), 0.72, 0.6, 0.5, 1.0, 0.0, 0.8, 0.7, 0.0, 1.0],
	[Vector3(0.2, 0.8, 2.0), Vector3(0.9, 2.6, 3.8), 0.6, -0.9, 0.3, 0.65, 0.1, 0.9, 0.5, 0.0, 0.5],
	[Vector3(0.9, 2.2, 3.0), Vector3(3.0, 4.4, 4.8), 0.5, 1.4, 0.1, 0.3, 0.25, 1.0, 0.4, 1.4, 0.0],
]
# 泡の殻（一層）：[濃い色, 内の色, cut, inner]
const BUBBLE_SHELL := [Vector3(0.05, 0.3, 1.0), Vector3(0.4, 1.4, 2.8), 0.55, 0.4]

var _size := 1.0
var _bubbles: Array = []       # [泡の親ノード, 誕生, 角度, 大きさ, 糸がつながり始める時刻, 糸の MeshInstance3D]
var _ball: Node3D
var _ball_layers: Array = []   # [殻, 回る速さ, 半径, はじけの遅れ, はじけの長さ, 広がり, 上へ抜ける量, 泡側へふくらむ割合, 基本の cut]
var _flow: Array[MeshInstance3D] = []   # 模様を流す殻すべて
var _thread_mat: ShaderMaterial
var _drop_mat: ShaderMaterial
var _circle: MeshInstance3D
var _ring: MeshInstance3D
var _splash: MeshInstance3D
var _flash: MeshInstance3D
var _drops: MultiMeshInstance3D
var _drop_data: Array = []     # [発射の遅れ, 発射位置, 初速]
var _light: OmniLight3D
var _streak: MeshInstance3D    # 芯：はじけた後、中心から上へ細く抜ける光の筋（球のまま抜けると白い球に見えたため）
static var _shell_mesh: SphereMesh


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size * SCALE
	life = LIFE
	if _shell_mesh == null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 1.0
		_shell_mesh.height = 2.0
		_shell_mesh.radial_segments = 32
		_shell_mesh.rings = 16
	_circle = _disc("vfx_spiral07.jpg", 0.25, Color(0.4, 1.5, 3.0, 1.0), Color(2.5, 4.0, 5.0, 1.0))
	_ring = _disc("vfx_ex1d.jpg", 0.4, Color(0.5, 1.3, 2.6, 1.0), Color(2.0, 3.0, 4.0, 1.0))
	_splash = _disc("vfx_ex1d.jpg", 0.35, Color(0.6, 1.5, 2.8, 1.0), Color(2.4, 3.6, 4.6, 1.0))
	# 糸：泡から玉へ伸びる細い水。泡と同じ殻を、一本の筒に沿わせて作る
	_thread_mat = Lib.material("wisp", {
		"mask_a": Lib.tex("noise_wo14.png"), "mask_b": Lib.noise("soft"), "seed": 0.2,
		"cut": 0.42, "inner": 0.3, "color": THREAD_DARK, "color_inner": THREAD_LIGHT,
		"tip": 0.0, "top_thin": 0.0, "sway": 0.0, "ripple": 0.02,
	})
	# 玉：殻を三層。半径・速さ・はじける時刻を層ごとに変える
	_ball = Node3D.new()
	add_child(_ball)
	for i in BALL_SHELLS.size():
		var s: Array = BALL_SHELLS[i]
		var layer := _shell(i, BALL_SHELLS.size(), s[0], s[1], s[2], s[4])
		_ball.add_child(layer)
		_flow.append(layer)
		_ball_layers.append([layer, s[3], s[5], s[6], s[7], s[8], s[9], s[10], s[2]])
		# 外と中は模様を細い斜めの筋にする（大きい地図の模様に見えないように）
		if i < 2:
			param(layer, "scale_a", Vector2(3.0, 0.6))
			param(layer, "shear", 1.0)
	_ball.visible = false
	# 泡：一層ずつ。生まれて陣を回り、糸でつながってから玉へ入る
	for i in BUBBLES:
		var mi := Node3D.new()
		mi.visible = false
		add_child(mi)
		var layer := _shell(0, 1, BUBBLE_SHELL[0], BUBBLE_SHELL[1], BUBBLE_SHELL[2], BUBBLE_SHELL[3])
		mi.add_child(layer)
		_flow.append(layer)
		var thread := MeshInstance3D.new()
		thread.material_override = _thread_mat
		thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		thread.visible = false
		add_child(thread)
		_bubbles.append([
			mi,
			lerpf(BIRTH_FIRST, BIRTH_LAST, float(i) / (BUBBLES - 1)) + randf_range(-0.04, 0.04),
			TAU * float(i) / BUBBLES + randf() * 0.4,
			randf_range(0.2, 0.22) * _size,
			MERGE + GATHER_STEP * float(i),
			thread,
		])
	# 水滴：小さな殻。直径 0.12m 以下の粒を一粒ずつ放物線で飛ばす
	_drop_mat = Lib.material("wisp", {
		"mask_a": Lib.tex("noise_wo14.png"), "mask_b": Lib.noise("soft"), "seed": 0.5,
		"cut": 0.5, "color": Vector3(0.12, 0.55, 1.5), "color_inner": Vector3(1.0, 1.5, 1.9),
		"tip": 0.0, "top_thin": 0.0, "sway": 0.0, "ripple": 0.02,
	})
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.055    # 直径 0.11m
	drop_mesh.height = 0.11
	drop_mesh.radial_segments = 12
	drop_mesh.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = DROPS
	mm.mesh = drop_mesh
	_drops = MultiMeshInstance3D.new()
	_drops.multimesh = mm
	_drops.material_override = _drop_mat
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in DROPS:
		var a := randf() * TAU
		var dir := Vector3(cos(a), 0.0, sin(a))
		var start_pos := Vector3(0.0, CENTER_Y * _size + 0.15 * _size, 0.0) + dir * BALL_R * _size * 0.8
		var vel := dir * randf_range(1.2, 3.2) * _size + Vector3(0.0, randf_range(2.0, 4.6) * _size, 0.0)
		_drop_data.append([randf() * 0.06, start_pos, vel])
	_flash = sprite(2, Color(3.0, 3.6, 4.2, 1.0), 2.6 * _size)
	_flash.position = Vector3(0.0, CENTER_Y * _size, 0.0)
	_flash.visible = false
	_light = lamp(Color(0.55, 0.9, 1.0), 10.0 * _size)
	_light.position.y = CENTER_Y * _size
	_streak = Lib.wisp_layer(ArrayMesh.new(), 2, BALL_SHELLS.size(), BALL_SHELLS[2][0], BALL_SHELLS[2][1], {
		"tip": 0.0, "top_thin": 0.3, "sway": 0.0, "ripple": 0.02, "cut": 0.5, "inner": 0.1, "seed": 0.9,
	})
	_streak.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	_streak.visible = false
	add_child(_streak)
	_pose(0.0)


# 薄い殻を一層（wisp）。球の上に、すき間だらけの模様が流れる
func _shell(i: int, count: int, dark: Vector3, light: Vector3, cut: float, inner: float) -> MeshInstance3D:
	return Lib.wisp_layer(_shell_mesh, i, count, dark, light, {
		"tip": 0.0, "top_thin": 0.15, "sway": 0.0, "ripple": 0.04,
		"cut": cut, "inner": inner, "seed": 0.37 * i + randf() * 3.0,
	})


# 円盤（地面に寝かせた絵）。reveal で中心から開き、hide で外から消える
func _disc(file: String, cut: float, color: Color, core: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	mi.material_override = Lib.material("stamp", {
		"shape": Lib.tex(file), "cut": cut, "core_cut": 0.7,
		"color": color, "core_color": core, "reveal": 1.0,
	})
	mi.rotation.x = -PI / 2.0
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _tick(_delta: float) -> void:
	_pose(age)


# 泡が玉へ吸い込まれる進み具合（0〜1）。糸がつながってから吸い込み始める
func _absorbed(gather: float, t: float) -> float:
	return smoothstep(gather + LINK, gather + LINK + ABSORB, t)


func _pose(t: float) -> void:
	# 模様の流れ：全部の殻を同じ時刻で流す
	for layer: MeshInstance3D in _flow:
		param(layer, "phase", t)
	_drop_mat.set_shader_parameter("phase", t)
	_thread_mat.set_shader_parameter("phase", t)
	# 陣と波紋
	var open := ease_out(clampf(t / 0.9, 0.0, 1.0))
	_circle.visible = t < BURST + 0.4
	_circle.scale = Vector3.ONE * _size * lerpf(0.4, 3.0, open)
	param(_circle, "reveal", open)
	param(_circle, "spin", -t * 0.6)
	param(_circle, "sweep", clampf((t - BURST) / 0.4, 0.0, 1.0))
	_ring.scale = Vector3.ONE * _size * lerpf(0.5, 2.2, ease_out(clampf((t - 0.2) / 1.0, 0.0, 1.0)))
	param(_ring, "spin", t * 1.1)
	param(_ring, "sweep_from", 0.5)
	param(_ring, "sweep", smoothstep(BURST - 0.5, BURST + 0.1, t))
	var since := t - BURST
	_splash.visible = since >= 0.0 and since < 1.4
	_splash.scale = Vector3.ONE * _size * lerpf(0.4, 2.6, ease_out(clampf(since / 0.35, 0.0, 1.0)))
	param(_splash, "reveal", ease_out(clampf(since / 0.3, 0.0, 1.0)))
	param(_splash, "sweep_from", 0.25)
	param(_splash, "cut", lerpf(0.35, 1.0, smoothstep(0.4, 1.1, since)))
	param(_splash, "sweep", smoothstep(0.6, 1.3, since))
	# 玉に入った量（0〜1）。泡の数ではなく、吸い込まれた分の合計で決める
	var frac := 0.0
	for b: Array in _bubbles:
		frac += _absorbed(float(b[4]), t)
	frac /= BUBBLES
	var lift := smoothstep(MERGE, BURST, t)
	var bob := sin(t * 1.4) * 0.06 * _size
	var center := Vector3(0.0, CENTER_Y * _size + 0.15 * _size * lift + bob, 0.0)
	var ball_r := BALL_R * _size * pow(frac, 0.4)
	# 泡：生まれて回り、糸でつながってから玉へ吸い込まれる。入ってくる側を膨らませる向きを集める
	var pull := Vector3.ZERO
	var pull_w := 0.0
	for i in _bubbles.size():
		var b: Array = _bubbles[i]
		var mi: Node3D = b[0]
		var thread: MeshInstance3D = b[5]
		var born := t - float(b[1])
		var gather: float = b[4]
		var k := _absorbed(gather, t)
		var link := smoothstep(gather, gather + LINK, t)
		mi.visible = born >= 0.0 and k < 1.0
		thread.visible = false
		if not mi.visible:
			continue
		var ang: float = float(b[2]) + t * 0.9
		var r := lerpf(1.5, 1.0, clampf(born / 2.0, 0.0, 1.0)) * _size
		var y := lerpf(0.25, 1.5, clampf(born / 1.4, 0.0, 1.0)) * _size + sin(t * 2.0 + float(b[2])) * 0.05 * _size
		var orbit := Vector3(cos(ang) * r, y, sin(ang) * r)
		mi.position = orbit.lerp(center, k)
		mi.scale = Vector3.ONE * float(b[3]) * ease_out(clampf(born / 0.14, 0.0, 1.0)) * (1.0 - 0.35 * k)
		var from_center := mi.position - center
		var w := 4.0 * k * (1.0 - k)     # 吸い込まれている最中の泡ほど、その側がふくらむ
		if from_center.length() > 0.01:
			pull += from_center.normalized() * w
			pull_w += w
		# 糸：泡から玉の表面へ。つながった後、泡と一緒に縮んで消える
		if t >= gather and link > 0.02 and from_center.length() > 0.05:
			var dir := from_center.normalized()
			var attach := center + dir * maxf(ball_r * 0.9, 0.05 * _size)
			var mid := (attach + mi.position) * 0.5 + Vector3.UP * 0.12 * _size * sin(t * 5.0 + float(i))
			var pts := Lib.smooth_path(PackedVector3Array([attach, mid, mi.position]), 5)
			thread.mesh = Lib.path_tube(pts, 0.035 * _size * link, 0.5, 8)
			thread.visible = true
	var bulge: Vector3 = pull.limit_length(1.0) if pull_w > 0.0 else Vector3.ZERO
	# 玉の形：集まる間は少し膨らみ、落ち着くと横に広く縦に低く、はじける直前に縦へ伸びる。はじけたら形の補正を外す
	var live := 1.0 - smoothstep(BURST, BURST + 0.05, t)
	var heavy := smoothstep(4.4, 4.8, t) * live
	var pre := smoothstep(BURST - 0.4, BURST, t) * live
	var wide := 1.0 + 0.03 * heavy - 0.08 * pre
	var tall := 1.0 - 0.06 * heavy + 0.25 * pre
	_ball.visible = frac > 0.0 and t < BURST + 1.3
	_ball.position = center
	_ball.scale = Vector3(ball_r * wide, ball_r * tall, ball_r * wide)
	# 三層：外から先にほどけて広がり、芯は遅れて上へ抜ける。cut を上げて、すき間から消えていく
	for pair: Array in _ball_layers:
		var layer: MeshInstance3D = pair[0]
		var base_r: float = pair[2]
		var delay: float = pair[3]
		var dur: float = pair[4]
		var spread: float = pair[5]
		var rise: float = pair[6]
		if rise > 0.0:
			# 芯は球で描かず、下の _streak で光の筋として抜けさせる
			layer.visible = false
			continue
		var bulge_w: float = pair[7]
		var cut: float = pair[8]
		var u := clampf((t - BURST - delay) / dur, 0.0, 1.0)
		var eo := ease_out(u)
		# ほどけ：cut を 0.4 秒で 1.0 まで上げ切って消す。芯は上へ抜けてから消えるので、その分遅らせる
		var fade_start := delay + (0.5 if rise > 0.0 else 0.0)
		var uc := clampf((t - BURST - fade_start) / 0.4, 0.0, 1.0)
		layer.visible = uc < 1.0
		layer.rotation.y = t * float(pair[1])
		layer.rotation.x = sin(t * 0.5 + float(pair[1])) * 0.25
		layer.scale = Vector3.ONE * base_r * (1.0 + spread * eo)
		layer.position = bulge * BULGE * bulge_w + Vector3(0.0, rise * eo, 0.0)
		param(layer, "cut", cut + (1.0 - cut) * uc)
	# 芯：中心から上へ細く伸び、先の抜けに合わせて根元から消える（eaten は根元から削る）
	var streak_t := t - BURST - 0.25
	_streak.visible = streak_t >= 0.0 and streak_t < 1.6
	if _streak.visible:
		var up := smoothstep(0.0, 1.0, streak_t) * 2.4 * _size
		var spine := PackedVector3Array()
		for k in 6:
			var s := float(k) / 5.0
			spine.append(center + Vector3(sin(t * 3.0 + s * 2.0) * 0.04 * _size * s, s * up, 0.0))
		_streak.mesh = Lib.path_tube(spine, 0.09 * _size * (1.0 - 0.4 * clampf(streak_t, 0.0, 1.0)), 0.6, 10)
		param(_streak, "phase", t)
		param(_streak, "eaten", smoothstep(0.4, 1.6, streak_t))
	# 閃光と水滴
	_flash.visible = t >= BURST and t < BURST + 0.14
	_flash.position = center
	_light.position = center
	_light.light_energy = 2.5 * _size * frac * (1.0 - clampf(since / 1.0, 0.0, 1.0)) + (12.0 * _size if _flash.visible else 0.0)
	var mm := _drops.multimesh
	for i in DROPS:
		var d: Array = _drop_data[i]
		var tau := since - float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0:
			var p: Vector3 = (d[1] as Vector3) + (d[2] as Vector3) * tau + Vector3(0.0, -0.5 * GRAVITY * _size * tau * tau, 0.0)
			if p.y > 0.0:
				xf = Transform3D(Basis.IDENTITY, p)
		mm.set_instance_transform(i, xf)
