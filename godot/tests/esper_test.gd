extends SceneTree
# 超能力の演出（vfx/esper/）が、6本ともエラーなく出て、止まり、寿命で片付くことを確かめる。
#   godot --headless --path godot --script res://tests/esper_test.gd
const NAMES := ["pk", "teleport", "pyro", "telepathy", "barrier", "sight"]
var failed := false


func _initialize() -> void:
	run.call_deferred()
	create_timer(60.0, true, false, true).timeout.connect(func(): quit(2))


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, false).timeout


func check(ok: bool, label: String) -> void:
	print("ESPER_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var effects: Array[Node3D] = []
	for i in NAMES.size():
		var script: GDScript = load("res://vfx/esper/esper_%s.gd" % NAMES[i])
		effects.append(script.spawn(world, Vector3.ZERO))
	check(effects.all(func(fx): return is_instance_valid(fx) and fx.get_child_count() >= 3), "six esper effects spawn with their stage")
	await wait(0.5)
	paused = true
	var ages: Array = effects.map(func(fx): return fx.age)
	await wait(0.2)
	var frozen := true
	for i in effects.size():
		frozen = frozen and is_equal_approx(effects[i].age, ages[i])
	check(frozen, "pause freezes every effect")
	paused = false
	# 全部の場面（浮く・跳ぶ・燃える・渡る・弾く・見つける）を通す
	await wait(4.4)
	check(effects.all(func(fx): return is_instance_valid(fx)), "effects survive their whole choreography")
	await wait(4.2)
	await process_frame
	check(effects.all(func(fx): return not is_instance_valid(fx)), "effects clean up at the end of their life")
	await wait(2.5)
	await process_frame
	check(get_nodes_in_group("vfx").is_empty(), "nothing is left behind (fires, shots, dust)")
	print("ESPER_TEST_FAIL" if failed else "ESPER_TEST_OK")
	quit(1 if failed else 0)
