extends CanvasLayer
# モニター係の作業画面。切り替えの権限はホストが管理する。
var game: Node
var opened := false
var root: Control
var sheet: Panel
var title: Label
var status: Label
var program: TextureRect
var previews: Array[TextureRect] = []
var choices: Array[Button] = []
var cues: Array[Button] = []
var control_button: Button
var close_button: Button
var hint: Label
# 場面の列を持つ依頼（production_beats.gd）：枠の印（場面のランプ・フィルムの目盛り）と、場面を進める合図
const MonitorMarks := preload("res://scripts/ui/monitor_marks.gd")
const CUE_NAMES := ["演技の合図", "爆発の合図", "再会の合図"]
const PAGE_NAMES := ["次の場面へ", "もう一度", ""]
var marks: Control
var _previous_mouse := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.018,0.025,0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	sheet = Panel.new()
	sheet.add_theme_stylebox_override("panel",_style(Color(0.055,0.065,0.08),Color(0.24,0.27,0.31)))
	root.add_child(sheet)
	title = _label(sheet,24)
	status = _label(sheet,15)
	program = _image(sheet)
	for i in range(3):
		var button := _button(sheet,"")
		button.pressed.connect(func(): game.h_camera_cut.rpc_id(1,i))
		choices.append(button)
		var preview := _image(button)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		previews.append(preview)
		var caption := _label(button,16)
		caption.name = "Caption"
	for i in range(3):
		var button := _button(sheet,["演技の合図","爆発の合図","再会の合図"][i])
		button.pressed.connect(func(): game.h_monitor_cue.rpc_id(1,i+1))
		cues.append(button)
	control_button = _button(sheet,"スイッチ係になる")
	control_button.pressed.connect(func(): game.h_monitor_control.rpc_id(1,true))
	close_button = _button(sheet,"閉じる")
	close_button.pressed.connect(func(): set_open(false))
	hint = _label(sheet,14)
	marks = MonitorMarks.new()
	marks.visible = false
	sheet.add_child(marks)
	hint.text = "1 / 2 / 3：カメラ切替　T：カット　右クリック / Esc：閉じる"

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	return s

func _label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font",game.font)
	label.add_theme_font_size_override("font_size",size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font",game.font)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_stylebox_override("normal",_style(Color(0.1,0.12,0.15),Color(0.3,0.33,0.38)))
	button.add_theme_stylebox_override("hover",_style(Color(0.18,0.20,0.24),Color(0.9,0.76,0.34)))
	button.add_theme_stylebox_override("pressed",_style(Color(0.24,0.21,0.14),Color(0.9,0.76,0.34)))
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _image(parent: Control) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func set_open(on: bool) -> void:
	if on == opened: return
	opened = on
	root.visible = on
	if on: _previous_mouse = Input.mouse_mode
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif game.camera_switcher.allowed():
		Input.mouse_mode = _previous_mouse
	game.h_monitor_control.rpc_id(1,on)

func state_changed() -> void:
	if not opened: return
	if game.camera_switcher.allowed():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		set_open(false)

func handle_input(event: InputEvent) -> bool:
	if not opened: return false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			set_open(false)
			return true
		return event.button_index != MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_ESCAPE: set_open(false)
				KEY_1,KEY_2,KEY_3: game.h_camera_cut.rpc_id(1,event.keycode-KEY_1)
				KEY_T:
					if game.state == game.S.TAKE: game.h_monitor_stop.rpc_id(1)
		return true
	return event is InputEventMouseMotion

func _process(_delta: float) -> void:
	if not opened: return
	var switcher: Node = game.camera_switcher
	if not switcher.allowed() or not switcher.nearby(game.local_player()):
		set_open(false)
		return
	var own: bool = switcher.operator_peer == Net.my_id()
	var letter: String = ["A","B","C"][switcher.index()]
	title.text = ("● REC" if game.state == game.S.TAKE else "STANDBY") + "   採用映像：カメラ " + letter
	title.modulate = Color(1,0.48,0.43) if game.state == game.S.TAKE else Color(0.95,0.95,0.97)
	status.text = "スイッチ係：あなた — 下の合図で撮影班へ指示" if own else ("ほかの撮影班員が切り替えを担当しています" if switcher.operator_peer != 0 else "スイッチ係を募集中")
	program.texture = game.program_camera().view.get_texture()
	for i in range(3):
		previews[i].texture = switcher.cameras[i].view.get_texture()
		choices[i].disabled = not own
		choices[i].get_node("Caption").text = "%s  カメラ %s%s" % [i+1,["A","B","C"][i],"  ● 採用中" if i == switcher.index() else ""]
		choices[i].get_node("Caption").modulate = Color(1,0.83,0.4) if i == switcher.index() else Color.WHITE
	var paging: bool = game.beats != null and game.beats.active()
	for i in cues.size():
		var cue_name: String = PAGE_NAMES[i] if paging else CUE_NAMES[i]
		cues[i].text = cue_name
		cues[i].visible = cue_name != ""
		cues[i].disabled = not own
	marks.visible = paging
	if paging:
		marks.set_marks(game.beats.lamps(), game.beats.film_frac())
	control_button.visible = not own
	control_button.disabled = switcher.operator_peer != 0
	_layout()

func _place(control: Control, at: Vector2, extent: Vector2) -> void:
	control.position = at
	control.size = extent

func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var extent := Vector2(minf(1180,screen.x-36),minf(730,screen.y-32))
	_place(sheet,(screen-extent)*0.5,extent)
	var content_h: float = extent.y-174
	var preview_w: float = minf(extent.x*0.26,(content_h/3.0-28.0)*16.0/9.0)
	var main_w: float = extent.x-preview_w-60
	_place(title,Vector2(20,14),Vector2(extent.x-40,34))
	_place(status,Vector2(20,52),Vector2(extent.x-40,24))
	_place(program,Vector2(20,86),Vector2(main_w,content_h))
	for i in range(3):
		_place(choices[i],Vector2(extent.x-preview_w-20,86+i*content_h/3.0),Vector2(preview_w,content_h/3.0-8))
		_place(previews[i],Vector2(6,6),Vector2(preview_w-12,content_h/3.0-42))
		_place(choices[i].get_node("Caption"),Vector2(9,content_h/3.0-32),Vector2(preview_w-18,24))
		if preview_w < 200:
			choices[i].get_node("Caption").text = "%s  %s%s" % [i+1,["A","B","C"][i],"  ● 採用中" if i == game.camera_switcher.index() else ""]
	for i in range(3):
		_place(cues[i],Vector2(20+i*156,extent.y-72),Vector2(146,36))
	_place(control_button,Vector2(extent.x-328,extent.y-72),Vector2(196,36))
	_place(close_button,Vector2(extent.x-122,extent.y-72),Vector2(102,36))
	_place(hint,Vector2(20,extent.y-30),Vector2(extent.x-40,24))
	_place(marks,Vector2(extent.x-380,58),Vector2(360,14))
