extends "res://tests/parody_base.gd"
# 髪がなびく車のCM（会社の前）：依頼主が送風機と車の正面の書割を出しておく・場面1「風を受ける」（wind）・場面2「走り抜ける」（pass）
#   車の正面は、ふだんは包みの中にしまってある（features/junk_bags.gd）。依頼を受けると、廃材置き場の空いた所に出てくる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_car_test.gd
var fan: RigidBody3D
var bus: RigidBody3D


func title() -> String:
	return "髪がなびく車のCM"


func label() -> String:
	return "CARCM"


func targets() -> Array:
	return [0, 1]


func accept(job: int) -> void:
	# 普段と同じに、廃材置き場の日替わりで、しまってある物を作る
	flow.daily = true
	flow.restock()
	await frames(5)
	game.h_accept_job(job)
	await frames(20)
	flow.daily = false
	fan = of_kind("scrap_fan")
	bus = of_kind("scrap_car_front_shell")
	check(fan != null and bus != null, "依頼主の頼みで、送風機と車の正面が出してある")
	if bus != null:
		await frames(30)
		check(bus.global_position.y > -0.5, "車の正面は、地面の下ではなく、廃材置き場に出ている（%s）" % str(bus.global_position))


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-0.5 + 1.0 * aid, 0.05, -1.5))
		set_mark(aid, 1, C + Vector3(-0.5 + 1.0 * aid, 0.05, -2.2))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.4))
		game.actors[aid].global_position = beats.mark(aid, 0).global_position
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(0, 0.9, -1.5), 60.0)
	await light(C + Vector3(0, 0, -1.5))
	var at: Vector3 = C + Vector3(-2.6, 0.05, 0.4)
	var to: Vector3 = C + Vector3(0.0, 0.0, -1.5) - at
	place(fan, at, atan2(to.x, to.z))
	await frames(20)
	rig.host_fan(fan, -1.0)


func before(t: int) -> void:
	if t == 1:
		place(bus, C + Vector3(-3.5, 0.05, 1.2), PI * 0.5)
		await frames(20)


func during(t: int) -> void:
	if t == 1:
		# 台車に載せて引くかわりに、横へ走らせる
		for i in 150:
			bus.linear_velocity = Vector3(3.0, bus.linear_velocity.y, 0.0)
			bus.sleeping = false
			await physics_frame
			if beats.lit[1]:
				break
