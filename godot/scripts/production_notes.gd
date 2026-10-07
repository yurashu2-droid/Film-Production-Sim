extends RefCounted
# 実際の撮影カメラから測る、テイク単位の追加注文とNG日誌。
var game: Node
var crew_seconds := 0.0
var moon_seconds := 0.0
var cameos := {}

func reset() -> void:
	crew_seconds = 0.0
	moon_seconds = 0.0
	cameos.clear()

func tick(delta: float) -> void:
	var someone := false
	for player: Node in game.players.values():
		if _seen(player.vis.head_pos(), player.get_rid()) or _seen(player.vis.chest_pos(), player.get_rid()):
			someone = true
			var index: int = game.PLAYER_CASTS.find(player.vis.tag)
			var name: String = game.PLAYER_NAMES[index] if index >= 0 else "スタッフ"
			cameos[name] = float(cameos.get(name,0.0)) + delta
	if someone:
		crew_seconds += delta
	for prop: Node in game.props.values():
		if not prop.absent and "moon" in prop.tags and _seen(prop.center_global(),prop.get_rid()):
			moon_seconds += delta
			break

func _seen(point: Vector3, subject: RID) -> bool:
	var cam: Camera3D = game.film.view_cam
	if not game.judge._in_frame(cam,Vector2(game.film.view.size),point):
		return false
	var query := PhysicsRayQueryParameters3D.create(cam.global_position,point,1 | 2 | 8)
	query.exclude = [game.film.get_rid(),subject]
	var hit: Dictionary = game.film.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(point) <= 0.15

func finish(job_index: int, take_index: int, passed: Array) -> Dictionary:
	var extra_ok := false
	match job_index:
		0: extra_ok = take_index == 0
		1: extra_ok = crew_seconds <= 0.5
		2: extra_ok = moon_seconds >= 2.0
	return {"bonus_ok":extra_ok and passed.count(true) == 3,"crew_seconds":crew_seconds,"moon_seconds":moon_seconds,"cameos":cameos.duplicate(),"early_boom":game.judge.boom_early}

func observations(data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var guests: Dictionary = data.get("cameos",{})
	for name: String in guests:
		if float(guests[name]) >= 0.5:
			lines.append("%sが%.1f秒出演。出演料は気持ちで。" % [name,float(guests[name])])
		if lines.size() >= 2:
			break
	if data.get("early_boom",false):
		lines.append("告白より先に爆発。愛がせっかちだった。")
	return lines
