extends SceneTree
# キー設定（scripts/keybinds.gd）：
#   ・初期の割り当てが InputMap に入る
#   ・替えると、そのキーで読める。ほかの操作が使っていたキーなら入れ替わる（どの操作もキーを失わない）
#   ・画面の案内の初期のキー名（"F"・"1・2・3"・"WASD"）が、今のキー名に読み替わる
#   ・Esc・Enter には割り当てられない。初期に戻せる。保存して、読み直しても同じ
# 遊ぶ人の設定ファイル（user://settings.cfg）を使うので、はじめに写して、終わったら元に戻す
#   godot --headless --path godot --script res://tests/keybinds_test.gd
var failed := false


func check(ok: bool, label: String) -> void:
	print("KEYS_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func _initialize() -> void:
	var file := Keybinds.FILE
	var had := FileAccess.file_exists(file)
	var saved := FileAccess.get_file_as_bytes(file) if had else PackedByteArray()
	Keybinds.reset()
	check(Keybinds.code("operate") == KEY_F and InputMap.has_action("cue_1"), "the default keys are in place")
	check(_event_key("operate") == KEY_F, "the input map uses the key")
	check(Keybinds.rebind("operate", KEY_E), "a key can be changed")
	check(Keybinds.code("operate") == KEY_E and _event_key("operate") == KEY_E, "the new key is read (%s)" % Keybinds.label("operate"))
	check(Keybinds.code("rot_right") == KEY_F, "the action that had the key gets the old one (%s)" % Keybinds.label("rot_right"))
	check(Keybinds.shown("F") == "E" and Keybinds.shown("E") == "F", "hint key names follow the new keys (F→%s, E→%s)" % [Keybinds.shown("F"), Keybinds.shown("E")])
	Keybinds.rebind("cue_2", KEY_J)
	check(Keybinds.shown("1・2・3") == "1・J・3" and Keybinds.shown("WASD") == "WASD", "grouped names follow too (%s / %s)" % [Keybinds.shown("1・2・3"), Keybinds.shown("WASD")])
	check(Keybinds.translate("箱　[F] 開く") == "箱　[E] 開く" and Keybinds.translate("パイ　K：頭にしまう") == "パイ　K：頭にしまう",
		"key names inside sentences follow too (%s)" % Keybinds.translate("箱　[F] 開く"))
	check(not Keybinds.rebind("operate", KEY_ESCAPE) and Keybinds.code("operate") == KEY_E, "Esc cannot be assigned")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	check(Keybinds.pressed(ev, "operate") and not Keybinds.pressed(ev, "rot_right"), "a key press is matched to the right action")
	Keybinds.apply_saved()
	check(Keybinds.code("operate") == KEY_E and Keybinds.code("cue_2") == KEY_J, "the keys survive a reload from the file")
	Keybinds.reset()
	check(Keybinds.code("operate") == KEY_F and Keybinds.code("rot_right") == KEY_E and Keybinds.code("cue_2") == KEY_2, "reset brings back the defaults")
	# 遊ぶ人の設定ファイルを元に戻す
	if had:
		var f := FileAccess.open(file, FileAccess.WRITE)
		f.store_buffer(saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("KEYS_TEST_FAIL" if failed else "KEYS_TEST_OK")
	quit(1 if failed else 0)


func _event_key(id: String) -> int:
	for e: InputEvent in InputMap.action_get_events(id):
		if e is InputEventKey:
			return (e as InputEventKey).physical_keycode
	return 0
