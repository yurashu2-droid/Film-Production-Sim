extends RefCounted
# VFX共通の部品。画像・メッシュは一度だけ作って使い回す。
# 画像はすべてコードで描くので、素材ファイルもエディタ作業も要らない。
# 別の画像に差し替えたい時は、材質に set_shader_parameter で渡せばよい。

const SHADER_DIR := "res://vfx/shaders/"

static var _cache: Dictionary = {}


# 最初の一発で止まらないよう、起動時に作っておく
static func warm() -> void:
	noise("cells")
	noise("soft")
	flame_texture()
	for i in 3:
		cloud_mesh(i)


static func shader(shader_name: String) -> Shader:
	return load(SHADER_DIR + shader_name + ".gdshader") as Shader


static func material(shader_name: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(shader_name)
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return m


# 継ぎ目なく繰り返せるノイズ画像。"cells" は泡状（溶かし用）、"soft" はなだらか（歪み・軌跡用）
static func noise(kind: String) -> ImageTexture:
	var key := "noise_" + kind
	if not _cache.has(key):
		var n := FastNoiseLite.new()
		n.seed = 7
		if kind == "cells":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.04
			n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN_SQUARED
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
		else:
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.02
			n.fractal_octaves = 3
		var img := n.get_seamless_image(128, 128)
		img.generate_mipmaps()
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


# 流れる方向と濃さを別チャンネルに格納した、継ぎ目のない模様。
static func flow_noise() -> ImageTexture:
	# RG: curl direction of a seamless scalar field. B: its density.
	# Separates where the material goes from how opaque its texture is.
	if not _cache.has("flow_noise"):
		var source := noise("soft").get_image()
		var w := source.get_width()
		var h := source.get_height()
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var dx := source.get_pixel((x+1)%w,y).r-source.get_pixel((x+w-1)%w,y).r
				var dy := source.get_pixel(x,(y+1)%h).r-source.get_pixel(x,(y+h-1)%h).r
				img.set_pixel(x,y,Color(clampf(0.5-dy*8,0,1),clampf(0.5+dx*8,0,1),source.get_pixel(x,y).r,1))
		img.generate_mipmaps()
		_cache["flow_noise"] = ImageTexture.create_from_image(img)
	return _cache["flow_noise"]


# 炎の絵。しずく形を3階調（外 0.5 / 中 0.75 / 芯 1.0）で描く。上端が炎の先。
static func flame_texture() -> ImageTexture:
	if not _cache.has("flame"):
		var w := 160
		var h := 256
		var data := PackedByteArray()
		data.resize(w * h)
		for y in h:
			var v := 1.0 - (y + 0.5) / h
			for x in w:
				var u := (x + 0.5) / w * 2.0 - 1.0
				var g := 0.5 * _flame_cover(u, v, 1.0, 0.0)
				g = maxf(g, 0.75 * _flame_cover(u, v, 0.66, 2.1))
				g = maxf(g, _flame_cover(u, v, 0.36, 4.4))
				data[y * w + x] = int(g * 255.0)
		var img := Image.create_from_data(w, h, false, Image.FORMAT_L8, data)
		img.generate_mipmaps()
		_cache["flame"] = ImageTexture.create_from_image(img)
	return _cache["flame"]


static func _flame_cover(u: float, v: float, s: float, ph: float) -> float:
	var yy := (v - 0.03) / (0.94 * s)
	if yy <= 0.0 or yy >= 1.0:
		return 0.0
	var half := 0.62 * s * sqrt(yy) * pow(1.0 - yy, 1.1) / 0.37
	half *= 1.0 + 0.2 * sin(yy * 12.0 + ph) * yy + 0.22 * (absf(sin(yy * 8.0 + ph * 1.9)) - 0.5) * yy
	var center := 0.16 * s * sin(yy * 6.5 + ph * 1.3) * yy
	return clampf((half - absf(u - center)) / 0.025, 0.0, 1.0)


# もこもこした雲のかたまり。球の上に丸い房をいくつも盛って作る。variant で形違い。
static func cloud_mesh(variant: int = 0) -> ArrayMesh:
	var key := "cloud_%d" % variant
	if not _cache.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + variant * 5
		var lobes: Array = []     # [向き, 高さ, 鋭さ]
		for i in 12:
			var y := 1.0 - 2.0 * (i + 0.5) / 12.0
			var ring := sqrt(1.0 - y * y)
			var around := i * 2.39996 + rng.randf_range(-0.5, 0.5)
			lobes.append([Vector3(cos(around) * ring, y + rng.randf_range(-0.2, 0.2), sin(around) * ring).normalized(), rng.randf_range(0.55, 1.0), rng.randf_range(5.0, 9.0)])
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 24
		sphere.rings = 12
		var arrays := sphere.get_mesh_arrays()
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in points.size():
			var d := points[i].normalized()
			var side := d.cross(Vector3.UP).normalized() if absf(d.y) < 0.95 else d.cross(Vector3.RIGHT).normalized()
			var up := d.cross(side).normalized()
			var a := (d + side * 0.02).normalized()
			var b := (d + up * 0.02).normalized()
			var p := d * _cloud_radius(lobes, d)
			normals[i] = (a * _cloud_radius(lobes, a) - p).cross(b * _cloud_radius(lobes, b) - p).normalized()
			points[i] = p
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_cache[key] = mesh
	return _cache[key]


static func _cloud_radius(lobes: Array, d: Vector3) -> float:
	var best := 0.0
	for lobe: Array in lobes:
		best = maxf(best, lobe[1] * exp(-lobe[2] * (1.0 - d.dot(lobe[0]))))
	return 0.5 * (0.5 + 0.5 * best)


static func quad() -> QuadMesh:
	if not _cache.has("quad"):
		_cache["quad"] = QuadMesh.new()
	return _cache["quad"]


# 火花の一本。+Y が進行方向で、後ろが細る。長さ1。
static func streak_mesh() -> CylinderMesh:
	if not _cache.has("streak"):
		var m := CylinderMesh.new()
		m.height = 1.0
		m.top_radius = 0.035
		m.bottom_radius = 0.0
		m.radial_segments = 4
		m.rings = 1
		_cache["streak"] = m
	return _cache["streak"]


# 色の移り変わり。[[位置, 色], ...]。1を超える色もそのまま持つ。
static func ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s: Array in stops:
		offsets.append(s[0])
		colors.append(s[1])
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	t.use_hdr = true
	return t


# 寿命に沿う曲線。[[位置, 値], ...]
static func curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Array in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	t.width = 64
	return t


# 粒子の動きの設定を、項目名の辞書からまとめて作る
static func process(props: Dictionary) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	for key: String in props:
		assert(key in m, "ParticleProcessMaterial に無い項目: " + key)
		m.set(key, props[key])
	return m


static func particles(mesh: Mesh, mat: Material, proc: ParticleProcessMaterial, amount: int, lifetime: float, one_shot: bool = true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.draw_pass_1 = mesh
	p.material_override = mat
	p.process_material = proc
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.emitting = false
	p.fixed_fps = 60
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return p


# 取り込み済みの素材テクスチャ（assets/vfx/lelu_noise。出典とライセンスは同じフォルダの SOURCE.md）
static func tex(file_name: String) -> Texture2D:
	return load("res://assets/vfx/lelu_noise/" + file_name) as Texture2D


# 回転体の筒。profile は [[高さ0〜1, 半径], ...]。UV.x が周方向、UV.y が 0＝根元 〜 1＝先端。高さは1なので、置く側で伸ばす。
static func tube_mesh(profile: Array, sides: int = 32, rings: int = 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for j in rings + 1:
		var v := float(j) / rings
		var radius: float = profile[-1][1]
		for k in profile.size() - 1:
			if v <= profile[k + 1][0]:
				radius = lerpf(profile[k][1], profile[k + 1][1], inverse_lerp(profile[k][0], profile[k + 1][0], v))
				break
		var row: Array = []
		for i in sides + 1:
			var a := float(i) / sides * TAU
			row.append([Vector3(cos(a) * radius, v, sin(a) * radius), Vector2(float(i) / sides, v)])
		grid.append(row)
	for j in rings:
		for i in sides:
			for corner: Array in [[j, i], [j + 1, i], [j, i + 1], [j, i + 1], [j + 1, i], [j + 1, i + 1]]:
				var point: Array = grid[corner[0]][corner[1]]
				st.set_uv(point[1])
				st.add_vertex(point[0])
	st.generate_normals()
	return st.commit()


# 重ねて使う「すき間だらけの薄い殻」を1層作る（wisp シェーダー）。i は外から数えた番号、count は層の数。
# 外の層ほどすき間が多く遅く、内の層ほど詰まって速い。色は呼ぶ側で、外を暗く・内を明るく渡す。
static func wisp_layer(mesh: Mesh, i: int, count: int, color: Vector3, color_inner: Vector3, extra: Dictionary = {}) -> MeshInstance3D:
	var k := float(i) / maxf(count - 1, 1)
	var params := {
		"mask_a": tex("noise_wo14.png"), "mask_b": noise("soft"), "seed": i * 0.37,
		"cut": lerpf(0.63, 0.52, k),
		"speed_a": Vector2(lerpf(0.4, 1.5, k), lerpf(0.2, 0.8, k)),
		"speed_b": Vector2(-lerpf(0.15, 0.6, k), lerpf(0.26, 1.0, k)),
		"color": color, "color_inner": color_inner,
	}
	params.merge(extra, true)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material("wisp", params)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-3, -1.5, -3), Vector3(6, 4, 6))
	return mi
