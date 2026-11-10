extends Node
## 追加注文の札（docs/production/order-cards.md）：依頼を受けると、依頼主から FAX で、追加の注文が何枚か届く。
## 台本（30本）とは別の束から引くので、同じ台本でも、毎回ちがう縛りで撮ることになる。
##   ・枚数は、依頼の格で決まる（格1・2＝1枚、格3＝2枚、格4＝3枚）。会社の紹介動画（1日目）には来ない
##   ・2枚以上のときは、最後の1枚が「当日の差し込み」：現場に着いてから届く（準備のあとで言われる）
##   ・守れたら、ギャラに上乗せ。守れなくても、引かれない（失格にしない）。1場面も撮れていなければ、上乗せは無し
##   ・札は、画面の左下の FAX の紙に並ぶ（事務所での準備から、撮影が終わるまで）
## 引く・数える・達成を決めるのはホスト。札の中身は、全員の画面に届く。
## ふつうに遊ぶときだけ引く（自動確認の中では引かない。確認は force を立てるか、draw() を呼ぶ）
const Cast := preload("res://scripts/production_cast.gd")
const COUNT_BY_RANK := [1, 1, 2, 3]
const ITEM_SEC := 2.0                # 「これを映して」：この秒数、撮影カメラに映す
const GEAR_SEC := 0.3                # 「機材を映すな」：映ってよい秒数の合計
const CAMEO_SEC := 1.5               # 「スタッフも出して」：映り込みの合計の秒数
const QUICK_LEFT := 300.0            # 「巻きで」：撮影時間をこれだけ残す
const SHORT_PER_SCENE := 8.0         # 「短くまとめて」：1場面あたりの秒数
const GEAR_KINDS := ["spot", "monitor", "clapper", "script"]
# 撮り方の札：撮影カメラ（いま映している1台）の動きと向きを、本番中に毎コマ見る
const LOW_HEIGHT := 0.7              # 「低い所から」：床からカメラまでの高さ
const LOW_SHARE := 0.9               # 　　〃　　：本番のこの割合、低いまま
const TOP_DOWN := -0.8               # 「真上から」：カメラの向きの下向きの成分（これより下を向く）
const TOP_SEC := 2.0
const MOVE_SPEED := 0.15             # 「じっとさせないで」：カメラが動いていると数える速さ（m/秒）
const MOVE_SHARE := 0.6
const TILT_ROLL := 0.26              # 「斜めに」：カメラの傾き（ラジアン。約15度）
const TILT_SEC := 2.0
const ZOOM_STILL := 0.5              # 「ズーム禁止」：動いてよい画角の幅（度）
const DOLLY_SPEED := 0.25            # 「めまい」：前後に動く速さ（m/秒）
const DOLLY_ZOOM := 2.0              # 　　〃　：画角が変わる速さ（度/秒）
const DOLLY_SEC := 1.0
const FLOAT_SEC := 2.0               # 「宙に浮かせて」：役者が、足を何にも着けないまま映る秒数（続けて）
const FLOAT_GAP := 0.25              # 　　〃　　　　：足の下が、これだけ空いていれば「浮いている」（m）
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
	"zoom_ban": {"say": "ズームは、目が回るからやめて", "need": "本番中、ズームを動かさない", "coins": 100},
	"low_angle": {"say": "子どもの目線で撮って", "need": "カメラを、ひざより低く置いたまま撮る", "coins": 120},
	"top_down": {"say": "1回でいいから、真上から", "need": "真下を見下ろす向きで、合計2秒撮る", "coins": 150},
	"always_moving": {"say": "カメラは、じっとさせないで", "need": "本番中の6割、カメラが動いている", "coins": 150},
	"dolly_zoom": {"say": "あの、背景だけ伸びるやつ、やって", "need": "カメラを引きながらズームで寄る（か、その逆）を1秒", "coins": 200},
	"tilt": {"say": "不安な感じに。画面を斜めにして", "need": "カメラを傾けたまま、合計2秒撮る", "coins": 120},
	"panel_actor": {"say": "うちの社長、忙しくてね。パネルでいいから", "need": "等身大パネルを1枚、役者にする", "coins": 120},
	"all_cast": {"say": "社員さん、みんな出てよ", "need": "班の全員が、役に入っている", "coins": 150},
	"real_fire": {"say": "書割の爆発は、見れば分かる。本物でやって", "need": "爆発は、本物の爆弾で（火薬を入れて鳴らす）", "coins": 150},
	"no_fire": {"say": "町内会がうるさくて。本物の火は使わないで", "need": "爆発は、爆弾を使わずに（書割や、爆発に見立てた物で）", "coins": 120},
	"float": {"say": "主役を、宙に浮かせて。飛んでるみたいに", "need": "役者が、足を何にも着けないまま2秒、映る（吊る・ゆっくり跳ぶ、やり方は自由）", "coins": 180},
	"stunt": {"say": "どこかで1回、体を張って", "need": "役者が、高い所から飛び降りる（か、爆風で吹っ飛ぶ）所を映す。のびないこと", "coins": 200},
}
# いっしょには引かない組
const CLASH := [["half_budget", "no_rental"], ["zoom_ban", "dolly_zoom"], ["low_angle", "top_down"], ["cameo", "all_cast"],
	["real_fire", "no_fire"], ["real_fire", "no_rental"]]          # 爆弾は、借りるか買うかしないと無い

var game: Node
var force := false                   # 自動確認でも引く
var cards: Array = []                # 引いた札 [{"id", "need", "coins", "ref"（物のID。無ければ 0）, "shown"（もう届いたか）}, ...]
var _by_take := {}                   # テイクの番号 → [[依頼主のひとこと, コイン, 守れたか], ...]（ホスト）
var _item_sec := {}                  # 札の番号 → 映った秒数（「これを映して」）
var _gear_sec := 0.0
var _float := {}                     # 「宙に浮かせて」：役者の番号 → いま、続けて浮いて映っている秒数
var _float_best := 0.0               # 　　〃　　　　：このテイクで、いちばん長かった秒数
var _cam := {}                       # 撮り方の札のための数え（本番ごと）：t・low・top・move・tilt・dolly・fov_min・fov_max
var _cam_prev: Node                  # 前のコマに映していたカメラ（切り替えた瞬間は、動きに数えない）
var _cam_pos := Vector3.ZERO
var _cam_fov := 0.0
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
	out.append_array(["zoom_ban", "low_angle", "top_down", "always_moving", "dolly_zoom", "tilt", "panel_actor", "float"])
	if (game.players as Dictionary).size() >= 2:
		out.append("all_cast")       # ひとり遊びでは、言うまでもない
	if "boom" in Cast.roles_for(str(flow.job().get("script", ""))):
		out.append_array(["real_fire", "no_fire"])      # 爆発のある台本だけ。同じ手（無料の書割）が、いつも通るとは限らない
	if int(flow.job_rank(flow.chosen_job)) >= 2 and game.hooks.feature("stunts") != null:
		out.append("stunt")          # 体を張る注文は、格2から（features/stunts.gd）
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
	_watch_camera(delta)
	_watch_float(delta)


# 「宙に浮かせて」：役者（役に入った人・雇った役者）が、足を何にも着けないまま、撮影カメラに映っている秒数を数える。
# 吊る（features/harness.gd）・スロー光線の中で跳ぶ、など、やり方は見ない。箱の上に立っているのは、浮いていない
func _watch_float(delta: float) -> void:
	var stunts: Node = game.hooks.feature("stunts")
	if stunts == null or not cards.any(func(c: Dictionary) -> bool: return str(c["id"]) == "float"):
		return
	var notes: RefCounted = game.production.notes
	for row: Array in stunts.cast_bodies():
		var who := int(row[0])
		var body: Node3D = row[1]
		var vis: Node3D = body.vis
		var up: bool = not _on_something(body) and (bool(notes._seen(vis.head_pos(), body.get_rid())) or bool(notes._seen(vis.chest_pos(), body.get_rid())))
		_float[who] = (float(_float.get(who, 0.0)) + delta) if up else 0.0
		_float_best = maxf(_float_best, float(_float[who]))


# 足の下に、床か物があるか（FLOAT_GAP まで）
func _on_something(body: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0, 0.3, 0), body.global_position + Vector3(0, -FLOAT_GAP, 0), 1 | 2)
	q.exclude = [(body as CollisionObject3D).get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# 撮影カメラ（いま映している1台）の動きと向きを数える
func _watch_camera(delta: float) -> void:
	var film: Node3D = game.program_camera() as Node3D
	if film == null or film.get("view_cam") == null or delta <= 0.0:
		return
	var cam: Camera3D = film.view_cam
	var pos: Vector3 = cam.global_position
	var fov: float = cam.fov
	var ahead: Vector3 = -cam.global_transform.basis.z
	if _cam.is_empty():
		_cam = {"t": 0.0, "low": 0.0, "top": 0.0, "move": 0.0, "tilt": 0.0, "dolly": 0.0, "fov_min": fov, "fov_max": fov}
		_cam_prev = null
	_cam["t"] = float(_cam["t"]) + delta
	_cam["fov_min"] = minf(float(_cam["fov_min"]), fov)
	_cam["fov_max"] = maxf(float(_cam["fov_max"]), fov)
	if pos.y - float(game.production.site_center().y) < LOW_HEIGHT:
		_cam["low"] = float(_cam["low"]) + delta
	if ahead.y < TOP_DOWN:
		_cam["top"] = float(_cam["top"]) + delta
	if absf(asin(clampf(cam.global_transform.basis.x.y, -1.0, 1.0))) > TILT_ROLL:
		_cam["tilt"] = float(_cam["tilt"]) + delta
	if _cam_prev == film:
		var step: Vector3 = pos - _cam_pos
		if step.length() / delta > MOVE_SPEED:
			_cam["move"] = float(_cam["move"]) + delta
		# めまい：前へ出ながら画角を広げる（引く）か、下がりながら画角を狭める（寄る）
		var forward := step.dot(ahead) / delta
		var zoom := (fov - _cam_fov) / delta
		if absf(forward) > DOLLY_SPEED and absf(zoom) > DOLLY_ZOOM and signf(forward) == signf(zoom):
			_cam["dolly"] = float(_cam["dolly"]) + delta
	_cam_prev = film
	_cam_pos = pos
	_cam_fov = fov


func hook_take_start() -> void:
	_item_sec.clear()
	_gear_sec = 0.0
	_float.clear()
	_float_best = 0.0
	_cam = {}


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
		"zoom_ban":
			return not _cam.is_empty() and float(_cam["fov_max"]) - float(_cam["fov_min"]) <= ZOOM_STILL
		"low_angle":
			return float(_cam.get("t", 0.0)) > 1.0 and float(_cam["low"]) >= LOW_SHARE * float(_cam["t"])
		"top_down":
			return float(_cam.get("top", 0.0)) >= TOP_SEC
		"always_moving":
			return float(_cam.get("t", 0.0)) > 1.0 and float(_cam["move"]) >= MOVE_SHARE * float(_cam["t"])
		"dolly_zoom":
			return float(_cam.get("dolly", 0.0)) >= DOLLY_SEC
		"tilt":
			return float(_cam.get("tilt", 0.0)) >= TILT_SEC
		"panel_actor":
			var stands: Node = game.hooks.feature("stand_ins")
			return stands != null and (stands.holders as Array).any(func(h: Array) -> bool: return str(h[0]) == "prop")
		"all_cast":
			var cast: Node = game.hooks.feature("stand_ins")
			if cast == null:
				return false
			for who: Variant in (game.players as Dictionary).keys():
				if not (cast.holders as Array).any(func(h: Array) -> bool: return str(h[0]) == "player" and int(h[1]) == int(who)):
					return false
			return true
		"real_fire", "no_fire":
			# 数えた爆発（場面が見ている爆発）を出した物が、本物の爆弾か
			var src: Node = game.props.get(int(game.judge.boom_src))
			if src == null:
				return false
			return (str(src.kind) == "fx") == (str(cards[i]["id"]) == "real_fire")
		"float":
			return _float_best >= FLOAT_SEC
		"stunt":
			var stunts: Node = game.hooks.feature("stunts")
			return stunts != null and not (stunts.filmed() as Array).is_empty()
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
