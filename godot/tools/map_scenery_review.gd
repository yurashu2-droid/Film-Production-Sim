extends Node3D
const Office := preload("res://scripts/production_office.gd")
const Yard := preload("res://scripts/production_yard.gd")
const Extras := preload("res://scripts/features/map_street_details.gd")
const Look := preload("res://scripts/production_look.gd")
var world: Node3D
var camera: Camera3D
var legacy := false

func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7bbc9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c1d4df")
	env.ambient_light_energy = .65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-30,0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 52
	add_child(camera)
	_rebuild(false)
	show_view("wide")

func _rebuild(old: bool) -> void:
	if is_instance_valid(world):world.free()
	world = Node3D.new()
	add_child(world)
	legacy = old
	if old:
		# 比較用の旧版は capture_map_scenery.py が Git から一時生成する。
		var OldOffice = load("res://tools/map_scenery_baseline/production_office.gd")
		var OldYard = load("res://tools/map_scenery_baseline/production_yard.gd")
		OldOffice.build(world,Look.font())
		OldYard.build(world)
	else:
		Office.build(world,Look.font())
		Yard.build(world)
		Extras.build(world)

func show_view(view: String, old: bool = false) -> void:
	if old != legacy:_rebuild(old)
	var views := {
		"wide":[Vector3(103,29,48),Vector3(65,0,11)],
		"amenities":[Vector3(89,6.5,5),Vector3(80,1,-1)],
		"service":[Vector3(61,10,4),Vector3(48,1,-4)],
		"truck":[Vector3(38,6,41),Vector3(48,1.2,33.4)],
		"hopper":[Vector3(56,4,29),Vector3(49.5,1.2,33.5)],
		"junk":[Vector3(71,6,17),Vector3(61,1,17)],
		"road":[Vector3(83,6,34),Vector3(80,1,52)],
		"mailbox":[Vector3(64.8,2.2,10.2),Vector3(66.4,.65,8)],
		"appliances":[Vector3(62.4,2.1,10),Vector3(61.1,.6,5.8)],
		"television":[Vector3(62.4,1.15,25.5),Vector3(61.15,.45,24.9)]}
	var v: Array = views[view]
	camera.position = v[0]
	camera.look_at(v[1])
