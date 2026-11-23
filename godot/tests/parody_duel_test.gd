extends "res://tests/parody_base.gd"
# 夕暮れの決闘（時代劇）：場面1「屋敷の前で向き合う」（show。屋敷の役の物が映る）・場面2「風が吹く」（wind）。
#   依頼主が出しておく障子を屋敷の役にし、送風機の風を二人の正面から当てる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_duel_test.gd
var fan: RigidBody3D
var shoji: RigidBody3D


func title() -> String:
	return "夕暮れの決闘（時代劇）"


func label() -> String:
	return "DUEL"


func targets() -> Array:
	return [0, 1]


func accept(job: int) -> void:
	flow.daily = true
	flow.restock()
	await frames(5)
	game.h_accept_job(job)
	await frames(20)
	flow.daily = false
	fan = of_kind("scrap_fan")
	shoji = of_kind("scrap_sliding_shoji")
	check(fan != null and shoji != null, "依頼主の頼みで、送風機と障子が出してある")


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-0.5 + 1.0 * aid, 0.05, -1.5))
		set_mark(aid, 1, C + Vector3(-0.5 + 1.0 * aid, 0.05, -2.0))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.4))
		game.actors[aid].global_position = beats.spot(aid, 0)
	await aim_camera(C + Vector3(0, 0.05, 5.5), C + Vector3(0, 0.9, -1.8), 60.0)
	await light(C + Vector3(0, 0, -1.5))
	check(flow.Cast.roles_for(flow.story()) == ["manor", "woods"], "台本の役は、屋敷と森")
	place(shoji, C + Vector3(0.0, 0.05, -3.6))
	await frames(20)
	check(flow.cast_set(shoji.pid, "manor"), "障子を、屋敷の役にする")
	var at: Vector3 = C + Vector3(-2.6, 0.05, 0.4)
	var to: Vector3 = C + Vector3(0.0, 0.0, -1.5) - at
	place(fan, at, atan2(to.x, to.z))
	await frames(20)
	rig.host_fan(fan, -1.0)
