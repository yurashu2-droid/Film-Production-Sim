extends SceneTree
# 水の五種類が出て、それぞれ寿命で自分で片付くことを確かめる（画面なし）。
const WaterOrb := preload("res://vfx/vfx_water_orb.gd")
const WaterSlash := preload("res://vfx/vfx_water_slash.gd")
const WaterIce := preload("res://vfx/vfx_water_ice.gd")
const WaterManga := preload("res://vfx/vfx_water_manga.gd")
const WaterWave := preload("res://vfx/vfx_water_wave.gd")
var failed := false


func _initialize() -> void:
	run.call_deferred()
	create_timer(30.0, true, false, true).timeout.connect(func(): quit(2))


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func check(ok: bool, label: String) -> void:
	print("WATER_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var fxs: Array = [
		WaterOrb.spawn(world, Vector3(0, 0, 0)),
		WaterSlash.spawn(world, Vector3(4, 0, 0)),
		WaterIce.spawn(world, Vector3(8, 0, 0)),
		WaterManga.spawn(world, Vector3(12, 0, 0)),
		WaterWave.spawn(world, Vector3(16, 0, 0)),
	]
	check(fxs.all(func(fx): return is_instance_valid(fx) and fx.get_child_count() > 0), "five water effects spawn")
	await wait(1.0)
	check(fxs.all(func(fx): return is_instance_valid(fx)), "all five still running after 1 s")
	# 一番長い演出の寿命（8秒まで）より後で確かめる
	await wait(8.5)
	check(fxs.all(func(fx): return not is_instance_valid(fx)), "all five clean up after their life")
	print("WATERTEST_FAIL" if failed else "WATERTEST_OK")
	quit(1 if failed else 0)
