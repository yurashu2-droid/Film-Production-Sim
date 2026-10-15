extends Node
## 試写会：「このテイクを納品」（画面のボタン・Enter）を押すと、選んだテイクを依頼主と一緒に見てから納品する。
##   ・流すのは、いつもの見返し（main.gd の h_replay）。全員の画面に、撮影カメラの映像が大きく出る
##   ・依頼主（production_briefs.gd の顔と名前）が、画面の左下で一緒に見ている。
##     場面が撮れた瞬間と、爆発で反応する（場面が撮れた時刻は、本番中にホストがテイクごとに測っておく）
##   ・見終わる（または Enter・Esc でとばす）と納品になり、依頼主がギャラの中身を1行ずつ読み上げる。
##     読み上げが終わると、いつもの精算の画面（production_hud.gd）が見える
##   ・見返し（R）と、8コマ保存（P）は、今までどおり。試写会にはならない
## 決めるのはホスト（流す・反応・納品）。読み上げは、届いた精算の中身から、各自の画面で組む。
## 自動確認などが直接呼ぶ納品（game.h_deliver）は、今までどおり、すぐ納品になる（試写会は、画面から頼んだときだけ）
const UI := preload("res://scripts/ui/ui_theme.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const LINE_SEC := 0.7        # 読み上げの1行の間（秒）
const VOICE_SEC := 1.6       # 依頼主のせりふの行の間
const HOLD_SEC := 2.2        # 読み上げ終わってから、精算の画面へ移るまで
const BUBBLE_SEC := 2.8      # 反応のふきだしを出しておく秒数
const START := ["さあ、見せてもらおうか", "楽しみにしてたよ", "どれどれ……", "期待してるよ"]
const HAPPY := ["おおっ、%s！", "いいねえ、%s！", "これこれ、%s！", "%s、きたきた！", "ほう……%s、やるね"]
const WOW := ["うわっ！", "ひゃっ！", "おおお……！", "近い近い！"]

var game: Node
var screening := -1          # いま流しているテイク（全員の画面。-1＝流していない）
var last_line := ""          # いちばん新しい、依頼主のひとこと（確認用）
var tally: Array = []        # 読み上げる行 [文, コイン（無ければ null）, 依頼主のせりふか]
# ホストだけ
var _times := {}             # テイクの番号 → 場面ごとの撮れた時刻（撮れていなければ -1）
var _watch: Array = []       # 本番中に測っている時刻
var _cues: Array = []        # 試写会で出す反応 [時刻, せりふ, 気分]（時刻順）
var _cue_i := 0
var _wow_i := 0
# 各自の画面
var _await_tally := false
var _tally_i := 0
var _tally_t := 0.0
var _tally_done := false
var _bubble_t := 0.0
var _layer: CanvasLayer
var _film: TextureRect
var _shade: ColorRect
var _title: Label
var _hint: Label
var _card: Control
var _face: TextureRect
var _name: Label
var _bubble: PanelContainer
var _bubble_text: Label
var _sheet: PanelContainer
var _rows: VBoxContainer
var _total: Label
var _tween: Tween
var _flash: ColorRect
var _chapter: Label
var _card_box: Control         # 黒地の札（始まりの題名・終わりの「終」）
var _card_small: Label
var _card_big: Label
var _card_ring: PanelContainer
var _card_t := 0.0             # 札を出しておく残り（秒）
var _end_t := 0.0              # 「終」を見せ終わるまで、読み上げを待つ
var _scene_seen := -2          # 見出しを出した場面
var _closing_line: Array = []  # 「終」のあとに言う、締めのひとこと [文, 気分]
const CARD_SEC := 1.8          # 始まりの題名を出しておく秒数
const END_SEC := 1.6           # 「終」を出しておく秒数


# 黒地の札：始まりは「格安アクション映画制作班 作品／題名」、終わりは「終」
func _build_card(root: Control) -> void:
	_card_box = ColorRect.new()
	(_card_box as ColorRect).color = Color.BLACK
	_card_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_box.mouse_filter = Control.MOUSE_FILTER_STOP      # 札の下の、確認の画面のボタンを押させない
	_card_box.visible = false
	root.add_child(_card_box)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(column)
	_card_small = UI.label("", 20, UI.MUTED, "body")
	_card_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_card_small)
	# 大きい字。「終」のときだけ、昔の映画の終わりの札のように丸で囲む
	_card_ring = PanelContainer.new()
	_card_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_card_ring)
	_card_big = UI.label("", 52, UI.PAPER, "display")
	_card_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_ring.add_child(_card_big)


# 「終」を囲む丸（UI の箱の決まり＝角の丸みは小さく、には従わない。映画の札なので）
static func _ring_style() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = UI.PAPER
	ring.set_border_width_all(4)
	ring.set_corner_radius_all(80)
	ring.set_content_margin_all(8)
	ring.anti_aliasing = true
	return ring


func _show_card(small: String, big: String, sec: float) -> void:
	_card_small.text = small
	_card_small.visible = small != ""
	_card_big.text = big
	var ring: bool = big == "終"
	_card_big.add_theme_font_size_override("font_size", 64 if ring else 52)
	_card_big.custom_minimum_size = Vector2(118, 118) if ring else Vector2.ZERO
	_card_ring.add_theme_stylebox_override("panel", _ring_style() if ring else StyleBoxEmpty.new())
	_card_box.visible = true
	_card_box.modulate.a = 1.0
	_card_t = sec


func setup() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 7
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	# 映画館：まわりは真っ黒にして、撮影カメラの映像だけを幕の間に映す（いつもの画面の部品は見せない）
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	_film = TextureRect.new()
	_film.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film.offset_top = 64
	_film.offset_bottom = -52
	_film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_film.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_film)
	# 四隅を少し暗く（映写した画面らしく。真ん中は、そのまま）
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	falloff.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)])
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = falloff
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.fill_from = Vector2(0.5, 0.5)
	vignette_tex.fill_to = Vector2(1.0, 1.0)
	var vignette := TextureRect.new()
	vignette.texture = vignette_tex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.offset_top = 64
	vignette.offset_bottom = -52
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)
	# つなぎ目の白い光（カット割りの依頼で、場面が切り替わる所）
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	# 場面の見出し（左上。「第1場　城の前の二人」）
	_chapter = UI.label("", 24, UI.PAPER, "bold", true)
	_chapter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_chapter.position = Vector2(34, 84)
	_chapter.modulate.a = 0.0
	root.add_child(_chapter)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0, 0, 0, 0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)
	# 上下の黒い帯（映画館の幕）。上に題、下に「とばす」
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.92)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_title = UI.label("", 26, UI.PAPER, "display")
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_title)
	var bottom := ColorRect.new()
	bottom.color = Color(0, 0, 0, 0.92)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -52
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_hint = UI.label("", 18, UI.MUTED)
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.offset_right = -24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	# 依頼主（左下）。顔は手で動かす（はねる・ふるえる）ので、入れ物に入れない
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.offset_left = 26
	_card.offset_top = -262
	_card.offset_right = 206
	_card.offset_bottom = -62
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UI.box(UI.BOARD, UI.TAPE, 3, 10))
	frame.position = Vector2(8, 4)
	frame.size = Vector2(164, 164)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(frame)
	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.position = Vector2(14, 10)
	_face.size = Vector2(152, 152)
	_face.pivot_offset = Vector2(76, 152)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_face)
	_name = UI.label("", 18, UI.PAPER, "bold", true)
	_name.position = Vector2(0, 172)
	_name.size = Vector2(180, 26)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_name)
	# ふきだし（顔の右）
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UI.box(UI.PAPER, UI.INK, 3, 16, 20, 12, Vector2(0, 4)))
	_bubble.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bubble.offset_left = 214
	_bubble.offset_right = 214
	_bubble.offset_top = -150
	_bubble.offset_bottom = -150
	_bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	root.add_child(_bubble)
	_bubble_text = UI.label("", 28, UI.INK, "bold")
	_bubble.add_child(_bubble_text)
	# 読み上げ（真ん中）
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UI.box(Color(UI.BOARD, 0.96), UI.LINE, 1, 8, 30, 22))
	_sheet.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sheet.offset_left = -380
	_sheet.offset_right = 380
	_sheet.offset_top = 92
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	root.add_child(_sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(column)
	var head := UI.label("依頼主の感想とギャラ", 24, UI.TAPE, "display")
	column.add_child(head)
	_build_card(root)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rows)
	_total = UI.label("", 34, UI.GREEN_LIGHT, "display")
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_total)


# ---- 本番中：場面が撮れた時刻を測る（ホスト） ----

func hook_take_start() -> void:
	_watch = []


func hook_take_cut() -> void:
	if not (game.takes as Array).is_empty():
		_times[game.takes.size() - 1] = _watch.duplicate()


func hook_new_job() -> void:
	_times.clear()


func hook_return_office() -> void:
	_times.clear()


func _physics_process(_delta: float) -> void:
	if not Net.is_host() or game.production == null:
		return
	if game.state == game.S.TAKE:
		var now: Array = game.judge.passed()
		if _watch.size() != now.size():
			_watch.resize(now.size())
			_watch.fill(-1.0)
		for i in now.size():
			if bool(now[i]) and float(_watch[i]) < 0.0:
				_watch[i] = float(game.take_t)
	elif screening >= 0 and game.state == game.S.REPLAY:
		while _cue_i < _cues.size() and float(_cues[_cue_i][0]) <= float(game.replay_t):
			game.host_ev("premiere_react", [_cues[_cue_i][1], _cues[_cue_i][2]])
			_cue_i += 1


# ---- 試写会を始める・終える（ホスト） ----

# 画面から納品を頼まれた（production_main.gd の h_request_deliver）。流せるテイクなら、試写会を始めて true
func hook_deliver(index: int) -> bool:
	if screening >= 0:
		return true
	if game.production == null or index < 0 or index >= (game._take_data as Array).size():
		return false
	if (game._take_data[index]["frames"] as Array).size() < 2:
		return false
	_cues = _plan(index)
	_cue_i = 0
	game.host_ev("premiere_on", [index])
	_roll.call_deferred(index)
	return true


# 題名の札（CARD_SEC 秒）のあとで、映画（見返し）を流し始める。流せなければ、そのまま納品する
func _roll(index: int) -> void:
	await get_tree().create_timer(CARD_SEC).timeout
	if screening != index or game.state != game.S.RESULT:
		return
	game.h_replay(index)
	if game.state != game.S.REPLAY:
		game.host_ev("premiere_off", [_closing(index)])
		_finish.call_deferred(index)


# 依頼主の反応の予定：始まりのひとこと、場面が撮れた時刻ごとのひとこと
func _plan(index: int) -> Array:
	var job: int = int(game.production.chosen_job)
	var plan: Array = [[0.0, START[job % START.size()], "neutral"]]      # 札が明けたら、すぐ
	var titles: Array = game.scene_titles()
	var times: Array = _times.get(index, [])
	for i in times.size():
		if float(times[i]) >= 0.0:
			var line: String = HAPPY[(i + job) % HAPPY.size()] % _short(str(titles[i]) if i < titles.size() else "")
			plan.append([maxf(float(times[i]), 0.8), line, "happy"])
	plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return plan


# 見返しが終わった（最後まで流れた・とばした）。試写会なら、締めのひとことを出して納品する
func hook_playback(on: bool) -> void:
	if on or screening < 0:
		return
	var index := screening
	game.host_ev("premiere_off", [_closing(index)])
	_finish.call_deferred(index)


func _finish(index: int) -> void:
	if game.state == game.S.RESULT:
		game.h_deliver(index)


func _closing(index: int) -> String:
	var passed: Array = game.takes[index]["passed"] if index < (game.takes as Array).size() else []
	var titles: Array = game.scene_titles()
	if passed.is_empty() or not true in passed:
		return "えーと……これは、何の映画？"
	for i in passed.size():
		if not bool(passed[i]):
			return "……あれ、%sは？" % _short(str(titles[i]) if i < titles.size() else "")
	return "ブラボー！ 頼んでよかった！"


static func _short(title: String) -> String:
	return title.split("（")[0]


# ---- 全員の画面 ----

func hook_events() -> Array:
	return ["premiere_on", "premiere_react", "premiere_off"]


func hook_event(n: String, a: Array) -> void:
	match n:
		"premiere_on":
			screening = int(a[0])
			_open()
		"premiere_react":
			_say(str(a[0]), str(a[1]))
		"premiere_off":
			screening = -1
			_closing_line = [str(a[0]), "sad" if str(a[0]).begins_with("…") or str(a[0]).begins_with("えーと") else "happy"]
			_show_card("", "終", END_SEC)
			_end_t = END_SEC
			_await_tally = true
			_hint.text = "精算を待っています…"


# 試写会の間の爆発には、依頼主がびっくりする（見返しでも、爆発の知らせは届く）
# 見ごたえのある爆発（scripts/features/spectacle.gd の測り方。見返しの撮影カメラで、各自の画面で測る）には、もっと驚く
func hook_core_event(n: String, a: Array) -> void:
	if n != "burst" or screening < 0:
		return
	var line: String = WOW[_wow_i % WOW.size()]
	_wow_i += 1
	var spectacle: Node = game.hooks.feature("spectacle")
	if spectacle != null and a.size() >= 2:
		var seen: Dictionary = spectacle.measure(a[0], float(a[1]))
		if float(seen["size"]) >= spectacle.FILL:
			line = "画面いっぱいの爆発！ 迫力あるねえ！"
		elif bool(seen["close"]):
			line = "近い近い！ 役者さん、大丈夫！？"
	_say(line, "wow")


func _open() -> void:
	var flow: Node = game.production
	var brief: Dictionary = Briefs.brief(int(flow.chosen_job))
	var path := "res://assets/ui/clients/%s.png" % str(brief.get("cast", ""))
	_face.texture = load(path) if ResourceLoader.exists(path) else null
	_name.text = str(brief.get("name", "依頼主"))
	_title.text = "試写会　『%s』" % str(game.film_title())
	_hint.text = "Enter・Esc：とばして結果へ"
	_shade.color = Color(0, 0, 0, 0)
	_sheet.visible = false
	_bubble.visible = false
	_card.visible = true
	_card.modulate.a = 1.0
	_layer.visible = true
	_await_tally = false
	_tally_done = false
	tally.clear()
	_wow_i = 0
	_scene_seen = -2
	_end_t = 0.0
	_closing_line = []
	_chapter.modulate.a = 0.0
	_show_card("格安アクション映画制作班　作品", "『%s』" % str(game.film_title()), CARD_SEC)


# 依頼主のひとこと。気分で、顔の動きと音を変える（happy はねる / wow びくっ / sad かしげる / neutral うなずく）
func _say(text: String, mood: String) -> void:
	last_line = text
	_bubble_text.text = text
	_bubble.visible = _layer.visible
	_bubble_t = BUBBLE_SEC
	if _tween != null:
		_tween.kill()
	_face.position.y = 10.0
	_face.scale = Vector2.ONE
	_face.rotation = 0.0
	_tween = create_tween()
	match mood:
		"happy":
			for i in 2:
				_tween.tween_property(_face, "position:y", -14.0, 0.12).set_ease(Tween.EASE_OUT)
				_tween.tween_property(_face, "position:y", 10.0, 0.14).set_ease(Tween.EASE_IN)
			Sfx.play("ui_ok")
		"wow":
			_tween.tween_property(_face, "scale", Vector2(1.18, 1.18), 0.07)
			_tween.tween_property(_face, "rotation", 0.08, 0.05)
			_tween.tween_property(_face, "rotation", -0.08, 0.07)
			_tween.tween_property(_face, "rotation", 0.0, 0.05)
			_tween.tween_property(_face, "scale", Vector2.ONE, 0.2)
		"sad":
			_tween.tween_property(_face, "rotation", -0.18, 0.4).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(0.6)
			_tween.tween_property(_face, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			Sfx.play("ui_back")
		_:
			_tween.tween_property(_face, "position:y", 16.0, 0.15)
			_tween.tween_property(_face, "position:y", 10.0, 0.15)


func _process(delta: float) -> void:
	if _layer == null or not _layer.visible:
		return
	# 次の依頼・撮り直しなどへ進んだら、片づける
	if game.state not in [game.S.REPLAY, game.S.RESULT, game.S.DELIVERED]:
		_close()
		return
	# 映すのは、いま選ばれている撮影カメラ（見返しの途中で切り替わることがある）
	var camera: Node = game.program_camera()
	if camera != null and camera.get("view") is SubViewport:
		_film.texture = (camera.view as SubViewport).get_texture()
	if _card_t > 0.0:
		_card_t -= delta
		_card_box.modulate.a = clampf(_card_t / 0.35, 0.0, 1.0)
		if _card_t <= 0.0:
			_card_box.visible = false
	_sync_chapter()
	if _end_t > 0.0:
		_end_t -= delta
		if _end_t <= 0.0 and not _closing_line.is_empty():
			_say(str(_closing_line[0]), str(_closing_line[1]))
			_closing_line = []
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and not _sheet.visible:
			_bubble.visible = false
	if _await_tally and _end_t <= 0.0 and game.state == game.S.DELIVERED and int(game.production.phase) == 5:
		_await_tally = false
		_start_tally()
	if _sheet.visible and not _tally_done:
		_tally_t -= delta
		if _tally_t <= 0.0:
			_next_row()
	elif _tally_done:
		_tally_t -= delta
		if _tally_t <= 0.0:
			_close()


# 読み上げる行：基本・場面ごと・全部そろった・精算の一言（追加注文・NG日誌・コンボ・依頼主のせりふ）・浮かせた制作費・家賃
func build_tally() -> Array:
	var flow: Node = game.production
	var out: Array = []
	var takes: Array = game.takes
	var passed: Array = takes[clampi(int(game.selected), 0, takes.size() - 1)]["passed"] if not takes.is_empty() else []
	var titles: Array = game.scene_titles()
	out.append(["納品の基本", 150, false])
	for i in passed.size():
		var title := _short(str(titles[i]) if i < titles.size() else "場面%d" % (i + 1))
		out.append(["%s　%s" % [title, "撮れた" if bool(passed[i]) else "撮れていない"], 250 if bool(passed[i]) else 0, false])
	if not passed.is_empty() and not false in passed:
		out.append(["全部の場面がそろった", int(flow.job().get("fee_all", 300)), false])
	for line: String in flow.last_flubs:
		if line.begins_with("依頼主『"):
			out.append([line.trim_prefix("依頼主『").trim_suffix("』"), null, true])
		else:
			out.append([line, null, false])
	if int(flow.saved) > 0:
		out.append(["浮かせた制作費（会社の儲け）", int(flow.saved), false])
	if int(flow.rent_paid) > 0:
		out.append(["家賃", -int(flow.rent_paid), false])
	if bool(flow.bankrupt):
		out.append(["家賃 %d コインが払えない……" % int(flow.rent_amount()), null, false])
	return out


func _start_tally() -> void:
	tally = build_tally()
	for row: Node in _rows.get_children():
		row.queue_free()
	_tally_i = 0
	_tally_t = 0.4
	_tally_done = false
	_total.text = ""
	_shade.color = Color(0, 0, 0, 0.72)
	_sheet.visible = true
	_hint.text = "Enter：読み上げをとばす"


func _next_row() -> void:
	if _tally_i >= tally.size():
		var flow: Node = game.production
		_total.text = "ギャラ +%d　＋　浮かせた制作費 +%d" % [int(flow.last_payment), int(flow.saved)]
		Sfx.play("success_fanfare" if int(flow.last_payment) > 150 else "ui_ok")
		_tally_done = true
		_tally_t = HOLD_SEC
		_hint.text = "Enter：精算の画面へ"
		return
	var row: Array = tally[_tally_i]
	_tally_i += 1
	_rows.add_child(_row(row))
	if bool(row[2]):
		_say(str(row[0]), "happy")
		_tally_t = VOICE_SEC
	else:
		if row[1] != null and int(row[1]) > 0:
			Sfx.play("ui_select")
		_tally_t = LINE_SEC


func _row(row: Array) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var voice: bool = bool(row[2])
	var text := UI.label("『%s』" % row[0] if voice else str(row[0]), 20, UI.TAPE_HI if voice else UI.PAPER, "bold" if voice else "body")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(text)
	if row[1] != null:
		var coins: int = int(row[1])
		var amount := UI.label(("+%d" % coins) if coins >= 0 else ("−%d" % -coins), 22, UI.GREEN_LIGHT if coins > 0 else (UI.STAMP_RED if coins < 0 else UI.MUTED), "display")
		line.add_child(amount)
	UI.pop_on_show(line)
	return line


# 読み上げを最後まで出す（Enter）。もう出し終わっていれば、精算の画面へ
func finish_tally() -> void:
	if not _sheet.visible:
		# 「終」の札の最中：札をとばして、精算が届いていれば読み上げへ
		if not _await_tally or game.state != game.S.DELIVERED or int(game.production.phase) != 5:
			return
		_card_box.visible = false
		_card_t = 0.0
		_end_t = 0.0
		_await_tally = false
		_start_tally()
	if _tally_done:
		_close()
		return
	while not _tally_done:
		_next_row()


# 場面の見出し（場面の列を持つ依頼。見返しで場面が進むたび）。カット割りの依頼では、つなぎ目が白く光る
func _sync_chapter() -> void:
	var beats: Node = game.get("beats")
	if screening < 0 or _card_t > 0.0 or beats == null or not beats.active():
		return
	var now: int = int(beats.scene)
	if now < 0 or now == _scene_seen:
		return
	var cut: bool = _scene_seen >= 0 and beats.cut_mode()
	_scene_seen = now
	var titles: Array = game.scene_titles()
	_chapter.text = "第%d場　%s" % [now + 1, _short(str(titles[now]) if now < titles.size() else "")]
	var fade := create_tween()
	fade.tween_property(_chapter, "modulate:a", 1.0, 0.25)
	fade.tween_interval(2.2)
	fade.tween_property(_chapter, "modulate:a", 0.0, 0.5)
	if cut:
		_flash.color.a = 0.8
		create_tween().tween_property(_flash, "color:a", 0.0, 0.3)


func _close() -> void:
	_layer.visible = false
	_card_box.visible = false
	_card_t = 0.0
	_end_t = 0.0
	_sheet.visible = false
	_bubble.visible = false
	_await_tally = false
	_tally_done = false
	screening = -1


# 読み上げの間の Enter は、精算の画面の「帰社」へ回さず、読み上げを先へ進める
func hook_input(event: InputEvent) -> bool:
	if _layer == null or not _layer.visible:
		return false
	if screening >= 0 and game.state == game.S.RESULT:
		return event is InputEventKey or event is InputEventMouseButton     # 題名の札の間
	if not (_sheet.visible or _await_tally):
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		finish_tally()
		return true
	return false
