extends Node3D
## 会社のアップグレード画面（事務所の奥の大きなディスプレイ）。
## 画面を見て、買いたい枠に照準を合わせて左クリックすると買える（メニューは開かない）。
## 中身は SubViewport に描いた普通の UI を、板に貼って見せている。
## 見た目は昔の通販雑誌の見開き：クリーム色の紙・赤い帯の見出し・品物ごとに写真と赤い値段。
## 照準の合った品物は赤ペンで丸く囲み、右下の注文はがきに書き足される（貯金と次の家賃も、はがきに）。
const SCREEN := Vector2(4.4, 2.475)          # 画面の大きさ（m）
const VIEW := Vector2i(800, 450)       # 小さく描いて大きく貼る（遠くからでも字が読めるように）
const REACH := 7.5                           # これより遠いと買えない
# 見開きの中の枠の場所（TRACKS の並び順）。左のページに 2×2、右のページの左上に1つ。右下は注文はがき
const CELLS := [Rect2(22, 62, 176, 180), Rect2(212, 62, 176, 180), Rect2(22, 252, 176, 180), Rect2(212, 252, 176, 180),
	Rect2(414, 62, 176, 180)]
const PAPER := Color("fbf6e8")
const GRAY_INK := Color("8a857b")
# 品物の写真の地の色（会社の物の種類ごと）
const PHOTO_BG := {"car": Color("6b7a86"), "studio": Color("3f6b55"), "monitor": Color("8a3a32"), "camera": Color("5a5a7a"), "plan": Color("b88d3a")}

var game: Node
var hover := ""                              # いま照準が合っている枠（無ければ ""）
var _view: SubViewport
var _cards := {}                             # 枠の名前 → {box, now, name, desc, price, unit, photo, short}
var _wallet: Label
var _rent: Label
var _rent_row: Control
var _order_name: Label
var _order_price: Label
var _left: Label
var _ring: CatalogPrint.PenRing
var _quad: MeshInstance3D
var _sig := ""


func build(owner_game: Node) -> void:
	game = owner_game
	# 台と枠
	_box(Vector3(0, 0.45, 0.1), Vector3(2.4, 0.9, 0.5), Color("3b3f47"))
	_box(Vector3(0, 2.2, -0.02), Vector3(SCREEN.x + 0.16, SCREEN.y + 0.16, 0.1), Color("1b1c20"))
	_view = SubViewport.new()
	_view.size = VIEW
	_view.disable_3d = true
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_build_ui()
	_quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = SCREEN
	_quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _view.get_texture()
	_quad.material_override = mat
	_quad.position = Vector3(0, 2.2, 0.04)
	add_child(_quad)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.9, 0.5)
	cs.shape = shape
	cs.position = Vector3(0, 0.45, 0.1)
	body.add_child(cs)
	add_child(body)


func _build_ui() -> void:
	var root := Spread.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.add_child(root)
	# 帯の見出し
	var head := FilmSet.label("撮影機材　大放出！", 28, Color("fff8e6"), "stencil")
	head.position = Vector2(24, 9)
	root.add_child(head)
	var head_r := FilmSet.label("会社の備品", 18, Color("fff8e6"), "mincho")
	head_r.position = Vector2(420, 16)
	root.add_child(head_r)
	var i := 0
	for id: String in game.production.TRACKS:
		if i >= CELLS.size():
			break                                # 枠が増えたら CELLS に場所を足す
		var track: Dictionary = game.production.TRACKS[id]
		_cards[id] = _item(root, id, str(track["title"]), CELLS[i])
		i += 1
	# 右のページ：「送料無料」の星と、ひとこと
	var star := CatalogPrint.Badge.new().setup("送料\n無料", "star", 118.0, 24, CatalogPrint.YELLOW, CatalogPrint.RED, 10.0)
	star.position = Vector2(442, 270)
	root.add_child(star)
	var note := FilmSet.label("代金は\n会社の貯金から", 17, CatalogPrint.INK, "mincho")
	note.position = Vector2(424, 384)
	root.add_child(note)
	_build_hagaki(root)
	# 赤ペンの丸（いちばん上に重ねる）
	_ring = CatalogPrint.PenRing.new()
	_ring.width = 4.0
	_ring.pad = Vector2(9, 7)
	root.add_child(_ring)


# 品物の枠1つ：写真の箱・品名・いまの段階・赤い値段
func _item(root: Control, id: String, title: String, cell: Rect2) -> Dictionary:
	var box := Control.new()
	box.position = cell.position
	box.size = cell.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var photo := Photo.new()
	photo.kind = id
	photo.title = title
	photo.position = Vector2.ZERO
	photo.size = Vector2(cell.size.x, 86)
	box.add_child(photo)
	# お金が足りないとき、写真の下の端に赤い字で
	var short := FilmSet.label("貯金が足りません", 16, CatalogPrint.RED, "marker")
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	short.add_theme_stylebox_override("normal", sb)
	short.position = Vector2(cell.size.x - 146, 62)
	short.visible = false
	box.add_child(short)
	var name_label := FilmSet.label("", 25, CatalogPrint.INK, "mincho")
	name_label.position = Vector2(0, 88)
	name_label.size = Vector2(cell.size.x, 34)
	name_label.clip_text = true
	box.add_child(name_label)
	# 細かい説明は画面には出さない（照準を合わせると、手前の案内に出る）
	var desc := FilmSet.label("", 14, CatalogPrint.SOFT, "mincho")
	desc.visible = false
	box.add_child(desc)
	var now := FilmSet.label("", 15, CatalogPrint.SOFT, "mincho")
	now.position = Vector2(0, 121)
	now.size = Vector2(cell.size.x, 20)
	now.clip_text = true
	box.add_child(now)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.position = Vector2(0, 138)
	row.size = Vector2(cell.size.x, 42)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var price := FilmSet.label("", 34, CatalogPrint.RED, "stencil")
	price.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(price)
	var unit := FilmSet.label("コイン", 15, CatalogPrint.INK, "mincho")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(unit)
	return {"box": box, "now": now, "name": name_label, "desc": desc, "price": price, "unit": unit, "photo": photo, "short": short}


# 右下の注文はがき：照準の合った品物と、貯金・のこり・次の家賃
func _build_hagaki(root: Control) -> void:
	var card := Hagaki.new()
	card.position = Vector2(608, 66)
	card.size = Vector2(176, 368)
	card.pivot_offset = card.size * 0.5
	card.rotation = deg_to_rad(3.0)
	root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.position = Vector2(12, 40)
	col.size = Vector2(card.size.x - 24, card.size.y - 50)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var title := FilmSet.label("郵 便 は が き", 18, CatalogPrint.RED, "mincho")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(FilmSet.label("ご注文の品", 14, CatalogPrint.RED, "mincho"))
	var name_row := CatalogPrint.RuledRow.new()
	col.add_child(name_row)
	_order_name = FilmSet.label("", 22, CatalogPrint.INK, "marker")
	_order_name.clip_text = true
	_order_name.custom_minimum_size = Vector2(150, 30)
	name_row.add_child(_order_name)
	_order_price = _hagaki_row(col, "代金")
	_wallet = _hagaki_row(col, "貯金")
	_left = _hagaki_row(col, "のこり")
	_rent = _hagaki_row(col, "次の家賃")
	_rent_row = _rent.get_parent()
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	var hint := FilmSet.label("ねらって左クリックで\nご注文", 15, GRAY_INK, "marker")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


# はがきの1行：左に刷った見出し（赤）、右に手書きの数字。数字の Label を返す
func _hagaki_row(col: VBoxContainer, caption: String) -> Label:
	var row := CatalogPrint.RuledRow.new()
	col.add_child(row)
	var cap := FilmSet.label(caption, 14, CatalogPrint.RED, "mincho")
	cap.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(cap)
	var num := FilmSet.label("", 22, CatalogPrint.INK, "marker")
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.clip_text = true
	num.custom_minimum_size.x = 60
	row.add_child(num)
	return num


func _process(_delta: float) -> void:
	if game == null or game.production == null:
		return
	var flow: Node = game.production
	hover = _aimed(flow)
	var sig := str(flow.levels) + str(flow.wallet) + hover + str(flow.day) + str(flow.rent_no)
	if sig == _sig:
		return
	_sig = sig
	var purse := int(flow.wallet)
	_wallet.text = "%d" % purse
	_rent_row.visible = bool(flow.hazards)
	_rent.text = "%d（あと%d本）" % [flow.rent_amount(), flow.rent_in()] if flow.hazards else ""
	var ringed: Control = null
	for id: String in _cards:
		var card: Dictionary = _cards[id]
		var levels: Array = flow.TRACKS[id]["levels"]
		var have: int = int(flow.levels.get(id, 0))
		var maxed: bool = have >= levels.size() - 1
		if id == hover and not maxed:
			ringed = card["box"]
		var price: Label = card["price"]
		var photo: Photo = card["photo"]
		(card["now"] as Label).text = "いま：%s" % str(levels[have]["name"])
		if maxed:
			(card["name"] as Label).text = str(levels[have]["name"])
			(card["desc"] as Label).text = str(levels[have]["desc"])
			price.text = "お買い上げ済み"
			price.add_theme_font_size_override("font_size", 21)
			price.add_theme_color_override("font_color", GRAY_INK)
			price.modulate.a = 1.0
			(card["unit"] as Label).visible = false
			(card["short"] as Label).visible = false
			(card["name"] as Label).add_theme_color_override("font_color", GRAY_INK)
			photo.gray = true
		else:
			var next: Dictionary = levels[have + 1]
			var short: bool = purse < int(next["cost"])
			(card["name"] as Label).text = str(next["name"])
			(card["desc"] as Label).text = str(next["desc"])
			price.text = _comma(int(next["cost"]))
			price.add_theme_font_size_override("font_size", 34)
			price.add_theme_color_override("font_color", CatalogPrint.RED)
			# 貯金が足りない値段は、少し薄く。写真の下に「貯金が足りません」
			price.modulate.a = 0.42 if short else 1.0
			(card["unit"] as Label).visible = true
			(card["unit"] as Label).modulate.a = price.modulate.a
			(card["short"] as Label).visible = short
			(card["name"] as Label).add_theme_color_override("font_color", CatalogPrint.INK)
			photo.gray = false
		photo.queue_redraw()
	# 照準の合った品物を赤ペンで囲み、はがきに書き足す
	if ringed != null:
		_ring.position = ringed.position
		_ring.size = ringed.size
		_ring.seed = absi(hover.hash()) % 997
		_ring.set_on(false, false)
		_ring.set_on(true)
	else:
		_ring.set_on(false, false)
	var offer := aimed_offer()
	if offer.is_empty():
		_order_name.text = ""
		_order_price.text = ""
		_left.text = ""
	else:
		var cost := int(offer["cost"])
		_order_name.text = str(offer["name"])
		_order_price.text = _comma(cost)
		_left.text = _comma(purse - cost) if purse >= cost else "足りません"
		_left.add_theme_color_override("font_color", CatalogPrint.INK if purse >= cost else CatalogPrint.RED)


# 画面のどの枠に照準が合っているか。遠すぎる・画面の外・買えない段階なら ""
func _aimed(flow: Node) -> String:
	var cam := get_viewport().get_camera_3d()
	var me: Node3D = game.local_player()
	if cam == null or me == null or flow.phase not in [0, 2] or game.ui_blocking():
		return ""
	if me.global_position.distance_to(global_position) > REACH:
		return ""
	var to_local := _quad.global_transform.affine_inverse()
	var from: Vector3 = to_local * cam.global_position
	var dir: Vector3 = to_local.basis * (-cam.global_basis.z)
	if absf(dir.z) < 0.001 or from.z <= 0.0:
		return ""
	var t := -from.z / dir.z
	if t <= 0.0:
		return ""
	var hit := from + dir * t
	var px := Vector2((hit.x / SCREEN.x + 0.5) * VIEW.x, (0.5 - hit.y / SCREEN.y) * VIEW.y)
	for id: String in _cards:
		if ((_cards[id]["box"] as Control).get_global_rect()).has_point(px):
			return id
	return ""


# 照準の合っている枠の、次の段階（買えるものが無ければ空）
func aimed_offer() -> Dictionary:
	if game == null or hover == "" or game.production == null:
		return {}
	var flow: Node = game.production
	var levels: Array = flow.TRACKS[hover]["levels"]
	var have: int = int(flow.levels.get(hover, 0))
	if have >= levels.size() - 1:
		return {}
	return levels[have + 1]


static func _comma(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if n < 0 else "") + out


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


# ---- 見開きの紙：クリーム色の紙・まん中の綴じ目の影・上の赤い帯 ----
class Spread extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("2b2622"))
		var page := Rect2(Vector2(4, 4), s - Vector2(8, 8))
		draw_rect(page, Color("fbf6e8"))
		draw_texture_rect_region(FilmSet.brush(), page, FilmSet.paint_region(page), Color(1, 1, 1, 0.3))
		# 赤い帯（見出し）と、帯の下の細い線
		draw_rect(Rect2(page.position, Vector2(page.size.x, 46)), Color("d63a26"))
		draw_rect(Rect2(page.position + Vector2(0, 49), Vector2(page.size.x, 2)), Color("d63a26"))
		# ページの番号ふうの細い線（下の端）
		draw_rect(Rect2(Vector2(page.position.x + 14, page.end.y - 6), Vector2(page.size.x - 28, 1)), Color(0.11, 0.1, 0.09, 0.25))
		# 綴じ目の影（まん中が暗く、両側へ明るくなる）
		var cx := s.x * 0.5
		for side: float in [-1.0, 1.0]:
			var w := 26.0
			var a := Vector2(cx, page.position.y)
			var b := Vector2(cx + w * side, page.position.y)
			draw_polygon(PackedVector2Array([a, b, Vector2(b.x, page.end.y), Vector2(a.x, page.end.y)]),
				PackedColorArray([Color(0.3, 0.24, 0.15, 0.32), Color(0.3, 0.24, 0.15, 0.0), Color(0.3, 0.24, 0.15, 0.0), Color(0.3, 0.24, 0.15, 0.32)]))
		draw_line(Vector2(cx, page.position.y), Vector2(cx, page.end.y), Color(0.25, 0.2, 0.12, 0.35), 1.0)


# ---- 品物の写真の箱：色の地に、品物の形を簡単に描く。持っている最高段階は灰色 ----
class Photo extends Control:
	var kind := "car"
	var title := ""
	var gray := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _col(c: Color) -> Color:
		if not gray:
			return c
		var v := c.get_luminance()
		return Color(v, v, v, c.a).lerp(Color("d8d3c8"), 0.45)

	func _draw() -> void:
		var s := size
		var bg: Color = PHOTO_BG.get(kind, Color("777777"))
		draw_rect(Rect2(Vector2.ZERO, s), _col(bg))
		# 写真の上の、うすい光
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x * 0.55, 0), Vector2(s.x * 0.3, s.y), Vector2(0, s.y)]),
			PackedColorArray([Color(1, 1, 1, 0.1), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.05)]))
		var fg := _col(Color("f6efdc"))
		var dark := _col(bg.darkened(0.55))
		var c := Vector2(s.x * 0.6, s.y * 0.58)
		match kind:
			"car":
				draw_rect(Rect2(c + Vector2(-46, -20), Vector2(70, 30)), fg)
				draw_colored_polygon(PackedVector2Array([c + Vector2(24, -20), c + Vector2(40, -20), c + Vector2(52, -4), c + Vector2(52, 10), c + Vector2(24, 10)]), fg)
				draw_rect(Rect2(c + Vector2(30, -15), Vector2(12, 10)), dark)
				for x: float in [-28.0, 34.0]:
					draw_circle(c + Vector2(x, 12), 9.0, dark)
					draw_circle(c + Vector2(x, 12), 3.5, fg)
			"studio":
				draw_rect(Rect2(c + Vector2(-44, -12), Vector2(88, 40)), fg)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-50, -12), c + Vector2(0, -34), c + Vector2(50, -12)]), fg)
				draw_rect(Rect2(c + Vector2(-14, 4), Vector2(28, 24)), dark)
				for x: float in [-36.0, 22.0]:
					draw_rect(Rect2(c + Vector2(x, -4), Vector2(14, 10)), dark)
			"monitor":
				draw_rect(Rect2(c + Vector2(-38, -30), Vector2(76, 48)), fg)
				draw_rect(Rect2(c + Vector2(-32, -24), Vector2(64, 36)), dark)
				draw_rect(Rect2(c + Vector2(-4, 18), Vector2(8, 10)), fg)
				draw_rect(Rect2(c + Vector2(-20, 27), Vector2(40, 5)), fg)
				draw_circle(c + Vector2(22, -16), 3.0, Color("e5392d") if not gray else fg)
			"camera":
				for d: float in [-24.0, 0.0, 24.0]:
					draw_line(c + Vector2(0, 0), c + Vector2(d, 32), fg, 3.0, true)
				draw_rect(Rect2(c + Vector2(-24, -30), Vector2(40, 28)), fg)
				draw_rect(Rect2(c + Vector2(16, -24), Vector2(14, 16)), fg)
				draw_circle(c + Vector2(-4, -16), 7.0, dark)
			_:
				draw_rect(Rect2(c + Vector2(-26, -30), Vector2(52, 62)), fg)
				draw_rect(Rect2(c + Vector2(-10, -35), Vector2(20, 9)), dark)
				for k in 4:
					draw_rect(Rect2(c + Vector2(-18, -14 + k * 11), Vector2(36 - (k % 2) * 10, 3)), dark)
		# 左上に、種類の名前（白い字）
		var f := FilmSet.font("stencil")
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(Vector2.ZERO, Vector2(tw + 14, 24)), Color(0, 0, 0, 0.35))
		draw_string(f, Vector2(7, 3 + f.get_ascent(16)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.95))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.25), false, 1.0)


# ---- 注文はがき：白い紙に、赤い郵便番号の枠 ----
class Hagaki extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2(3, 5), s), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(Vector2.ZERO, s), Color("fffdf6"))
		var red := Color("d63a26")
		for i in 7:
			var x := 16.0 + float(i) * 19.0 + (6.0 if i >= 3 else 0.0)
			draw_rect(Rect2(Vector2(x, 10), Vector2(14, 19)), red, false, 1.4)
		draw_line(Vector2(16 + 3 * 19 - 3, 19), Vector2(16 + 3 * 19 + 4, 19), red, 1.4)
