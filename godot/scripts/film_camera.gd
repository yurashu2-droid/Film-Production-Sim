extends "res://scripts/prop.gd"
# 三脚つきの撮影カメラ。置けばその構図を保つ。操作中は首振り・ズーム・台車移動ができる。

const VIEW_SIZE := Vector2i(1280, 720)
const HEAD_Y := 1.35
const FOV_MIN := 18.0
const FOV_MAX := 75.0

var cam_yaw := 0.0
var cam_pitch := 0.0
var fov := 52.0
var operator := 0
var dolly := Vector3.ZERO     # 操作者からの移動入力（ワールド方向、長さ0..1）

var pan_node: Node3D
var tilt_node: Node3D
var lens: Node3D              # -Z が撮影方向
var view: SubViewport
var view_cam: Camera3D
var tally: MeshInstance3D


func build() -> void:
	kind = "camera"
	label = "撮影カメラ"
	mass = 14.0
	center = Vector3(0, 0.7, 0)
	half = Vector3(0.45, 0.75, 0.45)
	hold_min = 1.4
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	angular_damp = 6.0

	# 三脚（首振り・上下の可動部つき）にカメラを載せる。素材は+Z向きなので-Zへそろえる
	visual = (load("res://assets/gear/T06_Fluid_Tripod.glb") as PackedScene).instantiate()
	visual.rotation.y = PI
	add_child(visual)
	pan_node = visual.find_child("PIVOT_PAN_Z", true, false)
	tilt_node = visual.find_child("PIVOT_TILT_X", true, false)
	var mount: Node3D = visual.find_child("ATTACH_C04_CAMERA_ROOT", true, false)
	var body: Node3D = (load("res://assets/gear/C04_Field_Camera.glb") as PackedScene).instantiate()
	mount.add_child(body)
	var axis: Node3D = body.find_child("AIM_OPTICAL_AXIS", true, false)
	lens = Node3D.new()
	lens.rotation.y = PI
	lens.position = Vector3(0, 0, 0.02)
	axis.add_child(lens)

	tally = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	tally.mesh = sm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(1, 0.1, 0.1)
	tm.emission_enabled = true
	tm.emission = Color(1, 0.1, 0.1)
	tm.emission_energy_multiplier = 4.0
	tally.material_override = tm
	tally.position = Vector3(0, 0.185, 0.06)
	tally.visible = false
	body.add_child(tally)

	_add_box(Vector3(0, 0.55, 0), Vector3(0.8, 1.1, 0.8))
	_add_box(Vector3(0, HEAD_Y, 0), Vector3(0.3, 0.32, 0.4))

	view = SubViewport.new()
	view.size = VIEW_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	view.audio_listener_enable_3d = false
	add_child(view)
	view_cam = Camera3D.new()
	view_cam.near = 0.15
	view_cam.far = 120.0
	view_cam.environment = _film_environment()
	view.add_child(view_cam)
	view_cam.current = true


func _add_box(c: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = c
	add_child(cs)


# 撮影側だけ暗く締めて、当てた光と爆発が映えるようにする
func _film_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.012, 0.016, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.45, 0.8)
	e.ambient_light_energy = 0.28
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.85
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.15
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.12
	e.adjustment_saturation = 1.1
	return e


func aim(dyaw: float, dpitch: float, dfov: float) -> void:
	cam_yaw = wrapf(cam_yaw + dyaw, -PI, PI)
	cam_pitch = clampf(cam_pitch + dpitch, -1.0, 1.0)
	fov = clampf(fov + dfov, FOV_MIN, FOV_MAX)


func shoot_dir() -> Vector3:
	return -lens.global_basis.z


func _process(_delta: float) -> void:
	pan_node.rotation.y = cam_yaw
	tilt_node.rotation.x = -cam_pitch
	view_cam.global_transform = lens.global_transform
	view_cam.fov = fov


func _host_tick(_delta: float) -> void:
	if operator != 0 and holder == 0 and not fixed:
		var v := dolly * 2.2
		linear_velocity.x = v.x
		linear_velocity.z = v.z
		sleeping = false


func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed, cam_yaw, cam_pitch, fov]


func _apply_extra(s: Array) -> void:
	if s.size() < 6:
		return
	cam_yaw = s[3]
	cam_pitch = s[4]
	fov = s[5]
