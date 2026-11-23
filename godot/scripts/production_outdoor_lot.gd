extends RefCounted
## 土の空き地と、北のフェンス越しに見える工事現場。
const Look := preload("res://scripts/production_look.gd")
const Foliage := preload("res://scripts/foliage.gd")
const SOIL := preload("res://shaders/location_soil.gdshader")
const GRASS_WIND := preload("res://shaders/location_grass_wind.gdshader")
const CAMERA_FAR := 400.0


static func build(root: Node3D) -> void:
	var ground := Look.Batch.new()
	var soil := ShaderMaterial.new()
	soil.shader = SOIL
	ground.boxp(Look.Tint.new(soil, Color.WHITE), Vector3(-6, -0.235, -9), Vector3(68, 0.48, 78))
	ground.solidp(Vector3(-6, -0.235, -9), Vector3(68, 0.48, 78))
	ground.boxp(Look.mat("asphalt", Color("8c8981")), Vector3(16, 0.01, 6.5), Vector3(11.8, 0.03, 17.5))
	ground.build(root, "DirtLot")
	_grass(root)
	_pipes(root)
	_construction(root)
	_horizon(root)
	_neighborhood(root)
	_planting(root)


static func _grass(root: Node3D) -> void:
	var batch := Look.Batch.new()
	var grass_material := ShaderMaterial.new()
	grass_material.shader = GRASS_WIND
	var grass_source := Look.mat("grass").mat as StandardMaterial3D
	grass_material.set_shader_parameter("grass_texture", grass_source.albedo_texture)
	var grass := Look.Tint.new(grass_material)
	var rng := RandomNumberGenerator.new()
	rng.seed = 132
	# 草は外周と土管の根元へ寄せ、中央と搬入側は歩きやすい土のままにする。
	var patches := [Vector4(-20, -2, 1.8, 14), Vector4(0, 16, 19, 1.4),
			Vector4(-5, -16.5, 15, 1.4), Vector4(-12, -7, 4.0, 1.8),
			Vector4(19, -11, 2.0, 3.5)]
	for patch in patches:
		for clump in 70:
			var spot := Vector3(patch.x + rng.randf_range(-patch.z, patch.z), 0.02,
					patch.y + rng.randf_range(-patch.w, patch.w))
			var height := rng.randf_range(0.12, 0.40)
			var width := rng.randf_range(0.16, 0.42)
			var color := Color("707f46").lerp(Color("a0a16a"), rng.randf())
			for angle in [0.35, 1.92]:
				var right := Vector3(cos(angle), 0, sin(angle))
				batch.card(grass, spot + Vector3.UP * height * 0.5, right * width * 0.5,
						Vector3.UP * height * 0.5, right.cross(Vector3.UP), color)
	batch.build(root, "LotGrass").add_to_group("location_wind_grass")


static func _pipes(root: Node3D) -> void:
	var batch := Look.Batch.new()
	var concrete := Look.mat("concrete", Color("a8aaa0"))
	var bore := Look.mat("concrete", Color("777f77"))
	# 各土管は、内壁・外壁・端面がつながった中空のメッシュ。穴の内側にも当たり判定がある。
	var pipes := [
		Transform3D(Basis(Vector3.UP, 0.24), Vector3(-11.8, 1.07, -7.3)),
		Transform3D(Basis(Vector3.UP, -0.36), Vector3(-15.0, 0.83, -6.15)),
	]
	for i in pipes.size():
		var xf: Transform3D = pipes[i]
		var outer := xf.origin.y
		var inner := outer - 0.13
		var half := 1.4 if i == 0 else 1.10
		for segment in 40:
			var a := TAU * segment / 40.0
			var b := TAU * (segment + 1) / 40.0
			var da := Vector3(cos(a), sin(a), 0)
			var db := Vector3(cos(b), sin(b), 0)
			var along := Vector3.BACK * half
			var ofa := xf * (da * outer + along)
			var ofb := xf * (db * outer + along)
			var oba := xf * (da * outer - along)
			var obb := xf * (db * outer - along)
			var ifa := xf * (da * inner + along)
			var ifb := xf * (db * inner + along)
			var iba := xf * (da * inner - along)
			var ibb := xf * (db * inner - along)
			batch.poly_out(concrete, [ofa, oba, obb, ofb], xf.basis * (da + db))
			batch.poly_out(bore, [ifa, iba, ibb, ifb], xf.basis * -(da + db))
			batch.poly_out(concrete, [ofa, ofb, ifb, ifa], xf.basis.z)
			batch.poly_out(concrete, [oba, obb, ibb, iba], -xf.basis.z)
	var built := batch.build(root, "ConcreteDrainPipes")
	var mesh := built.get_node("Mesh") as MeshInstance3D
	mesh.create_trimesh_collision()


static func _construction(root: Node3D) -> void:
	var batch := Look.Batch.new()
	var concrete := Look.mat("concrete", Color("a9a89b"))
	var steel := Look.mat("metal", Color("727b7e"))
	var panel := Look.mat("metal", Color("d8d9cd"))
	var green := Look.mat("metal", Color("617b71"))
	var timber := Look.mat("wood", Color("a98a64"))
	# 仮囲いは外周の北側。手前に土の空き地、奥に建設途中の二層の躯体が見える。
	for bay in 18:
		var x := -20.9 + bay * 1.35
		batch.boxp(panel, Vector3(x, 1.08, -17.90), Vector3(1.33, 1.97, 0.10))
		batch.boxp(green, Vector3(x, 0.22, -17.84), Vector3(1.33, 0.23, 0.05))
		batch.boxp(steel, Vector3(x - 0.66, 1.06, -17.82), Vector3(0.048, 2.0, 0.056))
	batch.boxp(steel, Vector3(-9.43, 2.08, -17.85), Vector3(24.32, 0.09, 0.15))
	for y in [0.16, 3.13, 6.16]:
		batch.boxp(concrete, Vector3(-7.0, y, -28.0), Vector3(19.0, 0.30, 9.0))
	for x in [-16.0, -10.0, -4.0, 2.0]:
		for z in [-24.0, -32.0]:
			batch.boxp(concrete, Vector3(x, 3.15, z), Vector3(0.60, 6.1, 0.60))
			for offset in [-0.16, 0.16]:
				batch.cylp(steel, Vector3(x + offset, 6.28, z), 0.019, 0.55)
	batch.boxp(concrete, Vector3(-11.5, 3.15, -31.9), Vector3(8.6, 5.7, 0.24))
	for bay in 8:
		var x := -16.0 + bay * 2.28
		for z in [-22.7, -21.2]:
			batch.cylp(steel, Vector3(x, 0, z), 0.045, 6.60)
			for y in [1.9, 4.0]:
				batch.bar(steel, Vector3(x, y, z), Vector3(x + 2.28, y + 1.7, z), 0.037)
				batch.bar(steel, Vector3(x, y + 0.39, z), Vector3(x + 2.28, y + 0.39, z), 0.045)
		for y in [1.86, 3.95, 5.98]:
			batch.boxp(timber, Vector3(x + 1.14, y, -21.95), Vector3(2.28, 0.08, 1.23))
	for z in [-22.7, -21.2]:
		batch.cylp(steel, Vector3(2.24, 0, z), 0.045, 6.60)
	for z in [-23.2, -26.0, -28.8]:
		for i in 3:
			batch.boxy(timber, Vector3(7.2, 0.14 + i * 0.13, z), Vector3(3.4, 0.10, 0.8), 0.14)
	batch.build(root, "ConstructionNextDoor")
	_construction_safety(root)


static func _construction_safety(root: Node3D) -> void:
	var batch := Look.Batch.new()
	var yellow := Look.plain(Color("f1c435"))
	var black := Look.plain(Color("292c2b"))
	var white := Look.plain(Color("f5f1dd"))
	var orange := Look.plain(Color("d95624"))
	var frame := Look.mat("metal", Color("515b55"))
	var sign_font := preload("res://assets/fonts/DelaGothicOne-Regular.ttf")
	# 仮囲いと一体の看板。地面から伸びる看板や浮いた文字は使わない。
	var sign_at := Vector3(-8.8, 1.27, -17.79)
	batch.boxp(frame, sign_at, Vector3(3.14, 1.37, 0.12))
	batch.boxp(white, sign_at + Vector3(0, 0, 0.065), Vector3(3.03, 1.25, 0.02))
	batch.boxp(yellow, sign_at + Vector3(0, 0.24, 0.08), Vector3(3.03, 0.67, 0.02))
	Look.label(root, Transform3D(Basis.IDENTITY, sign_at + Vector3(0, 0.23, 0.094)),
			"工事中", 0.0052, 102, Color("252925"), sign_font, false)
	Look.label(root, Transform3D(Basis.IDENTITY, sign_at + Vector3(0, -0.31, 0.079)),
			"関係者以外 立入禁止", 0.0026, 88, Color("252925"), sign_font, false)
	for x in [-16.8, -3.8, 0.65]:
		# 黒い斜線は黄色の横桟の面に合わせ、両端からはみ出さない。
		_hazard_rail(batch, Vector3(x, 0.79, -17.72), yellow, black)
		for dx in [-1.46, 1.46]:
			batch.boxp(frame, Vector3(x + dx, 0.39, -17.70), Vector3(0.075, 0.78, 0.08))
			batch.boxp(frame, Vector3(x + dx, 0.04, -17.70), Vector3(0.19, 0.08, 0.32))
	# カラーコーンは柵の切り替わりから資材置き場へ続く。帯は円錐の形状に沿う。
	for p in [Vector3(3.25, 0.005, -17.53), Vector3(5.7, 0.005, -18.7),
			Vector3(7.1, 0.005, -19.9), Vector3(9.4, 0.005, -20.4)]:
		batch.boxy(black, p + Vector3.UP * 0.035, Vector3(0.50, 0.07, 0.50), 0.22)
		batch.cylp(orange, p + Vector3.UP * 0.07, 0.20, 0.23, 12, 0.145)
		batch.cylp(white, p + Vector3.UP * 0.30, 0.145, 0.14, 12, 0.111)
		batch.cylp(orange, p + Vector3.UP * 0.44, 0.111, 0.28, 12, 0.043)
	batch.build(root, "ConstructionSafety")


static func _hazard_rail(batch: Look.Batch, at: Vector3, yellow: Look.Tint, black: Look.Tint) -> void:
	batch.boxp(yellow, at, Vector3(3.42, 0.24, 0.13))
	for stripe in 7:
		var x := -1.59 + stripe * 0.45
		var face := at + Vector3(x, 0, 0.066)
		batch.poly_out(black, [face + Vector3(0, -0.12, 0), face + Vector3(0.21, -0.12, 0),
				face + Vector3(0.42, 0.12, 0), face + Vector3(0.21, 0.12, 0)], Vector3.BACK)


static func _horizon(root: Node3D) -> void:
	# 家並みの切れ間や高い撮影位置からも、地面の終端が空に抜けないようにする。
	# 遠景は起伏と頂点色だけの一枚のメッシュ。手前と同じ環境の霧がかかる。
	var batch := Look.Batch.new()
	batch.no_shadow = true
	batch.boxp(Look.mat("concrete", Color("a6a08e")), Vector3(0, -0.16, 0),
			Vector3(600, 0.02, 600), Look.Batch.F_PY)
	var land := Look.mat("foliage")
	var slopes := [Color("8d9c84"), Color("82957f"), Color("748d7b"),
			Color("899f92"), Color("799588"), Color("8fa8a0")]
	var radii := [90.0, 118.0, 150.0, 182.0, 225.0, 280.0, 330.0]
	var mesh_rings: Array[PackedVector3Array] = []
	var segments := 112
	for ring in radii.size():
		var loop := PackedVector3Array()
		for i in segments:
			var angle := i * TAU / segments
			var bend := 10.0 * sin(3.0 * angle + 0.3) + 5.0 * cos(7.0 * angle)
			var low_hills := 17.5 + 4.5 * sin(5.0 * angle + 0.85) + 3.8 * sin(8.0 * angle - 0.5)
			var far_hills := 28.5 + 7.0 * sin(4.0 * angle + 2.1) + 5.5 * cos(9.0 * angle + 0.4)
			var heights := [-0.155, 4.1, low_hills, 8.0, far_hills, 15.5, 4.2]
			var radius: float = radii[ring] + bend
			loop.append(Vector3(cos(angle) * radius, heights[ring], sin(angle) * radius))
		mesh_rings.append(loop)
	for ring in mesh_rings.size() - 1:
		var near := mesh_rings[ring]
		var far := mesh_rings[ring + 1]
		for i in segments:
			var j := (i + 1) % segments
			var tint: Color = slopes[ring].lightened(0.023 * sin(i * TAU / segments * 11.0))
			batch.poly_out(Look.Tint.new(land.mat, tint), [near[i], far[i], far[j]], Vector3.UP)
			batch.poly_out(Look.Tint.new(land.mat, tint), [near[i], far[j], near[j]], Vector3.UP)
	# 西・北・南では、家並みの奥と丘の間にまとまった樹冠を置く。東側には既存の街区がある。
	var rng := RandomNumberGenerator.new()
	rng.seed = 401
	for i in 54:
		var angle := lerpf(0.26 * PI, 1.74 * PI, float(i) / 53.0)
		var radius := rng.randf_range(76.0, 89.0)
		var center := Vector3(cos(angle) * radius, rng.randf_range(1.4, 3.0), sin(angle) * radius)
		var tint := Color("667e66").lerp(Color("85977a"), rng.randf())
		var canopy := Vector3(rng.randf_range(3.4, 5.6), rng.randf_range(2.7, 4.7), rng.randf_range(3.5, 5.6))
		batch.lump(Look.Tint.new(land.mat, tint), center, canopy, center - Vector3.UP, rng, 0.26, 4, 8)
	batch.build(root, "ContinuousTerrainAndDistantHills")


static func _neighborhood(root: Node3D) -> void:
	var batch := Look.Batch.new()
	# 街並みは空き地の外なので描画だけに使う。
	var road := Look.mat("asphalt", Color("898b87"))
	batch.boxp(road, Vector3(-36, 0.009, -7.6), Vector3(5.2, 0.022, 64.8))
	batch.boxp(road, Vector3(-5.9, 0.009, 27.0), Vector3(65.4, 0.022, 4.4))
	# 住宅の切れ間には、既存の遠景用の窓テクスチャで奥の街を見せる。
	var distant := Look.mat("tower", Color("aeb6b5"))
	var cap := Look.plain(Color("8f9898"))
	var blocks := [Vector4(-28, -63, 12, 11), Vector4(-44, -56, 10, 12),
			Vector4(-60, -43, 14, 13), Vector4(-66, -21, 13, 10), Vector4(-64, 4, 12, 11),
			Vector4(-58, 28, 16, 12), Vector4(15, -62, 15, 11), Vector4(-2, -69, 13, 9),
			Vector4(-31, 55, 15, 11), Vector4(-8, 60, 14, 13), Vector4(14, 57, 13, 10)]
	for block in blocks:
		var foot := Vector3(block.x, -0.15, block.y)
		batch.boxp(distant, foot + Vector3.UP * block.w * 0.5, Vector3(block.z, block.w, 9))
		batch.boxp(cap, foot + Vector3.UP * block.w, Vector3(block.z + 0.3, 0.26, 9.3))
	var homes := [
		[Vector3(-43, 0, -28), 0.8, PI * 0.5], [Vector3(-45, 0, -17), 1.0, PI * 0.5],
		[Vector3(-42, 0, -5), 0.85, PI * 0.5], [Vector3(-46, 0, 7), 1.15, PI * 0.5],
		[Vector3(-43, 0, 19), 1.0, PI * 0.5], [Vector3(-38, 0, 42), 1.15, PI],
		[Vector3(-25, 0, 36), 0.85, PI], [Vector3(-12, 0, 39), 1.1, PI],
		[Vector3(2, 0, 35), 0.90, PI], [Vector3(16, 0, 37), 1.05, PI],
		[Vector3(14, 0, -44), 1.25, 0.0], [Vector3(26, 0, -41), 0.9, 0.0],
		[Vector3(-27, 0, -39), 0.95, 0.0], [Vector3(-38, 0, -46), 1.15, 0.0],
	]
	var walls := [Color("c9b9a6"), Color("bcbfba"), Color("dbd2bd"), Color("c0ac9b")]
	var roofs := [Color("5f686a"), Color("73695e"), Color("6f7776"), Color("776664")]
	for i in homes.size():
		var house: Array = homes[i]
		var scale_factor: float = house[1]
		batch.xf = Transform3D(Basis(Vector3.UP, house[2]).scaled(Vector3.ONE * scale_factor), house[0])
		_house(batch, walls[i % walls.size()], roofs[i % roofs.size()])
	batch.xf = Transform3D.IDENTITY
	batch.build(root, "NeighborhoodBeyondTheLot")


static func _house(batch: Look.Batch, wall_color: Color, roof_color: Color) -> void:
	var wall := Look.mat("plaster", wall_color)
	var roof := Look.mat("metal", roof_color)
	var frames := Look.mat("wood", Color("989185"))
	var glass := Look.mat("glass", Color("718287"))
	batch.boxp(wall, Vector3(0, 2.73, 0), Vector3(7.4, 5.8, 5.4))
	var gable := [Vector2(-3.7, 0), Vector2(3.7, 0), Vector2(0, 1.65)]
	batch.extrude(wall, Transform3D(Basis.IDENTITY, Vector3(0, 5.63, 0)), gable, 5.4)
	for side in [-1, 1]:
		var at := Transform3D(Basis(Vector3.BACK, -side * atan2(1.65, 3.7)),
				Vector3(side * 1.93, 6.52, 0))
		batch.box(roof, at, Vector3(4.38, 0.18, 5.95), Look.Batch.ALL)
	for y in [1.55, 4.05]:
		for x in [-2.10, 0, 2.10]:
			batch.boxp(frames, Vector3(x, y, 2.72), Vector3(1.40, 1.23, 0.08))
			batch.boxp(glass, Vector3(x, y, 2.768), Vector3(1.27, 1.09, 0.04))
			batch.boxp(frames, Vector3(x, y, 2.79), Vector3(0.05, 1.10, 0.035))


static func _planting(root: Node3D) -> void:
	var batch := Look.Batch.new()
	for p in [Vector3(-19, 0.005, -9), Vector3(-19, 0.005, 12), Vector3(17, 0.005, -14), Vector3(20, 0.005, -10)]:
		Foliage.pit(batch, p, 1.3 * 1.16)
		var tree := Look.Batch.new()
		tree.xf.origin = -p
		Foliage.tree(tree, p, 1.16, "street", false)
		var trunk := tree.build(root, "WindTree")
		trunk.position = p
		trunk.add_to_group("location_wind_tree")
		batch.solidp(p + Vector3.UP * 0.89, Vector3(0.31, 1.78, 0.31))
		batch.solidp(p + Vector3.UP * 0.064, Vector3(1.50, 0.13, 1.50))
	# 金網越しに足元の地面が途切れないよう、低い茂みの後ろに木立と屋根を重ねる。
	var shrubs := [Vector2(-24.1, -16), Vector2(-25, -12.6), Vector2(-24.5, -9.1),
			Vector2(-24.8, -4.5), Vector2(-24.4, -1.6), Vector2(-24.2, 2.8), Vector2(-25, 7.3),
			Vector2(-24.3, 10.3), Vector2(-24.0, 14.0), Vector2(-22.1, 19.8),
			Vector2(-17.8, 20.4), Vector2(-13.7, 20.2), Vector2(-9.7, 20.0), Vector2(-5.4, 20.2),
			Vector2(-1.2, 19.9), Vector2(3.6, 20.5), Vector2(8, 20.1), Vector2(13, 20.4),
			Vector2(17.6, 20.2), Vector2(22.0, 20.5), Vector2(24.7, 13.0), Vector2(24.8, 8.1),
			Vector2(25.0, 3.6), Vector2(24.5, -1.1), Vector2(25.0, -6.0), Vector2(24.7, -10.4),
			Vector2(24.0, -15), Vector2(8.5, -20.4), Vector2(12.7, -20.9), Vector2(17.6, -20.0)]
	for i in shrubs.size():
		var spot: Vector2 = shrubs[i]
		var radius := 1.4 + 0.24 * (i % 4)
		Foliage.bush(batch, Vector3(spot.x, radius * 0.63, spot.y), radius, "hedge")
	var trees := [Vector3(-27, 0, -15), Vector3(-30, 0, -5), Vector3(-27, 0, 4), Vector3(-31, 0, 13),
			Vector3(-21, 0, 24), Vector3(-12, 0, 24), Vector3(-3, 0, 23), Vector3(7, 0, 24), Vector3(18, 0, 24),
			Vector3(26, 0, 14), Vector3(26, 0, 3), Vector3(26, 0, -9), Vector3(25, 0, -17),
			Vector3(6, 0, -32), Vector3(14, 0, -30), Vector3(23, 0, -29), Vector3(-24, 0, -25),
			Vector3(-36, -0.15, -40), Vector3(-42, -0.15, -33), Vector3(-37, -0.15, -54),
			Vector3(9, -0.15, -50), Vector3(-18, -0.15, 46)]
	for i in trees.size():
		Foliage.tree(batch, trees[i], 1.32 + 0.14 * (i % 4), "young" if i % 3 == 0 else "street")
	batch.build(root, "ExistingStreetTreesAndShrubs")
