extends RefCounted
## キャラの特技の見た目の部品（cast_talent.gd が使う）。ゲームの状態には触らない。
##   ・ショール：物にかぶせる布（物の大きさに合わせて作る。ずれた分だけ片側へ垂れる）と、腕に掛けた布（残りの枚数）
##   ・止まれ！：背中の赤い札（使うと倒れて、ゆっくり起き上がる）、吹き出し、「ぴたっ」
##   ・毛ひも：頭の房（毛の残りの長さだけ生えている）と、手に持つ毛の束
## 残りの数や秒は、文字では出さない。ここの見た目だけで分かるようにする。

const Talents := preload("res://scripts/cast_talents.gd")
const FilmCamera := preload("res://scripts/film_camera.gd")

const CLOTH := Color(0.16, 0.74, 0.72)          # ショールの色（ドレスの桃色と、はっきり違う色）
const CLOTH_BAND := Color(0.98, 0.86, 0.36)     # ふちの帯
const CLOTH_TASSEL := Color(1.0, 0.96, 0.82)    # 房
const CLOTH_GRID := 16
# 腕のショール（残りの枚数）：前腕に掛けた、たたんだ布の大きさと置き場所
const SHAWL_HALF := Vector3(0.1, 0.025, 0.0)     # 腕に載る所（腕に沿った幅・厚みの半分。前後は腕の太さから決める。m）
const SHAWL_DRAPE := 0.2                         # 前後へ垂れる長さ（m）
const SHAWL_ALONG := 0.45                        # 肘から手首までの、どのあたりに掛けるか（0＝肘・1＝手首）
const PADDLE_RED := Color(0.90, 0.12, 0.12)
const PADDLE_PALE := Color(0.62, 0.52, 0.52)


static func _cloth_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	return mat


# 箱形（中心 center・外形の半分 half）にかぶせた布。上の面に載り、はみ出した分が横へ垂れる。
#   slide：ずれ（上の面の上での、布の中心のずれ。m） / floor_y：これより下へは垂れない（床に広がる）
#   drape：垂れる長さ（m）
#   tassel：房の長さ（m。負なら垂れる長さから決める）
static func cloth(center: Vector3, half: Vector3, drape: float, slide: Vector2 = Vector2.ZERO, floor_y: float = -INF, tassel: float = -1.0) -> MeshInstance3D:
	var top: float = center.y + half.y + 0.012
	var edge := Vector2(half.x + 0.015, half.z + 0.015)
	var reach := Vector2(edge.x + drape, edge.y + drape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := CLOTH_GRID
	for j in n + 1:
		for i in n + 1:
			var u: float = float(i) / float(n) * 2.0 - 1.0
			var v: float = float(j) / float(n) * 2.0 - 1.0
			st.set_color(_cloth_color(i, j, n))
			st.add_vertex(_cloth_point(Vector2(u * reach.x, v * reach.y) + slide, center, edge, top, floor_y))
	for j in n:
		for i in n:
			var a: int = j * (n + 1) + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + 1)
			st.add_index(a + n + 2)
			st.add_index(a + n + 1)
	st.generate_normals()
	var mesh := st.commit()
	# ふちの房：すその外へ、小さな三角を並べる
	var fringe := SurfaceTool.new()
	fringe.begin(Mesh.PRIMITIVE_TRIANGLES)
	fringe.set_color(CLOTH_TASSEL)
	var long: float = minf(0.07, drape * 0.35) if tassel < 0.0 else tassel
	for side in 4:
		for k in n * 2:
			var w0: float = float(k) / float(n * 2) * 2.0 - 1.0
			var w1: float = float(k + 1) / float(n * 2) * 2.0 - 1.0
			var wm: float = (w0 + w1) * 0.5
			var pts: Array = []
			for w: float in [w0, w1, wm]:
				var flat := Vector2(w * reach.x, (1.0 if side == 0 else -1.0) * reach.y) if side < 2 else Vector2((1.0 if side == 2 else -1.0) * reach.x, w * reach.y)
				if w == wm:
					# 房の先は、すそより少し先（外へ）
					flat += (Vector2(0, 1.0 if side == 0 else -1.0) if side < 2 else Vector2(1.0 if side == 2 else -1.0, 0)) * long
				pts.append(_cloth_point(flat + slide, center, edge, top, floor_y))
			var face: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).cross((pts[2] as Vector3) - (pts[0] as Vector3)).normalized()
			fringe.set_normal(face)
			for p: Vector3 in pts:
				fringe.add_vertex(p)
	fringe.commit(mesh)
	var out := MeshInstance3D.new()
	out.mesh = mesh
	out.material_override = _cloth_material()
	return out


static func _cloth_color(i: int, j: int, n: int) -> Color:
	var rim: int = mini(mini(i, n - i), mini(j, n - j))
	if rim <= 1:
		return CLOTH_BAND
	if rim == 3:
		return CLOTH.lightened(0.35)
	return CLOTH


# 平らな布の上の点（flat＝上から見た場所。物の中心から）を、箱にかぶせたときの場所へ移す
static func _cloth_point(flat: Vector2, center: Vector3, edge: Vector2, top: float, floor_y: float) -> Vector3:
	var over := Vector2(maxf(absf(flat.x) - edge.x, 0.0), maxf(absf(flat.y) - edge.y, 0.0))
	var x: float = clampf(flat.x, -edge.x, edge.x)
	var z: float = clampf(flat.y, -edge.y, edge.y)
	var fall: float = maxf(over.x, over.y)
	# 角では、布が外へふくらむ
	var flare: float = minf(over.x, over.y) * 0.55
	# 垂れた所は、少し波打って外へ開く
	var wave: float = fall * (0.10 + 0.05 * sin((flat.x + flat.y) * 11.0))
	if over.x > 0.0:
		x += signf(flat.x) * (flare + wave)
	if over.y > 0.0:
		z += signf(flat.y) * (flare + wave)
	var y: float = top - fall
	if y < floor_y:
		# 床まで届いた分は、床の上に広がる
		var spread: float = floor_y - y
		y = floor_y
		if over.x >= over.y and over.x > 0.0:
			x += signf(flat.x) * spread
		elif over.y > 0.0:
			z += signf(flat.y) * spread
	return Vector3(center.x + x, y, center.z + z)


# 物にかぶせるショール。物の外形（prop.center・prop.half）に合わせる。slip（0〜1）と向き dir で、片側へずれる
static func prop_shawl(center: Vector3, half: Vector3, slip: float, dir: Vector2) -> MeshInstance3D:
	# 垂れる長さは、物の高さの3割ほど（下に何があるか、見て分かるように。かぶせきらない）
	var drape: float = clampf(half.y * 0.6, 0.05, 0.3)
	# 大きな物でも、布の大きさには限りがある（上の面の真ん中に載る）
	var box := Vector3(minf(half.x, 0.75), half.y, minf(half.z, 0.75))
	var slide := dir * slip * Vector2(box.x + drape, box.z + drape) * 0.9
	var mesh := cloth(center, box, drape, slide, center.y - half.y + 0.012)
	mesh.name = "TalentShawl"
	return mesh


# 腕に掛けたショール（残りの枚数）。たたんだ布を、左右の前腕に1枚ずつ掛けて、前後へ短く垂らす（ナプキンを腕に掛ける形）。
# 前腕の骨に付けるので、腕を動かしても付いてくる。腕の太さと表面の高さは、キャラの体の形から測る
static func show_shoulders(vis: Node3D, count: int) -> void:
	if count == int(vis.get_meta("talent_shawls", -1)):
		return
	vis.set_meta("talent_shawls", count)
	for side: String in ["L", "R"]:
		var rack: BoneAttachment3D = vis.skel.get_node_or_null("TalentShawl" + side)
		if rack != null:
			for old in rack.get_children():
				rack.remove_child(old)
				old.queue_free()
	for i in count:
		var side: String = "L" if i == 0 else "R"
		var fore: int = vis.skel.find_bone("FOREARM." + side)
		var hand: int = vis.skel.find_bone("HAND." + side)
		if fore < 0 or hand < 0:
			continue
		var rack: BoneAttachment3D = vis.skel.get_node_or_null("TalentShawl" + side)
		if rack == null:
			rack = BoneAttachment3D.new()
			rack.name = "TalentShawl" + side
			rack.bone_name = "FOREARM." + side
			vis.skel.add_child(rack)
		var rest: Transform3D = vis.skel.get_bone_global_rest(fore)
		var mid: Vector3 = rest.origin.lerp(vis.skel.get_bone_global_rest(hand).origin, SHAWL_ALONG)
		# 腕の上の面の高さと、前後の太さ（測れなければ、骨の少し上）
		var arm: Array = _limb_top(vis, mid)
		var top: Vector3 = arm[0]
		var thick: float = arm[1]
		var half := Vector3(SHAWL_HALF.x, SHAWL_HALF.y, thick + 0.02)
		var piece := cloth(Vector3(top.x, top.y - half.y + 0.01, top.z), half, SHAWL_DRAPE, Vector2.ZERO, -INF, 0.02)
		piece.transform = rest.affine_inverse()
		# 描く層は体と同じ（一人称で自分の体を隠しているときは、布も隠れる）
		for body: MeshInstance3D in vis.skel.find_children("*", "MeshInstance3D", false, false):
			piece.layers = body.layers
			break
		rack.add_child(piece)


# 腕に掛けてあるショールの数（確認用）。腕のショールを持たないキャラは -1
static func shawls_shown(vis: Node3D) -> int:
	var out := -1
	for side: String in ["L", "R"]:
		var rack: Node = vis.skel.get_node_or_null("TalentShawl" + side)
		if rack != null:
			out = maxi(out, 0) + rack.get_child_count()
	if out < 0 and vis.has_meta("talent_shawls"):
		out = 0
	return out


# 体の形（骨格の空間。立ち姿）で、腕の at の所の上の面：[[x, いちばん高い所, 前後の真ん中], 前後の太さの半分]。
# 腕のまわりだけを見る。測れなければ、骨の少し上
static func _limb_top(vis: Node3D, at: Vector3) -> Array:
	var skel: Skeleton3D = vis.skel
	var best := -INF
	var front := INF
	var back := -INF
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", false, false):
		if mi.mesh == null:
			continue
		var to_skel: Transform3D = skel.global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = to_skel * v
				if absf(p.x - at.x) > 0.04 or absf(p.y - at.y) > 0.35 or absf(p.z - at.z) > 0.35:
					continue
				best = maxf(best, p.y)
				front = minf(front, p.z)
				back = maxf(back, p.z)
	if best == -INF:
		return [at + Vector3(0, 0.12, 0), 0.12]
	return [Vector3(at.x, best, (front + back) * 0.5), (back - front) * 0.5]


# ---- 止まれ！：背中の赤い札 ----

# up：1＝立っている（使える）〜 0＝倒れている（使ったばかり）
static func show_paddle(vis: Node3D, up: float) -> void:
	var rack: BoneAttachment3D = vis.skel.get_node_or_null("TalentPaddle")
	if rack == null:
		rack = BoneAttachment3D.new()
		rack.name = "TalentPaddle"
		rack.bone_name = "BODY"
		vis.skel.add_child(rack)
		var rest: Transform3D = vis.skel.get_bone_global_rest(vis.skel.find_bone("BODY"))
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		# 体の右うしろ。立てても、後ろからの視点の照準（頭の真上）には、かからない高さと位置
		hinge.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(-0.66, 1.2, -0.5))
		rack.add_child(hinge)
		var stick := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 0.035
		rod.bottom_radius = 0.035
		rod.height = 1.05
		stick.mesh = rod
		stick.position = Vector3(0, 0.525, 0)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.95, 0.93, 0.86)
		stick.material_override = wood
		hinge.add_child(stick)
		var disc := MeshInstance3D.new()
		disc.name = "Disc"
		var plate := CylinderMesh.new()
		plate.top_radius = 0.36
		plate.bottom_radius = 0.36
		plate.height = 0.05
		plate.radial_segments = 24
		disc.mesh = plate
		disc.rotation.x = PI * 0.5
		disc.position = Vector3(0, 1.3, 0)
		disc.material_override = StandardMaterial3D.new()
		hinge.add_child(disc)
		for face: float in [1.0, -1.0]:
			var word := Label3D.new()
			word.text = "止"
			word.font_size = 96
			word.pixel_size = 0.0047
			word.modulate = Color.WHITE
			word.outline_size = 0
			word.position = Vector3(0, 1.3, 0.03 * face)
			word.rotation.y = 0.0 if face > 0.0 else PI
			hinge.add_child(word)
	var hinge: Node3D = rack.get_node("Hinge")
	# 倒れているときは、後ろへ寝て、色も薄い
	hinge.rotation.x = -lerpf(1.85, 0.0, smoothstep(0.0, 1.0, up))
	var paint := (hinge.get_node("Disc") as MeshInstance3D).material_override as StandardMaterial3D
	paint.albedo_color = PADDLE_PALE.lerp(PADDLE_RED, clampf((up - 0.75) * 4.0, 0.0, 1.0))
	paint.emission_enabled = up >= 1.0
	paint.emission = PADDLE_RED
	paint.emission_energy_multiplier = 0.6


# 制作班にだけ見える、頭の上や物の上の文字（映画には映らない）。seconds たったら消える
static func pop_word(parent: Node, font: Font, text: String, at: Vector3, size: int, tint: Color, seconds: float) -> Label3D:
	var word := Label3D.new()
	word.text = text
	if font != null:
		word.font = font
	word.font_size = size
	word.fixed_size = true
	word.pixel_size = 0.0011
	word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	word.no_depth_test = true
	word.modulate = tint
	word.outline_modulate = Color(0, 0, 0, 0.85)
	word.outline_size = 12
	word.layers = FilmCamera.CREW_LAYER
	word.top_level = true
	parent.add_child(word)
	word.global_position = at
	var fade := word.create_tween()
	fade.tween_property(word, "scale", Vector3.ONE, 0.12).from(Vector3.ONE * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fade.tween_interval(maxf(seconds - 0.4, 0.05))
	fade.tween_property(word, "modulate:a", 0.0, 0.28)
	fade.tween_callback(word.queue_free)
	return word


# ---- 毛ひも：頭の房と、手に持つ束 ----

static func _hair_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Talents.HAIR_COLOR
	mat.roughness = 1.0
	return mat


# 頭の房。lengths＝房それぞれの長さ（0〜1。cast_talents.gd の hair_tufts）。変わったときだけ作り直す
static func show_tufts(vis: Node3D, lengths: Array) -> void:
	var key: Array = lengths.map(func(v: float) -> int: return int(round(v * 8.0)))
	if key == vis.get_meta("talent_tufts", []):
		return
	vis.set_meta("talent_tufts", key)
	var rack: BoneAttachment3D = vis.skel.get_node_or_null("TalentTufts")
	if rack == null:
		rack = BoneAttachment3D.new()
		rack.name = "TalentTufts"
		rack.bone_name = "HEAD"
		vis.skel.add_child(rack)
	for old in rack.get_children():
		rack.remove_child(old)
		old.queue_free()
	var rest: Transform3D = vis.skel.get_bone_global_rest(vis.skel.find_bone("HEAD"))
	var top := 0.0
	for mesh: MeshInstance3D in vis.skel.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			top = maxf(top, mesh.get_aabb().end.y)
	var root := Node3D.new()
	root.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(0, top - 0.62, 0))
	rack.add_child(root)
	var mat := _hair_material()
	for i in key.size():
		var amount: float = float(key[i]) / 8.0
		if amount <= 0.0:
			continue
		# 冠のまわりに、放射状に生える。根元は上へ、先は外へ垂れる
		var turn: float = TAU * (float(i) + 0.5) / float(key.size())
		var out := Vector3(sin(turn), 0, cos(turn))
		var at := out * 0.34
		var links: int = maxi(2, int(ceil(amount * 9.0)))
		for k in links:
			var t: float = float(k) / 9.0
			var bead := MeshInstance3D.new()
			var ball := SphereMesh.new()
			var r: float = lerpf(0.15, 0.085, t)
			ball.radius = r
			ball.height = r * 2.0
			ball.radial_segments = 10
			ball.rings = 5
			bead.mesh = ball
			bead.material_override = mat
			# 弧：はじめは上へ、だんだん外へ倒れて、下へ垂れる。
			# いちばん高い所でも、もとの頭のてっぺん（冠の羽根）を越えない（視点の照準に、頭がかからないように）
			var lean: float = t * 2.5
			bead.position = at + out * (0.46 * (1.0 - cos(lean))) + Vector3(0, 0.45 * sin(lean), 0)
			root.add_child(bead)


# 手に持つ毛の束（輪にした毛。物として作る。当たりは呼ぶ側で付ける）
static func hair_bundle() -> Node3D:
	var root := Node3D.new()
	var mat := _hair_material()
	for i in 3:
		var loop := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.085 - 0.012 * float(i)
		ring.outer_radius = 0.15 - 0.012 * float(i)
		ring.rings = 16
		ring.ring_segments = 8
		loop.mesh = ring
		loop.material_override = mat
		loop.position = Vector3(0, 0.035 + 0.03 * float(i), 0)
		loop.rotation = Vector3(0.12 * float(i), 0.8 * float(i), 0.08 * float(i))
		root.add_child(loop)
	return root
