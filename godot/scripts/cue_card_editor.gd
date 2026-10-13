extends CanvasLayer
# カンペと等身大パネルのペイント画面。開いている間は歩けない。
# 筆の命令（点の列・色・太さ）をホストへ送り、全員の絵に同じ線が引かれる。
#   カンペ　　　：横長。黒・赤・青・消しゴム
#   等身大パネル：縦長。絵の具14色・下塗り・見本の貼り付け
const Canvas := preload("res://scripts/cue_card_canvas.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
var cards: Node
var board: RigidBody3D           # いま描いている物
var opened := false
var root: Control
var sheet: PanelContainer
var canvas: Control
var color := Color.BLACK
var radius := 8.0
var _points := PackedVector2Array()
var _last := Vector2.ZERO
var _time := 0.0
var _previous_mouse := Input.MOUSE_MODE_CAPTURED
var _built_for: RigidBody3D
var _swatch: ColorRect           # いまの色（等身大パネル）

func _ready() -> void:
	layer = 6
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.018,0.025,0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

func _portrait() -> bool:
	return board != null and board.res.y > board.res.x

func _aspect() -> float:
	return float(board.res.x)/board.res.y

# 描く物に合わせて、道具の並びを組む（物が替わったときだけ）
func _build() -> void:
	if _built_for == board and sheet != null:
		canvas.texture = board.texture
		return
	_built_for = board
	if sheet != null:
		root.remove_child(sheet)
		sheet.queue_free()
	sheet = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20252d")
	style.set_content_margin_all(18)
	style.set_corner_radius_all(8)
	sheet.add_theme_stylebox_override("panel",style)
	root.add_child(sheet)
	canvas = Canvas.new()
	canvas.texture = board.texture
	canvas.resolution = board.res
	canvas.point_drawn.connect(_point)
	canvas.stroke_finished.connect(flush)
	if _portrait():
		_build_panel()
	else:
		_build_card()

# カンペ：題・道具の横1列・紙・ひとこと
func _build_card() -> void:
	color = Color.BLACK
	radius = 8.0
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	sheet.add_child(stack)
	var title := Label.new()
	title.text = "カンペに書く　—　書いた内容は、そのまま相手に見えます"
	title.add_theme_font_override("font",cards.game.font)
	title.add_theme_font_size_override("font_size",22)
	stack.add_child(title)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",8)
	stack.add_child(tools)
	var group := ButtonGroup.new()
	for item in cards.CARD_COLORS:
		var ink_color: Color = item[1]
		var button := _button(tools,item[0])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = ink_color == Color.BLACK
		button.pressed.connect(func(): flush(); color = ink_color)
	var width := OptionButton.new()
	for option in ["細い","ふつう","太い"]: width.add_item(option)
	width.selected = 1
	width.add_theme_font_override("font",cards.game.font)
	width.item_selected.connect(func(i: int): flush(); radius = [4.0,8.0,16.0][i])
	tools.add_child(width)
	_button(tools,"全消去").pressed.connect(func(): flush(); cards.h_clear.rpc_id(1,board.pid))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	_button(tools,"閉じる（F / Esc）").pressed.connect(close)
	stack.add_child(canvas)
	var hint := Label.new()
	hint.text = "左ドラッグで書く ／ 上の綴じ穴を避けて大きな文字で ／ 正面の相手から見える向きで表示"
	hint.add_theme_font_override("font",cards.game.font)
	hint.add_theme_font_size_override("font_size",16)
	stack.add_child(hint)

# 等身大パネル：左に絵の具と道具、右に縦長の紙
func _build_panel() -> void:
	color = cards.PANEL_COLORS[0][1]
	radius = 10.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	sheet.add_child(row)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation",10)
	side.custom_minimum_size.x = 316
	row.add_child(side)
	side.add_child(UI.overline("等身大パネル"))
	side.add_child(UI.label("好きな絵を描く",26,UI.CLAP_WHITE,"display"))
	var lead := UI.label("描いた絵は、そのまま撮影に映る。\n何の役にもなれるジョーカー。役は、閉じてから物を見て Y で決める。",14,UI.MUTED,"body")
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.custom_minimum_size.x = 316
	side.add_child(lead)
	side.add_child(UI.hairline())
	# 絵の具
	var paint_head := HBoxContainer.new()
	paint_head.add_theme_constant_override("separation",10)
	side.add_child(paint_head)
	var paint_title := UI.overline("絵の具")
	paint_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_head.add_child(paint_title)
	var swatch_frame := PanelContainer.new()
	swatch_frame.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,0),Color(1,1,1,0.5),1,3,2,2))
	paint_head.add_child(swatch_frame)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(56,14)
	_swatch.color = color
	swatch_frame.add_child(_swatch)
	var palette := GridContainer.new()
	palette.columns = 7
	palette.add_theme_constant_override("h_separation",8)
	palette.add_theme_constant_override("v_separation",8)
	side.add_child(palette)
	var group := ButtonGroup.new()
	for item: Array in cards.PANEL_COLORS:
		var paint: Color = item[1]
		var chip := Button.new()
		chip.toggle_mode = true
		chip.button_group = group
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(38,38)
		chip.tooltip_text = str(item[0])
		chip.add_theme_stylebox_override("normal",UI.box(paint,Color(0,0,0,0.55),2,5,0,0))
		chip.add_theme_stylebox_override("hover",UI.box(paint,Color(1,1,1,0.55),2,5,0,0))
		chip.add_theme_stylebox_override("pressed",UI.box(paint,UI.CLAP_WHITE,4,5,0,0))
		chip.add_theme_stylebox_override("hover_pressed",UI.box(paint,UI.CLAP_WHITE,4,5,0,0))
		chip.button_pressed = paint.is_equal_approx(color)
		chip.pressed.connect(func(): flush(); color = paint; _swatch.color = paint)
		palette.add_child(chip)
	# 筆の太さ
	side.add_child(UI.overline("筆の太さ"))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation",8)
	side.add_child(sizes)
	var size_group := ButtonGroup.new()
	for item: Array in [["細い",5.0],["ふつう",10.0],["太い",22.0],["特大",46.0]]:
		var width: float = item[1]
		var b := _tool(sizes,str(item[0]),true)
		b.button_group = size_group
		b.button_pressed = is_equal_approx(width,radius)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): flush(); radius = width)
	side.add_child(UI.hairline())
	_tool(side,"全面を、いまの色で塗る").pressed.connect(func(): flush(); cards.h_fill.rpc_id(1,board.pid,color))
	_tool(side,"白紙に戻す").pressed.connect(func(): flush(); cards.h_clear.rpc_id(1,board.pid))
	# 素材に付いていた見本（架空の俳優の絵）
	side.add_child(UI.overline("見本を貼る（代役の俳優）"))
	var samples := HBoxContainer.new()
	samples.add_theme_constant_override("separation",8)
	side.add_child(samples)
	for item: Array in [["俳優 A","actor_a"],["俳優 B","actor_b"]]:
		var id: String = item[1]
		var b := _tool(samples,str(item[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): flush(); cards.h_preset.rpc_id(1,board.pid,id))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var hint := UI.label("左ドラッグで描く。全員に同じ絵が見える。",13,UI.MUTED,"body")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 316
	side.add_child(hint)
	var done := UI.KeyButton.new().setup("閉じる","F","tape",17,48)
	done.pressed.connect(close)
	side.add_child(done)
	# 紙（木の板に留めた紙に見えるよう、薄いふちを付ける）
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",UI.box(Color("c9b48d"),Color("8a744e"),1,2,8,8))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	frame.add_child(canvas)

func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 38
	button.add_theme_font_override("font",cards.game.font)
	button.add_theme_font_size_override("font_size",18)
	parent.add_child(button)
	return button

func _tool(parent: Control, text: String, toggle: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	UI.style_button(button,"slate",15,38)
	button.focus_mode = Control.FOCUS_NONE
	if toggle:
		# 選んでいるものは、白地に黒い字
		button.toggle_mode = true
		var on := UI.box(UI.CLAP_WHITE,Color(0,0,0,0),0,4,12,8)
		button.add_theme_stylebox_override("pressed",on)
		button.add_theme_stylebox_override("hover_pressed",on)
		button.add_theme_color_override("font_pressed_color",UI.INK)
		button.add_theme_color_override("font_hover_pressed_color",UI.INK)
	parent.add_child(button)
	return button

func open_card() -> void:
	open_board(cards.card)

func open_board(target: RigidBody3D) -> void:
	if opened or target == null or not cards.allowed(target.pid,Net.my_id()): return
	board = target
	_build()
	_previous_mouse = Input.mouse_mode
	opened = true
	root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cards.game.local_player().velocity = Vector3.ZERO
	_layout()

func close() -> void:
	if not opened: return
	flush()
	canvas.drawing = false
	opened = false
	root.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cards.game.ui_blocking() else _previous_mouse

func handle_input(event: InputEvent) -> bool:
	if not opened: return false
	if event is InputEventKey:
		if event.pressed and not event.echo and (event.physical_keycode in [KEY_F,KEY_ESCAPE] or event.is_action_pressed("operate")):
			close()
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: close()
		return true
	return false

func _point(point: Vector2, first: bool) -> void:
	if first:
		flush()
		_last = point
	if _points.is_empty(): _points.append(_last)
	_points.append(point)
	_last = point
	# Solo reflects each motion event immediately; network strokes are batched at 20 Hz.
	if not Net.has_peers() or _points.size() >= 32: flush()

func flush() -> void:
	if _points.is_empty(): return
	cards.h_draw.rpc_id(1,board.pid,_points,color,radius)
	_points = PackedVector2Array()
	canvas.queue_redraw()
	_time = 0.0

func _process(delta: float) -> void:
	if not opened: return
	if not cards.allowed(board.pid,Net.my_id()):
		close()
		return
	_time += delta
	if _time >= 0.05: flush()
	canvas.queue_redraw()
	_layout()

func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if _portrait():
		# 縦長の紙：画面の高さいっぱいに近く
		var tall := minf(1200.0,screen.y-110.0)
		canvas.custom_minimum_size = Vector2(tall*_aspect(),tall)
	else:
		var width := minf(1024,minf(screen.x-72,(screen.y-220)*_aspect()))
		canvas.custom_minimum_size = Vector2(width,width/_aspect())
	sheet.size = sheet.get_combined_minimum_size()
	sheet.position = (screen-sheet.size)*0.5
