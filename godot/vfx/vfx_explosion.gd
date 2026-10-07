extends "res://vfx/vfx_base.gd"
# 爆発。役割ごとに層を分け、時間をずらして重ねる。
#   閃光（一瞬）→ 火球（膨らんで煤になり、焼けた縁を残して溶ける）→ 火花・破片・衝撃波
#   → 地を這う土煙 → 立ちのぼる黒煙 → 地面の残り火
# size はおおよその火球の半径（m）。ground_drop は中心から地面までの距離で、負なら空中爆発。

const Fire := preload("res://vfx/vfx_fire.gd")


static func spawn(parent: Node, pos: Vector3, size: float = 3.2, ground_drop: float = 1.25, full: bool = true) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, ground_drop, full)
	return fx


# 爆発前の溜め。火花を噴きながら光が強まっていく。seconds 後に爆発を出す側と合わせて使う。
static func fuse(parent: Node, pos: Vector3, seconds: float, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start_fuse(seconds, size)
	return fx


func start(u: float, ground_drop: float, full: bool) -> void:
	life = 3.6 if full else 2.4
	var cells := Lib.noise("cells")
	var grounded := ground_drop >= 0.0 and ground_drop < u * 2.0
	var ground := Vector3(0, -ground_drop, 0)

	# 閃光：最初の数コマだけ、画面を白く飛ばす
	var flash := sprite(2, Color(10, 8.5, 6), u)
	param(flash, "toward_camera", u * 1.8)
	over(0.0, 0.16, func(k: float) -> void:
		flash.scale = Vector3.ONE * u * lerpf(1.5, 3.6, ease_out(k))
		param(flash, "color", Color(10, 8.5, 6, 1.0 - k * k))
	)
	at(0.17, flash.queue_free)
	var light := lamp(Color(1.0, 0.6, 0.25), u * 6.5)
	over(0.0, 1.3, func(k: float) -> void:
		light.light_energy = 19.0 * u * pow(1.0 - k, 2.0) * (0.85 + 0.15 * sin(age * 50.0))
	)

	# 火球：白熱 → 橙 → 暗い赤 → 煤。寿命の後半で穴が開き、縁が焼けて見える
	var fire_mat := Lib.material("cloud", {
		"dissolve_texture": cells,
		"shadow_tint": Vector3(0.5, 0.28, 0.2),
		"highlight_tint": Vector3(1.35, 1.35, 1.3),
		"edge_color": Vector3(6.0, 1.6, 0.2),
	})
	emit(Lib.particles(Lib.cloud_mesh(0), fire_mat, Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.2 * u,
		"direction": Vector3.UP,
		"spread": 130.0,
		"initial_velocity_min": 2.5 * u,
		"initial_velocity_max": 6.5 * u,
		"damping_min": 20.0 * u,
		"damping_max": 26.0 * u,
		"gravity": Vector3(0, 0.5 * u, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"angular_velocity_min": -40.0,
		"angular_velocity_max": 40.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.45 * u,
		"scale_max": 0.9 * u,
		"scale_curve": Lib.curve([[0.0, 0.25], [0.13, 1.0], [1.0, 0.75]]),
		"lifetime_randomness": 0.3,
		"color_ramp": Lib.ramp([
			[0.0, Color(10, 8.5, 5.5, 1)],
			[0.1, Color(8, 4.2, 0.9, 1)],
			[0.28, Color(5, 1.3, 0.15, 1)],
			[0.48, Color(1.4, 0.28, 0.06, 1)],
			[0.68, Color(0.22, 0.17, 0.15, 0.75)],
			[1.0, Color(0.2, 0.18, 0.17, 0.0)],
		]),
	}), 24 if full else 11, 1.25))

	# 火花：進む向きに伸びた筋が、重力で落ちながら細って消える
	emit(Lib.particles(Lib.streak_mesh(), Lib.material("spark"), Lib.process({
		"direction": Vector3.UP,
		"spread": 100.0,
		"initial_velocity_min": 3.0 * u,
		"initial_velocity_max": 7.5 * u,
		"gravity": Vector3(0, -11, 0),
		"damping_min": 1.5,
		"damping_max": 3.0,
		"particle_flag_align_y": true,
		"scale_min": 0.18 * u,
		"scale_max": 0.45 * u,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.6, 0.7], [1.0, 0.0]]),
		"lifetime_randomness": 0.5,
		"color_ramp": Lib.ramp([[0.0, Color(10, 8, 4)], [0.4, Color(8, 3, 0.5)], [1.0, Color(3, 0.4, 0.05)]]),
	}), 46 if full else 16, 0.95))

	# 衝撃波：カメラに向く輪（空気）と、地面を走る輪
	var air := sprite(1, Color(3, 2.6, 2.2), u)
	over(0.0, 0.28, func(k: float) -> void:
		air.scale = Vector3.ONE * u * lerpf(0.3, 3.6, ease_out(k))
		param(air, "ring_width", lerpf(0.16, 0.03, k))
		param(air, "color", Color(3, 2.6, 2.2, 1.0 - k))
	)
	at(0.29, air.queue_free)
	if grounded:
		var wave := sprite(1, Color(4, 3, 2), u, false)
		wave.position = ground + Vector3(0, 0.06, 0)
		wave.rotation.x = -PI / 2.0
		over(0.02, 0.5, func(k: float) -> void:
			wave.scale = Vector3.ONE * u * lerpf(0.3, 4.8, ease_out(k))
			param(wave, "ring_width", lerpf(0.3, 0.05, k))
			param(wave, "color", Color(4, 3, 2, pow(1.0 - k, 1.5)))
		)
		at(0.53, wave.queue_free)
		# 土煙：地面に沿って外へ押し出され、すぐに減速する
		var dust_mat := Lib.material("cloud", {"dissolve_texture": cells, "shadow_tint": Vector3(0.55, 0.5, 0.55)})
		emit(Lib.particles(Lib.cloud_mesh(2), dust_mat, Lib.process({
			"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_RING,
			"emission_ring_axis": Vector3.UP,
			"emission_ring_height": 0.0,
			"emission_ring_radius": 0.5 * u,
			"emission_ring_inner_radius": 0.3 * u,
			"direction": Vector3.UP,
			"spread": 20.0,
			"initial_velocity_min": 0.1 * u,
			"initial_velocity_max": 0.4 * u,
			"gravity": Vector3.ZERO,
			"radial_velocity_min": 3.5 * u,
			"radial_velocity_max": 6.0 * u,
			"radial_velocity_curve": Lib.curve([[0.0, 1.0], [0.35, 0.22], [1.0, 0.0]]),
			"angle_min": -180.0,
			"angle_max": 180.0,
			"particle_flag_rotate_y": true,
			"scale_min": 0.22 * u,
			"scale_max": 0.42 * u,
			"scale_curve": Lib.curve([[0.0, 0.3], [0.25, 1.0], [1.0, 0.8]]),
			"color_ramp": Lib.ramp([[0.0, Color(0.42, 0.3, 0.2, 1)], [0.5, Color(0.3, 0.25, 0.2, 0.9)], [1.0, Color(0.28, 0.25, 0.22, 0)]]),
		}), 22 if full else 10, 1.3), 0.03, ground + Vector3(0, 0.09 * u, 0))

	# 黒煙：火球に少し遅れて立ちのぼり、長く残る
	var smoke_mat := Lib.material("cloud", {"dissolve_texture": cells, "texture_scale": Vector2(1.5, 1.0)})
	var smoke := Lib.particles(Lib.cloud_mesh(1), smoke_mat, Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.45 * u,
		"direction": Vector3.UP,
		"spread": 40.0,
		"initial_velocity_min": 0.6 * u,
		"initial_velocity_max": 1.4 * u,
		"damping_min": 0.5 * u,
		"damping_max": 1.0 * u,
		"gravity": Vector3(0, 0.2 * u, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"angular_velocity_min": -25.0,
		"angular_velocity_max": 25.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.6 * u,
		"scale_max": 1.0 * u,
		"scale_curve": Lib.curve([[0.0, 0.35], [0.3, 0.85], [1.0, 1.0]]),
		"lifetime_randomness": 0.2,
		"color_ramp": Lib.ramp([
			[0.0, Color(3.0, 0.7, 0.12, 1)],
			[0.14, Color(0.5, 0.2, 0.12, 1)],
			[0.3, Color(0.2, 0.18, 0.17, 1)],
			[0.6, Color(0.3, 0.29, 0.28, 0.85)],
			[1.0, Color(0.36, 0.35, 0.34, 0)],
		]),
	}), 14 if full else 6, 2.6 if full else 1.8)
	smoke.explosiveness = 0.8
	emit(smoke, 0.1)

	if not full:
		return
	# 破片：黒い塊が放物線で飛ぶ
	emit(Lib.particles(Lib.cloud_mesh(2), Lib.material("cloud", {"dissolve_texture": cells}), Lib.process({
		"direction": Vector3.UP,
		"spread": 70.0,
		"initial_velocity_min": 2.5 * u,
		"initial_velocity_max": 5.0 * u,
		"gravity": Vector3(0, -14, 0),
		"angle_min": -180.0,
		"angle_max": 180.0,
		"angular_velocity_min": -500.0,
		"angular_velocity_max": 500.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.05 * u,
		"scale_max": 0.11 * u,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]]),
		"color": Color(0.07, 0.06, 0.055),
	}), 14, 1.3))
	# 残り火：地面で少しのあいだ燃える
	if grounded:
		for i in 3:
			var away := Vector3.RIGHT.rotated(Vector3.UP, TAU * (i + randf()) / 3.0) * u * randf_range(0.3, 0.75)
			at(0.25 + i * 0.07, func() -> void:
				var f: Node3D = Fire.new()
				add_child(f)
				f.position = ground + away
				f.start(u * randf_range(0.3, 0.45), 1.5, Color(4.0, 0.8, 0.0))
			)


func start_fuse(seconds: float, size: float) -> void:
	life = seconds + 0.5
	var sparks := emit(Lib.particles(Lib.streak_mesh(), Lib.material("spark"), Lib.process({
		"direction": Vector3.UP,
		"spread": 38.0,
		"initial_velocity_min": 2.0 * size,
		"initial_velocity_max": 4.8 * size,
		"gravity": Vector3(0, -9, 0),
		"particle_flag_align_y": true,
		"scale_min": 0.1 * size,
		"scale_max": 0.22 * size,
		"scale_curve": Lib.curve([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": Lib.ramp([[0.0, Color(10, 8, 4)], [1.0, Color(6, 1.5, 0.2)]]),
	}), 26, 0.38, false))
	at(seconds, func() -> void: sparks.emitting = false)
	var glow := sprite(0, Color(8, 3, 0.5), 0.1)
	var light := lamp(Color(1.0, 0.6, 0.25), 5.0 * size)
	over(0.0, seconds, func(k: float) -> void:
		var beat := 0.8 + 0.2 * sin(age * 60.0)
		glow.scale = Vector3.ONE * size * lerpf(0.3, 1.3, k * k) * beat
		light.light_energy = 6.0 * size * k * k * beat
	)
	at(seconds, func() -> void:
		glow.queue_free()
		light.queue_free()
	)
