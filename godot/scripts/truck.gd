extends "res://scripts/prop.gd"
# 搬入口に停まっている軽トラ。荷台に機材を積んで届く。動かせない。

# 道路とキャラクターに対して存在感を出す。見た目・荷台・当たり判定を同じ倍率に揃える。
const VEHICLE_SCALE := 1.55
var _travel_state := -1

func build() -> void:
	kind = "truck"
	label = "軽トラ"
	mass = 800.0
	immovable = true
	center = Vector3(0, 0.9, 0)
	half = Vector3(0.9, 0.9, 1.73)
	hold_min = 3.0
	deck_top = 0.67
	deck_half = Vector2(0.66, 0.92)
	deck_c = Vector2(0, -0.72)
	visual = (load("res://assets/stage/kei_truck.glb") as PackedScene).instantiate()
	_scale_vehicle()
	add_child(visual)
	# 後ろのあおりを倒して、荷下ろしできる状態にしておく
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X", true, false)
	if tail:
		tail.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	_box(Vector3(0, 0.88, 1.0), Vector3(1.7, 1.76, 1.45))
	_box(Vector3(0, 0.44, -0.72), Vector3(1.5, 0.44, 1.95))


func _scale_vehicle() -> void:
	visual.scale *= VEHICLE_SCALE
	center *= VEHICLE_SCALE
	half *= VEHICLE_SCALE
	deck_top *= VEHICLE_SCALE
	deck_half *= VEHICLE_SCALE
	deck_c *= VEHICLE_SCALE


func _box(c: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size * VEHICLE_SCALE
	cs.shape = b
	cs.position = c * VEHICLE_SCALE
	add_child(cs)


# 腰の支点とハンドルは車体ローカル座標。先頭の乗員が運転、次の乗員が助手席。
func seat(index: int) -> Dictionary:
	var van: bool = "vehicle" in self and get("vehicle") == "van"
	var base_scale := VEHICLE_SCALE * (0.9 if van else 1.0)
	var hip := Vector3(0.367,0.82,0.84)
	var wheel := Vector3(0.367,1.075,1.11)
	var radius := 0.169
	if van:
		hip = Vector3(-0.51,1.07,1.42)
		wheel = Vector3(-0.482,1.4325,1.75)
		radius = 0.195
	if index == 1:
		hip.x *= -1.0
	elif index >= 2:
		hip = Vector3(-0.40 if index % 2 == 0 else 0.40, 0.85 if van else 0.79, -0.75)
	return {"hip":hip*base_scale, "wheel":wheel*base_scale, "radius":radius*base_scale, "roof":(1.96 if van else 1.70)*base_scale if index < 2 else 10.0}

func set_traveling(value: bool) -> void:
	if _travel_state == int(value): return
	_travel_state = int(value)
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X",true,false)
	if tail: tail.rotation.x = 0.0 if value else -PI*0.5
	var hatch: Node3D = visual.find_child("REAR_HATCH_PIVOT",true,false)
	if hatch: hatch.rotation_degrees.x = 0.0 if value else 95.0
	var slide: Node3D = visual.find_child("SLIDING_DOOR_ROOT",true,false)
	if slide: slide.position = Vector3(0.927,0.625,0.08) + (Vector3.ZERO if value else Vector3(0.13,0,-1.45))
	if hatch and has_method("_van_supports"): call("_van_supports",hatch.get_parent(),hatch)

func drive_to(point: Vector3) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = point

func _ready() -> void:
	super._ready()
	set_fixed(true)
