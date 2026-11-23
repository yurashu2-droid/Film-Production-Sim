extends SceneTree
const Effect=preload("res://pixel_vfx/ultimate/px_apotheosis.gd")
var failed:=false
var notifications:=0
func _initialize()->void:
	run.call_deferred()
	create_timer(25,true,false,true).timeout.connect(func():quit(2))
func check(ok:bool,label:String)->void:
	print("APOTHEOSIS_CHECK ",label," ","OK" if ok else "FAIL")
	failed=failed or not ok
func run()->void:
	var parent=Node3D.new()
	root.add_child(parent)
	parent.position=Vector3(3,1,-2)
	var fx=Effect.spawn(parent,Vector3(1,0,2),.8)
	fx.set_process(false)
	fx.free_on_finish=false
	fx.finished.connect(func():notifications+=1)
	check(fx.global_position.is_equal_approx(Vector3(1,0,2)),"spawn world origin")
	check(fx._parts.size()==3 and fx._gates.size()==6,"three authored groups plus layered gate")
	fx.playback_speed=0
	fx._process(1)
	check(is_zero_approx(fx.age),"pause freezes all material clocks")
	fx.playback_speed=.5
	fx._process(2)
	check(is_equal_approx(fx.age,1),"speed controls authored time")
	for t in [3.0,7.0,12.8,17.0,21.8]:fx.pose(t)
	fx.playback_speed=1
	fx.age=21.9
	fx._process(.2)
	fx._process(1)
	check(notifications==1 and fx._done,"22 second finish emits once")
	var empty:=true
	for gate in fx._gates:empty=empty and not gate.visible
	for light in fx._lights:empty=empty and is_zero_approx(light.light_energy)
	check(empty,"gate and illumination end")
	fx.stop()
	fx.start()
	check(fx.visible and not fx._done and is_zero_approx(fx.age),"restart after stop restores visibility")
	fx.free()
	var scene=preload("res://pixel_vfx/ultimate/apotheosis.tscn").instantiate()
	parent.add_child(scene)
	scene.set_process(false)
	check(scene._parts.size()==3,"drag in scene autostarts")
	scene._process(22.1)
	await process_frame
	check(not is_instance_valid(scene) and get_nodes_in_group("pixel_vfx").is_empty(),"one shot frees every child")
	parent.free()
	print("APOTHEOSIS_TEST_FAIL" if failed else "APOTHEOSIS_TEST_OK")
	quit(1 if failed else 0)
