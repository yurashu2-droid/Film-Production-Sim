extends RefCounted
const SeatedPose := preload("res://scripts/seated_pose.gd")
var vehicle: Node3D
var seat_index := -1
var pose: SkeletonModifier3D
var visual: Node3D
var _layer := 8
var _mask := 15
var _grounding := true

func enter(player: CharacterBody3D, truck: Node3D, index: int) -> void:
	if vehicle == truck and seat_index == index and visual == player.vis:
		update(player)
		return
	if vehicle != null:
		leave(player)
	vehicle = truck
	seat_index = index
	visual = player.vis
	_layer = player.collision_layer
	_mask = player.collision_mask
	_grounding = visual.grounding_enabled
	player.collision_layer = 0
	player.collision_mask = 0
	if player.has_method("cancel_performance"):
		player.cancel_performance()
	player._net.clear()
	visual.grounding_enabled = false
	visual.play("carry_idle", 0.0, true)
	visual.anim.advance(0.0)
	pose = SeatedPose.new()
	pose.name = "SeatedPose"
	visual.skel.add_child(pose)
	for mesh: MeshInstance3D in visual._model.find_children("*", "MeshInstance3D", true, false):
		var to_skeleton: Transform3D = visual.skel.global_transform.affine_inverse() * mesh.global_transform
		pose.model_top = maxf(pose.model_top,(to_skeleton * mesh.get_aabb().end).y)
	update(player)

func update(player: CharacterBody3D) -> void:
	if not is_instance_valid(vehicle):
		leave(player)
		return
	if not is_instance_valid(visual) or visual != player.vis:
		enter(player, vehicle, seat_index)
		return
	var seat: Dictionary = vehicle.seat(seat_index)
	var hip: Vector3 = visual.skel.get_bone_global_rest(visual.skel.find_bone("BODY")).origin * visual.SCALE
	player.global_transform = vehicle.global_transform * Transform3D(Basis.IDENTITY, seat.hip-hip)
	player.velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	pose.wheel = (seat.wheel-seat.hip+hip) / visual.SCALE
	pose.radius = float(seat.radius) / visual.SCALE
	pose.driving = seat_index == 0
	pose.lean = deg_to_rad(5.0) * clampf((visual.height - 1.45) / 0.35, 0.0, 1.0)
	pose.ceiling = (float(seat.roof)-seat.hip.y+hip.y) / visual.SCALE
	player.aim_yaw = vehicle.global_rotation.y + PI

func leave(player: CharacterBody3D) -> void:
	if vehicle == null:
		return
	vehicle = null
	seat_index = -1
	player.collision_layer = _layer
	player.collision_mask = _mask
	player.global_rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player._net.clear()
	if is_instance_valid(pose):
		pose.active = false
		pose.queue_free()
	if is_instance_valid(visual) and not visual.is_queued_for_deletion():
		visual.skel.reset_bone_poses()
		visual.grounding_enabled = _grounding
		visual.play("idle", 0.0, true)
		visual.anim.advance(0.0)
