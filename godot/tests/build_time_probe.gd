extends SceneTree
# 拠点の背景づくり（事務所・敷地・まわりの建物）にかかる時間を測る。 godot --headless --path godot --script res://tests/build_time_probe.gd
const Office := preload("res://scripts/production_office.gd")
const Yard := preload("res://scripts/production_yard.gd")
const Look := preload("res://scripts/production_look.gd")

func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var t0 := Time.get_ticks_msec()
	for k in ["asphalt", "concrete", "paving", "block", "metal", "shutter", "floor", "wood", "plain", "paint", "stain", "tower", "rug"]:
		Look.mat(k)
	var t1 := Time.get_ticks_msec()
	var o: Node3D = Office.build(holder, ThemeDB.fallback_font)
	var t2 := Time.get_ticks_msec()
	Yard._surroundings(o)
	var t3 := Time.get_ticks_msec()
	print("BUILDTIME textures=", t1 - t0, "ms office=", t2 - t1, "ms surroundings=", t3 - t2, "ms nodes=", holder.find_children("*", "", true, false).size())
	quit()
