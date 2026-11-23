extends "res://tests/parody_base.gd"
# きょうのお料理（料理番組・会社の前）：場面1「きょうの料理」（show。料理の役の物が映る）・場面2「フランベ」（scorch）・
#   場面3「オーブンがチン」（ring）。フライパンを料理の役にし、点火トーチの炎を二人のそばで出し、目覚まし時計を鳴らす
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_cooking_test.gd
var pan: RigidBody3D
var torch: RigidBody3D


func title() -> String:
	return "きょうのお料理（料理番組）"


func label() -> String:
	return "COOKING"


func targets() -> Array:
	return [0, 1, 2]


func accept(job: int) -> void:
	flow.daily = true
	flow.restock()
	await frames(5)
	game.h_accept_job(job)
	await frames(20)
	flow.daily = false
	pan = of_kind("scrap_frying_pan")
	check(pan != null and of_kind("scrap_kitchen_stove") != null, "依頼主の頼みで、フライパンとコンロが出してある")


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-1.0 + 2.0 * aid, 0.05, -1.6))
		set_mark(aid, 1, C + Vector3(-0.2, 0.05, -1.6 + 0.9 * aid))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.6))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(-0.3, 0.8, -1.3), 60.0)
	await light(C + Vector3(-0.3, 0, -1.3))
	check(flow.Cast.roles_for(flow.story()) == ["dish", "stove"], "台本の役は、料理とコンロ")
	place(pan, C + Vector3(0.0, 0.05, -1.3))
	await frames(20)
	check(flow.cast_set(pan.pid, "dish"), "フライパンを、料理の役にする")
	for p: RigidBody3D in rig.parts:
		if p.kind == "igniter" and torch == null:
			torch = p


func before(t: int) -> void:
	if t == 1:
		place(torch, C + Vector3(0.25, 0.05, -1.2))
		await frames(20)
	elif t == 2:
		place(torch, C + Vector3(3.0, 0.05, 2.0))
		var clock: RigidBody3D = of_kind("timer")
		place(clock, C + Vector3(0.4, 0.05, -0.4))
		await frames(20)
		rig.timers[clock.pid] = 4.0
		rig._changed()


func during(t: int) -> void:
	if t == 1:
		for i in 300:
			if game.actors[0].beat_arrived() and game.actors[1].beat_arrived():
				break
			await physics_frame
		rig.host_flame(torch)
