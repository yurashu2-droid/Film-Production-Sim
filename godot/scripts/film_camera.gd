extends "res://scripts/prop.gd"
# 三脚つきの撮影カメラ。操作中は身体を動かさず首振りとズームを行う。

const VIEW_SIZE := Vector2i(1280, 720)
const HEAD_Y := 1.35
const DROP := 1.30                # 三脚なし：カメラ本体を、三脚の頭の高さから床まで下げる分（三脚の頭の、カメラを載せる所の高さ）
# 三脚なしのときに隠す、三脚の部品（脚・開き止め・頭の飾り）。首振り・上下の可動部（PIVOT_PAN_Z・PIVOT_TILT_X）は、見えない軸として残す
const TRIPOD_PARTS := ["01_BOWL_CROWN", "PIVOT_LEG_01_SPLAY", "PIVOT_LEG_02_SPLAY", "PIVOT_LEG_03_SPLAY", "PIVOT_SPREADER_01", "PIVOT_SPREADER_02",
	"PIVOT_SPREADER_03", "T06_TRIPOD_ROOT merged surfaces", "PIVOT_BOWL_LEVEL_XY merged surfaces", "PIVOT_PAN_Z merged surfaces", "PIVOT_PAN_LOCK_Z",
	"PIVOT_TILT_LOCK_X", "PIVOT_PAN_BAR_X", "PIVOT_QR_LOCK_X", "PIVOT_TILT_X merged surfaces", "SLIDE_QUICK_RELEASE_PLATE_Y merged surfaces"]
var tripod := true                # 三脚に載っているか（会社のアップグレード。features/camera_kit.gd が決める）
var head_y := HEAD_Y              # レンズの高さ（三脚なしなら、床から少し上）
const FOV_MIN := 18.0
const FOV_MAX := 75.0
const PropShapes := preload("res://scripts/prop_shapes.gd")
# カードの残り（録画できる残り）：カメラには出さない。画面の上の欄にバーで出す（features/card_gauge.gd）。
# 前は横腹に小窓（フィルムの巻き → 残量のバー）を付けていたが、「カメラのそんな所に、バーはふつう無い」（2026-11-14 ユーザー）。
# ここは、残りの値を持つだけ（production_beats.gd が毎コマ入れる）。残りわずかの時は、録画灯がせわしなく点滅する
const REEL_EMPTY := 0.33          # 前の小窓の決まりの名残（reel_fill の一番小さい値。確認が使う）

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
var film_shown := false          # カードの残りを数えているか（場面の列を持つ依頼の、本番の前後）
var film_frac := 1.0             # カードの残り（1＝まるごと / 0＝いっぱい）
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
	# 制作班だけに見える札（CREW_LAYER）と、一人称の手の写し（1 << 13。first_person_arms.gd）と、
	# 試写会を見ている人（1 << 15。features/premiere.gd）は、映画には映さない
	view_cam.cull_mask = 0xFFFFF & ~CREW_LAYER & ~(1 << 13) & ~(1 << 15)
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
	return Transform3D(Basis.IDENTITY,eye).looking_at(target,Vector3.UP)


func aim(dyaw: float, dpitch: float, dfov: float) -> void:
	cam_yaw = wrapf(cam_yaw + dyaw, -PI, PI)
	cam_pitch = clampf(cam_pitch + dpitch, -1.0, 1.0)
	fov = clampf(fov + dfov, FOV_MIN, FOV_MAX)


func shoot_dir() -> Vector3:
	return -lens.global_basis.z


# カードの残りを見せる（全員の画面。production_beats.gd が毎コマ呼ぶ）。
#   shown＝残りを数えているか / frac＝残り（1〜0）/ rolling＝回っているか（本番・見返し）/ low＝残りわずか
func set_film(shown: bool, frac: float, rolling: bool, low: bool) -> void:
	film_shown = shown
	film_frac = clampf(frac, 0.0, 1.0)
	_film_rolling = rolling
	_film_low = low


# 残りの割合を、REEL_EMPTY〜1 に直した値（前の小窓の決まり。確認が使う）。0＝これから撮る分 / 1＝撮り終えた分
func reel_fill(which: int) -> float:
	var amount: float = film_frac if which == 0 else 1.0 - film_frac
	return lerpf(REEL_EMPTY, 1.0, amount)


func _show_film(delta: float) -> void:
	_film_t += delta
	# 残りわずか：録画灯が、せわしなく点滅する
	var lamp: StandardMaterial3D = tally.material_override
	lamp.emission_energy_multiplier = (8.0 if int(_film_t * 8.0) % 2 == 0 else 0.4) if _film_low else 4.0


func _process(delta: float) -> void:
	pan_node.rotation.y = cam_yaw
	tilt_node.rotation.x = -cam_pitch
	view_cam.global_transform = lens.global_transform
	view_cam.fov = fov
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


# 三脚に載せる・外す（全員の画面で同じに呼ぶ）。外すと、三脚の部品を隠し、カメラ本体を床まで下げて、当たり判定を本体の箱にする。
# 向きの操作（首振り・上下）は、そのまま使える（見えない軸が残っている）
func set_tripod(on: bool) -> void:
	if on == tripod:
		return
	tripod = on
	for part: String in TRIPOD_PARTS:
		var node: Node3D = visual.find_child(part, true, false)
		if node != null:
			node.visible = on
	visual.position.y = 0.0 if on else -DROP
	head_y = HEAD_Y if on else HEAD_Y - DROP
	for child: Node in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	if on:
		mass = 14.0
		center = Vector3(0, 0.7, 0)
		half = Vector3(0.45, 0.75, 0.45)
		hold_min = 1.4
		PropShapes.build(self, kind)
	else:
		# カメラ本体だけ：本体の外形の箱ひとつ（段ボールの上に載せる・手で持つ）
		var box := _body_bounds()
		mass = 5.0
		center = box.get_center()
		half = box.size * 0.5
		hold_min = maxf(1.0, half.z + 0.8)
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = center
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size * 0.96
		shape.shape = bs
		shape.position = center
		add_child(shape)


# カメラ本体（三脚の部品を除く）の外形（この物の座標）
func _body_bounds() -> AABB:
	var out := AABB()
	var first := true
	var mount: Node3D = visual.find_child("ATTACH_C04_CAMERA_ROOT", true, false)
	for mi: MeshInstance3D in mount.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var b: AABB = (global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
