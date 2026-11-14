extends Node
## 張りぼての大岩（冒険映画の「大岩に追われる」名場面のパロディ用。発注で借りる。main.gd の OPTIONS「boulder」）。
##   ・新聞紙と糊で作った、直径 1.7m ほどの丸い岩（人より大きい）。軽い（7kg）ので持てるし、押せば・坂を下れば・ロープで引けば転がる。
##   ・当たり判定は球。床の上では、少しずつ転がりが弱まって止まる。軽トラの荷台に載っている間は、転がりにくい（道中で落ちにくいように）。
##   ・借りると、軽トラの横に届く（main.gd の届け先の表には無いので、ここで置く）。返すと、ほかの借り物と同じに消える。
## 見た目はこのファイルで作る（ゴツゴツした多面体に、黄土色と茶色のまだら。ところどころ新聞紙の継ぎ目が見える）
const Prop := preload("res://scripts/prop.gd")

const RADIUS := 0.85
const MASS := 7.0
const ROLL_DAMP := 0.35                      # 床の上での、転がりの弱まり方
const RIDE_DAMP := 6.0                       # 荷台に載っている間の、転がりにくさ
const HOME_AT := Vector3(74.6, RADIUS + 0.02, 16.9)   # 届く場所（会社の庭、軽トラの横）

var game: Node
var rock: RigidBody3D


func setup() -> void:
	var p: RigidBody3D = Prop.new()
	p.kind = "boulder"
	p.label = "張りぼての大岩"
	p.mass = MASS
	var root := Node3D.new()
	root.add_child(_rock_mesh())
	p.visual = root
	p.add_child(root)
	p.center = Vector3(0, RADIUS, 0)
	p.half = Vector3.ONE * RADIUS
	p.hold_min = RADIUS + 1.0
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = RADIUS * 0.97
	shape.shape = ball
	shape.position = Vector3(0, RADIUS, 0)
	p.add_child(shape)
	p.angular_damp = ROLL_DAMP
	rock = game.stage._register(p, Vector3(float(game.props.size() + 1) * 3.0, -60.0, 0.0), 0.0)
	# 借りていなければ、現場に無い（ほかの借り物と同じ）
	rock.set_absent("boulder" in game._absent_kinds())


# ゴツゴツした張りぼての岩：多面体の球を、ノイズで押し引きして、面ごとに色を変える
func _rock_mesh() -> MeshInstance3D:
	var base := SphereMesh.new()
	base.radius = RADIUS
	base.height = RADIUS * 2.0
	base.radial_segments = 14
	base.rings = 9
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 1.6
	var paper := FastNoiseLite.new()
	paper.seed = 77
	paper.frequency = 3.2
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moved := PackedVector3Array()
	moved.resize(verts.size())
	for i in verts.size():
		var v: Vector3 = verts[i]
		var dir := v.normalized() if v.length() > 0.0001 else Vector3.UP
		var bump := 1.0 + 0.16 * noise.get_noise_3dv(dir * 1.3)
		moved[i] = dir * RADIUS * bump * Vector3(1.0, 0.94, 1.0) + Vector3(0, RADIUS, 0)
	for t in range(0, index.size(), 3):
		var a := moved[index[t]]
		var b := moved[index[t + 1]]
		var c := moved[index[t + 2]]
		var mid := (a + b + c) / 3.0 - Vector3(0, RADIUS, 0)
		# 面ごとの色：黄土色の砂岩に茶のまだら（暗い倉庫や灰色の壁の前でも、岩が浮いて見える）。
		# ところどころ、新聞紙の継ぎ目（明るい生成り）
		var stone := Color("a98559").lerp(Color("6e5136"), clampf(0.5 + noise.get_noise_3dv(mid * 2.5), 0.0, 1.0))
		if paper.get_noise_3dv(mid * 1.7) > 0.45:
			stone = Color("dcd0b2")
		var n := (c - a).cross(b - a).normalized()      # Godot の面は時計回り。外向きの法線にする
		for v: Vector3 in [a, b, c]:
			st.set_color(stone)
			st.set_normal(n)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true          # 上の色は見たままの色（sRGB）で書いてある
	mat.roughness = 0.97
	mi.material_override = mat
	return mi


# 借りた・返した（"absent" の合図のあと）：届いたら、軽トラの横に置く（ホスト）
func hook_core_event(n: String, _a: Array) -> void:
	if n != "absent" or rock == null or not Net.is_host():
		return
	if not rock.absent and rock.global_position.y < -30.0:
		rock.restore([HOME_AT, Quaternion.IDENTITY, false])


# 荷台に載っている間は転がりにくく、降りたら、また転がる
func _physics_process(_delta: float) -> void:
	if rock == null or not Net.is_host():
		return
	var want := RIDE_DAMP if rock.rider_of != 0 else ROLL_DAMP
	if not is_equal_approx(rock.angular_damp, want):
		rock.angular_damp = want
