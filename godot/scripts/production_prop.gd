extends "res://scripts/prop.gd"
## Movable owner-provided production carts. Use build_model before adding to scene.
var active := false
var action_time := 0.0
var moving := false
var _anim: AnimationPlayer
var _clip := ""
var _table: Node3D
var _deck_shape: CollisionShape3D
const LIFT_END := 3.0

func build_model(model_kind: String) -> void:
	assert(model_kind in ["lift_cart", "cleaning_cart"])
	kind = model_kind
	label = "昇降カメラ台" if kind == "lift_cart" else "清掃カート・絞り機"
	mass = 24.0 if kind == "lift_cart" else 12.0
	rolls = true
	hold_min = 1.15
	center = Vector3(-0.10, 0.42, 0) if kind == "lift_cart" else Vector3(0, 0.55, 0)
	half = Vector3(0.64, 0.50, 0.29) if kind == "lift_cart" else Vector3(0.60, 0.75, 0.33)
	visual = load("res://assets/production/" + kind + ".glb").instantiate() as Node3D
	add_child(visual)
	_anim = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_clip = "Lift" if kind == "lift_cart" else "Wringer"
	assert(_anim != null and _anim.has_animation(_clip))
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim.play(_clip)
	_anim.pause()
	if kind == "lift_cart":
		_table = visual.find_child("TABLE_RIG", true, false) as Node3D
		deck_half = Vector2(0.48, 0.24)
		deck_c = Vector2.ZERO
		_add_box(Vector3(-0.08, 0.14, 0), Vector3(1.08, 0.28, 0.52))
		# Handle proxy above the narrow rolling chassis.
		_add_box(Vector3(-0.65, 0.56, 0), Vector3(0.075, 0.70, 0.48))
		_deck_shape = _add_box(Vector3(0, 0.415, 0), Vector3(1.0, 0.05, 0.50))
	else:
		_add_box(Vector3(0, 0.29, 0), Vector3(1.16, 0.58, 0.52))
		_add_box(Vector3(-0.46, 0.78, 0), Vector3(0.10, 0.44, 0.50))
	_sample_action(false)

func _add_box(at: Vector3, size: Vector3) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = at
	add_child(collider)
	return collider

## Broadcast via existing host_ev. State snapshots also include phase to correct drift.
func set_active(on: bool) -> void:
	active = on
	if kind == "cleaning_cart":
		action_time = 0.0
	moving = true
	sleeping = false

func can_board() -> bool:
	return kind == "lift_cart" and not moving and not absent

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if playback or not is_host():
		return
	if kind == "lift_cart":
		action_time = move_toward(action_time, LIFT_END if active else 0.0, delta)
		moving = not is_equal_approx(action_time, LIFT_END if active else 0.0)
	elif active:
		action_time = minf(action_time + delta, _anim.get_animation(_clip).length)
		moving = action_time < _anim.get_animation(_clip).length
	_sample_action(true)

func _sample_action(move_riders: bool) -> void:
	if _anim == null:
		return
	_anim.seek(action_time, true)
	if _table == null:
		return
	var old_top := deck_top
	# Authored TABLE_RIG origin is the platform top (0.44 to 1.00 metres).
	deck_top = (visual.transform * _table.transform).origin.y
	_deck_shape.position.y = deck_top - 0.025
	if move_riders and old_top >= 0.0 and game != null:
		for rider in game.props.values():
			if rider.rider_of == pid:
				rider.ride_local.origin.y += deck_top - old_top

func get_state() -> Array:
	var state := super.get_state()
	state.append_array([active, action_time])
	return state

func _apply_extra(state: Array) -> void:
	if state.size() < 5:
		return
	active = bool(state[3])
	action_time = float(state[4])
	moving = (not is_equal_approx(action_time, LIFT_END if active else 0.0)) if kind == "lift_cart" else (active and action_time < 3.0)
	_sample_action(false)

