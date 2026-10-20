extends VBoxContainer
## 設定の紙（中身だけ。入れ物のクリップボードは使う側が用意する）。タイトル画面の「設定」と、遊んでいる途中の Esc → 設定で同じ物を使う。
##   1枚目：マウスの感度・音量（全体・BGM・効果音）・全画面・「キー設定」・閉じる（もどる）
##   2枚目：キー設定（keybinds.gd）。操作ごとに今のキーの札。札を押して新しいキーを押すと替わる。Esc でやめる
## 保存は、それぞれの持ち主がする（感度＝player.gd、音量・全画面＝game_settings.gd、キー＝keybinds.gd。どれも user://settings.cfg）
signal closed                       # 閉じる（もどる）を押した
signal width_wanted(width: float)   # 入れ物の幅を替えてほしい（キー設定は2列で広い）

const UI := preload("res://scripts/ui/ui_theme.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const Player := preload("res://scripts/player.gd")
const NARROW := 440.0
const WIDE := 680.0

var close_text := "もどる"
var _main: VBoxContainer
var _keys: VBoxContainer
var _sens: HSlider
var _keys_note: Label
var _key_buttons := {}
var _rebinding := ""


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build_main()
	_build_keys()
	show_main()


func show_main() -> void:
	Player.load_settings()
	_sens.value = Player.sens_scale
	_rebinding = ""
	_main.visible = true
	_keys.visible = false
	width_wanted.emit(NARROW)


func _ink(n: Node) -> void:
	if n is Label:
		(n as Label).add_theme_font_override("font", FilmSet.font("marker"))
		(n as Label).add_theme_color_override("font_color", FilmSet.MARKER_INK)
	elif n is HSlider:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0.22)
		track.set_corner_radius_all(3)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		(n as HSlider).add_theme_stylebox_override("slider", track)
		# 今の値まで、ペンで塗った線（紙の上では、つまみの白い丸が見えないので）
		var fill := StyleBoxFlat.new()
		fill.bg_color = FilmSet.MARKER_INK
		fill.set_corner_radius_all(3)
		fill.content_margin_top = 3
		fill.content_margin_bottom = 3
		(n as HSlider).add_theme_stylebox_override("grabber_area", fill)
		(n as HSlider).add_theme_stylebox_override("grabber_area_highlight", fill)
	elif n is Button:
		FilmSet.style_sign_button(n as Button, "cream", 17, 40)


func _sign(text: String, paint: String, px: int, tall: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(b, paint, px, tall)
	return b


func _build_main() -> void:
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	add_child(_main)
	_main.add_child(FilmSet.label("設定", 30, FilmSet.MARKER_INK, "marker"))
	_main.add_child(FilmSet.label("マウスの感度（左：ゆっくり　右：速い）", 16, FilmSet.MARKER_INK, "marker"))
	_sens = HSlider.new()
	_sens.name = "MouseSens"
	_sens.min_value = 0.2
	_sens.max_value = 3.0
	_sens.step = 0.05
	_sens.custom_minimum_size = Vector2(360, 28)
	_sens.value_changed.connect(func(v: float): Player.set_sens(v))
	_ink(_sens)
	_main.add_child(_sens)
	var rows: VBoxContainer = GameSettings.build_rows()
	_main.add_child(rows)
	for n: Node in rows.find_children("*", "", true, false):
		_ink(n)
	var keys_button := _sign("キー設定", "sky", 19, 46)
	keys_button.pressed.connect(_show_keys)
	_main.add_child(keys_button)
	var close := _sign(close_text, "mustard", 20, 48)
	close.name = "Close"
	close.pressed.connect(func(): closed.emit())
	_main.add_child(close)


func _build_keys() -> void:
	_keys = VBoxContainer.new()
	_keys.add_theme_constant_override("separation", 12)
	add_child(_keys)
	_keys.add_child(FilmSet.label("キー設定", 30, FilmSet.MARKER_INK, "marker"))
	_keys_note = FilmSet.label("", 15, Color("5d5850"), "marker")
	_keys.add_child(_keys_note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	_keys.add_child(grid)
	for a: Array in Keybinds.ACTIONS:
		var id: String = a[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		grid.add_child(row)
		var name := FilmSet.label(str(a[1]), 16, FilmSet.MARKER_INK, "marker")
		name.custom_minimum_size.x = 140
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name)
		var key := _sign("", "cream", 16, 32)
		key.custom_minimum_size.x = 120
		key.pressed.connect(func(): _start_rebind(id))
		row.add_child(key)
		_key_buttons[id] = key
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_keys.add_child(bottom)
	var reset := _sign("初期に戻す", "tomato", 18, 46)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func():
		Keybinds.reset()
		_rebinding = ""
		_sync_keys())
	bottom.add_child(reset)
	var back := _sign("もどる", "mustard", 20, 46)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(show_main)
	bottom.add_child(back)


func _show_keys() -> void:
	_rebinding = ""
	_main.visible = false
	_keys.visible = true
	width_wanted.emit(WIDE)
	_sync_keys()


func _start_rebind(id: String) -> void:
	_rebinding = id
	_sync_keys()


func _sync_keys() -> void:
	for id: String in _key_buttons:
		(_key_buttons[id] as Button).text = "キーを押す…" if id == _rebinding else Keybinds.label(id)
	_keys_note.text = "Esc でやめる" if _rebinding != "" else "替えたい操作の札を押して、新しいキーを押す"


# 新しいキーを受ける（キー設定の札を押したあと）。Esc でやめる。マウスのボタンは受けない
func _input(event: InputEvent) -> void:
	if _rebinding == "" or not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = (event as InputEventKey).physical_keycode
	if code != KEY_ESCAPE:
		Keybinds.rebind(_rebinding, code)
	_rebinding = ""
	_sync_keys()


func rebinding() -> bool:
	return _rebinding != ""
