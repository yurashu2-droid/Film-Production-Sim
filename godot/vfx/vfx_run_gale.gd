extends Node3D
# スミア ＋ 風の線。体が自分の色のまま後ろへ伸び、そのまわりを光らない白い曲線が流れる。

const Smear := preload("res://vfx/vfx_run_smear.gd")
const Wind := preload("res://vfx/vfx_run_wind.gd")

var runner: Node3D


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	for fx: Node3D in [Smear.new(), Wind.new()]:
		get_parent().add_child(fx)
		fx.global_position = global_position
		fx.runner = runner
		fx.burst(direction, size, trail)
	queue_free()
