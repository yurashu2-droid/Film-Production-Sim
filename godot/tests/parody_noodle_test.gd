extends "res://tests/parody_base.gd"
# カップ麺の3分（CM・会社の前）：場面2「タイマーがチン」（ring）。目覚まし時計を巻いておくと、映っている所で鳴って撮れる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_noodle_test.gd


func title() -> String:
	return "カップ麺の3分（CM）"


func label() -> String:
	return "NOODLE"


func targets() -> Array:
	return [1]


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-1.2 + 2.4 * aid, 0.05, -1.6))
		set_mark(aid, 1, C + Vector3(-0.6 + 1.2 * aid, 0.05, -1.0))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.6))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(0, 0.8, -1.0), 55.0)
	await light(C + Vector3(0, 0, -1.0))


func before(_t: int) -> void:
	var clock: RigidBody3D = of_kind("timer")
	place(clock, C + Vector3(0.0, 0.05, -0.2))
	await frames(20)
	rig.timers[clock.pid] = 4.0      # 3分のかわりに4秒巻いておく（手ぶらで F を押すのと同じ）
	rig._changed()
