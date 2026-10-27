extends Node
## 試写会：「このテイクを納品」（画面のボタン・Enter）を押すと、選んだテイクを依頼主と一緒に見てから納品する。
##   ・流すのは、いつもの見返し（main.gd の h_replay）。映すのは、事務所の奥の壁に下ろす試写用のスクリーン。
##     全員、事務所に集まり、カメラはスクリーンの方を向いたまま。見ている間も、プレイヤーは歩き回れる（main.gd の audience）。
##     撮影中の班の動きは、プレイヤーの体ではなく人形（Double）に再現する（main.gd の replay_doubles）
##   ・依頼主（production_briefs.gd の顔と名前）が、画面の左下で一緒に見ている。
##     場面が撮れた瞬間と、爆発で反応する（場面が撮れた時刻は、本番中にホストがテイクごとに測っておく）
##   ・見ている間は点数を出さない（依頼主の顔と、ひとことから、出来を予想する）
##   ・見終わる（または Enter・Esc でとばす）と納品になる。画面の真ん中に、いま見たフィルムが右から左へ流れ、
##     コマ（試写会の間に写した撮影カメラの絵。3秒ごとと、見せ場ごと）が真ん中を通るたびに、その下に良かった点・だめな点と
##     コインが出る。場面の行はその場面が撮れたコマ、爆発の行は爆発のコマ、ほかは最後の「終」のコマ。
##     最後に合計が出て、そのあと、いつもの精算の画面（production_hud.gd）が見える
##   ・見返し（R）と、8コマ保存（P）は、今までどおり。試写会にはならない
##   ・最初の一本（会社の紹介動画）は、試写会ではなく「ネットに上げる」：依頼主の顔の代わりに再生数が伸び、反応はコメントとして出る
## 決めるのはホスト（流す・反応・納品）。読み上げは、届いた精算の中身から、各自の画面で組む。
## 自動確認などが直接呼ぶ納品（game.h_deliver）は、今までどおり、すぐ納品になる（試写会は、画面から頼んだときだけ）
const UI := preload("res://scripts/ui/ui_theme.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const CompanyLogo := preload("res://scripts/ui/company_logo.gd")   # 「{会社}」＝事務所に掛けた看板の絵（features/company_sign.gd）
const LINE_SEC := 0.7        # 読み上げの1行の間（秒）
const VOICE_SEC := 1.6       # 依頼主のせりふの行の間
const HOLD_SEC := 2.2        # 読み上げ終わってから、精算の画面へ移るまで
const BUBBLE_SEC := 2.8      # 反応のふきだしを出しておく秒数
const START := ["さあ、見せてもらおうか", "楽しみにしてたよ", "どれどれ……", "期待してるよ"]
const HAPPY := ["おおっ、%s！", "いいねえ、%s！", "これこれ、%s！", "%s、きたきた！", "ほう……%s、やるね"]
const WOW := ["うわっ！", "ひゃっ！", "おおお……！", "近い近い！"]
# 班の誰かが映り込んだ時（%s＝その人の名前）
const CAMEO_LINES := ["……いま、%sが映ってませんでした？", "あれ？ %s、そこで何してるの？", "ちょっと、%sが見切れてますよ"]
# ネットに上げたとき（最初の一本）の、見始めのコメントと、場面が撮れた時刻のコメント
const NET_START := ["新着動画だ", "サムネで来ました", "なんの会社？"]
const NET_HAPPY := ["%s、草", "%s、じわる", "%sで笑った", "%s、好き", "%s、ガチじゃん"]
# 撮れた場面の数 → 再生数（ネットに上げたとき。全員の画面で同じ計算）
const NET_VIEWS := [37, 480, 1520, 4890, 12800]

var game: Node
var screening := -1          # いま流しているテイク（全員の画面。-1＝流していない）
var last_line := ""          # いちばん新しい、依頼主のひとこと（確認用）
var tally: Array = []        # 読み上げる行 [文, コイン（無ければ null）, 依頼主のせりふか]
# ホストだけ
var _times := {}             # テイクの番号 → 場面ごとの撮れた時刻（撮れていなければ -1）
var _watch: Array = []       # 本番中に測っている時刻
var _cue_watch: Array = []   # 本番中に出た合図 [時刻, 場面]（3場面の依頼）
var _cue_times := {}         # テイクの番号 → _cue_watch
var _cameo_times := {}       # テイクの番号 → 映り込んだ人と時刻 [[時刻, 名前], ...]（production_notes.gd の cameo_at。0.5秒以上映った人だけ）
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
var _sheet: Control
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
var _sheet_head: Label         # 読み上げの見出し（ネットに上げたときは、コメントと広告収入）
var _views: Label              # ネットに上げたときの再生数（依頼主の顔の代わり）
var views_now := 0.0           # いま見せている再生数（確認用）
var _views_goal := 0
const CARD_SEC := 1.8          # 始まりの題名を出しておく秒数
const AUDIENCE_LAYER := 1 << 15                # 試写会を見ている人の見た目（撮影カメラには映さない。film_camera.gd）
const SCREEN_W := 5.2                           # 試写用スクリーン（16:9）
const SCREEN_H := 2.925
const SCREEN_TOP := Vector3(72.0, 3.75, -7.45)  # スクリーンの上の端の真ん中（事務所の奥の壁の前）
const VIEW_AT := Vector3(72.0, 2.6, -1.15)     # 試写会の固定カメラ（受付の掲示板の裏＝奥の部屋の側、少し高い所から）
const SEATS := Vector3(70.8, 0.1, -4.3)        # 試写会の立ち位置（ここから東へ並ぶ）
const ROLL_SEC := 0.9                           # スクリーンを下ろす・巻き上げる秒数
const DOUBLE_SEND := 0.1                        # 人形の動きを送る間隔（ホスト → 全員）
const FLOW_SEC := 3.0                           # フィルムの流れ：3秒ごとに1コマ写す
const SHOT_SIZE := Vector2i(320, 180)           # 写したコマの大きさ
const FRAME_SIZE := Vector2(232, 130)           # フィルムの上のコマの大きさ
const FRAME_GAP := 30.0
const STRIP_SPEED := 1100.0                     # フィルムが流れる速さ（画面の点/秒）
const PAUSE_SEC := 0.8                          # 点の付いたコマが真ん中に来たら、少し止まる
const STRIP_LIFT := 80.0                        # フィルムの帯を、画面の真ん中より上へ（下の札が、依頼主のふきだしに重ならないように）
var _shots: Array = []         # 試写会で写したコマ [時刻, ImageTexture か null, 印]（印：""・"scene:i"・"burst"・"react"）
var _next_shot := 0.0
var _want_shots: Array = []    # これから写すコマ [時刻, 印]（見せ場の少しあと）
var _band: Control             # フィルムの帯（送り穴を描く）
var _track: Control            # コマの列（左へ動かす）
var _items: Array = []         # [コマの真ん中の x, 下の札, 行の一覧, 出したか, コマの印]
var _offset := 0.0             # フィルムを送った量
var _offset_end := 0.0
var _pause := 0.0
var _running := 0              # ここまで出た行のコインの合計
var _running_label: Label
var _screen_vp: SubViewport    # スクリーンに映す絵（映画・題・見出し・札）
var _room: Node3D              # スクリーンと固定カメラ（事務所の中）
var _blind: Node3D             # スクリーンの布（上の端を軸に、縦に伸び縮みする）
var _cam: Camera3D
var _prev_cam: Camera3D
var _layers := {}              # 試写会の間に入れ替えた、プレイヤーの見た目の層（あとで元に戻す）
var _hidden_ui: Array = []     # 試写会の間に隠した、いつもの画面の層（あとで元に戻す）
var _doubles := {}             # 人形（プレイヤーの番号 → Double）
var _send_t := 0.0
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
	CompanyLogo.show_in(_card_small, small)
	_card_small.visible = small != ""
	CompanyLogo.show_in(_card_big, big)
	var ring: bool = big == "終"
	_card_big.add_theme_font_size_override("font_size", 64 if ring else 52)
	_card_big.custom_minimum_size = Vector2(118, 118) if ring else Vector2.ZERO
	_card_ring.add_theme_stylebox_override("panel", _ring_style() if ring else StyleBoxEmpty.new())
	_card_box.visible = true
	_card_box.modulate.a = 1.0
	_card_t = sec


func setup() -> void:
	# 各自の画面に重ねる物（依頼主の顔とふきだし・読み上げ・案内）
	_layer = CanvasLayer.new()
	_layer.layer = 7
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0, 0, 0, 0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)
	_hint = UI.label("", 18, UI.PAPER, "body", true)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -520
	_hint.offset_right = -24
	_hint.offset_top = -46
	_hint.offset_bottom = -14
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_hint)
	# スクリーンに映す絵（映画館：まわりは黒、撮影カメラの映像、上の帯に題）
	_screen_vp = SubViewport.new()
	_screen_vp.size = Vector2i(1280, 720)
	_screen_vp.transparent_bg = false
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_screen_vp)
	var cinema := Control.new()
	cinema.size = Vector2(1280, 720)
	cinema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_vp.add_child(cinema)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(backdrop)
	_film = TextureRect.new()
	_film.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film.offset_top = 56
	_film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_film.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(_film)
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
	vignette.offset_top = 56
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(vignette)
	# つなぎ目の白い光（カット割りの依頼で、場面が切り替わる所）
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(_flash)
	# 場面の見出し（左上。「第1場　城の前の二人」）
	_chapter = UI.label("", 30, UI.PAPER, "bold", true)
	_chapter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_chapter.position = Vector2(30, 74)
	_chapter.modulate.a = 0.0
	cinema.add_child(_chapter)
	# 上の黒い帯（映画館の幕）に題
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.92)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 56
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(top)
	_title = UI.label("", 28, UI.PAPER, "display")
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_title)
	_build_card(cinema)
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
	_views = UI.label("", 30, UI.PAPER, "display", true)
	_views.position = Vector2(8, 40)
	_views.size = Vector2(164, 100)
	_views.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_views.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_views.visible = false
	_card.add_child(_views)
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
	_build_strip(root)


# ---- 本番中：場面が撮れた時刻を測る（ホスト） ----

func hook_take_start() -> void:
	_watch = []
	_cue_watch = []


# 3場面の依頼の合図（1・2・3）：本番中の時刻を控えて、試写会で、その時刻に場面の見出しを出す
func hook_cue(n: int) -> void:
	if game.state == game.S.TAKE and not game.take_held() and n >= 1:
		_cue_watch.append([float(game.take_t), n - 1])


func hook_take_cut() -> void:
	if not (game.takes as Array).is_empty():
		_times[game.takes.size() - 1] = _watch.duplicate()
		_cue_times[game.takes.size() - 1] = _cue_watch.duplicate()
		var notes: RefCounted = game.production.notes if game.production != null else null
		var seen: Array = []
		if notes != null:
			for name: String in notes.cameo_at:
				if float(notes.cameos.get(name, 0.0)) >= 0.5:
					seen.append([float(notes.cameo_at[name]), name])
		_cameo_times[game.takes.size() - 1] = seen


func hook_new_job() -> void:
	_times.clear()
	_cue_times.clear()
	_cameo_times.clear()


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
			var cue: Array = _cues[_cue_i]
			game.host_ev("premiere_react", [cue[1], cue[2], str(cue[3]) if cue.size() >= 4 else ""])
			_cue_i += 1
		# 人形の動き（見返しはホストだけが進める）を、みんなの画面へ
		_send_t -= get_physics_process_delta_time()
		if _send_t <= 0.0 and not _doubles.is_empty() and Net.has_peers():
			_send_t = DOUBLE_SEND
			var states := {}
			for id: int in _doubles:
				states[id] = (_doubles[id] as Double).state()
			game.host_ev("premiere_pl", [states])


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
	_gather()
	_roll.call_deferred(index)
	return true


# 班を事務所のスクリーンの前に集める。持っている物は置き、機材の操作もやめる（ホスト）
func _gather() -> void:
	for prop: Node in game.props.values():
		if prop.holder != 0:
			game.host_release(prop)
		if "operator" in prop and prop.operator != 0:
			game._stop_operating(prop)
	game.move_crew(SEATS, 0.0)


# 題名の札（CARD_SEC 秒）のあとで、映画（見返し）を流し始める。流せなければ、そのまま納品する
func _roll(index: int) -> void:
	await get_tree().create_timer(CARD_SEC).timeout
	if screening != index or game.state != game.S.RESULT:
		return
	game.h_replay(index)
	if game.state != game.S.REPLAY:
		game.host_ev("premiere_off", [_closing(index), index])
		_finish.call_deferred(index)
		return
	# 撮影中の班の動きは、人形に再現する（プレイヤーの体は、試写会で歩き回る）
	var first: Dictionary = game._replay["frames"][0][1]["pl"]
	var tags := {}
	for id: int in first:
		var st: Array = first[id]
		tags[id] = str(st[4]) if st.size() >= 5 else ""
	game.host_ev("premiere_doubles", [tags])
	game.replay_doubles = _doubles


# 依頼主の反応の予定：始まりのひとこと、場面が撮れた時刻ごとのひとこと
func _plan(index: int) -> Array:
	var job: int = int(game.production.chosen_job)
	var net := _online()
	var plan: Array = [[0.0, (NET_START if net else START)[job % (NET_START if net else START).size()], "neutral"]]      # 札が明けたら、すぐ
	var titles: Array = game.scene_titles()
	var times: Array = _times.get(index, [])
	for i in times.size():
		if float(times[i]) >= 0.0:
			var says: Array = NET_HAPPY if net else HAPPY
			var line: String = says[(i + job) % says.size()] % _short(str(titles[i]) if i < titles.size() else "")
			plan.append([maxf(float(times[i]), 0.8), line, "happy", "scene:%d" % i])
	# 3場面の依頼：合図を出した時刻に、場面の見出し
	for cue: Array in _cue_times.get(index, []):
		plan.append([maxf(float(cue[0]), 0.05), "", "chapter:%d" % int(cue[1])])
	# 班の誰かが映り込んだ時刻：依頼主が気づく。そのコマを写して、フィルムの採点で「映り込み」の行を付ける
	for seen: Array in _cameo_times.get(index, []):
		plan.append([maxf(float(seen[0]), 0.3), CAMEO_LINES[(job + plan.size()) % CAMEO_LINES.size()] % str(seen[1]), "sad", "cameo:%s" % str(seen[1])])
	# ほかの仕組みが足す反応（手描きの看板が映った など。各仕組みの hook_premiere_cues）
	for target: Object in game.hooks.in_order("hook_premiere_cues"):
		for cue: Array in target.hook_premiere_cues(index):
			plan.append(cue + ["react"] if cue.size() == 3 else cue)
	plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return plan


# 見返しが終わった（最後まで流れた・とばした）。試写会なら、締めのひとことを出して納品する
func hook_playback(on: bool) -> void:
	if on or screening < 0:
		return
	var index := screening
	game.host_ev("premiere_off", [_closing(index), index])
	_finish.call_deferred(index)


func _finish(index: int) -> void:
	if game.state == game.S.RESULT:
		game.h_deliver(index)


func _closing(index: int) -> String:
	var passed: Array = game.takes[index]["passed"] if index < (game.takes as Array).size() else []
	var titles: Array = game.scene_titles()
	if _online():
		# ネットに上げたとき：再生数と、コメントひとつ（失敗しても、笑える形で終わる）
		var views := _coins(views_for(index))
		if passed.is_empty() or not true in passed:
			return "えーと……再生 %s回。「これ、何の会社？」「逆にじわる」" % views
		for i in passed.size():
			if not bool(passed[i]):
				return "……再生 %s回。「%sは？」「でも嫌いじゃない」" % [views, _short(str(titles[i]) if i < titles.size() else "")]
		return "バズった！ 再生 %s回。「爆発の前で動じない社長、何者」" % views
	if passed.is_empty() or not true in passed:
		return "えーと……これは、何の映画？"
	for i in passed.size():
		if not bool(passed[i]):
			return "……あれ、%sは？" % _short(str(titles[i]) if i < titles.size() else "")
	return "ブラボー！ 頼んでよかった！"


# ネットに上げたときの再生数（撮れた場面の数で決まる。全員の画面で同じ）
func views_for(index: int) -> int:
	var passed: Array = game.takes[index]["passed"] if index >= 0 and index < (game.takes as Array).size() else []
	var count := passed.count(true)
	return int(NET_VIEWS[clampi(count, 0, NET_VIEWS.size() - 1)])


static func _coins(n: int) -> String:
	var digits := str(n)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


static func _short(title: String) -> String:
	return title.split("（")[0]


# ---- 全員の画面 ----

func hook_events() -> Array:
	return ["premiere_on", "premiere_react", "premiere_off", "premiere_doubles", "premiere_pl"]


func hook_event(n: String, a: Array) -> void:
	match n:
		"premiere_on":
			screening = int(a[0])
			_open()
		"premiere_react":
			if str(a[1]).begins_with("chapter:"):
				_show_chapter(int(str(a[1]).trim_prefix("chapter:")), false)
			else:
				_say(str(a[0]), str(a[1]))
				if a.size() >= 3 and str(a[2]) != "":
					_want_shots.append([float(game.replay_t) + 0.12, str(a[2])])
		"premiere_doubles":
			_make_doubles(a[0])
		"premiere_pl":
			if not Net.is_host():
				for id: int in a[0]:
					if _doubles.has(id):
						(_doubles[id] as Double).follow(a[0][id])
		"premiere_off":
			_drop_doubles()
			screening = -1
			_closing_line = [str(a[0]), "sad" if str(a[0]).begins_with("…") or str(a[0]).begins_with("えーと") else "happy"]
			# 会社の紹介動画は、ネットの動画の終わり方。ほかは映画の「終」
			if _online():
				_show_card("ご視聴ありがとうございました", "チャンネル登録、よろしく！", END_SEC)
				_views_goal = views_for(int(a[1]) if a.size() >= 2 else 0)
			else:
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
	_want_shots.append([float(game.replay_t) + 0.3, "burst"])


# 会社のCM（最初の一本）は、試写会ではなく、テレビの深夜枠での放送として見せる
func _online() -> bool:
	return game.production != null and bool(game.production.job().get("debut", false))


func _open() -> void:
	var flow: Node = game.production
	var brief: Dictionary = Briefs.brief(int(flow.chosen_job))
	var path := "res://assets/ui/clients/%s.png" % str(brief.get("cast", ""))
	_face.texture = load(path) if ResourceLoader.exists(path) else null
	_name.text = str(brief.get("name", "依頼主"))
	# ネットに上げるとき：顔の代わりに再生数。ひとことは、見た人のコメント
	_face.visible = not _online()
	_views.visible = _online()
	views_now = 0.0
	_views_goal = 0
	_views.text = "0\n回 再生"
	_sheet_head.text = "コメントと広告収入" if _online() else "依頼主の感想とギャラ"
	if _online():
		_name.text = "コメント欄"
	CompanyLogo.show_in(_title, ("動画サイトに投稿　『%s』" if _online() else "試写会　『%s』") % _film_name())
	_hint.text = "Enter・Esc：とばして結果へ"
	_shade.color = Color(0, 0, 0, 0)
	_sheet.visible = false
	_bubble.visible = false
	_card.visible = true
	_card.modulate.a = 1.0
	_layer.visible = true
	_await_tally = false
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_shots = []
	_want_shots = []
	_next_shot = 0.0
	_enter_audience()
	_tally_done = false
	tally.clear()
	_wow_i = 0
	_scene_seen = -2
	_end_t = 0.0
	_closing_line = []
	_chapter.modulate.a = 0.0
	_show_card("アップロード完了" if _online() else CompanyLogo.TOKEN + "　作品", "『%s』" % _film_name(), CARD_SEC)


# 上映する作品の題。会社の紹介動画は、会社の名前（看板の絵）を題に入れる
func _film_name() -> String:
	if _online():
		return CompanyLogo.TOKEN + " 紹介動画"
	return str(game.film_title())


# 依頼主のひとこと。気分で、顔の動きと音を変える（happy はねる / wow びくっ / sad かしげる / neutral うなずく）
func _say(text: String, mood: String) -> void:
	last_line = text
	CompanyLogo.show_in(_bubble_text, text)
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
	if _room == null and game.production != null and game.production.get("_office_root") != null:
		_build_room()
	for d: Node in _doubles.values():
		(d as Double).smooth(delta)
	if _layer == null or not _layer.visible:
		return
	# 見ている間は、マウスで向きを変えない（歩く向きは、スクリーンの方が前）
	if game.audience and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
			if _online():
				views_now = float(_views_goal)
				_views.text = "%s\n回 再生" % _coins(_views_goal)
			if str(_closing_line[0]).begins_with("ブラボー") or str(_closing_line[0]).begins_with("バズった"):
				Sfx.play("applause")          # 全部の場面が撮れた：拍手
			_closing_line = []
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and not _sheet.visible:
			_bubble.visible = false
	if _await_tally and _end_t <= 0.0 and game.state == game.S.DELIVERED and int(game.production.phase) == 5:
		_await_tally = false
		_start_tally()
	if screening >= 0 and game.state == game.S.REPLAY and _online():
		# 見ている間、再生数がじわじわ伸びる（最後の数は、見終わったときに出る）
		var goal := float(views_for(screening))
		views_now = minf(views_now + delta * maxf(goal / 16.0, 1.5), goal * 0.8)
		_views.text = "%s\n回 再生" % _coins(int(views_now))
	if screening >= 0 and game.state == game.S.REPLAY:
		var now: float = float(game.replay_t)
		if now >= _next_shot:
			_shoot(now, "")
			_next_shot += FLOW_SEC
		while not _want_shots.is_empty() and float(_want_shots[0][0]) <= now:
			_shoot(now, str(_want_shots.pop_front()[1]))
	if _sheet.visible and not _tally_done:
		_feed(delta)
	elif _tally_done:
		_tally_t -= delta
		if _tally_t <= 0.0:
			_close()


# 読み上げる行：基本・場面ごと・全部そろった・精算の一言（追加注文・NG日誌・コンボ・依頼主のせりふ）・浮かせた制作費・家賃
# 行は [文, コイン（無ければ null）, 依頼主のせりふか, どのコマに付けるか（"base"・"scene:i"・"all"・"burst"・"sign"・"tail"）]
func build_tally() -> Array:
	var flow: Node = game.production
	var out: Array = []
	var takes: Array = game.takes
	var passed: Array = takes[clampi(int(game.selected), 0, takes.size() - 1)]["passed"] if not takes.is_empty() else []
	var titles: Array = game.scene_titles()
	out.append(["納品の基本", 150 if passed.has(true) else 0, false, "base"])      # 1場面も撮れていなければ出ない（production_flow.gd の take_fee）
	for i in passed.size():
		var title := _short(str(titles[i]) if i < titles.size() else "場面%d" % (i + 1))
		out.append(["%s　%s" % [title, "撮れた" if bool(passed[i]) else "撮れていない"], 250 if bool(passed[i]) else 0, false, "scene:%d" % i if bool(passed[i]) else "tail"])
	if not passed.is_empty() and not false in passed:
		out.append(["全部の場面がそろった", int(flow.job().get("fee_all", 300)), false, "all"])
	for line: String in flow.last_flubs:
		var kind := "tail"
		if line.contains("秒出演"):
			kind = "cameo:%s" % line.get_slice("が", 0)       # 映り込んだ人：その人が映ったコマ（production_notes.gd の observations）
		elif line.contains("爆発") or line.contains("迫力"):
			kind = "burst"
		elif line.contains("名前") or line.contains("看板"):
			kind = "sign"
		if line.begins_with("依頼主『"):
			out.append([line.trim_prefix("依頼主『").trim_suffix("』"), null, true, kind])
		else:
			out.append([line, null, false, kind])
	if int(flow.saved) > 0:
		out.append(["浮かせた制作費（会社の儲け）", int(flow.saved), false, "tail"])
	if int(flow.rent_paid) > 0:
		out.append(["家賃", -int(flow.rent_paid), false, "tail"])
	if bool(flow.bankrupt):
		out.append(["家賃 %d コインが払えない……" % int(flow.rent_amount()), null, false, "tail"])
	return out


# 試写会の間に、撮影カメラの絵を1コマ写しておく（各自の画面）
func _shoot(at: float, mark: String) -> void:
	var tex: ImageTexture = null
	var camera: Node = game.program_camera()
	# 画面なしの実行（自動確認）では、絵は無い（コマの時刻と印だけを控える）
	if camera != null and camera.get("view") is SubViewport and DisplayServer.get_name() != "headless":
		var img: Image = (camera.view as SubViewport).get_texture().get_image()
		if img != null and not img.is_empty():
			img.resize(SHOT_SIZE.x, SHOT_SIZE.y, Image.INTERPOLATE_BILINEAR)
			tex = ImageTexture.create_from_image(img)
	_shots.append([at, tex, mark])


# フィルムの画面（真ん中の帯・真ん中の窓・上の見出しと、ここまでのギャラ・下の合計）
func _build_strip(root: Control) -> void:
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	root.add_child(_sheet)
	var head := UI.label("依頼主の感想とギャラ", 26, UI.TAPE, "display", true)
	_sheet_head = head
	head.set_anchors_preset(Control.PRESET_CENTER)
	head.offset_left = -400
	head.offset_right = 400
	head.offset_top = -205 - STRIP_LIFT
	head.offset_bottom = -170 - STRIP_LIFT
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet.add_child(head)
	_running_label = UI.label("", 26, UI.GREEN_LIGHT, "display", true)
	_running_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_running_label.offset_left = -360
	_running_label.offset_right = -40
	_running_label.offset_top = -205 - STRIP_LIFT
	_running_label.offset_bottom = -170 - STRIP_LIFT
	_running_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sheet.add_child(_running_label)
	_band = Band.new()
	_band.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_band.offset_top = -FRAME_SIZE.y * 0.5 - 34 - STRIP_LIFT
	_band.offset_bottom = FRAME_SIZE.y * 0.5 + 34 - STRIP_LIFT
	_band.anchor_top = 0.5
	_band.anchor_bottom = 0.5
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.clip_contents = false
	_sheet.add_child(_band)
	_track = Control.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_track)
	# 真ん中の窓（ここを通ったコマに、点が出る）
	var gate := Panel.new()
	gate.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), UI.TAPE, 4, 6))
	gate.set_anchors_preset(Control.PRESET_CENTER)
	gate.offset_left = -FRAME_SIZE.x * 0.5 - 10
	gate.offset_right = FRAME_SIZE.x * 0.5 + 10
	gate.offset_top = -FRAME_SIZE.y * 0.5 - 10 - STRIP_LIFT
	gate.offset_bottom = FRAME_SIZE.y * 0.5 + 10 - STRIP_LIFT
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(gate)
	_rows = VBoxContainer.new()          # （使わない。前の読み上げの名残）
	_total = UI.label("", 34, UI.GREEN_LIGHT, "display", true)
	_total.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_total.offset_left = -560
	_total.offset_right = 560
	_total.offset_top = -150
	_total.offset_bottom = -100
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet.add_child(_total)


func _start_tally() -> void:
	tally = build_tally()
	for c: Node in _track.get_children():
		c.queue_free()
	_items = []
	_running = 0
	_running_label.text = ""
	_total.text = ""
	_tally_done = false
	_pause = 0.4
	# コマの並び：頭のコマ（題名）→ 写したコマ（時刻の順）→ 終わりのコマ（「終」）
	var shots: Array = _shots.duplicate()
	shots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var frames: Array = [[null, "head", []]]
	for shot: Array in shots:
		frames.append([shot[1], str(shot[2]), []])
	frames.append([null, "tail", []])
	# 行を、それぞれのコマに付ける（見つからなければ「終」のコマ）
	var used := {}
	for row: Array in tally:
		var kind: String = str(row[3]) if row.size() >= 4 else "tail"
		var at := frames.size() - 1
		match kind:
			"base":
				at = 0
			"all":
				for k in range(frames.size() - 2, 0, -1):
					if str(frames[k][1]).begins_with("scene:"):
						at = k
						break
			"burst", "sign":
				var want := "burst" if kind == "burst" else "react"
				for k in range(1, frames.size() - 1):
					if str(frames[k][1]) == want and not used.has(k):
						at = k
						used[k] = true
						break
			_:
				if kind.begins_with("scene:") or kind.begins_with("cameo:"):
					for k in range(1, frames.size() - 1):
						if str(frames[k][1]) == kind:
							at = k
							break
		(frames[at][2] as Array).append(row)
	var x := 0.0
	for f: Array in frames:
		var cx := x + FRAME_SIZE.x * 0.5
		var pic := _frame(f[0], str(f[1]))
		pic.position = Vector2(x, -FRAME_SIZE.y * 0.5)
		_track.add_child(pic)
		var note: Control = null
		if not (f[2] as Array).is_empty():
			note = _note(f[2])
			_track.add_child(note)
			note.position = Vector2(cx - 160.0, FRAME_SIZE.y * 0.5 + 44.0)
			note.modulate.a = 0.0
			note.reset_size.call_deferred()
		_items.append([cx, note, f[2], false, str(f[1])])
		x += FRAME_SIZE.x + FRAME_GAP
	_offset = -FRAME_SIZE.x * 1.6         # 頭のコマは、右の外から入ってくる
	_offset_end = _items.back()[0] as float          # 最後は「終」のコマが窓に来て止まる
	_shade.color = Color(0, 0, 0, 0.72)
	_sheet.visible = true
	_place_track()
	_hint.text = "Enter：フィルムをとばす"


# 1コマ（写した絵。頭は題名、終わりは「終」の黒いコマ）
func _frame(tex: Variant, mark: String) -> Control:
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UI.box(Color("0b0b0c"), Color(0, 0, 0, 0), 0, 3))
	box.size = FRAME_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex is Texture2D:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.size = FRAME_SIZE
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pic)
	else:
		var words := UI.label("終" if mark == "tail" else str(game.film_title()), 34 if mark == "tail" else 18, UI.PAPER, "display")
		words.size = FRAME_SIZE
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(words)
	return box


# コマの下の札：そのコマで良かった点・だめな点と、コイン
func _note(rows: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.BOARD, 0.94), UI.LINE, 1, 6, 12, 8))
	panel.custom_minimum_size = Vector2(320, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var voice: bool = bool(row[2])
		var text := UI.label("", 17, UI.TAPE_HI if voice else UI.PAPER, "bold" if voice else "body")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(228, 0)      # 折り返しの幅を先に決める（決めないと、1字ずつ折れて縦に伸びる）
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		CompanyLogo.show_in(text, "『%s』" % row[0] if voice else str(row[0]))
		line.add_child(text)
		if row[1] != null:
			var coins: int = int(row[1])
			line.add_child(UI.label(("+%d" % coins) if coins >= 0 else ("−%d" % -coins), 20, UI.GREEN_LIGHT if coins > 0 else (UI.STAMP_RED if coins < 0 else UI.MUTED), "display"))
		column.add_child(line)
	return panel


# フィルムを送る。点の付いたコマが真ん中の窓に来たら、札を出して少し止まる
func _feed(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	_offset += STRIP_SPEED * delta
	for item: Array in _items:
		if not bool(item[3]) and _offset >= float(item[0]):
			_offset = maxf(float(item[0]), _offset - STRIP_SPEED * delta) if not (item[2] as Array).is_empty() else _offset
			_reveal(item)
			if not (item[2] as Array).is_empty():
				_pause = PAUSE_SEC
				break
	_place_track()
	if _offset >= _offset_end:
		_end_strip()


func _reveal(item: Array) -> void:
	item[3] = true
	var rows: Array = item[2]
	if rows.is_empty():
		return
	var note: Control = item[1]
	if note != null:
		create_tween().tween_property(note, "modulate:a", 1.0, 0.18)
		UI.pop_on_show(note)
	var gain := 0
	for row: Array in rows:
		if row[1] != null:
			gain += int(row[1])
			_running += int(row[1])
		if bool(row[2]):
			_say(str(row[0]), "happy")
	if gain > 0:
		Sfx.play("ui_select")
	elif gain < 0:
		Sfx.play("ui_back")


func _place_track() -> void:
	var mid: Vector2 = _sheet.size * 0.5
	_track.position = Vector2(mid.x - _offset, mid.y - STRIP_LIFT)
	if _band != null:
		(_band as Band).shift = _offset


func _end_strip() -> void:
	if _tally_done:
		return
	for item: Array in _items:
		if not bool(item[3]):
			_reveal(item)
	_offset = _offset_end
	_place_track()
	var flow: Node = game.production
	_total.text = "ギャラ +%d　＋　浮かせた制作費 +%d" % [int(flow.last_payment), int(flow.saved)]
	UI.pop_on_show(_total)
	Sfx.play("success_fanfare" if int(flow.last_payment) > 150 else "ui_ok")
	_tally_done = true
	_tally_t = HOLD_SEC + 1.2
	_hint.text = "Enter：精算の画面へ"


# フィルムを最後まで送る（Enter）。もう送り終わっていれば、精算の画面へ
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
	_end_strip()


# フィルムの帯：黒い帯と、上下の送り穴（フィルムといっしょに動く）
class Band extends Control:
	var shift := 0.0:
		set(v):
			shift = v
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a1714"))
		var hole := Vector2(16, 11)
		var step := 34.0
		var start := -fposmod(shift, step)
		var x := start
		while x < size.x:
			for y: float in [8.0, size.y - 8.0 - hole.y]:
				draw_rect(Rect2(Vector2(x, y), hole), Color("d9d2c2"))
			x += step


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
	_show_chapter(now, cut)


# 場面の見出し「第N場　題」を出す。cut＝カット割りのつなぎ目（白く光る）
func _show_chapter(i: int, cut: bool) -> void:
	var titles: Array = game.scene_titles()
	_chapter.text = "第%d場　%s" % [i + 1, _short(str(titles[i]) if i >= 0 and i < titles.size() else "")]
	var fade := create_tween()
	fade.tween_property(_chapter, "modulate:a", 1.0, 0.25)
	fade.tween_interval(2.2)
	fade.tween_property(_chapter, "modulate:a", 0.0, 0.5)
	if cut:
		_flash.color.a = 0.8
		create_tween().tween_property(_flash, "color:a", 0.0, 0.3)


func _close() -> void:
	_leave_audience()
	_drop_doubles()
	if _screen_vp != null:
		_screen_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_layer.visible = false
	_card_box.visible = false
	_card_t = 0.0
	_end_t = 0.0
	_sheet.visible = false
	_bubble.visible = false
	_await_tally = false
	_tally_done = false
	_shade.color = Color(0, 0, 0, 0)
	screening = -1


# 見ている間は、物を持つ・発注するなどはしない（歩き回るだけ）
func hook_f(_me: Node) -> bool:
	return game.audience


func hook_click(_me: Node) -> bool:
	return game.audience


# 読み上げの間の Enter は、精算の画面の「帰社」へ回さず、読み上げを先へ進める
func hook_input(event: InputEvent) -> bool:
	if _layer == null or not _layer.visible:
		return false
	if screening >= 0 and game.state == game.S.RESULT:
		return event is InputEventKey or event is InputEventMouseButton     # 題名の札の間
	if screening >= 0 and game.state == game.S.REPLAY and event is InputEventKey and event.physical_keycode in [KEY_SPACE, KEY_R]:
		return true          # 見ている間の Space（跳ぶ）・R で、試写会が止まらないように
	if not (_sheet.visible or _await_tally):
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		finish_tally()
		return true
	return false


# ---- 事務所の試写用スクリーン（巻き上げ式）と、固定カメラ ----

func _build_room() -> void:
	var office: Node3D = game.production.get("_office_root")
	_room = Node3D.new()
	_room.name = "PremiereScreen"
	office.add_child(_room)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2b2e31")
	dark.roughness = 0.6
	var case := MeshInstance3D.new()
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(SCREEN_W + 0.36, 0.18, 0.18)
	case.mesh = case_mesh
	case.material_override = dark
	case.position = SCREEN_TOP + Vector3(0, 0.1, 0)
	_room.add_child(case)
	for side: float in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pole_mesh := BoxMesh.new()
		pole_mesh.size = Vector3(0.06, SCREEN_TOP.y + 0.2, 0.06)
		pole.mesh = pole_mesh
		pole.material_override = dark
		pole.position = Vector3(SCREEN_TOP.x + side * (SCREEN_W * 0.5 + 0.22), (SCREEN_TOP.y + 0.2) * 0.5, SCREEN_TOP.z)
		_room.add_child(pole)
	# 布：上の端を軸にして、縦に伸ばして下ろす。白い縁の上に、映画の絵
	_blind = Node3D.new()
	_blind.position = SCREEN_TOP
	_blind.scale = Vector3(1, 0.001, 1)
	_room.add_child(_blind)
	var edge := MeshInstance3D.new()
	var edge_mesh := QuadMesh.new()
	edge_mesh.size = Vector2(SCREEN_W + 0.16, SCREEN_H + 0.2)
	edge.mesh = edge_mesh
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("ecebe4")
	cloth.roughness = 0.9
	edge.material_override = cloth
	edge.position = Vector3(0, -SCREEN_H * 0.5 - 0.06, -0.005)
	_blind.add_child(edge)
	var picture := MeshInstance3D.new()
	var picture_mesh := QuadMesh.new()
	picture_mesh.size = Vector2(SCREEN_W, SCREEN_H)
	picture.mesh = picture_mesh
	var shown := StandardMaterial3D.new()
	shown.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shown.albedo_texture = _screen_vp.get_texture()
	picture.material_override = shown
	picture.position = Vector3(0, -SCREEN_H * 0.5 - 0.02, 0)
	_blind.add_child(picture)
	var weight := MeshInstance3D.new()
	var weight_mesh := BoxMesh.new()
	weight_mesh.size = Vector3(SCREEN_W + 0.24, 0.05, 0.05)
	weight.mesh = weight_mesh
	weight.material_override = dark
	weight.position = Vector3(0, -SCREEN_H - 0.17, 0)
	_blind.add_child(weight)
	_cam = Camera3D.new()
	_cam.name = "PremiereCamera"
	_cam.fov = 50.0
	_room.add_child(_cam)
	_cam.global_position = VIEW_AT
	_cam.look_at(SCREEN_TOP + Vector3(0, -SCREEN_H * 0.62, 0))


# スクリーンを下ろす（down）・巻き上げる
func _roll_screen(down: bool) -> void:
	if _blind == null:
		return
	var t := create_tween()
	t.tween_property(_blind, "scale:y", 1.0 if down else 0.001, ROLL_SEC).set_trans(Tween.TRANS_SINE)


# 見ている間：カメラはスクリーンの方に固定。プレイヤーの体は撮影カメラに映さない（家の前で撮った映画にも、見ている人は写らない）
func _enter_audience() -> void:
	if _room == null and game.production != null and game.production.get("_office_root") != null:
		_build_room()
	game.audience = true
	_roll_screen(true)
	_prev_cam = get_viewport().get_camera_3d()
	if _cam != null:
		_cam.make_current()
	_layers.clear()
	for p: Node in game.players.values():
		for v: Node in p.find_children("*", "VisualInstance3D", true, false):
			_layers[v] = (v as VisualInstance3D).layers
			(v as VisualInstance3D).layers = AUDIENCE_LAYER
	# いつもの画面（撮影カメラの映像を全面に出す見返しの画面・確認の札・精算）は、試写会のあいだ隠す
	_hidden_ui.clear()
	for ui: Variant in [game.get("hud"), game.get("production_hud")]:
		if ui is CanvasLayer and (ui as CanvasLayer).visible:
			(ui as CanvasLayer).visible = false
			_hidden_ui.append(ui)


func _leave_audience() -> void:
	if not game.audience:
		return
	game.audience = false
	_roll_screen(false)
	for v: Object in _layers:
		if is_instance_valid(v):
			(v as VisualInstance3D).layers = _layers[v]
	_layers.clear()
	for ui: Object in _hidden_ui:
		if is_instance_valid(ui):
			(ui as CanvasLayer).visible = true
	_hidden_ui.clear()
	if _prev_cam != null and is_instance_valid(_prev_cam) and _prev_cam.is_inside_tree():
		_prev_cam.make_current()
	else:
		var me: Node = game.local_player()
		if me != null and me.get("cam") is Camera3D:
			(me.cam as Camera3D).make_current()


# ---- 人形（撮影中の班の動きを、見返しで再現する） ----

func _make_doubles(tags: Dictionary) -> void:
	for id: int in tags:
		if _doubles.has(id):
			continue
		var d := Double.new()
		d.name = "PremiereDouble%d" % id
		game.add_child(d)
		d.setup(str(tags[id]))
		var body: Node3D = game.players.get(id)
		if body != null:
			d.global_position = body.global_position
		_doubles[id] = d
	if Net.is_host():
		game.replay_doubles = _doubles


func _drop_doubles() -> void:
	game.replay_doubles = {}
	for d: Node in _doubles.values():
		if is_instance_valid(d):
			d.queue_free()
	_doubles = {}


class Double extends Node3D:
	const CastVisual := preload("res://scripts/cast_visual.gd")
	var vis: Node3D
	var _goal_pos := Vector3.ZERO
	var _goal_yaw := 0.0
	var _following := false

	func setup(tag: String) -> void:
		vis = CastVisual.new()
		add_child(vis)
		if tag != "":
			vis.setup(tag)

	# 見返し（ホスト）が、コマごとに呼ぶ（main.gd の _replay_step）
	func apply_state(s: Array) -> void:
		if s.size() >= 5 and str(s[4]) != "" and str(s[4]) != str(vis.tag):
			var keep: float = vis.rotation.y
			vis.queue_free()
			vis = CastVisual.new()
			add_child(vis)
			vis.setup(str(s[4]))
			vis.rotation.y = keep
		global_position = s[0]
		vis.rotation.y = s[1]
		vis.play(str(s[2]), 0.12)
		vis.set_face(str(s[3]))

	func state() -> Array:
		return [global_position, vis.rotation.y, vis.current, vis.face]

	# ほかの人の画面：届いた動きへ、なめらかに寄せる
	func follow(s: Array) -> void:
		if not _following:
			global_position = s[0]
			vis.rotation.y = s[1]
		_following = true
		_goal_pos = s[0]
		_goal_yaw = s[1]
		vis.play(str(s[2]), 0.12)
		vis.set_face(str(s[3]))

	func smooth(delta: float) -> void:
		if not _following:
			return
		var w := clampf(delta * 12.0, 0.0, 1.0)
		global_position = global_position.lerp(_goal_pos, w)
		vis.rotation.y = lerp_angle(vis.rotation.y, _goal_yaw, w)

