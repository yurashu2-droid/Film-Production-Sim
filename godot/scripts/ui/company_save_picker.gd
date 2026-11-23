extends Control
## タイトル画面の「ひとりで遊ぶ」「会社を開く」の次に出る、会社（セーブの枠）を選ぶ画面。
## 2026-11-24 見た目を作り直した（1 版は Codex：紙のボードに灰色のボタンが3つと、説明の文）。
## 見た目の決まりは、納品の編集者を選ぶ画面（ui/editor_pick.gd。ユーザーが良いと言った形）にそろえる：
##   ・見出しは「会社」だけ。説明の文・キーの案内は出さない
##   ・横長の札を縦に並べる。マウスを乗せると札が明るく、左はしに黄色い線。押すと決まる
##   ・閉じるのは、右上の ×・Esc・右クリック
## 札の中身：左に枠の番号の大きな数字（使っている会社は黄色・空きは「＋」・読めない時は ×）、
##           まん中に会社の名前と「何日目・作品何本・最後に保存した日時」、右に貯金（コインの丸と数字）。
signal selected(slot: int)
signal closed

const UI := preload("res://scripts/ui/ui_theme.gd")
const Saves := preload("res://scripts/company_saves.gd")

const BLOCK := Vector2(760, 0)             # 幅（高さは枠の数で決まる）
const ROW_H := 104.0
const ROW_GAP := 10.0
const TOP := 84.0                          # 見出しの下、札が始まる所
const BADGE_W := 104.0
const BROKEN := Color("d0574a")

var _rows: Array = []                      # 枠ごと：{slot, state("used"/"empty"/"broken"), data, updated}
var _glow: Array = []
var _over := -1
var _over_close := false
var _host := false
var _back: Button                          # キーボードで閉じる時の受け口（見た目には出さない）


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_back = Button.new()
	_back.focus_mode = Control.FOCUS_ALL
	_back.flat = true
	_back.modulate = Color(1, 1, 1, 0)
	_back.size = Vector2.ONE
	_back.pressed.connect(func(): closed.emit())
	add_child(_back)


func open(store: RefCounted, host_requested: bool) -> void:
	_host = host_requested
	_rows.clear()
	_glow.clear()
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var entry: Dictionary = store.status(slot)
		var row := {"slot": slot, "state": "empty", "data": {}, "updated": ""}
		if int(entry.error) != OK:
			row.state = "broken"
		elif not (entry.data as Dictionary).is_empty():
			row.state = "used"
			row.data = entry.data
			row.updated = str(entry.get("updated", ""))
		_rows.append(row)
		_glow.append(0.0)
	_over = -1
	show()
	_back.grab_focus()
	queue_redraw()


# 札を押したのと同じ（i は 0 から。確認が使う）
func press(i: int) -> void:
	if _usable(i):
		selected.emit(int(_rows[i].slot))


func _height() -> float:
	return TOP + float(_rows.size()) * (ROW_H + ROW_GAP) - ROW_GAP


func _origin() -> Vector2:
	return ((size - Vector2(BLOCK.x, _height())) * 0.5).floor()


func _row_rect(i: int) -> Rect2:
	return Rect2(_origin() + Vector2(0, TOP + float(i) * (ROW_H + ROW_GAP)), Vector2(BLOCK.x, ROW_H))


func _close_rect() -> Rect2:
	return Rect2(_origin() + Vector2(BLOCK.x - 44.0, 10.0), Vector2(44, 44))


func _usable(i: int) -> bool:
	return i >= 0 and i < _rows.size() and str(_rows[i].state) != "broken"


func _process(delta: float) -> void:
	if not visible:
		return
	var moved := false
	for i in _glow.size():
		var want := 1.0 if i == _over and _usable(i) else 0.0
		var next := move_toward(float(_glow[i]), want, delta * 7.0)
		moved = moved or not is_equal_approx(next, float(_glow[i]))
		_glow[i] = next
	if moved:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var before := _over
		_over = -1
		for i in _rows.size():
			if _row_rect(i).has_point(event.position):
				_over = i
		var was := _over_close
		_over_close = _close_rect().has_point(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _usable(_over) or _over_close else Control.CURSOR_ARROW
		if before != _over or was != _over_close:
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and _close_rect().has_point(event.position)):
			closed.emit()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in _rows.size():
				if _row_rect(i).has_point(event.position) and _usable(i):
					selected.emit(int(_rows[i].slot))
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.93))
	var o := _origin()
	draw_string(UI.fnt("display"), o + Vector2(0, 54), "会社", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UI.CLAP_WHITE)
	if _host:
		var w := UI.fnt("display").get_string_size("会社", HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		_tag(o + Vector2(w + 18.0, 22.0), "みんなで")
	var cr := _close_rect()
	var cc := UI.CLAP_WHITE if _over_close else UI.MUTED
	draw_line(cr.position + Vector2(12, 12), cr.end - Vector2(12, 12), cc, 2.5)
	draw_line(cr.position + Vector2(28, 12), cr.position + Vector2(12, 28), cc, 2.5)
	for i in _rows.size():
		_draw_row(i)


# 見出しの横の小さな札（会社を開く＝みんなで遊ぶ時）
func _tag(at: Vector2, text: String) -> void:
	var font: Font = UI.fnt("bold")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 22.0
	_plate(Rect2(at, Vector2(w, 30)), Color(UI.TAPE, 0.16), 15, Color(UI.TAPE, 0.7), 1)
	draw_string(font, at + Vector2(11, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.TAPE)


# 角の丸い面
func _plate(r: Rect2, color: Color, radius: int, edge := Color(0, 0, 0, 0), edge_w := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.set_border_width_all(edge_w)
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), r)


func _draw_row(i: int) -> void:
	var row: Dictionary = _rows[i]
	var state := str(row.state)
	var k: float = _glow[i]
	var r := _row_rect(i).grow_individual(10.0 * k, 0, 10.0 * k, 0)
	_plate(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3), 10)
	if state == "empty":
		# 空きの枠：中を塗らず、点線のふち
		_plate(r, Color("16181d", 0.55).lerp(Color("2a2c33"), k), 10)
		_dashed(r.grow(-1.0), Color(UI.CLAP_WHITE, lerpf(0.22, 0.6, k)))
	else:
		_plate(r, Color("16181d").lerp(Color("2a2c33"), k), 10, Color(UI.CLAP_WHITE, 0.55 * k), 1 if k > 0.3 else 0)
	# 左：枠の番号
	var badge := Rect2(r.position + Vector2(8.0 + 6.0 * k, 8.0), Vector2(BADGE_W, ROW_H - 16.0))
	var font: Font = UI.fnt("display")
	var mid := r.position.y + r.size.y * 0.5
	match state:
		"used":
			_plate(badge, Color(UI.TAPE, lerpf(0.85, 1.0, k)), 7)
			_stripes(badge, Color(UI.TAPE_DARK, 0.35))
			draw_string(font, Vector2(badge.position.x, badge.get_center().y + 24.0), str(row.slot), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 66, Color("1d1a14"))
		"empty":
			var c := badge.get_center()
			var col := Color(UI.CLAP_WHITE, lerpf(0.4, 0.95, k))
			draw_line(c - Vector2(16, 0), c + Vector2(16, 0), col, 4.0)
			draw_line(c - Vector2(0, 16), c + Vector2(0, 16), col, 4.0)
		"broken":
			_plate(badge, Color(BROKEN, 0.14), 7, Color(BROKEN, 0.5), 1)
			var c := badge.get_center()
			draw_line(c - Vector2(13, 13), c + Vector2(13, 13), BROKEN, 4.0)
			draw_line(c + Vector2(13, -13), c + Vector2(-13, 13), BROKEN, 4.0)
	var x := badge.end.x + 26.0
	var bright := lerpf(0.84, 1.0, k)
	match state:
		"used":
			var data: Dictionary = row.data
			var name := str(data.get("company", ""))
			if name.strip_edges() == "":
				name = "名前のない会社"
			draw_string(UI.fnt("bold"), Vector2(x, mid - 4.0), name, HORIZONTAL_ALIGNMENT_LEFT, BLOCK.x - (x - r.position.x) - 190.0, 30, Color(UI.CLAP_WHITE, bright))
			var films: int = (data.get("films", []) as Array).size()
			var parts := ["%d日目" % int(data.get("day", 1)), "作品 %d本" % films]
			var when := _when(str(row.updated))
			if when != "":
				parts.append(when)
			draw_string(UI.fnt("body"), Vector2(x, mid + 28.0), "   ·   ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.MUTED)
			_coins(Vector2(r.end.x - 28.0, mid + 14.0), int(data.get("wallet", 0)), 38, bright)
		"empty":
			draw_string(UI.fnt("bold"), Vector2(x, mid + 11.0), "新しい会社", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(UI.CLAP_WHITE, lerpf(0.55, 1.0, k)))
		"broken":
			draw_string(UI.fnt("bold"), Vector2(x, mid - 4.0), "読み込めません", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(BROKEN, 0.95))
			draw_string(UI.fnt("body"), Vector2(x, mid + 26.0), "保存のファイルが壊れています", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.MUTED)
	if k > 0.02:
		_plate(Rect2(r.position, Vector2(6.0, r.size.y)), Color(UI.TAPE, k), 3)


# 保存の日時（"2026-11-23 22:21:57"）を「11/23 22:21」に
func _when(stamp: String) -> String:
	var parts := stamp.replace("T", " ").split(" ")
	if parts.size() < 2:
		return ""
	var d := parts[0].split("-")
	var t := parts[1].split(":")
	if d.size() < 3 or t.size() < 2:
		return ""
	return "%d/%d %s:%s" % [int(d[1]), int(d[2]), t[0], t[1]]


# 貯金：コインの丸と、数字（右そろえ。right は、数字の右はしのベースライン）
func _coins(right: Vector2, amount: int, px: int, alpha: float) -> void:
	var font: Font = UI.fnt("display")
	var text := str(amount)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, right - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UI.TAPE, alpha))
	var c := right - Vector2(w + float(px) * 0.52, float(px) * 0.34)
	draw_circle(c, float(px) * 0.3, Color(UI.TAPE_DARK, alpha))
	draw_circle(c, float(px) * 0.21, Color(UI.TAPE, alpha))


# 番号の札の、うすい斜めの縞（カチンコの縞の名残。札の中だけ）
func _stripes(r: Rect2, color: Color) -> void:
	var step := 22.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(x, r.end.y)
		var b := Vector2(x + r.size.y, r.position.y)
		var pts := PackedVector2Array([a, b, b + Vector2(9, 0), a + Vector2(9, 0)])
		var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(pts, box):
			if part.size() >= 3:
				draw_colored_polygon(part, color)
		x += step


# 点線の四角（角は丸めない）
func _dashed(r: Rect2, color: Color) -> void:
	var dash := 10.0
	var gap := 7.0
	for edge: Array in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var t := 0.0
		while t < length:
			draw_line(a + dir * t, a + dir * minf(t + dash, length), color, 1.5)
			t += dash + gap
