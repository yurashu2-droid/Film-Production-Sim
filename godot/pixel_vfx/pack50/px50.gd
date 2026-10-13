extends RefCounted
const Catalog:=preload("res://pixel_vfx/pack50/px50_catalog.gd")
const Instance:=preload("res://pixel_vfx/pack50/px50_instance.gd")

static func spawn(parent:Node,pos:Vector3,id:String,options:Dictionary={})->Node3D:
	assert(Catalog.BY_ID.has(id),"Unknown Pixel×Real50 ID "+id)
	var instance=Instance.new()
	instance.effect_id=id
	instance.effect_size=float(options.get("size",1.0))
	instance.playback_speed=float(options.get("speed",1.0))
	instance.loop=bool(options.get("loop",false))
	parent.add_child(instance)
	instance.global_position=pos
	return instance
