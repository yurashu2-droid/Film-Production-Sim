extends Node
## 見ごたえ：危ない撮り方が、カメラに映っていれば報われる（リスクとリターン）。ギャラに上乗せする。
##   ・画面いっぱいの爆発：爆発が、撮影カメラの画面の高さの FILL 以上に映った（寄って撮る・大きくする・カメラの近くで爆ぜる）
##   ・間一髪：画面に映っている役者の CLOSE_M 以内で、爆発した（役者を巻き込みかねない所で撮る）
## 決めるのはホスト。本番中（フィルムを回している間）の爆発だけを、撮影カメラの映り方で測る。
## 数えるのは映り方だけ。吹き飛んだ物の数・壊した量には、上乗せしない（企画書：破壊量に報酬を付けない）。
const FILL := 0.5            # 画面の高さに対する、爆発の大きさ
const CLOSE_M := 2.2         # 役者の胸から、爆発の中心まで
const FILL_COINS := 80
const CLOSE_COINS := 60

var game: Node
var _now := {}               # 本番中に測っている、いちばんの映り方 {"size": 画面の高さに対する大きさ, "close": 間一髪だったか}
var _by_take := {}           # テイクの番号 → _now


func hook_take_start() -> void:
	_now = {"size": 0.0, "close": false}


func hook_take_cut() -> void:
	if not (game.takes as Array).is_empty():
		_by_take[game.takes.size() - 1] = _now.duplicate()


func hook_new_job() -> void:
	_by_take.clear()


func hook_return_office() -> void:
	_by_take.clear()


# 爆発（全員の画面に届く中心の合図）。ホストが、本番中だけ測る。見返しの爆発は数えない
func hook_core_event(n: String, a: Array) -> void:
	if n != "burst" or not Net.is_host() or game.replaying or game.state != game.S.TAKE or game.take_held():
		return
	var pos: Vector3 = a[0]
	var power: float = float(a[1])
	var measured := measure(pos, power)
	_now["size"] = maxf(float(_now.get("size", 0.0)), float(measured["size"]))
	_now["close"] = bool(_now.get("close", false)) or bool(measured["close"])


# その爆発が、いまの撮影カメラにどう映るか {"size": 画面の高さに対する大きさ（画面の外なら 0）, "close": 間一髪か}
func measure(pos: Vector3, power: float) -> Dictionary:
	var film: Node = game.program_camera()
	var out := {"size": 0.0, "close": false}
	if film == null or film.get("view_cam") == null:
		return out
	var cam: Camera3D = film.view_cam
	var vs := Vector2(film.view.size)
	if not _in_frame(cam, vs, pos):
		return out
	var across := _visible_size(pos, power)
	var up: Vector3 = cam.global_basis.y
	var top := cam.unproject_position(pos + up * across * 0.5)
	var bottom := cam.unproject_position(pos - up * across * 0.5)
	out["size"] = absf(top.y - bottom.y) / vs.y
	for actor: Node3D in game.actors:
		var chest: Vector3 = actor.chest_pos()
		if chest.distance_to(pos) <= CLOSE_M and _in_frame(cam, vs, chest):
			out["close"] = true
	return out


# 爆発の見た目の大きさ（m）。爆弾は火薬の量で（main.gd の _show_burst と同じ式）、爆炎の書割などは、その物の高さ
func _visible_size(pos: Vector3, power: float) -> float:
	if power > 0.0:
		var look := 0.55 + 0.45 * power if power < 1.0 else 1.0 + (power - 1.0) * 0.55
		return 3.2 * look
	var best := 0.9
	var near := 2.0
	for prop: Node3D in game.props.values():
		if prop.absent or game.judge.role_of(prop) != "boom":
			continue
		var d: float = prop.center_global().distance_to(pos)
		if d < near:
			near = d
			best = maxf(0.9, float((prop.half as Vector3).y) * 2.0)
	return best


static func _in_frame(cam: Camera3D, vs: Vector2, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p)
	return s.x >= 0.0 and s.y >= 0.0 and s.x <= vs.x and s.y <= vs.y


# ギャラの上乗せ（production_flow.gd の take_fee と、精算の文）
func hook_fee_lines(index: int) -> Array:
	var got: Dictionary = _by_take.get(index, {})
	var out: Array = []
	if float(got.get("size", 0.0)) >= FILL:
		out.append(["見ごたえ：画面いっぱいの爆発", FILL_COINS])
	if bool(got.get("close", false)):
		out.append(["見ごたえ：間一髪（役者のすぐそばで爆発）", CLOSE_COINS])
	return out
