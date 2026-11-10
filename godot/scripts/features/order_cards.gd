extends Node
## 追加注文の札（docs/production/order-cards.md）：依頼を受けると、依頼主から FAX で、追加の注文が何枚か届く。
## 台本（30本）とは別の束から引くので、同じ台本でも、毎回ちがう縛りで撮ることになる。
##   ・枚数は、依頼の格で決まる（格1・2＝1枚、格3＝2枚、格4＝3枚）。会社の紹介動画（1日目）には来ない
##   ・2枚以上のときは、最後の1枚が「当日の差し込み」：現場に着いてから届く（準備のあとで言われる）
##   ・守れたら、ギャラに上乗せ。守れなくても、引かれない（失格にしない）。1場面も撮れていなければ、上乗せは無し
##   ・札は、画面の左下の FAX の紙に並ぶ（事務所での準備から、撮影が終わるまで）
## 引く・数える・達成を決めるのはホスト。札の中身は、全員の画面に届く。
## ふつうに遊ぶときだけ引く（自動確認の中では引かない。確認は force を立てるか、draw() を呼ぶ）
const COUNT_BY_RANK := [1, 1, 2, 3]
const ITEM_SEC := 2.0                # 「これを映して」：この秒数、撮影カメラに映す
const GEAR_SEC := 0.3                # 「機材を映すな」：映ってよい秒数の合計
const CAMEO_SEC := 1.5               # 「スタッフも出して」：映り込みの合計の秒数
const QUICK_LEFT := 300.0            # 「巻きで」：撮影時間をこれだけ残す
const SHORT_PER_SCENE := 8.0         # 「短くまとめて」：1場面あたりの秒数
const GEAR_KINDS := ["spot", "monitor", "clapper", "script"]
# 札：say＝依頼主のひとこと／need＝守る事／coins＝守れたときの上乗せ。"%s" は、札ごとの物の名前
const CARDS := {
	"half_budget": {"say": "予算、半分しか出せなくなった", "need": "制作費の半分までで撮る", "coins": 150},
	"no_rental": {"say": "借り物の領収書は、受け取らない", "need": "何も借りずに撮る", "coins": 200},
	"quick": {"say": "次の予約がある。5分残して終わって", "need": "撮影時間を5分残して撮り切る", "coins": 120},
	"short": {"say": "尺が無い。短くまとめて", "need": "テイクを %d 秒以内に", "coins": 120},
	"cameo": {"say": "スタッフの顔も、ちらっと見たいな", "need": "スタッフが合計1.5秒、映り込む", "coins": 100},
	"rookie": {"say": "うちの甥を出してやって。劇団の新人なんだ", "need": "劇団の新人を1人、役者に使う", "coins": 150},
	"show_item": {"say": "これ、スポンサーの私物。映しておいて", "need": "「%s」を2秒、映す", "coins": 150},
	"hide_gear": {"say": "機材が映るのは、素人だよ", "need": "ライト・モニター・カチンコ・台本を映さない", "coins": 120},
}
# いっしょには引かない組
const CLASH := [["half_budget", "no_rental"]]

var game: Node
var force := false                   # 自動確認でも引く
var cards: Array = []                # 引いた札 [{"id", "need", "coins", "ref"（物のID。無ければ 0）, "shown"（もう届いたか）}, ...]
var _by_take := {}                   # テイクの番号 → [[依頼主のひとこと, コイン, 守れたか], ...]（ホスト）
var _item_sec := {}                  # 札の番号 → 映った秒数（「これを映して」）
var _gear_sec := 0.0
var _layer: CanvasLayer
var _paper: PanelContainer
var _rows: VBoxContainer
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	_build_paper()


# ---- 引く（ホスト） ----

func hook_new_job() -> void:
	var flow: Node = game.production
	if not Net.is_host() or flow == null:
		return
	_by_take.clear()
	if not (bool(flow.hazards) or force) or bool(flow.job().get("debut", false)):
		_send([])
		return
	_send(draw(_rng.randi()))
	var now: Array = cards.filter(func(c: Dictionary) -> bool: return bool(c["shown"]))
	if not now.is_empty():
		game.host_ev("toast", ["FAX が届いた。依頼主『%s』" % "』『".join(now.map(func(c: Dictionary) -> String: return str(CARDS[c["id"]]["say"]))), 0])


# この依頼の札を引く（seed で決まる）
func draw(seed_value: int) -> Array:
	var flow: Node = game.production
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var want: int = COUNT_BY_RANK[clampi(int(flow.job_rank(flow.chosen_job)) - 1, 0, COUNT_BY_RANK.size() - 1)]
	var pool: Array = _candidates()
	# 並べ替えて、上から取る（いっしょに引かない組は、あとの札を飛ばす）
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for id: String in pool:
		if out.size() >= want:
			break
		var clash := false
		for pair: Array in CLASH:
			if id in pair:
				for got: Dictionary in out:
					clash = clash or (str(got["id"]) in pair)
		if clash:
			continue
		var card := {"id": id, "need": str(CARDS[id]["need"]), "coins": int(CARDS[id]["coins"]), "ref": 0, "shown": true}
		if id == "short":
			card["need"] = str(CARDS[id]["need"]) % int(SHORT_PER_SCENE * (flow.job()["scenes"] as Array).size())
		elif id == "show_item":
			var items := _items()
			var item: Node = items[rng.randi_range(0, items.size() - 1)]
			card["ref"] = int(item.pid)
			card["need"] = str(CARDS[id]["need"]) % str(item.label)
		out.append(card)
	# 2枚以上なら、最後の1枚は、現場に着いてから届く
	if out.size() >= 2:
		out[-1]["shown"] = false
	return out


# いまの依頼で引ける札
func _candidates() -> Array:
	var flow: Node = game.production
	var out: Array = ["quick", "short", "rookie", "hide_gear"]
	if int(flow.budget()) > 0:
		out.append_array(["half_budget", "no_rental"])
	if str(flow.job().get("bonus", "")) != "no_crew":
		out.append("cameo")          # 「映り込み0.5秒以内」の依頼には、逆の注文は出さない
	if not _items().is_empty():
		out.append("show_item")
	return out


# 「これを映して」に選べる物：今日、手に入る廃材
func _items() -> Array:
	var out: Array = []
	for p: Variant in game.props.values():
		var prop := p as Node
		if prop != null and str(prop.get("kind")).begins_with("scrap_") and not bool(prop.get("absent")) and str(prop.get("label")) != "":
			out.append(prop)
	out.sort_custom(func(a: Node, b: Node) -> bool: return int(a.pid) < int(b.pid))
	return out


func _send(list: Array) -> void:
	game.host_ev("order_cards", [list])


# ---- 数える・決める（ホスト） ----

func _physics_process(delta: float) -> void:
	if not Net.is_host() or cards.is_empty():
		return
	var flow: Node = game.production
	if flow == null:
		return
	# 当日の差し込み：現場に着いたら届く
	if int(flow.phase) == 4:
		for i in cards.size():
			if not bool(cards[i]["shown"]):
				var list: Array = cards.duplicate(true)
				list[i]["shown"] = true
				_send(list)
				game.host_ev("toast", ["当日の差し込み！ FAX が届いた。依頼主『%s』" % str(CARDS[list[i]["id"]]["say"]), 1])
				break
	# 本番中：映った秒数を数える（フィルムを止めている間は数えない）
	if int(game.state) != int(game.S.TAKE) or bool(game.take_held()):
		return
	var notes: RefCounted = flow.notes
	for i in cards.size():
		if str(cards[i]["id"]) == "show_item" and bool(cards[i]["shown"]):
			var item: Node = game.props.get(int(cards[i]["ref"]))
			if item != null and not bool(item.absent) and bool(notes._seen(item.center_global(), item.get_rid())):
				_item_sec[i] = float(_item_sec.get(i, 0.0)) + delta
	for p: Variant in game.props.values():
		var prop := p as Node
		if prop != null and str(prop.kind) in GEAR_KINDS and not bool(prop.absent) and bool(notes._seen(prop.center_global(), prop.get_rid())):
			_gear_sec += delta
			break


func hook_take_start() -> void:
	_item_sec.clear()
	_gear_sec = 0.0


func hook_take_cut() -> void:
	if (game.takes as Array).is_empty() or cards.is_empty():
		return
	var index: int = game.takes.size() - 1
	var take: Dictionary = game.takes[index]
	var shot_any: bool = (take["passed"] as Array).count(true) > 0
	var rows: Array = []
	var kept := 0
	for i in cards.size():
		if not bool(cards[i]["shown"]):
			continue
		var ok := shot_any and met(i, take)
		kept += 1 if ok else 0
		rows.append([str(CARDS[cards[i]["id"]]["say"]), int(cards[i]["coins"]), ok])
	_by_take[index] = rows
	if not rows.is_empty():
		game.host_ev("toast", ["追加注文の札：%d 枚のうち %d 枚、守れた" % [rows.size(), kept], 0])


# その札を、このテイクで守れたか（ホスト）
func met(i: int, take: Dictionary) -> bool:
	var flow: Node = game.production
	match str(cards[i]["id"]):
		"half_budget":
			return int(flow.expenses) * 2 <= int(flow.budget())
		"no_rental":
			return int(flow.expenses) == 0
		"quick":
			return float(flow.lease_left) >= QUICK_LEFT
		"short":
			return float(take.get("dur", 999.0)) <= SHORT_PER_SCENE * (flow.job()["scenes"] as Array).size()
		"cameo":
			return float(flow.notes.crew_seconds) >= CAMEO_SEC
		"rookie":
			var stand: Node = game.hooks.feature("stand_ins")
			return stand != null and "rookie" in (stand.plan as Array)
		"show_item":
			return float(_item_sec.get(i, 0.0)) >= ITEM_SEC
		"hide_gear":
			return _gear_sec <= GEAR_SEC
	return false


func hook_fee_lines(index: int) -> Array:
	var out: Array = []
	for row: Array in _by_take.get(index, []):
		if bool(row[2]):
			out.append(["追加注文『%s』を守った" % str(row[0]), int(row[1])])
	return out


func hook_return_office() -> void:
	_by_take.clear()
	if Net.is_host():
		_send([])


# ---- 全員の画面 ----

func hook_events() -> Array:
	return ["order_cards"]


func hook_event(n: String, a: Array) -> void:
	if n == "order_cards":
		cards = (a[0] as Array).duplicate(true)
		_fill_paper()


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "order_cards", [cards])


# FAX の紙（画面の左下）
func _build_paper() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "OrderCardsPaper"
	_layer.layer = 4
	add_child(_layer)
	_paper = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.95, 0.88, 0.96)
	style.border_color = Color(0.25, 0.2, 0.15, 0.5)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.set_content_margin_all(10)
	_paper.add_theme_stylebox_override("panel", style)
	_paper.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_paper.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_paper.offset_left = 18
	_paper.offset_bottom = -18
	_paper.custom_minimum_size.x = 345
	_paper.rotation = -0.015
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.visible = false
	_layer.add_child(_paper)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(_rows)


func _ink(words: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	if game.get("font") != null:
		label.add_theme_font_override("font", game.font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 320
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fill_paper() -> void:
	if _rows == null:
		return
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var shown: Array = cards.filter(func(c: Dictionary) -> bool: return bool(c["shown"]))
	if shown.is_empty():
		return
	_rows.add_child(_ink("FAX　追加の注文（守れたら上乗せ）", 13, Color(0.45, 0.4, 0.35)))
	for card: Dictionary in shown:
		_rows.add_child(_ink("＋%d　『%s』" % [int(card["coins"]), str(CARDS[card["id"]]["say"])], 14, Color(0.12, 0.1, 0.1)))
		_rows.add_child(_ink("　　　→ %s" % str(card["need"]), 13, Color(0.6, 0.16, 0.12)))


func _process(_delta: float) -> void:
	if _paper == null:
		return
	var flow: Node = game.production
	var on: bool = flow != null and not cards.is_empty() and int(flow.phase) in [1, 2, 3, 4] and not game.ui_blocking() and cards.any(func(c: Dictionary) -> bool: return bool(c["shown"]))
	_paper.visible = on
