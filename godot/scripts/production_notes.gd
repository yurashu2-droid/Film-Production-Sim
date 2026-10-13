extends RefCounted
# 実際の撮影カメラから測る、テイク単位の追加注文とNG日誌。
var game: Node
var crew_seconds := 0.0
var moon_seconds := 0.0
var cameos := {}
var role_seen := {}      # 役の付いた物が、撮影カメラに映った秒数（物のID → 秒）

func reset() -> void:
	crew_seconds = 0.0
	moon_seconds = 0.0
	cameos.clear()
	role_seen.clear()

# いま撮影カメラに映っている制作班（名前の一覧）。頭か胸が、画面の中にあって、物に隠れていなければ映っている。
# 物の陰に隠れていれば、映っていない扱い（場面の列を持つ依頼では、映っている間は「撮れている時間」に数えない。production_beats.gd）
func crew_in_frame() -> Array:
	var seen: Array = []
	for player: Node in game.players.values():
		if _seen(player.vis.head_pos(), player.get_rid()) or _seen(player.vis.chest_pos(), player.get_rid()):
			var index: int = game.PLAYER_CASTS.find(player.vis.tag)
			seen.append(game.PLAYER_NAMES[index] if index >= 0 else "スタッフ")
	return seen

func tick(delta: float) -> void:
	var crew := crew_in_frame()
	for name: String in crew:
		cameos[name] = float(cameos.get(name,0.0)) + delta
	if not crew.is_empty():
		crew_seconds += delta
	var moon_shown := false
	for prop: Node in game.props.values():
		if prop.absent:
			continue
		var role: String = game.judge.role_of(prop)
		if role == "" or not _seen(prop.center_global(),prop.get_rid()):
			continue
		role_seen[prop.pid] = float(role_seen.get(prop.pid,0.0)) + delta
		moon_shown = moon_shown or role == "moon"
	if moon_shown:
		moon_seconds += delta

func _seen(point: Vector3, subject: RID) -> bool:
	var film: Node = game.program_camera()
	var cam: Camera3D = film.view_cam
	if not game.judge._in_frame(cam,Vector2(film.view.size),point):
		return false
	var query := PhysicsRayQueryParameters3D.create(cam.global_position,point,1 | 2 | 8)
	query.exclude = [film.get_rid(),subject]
	var hit: Dictionary = film.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(point) <= 0.15

func finish(bonus_kind: Variant, take_index: int, passed: Array) -> Dictionary:
	# 以前は依頼の番号で渡していたので、数字も受ける
	var bonus: String = ["first_take", "no_crew", "moon"][bonus_kind] if bonus_kind is int else str(bonus_kind)
	var extra_ok := false
	match bonus:
		"first_take": extra_ok = take_index == 0
		"no_crew": extra_ok = crew_seconds <= 0.5
		"moon": extra_ok = moon_seconds >= 2.0
	return {"bonus_ok":extra_ok and not passed.is_empty() and not false in passed,"crew_seconds":crew_seconds,"moon_seconds":moon_seconds,"cameos":cameos.duplicate(),"early_boom":game.judge.boom_early,
		"cast":game.production.cast_report(role_seen,game.judge.boom_src,passed)}

func observations(data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var guests: Dictionary = data.get("cameos",{})
	for name: String in guests:
		if float(guests[name]) >= 0.5:
			lines.append("%sが%.1f秒出演。出演料は気持ちで。" % [name,float(guests[name])])
		if lines.size() >= 2:
			break
	if data.get("early_boom",false):
		lines.append("怪獣が出る前に爆発。街が先に降参した。" if game.judge.story == "kaiju" else "告白より先に爆発。愛がせっかちだった。")
	return lines
