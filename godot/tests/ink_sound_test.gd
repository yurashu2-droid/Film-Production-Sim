extends SceneTree
# 新しい六作品の生成・停止・音同期・寿命を一度の狭い実行で確認する。
const IDS := ["ink_undertow","ink_cross","ink_bloom","sound_bass","sound_echo","sound_chime"]
var failed := false
var effects: Array[Node3D] = []

func _initialize() -> void:
	run.call_deferred()
	create_timer(35,true,false,true).timeout.connect(func():quit(2))

func check(ok: bool, label: String) -> void:
	print("INK_SOUND_CHECK ",label," ","OK" if ok else "FAIL")
	failed=failed or not ok

func run() -> void:
	var studio_script=load("res://vfx/vfx_lab.gd")
	for id in IDS:
		check(studio_script.ITEMS.any(func(item):return item[1]==id),id+" lab registration")
	var world:=Node3D.new()
	root.add_child(world)
	for i in IDS.size():
		var code=load("res://vfx/vfx_%s.gd"%IDS[i])
		var effect:Node3D=code.spawn(world,Vector3(i*8,0,0),1.0)
		effects.append(effect)
		check(effect.get_child_count()>=3,IDS[i]+" spawns")
	await process_frame
	paused=true
	var ages:Array[float]=[]
	for effect in effects:ages.append(effect.age)
	await create_timer(.12,true,false,true).timeout
	for i in effects.size():check(is_equal_approx(effects[i].age,ages[i]),IDS[i]+" pauses")
	for i in range(3,6):
		var voices:=effects[i].find_children("*","AudioStreamPlayer",true,false)
		check(voices.size()==1 and voices[0].stream.get_length()>5.0 and (not voices[0].playing if DisplayServer.get_name()=="headless" else voices[0].stream_paused),IDS[i]+" score pauses")
	paused=false
	# 一つはゼロ速度で停止し、残りの作品から独立していることを確認。
	effects[0].speed=0.0
	var frozen:float=effects[0].age
	await create_timer(.15,true,false,true).timeout
	check(is_equal_approx(effects[0].age,frozen),"zero speed stops the material clock")
	effects[0].speed=1.0
	var frames:=0
	while effects.any(func(effect):return is_instance_valid(effect)) and frames<480:
		await process_frame
		frames+=1
	check(effects.all(func(effect):return not is_instance_valid(effect)),"all six and their sounds clean up")
	print("INK_SOUND_TEST_FAIL" if failed else "INK_SOUND_TEST_OK")
	world.queue_free()
	preload("res://vfx/vfx_sound_score.gd")._cache.clear()
	await create_timer(.15,true,false,true).timeout
	quit(1 if failed else 0)
