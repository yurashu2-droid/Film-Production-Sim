extends "res://tests/parody_base.gd"
# 階段を駆け上がれ（室内スタジオ）：場面2「駆け上がる」（climb）・場面3「頂上で万歳」（high）
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_stairs_test.gd


func title() -> String:
	return "階段を駆け上がれ"


func label() -> String:
	return "STAIRS"


func targets() -> Array:
	return [1, 2]


func prepare() -> void:
	# 頂上のかわりの台（高さ 1.0m。確かめの中だけの物）
	var top := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 1.8)
	shape.shape = box
	top.add_child(shape)
	game.add_child(top)
	top.global_position = C + Vector3(1.8, 0.5, -0.9)
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-3.0, 0.05, -1.4 + 0.8 * aid))
		set_mark(aid, 1, C + Vector3(-1.0, 0.05, -1.4 + 0.8 * aid))
		set_mark(aid, 2, C + Vector3(1.5 + 0.6 * aid, 1.05, -1.2 + 0.6 * aid))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(0.6, 1.2, -1.0), 62.0)
	await light(C + Vector3(0.6, 0.6, -1.0))


func during(t: int) -> void:
	if t == 1:
		# 階段のかわりに、走り出したら台の上へ上げる（NPC の役者は、段を上れない）
		for i in 200:
			if game.actors[0].beat_walking():
				break
			await physics_frame
		await frames(10)
		for aid in 2:
			var a: Node3D = game.actors[aid]
			a.global_position = beats.mark(aid, 2).global_position + Vector3(-0.3, 0.05, 0)
