extends SceneTree
# ジョークグッズの「ゴムのうんこ」を作って GLB に書き出す（素材の200個に無いので、これだけ形から作る）。
#   godot --headless --path godot -s res://tools/make_poop.gd
# 出力：res://assets/production/scrap/J001_rubber_poop.glb（底が y=0、前が +Z）
# 形：太い紐を、上へ行くほど細く・小さく巻いたソフトクリーム型。

const OUT := "res://assets/production/scrap/J001_rubber_poop.glb"
const TURNS := 3.1
const STEPS := 120          # 巻きの刻み
const RING := 16            # 紐の断面の角数


func _init() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var centers := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in STEPS + 1:
		var u := float(i) / STEPS
		var ang := u * TURNS * TAU
		# 巻きの半径：下は広く、上はほぼ中心へ。高さ：巻くごとに一段ずつ上がる
		var coil := lerpf(0.30, 0.0, pow(u, 0.85))
		var tube := lerpf(0.165, 0.035, pow(u, 0.9))
		var y := tube + lerpf(0.0, 0.50, pow(u, 1.15))
		if u > 0.94:
			# 先はくるんと尖らせる
			var tip := (u - 0.94) / 0.06
			tube = lerpf(tube, 0.004, tip)
			y += 0.07 * tip
		centers.append(Vector3(cos(ang) * coil, y, sin(ang) * coil))
		radii.append(tube)
	for i in STEPS + 1:
		var c: Vector3 = centers[i]
		var ahead: Vector3 = centers[mini(i + 1, STEPS)] - centers[maxi(i - 1, 0)]
		var tangent := ahead.normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length() < 0.5:
			side = Vector3.RIGHT
		var up := side.cross(tangent).normalized()
		for k in RING:
			var a := float(k) / RING * TAU
			var n := (side * cos(a) + up * sin(a)).normalized()
			verts.append(c + n * radii[i])
			normals.append(n)
	for i in STEPS:
		for k in RING:
			var a := i * RING + k
			var b := i * RING + (k + 1) % RING
			var c2 := (i + 1) * RING + k
			var d := (i + 1) * RING + (k + 1) % RING
			indices.append_array([a, c2, b, b, c2, d])
	# 巻き始めの切り口をふさぐ
	var start := verts.size()
	var first: Vector3 = centers[0]
	var back := (centers[0] - centers[1]).normalized()
	verts.append(first + back * radii[0] * 0.75)
	normals.append(back)
	for k in RING:
		indices.append_array([start, k, (k + 1) % RING])
	# 床に沈んだ分を平らに切らず、底を y=0 に合わせる
	var low := INF
	for v: Vector3 in verts:
		low = minf(low, v.y)
	for i in verts.size():
		verts[i].y -= low

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "FC_RubberBrown"
	mat.albedo_color = Color(0.44, 0.27, 0.14)
	mat.roughness = 0.5
	mesh.surface_set_material(0, mat)
	mesh.surface_set_name(0, "rubber")

	var scene := Node3D.new()
	scene.name = "J001_rubber_poop"
	var body := MeshInstance3D.new()
	body.name = "swirl"
	body.mesh = mesh
	scene.add_child(body)
	body.owner = scene
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene, state)
	if err == OK:
		err = doc.write_to_filesystem(state, OUT)
	print("MAKE_POOP ", "OK" if err == OK else "FAIL %d" % err, " tris=", indices.size() / 3, " aabb=", mesh.get_aabb())
	scene.free()
	quit(0 if err == OK else 1)
