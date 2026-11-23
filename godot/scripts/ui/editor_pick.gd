extends Control
## 納品の時に、編集をだれに頼むかを選ぶ画面（features/editors.gd が開く）。
## 2026-11-14 ユーザー：物で渡す形はやめて、納品するタイミングで GUI で選ぶ。金額・名前・得意分野か特徴。その人の背景に、ちょっと個性を出す。
## 同じ日の直し（1 版＝縦長の札を横に並べ、← → で選ぶ形への指摘）：
##   ・字は短く。見出しは「編集者」だけ。説明の文・キーの案内は出さない（「決定」でいい所を「決定する？」と書かない）
##   ・選ぶのはマウス（乗せると右に大きく出て、押すと決まる）。矢印キーでは選ばせない
##   ・横長の札を、縦に並べる
## 並び：左に、横長の札が縦に 7 枚（頼まない＋編集者）。札は、左から 顔（その人の背景つき）・名前と特徴・代金。
##       右に、いまマウスが乗っている人の大きな絵（背景いっぱいに、胸から上）。
## 閉じる：右上の × か、Esc か、右クリック。
## 顔は、紹介動画の依頼主たち（ランダム生成のキャラ。godot/trailer/clients/。公開リポジトリには無い）。無ければ、班のキャラの素材で代わりにする。
## 字の決まり：既定の書体に黒い縁を付けない。字の下に帯を敷かない。書体は 2 つ（見出し・数字＝display、ほか＝bold / body）、色は 白・灰・黄
const UI := preload("res://scripts/ui/ui_theme.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")

signal chosen(id: String)
signal closed

const BLOCK := Vector2(1150, 632)          # 全体の大きさ（画面の真ん中に置く）
const LIST_W := 700.0
const ROW_H := 72.0
const ROW_GAP := 8.0
const TOP := 80.0                          # 見出しの下、札が始まる所
const SIDE_X := 748.0                      # 右の大きな絵の左はし
const FACE_PX := 420
# 編集者ごとの顔（ランダム生成のキャラの番号）と、無い時の代わり（班のキャラ）
const FACES := {"steady": ["31", "03"], "cm": ["22", "04"], "mv": ["34", "01"], "wild": ["37", "09"], "pro": ["39", "M02"], "hype": ["23", "06"]}
const CLIENTS := "res://trailer/clients/cast%s_game.glb"

var ids: Array = []
var info := {}
var selected := 0
var _faces := {}                 # 編集者 → 顔の絵
var _views := {}                 # 編集者 → 顔を映す SubViewport
var _glow: Array = []            # 札ごとの、乗っている度合い（0〜1。なめらかに）
var _over_close := false


func setup(order: Array, editors: Dictionary) -> void:
	ids = order.duplicate()
	info = editors
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id: String in ids:
		_faces[id] = _face(id)
		_glow.append(0.0)
	hide()


func _origin() -> Vector2:
	return ((size - BLOCK) * 0.5).floor()


func _row_rect(i: int) -> Rect2:
	return Rect2(_origin() + Vector2(0, TOP + float(i) * (ROW_H + ROW_GAP)), Vector2(LIST_W, ROW_H))


func _close_rect() -> Rect2:
	return Rect2(_origin() + Vector2(BLOCK.x - 44.0, 12.0), Vector2(44, 44))


func _process(delta: float) -> void:
	if not visible:
		return
	for i in _glow.size():
		_glow[i] = lerpf(float(_glow[i]), 1.0 if i == selected else 0.0, 1.0 - exp(-20.0 * delta))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_over_close = _close_rect().has_point(event.position)
		for i in ids.size():
			if _row_rect(i).grow_individual(0, ROW_GAP * 0.5, 24, ROW_GAP * 0.5).has_point(event.position):
				selected = i
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and _close_rect().has_point(event.position)):
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in ids.size():
				if _row_rect(i).grow_individual(0, 0, 24, 0).has_point(event.position):
					selected = i
					confirm()
					return
	accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.88))
	var o := _origin()
	draw_string(UI.fnt("display"), o + Vector2(0, 52), "編集者", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UI.CLAP_WHITE)
	# 閉じる ×
	var cr := _close_rect()
	var cc := UI.CLAP_WHITE if _over_close else UI.MUTED
	draw_line(cr.position + Vector2(12, 12), cr.end - Vector2(12, 12), cc, 2.5)
	draw_line(cr.position + Vector2(28, 12), cr.position + Vector2(12, 28), cc, 2.5)
	for i in ids.size():
		_draw_row(i)
	_draw_side(str(ids[selected]))


# 角の丸い面
func _plate(r: Rect2, color: Color, radius: int, edge := Color(0, 0, 0, 0), edge_w := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.set_border_width_all(edge_w)
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), r)


# 横長の札：顔（その人の背景）・名前と特徴・代金。乗っている札は、左右へ少し伸びて明るくなり、左はしに黄色い線
func _draw_row(i: int) -> void:
	var id := str(ids[i])
	var data: Dictionary = info[id]
	var k: float = _glow[i]
	var r := _row_rect(i).grow_individual(10.0 * k, 0, 10.0 * k, 0)
	_plate(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3), 9)
	_plate(r, Color("16181d").lerp(Color("2a2c33"), k), 9, Color(UI.CLAP_WHITE, 0.55 * k), 1 if k > 0.3 else 0)
	var face_r := Rect2(r.position + Vector2(6.0 + 6.0 * k, 5.0), Vector2(116.0, ROW_H - 10.0))
	_backdrop(face_r, id, lerpf(0.78, 1.0, k), 1.0)
	var tex: Texture2D = _faces.get(id)
	if tex != null:
		# 頭と肩のあたりを、横長に切り出す
		var s := float(tex.get_width())
		var wide := s * 0.84
		draw_texture_rect_region(tex, face_r, Rect2((s - wide) * 0.5, s * 0.02, wide, wide * face_r.size.y / face_r.size.x), Color.WHITE.darkened(0.2 * (1.0 - k)))
	else:
		_sd_card(face_r.get_center(), 0.62, lerpf(0.75, 1.0, k))
	var x := face_r.end.x + 22.0
	var mid := r.position.y + r.size.y * 0.5
	draw_string(UI.fnt("bold"), Vector2(x, mid - 1.0), str(data.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(UI.CLAP_WHITE, lerpf(0.82, 1.0, k)))
	draw_string(UI.fnt("body"), Vector2(x, mid + 22.0), str(data.get("tag", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.MUTED)
	_fee(Vector2(r.end.x - 24.0, mid + 13.0), int(data.get("fee", 0)), 36, lerpf(0.78, 1.0, k))
	if k > 0.02:
		_plate(Rect2(r.position, Vector2(6.0, r.size.y)), Color(UI.TAPE, k), 3)


# 代金：コインの丸と、数字（右そろえ。right は、数字の右はしのベースライン）
func _fee(right: Vector2, fee: int, px: int, alpha: float) -> void:
	var font: Font = UI.fnt("display")
	var text := str(fee)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, right - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UI.TAPE, alpha))
	var c := right - Vector2(w + float(px) * 0.52, float(px) * 0.34)
	draw_circle(c, float(px) * 0.3, Color(UI.TAPE_DARK, alpha))
	draw_circle(c, float(px) * 0.21, Color(UI.TAPE, alpha))


# 右：いま乗っている人の大きな絵。背景の前に胸から上、下に名前だけ
func _draw_side(id: String) -> void:
	var data: Dictionary = info[id]
	var o := _origin()
	var r := Rect2(o + Vector2(SIDE_X, TOP), Vector2(BLOCK.x - SIDE_X, 7.0 * ROW_H + 6.0 * ROW_GAP))
	_plate(r, Color("16181d"), 14, Color(UI.CLAP_WHITE, 0.12), 1)
	var pic := Rect2(r.position + Vector2(26, 26), Vector2(r.size.x - 52.0, r.size.y - 26.0 - 104.0))
	_backdrop(pic, id, 1.0, 1.0)
	var tex: Texture2D = _faces.get(id)
	if tex != null:
		var side := minf(pic.size.x, pic.size.y)
		var crop := float(tex.get_width()) * pic.size.x / maxf(pic.size.y, 1.0) if pic.size.x < pic.size.y else float(tex.get_width())
		var s := float(tex.get_width())
		draw_texture_rect_region(tex, pic if pic.size.x < pic.size.y else Rect2(pic.position.x + (pic.size.x - side) * 0.5, pic.end.y - side, side, side), Rect2((s - minf(crop, s)) * 0.5, 0, minf(crop, s), s))
	else:
		_sd_card(pic.get_center(), 1.8, 1.0)
	var name := str(data.get("name", ""))
	var font: Font = UI.fnt("display")
	var px := clampi(int(34.0 * (r.size.x - 48.0) / maxf(font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x, 1.0)), 18, 34)
	draw_string(font, Vector2(r.position.x, pic.end.y + 64.0), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, UI.CLAP_WHITE)


# r の中だけに塗る多角形（はみ出す分は切る）
func _poly_in(r: Rect2, pts: PackedVector2Array, color: Color) -> void:
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for part: PackedVector2Array in Geometry2D.intersect_polygons(pts, box):
		if part.size() >= 3:
			draw_colored_polygon(part, color)


# その人の背景：色と、模様をひとつ。dim＝明るさ、alpha＝濃さ（札いっぱいに薄く敷く時は小さく）
func _backdrop(r: Rect2, id: String, dim: float, alpha: float) -> void:
	var c := func(hex: String, a := 1.0) -> Color:
		var col := Color(hex)
		return Color(col.r * dim, col.g * dim, col.b * dim, a * alpha)
	var u := minf(r.size.x, r.size.y)
	match id:
		"steady":        # 方眼：定規で引いたような、細い線
			draw_rect(r, c.call("56636f"))
			var step := maxf(u / 10.0, 7.0)
			for i in range(1, int(r.size.y / step) + 1):
				draw_line(r.position + Vector2(0, i * step), r.position + Vector2(r.size.x, i * step), c.call("ffffff", 0.14), 1.0)
			draw_line(r.position + Vector2(u * 0.14, 0), r.position + Vector2(u * 0.14, r.size.y), c.call("e5392d", 0.5), 1.0)
		"cm":            # 通販：黄色い地に、赤いギザギザ
			draw_rect(r, c.call("f2c531"))
			var pts := PackedVector2Array()
			var at := r.position + Vector2(r.size.x - u * 0.24, u * 0.25)
			for k in 24:
				pts.append(at + Vector2.from_angle(TAU * float(k) / 24.0) * u * (0.2 if k % 2 == 0 else 0.13))
			_poly_in(r, pts, c.call("e5392d"))
			draw_circle(at, u * 0.075, c.call("fff6d0"))
		"mv":            # 雰囲気：紫のぼかしと、明かりの粒
			for i in 12:
				draw_rect(Rect2(r.position + Vector2(0, r.size.y * float(i) / 12.0), Vector2(r.size.x, r.size.y / 12.0 + 1.0)), c.call("2e2158").lerp(c.call("b78fd6"), float(i) / 11.0))
			for i in 9:
				var p := r.position + Vector2(r.size.x * (0.06 + 0.88 * float(hash([i, 3]) % 100) / 99.0), r.size.y * (0.08 + 0.5 * float(hash([i, 7]) % 100) / 99.0))
				draw_circle(p, u * (0.012 + 0.006 * float(i % 3)), c.call("fff2c2", 0.75))
		"wild":          # 前衛：ちぐはぐな斜めの縞
			draw_rect(r, c.call("2f8f8a"))
			var cols := ["f06a8b", "f2c531", "5c4bd1"]
			var w := u * 0.11
			var i := 0
			var x0 := r.position.x - r.size.y
			while x0 < r.end.x:
				_poly_in(r, PackedVector2Array([Vector2(x0, r.end.y), Vector2(x0 + w, r.end.y), Vector2(x0 + w + r.size.y, r.position.y), Vector2(x0 + r.size.y, r.position.y)]), c.call(cols[i % 3]))
				x0 += w * 2.0
				i += 1
		"pro":           # 名匠：濃い木の色に、細い金の枠
			draw_rect(r, c.call("2b1d14"))
			if u > 30.0:
				draw_rect(r.grow(-u * 0.05), c.call("c9a24a", 0.9), false, 1.5)
				draw_rect(r.grow(-u * 0.075), c.call("c9a24a", 0.35), false, 1.0)
		"hype":          # ド派手：黒と赤に、稲妻
			draw_rect(r, c.call("140a0c"))
			_poly_in(r, PackedVector2Array([r.position, r.position + Vector2(u * 0.75, 0), r.position + Vector2(0, u * 0.9)]), c.call("c2182b"))
			var bolt := PackedVector2Array()
			var bx := r.end.x - u * 0.2
			for k in 6:
				bolt.append(Vector2(bx + u * (0.06 if k % 2 == 0 else -0.06), r.position.y + r.size.y * (0.06 + 0.16 * float(k))))
			draw_polyline(bolt, c.call("ffcc00"), maxf(u * 0.022, 1.5))
		_:
			draw_rect(r, c.call("1b1d21"))


# 「頼まない」：カードの絵（撮ったまま出す）
func _sd_card(at: Vector2, scale_by: float, dim: float) -> void:
	var w := 56.0 * scale_by
	var h := 72.0 * scale_by
	var o := at - Vector2(w, h) * 0.5
	var cut := 14.0 * scale_by
	draw_colored_polygon(PackedVector2Array([o, o + Vector2(w - cut, 0), o + Vector2(w, cut), o + Vector2(w, h), o + Vector2(0, h)]), Color(0.36 * dim, 0.39 * dim, 0.44 * dim))
	for i in 5:
		draw_rect(Rect2(o + Vector2(6.0 + 7.0 * float(i), 5.0) * scale_by, Vector2(4.0, 13.0) * scale_by), Color(0.83 * dim, 0.68 * dim, 0.3 * dim))
	draw_rect(Rect2(o + Vector2(8.0, 30.0) * scale_by, Vector2(w - 16.0 * scale_by, 28.0 * scale_by)), Color(0.9 * dim, 0.88 * dim, 0.83 * dim))


# 顔：そのキャラの胸から上を、小さな画面に映す（背景は透かす。札の模様が後ろに見える）
func _face(id: String) -> Texture2D:
	if not FACES.has(id):
		return null
	var tag := str(FACES[id][0])
	var path := CLIENTS % tag
	if not ResourceLoader.exists(path):
		tag = str(FACES[id][1])
		path = ""
		if not ResourceLoader.exists("res://assets/cast/cast%s_game.glb" % tag):
			return null
	var view := SubViewport.new()
	view.size = Vector2i(FACE_PX, FACE_PX)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var vis: Node3D = CastVisual.new()
	view.add_child(vis)
	vis.setup(tag, path)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.82, 0.84, 0.9)
	env.environment.ambient_light_energy = 0.7
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.55, 0.0)
	sun.light_energy = 1.25
	view.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 26.0
	view.add_child(cam)
	var head := Vector3(0, float(vis.height) - 0.22, 0)
	cam.position = head + Vector3(0.34, 0.05, 2.35)
	cam.look_at(head + Vector3(0, -0.13, 0))
	_views[id] = view
	return view.get_texture()


func open(index: int) -> void:
	show()
	for id: String in _views:
		(_views[id] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	selected = clampi(index, 0, ids.size() - 1)


func close() -> void:
	if not visible:
		return
	hide()
	for id: String in _views:
		(_views[id] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func confirm() -> void:
	var id := str(ids[selected])
	close()
	chosen.emit(id)


# キー（features/editors.gd の hook_input から）。選ぶのはマウスだけ。Esc で閉じる。開いている間は、キーをほかへ回さない
func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
	return event is InputEventKey
