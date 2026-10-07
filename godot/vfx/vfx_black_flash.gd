extends "res://vfx/vfx_base.gd"
# 黒閃（『呪術廻戦』風）。黒い芯に赤いふちの稲妻が、殴った点から走る。
# 稲妻は折れ線の形で作らない。板の上で、流れるノイズから線を取り出して描く（arc シェーダー）。
#   参考にした作り方：
#     ・ノイズで線の位置をずらす／ノイズがある値をまたぐ所を線にする（ゼルダBotWの稲妻。realtimevfx.com の解説）
#     ・手描きアニメの稲妻は、ゆるく不揃いな形に「指」のような枝を付け、先へ細らせる
#     ・黒い光は加算では出ない。黒い芯は背景を隠し、赤いにじみだけを足す（乗算済みアルファ）
#   0コマ目    白い閃光
#   1〜2コマ目 画面ごと白黒反転（インパクトフレーム）
#   稲妻       太い本流を6本、それぞれ別の時刻に光り直す（そのときだけ形が跳ぶ）。細い副流を重ねる
#   放電の網   殴った点のまわりを、細い線が這い回る
#   黒い煙     下から赤く照らされた塊
#   終わり     稲妻は先端から引っ込み、網は細って消える。地面のひびは細って、ぐるっとぬぐわれる

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const FPS := 15.0
const RED := Vector3(4.2, 0.14, 0.07)
const SMOKE := [
	[0.07, Vector3(0.6, 0.5, 1.0), 1.5, 0.8, 0.7], [0.07, Vector3(0.3, 0.4, -1.0), 1.4, 0.75, 0.75],
	[0.07, Vector3(-0.8, 0.5, 0.3), 1.3, 0.7, 0.7], [0.13, Vector3(1.0, 0.3, 0.3), 2.2, 0.6, 0.6],
	[0.13, Vector3(0.2, 1.0, -0.3), 1.7, 0.55, 0.75], [0.2, Vector3(-0.5, 0.9, 0.6), 1.6, 0.45, 0.65],
]

var _size := 1.0
var _dir := Vector3.RIGHT
var _frame := -1
var _bolts: Array = []        # 稲妻ごとの情報
var _web: MeshInstance3D
var _flash: MeshInstance3D
var _flip: MeshInstance3D
var _cracks: MeshInstance3D
var _smoke: MultiMesh
var _light: OmniLight3D


# pos は殴った点。direction は殴った向き。
static func spawn(parent: Node, pos: Vector3, size: float = 1.0, direction: Vector3 = Vector3.RIGHT) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, direction)
	return fx


func start(size: float, direction: Vector3) -> void:
	_size = size
	_dir = Vector3(direction.x, 0, direction.z).normalized()
	life = 1.5
	_light = lamp(Color(1.0, 0.12, 0.08), 12.0 * size)
	_flash = sprite(2, Color(10, 10, 10), size)
	param(_flash, "toward_camera", size)
	# インパクトフレーム：画面を白黒反転させる板。先に描いて、黒と赤をその上に乗せる
	_flip = MeshInstance3D.new()
	_flip.mesh = Lib.quad()
	var flip_mat := Lib.material("invert")
	flip_mat.render_priority = -100
	_flip.material_override = flip_mat
	_flip.scale = Vector3.ONE * 120.0
	_flip.extra_cull_margin = 1000.0
	_flip.visible = false
	add_child(_flip)
	# 稲妻：殴った向きの前後と上へ6本。1本につき、太い本流と細い副流を同じ板の向きに重ねる
	var across := _dir.cross(Vector3.UP).normalized()
	var ways: Array[Vector3] = [_dir + Vector3.UP * 0.45, -_dir + Vector3.UP * 0.3, _dir * 0.45 + Vector3.UP + across * 0.2, -_dir * 0.4 + Vector3.UP * 0.85 - across * 0.5, _dir * 0.9 - Vector3.UP * 0.08 - across * 0.6, Vector3.UP * 0.9 + across * 0.7 - _dir * 0.15]
	for i in ways.size():
		var reach := randf_range(4.0, 6.5) * size
		for strand in 2:
			var r: MeshInstance3D = Ribbon.new()
			var mat := Lib.material("arc", {
				"noise_texture": Lib.noise("soft"), "width": reach * (0.55 if strand == 0 else 0.7),
				"thickness": 0.19 if strand == 0 else 0.06, "forks": 2.0 if strand == 0 else 1.0,
				"variation": 0.5 if strand == 0 else 0.7, "frequency": 0.4 if strand == 0 else 0.75,
				"speed": 1.4 if strand == 0 else 2.2, "morph": 1.0 if strand == 0 else 1.8,
				"rim_color": RED, "glow": 0.22 if strand == 0 else 0.16, "seed": randf() * 50.0,
			})
			mat.render_priority = 2 - strand
			r.material_override = mat
			add_child(r)
			_bolts.append({"ribbon": r, "way": ways[i].normalized(), "reach": reach, "main": strand == 0, "next": randf_range(0.14, 0.3), "born": i * 0.012})
	# 放電の網：殴った点のまわりを細い線が這う
	_web = MeshInstance3D.new()
	_web.mesh = Lib.quad()
	var web_mat := Lib.material("arc", {
		"noise_texture": Lib.noise("soft"), "web": true, "width": 5.0 * size, "thickness": 0.05, "frequency": 0.8, "morph": 2.2,
		"rim_color": RED, "glow": 0.2, "seed": randf() * 50.0,
	})
	web_mat.render_priority = 0
	_web.material_override = web_mat
	_web.extra_cull_margin = 10.0
	add_child(_web)
	# 黒い煙：下から赤く照らされた塊
	_smoke = MultiMesh.new()
	_smoke.transform_format = MultiMesh.TRANSFORM_3D
	_smoke.use_colors = true
	_smoke.mesh = Lib.cloud_mesh(0)
	_smoke.instance_count = SMOKE.size()
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _smoke
	holder.material_override = Lib.material("cloud", {
		"dissolve_texture": Lib.noise("cells"), "light_dir": Vector3(0.25, -0.9, 0.2),
		"shadow_tint": Vector3(0.02, 0.02, 0.02), "highlight_tint": Vector3(16.0, 6.0, 5.0), "shadow_threshold": 0.05, "highlight_threshold": 0.72,
	})
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -10.0 * size, Vector3.ONE * 20.0 * size)
	add_child(holder)
	_cracks = MeshInstance3D.new()
	_cracks.mesh = Lib.quad()
	_cracks.material_override = Lib.material("stamp", {"shape": Lib.tex("cracks336.png"), "cut": 0.38, "core_cut": 2.0, "reveal": 0.0, "color": Color(0.02, 0.01, 0.01, 1), "core_color": Color(0.02, 0.01, 0.01, 1)})
	_cracks.rotation.x = -PI / 2.0
	add_child(_cracks)
	_pose(0.0)
	_flow()


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)
	_flow()


# 稲妻と網は毎フレーム動かす。形はノイズが流れることで連続して変わり、光り直しのときだけ跳ぶ
func _flow() -> void:
	var since := age - 1.0 / FPS
	for bolt: Dictionary in _bolts:
		var r: MeshInstance3D = bolt["ribbon"]
		var t: float = since - float(bolt["born"])
		var lasts := 0.95 if bolt["main"] else 0.8
		if t < 0.0 or t >= lasts:
			r.draw(PackedVector3Array())
			continue
		if t >= float(bolt["next"]):
			bolt["next"] = t + randf_range(0.12, 0.26)
			param(r, "seed", randf() * 50.0)
			bolt["hot"] = t
		var way: Vector3 = bolt["way"]
		r.draw(PackedVector3Array([global_position, global_position + way * float(bolt["reach"])]))
		param(r, "phase", age)
		param(r, "reveal", ease_out(clampf(t / 0.09, 0.0, 1.0)) * (1.0 - smoothstep(lasts * 0.6, lasts, t)) * 1.05)
		# 光り直した直後だけ、芯が一瞬白熱する
		var struck: float = t - float(bolt.get("hot", 0.0))
		param(r, "core_color", Vector3(10, 6, 5) if struck < 0.02 else Vector3.ZERO)
	var live := since >= 0.0 and since < 0.75
	_web.visible = live
	if live:
		param(_web, "phase", age)
		param(_web, "thickness", 0.05 * (1.0 - smoothstep(0.35, 0.75, since)))
		param(_web, "fade", ease_out(clampf(since / 0.08, 0.0, 1.0)))


func _pose(t: float) -> void:
	var f := int(roundf(t * FPS))
	var since := t - 1.0 / FPS
	_flash.visible = f == 0
	_flash.scale = Vector3.ONE * _size * 3.2
	_flip.visible = f == 1 or f == 2
	_light.light_energy = 14.0 * _size * maxf(0.0, 1.0 - t / 1.0)
	# 黒い煙：赤い光を下から受けながら噴き出し、昇りながら縮む
	var frame_of := Basis(_dir, Vector3.UP, _dir.cross(Vector3.UP))
	for i in SMOKE.size():
		var plan: Array = SMOKE[i]
		var tt: float = t - float(plan[0])
		var k: float = tt / float(plan[4])
		var dia := 0.0001
		var pos := Vector3.ZERO
		if tt >= 0.0 and k < 1.0:
			var pop := lerpf(0.4, 1.15, tt / 0.07) if tt < 0.07 else (lerpf(1.15, 1.0, (tt - 0.07) / 0.12) if tt < 0.19 else 1.0)
			dia = float(plan[3]) * _size * pop * (1.0 - pow(smoothstep(0.45, 1.0, k), 1.5))
			pos = (frame_of * (plan[1] as Vector3).normalized()) * float(plan[2]) * _size * ease_out(clampf(tt / 0.3, 0.0, 1.0)) + Vector3.UP * 0.6 * tt * _size
		_smoke.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(i * 1.3, i * 2.1 + t, i * 0.7)) * Basis.from_scale(Vector3.ONE * maxf(dia, 0.0001)), pos))
		_smoke.set_instance_color(i, Color(0.5, 0.03, 0.02, 1.0))
	# 地面のひび：走って、細って千切れながら、ぐるっとぬぐわれる
	_cracks.global_position = global_position + Vector3(0, -minf(global_position.y, 1.2 * _size) + 0.02, 0)
	_cracks.scale = Vector3.ONE * 7.0 * _size
	_cracks.visible = f >= 1
	param(_cracks, "reveal", ease_out(clampf(since / 0.2, 0.0, 1.0)))
	param(_cracks, "cut", 0.38 + 0.5 * smoothstep(0.9, 1.4, t))
	param(_cracks, "sweep", smoothstep(1.0, 1.4, t))
