extends "res://scripts/paint_board.gd"
# 段ボール板：段ボール箱をたたんで平らにした物（features/spray_sign.gd）。表（+Z）にスプレーで描ける。
# 板は立てた向き（横 SIZE.x・縦 SIZE.y・厚み THICK）。裏と縁は、段ボール箱の素材の面をそのまま使う。
# 描く仕組み（ink・同期）は paint_board.gd。カンペ・等身大パネルと同じに cue_cards.gd に登録して、絵を全員へ配る
const CARTON := preload("res://assets/gear/carton.glb")
# 段ボール箱をたたんだ形：2枚重ね・左右の丸い折り目・フラップの切れ込み・折り筋・切り口の中芯・はがしたテープ・少しの反り。
# 表の面は素材名 PaintFace（全面に UV 0〜1）。ほかの面の素材名は carton.glb と同じで、読み込み時に差し替える。
# 作り直し：blender -b --python build_cardboard_sheet.py
const SHEET_MODEL := preload("res://assets/gear/cardboard_sheet.glb")
static var _carton_mats := {}
const SIZE := Vector2(1.1, 0.74)
const THICK := 0.02
const RESOLUTION := Vector2i(704, 474)
const BASE := Color(0.72, 0.55, 0.36)        # 段ボールの地の色（スプレーの絵の下地）


func build() -> void:
	kind = "cardboard"
	label = "段ボール板"
	mass = 1.2
	visual = Node3D.new()
	add_child(visual)
	# たたんだ段ボール箱の形（下の真ん中が原点、表が +Z）。表以外の面は、段ボール箱と同じ素材にする
	var model: Node3D = SHEET_MODEL.instantiate()
	visual.add_child(model)
	_use_carton_materials(model)
	# 表：スプレーの絵（地の色から始まる）。PaintFace の面に映す（照明を受ける）
	make_ink(RESOLUTION)
	ink.fill(BASE)
	texture.update(ink)
	bind_surface(model, "PaintFace", true)
	_paper_relief()
	center = Vector3(0, SIZE.y * 0.5, 0)
	half = Vector3(SIZE.x * 0.5, SIZE.y * 0.5, THICK * 0.5 + 0.004)
	hold_min = 1.3
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	collider.shape = shape
	collider.position = center
	add_child(collider)
	_refresh()


# 段ボール箱（carton.glb）の素材を、素材名で引けるように集める（1回だけ）
static func _carton_materials() -> Dictionary:
	if _carton_mats.is_empty():
		var model: Node3D = CARTON.instantiate()
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(i)
				if m != null and not _carton_mats.has(m.resource_name):
					_carton_mats[m.resource_name] = m
		model.free()
	return _carton_mats


static func _use_carton_materials(root: Node3D) -> void:
	var mats := _carton_materials()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(i)
			if m != null and mats.has(m.resource_name):
				mi.set_surface_override_material(i, mats[m.resource_name])


# 表（スプレーの面）に、段ボール箱の紙と同じ凹凸とザラつきを重ねる（色は描いた絵のまま）
func _paper_relief() -> void:
	if surface == null or _ink_surface < 0:
		return
	var face := surface.get_surface_override_material(_ink_surface) as StandardMaterial3D
	var kraft := _carton_materials().get("01 • outer kraft liner / uncoated.001") as StandardMaterial3D
	if face == null or kraft == null:
		return
	face.normal_enabled = kraft.normal_enabled
	face.normal_texture = kraft.normal_texture
	face.normal_scale = kraft.normal_scale
	face.roughness = 1.0
	face.roughness_texture = kraft.roughness_texture
	face.roughness_texture_channel = kraft.roughness_texture_channel


static func _carton_material() -> Material:
	var model: Node3D = CARTON.instantiate()
	var out: Material = null
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Body" and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			out = mi.get_active_material(0)
			break
	model.free()
	return out


# 表の点（この物の座標）→ 絵のピクセル。表から外れていれば null
func pixel_at(local: Vector3) -> Variant:
	var u := (local.x + SIZE.x * 0.5) / SIZE.x
	var v := 1.0 - local.y / SIZE.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0 or local.z < 0.0:
		return null
	return Vector2(u * float(res.x - 1), v * float(res.y - 1))


# ---- スプレーの跡（docs/production/spray-paint-study.md） ----
const CELL := 20                 # 垂れを数える升目（ピクセル）
const DRIP_AT := 9.0             # 升目に溜まった塗料がこれを超えると、下へ垂れる
const DOTS_PER_POINT := 240      # 1回分（1コマ分）に出る粒の数
const DOT_ALPHA := 0.5           # 1粒の濃さ（同じ所に重なるほど濃くなる）
const DOT_R := 2                 # 1粒の丸の半径（ピクセル）
var _wet := {}                   # 升目 → 溜まった塗料の量


# 吹いた跡を描く（全員の画面で同じに描く。粒のまき方は seed で決まる）。
# points：吹いた所のピクセル、spreads：その時の広がり（ガウスの幅。ピクセル）。点と点の間は埋める
func spray(points: PackedVector2Array, spreads: PackedFloat32Array, color: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in points.size():
		var to: Vector2 = points[i]
		var sigma: float = spreads[mini(i, spreads.size() - 1)]
		var from: Vector2 = points[i - 1] if i > 0 else to
		var steps := maxi(1, int(ceil(from.distance_to(to) / maxf(1.0, sigma * 0.3))))
		# 1回分（1コマ分）に出る塗料の量は一定。間を埋めるときは、その量を分けて配る（素早く動かすと線が薄くなる）
		var share := maxi(4, DOTS_PER_POINT / steps)
		for k in range(1 if i > 0 else 0, steps + 1):
			_dab(from.lerp(to, float(k) / float(steps)), sigma, color, rng, share)
	_refresh()


# 1回の吹き：ガウス分布の細かい粒の集まり。真ん中ほど詰まって濃く、外はまばら（柔らかい縁と飛び散り）
func _dab(c: Vector2, sigma: float, color: Color, rng: RandomNumberGenerator, count: int) -> void:
	var strength := DOT_ALPHA * clampf(9.0 / sigma, 0.3, 1.0)      # 遠い（広い）ほど、1粒は薄い
	for j in count:
		var r := sigma * sqrt(-2.0 * log(maxf(rng.randf(), 0.000001)))
		var a := rng.randf() * TAU
		var x := int(c.x + cos(a) * r)
		var y := int(c.y + sin(a) * r)
		# 1粒は小さな丸（真ん中が濃く、縁が薄い）。重なってなめらかにつながる
		for dy in range(-DOT_R, DOT_R + 1):
			var py := y + dy
			if py < 0 or py >= res.y:
				continue
			for dx in range(-DOT_R, DOT_R + 1):
				var px := x + dx
				if px < 0 or px >= res.x:
					continue
				var fall := 1.0 - float(dx * dx + dy * dy) / float((DOT_R + 1) * (DOT_R + 1))
				if fall <= 0.0:
					continue
				ink.set_pixel(px, py, ink.get_pixel(px, py).lerp(color, strength * fall))
	# 溜まった量（細く近く吹くほど、早く溜まる）。超えたら垂れる
	var cell := Vector2i(int(c.x) / CELL, int(c.y) / CELL)
	var wet: float = float(_wet.get(cell, 0.0)) + float(count) * strength * 0.04 / maxf(1.0, sigma)
	if wet > DRIP_AT:
		_drip(c, sigma, color, rng)
		wet = 0.0
	_wet[cell] = wet


# 垂れ：溜まった所から下へ、細くなりながら伸びて、先に小さな玉ができて止まる
func _drip(c: Vector2, sigma: float, color: Color, rng: RandomNumberGenerator) -> void:
	var length := rng.randf_range(28.0, 74.0)
	var width := clampf(sigma * 0.22, 1.2, 3.2)
	var x0 := c.x + rng.randf_range(-sigma * 0.4, sigma * 0.4)
	for t in int(length):
		var w := width * (1.0 - 0.35 * float(t) / length)
		var y := int(c.y + float(t))
		if y >= res.y:
			return
		var x := x0 + sin(float(t) * 0.15) * 0.6
		for dx in range(int(floor(x - w)), int(ceil(x + w)) + 1):
			if dx >= 0 and dx < res.x:
				ink.set_pixel(dx, y, ink.get_pixel(dx, y).lerp(color, 0.85))
	var end := Vector2(x0, c.y + length)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var px := Vector2i(int(end.x) + dx, int(end.y) + dy)
			if px.x >= 0 and px.y >= 0 and px.x < res.x and px.y < res.y and Vector2(dx, dy).length() <= width + 1.2:
				ink.set_pixel(px.x, px.y, ink.get_pixel(px.x, px.y).lerp(color, 0.9))


# 絵のピクセル → 表の点（世界の座標）
func world_at(px: Vector2) -> Vector3:
	var local := Vector3((px.x / float(res.x - 1) - 0.5) * SIZE.x, (1.0 - px.y / float(res.y - 1)) * SIZE.y, THICK * 0.5)
	return global_transform * local


# スプレーで描いた所の割合（0〜1）。地の色は数えない（濃い色＝黒・赤・白で吹いた所だけ）
func painted() -> float:
	if _painted < 0.0:
		var hit := 0
		var total := 0
		for y in range(3, res.y, 6):
			for x in range(3, res.x, 6):
				total += 1
				if _sprayed(ink.get_pixel(x, y)):
					hit += 1
		_painted = float(hit) / maxf(1.0, total)
	return _painted


static func _sprayed(c: Color) -> bool:
	return absf(c.r - BASE.r) + absf(c.g - BASE.g) + absf(c.b - BASE.b) > 0.25
