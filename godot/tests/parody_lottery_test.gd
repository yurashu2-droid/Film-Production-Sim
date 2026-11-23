extends "res://tests/parody_base.gd"
# 商店街の福引き（CM・会社の前）：場面1「店先」（show。商店街の役の物が映る）・場面2「大当たりの鐘」（ring）。
#   依頼主が出しておく屋台を、商店街の役にする。目覚まし時計を巻いておくと、映っている所で鳴って撮れる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_lottery_test.gd
var stall: RigidBody3D


func title() -> String:
	return "商店街の福引き（CM）"


func label() -> String:
	return "LOTTERY"


func targets() -> Array:
	return [0, 1]


func accept(job: int) -> void:
	flow.daily = true
	flow.restock()
	await frames(5)
	game.h_accept_job(job)
	await frames(20)
	flow.daily = false
	stall = of_kind("scrap_market_stall")
	check(stall != null, "依頼主の頼みで、屋台が出してある")


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-1.2 + 2.4 * aid, 0.05, -1.6))
		set_mark(aid, 1, C + Vector3(-0.6 + 1.2 * aid, 0.05, -1.0))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.6))
	await aim_camera(C + Vector3(0, 0.05, 6.0), C + Vector3(0, 0.9, -1.5), 60.0)
	await light(C + Vector3(0, 0, -1.2))
	check(flow.Cast.roles_for(flow.story()) == ["street", "relic"], "台本の役は、商店街と特賞")
	place(stall, C + Vector3(0.0, 0.05, -2.3))
	await frames(20)
	check(flow.cast_set(stall.pid, "street"), "屋台を、商店街の役にする")
	check(str(flow.cast_sheet()["rows"][0]["name"]) == "商店街", "配役表の最初の役は、商店街（台本の中の呼び名）")


func before(_t: int) -> void:
	var clock: RigidBody3D = of_kind("timer")
	place(clock, C + Vector3(0.0, 0.05, -0.2))
	await frames(20)
	rig.timers[clock.pid] = 4.0
	rig._changed()
