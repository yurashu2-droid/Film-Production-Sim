extends "res://tests/parody_base.gd"
# 沈まない船の舳先で（野外）：場面1「高い舳先に立つ」（high）・場面2「風を受ける」（wind）。送風機は依頼主が出しておく
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_ship_test.gd
var fan: RigidBody3D


func title() -> String:
	return "沈まない船の舳先で"


func label() -> String:
	return "SHIP"


func targets() -> Array:
	return [0, 1]


func prepare() -> void:
	# 舳先のかわりの台（高さ 0.5m。確かめの中だけの物）
	var deck := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.5, 1.8)
	shape.shape = box
	deck.add_child(shape)
	game.add_child(deck)
	deck.global_position = C + Vector3(0, 0.25, -1.6)
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-0.3 + 0.6 * aid, 0.05, 0.4 + 0.3 * aid))       # 床（舳先の手前）
		set_mark(aid, 1, C + Vector3(-0.3 + 0.6 * aid, 0.55, -1.9 + 0.5 * aid))     # 舳先の上（役者は、台に跳び乗って上る）
		set_mark(aid, 2, C + Vector3(-0.3 + 0.6 * aid, 0.55, -1.2))
		game.actors[aid].global_position = beats.spot(aid, 0)
	await aim_camera(C + Vector3(-0.5, 0.05, 5.0), C + Vector3(0, 1.4, -1.6), 60.0)
	await light(C + Vector3(0, 0.5, -1.6))
	fan = of_kind("scrap_fan")
	check(fan != null, "送風機が、廃材置き場に出してある")


func before(t: int) -> void:
	if t == 1:
		var at: Vector3 = C + Vector3(2.6, 0.05, 1.0)
		var to: Vector3 = C + Vector3(0.0, 0.0, -1.7) - at
		place(fan, at, atan2(to.x, to.z))
		await frames(20)


func during(t: int) -> void:
	if t == 1:
		rig.host_fan(fan, -1.0)
