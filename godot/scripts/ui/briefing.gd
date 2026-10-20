extends Control
# 依頼の打ち合わせ：喫茶店のテーブルで、依頼主と向かい合う。
#   左：依頼主の写真（ポラロイド）と、吹き出しのせりふ ／ まん中：絵コンテの紙を場面の数だけ ／ 右：御伝票（条件と制作費）
#   引き受けるときは、赤い判子を押す（伝票に赤い跡が残る）。「ほかの依頼を見る」は段ボールの札。
# 絵コンテは「どんな画か」だけ。何を使うかは制作班が決めるので、完成写真（答え）は見せない。
# ここで「受ける」を押して初めて依頼が始まる（廃材置き場の門が開き、時計が動く）。
# テーブルの物は ui/cafe_parts.gd が描く。配置は 1600x900 の台の上に決め打ちし、画面のまん中に置く
const Briefs := preload("res://scripts/production_briefs.gd")
const Storyboard := preload("res://scripts/ui/storyboard.gd")
const Scripts := preload("res://scripts/production_script.gd")
const STAGE := Vector2(1600, 900)
const CREAM := Color("f5e6cc")
const TILT := [-2.0, 1.5, -1.0, 2.2, -1.6]
const DROP := [0.0, 8.0, 0.0, 5.0, 3.0]

signal accepted(index: int)
signal declined

var game: Node
var job_index := -1
var accept: Button              # 判子（押すと引き受ける）

var _panel: Control             # テーブル一式（の台）。production_hud.gd が紙の色に塗り替えようとするが、ここの物は自分の色を持つ（_seal）
var _table: CafeParts.Table
var _title: Label
var _face: CafeParts.Photo
var _name: Label
var _role: Label
var _polaroid: PanelContainer
var _bubble: PanelContainer
var _words: Label
var _center: VBoxContainer
var _rows: VBoxContainer         # 絵コンテの紙を並べる所（場面の数だけ。ふつうは3枚、完全版は5枚）
var _like: Label
var _rule: Label
var _slip: PanelContainer
var _place: Label
var _scenes: Label
var _fee: Label
var _fee_all_cap: Label
var _fee_all: Label
var _bonus: Label
var _budget: Label
var _purse: Label
var _terms: Label
var _back: Button
var _cups: Array = []
var _mark: CafeParts.Mark
var _shown := 0
var _timer := 0.0
var _lines: Array = []
var _closing := false
var _pressed := false
var _tween: Tween


func build(owner_game: Node) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = Control.new()
	_panel.size = STAGE
	add_child(_panel)

	_table = CafeParts.Table.new()
	_table.size = STAGE
	_table.top = Rect2(80, 34, 1440, 832)
	_panel.add_child(_table)
	# コーヒーカップ（飾り）。紙の下に来るよう、先に置く
	for spec: Array in [[Vector2(1062, 640), 118.0, 0.5, true], [Vector2(118, 742), 96.0, 2.6, false]]:
		var cup := CafeParts.Cup.new()
		cup.position = spec[0]
		cup.size = Vector2(spec[1], spec[1])
		cup.handle_angle = spec[2]
		cup.spoon = spec[3]
		_panel.add_child(cup)
		_cups.append(cup)

	# 左：依頼主の写真（ポラロイド）
	_polaroid = PanelContainer.new()
	_polaroid.add_theme_stylebox_override("panel", CafeParts.PaperStyle.new(Color("fbfaf5"), 12.0, 12.0, 10.0))
	_polaroid.position = Vector2(140, 84)
	_polaroid.rotation = deg_to_rad(-5.0)
	_panel.add_child(_polaroid)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 2)
	_polaroid.add_child(pcol)
	_face = CafeParts.Photo.new()
	_face.custom_minimum_size = Vector2(196, 196)
	pcol.add_child(_face)
	_name = FilmSet.label("", 20, CafeParts.INK, "marker")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pcol.add_child(_name)
	_role = FilmSet.label("", 14, CafeParts.INK_SOFT, "marker")
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.custom_minimum_size.x = 196
	pcol.add_child(_role)

	# 左の下：吹き出し（せりふが1つずつ足される）
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", CafeParts.BubbleStyle.new())
	_bubble.position = Vector2(126, 398)
	_panel.add_child(_bubble)
	_words = FilmSet.label("", 16, CafeParts.INK, "marker")
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size.x = 268
	_words.add_theme_constant_override("line_spacing", 3)
	_bubble.add_child(_words)

	# まん中：題と、絵コンテの紙と、好み・決まりの書き付け
	_center = VBoxContainer.new()
	_center.position = Vector2(468, 66)
	_center.custom_minimum_size.x = 640
	_center.add_theme_constant_override("separation", 10)
	_panel.add_child(_center)
	_title = FilmSet.label("", 32, CREAM, "marker")
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.55))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 640
	_center.add_child(_title)
	var cap := FilmSet.label("絵コンテ　こう映れば成立。「？」に何を使うかは制作班しだい", 15, Color(CREAM, 0.78), "marker")
	_center.add_child(cap)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 18)
	_center.add_child(_rows)
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	_center.add_child(gap)
	_like = FilmSet.label("", 17, Color("ffe7a8"), "marker")
	_like.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_like.custom_minimum_size.x = 600
	_center.add_child(_like)
	_rule = FilmSet.label("", 14, Color(CREAM, 0.8), "marker")
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.custom_minimum_size.x = 560
	_center.add_child(_rule)

	# 右：御伝票
	_slip = PanelContainer.new()
	_slip.add_theme_stylebox_override("panel", CafeParts.PaperStyle.new(Color("f6f3ea"), 20.0, 16.0, 16.0))
	_slip.position = Vector2(1160, 76)
	_slip.custom_minimum_size.x = 318
	_slip.rotation = deg_to_rad(1.5)
	_panel.add_child(_slip)
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 3)
	_slip.add_child(sc)
	var head := FilmSet.label("御 伝 票", 22, CafeParts.PRINT_RED, "mincho")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.add_child(head)
	sc.add_child(CafeParts.Rule.new(Color(CafeParts.PRINT_RED, 0.7), 7.0, 4.0, 1.5))
	_place = _slip_row(sc, "撮影場所", "marker")
	_scenes = _slip_row(sc, "場面", "marker")
	_fee = _slip_row(sc, "ギャラ（1場面）", "mono")
	_fee_all = _slip_row(sc, "", "mono")
	_fee_all_cap = (_fee_all.get_parent() as HBoxContainer).get_child(0) as Label
	var bonus_amount := _slip_row(sc, "追加の注文", "mono", false)
	bonus_amount.text = "+150"
	_bonus = FilmSet.label("", 15, CafeParts.INK, "marker")
	_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus.custom_minimum_size.x = 278
	sc.add_child(_bonus)
	sc.add_child(CafeParts.Rule.new(Color(0, 0, 0, 0.3), 2.0, 3.0, 1.2))
	var total := HBoxContainer.new()
	sc.add_child(total)
	var tcap := FilmSet.label("制作費", 19, CafeParts.PRINT_RED, "mincho")
	tcap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tcap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(tcap)
	_budget = FilmSet.label("", 28, CafeParts.INK, "mono")
	total.add_child(_budget)
	var unit := FilmSet.label("コイン", 13, CafeParts.INK_SOFT, "mincho")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	total.add_child(unit)
	_purse = FilmSet.label("", 14, CafeParts.INK, "marker")
	_purse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_purse.custom_minimum_size.x = 278
	sc.add_child(_purse)
	sc.add_child(CafeParts.Rule.new(Color(CafeParts.PRINT_RED, 0.7), 7.0, 4.0, 1.5))
	_terms = FilmSet.label("", 12, CafeParts.INK_SOFT, "mincho")
	_terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terms.custom_minimum_size.x = 278
	_terms.add_theme_constant_override("line_spacing", 2)
	sc.add_child(_terms)

	# 判子（引き受ける）
	var hanko := CafeParts.Hanko.new()
	hanko.size = Vector2(150, 150)
	hanko.rotation = deg_to_rad(-12.0)
	hanko.pressed.connect(_on_stamp)
	_panel.add_child(hanko)
	accept = hanko

	# ほかの依頼を見る（段ボールの札）
	_back = Button.new()
	_back.text = "ほかの依頼を見る"
	_back.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(_back, "cream", 20, 50)
	_back.rotation = deg_to_rad(-1.5)
	_back.pressed.connect(func() -> void:
		if not _closing:
			declined.emit())
	_panel.add_child(_back)

	visible = false
	resized.connect(_fit)
	_fit()
	_seal(self)


# 伝票の1行（刷ってある項目名と、手書きの中身）。中身の Label を返す
func _slip_row(parent: VBoxContainer, caption: String, kind: String, ruled := true) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var c := FilmSet.label(caption, 14, CafeParts.PRINT_RED, "mincho")
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	var v := FilmSet.label("", 17 if kind == "mono" else 16, CafeParts.INK, kind)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.custom_minimum_size.x = 60
	row.add_child(v)
	if ruled:
		parent.add_child(CafeParts.Rule.new(Color(0, 0, 0, 0.3), 2.0, 3.0, 1.2))
	return v


# ほかの画面（production_hud.gd の paperize）に色を塗り替えられないよう、印を付ける。飾りはクリックを素通しにする
func _seal(n: Node) -> void:
	n.set_meta("papered", true)
	if n is Control and n != self and not (n is Button):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_seal(c)


func _fit() -> void:
	if _panel == null:
		return
	_panel.position = ((size - STAGE) * 0.5).floor()


# 中身が決まってから、紙の大きさに合わせて判子と札を置く
func _place_tools() -> void:
	for c: Control in [_polaroid, _bubble, _center, _slip]:
		c.reset_size()
		c.pivot_offset = c.size * 0.5
	_back.reset_size()
	_back.pivot_offset = _back.size * 0.5
	_back.position = Vector2(_center.position.x + 6.0, maxf(_center.position.y + _center.size.y + 18.0, 772.0))
	if not _closing:
		accept.position = Vector2(1258, clampf(_slip.position.y + _slip.size.y + 14.0, 600.0, 700.0))
	_cups[0].position = Vector2(1092, clampf(accept.position.y + 20.0, 600.0, 700.0))


func open(index: int) -> void:
	_stop_anim()
	job_index = index
	var job: Dictionary = game.production.JOBS[index]
	var data: Dictionary = Briefs.brief(index)
	_title.text = str(job["title"])
	_name.text = str(data["name"])
	_role.text = str(data["role"])
	var face_path := "res://assets/ui/clients/%s.png" % str(data["cast"])
	_face.tex = load(face_path) if ResourceLoader.exists(face_path) else null
	_face.queue_redraw()
	var likes: Array = data.get("likes", [])
	_like.text = "好み　" + "".join(likes.map(func(a: String) -> String: return "〔%s〕" % a)) + "　の物を役に使うと、役ごとに +60"
	_like.visible = not likes.is_empty()
	_rule.text = "「？」の役は、どの物を使ってもいい。らしい物ほどギャラが増え、同じ属性の物を別々の役に使うとコンボでさらに増える。"
	var story: String = str(job["script"])
	# 絵コンテの組（5場面の完全版は、専用の5枚。無ければ、台本と同じ名前の3枚）
	var board_set: String = str(job.get("board", story))
	var scenes: Array = job["scenes"]
	var needs: Array = Briefs.BOARDS.get(board_set, [])
	_fill_boards(board_set, scenes, needs)
	# 伝票
	var paging: bool = not (Scripts.beats(index) as Array).is_empty()
	var cut: bool = paging and Scripts.cuts(index)
	_place.text = game.production.location_name()
	_scenes.text = ("カット割り %d" if cut else ("通し %d" if paging else "%d")) % scenes.size()
	_fee.text = "250"
	_fee_all_cap.text = "%dつそろえば" % scenes.size()
	_fee_all.text = "+%d" % int(job.get("fee_all", 300))
	_bonus.text = str(job["bonus_title"])
	_budget.text = str(int(job.get("budget", 600)))
	var purse: String = str(data.get("purse", ""))
	_purse.text = "「%s」" % purse if purse != "" else ""
	_purse.visible = purse != ""
	_terms.text = "借り物は制作費の中から。使わなかった制作費は、そのまま会社の儲けになる。準備は3分。"
	if cut:
		_terms.text += "\nカット割り：場面が撮れるとフィルムが止まる。止まっている間に次の場面を用意して、台本を読める人が 1 で回す。回している間に班の誰かが映ると、撮れていない。"
	elif paging:
		_terms.text += "\n場面は、台本を読める人が進める。テイクは、フィルム1本ぶん（止まらない）。班の誰かが映っている間は、撮れていない。"
	# せりふは1つずつ出る（クリックで全部出す）
	_lines = (data["lines"] as Array).duplicate()
	if str(data.get("taste", "")) != "":
		_lines.append(str(data["taste"]) + "。")
	_words.text = ""
	_bubble.visible = false
	_shown = 0
	_timer = 0.15
	_seal(self)
	visible = true
	_place_tools()
	_place_tools.call_deferred()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.14)


# 絵コンテの紙を、場面の数だけ並べる（4枚までは1列。5枚は 3＋2 の2段）
func _fill_boards(board_set: String, scenes: Array, needs: Array) -> void:
	for old: Node in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	var count := scenes.size()
	var per_row := count if count <= 4 else 3
	var sep := 16.0 if per_row >= 4 else 26.0
	var w := floorf((640.0 - sep * (per_row - 1)) / per_row) - 6.0
	var row: HBoxContainer
	for i in count:
		if i % per_row == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", int(sep))
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			_rows.add_child(row)
		var sheet := PanelContainer.new()
		sheet.add_theme_stylebox_override("panel", CafeParts.PaperStyle.new(Color("fbfaf5"), 9.0, 8.0, 10.0))
		sheet.custom_minimum_size.x = w
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		sheet.add_child(col)
		var title := FilmSet.label("%d　%s" % [i + 1, str(scenes[i]).get_slice("（", 0)], 17 if per_row < 4 else 15, CafeParts.INK, "marker")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = w - 18.0
		col.add_child(title)
		var tex := Storyboard.texture(board_set, i)
		if tex != null:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			pic.custom_minimum_size = Vector2(w - 18.0, floorf((w - 18.0) * 9.0 / 16.0))
			col.add_child(pic)
		var need := FilmSet.label(str(needs[i]) if i < needs.size() else "", 14 if per_row < 4 else 13, CafeParts.INK_SOFT, "marker")
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.custom_minimum_size.x = w - 18.0
		col.add_child(need)
		# 箱（HBox）は中の物の傾きを消すので、ただの置き場（slot）に入れて傾ける
		var slot := Control.new()
		slot.custom_minimum_size.x = w
		slot.add_child(sheet)
		sheet.position = Vector2(0, DROP[i % DROP.size()])
		sheet.rotation = deg_to_rad(TILT[i % TILT.size()])
		sheet.resized.connect(func() -> void:
			sheet.pivot_offset = sheet.size * 0.5
			slot.custom_minimum_size = Vector2(w, sheet.size.y + DROP[i % DROP.size()]))
		row.add_child(slot)


func close() -> void:
	if _closing:
		return
	# 引き受けたとき（判子を押した・Enter で受けた）は、判子を伝票に押してから消える
	var taken: bool = _pressed or (game != null and game.production != null and int(game.production.phase) != 0)
	job_index = -1
	if visible and taken:
		_stamp_and_leave()
		return
	_stop_anim()
	visible = false


func _on_stamp() -> void:
	if _closing or _pressed or job_index < 0:
		return
	_pressed = true
	accepted.emit(job_index)


# 判子が持ち上がって伝票の制作費の所へ降り、ポンと縮んで赤い跡を残す。少し置いてから画面ごと消える
func _stamp_and_leave() -> void:
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accept.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	while _shown < _lines.size():
		_say()
	if _tween != null:
		_tween.kill()
	_panel.modulate.a = 1.0
	var hit := _slip.get_global_transform() * (Vector2(_slip.size.x * 0.55, _slip.size.y * 0.62))
	hit = _panel.get_global_transform().affine_inverse() * hit
	var start_pos := accept.position
	_tween = create_tween()
	_tween.tween_property(accept, "scale", Vector2(1.12, 1.12), 0.07).set_ease(Tween.EASE_OUT)
	_tween.tween_property(accept, "position", hit - accept.size * 0.5 + Vector2(6, -26), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(accept, "rotation", deg_to_rad(-6.0), 0.13)
	_tween.tween_property(accept, "position", hit - accept.size * 0.5, 0.06).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(accept, "scale", Vector2(0.86, 0.86), 0.06).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		_mark = CafeParts.Mark.new()
		_mark.size = accept.size * 0.86
		_mark.position = hit - _mark.size * 0.5
		_mark.rotation = deg_to_rad(-6.0)
		_mark.set_meta("papered", true)
		_panel.add_child(_mark)
		_panel.move_child(accept, -1)
		_mark.scale = Vector2(1.08, 1.08)
		create_tween().tween_property(_mark, "scale", Vector2.ONE, 0.08)
		Sfx.play("ui_ok", null, -4.0))
	_tween.tween_property(accept, "position", start_pos + Vector2(0, -20), 0.16).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(accept, "scale", Vector2.ONE, 0.16)
	_tween.parallel().tween_property(accept, "modulate:a", 0.0, 0.16)
	_tween.tween_interval(0.4)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void:
		_stop_anim()
		visible = false)


# 判子・跡・消えかけを、元に戻す
func _stop_anim() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_closing = false
	_pressed = false
	if _mark != null:
		_mark.queue_free()
		_mark = null
	if accept != null:
		accept.scale = Vector2.ONE
		accept.rotation = deg_to_rad(-12.0)
		accept.modulate.a = 1.0
		accept.mouse_filter = Control.MOUSE_FILTER_STOP
		_back.mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_filter = Control.MOUSE_FILTER_STOP
		_panel.modulate.a = 1.0


func _process(delta: float) -> void:
	if not visible or _closing or _shown >= _lines.size():
		return
	_timer -= delta
	if _timer <= 0.0:
		_say()
		_timer = 1.1


func _say() -> void:
	_words.text += ("\n" if _shown > 0 else "") + str(_lines[_shown])
	_shown += 1
	_bubble.visible = true
	_bubble.reset_size()
	if _shown == 1:
		_bubble.modulate.a = 0.0
		_bubble.create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.18)
	if not _closing:
		Sfx.play("ui_select", null, -8.0)


func _gui_input(event: InputEvent) -> void:
	# どこかをクリックすると、残りのせりふをすぐ出す
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		while _shown < _lines.size():
			_say()
