extends Control

signal selected(slot: int)
signal closed

const UI := preload("res://scripts/ui/ui_theme.gd")
const FilmSet := preload("res://scripts/ui/film_set.gd")
const Saves := preload("res://scripts/company_saves.gd")

var _rows: VBoxContainer
var _heading: Label
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.05, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 590
	panel.add_theme_stylebox_override("panel", FilmSet.ClipboardStyle.new())
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	_heading = UI.label("", 30, UI.INK)
	body.add_child(_heading)
	body.add_child(UI.label("会社は事務所へ戻るたびに自動で保存されます。", 18, UI.INK))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	body.add_child(_rows)
	_back = Button.new()
	_back.text = "戻る"
	UI.style_button(_back, "paper", 19, 44)
	_back.pressed.connect(func(): closed.emit())
	body.add_child(_back)


func open(store: RefCounted, host_requested: bool) -> void:
	_heading.text = "開く会社を選ぶ" if host_requested else "遊ぶ会社を選ぶ"
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var first: Button = null
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var entry: Dictionary = store.status(slot)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UI.style_button(button, "paper", 22, 70)
		if int(entry.error) != OK:
			button.text = "会社 %d   保存データを読み込めません" % slot
			button.disabled = true
		elif entry.data.is_empty():
			button.text = "会社 %d   はじめから" % slot
		else:
			var data: Dictionary = entry.data
			button.text = "会社 %d   %d日目   %dコイン\n最終保存 %s" % [slot, data.day, data.wallet, entry.updated]
		button.pressed.connect(func(): selected.emit(slot))
		_rows.add_child(button)
		if first == null and not button.disabled:
			first = button
	show()
	(first if first != null else _back).grab_focus()
