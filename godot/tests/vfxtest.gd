extends SceneTree
# VFXが全部エラーなく出て、使い捨てのものは自分で片付くことを確かめる。
const Explosion := preload("res://vfx/vfx_explosion.gd")
const Fire := preload("res://vfx/vfx_fire.gd")
const Smoke := preload("res://vfx/vfx_smoke.gd")
const Projectile := preload("res://vfx/vfx_projectile.gd")
const Lightning := preload("res://vfx/vfx_lightning.gd")
const Brawl := preload("res://vfx/vfx_brawl.gd")
const Mushroom := preload("res://vfx/vfx_mushroom.gd")
const FireTornado := preload("res://vfx/vfx_fire_tornado.gd")
const MOTIFS := [preload("res://vfx/vfx_motif_solar.gd"), preload("res://vfx/vfx_motif_geyser.gd"), preload("res://vfx/vfx_motif_jelly.gd"), preload("res://vfx/vfx_motif_ferro.gd"), preload("res://vfx/vfx_motif_seed.gd")]
var failed := false
var hits := 0
func _initialize() -> void:
	run.call_deferred()
	create_timer(20.0, true, false, true).timeout.connect(func(): quit(2))
func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, false).timeout
func check(ok: bool, label: String) -> void:
	print("VFX_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var fire_tornado: Node3D = FireTornado.spawn(world, Vector3(-8,0,-8))
	var motifs: Array[Node3D] = []
	for i in MOTIFS.size():
		motifs.append(MOTIFS[i].spawn(world, Vector3(i*6, 0, -10)))
	check(motifs.all(func(fx): return is_instance_valid(fx) and fx.get_child_count()>0), "five motif effects spawn")
	var big: Node3D = Explosion.spawn(world, Vector3(0, 1.3, 0))
	var small: Node3D = Explosion.spawn(world, Vector3(6, 1.3, 0), 0.9, 1.25, false)
	var air: Node3D = Explosion.spawn(world, Vector3(0, 9, 0), 2.0, -1.0)
	var fuse: Node3D = Explosion.fuse(world, Vector3(0, 0.5, 0), 0.8)
	var bolt: Node3D = Lightning.strike(world, Vector3(3, 0, 0))
	var brawl: Node3D = Brawl.spawn(world, Vector3(0, 0, 6), 1.4)
	check(brawl.get_child_count() >= 9, "brawl builds cloud, strokes and comic hits")
	var mushroom: Node3D = Mushroom.spawn(world, Vector3(7, 0, 6))
	var soil: Node3D = Mushroom.spawn(world, Vector3(10, 0, 6), 1, "soil")
	var mini: Node3D = Mushroom.spawn(world, Vector3(13, 0, 6), 0.7, "mini")
	check(mushroom.get_child_count() >= 2, "reference explosion builds incandescent body and pressure collar")
	var shot: Node3D = Projectile.fire(world, Vector3(-4, 1, 0), Vector3(4, 1, 0), {"palette": "arcane", "arc": Vector3(0, 2, 0), "ease": "in"})
	shot.impacted.connect(func(_pos: Vector3, _dir: Vector3): hits += 1)
	var miss: Node3D = Projectile.fire(world, Vector3(-4, 1, 2), Vector3(4, 1, 2), {"palette": "venom", "buildup": 0.0, "hit": false})
	miss.impacted.connect(func(_pos: Vector3, _dir: Vector3): hits += 10)
	var fire: Node3D = Fire.spawn(world, Vector3(0, 0, 4))
	var timed_fire: Node3D = Fire.spawn(world, Vector3(2, 0, 4), 1.0, 0.6)
	var smoke: Node3D = Smoke.spawn(world, Vector3(0, 0, -4))
	var timed_smoke: Node3D = Smoke.spawn(world, Vector3(2, 0, -4), 1.0, 0.5, true)
	check(get_nodes_in_group("vfx").size() >= 11, "all effects spawn")
	paused = true
	var age: float = big.age
	var brawl_age: float = brawl.age
	var mushroom_age: float = mushroom.age
	await wait(0.15)
	check(is_equal_approx(big.age, age), "pause freezes effects")
	check(is_equal_approx(brawl.age, brawl_age), "pause freezes brawl choreography")
	check(is_equal_approx(mushroom.age, mushroom_age), "pause freezes reference explosion")
	check(is_zero_approx(fire_tornado.age), "pause freezes fire tornado material flow")
	check(motifs.all(func(fx): return is_zero_approx(fx.age)), "pause freezes all motif choreography")
	paused = false
	await wait(1.2)
	check(big.get_child_count() > 8 and small.get_child_count() < big.get_child_count(), "full explosion has more layers than a test burst")
	check(not is_instance_valid(fuse) or fuse.is_queued_for_deletion() or fuse.age > 0.8, "fuse runs for its duration")
	await wait(3.6)
	# Effects advance in process time and queue_free; finish the frame before checking validity.
	await process_frame
	check(not is_instance_valid(big) and not is_instance_valid(small) and not is_instance_valid(air), "explosions clean up")
	check(not is_instance_valid(bolt), "lightning cleans up")
	check(not is_instance_valid(brawl), "brawl clears cloud, fists and impact cards")
	check(not is_instance_valid(fire_tornado), "fire tornado clears sheets, roots and ground flow")
	check(not is_instance_valid(mushroom) and not is_instance_valid(soil) and not is_instance_valid(mini), "reference explosions clean up")
	check(motifs.all(func(fx): return not is_instance_valid(fx)), "five motif effects clean up")
	check(not is_instance_valid(shot) and not is_instance_valid(miss), "projectiles clean up")
	check(hits == 1, "impact reported once, and only on a hit")
	check(not is_instance_valid(timed_fire) and not is_instance_valid(timed_smoke), "timed fire and smoke clean up")
	check(is_instance_valid(fire) and is_instance_valid(smoke), "untimed fire and smoke keep going")
	fire.extinguish()
	smoke.stop()
	await wait(2.2)
	check(get_nodes_in_group("vfx").is_empty(), "stopped effects clean up")
	print("VFXTEST_FAIL" if failed else "VFXTEST_OK")
	quit(1 if failed else 0)
