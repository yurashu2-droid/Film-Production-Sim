extends Control
const Stage := preload("res://scripts/stage.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
var game: Node
var selected := 0
var view: SubViewport
var preview: Node3D
var camera: Camera3D
var avatar: Node3D
var buttons: Array[Button] = []

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.035, 0.88)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 490)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.085)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -370
	panel.offset_right = 370
	panel.offset_top = -245
	panel.offset_bottom = 245
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "制作班のキャラクターを選ぶ"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
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
	e.background_color = style.bg_color
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
	var image := TextureRect.new()
	image.texture = view.get_texture()
	image.custom_minimum_size = Vector2(340, 320)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 6)
	row.add_child(choices)
	for i in game.PLAYER_CASTS.size():
		var button := Button.new()
		button.text = game.PLAYER_NAMES[i]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 38
		button.pressed.connect(choose.bind(i))
		choices.add_child(button)
		buttons.append(button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	var hint := Label.new()
	hint.text = "↑↓ 選択　Enter 決定　Esc 戻る"
	hint.add_theme_font_size_override("font_size", 16)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var cancel := Button.new()
	cancel.text = "戻る"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): game.set_character_menu(false))
	footer.add_child(cancel)
	var accept := Button.new()
	accept.text = "このキャラクターにする"
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(confirm)
	footer.add_child(accept)
	hide()

func set_open(on: bool) -> void:
	visible = on
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	preview.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		var me: Node = game.local_player()
		choose(game.PLAYER_CASTS.find(me.vis.tag))

func choose(index: int) -> void:
	selected = posmod(index, game.PLAYER_CASTS.size())
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == selected)
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
