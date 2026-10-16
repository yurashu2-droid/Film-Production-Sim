extends "res://tests/parody_base.gd"
# カップ麺の3分（CM・会社の前）：場面1「お湯を注ぐ」（show。カップ麺の役の物が映る）・場面2「タイマーがチン」（ring）。
#   カップ麺の役：ゴミ袋から出てくるマグカップを見立てる。役が決まっていない・映っていないと、場面1は撮れない。
#   目覚まし時計を巻いておくと、映っている所で鳴って撮れる
#   godot --headless --path godot --fixed-fps 60 --script res://tests/parody_noodle_test.gd


func title() -> String:
	return "カップ麺の3分（CM）"


func label() -> String:
	return "NOODLE"


func targets() -> Array:
	return [0, 1]


func prepare() -> void:
	for aid in 2:
		set_mark(aid, 0, C + Vector3(-1.2 + 2.4 * aid, 0.05, -1.6))
		set_mark(aid, 1, C + Vector3(-0.6 + 1.2 * aid, 0.05, -1.0))
		set_mark(aid, 2, C + Vector3(-0.4 + 0.8 * aid, 0.05, 0.6))
	await aim_camera(C + Vector3(0, 0.05, 5.0), C + Vector3(0, 0.8, -1.0), 55.0)
	await light(C + Vector3(0, 0, -1.0))
	check(flow.Cast.roles_for(flow.story()) == ["noodle", "kettle"], "台本の役は、カップ麺とやかん")
	check(of_kind("scrap_teapot") != null, "依頼主の頼みで、やかん代わりのティーポットが出してある")
	# ゴミ袋から出たマグカップ（袋を振ったのと同じに、しまってある物から出す）を、二人のあいだに置く
	var mug: RigidBody3D = null
	for p: Node in game.props.values():
		if p.kind == "scrap_mug":
			mug = p
	var hidden: Array = (flow.stash as Array).duplicate()
	hidden.erase(mug.pid)
	game.host_ev("stash", [hidden])
	place(mug, C + Vector3(0.0, 0.05, -1.3))
	await frames(10)
	check(flow.cast_set(mug.pid, "noodle"), "マグカップを、カップ麺の役にする")
	check(str(flow.cast_sheet()["rows"][0]["name"]) == "カップ麺", "配役表の最初の役は、カップ麺")


func before(_t: int) -> void:
	var clock: RigidBody3D = of_kind("timer")
	place(clock, C + Vector3(0.0, 0.05, -0.2))
	await frames(20)
	rig.timers[clock.pid] = 4.0      # 3分のかわりに4秒巻いておく（手ぶらで F を押すのと同じ）
	rig._changed()
