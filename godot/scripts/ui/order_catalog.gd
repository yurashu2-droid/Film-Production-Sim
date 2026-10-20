extends Control
# 機材レンタルのカタログ（発注画面）。左に写真つきの商品カード、右に注文票。
#   ・写真は tools/render_catalog.gd が実物の3Dモデルから撮ったもの（assets/ui/catalog）
#   ・カードをクリックで入れる／外す。火薬の袋だけは −／＋ で数を決める
#   ・くり返し使える物は、カードの下で「借りる（制作費から）／買う（会社の貯金から）」を選ぶ。
#     買った物は会社の持ち物になり、次からは「持っている」と出て、注文の対象から外れる
#   ・右は注文票と値段だけ。配役表・今日の廃材の一覧・場面の並びは出さない（発注する人は、現物の一覧を見られない。
#     廃材置き場に何が在るかは、集めに行った人に聞く）
const UI := preload("res://scripts/ui/ui_theme.gd")
const Cast := preload("res://scripts/production_cast.gd")
const THUMBS := "res://assets/ui/catalog/"
const PHOTO := {"balcony": "set_balcony", "fx": "fx", "refill": "fx_powder", "fuse": "fx_fuse", "dolly": "dolly", "fix": "sandbag", "rose": "rose"}
const PAPER_TILE := Color("e4e1d8")
const SLIP_W := 336.0

var game: Node
var rows: Array = []            # カードごとの部品（hud._opt_rows と同じ並び）
var confirm: Button

var _panel: PanelContainer
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


func build(owner_game: Node) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
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

	# 見出し：左に題、右に会社の残金
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var head_l := VBoxContainer.new()
	head_l.add_theme_constant_override("separation", 2)
	head_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_l)
	head_l.add_child(UI.overline("RENTAL"))
	_title = UI.label("機材レンタル", 28, UI.CLAP_WHITE, "display")
	head_l.add_child(_title)
	_sub = UI.label("", 15, UI.MUTED, "body")
	head_l.add_child(_sub)
	# 財布は2つ：会社の貯金（買う物）と、この依頼の制作費（借りる物・火薬）
	var head_s := VBoxContainer.new()
	head_s.add_theme_constant_override("separation", 0)
	head_s.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(head_s)
	var savings_cap := UI.overline("会社の貯金（買う物）")
	savings_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_s.add_child(savings_cap)
	_savings = UI.label("", 30, UI.CLAP_WHITE, "display")
	_savings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_s.add_child(_savings)
	_savings_box = head_s
	var head_r := VBoxContainer.new()
	head_r.add_theme_constant_override("separation", 0)
	head_r.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(head_r)
	_wallet_cap = UI.overline("会社の残金")
	_wallet_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_r.add_child(_wallet_cap)
	_wallet = UI.label("", 30, UI.CLAP_WHITE, "display")
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_r.add_child(_wallet)
	col.add_child(UI.hairline())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)
	_grid = GridContainer.new()
	# 品数が6つまでは3列。それより多ければ4列にして、2段に収める
	_grid.columns = 3 if game.OPTIONS.size() <= 6 else 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_grid)
	for i in game.OPTIONS.size():
		_grid.add_child(_card(i))
	body.add_child(UI.hairline(true))
	# 左の列：上にレンタルのカード、下に備品（買い切り）
	body.remove_child(_grid)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 品数が多いと、画面の下からはみ出す。カードの欄だけを、画面に入る高さで流せるようにする（_fit）
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(left)
	body.add_child(_scroll)
	body.move_child(_scroll, 0)
	left.add_child(_grid)
	_gear = VBoxContainer.new()
	_gear.visible = false
	left.add_child(_gear)
	body.add_child(_slip())
	visible = false
	resized.connect(_fit)
	_fit()


# 画面の広さに合わせて板の幅を決める（狭い画面ではカードを細くする）
func _fit() -> void:
	var w := clampf(size.x - 48.0, 960.0, minf(1180.0, size.x - 24.0))
	_panel.custom_minimum_size.x = w
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5
	# 縦：見出しと余白のぶんを引いた高さまで（それより長い一覧は、中で流す）
	if _scroll != null and size.y > 0.0:
		var need: float = (_scroll.get_child(0) as Control).get_combined_minimum_size().y
		_scroll.custom_minimum_size.y = minf(need, maxf(240.0, size.y - 250.0))
	_panel.offset_top = 0
	_panel.offset_bottom = 0


func _card(i: int) -> Control:
	var o: Dictionary = game.OPTIONS[i]
	var many: bool = int(o["max"]) > 1
	var cb := UI.ClickBox.new()
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cb.custom_minimum_size = Vector2(228 if game.OPTIONS.size() <= 6 else 168, 0)
	var normal := UI.box(Color(1, 1, 1, 0.035), UI.LINE, 1, 6, 10, 10)
	var hover := UI.box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.22), 1, 6, 10, 10)
	var chosen := UI.box(Color(1, 1, 1, 0.09), UI.CLAP_WHITE, 2, 6, 9, 9)
	cb.set_styles(normal, hover, chosen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cb.add_child(v)

	# 写真：明るい紙の上に実物を置く
	var photo := PanelContainer.new()
	photo.custom_minimum_size.y = 88
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	photo.add_theme_stylebox_override("panel", UI.box(PAPER_TILE, Color(0, 0, 0, 0), 0, 4, 10, 10))
	v.add_child(photo)
	var pic := TextureRect.new()
	pic.texture = thumb(str(PHOTO.get(o["id"], o["id"])))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.add_child(pic)
	var corner := MarginContainer.new()
	photo.add_child(corner)
	var mark := UI.ShotBox.new()
	mark.size_flags_horizontal = Control.SIZE_SHRINK_END
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mark.visible = false
	corner.add_child(mark)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	v.add_child(name_row)
	# 4列のときはカードが細いので、長い名前は2行に折り返す
	var compact: bool = game.OPTIONS.size() > 6
	var name_label := UI.label(str(o["name"]).trim_prefix("借りる"), 15 if compact else 16, UI.CLAP_WHITE, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size.x = 60
	if compact:
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	var price := UI.label(str(o["cost"]), 17, UI.CLAP_WHITE, "bold")
	name_row.add_child(price)
	var desc := UI.label(str(o["desc"]), 13, UI.MUTED, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(120, 40)
	v.add_child(desc)

	# いちばん下の1行：いまの状態。充填だけは数を選ぶ
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	foot.custom_minimum_size.y = 28
	v.add_child(foot)
	var state := UI.label("", 13, UI.MUTED, "bold")
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
	# 会社がもう持っている物：ボタンの代わりに、緑の札を出す
	var own := PanelContainer.new()
	own.add_theme_stylebox_override("panel", UI.box(Color(UI.OK_GREEN, 0.16), UI.OK_GREEN, 1, 4, 6, 0))
	own.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own.custom_minimum_size.y = 28
	own.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own.visible = false
	var own_text := UI.label("持っている", 13, UI.GREEN_LIGHT, "bold")
	own_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	own.add_child(own_text)
	foot.add_child(own)
	cb.hovered.connect(func() -> void: game.order_cursor = i)
	cb.pressed.connect(func() -> void: _toggle(i))
	rows.append({"box": cb, "mark": mark, "state": state, "price": price, "minus": minus, "plus": plus, "pic": pic, "rent": rent, "buy": buy, "own": own})
	return cb


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


# on：選んである（黄色）/ short：お金が足りない（赤い字で、押せない）
func _set_pick(b: Button, on: bool, short: bool) -> void:
	var look := "on" if on else ("short" if short else "off")
	if b.has_meta("look") and str(b.get_meta("look")) == look:
		return
	b.set_meta("look", look)
	UI.style_button(b, "tape" if on else "slate", 13, 28)
	for part: String in ["normal", "hover", "pressed", "disabled"]:
		var sb := b.get_theme_stylebox(part) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = 6
			sb.content_margin_right = 6
	b.disabled = short and not on
	b.add_theme_color_override("font_disabled_color", UI.STAMP_RED.lightened(0.25))


func _step(text: String) -> Button:
	var b := Button.new()
	b.text = text
	UI.style_button(b, "slate", 15, 28)
	b.custom_minimum_size = Vector2(34, 28)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _slip() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size.x = SLIP_W
	v.add_child(UI.overline("今日の一本"))
	_job_title = UI.label("", 18, UI.CLAP_WHITE, "bold")
	_job_title.custom_minimum_size.x = SLIP_W
	_job_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_job_title)
	_job_sub = UI.label("", 13, UI.MUTED, "body")
	_job_sub.custom_minimum_size.x = SLIP_W
	_job_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_job_sub)
	# 発注する人（監督）への一言。現物の一覧は、ここには出さない
	_ask = UI.label("廃材置き場に何が在るかは、ここからは見えない。集めに行った人に、声で聞こう。", 13, UI.MUTED, "body")
	_ask.custom_minimum_size.x = SLIP_W
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_ask)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)
	v.add_child(UI.hairline())
	v.add_child(UI.overline("注文票"))
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 2)
	v.add_child(_lines)
	v.add_child(UI.hairline())
	var total_row := _pair("合計", 17, "bold")
	_total = total_row[1]
	_total_cap = total_row[2]
	v.add_child(total_row[0])
	var paid_row := _pair("貯金から（買う物）", 14, "body")
	_paid = paid_row[1]
	_paid_row = paid_row[0]
	_paid_row.visible = false
	v.add_child(_paid_row)
	var after_row := _pair("支払い後の残金", 14, "body")
	_after_cap = after_row[2]
	_after = after_row[1]
	v.add_child(after_row[0])
	v.add_child(UI.gap(2))
	confirm = UI.KeyButton.new().setup("この内容で借りる", "Enter", "tape", 17, 48)
	confirm.pressed.connect(func() -> void: game.h_order_confirm.rpc_id(1))
	v.add_child(confirm)
	# 決めずに閉じる（制作モードだけ）。選びかけの注文は、前に決めた注文へ戻る
	_skip = UI.KeyButton.new().setup("閉じる（注文は変えない）", "Esc", "slate", 15, 36)
	_skip.pressed.connect(_close)
	v.add_child(_skip)
	return v


# 左に名前、右に数字の1行。[行, 数字, 名前]
func _pair(text: String, px: int, kind: String) -> Array:
	var row := HBoxContainer.new()
	var cap := UI.label(text, px, UI.CLAP_WHITE if kind == "bold" else UI.MUTED, kind)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var num := UI.label("", px, UI.CLAP_WHITE, "bold")
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
	UI.recolor(_after, UI.STAMP_RED.lightened(0.25) if limit - used < 0 else UI.CLAP_WHITE)

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
		cb.modulate.a = 1.0 if usable else 0.45
		(r["mark"] as UI.ShotBox).visible = picked
		(r["mark"] as UI.ShotBox).set_on(picked)
		var state: Label = r["state"]
		state.visible = not choice and not own
		(r["own"] as Control).visible = own
		(r["price"] as Label).visible = not choice and not own
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
		if own:
			UI.recolor(state, UI.GREEN_LIGHT)
		else:
			UI.recolor(state, UI.CLAP_WHITE if n > 0 else (UI.STAMP_RED.lightened(0.25) if short and usable else UI.MUTED))
		UI.recolor(r["price"], UI.MUTED if short else UI.CLAP_WHITE)
		if many:
			(r["minus"] as Button).disabled = n <= 0
			(r["plus"] as Button).disabled = n >= int(game.order_max(o)) or not usable

	# 注文票の行（中身が変わったときだけ組み直す）
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
			var row := _pair(item + "（買う）" if bought else item + ("　×%d" % n if n > 1 else ""), 14, "body")
			UI.recolor(row[2], UI.CLAP_WHITE)
			(row[1] as Label).text = "貯金 %d" % int(game.buy_price(o)) if bought else "%d" % (int(o["cost"]) * n)
			_lines.add_child(row[0])
		if not any:
			_lines.add_child(UI.label("まだ何も注文していない", 14, UI.MUTED, "body"))

