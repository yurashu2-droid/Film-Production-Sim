extends "res://scripts/prop.gd"
# Four independent hinges; lid state travels with the prop snapshot.
const CLOSED := [-2.96467, 0.06733, 0.12419, -0.06582]
const OPEN := [0.0, PI + 0.06733, -PI + 0.14919, -PI - 0.06582]
var opened := true
var open_amount := 1.0
var flaps: Array[Node3D] = []
var lid: CollisionShape3D

func configure() -> void:
	for side: String in ["Front", "Right", "Back", "Left"]:
		flaps.append(visual.find_child("Flap" + side, true, false) as Node3D)
	# Keep the interior empty when open; closing adds a surface across the top.
	_box(Vector3(0, 0.014, 0), Vector3(0.82, 0.028, 0.60))
	for x in [-0.405, 0.405]:
		_box(Vector3(x, 0.28, 0), Vector3(0.022, 0.56, 0.60))
	for z in [-0.295, 0.295]:
		_box(Vector3(0, 0.28, z), Vector3(0.82, 0.56, 0.022))
	lid = _box(Vector3(0, 0.57, 0), Vector3(0.82, 0.022, 0.60))
	_apply_lids()

func _box(pos: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	add_child(cs)
	return cs

func _follow_net(delta: float) -> void:
	super._follow_net(delta)
	if not game.replaying:
		_host_tick(delta)

func _host_tick(delta: float) -> void:
	open_amount = move_toward(open_amount, 1.0 if opened else 0.0, delta / 0.4)
	_apply_lids()

func _apply_lids() -> void:
	for i in flaps.size():
		# Side flaps fold first, then the two outer flaps overlap them.
		var t := clampf(open_amount * 1.25 - (0.0 if i in [0, 2] else 0.25), 0.0, 1.0)
		t = smoothstep(0.0, 1.0, t)
		var angle: float = lerpf(CLOSED[i], OPEN[i], t)
		if i in [0, 2]:
			flaps[i].rotation.x = angle
		else:
			flaps[i].rotation.z = angle
	lid.set_deferred("disabled", open_amount > 0.02)

func get_state() -> Array:
	var s := super.get_state()
	s.append(open_amount)
	s.append(opened)
	return s

func _apply_extra(s: Array) -> void:
	if s.size() >= 5 and (is_host() or playback or game.replaying):
		open_amount = float(s[3])
		opened = s[4]
		_apply_lids()
