extends "res://vfx/vfx_base.gd"
# 様式化した炎。揺れる炎の板 ＋ 立ちのぼる煙 ＋ 火の粉（チュートリアル「Stylized Fire」の構成）。
# duration が 0 以下なら extinguish() を呼ぶまで燃え続ける。

var _size := 1.0
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _smoke: GPUParticles3D
var _embers: GPUParticles3D
var _burn := 0.0      # 0〜1。点火と消火でなめらかに変える
var _dying := false
var _base: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, duration: float = -1.0, color: Color = Color(4.0, 0.8, 0.0)) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, duration, color)
	return fx


func start(size: float, duration: float, color: Color) -> void:
	_size = size
	life = 0.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.5)
	mesh.center_offset = Vector3(0, 0.75, 0)
	# 外側の炎と、少し速く揺れる内側の炎を重ねる
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = Lib.material("fire", {
			"flame_texture": Lib.flame_texture(),
			"distortion_texture": Lib.noise("soft"),
			"color": color if i == 0 else Color(color.r * 1.5, color.g * 2.6, color.b + 0.3),
			"speed": Vector2(0.0, 1.0) if i == 0 else Vector2(0.12, 1.5),
			"phase": i * 0.37,
		})
		mi.sorting_offset = 2.0 + i     # 煙より手前に描く
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_flames.append(mi)
	_base = sprite(0, Color(color.r, color.g, color.b, 0.45), size * 1.5)
	_base.position.y = size * 0.3
	_light = lamp(Color(1.0, 0.55, 0.2), size * 5.0)
	_light.position.y = size * 0.6
	var grey := Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "texture_scale": Vector2(1.5, 1.0)})
	_smoke = emit(Lib.particles(Lib.cloud_mesh(1), grey, Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.2 * size,
		"direction": Vector3.UP,
		"spread": 12.0,
		"initial_velocity_min": 0.8 * size,
		"initial_velocity_max": 1.4 * size,
		"gravity": Vector3.ZERO,
		"damping_min": 0.2 * size,
		"damping_max": 0.4 * size,
		"angle_min": -180.0,
		"angle_max": 180.0,
		"angular_velocity_min": -60.0,
		"angular_velocity_max": 60.0,
		"particle_flag_rotate_y": true,
		"scale_min": 0.28 * size,
		"scale_max": 0.5 * size,
		"scale_curve": Lib.curve([[0.0, 0.5], [0.25, 1.0], [1.0, 0.45]]),
		"color_ramp": Lib.ramp([[0.0, Color(0.5, 0.2, 0.08, 0.0)], [0.2, Color(0.16, 0.14, 0.13, 1.0)], [0.6, Color(0.2, 0.2, 0.21, 0.8)], [1.0, Color(0.24, 0.24, 0.26, 0.0)]]),
	}), 10, 1.6, false), 0.0, Vector3(0, size * 1.1, 0))
	_embers = emit(Lib.particles(Lib.quad(), Lib.material("glow"), Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.25 * size,
		"direction": Vector3.UP,
		"spread": 25.0,
		"initial_velocity_min": 1.0 * size,
		"initial_velocity_max": 2.2 * size,
		"gravity": Vector3(0, 1.0, 0),
		"turbulence_enabled": true,
		"turbulence_noise_strength": 0.6,
		"turbulence_influence_min": 0.05,
		"turbulence_influence_max": 0.15,
		"scale_min": 0.05 * size,
		"scale_max": 0.1 * size,
		"scale_curve": Lib.curve([[0.0, 1.0], [0.7, 0.8], [1.0, 0.0]]),
		"color_ramp": Lib.ramp([[0.0, Color(9, 5, 1.2, 1)], [0.6, Color(7, 1.6, 0.15, 1)], [1.0, Color(3, 0.3, 0.02, 0)]]),
	}), 12, 1.3, false), 0.0, Vector3(0, size * 0.5, 0))
	over(0.0, 0.18, func(k: float) -> void: _burn = ease_out(k))
	if duration > 0.0:
		at(maxf(duration - 0.3, 0.0), extinguish)


# 火を消す。炎をしぼませ、出ている煙が消えるのを待って片付ける。
func extinguish() -> void:
	if _dying:
		return
	_dying = true
	_smoke.emitting = false
	_embers.emitting = false
	over(age, 0.3, func(k: float) -> void: _burn = 1.0 - k)
	life = age + 1.9


func _tick(_delta: float) -> void:
	for i in _flames.size():
		var s := maxf(_size * _burn * (1.0 if i == 0 else 0.62), 0.001)
		_flames[i].scale = Vector3(s * (1.0 + 0.05 * sin(age * 17.0 + i)), s * (1.0 + 0.08 * sin(age * 23.0 + i * 2.0)), s)
		_flames[i].visible = _burn > 0.01
	_base.scale = Vector3.ONE * maxf(_size * 1.5 * _burn, 0.001)
	_light.light_energy = 2.5 * _size * _burn * (0.85 + 0.15 * sin(age * 31.0) * sin(age * 13.0))
