extends Node3D
# スミア × 雷。体の後ろへ伸びるスミアの先が、ぎざぎざの雷の光になる。
# スミア（雷の色・折れ線つき）と、オーラと帯を外した雷（放電・火花・輪・稲妻だけ）を同時に出す。

const Smear := preload("res://vfx/vfx_run_smear.gd")
const Thunder := preload("res://vfx/vfx_run_thunder.gd")

var runner: Node3D


func burst(direction: Vector3, size: float = 1.0, trail: bool = false) -> void:
	var smear: Node3D = Smear.new()
	smear.electric = true
	var thunder: Node3D = Thunder.new()
	thunder.bare = true
	for fx: Node3D in [smear, thunder]:
		get_parent().add_child(fx)
		fx.global_position = global_position
		fx.runner = runner
		fx.burst(direction, size, trail)
	queue_free()
