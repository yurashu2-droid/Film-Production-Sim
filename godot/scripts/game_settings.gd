extends RefCounted
## 遊ぶ人ごとの設定（音量・全画面）。user://settings.cfg に保存する（マウスの感度は player.gd が同じファイルの input に書く）。
## 音は3つの流れに分ける：Master（全体）← Music（BGM）／SFX（効果音・環境音）。流れは起動時にここで作る（default_bus_layout は使わない）。
## Sfx（autoload）の _ready から apply_saved() を呼ぶ。タイトル画面の「設定」は build_panel() で作った物を出す。
const FILE := "user://settings.cfg"
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX"}
const LABELS := {"master": "全体の音量", "music": "BGM の音量", "sfx": "効果音の音量"}

static var volume := {"master": 1.0, "music": 1.0, "sfx": 1.0}   # 0〜1（見た目の量。dB へは linear_to_db）
static var fullscreen := false


# 音の流れ Music と SFX を作る（無ければ）。どちらも Master へ流す
static func ensure_buses() -> void:
	for key: String in ["music", "sfx"]:
		var bus: String = BUSES[key]
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


static func apply_saved() -> void:
	ensure_buses()
	var file := ConfigFile.new()
	if file.load(FILE) == OK:
		for key: String in volume:
			volume[key] = clampf(float(file.get_value("audio", key, 1.0)), 0.0, 1.0)
		fullscreen = bool(file.get_value("display", "fullscreen", false))
	for key: String in volume:
		_apply_volume(key)
	_apply_fullscreen()


static func set_volume(key: String, value: float) -> void:
	volume[key] = clampf(value, 0.0, 1.0)
	_apply_volume(key)
	_save("audio", key, volume[key])


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	_save("display", "fullscreen", on)


static func _apply_volume(key: String) -> void:
	var i := AudioServer.get_bus_index(BUSES[key])
	if i == -1:
		return
	var v: float = volume[key]
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


static func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now := DisplayServer.window_get_mode()
	var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


static func _save(section: String, key: String, value: Variant) -> void:
	var file := ConfigFile.new()
	file.load(FILE)      # 他の設定（マウスの感度など）を消さないよう、読んでから書く
	file.set_value(section, key, value)
	file.save(FILE)


# 設定の中身（つまみ3本＋全画面）。入れ物の見た目は呼ぶ側が付ける
static func build_rows() -> VBoxContainer:
	var UI: GDScript = load("res://scripts/ui/ui_theme.gd")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	for key: String in ["master", "music", "sfx"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		rows.add_child(row)
		row.add_child(UI.label(LABELS[key], 16, UI.CLAP_WHITE, "bold"))
		var slider := HSlider.new()
		slider.name = "Volume_" + key
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = volume[key]
		slider.custom_minimum_size = Vector2(380, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# つまみの通り道が背景に溶けて見えないので、色を付ける（一時メニューの感度のつまみと同じ）
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.22)
		track.set_corner_radius_all(3)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		slider.add_theme_stylebox_override("slider", track)
		slider.value_changed.connect(func(v: float): set_volume(key, v))
		# 効果音のつまみを離したら、どのくらいの大きさか鳴らして聞かせる
		if key != "music":
			slider.drag_ended.connect(func(_changed: bool):
				var sfx: Node = Engine.get_main_loop().root.get_node_or_null("Sfx")
				if sfx != null and sfx.has_sound("ui_ok"):
					sfx.play("ui_ok"))
		row.add_child(slider)
	# 全画面：押すたびに入る・切れる。今の状態は文字で見せる（スイッチの絵は暗い板に溶けて見えなかった）
	var full := Button.new()
	full.name = "Fullscreen"
	full.toggle_mode = true
	full.button_pressed = fullscreen
	full.text = "全画面：オン" if fullscreen else "全画面：オフ"
	UI.style_button(full, "slate", 16, 40)
	full.toggled.connect(func(on: bool):
		full.text = "全画面：オン" if on else "全画面：オフ"
		set_fullscreen(on))
	rows.add_child(full)
	return rows
