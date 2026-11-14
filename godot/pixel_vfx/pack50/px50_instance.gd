extends Node3D
# Drag a preset .tscn into a scene, or call Px50.spawn. Legacy path stays stable.
signal finished
const Catalog:=preload("res://pixel_vfx/pack50/px50_catalog.gd")
@export var effect_id:String="px50_astral_gate"
@export_range(.1,8.0,.05) var effect_size:float=1.0
@export_range(.0,4.0,.05) var playback_speed:float=1.0
@export var auto_play:bool=true
@export var loop:bool=false
@export var free_on_finish:bool=true
var age:=0.0
var life:=0.0
var target:Node3D
var _playing:=false
var _notified:=false
var _gap:=0.0

func _ready()->void:
	add_to_group("pixel_real_50")
	if auto_play:play()

func play()->void:
	if is_instance_valid(target):
		target.free()
	assert(Catalog.BY_ID.has(effect_id),"Unknown preset "+effect_id)
	var row:Dictionary=Catalog.BY_ID[effect_id]
	var script=load("res://pixel_vfx/pack50/px50_%s.gd"%row["family"])
	target=script.spawn(self,global_position,effect_size,row["variant"])
	target.set_process(false)
	age=0.0
	life=float(row["life"])
	_gap=float(row["gap"])
	_playing=true
	_notified=false

func stop()->void:
	_playing=false
	if is_instance_valid(target):target.queue_free()

func _process(delta:float)->void:
	if not _playing:return
	var step=delta*playback_speed
	age+=step
	if is_instance_valid(target) and not target.is_queued_for_deletion():target._process(step)
	if age>=life and not _notified:
		_notified=true
		finished.emit()
	if age>=_gap:
		if loop:play()
		else:
			_playing=false
			if free_on_finish:queue_free()
