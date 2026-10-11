extends "res://scripts/prop.gd"
# 搬入口に停まっている軽トラ。荷台に機材を積んで届く。動かせない。

# 道路とキャラクターに対して存在感を出す。見た目・荷台・当たり判定を同じ倍率に揃える。
const VEHICLE_SCALE := 1.55
var _travel_state := -1
var _cargo_panels: Array = []

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
	_build_cargo_walls()


func _scale_vehicle() -> void:
	visual.scale *= VEHICLE_SCALE
	center *= VEHICLE_SCALE
	half *= VEHICLE_SCALE
	deck_top *= VEHICLE_SCALE
	deck_half *= VEHICLE_SCALE
	deck_c *= VEHICLE_SCALE


func _box(c: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size * VEHICLE_SCALE
	cs.shape = b
	cs.position = c * VEHICLE_SCALE
	add_child(cs)
	return cs


# 荷台の側板と可動パネル。モデルの比率を変えずに、当たり判定を揃える。
func _build_cargo_walls() -> void:
	_cargo_panels.clear()
	if "vehicle" in self and get("vehicle") == "van":
		_box(Vector3(0,2.015,-0.725),Vector3(1.8,0.09,3.15))
		_add_cargo_panel("REAR_HATCH_PIVOT",Vector3(0,-0.80,0),Vector3(1.70,1.58,0.09))
		_add_cargo_panel("SLIDING_DOOR_ROOT",Vector3(0,0.67,0.06),Vector3(0.09,1.77,1.46))
	else:
		for side in [-1.0,1.0]:
			_box(Vector3(side*0.713,0.807,-0.72),Vector3(0.085,0.29,1.91))
		_box(Vector3(0,0.807,0.22),Vector3(1.45,0.29,0.07))
		# 鳥居の空いている部分は塞がず、柱と上の桟だけを支える。
		for side in [-1.0,1.0]:
			_box(Vector3(side*0.665,1.35,0.22),Vector3(0.06,0.8,0.06))
		_box(Vector3(0,1.725,0.22),Vector3(1.39,0.06,0.06))
		_add_cargo_panel("TAILGATE_HINGE_X",Vector3(0,0.143,-0.006),Vector3(1.45,0.29,0.05))


func _panel_transform(panel: Node3D) -> Transform3D:
	var at := Transform3D.IDENTITY
	var node := panel
	while node != self:
		at = node.transform * at
		node = node.get_parent() as Node3D
	return at


func _add_cargo_panel(part: String, c: Vector3, size: Vector3) -> void:
	var panel: Node3D = visual.find_child(part,true,false)
	if panel == null: return
	var at := _panel_transform(panel)
	var shape := _box(Vector3.ZERO,size*at.basis.get_scale().abs()/VEHICLE_SCALE)
	shape.transform = Transform3D(at.basis.orthonormalized(),at*c)
	_cargo_panels.append([shape,panel,c])


func _update_cargo_panels() -> void:
	for panel: Array in _cargo_panels:
		# 車種切り替え中は、古いモデルを外してから衝突を作り直す。
		if not is_instance_valid(panel[1]) or not is_ancestor_of(panel[1]):
			continue
		var at := _panel_transform(panel[1])
		panel[0].transform = Transform3D(at.basis.orthonormalized(),at*(panel[2] as Vector3))


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
	_update_cargo_panels()
	if hatch and has_method("_van_supports"): call("_van_supports",hatch.get_parent(),hatch)

func drive_to(point: Vector3) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = point

func _ready() -> void:
	super._ready()
	set_fixed(true)
