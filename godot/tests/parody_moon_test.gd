extends "res://tests/parody_base.gd"
# 月夜の自転車（野外）：場面2「満月の前を横切る」（cross）。月の前を、役者が画面の上で重なって横切ると撮れる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_moon_test.gd


func title() -> String:
	return "月夜の自転車"


func label() -> String:
	return "MOONBIKE"


func targets() -> Array:
	return [1]


func prepare() -> void:
	var moon: RigidBody3D = of_kind("moon")
	check(moon != null, "月の役にできる物がある")
	place(moon, me.global_position + Vector3(1.0, 0.1, 0.0))
	await frames(10)
	game.h_cast(moon.pid, "moon")
	await frames(5)
	check(game.judge.role_of(moon) == "moon", "物を月の役にした")
	# 月の丸の真ん中が、役者の胸のあたりに来るように置く（月の物は台つきで、丸は上のほうにある）
	var lift: float = moon.center_global().y - moon.global_position.y
	place(moon, C + Vector3(0.0, 1.15 - lift, -3.3), 0.0, true)
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-3.6, 0.05, -2.0 + 0.6 * aid))
		set_mark(aid, 1, C + Vector3(3.6, 0.05, -2.0 + 0.6 * aid))
		set_mark(aid, 2, C + Vector3(1.0 + 0.8 * aid, 0.05, 0.4))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(0, 1.2, -3.3), 60.0)



