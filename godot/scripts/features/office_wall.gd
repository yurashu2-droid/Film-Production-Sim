extends Node
## 事務所の壁の「実績」と、格の見た目（数字ではなく、事務所の中の物で見せる）。
##   ・納品した作品（production_flow.gd の films）のポスターが、入口から入って左（西）の壁に1枚ずつ増える。
##     西の壁がいっぱいになったら、奥の壁の上の段へ続く。それも埋まったら、古い物から外す（新しい物を貼る）。
##     出来で貼り方が変わる：全部の場面が成立＝黒い額に入って「大入」の判 / 半分以上＝画びょう4つでまっすぐ /
##     半分に届かない＝テープ2枚で少し斜め / 1場面も撮れない＝角が破れ、テープ1枚で大きく傾く（色もあせている）
##     ポスターの絵は、依頼の掲示板と同じ ui/film_set.gd の PosterArt。題名と場面の印も、同じ絵（SubViewport）に描く
##   ・格（rank）が上がるたびに、事務所に物が増える。下がったら外す
##     格2：地方テレビ局からの感謝状（奥の壁、書類の棚の上の額） / 格3：映画会社の名刺の束（机）とトロフィー（書類の棚の上） /
##     格4：大手から届いた台本の山（書類の棚の西どなりの床）
##   ・倒産・エンディングで新しい会社になったら、壁は空（帰社のとき、ホストが films を空にする）
## 決めるのはホスト（films と評判は production_flow.gd の snapshot で全員へ配られる）。どの画面も、届いた中身から同じ物を作る
const Look := preload("res://scripts/production_look.gd")
const FilmSet := preload("res://scripts/ui/film_set.gd")
const ALL := 63

# ポスター1枚の大きさ（掲示板のポスターと同じ縦横の比。236×372）
const POSTER := Vector2(0.62, 0.977)
const TEX := Vector2i(236, 372)
# 貼る場所：西の壁（入口の側から奥へ）12枚 → 奥の壁の上の段（西から東へ）14枚
const WEST_X := 65.125            # 西の壁の内側の面
const WEST_Y := 1.8
const WEST_Z0 := 3.0
const BACK_Z := -7.88             # 奥の壁の内側の面
const BACK_Y := 2.76
const BACK_X0 := 65.9
const STEP := 0.9
const WEST_N := 12
const BACK_N := 14
const MAX := WEST_N + BACK_N
# 格の物の置き場所
const CERT_AT := Vector3(76.7, 1.78, -7.875)      # 奥の壁の面、書類の棚の上（感謝状の額の中心）。東の壁は、機材の棚と机でふさがっている
const TROPHY_AT := Vector3(77.45, 1.0, -5.75)     # 書類の棚の上
const CARDS_AT := Vector3(73.62, 0.96, 0.48)      # 机の東の端（電気スタンドの手前）
const SCRIPTS_AT := [Vector3(75.05, 0.0, -7.4), Vector3(74.45, 0.0, -7.45), Vector3(75.1, 0.0, -6.8)]   # 書類の棚の西どなりの床（奥の壁ぎわ）

var game: Node
var root: Node3D
var slots: Array = []             # 貼ってあるポスター（Node3D）。並びは貼る場所の順
var _keys: Array = []             # 各ポスターの中身（作り直すかどうかの比べ用）
var rank_items := {}              # 格 → その格で増える物（Node3D）
var shown_rank := 0
var _seen := 0                    # films の中身のハッシュ（確認用の書き換えにも追いつく）
var _poll := 0.0


func setup() -> void:
	root = Node3D.new()
	root.name = "OfficeWallThings"
	game.add_child(root)
	rank_items[2] = _certificate()
	rank_items[3] = _trophy_and_cards()
	rank_items[4] = _script_piles()
	refresh()


func hook_production_applied() -> void:
	refresh()


# 帰社：倒産・エンディングで新しい会社になるなら、壁を空にする（ホスト。このあと snapshot で全員へ配られる）
func hook_return_office() -> void:
	var flow: Node = game.production
	if flow != null and (bool(flow.bankrupt) or bool(flow.finale_done)):
		flow.films = []


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.25
	var flow: Node = game.production if game != null else null
	if flow == null:
		return
	if str(flow.get("films")).hash() != _seen or flow.rank() != shown_rank:
		refresh()


func films() -> Array:
	var flow: Node = game.production
	var out: Variant = flow.get("films") if flow != null else null
	return out if out is Array else []


# 届いた中身に合わせて、ポスターと格の物をそろえる（全員の画面）
func refresh() -> void:
	var flow: Node = game.production
	if flow == null or root == null:
		return
	var list: Array = films()
	_seen = str(flow.get("films")).hash()
	var start := maxi(0, list.size() - MAX)
	var want: Array = list.slice(start)
	for i in maxi(want.size(), slots.size()):
		var key := ""
		if i < want.size():
			var f: Dictionary = want[i]
			key = "%d|%d|%d|%d" % [start + i, int(f.get("job", 0)), int(f.get("ok", 0)), int(f.get("of", 1))]
		if i < _keys.size() and _keys[i] == key:
			continue
		if i < slots.size() and is_instance_valid(slots[i]):
			slots[i].queue_free()
		while slots.size() <= i:
			slots.append(null)
			_keys.append("")
		slots[i] = _poster(want[i], start + i, i) if key != "" else null
		_keys[i] = key
	while not slots.is_empty() and slots[-1] == null:
		slots.pop_back()
		_keys.pop_back()
	shown_rank = flow.rank()
	for k: int in rank_items:
		var item: Node3D = rank_items[k]
		item.visible = shown_rank >= k
		# 外した物には、ぶつからない（台本の山の当たり判定）
		for body: Node in item.find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = 1 if item.visible else 0


# 出来の段階：3＝全部の場面 / 2＝半分以上 / 1＝少し / 0＝何も撮れていない
static func grade(f: Dictionary) -> int:
	var ok := int(f.get("ok", 0))
	var of := maxi(1, int(f.get("of", 1)))
	if ok >= of:
		return 3
	if ok * 2 >= of:
		return 2
	return 1 if ok > 0 else 0


# 貼る場所（ポスターの中心。+Z が部屋の側）
static func slot_xf(i: int) -> Transform3D:
	if i < WEST_N:
		return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(WEST_X, WEST_Y, WEST_Z0 - i * STEP))
	return Transform3D(Basis.IDENTITY, Vector3(BACK_X0 + (i - WEST_N) * STEP, BACK_Y, BACK_Z))


# ---- ポスター ----
func _poster(f: Dictionary, serial: int, i: int) -> Node3D:
	var g := grade(f)
	var job := int(f.get("job", 0))
	var holder := Node3D.new()
	holder.name = "Poster%d" % i
	holder.set_meta("grade", g)
	holder.set_meta("job", job)
	root.add_child(holder)
	holder.transform = slot_xf(i)
	var side := 1.0 if (serial * 7 + job) % 2 == 0 else -1.0
	var tilt: float = [0.24, 0.1, 0.022, 0.0][g] * side
	holder.rotate_object_local(Vector3.BACK, tilt)
	# 絵（2D の画面に描いて、板に貼る）
	var vp := _face(f, g)
	holder.add_child(vp)
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = _sheet(g, serial)
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.roughness = 0.88 if g < 3 else 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	face.material_override = m
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.position.z = 0.03 if g == 3 else 0.006
	holder.add_child(face)
	# 貼り方
	var b := Look.Batch.new()
	b.no_shadow = true
	var hw := POSTER.x * 0.5
	var hh := POSTER.y * 0.5
	match g:
		3:
			# 黒い額（金の内縁）と、下の真鍮の札
			var frame := Look.plain(Color("1c1714"), 0.45)
			var gold := Look.plain(Color("c8a24a"), 0.35, 0.7)
			var fw := 0.055
			for s: float in [-1.0, 1.0]:
				b.boxp(frame, Vector3(0, s * (hh + fw * 0.5), 0.02), Vector3(POSTER.x + fw * 2.0, fw, 0.04), ALL)
				b.boxp(frame, Vector3(s * (hw + fw * 0.5), 0, 0.02), Vector3(fw, POSTER.y, 0.04), ALL)
				b.boxp(gold, Vector3(0, s * (hh + 0.004), 0.033), Vector3(POSTER.x, 0.012, 0.012), ALL)
				b.boxp(gold, Vector3(s * (hw + 0.004), 0, 0.033), Vector3(0.012, POSTER.y, 0.012), ALL)
			b.boxp(Look.plain(Color("221c18")), Vector3(0, 0, 0.004), Vector3(POSTER.x, POSTER.y, 0.008), ALL)
			b.boxp(gold, Vector3(0, -hh - fw * 0.5, 0.045), Vector3(0.16, 0.03, 0.006), ALL)
		2:
			# 画びょう4つ
			var cols := [Color("d23a2a"), Color("e0b43a"), Color("3f7fb8"), Color("d23a2a")]
			var k := 0
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var at := Vector3(sx * (hw - 0.035), sy * (hh - 0.035), 0.008)
					b.cyl(Look.plain(cols[k], 0.4), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at), 0.014, 0.012, 8)
					k += 1
		1:
			# 上の角に、養生テープを2枚（斜め）
			var tape := Look.plain(Color("e4d7a8"), 0.9)
			for sx: float in [-1.0, 1.0]:
				b.box(tape, Transform3D(Basis(Vector3.BACK, -sx * 0.7), Vector3(sx * (hw - 0.02), hh - 0.02, 0.009)), Vector3(0.13, 0.04, 0.003), ALL)
		0:
			# テープ1枚だけ（傾いた上の側の角）。もう1枚は、はがれて丸まっている
			var tape0 := Look.plain(Color("ddd0a0"), 0.9)
			var sx0 := -side
			b.box(tape0, Transform3D(Basis(Vector3.BACK, -sx0 * 0.7), Vector3(sx0 * (hw - 0.02), hh - 0.02, 0.009)), Vector3(0.13, 0.04, 0.003), ALL)
			b.cyl(tape0, Transform3D(Basis.IDENTITY, Vector3(-sx0 * (hw - 0.03), hh - 0.03, 0.012)), 0.012, 0.035, 6)
	b.build(holder, "Hang")
	return holder


# ポスターの紙の形（UV は絵の 0〜1）。何も撮れなかった作品は、右下の角が破れて、右の縁にも裂け目
static func _sheet(g: int, serial: int) -> ArrayMesh:
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	if g == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + serial
		outline = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.46), Vector2(0.9, 0.5), Vector2(0.97, 0.53), Vector2(1, 0.6)])
		# 右の縁から下の縁へ、ぎざぎざに破れる
		var a := Vector2(1, 0.68)
		var c := Vector2(0.58, 1)
		outline.append(a)
		for k in range(1, 7):
			var t := float(k) / 7.0
			var p := a.lerp(c, t) + Vector2(rng.randf_range(-0.035, 0.035), rng.randf_range(-0.03, 0.03)) - Vector2(0.06, 0.06) * sin(t * PI)
			outline.append(p)
		outline.append(c)
		outline.append(Vector2(0, 1))
	var idx := Geometry2D.triangulate_polygon(outline)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var nrm := PackedVector3Array()
	for p: Vector2 in outline:
		verts.append(Vector3((p.x - 0.5) * POSTER.x, (0.5 - p.y) * POSTER.y, 0))
		uvs.append(p)
		nrm.append(Vector3.BACK)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


# ポスターの絵：掲示板のポスターと同じ絵（PosterArt）・題名・場面の印（成立＝赤い四角、だめ＝白抜き）
func _face(f: Dictionary, g: int) -> SubViewport:
	var flow: Node = game.production
	var job := int(f.get("job", 0))
	var info: Dictionary = flow.JOBS[job] if job >= 0 and job < flow.JOBS.size() else {}
	var vp := SubViewport.new()
	vp.name = "Art"
	vp.size = TEX
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var paper := Face.new()
	paper.grade = g
	paper.ok = int(f.get("ok", 0))
	paper.of = maxi(1, int(f.get("of", 1)))
	paper.size = Vector2(TEX)
	vp.add_child(paper)
	var art := FilmSet.PosterArt.new()
	art.kind = "debut" if bool(info.get("debut", false)) else str(info.get("script", "castle"))
	art.variant = job
	art.custom_minimum_size = Vector2.ZERO
	art.position = Vector2(10, 10)
	art.size = Vector2(TEX.x - 20, 250)
	paper.add_child(art)
	var title := FilmSet.label(str(info.get("title", "")), 21, Color("1d1a14"), "stencil")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	title.clip_text = true
	title.position = Vector2(10, 264)
	title.size = Vector2(TEX.x - 20, 72)
	paper.add_child(title)
	# あせ・汚れ（上に重ねる）と、全部そろった作品の「大入」の判
	var over := Over.new()
	over.grade = g
	over.size = Vector2(TEX)
	paper.add_child(over)
	if g == 3:
		var stamp := FilmSet.label("大入", 22, Color("fff4e4"), "mincho")
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.position = Vector2(TEX.x - 78, 18)
		stamp.size = Vector2(60, 60)
		stamp.rotation = 0.18
		stamp.pivot_offset = Vector2(30, 30)
		paper.add_child(stamp)
	return vp


# 紙と、場面の印
class Face extends Control:
	var grade := 2
	var ok := 0
	var of := 3

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("f1e8d4") if grade > 0 else Color("d9cba8"))
		draw_rect(Rect2(Vector2(8, 8), Vector2(s.x - 16, 254)), Color("161214"))
		var w := 16.0
		var gap := 8.0
		var x0 := (s.x - (of * w + (of - 1) * gap)) * 0.5
		for k in of:
			var r := Rect2(Vector2(x0 + k * (w + gap), 342), Vector2(w, w))
			if k < ok:
				draw_rect(r, Color("c4302a"))
			else:
				draw_rect(r, Color("5d5850"), false, 2.0)


class Over extends Control:
	var grade := 2

	func _draw() -> void:
		var s := size
		match grade:
			3:
				draw_circle(Vector2(s.x - 48, 48), 31, Color("c4302a"))
				draw_arc(Vector2(s.x - 48, 48), 27, 0, TAU, 32, Color("fff4e4"), 2.0)
			1:
				draw_rect(Rect2(Vector2.ZERO, s), Color(0.85, 0.78, 0.6, 0.18))
			0:
				draw_rect(Rect2(Vector2.ZERO, s), Color(0.8, 0.72, 0.52, 0.42))
				# 水のしみと、斜めの折れ目
				draw_circle(Vector2(s.x * 0.3, s.y * 0.62), s.x * 0.2, Color(0.55, 0.45, 0.28, 0.22))
				draw_line(Vector2(0, s.y * 0.2), Vector2(s.x, s.y * 0.48), Color(1, 1, 1, 0.35), 2.0)
				draw_line(Vector2(0, s.y * 0.2 + 2), Vector2(s.x, s.y * 0.48 + 2), Color(0, 0, 0, 0.2), 1.5)


# ---- 格の物 ----
# 格2：地方テレビ局からの感謝状（東の壁。額の中の紙は、2D の画面に描く）
func _certificate() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Certificate"
	root.add_child(holder)
	holder.transform = Transform3D(Basis.IDENTITY, CERT_AT)
	var size := Vector2(0.78, 0.56)
	var b := Look.Batch.new()
	var wood := Look.plain(Color("5a3a22"), 0.5)
	var gold := Look.plain(Color("c8a24a"), 0.35, 0.7)
	var fw := 0.045
	for s: float in [-1.0, 1.0]:
		b.boxp(wood, Vector3(0, s * (size.y * 0.5 + fw * 0.5), 0.02), Vector3(size.x + fw * 2.0, fw, 0.04), ALL)
		b.boxp(wood, Vector3(s * (size.x * 0.5 + fw * 0.5), 0, 0.02), Vector3(fw, size.y, 0.04), ALL)
		b.boxp(gold, Vector3(0, s * (size.y * 0.5 + 0.003), 0.032), Vector3(size.x, 0.01, 0.01), ALL)
		b.boxp(gold, Vector3(s * (size.x * 0.5 + 0.003), 0, 0.032), Vector3(0.01, size.y, 0.01), ALL)
	b.build(holder, "Frame")
	var vp := SubViewport.new()
	vp.name = "Paper"
	vp.size = Vector2i(390, 280)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var paper := Certificate.new()
	paper.size = Vector2(390, 280)
	vp.add_child(paper)
	var head := FilmSet.label("感　謝　状", 40, Color("1d1a14"), "mincho")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 26)
	head.size = Vector2(390, 56)
	paper.add_child(head)
	var from := FilmSet.label("地方テレビ局　編成部", 15, Color("3a332a"), "mincho")
	from.position = Vector2(150, 222)
	from.size = Vector2(200, 24)
	paper.add_child(from)
	holder.add_child(vp)
	var face := MeshInstance3D.new()
	face.name = "Face"
	var q := QuadMesh.new()
	q.size = size
	face.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.roughness = 0.3
	face.material_override = m
	face.position.z = 0.012
	holder.add_child(face)
	return holder


class Certificate extends Control:
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("f6f0de"))
		# 地紋の縁取り（金と青の二重線）
		draw_rect(Rect2(Vector2(10, 10), s - Vector2(20, 20)), Color("b8963c"), false, 4.0)
		draw_rect(Rect2(Vector2(18, 18), s - Vector2(36, 36)), Color("3d5f8c"), false, 1.5)
		# 本文の行（字は読めない大きさ。行だけ）
		for k in 5:
			var w := 300.0 - float((k * 37) % 5) * 22.0
			draw_rect(Rect2(Vector2(46, 100 + k * 22), Vector2(w, 6)), Color(0.25, 0.22, 0.2, 0.55))
		# 朱の角印
		draw_rect(Rect2(Vector2(300, 200), Vector2(46, 46)), Color("c4302a"))
		draw_rect(Rect2(Vector2(305, 205), Vector2(36, 36)), Color("f6f0de"), false, 2.0)
		draw_rect(Rect2(Vector2(313, 213), Vector2(20, 20)), Color("f6f0de"), false, 2.0)


# 格3：映画会社の名刺の束（机）と、トロフィー（書類の棚の上）
func _trophy_and_cards() -> Node3D:
	var holder := Node3D.new()
	holder.name = "TrophyAndCards"
	root.add_child(holder)
	var b := Look.Batch.new()
	var gold := Look.plain(Color("d8b04a"), 0.25, 0.85)
	var black := Look.plain(Color("1c1a1a"), 0.4)
	var t := TROPHY_AT
	b.boxp(black, t + Vector3(0, 0.04, 0), Vector3(0.2, 0.08, 0.2), ALL)
	b.boxp(black, t + Vector3(0, 0.1, 0), Vector3(0.15, 0.04, 0.15), ALL)
	b.boxp(gold, t + Vector3(-0.0, 0.05, 0.101), Vector3(0.12, 0.035, 0.004), ALL)
	b.cylp(gold, t + Vector3(0, 0.12, 0), 0.025, 0.12, 10)
	b.cylp(gold, t + Vector3(0, 0.24, 0), 0.03, 0.03, 12, 0.06)
	b.cylp(gold, t + Vector3(0, 0.27, 0), 0.06, 0.13, 14, 0.085)
	for sx: float in [-1.0, 1.0]:
		b.bar(gold, t + Vector3(sx * 0.07, 0.36, 0), t + Vector3(sx * 0.12, 0.31, 0), 0.012)
		b.bar(gold, t + Vector3(sx * 0.12, 0.31, 0), t + Vector3(sx * 0.065, 0.28, 0), 0.012)
	# てっぺんに、金のフィルムのリール
	b.cyl(gold, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), t + Vector3(0, 0.46, 0.012)), 0.055, 0.024, 14)
	# 名刺の束：白い紙に、映画会社の色の帯。輪ゴムで留めた束が3つと、ばらした数枚
	var white := Look.plain(Color("f4f1ea"), 0.8)
	var bands := [Color("2a4f8c"), Color("b8302a"), Color("1f6b4e")]
	for k in 3:
		var at := CARDS_AT + Vector3(-0.12 + k * 0.11, 0.0, (k % 2) * 0.03)
		var yaw := 0.2 * (k - 1)
		b.boxy(white, at + Vector3(0, 0.015, 0), Vector3(0.091, 0.03, 0.055), yaw, ALL)
		b.boxy(Look.plain(bands[k], 0.7), at + Vector3(0, 0.0305, -0.018), Vector3(0.088, 0.002, 0.01), yaw, ALL)
		b.boxy(Look.plain(Color("c2803a"), 0.6), at + Vector3(0, 0.016, 0), Vector3(0.012, 0.032, 0.057), yaw, ALL)
	for k in 4:
		var at := CARDS_AT + Vector3(0.02 + k * 0.025, 0.002 + k * 0.001, 0.13)
		var yaw := -0.5 + k * 0.28
		b.boxy(white, at, Vector3(0.091, 0.002, 0.055), yaw, ALL)
		b.boxy(Look.plain(bands[k % 3], 0.7), at + Vector3(0, 0.0012, 0), Vector3(0.088, 0.001, 0.012), yaw, ALL)
	b.build(holder, "Mesh")
	return holder


# 格4：大手から届いた台本の山（A4 の厚い台本。表紙の色はまちまち、黒いクリップ留め）
func _script_piles() -> Node3D:
	var holder := Node3D.new()
	holder.name = "ScriptPiles"
	root.add_child(holder)
	var b := Look.Batch.new()
	var pages := Look.plain(Color("f2eee2"), 0.9)
	var covers := [Color("c9dcef"), Color("f4f1ea"), Color("f2c9c4"), Color("f4e3a1"), Color("cfe5c8"), Color("f4f1ea"), Color("2a4f8c")]
	var clip := Look.plain(Color("1a1a1a"), 0.4, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var heights := [24, 17, 11]
	for p in SCRIPTS_AT.size():
		var base: Vector3 = SCRIPTS_AT[p]
		var y := 0.0
		for k in int(heights[p]):
			var th := rng.randf_range(0.02, 0.034)
			var yaw := rng.randf_range(-0.25, 0.25) + PI * 0.5
			var off := Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
			var c: Color = covers[rng.randi() % covers.size()]
			b.boxy(pages, base + off + Vector3(0, y + th * 0.5, 0), Vector3(0.21, th, 0.297), yaw, ALL)
			b.boxy(Look.plain(c, 0.7), base + off + Vector3(0, y + th + 0.0015, 0), Vector3(0.214, 0.003, 0.301), yaw, ALL)
			var edge := Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.14)
			if k % 3 == 0:
				b.boxy(clip, base + off + edge + Vector3(0, y + th * 0.5 + 0.001, 0), Vector3(0.05, th + 0.008, 0.02), yaw, ALL)
			y += th + 0.003
		b.solidp(base + Vector3(0, y * 0.5, 0), Vector3(0.32, y, 0.32))
	b.build(holder, "Mesh")
	return holder
