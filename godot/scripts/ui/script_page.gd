extends PanelContainer
# 台本のページ。台本を手に持っている人の画面の右側にだけ出る（紙の見た目）。
# 3場面のト書き・せりふ・撮り方を1枚に並べ、撮影中は「いまの場面」を濃く見せる。
const UI := preload("res://scripts/ui/ui_theme.gd")
const Scripts := preload("res://scripts/production_script.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Storyboard := preload("res://scripts/ui/storyboard.gd")
const PAPER := Color("f3eee0")
const INK := Color("1b1c20")
const FADED := Color("6a665c")
const WIDTH := 430.0

var game: Node
var _rows: VBoxContainer
var _sig := ""
var _blocks: Array = []
var _talks: Array = []           # 場面の列を持つ台本：場面ごとの、せりふの欄（いまの場面の分だけ開く）


func build(owner_game: Node) -> void:
	game = owner_game
	add_theme_stylebox_override("panel", UI.box(PAPER, Color("d8d2c0"), 1, 3, 22, 18))
	custom_minimum_size.x = WIDTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_right = -18.0
	offset_left = -18.0 - WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	visible = false


# job：依頼の番号（まだ受けていなければ -1）。now：撮影中の「いまの場面」（0〜2、撮影中でなければ -1）
func sync(job: int, now: int) -> void:
	# 配役（見立て）が変わったら書き直す
	var sig := "%d|%s" % [job, str(game.production.cast_sheet()) if job >= 0 else ""]
	if sig != _sig:
		_sig = sig
		_rebuild(job)
	for i in _blocks.size():
		(_blocks[i] as Control).modulate.a = 1.0 if now < 0 or i == now else 0.38
	# 場面の列を持つ台本：せりふは、いまの場面（まだ始めていなければ、最初の場面）の分だけを開く
	for i in _talks.size():
		(_talks[i] as Control).visible = i == maxi(now, 0)


func _rebuild(job: int) -> void:
	for c in _rows.get_children():
		c.queue_free()
	_blocks.clear()
	_talks.clear()
	var head := UI.overline("台本", FADED)
	_rows.add_child(head)
	if job < 0:
		_rows.add_child(_text("まだ白紙。", 20, INK, "bold"))
		_rows.add_child(_text("掲示板で依頼を受けると、ここに台本が書き込まれる。", 14, FADED))
		return
	var info: Dictionary = game.production.JOBS[job]
	var brief: Dictionary = Briefs.brief(job)
	_rows.add_child(_text(str(info["title"]), 20, INK, "display"))
	_rows.add_child(_text("依頼主：%s（%s）　／　%s" % [brief["name"], brief["role"], game.production.location_name()], 12, FADED))
	# 場面の列を持つ台本（5場面の完全版）：合図ではなく、ページをめくって進める
	var paging: bool = not (Scripts.beats(job) as Array).is_empty()
	if paging:
		_rows.add_child(_text("台本はこの1冊だけ。読める人が監督。せりふを声に出し、1 で次の場面へ、2 で今の場面をもう一度。", 12, FADED))
	else:
		_rows.add_child(_text("台本はこの1冊だけ。持っている人が監督。せりふを声に出し、合図 1・2・3 を出そう。", 12, FADED))
	# 配役：何を何の役に見立てたか。決めるのは制作班（物を見て Y）
	var sheet: Dictionary = game.production.cast_sheet()
	var story: String = game.production.story()
	var cast_box := VBoxContainer.new()
	cast_box.add_theme_constant_override("separation", 0)
	cast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(cast_box)
	cast_box.add_child(_text("配役　（物を見て Y で決める）", 13, INK, "bold"))
	for row: Dictionary in sheet["rows"]:
		var title: String = Cast.role_title(str(row["role"]), story)
		if int(row["grade"]) >= 0:
			cast_box.add_child(_text("　%s … %s　%s %s" % [title, row["items"], Cast.stars(int(row["grade"])), row["grade_name"]], 13, INK))
		else:
			cast_box.add_child(_text("　%s … %s" % [title, "無くても撮れる" if row["optional"] else "まだ決めていない"], 13, FADED))
	for combo: Dictionary in sheet["combos"]:
		cast_box.add_child(_text("　コンボの見込み %s　+%d" % [combo["name"], int(combo["coins"])], 13, Color("2f6b3a"), "bold"))
	var liked: Dictionary = sheet["liked"]
	if not (liked["attrs"] as Array).is_empty():
		var n: int = liked["roles"]
		cast_box.add_child(_text("　依頼主の好み %s　%s" % [Cast.chips(liked["attrs"]), "%d役 +%d" % [n, int(liked["coins"])] if n > 0 else "役に使うと、役ごとに +%d" % Cast.LIKE_COINS],
			13, Color("2f6b3a") if n > 0 else FADED, "bold" if n > 0 else "body"))
	var names: Dictionary = game.production.cast_names()
	var scenes: Array = Scripts.of(job)["scenes"]
	for i in scenes.size():
		var scene: Dictionary = scenes[i]
		if paging:
			_paged_block(i, scene, info, names)
			continue
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(block)
		_blocks.append(block)
		var rule := ColorRect.new()
		rule.color = Color(INK, 0.25)
		rule.custom_minimum_size.y = 1
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(rule)
		block.add_child(_text("第%d場　%s　　合図 %d" % [i + 1, str(info["scenes"][i]).get_slice("（", 0), i + 1], 15, INK, "bold"))
		block.add_child(_text(str(scene["dir"]), 13, FADED))
		for line: Array in scene["lines"]:
			var who: String = line[0]
			if str(line[1]) == "":
				block.add_child(_text("　　" + who, 13, FADED, "bold"))
			else:
				block.add_child(_text("%s「%s」" % [who, Scripts.fill(str(line[1]), names)], 14, INK))
		block.add_child(_text("撮り方：" + str(scene["memo"]), 12, Color("8e2d22"), "bold"))


# 場面の列を持つ台本の1場面：小さな絵コンテ（現場で、モニターの絵と見比べる）・ト書き・撮り方。その下に、せりふ
func _paged_block(i: int, scene: Dictionary, info: Dictionary, names: Dictionary) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(block)
	_blocks.append(block)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.25)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(rule)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(row)
	var pic := TextureRect.new()
	pic.texture = Storyboard.texture(str(info.get("board", info["script"])), i)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(128, 72)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 1)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(side)
	var narrow: float = WIDTH - 44.0 - 138.0
	side.add_child(_text("第%d場　%s" % [i + 1, str(info["scenes"][i]).get_slice("（", 0)], 14, INK, "bold", narrow))
	side.add_child(_text(str(scene["dir"]), 12, FADED, "body", narrow))
	side.add_child(_text("撮り方：" + str(scene["memo"]), 12, Color("8e2d22"), "bold", narrow))
	var talk := VBoxContainer.new()
	talk.add_theme_constant_override("separation", 1)
	talk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(talk)
	_talks.append(talk)
	for line: Array in scene["lines"]:
		var who: String = line[0]
		if str(line[1]) == "":
			talk.add_child(_text("　　" + who, 13, FADED, "bold"))
		else:
			talk.add_child(_text("%s「%s」" % [who, Scripts.fill(str(line[1]), names)], 14, INK))


func _text(words: String, px: int, color: Color, kind: String = "body", width: float = WIDTH - 44.0) -> Label:
	var l := UI.label(words, px, color, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
