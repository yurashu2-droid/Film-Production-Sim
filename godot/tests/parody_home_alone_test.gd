extends "res://tests/parody_base.gd"
# 空き巣にご用心（室内スタジオ）：場面2「振り子が当たる」（hit）・場面3「炎がお尻に」（scorch）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_home_alone_test.gd
var torch: RigidBody3D


func title() -> String:
	return "空き巣にご用心"


func label() -> String:
	return "HOMEALONE"


func targets() -> Array:
	return [1, 2]


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-2.4, 0.05, -1.6 + 0.9 * aid))
		set_mark(aid, 1, C + Vector3(-0.2, 0.05, -1.6 + 0.9 * aid))
		set_mark(aid, 2, C + Vector3(0.6, 0.05, -0.2 + 0.6 * aid))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(-0.6, 0.8, -1.2), 60.0)
	await light(C + Vector3(-0.8, 0, -1.2))
	for p: RigidBody3D in rig.parts:
		if p.kind == "igniter" and torch == null:
			torch = p


func before(t: int) -> void:
	if t == 2:
		place(torch, C + Vector3(0.25, 0.05, -1.2))
		await frames(20)


func during(t: int) -> void:
	var a: Node3D = game.actors[0]
	if t == 1:
		# 吊るした物の振り子のかわりに、横から物を飛ばして当てる
		for i in 200:
			if a.beat_walking():
				break
			await physics_frame
		await frames(20)
		var bag: RigidBody3D = game.stage.spawn("sandbag", a.chest_pos() + Vector3(0, 0, 1.4), 0.0)
		await frames(1)
		bag.launch(a.chest_pos() + Vector3(0, -0.2, 1.4), Vector3(0, 0.5, -6.0), Vector3.ZERO)
	elif t == 2:
		for i in 300:
			if a.beat_arrived() and game.actors[1].beat_arrived():
				break
			await physics_frame
		rig.host_flame(torch)
