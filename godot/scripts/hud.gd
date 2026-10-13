extends CanvasLayer
# 画面表示。ゲームの状態を毎フレーム読んで描くだけで、判断はしない。
# 見た目の方針は ui_theme.gd の先頭を参照（暗い面・白い文字・黄色は合図1か所だけ・飾りは足さない）。

const UI := preload("res://scripts/ui/ui_theme.gd")

# 他のスクリプトが「色の合図」として渡してくる値（見た目の色ではなく、種類の目印）
const YELLOW := Color(1.0, 0.86, 0.35)
const GREEN := Color(0.5, 1.0, 0.6)
const RED := Color(1.0, 0.45, 0.4)
const DIM := Color(0.8, 0.82, 0.88)

const CharacterPicker := preload("res://scripts/character_picker.gd")
const DEFAULT_SCENES := ["告白（高低差・城・明るさ）", "背後で大爆発", "爆発のあと再会"]
const DEFAULT_FILM := "月下の城と大爆発"
const Catalog := preload("res://scripts/ui/order_catalog.gd")
const MonitorMarks := preload("res://scripts/ui/monitor_marks.gd")
const PANEL_W := 672.0
const NOTE_FREE := "無料：カメラ・ライト2台・カチンコは荷台に載っている。廃材置き場に出ている物も自由に使える。"
var character_picker: Control
var character_button: Button

var game: Node
var root: Control
var viewfinder: TextureRect
var vf_frame: Control
var monitor_box: PanelContainer
var monitor: TextureRect
var monitor_title: Label
var hints: Label
var order_lines: Array = []
var order_state: Label
var keys: Label
var cross: Control
var target_label: Label
var take_bar: PanelContainer
var toast: PanelContainer
var toast_label: Label
var panel: PanelContainer
var panel_text: RichTextLabel
var help: PanelContainer
var slate: Control
var order_panel: PanelContainer
var order_title: Label
var order_boxes: Array = []
var order_checked: Array = [false, false, false]
var order_checked_override: Array = []   # 制作モードが、見ているテイクの成立を上書きするとき
# 場面の列を持つ依頼（制作モードの production_beats.gd）のときだけ使う物
var more_lines: Array = []       # 4つ目からの場面の行
var more_boxes: Array = []
var monitor_marks: Control       # 右上のカメラ映像の下の、場面のランプとフィルムの目盛り（確認用モニターの枠と同じ）
var _scene_list_on := true
var _scene_now := -2
var panel_title: Label
var key_help: VBoxContainer
var monitor_frame: PanelContainer
var toast_top := 100.0
# 依頼パネルの追加注文の行（制作モードが文字を入れる）
var bonus_box: VBoxContainer
var bonus_tag: Label
var bonus_text: Label
var bonus_sub: Label
# 撮影中の上の帯
var take_row: HBoxContainer
var replay_row: HBoxContainer
var take_secs: Label
var take_hint: Label
var cue_chips: Array = []
var cue_names_labels: Array = []
var charge_box: HBoxContainer
var charge_note: Label
var replay_time: Label
# 確認のパネル
var panel_over: Label
var panel_aside: Label
var panel_sub: Label
var order_view: VBoxContainer
var result_view: VBoxContainer
var delivered_view: VBoxContainer
var help_sheet: Control
var help_dim: ColorRect

var _toast_t := 0.0
var _toast_slide := 0.0
var _toast_tween: Tween
var _hint_mode := ""
var _hint_sig := ""
var _key_sig := ""
var _number_prefix := RegEx.new()
var _monitor_rec := false
var _rec_box: HBoxContainer
var _rec_dot: Control
var _hint_box: VBoxContainer
var _last_size := Vector2.ZERO
var _charge_sig := ""
var _cue_sig := ""
# 注文表
var _opt_rows: Array = []
var catalog: Control
var _budget_label: Label
var _budget_side: Label
var _budget_bar: Control
var _order_button: Button
var _order_note: Label
# 結果・納品
var _result_sig := ""
var _delivered_sig := ""


func build() -> void:
	_number_prefix.compile("^\\d+[\\s　]*")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme(20)
	add_child(root)

	viewfinder = TextureRect.new()
	viewfinder.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewfinder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewfinder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	viewfinder.texture = game.film.view.get_texture()
	viewfinder.visible = false
	viewfinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(viewfinder)
	vf_frame = _Frame.new()
	vf_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	vf_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vf_frame.visible = false
	root.add_child(vf_frame)

	slate = _Slate.new()
	slate.game = game
	slate.set_anchors_preset(Control.PRESET_FULL_RECT)
	slate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slate)

	_build_order_panel()
	_build_monitor()
	_build_take_bar()
	_build_toast()

	cross = _Cross.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-10, -10)
	cross.size = Vector2(20, 20)
	root.add_child(cross)
	target_label = _label("", 17, UI.CLAP_WHITE, "bold")
	target_label.set_anchors_preset(Control.PRESET_CENTER)
	target_label.offset_left = 0
	target_label.offset_right = 0
	target_label.offset_top = 28
	target_label.offset_bottom = 28
	target_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(target_label)

	# 操作の案内。keys は文字の元データ（他のスクリプトが書き換える）。見せるのは key_help のキーキャップ
	keys = _label("", 15, DIM)
	_place(keys, Control.PRESET_CENTER_BOTTOM, Vector2(-700, -64), 1400)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.modulate = Color(1, 1, 1, 0)
	root.add_child(keys)
	key_help = VBoxContainer.new()
	key_help.add_theme_constant_override("separation", 6)
	key_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(key_help)

	_build_panel()

	help_dim = ColorRect.new()
	help_dim.color = Color(UI.INK, 0.6)
	help_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_dim.visible = false
	root.add_child(help_dim)
	help = UI.panel("slate", 0.0, true, 28, 24)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help)
	help.set_anchors_preset(Control.PRESET_CENTER)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BOTH
	help.offset_top = 0
	help.offset_bottom = 0
	help_sheet = _HelpSheet.new()
	help.add_child(help_sheet)
	help_sheet.text = HELP_TEXT
	_place_help()
	help.visible = false
	UI.pop_on_show(help)
	UI.pop_on_show(monitor_box)
	character_picker = CharacterPicker.new()
	character_picker.game = game
	root.add_child(character_picker)
	character_picker.build()


# ---- 部品の組み立て ----

func _build_order_panel() -> void:
	# 左上：依頼とショットリスト
	var order := UI.panel("slate", 0.0, true, 20, 16)
	order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order.position = Vector2(18, 18)
	order.custom_minimum_size = Vector2(340, 0)
	root.add_child(order)
	order_panel = order
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 6)
	order.add_child(ov)
	ov.add_child(UI.overline("依頼"))
	order_title = _label(_film_title(), 20, UI.CLAP_WHITE, "bold")
	order_title.custom_minimum_size.x = 300
	order_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ov.add_child(order_title)
	ov.add_child(UI.gap(2))
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 34
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(row)
		var box := UI.ShotBox.new()
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		order_boxes.append(box)
		var l := _label("", 17, UI.CLAP_WHITE, "bold")
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		order_lines.append(l)
	# 4つ目・5つ目の場面（場面の列を持つ依頼のときだけ出す）
	for i in 2:
		var more_row := HBoxContainer.new()
		more_row.add_theme_constant_override("separation", 12)
		more_row.custom_minimum_size.y = 34
		more_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more_row.visible = false
		ov.add_child(more_row)
		var more_box := UI.ShotBox.new()
		more_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more_row.add_child(more_box)
		more_boxes.append(more_box)
		var more_label := _label("", 17, UI.CLAP_WHITE, "bold")
		more_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		more_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		more_row.add_child(more_label)
		more_lines.append(more_label)
	ov.add_child(UI.hairline())
	order_state = _label("", 15, UI.MUTED, "body")
	ov.add_child(order_state)
	# 追加注文（制作モードだけ使う）
	bonus_box = VBoxContainer.new()
	bonus_box.add_theme_constant_override("separation", 2)
	bonus_box.visible = false
	ov.add_child(bonus_box)
	var bonus_row := HBoxContainer.new()
	bonus_row.add_theme_constant_override("separation", 8)
	bonus_box.add_child(bonus_row)
	bonus_tag = _label("+150", 15, UI.TAPE, "bold")
	bonus_tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bonus_row.add_child(bonus_tag)
	bonus_text = _label("", 15, UI.MUTED, "body")
	bonus_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_text.custom_minimum_size.x = 240
	bonus_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_row.add_child(bonus_text)
	bonus_sub = _label("", 15, UI.MUTED, "body")
	bonus_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_box.add_child(bonus_sub)
	character_button = Button.new()
	character_button.text = "キャラクターを選ぶ"
	character_button.focus_mode = Control.FOCUS_NONE
	UI.style_button(character_button, "slate", 15, 34)
	character_button.pressed.connect(func(): game.set_character_menu(true))
	character_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ov.add_child(character_button)


func _build_monitor() -> void:
	# 右上：フィールドモニター（カメラ映像）と足りないこと
	monitor_box = UI.panel("slate", 0.0, true, 16, 14)
	monitor_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(monitor_box)
	_place(monitor_box, Control.PRESET_TOP_RIGHT, Vector2(-376, 18), 358)
	monitor_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	monitor_box.add_child(mv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	mv.add_child(head)
	monitor_title = UI.overline("カメラ映像")
	monitor_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(monitor_title)
	_rec_box = HBoxContainer.new()
	_rec_box.add_theme_constant_override("separation", 6)
	_rec_box.visible = false
	head.add_child(_rec_box)
	_rec_dot = UI.Dot.new().setup(UI.STAMP_RED, 8.0)
	_rec_box.add_child(_rec_dot)
	_rec_box.add_child(_label("REC", 13, UI.STAMP_RED, "bold"))
	monitor_frame = PanelContainer.new()
	monitor_frame.add_theme_stylebox_override("panel", _frame_style(false))
	monitor_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.add_child(monitor_frame)
	monitor = TextureRect.new()
	monitor.custom_minimum_size = Vector2(326, 184)
	monitor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	monitor.stretch_mode = TextureRect.STRETCH_SCALE
	monitor.texture = game.film.view.get_texture()
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_frame.add_child(monitor)
	# 確認用モニターの枠の印（場面のランプ・フィルムの目盛り）を、ここにも同じ形で出す。数字は出さない
	monitor_marks = MonitorMarks.new()
	monitor_marks.custom_minimum_size = Vector2(0, 12)
	monitor_marks.visible = false
	mv.add_child(monitor_marks)
	_hint_box = VBoxContainer.new()
	_hint_box.add_theme_constant_override("separation", 4)
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.add_child(_hint_box)
	# 文字の元データ（hints.text に足りないことが改行区切りで入る）
	hints = _label("", 15, UI.CLAP_WHITE, "body")
	hints.visible = false
	_hint_box.add_child(hints)
	_set_hint_mode("")


func _frame_style(rec: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("070707")
	s.border_color = UI.STAMP_RED if rec else UI.LINE
	s.set_border_width_all(2 if rec else 1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	s.anti_aliasing = true
	return s


func _build_take_bar() -> void:
	take_bar = UI.panel("slate", 0.0, true, 20, 8)
	take_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	take_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	take_bar.offset_left = 0
	take_bar.offset_right = 0
	take_bar.offset_top = 16
	take_bar.offset_bottom = 16
	take_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(take_bar)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	take_bar.add_child(tv)
	# 本番：大きな秒数と、3つの合図
	take_row = HBoxContainer.new()
	take_row.add_theme_constant_override("separation", 12)
	tv.add_child(take_row)
	var rec := UI.Dot.new().setup(UI.STAMP_RED, 8.0)
	rec.name = "RecDot"
	take_row.add_child(rec)
	take_secs = _label("60", 32, UI.CLAP_WHITE, "bold")
	take_secs.custom_minimum_size.x = 48
	take_secs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	take_row.add_child(take_secs)
	var unit := _label("秒", 15, UI.MUTED, "body")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	unit.custom_minimum_size.y = 28
	take_row.add_child(unit)
	take_row.add_child(UI.hairline(true))
	for i in 3:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size.y = 34
		chip.add_theme_stylebox_override("panel", _cue_style(false))
		take_row.add_child(chip)
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 8)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(ch)
		var n := _label(str(i + 1), 13, UI.MUTED, "bold")
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(n)
		var name_label := _label("", 15, UI.CLAP_WHITE, "bold")
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(name_label)
		cue_names_labels.append(name_label)
		cue_chips.append(chip)
		if i == 1:
			charge_box = HBoxContainer.new()
			charge_box.add_theme_constant_override("separation", 4)
			charge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ch.add_child(charge_box)
			charge_note = _label("", 13, UI.MUTED, "bold")
			charge_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ch.add_child(charge_note)
	# 見返し
	replay_row = HBoxContainer.new()
	replay_row.add_theme_constant_override("separation", 12)
	replay_row.visible = false
	tv.add_child(replay_row)
	replay_row.add_child(_label("見返し中", 17, UI.CLAP_WHITE, "bold"))
	replay_time = _label("0.0 秒", 20, UI.CLAP_WHITE, "bold")
	replay_time.custom_minimum_size.x = 72
	replay_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	replay_row.add_child(replay_time)
	replay_row.add_child(UI.key_item("Esc 戻る", 15))
	# カメラ操作中で右上のモニターが隠れているときの、足りないこと
	take_hint = _label("", 15, UI.CLAP_WHITE, "body")
	take_hint.visible = false
	tv.add_child(take_hint)
	take_bar.visible = false


func _cue_style(next: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = UI.TAPE if next else Color(1, 1, 1, 0.14)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.anti_aliasing = true
	return s


func _build_toast() -> void:
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = 0
	toast.offset_right = 0
	toast.offset_top = toast_top
	toast.offset_bottom = toast_top
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(toast)
	toast.resized.connect(func() -> void:
		toast.offset_left = -toast.size.x * 0.5
		toast.offset_right = toast.size.x * 0.5)
	toast_label = _label("", 20, UI.CLAP_WHITE, "bold")
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.max_lines_visible = 2
	toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast.add_child(toast_label)
	toast.visible = false


func _toast_style(bar: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UI.BOARD, 0.94)
	s.border_color = bar
	s.border_width_left = 4
	s.set_corner_radius_all(6)
	s.content_margin_left = 20
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


# 確認パネル（注文表・テイク確認・納品）の外枠。中身は状態ごとに作る
func _build_panel() -> void:
	panel = UI.panel("slate", 0.0, true, 24, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size.x = PANEL_W
	_layout_panel()
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	panel.add_child(pv)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	pv.add_child(head)
	panel_over = UI.overline("")
	head.add_child(panel_over)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	head.add_child(title_row)
	panel_title = _label("", 24, UI.CLAP_WHITE, "display")
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel_title.custom_minimum_size.x = 200
	title_row.add_child(panel_title)
	panel_aside = _label("", 15, UI.MUTED, "body")
	panel_aside.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(panel_aside)
	panel_sub = _label("", 15, UI.MUTED, "body")
	panel_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(panel_sub)
	pv.add_child(UI.hairline())
	order_view = VBoxContainer.new()
	order_view.add_theme_constant_override("separation", 4)
	pv.add_child(order_view)
	result_view = VBoxContainer.new()
	result_view.add_theme_constant_override("separation", 12)
	pv.add_child(result_view)
	delivered_view = VBoxContainer.new()
	delivered_view.add_theme_constant_override("separation", 12)
	pv.add_child(delivered_view)
	# 以前の文章表示。他のスクリプトが参照するので残す（表示はしない）
	panel_text = RichTextLabel.new()
	panel_text.bbcode_enabled = true
	panel_text.fit_content = true
	panel_text.scroll_active = false
	panel_text.visible = false
	panel_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(panel_text)
	_build_order_view()
	panel.visible = false
	UI.pop_on_show(panel)


const HELP_TEXT := """あそびかた（Tabで閉じる）

少ない機材と廃材で、
依頼された3つの場面を1テイクに収める。
{scenes}
合図キー
{cues}
本番開始：カチンコを持って F ／ カット：T かカチンコ

WASD 移動 ／ Shift 走る ／ Space ジャンプ ／ 視点 マウス
持つ・置く 左クリック ／ 距離 ホイール ／ 回す 右ドラッグ（Q・Eも可）
F 段ボールの開閉（持っている箱、または照準の箱）
C キャラクターを選ぶ（依頼画面・仕込み中）
F2 視点の切り替え（後ろから ⇄ 自分の目）
重り：載せて支える ／ 接着剤：Fで塗り、2点を近づけて接着
F カメラ操作：首振り・ホイールでズーム
F ライト操作：向き・ホイールで明るさ
台車：物を上で離すと載る。
撮影カメラを使う間は身体を固定。移動するときは F で離れる。
ライトは持って歩くと、見ている方向を照らす。
軽トラ：搬入口の荷台から機材を降ろす。
物を戻して載せることもできる。
B 役者を立ち位置へ戻す ／ F9 見本のセットを組む
Esc マウスを離す"""


func _label(text: String, size: int, col: Color, kind: String = "body", outline: bool = false) -> Label:
	return UI.label(text, size, col, kind, outline)


func _panel(pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p := UI.panel("slate", 0.0, false, 12, 12)
	p.position = pos
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p


# すでに画面に載っている枠を、基準点からのずれで置く
func _place(c: Control, preset: int, offset: Vector2, width: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_right = offset.x + width
	c.offset_top = offset.y
	c.offset_bottom = offset.y


func _place_help() -> void:
	var vw := _viewport_size().x
	var w := minf(960.0, vw - 64.0)
	help.offset_left = -w * 0.5
	help.offset_right = w * 0.5
	help.custom_minimum_size.x = w


func _viewport_size() -> Vector2:
	if root != null and root.is_inside_tree():
		return root.get_viewport_rect().size
	return Vector2(1600, 900)


func _production() -> Node:
	if game != null and "production" in game and game.production != null:
		return game.production
	return null


func _film_title() -> String:
	return str(game.film_title()) if game != null and game.has_method("film_title") else DEFAULT_FILM


# 場面名。番号は表示側で付けるので、元の文字列に番号があれば外す
func scene_titles() -> Array:
	var raw: Array = game.scene_titles() if game.has_method("scene_titles") else DEFAULT_SCENES
	var out: Array = []
	for i in maxi(3, raw.size()):
		var t: String = str(raw[i]) if i < raw.size() else ""
		out.append(_number_prefix.sub(t, "", false))
	return out


func cue_list() -> Array:
	return game.cue_names() if game.has_method("cue_names") else ["告白", "爆発", "再会"]


func show_slate(mode: String, take: int) -> void:
	slate.start(mode, take)


# 場面の一覧（左上の3行）を出す・隠す。制作モードでは、台本を読める人の画面にだけ出す（production_hud.gd）。
# 何を撮るかは監督（台本を持つ人）が知っていて、ほかの人は声で聞く
func show_scene_list(on: bool) -> void:
	_scene_list_on = on
	for line: Label in order_lines:
		(line.get_parent() as Control).visible = on


# ---- お知らせ ----

func _toast_max_width() -> float:
	var vw := _viewport_size().x
	var side := maxf(order_panel.custom_minimum_size.x, monitor_box.custom_minimum_size.x) + 36.0
	return minf(vw * 0.46, vw - 2.0 * side)


func show_toast(text: String, col: Color = YELLOW, sec: float = 2.6) -> void:
	var bar := UI.TAPE
	if col.is_equal_approx(RED):
		bar = UI.STAMP_RED
	elif col.is_equal_approx(GREEN):
		bar = UI.OK_GREEN
	var max_w := _toast_max_width()
	var text_w := UI.fnt("bold").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	toast_label.text = text
	# 2行になるときは、行の長さを揃える（1文字だけ次の行へ落ちないように）
	var label_w := text_w + 2.0
	if label_w > max_w - 48.0:
		label_w = minf(max_w - 48.0, label_w * 0.5 + 60.0)
	toast_label.custom_minimum_size.x = label_w
	toast.add_theme_stylebox_override("panel", _toast_style(bar))
	toast.reset_size()
	toast.visible = true
	toast.modulate.a = 0.0
	_toast_t = sec
	_toast_slide = 8.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(self, "_toast_slide", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# 文字に板を敷く／外す（文字が無いときに板だけ残らないように）。tone が同じなら何もしない
func _tone(l: Label, tone: String, style: StyleBox = null) -> void:
	if str(l.get_meta("tone", "")) == tone:
		return
	l.set_meta("tone", tone)
	l.add_theme_stylebox_override("normal", style if tone != "" and style != null else StyleBoxEmpty.new())


# 足りないこと：点つきの行（warn=黄の点・白い字 / ok=緑の点・緑の字）
func _set_hint_mode(mode: String) -> void:
	_hint_mode = mode


func _set_hints(lines: Array, mode: String) -> void:
	var sig := mode + "|" + "\n".join(lines.map(func(x: Variant) -> String: return str(x)))
	if sig == _hint_sig:
		return
	_hint_sig = sig
	_hint_mode = mode
	for c in _hint_box.get_children():
		if c != hints:
			_hint_box.remove_child(c)
			c.queue_free()
	hints.text = "\n".join(lines.map(func(x: Variant) -> String: return str(x)))
	var dot_col := UI.OK_GREEN if mode == "ok" else UI.TAPE
	var text_col := UI.GREEN_LIGHT if mode == "ok" else UI.CLAP_WHITE
	for line: Variant in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size.y = 32
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_box.add_child(row)
		row.add_child(UI.Dot.new().setup(dot_col, 6.0))
		var l := _label(str(line), 15, text_col, "body")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 200
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


# 画面の大きさに合わせて、左右の板の幅と、お知らせの最大幅を決める
func _fit_layout() -> void:
	var vs := _viewport_size()
	if vs == _last_size:
		return
	_last_size = vs
	var wide := vs.x >= 1500.0
	order_panel.custom_minimum_size.x = 400.0 if wide else 340.0
	order_title.custom_minimum_size.x = order_panel.custom_minimum_size.x - 40.0
	var mw := 420.0 if wide else 358.0
	monitor_box.offset_left = -(mw + 18.0)
	monitor_box.offset_right = -18.0
	monitor_box.custom_minimum_size.x = mw
	# 操作の案内の既定の置き場所（下の中央）。制作モードは段階ごとに置き直す
	var kw := minf(1400.0, vs.x - 40.0)
	_place(keys, Control.PRESET_CENTER_BOTTOM, Vector2(-kw * 0.5, -64), kw)
	var img_w := mw - 32.0
	monitor.custom_minimum_size = Vector2(img_w, roundf(img_w * 9.0 / 16.0))
	_place_help()


func _layout_panel() -> void:
	var w := PANEL_W
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	var y := clampf((_viewport_size().y - panel.size.y) * 0.5, 76.0, 240.0)
	panel.offset_top = y
	panel.offset_bottom = y


func _process(delta: float) -> void:
	if game == null or root == null:
		return
	_fit_layout()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.3:
			toast.modulate.a = clampf(_toast_t / 0.3, 0.0, 1.0)
	elif toast.visible:
		toast.visible = false
		toast_label.text = ""
	toast.offset_top = toast_top + _toast_slide
	toast.offset_bottom = toast.offset_top
	toast.offset_left = -toast.size.x * 0.5
	toast.offset_right = toast.size.x * 0.5

	var st: int = game.state
	var S: Dictionary = game.S
	var live: Dictionary = game.live
	var prod: Node = _production()
	var shooting: bool = prod == null or prod.phase == 4
	# 場面の列を持つ依頼（制作モードだけ）：合図ではなく、監督がページをめくって進める
	var beats: Variant = game.get("beats")
	var paging: bool = beats != null and beats.active()
	character_button.visible = prod == null and st in [S.ORDER, S.PREP]
	character_button.disabled = game.local_player() == null
	var me: Node = game.local_player()
	var op: Node3D = game.props.get(me.operating) if me and me.operating != 0 else null
	var output: Node = game.program_camera()
	var finder: Node = op if op != null and op.kind == "camera" and st != S.REPLAY else output
	viewfinder.texture = finder.view.get_texture()
	monitor.texture = finder.view.get_texture()
	monitor_title.text = finder.label + ("　操作中" if op != null and op.kind == "camera" else "　採用中")
	var full: bool = shooting and st == S.REPLAY
	viewfinder.visible = full
	vf_frame.visible = full
	vf_frame.set("rec", st == S.TAKE)
	vf_frame.set("tag", "PLAY" if st == S.REPLAY else "STBY")
	monitor_box.visible = (shooting or (op != null and op.kind == "camera")) and not full and st != S.RESULT and st != S.DELIVERED and st != S.ORDER and (game.can_see_monitor() or (op != null and op.kind == "camera"))
	# モニターを見られる人には、枠の印（撮れた場面のランプ・フィルムの目盛り）も見える
	var marks_on: bool = paging and monitor_box.visible and shooting and game.can_see_monitor()
	monitor_marks.visible = marks_on
	if marks_on:
		monitor_marks.set_marks(beats.lamps(), beats.film_frac())
	help.visible = game.help_open
	help_dim.visible = help.visible
	if help.visible:
		(help_sheet as _HelpSheet).set_context(cue_list(), scene_titles())

	# 注文（ショットリスト）
	var passed: Array = live.get("passed", [false, false, false])
	if not order_checked_override.is_empty():
		passed = order_checked_override
	var titles: Array = scene_titles()
	for i in 3:
		var l: Label = order_lines[i]
		var on: bool = passed[i] and (st == S.TAKE or st == S.RESULT or st == S.REPLAY)
		l.text = "%d　%s" % [i + 1, titles[i]]
		order_checked[i] = on
		(order_boxes[i] as UI.ShotBox).set_on(on)
	# 場面の列を持つ依頼：4つ目からの行も出し、いまの場面だけを白く、ほかを薄くする
	for k in more_lines.size():
		var more: Label = more_lines[k]
		var shown: bool = paging and 3 + k < titles.size() and _scene_list_on
		(more.get_parent() as Control).visible = shown
		if shown:
			more.text = "%d　%s" % [4 + k, titles[3 + k]]
			(more_boxes[k] as UI.ShotBox).set_on(3 + k < passed.size() and bool(passed[3 + k]) and (st == S.TAKE or st == S.RESULT or st == S.REPLAY))
	var scene_now: int = int(beats.scene) if paging and (st == S.PREP or st == S.TAKE or st == S.REPLAY) else -1
	if scene_now != _scene_now:
		_scene_now = scene_now
		var rows: Array = order_lines + more_lines
		for i in rows.size():
			UI.recolor(rows[i], UI.CLAP_WHITE if scene_now < 0 or scene_now == i else UI.MUTED)
	var names := {S.PREP: "仕込み中", S.COUNTDOWN: "まもなく本番", S.TAKE: "本番", S.RESULT: "確認",
		S.REPLAY: "見返し中", S.DELIVERED: "納品", S.ORDER: "依頼を受ける"}
	order_state.text = "%s　テイク %d / %d" % [names[st], game.takes.size() + (1 if st in [S.PREP, S.COUNTDOWN, S.TAKE] else 0), game.MAX_TAKES]
	if Net.mode != "solo":
		order_state.text += "　参加 %d人" % game.players.size()

	# 足りないこと
	var hl: Array = live.get("hints", [])
	var recording: bool = st == S.TAKE
	if st == S.PREP or st == S.TAKE or st == S.COUNTDOWN:
		if hl.is_empty():
			# 場面の列を持つ依頼では、準備中に答えを出さない（live の mute）
			if st == S.PREP and not live.get("mute", false):
				_set_hints(["この画なら条件を満たせる"], "ok")
			else:
				_set_hints([], "")
		else:
			_set_hints(hl.slice(0, 4), "warn")
	else:
		_set_hints([], "")
	_hint_box.visible = not _hint_box.get_children().is_empty() and hints.text != ""
	_rec_box.visible = recording
	if recording:
		_rec_dot.modulate.a = 1.0 if int(Time.get_ticks_msec() / 450) % 2 == 0 else 0.25
	if recording != _monitor_rec:
		_monitor_rec = recording
		monitor_frame.add_theme_stylebox_override("panel", _frame_style(recording))

	# 本番の時計と合図
	# 場面の列を持つ依頼では、本番の残り秒数と合図の札を出さない（時計は、カメラのリールとモニターの枠の目盛り）
	take_row.visible = st == S.TAKE and not (game.has_method("hides_take_clock") and game.hides_take_clock())
	replay_row.visible = st == S.REPLAY
	if st == S.TAKE:
		var left: float = maxf(game.take_limit() - game.take_t, 0.0)
		take_secs.text = "%02d" % int(ceil(left))
		UI.recolor(take_secs, UI.CLAP_WHITE if left >= 10.0 else UI.STAMP_RED)
		(take_row.get_node("RecDot") as UI.Dot).modulate.a = 1.0 if int(Time.get_ticks_msec() / 450) % 2 == 0 else 0.25
		_sync_cues(live, passed)
	elif st == S.REPLAY:
		replay_time.text = "%.1f 秒" % game.replay_t
	var cam_hint := ""
	if full and (st == S.PREP or st == S.TAKE) and not hl.is_empty():
		cam_hint = "　".join(hl.slice(0, 3))
	take_hint.text = cam_hint
	take_hint.visible = cam_hint != ""
	take_bar.visible = take_row.visible or replay_row.visible or take_hint.visible

	# 照準と対象
	var play: bool = st == S.PREP or st == S.TAKE or st == S.COUNTDOWN
	cross.visible = play and not full and not (op != null and op.kind == "camera")
	var tl := ""
	if play and me and op == null:
		if me.held != 0 and game.props.has(me.held):
			var held: Node = game.props[me.held]
			tl = "%s を持っている" % held.label
			if held.kind == "carton":
				tl += "　[F] " + ("閉じる" if held.opened else "開く")
		elif me.target:
			var t: Node3D = me.target
			tl = t.label
			if t.kind == "carton" and t.holder == 0:
				tl += "　[F] " + ("閉じる" if t.opened else "開く")
			if t.fixed:
				tl += "（固定中）"
			if t.holder != 0:
				tl += "（誰かが持っている）"
	target_label.text = (tl if slate.mode == "" else "").replace("[F] ", "F：")
	# 持っている物の名前は、画面のまん中に出さない（視界のじゃまになる）。下の操作の案内のすぐ上へ下げる。
	# 狙っているだけの物の名前は、今までどおり照準のすぐ下
	var label_drop: float = get_viewport().get_visible_rect().size.y * 0.5 - 132.0 if play and me != null and me.held != 0 else 28.0
	target_label.offset_top = label_drop
	target_label.offset_bottom = label_drop
	_tone(target_label, "on" if target_label.text != "" else "", UI.box(Color(UI.BOARD, 0.88), UI.LINE, 1, 6, 14, 6))

	# 操作の案内
	var k := ""
	if st == S.PREP or st == S.TAKE:
		if op and op.kind == "camera":
			k = "カメラ操作中：マウスで首振り ／ ホイールでズーム ／ 身体はその場で固定 ／ F で離れる"
		elif op:
			k = "ライト操作中：マウスで向き ／ ホイールで明るさ（%d／3） ／ F で離れる" % op.level
		elif me and me.held != 0:
			var hk: String = game.props[me.held].kind if game.props.has(me.held) else ""
			if hk == "cue_card":
				k = "F カンペに書く"
			elif hk == "clapper":
				k = "F カチンコを打つ（%s）" % ("カット" if st == S.TAKE else "本番開始")
			elif hk == "spot":
				k = "見ている方向へ光が向く"
			elif hk == "dolly":
				k = "台車は床を転がして運ぶ"
			k += ("\n" if k != "" else "") + game.hold_hint()
		elif me and me.target:
			k = "左クリックで持つ"
			if me.target.kind in ["camera", "spot"]:
				k += " ／ F で操作"
		else:
			k = "WASD 移動 ／ Shift 走る ／ Space ジャンプ"
		if st == S.PREP:
			k += "\nカチンコを持って F で本番開始 ／ 1・2・3 合図のリハーサル ／ B 役者を戻す ／ F9 見本を組む ／ Tab あそびかた"
		else:
			k += "\n1・2・3 合図 ／ T かカチンコでカット"
	keys.text = game.adhesive.hint() if me != null and me.held == game.adhesive.tool.pid else k
	if me != null and me.held == game.adhesive.tool.pid and not game.adhesive.applying:
		keys.text += "\n" + game.hold_hint()
	# 制作モードが keys.text を書き換えたあとの最終の文字で組む
	_sync_key_help.call_deferred()

	# 確認パネル。カチンコの演出が終わるまでは出さない（演出の下に潜らせない）
	var want_panel: bool = (st == S.RESULT or st == S.DELIVERED) and (prod == null or prod.phase == 4)
	if slate.mode != "":
		want_panel = false
	if st == S.RESULT and game.takes.is_empty():
		want_panel = false
	panel.visible = want_panel
	# 発注の画面：撮影だけモードでは全員に、制作モードでは発注を開いた人の画面にだけ出す（game.ordering()）
	var ordering: bool = game.ordering()
	catalog.visible = ordering and not game.help_open and not game.character_open
	if want_panel:
		_sync_panel(st)
		_layout_panel()
	if ordering:
		_sync_order()


# 合図の札：次の合図は黄の枠、済んだ合図は薄く。効果の残りは点で
func _sync_cues(live: Dictionary, passed: Array) -> void:
	var cues: Array = cue_list()
	var next := -1
	for i in 3:
		if not passed[i]:
			next = i
			break
	for i in 3:
		(cue_names_labels[i] as Label).text = str(cues[i]) if i < cues.size() else ""
		var chip: PanelContainer = cue_chips[i]
		chip.add_theme_stylebox_override("panel", _cue_style(i == next))
		chip.modulate.a = 0.45 if passed[i] else 1.0
	var ch: int = live.get("charges", 0)
	var sig := str(ch)
	if sig == _charge_sig:
		return
	_charge_sig = sig
	for c in charge_box.get_children():
		charge_box.remove_child(c)
		c.queue_free()
	for i in maxi(ch, 0):
		charge_box.add_child(UI.Dot.new().setup(UI.CLAP_WHITE, 6.0))
	charge_note.text = "書割" if ch < 0 else ("なし" if ch == 0 else "")


# ---- 操作の案内：「／」区切りを、キーキャップ＋説明にして並べる（最大2行） ----

func _sync_key_help() -> void:
	var show := keys.visible and keys.text != ""
	key_help.visible = show
	if not show:
		_key_sig = ""
		return
	# 位置と幅は、制作モードが keys に決めたものに合わせる
	key_help.anchor_left = keys.anchor_left
	key_help.anchor_right = keys.anchor_right
	key_help.anchor_top = 1.0
	key_help.anchor_bottom = 1.0
	key_help.offset_left = keys.offset_left
	key_help.offset_right = keys.offset_right
	key_help.offset_top = -16.0
	key_help.offset_bottom = -16.0
	var align := keys.horizontal_alignment
	var sig := "%s|%d|%d" % [keys.text, align, int(keys.offset_right - keys.offset_left)]
	if sig == _key_sig:
		return
	_key_sig = sig
	for c in key_help.get_children():
		key_help.remove_child(c)
		c.queue_free()
	var lines := keys.text.split("\n", false)
	for li in mini(lines.size(), 2):
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 20)
		flow.add_theme_constant_override("v_separation", 4)
		flow.alignment = FlowContainer.ALIGNMENT_BEGIN if align == HORIZONTAL_ALIGNMENT_LEFT else FlowContainer.ALIGNMENT_CENTER
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_help.add_child(flow)
		for segment in lines[li].split("／", false):
			if segment.strip_edges() != "":
				flow.add_child(UI.key_item(segment.strip_edges(), 15, true))


# ---- 確認パネル ----

func _sync_panel(st: int) -> void:
	var S: Dictionary = game.S
	order_view.visible = st == S.ORDER
	result_view.visible = st == S.RESULT
	delivered_view.visible = st == S.DELIVERED
	panel_aside.text = ""
	panel_sub.visible = false
	if st == S.ORDER:
		_sync_order()
	elif st == S.RESULT:
		_sync_result()
	else:
		_sync_delivered()


func _legacy_mode() -> bool:
	return _production() == null


# ---- 注文表 ----

func _build_order_view() -> void:
	# 注文表は、写真つきのカタログ（scripts/ui/order_catalog.gd）に任せる
	catalog = Catalog.new()
	root.add_child(catalog)
	catalog.build(game)
	_opt_rows = catalog.rows
	_order_button = catalog.confirm


func _hint_pair(key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(UI.KeyCap.new().setup(key))
	var l := _label(text, 15, UI.MUTED, "body")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _sync_order() -> void:
	catalog.sync(_production())


# 注文表の見出しの下の「追加注文」の1行（制作モードだけ）
var _order_bonus_row: HBoxContainer


func bonus_line_for_panel(title: String) -> void:
	if _order_bonus_row == null:
		_order_bonus_row = HBoxContainer.new()
		_order_bonus_row.add_theme_constant_override("separation", 8)
		var tag := _label("+150", 15, UI.TAPE, "bold")
		_order_bonus_row.add_child(tag)
		var t := _label("", 15, UI.CLAP_WHITE, "body")
		t.name = "Text"
		_order_bonus_row.add_child(t)
		panel_sub.get_parent().add_child(_order_bonus_row)
	_order_bonus_row.visible = title != ""
	if title != "":
		(_order_bonus_row.get_node("Text") as Label).text = "追加注文　" + title


# ---- テイク確認 ----

func _sync_result() -> void:
	var prod: Node = _production()
	var takes: Array = game.takes
	var sel: int = clampi(game.selected, 0, takes.size() - 1)
	var t: Dictionary = takes[sel]
	panel_over.text = "TAKE %d / %d" % [sel + 1, game.MAX_TAKES]
	panel_title.text = "テイク確認"
	UI.recolor(panel_title, UI.CLAP_WHITE)
	panel_aside.text = "%.0f 秒" % float(t.get("dur", 0.0))
	if _order_bonus_row != null:
		_order_bonus_row.visible = false
	var saved := ""
	if prod != null and "production_export" in game and game.production_export != null:
		saved = str(game.production_export.last_saved)
	var sig := "%d|%s|%d|%d|%s|%s" % [str(takes).hash(), str(sel), takes.size(), 1 if (prod != null and prod.expired) else 0, saved, str(prod.bonus_status()) if prod != null else ""]
	if prod != null and game.get("crew_skills") != null:
		sig += "|" + str(game.crew_skills.preview)
	if sig == _result_sig:
		return
	_result_sig = sig
	_build_result(t, sel, prod, saved)


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _result_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.StatusMark.new().setup(bool(r["ok"]), 26.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var title := _label(str(r["title"]), 17, UI.CLAP_WHITE, "bold")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(title)
	var detail := _label(str(r["detail"]), 15, UI.MUTED, "body")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 400
	col.add_child(detail)
	return row


func _build_result(t: Dictionary, sel: int, prod: Node, saved: String) -> void:
	_clear(result_view)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	result_view.add_child(rows)
	for r: Dictionary in t["results"]:
		rows.add_child(_result_row(r))
	if prod != null:
		# 見立て：何を何の役に使ったかと、らしさ・コンボのコイン
		var cast_lines: Array = prod.Cast.lines((t.get("extras", {}) as Dictionary).get("cast", {}))
		if not cast_lines.is_empty():
			result_view.add_child(UI.hairline())
			var cb := VBoxContainer.new()
			cb.add_theme_constant_override("separation", 2)
			result_view.add_child(cb)
			cb.add_child(UI.overline("見立て"))
			for line: Array in cast_lines:
				cb.add_child(_coin_row(str(line[0]), int(line[1])))
		var comments: Array = prod.notes.observations(t.get("extras", {}))
		if not comments.is_empty():
			result_view.add_child(UI.hairline())
			var nb := VBoxContainer.new()
			nb.add_theme_constant_override("separation", 4)
			result_view.add_child(nb)
			nb.add_child(UI.overline("NG日誌"))
			for c: Variant in comments:
				var cl := _label(str(c), 15, UI.CLAP_WHITE, "body")
				cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cl.custom_minimum_size.x = 600
				nb.add_child(cl)
		result_view.add_child(_bonus_result_row(str(prod.bonus_status())))
		if game.get("crew_skills") != null:
			var growth: Dictionary = game.crew_skills.preview
			var amounts: Array[String] = []
			for role: String in ["actor", "camera", "backstage"]:
				amounts.append("%s +%d" % [game.crew_skills.Profile.NAMES[role], int(growth.get(role, {}).get("gained", 0))])
			result_view.add_child(_label("成長予定　%s XP\nNGも含め、納品時に確定します。" % " / ".join(amounts), 15, UI.CLAP_WHITE))
	result_view.add_child(UI.hairline())
	# テイクの選び（1つ1枚の札・三つの小さな成否の点）
	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 8)
	result_view.add_child(sel_row)
	for i in game.takes.size():
		sel_row.add_child(_take_chip(i, i == sel))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_row.add_child(fill)
	if game.takes.size() > 1:
		sel_row.add_child(_hint_pair("←→", "テイクを選ぶ"))
	# 操作
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	result_view.add_child(sub)
	var replay_button := UI.KeyButton.new().setup("見返す", "R", "slate", 15, 36)
	replay_button.pressed.connect(func() -> void: game.h_replay.rpc_id(1, game.selected))
	sub.add_child(replay_button)
	if prod != null and game.production_export != null:
		var save_button := UI.KeyButton.new().setup("8コマ保存", "P", "slate", 15, 36)
		save_button.tooltip_text = "見返して8コマをPNGで保存する。保存先：ユーザーデータの film_stills フォルダ"
		save_button.pressed.connect(func() -> void: game.production_export.begin())
		sub.add_child(save_button)
		if saved != "":
			var open_button := UI.KeyButton.new().setup("フォルダを開く", "O", "slate", 15, 36)
			open_button.tooltip_text = saved
			open_button.pressed.connect(func() -> void: game.production_export.open_saved())
			sub.add_child(open_button)
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 12)
	result_view.add_child(main_row)
	var left_takes: int = game.MAX_TAKES - game.takes.size()
	var expired: bool = prod != null and prod.expired
	var can_retake := left_takes > 0 and not expired
	var retake_text := "撮り直す　あと%d回" % left_takes
	if expired:
		retake_text = "借り時間終了"
	elif left_takes <= 0:
		retake_text = "撮り直しなし"
	var retake := UI.KeyButton.new().setup(retake_text, "Space", "slate", 17, 48)
	retake.set_enabled(can_retake)
	retake.pressed.connect(func() -> void: game.h_retake.rpc_id(1))
	main_row.add_child(retake)
	var fill2 := Control.new()
	fill2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(fill2)
	var deliver := UI.KeyButton.new().setup("このテイクを納品", "Enter", "tape", 17, 48)
	deliver.pressed.connect(func() -> void: game.h_deliver.rpc_id(1, game.selected))
	main_row.add_child(deliver)


# 「文　　+60」の1行（増えるなら緑、減るなら赤、変わらないなら薄く）
func _coin_row(text: String, coins: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label(text, 15, UI.CLAP_WHITE, "body")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(t)
	var col: Color = UI.GREEN_LIGHT if coins > 0 else (UI.STAMP_RED.lightened(0.25) if coins < 0 else UI.MUTED)
	row.add_child(_label(("%+d" % coins) if coins != 0 else "±0", 15, col, "bold"))
	return row


# 追加注文の達成（bonus_status の1〜2行目から組む）
func _bonus_result_row(status: String) -> Control:
	var lines := status.split("\n")
	var head: String = lines[0].replace("✔ ", "").replace("✔", "")
	head = head.trim_prefix("追加注文 +150コイン：")
	var state := ""
	var p := head.rfind("　")
	if p >= 0:
		state = head.substr(p + 1)
		head = head.substr(0, p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 28
	var tag := _label("+150", 15, UI.TAPE, "bold")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	var title := _label(head, 15, UI.CLAP_WHITE, "body")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	if state != "":
		var ok_state := state == "達成"
		var s := _label(state, 15, UI.GREEN_LIGHT if ok_state else UI.MUTED, "bold")
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(s)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	if lines.size() > 1:
		var fee: String = lines[1].replace("納品料見込み：", "")
		var cap := _label("納品料見込み", 15, UI.MUTED, "body")
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cap)
		var amount := _label(fee, 17, UI.CLAP_WHITE, "bold")
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(amount)
	return row


func _take_chip(i: int, selected: bool) -> Control:
	var cb := UI.ClickBox.new()
	cb.custom_minimum_size.y = 36
	var normal := UI.box(Color(0, 0, 0, 0), UI.LINE, 1, 6, 12, 4)
	var chosen := UI.box(Color(1, 1, 1, 0.04), UI.TAPE, 1, 6, 12, 4)
	chosen.border_color = UI.TAPE
	var hover := UI.box(Color(1, 1, 1, 0.04), UI.LINE, 1, 6, 12, 4)
	cb.set_styles(normal, hover, chosen)
	cb.set_active(selected)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	cb.add_child(row)
	var l := _label("テイク%d" % (i + 1), 15, UI.CLAP_WHITE, "bold")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	for ok: Variant in game.takes[i]["passed"]:
		row.add_child(UI.Dot.new().setup(UI.OK_GREEN if bool(ok) else UI.STAMP_RED, 8.0))
	UI.ignore_mouse(cb)
	cb.pressed.connect(func() -> void: game.h_select.rpc_id(1, i))
	return cb


# ---- 納品 ----

func _sync_delivered() -> void:
	var takes: Array = game.takes
	if takes.is_empty():
		return
	var sel: int = clampi(game.selected, 0, takes.size() - 1)
	var t: Dictionary = takes[sel]
	var ok: bool = bool(game.delivered_ok)
	panel_over.text = "DELIVERED"
	panel_title.text = "納品完了" if ok else "納品したが、注文に届かなかった"
	UI.recolor(panel_title, UI.GREEN_LIGHT if ok else UI.STAMP_RED.lightened(0.2))
	panel_aside.text = ""
	panel_sub.visible = true
	panel_sub.text = "依頼どおりのクライマックスが撮れた。" if ok else "報酬はなし。次の依頼の制作費は確保されている。"
	if _order_bonus_row != null:
		_order_bonus_row.visible = false
	var sig := "%d|%d|%d" % [str(takes).hash(), sel, 1 if ok else 0]
	if sig == _delivered_sig:
		return
	_delivered_sig = sig
	_clear(delivered_view)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	delivered_view.add_child(rows)
	for r: Dictionary in t["results"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size.y = 34
		rows.add_child(row)
		var mark := UI.StatusMark.new().setup(bool(r["ok"]), 22.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		var l := _label(str(r["title"]), 17, UI.CLAP_WHITE, "bold")
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	if ok:
		delivered_view.add_child(UI.hairline())
		delivered_view.add_child(_money_row("会社報酬", "%d コイン" % int(game.REWARD), true))
		delivered_view.add_child(_money_row("制作費の残り（精算）", "%d コイン" % maxi(0, int(game.BUDGET) - int(game.order_cost())), false))
	var foot := HBoxContainer.new()
	delivered_view.add_child(foot)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	var next := UI.KeyButton.new().setup("次の撮影へ", "Enter", "tape", 17, 48)
	next.pressed.connect(func() -> void: game.h_next.rpc_id(1))
	foot.add_child(next)


func _money_row(caption: String, amount: String, strong: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34
	var cap := _label(caption, 15, UI.MUTED, "body")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var a := _label(amount, 20 if strong else 17, UI.CLAP_WHITE, "bold")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	return row


# ---- あそびかた（Tab）。「題＋2段の短い行」に組み直す ----
class _HelpSheet extends VBoxContainer:
	var text := "":
		set(v):
			text = v
			_sig = ""
			_rebuild()
	var cues: Array = ["告白", "爆発", "再会"]
	var scenes: Array = []
	var _sig := ""

	func set_context(c: Array, s: Array) -> void:
		if str(c) == str(cues) and str(s) == str(scenes):
			return
		cues = c
		scenes = s
		_rebuild()

	func _rendered() -> String:
		var numbered: Array = []
		for i in scenes.size():
			numbered.append("%d %s" % [i + 1, scenes[i]])
		var cue_text: Array = []
		for i in mini(3, cues.size()):
			cue_text.append("%d %s" % [i + 1, cues[i]])
		var out := text.replace("\r", "")
		out = out.replace("{scenes}", "\n".join(numbered) if not numbered.is_empty() else "1 告白\n2 爆発\n3 再会")
		out = out.replace("{cues}", " ／ ".join(cue_text) if not cue_text.is_empty() else "1 告白 ／ 2 爆発 ／ 3 再会")
		return out

	func _rebuild() -> void:
		var rendered := _rendered()
		if rendered == _sig:
			return
		_sig = rendered
		for c in get_children():
			remove_child(c)
			c.queue_free()
		add_theme_constant_override("separation", 16)
		var lines := rendered.split("\n")
		var title: String = lines[0]
		var note := ""
		var p := title.find("（")
		if p >= 0:
			note = title.substr(p + 1).trim_suffix("）")
			title = title.substr(0, p)
		add_child(UI.overline("HOW TO PLAY"))
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 16)
		add_child(head)
		var t := UI.label(title, 24, UI.CLAP_WHITE, "display")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if note != "":
			var n: Control
			if note.begins_with("Tab"):
				n = UI.key_item("Tab " + note.substr(3), 15)
				for l in n.get_children():
					if l is Label:
						UI.recolor(l, UI.MUTED)
			else:
				n = UI.label(note, 15, UI.MUTED, "body")
			n.size_flags_vertical = Control.SIZE_SHRINK_END
			head.add_child(n)
		add_child(UI.hairline())
		# 空行で区切った段落。行数が半分ずつになるよう、左右の列へ振り分ける
		var groups: Array = []
		var cur: Array = []
		for i in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				if not cur.is_empty():
					groups.append(cur)
					cur = []
			else:
				cur.append(line)
		if not cur.is_empty():
			groups.append(cur)
		var total := 0
		for g: Array in groups:
			total += g.size() + 1
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 40)
		add_child(cols)
		var col_boxes: Array = []
		for k in 2:
			var cb := VBoxContainer.new()
			cb.add_theme_constant_override("separation", 14)
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cols.add_child(cb)
			col_boxes.append(cb)
		# 左右の高さの差がいちばん小さくなる位置で分ける
		var split := groups.size()
		var best := 1000000
		var acc := 0
		for gi in groups.size():
			var diff := absi(acc * 2 - total)
			if diff < best:
				best = diff
				split = gi
			acc += (groups[gi] as Array).size() + 1
		var gi_now := 0
		for g: Array in groups:
			var target: VBoxContainer = col_boxes[0] if gi_now < split else col_boxes[1]
			gi_now += 1
			var gb := VBoxContainer.new()
			gb.add_theme_constant_override("separation", 6)
			target.add_child(gb)
			for line: String in g:
				gb.add_child(_line(line))

	func _line(line: String) -> Control:
		var first := line.split(" ", false)[0] if not line.strip_edges().is_empty() else ""
		if " ／ " in line or UI.is_key_token(first):
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 18)
			flow.add_theme_constant_override("v_separation", 4)
			flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for segment in line.split("／", false):
				if segment.strip_edges() != "":
					flow.add_child(UI.key_item(segment.strip_edges(), 15))
			return flow
		var l := UI.label(line, 15, UI.CLAP_WHITE, "body")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 380
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return l


# 照準（中央の十字）
class _Cross extends Control:
	func _draw() -> void:
		var c := size * 0.5
		for col_w: Array in [[Color(0, 0, 0, 0.45), 4.0], [Color(1, 1, 1, 0.9), 2.0]]:
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), col_w[0], col_w[1])
			draw_line(c + Vector2(0, -7), c + Vector2(0, 7), col_w[0], col_w[1])


# ファインダーの枠線
class _Frame extends Control:
	var rec := false
	var tag := "STBY"

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var s := size
		var c := Color(1, 1, 1, 0.6)
		var m := 40.0
		var l := 60.0
		for corner: Vector2 in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
			var sx := 1.0 if corner.x < s.x * 0.5 else -1.0
			var sy := 1.0 if corner.y < s.y * 0.5 else -1.0
			draw_line(corner, corner + Vector2(l * sx, 0), c, 3.0)
			draw_line(corner, corner + Vector2(0, l * sy), c, 3.0)
		draw_line(Vector2(s.x * 0.5 - 14, s.y * 0.5), Vector2(s.x * 0.5 + 14, s.y * 0.5), c, 2.0)
		draw_line(Vector2(s.x * 0.5, s.y * 0.5 - 14), Vector2(s.x * 0.5, s.y * 0.5 + 14), c, 2.0)
		# 三分割の薄い線
		var thin := Color(1, 1, 1, 0.14)
		for i in [1, 2]:
			draw_line(Vector2(s.x * i / 3.0, m), Vector2(s.x * i / 3.0, s.y - m), thin, 1.0)
			draw_line(Vector2(m, s.y * i / 3.0), Vector2(s.x - m, s.y * i / 3.0), thin, 1.0)
		var f: Font = UI.fnt("bold")
		draw_string(f, Vector2(m + 8, m + 32), "CAM A", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
		if rec:
			var on := int(Time.get_ticks_msec() / 450) % 2 == 0
			if on:
				draw_circle(Vector2(s.x - m - 88, m + 25), 7.0, UI.STAMP_RED)
			draw_string(f, Vector2(s.x - m - 72, m + 32), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.STAMP_RED)
			draw_rect(Rect2(m - 6, m - 6, s.x - m * 2.0 + 12, s.y - m * 2.0 + 12), Color(UI.STAMP_RED, 0.7), false, 2.0)
		else:
			draw_string(f, Vector2(s.x - m - 64, m + 32), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.6))


# 画面に大きく出るカチンコ。本番前に出て、打って消える
class _Slate extends Control:
	var game: Node
	var mode := ""
	var take := 1
	var t := 0.0

	func start(m: String, n: int) -> void:
		mode = m
		take = n
		t = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _process(delta: float) -> void:
		if mode == "":
			return
		t += delta
		if (mode == "clap" and t > 0.95) or (mode == "cut" and t > 1.25):
			mode = ""
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if mode == "":
			return
		var font: Font = UI.fnt("bold")
		var display: Font = UI.fnt("display")
		var film: String = str(game.film_title()) if game.has_method("film_title") else "月下の城と大爆発"
		var w := 520.0
		var h := 330.0
		var bar := 54.0
		var slide := 0.0          # 0=定位置、1=画面の下へ
		var angle := -0.38        # 上の拍子木の開き
		if mode == "ready":
			slide = 1.0 - clampf(t / 0.22, 0.0, 1.0)
		elif mode == "clap":
			angle = lerpf(-0.38, 0.0, clampf(t / 0.06, 0.0, 1.0))
			slide = clampf((t - 0.6) / 0.3, 0.0, 1.0)
		else:
			angle = lerpf(-0.38, 0.0, clampf((t - 0.14) / 0.06, 0.0, 1.0))
			slide = (1.0 - clampf(t / 0.12, 0.0, 1.0)) + clampf((t - 0.9) / 0.3, 0.0, 1.0)
		slide = slide * slide
		var origin := Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.35 + slide * size.y * 0.8)
		draw_set_transform(origin, 0.0, Vector2.ONE)
		var black := UI.INK
		var white := UI.CLAP_WHITE
		var dim := UI.MUTED
		draw_rect(Rect2(0, bar, w, h), black)
		draw_rect(Rect2(0, bar, w, h), white, false, 2.0)
		_stripes(Rect2(0, 0, w, bar), black, white)
		draw_line(Vector2(0, bar + 92), Vector2(w, bar + 92), Color(white, 0.5), 1.0)
		draw_line(Vector2(w * 0.5, bar + 92), Vector2(w * 0.5, bar + h), Color(white, 0.5), 1.0)
		draw_string(font, Vector2(20, bar + 34), "格安アクション映画制作班", HORIZONTAL_ALIGNMENT_LEFT, w - 40, 17, dim)
		draw_string(display, Vector2(20, bar + 72), film, HORIZONTAL_ALIGNMENT_LEFT, w - 40, 32, white)
		draw_string(font, Vector2(20, bar + 128), "TAKE", HORIZONTAL_ALIGNMENT_LEFT, 200, 20, dim)
		draw_string(display, Vector2(0, bar + 262), str(take), HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, 150, white)
		var right := ""
		if mode == "ready":
			right = str(int(ceil(game.countdown_t)))
			draw_string(font, Vector2(w * 0.5 + 20, bar + 128), "本番まで", HORIZONTAL_ALIGNMENT_LEFT, 200, 20, dim)
			draw_string(display, Vector2(w * 0.5, bar + 262), right, HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, 150, UI.TAPE)
		else:
			right = "本番" if mode == "clap" else "カット"
			var col := UI.STAMP_RED if mode == "clap" else UI.TAPE
			draw_string(display, Vector2(w * 0.5, bar + 222), right, HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, 48, col)
		# 上の拍子木（左端の蝶番で開く。これだけは動かす）
		draw_set_transform(origin, angle, Vector2.ONE)
		_stripes(Rect2(0, -bar, w, bar), black, white)
		draw_circle(Vector2(10, 0), 8.0, UI.MUTED)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _stripes(r: Rect2, black: Color, white: Color) -> void:
		draw_rect(r, black)
		var n := 7
		var sw := r.size.x / n
		for i in n:
			var x := r.position.x + i * sw
			var pts := PackedVector2Array([Vector2(x + sw * 0.15, r.position.y), Vector2(x + sw * 0.65, r.position.y),
				Vector2(x + sw * 0.35, r.end.y), Vector2(x - sw * 0.15, r.end.y)])
			for k in pts.size():
				pts[k].x = clampf(pts[k].x, r.position.x, r.end.x)
			draw_colored_polygon(pts, white)
		draw_rect(r, white, false, 2.0)
