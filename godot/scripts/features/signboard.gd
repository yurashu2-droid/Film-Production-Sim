extends Node
## 会社のCM（最初の一本）だけの上乗せ：手描きの看板（カンペ・等身大パネルに描いた会社の名前など）が、CMに映った。
##   依頼主は「会社の名前が、どこかに映っているといいですね」とだけ言う。何に・どう描いて・どこに置くかは制作班が決める。
##   文字は読めないので、何か描いてある描ける物（白でない所が PAINTED 以上）が、表をカメラへ向けて、
##   隠れずに撮影カメラに NEED_SEC 秒以上映ったら、上乗せ（SIGN_COINS）。フィルムを回している間だけ数える。
## 決めるのはホスト。
const PAINTED := 0.02
const NEED_SEC := 1.0
const SIGN_COINS := 100
const CHECK_EVERY := 0.1

var game: Node
var _seen := 0.0             # 本番中に、手描きの看板が映っていた秒数
var _clock := 0.0
var _by_take := {}           # テイクの番号 → 映っていたか


func _debut() -> bool:
	var flow: Node = game.production
	return flow != null and bool(flow.job().get("debut", false))


func hook_take_start() -> void:
	_seen = 0.0


func hook_take_cut() -> void:
	if not (game.takes as Array).is_empty():
		_by_take[game.takes.size() - 1] = _seen >= NEED_SEC


func hook_new_job() -> void:
	_by_take.clear()


func hook_return_office() -> void:
	_by_take.clear()


func _physics_process(delta: float) -> void:
	if not Net.is_host() or game.replaying or game.state != game.S.TAKE or game.take_held() or not _debut():
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = CHECK_EVERY
	if showing():
		_seen += CHECK_EVERY


# いま、手描きの看板が撮影カメラに映っているか（表をカメラへ向けて、隠れずに、画面の中に）
func showing() -> bool:
	var cards: Node = game.get("cue_cards")
	var film: Node = game.program_camera()
	if cards == null or film == null or film.get("view_cam") == null:
		return false
	var cam: Camera3D = film.view_cam
	var vs := Vector2(film.view.size)
	var space: PhysicsDirectSpaceState3D = film.get_world_3d().direct_space_state
	for board: RigidBody3D in (cards.boards as Dictionary).values():
		if board.absent or not board.has_method("painted") or float(board.painted()) < PAINTED:
			continue
		var c: Vector3 = board.center_global()
		if cam.is_position_behind(c):
			continue
		var s := cam.unproject_position(c)
		if s.x < 0.0 or s.y < 0.0 or s.x > vs.x or s.y > vs.y:
			continue
		if board.global_basis.z.dot(cam.global_position - c) <= 0.0:
			continue          # 裏を向けている
		var ray := PhysicsRayQueryParameters3D.create(cam.global_position, c, 1 | 2 | 4 | 16)
		ray.exclude = [film.get_rid(), board.get_rid()]
		if not space.intersect_ray(ray).is_empty():
			continue          # 何かの陰
		return true
	return false


func hook_fee_lines(index: int) -> Array:
	if bool(_by_take.get(index, false)):
		return [["CMに、手描きの看板（会社の名前）が映った", SIGN_COINS]]
	return []
