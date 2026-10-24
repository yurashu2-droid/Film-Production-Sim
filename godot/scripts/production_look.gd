extends RefCounted
# 拠点の「絵作り」：環境光・手続き生成テクスチャ・共有マテリアル・まとめ描画（Batch）。
#   ・apply(env, stage, root) を拠点を作り終えたあとに1回呼ぶ（空・霧・SSAO・トーンマップ）
#   ・テクスチャは画像ファイルを使わず、ノイズと矩形塗りだけで起動時に作る（最初に使われた時に生成して使い回す）
#   ・Batch は箱・円柱・板をマテリアルごとに1つのメッシュへまとめる（描画回数を増やさない）
#   ・太陽（DirectionalLight3D）には触らない。撮影現場と共有する環境なので、明るさの基準は変えない

const FONT_PATH := "res://assets/fonts/NotoSansJP-VF.ttf"

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _font: Font


# ---- 環境 ----

static func apply(env: Environment, stage: Node, root: Node3D) -> void:
	if env == null:
		return
	if root != null and root.has_meta("look_applied"):
		return
	if root != null:
		root.set_meta("look_applied", true)
	# 空：上は少し濃い青、地平線はあたたかい白。霧の色を地平線に合わせて遠景をなじませる
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d86d8")
	sky_mat.sky_horizon_color = Color("dce8e6")
	sky_mat.sky_curve = 0.16
	sky_mat.ground_horizon_color = Color("bdc4b8")
	sky_mat.ground_bottom_color = Color("6f7a70")
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("d8e2dc")
	env.fog_light_energy = 1.0
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.45
	env.fog_aerial_perspective = 0.2
	env.fog_sun_scatter = 0.05
	# 接触影を効かせて、物の足元や壁際に奥行きを出す（SSAO自体は舞台で有効）
	env.ssao_enabled = true
	env.ssao_radius = 1.3
	env.ssao_intensity = 2.6
	env.ssao_power = 1.7
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.25
	# トーンマップとカラー調整：少しコントラストと彩度を足す
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.96
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.24
	env.adjustment_brightness = 1.0
	# 色調：明るい所は日なたの暖かい色、暗い所は少し青く（参考：Dear Passengers・PEAK の昼の光）
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grade.colors = PackedColorArray([Color(0.0, 0.015, 0.05), Color(0.525, 0.5, 0.455), Color(1.0, 0.975, 0.9)])
	var lut := GradientTexture1D.new()
	lut.gradient = grade
	lut.width = 256
	env.adjustment_color_correction = lut
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_hdr_threshold = 1.5
	env.glow_bloom = 0.03


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH) as Font
		else:
			_font = ThemeDB.fallback_font
	return _font


# 看板の文字（床や壁に貼る）
static func label(parent: Node, xf: Transform3D, words: String, pixel: float, size: int, color: Color, fnt: Font = null, shaded := true) -> Label3D:
	var l := Label3D.new()
	l.text = words
	l.font = fnt if fnt != null else font()
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = shaded
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.transform = xf
	parent.add_child(l)
	return l


# ---- 金網 ----

const CHAIN_LINK := preload("res://shaders/chain_link.gdshader")


# 金網のマテリアル（頂点色で色を付ける）。diamond：ひし形の金網フェンス、false：縦長の格子の溶接金網。
# 網目を画像で抜かずに計算するので、遠くでも網が透けて消えない（shaders/chain_link.gdshader）
static func chain_link(pitch: Vector2, wire: float, diamond := true) -> ShaderMaterial:
	var key := "chain%s%.4f%s" % [str(pitch), wire, str(diamond)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = CHAIN_LINK
	m.set_shader_parameter("pitch", pitch)
	m.set_shader_parameter("wire", wire)
	m.set_shader_parameter("diamond", diamond)
	_mat_cache[key] = m
	return m


# ---- 絵記号（文字を使わない札の絵） ----
# 板の面にぴったり貼る（浮かせない）。xf の +Z が絵の表。大きさは size（メートル）
#   no_entry：赤い丸に白い横棒（進入禁止）　camera：防犯カメラ　arrow：右向きの矢印（左は xf で裏返す）
#   bag：ごみ袋　movie_camera：映画の撮影機（リール2つ）　box：段ボール箱
static var _picto_cache: Dictionary = {}


static func picto(parent: Node, xf: Transform3D, kind: String, size: Vector2, layers := 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Picto_" + kind
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.material_override = _picto_mat(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = layers
	mi.transform = xf
	parent.add_child(mi)
	return mi


static func _picto_mat(kind: String) -> StandardMaterial3D:
	if _picto_cache.has(kind):
		return _picto_cache[kind]
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_picto_image(kind, 128))
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.roughness = 0.75
	_picto_cache[kind] = m
	return m


# 形の一覧（[種類, 引数...]）と色の組を、塗る順に並べる。座標は -1..1（上が +y）
static func _picto_layers(kind: String) -> Array:
	var ink := Color("26282a")
	match kind:
		"no_entry":
			return [[[["circle", Vector2.ZERO, 1.0]], Color("f4f2ea")],
					[[["circle", Vector2.ZERO, 0.86]], Color("c8352b")],
					[[["box", Vector2.ZERO, Vector2(0.6, 0.15), 0.0]], Color("f4f2ea")]]
		"camera":
			return [[[["box", Vector2(0.12, 0.18), Vector2(0.5, 0.2), -0.32], ["box", Vector2(0.16, 0.42), Vector2(0.58, 0.05), -0.32],
					["box", Vector2(-0.42, -0.08), Vector2(0.07, 0.3), 0.0], ["box", Vector2(-0.42, -0.4), Vector2(0.22, 0.07), 0.0]], ink],
					[[["circle", Vector2(0.55, 0.02), 0.09]], Color("f2d23c")]]
		"arrow":
			return [[[["box", Vector2(-0.25, 0.0), Vector2(0.55, 0.15), 0.0],
					["poly", [Vector2(0.2, -0.48), Vector2(0.85, 0.0), Vector2(0.2, 0.48)]]], Color("fff1d1")]]
		"bag":
			return [[[["circle", Vector2(0.0, -0.22), 0.6], ["box", Vector2(0.0, 0.42), Vector2(0.1, 0.14), 0.0],
					["circle", Vector2(-0.17, 0.62), 0.13], ["circle", Vector2(0.17, 0.62), 0.13]], Color("2f7d4f")]]
		"movie_camera":
			return [[[["box", Vector2(-0.12, -0.2), Vector2(0.45, 0.28), 0.0], ["circle", Vector2(-0.36, 0.36), 0.26], ["circle", Vector2(0.16, 0.36), 0.26],
					["poly", [Vector2(0.3, -0.2), Vector2(0.88, -0.52), Vector2(0.88, 0.12)]]], Color("f4f1ea")]]
		"box":
			return [[[["seg", Vector2(-0.62, 0.22), Vector2(0.36, 0.22), 0.05], ["seg", Vector2(0.36, 0.22), Vector2(0.36, -0.72), 0.05],
					["seg", Vector2(0.36, -0.72), Vector2(-0.62, -0.72), 0.05], ["seg", Vector2(-0.62, -0.72), Vector2(-0.62, 0.22), 0.05],
					["seg", Vector2(-0.62, 0.22), Vector2(-0.3, 0.6), 0.05], ["seg", Vector2(-0.3, 0.6), Vector2(0.68, 0.6), 0.05],
					["seg", Vector2(0.68, 0.6), Vector2(0.36, 0.22), 0.05], ["seg", Vector2(0.68, 0.6), Vector2(0.68, -0.34), 0.05],
					["seg", Vector2(0.68, -0.34), Vector2(0.36, -0.72), 0.05], ["seg", Vector2(-0.13, 0.22), Vector2(0.19, 0.6), 0.04]], Color("3a2a1c")]]
	return []


static func _picto_image(kind: String, sz: int) -> Image:
	var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var px := 2.0 / sz
	var layers := _picto_layers(kind)
	for j in sz:
		for i in sz:
			var p := Vector2(-1.0 + (i + 0.5) * px, 1.0 - (j + 0.5) * px)
			var out := Color(0, 0, 0, 0)
			for layer: Array in layers:
				var d := INF
				for s: Array in layer[0]:
					d = minf(d, _sdf(p, s))
				var cov := clampf(0.5 - d / px, 0.0, 1.0)
				if cov > 0.0:
					var c: Color = layer[1]
					var a := out.a * (1.0 - cov) + cov
					var keep := out.a * (1.0 - cov) / a
					out = Color(out.r * keep + c.r * (1.0 - keep), out.g * keep + c.g * (1.0 - keep), out.b * keep + c.b * (1.0 - keep), a)
			im.set_pixel(i, j, out)
	im.generate_mipmaps()
	return im


static func _sdf(p: Vector2, s: Array) -> float:
	match str(s[0]):
		"circle":
			return p.distance_to(s[1]) - float(s[2])
		"box":
			var q: Vector2 = (p - s[1]).rotated(-float(s[3]))
			var d: Vector2 = q.abs() - (s[2] as Vector2)
			return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)
		"seg":
			var a: Vector2 = s[1]
			var ab: Vector2 = (s[2] as Vector2) - a
			var h := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
			return (p - a - ab * h).length() - float(s[3])
		"poly":
			# 凸多角形（反時計回り）：辺の外向きの距離のうち最大
			var pts: Array = s[1]
			var d := -INF
			for k in pts.size():
				var a: Vector2 = pts[k]
				var e: Vector2 = (pts[(k + 1) % pts.size()] as Vector2) - a
				var n := Vector2(e.y, -e.x).normalized()
				d = maxf(d, (p - a).dot(n))
			return d
	return INF


# ---- 画像の部品 ----

static func _blank(w: int, h: int, c: Color = Color(0, 0, 0, 0)) -> Image:
	var im := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	im.fill(c)
	return im


static func _noise_img(sd: int, freq: float, octaves: int, w: int, h: int, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = kind as FastNoiseLite.NoiseType
	n.seed = sd
	n.frequency = freq
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	var im := n.get_seamless_image(w, h, false, false, 0.15, true)
	im.convert(Image.FORMAT_RGBA8)
	return im


# base の上に over を割合 a で重ねる
static func _mix(base: Image, over: Image, a: float) -> void:
	var m := _blank(base.get_width(), base.get_height(), Color(1, 1, 1, a))
	base.blend_rect_mask(over, m, Rect2i(0, 0, base.get_width(), base.get_height()), Vector2i.ZERO)


# 明るさの下限を持ち上げる（0..1 → lo..1）。白を割合 lo で重ねる
static func _lift(im: Image, lo: float) -> void:
	_mix(im, _blank(im.get_width(), im.get_height(), Color.WHITE), lo)


static func _normal_of(height: Image, strength: float) -> Image:
	var n := height.duplicate() as Image
	n.bump_map_to_normal_map(strength)
	return n


static func _to_tex(im: Image, is_normal := false) -> ImageTexture:
	im.generate_mipmaps(is_normal)
	return ImageTexture.create_from_image(im)


static func _cracks(im: Image, rng: RandomNumberGenerator, count: int, col: Color, steps: int = 140) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for k in count:
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var a := rng.randf() * TAU
		for s in steps:
			a += rng.randf_range(-0.45, 0.45)
			p += Vector2(cos(a), sin(a)) * 1.4
			im.set_pixel(posmod(int(p.x), w), posmod(int(p.y), h), col)


# 端でまわり込む矩形塗り
static func _rect_wrap(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var iw := im.get_width()
	if x < 0:
		im.fill_rect(Rect2i(x + iw, y, -x, h), c)
		im.fill_rect(Rect2i(0, y, x + w, h), c)
	elif x + w > iw:
		im.fill_rect(Rect2i(x, y, iw - x, h), c)
		im.fill_rect(Rect2i(0, y, x + w - iw, h), c)
	else:
		im.fill_rect(Rect2i(x, y, w, h), c)


# ---- テクスチャ（name → {albedo, normal, rough}） ----

static func _tex(nm: String) -> Dictionary:
	if _tex_cache.has(nm):
		return _tex_cache[nm]
	var d: Dictionary
	match nm:
		"asphalt": d = _gen_asphalt()
		"concrete": d = _gen_concrete()
		"paving": d = _gen_paving()
		"block": d = _gen_block()
		"metal": d = _gen_metal()
		"shutter": d = _gen_shutter()
		"floor": d = _gen_floor()
		"wood": d = _gen_wood()
		"paint": d = _gen_paint()
		"stain": d = _gen_stain()
		"tower": d = _gen_tower()
		"rug": d = _gen_rug()
		"leaf": d = _gen_leaf()
		"grass": d = _gen_grass()
		"puddle": d = _gen_puddle()
		_: d = _gen_plaster()
	_tex_cache[nm] = d
	return d


# 葉の房（白黒。頂点色で緑に染める）。中心から外へ向かう葉を重ねる。
# 透明な所は明るい灰色にしておき、縮めた絵で葉の縁が黒ずまないようにする
static func _gen_leaf() -> Dictionary:
	var sz := 256
	var im := _blank(sz, sz, Color(0.78, 0.8, 0.74, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ctr := Vector2(sz, sz) * 0.5
	for k in 44:
		var ln := rng.randf_range(34.0, 52.0)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (sz * 0.5 - ln - 6.0)
		var dir := Vector2.from_angle(a + rng.randf_range(-0.6, 0.6))
		_leaf_shape(im, ctr + Vector2.from_angle(a) * r, dir, ln, ln * rng.randf_range(0.34, 0.44), rng.randf_range(0.7, 1.0))
	return {"albedo": _to_tex_cover(im, 0.5), "normal": null, "rough": null}


# 草の房（白黒。下の真ん中から上へ広がる細い葉）。根元ほど暗い
static func _gen_grass() -> Dictionary:
	var sz := 128
	var im := _blank(sz, sz, Color(0.7, 0.74, 0.62, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for k in 16:
		var bx := rng.randf_range(40.0, 88.0)
		var tip := Vector2(bx + rng.randf_range(-34.0, 34.0), rng.randf_range(6.0, 58.0))
		var bend := rng.randf_range(-10.0, 10.0)
		var w := rng.randf_range(3.0, 5.5)
		var val := rng.randf_range(0.75, 1.0)
		for y in range(int(tip.y), sz):
			var t := (float(sz - 1) - y) / (float(sz - 1) - tip.y)
			var cx := lerpf(bx, tip.x, t) + bend * sin(PI * t)
			var hw := w * (1.0 - t)
			for x in range(maxi(int(cx - hw), 0), mini(int(cx + hw) + 1, sz)):
				var c := val * lerpf(0.6, 1.0, t)
				im.set_pixel(x, y, Color(c, c, c * 0.95, 1.0))
	return {"albedo": _to_tex_cover(im, 0.5), "normal": null, "rough": null}


# 水たまりの形（でこぼこの縁。真ん中ほど濃い）
static func _gen_puddle() -> Dictionary:
	var s := 128
	var n := _noise_img(29, 0.04, 3, s, s)
	var im := _blank(s, s, Color(1, 1, 1, 0))
	for y in s:
		for x in s:
			var d := Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.5)
			var v := n.get_pixel(x, y).r
			# 縁はくっきり（ふわふわさせると雲に見える）。縁ぎわは少し暗く、真ん中は空を映して明るい
			var e := (1.0 - d) * 1.4 - (1.0 - v) * 0.5
			var al := clampf(e * 12.0, 0.0, 1.0)
			var c := lerpf(0.72, 1.0, clampf(e * 2.5, 0.0, 1.0))
			im.set_pixel(x, y, Color(c, c, c, al * 0.85))
	return {"albedo": _to_tex(im), "normal": null, "rough": null}


# 1枚の葉（根元 base から dir へ長さ ln、幅 wd）。根元ほど少し暗く、真ん中に葉脈
static func _leaf_shape(im: Image, base: Vector2, dir: Vector2, ln: float, wd: float, val: float) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := base + dir * ln
	var lo := base.min(tip) - Vector2(wd, wd) * 0.5
	var hi := base.max(tip) + Vector2(wd, wd) * 0.5
	for y in range(maxi(int(lo.y), 0), mini(int(hi.y) + 1, im.get_height())):
		for x in range(maxi(int(lo.x), 0), mini(int(hi.x) + 1, im.get_width())):
			var d := Vector2(x + 0.5, y + 0.5) - base
			var t := d.dot(dir) / ln
			if t <= 0.0 or t >= 1.0:
				continue
			var v := absf(d.dot(side))
			if v > wd * 0.5 * pow(sin(PI * t), 0.75):
				continue
			var c := val * lerpf(0.8, 1.0, t)
			if v < 0.9 and t < 0.85:
				c *= 0.82
			im.set_pixel(x, y, Color(c, c * 1.0, c * 0.96, 1.0))


# 抜き（alpha scissor）の絵の縮小画像を自分で作る：段ごとに、しきい値を超える割合を元の絵と同じに保つ
# （普通に縮めると、遠くの木の葉がすかすかに痩せる）
static func _to_tex_cover(im: Image, thr: float) -> ImageTexture:
	var target := _cover(im.get_data(), thr)
	var data := im.get_data()
	var raw := im
	while raw.get_width() > 1 or raw.get_height() > 1:
		raw = raw.duplicate() as Image
		raw.resize(maxi(raw.get_width() / 2, 1), maxi(raw.get_height() / 2, 1), Image.INTERPOLATE_BILINEAR)
		data.append_array(_keep_cover(raw.get_data(), thr, target))
	return ImageTexture.create_from_image(Image.create_from_data(im.get_width(), im.get_height(), true, Image.FORMAT_RGBA8, data))


static func _cover(px: PackedByteArray, thr: float) -> float:
	var n := px.size() / 4
	var hit := 0
	var cut := int(thr * 255.0)
	for i in n:
		if px[i * 4 + 3] >= cut:
			hit += 1
	return float(hit) / maxf(n, 1)


static func _keep_cover(px: PackedByteArray, thr: float, target: float) -> PackedByteArray:
	var n := px.size() / 4
	var hist := PackedInt32Array()
	hist.resize(256)
	for i in n:
		hist[px[i * 4 + 3]] += 1
	# 上から数えて target の割合に届く値 c を探し、c がしきい値に来るように不透明度を伸ばす
	var need := int(target * n)
	var acc := 0
	var c := 255
	while c > 1:
		acc += hist[c]
		if acc >= need:
			break
		c -= 1
	var k := thr * 255.0 / float(c)
	for i in n:
		px[i * 4 + 3] = mini(int(px[i * 4 + 3] * k), 255)
	return px


static func _gen_asphalt() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := _noise_img(11, 0.011, 5, 512, 512)
	var grit := _noise_img(12, 0.85, 1, 512, 512, FastNoiseLite.TYPE_VALUE)
	_mix(a, grit, 0.45)
	# 凹凸は細かい粒だけ（大きなムラは色だけ）
	var hm := _noise_img(13, 0.6, 1, 512, 512, FastNoiseLite.TYPE_VALUE)
	_mix(hm, _noise_img(14, 0.03, 3, 512, 512), 0.4)
	var nrm := _normal_of(hm, 3.0)
	_lift(a, 0.25)
	var r := a.duplicate() as Image
	_lift(r, 0.8)
	return {"albedo": _to_tex(a), "normal": _to_tex(nrm, true), "rough": _to_tex(r)}


# 5m角のコンクリート床：2.5mの板が4枚（継ぎ目つき、板ごとに色味が違う）
static func _gen_concrete() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var s := 512
	var a := _noise_img(21, 0.008, 4, s, s)
	_mix(a, _noise_img(22, 0.25, 1, s, s, FastNoiseLite.TYPE_VALUE), 0.05)
	_cracks(a, rng, 3, Color(0.2, 0.2, 0.2, 1.0), 90)
	var hm := a.duplicate() as Image
	_lift(a, 0.55)
	var ov := _blank(s, s)
	for sy in 2:
		for sx in 2:
			var t := rng.randf_range(0.68, 1.0)
			ov.fill_rect(Rect2i(sx * 256, sy * 256, 256, 256), Color(t, t, t * 0.97, 0.5))
	a.blend_rect(ov, Rect2i(0, 0, s, s), Vector2i.ZERO)
	# 継ぎ目（端でまわり込む）
	for edge: int in [0, 256]:
		for im: Image in [a, hm]:
			var c := Color(0.42, 0.42, 0.42, 1.0) if im == a else Color(0, 0, 0, 1)
			_rect_wrap(im, edge - 2, 0, 5, s, c)
			im.fill_rect(Rect2i(0, maxi(edge - 2, 0), s, 5 if edge > 0 else 3), c)
			if edge == 0:
				im.fill_rect(Rect2i(0, s - 2, s, 2), c)
	var nrm := _normal_of(hm, 1.2)
	var r := a.duplicate() as Image
	_lift(r, 0.7)
	return {"albedo": _to_tex(a), "normal": _to_tex(nrm, true), "rough": _to_tex(r)}


# 0.5m角の敷石（2m四方で繰り返す）
static func _gen_paving() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := 256
	var a := _noise_img(41, 0.02, 4, s, s)
	_lift(a, 0.82)
	var ov := _blank(s, s)
	for ty in 4:
		for tx in 4:
			var tone := rng.randf_range(0.55, 1.0)
			ov.fill_rect(Rect2i(tx * 64, ty * 64, 64, 64), Color(tone, tone * 0.98, tone * 0.94, 0.5))
	a.blend_rect(ov, Rect2i(0, 0, s, s), Vector2i.ZERO)
	var h := a.duplicate() as Image
	for i in 4:
		a.fill_rect(Rect2i(i * 64, 0, 2, s), Color(0.28, 0.28, 0.28, 1.0))
		a.fill_rect(Rect2i(0, i * 64, s, 2), Color(0.28, 0.28, 0.28, 1.0))
		h.fill_rect(Rect2i(i * 64, 0, 3, s), Color(0, 0, 0, 1))
		h.fill_rect(Rect2i(0, i * 64, s, 3), Color(0, 0, 0, 1))
	return {"albedo": _to_tex(a), "normal": _to_tex(_normal_of(h, 3.0), true), "rough": null}


# 0.8m角のブロック／レンガ（0.2m段・0.4m幅の芋目地ずらし）
static func _gen_block() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var s := 256
	var a := _noise_img(31, 0.035, 4, s, s)
	_lift(a, 0.78)
	var ov := _blank(s, s, Color(0.2, 0.18, 0.16, 0.42))
	var hmap := _blank(s, s, Color(0.1, 0.1, 0.1, 1.0))
	for row in 4:
		var off := 0 if row % 2 == 0 else 64
		for k in 3:
			var x0 := off + k * 128 - 128
			if off == 0 and k == 2:
				continue
			var lite := rng.randf_range(0.0, 0.22)
			_rect_wrap(ov, x0 + 3, row * 64 + 3, 122, 58, Color(1, 1, 1, lite))
			_rect_wrap(hmap, x0 + 3, row * 64 + 3, 122, 58, Color(0.9, 0.9, 0.9, 1.0))
	a.blend_rect(ov, Rect2i(0, 0, s, s), Vector2i.ZERO)
	return {"albedo": _to_tex(a), "normal": _to_tex(_normal_of(hmap, 3.5), true), "rough": null}


# 波板：縦リブ。1.2m×2.4m（リブ8本）で繰り返す
static func _gen_metal() -> Dictionary:
	var w := 256
	var h := 512
	var g := _noise_img(51, 0.05, 4, 64, 64)
	g.resize(w, h, Image.INTERPOLATE_BILINEAR)
	# 縦の汚れ筋を強める
	_lift(g, 0.55)
	var nb := PackedByteArray()
	var ab := PackedByteArray()
	var row_n := PackedByteArray()
	var row_a := PackedByteArray()
	row_n.resize(w * 3)
	row_a.resize(w * 4)
	for x in w:
		var ph := TAU * float(x) / 32.0
		var slope := cos(ph) * 0.85
		var nv := Vector3(-slope, 0.0, 1.0).normalized()
		row_n[x * 3] = int((nv.x * 0.5 + 0.5) * 255.0)
		row_n[x * 3 + 1] = 128
		row_n[x * 3 + 2] = int((nv.z * 0.5 + 0.5) * 255.0)
		var sh := int((0.74 + 0.26 * (0.5 + 0.5 * sin(ph))) * 255.0)
		row_a[x * 4] = sh
		row_a[x * 4 + 1] = sh
		row_a[x * 4 + 2] = sh
		row_a[x * 4 + 3] = 255
	for y in h:
		nb.append_array(row_n)
		ab.append_array(row_a)
	var nrm := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, nb)
	var rib := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, ab)
	_mix(g, rib, 0.6)
	return {"albedo": _to_tex(g), "normal": _to_tex(nrm, true), "rough": null}


# ローラーシャッター：横スラット。0.5m四方
static func _gen_shutter() -> Dictionary:
	var s := 128
	var a := _noise_img(61, 0.05, 3, s, s)
	_lift(a, 0.7)
	var hm := _blank(s, s, Color(0.85, 0.85, 0.85, 1.0))
	for i in 4:
		a.fill_rect(Rect2i(0, i * 32 + 28, s, 4), Color(0.18, 0.18, 0.18, 1.0))
		hm.fill_rect(Rect2i(0, i * 32 + 27, s, 5), Color(0.0, 0.0, 0.0, 1.0))
		hm.fill_rect(Rect2i(0, i * 32, s, 4), Color(1, 1, 1, 1.0))
	return {"albedo": _to_tex(a), "normal": _to_tex(_normal_of(hm, 4.0), true), "rough": null}


# 木の床板：1.12m四方に幅0.14mの板
static func _gen_floor() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var s := 256
	var grain := _noise_img(71, 0.06, 3, 32, s)
	grain.resize(s, s, Image.INTERPOLATE_BILINEAR)
	_lift(grain, 0.7)
	var ov := _blank(s, s)
	var hm := _blank(s, s, Color(0.9, 0.9, 0.9, 1.0))
	for row in 8:
		var off := (row * 91) % 128
		for k in 3:
			var x0 := off + k * 128 - 128
			var tone := rng.randf_range(0.7, 1.0)
			_rect_wrap(ov, x0, row * 32, 128, 32, Color(tone, tone * 0.86, tone * 0.66, 0.6))
			_rect_wrap(hm, x0, row * 32, 2, 32, Color(0, 0, 0, 1))
		hm.fill_rect(Rect2i(0, row * 32, s, 2), Color(0, 0, 0, 1))
	grain.blend_rect(ov, Rect2i(0, 0, s, s), Vector2i.ZERO)
	for row in 8:
		grain.fill_rect(Rect2i(0, row * 32, s, 2), Color(0.25, 0.18, 0.12, 1.0))
	return {"albedo": _to_tex(grain), "normal": _to_tex(_normal_of(hm, 2.5), true), "rough": null}


# 木目（パレット・木箱など）：1m四方、木目は横
static func _gen_wood() -> Dictionary:
	var s := 256
	var grain := _noise_img(81, 0.09, 3, 24, s)
	grain.resize(s, s, Image.INTERPOLATE_BILINEAR)
	var nrm := _normal_of(grain, 2.0)
	_lift(grain, 0.55)
	return {"albedo": _to_tex(grain), "normal": _to_tex(nrm, true), "rough": null}


# 壁のしっくい・塗装のムラ（3m）
static func _gen_plaster() -> Dictionary:
	var s := 256
	var a := _noise_img(91, 0.018, 4, s, s)
	_mix(a, _noise_img(92, 0.3, 1, s, s, FastNoiseLite.TYPE_VALUE), 0.12)
	var nrm := _normal_of(a, 0.5)
	_lift(a, 0.86)
	return {"albedo": _to_tex(a), "normal": _to_tex(nrm, true), "rough": null}


# かすれた白線（アルファで抜く）
static func _gen_paint() -> Dictionary:
	var s := 128
	var n := _noise_img(101, 0.07, 4, s, s)
	var m := _noise_img(102, 0.4, 1, s, s, FastNoiseLite.TYPE_VALUE)
	var im := _blank(s, s)
	for y in s:
		for x in s:
			var v := n.get_pixel(x, y).r * 0.8 + m.get_pixel(x, y).r * 0.2
			var al := 1.0 if v > 0.27 else 0.0
			var shade := 0.88 + 0.12 * m.get_pixel(x, y).r
			im.set_pixel(x, y, Color(shade, shade, shade, al))
	return {"albedo": _to_tex(im), "normal": null, "rough": null}


# 油じみ・汚れ（円形にぼかして透過）
static func _gen_stain() -> Dictionary:
	var s := 128
	var n := _noise_img(111, 0.05, 4, s, s)
	var im := _blank(s, s)
	for y in s:
		for x in s:
			var d := Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.5)
			var v := n.get_pixel(x, y).r
			var al := clampf((1.0 - d) * 1.6 - (1.0 - v) * 0.55, 0.0, 1.0)
			im.set_pixel(x, y, Color(0.04, 0.04, 0.05, al * 0.55))
	return {"albedo": _to_tex(im), "normal": null, "rough": null}


# 遠くのビルの窓の格子（3列×4階を1枚に）：9m×12.8m
static func _gen_tower() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var w := 192
	var h := 256
	var a := _noise_img(121, 0.03, 3, w, h)
	_lift(a, 0.8)
	var ov := _blank(w, h)
	for r in 4:
		for c in 3:
			var lit := rng.randf() < 0.18
			var col := Color(0.98, 0.86, 0.55, 0.9) if lit else Color(0.16, 0.22, 0.3, 0.88)
			ov.fill_rect(Rect2i(c * 64 + 10, r * 64 + 14, 44, 34), col)
			ov.fill_rect(Rect2i(c * 64 + 10, r * 64 + 14, 44, 3), Color(0.9, 0.92, 0.95, 0.9))
			ov.fill_rect(Rect2i(c * 64 + 31, r * 64 + 14, 2, 34), Color(0.9, 0.92, 0.95, 0.85))
	a.blend_rect(ov, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return {"albedo": _to_tex(a), "normal": null, "rough": null}


# 事務所の敷物：1枚柄（縁取りと菱形）
static func _gen_rug() -> Dictionary:
	var w := 192
	var h := 128
	var a := _noise_img(131, 0.12, 3, w, h)
	_lift(a, 0.82)
	var ov := _blank(w, h)
	ov.fill_rect(Rect2i(0, 0, w, h), Color(0.62, 0.3, 0.24, 1.0))
	ov.fill_rect(Rect2i(6, 6, w - 12, h - 12), Color(0.9, 0.82, 0.62, 1.0))
	ov.fill_rect(Rect2i(12, 12, w - 24, h - 24), Color(0.31, 0.47, 0.49, 1.0))
	for i in range(0, 6):
		var inset := 22 + i * 4
		ov.fill_rect(Rect2i(inset, inset * 2 / 3 + 6, w - inset * 2, h - (inset * 2 / 3 + 6) * 2), Color(0.31, 0.47, 0.49, 1.0) if i % 2 == 0 else Color(0.82, 0.62, 0.36, 1.0))
	for x in range(18, w - 18, 12):
		ov.fill_rect(Rect2i(x, 8, 4, 2), Color(0.62, 0.3, 0.24, 1.0))
		ov.fill_rect(Rect2i(x, h - 10, 4, 2), Color(0.62, 0.3, 0.24, 1.0))
	a.blend_rect(ov, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return {"albedo": _to_tex(a), "normal": _to_tex(_normal_of(a, 1.5), true), "rough": null}


# ---- マテリアル ----

static func _use(m: StandardMaterial3D, tex_name: String, tile_u: float, tile_v: float, normal_scale := 1.0) -> void:
	var t := _tex(tex_name)
	if t["albedo"] != null:
		m.albedo_texture = t["albedo"]
	if t["normal"] != null:
		m.normal_enabled = true
		m.normal_texture = t["normal"]
		m.normal_scale = normal_scale
	if t["rough"] != null:
		m.roughness_texture = t["rough"]
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_scale = Vector3(1.0 / tile_u, 1.0 / tile_v, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


# マテリアル＋頂点色のひと組。色違いは頂点色で出すので、種類ごとに1つのマテリアルを共有できる（描画回数が増えない）
class Tint extends RefCounted:
	var mat: Material
	var color := Color.WHITE

	func _init(m: Material = null, c: Color = Color.WHITE) -> void:
		mat = m
		color = c


static var _tint_cache: Dictionary = {}


static func _tinted(base: Material, c: Color, key: String) -> Tint:
	var k := key + c.to_html()
	if _tint_cache.has(k):
		return _tint_cache[k]
	var t := Tint.new(base, c)
	_tint_cache[k] = t
	return t


static func _base(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind
	if kind == "lit" or kind == "emit":
		key += tint.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	match kind:
		"asphalt":
			_use(m, "asphalt", 3.2, 3.2, 1.0)
			m.roughness = 1.0
			m.metallic_specular = 0.25
		"concrete":
			_use(m, "concrete", 5.0, 5.0, 0.6)
			m.roughness = 1.0
			m.metallic_specular = 0.3
		"paving":
			_use(m, "paving", 2.0, 2.0, 1.0)
		"block":
			_use(m, "block", 0.8, 0.8, 1.0)
		"metal":
			_use(m, "metal", 1.2, 2.4, 1.0)
			m.roughness = 0.6
			m.metallic = 0.2
		"shutter":
			_use(m, "shutter", 0.5, 0.5, 1.0)
			m.roughness = 0.55
			m.metallic = 0.25
		"floor":
			_use(m, "floor", 1.12, 1.12, 0.8)
			m.roughness = 0.7
		"wood":
			_use(m, "wood", 1.0, 1.0, 0.5)
		"plaster":
			_use(m, "plaster", 3.0, 3.0, 0.25)
		"tower":
			_use(m, "tower", 9.0, 12.8, 1.0)
		"rug":
			_use(m, "rug", 3.0, 2.0, 0.6)
			m.roughness = 1.0
		"paint":
			_use(m, "paint", 0.8, 0.8, 1.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		"stain":
			_use(m, "stain", 1.0, 1.0, 1.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = -1
			m.roughness = 0.6
		"puddle":
			# 浅い水たまり：空の色を薄く映す。縁はでこぼこで、地面になじませる
			_use(m, "puddle", 1.0, 1.0, 1.0)
			m.albedo_color = Color(0.4, 0.47, 0.53)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = -1
			m.roughness = 0.06
			m.metallic_specular = 0.7
		"glass":
			m.albedo_color = Color(0.1, 0.16, 0.21)
			m.roughness = 0.12
			m.metallic = 0.35
		"emit":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = tint
			m.emission_enabled = true
			m.emission = tint
			m.emission_energy_multiplier = 3.0
			m.roughness = 0.5
		"lit":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = tint
			m.emission_enabled = true
			m.emission = tint
			m.emission_energy_multiplier = 1.5
			m.roughness = 0.4
		"leaf":
			# 葉の板：葉の形で抜き、光を少し透かす（逆光で明るく）。両面は Batch.card が2枚貼る
			m.albedo_texture = _tex("leaf")["albedo"]
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.roughness = 1.0
			m.metallic_specular = 0.25
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			m.backlight_enabled = true
			m.backlight = Color(0.3, 0.36, 0.16)
		"grass":
			m.albedo_texture = _tex("grass")["albedo"]
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.roughness = 1.0
			m.metallic_specular = 0.2
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			m.backlight_enabled = true
			m.backlight = Color(0.3, 0.36, 0.16)
		"foliage":
			# 茂みの芯：葉のすき間から見える奥の暗がり。やわらかく照らす
			m.roughness = 1.0
			m.metallic_specular = 0.15
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		"cloth":
			_use(m, "plaster", 1.0, 1.0, 0.2)
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			_use(m, "plaster", 2.0, 2.0, 0.3)
	_mat_cache[key] = m
	return m


# 種類（テクスチャ付き）と色。色は頂点色で掛かる
static func mat(kind: String, tint: Color = Color.WHITE) -> Tint:
	var base := _base(kind, tint)
	var c := Color.WHITE if (kind == "lit" or kind == "emit") else tint
	return _tinted(base, c, kind + (tint.to_html() if (kind == "lit" or kind == "emit") else ""))


# 色指定だけの手軽なマテリアル（塗装のムラつき）
static func plain(c: Color, rough := 0.85, metal := 0.0) -> Tint:
	var key := "plain%.2f_%.2f" % [rough, metal]
	var base: StandardMaterial3D
	if _mat_cache.has(key):
		base = _mat_cache[key]
	else:
		base = StandardMaterial3D.new()
		base.vertex_color_use_as_albedo = true
		base.vertex_color_is_srgb = true
		_use(base, "plaster", 2.0, 2.0, 0.3)
		base.roughness = rough
		base.metallic = metal
		_mat_cache[key] = base
	return _tinted(base, c, key)


# ---- 形をまとめて1つのメッシュにする入れ物 ----

class Surf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var u := PackedVector2Array()
	var i := PackedInt32Array()
	var c := PackedColorArray()


class Batch extends RefCounted:
	const F_PX := 1
	const F_NX := 2
	const F_PY := 4
	const F_NY := 8
	const F_PZ := 16
	const F_NZ := 32
	const ALL := 63
	const GROUND := 55            # 底面なし（地面に置く物）
	const FACADE := 23            # 手前(+Z)・上・左右だけ（壁に貼る物）
	const FACES := [[Vector3.RIGHT, Vector3.UP], [Vector3.LEFT, Vector3.UP], [Vector3.UP, Vector3.FORWARD],
			[Vector3.DOWN, Vector3.BACK], [Vector3.BACK, Vector3.UP], [Vector3.FORWARD, Vector3.UP]]

	var surfaces: Dictionary = {}
	var solids: Array = []        # [Transform3D, Vector3] 当たり判定の箱
	var xf := Transform3D.IDENTITY   # 以降に足す形すべてへ掛ける変換（建物ごとの向き用）
	var no_shadow := false

	var _col := Color.WHITE

	func _surf(t: Tint) -> Surf:
		var s: Surf = surfaces.get(t.mat)
		if s == null:
			s = Surf.new()
			surfaces[t.mat] = s
		_col = t.color
		return s

	# 多角形（表から見て反時計回りに並べる）。axes を渡すと UV の向きを指定できる（rel で最初の点を原点にする）
	func poly(m: Tint, pts: Array, nrm := Vector3.ZERO, axes: Array = [], rel := false) -> void:
		var s := _surf(m)
		var p0: Vector3 = pts[0]
		var n := nrm
		if n == Vector3.ZERO:
			n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
		var e1: Vector3
		var e2: Vector3
		if axes.size() == 2:
			e1 = axes[0]
			e2 = axes[1]
		elif absf(n.y) > 0.9:
			e1 = Vector3.RIGHT
			e2 = Vector3.BACK
		else:
			e1 = Vector3.UP.cross(n).normalized()
			e2 = n.cross(e1)
		var w := 1.0 if n.cross(e1).dot(-e2) > 0.0 else -1.0
		var o := p0 if rel else Vector3.ZERO
		var base := s.v.size()
		for p: Vector3 in pts:
			s.v.append(p)
			s.c.append(_col)
			s.n.append(n)
			s.u.append(Vector2((p - o).dot(e1), (p - o).dot(e2)))
			s.t.append(e1.x)
			s.t.append(e1.y)
			s.t.append(e1.z)
			s.t.append(w)
		for k in range(1, pts.size() - 1):
			s.i.append(base)
			s.i.append(base + k + 1)
			s.i.append(base + k)

	# 向きの目安（外向き）に合わせて、必要なら点の順を逆にして貼る
	func poly_out(m: Tint, pts: Array, outward: Vector3, axes: Array = [], rel := false) -> void:
		var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
		if n.dot(outward) < 0.0:
			var r: Array = pts.duplicate()
			r.reverse()
			poly(m, r, -n, axes, rel)
		else:
			poly(m, pts, n, axes, rel)

	# 箱（中心が xf_local の原点）。mask で貼る面を選ぶ
	func box(m: Tint, at: Transform3D, size: Vector3, mask := GROUND) -> void:
		var t := xf * at
		var h := size * 0.5
		for k in 6:
			if mask & (1 << k) == 0:
				continue
			var n: Vector3 = FACES[k][0]
			var u: Vector3 = FACES[k][1]
			var r := u.cross(n)
			var hn := absf(n.dot(h))
			var hr := r.abs().dot(h)
			var hu := u.abs().dot(h)
			var c := n * hn
			var pts := [t * (c - r * hr - u * hu), t * (c + r * hr - u * hu), t * (c + r * hr + u * hu), t * (c - r * hr + u * hu)]
			poly(m, pts, (t.basis * n).normalized())

	func boxp(m: Tint, pos: Vector3, size: Vector3, mask := GROUND) -> void:
		box(m, Transform3D(Basis.IDENTITY, pos), size, mask)

	func boxy(m: Tint, pos: Vector3, size: Vector3, yaw: float, mask := GROUND) -> void:
		box(m, Transform3D(Basis(Vector3.UP, yaw), pos), size, mask)

	# 2点をつなぐ細い棒（脚・フレーム・ケーブル）。両端の面は貼らない（mask 15）
	func bar(m: Tint, p: Vector3, q: Vector3, th: float, mask := 15) -> void:
		var d := q - p
		var ln := d.length()
		if ln < 0.001:
			return
		var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		box(m, Transform3D(Basis.looking_at(d, up), (p + q) * 0.5), Vector3(th, th, ln), mask)

	# 当たり判定の箱を追加（見た目は別に足す）
	func solid(at: Transform3D, size: Vector3) -> void:
		solids.append([xf * at, size])

	func solidp(pos: Vector3, size: Vector3) -> void:
		solid(Transform3D(Basis.IDENTITY, pos), size)

	# 柱・円筒・円錐。原点は底の中心。r_top < 0 で同じ半径
	func cyl(m: Tint, at: Transform3D, radius: float, height: float, segs := 10, r_top := -1.0, cap_top := true, cap_bottom := false) -> void:
		var t := xf * at
		var rt := radius if r_top < 0.0 else r_top
		var ring_b: Array = []
		var ring_t: Array = []
		for k in segs:
			var a := TAU * k / segs
			ring_b.append(Vector3(cos(a) * radius, 0.0, -sin(a) * radius))
			ring_t.append(Vector3(cos(a) * rt, height, -sin(a) * rt))
		for k in segs:
			var k2 := (k + 1) % segs
			var a1 := TAU * k / segs
			var a2 := TAU * k2 / segs
			var n1 := t.basis * Vector3(cos(a1), 0.0, -sin(a1))
			var n2 := t.basis * Vector3(cos(a2), 0.0, -sin(a2))
			var slope := (radius - rt) / maxf(height, 0.001)
			n1 = (n1 + t.basis * Vector3(0, slope, 0)).normalized()
			n2 = (n2 + t.basis * Vector3(0, slope, 0)).normalized()
			var pts := [t * ring_b[k], t * ring_b[k2], t * ring_t[k2], t * ring_t[k]]
			_quad_smooth(m, pts, [n1, n2, n2, n1])
		if cap_top and rt > 0.001:
			var top: Array = []
			for k in segs:
				top.append(t * ring_t[k])
			poly_out(m, top, t.basis * Vector3.UP)
		if cap_bottom:
			var bot: Array = []
			for k in segs:
				bot.append(t * ring_b[k])
			poly_out(m, bot, t.basis * Vector3.DOWN)

	func cylp(m: Tint, pos: Vector3, radius: float, height: float, segs := 10, r_top := -1.0) -> void:
		cyl(m, Transform3D(Basis.IDENTITY, pos), radius, height, segs, r_top)

	func _quad_smooth(m: Tint, pts: Array, nrms: Array) -> void:
		var s := _surf(m)
		var e1: Vector3 = (pts[1] - pts[0]).normalized()
		var base := s.v.size()
		for k in 4:
			s.v.append(pts[k])
			s.c.append(_col)
			s.n.append(nrms[k])
			s.u.append(Vector2((pts[k] as Vector3).dot(e1), (pts[k] as Vector3).y))
			s.t.append(e1.x)
			s.t.append(e1.y)
			s.t.append(e1.z)
			s.t.append(1.0)
		s.i.append(base)
		s.i.append(base + 2)
		s.i.append(base + 1)
		s.i.append(base)
		s.i.append(base + 3)
		s.i.append(base + 2)

	# 断面（XY平面の凸多角形）をZ方向に押し出した形（切妻屋根・鋸屋根など）。原点は断面の原点、Zは中央
	func extrude(m: Tint, at: Transform3D, profile: Array, length: float) -> void:
		var t := xf * at
		var hz := length * 0.5
		var cen := Vector2.ZERO
		for p: Vector2 in profile:
			cen += p
		cen /= profile.size()
		var c3 := t * Vector3(cen.x, cen.y, 0.0)
		var front: Array = []
		var back: Array = []
		for p: Vector2 in profile:
			front.append(t * Vector3(p.x, p.y, hz))
			back.append(t * Vector3(p.x, p.y, -hz))
		poly_out(m, front, t.basis * Vector3.BACK)
		poly_out(m, back, t.basis * Vector3.FORWARD)
		for k in profile.size():
			var k2 := (k + 1) % profile.size()
			var quad := [front[k], front[k2], back[k2], back[k]]
			var mid: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
			poly_out(m, quad, mid - c3)

	# 上向きの平らな帯（a→b、幅 w、高さ y）。UV は長さ方向が u
	func strip(m: Tint, a: Vector3, b: Vector3, w: float, y: float) -> void:
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var dn := d.normalized()
		var side := Vector3(-dn.z, 0.0, dn.x) * (w * 0.5)
		var pts := [Vector3(a.x, y, a.z) - side, Vector3(b.x, y, b.z) - side, Vector3(b.x, y, b.z) + side, Vector3(a.x, y, a.z) + side]
		poly_out(m, pts.map(func(p: Vector3) -> Vector3: return xf * p), Vector3.UP, [dn, side.normalized()])

	# 地面の板（軸に沿った長方形。ワールド座標でUV）
	func quad_up(m: Tint, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
		var pts := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
		poly_out(m, pts.map(func(p: Vector3) -> Vector3: return xf * p), Vector3.UP)

	# 中心から広がる円盤（にじみ・染み）。UV は 0..1 で中心が 0.5
	func blob(m: Tint, c: Vector3, rx: float, rz: float, yaw: float, rng: RandomNumberGenerator = null, segs := 14, jitter := 0.0) -> void:
		var s := _surf(m)
		var base := s.v.size()
		var ctr := xf * c
		s.v.append(ctr)
		s.c.append(_col)
		s.n.append(Vector3.UP)
		s.u.append(Vector2(0.5, 0.5))
		for q in [1.0, 0.0, 0.0, 1.0]:
			s.t.append(q)
		var bs := Basis(Vector3.UP, yaw)
		for k in segs:
			var a := TAU * k / segs
			var jr := 1.0 + (rng.randf_range(-jitter, jitter) if rng != null else 0.0)
			var local := Vector3(cos(a) * rx * jr, 0.0, -sin(a) * rz * jr)
			s.v.append(xf * (c + bs * local))
			s.c.append(_col)
			s.n.append(Vector3.UP)
			s.u.append(Vector2(0.5 + 0.5 * cos(a) * jr, 0.5 - 0.5 * sin(a) * jr))
			for q in [1.0, 0.0, 0.0, 1.0]:
				s.t.append(q)
		for k in segs:
			s.i.append(base)
			s.i.append(base + 1 + (k + 1) % segs)
			s.i.append(base + 1 + k)

	# 葉の板：中心 c、右 r・上 u は半分の長さ。表裏の2枚を貼り、どちらも同じ法線 n で照らす
	# （n を茂み全体の中心から外向きにすると、板の集まりがひとかたまりのふわっとした茂みに見える）
	func card(m: Tint, c: Vector3, r: Vector3, u: Vector3, n: Vector3, col: Color) -> void:
		var s := _surf(m)
		var pts := [xf * (c - r - u), xf * (c + r - u), xf * (c + r + u), xf * (c - r + u)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var nn := (xf.basis * n).normalized()
		var tg := (xf.basis * r).normalized()
		for side in 2:
			var base := s.v.size()
			for k in 4:
				s.v.append(pts[k])
				s.c.append(col)
				s.n.append(nn)
				s.u.append(uvs[k])
				s.t.append(tg.x)
				s.t.append(tg.y)
				s.t.append(tg.z)
				s.t.append(1.0)
			if side == 0:
				s.i.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
			else:
				s.i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	# 丸い芯（中心 c、半径 rad）。少しこぶを付け、法線は from から外向き。下ほど暗く（dark：いちばん下の暗さ）
	func lump(m: Tint, c: Vector3, rad: Vector3, from: Vector3, rng: RandomNumberGenerator, dark := 0.45, rings := 6, segs := 10, wob := 0.12) -> void:
		var s := _surf(m)
		var col := _col
		var base := s.v.size()
		var bumps: Array = []
		for k in 5:
			bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(-wob, wob)])
		for i in rings + 1:
			var th := PI * i / rings
			for j in segs + 1:
				var ph := TAU * j / segs
				var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var f := 1.0
				for bp: Array in bumps:
					f += float(bp[1]) * maxf((bp[0] as Vector3).dot(d), 0.0) * 2.0
				var p := c + Vector3(d.x * rad.x, d.y * rad.y, d.z * rad.z) * f
				s.v.append(xf * p)
				s.n.append((xf.basis * (p - from)).normalized())
				s.c.append(col.darkened((1.0 - (d.y + 1.0) * 0.5) * dark))
				s.u.append(Vector2(float(j) / segs, float(i) / rings))
				var tg := Vector3(-sin(ph), 0.0, cos(ph))
				s.t.append(tg.x)
				s.t.append(tg.y)
				s.t.append(tg.z)
				s.t.append(1.0)
		for i in rings:
			for j in segs:
				var a := base + i * (segs + 1) + j
				var b2 := a + segs + 1
				s.i.append_array([a, b2 + 1, a + 1, a, b2, b2 + 1])

	func build(parent: Node, nm: String) -> Node3D:
		var out := Node3D.new()
		out.name = nm
		parent.add_child(out)
		if not surfaces.is_empty():
			var mesh := ArrayMesh.new()
			for m: Material in surfaces:
				var s: Surf = surfaces[m]
				var arr := []
				arr.resize(Mesh.ARRAY_MAX)
				arr[Mesh.ARRAY_VERTEX] = s.v
				arr[Mesh.ARRAY_NORMAL] = s.n
				arr[Mesh.ARRAY_COLOR] = s.c
				arr[Mesh.ARRAY_TANGENT] = s.t
				arr[Mesh.ARRAY_TEX_UV] = s.u
				arr[Mesh.ARRAY_INDEX] = s.i
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				mesh.surface_set_material(mesh.get_surface_count() - 1, m)
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = mesh
			if no_shadow:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			out.add_child(mi)
		if not solids.is_empty():
			var body := StaticBody3D.new()
			body.name = "Solid"
			body.collision_layer = 1
			body.collision_mask = 0
			out.add_child(body)
			for sd: Array in solids:
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = sd[1]
				cs.shape = bs
				cs.transform = sd[0]
				body.add_child(cs)
		return out
