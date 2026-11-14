extends MeshInstance3D
# 念のオーラ1枚：物・人・手・何もない一点のまわりに出す「念の膜」（shaders/psychic_aura）。超能力の演出（vfx/esper/）で使い回す。
# 物の外形の点をカメラごとに画面へ写して輪郭を出すので、どの向きから見ても輪郭に沿う。板は物の後ろにあり、物を隠さない。
# 使い方：around(親, 物) か at(親, 点の列) で作り、毎コマ place(時刻) を呼ぶ。波紋は ring(時刻)。そのほかは p("名前", 値) で直接渡す。
const Lib := preload("res://vfx/vfx_lib.gd")
const Psychic := preload("res://vfx/vfx_psychic.gd")

# 見た目の既定（opts で上書きする）
const LOOK := {
	"band": 0.018, "amp": 0.075, "jag": 0.55, "teeth": 10.0, "rise": 0.6, "split": 0.011, "haze": 0.0,
	"ring_gain": 0.9, "ring_reach": 0.36, "ring_width": 0.014, "warp": 0.5, "pad": 0.0, "opacity": 0.92,
}

var body: Node3D                      # 追う相手（無ければ、点はワールド座標のまま）
var center_local := Vector3.ZERO      # 外形の中心（相手のローカル。相手が無ければワールド）
var radius := 0.4                     # 外形の半径（m）
var reach := 1.0                      # 板の余白（帯と波紋が届く距離。m）
var in_front := true                  # 輪郭の外の部分を、物の手前側の奥行きで比べる（壁・床に隠れない）
var ring_sec := 0.75                  # 波紋1本の寿命
var mat: ShaderMaterial
var _rings: Array[float] = [-9.0, -9.0, -9.0]
var _next := 0
var _spark := 0.0
var _boil := 0.0
var _last := -1.0


# target の見た目（その下のメッシュ）を包むオーラ
static func around(parent: Node, target: Node3D, opts: Dictionary = {}) -> MeshInstance3D:
	var quad: MeshInstance3D = new()
	parent.add_child(quad)
	var sources: Array = []
	_collect(target, sources)
	var to_local := target.global_transform.affine_inverse()
	var all := PackedVector3Array()
	var box := AABB()
	for i in sources.size():
		var src: MeshInstance3D = sources[i]
		var part: Transform3D = to_local * src.global_transform
		for point: Vector3 in Psychic._mesh_extremes(src.mesh):
			all.append(part * point)
		var bounds: AABB = part * src.get_aabb()
		box = bounds if i == 0 else box.merge(bounds)
	var outline := PackedVector3Array()
	for d in Psychic.DIRS:
		var dir: Vector3 = Psychic._dir(d)
		var pick := Vector3.ZERO
		var far := -INF
		for point: Vector3 in all:
			if point.dot(dir) > far:
				far = point.dot(dir)
				pick = point
		if far > -INF and not outline.has(pick):
			outline.append(pick)
	quad.body = target
	quad.center_local = box.get_center()
	quad.radius = (target.global_basis * (box.size * 0.5)).length()
	quad.build(outline, opts)
	return quad


# 点の列（ワールド座標）を包むオーラ。1点なら、その点のまわりの丸（pad で大きさを決める）
static func at(parent: Node, points: PackedVector3Array, opts: Dictionary = {}) -> MeshInstance3D:
	var quad: MeshInstance3D = new()
	parent.add_child(quad)
	quad.build(points, opts)
	quad.move(points)
	return quad


static func _collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).visible:
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null and ((child as MeshInstance3D).layers & 1) != 0:
			out.append(child)
		_collect(child, out)


func build(outline: PackedVector3Array, opts: Dictionary) -> void:
	var look := LOOK.duplicate()
	look.merge(opts, true)
	var tint: Color = opts.get("tint", Psychic.TINT)
	var top := maxf(maxf(tint.r, tint.g), maxf(tint.b, 0.001))
	var hue := Vector3(tint.r, tint.g, tint.b) / top
	mat = Lib.material("psychic_aura", {
		"noise_tex": Lib.noise("soft"), "color": hue * 0.95, "color_core": hue.lerp(Vector3.ONE, 0.6) * 1.25,
		"color_a": Vector3(1.0, 0.35, 0.8), "color_b": Vector3(0.3, 0.85, 1.0),
	})
	for key: String in LOOK:
		mat.set_shader_parameter(key, look[key])
	mat.render_priority = int(opts.get("priority", 1))
	_set_points(outline)
	reach = float(look["amp"]) * 2.6 + float(look["ring_reach"]) + 0.15
	in_front = bool(opts.get("in_front", true))
	mesh = Lib.quad()
	material_override = mat
	layers = int(opts.get("layers", 1))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	custom_aabb = AABB(Vector3.ONE * -4.0, Vector3.ONE * 8.0)


func _set_points(outline: PackedVector3Array) -> void:
	var pts := PackedVector3Array()
	pts.resize(16)
	for i in 16:
		pts[i] = outline[mini(i, outline.size() - 1)] if not outline.is_empty() else Vector3.ZERO
	mat.set_shader_parameter("pts", pts)
	mat.set_shader_parameter("pt_count", clampi(outline.size(), 1, 16))


# 相手を持たないオーラの点を、動かす（ワールド座標。16 個まで）
func move(points: PackedVector3Array) -> void:
	_set_points(points)
	var mid := Vector3.ZERO
	for point: Vector3 in points:
		mid += point / maxf(points.size(), 1.0)
	center_local = mid
	radius = 0.05
	for point: Vector3 in points:
		radius = maxf(radius, point.distance_to(mid))


func p(key: String, value: Variant) -> void:
	mat.set_shader_parameter(key, value)


# 波紋を1本出す
func ring(now: float) -> void:
	_rings[_next % 3] = now
	_next += 1


# 毎コマ呼ぶ：相手について行き、コマ打ちと波紋を進める。active（0〜1）で沸き方の速さを変える
func place(now: float, active: float = 0.0) -> void:
	var delta := maxf(now - _last, 0.0) if _last >= 0.0 else 0.0
	_last = now
	_spark += delta * 12.0 * lerpf(0.6, 1.0, active)
	_boil += delta * lerpf(0.35, 0.9, active)
	var xf := Transform3D.IDENTITY
	if body != null:
		if not is_instance_valid(body):
			visible = false
			return
		xf = body.get_global_transform_interpolated()
	var center := xf * center_local
	var pad: float = mat.get_shader_parameter("pad")
	global_position = center
	mat.set_shader_parameter("body", xf)
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("extent", radius + pad + reach * 2.2)
	mat.set_shader_parameter("back", radius + pad + 0.05)
	mat.set_shader_parameter("front", radius + pad if in_front else 0.0)
	mat.set_shader_parameter("frame", _spark)
	mat.set_shader_parameter("boil", _boil)
	mat.set_shader_parameter("rings", Vector3((now - _rings[0]) / ring_sec, (now - _rings[1]) / ring_sec, (now - _rings[2]) / ring_sec))
