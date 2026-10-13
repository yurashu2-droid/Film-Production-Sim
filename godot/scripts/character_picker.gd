extends Control
const Stage := preload("res://scripts/stage.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const Talents := preload("res://scripts/cast_talents.gd")
var game: Node
var selected := 0
var view: SubViewport
var preview: Node3D
var camera: Camera3D
var avatar: Node3D
var buttons: Array[Button] = []
# 選んでいるキャラの特技（名前・準備中の札・説明）
var _talent_name: Label
var _talent_wait: Control
var _talent_desc: Label
var _talent_parts: Array[Control] = []     # 特技まわりの部品。特技の無いモード（撮影だけモード）では隠す

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UI.INK, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 3Dプレビューの背景は、板の上の一段明るい面と同じ色にする
	var bg := UI.BOARD_2
	var panel := UI.panel("slate", 0.0, true, 28, 24)
	panel.custom_minimum_size = Vector2(740, 0)
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -370
	panel.offset_right = 370
	panel.offset_top = 0
	panel.offset_bottom = 0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	column.add_child(head)
	head.add_child(UI.overline("CHARACTER"))
	head.add_child(UI.label("制作班のキャラクターを選ぶ", 24, UI.CLAP_WHITE, "display"))
	column.add_child(UI.hairline())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	view = SubViewport.new()
	view.size = Vector2i(340, 320)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	preview = Node3D.new()
	view.add_child(preview)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.9, 1.0)
	e.ambient_light_energy = 0.6
	env.environment = e
	preview.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.5
	preview.add_child(light)
	camera = Camera3D.new()
	camera.fov = 35
	preview.add_child(camera)
	camera.current = true
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(bg, UI.LINE, 1, 6, 0, 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var image := TextureRect.new()
	image.texture = view.get_texture()
	image.custom_minimum_size = Vector2(340, 320)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 4)
	row.add_child(choices)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 14
	empty.content_margin_right = 14
	for i in game.PLAYER_CASTS.size():
		var button := Button.new()
		button.text = game.PLAYER_NAMES[i]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 40
		button.add_theme_font_override("font", UI.fnt("body"))
		button.add_theme_font_size_override("font_size", 17)
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(c, UI.MUTED if c == "font_color" else UI.CLAP_WHITE)
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4, 14, 8))
		# 選んでいる行は、白6%の面と左の細い黄色
		button.add_theme_stylebox_override("pressed", UI.cursor_box(14, 8))
		button.add_theme_stylebox_override("hover_pressed", UI.cursor_box(14, 8))
		button.pressed.connect(choose.bind(i))
		# 行の右はしに、そのキャラの特技の名前
		var tag: String = game.PLAYER_CASTS[i]
		var skill := UI.label(Talents.title(tag) + ("" if Talents.ready(tag) else "（準備中）"), 13, UI.MUTED, "body")
		skill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		skill.offset_right = -14
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		skill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(skill)
		_talent_parts.append(skill)
		choices.add_child(button)
		buttons.append(button)
	# 選んでいるキャラの特技。まだ作っていない特技には「準備中」の札を出す
	var talent_line := UI.hairline()
	column.add_child(talent_line)
	var talent := VBoxContainer.new()
	talent.add_theme_constant_override("separation", 6)
	column.add_child(talent)
	_talent_parts.append(talent_line)
	_talent_parts.append(talent)
	var talent_head := HBoxContainer.new()
	talent_head.add_theme_constant_override("separation", 10)
	talent.add_child(talent_head)
	var talent_over := UI.overline("特技")
	talent_over.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	talent_head.add_child(talent_over)
	talent_head.add_child(UI.KeyCap.new().setup(Talents.KEY_NAME))
	_talent_name = UI.label("", 20, UI.CLAP_WHITE, "bold")
	talent_head.add_child(_talent_name)
	_talent_wait = UI.Stamp.new().setup("準備中", 13, UI.MUTED)
	_talent_wait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	talent_head.add_child(_talent_wait)
	_talent_desc = UI.label("", 15, UI.MUTED, "body")
	_talent_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_desc.custom_minimum_size = Vector2(684, 46)
	talent.add_child(_talent_desc)
	column.add_child(UI.hairline())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 20)
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(hints)
	for pair: Array in [["↑↓", "選択"], ["Enter", "決定"], ["Esc", "戻る"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		item.add_child(UI.KeyCap.new().setup(pair[0]))
		var t := UI.label(pair[1], 15, UI.MUTED, "body")
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(t)
		hints.add_child(item)
	var cancel := Button.new()
	cancel.text = "戻る"
	cancel.focus_mode = Control.FOCUS_NONE
	UI.style_button(cancel, "slate", 17, 44)
	cancel.pressed.connect(func(): game.set_character_menu(false))
	footer.add_child(cancel)
	var accept := Button.new()
	accept.text = "このキャラクターにする"
	accept.focus_mode = Control.FOCUS_NONE
	UI.style_button(accept, "tape", 17, 44)
	accept.pressed.connect(confirm)
	footer.add_child(accept)
	hide()

func set_open(on: bool) -> void:
	visible = on
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	preview.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		# 特技は制作モードだけ（game.talent がある）。無いモードでは欄ごと隠す
		for part: Control in _talent_parts:
			part.visible = game.get("talent") != null
		var me: Node = game.local_player()
		choose(game.PLAYER_CASTS.find(me.vis.tag))

func choose(index: int) -> void:
	selected = posmod(index, game.PLAYER_CASTS.size())
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == selected)
	var picked: String = game.PLAYER_CASTS[selected]
	_talent_name.text = Talents.title(picked)
	_talent_wait.visible = not Talents.ready(picked)
	_talent_desc.text = Talents.describe(picked) + ("" if Talents.ready(picked) else "\n（準備中。まだ使えない）")
	if avatar:
		preview.remove_child(avatar)
		avatar.queue_free()
	avatar = CastVisual.new()
	preview.add_child(avatar)
	avatar.setup(game.PLAYER_CASTS[selected])
	var bounds := Stage.merged_aabb(avatar)
	var center := bounds.get_center()
	var distance := bounds.size.length() * 0.55 / sin(deg_to_rad(camera.fov * 0.5))
	camera.position = center + Vector3(0.26, 0.12, 1).normalized() * distance
	camera.look_at(center)

func confirm() -> void:
	game.h_select_cast.rpc_id(1, selected)
	game.set_character_menu(false)

func handle_key(key: int) -> void:
	match key:
		KEY_UP, KEY_LEFT: choose(selected - 1)
		KEY_DOWN, KEY_RIGHT: choose(selected + 1)
		KEY_ENTER, KEY_KP_ENTER: confirm()
		KEY_ESCAPE, KEY_C: game.set_character_menu(false)
