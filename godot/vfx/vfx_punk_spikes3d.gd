extends "res://vfx/vfx_base.gd"
# 棘の地走り（3D 版）。見た目は 2D のペン画、物は 3D。奥行きのある弧に沿って、本物の円錐の棘が生える。
# 素材：        骨の棘（円錐）、赤い布（3D 空間をうねる帯）、薄紫の稲妻（角ばった立体の棒）、破片（箱）
# どこから来る： 左手前の地面。弧を描いて奥へ、また手前へ走る
# 先に動く部分： 棘（一本ずつ、小さい → 行き過ぎ → 落ち着く）と、赤い布の頭
# 遅れて追う部分：布の尾、棘が生える時に跳ねる破片、最後の大棘に落ちる稲妻、王冠の落書き
# 終わり（素材ごとに別）：
#   棘    手前から順に外へ倒れ、倒れた後に網点が小さくなってはがれる（トーンの消え方）
#   布    頭が棘の列を抜けて、上へ飛び去る（戻らない）
#   稲妻  上（供給元）から消える
#   破片  地面に落ちて止まり、網点になって消える
# 塗りは punk3d（べた・網点・墨）、輪郭は punk3d_ink。12 コマ/秒。

const FPS := 12.0
const BONE := Vector3(0.91, 0.86, 0.85)
const INK := Vector3(0.03, 0.03, 0.035)
const RED := Vector3(0.55, 0.015, 0.045)
const LILAC := Vector3(0.62, 0.6, 0.86)
const COUNT := 10
const FALL := 2.5            # 棘が倒れはじめる時刻

var _size := 1.0
var _frame := -1
var _mats: Array = []        # 線の震えを進める材質（輪郭）
var _spikes: Array = []      # [軸, 材質, 生える時刻, 倒れる向き]
var _chips: MultiMeshInstance3D
var _chip_data: Array = []   # [出る時刻, 位置, 初速, 回る速さ]
var _chip_mat: ShaderMaterial
var _rag: MeshInstance3D
var _bolt: MeshInstance3D
var _bolt_top := Vector3.ZERO
var _bolt_tip := Vector3.ZERO
var _crown: MeshInstance3D
static var _cone: CylinderMesh


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 4.1
	if _cone == null:
		_cone = CylinderMesh.new()
		_cone.height = 1.0
		_cone.top_radius = 0.0
		_cone.bottom_radius = 0.5
		_cone.radial_segments = 5
		_cone.rings = 1
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.22, 0.26)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = COUNT * 2
	mm.mesh = box
	_chip_mat = _paint(BONE)
	_chips = MultiMeshInstance3D.new()
	_chips.multimesh = mm
	_chips.material_override = _chip_mat
	_chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chips)
	for i in COUNT:
		var base := _line(float(i) / (COUNT - 1))
		var last := i == COUNT - 1
		var h := (4.2 if last else 1.5 + 0.2 * i + randf_range(-0.25, 0.35)) * size
		var pivot := Node3D.new()
		pivot.position = base
		pivot.rotation = Vector3(-0.12, randf() * TAU, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = _cone
		mi.position.y = h * 0.5
		mi.scale = Vector3(h * (0.26 if last else 0.2), h, h * (0.26 if last else 0.2))
		mi.rotation.z = 0.0 if last else (0.3 if i % 2 == 0 else -0.3)
		var mat := _paint(BONE)
		mat.set_shader_parameter("stripes", 1.0 if last else 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		pivot.visible = false
		add_child(pivot)
		_spikes.append([pivot, mat, 0.15 * i, 1.0 if i % 2 == 0 else -1.0])
		for k in 2:
			var a := randf() * TAU
			_chip_data.append([0.15 * i, base + Vector3(0.0, 0.2, 0.0), Vector3(cos(a) * randf_range(1.0, 2.6), randf_range(3.0, 5.5), sin(a) * randf_range(1.0, 2.6)) * size, randf_range(4.0, 9.0)])
	_rag = _shape(RED)
	_bolt = _shape(LILAC)
	_bolt_tip = _line(1.0) + Vector3(0.0, 4.2 * size, 0.0)
	_bolt_top = _bolt_tip + Vector3(-1.6, 3.4, 0.3) * size
	_crown = MeshInstance3D.new()
	_crown.mesh = Lib.quad()
	_crown.material_override = Lib.material("punk", {"mode": 4, "fill": RED, "ink": INK, "grow": 0.0, "seed": 2.0})
	_crown.position = _bolt_tip + Vector3(1.3, 0.2, 0.0) * size
	_crown.scale = Vector3.ONE * 2.2 * size
	_crown.visible = false
	add_child(_crown)
	_pose(0.0)


# 棘の列が通る線。u は 0（左手前）〜 1（右）。弧を描いて奥へ行き、手前へ戻る
func _line(u: float) -> Vector3:
	return Vector3(-4.2 + 8.4 * u, 0.0, 1.2 - 3.4 * sin(u * PI)) * _size


# べた・網点・墨の塗り ＋ 震える輪郭
func _paint(color: Vector3) -> ShaderMaterial:
	var mat := Lib.material("punk3d", {"fill": color, "ink": INK})
	var line := Lib.material("punk3d_ink", {"ink": INK})
	mat.next_pass = line
	_mats.append(line)
	return mat


func _shape(color: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = _paint(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -20.0, Vector3.ONE * 40.0)
	add_child(mi)
	return mi


static func _wear(mat: ShaderMaterial, value: float) -> void:
	mat.set_shader_parameter("wear", value)
	(mat.next_pass as ShaderMaterial).set_shader_parameter("wear", value)


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	for line: ShaderMaterial in _mats:
		line.set_shader_parameter("phase", t)
	# 棘：生えて、倒れて、網点になってはがれる
	for i in COUNT:
		var s: Array = _spikes[i]
		var pivot: Node3D = s[0]
		var since := t - float(s[2])
		pivot.visible = since >= 0.0
		pivot.scale = Vector3.ONE * [0.35, 1.2, 1.0][clampi(int(since * FPS), 0, 2)]
		var falling := t - (FALL + 0.08 * i)
		var tip: float = [0.0, 0.5, 1.2, 1.45][clampi(int(falling * FPS) + 1, 0, 3)] if falling >= 0.0 else 0.0
		pivot.rotation.x = -0.12 + tip * float(s[3])
		_wear(s[1], clampf((falling - 0.35) / 0.5, 0.0, 1.0))
	# 破片：跳ねて、落ちて、止まり、網点になって消える
	var mm := _chips.multimesh
	for i in _chip_data.size():
		var d: Array = _chip_data[i]
		var tau := t - float(d[0])
		var xf := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if tau >= 0.0:
			var p: Vector3 = (d[1] as Vector3) + (d[2] as Vector3) * tau + Vector3(0.0, -7.0 * _size * tau * tau, 0.0)
			var spin := tau * float(d[3])
			if p.y < 0.12 * _size:
				var land := ((d[2] as Vector3).y + sqrt(pow((d[2] as Vector3).y, 2.0) + 28.0 * _size * 0.08)) / (14.0 * _size)
				p = (d[1] as Vector3) + (d[2] as Vector3) * land
				p.y = 0.12 * _size
				spin = land * float(d[3])
			xf = Transform3D(Basis.from_euler(Vector3(spin, spin * 0.7, i)) * Basis.from_scale(Vector3.ONE * _size), p)
		mm.set_instance_transform(i, xf)
	_wear(_chip_mat, smoothstep(3.0, 3.6, t))
	# 赤い布：棘の列をうねって抜け、上へ飛び去る
	var head := (t - 0.2) / 1.5 * 1.15
	var pts := PackedVector3Array()
	var prof := PackedFloat32Array()
	for k in 24:
		var u := head - k * 0.03
		if u < 0.0:
			break
		var p := _line(minf(u, 1.0)) + Vector3(0.0, 1.3 + 0.8 * sin(u * 11.0), 0.9 * cos(u * 13.0)) * _size
		if u > 1.0:
			p += Vector3(2.0, 9.0, -1.5) * (u - 1.0) * (u - 1.0) * 6.0 * _size
		pts.append(p)
		prof.append(0.2 + 0.8 * sin(PI * minf(float(k) / 23.0 + 0.08, 1.0)))
	_rag.visible = pts.size() >= 3 and pts[pts.size() - 1].y < 14.0 * _size
	if _rag.visible:
		_rag.mesh = Lib.path_tube(pts, 0.42 * _size, 0.0, 2, prof)
	# 稲妻：最後の大棘へ落ち、3回描き直され、上から消える
	var strike := t - 1.55
	_bolt.visible = strike >= 0.0 and strike < 0.85
	if _bolt.visible:
		var seed := mini(int(strike * FPS), 3)
		var all := PackedVector3Array()
		for k in 9:
			var u := float(k) / 8.0
			var p := _bolt_top.lerp(_bolt_tip, u)
			if k > 0 and k < 8:
				p += Vector3((0.7 if (k + seed) % 2 == 0 else -0.7) * (0.6 + 0.4 * sin(k * 2.3 + seed)), 0.0, 0.25 * sin(k * 1.7 + seed)) * _size
			all.append(p)
		var from := clampi(int(clampf((strike - 0.45) / 0.35, 0.0, 1.0) * 7.0), 0, 6)
		_bolt.mesh = Lib.path_tube(all.slice(from), 0.2 * _size, 0.0, 4)
	# 王冠の落書き（2D の飾り）
	var up := t - 1.75
	_crown.visible = up >= 0.0 and t < 3.5
	param(_crown, "phase", t)
	param(_crown, "grow", clampf(up / 0.45, 0.0, 1.0))
	param(_crown, "wear", smoothstep(3.0, 3.45, t))
