extends "res://tests/parody_base.gd"
# 弾をよける男（倉庫）：場面2「のけぞる二人のまわりを、カメラが回り込む」（orbit）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_dodge_test.gd


func title() -> String:
	return "弾をよける男"


func label() -> String:
	return "DODGE"


func targets() -> Array:
	return [1]


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-1.6 + 3.2 * aid, 0.05, -1.0))
		set_mark(aid, 1, C + Vector3(-0.6 + 1.2 * aid, 0.05, -1.0))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.4))
	await aim_camera(C + Vector3(0, 0.05, 4.0), C + Vector3(0, 1.0, -1.0), 60.0)
	await light(C + Vector3(0, 0, -1.0))


func during(_t: int) -> void:
	for i in 300:
		if game.actors[0].beat_arrived() and game.actors[1].beat_arrived():
			break
		await physics_frame
	# 台車を弧に引くかわりに、カメラを二人のまわりで少しずつ回す
	var mid: Vector3 = (game.actors[0].global_position + game.actors[1].global_position) * 0.5
	var film: RigidBody3D = game.film
	var r := Vector2(film.global_position.x - mid.x, film.global_position.z - mid.z).length()
	var ang := atan2(film.global_position.x - mid.x, film.global_position.z - mid.z)
	for i in 120:
		ang += 0.012
		var pos := Vector3(mid.x + sin(ang) * r, film.global_position.y, mid.z + cos(ang) * r)
		film.global_transform = Transform3D(Basis(Vector3.UP, ang), pos)
		await physics_frame
		if beats.lit[1]:
			break
