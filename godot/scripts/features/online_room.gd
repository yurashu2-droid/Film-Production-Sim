extends Node
## Company number belongs to the crew UI, outside the recording viewport.
const UI := preload("res://scripts/ui/ui_theme.gd")
var game: Node
var panel: PanelContainer
var room_label: Label
var _copied_until := 0

func setup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	panel = UI.panel("slate", 0.0, false, 14, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -360
	panel.offset_right = -20
	panel.offset_top = -156
	panel.offset_bottom = -80
	panel.custom_minimum_size = Vector2(340, 76)
	room_label = UI.label("", 16, UI.CLAP_WHITE, "body")
	panel.add_child(room_label)
	_refresh()

func _process(_delta: float) -> void:
	if panel != null: _refresh()

func _refresh() -> void:
	panel.visible = Net.transport == "steam" and Net.steam_session.lobby_id != 0
	if not panel.visible: return
	var hint := "コピーしました" if Time.get_ticks_msec() < _copied_until else "F8：会社番号をコピー"
	room_label.text = "会社番号 %d\n制作班 %d / 4人　%s" % [Net.steam_session.lobby_id, game.players.size(), hint]

func hook_input(event: InputEvent) -> bool:
	if not panel.visible or not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_F8:
		return false
	DisplayServer.clipboard_set(str(Net.steam_session.lobby_id))
	_copied_until = Time.get_ticks_msec() + 2000
	_refresh()
	return true
