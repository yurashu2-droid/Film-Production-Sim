extends "res://scripts/prop.gd"
# 火薬の袋（口をしばった麻袋）。持って F を押している間、口から粉が出る（決めるのは bomb_kit.gd）。
#   fill：残っている量（1.0＝いっぱい / 0＝空）。減るほど袋がしぼんで、軽くなる。数字では出さない。
# 注いでいる間は、袋が前へ傾き、口から粉の筋が落ちる（pour_rate＝勢い。全員の画面で見える）

const PropShapes := preload("res://scripts/prop_shapes.gd")
const FULL_MASS := 7.0
const EMPTY_MASS := 0.7
const TILT := 2.0             # 注ぐときに傾ける角度（ラジアン）
const SPOUT := 0.26           # 傾けた袋の口が、袋の中心から前へ出る距離

var fill := 1.0
var pour_rate := 0.0          # いま出ている勢い（袋/秒）。0＝注いでいない
var pour_dir := Vector3.FORWARD   # 傾ける向き（世界の水平方向。持っている人から見て向こう側）

var _pivot: Node3D
var _bag: MeshInstance3D
var _neck: Node3D
var _thin: CPUParticles3D
var _thick: CPUParticles3D
var _tilt := 0.0
var _shown := -1.0


func build() -> void:
	kind = "powdersack"
	label = "火薬の袋"
	mass = FULL_MASS
	center = Vector3(0, 0.2, 0)
	half = Vector3(0.17, 0.22, 0.17)
	hold_min = 1.1
	visual = Node3D.new()
	add_child(visual)
	# 傾けるときの軸は、袋のまんなか
	_pivot = Node3D.new()
	_pivot.position = center
	visual.add_child(_pivot)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("c9b385")
	cloth.roughness = 0.97
	var band := StandardMaterial3D.new()
	band.albedo_color = Color("3a2f25")
	band.roughness = 0.9
	_bag = MeshInstance3D.new()
	var lump := SphereMesh.new()
	lump.radius = 0.17
	lump.height = 0.34
	lump.radial_segments = 18
	lump.rings = 9
	_bag.mesh = lump
	_bag.material_override = cloth
	_pivot.add_child(_bag)
	# しばった口：ひもの輪と、その上に開いた布のふち
	_neck = Node3D.new()
	_pivot.add_child(_neck)
	var tie := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.05
	ring.bottom_radius = 0.065
	ring.height = 0.05
	tie.mesh = ring
	tie.material_override = band
	_neck.add_child(tie)
	var frill := MeshInstance3D.new()
	var flare := CylinderMesh.new()
	flare.top_radius = 0.085
	flare.bottom_radius = 0.045
	flare.height = 0.08
	frill.mesh = flare
	frill.material_override = cloth
	frill.position = Vector3(0, 0.06, 0)
	_neck.add_child(frill)
	# 中身の印：黒い火薬のしるし（どくろではなく、火の形の染み）
	var stain := MeshInstance3D.new()
	var patch := SphereMesh.new()
	patch.radius = 0.06
	patch.height = 0.12
	stain.mesh = patch
	stain.material_override = band
	stain.scale = Vector3(1.0, 1.2, 0.3)
	stain.position = Vector3(0, 0.0, 0.155)
	_bag.add_child(stain)
	# 口から落ちる粉：細い筋と、どさっと出たときの太い筋
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.13, 0.12, 0.13)
	dust.roughness = 1.0
	_thin = _stream(26, 0.014, dust)
	_thick = _stream(90, 0.022, dust)
	PropShapes.build(self, kind)
	_show_fill()


func _stream(amount: int, grain: float, material: Material) -> CPUParticles3D:
	var out := CPUParticles3D.new()
	out.amount = amount
	out.lifetime = 0.55
	out.local_coords = false
	out.direction = Vector3.DOWN
	out.spread = 9.0
	out.initial_velocity_min = 0.4
	out.initial_velocity_max = 1.0
	out.gravity = Vector3(0, -9.8, 0)
	out.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	out.emission_sphere_radius = grain * 2.0
	var bit := SphereMesh.new()
	bit.radius = grain
	bit.height = grain * 2.0
	bit.radial_segments = 4
	bit.rings = 2
	bit.material = material
	out.mesh = bit
	out.emitting = false
	out.top_level = true
	add_child(out)
	return out


# 粉が出てくる場所（世界の位置）
func spout() -> Vector3:
	return center_global() + pour_dir * SPOUT + Vector3(0, -0.03, 0)


func _show_fill() -> void:
	_shown = fill
	var k := clampf(fill, 0.0, 1.0)
	# 減るほど、背が低く・横に広がって、くたっとする
	var tall := lerpf(0.34, 1.22, k)
	var wide := lerpf(1.14, 1.0, k)
	_bag.scale = Vector3(wide, tall, wide * 0.9)
	_bag.position = Vector3(0, 0.17 * tall - center.y, 0)
	_neck.position = Vector3(0, 0.34 * tall - center.y - 0.01, 0)
	_neck.rotation.z = lerpf(0.9, 0.0, k)       # 空に近いと、口が横へ倒れる
	mass = lerpf(EMPTY_MASS, FULL_MASS, k)


func _process(delta: float) -> void:
	if not is_equal_approx(_shown, fill):
		_show_fill()
	var pouring := pour_rate > 0.0 and not absent
	_tilt = move_toward(_tilt, TILT if pouring else 0.0, delta * 7.0)
	if _tilt > 0.001:
		# 袋の「上」を、注ぐ向きへ倒す
		var inv := global_basis.orthonormalized().inverse()
		var axis := (inv * Vector3.UP).cross(inv * pour_dir)
		_pivot.basis = Basis(axis.normalized(), _tilt) if axis.length() > 0.01 else Basis.IDENTITY
	else:
		_pivot.basis = Basis.IDENTITY
	var at := spout()
	_thin.global_position = at
	_thick.global_position = at
	_thin.emitting = pouring and _tilt > TILT * 0.5
	_thick.emitting = pouring and pour_rate > 0.24 and _tilt > TILT * 0.5


func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed, fill]


func _apply_extra(s: Array) -> void:
	# ホストは自分で量を決めている。置き直し（撮り直しで場所を戻す）で、注いだ分が袋へ戻らないようにする。
	# 見返しの間だけは、記録どおりの量を見せる
	if s.size() >= 4 and (playback or not is_host()):
		fill = float(s[3])
