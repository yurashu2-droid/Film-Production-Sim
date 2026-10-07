extends Node3D
# Kenney Smoke Particles (CC0) の画像を使う、蹴り出しの土ぼこり。
# 画像は原本のまま。物理刻みで動かし、Labの停止・コマ送りにも追従する。
const LIFETIME := 0.68
const TEXTURES := ["res://assets/vfx/kenney_smoke/whitePuff00.png", "res://assets/vfx/kenney_smoke/whitePuff06.png", "res://assets/vfx/kenney_smoke/whitePuff12.png"]
const ORIGINS: Array[Vector3] = [Vector3(-0.15, 0.10, 0.12), Vector3(0.15, 0.11, 0.15), Vector3(-0.26, 0.18, 0.34), Vector3(0.23, 0.20, 0.38), Vector3(-0.13, 0.29, 0.58), Vector3(0.13, 0.30, 0.65)]
const DIAMETERS: Array[float] = [0.47, 0.42, 0.50, 0.45, 0.33, 0.34]
var age := 0.0
var _size := 1.0
var _puffs: Array[Sprite3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("dash_dust")

func burst(direction: Vector3, size: float = 1.0) -> void:
	_size = size
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	if flat.length_squared() < 0.01:
		flat = Vector3.FORWARD
	rotation.y = atan2(-flat.x, -flat.z)
	for i in ORIGINS.size():
		var puff := Sprite3D.new()
		puff.texture = load(TEXTURES[i % TEXTURES.size()]) as Texture2D
		puff.pixel_size = 1.0 / puff.texture.get_width()
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		_puffs.append(puff)
	_update_puffs()

func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
	else:
		_update_puffs()

func _update_puffs() -> void:
	for i in _puffs.size():
		var puff := _puffs[i]
		var t := maxf(0.0, age - i * 0.012)
		var grow := 1.0 - pow(1.0 - clampf(t / 0.11, 0.0, 1.0), 3.0)
		var shrink := 1.0 - smoothstep(0.25, 0.60, t)
		var diameter := DIAMETERS[i] * grow * shrink * _size
		var side := -1.0 if i % 2 == 0 else 1.0
		puff.position = (ORIGINS[i] + Vector3(side * t * 0.30, t * 0.25, t * (0.64 + i * 0.035))) * _size
		var aspect := float(puff.texture.get_height()) / puff.texture.get_width()
		puff.position.y = maxf(puff.position.y, diameter * aspect * 0.48)
		puff.scale = Vector3.ONE * maxf(diameter, 0.0001)
		# 輪郭を縮めて消す。淡い縁は原画の透明度を活かす。
		puff.modulate = Color(0.94, 0.84, 0.65, 0.90 * (1.0 - smoothstep(0.20, 0.63, t)))
