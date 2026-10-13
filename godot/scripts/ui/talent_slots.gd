extends PanelContainer
# 段ボール頭「頭の道具箱」の中身。本人の画面の左下に、枠を3つ並べる。
# 入れた順に左から並び、次に出る物（最後に入れた物）の枠だけ黄色い線にする。

const UI := preload("res://scripts/ui/ui_theme.gd")
const Catalog := preload("res://scripts/ui/order_catalog.gd")
const Talents := preload("res://scripts/cast_talents.gd")
const TILE := 60.0

var _frames: Array = []       # 枠（PanelContainer）
var _pics: Array = []         # 写真（TextureRect）
var _initials: Array = []     # 写真の無い物の、名前の頭文字（Label）
var _count: Label
var _note: Label              # しまい方・出し方のひとこと
var _sig := "-"


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UI.box(Color(UI.BOARD, 0.90), UI.LINE, 1, 6, 12, 10))
	# 下の操作の案内（2行）の上に置く
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 18
	offset_right = 18
	offset_top = -104
	offset_bottom = -104
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	head.add_child(UI.KeyCap.new().setup(Talents.KEY_NAME))
	var title := UI.label(Talents.title("09"), 15, UI.CLAP_WHITE, "bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = UI.label("", 13, UI.MUTED, "bold")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for i in Talents.STOW_SLOTS:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(TILE, TILE)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(frame)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
		var initial := UI.label("", 20, UI.INK, "bold")
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(initial)
		_frames.append(frame)
		_pics.append(pic)
		_initials.append(initial)
	_note = UI.label("", 12, UI.MUTED, "body")
	_note.custom_minimum_size.x = TILE * Talents.STOW_SLOTS + 16.0
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.clip_text = true
	column.add_child(_note)
	visible = false
	sync(false, [])


# items：頭の中身 [{kind, label}, ...]（古い順）
func sync(show: bool, items: Array) -> void:
	visible = show
	var sig := str(items)
	if sig == _sig:
		return
	_sig = sig
	_count.text = "%d / %d" % [items.size(), Talents.STOW_SLOTS]
	_note.text = "小物を持って（見て）K でしまう" if items.is_empty() else "手ぶらの K か Shift+K で出す"
	for i in _frames.size():
		var filled: bool = i < items.size()
		var next_out: bool = filled and i == items.size() - 1
		var style: StyleBoxFlat = UI.box(Catalog.PAPER_TILE if filled else Color(1, 1, 1, 0.05), UI.LINE, 1, 4, 4, 4)
		if next_out:
			style.border_color = UI.TAPE
			style.set_border_width_all(2)
		(_frames[i] as PanelContainer).add_theme_stylebox_override("panel", style)
		var photo: Texture2D = Catalog.thumb(str(items[i]["kind"])) if filled else null
		(_pics[i] as TextureRect).texture = photo
		(_initials[i] as Label).text = str(items[i]["label"]).left(2) if filled and photo == null else ""
