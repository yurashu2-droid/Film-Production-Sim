extends CanvasLayer
# 制作班の移動と会計。撮影中の表示は既存の HUD に任せる。
# 見た目の方針は ui_theme.gd の先頭を参照。事務所・積み込み・精算も、撮影中と同じ暗い面で揃える。

const UI := preload("res://scripts/ui/ui_theme.gd")

const Catalog := preload("res://scripts/ui/order_catalog.gd")
const CompanyLogo := preload("res://scripts/ui/company_logo.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Scripts := preload("res://scripts/production_script.gd")
const Briefing := preload("res://scripts/ui/briefing.gd")
const ScriptPage := preload("res://scripts/ui/script_page.gd")
const TalentSlots := preload("res://scripts/ui/talent_slots.gd")
const PosterWall := preload("res://scripts/ui/poster_wall_3d.gd")
const SettingsSheet := preload("res://scripts/ui/settings_sheet.gd")
const BoxOffice := preload("res://scripts/ui/box_office.gd")
const PHASE_NAMES := ["事務所", "機材を借りる", "トラックに積む", "現場へ移動", "撮影現場", "今回の精算"]

var game: Node
var root: Control
var _strip: PanelContainer
var _status: Label            # 段階の名前（事務所・撮影現場など）
var _clock: Label
var _office: PanelContainer
var _office_head: Label
var briefing: Control
var _upgrade: PanelContainer
var _upgrade_rows: VBoxContainer
var _upgrade_wallet: Label
var _upgrade_sig := ""
var script_page: PanelContainer
var _travel_note: Label
var _packing: PanelContainer
var _packing_text: Label
var _depart: Button
var _crew: Label
var _travel: PanelContainer
var _travel_text: Label
var _travel_bar: ProgressBar
var _settled: PanelContainer
var _growth: PanelContainer
var _growth_text: Label
var _settled_pay: Label
var _settled_note_box: Control
var _warning: Label
var _bonus: Label
var _lobby: PanelContainer
var _lobby_status: Label
var _addresses: Array[String] = []
# 見た目の追加分
var _job_cards: Array[Control] = []
var _office_scroll: ScrollContainer
var _wall: Control               # 依頼の掲示板の壁（3D の布とポスター）
var _wall_prev: Button
var _wall_next: Button
var _job_keys: Array = []          # 依頼の札の番号（見えている順に振り直す）
var _packing_rows: VBoxContainer
var _packing_sig := ""
var _packing_aside: Label
var _packing_sub: Label
var _packing_scroll: ScrollContainer
var _pack_cam: Camera3D            # 積み込み確認の、真上からのカメラ
var _pack_prev: Camera3D
var _pack_character: Button        # 積み込み確認の「キャラクターを選ぶ」
var _settled_notes: Label
var _settled_expense: Label
var _settled_wallet: Label
var _settled_bought: Label
var _settled_rent: Label
var _settled_next: Label
var _settled_head: Label
var _envelope: Control             # 精算の給料袋
var _settled_rep: Label            # 精算の、評判の増減といまの格
var _tiles: Array = []            # 精算のボードの数字の札
var _settled_return: Button
var _rent: Label
var _rent_div: Control
var _settled_folder: Button
var _wallet_num: Label
var _wallet_unit: Label
var _people: Label
var _clock_div: Control
var _take_parts: Array = []      # 本番中だけ出す（秒数と合図）
var _take_divider: Control
var _wallet_box: Control
var _wallet_div: Control
var _status_div: Control
var _settings_sheet: Control     # Esc → 設定の紙（ui/settings_sheet.gd）
var _rec_dot: Label               # 上の帯（カメラの枠）の録画ランプ。本番中だけ赤く点滅して REC
var _rec_text: Label
var _last_wallet := -1
var wallet_shown := -1            # 0 以上なら、貯金の数字をこの値で見せる（数字がくるくる動く演出。features/delivery_box.gd）
var _clock_urgent := false
var _lobby_sub: Label
var _backdrop: ColorRect
var talent_slots: PanelContainer      # 段ボール頭「頭の道具箱」の中身（本人の画面の左下）


func build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = UI.make_theme(19)
	game.hud.help.get_child(0).text = """制作会社のあそびかた（Tabで閉じる）

事務所の掲示板で F：依頼を選ぶ → 廃材置き場で使える物を探す → 軽トラへ積む → 現場
事務所の机の「のぞき箱」を見て F：参考スライドをのぞく（役ごとのおすすめの形・依頼主の好み・絵コンテ）。A・D で送り、F でやめる。
のぞけるのは一度に1人。のぞいている間は、まわりが見えない。何が在るかは、集めに行った人に声で聞こう。
廃材置き場に出る物は日替わりで無料。足りない機材は、事務所の机の電話（か、軽トラの東の「機材レンタル」）を見て F で発注する。
発注の画面は、開いた人にだけ開く（一度に1人）。その間も、ほかの人は準備を続けられ、出発までの時計も進む。
借り物は依頼主の制作費から払う。使わなかった制作費とギャラが、会社の貯金になる。
見立て：物を見て（持って）Y で役を決める。城・怪獣・街・爆発の役は、どの物を使ってもいい。
物の名前の横に出る〔属性〕が役に合うほどギャラが増え、同じ属性の物を別々の役に使うとコンボでさらに増える。
依頼主には好みの属性がある（打ち合わせと台本と、のぞき箱の絵に出る）。その属性の物を役に使うと、役ごとに +60。
怪獣映画で爆発役にした物は、合図2で怪獣から撃ち出される（怪獣の技）。
爆弾（発注して借りる）は、空で届く。火薬の袋を持って、爆弾の口の上で F を押している間、粉が出る。出方にはむらがある。外すと床にこぼれる。
ロープ（段ボール置き場。荷台に掛けるのと同じ束）を持って、爆弾の口を見て F でつなぐと導火線になる。束を持って離れるとロープが伸びる。はさみ（段ボール置き場）を持って、ロープを見て F で切る。
ロープの先を見て F で点火。火はロープの長さぶんの時間で爆弾に届く。つないでいない爆弾に点火すると、その場で爆発する。合図キーの 2 では鳴らない。
火薬を入れるほど大きな爆発になりギャラも増えるが、まわりの物も役者も吹き飛ぶ。こぼれた粉にも火が移る。
等身大パネル（軽トラの西）は、見て F で色つきの絵を描ける。何か描けば、どの役にもなれるジョーカー。コンボも1つ完成させる。
貯金は車やスタジオに使える。ただし3本ごとに家賃を払い、払えないと倒産して最初からやり直し。
竜の頭や魔女の鍋も自由に使える。竜は F で口が開く。
持った物は軽トラのそばで F：荷台の床の空いた所に積む（低い荷物の真上で押せば、その上に重ねる）。高く積むなら、左クリックで手で置く。
会社の機材（カメラ3台・ライト2台・カチンコ・カンペ・確認用モニター）は、軽トラの北東の機材置き場にある。積まなくても、出発するといっしょに現場へ運ばれる。
手に持ったままの物も、持ったまま現場へ行ける。
全員が軽トラのそばへ集まり、手ぶらで F：積み込み確認を開いて出発。
カンペは機材置き場。持って F でペイントを開き、書いた内容をそのまま正面の相手へ見せられる。
台本は机の上に1冊だけ。持って F で開く。場面の一覧と配役は、台本にだけ書いてある（持っている人だけが読める）。せりふを声に出して、役者に声を当てよう。
カメラの映像は、確認用モニターのそばでだけ見られる（小型モニターを買えば、どこでも見られる）。
事務所の奥の大きな画面で、稼いだお金を使って車やスタジオを良くできる（買いたい枠を見て左クリック）。
出発の目安は3分。遅れた分だけ、撮影に使える時間が減る。
荷台に積みすぎると、道中の段差で上の物から落ちる。重りと接着剤で荷物を支えよう。
段ボール箱は、軽トラの西の「段ボール置き場」にいくらでもある（山を見て F で、もう1箱）。物を持って、開いた箱を見て F：箱に入れる。手ぶらで箱を見て F：取り出す。
箱に入れた物は、こぼれずに箱ごと運べる（小さい物なら4つ、大きめなら1〜2つ）。箱を荷台に積めば、中身もいっしょに現場へ届く。
荷物は、ロープ（段ボール置き場）で押さえる。束を持って、荷台のフックを見て F で端を結び、荷物をはさんだ向こうのフックを見て F でもう片方を結ぶ。
荷物の上をきちんと通って、張っているロープほど、よく押さえる。たるんだロープ・荷物の上を通っていないロープは、道中で役に立たない。
掛けたロープを見て F でほどく。はさみでも切れる。ロープの長さには限りがある（導火線と同じ束）。現場に着いたら、自分でほどく。
現場を借りられるのは10分。3場面を1テイクで撮り切ろう。
「完全版」の依頼（2日目から）は5場面。台本を読める人が 1 で次の場面へ、2 で今の場面をもう一度。台本は、置いても、すぐそばにいれば進められる。
役者は場面ごとに、印①②③へ動く。物にぶつかると立ち止まる。準備中に 1 で進めると通し稽古（B で戻す）。
完全版のテイクは、フィルム1本ぶん。残りは、カメラの上のリールと、モニターの枠の目盛りで見る。撮れた場面は、モニターの枠のランプが点く。
完全版では、班の誰かが映っている間、その場面は撮れていない。物の陰に隠れていれば、映っていない。
最初の一本は、会社のCM（地方テレビ局の深夜枠）。軽トラで出発せず、会社の前（事務所の正面）で撮る。CMが流れると、2日目から依頼の電話が来る。
「カット割り」の依頼（会社のCM・怪獣ドラマ）は、場面が撮れるとフィルムが止まる（場転）。止まっている間は、フィルムも時間の数えも減らない。
場転の間に、次の場面の物を出す・カメラを寄せる・ライトを向け直す。用意ができたら、台本を読める人が 1 で回す。回している間の 1 はカット（撮れていなければ、同じ場面を撮り直す）。
「このテイクを納品」を押すと、試写会。依頼主と一緒に見てから、ギャラが決まる（Enter・Esc でとばせる）。
見ごたえ：本番中の爆発が、撮影カメラの画面いっぱいに映ると +80、画面に映った役者のすぐそばで爆発すると（間一髪）+60。危ない撮り方ほど報われる。

合図キー
{cues}
カチンコを持って F：本番 ／ T：カット

WASD 移動 ／ Shift 走る ／ Space ジャンプ ／ 視点 マウス
左クリック 表面をつかむ・置く ／ 物は視点と同じ向きについて来る ／ 右ドラッグ 回す ／ Q・E 傾ける
ホイール 奥行き ／ R 起こす ／ G 一度起こして手元へ ／ N 力を抜く（垂らす）
重り：重さで風に耐える ／ 接着剤：Fで塗り、点同士を合わせる ／ 接着は1点だと回る。離して何点か留めると固まる
F カメラ・ライト操作、箱の開閉、昇降台・絞り機を動かす
V・中クリック ここ！目印（5秒、撮影映像には映らない）
C キャラクター選択 ／ Esc メニュー
F2 視点の切り替え（後ろから ⇄ 自分の目） ／ F3 押している間、表情の顔が並ぶ。マウス・ホイール・数字で選び、離すと決まる
K キャラの特技。ロボット：おなかのランプ ／ 段ボール頭：小物を3つ頭にしまう ／ 手帳の人：台本の写しを読む
　 ドレスの人：物にショールをかける ／ カエルの警官：動く物を止める ／ モップの王様：毛をひもにする ／ ベレー帽の人：首を伸ばす
開いた画面はマウスだけで操作できる。右クリックか Esc で閉じる。
H 演技・VFX選択 ／ Z 選んだ演技 ／ X 選んだVFX ／ Ctrl しゃがむ
演技は移動で中断。舞台効果は撮影に映り、見返しにも残る。
役者の印を持って動かすと、役者も立ち位置へ移る。B で戻す。
カメラ操作中はマウスで首振り、ホイールでズーム。
本番中のカメラ操作では、左クリックで次の合図を出せる。
カメラ操作中は身体を固定。移動するときは F で離れる。

結果画面：R で見返す、P で見返して8コマPNG保存。
保存先はユーザーデータの film_stills フォルダ。
保存できたら O：保存先を開く。
Space で撮り直す、Enter で納品。
期限が切れたら、撮れたテイクを納品して事務所へ帰ろう。"""
	# Windows の複数行文字列の CR は、Label で余分な行になってしまう。
	game.hud.help.get_child(0).text = game.hud.help.get_child(0).text.replace("\r", "")
	_build_help_board()

	_build_strip()
	# キャラの特技：段ボール頭の頭の中身（枠3つ）
	talent_slots = TalentSlots.new()
	root.add_child(talent_slots)
	talent_slots.build()

	# 画面を開いている間は、後ろを少し暗くする。外側を押すと閉じる
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.5)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			game.close_menu())
	root.add_child(_backdrop)

	_build_lobby(game.get_parent())

	# 台本のページ（台本を持っている人にだけ見える）
	script_page = ScriptPage.new()
	root.add_child(script_page)
	script_page.build(game)
	_build_office()
	_build_upgrade()
	# 打ち合わせ（依頼主の小芝居と絵コンテ）。依頼のカードを押すと開く
	briefing = Briefing.new()
	root.add_child(briefing)
	briefing.build(game)
	briefing.accepted.connect(func(index: int) -> void:
		game.close_menu()
		game.rpc_id(1, "h_accept_job", index))
	briefing.declined.connect(func() -> void: game.open_menu("board"))
	_build_packing()
	_build_travel()
	_build_settled()
	# 古い作りの画面（発注の案内など）は、暗い板ではなく紙に（ui/film_set.gd の paperize）。
	# 打ち合わせ・レンタル・積み込み・精算・キャラ選びは、画面全体を紙で包まない：物（テーブル・チラシ・カメラ・ボード・ラック）を、じかに置く
	var legacy: Node = game.hud
	for p: Control in [_upgrade, legacy.panel]:
		FilmSet.paperize(p)

	_warning = _label("", 17, UI.CLAP_WHITE, "bold")
	_warning.add_theme_stylebox_override("normal", _bar_style(UI.STAMP_RED))
	_warning.visible = false
	root.add_child(_warning)
	_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning.offset_left = 0
	_warning.offset_right = 0
	_warning.offset_top = 244
	_warning.offset_bottom = 244
	_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 追加注文の1行は、撮影中の依頼パネル（HUD側）に持たせる
	_bonus = game.hud.bonus_text
	for p: Control in [_office, _packing, _travel, _settled]:
		UI.pop_on_show(p)
	_refresh()


func _bar_style(bar: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UI.BOARD, 0.94)
	s.border_color = bar
	s.border_width_left = 4
	s.set_corner_radius_all(6)
	s.content_margin_left = 20
	s.content_margin_right = 24
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


func _divider() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hairline(true)
	h.custom_minimum_size = Vector2(1, 20)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.add_child(h)
	return m


# 上の帯：会社の財布｜人数｜段階｜貸し時間
func _build_strip() -> void:
	_strip = _panel("slate", Control.PRESET_CENTER_TOP, Vector2(0, 18), 0, 0.0, false, 20, 8)
	_strip.offset_left = 0
	_strip.offset_right = 0
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.custom_minimum_size.x = 0
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 板は描かず、撮影カメラの画面の四隅の枠にする（ui/film_set.gd）。準備中は STBY、本番中は REC
	(_strip as UI.TapedPanel).sb = null
	_strip.add_theme_stylebox_override("panel", FilmSet.CamStyle.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_strip.add_child(row)
	_rec_dot = FilmSet.label("●", 15, UI.STAMP_RED, "mono")
	_cam_outline(_rec_dot)
	row.add_child(_centered(_rec_dot))
	_rec_text = FilmSet.label("STBY", 13, UI.CLAP_WHITE, "mono")
	_cam_outline(_rec_text)
	row.add_child(_centered(_rec_text))
	_wallet_div = _divider()
	row.add_child(_wallet_div)
	# お金は、コインのマークと数だけ（「貯金」「コイン」の字は出さない）
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 6)
	row.add_child(wallet)
	_wallet_box = wallet
	wallet.add_child(_centered(FilmSet.CoinMark.new()))
	_wallet_num = _label("", 20, UI.CLAP_WHITE, "bold")
	_wallet_num.custom_minimum_size.x = 38
	_wallet_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.add_child(_centered(_wallet_num))
	_wallet_unit = _label("コイン", 15, UI.MUTED, "body")
	wallet.add_child(_centered(_wallet_unit))
	_wallet_unit.visible = false
	# 家賃：次に払う額と、あと何本か（事務所にいる間だけ出す）
	_rent_div = _divider()
	row.add_child(_rent_div)
	_rent = _label("", 15, UI.MUTED, "body")
	row.add_child(_centered(_rent))
	# 人数は帯に出さない（いつも見る物ではない。Esc のメニューに「制作班 n / 4 人」がある）
	_people = _label("", 17, UI.CLAP_WHITE, "body")
	_people.visible = false
	row.add_child(_people)
	_status_div = _divider()
	row.add_child(_status_div)
	_status = _label("", 17, UI.CLAP_WHITE, "bold")
	row.add_child(_centered(_status))
	_clock_div = _divider()
	row.add_child(_clock_div)
	_clock = _label("", 17, UI.CLAP_WHITE, "bold")
	_clock.custom_minimum_size.x = 124
	row.add_child(_centered(_clock))
	# 数字はカメラの表示と同じ等幅の字。明るい景色の上でも読めるように、黒いふちを付ける
	for l: Label in [_wallet_num, _clock]:
		l.add_theme_font_override("font", FilmSet.font("mono"))
	for l: Label in [_wallet_num, _wallet_unit, _rent, _status, _clock]:
		_cam_outline(l)
	# 本番中の秒数と3つの合図（hud.gd が作って、毎コマ書き換える）を、この帯の中へ移す。録画のランプは帯の物を使う
	var legacy: Node = game.hud
	var take_row: HBoxContainer = legacy.take_row
	take_row.get_parent().remove_child(take_row)
	take_row.get_node("RecDot").visible = false
	row.add_child(take_row)
	_take_parts = [take_row]
	legacy.take_secs.add_theme_font_override("font", FilmSet.font("mono"))
	legacy.take_secs.add_theme_font_size_override("font_size", 26)
	_cam_outline(legacy.take_secs)
	for l: Label in legacy.cue_names_labels:
		_cam_outline(l)
	_take_divider = _divider()
	row.add_child(_take_divider)
	var order: Array = [_rec_dot, _rec_text, _status_div, _status, _clock_div, _clock, _take_divider, take_row,
		_wallet_div, _wallet_box, _rent_div, _rent, _people]
	for i in order.size():
		row.move_child(order[i], i)


func _cam_outline(l: Label) -> void:
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))


func _centered(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


# 一時メニュー（Esc）：つづける・キャラクター・あそびかた・会社を閉じる
func _build_lobby(menu: Node) -> void:
	_lobby = _panel("slate", Control.PRESET_TOP_LEFT, Vector2.ZERO, 440, 0.0, true, 24, 20)
	_center(_lobby, 440)
	# クリップボードに挟んだ紙（ui/film_set.gd）。字はペン、ボタンは色を塗った段ボールの札
	(_lobby as UI.TapedPanel).sb = null
	_lobby.add_theme_stylebox_override("panel", FilmSet.ClipboardStyle.new())
	var lobby_rows := _rows(_lobby, 12)
	lobby_rows.add_child(FilmSet.label("ひと休み", 18, FilmSet.MARKER_RED, "marker"))
	_lobby_status = FilmSet.label("", 30, FilmSet.MARKER_INK, "marker")
	lobby_rows.add_child(_lobby_status)
	_lobby_sub = FilmSet.label("", 16, Color("5d5850"), "marker")
	lobby_rows.add_child(_lobby_sub)
	var can_leave: bool = menu != null and menu.has_method("return_to_menu")
	if Net.mode == "host" and can_leave:
		_addresses = menu.host_addresses()
		lobby_rows.add_child(UI.hairline(false, Color(0, 0, 0, 0.15)))
		lobby_rows.add_child(FilmSet.label("同じネットワークの友達へ", 14, Color("5d5850"), "marker"))
		var ip_row := HBoxContainer.new()
		ip_row.add_theme_constant_override("separation", 12)
		lobby_rows.add_child(ip_row)
		var ip := FilmSet.label("IP：" + (" / ".join(_addresses) if not _addresses.is_empty() else "見つかりませんでした"), 17, FilmSet.MARKER_INK, "mono")
		ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ip.custom_minimum_size.x = 120
		ip_row.add_child(ip)
		if not _addresses.is_empty():
			var copy_button := _button("コピー", "slate", 15, 34)
			FilmSet.style_sign_button(copy_button, "cream", 15, 34)
			copy_button.pressed.connect(func():
				if DisplayServer.get_name() != "headless": DisplayServer.clipboard_set(_addresses[0])
				game.hud.show_toast("IPをコピーしました。友達の参加画面へ", game.hud.YELLOW))
			ip_row.add_child(copy_button)
	# マウスの感度・音量は「設定」の紙へ（メニューの紙には、つづける・キャラ・あそびかた・設定だけ）
	lobby_rows.add_child(UI.hairline(false, Color(0, 0, 0, 0.15)))
	var resume := _button("つづける", "tape", 20, 52)
	FilmSet.style_sign_button(resume, "mustard", 24, 54)
	resume.pressed.connect(func(): game.close_menu())
	lobby_rows.add_child(resume)
	var cast := _button("キャラクターを選ぶ", "slate", 17, 44)
	FilmSet.style_sign_button(cast, "teal", 19, 46)
	cast.pressed.connect(func():
		game.close_menu()
		game.set_character_menu(true))
	lobby_rows.add_child(cast)
	var settings := _button("設定", "slate", 17, 44)
	FilmSet.style_sign_button(settings, "sky", 19, 46)
	settings.pressed.connect(func(): _show_settings(true))
	var how := _button("あそびかた", "slate", 17, 44)
	FilmSet.style_sign_button(how, "cream", 19, 46)
	how.pressed.connect(func():
		game.close_menu()
		game.help_open = true)
	lobby_rows.add_child(how)
	lobby_rows.add_child(settings)
	if can_leave:
		var leave_button := _button("会社を閉じる" if Net.mode in ["solo", "host"] else "会社を出る", "slate", 17, 44)
		leave_button.tooltip_text = "現在の会社の残金と撮影は終了します。"
		FilmSet.style_sign_button(leave_button, "tomato", 19, 46)
		leave_button.pressed.connect(func(): menu.return_to_menu())
		lobby_rows.add_child(leave_button)


# Tab の撮影の手引き：流れ（フィルムのコマ）・操作（段ボールの札）・コツ（カンペ）を、はみ出さずに1画面へ
func _build_help_board() -> void:
	var legacy: Node = game.hud
	var help: PanelContainer = legacy.help
	(help as UI.TapedPanel).sb = null
	help.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	legacy.help_sheet.visible = false
	var board := FilmSet.help_board()
	help.add_child(board)
	(board.find_child("Close", true, false) as Button).pressed.connect(func(): game.help_open = false)


# Esc のメニューの「設定」：同じクリップボードの紙を、設定の紙（ui/settings_sheet.gd。タイトル画面の設定と同じ物）に替える
func _show_settings(on: bool) -> void:
	if _settings_sheet == null:
		_settings_sheet = SettingsSheet.new()
		_settings_sheet.close_text = "もどる"
		_settings_sheet.visible = false
		_lobby.add_child(_settings_sheet)
		_settings_sheet.closed.connect(func(): _show_settings(false))
		_settings_sheet.width_wanted.connect(func(w: float):
			_center(_lobby, w)
			_lobby.reset_size())
	_lobby.get_child(0).visible = not on
	_settings_sheet.visible = on
	if on:
		_settings_sheet.show_main()
	else:
		_center(_lobby, 440.0)
		_lobby.reset_size()


func _center(p: Control, width: float) -> void:
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -width * 0.5
	p.offset_right = width * 0.5
	p.offset_top = 0
	p.offset_bottom = 0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH


# 事務所：依頼のカード（game.production.JOBS の数だけ）
func _build_office() -> void:
	var jobs: Array = game.production.JOBS
	_office = _panel("slate", Control.PRESET_TOP_LEFT, Vector2.ZERO, 900, 0.0, true, 24, 20)
	_center(_office, 900)
	# 映画館のロビーの「近日撮影」の壁（ui/film_set.gd の WallStyle）。依頼1件が、額縁入りのポスター1枚
	(_office as UI.TapedPanel).sb = null
	_office.add_theme_stylebox_override("panel", FilmSet.WallStyle.new())
	var office_rows := _rows(_office, 18)
	# 看板の帯：電球と「近日撮影 ・ 初仕事」
	var marquee := HBoxContainer.new()
	marquee.alignment = BoxContainer.ALIGNMENT_CENTER
	marquee.add_theme_constant_override("separation", 14)
	office_rows.add_child(marquee)
	for side in 2:
		if side == 1:
			_office_head = FilmSet.label("近日撮影", 30, Color("ffe7a8"), "stencil")
			_office_head.add_theme_constant_override("outline_size", 8)
			_office_head.add_theme_color_override("font_outline_color", Color(1.0, 0.7, 0.25, 0.35))
			marquee.add_child(_office_head)
		var bulbs := HBoxContainer.new()
		bulbs.add_theme_constant_override("separation", 10)
		bulbs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marquee.add_child(bulbs)
		for i in 3:
			var bulb := UI.Dot.new().setup(Color("ffe49a"), 6.0)
			bulbs.add_child(bulb)
	# 赤いビロードの布（3D）に、ポスターを上の一辺だけ留めて吊るす（ui/poster_wall_3d.gd）。下ほど、ぴらぴら揺れる
	_wall = PosterWall.new()
	_wall.custom_minimum_size = Vector2(1000, 540)
	_wall.make_poster = func(index: int) -> Control: return _poster_face(index, jobs[index])
	_wall.picked.connect(func(index: int): game.open_brief(index))
	office_rows.add_child(_wall)
	var foot := HBoxContainer.new()
	office_rows.add_child(foot)
	var office_character := UI.KeyButton.new().setup("キャラクターを選ぶ", "C", "slate", 15, 36)
	office_character.pressed.connect(func(): game.set_character_menu(true))
	FilmSet.style_sign_button(office_character, "cream", 16, 36)
	foot.add_child(office_character)
	# 壁を見て回る札（ポスターが4枚より多い日。ホイールでも動く）
	_wall_prev = Button.new()
	_wall_prev.text = "◀ 前の依頼"
	_wall_prev.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(_wall_prev, "mustard", 16, 36)
	_wall_prev.pressed.connect(func(): _wall.pan(-1))
	foot.add_child(_wall_prev)
	_wall_next = Button.new()
	_wall_next.text = "次の依頼 ▶"
	_wall_next.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(_wall_next, "mustard", 16, 36)
	_wall_next.pressed.connect(func(): _wall.pan(1))
	foot.add_child(_wall_next)
	var office_close := FilmSet.label("ポスターを押すと、依頼主との打ち合わせ　／　右クリック・Esc で閉じる", 14, Color("f3d9b0"), "marker")
	office_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	office_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	office_close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(office_close)


const POSTER_W := 236.0
const POSTER_H := 372.0


# 依頼のポスターの絵（2D。3D の壁が小さな画面に描いて、吊るす板に貼る）：上に絵（依頼の種類ごと）、題名、ひとこと、
# 下の小さな字のクレジット（場所・場面・追加の注文）と制作費。左上に、数字キーで開ける番号
func _poster_face(index: int, job: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(POSTER_W, POSTER_H)
	var face := FilmSet.frame_style(false)
	face.shadow_size = 0
	card.add_theme_stylebox_override("panel", face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	var art := FilmSet.PosterArt.new()
	art.kind = "debut" if bool(job.get("debut", false)) else str(job.get("script", "castle"))
	art.variant = index
	col.add_child(art)
	# 数字キーで開ける印（左上の小さな札）。番号は、きょう出ている順
	var offered: Array = game.production.offered()
	var key: Control = UI.KeyCap.new().setup(str(offered.find(index) + 1), 13, Color(1, 1, 1, 0.6))
	key.position = Vector2(8, 8)
	art.add_child(key)
	# 枠の帯（右上）：地元の仕事・いつもの仕事・大仕事。大仕事は赤
	var slot: String = game.production.slot_of(index)
	if slot != "":
		var band := Label.new()
		band.text = str(game.production.SLOT_NAMES[slot])
		band.add_theme_font_override("font", FilmSet.font("stencil"))
		band.add_theme_font_size_override("font_size", 15 if slot == "big" else 13)
		band.add_theme_color_override("font_color", Color("fff4e4") if slot == "big" else Color("1d1a14"))
		var bs := StyleBoxFlat.new()
		bs.bg_color = {"local": Color("8fc79a"), "regular": Color("f1e8d4"), "big": Color("d23a2a")}[slot]
		bs.content_margin_left = 10
		bs.content_margin_right = 10
		bs.content_margin_top = 3
		bs.content_margin_bottom = 4
		band.add_theme_stylebox_override("normal", bs)
		art.add_child(band)
		band.position = Vector2(POSTER_W - 12, 10)
		band.resized.connect(func() -> void: band.position.x = POSTER_W - band.size.x - 8)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	col.add_child(text)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 10)
	text.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	pad.add_child(inner)
	var title := FilmSet.label(str(job.get("title", "")), 22, Color.WHITE, "stencil")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = POSTER_W - 34
	title.max_lines_visible = 2
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	inner.add_child(title)
	var copy := FilmSet.label(_poster_copy(job), 13, Color(1, 1, 1, 0.82), "body")
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.x = POSTER_W - 34
	copy.max_lines_visible = 2
	inner.add_child(copy)
	inner.add_child(UI.hairline(false, Color(1, 1, 1, 0.35)))
	# クレジット（本物のポスターの下の、細い字の欄）
	var scenes: Array = job.get("scenes", [])
	var how := ("カット割り %d" % scenes.size()) if Scripts.cuts(index) else ("%d場面" % scenes.size())
	var billing := FilmSet.label("撮影 %s ／ %s\n追加 +150 %s" % [str(job.get("location", "")), how, str(job.get("bonus_title", ""))], 11, Color(1, 1, 1, 0.78), "body")
	billing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	billing.custom_minimum_size.x = POSTER_W - 34
	inner.add_child(billing)
	var fee := FilmSet.label("制作費 %d" % int(job.get("budget", 600)), 15, Color("ffd43b"), "mono")
	inner.add_child(fee)
	return card


# ポスターのひとこと：依頼の説明の、最初の一文（長ければ切る）
static func _poster_copy(job: Dictionary) -> String:
	var d := str(job.get("description", ""))
	var cut := d.find("。")
	var line := d.substr(0, cut + 1) if cut > 0 else d
	return line if line.length() <= 34 else line.substr(0, 33) + "…"


# 会社の備品：報酬で買い切りの備品を買う（事務所の奥のロッカーで F）
func _build_upgrade() -> void:
	_upgrade = _panel("slate", Control.PRESET_TOP_LEFT, Vector2.ZERO, 760, 0.0, true, 28, 22)
	_center(_upgrade, 760)
	var rows := _rows(_upgrade, 12)
	var head := HBoxContainer.new()
	rows.add_child(head)
	var head_l := VBoxContainer.new()
	head_l.add_theme_constant_override("separation", 2)
	head_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_l)
	head_l.add_child(UI.overline("COMPANY"))
	head_l.add_child(_label("会社の備品", 28, UI.CLAP_WHITE, "display"))
	head_l.add_child(_label("稼いだお金で会社を良くする。一度買えば、次の依頼からもずっと使える。", 15, UI.MUTED, "body"))
	_upgrade_wallet = _label("", 24, UI.CLAP_WHITE, "display")
	_upgrade_wallet.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_upgrade_wallet)
	rows.add_child(UI.hairline())
	_upgrade_rows = VBoxContainer.new()
	_upgrade_rows.add_theme_constant_override("separation", 10)
	rows.add_child(_upgrade_rows)
	var close := _label("右クリック・Esc で閉じる", 13, UI.MUTED, "body")
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rows.add_child(close)
	_upgrade.visible = false


func _sync_upgrade(production: Node) -> void:
	_upgrade_wallet.text = "%d コイン" % int(production.wallet)
	var sig := str(production.levels) + str(production.wallet)
	if sig == _upgrade_sig:
		return
	_upgrade_sig = sig
	for c in _upgrade_rows.get_children():
		c.queue_free()
	pass


# 積み込み確認：左に、本物の軽トラを真上から映すカメラ。右に、積んだ物の名前の一覧
func _build_packing() -> void:
	# 枠も紙も無し：画面ぜんたいが軽トラの真上からの眺めに切り替わり、右に文字をじかに書く
	_packing = PanelContainer.new()
	_packing.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_packing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_packing)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packing.add_child(stage)
	# 文字を書く右側だけ、景色をふんわり暗くする（枠ではなく、かげ）
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0, 0, 0, 0))
	grad.gradient.set_color(1, Color(0, 0, 0, 0.62))
	grad.fill_from = Vector2(0.0, 0.5)
	grad.fill_to = Vector2(0.45, 0.5)
	shade.texture = grad
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	shade.anchor_left = 0.42
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	var packing_rows := VBoxContainer.new()
	packing_rows.add_theme_constant_override("separation", 10)
	packing_rows.theme = _outlined_theme()
	stage.add_child(packing_rows)
	packing_rows.anchor_left = 0.5
	packing_rows.anchor_right = 0.5
	packing_rows.anchor_top = 0.56
	packing_rows.anchor_bottom = 0.56
	packing_rows.offset_left = 40
	packing_rows.offset_right = 40 + LIST_W
	packing_rows.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pack_cam = Camera3D.new()
	_pack_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_pack_cam.near = 0.05
	_pack_cam.far = 60.0
	add_child(_pack_cam)
	_packing.visibility_changed.connect(_on_packing_shown)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	packing_rows.add_child(head)
	var title_row := HBoxContainer.new()
	head.add_child(title_row)
	var title := FilmSet.label("積み込み確認", 30, UI.CLAP_WHITE, "stencil")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_packing_aside = _label("", 15, UI.MUTED, "body")
	_packing_aside.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(_packing_aside)
	_packing_sub = _label("", 15, UI.MUTED, "body")
	_packing_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_packing_sub.custom_minimum_size.x = 300
	head.add_child(_packing_sub)
	_packing_scroll = ScrollContainer.new()
	_packing_scroll.custom_minimum_size = Vector2(LIST_W, 240)
	_packing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	packing_rows.add_child(_packing_scroll)
	_packing_rows = VBoxContainer.new()
	_packing_rows.add_theme_constant_override("separation", 4)
	_packing_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_packing_scroll.add_child(_packing_rows)
	_packing_text = _label("", 15, UI.MUTED)
	_packing_text.visible = false
	_packing_rows.add_child(_packing_text)
	_crew = _label("", 18, Color("ffe08a"), "bold")
	packing_rows.add_child(_crew)
	var note := _label("荷台に積んだ物と手に持った物、それに会社の機材が現場へ行く。廃材は無料。", 14, Color(1, 1, 1, 0.8), "body")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = LIST_W
	packing_rows.add_child(note)
	packing_rows.add_child(UI.gap(4))
	_depart = _button("全員そろったら出発", "tape", 20, 52)
	_depart.pressed.connect(func(): game.rpc_id(1, "h_depart"))
	FilmSet.style_sign_button(_depart, "tomato", 18, 50)
	packing_rows.add_child(_depart)
	var packing_character := UI.KeyButton.new().setup("キャラクターを選ぶ", "C", "slate", 15, 36)
	packing_character.pressed.connect(func(): game.set_character_menu(true))
	FilmSet.style_sign_button(packing_character, "cream", 15, 36)
	packing_character.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	packing_rows.add_child(packing_character)
	_pack_character = packing_character


const LIST_W := 400.0


# 景色の上にじかに書く字：黒い縁取りで読めるように
func _outlined_theme() -> Theme:
	var th := Theme.new()
	th.set_constant("outline_size", "Label", 7)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	th.set_constant("shadow_offset_y", "Label", 2)
	return th


# 積み込み確認を開いたら、画面のカメラを軽トラの真上へ。閉じたら元のカメラへ戻す
func _on_packing_shown() -> void:
	if _packing.visible:
		var now := get_viewport().get_camera_3d()
		if now != _pack_cam:
			_pack_prev = now
		_aim_bed_camera()
		_pack_cam.make_current()
	elif _pack_cam.current:
		if _pack_prev != null and is_instance_valid(_pack_prev) and _pack_prev.is_inside_tree():
			_pack_prev.make_current()
		else:
			var me: Node = game.local_player()
			if me != null and me.get("cam") is Camera3D:
				(me.cam as Camera3D).make_current()


# 軽トラの真上へカメラを置く。運転席が画面の上。軽トラは画面の左寄り（右に一覧を書く場所を空ける）
func _aim_bed_camera() -> void:
	var truck: Node3D = game.get("truck")
	if truck == null or _pack_cam == null:
		return
	var deck_c: Vector2 = truck.get("deck_c")
	var deck_half: Vector2 = truck.get("deck_half")
	var top: float = float(truck.get("deck_top"))
	var tr := truck.global_transform
	var center: Vector3 = tr * Vector3(deck_c.x, top, deck_c.y + deck_half.y * 0.75)
	_pack_cam.size = deck_half.y * 2.0 * 2.7
	var fwd: Vector3 = tr.basis.z.normalized()
	_pack_cam.look_at_from_position(center + Vector3.UP * 14.0, center, fwd)
	var vp := get_viewport().get_visible_rect().size
	var wide: float = _pack_cam.size * vp.x / maxf(vp.y, 1.0)
	_pack_cam.global_position += _pack_cam.global_basis.x * wide * 0.2


# 移動：見出しと、細い進み具合の線だけ
func _build_travel() -> void:
	_travel = _panel("slate", Control.PRESET_CENTER_BOTTOM, Vector2(-280, -120), 560, 0.0, true, 24, 20)
	var travel_rows := _rows(_travel, 8)
	travel_rows.add_child(UI.overline("MOVING"))
	_travel_text = _label("", 24, UI.CLAP_WHITE, "display")
	travel_rows.add_child(_travel_text)
	_travel_note = _label("会社の機材もいっしょに運んでいる。着いたらすぐ荷下ろし。", 15, UI.MUTED, "body")
	_travel_note.custom_minimum_size.x = 500
	_travel_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	travel_rows.add_child(_travel_note)
	travel_rows.add_child(UI.gap(8))
	_travel_bar = ProgressBar.new()
	_travel_bar.max_value = 8.0
	_travel_bar.show_percentage = false
	_travel_bar.custom_minimum_size.y = 4
	_travel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.CLAP_WHITE
	_travel_bar.add_theme_stylebox_override("background", bg)
	_travel_bar.add_theme_stylebox_override("fill", fill)
	travel_rows.add_child(_travel_bar)


# 精算：映画館の上の「興行成績」のボード（数字の札がパタパタ入れ替わって決まる）、左下に給料袋、右下にスタッフのエンドロール。
# 紙の枠では包まない（物を画面にじかに置く。ui/box_office.gd）
func _build_settled() -> void:
	_settled = PanelContainer.new()
	_settled.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_settled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settled.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_settled)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settled.add_child(stage)
	# ボード
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", BoxOffice.Marquee.new())
	stage.add_child(board)
	board.set_anchors_preset(Control.PRESET_CENTER_TOP)
	board.custom_minimum_size.x = 640
	board.offset_left = -320
	board.offset_right = 320
	board.offset_top = 74
	board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	board.add_child(rows)
	var title := FilmSet.label("興 行 成 績", 30, Color("ffe7a8"), "stencil")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	_settled_pay = _ledger_row(rows, "ギャラ（出来に応じて）", true, 0.0)
	_settled_expense = _ledger_row(rows, "浮かせた制作費", false, 0.35)
	_settled_bought = _ledger_row(rows, "買った物（貯金から。支払い済み）", false, 0.7)
	_settled_rent = _ledger_row(rows, "家賃", false, 1.05)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.18)
	line.custom_minimum_size.y = 2
	rows.add_child(line)
	_settled_wallet = _ledger_row(rows, "会社の貯金", true, 1.5)
	_settled_rep = FilmSet.label("", 17, Color("ffe7a8"), "body")
	_settled_rep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_settled_rep)
	_settled_next = FilmSet.label("", 14, Color(1, 1, 1, 0.6), "body")
	_settled_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rows.add_child(_settled_next)
	# 給料袋（左下。少し傾けて置く）
	_envelope = BoxOffice.Envelope.new()
	stage.add_child(_envelope)
	_envelope.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_envelope.offset_left = 56
	_envelope.offset_top = -260
	_envelope.offset_right = 356
	_envelope.offset_bottom = -60
	_envelope.pivot_offset = Vector2(150, 100)
	_envelope.rotation = deg_to_rad(-6.0)
	_settled_head = FilmSet.label("", 1, Color.WHITE, "body")
	_settled_head.visible = false
	stage.add_child(_settled_head)
	# スタッフのエンドロール（右下。黒地に白い字）
	_growth = PanelContainer.new()
	var credits := StyleBoxFlat.new()
	credits.bg_color = Color("0c0c0c")
	credits.set_content_margin_all(22)
	credits.content_margin_top = 18
	credits.shadow_color = Color(0, 0, 0, 0.45)
	credits.shadow_size = 10
	_growth.add_theme_stylebox_override("panel", credits)
	stage.add_child(_growth)
	_growth.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_growth.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_growth.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_growth.offset_right = -40
	_growth.offset_bottom = -36
	_growth.offset_left = -40
	_growth.offset_top = -36
	var growth_rows := VBoxContainer.new()
	growth_rows.add_theme_constant_override("separation", 8)
	_growth.add_child(growth_rows)
	var staff := FilmSet.label("STAFF", 20, Color("ffe7a8"), "stencil")
	staff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	growth_rows.add_child(staff)
	_growth_text = FilmSet.label("", 15, Color("e9e4d8"), "body")
	_growth_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_growth_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_growth_text.custom_minimum_size.x = 380
	growth_rows.add_child(_growth_text)
	_settled_note_box = VBoxContainer.new()
	(_settled_note_box as VBoxContainer).add_theme_constant_override("separation", 4)
	growth_rows.add_child(_settled_note_box)
	var talk := FilmSet.label("こぼれ話", 15, Color("ffe7a8"), "mincho")
	talk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settled_note_box.add_child(talk)
	_settled_notes = FilmSet.label("", 14, Color("e9e4d8"), "body")
	_settled_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settled_notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settled_notes.custom_minimum_size.x = 380
	_settled_note_box.add_child(_settled_notes)
	var hint := FilmSet.label("H でスタッフスキル（キャラや会社が変わっても引き継ぐ）", 12, Color(1, 1, 1, 0.5), "body")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	growth_rows.add_child(hint)
	# 下の真ん中：次の一本へ（と、保存した8コマ）
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	stage.add_child(foot)
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_bottom = -40
	foot.offset_top = -40
	_settled_folder = UI.KeyButton.new().setup("保存した8コマのフォルダを開く", "O", "slate", 15, 36)
	_settled_folder.pressed.connect(func(): game.production_export.open_saved())
	FilmSet.style_sign_button(_settled_folder, "cream", 15, 36)
	_settled_folder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	foot.add_child(_settled_folder)
	var return_button := _button("事務所へ戻って、次の一本", "tape", 20, 52)
	return_button.pressed.connect(func(): game.rpc_id(1, "h_return_office"))
	FilmSet.style_sign_button(return_button, "mustard", 20, 52)
	foot.add_child(return_button)
	_settled_return = return_button
	# 開くたびに、札を回し直す
	_settled.visibility_changed.connect(func() -> void:
		if _settled.visible:
			for tiles: Control in _tiles:
				tiles.restart())
	_settled.visible = false


# ボードの1行：左に字、右に数字の札。数字は見えない label が持ち、札がそれを読んで回る
# （1つ目の子が字、行ごと隠せる。精算の更新は label.text と行の visible を書くだけ）
func _ledger_row(parent: Control, caption: String, strong: bool, delay: float = 0.0) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 50 if strong else 44
	parent.add_child(row)
	var cap := FilmSet.label(caption, 18 if strong else 16, Color("e9e4d8"), "body")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var value := _label("", 17, UI.CLAP_WHITE, "bold")
	value.visible = false
	row.add_child(value)
	var tiles: Control = BoxOffice.Tiles.new().setup(value, delay, strong)
	row.add_child(tiles)
	_tiles.append(tiles)
	return value


# 1〜9キーでも依頼を選べる（1〜3は production_main、4以降はここ）
func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.production == null or game.production.phase != 0:
		return
	if game.character_open or game.help_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if false and index >= 3 and index < game.production.JOBS.size():     # 数字キーは production_main.gd が全件を受ける
			game.rpc_id(1, "h_accept_job", index)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_instance_valid(root):
		return
	_refresh()


# コインの額を、3桁ごとのカンマで区切って書く（1000600 → 1,000,600）
static func coins(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if n < 0 else "") + out


# 財布の増減：数字の隣に小さく浮いて消える（面は敷かない）
func _wallet_popup(change: int) -> void:
	var gain := change > 0
	var l := UI.label(("+%s" if gain else "−%s") % coins(absi(change)), 17, UI.GREEN_LIGHT if gain else UI.STAMP_RED.lightened(0.25), "bold", true)
	root.add_child(l)
	# 財布の数字の真下から、帯のほうへ浮かんで消える
	var from := Vector2(_wallet_num.global_position.x + _wallet_num.size.x - l.get_combined_minimum_size().x, _strip.global_position.y + _strip.size.y + 12.0)
	l.position = from
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", from.y - 10.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


func _refresh() -> void:
	var production: Node = game.production
	var phase: int = production.phase
	var picker_open: bool = game.character_open
	var legacy: Node = game.hud
	var vw: float = game.get_viewport().get_visible_rect().size.x
	legacy.root.visible = true
	legacy.order_state.get_parent().get_parent().visible = phase == 4
	# 場面の一覧は、台本を読める人にだけ出す（ほかの人には、題名とテイクの数だけ）。
	# 場面の列を持つ依頼では、場面を進められる人（置いた台本のすぐそばにいる人も）に出す
	var paging: bool = game.beats != null and game.beats.active()
	legacy.show_scene_list(game.reads_script() or (paging and game.directs()))
	legacy.toast_top = 156.0 if phase == 4 else 100.0
	legacy.take_bar.offset_top = 78.0 if phase == 4 else 16.0
	legacy.take_bar.offset_bottom = legacy.take_bar.offset_top
	if phase != 4:
		var viewer: Node = game.local_player()
		var camera_view: bool = viewer != null and game.props.has(viewer.operating) and game.props[viewer.operating].kind == "camera"
		legacy.cross.visible = phase in [0, 2] and not picker_open and not camera_view
		legacy.target_label.visible = phase in [0, 2] and not picker_open
		legacy.order_checked_override = []
	else:
		legacy.target_label.visible = true
		legacy.order_title.text = production.job()["title"]
		if game.state in [game.S.RESULT, game.S.REPLAY] and not game.takes.is_empty():
			legacy.order_checked_override = game.takes[game.selected]["passed"]
		else:
			legacy.order_checked_override = []
	legacy.keys.visible = phase in [0, 2, 4] and not picker_open and not game.help_open
	var menu: String = game.menu_open
	var here: String = game.station()
	if phase in [0, 2]:
		var kw0 := minf(1100.0, vw - 40.0)
		legacy._place(legacy.keys, Control.PRESET_CENTER_BOTTOM, Vector2(-kw0 * 0.5, -64), kw0)
		legacy.keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var me: Node = game.local_player()
		var line := ""
		var offer: Dictionary = production.display.aimed_offer() if production.display else {}
		if not offer.is_empty() and (me == null or me.held == 0):
			line = "左クリック　%s を買う（%d コイン）　%s" % [offer["name"], int(offer["cost"]), offer["desc"]]
		elif me and game.props.has(me.held) and game.props[me.held].kind == "cue_card":
			line = "F カンペに書く\n" + game.hold_hint()
		elif me and game.holding_script():
			line = (("F 挟まっている写真を見る" if game.director != null and game.director.open_hours() else "F 台本を閉じる") if game.script_open else "F 台本を開く") + "\n" + game.hold_hint()
		elif me and me.held != 0:
			line = game.hold_hint()
			if me.global_position.distance_to(production.HOME_TRUCK) < 4.5:
				var bed: Dictionary = production.bed_load()
				line = "F 荷台に積む（荷台 %d / %d） ／ " % [bed["used"], bed["cap"]] + line
		elif phase == 0:
			line = "F 依頼を見る" if here == "board" else "事務所の掲示板で、今日の依頼を選ぼう"
		elif here == "packing" and me and me.target != null and me.target.kind in ["camera", "spot"]:
			line = "F %sを操作 ／ 左クリック 持つ" % ("カメラ" if me.target.kind == "camera" else "ライト")
		elif here == "packing":
			line = "F 積み込み確認・出発"
		elif here == "order":
			line = "F 発注する" if production.orderer == 0 else "発注は、いま別の人が使用中"
		else:
			line = "左クリック 持つ ／ 事務所の前の物を、青い影に合わせて置こう" if bool(production.job().get("debut", false)) and production.shoots_home() else "左クリック 持つ ／ 廃材置き場で使える物を探して、軽トラへ運ぼう"
		# 机の上の物（のぞき箱・発注の電話）を見ている：名前と、できることを出す
		var desk: String = game.director.aimed() if game.director != null else ""
		if desk != "":
			legacy.target_label.text = game.director.thing_label(desk)
			legacy._tone(legacy.target_label, "on", FilmSet.tag_style())
			var desk_keys: String = game.director.thing_keys(desk)
			if me != null and me.held != 0:
				line = desk_keys + " ／ " + line if desk_keys != "" else line
			else:
				line = desk_keys
		if me and game.is_action_prop(me.target):
			legacy.target_label.text = me.target.label + "　[F] " + game.prop_action_hint(me.target)
			line = "F " + game.prop_action_hint(me.target) + " ／ " + line
		legacy.keys.text = line + ("\nTab あそびかた" if legacy.first_day() else "")
	elif phase == 4:
		var kw := minf(1400.0, vw - 40.0)
		legacy._place(legacy.keys, Control.PRESET_CENTER_BOTTOM, Vector2(-kw * 0.5, -64), kw)
		legacy.keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legacy.keys.text = legacy.keys.text.replace(" ／ F9 見本を組む", "").replace(" ／ V・中クリック 目印", "")
		var me: Node = game.local_player()
		var action_prop: Node = game.props.get(me.held) if me and me.held != 0 else (me.target if me else null)
		if game.is_action_prop(action_prop):
			legacy.target_label.text = action_prop.label + "　[F] " + game.prop_action_hint(action_prop)
			legacy.keys.text = "F " + game.prop_action_hint(action_prop) + "\n" + (game.hold_hint() if me and me.held != 0 else "左クリック 持つ")
		# 1日目：青い影がまだ残っていれば、まずそれを案内する（影は、事務所の前の舞台の上。事務所を背にして見る）
		var guides: Object = game.hooks.feature("holo_guides") if game.get("hooks") != null else null
		if guides != null and guides.active() and guides.left() > 0 and not game.is_action_prop(action_prop):
			legacy.keys.text = ("左クリック 置く" if me and me.held != 0 else "左クリック 持つ") + " ／ 事務所の前の物を、舞台の青い影に合わせて置こう（あと %d）" % guides.left()
		if me and game.holding_script():
			legacy.keys.text = (("F 挟まっている写真を見る" if game.director != null and game.director.open_hours() else "F 台本を閉じる") if game.script_open else "F 台本を開く") + "\n" + game.hold_hint()
		if me and game.props.has(me.operating) and game.props[me.operating].kind == "camera" and game.state == game.S.TAKE:
			legacy.keys.text = "左クリック 次の合図 ／ マウス 首振り ／ ホイール ズーム ／ F 離れる\nT カット"
		if me and me.target == game.camera_switcher.monitor and me.held == 0 and me.operating == 0:
			legacy.keys.text = "右クリック モニターを開く ／ 3台の映像を確認・切り替え"
		if paging and game.state in [game.S.PREP, game.S.TAKE]:
			_sync_paging(legacy)
		_hint_under_panel(legacy, paging)
	_sync_cast(production, phase)
	_sync_hooks()
	_sync_talent(phase)
	legacy.target_label.text = Keybinds.translate(legacy.target_label.text)     # キーを替えていたら、今のキー名で
	var glue_holder: Node = game.local_player()
	if glue_holder != null and glue_holder.held == game.adhesive.tool.pid:
		legacy.keys.text = game.adhesive.hint()
		if not game.adhesive.applying:
			legacy.keys.text += "\n" + game.hold_hint()
	if menu != "" or game.ordering() or (game.monitor_popup != null and game.monitor_popup.opened):
		legacy.keys.visible = false
		legacy.cross.visible = false
		legacy.target_label.visible = false
	_backdrop.visible = menu != "" and menu != "brief" and not picker_open and not game.help_open
	_office.visible = menu == "board" and not picker_open and not game.help_open
	_upgrade.visible = menu == "upgrade" and not picker_open and not game.help_open
	if _upgrade.visible:
		_sync_upgrade(production)
	# 台本：手に持っている間だけ、右側に開く
	var reader: Node = game.local_player()
	var reading: bool = reader != null and reader.held != 0 and game.props.has(reader.held) and game.props[reader.held].kind == "script" and game.script_open
	# 手帳の人は、台本を持っていなくても、手帳に写したページを開ける（キャラの特技。K）
	if game.talent != null and reader != null and game.talent.note_open(reader.peer_id):
		reading = true
	script_page.visible = reading and menu == "" and phase in [0, 2, 4] and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE] and not picker_open and not game.help_open
	if script_page.visible:
		var now := -1
		if paging:
			# 場面の列を持つ依頼：監督がめくった場面（通し稽古の間も）
			now = int(game.beats.scene)
		elif game.state == game.S.TAKE:
			var ok: Array = game.live.get("passed", [false, false, false])
			now = 0 if not ok[0] else (1 if not ok[1] else 2)
		script_page.sync(production.chosen_job if phase >= 1 else -1, now)
	var want_brief: bool = menu == "brief" and not picker_open and not game.help_open
	if want_brief and (not briefing.visible or briefing.job_index != game.brief_job):
		briefing.open(game.brief_job)
	elif not want_brief and briefing.visible:
		briefing.close()
	if _office.visible:
		# きょう出ている依頼だけ見せる。番号は見えている順
		var offered: Array = production.offered()
		for index in _job_cards.size():
			(_job_cards[index] as Control).visible = index in offered
			# 番号は、見えている順（数字キーで開く順と同じ）
			if index < _job_keys.size() and index in offered:
				var number := str(offered.find(index) + 1)
				if _job_keys[index].text != number:
					_job_keys[index].text = number
					_job_keys[index].queue_redraw()
		_office_head.text = "近日撮影 ・ " + ("初仕事" if production.day <= 1 else "%d日目　%s" % [production.day, production.rank_name()])
		# 壁に吊るすポスターは、きょう出ている依頼だけ。壁の幅も、その数に合わせる
		if _wall.show_jobs(offered):
			var w := clampf(float(mini(offered.size(), 4)) * 300.0 + 160.0, 760.0, 1240.0)
			_wall.custom_minimum_size.x = w - 72.0
			_center(_office, w)
			_office.reset_size()
		_wall_prev.visible = _wall.can_pan(-1)
		_wall_next.visible = _wall.can_pan(1)
	if _lobby:
		_lobby.visible = menu == "pause" and not picker_open and not game.help_open
		if not _lobby.visible and _settings_sheet != null and _settings_sheet.visible:
			_show_settings(false)            # 閉じたら、次に開くときはメニューの紙から
		_lobby_status.text = "制作班 %d / 4 人" % game.players.size()
		_lobby_sub.text = "会社を開いています" if Net.mode == "host" else "友達の会社" if Net.mode == "client" else "ひとりで準備中"
	_packing.visible = menu == "packing" and not picker_open and not game.help_open
	if _packing.visible:
		_depart.text = "ここ（会社の前）で撮影を始める" if production.shoots_home() else "全員そろったら出発"
	_travel.visible = phase == 3
	_settled.visible = phase == 5 and not game.help_open
	_growth.visible = _settled.visible
	if _growth.visible and game.crew_skills != null:
		_growth_text.text = game.crew_skills.growth_text()
	_strip.offset_top = 18
	_strip.offset_bottom = _strip.offset_top
	_wallet_num.text = coins(int(production.wallet) if wallet_shown < 0 else wallet_shown)
	_rent.visible = production.hazards and phase == 0
	_rent_div.visible = _rent.visible
	if _rent.visible:
		_rent.text = "家賃 %d・あと%d本" % [production.rent_amount(), production.rent_in()]
	_people.text = "%d人" % game.players.size()
	var rolling: bool = game.state in [game.S.COUNTDOWN, game.S.TAKE]
	_rec_text.text = "REC" if rolling else "STBY"
	_rec_dot.modulate.a = (1.0 if fmod(Time.get_ticks_msec() / 600.0, 2.0) < 1.0 else 0.15) if rolling else 0.35
	# 会社の前で撮る依頼は、軽トラに積まない（準備の段階の名前を替える）
	_status.text = "撮影の準備" if phase == 2 and production.shoots_home() else PHASE_NAMES[clampi(phase, 0, 5)]
	if production.wallet != _last_wallet:
		if _last_wallet >= 0:
			_wallet_popup(production.wallet - _last_wallet)
		_last_wallet = production.wallet
	# 場面の列を持つ依頼の本番中は、秒を刻む時計を画面に出さない（時計は、カメラのリールとモニターの枠の目盛り）
	_clock.visible = phase in [1, 2, 4] and not game.hides_take_clock()
	_clock_div.visible = _clock.visible
	# 出す物を絞る（必要以上に情報を増やさない）：
	#   撮影現場では、お金と場所の名前は出さない（そこでは使わない・見れば分かる）。残り時間だけ
	#   本番中（秒数と合図が出ている間）は、残り時間も隠して、帯を1段のままにする
	var take_on: bool = (game.hud.take_row as Control).visible
	var at_site: bool = phase == 4
	_wallet_box.visible = not take_on and not at_site
	_rent.visible = _rent.visible and _wallet_box.visible
	_status.visible = not take_on and not at_site
	_clock.visible = _clock.visible and not take_on
	# 区切りの線は、見えている物の前にだけ（先頭は録画のランプ）
	_wallet_div.visible = _wallet_box.visible
	_rent_div.visible = _rent.visible
	_status_div.visible = _status.visible
	_clock_div.visible = _clock.visible
	_take_divider.visible = take_on
	var seconds := maxi(0, ceili(production.lease_left))
	_clock.text = "残り %d:%02d" % [seconds / 60, seconds % 60]
	_clock_urgent = seconds < 60
	if phase in [1, 2]:
		var prep: int = ceili(absf(production.prep_left))
		_clock_urgent = production.prep_left < 30.0
		_clock.text = ("出発まで %d:%02d" if production.prep_left >= 0.0 else "遅れ %d:%02d") % [prep / 60, prep % 60]
	UI.recolor(_clock, UI.STAMP_RED.lightened(0.2) if _clock_urgent else UI.CLAP_WHITE)
	_warning.visible = phase == 4 and (production.expired or seconds < 60)
	_warning.text = "管理人が来た！ いまあるテイクを納品しよう" if production.expired else "あと少しで借り時間終了。撮れたテイクを確かめよう"
	_sync_bonus(production, phase == 4 and not picker_open and not game.help_open)
	if phase == 2:
		_packing_aside.text = "借り物 %d ／ 制作費 %d コイン" % [production.expenses, production.budget()]
		_packing_sub.text = str(production.job().get("title", "今日の撮影"))
		_packing_text.text = "%s\n借り物  %dコイン\n\n%s" % [production.job().get("title", "今日の撮影"), production.expenses, production.loadout_status()]
		_rebuild_packing(production.loadout())
		_aim_bed_camera()
		_crew.text = production.crew_ready()
		_depart.disabled = not production.can_depart()
	if phase == 3:
		_travel_text.text = "%sへ向かっています…" % production.location_name()
		var dropped: Array = production.lost
		_travel_note.text = "会社の機材もいっしょに運んでいる。着いたらすぐ荷下ろし。" if dropped.is_empty() else "落とした物：" + "・".join(dropped)
		UI.recolor(_travel_note, UI.MUTED if dropped.is_empty() else UI.STAMP_RED.lightened(0.25))
		_travel_bar.value = clampf(production.trip_time, 0.0, 8.0)
	if phase == 5:
		var observations := "大きな騒ぎも、映画になれば思い出。"
		if not production.last_flubs.is_empty():
			observations = "\n".join(production.last_flubs)
		_settled_pay.text = "+%d" % production.last_payment
		(_settled_expense.get_parent().get_child(0) as Label).text = "浮かせた制作費（制作費 %d − 借り物 %d）" % [production.budget(), production.expenses]
		_settled_expense.text = "+%d" % production.saved
		# 買った物の行は、この依頼で何か買ったときだけ出す（発注のときに貯金から払ってある）
		(_settled_bought.get_parent() as Control).visible = production.bought > 0
		_settled_bought.text = "−%d" % production.bought
		# 家賃の行は、支払いの回（3本ごと）だけ出す
		(_settled_rent.get_parent() as Control).visible = production.rent_paid > 0 or production.bankrupt
		_settled_rent.text = "払えない（%d）" % production.rent_amount() if production.bankrupt else "−%d" % production.rent_paid
		UI.recolor(_settled_rent, UI.STAMP_RED.lightened(0.25) if production.bankrupt else UI.CLAP_WHITE)
		_settled_wallet.text = "%d コイン" % production.wallet
		_settled_head.text = "家賃が払えない。倒産…" if production.bankrupt else "おつかれさま、制作班！"
		_envelope.note = _settled_head.text
		var step: int = production.rep_to_next()
		_settled_rep.text = "評判 %s　いまの格：%s%s" % [("%+d" % production.rep_change) if production.rep_change != 0 else "±0", production.rank_name(), ("（次の格まで あと %d）" % step) if step > 0 else ""]
		UI.recolor(_settled_rep, Color("ff8a7a") if production.rep_change < 0 else Color("ffe7a8"))
		_envelope.empty = production.bankrupt or production.last_payment <= 0
		_envelope.queue_redraw()
		_settled_return.text = "新しい会社を立ち上げる" if production.bankrupt else "事務所へ戻って、次の一本"
		_settled_next.visible = production.hazards and not production.bankrupt
		if _settled_next.visible:
			var left: int = production.RENT_EVERY if production.rent_paid > 0 else production.rent_in() - 1
			_settled_next.text = "次の家賃：%d コイン（あと%d本）" % [production.rent_amount(), left]
		CompanyLogo.show_in(_settled_notes, observations)
		_settled_folder.visible = game.production_export != null and not game.production_export.last_saved.is_empty()


# 演技の案内（Z・X・H。production_performance.gd）は、左上の依頼の板のすぐ下に出る。
# 場面の一覧が5行になると板が伸びるので、その分だけ下へずらす（今までの依頼では、元の場所のまま）
func _hint_under_panel(legacy: Node, paging: bool) -> void:
	if game.performance == null or game.performance.get("_hint") == null:
		return
	var hint: Label = game.performance._hint
	var panel: Control = legacy.order_panel
	hint.position.y = maxf(300.0, panel.position.y + panel.size.y + 10.0) if paging else 300.0


# 場面の列を持つ依頼：合図の案内を「次の場面・もう一度」に替える。場面を進められる人にだけ出す
func _sync_paging(legacy: Node) -> void:
	var can: bool = game.directs()
	var text: String = legacy.keys.text
	# カット割りの依頼の本番：回している間は「1 カット」、止めている間（場転）は「1 回す」
	var take_keys := "1 次の場面 ／ 2 もう一度 ／ "
	if game.beats != null and game.beats.cut_mode() and game.state == game.S.TAKE:
		take_keys = "1 回す（アクション） ／ " if game.beats.holding else "1 カット（場転へ） ／ 2 もう一度 ／ "
		text = text.replace("T かカチンコでカット", "T かカチンコでテイク終了")     # 場面ごとのカット（1）と、まぎれないように
	text = text.replace(" ／ 1・2・3 合図のリハーサル", " ／ 1 次の場面（通し稽古） ／ 2 もう一度" if can else "")
	text = text.replace("1・2・3 合図 ／ ", take_keys if can else "")
	text = text.replace("左クリック 次の合図 ／ ", "左クリック 次の場面 ／ " if can else "")
	legacy.keys.text = text


# 仕組みの案内（爆弾の道具・箱とロープ・ロープをつかむ など）。文は、各仕組みの hook_hud() が決める。
# 呼ぶ順番は feature_hooks.gd の ORDERS["hook_hud"]。あとの仕組みは、前の仕組みが書いたあとの文を受け取る
func _sync_hooks() -> void:
	var legacy: Node = game.hud
	var me: Node = game.local_player()
	if me == null:
		return
	for feature: Object in game.hooks.in_order("hook_hud"):
		_apply_view(legacy, feature.hook_hud(me, legacy.target_label.text, legacy.keys.text))


# 仕組みの案内の1件を、狙った物の名前の欄と、操作の案内に反映する。空なら何もしない。
#   label：狙っている物の名前を、これに替える（操作の案内も keys_all に替える） / drop：名前の横から消す文 /
#   name・note：その名前の直後に足す文 / tail：最後に足す文 /
#   keys：操作の案内の先頭に足す文 / keys_all：操作の案内をまるごと差し替える文
func _apply_view(legacy: Node, view: Dictionary) -> void:
	if view.is_empty():
		return
	if view.has("label"):
		# 名前と操作を、まるごと差し替える（フック・掛けたロープ・爆弾の口 などを狙っている）
		legacy.target_label.text = str(view["label"])
		legacy.keys.text = str(view["keys_all"])
		return
	if legacy.target_label.text == "":
		# 何も狙っていない：持っている物の案内だけ出す
		if view.has("keys_all"):
			legacy.keys.text = str(view["keys_all"])
		return
	var text: String = legacy.target_label.text
	for old: String in view.get("drop", []):
		text = text.replace(old, "")
	if view.has("name") and view.has("note"):
		text = text.replace(str(view["name"]), str(view["name"]) + str(view["note"]))
	legacy.target_label.text = text + str(view.get("tail", ""))
	if view.has("keys_all"):
		legacy.keys.text = str(view["keys_all"])
	elif view.has("keys"):
		var rest: String = legacy.keys.text
		if str(view["keys"]).begins_with("F "):
			# F は仕組みの操作が先。その場所で開く画面（積み込み確認など）の案内は出さない
			for other: String in ["F 積み込み確認・出発", "F 発注する", "F 依頼を見る"]:
				rest = rest.replace(other, "左クリック 持つ")
		legacy.keys.text = str(view["keys"]) + " ／ " + rest


# 机の上の物（のぞき箱・発注の電話）に照準が合っているか。その間、名前の欄は机の物の名前のまま
func _on_desk() -> bool:
	return game.director != null and game.director.aimed() != ""


# 見立て：狙っている物（持っている物）の属性と役を名前の横に出し、操作の案内に Y を足す
func _sync_cast(production: Node, phase: int) -> void:
	var legacy: Node = game.hud
	var me: Node = game.local_player()
	if me == null or phase not in [2, 4] or game.state != game.S.PREP or me.operating != 0:
		return
	var subject: Node = game.props.get(me.held) if me.held != 0 else me.target
	if subject == null or not Cast.castable(subject.kind) or legacy.target_label.text == "":
		return
	var story: String = production.story()
	var tags: Array = production.cast_tags(subject)
	var attrs: Array = Cast.attrs(subject.kind, tags)
	var role: String = production.role_of(subject)
	# 「名前　[F] 操作」の形で来ることがあるので、操作は最後へ回す
	var text: String = legacy.target_label.text
	var action := ""
	var cut := text.find("　[F] ")
	if cut >= 0:
		action = text.substr(cut)
		text = text.substr(0, cut)
	text = text.replace("（Fでペイント）", "")
	if not attrs.is_empty():
		text += "　" + " ".join(attrs.map(func(a: String) -> String: return "〔%s〕" % a))
	if Cast.is_joker(subject.kind) and "blank" in tags:
		text += "（まだ白紙）"
	if role != "":
		# らしさは、台本を読める人にだけ（ほかの人は、監督に聞く）
		text += "　▶ %s" % Cast.role_title(role, story)
		if game.reads_script():
			text += "（%s）" % Cast.GRADES[Cast.fit(subject.kind, role, tags)]["name"]
	# 机の上の物を見ている間は、手に持った物の属性や役を、机の物の名前に足さない
	if not _on_desk():
		legacy.target_label.text = text + action
	if not Cast.locked(subject.kind):
		var next: String = Cast.cycle(subject.kind, story, role, tags, game.reads_script())
		legacy.keys.text = "Y 役を決める（次：%s） ／ " % Cast.role_title(next, story) + legacy.keys.text
	# 等身大パネルは、見て F で絵を描ける
	if game.cue_cards != null and me.held == 0 and subject == game.cue_cards.panel:
		legacy.keys.text = "F 絵を描く ／ " + legacy.keys.text


# キャラの特技：狙った物の名前の横と、操作の案内の先頭に K（仲間の頭を見ていれば F）を足す。段ボール頭の本人には、左下に頭の中身を出す
func _sync_talent(phase: int) -> void:
	var talent: Node = game.talent
	var legacy: Node = game.hud
	var me: Node = game.local_player()
	if talent == null or me == null:
		talent_slots.visible = false
		return
	var playing: bool = phase in [2, 3, 4] and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE] and game.menu_open == "" and not game.character_open and not game.help_open
	talent_slots.sync(playing and talent.cast_of(me.peer_id) == talent.BOX_HEAD, talent.slots(me))
	var hint: Dictionary = talent.hint(me)
	if str(hint["target"]) != "":
		# 仲間の頭を見ている：狙った相手の名前として出す
		legacy.target_label.text = str(hint["target"])
		legacy._tone(legacy.target_label, "on", FilmSet.tag_style())
	elif str(hint["label"]) != "" and legacy.target_label.text != "" and not _on_desk():
		legacy.target_label.text += str(hint["label"])
	if str(hint["keys"]) != "":
		legacy.keys.text = str(hint["keys"]) + " ／ " + legacy.keys.text


# 追加注文の1行を、撮影中の依頼パネルへ（「+150」だけ黄色）
func _sync_bonus(production: Node, show: bool) -> void:
	var hud: Node = game.hud
	hud.bonus_box.visible = show
	if not show:
		return
	var lines: PackedStringArray = str(production.bonus_status()).split("\n")
	var head: String = lines[0].replace("✔ ", "").replace("✔", "").trim_prefix("追加注文 +150コイン：")
	hud.bonus_text.text = head
	hud.bonus_sub.text = lines[1] if lines.size() > 1 else ""
	hud.bonus_sub.visible = hud.bonus_sub.text != ""


# 積み込みの文章を、チェック欄つきの行に組み直す（文章が変わったときだけ）
func _rebuild_packing(data: Dictionary) -> void:
	var sig := str(data)
	if sig == _packing_sig:
		return
	_packing_sig = sig
	for c in _packing_rows.get_children():
		if c != _packing_text:
			_packing_rows.remove_child(c)
			c.queue_free()
	# 会社の機材：積まなくても、出発するといっしょに運ばれる
	_packing_rows.add_child(_pack_head("会社の機材", "積まなくても、いっしょに運ばれる", UI.GREEN_LIGHT))
	for g: Array in data["gear"]:
		_packing_rows.add_child(_pack_line("✓", str(g[1]), int(g[2]), ""))
	_packing_rows.add_child(UI.gap(6))
	# 荷台：台本（1冊だけ。持つか積むかしないと、置いていく）と、積んだ物の名前
	var over: bool = int(data["used"]) > int(data["cap"])
	_packing_rows.add_child(_pack_head("荷台", "積んだ量 %d ／ %d" % [data["used"], data["cap"]], UI.STAMP_RED.lightened(0.25) if over else UI.MUTED))
	var book: Array = data["script"]
	if not book.is_empty():
		_packing_rows.add_child(_pack_line("✓" if book[2] else "□", str(book[1]), 1, "" if book[2] else "積み忘れ"))
	for item: Array in data["items"]:
		# ロープを掛けたかどうかは、ここには出さない（荷台を見て判断する）
		_packing_rows.add_child(_pack_line("✓", str(item[1]), int(item[2]), "落ちそう" if int(item[3]) > 0 else ""))
	if (data["items"] as Array).is_empty():
		_packing_rows.add_child(_label("廃材や借りた物は、まだ何も積んでいない。", 14, UI.MUTED, "body"))
	elif over:
		var warn := _label("はみ出した物は、道中の段差で落ちるかもしれない。降ろすか、ロープでしばろう（ロープは段ボール置き場）。", 14, UI.STAMP_RED.lightened(0.25), "body")
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size.x = LIST_W - 10
		_packing_rows.add_child(warn)
	# 配役表は、ここには出さない（何を何の役に使うかは、台本を持っている人だけが見られる。ほかの人は声で聞く）
	_fit_packing.call_deferred()


# 一覧の見出し（左に名前、右に小さな添え書き）
func _pack_head(title: String, aside: String, aside_color: Color) -> Control:
	var row := HBoxContainer.new()
	var t := FilmSet.label(title, 19, Color("ffe08a"), "stencil")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var a := _label(aside, 14, aside_color, "bold")
	a.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(a)
	return row


# 一覧の1行：赤ペンの印、名前、数、添え書き（落ちそう・積み忘れ）
func _pack_line(mark: String, name_text: String, count: int, warn: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var m := FilmSet.label(mark, 18, Color("7be08f") if mark == "✓" else Color(1, 1, 1, 0.7), "marker")
	m.custom_minimum_size.x = 18
	row.add_child(m)
	var n := FilmSet.label(name_text + ("　×%d" % count if count > 1 else ""), 16, UI.CLAP_WHITE, "marker")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(n)
	if warn != "":
		var w := _label(warn, 14, Color("ff8a7a"), "bold")
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(w)
	return row


# 一覧の高さは、カメラの高さに合わせる（多ければ一覧の中で流す）
func _fit_packing() -> void:
	await get_tree().process_frame
	var content: float = _packing_rows.get_combined_minimum_size().y
	var avail: float = game.get_viewport().get_visible_rect().size.y - 340.0
	_packing_scroll.custom_minimum_size.y = clampf(content + 4.0, 120.0, maxf(avail, 160.0))


func _panel(kind: String, anchor: int, position_at: Vector2, width: float, stripe: float = 0.0, taped: bool = true, mx: int = 18, my: int = 14) -> PanelContainer:
	var panel := UI.panel(kind, stripe, taped, mx, my)
	root.add_child(panel)
	panel.set_anchors_preset(anchor)
	panel.offset_left = position_at.x
	panel.offset_right = position_at.x + width
	panel.offset_top = position_at.y
	panel.offset_bottom = position_at.y
	if anchor in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		panel.offset_bottom = -24
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if anchor in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_TOP_RIGHT]:
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif anchor in [Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER_TOP]:
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _rows(panel: PanelContainer, separation: int = 12) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", separation)
	panel.add_child(rows)
	return rows


func _label(text: String, font_size: int, color: Color = UI.CLAP_WHITE, kind: String = "body") -> Label:
	var label := UI.label(text, font_size, color, kind)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _button(text: String, kind: String = "slate", font_size: int = 20, tall: int = 44) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	UI.style_button(button, kind, font_size, tall)
	return button
