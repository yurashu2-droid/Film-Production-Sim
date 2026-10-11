extends "res://scripts/prop.gd"
# 表の +Z に筆記面。持つときは正面の相手へ向け、手は板の下部を支える。
signal ink_restored
const Stage := preload("res://scripts/stage.gd")
const MODEL := preload("res://assets/gear/Q07_Replaceable_Cue_Board.glb")
const RESOLUTION := Vector2i(1024,724)
const SIZE := Vector2(1.12,0.792)
var ink: Image
var texture: ImageTexture
var surface: MeshInstance3D
var _ink_surface := -1
var revision := 0
var _png := PackedByteArray()

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
	ink = Image.create(RESOLUTION.x,RESOLUTION.y,false,Image.FORMAT_RGB8)
	ink.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(ink)
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i)
			if original == null or original.resource_name != "CUE_FRONT_REPLACE_IMAGE": continue
			surface = mesh
			_ink_surface = i
			var paper := original.duplicate() as StandardMaterial3D
			paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			paper.albedo_texture = texture
			paper.albedo_color = Color.WHITE
			paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mesh.set_surface_override_material(i,paper)
	assert(surface != null,"Supplied cue card must have CUE_FRONT_REPLACE_IMAGE")
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

func draw_line(from: Vector2, to: Vector2, color: Color, radius: float, refresh: bool = true) -> void:
	var steps := maxi(1,int(ceil(from.distance_to(to)/maxf(1,radius*0.5))))
	for i in range(steps+1):
		var p := from.lerp(to,float(i)/steps)
		var x0 := maxi(0,int(floor(p.x-radius)))
		var x1 := mini(RESOLUTION.x-1,int(ceil(p.x+radius)))
		var y0 := maxi(0,int(floor(p.y-radius)))
		var y1 := mini(RESOLUTION.y-1,int(ceil(p.y+radius)))
		for y in range(y0,y1+1):
			for x in range(x0,x1+1):
				if Vector2(x,y).distance_squared_to(p) <= radius*radius:
					ink.set_pixel(x,y,color)
	if refresh: _refresh()

func clear_ink() -> void:
	ink.fill(Color.WHITE)
	_refresh()

func _refresh() -> void:
	texture.update(ink)
	_png = ink.save_png_to_buffer()

func get_state() -> Array:
	var state := super.get_state()
	state.append_array([revision,_png])
	return state

# Reliable brush commands carry ink; frequent physics packets only carry transforms.
func network_state() -> Array:
	return super.get_state()

func _apply_extra(state: Array) -> void:
	if state.size() < 5 or (int(state[3]) == revision and state[4] == _png): return
	var image := Image.new()
	if image.load_png_from_buffer(state[4]) != OK or image.get_size() != RESOLUTION: return
	image.convert(Image.FORMAT_RGB8)
	ink = image
	revision = int(state[3])
	_refresh()
	ink_restored.emit()
