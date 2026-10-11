extends CanvasLayer
const Canvas := preload("res://scripts/cue_card_canvas.gd")
var cards: Node
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
	sheet = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20252d")
	style.set_content_margin_all(18)
	style.set_corner_radius_all(8)
	sheet.add_theme_stylebox_override("panel",style)
	root.add_child(sheet)
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
	for item in [["黒",Color.BLACK],["赤",Color.RED],["青",Color.BLUE],["消しゴム",Color.WHITE]]:
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
	_button(tools,"全消去").pressed.connect(func(): flush(); cards.h_clear.rpc_id(1,cards.card.pid))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	_button(tools,"閉じる（F / Esc）").pressed.connect(close)
	canvas = Canvas.new()
	canvas.texture = cards.card.texture
	canvas.point_drawn.connect(_point)
	canvas.stroke_finished.connect(flush)
	stack.add_child(canvas)
	var hint := Label.new()
	hint.text = "左ドラッグで書く ／ 大きな文字がおすすめ ／ 正面の相手から見える向きで表示"
	hint.add_theme_font_override("font",cards.game.font)
	hint.add_theme_font_size_override("font_size",16)
	stack.add_child(hint)

func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 38
	button.add_theme_font_override("font",cards.game.font)
	button.add_theme_font_size_override("font_size",18)
	parent.add_child(button)
	return button

func open_card() -> void:
	if opened or not cards.allowed(cards.card.pid,Net.my_id()): return
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
	cards.h_draw.rpc_id(1,cards.card.pid,_points,color,radius)
	_points = PackedVector2Array()
	canvas.queue_redraw()
	_time = 0.0

func _process(delta: float) -> void:
	if not opened: return
	if not cards.allowed(cards.card.pid,Net.my_id()):
		close()
		return
	_time += delta
	if _time >= 0.05: flush()
	canvas.queue_redraw()
	_layout()

func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var width := minf(1024,minf(screen.x-72,(screen.y-220)*1.6))
	canvas.custom_minimum_size = Vector2(width,width/1.6)
	sheet.size = sheet.get_combined_minimum_size()
	sheet.position = (screen-sheet.size)*0.5
