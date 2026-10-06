extends "res://scripts/prop.gd"
# 架空の効果機。合図から少し溜めて「爆発」を出す。位置と向きで現場を押し出す。

const MAX_CHARGES := 2
const FUSE_SEC := 0.8
const BURST_UP := 1.3      # 爆炎の中心の高さ

var charges := MAX_CHARGES
var fuse := -1.0
var _shake := 0.0


func build() -> void:
	kind = "fx"
	label = "効果機（爆発）"
	mass = 18.0
	center = Vector3(0, 0.3, 0)
	half = Vector3(0.33, 0.32, 0.24)
	hold_min = 1.2
	visual = (load("res://assets/props/fx_box.glb") as PackedScene).instantiate()
	add_child(visual)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.66, 0.5, 0.36)
	cs.shape = b
	cs.position = Vector3(0, 0.27, 0)
	add_child(cs)


func burst_point() -> Vector3:
	return global_position + Vector3(0, BURST_UP, 0)


# 全員の画面で、溜めの揺れを見せる（予兆）
func show_fuse() -> void:
	_shake = FUSE_SEC


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		var k := 1.0 - _shake / FUSE_SEC
		visual.position = Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 0.03 * (0.3 + k)
		visual.scale = Vector3.ONE * (1.0 + 0.12 * k)
	else:
		visual.position = Vector3.ZERO
		visual.scale = Vector3.ONE


func _host_tick(delta: float) -> void:
	if fuse >= 0.0:
		fuse -= delta
		if fuse < 0.0:
			fuse = -1.0
			game.host_burst(self)


func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed, charges]


func _apply_extra(s: Array) -> void:
	if s.size() < 4:
		return
	charges = int(s[3])
