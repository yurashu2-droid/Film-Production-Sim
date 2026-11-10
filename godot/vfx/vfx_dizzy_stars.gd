extends Node3D
## のびている人の頭の上を回る星（漫画の「目を回す」）。紙を切り抜いたような、ふちのある黄色い星が3つ。光らせない。
## 参考：『トムとジェリー』『ルーニー・テューンズ』の、頭をぶつけた時に頭の上を回る星。コマ打ち（12コマ/秒）で回す。
##   始まり：頭から、ぽんと飛び出して、輪に乗る（1つずつ、少し遅れて。行きすぎてから戻る）
##   途中：かたむいた輪の上を回る。輪のかたむきは、ゆっくり向きを変える。星は、大きさも並ぶ間隔も不揃い
##   終わり：回す力が切れて、そのときの向きへ飛び、床へ落ちる（縮めない・薄めない。床に着いた星から、いなくなる）
## 使い方：
##   var stars := Stars.new(); add_child(stars); stars.start(1 << 11)      # 描く層（制作班にだけ見せるなら、映画に映らない層）
##   stars.follow(頭の上の場所)                                              # 毎コマ
##   stars.release(床の高さ)                                                 # 起き上がる時。落ち切ったら、自分で片付く
const SHADER := preload("res://vfx/shaders/dizzy_star.gdshader")
const FPS := 12.0
const SPEED := 4.6               # 輪を回る速さ（ラジアン/秒）
const TILT := 0.38               # 輪のかたむき（ラジアン）
const SWAY := 0.55               # かたむきの向きが変わる速さ（ラジアン/秒）
const BORN := 0.24               # 飛び出して輪に乗るまで（秒）
const STAGGER := 0.07            # 星ごとの遅れ（秒）
const FALL := 9.0                # 落ちる速さの増え方（m/秒²）
# 星：[大きさ(m), 輪の半径(m), はじめの角度, 高さのずれ(m), 自分で回る速さ]
const STARS := [
	[0.32, 0.46, 0.0, 0.0, 2.6],
	[0.23, 0.42, 2.25, 0.05, -3.4],
	[0.17, 0.48, 4.2, -0.04, 4.4],
]

var _t := 0.0
var _centre := Vector3.ZERO
var _nodes: Array = []           # 星の板
var _mats: Array = []
var _released := false
var _floor := 0.0
var _fly: Array = []             # 落ちている星 [場所, 速さ, 回り]


func start(layers: int) -> void:
	top_level = true
	for row: Array in STARS:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var star := MeshInstance3D.new()
		star.mesh = quad
		star.material_override = mat
		star.layers = layers
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.scale = Vector3.ONE * float(row[0])
		star.extra_cull_margin = 1.0
		star.visible = false
		add_child(star)
		_nodes.append(star)
		_mats.append(mat)


func follow(at: Vector3) -> void:
	_centre = at


# 輪の上の場所（頭の上の場所からのずれ）と、進む向き
func _on_ring(index: int, now: float) -> Array:
	var row: Array = STARS[index]
	var angle: float = float(row[2]) + SPEED * now
	var lean := Basis(Vector3.UP, SWAY * now) * Basis(Vector3.RIGHT, TILT)
	var out := Vector3(cos(angle), 0.0, sin(angle))
	var along := Vector3(-sin(angle), 0.0, cos(angle))
	return [lean * (out * float(row[1])) + Vector3(0.0, float(row[3]), 0.0), lean * along, lean * out]


func release(floor_y: float) -> void:
	if _released:
		return
	_released = true
	_floor = floor_y
	var now := floorf(_t * FPS) / FPS
	for i in STARS.size():
		var ring := _on_ring(i, now)
		var speed: float = SPEED * float(STARS[i][1])
		# そのときの進む向きへ飛ぶ。少し外へ、少し上へ（星ごとに違う）
		var push: Vector3 = (ring[1] as Vector3) * speed + (ring[2] as Vector3) * (0.5 + 0.25 * float(i)) + Vector3.UP * (1.5 + 0.5 * float(i))
		_fly.append([_centre + (ring[0] as Vector3), push, float(STARS[i][4]) * now])


func _process(delta: float) -> void:
	_t += delta
	var now := floorf(_t * FPS) / FPS            # コマ打ち
	if not _released:
		for i in STARS.size():
			var born := clampf((now - STAGGER * float(i)) / BORN, 0.0, 1.0)
			var star: MeshInstance3D = _nodes[i]
			star.visible = born > 0.0
			if not star.visible:
				continue
			# 頭から飛び出す：行きすぎてから、輪に戻る
			var reach := 1.0 + 2.2 * pow(born - 1.0, 3.0) + 1.2 * pow(born - 1.0, 2.0)
			var ring := _on_ring(i, now)
			star.global_position = _centre + (ring[0] as Vector3) * reach + Vector3(0.0, -0.3 * (1.0 - born), 0.0)
			(_mats[i] as ShaderMaterial).set_shader_parameter("spin", float(STARS[i][4]) * now)
		return
	var left := 0
	for i in _fly.size():
		var star: MeshInstance3D = _nodes[i]
		if not star.visible:
			continue
		var row: Array = _fly[i]
		var speed: Vector3 = row[1]
		speed.y -= FALL * delta
		var at: Vector3 = (row[0] as Vector3) + speed * delta
		var turn: float = float(row[2]) + float(STARS[i][4]) * 2.2 * delta        # 落ちる間は、速く回る
		_fly[i] = [at, speed, turn]
		star.global_position = at
		(_mats[i] as ShaderMaterial).set_shader_parameter("spin", turn)
		if at.y <= _floor + float(STARS[i][0]) * 0.3:
			star.visible = false                 # 床に着いた
		else:
			left += 1
	if left == 0:
		queue_free()
