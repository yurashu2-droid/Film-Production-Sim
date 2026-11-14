extends SceneTree
# 設定の紙（ui/settings_sheet.gd）：タイトル画面の「設定」と、遊んでいる途中の Esc → 設定で同じ紙が開く
#   ・1枚目に感度・音量・全画面・キー設定・閉じる。キー設定へ進むと広い紙を頼み、もどると狭い紙に戻る
#   ・タイトル画面の「設定」で、この紙が開く
#   godot --headless --path godot --script res://tests/settings_sheet_test.gd
var failed := false


func check(ok: bool, label: String) -> void:
	print("SHEET_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var sheet: Control = load("res://scripts/ui/settings_sheet.gd").new()
	var widths: Array = []
	sheet.width_wanted.connect(func(w: float): widths.append(w))
	root.add_child(sheet)
	await process_frame
	check(sheet._main.visible and not sheet._keys.visible and sheet.find_child("MouseSens", true, false) != null and sheet.find_child("Volume_music", true, false) != null, "the first page has sensitivity and volume")
	sheet._show_keys()
	await process_frame
	check(sheet._keys.visible and not sheet._main.visible and widths.back() == sheet.WIDE, "the key page opens on a wide sheet")
	check(sheet._key_buttons.size() == Keybinds.ACTIONS.size(), "every action has a key sign (%d)" % sheet._key_buttons.size())
	sheet.show_main()
	check(sheet._main.visible and widths.back() == sheet.NARROW, "back returns to the first page")
	sheet.queue_free()
	var menu: Node = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 5:
		await process_frame
	menu.open_settings()
	await process_frame
	check(menu._settings_layer.visible and menu._settings_sheet.is_visible_in_tree() and menu._settings_sheet._main.visible, "the title screen settings open the same sheet")
	print("SHEET_TEST_FAIL" if failed else "SHEET_TEST_OK")
	quit(1 if failed else 0)
