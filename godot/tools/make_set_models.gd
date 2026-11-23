extends SceneTree
# 素材の無い大道具を、コードで作って GLB に書き出す（ゴミ袋・包みから出てくる物。production_scrap.gd の "bag"）。
#   godot --headless --path godot -s res://tools/make_set_models.gd
#   そのあと godot --headless --path godot --import で取り込む
# 出力：res://assets/production/scrap/X001_paper_mountain.glb（張りぼての山）
#       res://assets/production/scrap/X002_cardboard_bicycle.glb（段ボールの自転車）
# どちらも、ほかの大道具と同じ決まり：Y が上、正面 +Z、底の中心が原点。大きさは production_scrap.gd の size で決まる
const OUT := "res://assets/production/scrap/"


func _initialize() -> void:
	_save(_mountain(), "X001_paper_mountain")
	_save(_bicycle(), "X002_cardboard_bicycle")
	quit()


func _save(root: Node3D, name: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT + name + ".glb"))
	print("SET_MODEL ", name, " ", "OK" if err == OK else "FAIL %d" % err)
	root.free()


func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _part(root: Node3D, name: String, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = null
	mesh.surface_set_material(0, mat)
	mi.position = at
	mi.rotation = rot
	mi.scale = scale
	root.add_child(mi)
	mi.owner = root
	return mi


# ---- 張りぼての山：新聞紙を貼った、段々の丸い山。てっぺんは平らで、人が立てる。雪をかぶり、岩の色のまだら ----
func _mountain() -> Node3D:
	var root := Node3D.new()
	root.name = "X001_paper_mountain"
	var noise := FastNoiseLite.new()
	noise.seed = 1203
	noise.frequency = 2.2
	var body := _mound(noise, 1.0, 1.3)
	var st_green := SurfaceTool.new()
	var st_rock := SurfaceTool.new()
	var st_snow := SurfaceTool.new()
	for st: SurfaceTool in [st_green, st_rock, st_snow]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in body:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var mid := (a + b + c) / 3.0
		var st := st_green
		if mid.y > 1.02:
			st = st_snow
		elif noise.get_noise_3dv(mid * 1.6) > 0.18 or mid.y > 0.8:
			st = st_rock
		var n := (c - a).cross(b - a).normalized()
		for v: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
	_part(root, "Slope", st_green.commit(), _mat(Color("5f8f4a")), Vector3.ZERO)
	_part(root, "Rock", st_rock.commit(), _mat(Color("8a7a66")), Vector3.ZERO)
	_part(root, "Snow", st_snow.commit(), _mat(Color("eef0f2"), 0.7), Vector3.ZERO)
	# 裏の支え（張りぼてなので、裏は角材）
	for x: float in [-0.35, 0.35]:
		var post := BoxMesh.new()
		post.size = Vector3(0.06, 0.8, 0.06)
		_part(root, "Post", post, _mat(Color("b08a5a")), Vector3(x, 0.4, -0.45))
	return root


# 丸い山の三角形の一覧（底の半径 radius、頂上の平らな所の高さ height）
func _mound(noise: FastNoiseLite, radius: float, height: float) -> Array:
	var rings := 9
	var seg := 22
	var pts: Array = []
	for r in rings + 1:
		var t := float(r) / float(rings)
		var row: Array = []
		for k in seg:
			var ang := TAU * float(k) / float(seg)
			var dir := Vector3(cos(ang), 0, sin(ang))
			# 山の形：下は広がり、上はすぼまる。てっぺん（t=1）は半径 0.22 の平ら
			var rad := lerpf(radius, 0.22 * radius, pow(t, 0.8))
			var bump := 1.0 + 0.10 * noise.get_noise_3dv(dir * 2.0 + Vector3(0, t * 3.0, 0))
			var y := height * t
			row.append(dir * rad * bump + Vector3(0, y, 0))
		pts.append(row)
	var tris: Array = []
	for r in rings:
		for k in seg:
			var k2 := (k + 1) % seg
			var a: Vector3 = pts[r][k]
			var b: Vector3 = pts[r][k2]
			var c: Vector3 = pts[r + 1][k]
			var d: Vector3 = pts[r + 1][k2]
			tris.append([a, b, c])        # Godot の面は時計回り（外から見て）。法線は (c-a)×(b-a) で外向き
			tris.append([b, d, c])
	var top := Vector3(0, height + 0.02, 0)
	for k in seg:
		tris.append([pts[rings][k], pts[rings][(k + 1) % seg], top])
	return tris


# ---- 段ボールの自転車：段ボールを切って作った、子ども用くらいの自転車。車輪は丸く切った段ボールに、マジックで描いたスポーク ----
func _bicycle() -> Node3D:
	var root := Node3D.new()
	root.name = "X002_cardboard_bicycle"
	var card := _mat(Color("c79a62"))
	var dark := _mat(Color("6b4a2c"))
	var red := _mat(Color("c8443a"), 0.8)
	var tire := _mat(Color("33302c"))
	# 自転車の向き：前が +Z。車輪の半径 0.3、軸の間 0.95
	for z: float in [-0.475, 0.475]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.3
		wheel.bottom_radius = 0.3
		wheel.height = 0.04
		wheel.radial_segments = 24
		_part(root, "Wheel", wheel, card, Vector3(0, 0.32, z), Vector3(0, 0, PI * 0.5))
		var rim := TorusMesh.new()
		rim.inner_radius = 0.27
		rim.outer_radius = 0.32
		rim.rings = 24
		_part(root, "Tire", rim, tire, Vector3(0, 0.32, z), Vector3(0, 0, PI * 0.5))
		for s in 3:
			var spoke := BoxMesh.new()
			spoke.size = Vector3(0.05, 0.5, 0.018)
			_part(root, "Spoke", spoke, dark, Vector3(0, 0.32, z), Vector3(PI * float(s) / 3.0, 0, 0))
		var hub := CylinderMesh.new()
		hub.top_radius = 0.04
		hub.bottom_radius = 0.04
		hub.height = 0.08
		_part(root, "Hub", hub, red, Vector3(0, 0.32, z), Vector3(0, 0, PI * 0.5))
	# 骨組み（赤く塗った段ボールの筒）：下の管、上の管、座る所の管、前のフォーク
	var tubes := [
		[Vector3(0, 0.32, -0.475), Vector3(0, 0.62, 0.32)],   # 下の管（後ろの軸 → 前の上）
		[Vector3(0, 0.66, -0.12), Vector3(0, 0.66, 0.32)],    # 上の管
		[Vector3(0, 0.32, -0.475), Vector3(0, 0.7, -0.15)],   # 座る所の後ろ
		[Vector3(0, 0.32, -0.08), Vector3(0, 0.74, -0.18)],   # 座る所の管
		[Vector3(0, 0.32, 0.475), Vector3(0, 0.8, 0.36)],     # 前のフォーク
	]
	for tube: Array in tubes:
		var a: Vector3 = tube[0]
		var b: Vector3 = tube[1]
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = a.distance_to(b)
		var dir := (b - a).normalized()
		var tilt := atan2(-dir.z, dir.y)
		_part(root, "Tube", cyl, red, (a + b) * 0.5, Vector3(-tilt, 0, 0))
	# サドル・ハンドル・ペダル
	var saddle := BoxMesh.new()
	saddle.size = Vector3(0.14, 0.05, 0.24)
	_part(root, "Saddle", saddle, dark, Vector3(0, 0.78, -0.2))
	var bar := CylinderMesh.new()
	bar.top_radius = 0.02
	bar.bottom_radius = 0.02
	bar.height = 0.48
	_part(root, "Handle", bar, dark, Vector3(0, 0.82, 0.36), Vector3(0, 0, PI * 0.5))
	for x: float in [-0.24, 0.24]:
		var grip := CylinderMesh.new()
		grip.top_radius = 0.03
		grip.bottom_radius = 0.03
		grip.height = 0.09
		_part(root, "Grip", grip, tire, Vector3(x, 0.82, 0.36), Vector3(0, 0, PI * 0.5))
	var crank := CylinderMesh.new()
	crank.top_radius = 0.08
	crank.bottom_radius = 0.08
	crank.height = 0.05
	_part(root, "Crank", crank, card, Vector3(0, 0.32, -0.08), Vector3(0, 0, PI * 0.5))
	for side: float in [-1.0, 1.0]:
		var pedal := BoxMesh.new()
		pedal.size = Vector3(0.1, 0.03, 0.08)
		_part(root, "Pedal", pedal, dark, Vector3(side * 0.12, 0.32 - side * 0.1, -0.08 + side * 0.04))
	# 前かご（段ボール箱）
	var basket := BoxMesh.new()
	basket.size = Vector3(0.28, 0.18, 0.2)
	_part(root, "Basket", basket, card, Vector3(0, 0.78, 0.52))
	return root
