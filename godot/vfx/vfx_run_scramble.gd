extends Node3D
# 脚ぐるぐる ＋ 蹴り上げの土ぼこり。昔のアニメの「足が車輪になって土煙を上げて走る」。

const Wheel := preload("res://vfx/vfx_run_wheel.gd")
const Dust := preload("res://vfx/vfx_run_dust.gd")

var runner: Node3D


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	for fx: Node3D in [Wheel.new(), Dust.new()]:
		get_parent().add_child(fx)
		fx.global_position = global_position
		fx.runner = runner
		fx.burst(direction, size, trail)
	queue_free()
