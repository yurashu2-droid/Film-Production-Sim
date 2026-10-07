extends "res://vfx/vfx_base.gd"
# 様式化した煙の柱（チュートリアル「Stylized Smoke」の構成）。
# 雲の形のメッシュを粒子で流し、明るい色から暗い色へ移しながら、最後は穴が開いて消える。
# flat = true で影の段をやめた簡略版。duration が 0 以下なら stop() を呼ぶまで出続ける。

const LIFETIME := 1.3

var _smoke: GPUParticles3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, duration: float = -1.0, flat: bool = false, tint: Color = Color(1, 1, 1)) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, duration, flat, tint)
	return fx


func start(size: float, duration: float, flat: bool, tint: Color) -> void:
	life = 0.0
	var mat := Lib.material("cloud", {"dissolve_texture": Lib.noise("cells"), "texture_scale": Vector2(1.5, 1.0), "flat_style": flat})
	_smoke = emit(Lib.particles(Lib.cloud_mesh(1), mat, Lib.process({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.5 * size,
		"direction": Vector3(-0.08, 1.0, 0.0),
		"spread": 0.0,
		"initial_velocity_min": 3.0 * size,
		"initial_velocity_max": 4.0 * size,
		"gravity": Vector3.ZERO,
		"angle_min": -180.0,
		"angle_max": 180.0,
		"particle_flag_rotate_y": true,
		"scale_min": 1.0 * size,
		"scale_max": 1.2 * size,
		"scale_curve": Lib.curve([[0.0, 0.12], [0.4, 0.8], [1.0, 1.0]]),
		# 出だしは明るく、終わりは暗く。アルファは「どれだけ残っているか」
		"color_ramp": Lib.ramp([
			[0.0, Color(0.95, 0.93, 0.9, 1.0) * tint],
			[0.45, Color(0.6, 0.6, 0.66, 1.0) * tint],
			[0.75, Color(0.32, 0.33, 0.4, 0.6) * tint],
			[1.0, Color(0.2, 0.2, 0.27, 0.0) * tint],
		]),
	}), 20, LIFETIME, false))
	if duration > 0.0:
		at(duration, stop)


func stop() -> void:
	_smoke.emitting = false
	life = age + LIFETIME + 0.1
