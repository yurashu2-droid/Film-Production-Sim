extends CanvasLayer
# 制作班の移動と会計。撮影中の表示は既存の HUD に任せる。

const INK := Color("f5e8cd")
const MUTED := Color("c6bca8")
const GOLD := Color("efbf6b")
const RED := Color("ff7970")
const PHASE_NAMES := ["事務所", "道具を買う", "トラックに積む", "現場へ移動", "撮影現場", "今回の精算"]
const JOB_TITLES := ["月下の城と大爆発", "スタジオで月下の城", "青空の下でも夜の城"]
const JOB_PLACES := ["倉庫", "室内スタジオ", "野外"]

var game: Node
var root: Control
var _strip: PanelContainer
var _status: Label
var _clock: Label
var _office: PanelContainer
var _packing: PanelContainer
var _packing_text: Label
var _depart: Button
var _crew: Label
var _travel: PanelContainer
var _travel_text: Label
var _travel_bar: ProgressBar
var _settled: PanelContainer
var _settled_text: Label
var _shop: PanelContainer
var _warning: Label


func build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = game.font
	theme.default_font_size = 19
	root.theme = theme
	game.hud.help.get_child(0).text = """制作会社のあそびかた（Tabで閉じる）

事務所で依頼を選ぶ → 道具を買う → 廃材も軽トラへ → 現場
会社の財布から購入。廃材・昇降台・清掃カートは無料。
持った物は軽トラのそばで F：荷台に積む。
全員が軽トラのそばへ集まり、手ぶらで F：出発。
現場を借りられるのは10分。3場面を1テイクで撮り切ろう。

WASD 移動 ／ Shift 走る ／ Space ジャンプ ／ 視点 マウス
左クリック 持つ・置く ／ ホイール 距離 ／ 右ドラッグ 回す
G 固定・解除（固定用品なしなら4か所まで）
F カメラ・ライト操作、箱の開閉、昇降台・絞り機を動かす
C キャラクター選択 ／ Esc マウスを離す
役者の印を持って動かすと、役者も立ち位置へ移る。Bで戻す。

カチンコを持って F：本番（Tでも開始・カット）
1 告白：城・高低差・明るさ → 2 背後で爆発 → 3 再会
カメラ操作中はマウスで首振り、ホイールでズーム。
台車にカメラを載せると WASD で移動撮影もできる。

結果画面：Rで見返す、Spaceで撮り直す、Enterで納品。
期限が切れたら、撮れたテイクを納品して事務所へ帰ろう。
"""

	_strip = _panel(Control.PRESET_CENTER_TOP, Vector2(-330, 18), 660)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_strip.add_child(row)
	_status = _label("", 18)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_clock = _label("", 18, GOLD)
	_clock.custom_minimum_size.x = 132
	row.add_child(_clock)

	_office = _panel(Control.PRESET_BOTTOM_RIGHT, Vector2(-438, -456), 414)
	var office_rows := _rows(_office)
	office_rows.add_child(_label("今日の一本を選ぶ", 25, GOLD))
	office_rows.add_child(_label("会社方針：10分で撮り切る", 18, MUTED))
	for index in 3:
		var job_button := _button("%s\n%s  ／  城・月・大爆発を撮影" % [JOB_TITLES[index], JOB_PLACES[index]])
		job_button.custom_minimum_size.y = 74
		job_button.pressed.connect(func(): game.rpc_id(1, "h_accept_job", index))
		office_rows.add_child(job_button)
	var office_character := _button("[C] キャラクターを選ぶ")
	office_character.pressed.connect(func(): game.set_character_menu(true))
	office_rows.add_child(office_character)

	_packing = _panel(Control.PRESET_BOTTOM_RIGHT, Vector2(-438, -448), 414)
	var packing_rows := _rows(_packing)
	packing_rows.add_child(_label("積み込み確認", 25, GOLD))
	var inventory := ScrollContainer.new()
	inventory.custom_minimum_size.y = 230
	inventory.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	packing_rows.add_child(inventory)
	_packing_text = _label("", 18)
	_packing_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory.add_child(_packing_text)
	_crew = _label("",19,GOLD)
	packing_rows.add_child(_crew)
	packing_rows.add_child(_label("廃材は無料。\n積んだ物だけ現場へ持っていける。", 18, MUTED))
	_depart = _button("全員そろったら出発")
	_depart.pressed.connect(func(): game.rpc_id(1, "h_depart"))
	packing_rows.add_child(_depart)
	var packing_character := _button("[C] キャラクターを選ぶ")
	packing_character.pressed.connect(func(): game.set_character_menu(true))
	packing_rows.add_child(packing_character)

	_travel = _panel(Control.PRESET_CENTER_BOTTOM, Vector2(-330, -120), 660)
	var travel_rows := _rows(_travel)
	_travel_text = _label("", 23, GOLD)
	travel_rows.add_child(_travel_text)
	_travel_bar = ProgressBar.new()
	_travel_bar.max_value = 8.0
	_travel_bar.show_percentage = false
	_travel_bar.custom_minimum_size.y = 12
	_travel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_rows.add_child(_travel_bar)

	_settled = _panel(Control.PRESET_BOTTOM_RIGHT, Vector2(-508, -470), 484)
	var settled_rows := _rows(_settled)
	settled_rows.add_child(_label("おつかれさま、制作班！", 25, GOLD))
	_settled_text = _label("", 20)
	settled_rows.add_child(_settled_text)
	var return_button := _button("事務所へ戻って、次の一本")
	return_button.pressed.connect(func(): game.rpc_id(1, "h_return_office"))
	settled_rows.add_child(return_button)

	_shop = _panel(Control.PRESET_CENTER_BOTTOM, Vector2(-330, -92), 660)
	_shop.add_child(_label("必要な道具を選ぼう。買ったらトラックへ！", 21, GOLD))
	_warning = _label("", 18, RED)
	root.add_child(_warning)
	_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning.offset_left = -340
	_warning.offset_right = 340
	_warning.offset_top = 108
	_warning.offset_bottom = 108
	_warning.custom_minimum_size = Vector2(680, 0)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh()


func _process(_delta: float) -> void:
	if is_instance_valid(root):
		_refresh()


func _refresh() -> void:
	var production: Node = game.production
	var phase: int = production.phase
	var picker_open: bool = game.character_open
	var legacy: Node = game.hud
	legacy.root.visible = true
	legacy.order_state.get_parent().get_parent().visible = phase == 4
	if phase != 4:
		legacy.monitor_box.visible = false
		legacy.viewfinder.visible = false
		legacy.vf_frame.visible = false
		legacy.panel.visible = phase == 1
		legacy.cross.visible = phase in [0,2] and not picker_open
		legacy.target_label.visible = phase in [0,2] and not picker_open
	else:
		legacy.target_label.visible = true
		legacy.order_lines[0].get_parent().get_child(0).text = "依頼　" + production.job()["title"]
	legacy.keys.visible = phase in [0,2,4] and not picker_open and not game.help_open
	if phase in [0,2]:
		legacy._place(legacy.keys,Control.PRESET_BOTTOM_LEFT,Vector2(18,-72),minf(900,game.get_viewport().get_visible_rect().size.x-480))
		legacy.keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var me: Node = game.local_player()
		legacy.keys.text = "WASD 移動 ／ Shift 走る ／ C キャラ変更 ／ Tab 操作 ／ Esc マウス"
		if phase == 0:
			legacy.keys.text += "\n右の依頼をクリック、または 1・2・3 で選ぶ"
		elif me and me.held != 0:
			legacy.keys.text = "左クリックで置く ／ 右ドラッグで回す ／ G 固定\n軽トラのそばで F：荷台に積む"
		else:
			legacy.keys.text += "\n左クリックで持つ ／ 廃材も忘れずに！ 軽トラのそばで F 出発"
		if me and me.target and me.target.has_method("set_active"):
			legacy.target_label.text = me.target.label + ("　[F] 下げる" if me.target.active else "　[F] 動かす")
	elif phase == 4:
		legacy._place(legacy.keys,Control.PRESET_CENTER_BOTTOM,Vector2(-700,-64),1400)
		legacy.keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legacy.keys.text = legacy.keys.text.replace(" ／ F9 見本を組む","")
		var me: Node = game.local_player()
		if me and me.target and me.target.has_method("set_active"):
			legacy.target_label.text = me.target.label + ("　[F] 下げる" if me.target.active else "　[F] 動かす")
			legacy.keys.text = "左クリックで押す ／ G ブレーキ ／ F 昇降・絞り機"
	_office.visible = phase == 0 and not picker_open
	_shop.visible = phase == 1 and not picker_open
	_packing.visible = phase == 2 and not picker_open
	_travel.visible = phase == 3
	_settled.visible = phase == 5
	_strip.offset_top = 60 if phase == 4 else 18
	_strip.offset_bottom = _strip.offset_top
	_status.text = "会社 %dコイン   ／   %d人   ／   %s" % [production.wallet, game.players.size(), PHASE_NAMES[clampi(phase, 0, 5)]]
	_clock.visible = phase == 4
	var seconds := maxi(0, ceili(production.lease_left))
	_clock.text = "残り %d:%02d" % [seconds / 60, seconds % 60]
	_clock.modulate = RED if seconds < 60 else GOLD
	_warning.visible = phase == 4 and (production.expired or seconds < 60)
	_warning.text = "管理人が来た！いまあるテイクを納品しよう" if production.expired else "あと少しで借り時間終了！ 撮れたテイクを確かめよう"
	if phase == 2:
		_packing_text.text = "%s\n購入額  %dコイン\n\n%s" % [production.job().get("title", "今日の撮影"), production.expenses, production.loadout_status()]
		_crew.text = production.crew_ready()
		_depart.disabled = not production.can_depart()
	if phase == 3:
		_travel_text.text = "%sへ向かっています…" % production.job().get("location", "撮影現場")
		_travel_bar.value = clampf(production.trip_time, 0.0, 8.0)
	if phase == 5:
		var observations := "大きな騒ぎも、映画になれば思い出。"
		if not production.last_flubs.is_empty():
			observations = "現場のこぼれ話\n・" + "\n・".join(production.last_flubs)
		_settled_text.text = "出演・撮影料  %dコイン\n道具の購入額  %dコイン\n会社の財布    %dコイン\n\n%s" % [production.last_payment, production.expenses, production.wallet, observations]


func _panel(anchor: int, position_at: Vector2, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_preset(anchor)
	panel.offset_left = position_at.x
	panel.offset_right = position_at.x + width
	panel.offset_top = position_at.y
	panel.offset_bottom = position_at.y
	if anchor in [Control.PRESET_BOTTOM_RIGHT,Control.PRESET_CENTER_BOTTOM]:
		panel.offset_bottom = -24
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.10, 0.92)
	style.border_color = Color(0.52, 0.43, 0.29, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _rows(panel: PanelContainer) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	return rows


func _label(text: String, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.35))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("54432d") if state == "hover" else Color("342c22")
		if state == "pressed":
			style.bg_color = Color("6b5334")
		if state == "disabled":
			style.bg_color = Color("24221e")
		style.set_corner_radius_all(7)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)
	return button

