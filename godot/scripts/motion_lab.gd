extends "res://scripts/main.gd"
# ゲームと同じプレイヤーを、独立したスタジオで再生する。
var trial_time := 0.0
var foot_grounding_enabled := bool(ProjectSettings.get_setting("animation/foot_grounding", true))
var dust_enabled := true
var dust_scale := 1.0
var playback_speed := 1.0
var loop_enabled := false
var sustain_run := false
var _active := false
var _arming := 0
var _released := false
var _step_requested := false
var _camera_view := 0
var _lab_camera: Camera3D
var _floor_visual: Node3D
var _readout: Label
var _phase: Label
var _status: Label
var _timeline: ProgressBar
var _pause_button: Button
var _character_picker: OptionButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	_headless = DisplayServer.get_name() == "headless"
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "sans-serif"])
	font = sf
	_setup_input()
	state = S.PREP
	input_locked = true
	_build_studio()
	_roster = [[Net.my_id(), 3]]
	_apply_roster()
	_configure_player()
	_build_panel()
	reset_trial()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _configure_player() -> void:
	var me: Node = local_player()
	me.process_mode = Node.PROCESS_MODE_PAUSABLE
	me.set_process_unhandled_input(false)
	me.vis.grounding_enabled = foot_grounding_enabled
	me.vis.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if me.vis.face_anim:
		me.vis.face_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_lab_camera.make_current()

func _build_studio() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("192c3e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cbd9e4")
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.2, 60)
	collider.shape = box
	collider.position.y = -0.1
	floor_body.add_child(collider)
	add_child(floor_body)
	_floor_visual = Node3D.new()
	add_child(_floor_visual)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("304b5c")
	mat.roughness = 1.0
	floor_mesh.material_override = mat
	_floor_visual.add_child(floor_mesh)
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-16, 17):
		grid.surface_add_vertex(Vector3(i, 0.006, -16))
		grid.surface_add_vertex(Vector3(i, 0.006, 16))
		grid.surface_add_vertex(Vector3(-16, 0.006, i))
		grid.surface_add_vertex(Vector3(16, 0.006, i))
	grid.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = grid
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("486979")
	lines.material_override = gm
	_floor_visual.add_child(lines)
	_lab_camera = Camera3D.new()
	_lab_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_lab_camera.size = 4.2
	_lab_camera.h_offset = -0.85
	add_child(_lab_camera)

func _panel_label(parent: Node, text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_panel() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28)
	panel.size = Vector2(370, 0)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102230")
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_panel_label(col, "MOTION LAB", 30)
	_panel_label(col, "走り始め・加速・土ぼこりを確認", 16)
	var character := OptionButton.new()
	_character_picker = character
	for n in PLAYER_NAMES:
		character.add_item(n)
	character.select(3)
	character.item_selected.connect(choose_character)
	col.add_child(character)
	var view := OptionButton.new()
	for n in ["横から見る", "斜めから見る", "正面から見る"]:
		view.add_item(n)
	view.item_selected.connect(func(index: int): _camera_view = index)
	col.add_child(view)
	_phase = _panel_label(col, "待機", 23)
	_readout = _panel_label(col, "", 17)
	_timeline = ProgressBar.new()
	_timeline.max_value = 1.6
	_timeline.show_percentage = false
	_timeline.custom_minimum_size.y = 8
	col.add_child(_timeline)
	_button(col, "▶ ダッシュ再生  [Enter]", start_trial)
	var row := HBoxContainer.new()
	col.add_child(row)
	_pause_button = _button(row, "一時停止  [P]", toggle_pause)
	_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var step := _button(row, "1コマ  [.]", step_one)
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(col, "先頭に戻す  [R]", reset_trial)
	var speed := OptionButton.new()
	speed.add_item("再生速度  1.0 ×")
	speed.add_item("再生速度  0.5 ×")
	speed.item_selected.connect(func(index: int): set_playback_speed(1.0 if index == 0 else 0.5))
	col.add_child(speed)
	var motion := OptionButton.new()
	motion.add_item("走り始め → 走行 → 停止")
	motion.add_item("走行ループを確認（走り続ける）")
	motion.item_selected.connect(func(index: int): sustain_run = index == 1; start_trial())
	col.add_child(motion)
	var loop := CheckBox.new()
	loop.text = "繰り返し再生"
	loop.toggled.connect(func(on: bool): loop_enabled = on)
	col.add_child(loop)
	var grounding := CheckBox.new()
	grounding.text = "足の埋まり補正（OFFで元に戻す）"
	grounding.button_pressed = foot_grounding_enabled
	grounding.toggled.connect(func(on: bool): foot_grounding_enabled = on; local_player().vis.grounding_enabled = on)
	col.add_child(grounding)
	var dust := CheckBox.new()
	dust.text = "トゥーン土ぼこり"
	dust.button_pressed = true
	dust.toggled.connect(func(on: bool): dust_enabled = on; _clear_dash_dust())
	col.add_child(dust)
	var size_label := _panel_label(col, "土ぼこりの大きさ  1.00 ×", 16)
	var size_slider := HSlider.new()
	size_slider.min_value = 0.5
	size_slider.max_value = 1.5
	size_slider.step = 0.05
	size_slider.value = 1.0
	size_slider.value_changed.connect(func(value: float): dust_scale = value; size_label.text = "土ぼこりの大きさ  %.2f ×" % value)
	col.add_child(size_slider)
	var floor_check := CheckBox.new()
	floor_check.text = "床を表示（グリッドは1m）"
	floor_check.button_pressed = true
	floor_check.toggled.connect(func(on: bool): _floor_visual.visible = on)
	col.add_child(floor_check)
	var save := _button(col, "現在のコマをPNG保存", save_frame)
	save.disabled = _headless
	_status = _panel_label(col, "1コマ送り = ゲーム内の1/60秒", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 326

func _process(_delta: float) -> void:
	var me: Node3D = local_player()
	if me == null:
		return
	var focus := me.global_position + Vector3(0, 0.9, 0)
	var views := [Vector3(7, 2.0, 0), Vector3(6, 2.7, 4), Vector3(0, 2, -7)]
	_lab_camera.position = focus + views[_camera_view]
	_lab_camera.look_at(focus)
	if _readout:
		_phase.text = {"idle": "待機", "run_start": "ため → 蹴り出し", "run": "走行", "run_stop": "ブレーキ"}.get(me.vis.current, me.vis.current)
		_readout.text = "F%03d  /  %.3f 秒\n速度  %.2f m/s" % [roundi(trial_time * 60), trial_time, Vector2(me.velocity.x, me.velocity.z).length()]
		_timeline.value = trial_time
		_pause_button.text = "再開  [P]" if get_tree().paused else "一時停止  [P]"

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if _arming > 0:
		if local_player().is_on_floor():
			_arming -= 1
			if _arming == 0:
				_active = true
				input_locked = false
				Input.action_press("run")
				Input.action_press("move_forward")
	elif _active:
		trial_time += delta
		if trial_time >= 1.0 and not _released and not sustain_run:
			_release_input()
			_released = true
		if trial_time >= 1.6 and not sustain_run:
			_active = false
			input_locked = true
			if loop_enabled:
				start_trial()
	# 1mグリッドに揃えて位置だけ戻す。速度・アニメーション位相は維持。
	if sustain_run and local_player().position.z < -12.4:
		local_player().position.z += 16.0
		_clear_dash_dust()
	if _step_requested:
		_step_requested = false
		get_tree().paused = true
		Engine.time_scale = playback_speed

func _release_input() -> void:
	Input.action_release("run")
	Input.action_release("move_forward")

func reset_trial() -> void:
	get_tree().paused = false
	Engine.time_scale = playback_speed
	_step_requested = false
	_release_input()
	_clear_dash_dust()
	_active = false
	_arming = 0
	_released = false
	trial_time = 0.0
	input_locked = true
	var me: Node = local_player()
	me.position = Vector3(0, 0.02, 3.6)
	me.velocity = Vector3.ZERO
	me.aim_yaw = 0.0
	me._motion = ""
	me._motion_t = 0.0
	me._run_requested = false
	me._run_start_elapsed = 0.0
	me._dash_dust_pending = false
	me._ground_y = 0.0
	me.vis.rotation.y = PI
	me.vis.play("idle", 0.0, true)
	me.vis.anim.advance(0)

func start_trial() -> void:
	reset_trial()
	_arming = 2

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_process(0.0)

func step_one() -> void:
	if not get_tree().paused:
		get_tree().paused = true
	Engine.time_scale = 1.0
	_step_requested = true
	get_tree().paused = false

func choose_character(index: int) -> void:
	reset_trial()
	_character_picker.select(index)
	h_select_cast(index)
	_configure_player()

func set_playback_speed(value: float) -> void:
	playback_speed = value
	if not _step_requested:
		Engine.time_scale = value

func act_dash_dust() -> void:
	if dust_enabled:
		super.act_dash_dust()

func _show_dash_dust(pos: Vector3, direction: Vector3) -> void:
	if dust_enabled:
		var dust := ToonDust.new()
		add_child(dust)
		dust.global_position = pos
		dust.burst(direction, dust_scale)

func save_frame() -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("user://motion_lab")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join("%s_F%03d_%d" % [local_player().vis.tag, roundi(trial_time * 60), Time.get_ticks_msec()])
	var error := get_viewport().get_texture().get_image().save_png(file + ".png")
	if error == OK:
		var json := FileAccess.open(file + ".json", FileAccess.WRITE)
		if json:
			json.store_string(JSON.stringify({"cast": local_player().vis.tag, "frame": roundi(trial_time * 60), "time": trial_time, "animation": local_player().vis.current, "velocity": var_to_str(local_player().velocity), "dust_scale": dust_scale, "dust_enabled": dust_enabled, "foot_grounding": foot_grounding_enabled}, "\t"))
		_status.text = "保存しました: " + file + ".png"
	else:
		_status.text = "保存できませんでした（エラー %d）" % error

# Labでは撮影ゲームのC/T/Tab/F9などを受け取らない。
func _unhandled_input(_event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode not in [KEY_ENTER, KEY_P, KEY_PERIOD, KEY_R]:
			return
		get_viewport().set_input_as_handled()
		match event.physical_keycode:
			KEY_ENTER: start_trial()
			KEY_P: toggle_pause()
			KEY_PERIOD: step_one()
			KEY_R: reset_trial()

func _exit_tree() -> void:
	_release_input()
	get_tree().paused = false
	Engine.time_scale = 1.0
