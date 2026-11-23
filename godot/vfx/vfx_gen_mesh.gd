extends "res://vfx/vfx_base.gd"
# 蒼磁の解花: 生成マスクの境界を抽出→三角形化→細分→両面と厚みを持つ曲面へ。
# 素材: 白磁/淡青結晶。0.2から根元の圧力が順に先へ届く。6枚が0.14秒ずつ遅れる。
# 0.8-2.3 曲げが根から先へ進み開花、2.8-3.6 ひびが伝播して各花弁が3片に割れる。
# 破片は角速度を保って落下、着地で一度だけ小さく跳ね、5.0-5.5 地面へ沈む。
# 固体なので実厚/照明/弾道を使う。画像は装飾ではなく全頂点の輪郭を決める。
const SOURCE := "res://assets/vfx/ai_methods/petal_mask.png"
const MATERIAL := preload("res://vfx/shaders/gen_mesh.gdshader")
var _petals: Array = []
static var _whole: ArrayMesh
static var _parts: Array[ArrayMesh] = []
static var _centers: Array[Vector3] = []

static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx := new()
	parent.add_child(fx)
	fx.position = pos
	fx.scale = Vector3.ONE * size
	fx.life = 6.0
	fx._build()
	return fx

func _build() -> void:
	if _whole == null:
		_analyze_mask()
	for i in 6:
		var root := Node3D.new()
		root.rotation.y = TAU * float(i) / 6.0 + 0.16 * sin(float(i) * 2.2)
		root.position.y = 0.09
		add_child(root)
		var mat := _material(i)
		var full := MeshInstance3D.new()
		full.mesh = _whole
		full.material_override = mat
		root.add_child(full)
		var fragments: Array[MeshInstance3D] = []
		for j in 3:
			var part := MeshInstance3D.new()
			part.mesh = _parts[j]
			var pm := _material(i)
			pm.set_shader_parameter("broken", true)
			pm.set_shader_parameter("pivot", _centers[j])
			part.material_override = pm
			part.visible = false
			root.add_child(part)
			fragments.append(part)
		_petals.append({"full": full, "mat": mat, "parts": fragments, "id": i})
	_tick(0.0)

func _material(i: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MATERIAL
	mat.set_shader_parameter("delay", float(i) * 0.14)
	mat.set_shader_parameter("variation", float(i))
	return mat

func _tick(_delta: float) -> void:
	for petal: Dictionary in _petals:
		var i: int = petal.id
		var fracture := 2.85 + float(i) * 0.14
		var active := age >= fracture
		petal.full.visible = not active
		petal.mat.set_shader_parameter("clock", age)
		for j in 3:
			var part: MeshInstance3D = petal.parts[j]
			part.visible = active and age < 5.65
			if not active:
				continue
			var elapsed := maxf(0.0, age - fracture - float(j) * 0.07)
			var center := _bent_center(_centers[j], i)
			var velocity := Vector3((float(j) - 1.0) * 0.29 + sin(float(i) * 1.7) * 0.14, 0.38 + float(j) * 0.15, 0.34 + float(j) * 0.19)
			var gravity := 5.7
			var hit := (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * gravity * maxf(0.0, center.y - 0.12))) / gravity
			var flight := minf(elapsed, hit)
			var p := center + velocity * flight + Vector3.DOWN * gravity * flight * flight * 0.5
			if elapsed > hit:
				var bounce := elapsed - hit
				p.y = 0.12 + maxf(0.0, 0.22 * bounce - 2.0 * bounce * bounce)
				p.x += velocity.x * minf(bounce, 0.23) * 0.3
				p.z += velocity.z * minf(bounce, 0.23) * 0.3
			# Burial rather than shrink/fade. Vary the pickup time per fragment.
			p.y -= smoothstep(4.95 + float(j) * 0.10, 5.45 + float(j) * 0.10, age) * 2.0
			part.position = p
			part.rotation = Vector3(0.31, (float(j) - 1.0) * 0.72, 0.43 * sin(float(i) + float(j))) * minf(elapsed, hit + 0.16)
			if elapsed > hit:
				# Each thick ceramic fragment settles onto its broad face after contact.
				var settle := smoothstep(hit, hit + 0.30, elapsed)
				part.rotation.x = lerpf(part.rotation.x, PI * 0.5 - (1.15 + sin(float(i) * 1.9) * 0.12) * _centers[j].y / 2.6, settle)
			var pm := part.material_override as ShaderMaterial
			pm.set_shader_parameter("clock", fracture)

static func _bent_center(p: Vector3, i: int) -> Vector3:
	var y := p.y / 2.6
	var angle := (1.15 + sin(float(i) * 1.9) * 0.12) * y
	return Vector3(p.x, p.y * cos(angle) - p.z * sin(angle), p.y * sin(angle) + p.z * cos(angle))

static func _analyze_mask() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null or image.is_empty():
		push_error("Generated petal mask is missing: " + SOURCE)
		_whole = ArrayMesh.new()
		return
	image.resize(160, 160, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	# Put luminance into alpha before using Godot's actual contour extractor.
	for y in 160:
		for x in 160:
			var p := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1, 1, 1, p.r * p.a))
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.45)
	var polygons := bitmap.opaque_to_polygons(Rect2i(0, 0, 160, 160), 1.3)
	var outline := PackedVector2Array()
	for polygon: PackedVector2Array in polygons:
		if polygon.size() > outline.size():
			outline = polygon
	if outline.size() < 3:
		push_error("Petal source does not contain an extractable white shape")
		_whole = ArrayMesh.new()
		return
	var minimum := Vector2(160, 160)
	var maximum := Vector2.ZERO
	for point: Vector2 in outline:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var extent := maximum - minimum
	for k in outline.size():
		var q := (outline[k] - minimum) / extent
		outline[k] = Vector2((q.x - 0.5) * 1.32, (1.0 - q.y) * 2.6)
	var indices := Geometry2D.triangulate_polygon(outline)
	var triangles: Array = []
	for k in range(0, indices.size(), 3):
		_subdivide(outline[indices[k]], outline[indices[k + 1]], outline[indices[k + 2]], 3, triangles)
	_whole = _thick_mesh(triangles)
	_parts.clear()
	_centers.clear()
	for group in 3:
		var selected: Array = []
		var center := Vector3.ZERO
		var count := 0
		for tri: Array in triangles:
			var middle: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
			var g := 0 if middle.y < 0.93 else (1 if middle.y < 1.78 else 2)
			if g == group:
				selected.append(tri)
				center += _curve(middle)
				count += 1
		_parts.append(_thick_mesh(selected))
		_centers.append(center / float(maxi(count, 1)))

static func _subdivide(a: Vector2, b: Vector2, c: Vector2, levels: int, output: Array) -> void:
	if levels == 0:
		output.append([a, b, c])
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	_subdivide(a, ab, ca, levels - 1, output)
	_subdivide(ab, b, bc, levels - 1, output)
	_subdivide(ca, bc, c, levels - 1, output)
	_subdivide(ab, bc, ca, levels - 1, output)

static func _curve(p: Vector2) -> Vector3:
	return Vector3(p.x, p.y, 0.12 * sin(p.y / 2.6 * PI) + p.x * p.x * 0.38)

static func _thick_mesh(triangles: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in triangles:
		var front: Array[Vector3] = []
		var back: Array[Vector3] = []
		for q: Vector2 in tri:
			var p := _curve(q)
			front.append(p + Vector3(0, 0, 0.065))
			back.append(p - Vector3(0, 0, 0.065))
		for k in [0, 1, 2]:
			_vertex(st, front[k], tri[k])
		for k in [2, 1, 0]:
			_vertex(st, back[k], tri[k])
		for edge in 3:
			var next := (edge + 1) % 3
			for k in [0, 1, 2, 0, 2, 3]:
				var points := [front[edge], back[edge], back[next], front[next]]
				_vertex(st, points[k], tri[edge] if k < 2 else tri[next])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _vertex(st: SurfaceTool, p: Vector3, q: Vector2) -> void:
	st.set_uv(Vector2(q.x / 1.32 + 0.5, q.y / 2.6))
	st.add_vertex(p)
