extends "res://vfx/vfx_base.gd"
# 朱炎の裂咆: 生成された濃淡を各高さの分岐輪郭へ解析し、厚みのある疎な熱流にする。
# 素材: 炎。地面の圧力が先頭を押し上げ、古い腹は遅れて横へ巻き返す。
# 0.2-1.2 先頭の伝播 / 1.3-2.6 肩の横転 / 2.8-3.5 供給を断ち根が千切れる。
# 外: 赤い舌が上へ抜ける。中: 橙の腹が斜め上へ冷える。芯: 遅れて上昇排出。
# 完成した絵のquadや拡縮は使わず、画像の左右の分岐幅が実際の体積断面となる。

const SOURCE := "res://assets/vfx/ai_methods/silhouette.png"
const MATERIAL := preload("res://vfx/shaders/gen_silhouette.gdshader")
var _layers: Array[MeshInstance3D] = []
var _lamp: OmniLight3D
static var _shape: ArrayMesh

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx := new()
	parent.add_child(fx)
	fx.position = pos
	fx.scale = Vector3.ONE * size
	fx.life = 6.0
	fx._build()
	return fx

func _build() -> void:
	if _shape == null:
		_shape = _analyze_shape()
	for i in 3:
		var node := MeshInstance3D.new()
		node.mesh = _shape
		var mat := ShaderMaterial.new()
		mat.shader = MATERIAL
		mat.set_shader_parameter("layer", float(i))
		mat.set_shader_parameter("phase", float(i) * 1.9)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_layers.append(node)
	_lamp = lamp(Color(1.0, 0.2, 0.025), 5.0)
	_tick(0.0)

func _tick(_delta: float) -> void:
	for node in _layers:
		(node.material_override as ShaderMaterial).set_shader_parameter("clock", age)
		# All layer tails have passed their heads well before the parent cleanup.
		node.visible = age < 5.15
	if is_instance_valid(_lamp):
		_lamp.light_energy = 1.4 * smoothstep(0.0, 0.55, age) * (1.0 - smoothstep(3.4, 4.7, age))

static func _analyze_shape() -> ArrayMesh:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null or image.is_empty():
		push_error("Generated silhouette source is missing: " + SOURCE)
		return ArrayMesh.new()
	image.resize(128, 160, Image.INTERPOLATE_LANCZOS)
	var minimum := Vector2i(127, 159)
	var maximum := Vector2i.ZERO
	for y in 160:
		for x in 128:
			var p := image.get_pixel(x, y)
			if p.r * p.a > 0.20:
				minimum = minimum.min(Vector2i(x, y))
				maximum = maximum.max(Vector2i(x, y))
	if maximum.x > minimum.x and maximum.y > minimum.y:
		image = image.get_region(Rect2i(minimum, maximum - minimum + Vector2i.ONE))
		image.resize(128, 160, Image.INTERPOLATE_LANCZOS)
	var rows: Array = []
	# Read intervals, preserving the generated curled neck and split tips.
	for y in range(3, 158, 2):
		var spans: Array[Vector2] = []
		var entered := -1
		for x in 128:
			var p := image.get_pixel(x, y)
			var inside := p.r * p.a > 0.20
			if inside and entered < 0:
				entered = x
			if entered >= 0 and (not inside or x == 127):
				if x - entered > 2:
					spans.append(Vector2(float(entered) / 128.0, float(x) / 128.0))
				entered = -1
		rows.append({"v": 1.0 - float(y) / 160.0, "spans": spans})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rows.size() - 1):
		var top: Dictionary = rows[r]
		var bottom: Dictionary = rows[r + 1]
		for span: Vector2 in top.spans:
			var best := Vector2.ZERO
			var distance := 100.0
			for next: Vector2 in bottom.spans:
				var d := absf((span.x + span.y) - (next.x + next.y))
				if d < distance:
					distance = d
					best = next
			if distance > 0.3:
				continue
			for a in 16:
				var a0 := float(a) / 16.0
				var a1 := float(a + 1) / 16.0
				var corners := [_ring(span, top.v, a0), _ring(best, bottom.v, a0), _ring(best, bottom.v, a1), _ring(span, top.v, a1)]
				for j in [0, 1, 2, 0, 2, 3]:
					var side := a0 if j < 2 else a1
					var v: float = top.v if j == 0 or j == 3 else bottom.v
					var row_span: Vector2 = span if j == 0 or j == 3 else best
					st.set_color(Color((row_span.x + row_span.y) * 0.5, (row_span.y - row_span.x), 0, 1))
					st.set_uv(Vector2(side, v))
					st.add_vertex(corners[j])
	st.generate_normals()
	return st.commit()

static func _ring(span: Vector2, y: float, around: float) -> Vector3:
	var center := ((span.x + span.y) * 0.5 - 0.5) * 3.65
	var radius := (span.y - span.x) * 1.825
	var theta := around * TAU
	# Depth is an actual elliptical cross-section, not extruded constant depth.
	var depth := maxf(0.12, radius * 1.35)
	return Vector3(center + cos(theta) * radius, y * 3.8 + 0.06, sin(theta) * depth)
