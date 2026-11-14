extends Control
## 納品の時に、編集をだれに頼むかを選ぶ画面（features/editors.gd が開く）。
## 2026-11-14 ユーザー：「物で渡す形はやめて、納品するタイミングで GUI で選ぶ。金額・名前・得意分野か特徴。その人の背景に、ちょっと個性を出すぐらいでいい。
## 顔は、ランダムで作ったキャラを使えばいい」。
##   ・札を横に並べる（頼まない＋編集者の数）。札の上半分が、その人の背景（色と模様）と顔。下に、名前・特徴・代金
##   ・← → で選ぶ・Enter で決めて納品・Esc でやめる。マウスは、札に乗せると選ばれ、押すと決まる
##   ・顔は、紹介動画の依頼主たち（ランダム生成のキャラ。godot/trailer/clients/。公開リポジトリには無い）。無ければ、班のキャラの素材で代わりにする
##   ・字の決まり：既定の書体に黒い縁を付けない。字の下に帯を敷かない（札の地の上に、じかに置く）
const UI := preload("res://scripts/ui/ui_theme.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")

signal chosen(id: String)
signal closed

const CARD := Vector2(166, 318)
const FACE_H := 170.0
# 編集者ごとの顔（ランダム生成のキャラの番号）と、無い時の代わり（班のキャラ）
const FACES := {"steady": ["31", "03"], "cm": ["22", "04"], "mv": ["34", "01"], "wild": ["37", "09"], "pro": ["39", "M02"], "hype": ["23", "06"]}
const CLIENTS := "res://trailer/clients/cast%s_game.glb"

var ids: Array = []
var info := {}
var selected := 0
var _cards: Array = []
var _row: HBoxContainer
var _views := {}                 # 編集者 → 顔を映す SubViewport


class Card extends Control:
	var id := ""
	var data := {}
	var face: Texture2D
	var on := false
	var lift := 0.0

	func _ready() -> void:
		custom_minimum_size = CARD
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		var want := 1.0 if on else 0.0
		if not is_equal_approx(lift, want):
			lift = lerpf(lift, want, 1.0 - exp(-18.0 * delta))
			queue_redraw()

	func _draw() -> void:
		var up := -12.0 * lift
		var r := Rect2(Vector2(0, 12.0 + up), CARD - Vector2(0, 12.0))
		var dim := lerpf(0.62, 1.0, lift)
		draw_rect(Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, UI.BOARD)
		var top := Rect2(r.position, Vector2(r.size.x, FACE_H))
		_backdrop(top, dim)
		if face != null:
			draw_texture_rect(face, Rect2(top.position.x + (top.size.x - FACE_H) * 0.5, top.position.y, FACE_H, FACE_H), false, Color(dim, dim, dim))
		elif id == "none":
			_sd_card(top.get_center(), dim)
		var x := r.position.x + 12.0
		var y := top.end.y + 26.0
		var w := r.size.x - 24.0
		var name_font: Font = UI.fnt("bold")
		var name := str(data.get("name", ""))
		var px := clampi(int(17.0 * w / maxf(name_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, 1.0)), 12, 17)
		draw_string(name_font, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UI.CLAP_WHITE, lerpf(0.7, 1.0, lift)))
		draw_multiline_string(UI.fnt("body"), Vector2(x, y + 24.0), str(data.get("tag", "")), HORIZONTAL_ALIGNMENT_LEFT, w, 13, 3, Color(UI.MUTED, lerpf(0.8, 1.0, lift)))
		var fee := int(data.get("fee", 0))
		var fee_text := str(fee) if fee > 0 else "0"
		var fee_font: Font = UI.fnt("display")
		var base := r.end.y - 16.0
		draw_string(fee_font, Vector2(x, base), fee_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.TAPE if on else Color(UI.TAPE, 0.6))
		draw_string(UI.fnt("body"), Vector2(x + fee_font.get_string_size(fee_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 6.0, base), "コイン", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
		if lift > 0.02:
			draw_rect(r.grow(1.0), Color(UI.TAPE, lift), false, 3.0)

	# その人の背景：色と、模様をひとつ
	func _backdrop(r: Rect2, dim: float) -> void:
		var c := func(hex: String, a := 1.0) -> Color:
			var col := Color(hex)
			return Color(col.r * dim, col.g * dim, col.b * dim, a)
		match id:
			"steady":        # 方眼：定規で引いたような、細い横線
				draw_rect(r, c.call("56636f"))
				for i in range(1, int(r.size.y / 17.0) + 1):
					draw_line(r.position + Vector2(0, i * 17.0), r.position + Vector2(r.size.x, i * 17.0), c.call("ffffff", 0.13), 1.0)
				draw_line(r.position + Vector2(22, 0), r.position + Vector2(22, r.size.y), c.call("e5392d", 0.45), 1.0)
			"cm":            # 通販：黄色い地に、赤いギザギザ
				draw_rect(r, c.call("f2c531"))
				var pts := PackedVector2Array()
				var at := r.position + Vector2(r.size.x * 0.76, r.size.y * 0.27)
				for k in 24:
					pts.append(at + Vector2.from_angle(TAU * float(k) / 24.0) * (34.0 if k % 2 == 0 else 22.0))
				draw_colored_polygon(pts, c.call("e5392d"))
				draw_circle(at, 13.0, c.call("fff6d0"))
			"mv":            # 雰囲気：紫のぼかしと、明かりの粒
				for i in 12:
					var k := float(i) / 11.0
					draw_rect(Rect2(r.position + Vector2(0, r.size.y * float(i) / 12.0), Vector2(r.size.x, r.size.y / 12.0 + 1.0)), c.call("2e2158").lerp(c.call("b78fd6"), k))
				for i in 9:
					var p := r.position + Vector2(r.size.x * (0.1 + 0.8 * float(hash([i, 3]) % 100) / 99.0), r.size.y * (0.08 + 0.5 * float(hash([i, 7]) % 100) / 99.0))
					draw_circle(p, 2.0 + float(i % 3), c.call("fff2c2", 0.75))
			"wild":          # 前衛：ちぐはぐな斜めの縞
				draw_rect(r, c.call("2f8f8a"))
				var cols := ["f06a8b", "f2c531", "5c4bd1"]
				for i in range(-4, 9):
					var x0 := r.position.x + float(i) * 34.0
					var quad := PackedVector2Array([Vector2(x0, r.end.y), Vector2(x0 + 17.0, r.end.y), Vector2(x0 + 17.0 + r.size.y, r.position.y), Vector2(x0 + r.size.y, r.position.y)])
					for k in quad.size():
						quad[k].x = clampf(quad[k].x, r.position.x, r.end.x)
					if quad[1].x - quad[0].x > 0.5 or quad[2].x - quad[3].x > 0.5:
						draw_colored_polygon(quad, c.call(cols[posmod(i, 3)]))
			"pro":           # 名匠：濃い木の色に、細い金の枠
				draw_rect(r, c.call("2b1d14"))
				draw_rect(r.grow(-9.0), c.call("c9a24a", 0.9), false, 1.5)
				draw_rect(r.grow(-13.0), c.call("c9a24a", 0.35), false, 1.0)
			"hype":          # ド派手：黒と赤に、稲妻
				draw_rect(r, c.call("140a0c"))
				draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.55, 0), r.position + Vector2(0, r.size.y * 0.7)]), c.call("c2182b"))
				for side: float in [0.2, 0.82]:
					var bolt := PackedVector2Array()
					var bx := r.position.x + r.size.x * side
					for k in 6:
						bolt.append(Vector2(bx + (10.0 if k % 2 == 0 else -10.0), r.position.y + r.size.y * (0.08 + 0.15 * float(k))))
					draw_polyline(bolt, c.call("ffcc00"), 4.0)
			_:
				draw_rect(r, c.call("1b1d21"))
				draw_rect(r.grow(-10.0), c.call("ffffff", 0.08), false, 1.0)

	# 「頼まない」：カードの絵（撮ったまま出す）
	func _sd_card(at: Vector2, dim: float) -> void:
		var w := 56.0
		var h := 72.0
		var o := at - Vector2(w, h) * 0.5
		var body := PackedVector2Array([o + Vector2(0, 0), o + Vector2(w - 14.0, 0), o + Vector2(w, 14.0), o + Vector2(w, h), o + Vector2(0, h)])
		draw_colored_polygon(body, Color(0.36 * dim, 0.39 * dim, 0.44 * dim))
		for i in 5:
			draw_rect(Rect2(o + Vector2(6.0 + 7.0 * float(i), 5.0), Vector2(4.0, 13.0)), Color(0.83 * dim, 0.68 * dim, 0.3 * dim))
		draw_rect(Rect2(o + Vector2(8.0, 30.0), Vector2(w - 16.0, 28.0)), Color(0.9 * dim, 0.88 * dim, 0.83 * dim))


func setup(order: Array, editors: Dictionary) -> void:
	ids = order.duplicate()
	info = editors
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.05, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var head := UI.label("編集を、だれに頼む？", 34, UI.CLAP_WHITE, "display")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(head)
	var sub := UI.label("代金は、納品のあとの精算で引かれる。出来上がりは、試写会で流れるまで分からない", 15, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	column.add_child(UI.gap(14))
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_row)
	for i in ids.size():
		var card := Card.new()
		card.id = str(ids[i])
		card.data = info[ids[i]]
		card.face = _face(card.id)
		card.mouse_entered.connect(func() -> void: select(i))
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				select(i)
				confirm())
		_row.add_child(card)
		_cards.append(card)
	column.add_child(UI.gap(14))
	var keys := UI.label("← →　選ぶ　　　Enter　決めて納品　　　Esc　やめる", 15, UI.MUTED)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)
	hide()


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
	view.size = Vector2i(340, 340)
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
	select(clampi(index, 0, ids.size() - 1))


func close() -> void:
	if not visible:
		return
	hide()
	for id: String in _views:
		(_views[id] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func select(index: int) -> void:
	selected = posmod(index, ids.size())
	for i in _cards.size():
		(_cards[i] as Card).on = i == selected
		(_cards[i] as Card).queue_redraw()


func confirm() -> void:
	var id := str(ids[selected])
	close()
	chosen.emit(id)


# キー（features/editors.gd の hook_input から）。開いている間は、ほかへ回さない
func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_LEFT, KEY_A:
				select(selected - 1)
			KEY_RIGHT, KEY_D:
				select(selected + 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not event.echo:
					confirm()
			KEY_ESCAPE:
				close()
	return event is InputEventKey
