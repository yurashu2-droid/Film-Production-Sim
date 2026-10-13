extends "res://scripts/paint_board.gd"
# 表の +Z に筆記面。持つときは正面の相手へ向け、手は板の下部を支える。
# 絵を描く仕組み（ink・筆・同期）は paint_board.gd。
const Stage := preload("res://scripts/stage.gd")
const MODEL := preload("res://assets/gear/Q07_Replaceable_Cue_Board.glb")
const RESOLUTION := Vector2i(1024,724)
const SIZE := Vector2(1.12,0.792)

func build() -> void:
	kind = "cue_card"
	label = "カンペ（Fでペイント）"
	mass = 0.5
	carry_yaw = PI
	visual = MODEL.instantiate()
	add_child(visual)
	# A3 landscape sheet: scale uniformly, with the authored rings and page stack intact.
	var bounds := Stage.merged_aabb(visual)
	var factor := SIZE.x / 0.42
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
	bounds = AABB(bounds.position*factor+visual.position,bounds.size*factor)
	center = bounds.get_center()
	half = bounds.size*0.5
	half.z = maxf(half.z,0.016)
	make_ink(RESOLUTION)
	var found := bind_surface(visual,"CUE_FRONT_REPLACE_IMAGE")
	assert(found,"Supplied cue card must have CUE_FRONT_REPLACE_IMAGE")
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = half*2.0
	collider.shape = shape
	collider.position = center
	add_child(collider)
	_refresh()

func carry_target(player: Node3D) -> Array:
	var forward: Vector3 = player.flat_forward()
	var grip: Vector3 = player.vis.grip_pos(false)
	var pos := grip + Vector3(0,0.24,0) + forward*0.07
	return [pos,player.aim_yaw+player.hold_yaw+carry_yaw,player.global_position.y,0.0]
