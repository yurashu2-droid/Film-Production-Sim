extends Node
## 撮り方の加算・減点（会社の紹介動画の、一人ずつ寄り。production_beats.gd の "roll"）：
##   ・止めずに撮り切った（カメラを振って、一人ずつ寄りを一続きで撮った）：撮影技術として加算
##   ・頭が画面から切れたまま撮れた人（見切れ）：一人ごとに少し引く
## 決めるのはホスト（テイクが終わったときに、場面の列の数えを写す）。精算の行は production_flow.gd の take_fee に入る
const PAN_COINS := 60
const CUT_COINS := -10

var game: Node
var _by_take := {}           # テイクの番号 → {"pan": bool, "cut": [役の名前, ...]}


func _roll_job() -> bool:
	var beats: Node = game.get("beats")
	if beats == null or not beats.active():
		return false
	for b: Dictionary in beats.list():
		if str(b.get("rule", "")) == "roll":
			return true
	return false


func hook_take_cut() -> void:
	if (game.takes as Array).is_empty() or not _roll_job():
		return
	var beats: Node = game.beats
	var i: int = beats._rule_index("roll")
	var done: bool = i >= 0 and i < (beats.lit as Array).size() and bool(beats.lit[i])
	var cut: Array = []
	for aid: int in beats.roll_cut:
		cut.append(beats.role_name(aid))
	_by_take[game.takes.size() - 1] = {"pan": done and int(beats.roll_holds) == 0, "cut": cut}


func hook_new_job() -> void:
	_by_take.clear()


func hook_return_office() -> void:
	_by_take.clear()


func hook_fee_lines(index: int) -> Array:
	var got: Dictionary = _by_take.get(index, {})
	var out: Array = []
	if bool(got.get("pan", false)):
		out.append(["撮影技術：カメラを振って、一人ずつ寄りを止めずに撮った", PAN_COINS])
	for name: String in got.get("cut", []):
		out.append(["%sの頭が見切れていた" % name, CUT_COINS])
	return out
