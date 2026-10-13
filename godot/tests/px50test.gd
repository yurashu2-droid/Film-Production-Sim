extends SceneTree
const Pack:=preload("res://pixel_vfx/pack50/px50.gd")
var failed:=false
var notifications:=0
func _initialize()->void:
	run.call_deferred()
	create_timer(25,true,false,true).timeout.connect(func():quit(2))
func check(ok:bool,label:String)->void:
	print("PX50_CHECK ",label," ","OK" if ok else "FAIL")
	failed=failed or not ok
func run()->void:
	var world:=Node3D.new()
	root.add_child(world)
	world.position=Vector3(3,2,-4)
	var counts:={"L":0,"M":0,"S":0}
	for row in Pack.Catalog.ROWS:
		counts[row.complexity_class]+=1
		check(not row.composition.main.is_empty() and not row.tier_reason.is_empty(),row.id+" has composition and classification reason")
		var scene:PackedScene=load("res://pixel_vfx/pack50/scenes/%s.tscn"%row.id)
		var instance=scene.instantiate()
		instance.free_on_finish=false
		world.add_child(instance)
		instance.set_process(false)
		check(instance.target!=null and instance.effect_id==row.id,row.id+" scene starts")
		for frame in 16:
			instance._process(float(row.life)/16.0)
		instance._process(.1)
		await process_frame
		check(not is_instance_valid(instance.target),row.id+" material finishes")
		instance.free()
	check(Pack.Catalog.ROWS.size()==53 and counts==Pack.Catalog.TIER_COUNTS,"53 effects classified by content")
	for pair in [["px50_constellation_loom","L"],["px50_echo_stitch","M"],["px50_dew_inversion","S"]]:
		var row=Pack.Catalog.BY_ID[pair[0]]
		check(row.complexity_class==pair[1] and row.dist==9 and row.focus_height==1.8,pair[0]+" tier independent of shared camera scale")
	var fx=Pack.spawn(world,Vector3(1,.5,2),"px50_astral_gate",{"size":.7,"speed":0.0})
	fx.free_on_finish=false
	fx.finished.connect(func():notifications+=1)
	await process_frame
	check(fx.global_position.is_equal_approx(Vector3(1,.5,2)) and fx.target.position.is_zero_approx(),"spawn keeps requested world origin")
	check(is_zero_approx(fx.age) and is_zero_approx(fx.target.age),"zero speed freezes driver and material")
	fx.playback_speed=.5
	fx.set_process(false)
	fx._process(.4)
	check(is_equal_approx(fx.age,.2) and is_equal_approx(fx.target.age,.2),"speed scales both clocks")
	fx.set_process(true)
	paused=true
	var before:float=fx.age
	await create_timer(.1,true,false,true).timeout
	check(is_equal_approx(fx.age,before),"tree pause freezes wrapper")
	paused=false
	fx.set_process(false)
	fx._process(fx.life*2)
	fx._process(1)
	await process_frame
	check(notifications==1,"finished emitted once")
	fx.play()
	check(is_zero_approx(fx.age) and is_instance_valid(fx.target),"replay creates fresh material")
	fx.loop=true
	fx._process(30)
	check(is_zero_approx(fx.age) and is_instance_valid(fx.target),"loop restarts after authored gap")
	fx.stop()
	await process_frame
	check(not is_instance_valid(fx.target),"stop removes material")
	fx.free()
	var disposable=Pack.spawn(world,Vector3.ZERO,"px50_strike_snap")
	disposable.set_process(false)
	disposable._process(20)
	await process_frame
	check(not is_instance_valid(disposable),"default one shot removes wrapper")
	check(get_nodes_in_group("pixel_real_50").is_empty() and get_nodes_in_group("pixel_vfx").is_empty(),"all layers and wrappers cleaned")
	print("PX50TEST_FAIL" if failed else "PX50TEST_OK")
	quit(1 if failed else 0)
