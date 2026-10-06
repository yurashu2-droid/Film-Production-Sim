extends "res://scripts/prop.gd"
# 搬入口に停まっている軽トラ。荷台に機材を積んで届く。動かせない。

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
	add_child(visual)
	# 後ろのあおりを倒して、荷下ろしできる状態にしておく
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X", true, false)
	if tail:
		tail.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	_box(Vector3(0, 0.88, 1.0), Vector3(1.7, 1.76, 1.45))
	_box(Vector3(0, 0.44, -0.72), Vector3(1.5, 0.44, 1.95))


func _box(c: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = c
	add_child(cs)


func _ready() -> void:
	super._ready()
	set_fixed(true)
