extends Control
# 依頼の打ち合わせ：依頼主が何を撮ってほしいかを話し、絵コンテで3場面を見せる。
# 絵コンテは「どんな画か」だけ。何を使うかは制作班が決めるので、完成写真（答え）は見せない。
# ここで「受ける」を押して初めて依頼が始まる（廃材置き場の門が開き、時計が動く）。
const UI := preload("res://scripts/ui/ui_theme.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const Storyboard := preload("res://scripts/ui/storyboard.gd")
const Scripts := preload("res://scripts/production_script.gd")
const PAPER_TILE := Color("e4e1d8")

signal accepted(index: int)
signal declined

var game: Node
var job_index := -1
var accept: Button

var _panel: PanelContainer
var _title: Label
var _place: Label
var _face: TextureRect
var _name: Label
var _role: Label
var _like: Label
var _talk: VBoxContainer
var _boards: Array = []          # [{pic, title, need}]
var _strip: HBoxContainer        # 絵コンテを並べる所（場面の数だけ。ふつうは3枚、完全版は5枚）
var _terms: Label
var _bonus: Label
var _budget: Label
var _purse: Label
var _shown := 0
var _timer := 0.0
var _lines: Array = []


func build(owner_game: Node) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = UI.panel("slate", 0.0, true, 28, 22)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var head_l := VBoxContainer.new()
	head_l.add_theme_constant_override("separation", 2)
	head_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_l)
	head_l.add_child(UI.overline("打ち合わせ"))
	_title = UI.label("", 28, UI.CLAP_WHITE, "display")
	head_l.add_child(_title)
	_place = UI.label("", 15, UI.MUTED, "body")
	_place.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_place)
	col.add_child(UI.hairline())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)

	# 左：依頼主の顔と、せりふ
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 330
	body.add_child(left)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	left.add_child(who)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(124, 124)
	frame.add_theme_stylebox_override("panel", UI.box(PAPER_TILE, Color(0, 0, 0, 0), 0, 4, 6, 6))
	who.add_child(frame)
	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_face)
	var who_text := VBoxContainer.new()
	who_text.add_theme_constant_override("separation", 2)
	who_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(who_text)
	who_text.add_child(UI.overline("依頼主"))
	_name = UI.label("", 20, UI.CLAP_WHITE, "bold")
	who_text.add_child(_name)
	_role = UI.label("", 14, UI.MUTED, "body")
	who_text.add_child(_role)
	# 依頼主の好み：この属性の物を役に使うと、ギャラが増える
	_like = UI.label("", 14, UI.CLAP_WHITE, "bold")
	who_text.add_child(_like)
	_talk = VBoxContainer.new()
	_talk.add_theme_constant_override("separation", 8)
	left.add_child(_talk)

	body.add_child(UI.hairline(true))

	# 右：絵コンテ3枚と、条件
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(UI.overline("絵コンテ　／　こう映れば成立。「？」に何を使うかは制作班しだい"))
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 12)
	right.add_child(_strip)
	_fill_boards(3)
	right.add_child(UI.hairline())
	# 制作費：依頼主が出す。借り物はこの中から。使い残しは会社の儲け
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 10)
	right.add_child(money_row)
	var money_cap := UI.label("制作費", 15, UI.MUTED, "bold")
	money_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_row.add_child(money_cap)
	_budget = UI.label("", 24, UI.CLAP_WHITE, "display")
	money_row.add_child(_budget)
	_purse = UI.label("", 14, UI.MUTED, "body")
	_purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_purse.custom_minimum_size.x = 120
	_purse.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	money_row.add_child(_purse)
	var bonus_row := HBoxContainer.new()
	bonus_row.add_theme_constant_override("separation", 8)
	right.add_child(bonus_row)
	bonus_row.add_child(UI.label("+150", 15, UI.TAPE, "bold"))
	_bonus = UI.label("", 15, UI.CLAP_WHITE, "body")
	bonus_row.add_child(_bonus)
	_terms = UI.label("", 13, UI.MUTED, "body")
	_terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terms.custom_minimum_size.x = 600
	right.add_child(_terms)

	col.add_child(UI.hairline())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var back := Button.new()
	back.text = "ほかの依頼を見る"
	UI.style_button(back, "slate", 15, 44)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: declined.emit())
	foot.add_child(back)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	accept = UI.KeyButton.new().setup("この依頼を受ける", "Enter", "tape", 17, 48)
	accept.custom_minimum_size.x = 300
	accept.pressed.connect(func() -> void: accepted.emit(job_index))
	foot.add_child(accept)
	visible = false
	resized.connect(_fit)
	_fit()


# 絵コンテの枠を、場面の数だけ作り直す（3枚は今までの大きさ。5枚のときは、小さく並べる）
func _fill_boards(count: int) -> void:
	if _boards.size() == count:
		return
	for old: Node in _strip.get_children():
		_strip.remove_child(old)
		old.queue_free()
	_boards.clear()
	var many := count > 3
	_strip.add_theme_constant_override("separation", 8 if many else 12)
	for i in count:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.x = 122 if many else 200
		_strip.add_child(cell)
		var sheet := PanelContainer.new()
		sheet.add_theme_stylebox_override("panel", UI.box(Color("eee9dc"), Color(0, 0, 0, 0), 0, 3, 5, 5))
		cell.add_child(sheet)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size.y = 76 if many else 128
		sheet.add_child(pic)
		var title := UI.label("", 13 if many else 15, UI.CLAP_WHITE, "bold")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = 112 if many else 180
		cell.add_child(title)
		var need := UI.label("", 12 if many else 13, UI.MUTED, "body")
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.custom_minimum_size = Vector2(112, 66) if many else Vector2(180, 38)
		cell.add_child(need)
		_boards.append({"pic": pic, "title": title, "need": need})


func _fit() -> void:
	var w := clampf(size.x - 48.0, 960.0, 1180.0)
	_panel.custom_minimum_size.x = w
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5


func open(index: int) -> void:
	job_index = index
	var job: Dictionary = game.production.JOBS[index]
	var data: Dictionary = Briefs.brief(index)
	_title.text = str(job["title"])
	_place.text = "撮影場所：%s" % game.production.location_name()
	_name.text = str(data["name"])
	_role.text = str(data["role"])
	var likes: Array = data.get("likes", [])
	_like.text = "好み　" + "".join(likes.map(func(a: String) -> String: return "〔%s〕" % a))
	_like.visible = not likes.is_empty()
	var face_path := "res://assets/ui/clients/%s.png" % str(data["cast"])
	_face.texture = load(face_path) if ResourceLoader.exists(face_path) else null
	var story: String = str(job["script"])
	# 絵コンテの組（5場面の完全版は、専用の5枚。無ければ、台本と同じ名前の3枚）
	var board_set: String = str(job.get("board", story))
	var scenes: Array = job["scenes"]
	var needs: Array = Briefs.BOARDS.get(board_set, [])
	_fill_boards(scenes.size())
	for i in scenes.size():
		var board: Dictionary = _boards[i]
		(board["pic"] as TextureRect).texture = Storyboard.texture(board_set, i)
		(board["title"] as Label).text = "%d　%s" % [i + 1, str(scenes[i]).get_slice("（", 0)]
		(board["need"] as Label).text = str(needs[i]) if i < needs.size() else ""
	# 条件の文：場面の数と、全部そろったときの上乗せは、依頼ごと
	var paging: bool = not (Scripts.beats(index) as Array).is_empty()
	_terms.text = "借り物は制作費の中から。使わなかった制作費は、そのまま会社の儲けになる。\nギャラは、成立した場面1つにつき250コイン、%dつそろえばさらに%dコイン。準備は3分。\n" % [scenes.size(), int(job.get("fee_all", 300))]
	if paging:
		_terms.text += "場面は、台本を読める人が進める。テイクは、フィルム1本ぶん（止まらない）。班の誰かが映っている間は、撮れていない。\n"
	_terms.text += "「？」の役は、どの物を使ってもいい。らしい物ほどギャラが増え、同じ属性の物を別々の役に使うとコンボでさらに増える。依頼主の好みの属性の物を使えば、役ごとに +60。"
	_bonus.text = "追加注文　" + str(job["bonus_title"])
	_budget.text = "%d コイン" % int(job.get("budget", 600))
	var purse: String = str(data.get("purse", ""))
	_purse.text = "「%s」" % purse if purse != "" else ""
	# せりふは1つずつ出る（クリックで全部出す）
	for c in _talk.get_children():
		c.queue_free()
	_lines = (data["lines"] as Array).duplicate()
	if str(data.get("taste", "")) != "":
		_lines.append(str(data["taste"]) + "。")
	_shown = 0
	_timer = 0.15
	visible = true


func close() -> void:
	visible = false
	job_index = -1


func _process(delta: float) -> void:
	if not visible or _shown >= _lines.size():
		return
	_timer -= delta
	if _timer <= 0.0:
		_say()
		_timer = 1.1


func _say() -> void:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.box(PAPER_TILE, Color(0, 0, 0, 0), 0, 6, 14, 10))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := UI.label(str(_lines[_shown]), 15, UI.INK, "body")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 300
	bubble.add_child(words)
	_talk.add_child(bubble)
	bubble.modulate.a = 0.0
	bubble.create_tween().tween_property(bubble, "modulate:a", 1.0, 0.18)
	_shown += 1
	Sfx.play("ui_select", null, -8.0)


func _gui_input(event: InputEvent) -> void:
	# どこかをクリックすると、残りのせりふをすぐ出す
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		while _shown < _lines.size():
			_say()
