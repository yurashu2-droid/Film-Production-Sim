extends Control
# 機材レンタルのカタログ（発注画面）。激安レンタル屋の折り込みチラシと、右の切り取りの注文票。
#   ・暗くした画面の上に、チラシ（黄色い安い紙・赤と黒の2色刷り）と注文票の紙をじかに置く（外側の枠は無い）
#   ・写真は tools/render_catalog.gd が実物の3Dモデルから撮ったもの（assets/ui/catalog）
#   ・品物をクリックで入れる／外す。入れた品物は赤ペンで丸く囲む。火薬の袋だけは −／＋ で数を決める
#   ・くり返し使える物は、品物の下で「借りる（制作費から）／買う（会社の貯金から）」を選ぶ。
#     買った物は会社の持ち物になり、次からは「持っている」と出て、注文の対象から外れる
#   ・右は注文票と値段だけ。配役表・今日の廃材の一覧・場面の並びは出さない（発注する人は、現物の一覧を見られない。
#     廃材置き場に何が在るかは、集めに行った人に聞く）
#   ・飾りの星・丸は、品物の情報から言える事だけ（いちばん安い・1袋ずつ・説明の一言）
const UI := preload("res://scripts/ui/ui_theme.gd")
const Cast := preload("res://scripts/production_cast.gd")
const THUMBS := "res://assets/ui/catalog/"
const PHOTO := {"balcony": "set_balcony", "fx": "fx", "refill": "fx_powder", "fuse": "fx_fuse", "dolly": "dolly", "fix": "sandbag", "rose": "rose"}
const PAPER_TILE := Color("e4e1d8")
const SLIP_W := 300.0
# 飾り（品物の説明から言える一言だけ）。いちばん安い品物には、ほかに「最安」の星が付く
const BADGES := {"balcony": ["star", "置くだけで\n城！"], "refill": ["round", "1袋\nずつ"]}
const RED := Color("d63a26")
const INK := Color("1c1a17")
const SOFT := Color("4a453d")

var game: Node
var rows: Array = []            # カードごとの部品（hud._opt_rows と同じ並び）
var confirm: Button

var _panel: Control               # チラシと注文票を並べる置き場（地は透明）
var _flyer: PanelContainer
var _head: Control
var _scroll: ScrollContainer      # レンタルと備品のカードの欄（画面に入りきらないと、中で流す）
var _title: Label
var _sub: Label
var _wallet: Label
var _wallet_cap: Label
var _savings: Label
var _savings_box: Control
var _total_cap: Label
var _paid: Label
var _paid_row: Control
var _grid: GridContainer
var _job_title: Label
var _job_sub: Label
var _lines: VBoxContainer
var _total: Label
var _after: Label
var _after_cap: Label
var _skip: Button
var _ask: Label
var _gear: VBoxContainer
var _gear_sig := ""
var _sig := ""
static var _cache := {}


static func thumb(kind: String) -> Texture2D:
	if not _cache.has(kind):
		var path := THUMBS + kind + ".png"
		_cache[kind] = load(path) if ResourceLoader.exists(path) else null
	return _cache[kind]


# 写真の札（積み込み確認の、機材と荷台で使う）
#   named：下に名前を出す / missing：まだ無い物として薄く出す
static func tile(kind: String, label: String, count: int = 1, px: float = 42.0, named: bool = false, missing: bool = false, warn: String = "") -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(px, px)
	var pad := 3 if px < 50.0 else 6
	frame.add_theme_stylebox_override("panel", UI.box(PAPER_TILE, Color(0, 0, 0, 0), 0, 3, pad, pad))
	frame.tooltip_text = label + ("　×%d" % count if count > 1 else "")
	var attrs: Array = Cast.attrs(kind)
	if not attrs.is_empty():
		frame.tooltip_text += "\n" + " ".join(attrs.map(func(a: String) -> String: return "〔%s〕" % a))
	var pic := TextureRect.new()
	pic.texture = thumb(kind)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	if count > 1:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UI.box(UI.INK, Color(0, 0, 0, 0), 0, 3, 5, 0))
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		badge.size_flags_vertical = Control.SIZE_SHRINK_END
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(UI.label("×%d" % count, 12, UI.CLAP_WHITE, "bold"))
		frame.add_child(badge)
	if missing:
		frame.modulate = Color(1, 1, 1, 0.28)
	if not named:
		return frame
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size.x = px
	col.add_child(frame)
	var name_label := UI.label(warn if warn != "" else label, 12, UI.STAMP_RED.lightened(0.25) if missing or warn != "" else UI.MUTED, "bold" if warn != "" else "body")
	name_label.custom_minimum_size.x = px
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	col.add_child(name_label)
	return col


# 字（色はここで決める。紙の色への塗り替え：FilmSet.paperize は、この画面には要らない）
static func _ink(text: String, px: int, color: Color, kind: String) -> Label:
	var l: Label
	if kind in ["marker", "stencil", "mincho", "mono"]:
		l = FilmSet.label(text, px, color, kind)
	else:
		l = UI.label(text, px, color, kind)
	return l


static func _paint(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color)


func build(owner_game: Node) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	# 置き場：チラシ（左）と注文票（右）。置き場そのものは描かない
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 18)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = holder
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	# ---- チラシ ----
	_flyer = PanelContainer.new()
	_flyer.add_theme_stylebox_override("panel", FlyerStyle.new())
	_flyer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flyer.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(_flyer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_flyer.add_child(col)

	# 見出し：左に店の名前と、いまの画面の札。右に財布（制作費と会社の貯金）
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	_head = head
	var head_l := VBoxContainer.new()
	head_l.add_theme_constant_override("separation", 2)
	head_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_l)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 16)
	head_l.add_child(name_row)
	var shop := _ink("格安レンタル", 50, RED, "stencil")
	shop.add_theme_color_override("font_shadow_color", INK)
	shop.add_theme_constant_override("shadow_offset_x", 3)
	shop.add_theme_constant_override("shadow_offset_y", 3)
	name_row.add_child(shop)
	_title = _ink("機材レンタル", 18, Color("ffd43b"), "stencil")
	var tag := StyleBoxFlat.new()
	tag.bg_color = INK
	tag.content_margin_left = 10
	tag.content_margin_right = 10
	tag.content_margin_top = 2
	tag.content_margin_bottom = 4
	_title.add_theme_stylebox_override("normal", tag)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_title)
	_sub = _ink("", 14, INK, "mincho")
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size.x = 360
	head_l.add_child(_sub)
	# 財布は2つ：会社の貯金（買う物）と、この依頼の制作費（借りる物・火薬）。黒い枠の囲みに
	var purse := PanelContainer.new()
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(1, 1, 1, 0.55)
	pb.border_color = INK
	pb.set_border_width_all(2)
	pb.content_margin_left = 12
	pb.content_margin_right = 12
	pb.content_margin_top = 6
	pb.content_margin_bottom = 6
	purse.add_theme_stylebox_override("panel", pb)
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(purse)
	var purse_col := VBoxContainer.new()
	purse_col.add_theme_constant_override("separation", 0)
	purse.add_child(purse_col)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 10)
	purse_col.add_child(wallet_row)
	_wallet_cap = _ink("会社の残金", 14, INK, "mincho")
	_wallet_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_row.add_child(_wallet_cap)
	_wallet = _ink("", 26, RED, "stencil")
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_row.add_child(_wallet)
	var savings_row := HBoxContainer.new()
	savings_row.add_theme_constant_override("separation", 10)
	purse_col.add_child(savings_row)
	var savings_cap := _ink("会社の貯金（買う物）", 14, INK, "mincho")
	savings_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	savings_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	savings_row.add_child(savings_cap)
	_savings = _ink("", 26, INK, "stencil")
	_savings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	savings_row.add_child(_savings)
	_savings_box = savings_row
	col.add_child(DoubleRule.new())

	# 品物の欄。品数が多いと、画面の下からはみ出す。この欄だけを、画面に入る高さで流せるようにする（_fit）
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_scroll(_scroll)
	col.add_child(_scroll)
	var pad := MarginContainer.new()               # 赤ペンの丸と飾りの星が、流す欄の端で切れないように
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	_scroll.add_child(pad)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(left)
	_grid = GridContainer.new()
	# 品数が6つまでは2列、9つまでは3列、それより多ければ4列
	_grid.columns = 2 if game.OPTIONS.size() <= 4 else (3 if game.OPTIONS.size() <= 9 else 4)
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_grid)
	var cheapest := ""
	var low := 1 << 30
	for o: Dictionary in game.OPTIONS:
		if int(o["cost"]) < low:
			low = int(o["cost"])
			cheapest = str(o["id"])
	for i in game.OPTIONS.size():
		_grid.add_child(_card(i, str(game.OPTIONS[i]["id"]) == cheapest))
	_gear = VBoxContainer.new()
	_gear.visible = false
	left.add_child(_gear)

	# ---- 注文票（切り取り線で囲んだ、白い紙） ----
	holder.add_child(_slip())
	_seal(self)
	visible = false
	resized.connect(_fit)
	_fit()


# この画面の字と紙の色は、ここで決めてある。あとから紙の塗り替え（FilmSet.paperize）が掛かっても変えない
func _seal(n: Node) -> void:
	n.set_meta("papered", true)
	for c in n.get_children(true):
		_seal(c)


func _style_scroll(s: ScrollContainer) -> void:
	var bar := s.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.08)
	track.content_margin_left = 5
	track.content_margin_right = 5
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(INK, 0.6)
	grab.content_margin_left = 5
	grab.content_margin_right = 5
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)


# 画面の広さに合わせて、チラシと注文票の幅を決める（狭い画面では品物を細くする）
func _fit() -> void:
	var w := clampf(size.x - 60.0, 980.0, minf(1340.0, size.x - 24.0))
	_panel.custom_minimum_size.x = w
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5
	# 縦：見出しと余白のぶんを引いた高さまで（それより長い一覧は、中で流す）
	if _scroll != null and size.y > 0.0:
		var need: float = (_scroll.get_child(0) as Control).get_combined_minimum_size().y
		var paper := _flyer.get_theme_stylebox("panel")
		var fixed: float = _head.get_combined_minimum_size().y + 8.0 * 2.0 + 10.0 + paper.content_margin_top + paper.content_margin_bottom
		# 上下には、上の帯（撮影カメラの枠）と重ならない余白を残す
		_scroll.custom_minimum_size.y = minf(need, maxf(240.0, size.y - 120.0 - fixed))
	_panel.offset_top = 18
	_panel.offset_bottom = 18


func _card(i: int, cheapest: bool) -> Control:
	var o: Dictionary = game.OPTIONS[i]
	var many: bool = int(o["max"]) > 1
	var cb := UI.ClickBox.new()
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cb.custom_minimum_size = Vector2(200, 0)
	cb.set_styles(_card_box(Color(0, 0, 0, 0)), _card_box(Color(1, 1, 1, 0.32)), _card_box(Color(1, 1, 1, 0.2)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	cb.add_child(v)

	# 写真：白い地に実物（チラシの商品写真）
	var photo := PanelContainer.new()
	photo.custom_minimum_size.y = 84
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("fffdf4")
	ps.border_color = Color(INK, 0.55)
	ps.set_border_width_all(1)
	ps.content_margin_left = 6
	ps.content_margin_right = 6
	ps.content_margin_top = 6
	ps.content_margin_bottom = 6
	photo.add_theme_stylebox_override("panel", ps)
	v.add_child(photo)
	var pic := TextureRect.new()
	pic.texture = thumb(str(PHOTO.get(o["id"], o["id"])))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.add_child(pic)
	# 飾りの星・丸（写真の左上の角にかける。置き場はただの Control なので、傾けたまま置ける）
	var deco: Array = BADGES.get(o["id"], ["star", "最安"] if cheapest else [])
	if not deco.is_empty():
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.add_child(slot)
		var round: bool = deco[0] == "round"
		var long: bool = str(deco[1]).length() > 4
		var badge := CatalogPrint.Badge.new().setup(str(deco[1]), str(deco[0]), (92.0 if long else 76.0) if not round else 66.0, 16 if long else 20,
			Color("ffd43b") if not round else RED, RED if not round else Color("fff6dc"), -12.0 if not round else 8.0)
		badge.face = UI.fnt("display")
		badge.position = Vector2(-24, -12)
		slot.add_child(badge)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	v.add_child(name_row)
	var name_label := _ink(str(o["name"]).trim_prefix("借りる"), 17, INK, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_END
	name_label.custom_minimum_size.x = 60
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(name_label)
	var price := _ink(str(o["cost"]), 30, RED, "stencil")
	price.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(price)
	var unit := _ink("コイン", 12, INK, "mincho")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(unit)
	var desc := _ink(str(o["desc"]), 12, SOFT, "mincho")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(120, 30)
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.tooltip_text = str(o["desc"])
	v.add_child(desc)

	# いちばん下の1行：いまの状態。充填だけは数を選ぶ
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	foot.custom_minimum_size.y = 28
	v.add_child(foot)
	var state := _ink("", 13, SOFT, "bold")
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 文の長さでカードの幅が変わらないようにする（列の幅をそろえる）
	state.custom_minimum_size.x = 40
	state.clip_text = true
	foot.add_child(state)
	UI.ignore_mouse(cb)
	var minus: Button = null
	var plus: Button = null
	if many:
		minus = _step("−")
		plus = _step("＋")
		foot.add_child(minus)
		foot.add_child(plus)
		minus.pressed.connect(func() -> void: _add(i, -1))
		plus.pressed.connect(func() -> void: _add(i, 1))
	# くり返し使える物：借りるか、買うか（値段つきの2つのボタン）
	var rent: Button = null
	var buy: Button = null
	if o.get("buy", false) and not o.get("used_up", false):
		rent = _pick("借りる %d" % int(o["cost"]), "制作費から払う。依頼が終わると返す")
		buy = _pick("買う %d" % int(game.buy_price(o)), "会社の貯金から払う。次の依頼からも会社に在る")
		foot.add_child(rent)
		foot.add_child(buy)
		rent.pressed.connect(func() -> void: _toggle(i))
		buy.pressed.connect(func() -> void: _buy(i))
	# 会社がもう持っている物：ボタンの代わりに、赤い枠の札を出す
	var own := PanelContainer.new()
	var os := StyleBoxFlat.new()
	os.bg_color = Color(1, 1, 1, 0.4)
	os.border_color = RED
	os.set_border_width_all(2)
	os.content_margin_left = 6
	os.content_margin_right = 6
	own.add_theme_stylebox_override("panel", os)
	own.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own.custom_minimum_size.y = 28
	own.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own.visible = false
	var own_text := _ink("持っている", 14, RED, "bold")
	own_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	own.add_child(own_text)
	foot.add_child(own)
	# 入れた品物を囲む赤ペンの丸（カードのいちばん上に重ねる）
	var mark := CatalogPrint.PenRing.new()
	mark.seed = 11 + i * 37
	mark.pad = Vector2(12, 10)
	mark.width = 3.2
	cb.add_child(mark)
	cb.hovered.connect(func() -> void: game.order_cursor = i)
	cb.pressed.connect(func() -> void: _toggle(i))
	rows.append({"box": cb, "mark": mark, "state": state, "price": price, "unit": unit, "minus": minus, "plus": plus, "pic": pic, "rent": rent, "buy": buy, "own": own})
	return cb


func _card_box(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(INK, 0.28)
	s.border_width_bottom = 1
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	return s


# 刷った小さな枠のボタン。on：赤く塗る / 足りない：赤い字で、押せない
func _print_button(b: Button, on: bool, px: int = 13) -> void:
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(2 if not on else 0)
		s.content_margin_left = 6
		s.content_margin_right = 6
		s.content_margin_top = 2
		s.content_margin_bottom = 3
		return s
	var base := RED if on else Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", mk.call(base, INK))
	b.add_theme_stylebox_override("hover", mk.call(RED.lightened(0.12) if on else Color(1, 1, 1, 0.8), RED))
	b.add_theme_stylebox_override("pressed", mk.call(RED.darkened(0.15) if on else Color(1, 1, 1, 0.6), INK))
	b.add_theme_stylebox_override("hover_pressed", mk.call(RED.darkened(0.15), INK))
	b.add_theme_stylebox_override("disabled", mk.call(Color(1, 1, 1, 0.15), Color(INK, 0.25)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := Color("fff6dc") if on else INK
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, ink)
	b.add_theme_color_override("font_disabled_color", Color(RED, 0.75))
	b.add_theme_font_override("font", UI.fnt("bold"))
	b.add_theme_font_size_override("font_size", px)
	b.custom_minimum_size.y = 28


# 「借りる」「買う」のボタン
func _pick(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.visible = false
	_set_pick(b, false, false)
	return b


# on：選んである（赤く塗る）/ short：お金が足りない（赤い字で、押せない）
func _set_pick(b: Button, on: bool, short: bool) -> void:
	var look := "on" if on else ("short" if short else "off")
	if b.has_meta("look") and str(b.get_meta("look")) == look:
		return
	b.set_meta("look", look)
	_print_button(b, on)
	b.disabled = short and not on


func _step(text: String) -> Button:
	var b := Button.new()
	b.text = text
	_print_button(b, false, 15)
	b.custom_minimum_size = Vector2(32, 28)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _slip() -> Control:
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", SlipStyle.new())
	paper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size.x = SLIP_W
	paper.add_child(v)
	var title := _ink("注文票", 30, RED, "mincho")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_ink("今日の一本", 13, RED, "mincho"))
	_job_title = _ink("", 21, INK, "marker")
	_job_title.custom_minimum_size.x = SLIP_W
	_job_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_job_title)
	_job_sub = _ink("", 14, SOFT, "marker")
	_job_sub.custom_minimum_size.x = SLIP_W
	_job_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_job_sub)
	# 発注する人（監督）への一言。現物の一覧は、ここには出さない
	_ask = _ink("廃材置き場に何が在るかは、ここからは見えない。集めに行った人に、声で聞こう。", 13, SOFT, "mincho")
	_ask.custom_minimum_size.x = SLIP_W
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_ask)
	v.add_child(UI.gap(4))
	var items_cap := _ink("品名　　　　　　　　　　　金額", 13, RED, "mincho")
	v.add_child(items_cap)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 2)
	_lines.custom_minimum_size.y = 120
	v.add_child(_lines)
	var total_row := _pair("合計", 20, "bold")
	_total = total_row[1]
	_total_cap = total_row[2]
	v.add_child(total_row[0])
	var paid_row := _pair("貯金から（買う物）", 15, "body")
	_paid = paid_row[1]
	_paid_row = paid_row[0]
	_paid_row.visible = false
	v.add_child(_paid_row)
	var after_row := _pair("支払い後の残金", 15, "body")
	_after_cap = after_row[2]
	_after = after_row[1]
	v.add_child(after_row[0])
	v.add_child(UI.gap(6))
	confirm = UI.KeyButton.new().setup("この内容で借りる", "Enter", "slate", 18, 48)
	_style_main(confirm as UI.KeyButton)
	confirm.pressed.connect(func() -> void: game.h_order_confirm.rpc_id(1))
	v.add_child(confirm)
	# 決めずに閉じる（制作モードだけ）。選びかけの注文は、前に決めた注文へ戻る
	_skip = UI.KeyButton.new().setup("閉じる（注文は変えない）", "Esc", "slate", 15, 36)
	_print_button(_skip, false, 15)
	_fit_cap(_skip as UI.KeyButton, INK)
	_skip.pressed.connect(_close)
	v.add_child(_skip)
	return paper


# 注文するボタン：赤く刷った四角に、白い字
func _style_main(b: UI.KeyButton) -> void:
	for part: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": RED, "hover": RED.lightened(0.1), "pressed": RED.darkened(0.15), "hover_pressed": RED.darkened(0.15), "disabled": Color(RED, 0.4)}[part]
		s.border_color = INK
		s.border_width_bottom = 3
		s.content_margin_left = 16
		s.content_margin_top = 6
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(part, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color("fff6dc"))
	b.add_theme_font_override("font", UI.fnt("display"))
	_fit_cap(b, Color("fff6dc"))


# キーの印（Enter・Esc）のぶん、右の余白をあけ直す。印の色も紙に合わせる
func _fit_cap(b: UI.KeyButton, ink: Color) -> void:
	if b.cap == null:
		return
	b.cap.ink = ink
	b.cap.line = Color(ink, 0.6)
	for part: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := b.get_theme_stylebox(part)
		if s != null:
			s.content_margin_left = 16
			s.content_margin_right = 16 + b.cap.custom_minimum_size.x + 8.0


# 左に名前、右に数字の1行（下に罫線）。[行, 数字, 名前]
func _pair(text: String, px: int, kind: String) -> Array:
	var row := CatalogPrint.RuledRow.new()
	row.dotted = kind != "bold"
	row.line = Color(RED, 0.55)
	var cap := _ink(text, px - 2 if kind == "bold" else px - 1, RED if kind == "bold" else SOFT, "mincho")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(cap)
	var num := _ink("", px + 2, INK, "marker")
	row.add_child(num)
	return [row, num, cap]


func _toggle(i: int) -> void:
	game.order_cursor = i
	var o: Dictionary = game.OPTIONS[i]
	if game.owns(o["id"]):
		return
	# 「買う」にしてあるカードをクリックしたら、買うのをやめる
	if int(game.buying.get(o["id"], 0)) > 0:
		game.h_order_buy.rpc_id(1, o["id"], false)
		return
	var have: int = game.order.get(o["id"], 0)
	game.h_order_set.rpc_id(1, o["id"], 0 if have >= int(o["max"]) else have + 1)


func _buy(i: int) -> void:
	game.order_cursor = i
	var o: Dictionary = game.OPTIONS[i]
	game.h_order_buy.rpc_id(1, o["id"], int(game.buying.get(o["id"], 0)) == 0)


func _add(i: int, step: int) -> void:
	game.order_cursor = i
	var o: Dictionary = game.OPTIONS[i]
	var have: int = game.order.get(o["id"], 0)
	game.h_order_set.rpc_id(1, o["id"], clampi(have + step, 0, int(o["max"])))


# 決めずに閉じる（制作モード。Esc・右クリックでも同じ：production_main.gd）。撮影だけモードには、閉じる先が無い
func _close() -> void:
	if game.has_method("h_order_close"):
		game.h_order_close.rpc_id(1)


func sync(prod: Node) -> void:
	if visible:
		_fit.call_deferred()                     # 備品の行の出し入れで高さが変わる
	var used: int = game.order_cost()            # 制作費から払う分（借りる物・火薬）
	var paid: int = game.savings_cost()          # 会社の貯金から払う分（買う物）
	var limit: int = game.BUDGET
	var purse := 0
	if prod != null:
		limit = int(prod.budget())
		purse = int(prod.wallet)
		var job: Dictionary = prod.job()
		_title.text = "機材レンタル"
		_sub.text = "借りる物と火薬は制作費から。買う物は貯金から払い、次の依頼からも会社に在る。廃材は無料。"
		_wallet_cap.text = "この依頼の制作費（借りる物）"
		_wallet.text = "%d コイン" % limit
		_savings.text = "%d コイン" % purse
		_job_title.text = str(job["title"])
		_job_sub.text = str(prod.location_name())
		confirm.text = "この内容で注文する"
		_after_cap.text = "浮く分（会社の儲け）"
		_after.text = "+%d" % maxi(0, limit - used)
	else:
		_title.text = "機材を選ぶ"
		_sub.text = "制作費の中で借りる物を選ぶ。廃材置き場に出ている物は無料。"
		_wallet_cap.text = "制作費"
		_wallet.text = "%d コイン" % limit
		_job_title.text = str(game.film_title())
		_job_sub.text = " → ".join(game.scene_titles())
		confirm.text = "この内容で現場へ"
		_after_cap.text = "制作費の残り"
		_after.text = "%d" % (limit - used)
	_skip.visible = prod != null
	_ask.visible = prod != null
	_savings_box.visible = prod != null
	_total_cap.text = "制作費から" if prod != null else "合計"
	_total.text = "%d" % used
	_paid_row.visible = paid > 0
	_paid.text = "%d（残り %d）" % [paid, purse - paid]
	_paint(_after, RED if limit - used < 0 else INK)

	var has_bomb: bool = int(game.order.get("fx", 0)) > 0 or game.buying.has("fx") or game.owns("fx")
	for i in rows.size():
		var o: Dictionary = game.OPTIONS[i]
		var r: Dictionary = rows[i]
		var id: String = o["id"]
		var n: int = game.order.get(id, 0)
		var many: bool = int(o["max"]) > 1
		var own: bool = game.owns(id)                                   # もう会社が持っている
		var buy_on: bool = int(game.buying.get(id, 0)) > 0              # 今回「買う」にした
		var choice: bool = r["rent"] != null and game.can_buy(o) and not own   # 「借りる／買う」を選ぶカード
		var usable: bool = not (id in ["refill", "fuse"] and not has_bomb)
		var short: bool = n == 0 and used + int(o["cost"]) > limit
		var poor: bool = not buy_on and paid + int(game.buy_price(o)) > purse
		var picked: bool = n > 0 or buy_on
		var cb: UI.ClickBox = r["box"]
		cb.set_active(picked)
		cb.modulate.a = 1.0 if usable else 0.5
		(r["mark"] as CatalogPrint.PenRing).set_on(picked)
		var state: Label = r["state"]
		state.visible = not choice and not own
		(r["own"] as Control).visible = own
		(r["price"] as Label).visible = not choice and not own
		(r["unit"] as Label).visible = not choice and not own
		if r["rent"] != null:
			(r["rent"] as Button).visible = choice
			(r["buy"] as Button).visible = choice
			_set_pick(r["rent"], n > 0, short)
			_set_pick(r["buy"], buy_on, poor)
		if own:
			state.text = "持っている"
		elif not usable:
			state.text = "爆弾が必要"
		elif short:
			state.text = "制作費が足りない"
		elif many:
			state.text = "%s　×%d" % [str(o.get("unit", "買う")), n]      # unit：数え方（役者は「雇う」）
		else:
			state.text = "注文に入れた" if n > 0 else "クリックで入れる"
		_paint(state, INK if n > 0 else (RED if short and usable else SOFT))
		# 制作費が足りない値段は、少し薄く
		(r["price"] as Label).modulate.a = 0.4 if short else 1.0
		if many:
			(r["minus"] as Button).disabled = n <= 0
			(r["plus"] as Button).disabled = n >= int(game.order_max(o)) or not usable

	# 注文票の行（中身が変わったときだけ組み直す）。品名と金額は、手書きで
	var sig := str(game.order) + str(game.buying) + str(prod != null)
	if sig != _sig:
		_sig = sig
		for c in _lines.get_children():
			c.queue_free()
		var any := false
		for o: Dictionary in game.OPTIONS:
			var n: int = game.order.get(o["id"], 0)
			var bought: bool = int(game.buying.get(o["id"], 0)) > 0
			if n <= 0 and not bought:
				continue
			any = true
			var item := str(o["name"]).trim_prefix("借りる")
			var row := _pair(item + "（買う）" if bought else item + ("　×%d" % n if n > 1 else ""), 15, "body")
			var cap: Label = row[2]
			cap.add_theme_font_override("font", FilmSet.font("marker"))
			cap.add_theme_font_size_override("font_size", 17)
			_paint(cap, INK)
			cap.clip_text = true
			cap.custom_minimum_size.x = 120
			(row[1] as Label).text = "貯金 %d" % int(game.buy_price(o)) if bought else "%d" % (int(o["cost"]) * n)
			_lines.add_child(row[0])
			_seal(row[0])
		if not any:
			var none := _ink("まだ何も注文していない", 15, SOFT, "marker")
			_lines.add_child(none)
			_seal(none)


# ---- チラシの紙：黄色い安い紙、赤い二重の縁、見出しの右に赤い網点 ----
class FlyerStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 30
		content_margin_right = 30
		content_margin_top = 24
		content_margin_bottom = 22

	func _draw(item: RID, r: Rect2) -> void:
		for k in 3:
			var grow := float(k) * 2.0
			RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(-grow + 4, 8 - grow * 0.5), r.size + Vector2(grow * 2.0, grow * 2.0)), Color(0, 0, 0, 0.3 / (k + 1.5)))
		RenderingServer.canvas_item_add_rect(item, r, Color("f8e98f"))
		RenderingServer.canvas_item_add_texture_rect_region(item, r, FilmSet.brush().get_rid(), FilmSet.paint_region(r), Color(1, 1, 1, 0.28))
		# 見出しの右の、赤い網点（右ほど大きい）
		var red := Color("d63a26")
		var x0 := r.position.x + r.size.x * 0.42
		var step := 11.0
		var y := r.position.y + 14.0
		while y < r.position.y + 96.0:
			var x := x0
			while x < r.end.x - 14.0:
				var t := (x - x0) / (r.end.x - 14.0 - x0)
				RenderingServer.canvas_item_add_circle(item, Vector2(x, y), 0.6 + 3.2 * t, Color(red, 0.22))
				x += step
			y += step
		# 赤い二重の縁
		var outer := r.grow(-8.0)
		var inner := r.grow(-13.0)
		for e: Array in [[outer, 3.0], [inner, 1.0]]:
			var b: Rect2 = e[0]
			var w: float = e[1]
			RenderingServer.canvas_item_add_rect(item, Rect2(b.position, Vector2(b.size.x, w)), red)
			RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(b.position.x, b.end.y - w), Vector2(b.size.x, w)), red)
			RenderingServer.canvas_item_add_rect(item, Rect2(b.position, Vector2(w, b.size.y)), red)
			RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(b.end.x - w, b.position.y), Vector2(w, b.size.y)), red)


# ---- 注文票の紙：白い紙を、切り取り線（点線）で囲む。左上にはさみの印 ----
class SlipStyle extends StyleBox:
	func _init() -> void:
		content_margin_left = 26
		content_margin_right = 26
		content_margin_top = 22
		content_margin_bottom = 22

	func _draw(item: RID, r: Rect2) -> void:
		for k in 3:
			var grow := float(k) * 2.0
			RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(-grow + 4, 8 - grow * 0.5), r.size + Vector2(grow * 2.0, grow * 2.0)), Color(0, 0, 0, 0.3 / (k + 1.5)))
		RenderingServer.canvas_item_add_rect(item, r, Color("fffdf6"))
		RenderingServer.canvas_item_add_texture_rect_region(item, r, FilmSet.brush().get_rid(), FilmSet.paint_region(r), Color(1, 1, 1, 0.18))
		var b := r.grow(-9.0)
		var ink := Color(0.11, 0.1, 0.09, 0.55)
		var pts := [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y), b.position]
		for i in 4:
			var a: Vector2 = pts[i]
			var c: Vector2 = pts[i + 1]
			var len := a.distance_to(c)
			var d := (c - a) / len
			var t := 0.0
			while t < len:
				RenderingServer.canvas_item_add_line(item, a + d * t, a + d * minf(t + 8.0, len), ink, 1.5)
				t += 14.0
		# はさみ（2つの輪と、交わる刃）
		var s := b.position + Vector2(22, 0)
		RenderingServer.canvas_item_add_rect(item, Rect2(s - Vector2(14, 8), Vector2(28, 16)), Color("fffdf6"))
		for side: float in [-1.0, 1.0]:
			var ring := s + Vector2(-8, 4.5 * side)
			RenderingServer.canvas_item_add_circle(item, ring, 4.2, ink)
			RenderingServer.canvas_item_add_circle(item, ring, 2.4, Color("fffdf6"))
			RenderingServer.canvas_item_add_line(item, s + Vector2(-4, 2.5 * side), s + Vector2(12, -2.5 * side), ink, 2.0)


# ---- 見出しの下の、黒い二重線 ----
class DoubleRule extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0, 1), Vector2(size.x, 3)), Color("1c1a17"))
		draw_rect(Rect2(Vector2(0, 6), Vector2(size.x, 1)), Color("1c1a17"))
