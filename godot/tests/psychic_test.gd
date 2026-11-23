extends SceneTree
# 念力の演出（vfx/vfx_psychic.gd）が、全部の型でエラーなく出て、離すと自分で片付くことを確かめる。
#   godot --headless --path godot --script res://tests/psychic_test.gd
const Psychic := preload("res://vfx/vfx_psychic.gd")
var failed := false


func _initialize() -> void:
	run.call_deferred()
	create_timer(30.0, true, false, true).timeout.connect(func(): quit(2))


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, false).timeout


func check(ok: bool, label: String) -> void:
	print("PSYCHIC_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func box(world: Node3D, at: Vector3) -> Node3D:
	var prop := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(0.6, 0.4, 0.5)
	prop.add_child(mesh)
	world.add_child(prop)
	prop.global_position = at
	return prop


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var effects: Array[Node3D] = []
	var props: Array[Node3D] = []
	var styles: Array = Psychic.STYLES.keys()
	for i in styles.size():
		var prop := box(world, Vector3(i * 4.0, 1.2, 0))
		props.append(prop)
		effects.append(Psychic.attach(world, prop, {"style": styles[i], "tint": Color(1.0, 0.5, 0.2)}))
	check(effects.all(func(fx): return is_instance_valid(fx) and fx.get_child_count() >= 3), "every style builds the object and hand auras")
	# 動かしながら持つ：念波が飛び、止まらずに進む
	for step in 50:
		for i in props.size():
			props[i].global_position += Vector3(0.0, 0.01, 0.02)
			var hand := Vector3(i * 4.0, 1.0, 4.0)
			effects[i].hold(PackedVector3Array([hand + Vector3(0.2, 0, 0), hand - Vector3(0.2, 0, 0)]), props[i].global_position + Vector3(0, 0, 0.25))
		await process_frame
	check(effects.all(func(fx): return fx.age > 0.2 and fx.holding()), "effects keep running while held")
	check(effects.all(func(fx): return fx._pulses.size() >= 1 or fx._next_pulse > 0.0), "psychic waves are sent from the hand")
	paused = true
	var age: float = effects[0].age
	await wait(0.15)
	check(is_equal_approx(effects[0].age, age), "pause freezes the effect")
	paused = false
	# 手で持てる近さ：出さない
	effects[0].hold(PackedVector3Array([props[0].global_position + Vector3(0, 0, 0.3)]), props[0].global_position)
	await process_frame
	await process_frame
	check(effects[0]._reach < 0.05 and not effects[0]._aura.visible, "nothing is drawn when the hand can reach the prop")
	# 離す：残りが流れ切ってから、自分で片付く
	for fx in effects:
		fx.release()
	check(effects.all(func(fx): return not fx.holding()), "release stops the supply")
	await wait(2.0)
	await process_frame
	check(effects.all(func(fx): return not is_instance_valid(fx)), "released effects clean up by themselves")
	# 持っている物が消えたら、演出も消える
	var orphan: Node3D = Psychic.attach(world, props[1])
	await process_frame
	props[1].free()
	await process_frame
	await process_frame
	check(not is_instance_valid(orphan), "effect goes away with its prop")
	check(get_nodes_in_group("vfx").is_empty(), "nothing is left behind")
	print("PSYCHIC_TEST_FAIL" if failed else "PSYCHIC_TEST_OK")
	quit(1 if failed else 0)
