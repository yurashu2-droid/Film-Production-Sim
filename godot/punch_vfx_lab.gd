extends "res://addons/dev_session/benchmarks/punch_stage.gd"
# Standalone lab: normal game scenes and controls are not changed.
const EFFECTS := ["res://vfx/punch_trial_a/punch.gd", "res://vfx/punch_trial_b/punch.gd"]
const CAMERA_POSITIONS := [Vector3(3.4, 2.1, 4.8), Vector3(0, 1.4, 5.5), Vector3(5.5, 1.4, 0.03)]
var selected := 0
var view_index := 0
var title: Label

func _ready() -> void:
	super._ready()
	var hud := CanvasLayer.new()
	add_child(hud)
	title = Label.new()
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 23)
	hud.add_child(title)
	select_effect(0)

func select_effect(index: int) -> void:
	selected = clampi(index, 0, 1)
	title.text = "パンチVFX / %s\n1・2: 案を切替   Space: 再生   Tab: 視点\n通常速度 / 3方向 / 2秒ごとに再生" % ["A 通常確認" if selected == 0 else "B 圧縮確認"]
	begin(EFFECTS[selected])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if frame >= 120:
		begin(EFFECTS[selected])

func cycle_view() -> void:
	view_index = (view_index + 1) % CAMERA_POSITIONS.size()
	var camera := get_viewport().get_camera_3d()
	camera.position = CAMERA_POSITIONS[view_index]
	camera.look_at(Vector3(0, 1.05, 0))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: select_effect(0)
		KEY_2: select_effect(1)
		KEY_SPACE: begin(EFFECTS[selected])
		KEY_TAB: cycle_view()
