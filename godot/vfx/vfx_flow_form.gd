extends "res://vfx/vfx_base.gd"
# 黒雷の質感（薄い殻を三層重ね、外は暗く内へ明るく。跳ねながら流れ、先から消える）を、雷以外の形に使う。
# 色は作る側で選んだ（墨藤・琥珀・若苔・灰青・桜紅）。形は五つ：
#   whip   鞭：根元から三本の帯がしなり、先へ細る
#   orb    霊気の球：根元から八本の糸が球の表面へ伸び、糸がゆっくり回る
#   ring   輪：地面に寝た輪が広がり、たわみながら流れる。切れ目はない
#   jet    噴流：根元から立ち上がり、ねじれながら上へ抜ける
#   star   星：中心から八本の帯が放射し、先でしなって消える
# 作り方（共通）：Lib.path_tube の一本の筒（節を並べない）。wisp の三層。経路は15コマ/秒で作り直す（跳ね）。消えは先端から根元へ。

const FPS := 15.0
# [外の色, 内の色, cut, inner, 半径の比] を三層、外から順に。作る側が選んだ色
const PALETTES := {
	"whip": [
		[Vector3(0.10, 0.02, 0.22), Vector3(0.5, 0.12, 0.9), 0.8, 0.6, 1.0],
		[Vector3(0.9, 0.2, 1.6), Vector3(2.6, 0.9, 3.2), 0.6, 0.35, 0.6],
		[Vector3(2.6, 2.8, 3.0), Vector3(6.0, 6.0, 6.0), 0.5, 0.14, 0.25],
	],
	"orb": [
		[Vector3(0.25, 0.10, 0.02), Vector3(0.8, 0.45, 0.10), 0.74, 0.6, 1.0],
		[Vector3(1.6, 0.8, 0.2), Vector3(3.5, 2.2, 0.6), 0.6, 0.35, 0.6],
		[Vector3(3.0, 3.0, 2.6), Vector3(6.0, 5.8, 5.4), 0.5, 0.14, 0.25],
	],
	"ring": [
		[Vector3(0.02, 0.12, 0.10), Vector3(0.10, 0.50, 0.45), 0.74, 0.6, 1.0],
		[Vector3(0.2, 1.2, 1.0), Vector3(0.8, 3.0, 2.6), 0.6, 0.35, 0.6],
		[Vector3(2.2, 3.0, 2.8), Vector3(5.0, 6.0, 5.6), 0.5, 0.14, 0.25],
	],
	"jet": [
		[Vector3(0.06, 0.06, 0.12), Vector3(0.25, 0.30, 0.60), 0.74, 0.6, 1.0],
		[Vector3(0.6, 0.9, 1.8), Vector3(1.8, 2.6, 3.6), 0.6, 0.35, 0.6],
		[Vector3(3.0, 3.2, 3.4), Vector3(6.0, 6.0, 6.0), 0.5, 0.14, 0.25],
	],
	"star": [
		[Vector3(0.20, 0.02, 0.05), Vector3(0.7, 0.10, 0.25), 0.74, 0.6, 1.0],
		[Vector3(1.8, 0.3, 0.8), Vector3(3.4, 1.2, 2.2), 0.6, 0.35, 0.6],
		[Vector3(2.4, 1.1, 1.7), Vector3(4.0, 2.4, 3.2), 0.5, 0.14, 0.4],
	],
}
const TIMING := {
	"whip": {"life": 3.6, "grow": 0.3, "hold": 1.6, "fade": 1.0},
	"orb": {"life": 3.3, "grow": 0.5, "hold": 1.0, "fade": 0.8},
	"ring": {"life": 3.5, "grow": 0.6, "hold": 1.2, "fade": 1.0},
	"jet": {"life": 3.5, "grow": 0.5, "hold": 1.2, "fade": 0.8},
	"star": {"life": 3.0, "grow": 0.35, "hold": 0.6, "fade": 0.6},
}

var _kind := "whip"
var _size := 1.0
var _timing: Dictionary = {}
var _bolts: Array = []        # [{"kind", "seed", "root", "dir", "reach", "delay", "radius", "phase0", "layers"}]
var _frame := -1
var _light: OmniLight3D
var _shells: Array = []        # 霊気の球の殻（外 → 芯）。糸は使わない（REVIEW：球は殻を重ねた球面）


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, kind: String = "whip") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, kind)
	return fx


func start(size: float, kind: String) -> void:
	_size = size
	_kind = kind
	_timing = TIMING[kind]
	if kind == "orb":
		position.y = 1.2 * size
	life = float(_timing["life"])
	if kind == "orb":
		_make_shells()
	else:
		_make_bolts()
	var mid: Array = PALETTES[kind][1]
	var glow: Vector3 = mid[1]
	_light = lamp(Color(minf(glow.x, 1.0), minf(glow.y, 1.0), minf(glow.z, 1.0)), 8.0 * size)
	_light.position.y = 1.0 * size
	_pose(0.0)


# 型ごとに、本数・向き・長さ・出る遅れ・太さを決める
func _make_bolts() -> void:
	match _kind:
		"whip":
			for i in 3:
				_add_bolt(i, Vector3.ZERO, Vector3.UP, (3.2 + 0.3 * float(i)) * _size, 0.05 * float(i), 0.5, 2.1 * float(i))
		"orb":
			for k in 12:
				var y := 1.0 - 2.0 * (float(k) + 0.5) / 12.0
				var r := sqrt(maxf(0.0, 1.0 - y * y))
				var th := float(k) * 2.39996
				_add_bolt(k, Vector3.ZERO, Vector3(cos(th) * r, y, sin(th) * r), 2.2 * _size, 0.05 * float(k), 0.3, th)
		"ring":
			for i in 2:
				_add_bolt(i, Vector3.ZERO, Vector3.UP, (1.9 - 0.5 * float(i)) * _size, 0.1 * float(i), 0.22 - 0.08 * float(i), 1.3 * float(i))
		"jet":
			for i in 3:
				_add_bolt(i, Vector3(float(i - 1) * 0.35 * _size, 0.0, 0.0), Vector3.UP, (3.4 + 0.3 * float(i)) * _size, 0.08 * float(i), 0.45, 1.7 * float(i))
		_:
			for k in 8:
				var a := TAU * float(k) / 8.0
				_add_bolt(k, Vector3.ZERO, Vector3(cos(a), sin(a), 0.0), 2.1 * _size, 0.03 * float(k), 0.45, a)


func _add_bolt(index: int, root: Vector3, dir: Vector3, reach: float, delay: float, radius: float, phase0: float) -> void:
	var layers: Array = []
	for k in 3:
		var row: Array = PALETTES[_kind][k]
		var layer := Lib.wisp_layer(ArrayMesh.new(), k, 3, row[0], row[1], {
			"tip": 0.1 if _kind == "whip" else 0.3, "top_thin": 0.12, "sway": 0.0, "ripple": 0.04,
			"cut": row[2], "inner": row[3], "seed": float(index) * 1.3 + float(k) * 0.37,
			"speed_a": Vector2(0.6, 2.4), "speed_b": Vector2(0.0, 3.2), "scale_a": Vector2(1.5, 0.4),
		})
		add_child(layer)
		layers.append([layer, float(row[4])])
	_bolts.append({
		"kind": _kind, "seed": index * 17 + 5, "root": root, "dir": dir.normalized(), "reach": reach,
		"delay": delay, "radius": radius, "phase0": phase0, "layers": layers,
	})


# 経路を作り直して三層の筒に載せ直す（電気の跳ね）
func _rebuild(b: Dictionary, step: int, t: float) -> void:
	var pts := _path(b, step, t)
	if pts.size() < 2:
		return
	# 噴流は、消えるにつれて細る（上へ流れた部分が宙に残る白い小片にならないように）
	var thin: float = (1.0 - 0.6 * _gone(b, t)) if (_kind == "jet" or _kind == "whip") else 1.0
	for pair: Array in b["layers"]:
		var layer: MeshInstance3D = pair[0]
		layer.mesh = Lib.path_tube(pts, float(pair[1]) * float(b["radius"]) * _size * thin, 0.7, 10)


func _path(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var kind: String = b["kind"]
	match kind:
		"whip":
			return _whip(b, step, t)
		"orb":
			return _orb(b, step, t)
		"ring":
			return _ring(b, step, t)
		"jet":
			return _jet(b, step, t)
	return _star(b, step, t)


# 鞭：根元から、しなりながら上へ伸び、先へ細る
func _whip(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var sd: int = b["seed"]
	var reach: float = b["reach"]
	var ph: float = b["phase0"]
	var n := 30
	for i in n + 1:
		var u := float(i) / n
		var sway := sin(u * 6.0 - t * 7.0 + ph) * 0.35 * reach * u   # 根元から先へ進む一つの波（しなり）。三本は位相をずらし、V字に開かない
		var lift := cos(u * 6.0 - t * 7.0 + ph) * 0.25 * reach * u
		pts.append(Vector3(sway, u * reach * (1.0 + 0.3 * _gone(b, t)), lift) + _jag(sd, i, step, 0.05 * _size))
	return pts


# 霊気の球：中心から球の表面へ、ゆるい弧を描く糸（回りながら）
func _orb(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var sd: int = b["seed"]
	var d: Vector3 = b["dir"]
	var reach: float = b["reach"]
	var spin: float = float(b["phase0"]) + t * 1.4
	var perp := d.cross(Vector3.UP)
	if perp.length() < 0.01:
		perp = d.cross(Vector3.RIGHT)
	perp = perp.normalized()
	var p2 := d * reach
	var p1 := d * reach * 0.5 + perp * reach * 0.7 * sin(spin * 1.7)
	var n := 16
	for i in n + 1:
		var u := float(i) / n
		var p := 2.0 * (1.0 - u) * u * p1 + u * u * p2
		pts.append(p + _jag(sd, i, step, 0.05 * _size))
	return pts


# 輪：地面に寝た輪。半径がゆっくり波打ち、切れ目なく流れる
func _ring(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var sd: int = b["seed"]
	var rad: float = b["reach"]
	var ph: float = b["phase0"]
	var n := 48
	for i in n + 1:
		var th := TAU * 1.04 * float(i) / n
		var r := rad * (1.0 + 0.1 * sin(3.0 * th - t * 2.4 + ph))
		var y := 0.06 * _size + 0.08 * _size * sin(2.0 * th + t * 1.5 + ph)
		pts.append(Vector3(cos(th) * r, y, sin(th) * r) + _jag(sd, i, step, 0.04 * _size))
	return pts


# 噴流：根元から立ち上がり、ねじれながら上へ抜ける
func _jet(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var sd: int = b["seed"]
	var reach: float = b["reach"]
	var root: Vector3 = b["root"]
	var ph: float = b["phase0"]
	var n := 30
	for i in n + 1:
		var u := float(i) / n
		var x := sin(u * 5.0 - t * 4.5 + ph) * 0.6 * u * reach * 0.6
		var z := cos(u * 4.0 - t * 3.0 + ph) * 0.4 * u * reach * 0.6
		pts.append(root + Vector3(x, u * reach * (1.0 + 0.3 * _gone(b, t)), z) + _jag(sd, i, step, 0.06 * _size))
	return pts


# 星：中心から放射する帯。先でしなる。角度はゆっくり回る
func _star(b: Dictionary, step: int, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var sd: int = b["seed"]
	var reach: float = b["reach"]
	var a: float = float(b["phase0"]) + t * 0.4
	var perp := Vector3(-sin(a), cos(a), 0.0)
	var dd := Vector3(cos(a), sin(a), 0.0)
	var n := 20
	for i in n + 1:
		var u := float(i) / n
		var p := dd * reach * u * (1.0 + 0.6 * _gone(b, t)) + perp * 0.9 * reach * u * u * sin(t * 2.0 + float(sd))
		pts.append(p + _jag(sd, i, step, 0.05 * _size))
	return pts


# 決まった入力から、0〜1の乱数を作る（同じ条件なら同じ値）
static func _rnd(sd: int, i: int, step: int) -> float:
	return fposmod(sin(float(sd) * 12.9898 + float(i) * 78.233 + float(step) * 37.719) * 43758.5453, 1.0)


func _jag(sd: int, i: int, step: int, amp: float) -> Vector3:
	return Vector3(_rnd(sd, i, step) - 0.5, _rnd(sd + 3, i, step) - 0.5, _rnd(sd + 7, i, step) - 0.5) * amp


# 根元が食われ終わるまでの進み具合（0〜1）。上へ流す・外へ飛ばす量に使う
func _gone(b: Dictionary, t: float) -> float:
	return pow(clampf((t - float(b["delay"]) - float(_timing["hold"])) / float(_timing["fade"]), 0.0, 1.0), 1.6)


# 霊気の球：殻を三層重ねた球。糸は出さない。eaten は負にして、極の穴を防ぐ
func _make_shells() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	for i in 3:
		var row: Array = PALETTES["orb"][i]
		var shell := Lib.wisp_layer(sphere, i, 3, row[0], row[1], {
			"tip": 0.0, "top_thin": 0.15, "sway": 0.0, "ripple": 0.04, "eaten": -0.3,
			"cut": row[2], "inner": row[3], "seed": float(i) * 0.37,
			"scale_a": Vector2(2.0, 0.5), "shear": 0.8,
		})
		shell.scale = Vector3.ONE * (1.1 - 0.15 * float(i)) * _size
		add_child(shell)
		_shells.append(shell)


# 霊気の球の終わり：外の殻がほどけて広がり、芯は遅れて上へ抜ける
func _pose_orb(t: float) -> void:
	var hold: float = _timing["hold"]
	var fade: float = _timing["fade"]
	for i in _shells.size():
		var shell: MeshInstance3D = _shells[i]
		var base_cut: float = PALETTES["orb"][i][2]
		var k := clampf((t - hold - 0.2 * float(i)) / fade, 0.0, 1.0)
		var eo := ease_out(k)
		shell.visible = k < 1.0
		shell.rotation.y = t * (0.9 - 0.25 * float(i))
		shell.rotation.x = sin(t * 0.6 + float(i)) * 0.25
		shell.scale = Vector3.ONE * (1.1 - 0.15 * float(i)) * _size * (1.0 + 0.25 * eo * (1.0 if i == 0 else 0.0))
		shell.position = Vector3(0.0, 1.2 * _size * eo * float(i), 0.0)
		param(shell, "phase", t)
		if i < 2:
			param(shell, "eaten", lerpf(-0.3, 0.74, k))   # 外の二層は上から食われてほどける。ノイズの穴（cut）は芯の一層だけにする
		else:
			param(shell, "cut", base_cut + (1.05 - base_cut) * k)   # 1.0 だと、絵の一番明るい画素が点々になって残る


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		for b: Dictionary in _bolts:
			if age >= float(b["delay"]):
				_rebuild(b, frame, age)
	_pose(age)


func _pose(t: float) -> void:
	if _kind == "orb":
		_pose_orb(t)
	var grow_time: float = _timing["grow"]
	var hold: float = _timing["hold"]
	var fade: float = _timing["fade"]
	for b: Dictionary in _bolts:
		var since := t - float(b["delay"])
		var up := ease_out(clampf(since / grow_time, 0.0, 1.0))
		var down := clampf((since - hold) / fade, 0.0, 1.0)
		for li in b["layers"].size():
			var pair: Array = b["layers"][li]
			var layer: MeshInstance3D = pair[0]
			# 先端は戻さない。根元の供給が止まり、根元から先へ消える（外の層が先、芯が最後）
			var gone := clampf((since - hold - 0.1 * float(li)) / fade, 0.0, 1.0)
			layer.visible = up > 0.01 and gone < 1.0
			param(layer, "grow", up)
			param(layer, "eaten", gone * 0.74)   # wisp の根元の境界は eaten × 1.35。0.74 で根元の全域が消え切り、連続的に食われる
			param(layer, "phase", t)
	_light.light_energy = 3.0 * _size * (1.0 - clampf(t / life, 0.0, 1.0)) * ease_out(clampf(t / 0.4, 0.0, 1.0))
