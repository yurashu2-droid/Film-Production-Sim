extends CanvasLayer
# 画面表示。ゲームの状態を毎フレーム読んで描くだけで、判断はしない。

const YELLOW := Color(1.0, 0.86, 0.35)
const GREEN := Color(0.5, 1.0, 0.6)
const RED := Color(1.0, 0.45, 0.4)
const DIM := Color(0.8, 0.82, 0.88)

const CharacterPicker := preload("res://scripts/character_picker.gd")
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
var cross: Label
var target_label: Label
var take_bar: Label
var toast: Label
var big: Label
var panel: PanelContainer
var panel_text: RichTextLabel
var help: PanelContainer
var _toast_t := 0.0
var slate: Control


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

	slate = _Slate.new()
	slate.game = game
	slate.set_anchors_preset(Control.PRESET_FULL_RECT)
	slate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slate)

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
	character_button = Button.new()
	character_button.text = "[C] キャラクターを選ぶ"
	character_button.focus_mode = Control.FOCUS_NONE
	character_button.pressed.connect(func(): game.set_character_menu(true))
	ov.add_child(character_button)

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
	character_picker = CharacterPicker.new()
	character_picker.game = game
	root.add_child(character_picker)
	character_picker.build()


const HELP_TEXT := """あそびかた（Tabで閉じる）

少ない機材と廃材で、依頼された3つの場面を1テイクに収める。
  1 告白：二人が高低差つきで、城のセットと一緒に明るく映る
  2 爆発：告白のあと、二人の背後で爆発が映る
  3 再会：爆発のあと、近づいた二人が映る

移動 WASD ／ 走る Shift ／ ジャンプ Space ／ 視点 マウス
持つ・置く 左クリック ／ 距離 ホイール ／ 回す 右ドラッグ（Q・Eも可）
段ボールの開閉 F（持っている箱、または照準の箱）
キャラクターを選ぶ C（依頼画面・仕込み中）
固定・解除 G（倒れやすい物を留める）
機材を操作 F（カメラ：首振り・ホイールでズーム
　　　　　　　ライト：向き・ホイールで明るさ）
台車：物を上で離すと載る。カメラを載せると WASD で移動撮影
ライトは持って歩くと、見ている方向を照らす
本番開始：カチンコを持って F ／ カット：T かカチンコ
合図 1 告白・2 爆発・3 再会
軽トラ：搬入口の荷台から機材を降ろす。物を戻して載せることもできる
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


func show_slate(mode: String, take: int) -> void:
	slate.start(mode, take)


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
	character_button.visible = st in [S.ORDER, S.PREP]
	character_button.disabled = game.local_player() == null
	var me: Node = game.local_player()
	var op: Node3D = game.props.get(me.operating) if me and me.operating != 0 else null
	var full: bool = st == S.REPLAY or (op != null and op.kind == "camera")
	viewfinder.visible = full
	vf_frame.visible = full
	monitor_box.visible = not full and st != S.RESULT and st != S.DELIVERED and st != S.ORDER
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
		S.REPLAY: "見返し中", S.DELIVERED: "納品", S.ORDER: "依頼を受ける"}
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
		take_bar.text = "● 残り %02d秒　　[1]告白　[2]爆発 %s　[3]再会" % [int(ceil(left)), "（書割）" if ch < 0 else ("●".repeat(ch) if ch > 0 else "残りなし")]
		take_bar.add_theme_color_override("font_color", RED if left < 10.0 else Color.WHITE)
	elif st == S.REPLAY:
		take_bar.text = "▶ 見返し中　%.1f秒　　[Esc]で戻る" % game.replay_t
		take_bar.add_theme_color_override("font_color", Color.WHITE)
	else:
		take_bar.text = ""
	if full and (st == S.PREP or st == S.TAKE) and not hl.is_empty():
		take_bar.text += "\n" + "　".join(hl.slice(0, 3))

	big.text = ""

	# 照準と対象
	var play: bool = st == S.PREP or st == S.TAKE or st == S.COUNTDOWN
	cross.visible = play and not full
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
	target_label.text = tl if slate.mode == "" else ""

	# 操作の案内
	var k := ""
	if st == S.PREP or st == S.TAKE:
		if op and op.kind == "camera":
			k = "カメラ操作中：マウスで首振り ／ ホイールでズーム ／ %s ／ F で離れる" % ("WASDで台車ごと移動" if op.rider_of != 0 else "台車に載せると移動撮影できる")
		elif op:
			k = "ライト操作中：マウスで向き ／ ホイールで明るさ（%d／3） ／ F で離れる" % op.level
		elif me and me.held != 0:
			var hk: String = game.props[me.held].kind if game.props.has(me.held) else ""
			if hk == "clapper":
				k = "F でカチンコを打つ（%s） ／ 左クリックで置く" % ("カット" if st == S.TAKE else "本番開始")
			elif hk == "spot":
				k = "見ている方向へ光が向く ／ 左クリックで置く ／ G で固定"
			elif hk == "dolly":
				k = "台車を押している ／ 右ドラッグで向きを変える ／ 左クリックで離す ／ G でブレーキ"
			else:
				k = "左クリックで置く（台車の上なら載る） ／ ホイールで距離 ／ 右ドラッグで回す（Q・Eも可） ／ G で固定"
		elif me and me.target:
			k = "左クリックで持つ ／ G で%s" % ("固定を外す" if me.target.fixed else "固定")
			if me.target.kind in ["camera", "spot"]:
				k += " ／ F で操作"
		else:
			k = "WASD 移動 ／ Shift 走る ／ Space ジャンプ"
		if st == S.PREP:
			k += "\nカチンコを持って F で本番開始 ／ 1・2・3 合図のリハーサル ／ B 役者を戻す ／ F9 見本を組む ／ Tab あそびかた"
		else:
			k += "\n1 告白 → 2 爆発 → 3 再会 ／ T かカチンコでカット"
	keys.text = k

	panel.visible = st == S.RESULT or st == S.DELIVERED or st == S.ORDER
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


# 画面に大きく出るカチンコ。本番前に出て、打って消える
class _Slate extends Control:
	var game: Node
	var mode := ""
	var take := 1
	var t := 0.0
	var _home_parent: Node
	var _entry_layer: CanvasLayer

	func start(m: String, n: int) -> void:
		_restore_parent()
		mode = m
		take = n
		t = 0.0
		if mode == "intro":
			_home_parent = get_parent()
			_entry_layer = CanvasLayer.new()
			_entry_layer.layer = 10
			game.add_child(_entry_layer)
			reparent(_entry_layer)
			set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP if mode == "intro" else Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _restore_parent() -> void:
		if _entry_layer == null:
			return
		reparent(_home_parent)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_entry_layer.queue_free()
		_entry_layer = null
		_home_parent = null

	func _input(event: InputEvent) -> void:
		if mode == "intro" and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()

	func _process(delta: float) -> void:
		if mode == "":
			return
		var previous := t
		t += delta
		# 音は拍子木が閉じきる瞬間に一度だけ。入室を取り消せばノードと一緒に止まる。
		if mode == "intro" and previous < 0.38 and t >= 0.38:
			Sfx.play("clap")
		if (mode in ["intro", "clap"] and t > 0.95) or (mode == "cut" and t > 1.25):
			mode = ""
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			_restore_parent()
		queue_redraw()

	func _draw() -> void:
		if mode == "":
			return
		var font: Font = game.font
		var film := "本日の制作、スタート！" if mode == "intro" else "月下の城と大爆発"
		if mode == "intro":
			var shade := minf(clampf(t / 0.18, 0.0, 1.0), 1.0 - clampf((t - 0.65) / 0.3, 0.0, 1.0))
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, shade * 0.45))
		var w := 520.0
		var h := 330.0
		var bar := 54.0
		var slide := 0.0          # 0=定位置、1=画面の下へ
		var angle := -0.38        # 上の拍子木の開き
		if mode == "intro":
			angle = lerpf(-0.38, 0.0, clampf((t - 0.30) / 0.08, 0.0, 1.0))
			slide = (1.0 - clampf(t / 0.18, 0.0, 1.0)) + clampf((t - 0.65) / 0.3, 0.0, 1.0)
		elif mode == "ready":
			slide = 1.0 - clampf(t / 0.22, 0.0, 1.0)
		elif mode == "clap":
			angle = lerpf(-0.38, 0.0, clampf(t / 0.06, 0.0, 1.0))
			slide = clampf((t - 0.6) / 0.3, 0.0, 1.0)
		else:
			angle = lerpf(-0.38, 0.0, clampf((t - 0.14) / 0.06, 0.0, 1.0))
			slide = (1.0 - clampf(t / 0.12, 0.0, 1.0)) + clampf((t - 0.9) / 0.3, 0.0, 1.0)
		slide = slide * slide
		var origin := Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.35 + slide * size.y * 0.8)
		var tilt := -0.05 + (0.04 * sin(t * 30.0) * maxf(0.0, 0.25 - t) if mode != "ready" else 0.0)
		draw_set_transform(origin, tilt, Vector2.ONE)
		var black := Color(0.07, 0.07, 0.08)
		var white := Color(0.96, 0.95, 0.9)
		draw_rect(Rect2(-6, bar - 6, w + 12, h + 12), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, bar, w, h), black)
		draw_rect(Rect2(0, bar, w, h), white, false, 4.0)
		_stripes(Rect2(0, 0, w, bar), black, white)
		draw_line(Vector2(0, bar + 92), Vector2(w, bar + 92), white, 3.0)
		draw_line(Vector2(w * 0.5, bar + 92), Vector2(w * 0.5, bar + h), white, 3.0)
		draw_string(font, Vector2(20, bar + 40), "格安アクション映画制作班", HORIZONTAL_ALIGNMENT_LEFT, w - 40, 24, Color(0.75, 0.75, 0.7))
		draw_string(font, Vector2(20, bar + 78), film, HORIZONTAL_ALIGNMENT_LEFT, w - 40, 32, white)
		draw_string(font, Vector2(20, bar + 130), "TAKE", HORIZONTAL_ALIGNMENT_LEFT, 200, 26, Color(0.75, 0.75, 0.7))
		draw_string(font, Vector2(0, bar + 262), str(take), HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, 150, white)
		var right := ""
		var col := white
		if mode == "ready":
			right = str(int(ceil(game.countdown_t)))
			draw_string(font, Vector2(w * 0.5 + 20, bar + 130), "本番まで", HORIZONTAL_ALIGNMENT_LEFT, 200, 26, Color(0.75, 0.75, 0.7))
			draw_string(font, Vector2(w * 0.5, bar + 262), right, HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, 150, Color(1.0, 0.86, 0.35))
		else:
			right = "開始" if mode == "intro" else ("本番！" if mode == "clap" else "カット！")
			col = Color(1.0, 0.45, 0.4) if mode in ["intro", "clap"] else Color(1.0, 0.86, 0.35)
			draw_string(font, Vector2(w * 0.5, bar + 222), right, HORIZONTAL_ALIGNMENT_CENTER, w * 0.5, 66, col)
		# 上の拍子木（左端の蝶番で開く）
		draw_set_transform(origin + Vector2(0, 0).rotated(tilt), tilt + angle, Vector2.ONE)
		_stripes(Rect2(0, -bar, w, bar), black, white)
		draw_circle(Vector2(10, 0), 9.0, Color(0.6, 0.6, 0.62))
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
		draw_rect(r, white, false, 3.0)
