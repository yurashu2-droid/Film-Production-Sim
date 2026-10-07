extends SceneTree
# Pixel×Real のエフェクトが全部エラーなく出て、自分で片付くことを確かめる。
const Flame := preload("res://pixel_vfx/px_flame.gd")
const Burst := preload("res://pixel_vfx/px_burst.gd")
const Portal := preload("res://pixel_vfx/px_portal.gd")
const Teleport := preload("res://pixel_vfx/px_teleport.gd")
var failed := false
var arrived := 0
func _initialize() -> void:
	run.call_deferred()
	create_timer(20.0, true, false, true).timeout.connect(func(): quit(2))
func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
func check(ok: bool, label: String) -> void:
	print("PX_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var flame: Node3D = Flame.spawn(world, Vector3.ZERO)
	var timed_flame: Node3D = Flame.spawn(world, Vector3(3, 0, 0), 1.0, 0.6, "toxic")
	var burst: Node3D = Burst.spawn(world, Vector3(6, 1, 0))
	var portal: Node3D = Portal.spawn(world, Vector3(9, 1.5, 0), 1.0, 1.0)
	var teleport: Node3D = Teleport.spawn(world, Vector3(12, 0, 0))
	teleport.materialized.connect(func(): arrived += 1)
	check(get_nodes_in_group("pixel_vfx").size() == 5, "all pixel effects spawn")
	paused = true
	var age: float = burst.age
	await wait(0.15)
	check(is_equal_approx(burst.age, age), "pause freezes pixel effects")
	paused = false
	await wait(4.2)
	check(not is_instance_valid(burst) and not is_instance_valid(portal) and not is_instance_valid(teleport), "one-shot pixel effects clean up")
	check(arrived == 1, "teleport reports materialized once")
	check(not is_instance_valid(timed_flame), "timed flame cleans up")
	check(is_instance_valid(flame), "untimed flame keeps going")
	flame.extinguish()
	await wait(2.5)
	check(get_nodes_in_group("pixel_vfx").is_empty(), "extinguished flame cleans up")
	print("PXTEST_FAIL" if failed else "PXTEST_OK")
	quit(1 if failed else 0)
