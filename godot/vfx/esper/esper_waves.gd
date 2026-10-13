extends Node3D
# 念波：弧の列「）））」が、出どころから相手へ向けて飛ぶ。超能力の演出（vfx/esper/）で使い回す。
# 弧は出どころの大きさで生まれ、離れた分だけ広がり、進むほど細って切れる（shown までの区間だけ見せる）。
# 毎コマ tick(時刻) を呼ぶ。send() のたびに1つ飛ばす。届いた合図は arrived（相手側で波紋を出すのに使う）。
const Lib := preload("res://vfx/vfx_lib.gd")
const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const Psychic := preload("res://vfx/vfx_psychic.gd")
const GAP := 0.16                 # 弧どうしの遅れ（届くまでの時間に対する割合）

signal arrived(at: Vector3)

var tint := Psychic.TINT
var width := 0.034
var zig := 0.0                    # 1 でギザギザの弧
var shown := 0.6                  # 弧が見えている区間（道のりに対する割合）
var layers_mask := 1
var _waves: Array = []            # [弧3本, 始まった時刻, 秒, 出どころ, 相手, 届く大きさ, 向き, 開き, 回る速さ, 合図したか, 上へのふくらみ]
var _rng := RandomNumberGenerator.new()
var _now := 0.0


# from → to へ1つ飛ばす。size＝届いた時の弧の半径（m）、seconds＝届くまで、lift＝道のりの上へのふくらみ（m）
func send(from: Vector3, to: Vector3, size: float, seconds: float, lift: float = 0.0) -> void:
	var top := maxf(maxf(tint.r, tint.g), maxf(tint.b, 0.001))
	var hue := Vector3(tint.r, tint.g, tint.b) / top
	var arcs: Array = []
	for n in 3:
		var r: MeshInstance3D = Ribbon.new()
		var m: ShaderMaterial = Lib.material("psychic_thread", {
			"noise_tex": Lib.noise("soft"), "seed": _rng.randf(), "width": width * (1.0 - n * 0.2), "cut": 0.15, "stretch": 0.5,
			"color": hue.lerp(Vector3.ONE, 0.15), "color_core": hue.lerp(Vector3.ONE, 0.7) * 1.3, "opacity": 0.9, "head": 0.0,
		})
		m.render_priority = 4
		r.material_override = m
		r.layers = layers_mask
		add_child(r)
		arcs.append(r)
	_waves.append([arcs, _now, seconds, from, to, size, _rng.randf() * TAU, _rng.randf_range(3.4, 4.5), _rng.randf_range(-2.0, 2.0), false, lift])


func busy() -> bool:
	return not _waves.is_empty()


func tick(now: float) -> void:
	_now = now
	var i := 0
	while i < _waves.size():
		var w: Array = _waves[i]
		var lead: float = (now - float(w[1])) / float(w[2])
		if lead >= 1.0 and not w[9]:
			w[9] = true
			arrived.emit(w[4])
		if lead >= 1.0 + GAP * 2.0:
			for arc: Node in w[0]:
				arc.queue_free()
			_waves.remove_at(i)
			continue
		i += 1
		var from: Vector3 = w[3]
		var to: Vector3 = w[4]
		var ctrl := (from + to) * 0.5 + Vector3.UP * float(w[10]) * 2.0
		for n in 3:
			var arc: MeshInstance3D = w[0][n]
			var k := lead - n * GAP
			arc.visible = k > 0.0 and k < shown
			if not arc.visible:
				continue
			var e := pow(k, 0.85)
			var at := from.lerp(ctrl, e).lerp(ctrl.lerp(to, e), e)
			var ahead := (from.lerp(ctrl, e + 0.02).lerp(ctrl.lerp(to, e + 0.02), e + 0.02) - at).normalized()
			var side := ahead.cross(Vector3.UP)
			side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
			var lift := side.cross(ahead)
			var wide := maxf(0.07, float(w[5]) * e)
			var spent := k / shown
			var turn: float = float(w[6]) + float(w[8]) * (now - float(w[1])) + n * 0.5
			var points := PackedVector3Array()
			for j in 15:
				var a := turn + float(w[7]) * j / 14.0
				var r := wide * (1.0 + zig * 0.2 * (1.0 if j % 2 == 0 else -1.0))
				points.append(at + (side * cos(a) + lift * sin(a)) * r - ahead * wide * 0.3 * sin(PI * j / 14.0))
			arc.draw(points)
			var m := arc.material_override as ShaderMaterial
			m.set_shader_parameter("head", clampf(k / 0.1, 0.0, 1.0))
			m.set_shader_parameter("width", width * (1.0 - n * 0.2) * (1.0 - 0.75 * spent))
			m.set_shader_parameter("cut", lerpf(0.15, 0.62, spent * spent))
			m.set_shader_parameter("phase", now * 0.8)
