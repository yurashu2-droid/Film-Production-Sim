extends "res://vfx/vfx_base.gd"
# 『呪術廻戦』風の呪力。15コマ/秒のコマ打ちで、当たりの瞬間は1コマ単位で絵を切り替える（インパクトフレーム）。
#   "black_flash"  黒閃：白い衝撃の絵 → 黒に赤ふちの絵に反転 → 黒い稲妻が四方へ走り、先端から引っ込んで消える
#   "blue"         蒼：流れる絵を貼った青い球が、線と小石を吸い寄せ続け、最後は一点に潰れて弾ける
#   "purple"       茈：赤と青の球が引き合ってぶつかり、紫の球になって撃ち出され、地面に溝を残す
# 球は「メッシュ＋流れる絵をくっきり切り抜く」作り方（flow シェーダー）。黒い稲妻は加算ではなく塗りなので、黒が沈まない。
# 素材：LeLu's Noise Pack（vfx_ex1d / vfx_hit22 / cracks336 / vfx_spiral07 / marblenoise_tiled）。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Lightning := preload("res://vfx/vfx_lightning.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const BlackFlash := preload("res://vfx/vfx_black_flash.gd")
const FPS := 15.0
# 球の色：[ふち, 中, 明, 芯]
const BLUE := [Vector3(0.02, 0.06, 0.5), Vector3(0.1, 0.55, 2.8), Vector3(0.7, 2.8, 7.5), Vector3(7, 9, 10)]
const RED := [Vector3(0.45, 0.01, 0.02), Vector3(2.6, 0.12, 0.08), Vector3(7.5, 1.2, 0.4), Vector3(10, 8, 7)]
const PURPLE := [Vector3(0.12, 0.0, 0.4), Vector3(1.3, 0.15, 3.6), Vector3(4.5, 1.3, 8.5), Vector3(9.5, 8, 10)]

var _kind := "black_flash"
var _size := 1.0
var _dir := Vector3.RIGHT
var _frame := -1
var _star: MeshInstance3D
var _orbs: Array[Node3D] = []
var _lines: Array[MeshInstance3D] = []
var _rocks: MultiMesh
var _swirls: Array[MeshInstance3D] = []
var _link: Array[MeshInstance3D] = []
var _trail: MeshInstance3D
var _history: Array = []
var _trench: MeshInstance3D
var _trench_hot: MeshInstance3D
var _light: OmniLight3D
var _puffed := 0


# pos は効果の中心（黒閃なら当たった場所、蒼・茈なら球の高さ）。ground_drop は中心から地面までの距離。
static func spawn(parent: Node, pos: Vector3, kind: String = "black_flash", size: float = 1.0, direction: Vector3 = Vector3.RIGHT) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(kind, size, direction)
	return fx


func start(kind: String, size: float, direction: Vector3) -> void:
	_kind = kind
	_size = size
	_dir = Vector3(direction.x, 0, direction.z).normalized()
	_star = _stamp("vfx_hit22.jpg", {"cut": 0.3, "core_cut": 0.7, "billboard": true, "toward_camera": size})
	_star.visible = false
	match kind:
		"blue":
			life = 3.3
			_light = lamp(Color(0.3, 0.6, 1.0), 12.0 * size)
			_orbs = [_orb(BLUE)]
			_build_pull(Color(1.3, 1.7, 2.2, 0.95), Color(0.1, 0.6, 2.6, 1.0), Color(0.8, 2.6, 6.0, 1.0))
		"purple":
			life = 3.5
			_light = lamp(Color(0.75, 0.4, 1.0), 12.0 * size)
			_orbs = [_orb(RED), _orb(BLUE), _orb(PURPLE)]
			for i in 3:
				_link.append(_glow_ribbon(0.1, Color(6, 3, 10)))
			_trail = _glow_ribbon(1.1, Color(4.5, 1.2, 9))
			param(_trail, "color_tail", Color(1.0, 0.1, 3.0))
			param(_trail, "taper", 0.9)
			param(_trail, "erosion", 1.0)
			_trench = _strip(Vector3(0.03, 0.02, 0.04), Vector3(0.1, 0.04, 0.16), 0.4)
			_trench_hot = _strip(Vector3(2.4, 0.4, 5.0), Vector3(7.0, 3.0, 10.0), 0.58)
		_:
			# 黒閃は別のファイルに作り直した。古い呼び方で来たら、そちらへ渡す
			BlackFlash.spawn(get_parent(), global_position, size, direction)
			queue_free()
			return
	_pose(0.0)


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	match _kind:
		"blue":
			_pose_blue(t)
		"purple":
			_pose_purple(t)


# ---- 蒼 ----

# 吸い寄せられる線・小石・地面の渦を作る
func _build_pull(line_color: Color, swirl_color: Color, swirl_core: Color) -> void:
	for i in 9:
		var r: MeshInstance3D = Ribbon.new()
		r.material_override = Lib.material("stroke", {"width": randf_range(0.05, 0.11) * _size, "color": line_color})
		add_child(r)
		_lines.append(r)
	var stone := Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "shadow_tint": Vector3(0.5, 0.5, 0.6)})
	stone.next_pass = Lib.material("cloud_ink", {"dissolve_texture": Lib.noise("cells"), "ink": Vector3(0.03, 0.03, 0.05), "thickness": 0.06})
	_rocks = MultiMesh.new()
	_rocks.transform_format = MultiMesh.TRANSFORM_3D
	_rocks.use_colors = true
	_rocks.mesh = Lib.cloud_mesh(2)
	_rocks.instance_count = 14
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _rocks
	holder.material_override = stone
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -8.0 * _size, Vector3.ONE * 16.0 * _size)
	add_child(holder)
	# 地面の渦：大きさ・向き・濃さの違う3枚を重ねて1つの模様にする
	for i in 3:
		var dim: float = [0.35, 0.7, 1.0][i]
		var swirl := _stamp("vfx_spiral07.jpg", {
			"cut": [0.16, 0.26, 0.4][i], "core_cut": [0.45, 0.55, 0.66][i],
			"color": Color(swirl_color.r * dim, swirl_color.g * dim, swirl_color.b * dim, 1.0),
			"core_color": Color(swirl_core.r * dim, swirl_core.g * dim, swirl_core.b * dim, 1.0),
		})
		swirl.rotation.x = -PI / 2.0
		_swirls.append(swirl)


func _pose_blue(t: float) -> void:
	var hold := 2.4
	var f := int(roundf(t * FPS))
	var born := ease_out(clampf(t / 0.35, 0.0, 1.0))
	var crush := clampf((t - hold) / 0.14, 0.0, 1.0)
	var live := t < hold + 0.14
	_set_orb(_orbs[0], Vector3.ZERO, (lerpf(0.15, 1.7, born) + 0.12 * maxf(0.0, 1.0 - t / 0.5)) * lerpf(1.0, 0.04, crush) * (1.0 + 0.03 * sin(t * 30.0)), t, live)
	_light.light_energy = 6.0 * _size * born * (1.0 if live else 0.0)
	var drop := minf(global_position.y, 3.0 * _size)
	# 吸い寄せられる線：外から球へ、渦を巻いて入る
	for i in _lines.size():
		var points := PackedVector3Array()
		var cycle := fposmod(t * 1.6 + i * 0.37, 1.0)
		if live and t > 0.1:
			var tilt := Vector3(sin(i * 2.1), cos(i * 1.3) * 0.7, cos(i * 2.1)).normalized()
			var side := tilt.cross(Vector3.UP).normalized()
			var up := side.cross(tilt)
			for p in 9:
				var q := clampf(cycle + p * 0.045, 0.0, 1.0)
				var radius := lerpf(5.0, 0.7, q * q) * _size * (1.0 - crush)
				var a := i * 0.9 + q * 4.2
				points.append(global_position + (side * cos(a) + up * sin(a)) * radius)
		_lines[i].draw(points)
	# 小石：地面から浮いて、回りながら球へ落ち込む。吸われたら次が浮く
	for i in _rocks.instance_count:
		var cycle := fposmod(t * 0.55 + i * 0.173, 1.0)
		var a := i * 2.4 + cycle * 5.0
		var radius := lerpf(4.2, 0.4, cycle * cycle)
		var y := lerpf(-drop / _size, 0.0, ease_out(cycle))
		var dia := (0.16 + 0.1 * fposmod(i * 0.37, 1.0)) * (1.0 - smoothstep(0.75, 1.0, cycle)) * (0.0001 if not live else 1.0)
		_rocks.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(t * 3.0 + i, i, t * 2.0)) * Basis.from_scale(Vector3.ONE * maxf(dia, 0.0001) * _size), Vector3(cos(a) * radius, y, sin(a) * radius) * _size))
		_rocks.set_instance_color(i, Color(0.16, 0.17, 0.22, 1))
	# 地面の渦：内向きに回り、最後は外から中心へ閉じる
	# 消えるときは縮めず、1枚ごとに別の消え方：大きい渦は腕が細って千切れ、中の渦はぐるっとぬぐわれ、小さい渦は球へ吸い込まれる
	for i in _swirls.size():
		var swirl := _swirls[i]
		var open := ease_out(clampf((t - i * 0.15) / 0.4, 0.0, 1.0))
		var shut := clampf((t - hold + 0.1 - [0.4, 0.2, 0.0][i]) / [0.6, 0.5, 0.25][i], 0.0, 1.0)
		swirl.visible = open > 0.0 and shut < 1.0
		swirl.position = Vector3(0, -drop + 0.03 + i * 0.012, 0)
		swirl.scale = Vector3.ONE * _size * [8.5, 6.2, 3.8][i] * lerpf(0.4, 1.0, open) * (1.0 - (0.85 * shut if i == 2 else 0.0))
		param(swirl, "spin", t * [2.0, 3.4, 5.5][i] + i + (shut * shut * 5.0 if i == 0 else 0.0))
		param(swirl, "cut", [0.16, 0.26, 0.4][i] + (shut * 0.75 if i == 0 else 0.0))
		param(swirl, "sweep", shut if i == 1 else 0.0)
		param(swirl, "sweep_from", t * 0.5)
	# 潰れた直後の1コマだけ、白い瞬き
	_star.visible = f == int(roundf((hold + 0.14) * FPS))
	_star.scale = Vector3.ONE * _size * 3.2
	param(_star, "color", Color(1.5, 5, 10, 1))
	param(_star, "core_color", Color(9, 10, 10, 1))


# ---- 茈 ----

func _pose_purple(t: float) -> void:
	var f := int(roundf(t * FPS))
	var meet := 1.0          # 赤と青がぶつかる時刻
	var fire := 1.47         # 撃ち出す時刻
	var flight := 0.5
	var side := _dir.cross(Vector3.UP)
	# 赤と青：別々に現れ、引き合ってぶつかる
	var pull := pow(clampf((t - 0.45) / (meet - 0.45), 0.0, 1.0), 2.2)
	var apart := lerpf(1.7, 0.0, pull) * _size
	for i in 2:
		var born := ease_out(clampf((t - i * 0.2) / 0.25, 0.0, 1.0))
		_set_orb(_orbs[i], side * apart * (1.0 if i == 0 else -1.0), 0.85 * born * (1.0 + 0.04 * sin(t * 40.0 + i)), t, t < meet and born > 0.0)
	for r in _link:
		r.draw(Lightning._bolt(global_position + side * apart, global_position - side * apart, 0.25, 3) if t > 0.4 and t < meet and apart > 0.3 * _size else PackedVector3Array())
	# ぶつかった1コマだけ、白い瞬き
	_star.visible = f == int(roundf(meet * FPS))
	_star.scale = Vector3.ONE * _size * 5.0
	param(_star, "color", Color(6, 3, 10, 1))
	param(_star, "core_color", Color(10, 10, 10, 1))
	# 紫：生まれて震え、撃ち出される。進むほど速くなり、最後は一点に縮む
	var grown := ease_out(clampf((t - meet) / 0.2, 0.0, 1.0))
	var go := clampf((t - fire) / flight, 0.0, 1.0)
	var reach := 16.0 * _size * go * go
	var done := t >= fire + flight
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.07 * _size if t >= meet and t < fire else Vector3.ZERO
	var at_orb := _dir * reach + shake
	var orb: Node3D = _orbs[2]
	_set_orb(orb, at_orb, 1.9 * grown * (1.0 - smoothstep(0.85, 1.0, go)), t, t >= meet and not done)
	if go > 0.0 and not done:
		orb.basis = Basis.looking_at(_dir, Vector3.UP) * Basis.from_scale(orb.scale * Vector3(1, 1, 1.0 + go * 0.9))
	_light.position = at_orb
	_light.light_energy = 7.0 * _size * (grown if not done else 0.0)
	# 軌跡
	if go > 0.0 and not done:
		_history.push_front([global_position + at_orb, t])
	while not _history.is_empty() and t - _history[-1][1] > 0.22:
		_history.pop_back()
	var path := PackedVector3Array()
	for h: Array in _history:
		path.append(h[0])
	_trail.draw(path)
	# 地面の溝：球が通った所まで伸び、熱い紫が冷めて細り、黒い跡も最後に閉じる
	var drop := minf(global_position.y, 3.0 * _size)
	var cool := smoothstep(fire + flight, fire + flight + 0.6, t)
	var close := smoothstep(2.7, 3.4, t)
	for i in 2:
		var strip: MeshInstance3D = [_trench, _trench_hot][i]
		strip.visible = go > 0.0 and close < 1.0 and (i == 0 or cool < 1.0)
		var wide := (3.0 if i == 0 else 2.0 * (1.0 - cool)) * (1.0 - close) * _size
		strip.position = _dir * reach * 0.5 + Vector3(0, -drop + 0.03 + i * 0.01, 0)
		strip.basis = Basis.looking_at(_dir, Vector3.UP) * Basis.from_scale(Vector3(maxf(wide, 0.001), 1.0, maxf(reach, 0.001)))
	# 通った所の両脇へ、煙玉が押し出される
	while _puffed < 5 and go > 0.0 and reach > (_puffed + 0.5) * 3.0 * _size:
		var smoke: Node3D = Puffs.new()
		add_child(smoke)
		smoke.position = _dir * (_puffed + 0.5) * 3.0 * _size + Vector3(0, -drop, 0)
		smoke.start([[0.0, side + Vector3(0, 0.15, 0), 1.6, 1.0, 0.7], [0.0, -side + Vector3(0, 0.15, 0), 1.6, 0.95, 0.75]], _size, Color(0.85, 0.8, 1.0))
		_puffed += 1


# ---- 部品 ----

# 暗い芯のまわりに、すき間だらけの殻を4層重ねた球。外は暗く遅く、内は明るく速く、1層おきに逆回り
func _orb(colors: Array) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var core := MeshInstance3D.new()
	core.mesh = ball
	core.material_override = Lib.material("spark", {"tint": colors[3]})
	core.scale = Vector3.ONE * 0.46
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var tones: Array = [colors[0], colors[1], ((colors[1] as Vector3) + (colors[2] as Vector3)) * 0.5, colors[2], colors[3]]
	var skins: Array = []
	for i in 4:
		var turn := 1.0 if i % 2 == 0 else -1.0
		var skin := Lib.wisp_layer(ball, i, 4, tones[i], tones[i + 1], {
			"sway": 0.0, "ripple": 0.03, "top_thin": 0.0, "tip": 0.0, "shear": 0.9 * turn, "scale_a": Vector2(1.0, 0.7),
			"speed_a": Vector2(turn * lerpf(0.35, 1.3, i / 3.0), 0.12), "speed_b": Vector2(-turn * 0.3, 0.2),
			"cut": lerpf(0.64, 0.54, i / 3.0),
		})
		skin.scale = Vector3.ONE * [1.0, 0.86, 0.72, 0.6][i]
		root.add_child(skin)
		skins.append(skin)
	root.set_meta("skins", skins)
	return root


func _set_orb(orb: Node3D, at_local: Vector3, dia: float, t: float, shown: bool) -> void:
	orb.visible = shown and dia > 0.01
	orb.position = at_local
	orb.basis = Basis.from_scale(Vector3.ONE * maxf(dia, 0.001) * _size)
	for skin: MeshInstance3D in orb.get_meta("skins"):
		param(skin, "phase", t)


func _stamp(file_name: String, params: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	var all := {"shape": Lib.tex(file_name)}
	all.merge(params, true)
	mi.material_override = Lib.material("stamp", all)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _glow_ribbon(width: float, color: Color) -> MeshInstance3D:
	var r: MeshInstance3D = Ribbon.new()
	r.material_override = Lib.material("ribbon", {
		"noise_texture": Lib.noise("soft"), "width": width * _size, "color_head": color, "color_tail": color,
		"core_color": Vector3(10, 9, 10), "core": 0.3, "taper": 0.5, "erosion": 0.0,
	})
	add_child(r)
	return r


# 地面に寝かせた細長い焦げ跡。すき間のある模様で塗るので、ただの長方形に見えない
func _strip(tone: Vector3, tone_inner: Vector3, cut_at: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var mi := Lib.wisp_layer(plane, 0, 2, tone, tone_inner, {
		"sway": 0.0, "ripple": 0.0, "top_thin": 0.0, "tip": 0.0, "shear": 0.0, "scale_a": Vector2(0.6, 3.0), "scale_b": Vector2(1.0, 5.0),
		"speed_a": Vector2.ZERO, "speed_b": Vector2.ZERO, "cut": cut_at, "inner": 0.16, "side_ragged": 0.75,
	})
	mi.visible = false
	add_child(mi)
	return mi
