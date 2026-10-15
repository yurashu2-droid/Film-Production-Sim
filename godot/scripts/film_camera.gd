extends "res://scripts/prop.gd"
# 三脚つきの撮影カメラ。操作中は身体を動かさず首振りとズームを行う。

const VIEW_SIZE := Vector2i(1280, 720)
const HEAD_Y := 1.35
const FOV_MIN := 18.0
const FOV_MAX := 75.0
const PropShapes := preload("res://scripts/prop_shapes.gd")
# フィルムのリール（小物の P056。形は変えず、大きさだけ変えて、カメラの上に2つ載せる）。
# 前のリール＝これから撮る分（撮るほど巻きが細くなる）、後ろのリール＝撮り終えた分（太くなる）。
# 場面の列を持つ依頼（production_beats.gd）のときだけ出す。残り秒数の数字は、どこにも出さない
const REEL_MODEL := "res://assets/props/P056_film_reel.glb"
const REEL_SIZE := 0.47           # 元のモデル（直径 約0.3m）に対する大きさ（直径 約14cm）
const REEL_TOP := 0.186           # カメラの取っ手の上の高さ（カメラ本体の座標）。ここにリールを載せる
const REEL_CENTER := 0.148        # 元のモデルの、床から軸までの高さ
const REEL_EMPTY := 0.5           # 巻きがいちばん細いときの太さ（芯とほぼ同じ）

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
const CREW_LAYER := 1 << 11      # 制作班だけに見える物（見立ての札など）の描画レイヤー
var tally: MeshInstance3D
var monitor_surface: MeshInstance3D
var film_shown := false          # リールを出しているか
var film_frac := 1.0             # フィルムの残り（1＝まるごと / 0＝切れた）
var _reels: Node3D
var _spins: Array = []            # [前のリール, 後ろのリール] の、回る所
var _packs: Array = []            # それぞれの、巻いたフィルム [物, もとの置き方, 軸の場所]
var _film_rolling := false
var _film_low := false
var _film_t := 0.0


func build() -> void:
	kind = "camera"
	label = "撮影カメラ"
	mass = 14.0
	center = Vector3(0, 0.7, 0)
	half = Vector3(0.45, 0.75, 0.45)
	hold_min = 1.4
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

	# フィルムのリール：カメラの上に、前後に2つ。軸は横向き（横から見ると、巻きの太さが分かる）
	_reels = Node3D.new()
	_reels.name = "FilmReels"
	_reels.visible = false
	body.add_child(_reels)
	for z: float in [0.08, -0.068]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.0, REEL_TOP + REEL_CENTER * REEL_SIZE, z)
		pivot.rotation.y = PI * 0.5
		pivot.scale = Vector3.ONE * REEL_SIZE
		_reels.add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var reel: Node3D = (load(REEL_MODEL) as PackedScene).instantiate()
		reel.position = Vector3(0, -REEL_CENTER, 0)
		spin.add_child(reel)
		_spins.append(spin)
		# 巻いたフィルムの部品（P056_film_〜）。リールの枠と芯は、別の部品
		for pack: MeshInstance3D in reel.find_children("P056_film_*", "MeshInstance3D", true, false):
			_packs.append([pack, pack.transform, pack.transform * pack.mesh.get_aabb().get_center()])
			break
	# 支え：リールを載せる細い柱（単純な形）
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.012, REEL_CENTER * REEL_SIZE, 0.15)
	post.mesh = post_mesh
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("26282c")
	post_mat.roughness = 0.6
	post.material_override = post_mat
	post.position = Vector3(0.0, REEL_TOP + REEL_CENTER * REEL_SIZE * 0.5, 0.006)
	_reels.add_child(post)

	# 当たり判定と重心は表（prop_shapes.gd）：三脚の広がりに合わせた段々の円柱と、雲台・カメラの箱
	PropShapes.build(self, kind)

	view = SubViewport.new()
	view.size = VIEW_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	view.audio_listener_enable_3d = false
	add_child(view)
	view_cam = Camera3D.new()
	view_cam.near = 0.15
	view_cam.far = 120.0
	# 撮影カメラは、世界と同じ光（昼の空・もや・色味）で写す。目で見えているとおりに映る
	# （以前は撮影側だけ暗く締めて夜に見せていた。昼なのに夜に映るのが不自然なのでやめた）
	# 制作班だけに見える札（CREW_LAYER）と、一人称の手の写し（1 << 13。first_person_arms.gd）は、映画には映さない
	view_cam.cull_mask = 0xFFFFF & ~CREW_LAYER & ~(1 << 13)
	view.add_child(view_cam)
	view_cam.current = true
	monitor_surface = body.find_child("LCD*single*image*display*",true,false) as MeshInstance3D
	var display := StandardMaterial3D.new()
	display.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	display.albedo_texture = view.get_texture()
	monitor_surface.material_override = display

func monitor_texture() -> Texture2D:
	return monitor_surface.material_override.albedo_texture

func operation_view() -> Transform3D:
	var target: Vector3 = monitor_surface.global_transform * monitor_surface.get_aabb().get_center()
	var eye: Vector3 = lens.global_transform * Vector3(0.30,0.13,0.42)
	if film_shown:
		# フィルムのリールを載せているとき：少し引いて、少し上を見る（カメラの上のリールが、視野に入るように）
		target += lens.global_basis.y * 0.05
		eye = target + (eye - target) * 1.4
	return Transform3D(Basis.IDENTITY,eye).looking_at(target,Vector3.UP)


func aim(dyaw: float, dpitch: float, dfov: float) -> void:
	cam_yaw = wrapf(cam_yaw + dyaw, -PI, PI)
	cam_pitch = clampf(cam_pitch + dpitch, -1.0, 1.0)
	fov = clampf(fov + dfov, FOV_MIN, FOV_MAX)


func shoot_dir() -> Vector3:
	return -lens.global_basis.z


# フィルムの残りを見せる（全員の画面。production_beats.gd が毎コマ呼ぶ）。
#   shown＝リールを出すか / frac＝残り（1〜0）/ rolling＝回っているか（本番・見返し）/ low＝残りわずか
func set_film(shown: bool, frac: float, rolling: bool, low: bool) -> void:
	film_shown = shown
	film_frac = clampf(frac, 0.0, 1.0)
	_film_rolling = rolling
	_film_low = low
	_reels.visible = shown


# 巻いたフィルムの太さ（もとの太さに対する割合）。0＝これから撮る分（前のリール）/ 1＝撮り終えた分（後ろのリール）
func reel_fill(which: int) -> float:
	var amount: float = film_frac if which == 0 else 1.0 - film_frac
	return lerpf(REEL_EMPTY, 1.0, amount)


func _show_film(delta: float) -> void:
	_film_t += delta
	for i in _packs.size():
		var pack: MeshInstance3D = _packs[i][0]
		var k := reel_fill(i)
		var at: Vector3 = _packs[i][2]
		# 軸のまわりに、巻きだけを細くする（リールの枠と芯は、そのまま）
		pack.transform = Transform3D(Basis.IDENTITY, at) * Transform3D(Basis.from_scale(Vector3(k, k, 1.0)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -at) * (_packs[i][1] as Transform3D)
		pack.visible = k > REEL_EMPTY + 0.01
	for i in _spins.size():
		var spin: Node3D = _spins[i]
		if _film_rolling:
			# 巻きが細いほうが、速く回る
			spin.rotation.z = wrapf(spin.rotation.z - delta * 2.6 / reel_fill(i), -PI, PI)
		# 残りわずか：前のリールが、がたつく
		spin.position = Vector3(0, sin(_film_t * 47.0) * 0.012, 0) if _film_low and i == 0 else Vector3.ZERO
	# 残りわずか：録画灯が、せわしなく点滅する
	var lamp: StandardMaterial3D = tally.material_override
	lamp.emission_energy_multiplier = (8.0 if int(_film_t * 8.0) % 2 == 0 else 0.4) if _film_low else 4.0


func _process(delta: float) -> void:
	pan_node.rotation.y = cam_yaw
	tilt_node.rotation.x = -cam_pitch
	view_cam.global_transform = lens.global_transform
	view_cam.fov = fov
	if film_shown:
		_show_film(delta)


func _host_tick(_delta: float) -> void:
	if operator == 0 or rider_of == 0:
		return
	var cart: RigidBody3D = game.props.get(rider_of)
	if cart and cart.holder == 0 and not cart.fixed:
		var v := dolly * 2.2
		cart.linear_velocity.x = v.x
		cart.linear_velocity.z = v.z
		cart.sleeping = false


func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed, cam_yaw, cam_pitch, fov]


func _apply_extra(s: Array) -> void:
	if s.size() < 6:
		return
	cam_yaw = s[3]
	cam_pitch = s[4]
	fov = s[5]
