extends RefCounted
## 精算の画面の部品（production_hud.gd の _build_settled が使う）。
## 映画館の上の「興行成績」のボード（金の縁と電球）・入れ替わる数字の札・給料袋。


# ボード：黒い板、金の縁、上の辺に電球
class Marquee extends StyleBox:

	func _init() -> void:
		content_margin_left = 30
		content_margin_right = 30
		content_margin_top = 34
		content_margin_bottom = 22

	func _draw(item: RID, r: Rect2) -> void:
		FilmSet._shadow(item, r, 10.0, 0.5)
		RenderingServer.canvas_item_add_rect(item, r.grow(6.0), Color("b38a3a"))
		RenderingServer.canvas_item_add_rect(item, r.grow(2.0), Color("6b5020"))
		RenderingServer.canvas_item_add_rect(item, r, Color("141414"))
		# 電球（上下の辺）
		var n := int(r.size.x / 34.0)
		for side: float in [r.position.y + 12.0, r.end.y - 9.0]:
			for i in n:
				var c := Vector2(r.position.x + 17.0 + float(i) * (r.size.x - 34.0) / float(maxi(n - 1, 1)), side)
				RenderingServer.canvas_item_add_circle(item, c, 7.0, Color(1.0, 0.82, 0.45, 0.25))
				RenderingServer.canvas_item_add_circle(item, c, 4.0, Color("fff3c8"))


# 数字の札：label の文字が変わると、札がパタパタ入れ替わりながら左から順に決まる。
# 中身は label（見えない）が持つ。production_hud の精算の更新は label.text を書くだけでよい
class Tiles extends Control:
	const TW := 30.0
	const TH := 44.0
	const GAP := 4.0
	const SPIN := "0123456789"
	var label: Label
	var delay := 0.0                 # この行が回り始めるまでの秒
	var tile_px := 32
	var _target := ""
	var _shown: Array = []
	var _settle: Array = []
	var _t := 0.0
	var _next_flip := 0.0

	func setup(value: Label, start_delay: float, big: bool = false) -> Control:
		label = value
		delay = start_delay
		if big:
			tile_px = 40
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return self

	func _tw() -> float:
		return TW * float(tile_px) / 32.0

	func _th() -> float:
		return TH * float(tile_px) / 32.0

	# 見せる字：「 コイン」は札にしない（単位は横の字で）
	func _wanted() -> String:
		return label.text.replace(" コイン", "").replace("コイン", "").strip_edges()

	func restart() -> void:
		_target = ""

	func _process(delta: float) -> void:
		if label == null or not is_visible_in_tree():
			return
		var want := _wanted()
		if want != _target:
			_target = want
			_t = 0.0
			_shown.clear()
			_settle.clear()
			for i in want.length():
				_shown.append(SPIN[randi() % SPIN.length()])
				_settle.append(delay + 0.45 + 0.09 * float(i))
			custom_minimum_size = Vector2(float(want.length()) * (_tw() + GAP), _th())
			update_minimum_size()
		_t += delta
		if _t < delay:
			return
		_next_flip -= delta
		var flip := _next_flip <= 0.0
		if flip:
			_next_flip = 0.055
		var changed := false
		for i in _shown.size():
			var real: String = _target[i]
			if _t >= float(_settle[i]):
				if _shown[i] != real:
					_shown[i] = real
					changed = true
			elif flip:
				_shown[i] = SPIN[randi() % SPIN.length()]
				changed = true
		if changed:
			queue_redraw()

	func _draw() -> void:
		var font := FilmSet.font("stencil")
		var red := _target.begins_with("−") or _target.begins_with("-") or _target.begins_with("払")
		for i in _shown.size():
			var x := float(i) * (_tw() + GAP)
			var r := Rect2(Vector2(x, 0), Vector2(_tw(), _th()))
			var face := Color("d75a42") if red else Color("f4efe2")
			var ink := Color("fff4e4") if red else Color("111111")
			draw_rect(r, face)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4.0), Vector2(r.size.x, 4.0)), Color(0, 0, 0, 0.15))
			var ch: String = _shown[i]
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tile_px).x
			draw_string(font, Vector2(x + (_tw() - w) * 0.5, _th() * 0.5 + float(tile_px) * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tile_px, ink)
			# 札の真ん中の割れ目（上下2枚で1文字）
			draw_line(Vector2(x, _th() * 0.5), Vector2(x + _tw(), _th() * 0.5), Color(0, 0, 0, 0.35), 1.5)


# 給料袋（茶封筒）。上の三角のふた、「給料」の字、下に一言
class Envelope extends Control:
	var note := ""
	var empty := false

	func _init() -> void:
		custom_minimum_size = Vector2(300, 200)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("c9a46a"))
		draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.position.y + 70.0)]), Color("b8915a"))
		draw_polyline(PackedVector2Array([r.position, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 70.0), Vector2(r.end.x, r.position.y)]), Color(0, 0, 0, 0.18), 1.5)
		var mincho := FilmSet.font("mincho")
		var title := "給　料" if not empty else "空　袋"
		draw_string(mincho, Vector2(0, 128), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color("3a2414"))
		draw_string(FilmSet.font("marker"), Vector2(0, 168), note, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color("3a2414"))
