extends RefCounted
## 土の空き地と、北のフェンス越しに見える工事現場。
const Look := preload("res://scripts/production_look.gd")
const SOIL := preload("res://shaders/location_soil.gdshader")


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


static func _grass(root: Node3D) -> void:
	var batch := Look.Batch.new()
	var grass := Look.mat("grass")
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
	batch.build(root, "LotGrass")


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
