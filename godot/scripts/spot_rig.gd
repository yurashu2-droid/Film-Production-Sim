extends "res://scripts/prop.gd"
# スタンドつきスポットライト。置けばその向きを照らし続ける。

const ENERGY := [0.0, 7.0, 13.0, 22.0]
const FACTOR := [0.0, 0.6, 1.0, 1.6]   # 判定で使う明るさの係数
const RANGE := 24.0
const ANGLE := 21.0
const HEAD_Y := 2.0

var pan := 0.0
var tilt := -0.12
var level := 2
var operator := 0

var pan_node: Node3D
var tilt_node: Node3D
var light: SpotLight3D
var _face_mat: StandardMaterial3D


func build() -> void:
	kind = "spot"
	label = "スポットライト"
	mass = 11.0
	center = Vector3(0, 1.05, 0)
	half = Vector3(0.45, 1.1, 0.45)
	hold_min = 1.4
	carry_yaw = PI             # 光が自分の向いている先へ出るように持つ
	angular_damp = 2.5

	# スタンドの先端に灯体を載せる。先端の腕（グリップヘッド）は外しておく
	visual = (load("res://assets/gear/C06_Century_Stand.glb") as PackedScene).instantiate()
	add_child(visual)
	var grip: Node3D = visual.find_child("03_REMOVABLE_GRIP_HEAD", true, false)
	if grip:
		grip.visible = false
	var shoulder: Node3D = visual.find_child("ATTACH_LAMP_BABY_SHOULDER", true, false)
	pan_node = Node3D.new()
	shoulder.add_child(pan_node)
	var lamp: Node3D = (load("res://assets/gear/F06_Fresnel_Light.glb") as PackedScene).instantiate()
	pan_node.add_child(lamp)
	tilt_node = lamp.find_child("PIVOT_HEAD_TILT_X", true, false)
	light = SpotLight3D.new()
	light.position = Vector3(0, 0, 0.12)
	light.rotation.y = PI          # 素材の発光面は+Z向き
	light.spot_range = RANGE
	light.spot_angle = ANGLE
	light.spot_angle_attenuation = 0.6
	light.spot_attenuation = 0.8
	light.light_color = Color(1.0, 0.94, 0.82)
	light.shadow_enabled = true
	light.shadow_bias = 0.06
	tilt_node.add_child(light)

	# レンズの奥で光って見える面
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.052
	disc.bottom_radius = 0.052
	disc.height = 0.004
	face.mesh = disc
	face.rotation.x = PI * 0.5
	face.position = Vector3(0, 0, 0.097)
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_color = Color(1, 0.95, 0.8)
	_face_mat.emission_enabled = true
	_face_mat.emission = Color(1, 0.92, 0.75)
	face.material_override = _face_mat
	tilt_node.add_child(face)

	var legs := CollisionShape3D.new()
	var lb := CylinderShape3D.new()
	lb.radius = 0.45
	lb.height = 0.34
	legs.shape = lb
	legs.position = Vector3(0, 0.17, 0)
	add_child(legs)
	var pole := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(0.1, 1.5, 0.1)
	pole.shape = pb
	pole.position = Vector3(0, 1.05, 0)
	add_child(pole)
	var head := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(0.34, 0.36, 0.34)
	head.shape = hb
	head.position = Vector3(0, HEAD_Y, 0)
	add_child(head)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.35, 0)


func aim(dpan: float, dtilt: float, dlevel: int) -> void:
	pan = wrapf(pan + dpan, -PI, PI)
	tilt = clampf(tilt + dtilt, -1.1, 0.9)
	level = clampi(level + dlevel, 0, 3)


# 手で持っている間は、持ち手の見ている方向へ光が向く
func _host_tick(delta: float) -> void:
	if holder == 0:
		return
	var pl: Node = game.players.get(holder)
	if pl:
		var w := clampf(delta * 12.0, 0.0, 1.0)
		pan = lerp_angle(pan, 0.0, w)
		tilt = lerpf(tilt, clampf(pl.aim_pitch + 0.08, -1.1, 0.9), w)


func beam_origin() -> Vector3:
	return light.global_position


func beam_dir() -> Vector3:
	return -light.global_basis.z


func _process(_delta: float) -> void:
	pan_node.rotation.y = pan
	tilt_node.rotation.x = -tilt
	light.light_energy = ENERGY[level]
	light.visible = level > 0
	if _face_mat:
		_face_mat.emission_energy_multiplier = float(level) * 1.5


func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed, pan, tilt, level]


func _apply_extra(s: Array) -> void:
	if s.size() < 6:
		return
	pan = s[3]
	tilt = s[4]
	level = int(s[5])
