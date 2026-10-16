extends "res://tests/parody_base.gd"
# 階段を駆け上がれ（室内スタジオ）：場面2「駆け上がる」（climb。役者は段に跳び乗って上る）・場面3「頂上で万歳」（high）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_stairs_test.gd


func title() -> String:
	return "階段を駆け上がれ"


func label() -> String:
	return "STAIRS"


func targets() -> Array:
	return [1, 2]


func prepare() -> void:
	# 階段のかわりの段：0.5m の段と、その奥に 1.0m の頂上（確かめの中だけの物）。雇った役者も、段に跳び乗って上る
	for row: Array in [[Vector3(0.4, 0.25, -0.9), Vector3(0.8, 0.5, 1.8)], [Vector3(1.8, 0.5, -0.9), Vector3(2.0, 1.0, 1.8)]]:
		var step := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = row[1]
		shape.shape = box
		step.add_child(shape)
		game.add_child(step)
		step.global_position = C + (row[0] as Vector3)
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-3.0, 0.05, -1.4 + 0.8 * aid))
		set_mark(aid, 1, C + Vector3(-1.0, 0.05, -1.4 + 0.8 * aid))
		set_mark(aid, 2, C + Vector3(1.5 + 0.6 * aid, 1.05, -1.2 + 0.6 * aid))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(0.6, 1.2, -1.0), 62.0)
	await light(C + Vector3(0.6, 0.6, -1.0))

