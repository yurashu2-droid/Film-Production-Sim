extends CanvasLayer
# 画面表示。ゲームの状態を毎フレーム読んで描くだけで、判断はしない。

const YELLOW := Color(1.0, 0.86, 0.35)
const GREEN := Color(0.5, 1.0, 0.6)
const RED := Color(1.0, 0.45, 0.4)
const DIM := Color(0.8, 0.82, 0.88)

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
var cross: Label
var target_label: Label
var take_bar: Label
var toast: Label
var big: Label
var panel: PanelContainer
var panel_text: RichTextLabel
var help: PanelContainer
var _toast_t := 0.0


func build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = game.font
	th.default_font_size = 20
	root.theme = th
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

	# 左上：依頼と三つの注文
	var order := _panel(Vector2(18, 18), Vector2(430, 0))
	var ov := VBoxContainer.new()
	order.add_child(ov)
	var title := _label("依頼　月下の城と大爆発", 22, YELLOW)
	ov.add_child(title)
	for i in 3:
		var l := _label("", 19, Color.WHITE)
		ov.add_child(l)
		order_lines.append(l)
	order_state = _label("", 17, DIM)
	ov.add_child(order_state)

	# 右上：カメラ映像と足りないこと
	monitor_box = _panel(Vector2(0, 18), Vector2(440, 0))
	_place(monitor_box, Control.PRESET_TOP_RIGHT, Vector2(-458, 18), 440)
	var mv := VBoxContainer.new()
	monitor_box.add_child(mv)
	monitor_title = _label("カメラ映像", 17, DIM)
	mv.add_child(monitor_title)
	monitor = TextureRect.new()
	monitor.custom_minimum_size = Vector2(416, 234)
	monitor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	monitor.stretch_mode = TextureRect.STRETCH_SCALE
	monitor.texture = game.film.view.get_texture()
	mv.add_child(monitor)
	hints = _label("", 17, YELLOW)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.custom_minimum_size = Vector2(416, 0)
	mv.add_child(hints)

	take_bar = _label("", 26, Color.WHITE)
	take_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	take_bar.position = Vector2(-400, 16)
	take_bar.custom_minimum_size = Vector2(800, 0)
	take_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(take_bar)

	toast = _label("", 34, YELLOW)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-600, 110)
	toast.custom_minimum_size = Vector2(1200, 0)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast)

	big = _label("", 150, Color.WHITE)
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.position = Vector2(-400, -140)
	big.custom_minimum_size = Vector2(800, 200)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(big)

	cross = _label("＋", 22, Color(1, 1, 1, 0.8))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-11, -16)
	root.add_child(cross)
	target_label = _label("", 20, Color.WHITE)
	target_label.set_anchors_preset(Control.PRESET_CENTER)
	target_label.position = Vector2(-300, 22)
	target_label.custom_minimum_size = Vector2(600, 0)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(target_label)

	keys = _label("", 18, DIM)
	keys.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	keys.position = Vector2(-700, -64)
	keys.custom_minimum_size = Vector2(1400, 0)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(keys)

	panel = _panel(Vector2.ZERO, Vector2(760, 0))
	_place(panel, Control.PRESET_CENTER, Vector2(-380, -250), 760)
	panel_text = RichTextLabel.new()
	panel_text.bbcode_enabled = true
	panel_text.fit_content = true
	panel_text.scroll_active = false
	panel_text.custom_minimum_size = Vector2(720, 0)
	panel_text.add_theme_font_size_override("normal_font_size", 22)
	panel_text.add_theme_font_size_override("bold_font_size", 22)
	panel.add_child(panel_text)
	panel.visible = false

	help = _panel(Vector2.ZERO, Vector2(760, 0))
	_place(help, Control.PRESET_CENTER, Vector2(-380, -300), 760)
	var ht := _label(HELP_TEXT, 20, Color.WHITE)
	help.add_child(ht)
	help.visible = false


const HELP_TEXT := """あそびかた（Tabで閉じる）

少ない機材と廃材で、依頼された3つの場面を1テイクに収める。
  1 告白：二人が高低差つきで、城のセットと一緒に明るく映る
  2 爆発：告白のあと、二人の背後で爆発が映る
  3 再会：爆発のあと、近づいた二人が映る

移動 WASD ／ 走る Shift ／ ジャンプ Space ／ 視点 マウス
持つ・置く 左クリック ／ 距離 ホイール ／ 回す Q・E
固定・解除 G（倒れやすい物を留める）
機材を操作 F（カメラ：首振り・ホイールでズーム・WASDで移動
　　　　　　　ライト：向き・ホイールで明るさ）
本番開始・カット T ／ 合図 1 告白・2 爆発・3 再会
役者を立ち位置へ戻す B ／ 見本のセットを組む F9
マウスを離す Esc"""


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.78)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
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


func show_toast(text: String, col: Color = YELLOW, sec: float = 2.6) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", col)
	toast.modulate.a = 1.0
	_toast_t = sec


func _process(delta: float) -> void:
	if game == null or root == null:
		return
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	else:
		toast.text = ""

	var st: int = game.state
	var S: Dictionary = game.S
	var live: Dictionary = game.live
	var me: Node = game.local_player()
	var op: Node3D = game.props.get(me.operating) if me and me.operating != 0 else null
	var full: bool = st == S.REPLAY or (op != null and op.kind == "camera")
	viewfinder.visible = full
	vf_frame.visible = full
	monitor_box.visible = not full and st != S.RESULT and st != S.DELIVERED
	help.visible = game.help_open

	# 注文
	var passed: Array = live.get("passed", [false, false, false])
	var titles := ["1 告白（高低差・城・明るさ）", "2 背後で大爆発", "3 爆発のあと再会"]
	for i in 3:
		var l: Label = order_lines[i]
		var on: bool = passed[i] and (st == S.TAKE or st == S.RESULT or st == S.REPLAY)
		l.text = ("✔ " if on else "□ ") + titles[i]
		l.add_theme_color_override("font_color", GREEN if on else Color.WHITE)
	var names := {S.PREP: "仕込み中", S.COUNTDOWN: "まもなく本番", S.TAKE: "本番！", S.RESULT: "確認",
		S.REPLAY: "見返し中", S.DELIVERED: "納品"}
	order_state.text = "%s　テイク %d／%d" % [names[st], game.takes.size() + (1 if st in [S.PREP, S.COUNTDOWN, S.TAKE] else 0), game.MAX_TAKES]
	if Net.mode != "solo":
		order_state.text += "　参加 %d人" % game.players.size()

	# 足りないこと
	var hl: Array = live.get("hints", [])
	if st == S.PREP or st == S.TAKE or st == S.COUNTDOWN:
		if hl.is_empty():
			hints.text = "この画なら条件を満たせる" if st == S.PREP else ""
			hints.add_theme_color_override("font_color", GREEN)
		else:
			hints.text = "\n".join(hl.slice(0, 4).map(func(x: String) -> String: return "・" + x))
			hints.add_theme_color_override("font_color", YELLOW)
	else:
		hints.text = ""
	monitor_title.text = "カメラ映像" + ("　● REC" if st == S.TAKE else "")
	monitor_title.add_theme_color_override("font_color", RED if st == S.TAKE else DIM)

	# 本番の時計と合図
	if st == S.TAKE:
		var left: float = maxf(game.TAKE_SEC - game.take_t, 0.0)
		var ch: int = live.get("charges", 0)
		take_bar.text = "● 残り %02d秒　　[1]告白　[2]爆発 %s　[3]再会　　[T]カット" % [int(ceil(left)), "●".repeat(ch) + "○".repeat(2 - ch)]
		take_bar.add_theme_color_override("font_color", RED if left < 10.0 else Color.WHITE)
	elif st == S.REPLAY:
		take_bar.text = "▶ 見返し中　%.1f秒　　[Esc]で戻る" % game.replay_t
		take_bar.add_theme_color_override("font_color", Color.WHITE)
	else:
		take_bar.text = ""
	if full and (st == S.PREP or st == S.TAKE) and not hl.is_empty():
		take_bar.text += "\n" + "　".join(hl.slice(0, 3))

	big.text = str(int(ceil(game.countdown_t))) if st == S.COUNTDOWN else ""

	# 照準と対象
	var play: bool = st == S.PREP or st == S.TAKE or st == S.COUNTDOWN
	cross.visible = play and not full
	var tl := ""
	if play and me and op == null:
		if me.held != 0 and game.props.has(me.held):
			tl = "%s を持っている" % game.props[me.held].label
		elif me.target:
			var t: Node3D = me.target
			tl = t.label
			if t.fixed:
				tl += "（固定中）"
			if t.holder != 0:
				tl += "（誰かが持っている）"
	target_label.text = tl

	# 操作の案内
	var k := ""
	if st == S.PREP or st == S.TAKE:
		if op and op.kind == "camera":
			k = "カメラ操作中：マウスで首振り ／ ホイールでズーム ／ WASDで移動 ／ F で離れる"
		elif op:
			k = "ライト操作中：マウスで向き ／ ホイールで明るさ（%d／3） ／ F で離れる" % op.level
		elif me and me.held != 0:
			k = "左クリックで置く ／ ホイールで距離 ／ Q・E で回す ／ G で固定"
		elif me and me.target:
			k = "左クリックで持つ ／ G で%s" % ("固定を外す" if me.target.fixed else "固定")
			if me.target.kind in ["camera", "spot"]:
				k += " ／ F で操作"
		else:
			k = "WASD 移動 ／ Shift 走る ／ Space ジャンプ"
		if st == S.PREP:
			k += "\nT 本番開始 ／ 1・2・3 合図のリハーサル ／ B 役者を戻す ／ F9 見本を組む ／ Tab あそびかた"
		else:
			k += "\n1 告白 → 2 爆発 → 3 再会 ／ T カット"
	keys.text = k

	panel.visible = st == S.RESULT or st == S.DELIVERED
	if panel.visible:
		panel_text.text = game.panel_bbcode()


# ファインダーの枠線
class _Frame extends Control:
	func _draw() -> void:
		var s := size
		var c := Color(1, 1, 1, 0.55)
		var m := 40.0
		var l := 60.0
		for corner: Vector2 in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
			var sx := 1.0 if corner.x < s.x * 0.5 else -1.0
			var sy := 1.0 if corner.y < s.y * 0.5 else -1.0
			draw_line(corner, corner + Vector2(l * sx, 0), c, 3.0)
			draw_line(corner, corner + Vector2(0, l * sy), c, 3.0)
		draw_line(Vector2(s.x * 0.5 - 14, s.y * 0.5), Vector2(s.x * 0.5 + 14, s.y * 0.5), c, 2.0)
		draw_line(Vector2(s.x * 0.5, s.y * 0.5 - 14), Vector2(s.x * 0.5, s.y * 0.5 + 14), c, 2.0)
