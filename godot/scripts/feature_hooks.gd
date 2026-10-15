extends RefCounted
## 仕組みの登録（フック）。爆弾の道具・箱とロープ・特技…といった「仕組み」を、名前を付けて登録しておくと、
## 中心のファイル（main.gd・production_main.gd・production_hud.gd・production_flow.gd）が、決まった名前の関数を順に呼ぶ。
## ねらい：新しい仕組みを足すときに、中心のファイルを開かなくて済むようにする（並行で作業してもぶつからない）。
##   ・仕組みは、下の HOOKS にある名前の関数のうち、要る物だけを持つ（持っていない関数は、呼ばれないだけ）
##   ・呼ぶ順番は、下の ORDER と ORDERS に全部書いてある（順番で結果が変わる物は、ここだけを見ればよい）
##   ・食い違い（合図の名前の重なり・関数の名前の書きまちがい・順番の表のまちがい）は problems() が見つける。
##     確認は tests/feature_hooks_test.gd。中心のファイルや仕組みを直したら、この1本を流す
## 足し方の説明は docs/FEATURE_HOOKS.md

# 決まった名前の関数。仕組みが持っていれば、書いてある時に呼ばれる
const HOOKS := {
	"hook_events": "() -> Array：自分の合図（game.ev で届く知らせ）の名前。ほかの仕組みと重ねない",
	"hook_event": "(n: String, a: Array)：自分の合図が届いた（全員の画面）",
	"hook_rec_events": "() -> Array：自分の合図のうち、見返し（録画）に載せる物。game.host_ev で流した分が、本番中は記録される",
	"hook_core_event": "(n: String, a: Array)：中心の合図（absent・burst・state など）が処理されたあと（全員の画面）",
	"hook_sync": "(who: int)：あとから入った人へ、今の状態を送る（ホスト）",
	"hook_input": "(event: InputEvent) -> bool：どのキー・マウスよりも先に受ける（開いている画面の操作）。使ったら true",
	"hook_key": "(event: InputEvent, me: Node) -> bool：自分のキー（歩いている間）。使ったら true",
	"hook_f": "(me: Node) -> bool：F が押された。使ったら true（ほかへは回らない）",
	"hook_click": "(me: Node) -> bool：手ぶらの左クリック。使ったら true",
	"hook_hud": "(me: Node, label: String, keys: String) -> Dictionary：狙った物の名前の横と、操作の案内に足す文（production_hud.gd の _apply_view）",
	"hook_grab_block": "(prop: Node) -> String：その物を持ち上げられない理由（\"\"＝持てる）",
	"hook_new_job": "()：依頼を受けた（ホスト）",
	"hook_production_applied": "()：会社の状態（依頼・注文・持ち物）が届いた（全員の画面）",
	"hook_return_office": "()：帰社：物の置き場所を戻す前の後始末（ホスト）",
	"hook_office_ready": "()：帰社：片づけが終わって、次の日の事務所になった（ホスト）",
	"hook_take_ready": "()：準備中にテイクを始める直前（ホスト。撮り直しで戻す物を覚える）",
	"hook_take_start": "()：本番が始まった（ホスト。見返しの最初に流す知らせを game._rec_events に足す）",
	"hook_take_cut": "()：カットした（ホスト）",
	"hook_retake": "()：撮り直し：物の置き場所を戻す前（ホスト）",
	"hook_retake_done": "()：撮り直し：物の置き場所を戻したあと（ホスト）",
	"hook_playback": "(on: bool)：見返しの始まり（on。見返しに入る前）と終わり（off。戻ったあと）（ホスト）",
	"hook_premiere_cues": "(index: int) -> Array：試写会で、依頼主が反応する時刻とひとこと [[テイクの中の秒, せりふ, 気分(happy/wow/sad/neutral)], ...]（ホスト）",
	"hook_fee_lines": "(index: int) -> Array：そのテイクのギャラの上乗せ [[文, コイン], ...]（ホスト。production_flow.gd の take_fee と、精算の文に入る）",
	"hook_deliver": "(index: int) -> bool：画面（ボタン・Enter）から納品を頼まれた（ホスト）。true なら、その仕組みが先に何かを流し、終わったら自分で game.h_deliver を呼ぶ（試写会）",
}

# ---- 順番 ----
# ふつうの順番（下の ORDERS に無い関数は、全部この順に呼ぶ）。ここに無い仕組みは、このあとに、登録した順で続く
const ORDER := ["adhesive", "cue_cards", "cargo_kit", "bomb_kit", "beats", "rope_grab", "talent", "director"]
# 関数ごとの順番（順番で結果が変わる物）。書いてある仕組みが先。書いていない仕組みは、そのあとに ORDER の順で続く
const ORDERS := {
	# F：机の物 → 仲間の頭の道具箱 → つかんだロープの端 → 爆弾の道具 → 箱とロープ → カンペ・等身大パネル。
	# どれも使わなければ、production_main.gd の残り（荷台に積む・台本・仕掛けを動かす・その場所の画面）へ回る
	"hook_f": ["director", "talent", "rope_grab", "bomb_kit", "cargo_kit", "cue_cards"],
	# 開いている画面：のぞき箱・発注 → 接着剤 → カンペを書く画面
	"hook_input": ["director", "adhesive", "cue_cards"],
	# 画面の案内：あとの仕組みが、前の仕組みの文を見て書き足す・差し替える
	"hook_hud": ["bomb_kit", "cargo_kit", "rope_grab"],
	# 見返しの終わりだけは、場面の進み → 箱とロープ → 爆弾の順に戻す（run の3つ目に、この名前を渡す）
	"hook_playback:off": ["beats", "cargo_kit", "bomb_kit"],
}
# hook_ で始まるが、登録の関数ではない名前（荷台の「フック」の場所。cargo_kit.gd）。書きまちがいの確認から外す
const NOT_HOOKS := ["hook_at"]
# 置くだけで足される仕組みの置き場（spawn_folder）
const FOLDER := "res://scripts/features"

var _names: Array = []            # 登録した順の名前
var _features := {}               # 名前 → 仕組み（Node など）
var _owner := {}                  # 合図の名前 → 仕組みの名前
var _rec := {}                    # 見返しに載せる合図の名前 → true
var _problems: Array = []         # 登録のときに見つけた食い違い
var _cache := {}                  # 「関数の名前|順番の名前」→ その関数を持つ仕組み（呼ぶ順）


# 仕組みを登録する。name は、ほかと重ならない名前（ORDER・ORDERS に書く名前）
func add(name: String, feature: Object) -> void:
	if feature == null:
		return
	if _features.has(name):
		_problems.append("同じ名前で2回登録している：%s" % name)
		return
	_names.append(name)
	_features[name] = feature
	_cache.clear()
	if feature.has_method("hook_events"):
		for n: String in feature.hook_events():
			if _owner.has(n):
				_problems.append("合図「%s」が重なっている：%s と %s" % [n, _owner[n], name])
			else:
				_owner[n] = name
	if feature.has_method("hook_rec_events"):
		for n: String in feature.hook_rec_events():
			_rec[n] = true


func names() -> Array:
	return _names.duplicate()


func feature(name: String) -> Object:
	return _features.get(name)


# その関数を呼ぶ順の、仕組みの名前（その関数を持っている物だけ）
func order_names(hook: String, order: String = "") -> Array:
	var lead: Array = ORDERS.get(order if order != "" else hook, [])
	var out: Array = []
	for list: Array in [lead, ORDER, _names]:
		for name: String in list:
			if name not in out and _features.has(name) and is_instance_valid(_features[name]) and _features[name].has_method(hook):
				out.append(name)
	return out


func _targets(hook: String, order: String) -> Array:
	var key := hook + "|" + order
	if not _cache.has(key):
		_cache[key] = order_names(hook, order).map(func(name: String) -> Object: return _features[name])
	return _cache[key]


# その関数を持つ仕組み（呼ぶ順）。中心の側で、戻り値を自分で扱いたいときに使う（画面の案内など）
func in_order(hook: String, order: String = "") -> Array:
	return _targets(hook, order)


# 全部の仕組みの、その関数を順に呼ぶ
func run(hook: String, args: Array = [], order: String = "") -> void:
	for target: Object in _targets(hook, order):
		target.callv(hook, args)


# 順に呼んで、だれかが true を返したら、そこで止めて true を返す（F・左クリック・キー）
func first(hook: String, args: Array = [], order: String = "") -> bool:
	for target: Object in _targets(hook, order):
		if target.callv(hook, args):
			return true
	return false


# 順に呼んで、最初の空でない文を返す（持てない理由など）
func first_text(hook: String, args: Array = [], order: String = "") -> String:
	for target: Object in _targets(hook, order):
		var text: String = str(target.callv(hook, args))
		if text != "":
			return text
	return ""


# その合図は、どの仕組みの物か（"" ＝どれの物でもない＝中心の合図）
func owner_of(n: String) -> String:
	return _owner.get(n, "")


# 合図が届いた：持ち主の仕組みへ渡す。渡したら true（中心の側は、もう何もしない）
func event(n: String, a: Array) -> bool:
	if not _owner.has(n):
		return false
	var target: Object = _features[_owner[n]]
	if is_instance_valid(target) and target.has_method("hook_event"):
		target.hook_event(n, a)
	return true


# その合図は、見返しに載せるか（本番中に game.host_ev で流れたら、記録する）
func records(n: String) -> bool:
	return _rec.has(n)


# scripts/features/ に置いてある仕組みを、名前の順に作って登録する（全員の画面で同じ順。物のIDがそろう）。
# 仕組みの名前は、ファイルの名前（拡張子なし）。game と、あれば setup() を渡してから登録する
func spawn_folder(game: Node, dir: String = FOLDER) -> void:
	for path: String in scripts_in(dir):
		var made: Node = (load(path) as Script).new()
		var name: String = path.get_file().get_basename()
		made.name = name.to_pascal_case()
		made.set("game", game)
		game.add_child(made)
		if made.has_method("setup"):
			made.setup()
		add(name, made)


# その置き場にあるスクリプト（名前の順）。置き場が無ければ、空
static func scripts_in(dir: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files: PackedStringArray = ResourceLoader.list_directory(dir) if dir.begins_with("res://") else DirAccess.get_files_at(dir)
	for file: String in files:
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	out.sort()
	return out


# 登録の食い違いを、文の一覧で返す（空なら、食い違いは無い）。core_rec＝中心の側の「見返しに載せる合図」（main.gd の REC_EVENTS）
func problems(core_rec: Array = []) -> Array:
	var out: Array = _problems.duplicate()
	for name: String in _names:
		var target: Object = _features[name]
		if not is_instance_valid(target):
			out.append("登録した仕組みが、もう無い：%s" % name)
			continue
		for method: Dictionary in target.get_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("hook_") and not HOOKS.has(method_name) and method_name not in NOT_HOOKS:
				out.append("%s の %s() は、決まった名前に無い（書きまちがい？ feature_hooks.gd の HOOKS）" % [name, method_name])
		if target.has_method("hook_events") != target.has_method("hook_event"):
			out.append("%s：hook_events() と hook_event() は、両方そろえる" % name)
		var own: Array = target.hook_events() if target.has_method("hook_events") else []
		for n: String in own:
			if own.count(n) > 1:
				out.append("%s：合図「%s」を2回書いている" % [name, n])
		if target.has_method("hook_rec_events"):
			for n: String in target.hook_rec_events():
				if n not in own:
					out.append("%s：見返しに載せる合図「%s」が、自分の合図（hook_events）に無い" % [name, n])
				if n in core_rec:
					out.append("%s：見返しに載せる合図「%s」が、中心の側の一覧（main.gd の REC_EVENTS）にもある" % [name, n])
		for n: String in own:
			if n in core_rec and not _rec.has(n):
				out.append("%s：合図「%s」は中心の側の一覧（main.gd の REC_EVENTS）にあるのに、hook_rec_events() に無い" % [name, n])
	var lists := {"ORDER": ORDER}
	for key: String in ORDERS:
		lists[key] = ORDERS[key]
		if not HOOKS.has(key.get_slice(":", 0)):
			out.append("順番の表 ORDERS の「%s」は、決まった名前に無い" % key)
	for key: String in lists:
		var list: Array = lists[key]
		for name: String in list:
			if list.count(name) > 1:
				out.append("順番の表「%s」に、%s が2回ある" % [key, name])
			if key != "ORDER" and _features.has(name) and is_instance_valid(_features[name]) and not _features[name].has_method(key.get_slice(":", 0)):
				out.append("順番の表「%s」に %s があるのに、%s() を持っていない" % [key, name, key.get_slice(":", 0)])
	var unique: Array = []
	for line: String in out:
		if line not in unique:
			unique.append(line)
	return unique
