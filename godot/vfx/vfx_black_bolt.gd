extends "res://vfx/vfx_base.gd"
# 黒い稲妻の試作（ユーザーの案）：層を重ねた筒を、稲妻の折れ線に沿って節ごとに並べ、少しずつびりびり震わせる。
# 筒は竜巻や噴流と同じ「すき間だらけの殻を重ねる」作り。外は黒、内へ赤、芯は白熱。模様は先端へ向かって流れる。
#   0コマ目    白い閃光 ／ 1〜2コマ目 画面ごと白黒反転
#   稲妻       主役1本と脇2本。根元から節がひとつずつ伸び、15コマ/秒で折れ点が小さく震える。最後は先端の節から消える

const FPS := 15.0
const SEGMENTS := 7
const TONES := [Vector3(0.0, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), Vector3(1.2, 0.04, 0.02), Vector3(6.0, 0.4, 0.2), Vector3(10.0, 6.0, 5.0)]
const RATIOS := [1.0, 0.6, 0.28]

var _size := 1.0
var _dir := Vector3.RIGHT
var _frame := -1
var _bolts: Array = []
var _flash: MeshInstance3D
var _flip: MeshInstance3D
var _light: OmniLight3D
static var _meshes: Array = []


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, direction: Vector3 = Vector3.RIGHT) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, direction)
	return fx


func start(size: float, direction: Vector3) -> void:
	_size = size
	_dir = Vector3(direction.x, 0, direction.z).normalized()
	life = 1.45
	if _meshes.is_empty():
		for ratio: float in RATIOS:
			_meshes.append(Lib.tube_mesh([[0.0, 0.75 * ratio], [0.5, 1.0 * ratio], [1.0, 0.75 * ratio]], 20, 10))
	_light = lamp(Color(1.0, 0.12, 0.08), 12.0 * size)
	_flash = sprite(2, Color(10, 10, 10), size)
	param(_flash, "toward_camera", size)
	_flip = MeshInstance3D.new()
	_flip.mesh = Lib.quad()
	var flip_mat := Lib.material("invert")
	flip_mat.render_priority = -100
	_flip.material_override = flip_mat
	_flip.scale = Vector3.ONE * 120.0
	_flip.extra_cull_margin = 1000.0
	_flip.visible = false
	add_child(_flip)
	var across := _dir.cross(Vector3.UP).normalized()
	# 主役1本・脇2本。向きを大きく離して重ならせない。[向き, 太さ, 長さ, 遅れ]
	var plan: Array = [[_dir + Vector3.UP * 0.55, 1.0, 6.4, 0.0], [-_dir * 0.9 + Vector3.UP * 0.25 + across * 0.3, 0.5, 4.2, 0.07], [-_dir * 0.15 + Vector3.UP - across * 0.5, 0.36, 3.2, 0.13]]
	for item: Array in plan:
		var out := (item[0] as Vector3).normalized()
		var a := out.cross(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized()
		var kinks: Array = []
		# 節の長さは長短を混ぜる（等間隔のぎざぎざにしない）
		var cuts: Array = []
		var total := 0.0
		for j in SEGMENTS:
			total += [1.6, 0.5, 1.2, 0.4, 1.0, 0.6, 0.9][(j + _bolts.size() * 2) % 7]
			cuts.append(total)
		for j in SEGMENTS - 1:
			kinks.append([(1.0 if j % 2 == 0 else -1.0) * randf_range(0.5, 1.0), randf_range(-0.4, 0.4), float(cuts[j]) / total])
		var nodes: Array = []
		for j in SEGMENTS:
			var seg := Node3D.new()
			add_child(seg)
			for i in 3:
				var layer := Lib.wisp_layer(_meshes[i], i, 3, TONES[i], TONES[i + 1] if i < 2 else TONES[4], {
					"tip": 0.0, "top_thin": 0.0, "sway": 0.0, "ripple": 0.22, "cut": [0.64, 0.6, 0.5][i],
					"scale_a": Vector2(1.0, 0.5), "shear": 0.5 if i % 2 == 0 else -0.5,
					"speed_a": Vector2(0.4 + 0.3 * i, 2.4 + 0.8 * i), "speed_b": Vector2(-0.3, 3.2), "seed": j * 1.3 + i * 0.37,
				})
				seg.add_child(layer)
			nodes.append(seg)
		_bolts.append({"way": out, "a": a, "b": out.cross(a).normalized(), "length": float(item[2]) * size, "weight": float(item[1]), "delay": float(item[3]), "kinks": kinks, "nodes": nodes})
	_step(0.0)


func _tick(_delta: float) -> void:
	# 模様は毎フレーム流す
	for bolt: Dictionary in _bolts:
		for seg: Node3D in bolt["nodes"]:
			for layer: MeshInstance3D in seg.get_children():
				param(layer, "phase", age)
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_step(frame / FPS)


# 折れ点は15コマ/秒で小さく震える（形は保ち、びりびり揺れるだけ）
func _step(t: float) -> void:
	var f := int(roundf(t * FPS))
	var since := t - 1.0 / FPS
	_flash.visible = f == 0
	_flash.scale = Vector3.ONE * _size * 3.2
	_flip.visible = f == 1 or f == 2
	_light.light_energy = 14.0 * _size * maxf(0.0, 1.0 - t / 1.0)
	for bolt: Dictionary in _bolts:
		var way: Vector3 = bolt["way"]
		var reach: float = bolt["length"]
		var points: Array[Vector3] = [Vector3.ZERO]
		for j in SEGMENTS - 1:
			var k: Array = bolt["kinks"][j]
			var frac := float(k[2])
			var shiver := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.035 * reach
			points.append(way * reach * frac + ((bolt["a"] as Vector3) * float(k[0]) + (bolt["b"] as Vector3) * float(k[1])) * 0.1 * reach + shiver)
		points.append(way * reach + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.05 * reach)
		# 根元から節がひとつずつ伸び、最後は先端の節から消える
		var mine: float = since - float(bolt["delay"])
		var grown := clampf(mine / 0.12, 0.0, 1.0) * SEGMENTS
		var kept := (1.0 - smoothstep(0.5 + 0.25 * float(bolt["weight"]), 0.95, since)) * SEGMENTS
		for j in SEGMENTS:
			var seg: Node3D = bolt["nodes"][j]
			seg.visible = mine >= 0.0 and j < grown and j < kept
			if not seg.visible:
				continue
			var from := points[j]
			var span := points[j + 1] - from
			var up := span.normalized()
			var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
			var thick := 0.24 * _size * float(bolt["weight"]) * (1.0 - 0.8 * j / SEGMENTS) * (0.75 + 0.5 * randf())
			seg.transform = Transform3D(Basis(side * thick, up * span.length() * 1.25, side.cross(up) * thick), from - span * 0.1)
