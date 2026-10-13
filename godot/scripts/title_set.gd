extends Node3D
# タイトル画面の撮影現場。制作班が本番前の準備をしていて、手前の機材ケースがそのままメニューになる。
# 画面上の四角（ボタンの位置）から逆算してケースを置くので、2Dのボタンと3Dのケースがぴったり重なる。

const UI := preload("res://scripts/ui/ui_theme.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
const PoseAim := preload("res://scripts/pose_aim.gd")
const Backstage := preload("res://scripts/title_backstage.gd")
const Transport := preload("res://scripts/title_transport.gd")

const CAM_POS := Vector3(0.05, 1.3, 8.6)
const CAM_FOV := 32.0
const CASE_DEPTH := 4.4            # カメラからケース正面までの距離
const CASE_THICK := 0.52

var cam: Camera3D
var cases: Array = []              # ケース（Node3D）。meta: home, mat, label, primary, hover
var enabled := true
var _hover: Array = []
var _t := 0.0
var _lamps: Array = []
var _mouse := Vector2.ZERO
var _stack_base: Node3D
var _case_note := ""
var _case_note_label: Label3D

# 制作班
var _director: Node3D
var _megaphone: Node3D
var _hand: Node3D
var _shout_marks: Array = []
var _shout := 0.0
var _next_shout := 2.0
var _boss: Node3D
var _boss_yaw := 0.0
var _robot: Node3D
var _robot_box: Node3D
var _robot_hands: Array = []
var _robot_phase := 0.0


func build() -> void:
	_build_world()
	_build_backdrop()
	_build_lights()
	_build_crew()
	_build_props()
	var transport := Transport.new()
	add_child(transport)
	transport.setup()
	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.position = CAM_POS
	cam.near = 0.2
	cam.far = 80.0
	# 手前と奥を少しぼかして、制作班とメニューに目が行くようにする
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = 3.3
	attr.dof_blur_near_transition = 1.0
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 11.5
	attr.dof_blur_far_transition = 7.0
	attr.dof_blur_amount = 0.07
	cam.attributes = attr
	add_child(cam)
	cam.current = true


# ---- 床と空気 ----

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.022, 0.028)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.55, 0.85)
	e.ambient_light_energy = 0.22
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 5.0
	e.ssao_enabled = true
	e.ssr_enabled = true
	e.ssr_max_steps = 96
	e.ssr_fade_in = 0.2
	e.ssr_fade_out = 2.5
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 1.05
	# 光の筋が見えるくらいの薄いもや
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.007
	e.volumetric_fog_albedo = Color(0.9, 0.86, 0.8)
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 40.0
	e.volumetric_fog_ambient_inject = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.06
	env.environment = e
	add_child(env)

	# 濡れたように光を返す黒い床
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.045, 0.047, 0.055)
	m.roughness = 0.2
	m.metallic = 0.15
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 1.6
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.35
	m.uv1_scale = Vector3(10, 10, 10)
	var rough := NoiseTexture2D.new()
	var rn := FastNoiseLite.new()
	rn.frequency = 0.006
	rough.noise = rn
	rough.width = 256
	rough.height = 256
	rough.seamless = true
	m.roughness_texture = rough
	floor_mesh.material_override = m
	add_child(floor_mesh)


# ---- 奥の書割：ベニヤを切り抜いた街並みと、爆炎 ----

func _build_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# 奥の列（背が高い）と、手前の列（低くて暗い）で重ねて奥行きを出す
	_skyline_row(rng, 0.2, 9.6, -6.6, 3.2, 6.2, Color(0.30, 0.215, 0.15), 1.0)
	_skyline_row(rng, 1.2, 9.2, -5.0, 1.6, 3.4, Color(0.21, 0.15, 0.105), 0.8)
	# 爆炎の書割（本編の小道具と同じ絵）
	var bm := StandardMaterial3D.new()
	var maker: Object = (load("res://scripts/boom_flat.gd") as GDScript).new()
	bm.albedo_texture = maker._burst_texture()
	maker.free()
	bm.albedo_color = Color(0.6, 0.55, 0.52)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	bm.alpha_scissor_threshold = 0.5
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.roughness = 0.95
	bm.emission_enabled = true
	bm.emission_texture = bm.albedo_texture
	bm.emission_energy_multiplier = 0.1
	# 元の一枚を斜めに向け、炎の絵の端から支えが少し見えるようにする。
	Backstage.flame(self,Vector2(3.8,3.8),bm,Vector3(5.2,-0.15,-3.3),0.50,0.08)


func _skyline_row(rng: RandomNumberGenerator, x0: float, x1: float, z: float, h_min: float, h_max: float, col: Color, glow: float) -> void:
	var x := x0
	while x < x1:
		var w := rng.randf_range(0.8, 1.5)
		var h := rng.randf_range(h_min, h_max)
		var tint := col.lightened(rng.randf_range(-0.04, 0.05))
		var zz := z - rng.randf_range(0.0, 0.5)
		# 上の階も同じ書割として回し、正面の窓と側面の木枠を一緒に見せる。
		var tower := Node3D.new()
		tower.position = Vector3(x + w * 0.5, 0, zz)
		tower.rotation.y = 0.30 if glow >= 1.0 else 0.48
		add_child(tower)
		_building(tower, Vector3.ZERO, w, h, tint, rng, glow)
		# 段々になった上の階
		var top_y := h
		var tw := w
		for tier in rng.randi_range(0, 2):
			tw *= rng.randf_range(0.5, 0.75)
			var th := rng.randf_range(0.35, 1.1)
			_building(tower, Vector3(rng.randf_range(-0.12, 0.12), top_y, 0), tw, th, tint, rng, glow)
			top_y += th
		# てっぺんのアンテナ
		if rng.randf() < 0.5:
			var ant := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(0.035, rng.randf_range(0.4, 1.0), 0.035)
			ant.mesh = am
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint.darkened(0.3)
			ant.material_override = mat
			ant.position = Vector3(0, top_y + am.size.y * 0.5, 0)
			tower.add_child(ant)
		x += w + rng.randf_range(-0.1, 0.18)


func _building(parent: Node3D, base: Vector3, w: float, h: float, col: Color, rng: RandomNumberGenerator, glow: float) -> void:
	var m := StandardMaterial3D.new()
	m.roughness = 0.95
	# 1枚の絵に、ベニヤの色・縁の塗り残し・窓を描く
	var cols := maxi(2, int(round(w / 0.26)))
	var rows := maxi(1, int(round(h / 0.36)))
	var cell := 12
	var img := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGB8)
	var lit := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGB8)
	img.fill(col)
	lit.fill(Color.BLACK)
	img.fill_rect(Rect2i(0, 0, cols * cell, 1), col.lightened(0.18))
	for r in rows:
		for c in cols:
			var win := Rect2i(c * cell + 3, r * cell + 3, 6, 6)
			if rng.randf() < 0.38:
				var warm := Color(1.0, rng.randf_range(0.66, 0.82), rng.randf_range(0.25, 0.42))
				img.fill_rect(win, warm.darkened(0.25))
				lit.fill_rect(win, warm * rng.randf_range(0.5, 1.0))
			else:
				img.fill_rect(win, col.darkened(0.45))
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(lit)
	m.emission_energy_multiplier = 1.25 * glow
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	Backstage.building(parent,Vector2(w,h),m,base,0.0,base.y < 0.01 and glow < 1.0)


# ---- 照明：スタンドつきのライトが現場を照らす ----

func _build_lights() -> void:
	# [位置, 狙い, 明るさ, 色, 大きさ]
	_lamp(Vector3(-1.6, 0, -2.4), Vector3(1.3, 1.2, 0.6), 34.0, Color(1.0, 0.8, 0.52), 1.75)
	_lamp(Vector3(6.6, 0, -0.4), Vector3(2.0, 1.0, 0.5), 22.0, Color(1.0, 0.86, 0.62), 1.9)
	# 画面の外、右上から差し込む光
	var beam := SpotLight3D.new()
	beam.position = Vector3(8.5, 8.0, -3.0)
	add_child(beam)
	beam.look_at(Vector3(3.2, 0.0, 0.8))
	beam.light_color = Color(1.0, 0.9, 0.72)
	beam.light_energy = 16.0
	beam.spot_range = 22.0
	beam.spot_angle = 16.0
	beam.spot_angle_attenuation = 0.6
	beam.shadow_enabled = true
	beam.light_volumetric_fog_energy = 1.3
	_lamps.append([beam, 16.0, 1.3])
	# 奥の街並みの書割を、下からぼんやり照らす
	var wash := SpotLight3D.new()
	wash.position = Vector3(4.6, 0.6, 0.6)
	add_child(wash)
	wash.look_at(Vector3(5.0, 3.2, -6.0))
	wash.light_color = Color(1.0, 0.62, 0.3)
	wash.light_energy = 9.0
	wash.spot_range = 16.0
	wash.spot_angle = 52.0
	wash.spot_angle_attenuation = 0.5
	wash.light_volumetric_fog_energy = 0.0
	# 顔が黒くつぶれないよう、手前から弱い青い光
	var fill := SpotLight3D.new()
	fill.position = Vector3(-1.0, 3.2, 8.0)
	add_child(fill)
	fill.look_at(Vector3(1.8, 1.0, 0.4))
	fill.light_color = Color(0.6, 0.72, 1.0)
	fill.light_energy = 5.0
	fill.spot_range = 16.0
	fill.spot_angle = 26.0
	fill.light_volumetric_fog_energy = 0.0
	# メニューのケースを読める明るさに
	var menu := SpotLight3D.new()
	menu.position = Vector3(-1.2, 3.4, 7.4)
	add_child(menu)
	menu.look_at(Vector3(-1.2, 0.7, 4.0))
	menu.light_color = Color(1.0, 0.95, 0.86)
	menu.light_energy = 8.0
	menu.spot_range = 9.0
	menu.spot_angle = 30.0
	menu.light_volumetric_fog_energy = 0.0
	menu.shadow_enabled = true


func _lamp(pos: Vector3, target: Vector3, energy: float, col: Color, big: float) -> void:
	var rig := Node3D.new()
	rig.position = pos
	rig.scale = Vector3.ONE * big
	add_child(rig)
	var stand: Node3D = (load("res://assets/gear/C06_Century_Stand.glb") as PackedScene).instantiate()
	rig.add_child(stand)
	var grip: Node3D = stand.find_child("03_REMOVABLE_GRIP_HEAD", true, false)
	if grip:
		grip.visible = false
	var shoulder: Node3D = stand.find_child("ATTACH_LAMP_BABY_SHOULDER", true, false)
	var pan := Node3D.new()
	shoulder.add_child(pan)
	var lamp: Node3D = (load("res://assets/gear/F06_Fresnel_Light.glb") as PackedScene).instantiate()
	pan.add_child(lamp)
	var tilt: Node3D = lamp.find_child("PIVOT_HEAD_TILT_X", true, false)
	var d: Vector3 = target - (pos + Vector3(0, 2.0 * big, 0))
	pan.rotation.y = atan2(d.x, d.z)
	tilt.rotation.x = -atan2(d.y, Vector2(d.x, d.z).length())
	var light := SpotLight3D.new()
	light.position = Vector3(0, 0, 0.13)
	light.rotation.y = PI
	light.light_color = col
	light.light_energy = energy
	light.spot_range = 22.0
	light.spot_angle = 24.0
	light.spot_angle_attenuation = 0.7
	light.shadow_enabled = true
	light.shadow_blur = 1.4
	light.light_volumetric_fog_energy = 1.1
	tilt.add_child(light)
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.055
	disc.bottom_radius = 0.055
	disc.height = 0.004
	face.mesh = disc
	face.rotation.x = PI * 0.5
	face.position = Vector3(0, 0, 0.1)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = col
	fm.emission_enabled = true
	fm.emission = col
	fm.emission_energy_multiplier = 9.0
	face.material_override = fm
	tilt.add_child(face)
	_lamps.append([light, energy, randf() * 6.0])


# ---- 制作班：それぞれ自分の仕事をしている ----

func _cast(tag: String, pos: Vector3, yaw: float) -> Node3D:
	if not ResourceLoader.exists("res://assets/cast/cast%s_game.glb" % tag):
		return null
	var v: Node3D = CastVisual.new()
	add_child(v)
	v.setup(tag)
	v.position = pos
	v.rotation.y = yaw
	return v


func _pose(v: Node3D, aims: Dictionary) -> SkeletonModifier3D:
	var p: SkeletonModifier3D = PoseAim.new()
	v.skel.add_child(p)
	for bone: String in aims:
		p.set_aim(bone, aims[bone])
	return p


func _build_crew() -> void:
	# 監督：メガホンを口元に構え、もう片方の手で指示を出す
	_director = _cast("04", Vector3(0.1, 0, 0.9), 0.62)
	if _director:
		_director.play("idle")
		_pose(_director, {
			"UPPER_ARM.R": Vector3(-0.3, 0.9, 0.3), "FOREARM.R": Vector3(0.05, 0.88, 0.47), "HAND.R": Vector3(0.05, 0.85, 0.5),
			"UPPER_ARM.L": Vector3(0.55, 0.38, 0.74), "FOREARM.L": Vector3(0.5, 0.42, 0.76), "HAND.L": Vector3(0.48, 0.42, 0.77),
		})
		if ResourceLoader.exists("res://assets/title/P052_megaphone.glb"):
			var att := BoneAttachment3D.new()
			att.bone_name = "HAND.R"
			_director.skel.add_child(att)
			_megaphone = (load("res://assets/title/P052_megaphone.glb") as PackedScene).instantiate()
			att.add_child(_megaphone)
			_hand = att
			# 声が飛ぶ印：メガホンの先に黄色い線が3本
			var mark_mat := StandardMaterial3D.new()
			mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mark_mat.albedo_color = UI.TAPE
			for k in 3:
				var mk := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.022, 0.022, 0.13)
				mk.mesh = bm
				mk.material_override = mark_mat
				mk.visible = false
				add_child(mk)
				_shout_marks.append(mk)
	# 班長：腰に手を当てて、現場を見回している
	_boss = _cast("09", Vector3(1.5, 0, 0.3), -0.08)
	if _boss:
		_boss.play("idle")
		_boss_yaw = _boss.rotation.y
		_pose(_boss, {
			"UPPER_ARM.R": Vector3(-0.8, -0.5, -0.08), "FOREARM.R": Vector3(0.72, -0.5, 0.42), "HAND.R": Vector3(0.6, -0.6, 0.4),
			"UPPER_ARM.L": Vector3(0.8, -0.5, -0.08), "FOREARM.L": Vector3(-0.72, -0.5, 0.42), "HAND.L": Vector3(-0.6, -0.6, 0.4),
		})
	# ロボ：箱を抱えて、行ったり来たり運んでいる
	_robot = _cast("M02", Vector3(2.75, 0, 1.0), -0.4)
	if _robot:
		_robot.play("idle")
		# 両腕を前へ出して、箱を抱える
		_pose(_robot, {
			"UPPER_ARM.R": Vector3(-0.35, -0.25, 0.9), "FOREARM.R": Vector3(0.2, -0.05, 0.98), "HAND.R": Vector3(0.3, 0.0, 0.95),
			"UPPER_ARM.L": Vector3(0.35, -0.25, 0.9), "FOREARM.L": Vector3(-0.2, -0.05, 0.98), "HAND.L": Vector3(-0.3, 0.0, 0.95),
		})
		for side: String in ["HAND.L", "HAND.R"]:
			var ha := BoneAttachment3D.new()
			ha.bone_name = side
			_robot.skel.add_child(ha)
			_robot_hands.append(ha)
		if ResourceLoader.exists("res://assets/props/P069_apple_box.glb"):
			_robot_box = (load("res://assets/props/P069_apple_box.glb") as PackedScene).instantiate()
			_robot_box.scale = Vector3.ONE * 1.5
			add_child(_robot_box)


func _animate_crew(delta: float) -> void:
	if _director and _megaphone:
		# 数秒ごとに「よーい！」と声を張る：体を前へ、メガホンを突き出す
		_next_shout -= delta
		if _next_shout <= 0.0:
			_next_shout = randf_range(2.6, 4.4)
			_shout = 1.0
			_director.set_face("happy")
		_shout = maxf(0.0, _shout - delta * 1.5)
		var punch := sin(clampf(_shout, 0.0, 1.0) * PI)
		_director.rotation.x = 0.07 * punch
		if _shout <= 0.0:
			_director.set_face("neutral")
		var hp: Vector3 = _hand.global_position
		var fwd: Vector3 = _director.global_basis.z.normalized()
		var aim := (fwd + Vector3(0, 0.22 + 0.1 * punch, 0)).normalized()
		_megaphone.global_position = hp + aim * (0.12 + 0.05 * punch) + Vector3(0, 0.06, 0)
		_megaphone.global_basis = Basis.looking_at(-aim, Vector3.UP).scaled(Vector3.ONE * 1.25)
		var tip := _megaphone.global_position + aim * 0.36
		var side := aim.cross(Vector3.UP).normalized()
		for k in _shout_marks.size():
			var mk: MeshInstance3D = _shout_marks[k]
			mk.visible = _shout > 0.25
			var spread := float(k - 1) * 0.55
			var dir := (aim + (Vector3.UP * 0.75 + side * 0.25) * spread * 0.8).normalized()
			mk.global_position = tip + dir * (0.16 + 0.1 * (1.0 - _shout))
			mk.global_basis = Basis.looking_at(dir, Vector3.UP)
	if _boss:
		# ゆっくり左右を見回す
		_boss.rotation.y = _boss_yaw + 0.22 * sin(_t * 0.55)
	if _robot:
		# 右へ運び、少し止まり、戻ってくる
		_robot_phase = fmod(_robot_phase + delta, 9.0)
		var x := 2.4
		var moving := false
		var face_dir := 1.0
		if _robot_phase < 3.0:
			x = lerpf(2.4, 3.05, smoothstep(0.0, 3.0, _robot_phase))
			moving = true
		elif _robot_phase < 4.5:
			x = 3.05
		elif _robot_phase < 7.5:
			x = lerpf(3.05, 2.4, smoothstep(4.5, 7.5, _robot_phase))
			moving = true
			face_dir = -1.0
		_robot.position.x = x
		var want_yaw := (0.95 if face_dir > 0.0 else -0.95) if moving else -0.35
		_robot.rotation.y = lerp_angle(_robot.rotation.y, want_yaw, clampf(delta * 4.0, 0.0, 1.0))
		_robot.play("walk" if moving else "idle", 0.25)
		if _robot_box and _robot_hands.size() == 2:
			var grip: Vector3 = ((_robot_hands[0] as Node3D).global_position + (_robot_hands[1] as Node3D).global_position) * 0.5
			var rf: Vector3 = _robot.global_basis.z.normalized()
			_robot_box.global_position = grip + rf * 0.05 + Vector3(0, -0.2, 0)
			_robot_box.rotation.y = _robot.rotation.y


# ---- 現場に置いてある物 ----

func _build_props() -> void:
	_model("res://assets/title/S026_director_chair.glb", Vector3(-0.9, 0, -0.9), 0.55, 1.0)
	_model("res://assets/gear/carton.glb", Vector3(5.2, 0, 0.0), 0.4, 2.0)
	_model("res://assets/gear/carton.glb", Vector3(5.6, 0, 1.2), -0.3, 2.0)
	_model("res://assets/props/P069_apple_box.glb", Vector3(4.2, 0, -0.9), 0.2, 1.6)
	_model("res://assets/props/P069_apple_box.glb", Vector3(4.25, 0.29, -0.9), 0.5, 1.6)
	# 床を這うケーブル
	_model("res://assets/title/P065_cable_coil.glb", Vector3(0.6, 0.0, 2.6), 0.3, 2.4)
	_model("res://assets/title/P065_cable_coil.glb", Vector3(2.2, 0.0, 3.2), 1.4, 2.0)
	# 右下の手前：機材ケースが影になって、ぼけて入る
	_dark_box(Vector3(1.55, 0.36, 6.5), Vector3(0.9, 0.72, 0.6), 0.25)
	_dark_box(Vector3(1.75, 0.95, 6.55), Vector3(0.5, 0.42, 0.42), -0.2)
	# 右上の手前：吊ったライトの影
	if ResourceLoader.exists("res://assets/gear/F06_Fresnel_Light.glb"):
		var hang: Node3D = (load("res://assets/gear/F06_Fresnel_Light.glb") as PackedScene).instantiate()
		hang.position = Vector3(1.36, 2.1, 6.6)
		hang.rotation = Vector3(0.5, 2.3, PI)
		hang.scale = Vector3.ONE * 1.7
		add_child(hang)


func _dark_box(pos: Vector3, size: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.032, 0.038)
	m.roughness = 0.6
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)


func _model(path: String, pos: Vector3, yaw: float, big: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * big
	add_child(n)
	return n


# ---- メニューになる機材ケース ----

# rects: 画面上の四角（ビューポートの座標）。kinds: "primary" / "dark"。texts: 正面の文字。text_x: 文字の中心（四角の中の0..1）
func layout_cases(rects: Array, kinds: Array, texts: Array, text_x: Array) -> void:
	for c: Node3D in cases:
		c.queue_free()
	cases.clear()
	_hover.clear()
	if is_instance_valid(_stack_base):
		_stack_base.queue_free()
	cam.position = CAM_POS
	cam.rotation = Vector3.ZERO
	var lowest := INF
	var left := INF
	var right := -INF
	for i in rects.size():
		var r: Rect2 = rects[i]
		var tl: Vector3 = cam.project_position(r.position, CASE_DEPTH)
		var br: Vector3 = cam.project_position(r.end, CASE_DEPTH)
		var size := Vector3(absf(br.x - tl.x), absf(tl.y - br.y), CASE_THICK)
		var center := Vector3((tl.x + br.x) * 0.5, (tl.y + br.y) * 0.5, tl.z - CASE_THICK * 0.5)
		var px: float = size.y / r.size.y          # 画面1pxぶんの長さ
		var node := _make_case(size, kinds[i] == "primary", texts[i], px, float(text_x[i]))
		node.position = center
		node.set_meta("home", center)
		add_child(node)
		cases.append(node)
		_hover.append(0.0)
		lowest = minf(lowest, center.y - size.y * 0.5)
		left = minf(left, center.x - size.x * 0.5)
		right = maxf(right, center.x + size.x * 0.5)
	# ケースの山を載せる、ひと回り大きいケース（床まで）
	if lowest > 0.02 and lowest < 3.0 and not rects.is_empty():
		var px_base: float = (right - left) / (rects[0] as Rect2).size.x
		_stack_base = _make_case(Vector3(right - left + px_base * 20.0, lowest, CASE_THICK + 0.1), false, "", px_base, 0.5)
		_stack_base.position = Vector3((left + right) * 0.5, lowest * 0.5, cam.position.z - CASE_DEPTH - CASE_THICK * 0.5)
		add_child(_stack_base)
		# 連絡事項もケースの前面に書く。カメラが漂ってもケースと一緒に動く。
		_case_note_label = _stack_base.get_meta("label")
		_case_note_label.font = UI.fnt("body")
		_case_note_label.pixel_size = px_base * 17.0 / 96.0
		_case_note_label.width = (right - left - px_base * 36.0) / _case_note_label.pixel_size
		_case_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_case_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_case_note_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_case_note_label.modulate = Color(UI.CLAP_WHITE, 0.8)
		_case_note_label.position = Vector3(-(right - left) * 0.5 + px_base * 18.0, lowest * 0.5 - px_base * 30.0, (CASE_THICK + 0.1) * 0.5 + px_base * 2.5)
		_case_note_label.text = _case_note


func set_case_note(text: String) -> void:
	_case_note = text
	if is_instance_valid(_case_note_label):
		_case_note_label.text = text


func _make_case(size: Vector3, primary: bool, text: String, px: float, text_x: float) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size - Vector3(0, px * 4.0, 0)       # ケースどうしの間に細い影の隙間
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.66, 0.0) if primary else Color(0.105, 0.11, 0.125)
	m.roughness = 0.5
	m.metallic = 0.05
	m.emission_enabled = true
	m.emission = UI.TAPE if primary else Color(0.5, 0.55, 0.7)
	m.emission_energy_multiplier = 0.0
	body.material_override = m
	root.add_child(body)
	root.set_meta("mat", m)
	root.set_meta("primary", primary)
	# 縁の金具と留め具
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.1, 0.1, 0.11) if primary else Color(0.42, 0.44, 0.48)
	metal.metallic = 0.7
	metal.roughness = 0.38
	var edge := px * 3.0
	for sy: float in [-1.0, 1.0]:
		_bar(root, Vector3(0, sy * (size.y * 0.5 - px * 2.0 - edge * 0.5), size.z * 0.5), Vector3(size.x, edge, edge), metal)
	for sx: float in [-1.0, 1.0]:
		_bar(root, Vector3(sx * (size.x * 0.5 - edge * 0.5), 0, size.z * 0.5), Vector3(edge, size.y - px * 4.0, edge), metal)
		_bar(root, Vector3(sx * (size.x * 0.5 - px * 26.0), size.y * 0.5 - px * 9.0, size.z * 0.5 + px), Vector3(px * 16.0, px * 8.0, px * 3.0), metal)
	var label := Label3D.new()
	label.text = text
	label.font = UI.fnt("bold")
	label.font_size = 96
	label.pixel_size = px * 23.0 / 96.0
	label.modulate = UI.INK if primary else UI.CLAP_WHITE
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.position = Vector3((text_x - 0.5) * size.x, -px, size.z * 0.5 + px * 2.5)
	root.add_child(label)
	root.set_meta("label", label)
	return root


func _bar(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# いまの画面上の四角（カメラが少し揺れても、2Dのボタンを重ね直せる）
func case_rect(i: int) -> Rect2:
	var node: Node3D = cases[i]
	var bm: BoxMesh = (node.get_child(0) as MeshInstance3D).mesh
	var half := bm.size * 0.5
	var front := node.global_position + Vector3(0, 0, half.z)
	var a := cam.unproject_position(front + Vector3(-half.x, half.y, 0))
	var b := cam.unproject_position(front + Vector3(half.x, -half.y, 0))
	return Rect2(a, b - a)


func set_hover(i: int, on: bool) -> void:
	if i >= 0 and i < cases.size():
		cases[i].set_meta("hover", on)


func set_mouse(norm: Vector2) -> void:
	_mouse = norm


func _process(delta: float) -> void:
	_t += delta
	# カメラは、ほんの少しだけ漂う
	if cam:
		cam.position = CAM_POS + Vector3(sin(_t * 0.21) * 0.07 + _mouse.x * 0.06, sin(_t * 0.17) * 0.025 - _mouse.y * 0.03, 0.0)
	for i in cases.size():
		var node: Node3D = cases[i]
		var want := 1.0 if (enabled and node.get_meta("hover", false)) else 0.0
		_hover[i] = lerpf(_hover[i], want, clampf(delta * 14.0, 0.0, 1.0))
		var home: Vector3 = node.get_meta("home")
		node.position = home + Vector3(0, 0, 0.07 * _hover[i])
		var m: StandardMaterial3D = node.get_meta("mat")
		m.emission_energy_multiplier = _hover[i] * (0.3 if node.get_meta("primary") else 0.16)
		var label: Label3D = node.get_meta("label")
		var base: Color = UI.INK if node.get_meta("primary") else UI.CLAP_WHITE
		if not node.get_meta("primary"):
			base = base.lerp(UI.TAPE, _hover[i])
		label.modulate = Color(base, 1.0 if enabled else 0.4)
	# ライトはごくわずかに息をする
	for l: Array in _lamps:
		(l[0] as SpotLight3D).light_energy = float(l[1]) * (1.0 + 0.03 * sin(_t * 1.7 + float(l[2])))
	_animate_crew(delta)
