extends CanvasLayer
# 制作班の移動と会計。撮影中の表示は既存の HUD に任せる。
# 見た目の方針は ui_theme.gd の先頭を参照。事務所・積み込み・精算も、撮影中と同じ暗い面で揃える。

const UI := preload("res://scripts/ui/ui_theme.gd")

const Catalog := preload("res://scripts/ui/order_catalog.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Scripts := preload("res://scripts/production_script.gd")
const Briefing := preload("res://scripts/ui/briefing.gd")
const ScriptPage := preload("res://scripts/ui/script_page.gd")
const TalentSlots := preload("res://scripts/ui/talent_slots.gd")
const SettingsSheet := preload("res://scripts/ui/settings_sheet.gd")
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
var _job_keys: Array = []          # 依頼の札の番号（見えている順に振り直す）
var _packing_rows: VBoxContainer
var _packing_sig := ""
var _packing_aside: Label
var _packing_sub: Label
var _packing_scroll: ScrollContainer
var _settled_notes: Label
var _settled_expense: Label
var _settled_wallet: Label
var _settled_bought: Label
var _settled_rent: Label
var _settled_next: Label
var _settled_head: Label
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
	_office = _panel("slate", Control.PRESET_TOP_LEFT, Vector2.ZERO, 820, 0.0, true, 24, 20)
	_center(_office, 820)
	var office_rows := _rows(_office, 16)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	office_rows.add_child(head)
	_office_head = _label("今日の一本", 32, UI.CLAP_WHITE, "display")
	head.add_child(_office_head)
	head.add_child(_label("依頼をクリックすると、依頼主との打ち合わせが始まる。", 15, UI.MUTED, "body"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows_n := ceili(jobs.size() / 2.0)
	scroll.custom_minimum_size = Vector2(0, mini(470, rows_n * 121 + maxi(rows_n - 1, 0) * 12))
	office_rows.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for index in jobs.size():
		var card := _job_card(index, jobs[index])
		grid.add_child(card)
		_job_cards.append(card)
	var foot := HBoxContainer.new()
	office_rows.add_child(foot)
	var office_character := UI.KeyButton.new().setup("キャラクターを選ぶ", "C", "slate", 15, 36)
	office_character.pressed.connect(func(): game.set_character_menu(true))
	foot.add_child(office_character)
	var office_close := _label("右クリック・Esc で閉じる", 13, UI.MUTED, "body")
	office_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	office_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	office_close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(office_close)


func _job_card(index: int, job: Dictionary) -> Control:
	var kaiju: bool = job.get("script", "castle") == "kaiju"
	var card := UI.ClickBox.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(380, 121)
	card.tooltip_text = str(job.get("description", ""))
	card.set_styles(UI.card_box(false, 16, 12), UI.card_box(true, 16, 12))
	card.pressed.connect(func(): game.open_brief(index))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	card.add_child(rows)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	rows.add_child(head)
	var key: Control = UI.KeyCap.new().setup(str(index + 1))
	_job_keys.append(key)
	head.add_child(key)
	var title := _label(str(job.get("title", "")), 20, UI.CLAP_WHITE, "bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.custom_minimum_size.x = 120
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	# 場面の多い依頼（5場面の完全版）は、場面の数を印にする
	var scene_count: int = (job.get("scenes", []) as Array).size()
	# カット割りの依頼（場面ごとにフィルムが止まる）は、そう書く。長回しとの違いが、ボードで分かるように
	var cut: bool = Scripts.cuts(index)
	var tag := UI.Stamp.new().setup(("カット割り %d" % scene_count) if cut else (("長回し %d" % scene_count) if scene_count > 3 else ("怪獣" if kaiju else "城")), 13, UI.TAPE if cut else (UI.STAMP_RED if kaiju else UI.MUTED))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	var scenes: Array = job.get("scenes", [])
	# 3場面は「→」でつないだ1つの流れ。折り返すときは場面の切れ目で
	var scene_line := HFlowContainer.new()
	scene_line.add_theme_constant_override("h_separation", 6)
	scene_line.add_theme_constant_override("v_separation", 0)
	scene_line.custom_minimum_size = Vector2(340, 38)
	scene_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for si in scenes.size():
		scene_line.add_child(_label(str(scenes[si]), 13, UI.MUTED, "body"))
		if si < scenes.size() - 1:
			scene_line.add_child(_label("→", 13, UI.MUTED, "body"))
	rows.add_child(scene_line)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	rows.add_child(foot)
	foot.add_child(_label("+150", 15, UI.TAPE, "bold"))
	var bonus := _label(str(job.get("bonus_title", "")), 15, UI.CLAP_WHITE, "body")
	bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus.custom_minimum_size.x = 60
	bonus.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(bonus)
	foot.add_child(_label("制作費 %d" % int(job.get("budget", 600)), 15, UI.CLAP_WHITE, "bold"))
	UI.ignore_mouse(card)
	return card


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


# 積み込み確認：チェック欄つきのリスト
func _build_packing() -> void:
	_packing = _panel("slate", Control.PRESET_TOP_LEFT, Vector2.ZERO, 640, 0.0, true, 28, 22)
	_center(_packing, 640)
	var packing_rows := _rows(_packing, 12)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	packing_rows.add_child(head)
	head.add_child(UI.overline("PACKING"))
	var title_row := HBoxContainer.new()
	head.add_child(title_row)
	var title := _label("積み込み確認", 24, UI.CLAP_WHITE, "display")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_packing_aside = _label("", 15, UI.MUTED, "body")
	_packing_aside.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(_packing_aside)
	_packing_sub = _label("", 15, UI.MUTED, "body")
	_packing_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_packing_sub.custom_minimum_size.x = 300
	head.add_child(_packing_sub)
	packing_rows.add_child(UI.hairline())
	_packing_scroll = ScrollContainer.new()
	_packing_scroll.custom_minimum_size.y = 240
	_packing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	packing_rows.add_child(_packing_scroll)
	_packing_rows = VBoxContainer.new()
	_packing_rows.add_theme_constant_override("separation", 8)
	_packing_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_packing_scroll.add_child(_packing_rows)
	_packing_text = _label("", 15, UI.MUTED)
	_packing_text.visible = false
	_packing_rows.add_child(_packing_text)
	packing_rows.add_child(UI.hairline())
	_crew = _label("", 17, UI.CLAP_WHITE, "bold")
	packing_rows.add_child(_crew)
	var note := _label("廃材は無料。荷台に積んだ物と手に持った物、それに会社の機材が現場へ行く。足りない機材は、事務所の机の電話か「機材レンタル」で発注する。", 15, UI.MUTED, "body")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 560
	packing_rows.add_child(note)
	_depart = _button("全員そろったら出発", "tape", 20, 52)
	_depart.pressed.connect(func(): game.rpc_id(1, "h_depart"))
	packing_rows.add_child(_depart)
	var packing_character := UI.KeyButton.new().setup("キャラクターを選ぶ", "C", "slate", 15, 36)
	packing_character.pressed.connect(func(): game.set_character_menu(true))
	packing_character.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	packing_rows.add_child(packing_character)


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


# 精算：興行収入
func _build_settled() -> void:
	_growth = _panel("slate", Control.PRESET_TOP_LEFT, Vector2(24, 140), 480, 0.0, true, 24, 20)
	var growth_rows := _rows(_growth, 14)
	growth_rows.add_child(_label("今回のスタッフ成長", 24, UI.CLAP_WHITE, "display"))
	growth_rows.add_child(UI.hairline())
	_growth_text = _label("", 16, UI.CLAP_WHITE)
	_growth_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_growth_text.custom_minimum_size.x = 432
	growth_rows.add_child(_growth_text)
	growth_rows.add_child(_label("H → スタッフスキルで確認・装備\nキャラや会社が変わっても成長は引き継ぎます。", 14, UI.MUTED))
	_settled = _panel("slate", Control.PRESET_BOTTOM_RIGHT, Vector2(-504, -470), 480, 0.0, true, 24, 20)
	var settled_rows := _rows(_settled, 12)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	settled_rows.add_child(head)
	head.add_child(UI.overline("BOX OFFICE"))
	_settled_head = _label("おつかれさま、制作班！", 24, UI.CLAP_WHITE, "display")
	head.add_child(_settled_head)
	settled_rows.add_child(UI.hairline())
	var hero := VBoxContainer.new()
	hero.add_theme_constant_override("separation", 0)
	settled_rows.add_child(hero)
	hero.add_child(_label("ギャラ（出来に応じて）", 15, UI.MUTED, "body"))
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 10)
	hero.add_child(hero_row)
	_settled_pay = _label("", 48, UI.CLAP_WHITE, "display")
	hero_row.add_child(_settled_pay)
	var unit_box := MarginContainer.new()
	unit_box.add_theme_constant_override("margin_bottom", 12)
	unit_box.size_flags_vertical = Control.SIZE_SHRINK_END
	unit_box.add_child(_label("コイン", 17, UI.MUTED, "body"))
	hero_row.add_child(unit_box)
	var ledger := VBoxContainer.new()
	ledger.add_theme_constant_override("separation", 0)
	settled_rows.add_child(ledger)
	_settled_expense = _ledger_row(ledger, "浮かせた制作費", false)
	_settled_bought = _ledger_row(ledger, "買った物（貯金から。支払い済み）", false)
	_settled_rent = _ledger_row(ledger, "家賃", false)
	ledger.add_child(UI.hairline())
	_settled_wallet = _ledger_row(ledger, "会社の貯金", true)
	_settled_next = _label("", 14, UI.MUTED, "body")
	ledger.add_child(_settled_next)
	settled_rows.add_child(UI.hairline())
	_settled_note_box = VBoxContainer.new()
	(_settled_note_box as VBoxContainer).add_theme_constant_override("separation", 6)
	settled_rows.add_child(_settled_note_box)
	_settled_note_box.add_child(UI.overline("こぼれ話"))
	_settled_notes = _label("", 15, UI.CLAP_WHITE, "body")
	_settled_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settled_notes.custom_minimum_size.x = 432
	_settled_note_box.add_child(_settled_notes)
	_settled_folder = UI.KeyButton.new().setup("保存した8コマのフォルダを開く", "O", "slate", 15, 36)
	_settled_folder.pressed.connect(func(): game.production_export.open_saved())
	_settled_folder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settled_rows.add_child(_settled_folder)
	var return_button := _button("事務所へ戻って、次の一本", "tape", 20, 52)
	return_button.pressed.connect(func(): game.rpc_id(1, "h_return_office"))
	settled_rows.add_child(return_button)
	_settled_return = return_button


func _ledger_row(parent: Control, caption: String, strong: bool) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	parent.add_child(row)
	var cap := _label(caption, 15, UI.MUTED, "body")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var value := _label("", 17, UI.CLAP_WHITE, "bold" if strong else "body")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
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
			line = ("F 台本を閉じる" if game.script_open else "F 台本を開く") + "\n" + game.hold_hint()
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
		if me and game.holding_script():
			legacy.keys.text = ("F 台本を閉じる" if game.script_open else "F 台本を開く") + "\n" + game.hold_hint()
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
		_office_head.text = "初仕事" if production.day <= 1 else "%d日目の一本" % production.day
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
		_settled_return.text = "新しい会社を立ち上げる" if production.bankrupt else "事務所へ戻って、次の一本"
		_settled_next.visible = production.hazards and not production.bankrupt
		if _settled_next.visible:
			var left: int = production.RENT_EVERY if production.rent_paid > 0 else production.rent_in() - 1
			_settled_next.text = "次の家賃：%d コイン（あと%d本）" % [production.rent_amount(), left]
		_settled_notes.text = observations
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
	var gear_head := HBoxContainer.new()
	var gear_title := UI.overline("会社の機材")
	gear_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_head.add_child(gear_title)
	gear_head.add_child(_label("積まなくていい。出発すると、いっしょに運ばれる", 14, UI.GREEN_LIGHT, "bold"))
	_packing_rows.add_child(gear_head)
	var gear_grid := GridContainer.new()
	gear_grid.columns = 7
	gear_grid.add_theme_constant_override("h_separation", 10)
	gear_grid.add_theme_constant_override("v_separation", 10)
	_packing_rows.add_child(gear_grid)
	for g: Array in data["gear"]:
		gear_grid.add_child(Catalog.tile(str(g[0]), str(g[1]), int(g[2]), 72.0, true))
	_packing_rows.add_child(UI.gap(2))
	_packing_rows.add_child(UI.hairline())
	# 荷台：台本（1冊だけ。持つか積むかしないと、置いていく）と、積んだ物を写真で並べる
	var bed_head := HBoxContainer.new()
	var bed_title := UI.overline("荷台")
	bed_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bed_head.add_child(bed_title)
	var over: bool = int(data["used"]) > int(data["cap"])
	bed_head.add_child(_label("積んだ量 %d / %d" % [data["used"], data["cap"]], 14, UI.STAMP_RED.lightened(0.25) if over else UI.MUTED, "bold"))
	_packing_rows.add_child(bed_head)
	var gauge := UI.ThinBar.new()
	gauge.set_value(float(data["used"]), float(data["cap"]), UI.STAMP_RED if over else UI.CLAP_WHITE)
	_packing_rows.add_child(gauge)
	var bed := GridContainer.new()
	bed.columns = 7
	bed.add_theme_constant_override("h_separation", 10)
	bed.add_theme_constant_override("v_separation", 10)
	_packing_rows.add_child(bed)
	var book: Array = data["script"]
	if not book.is_empty():
		bed.add_child(Catalog.tile(str(book[0]), str(book[1]) if book[2] else "積み忘れ", 1, 72.0, true, not book[2]))
	for item: Array in data["items"]:
		# ロープを掛けたかどうかは、ここには出さない（荷台を見て判断する）
		var bed_tile: Control = Catalog.tile(str(item[0]), str(item[1]), int(item[2]), 72.0, true, false, "落ちそう" if int(item[3]) > 0 else "")
		bed.add_child(bed_tile)
	if (data["items"] as Array).is_empty():
		var empty := _label("廃材や借りた物は、まだ何も積んでいない。", 14, UI.MUTED, "body")
		_packing_rows.add_child(empty)
	elif over:
		var warn := _label("はみ出した物は、道中の段差で落ちるかもしれない。降ろすか、ロープでしばろう（ロープは段ボール置き場）。", 14, UI.STAMP_RED.lightened(0.25), "body")
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size.x = 560
		_packing_rows.add_child(warn)
	# 配役表は、ここには出さない（何を何の役に使うかは、台本を持っている人だけが見られる。ほかの人は声で聞く）
	_fit_packing.call_deferred()


# 中身の高さに合わせて、画面に収まる範囲でリストの高さを決める（並べ終わってから測る）
func _fit_packing() -> void:
	await get_tree().process_frame
	var avail: float = game.get_viewport().get_visible_rect().size.y - 24.0 - 16.0 - 490.0
	var content: float = _packing_rows.get_combined_minimum_size().y
	_packing_scroll.custom_minimum_size.y = clampf(content + 4.0, 120.0, maxf(avail, 170.0))


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
