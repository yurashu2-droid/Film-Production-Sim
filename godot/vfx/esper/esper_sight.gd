extends "res://vfx/vfx_base.gd"
# 超能力：透視（千里眼）。壁に「目の形の窓」が開き、壁の向こうに隠れた物と人が、影になって透けて見える。
# 参考：テレビの超能力番組の透視（封筒や箱の中身を言い当てる）、ゲームの透視（壁の向こうの相手が輪郭で見える：
#       『バットマン アーカム』の探偵モード、『アサシン クリード』のタカの眼）、漫画の千里眼（額に第三の目）。
# 壁を消したり透明にしたりしない。壁はそのままで、「見えた物の影」だけが壁の上に浮かぶ。
#
# 素材：        視線（念の波）と、見えた物の影（平たい色）
# どこから来る： 能力者の額から。念波が壁へ飛び、当たった所に窓が開く
# 先に動く部分： 窓のふち（まぶたのように縦に開く）
# 遅れて追う部分：窓の中の影（窓が通った所だけ見える）／窓から広がる波紋
# 形の変化：     0.25 額に火花。念波が壁へ飛ぶ
#                0.6  壁に、目が開くように窓が開く。中に、積んだ箱と魚の影
#                1.4  視線を右へ動かす。窓が壁の上をすべり、電話、そして隠れている人の影が現れる
#                3.0  見つけた。窓が止まって波紋を打ち、隠れていた人がびくっとする
#                3.9  目を閉じる。窓がまぶたのように縦に閉じ、残った横の線が、まん中から左右の端へ抜ける
# 終わり：
#   窓       … 縦に閉じる（目を閉じる動き）。残った線は、まん中から左右へ抜ける
#   影       … 窓が閉じた所から見えなくなる（窓を通してしか見えない物なので）
#   波紋     … 窓のふちから外へ進み、細って切れる

const Stage := preload("res://vfx/esper/esper_stage.gd")
const Aura := preload("res://vfx/esper/esper_aura.gd")
const Waves := preload("res://vfx/esper/esper_waves.gd")

const WALL_Z := 0.3
const TINT := Color(1.0, 0.42, 0.72)
const OPEN := 0.6
const SCAN := 1.4
const FOUND := 3.0
const SHUT := 3.9
# 窓の中心が通る道（壁の上。x, y）と時刻
const GAZE := [[0.0, Vector2(-1.5, 1.05)], [1.4, Vector2(-1.5, 1.05)], [2.1, Vector2(-0.2, 0.95)], [2.9, Vector2(1.5, 1.05)], [9.0, Vector2(1.5, 1.05)]]

var _esper: Node3D
var _hider: Node3D
var _waves: Node3D
var _lens: MeshInstance3D
var _shades: Array = []               # [影（写し）, 元のメッシュ]
var _xray: ShaderMaterial
var _halo: MeshInstance3D
var _rings: Array[float] = [-9.0, -9.0, -9.0]
var _ring_n := 0


static func spawn(parent: Node, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = origin
	fx.start()
	return fx


func start() -> void:
	life = 5.4
	# 壁（書き割り2枚）。塗った面を、見ている側へ向ける
	for x: float in [-1.25, 1.25]:
		var flat: Node3D = Stage.prop(self, "flat", Vector3(x, 0, WALL_Z))
		var size: Vector3 = flat.get_meta("size")
		# 人が隠れる高さ（2.3m）まで伸ばす
		flat.scale = Vector3(2.5 / maxf(size.x, 0.1), 2.3 / maxf(size.y, 0.1), 1.0)
		flat.position.y = float(flat.get_meta("rest")) * flat.scale.y
	_esper = Stage.figure(self, "01", Vector3(-3.6, 0, 2.6), Vector3(0.6, 0, -1.0), "idle")
	# 壁の向こう：積んだ箱と魚、電話、隠れている人
	var hidden: Array = []
	hidden.append(Stage.prop(self, "box", Vector3(-1.6, 0, -1.0), 0.3))
	hidden.append(Stage.prop(self, "box", Vector3(-1.55, 0.21, -1.0), -0.2))
	hidden.append(Stage.prop(self, "fish", Vector3(-1.55, 0.44, -1.0), 0.9))
	hidden.append(Stage.prop(self, "phone", Vector3(-0.2, 0, -0.9), 2.6))
	_hider = Stage.figure(self, "02", Vector3(1.5, 0, -1.1), Vector3(0, 0, 1.0), "crouch_idle")
	hidden.append(_hider)
	_xray = Lib.material("esper_xray", {"color": Vector3(TINT.r, TINT.g, TINT.b), "wall_z": WALL_Z + 0.05})
	_xray.render_priority = 6
	for node: Node3D in hidden:
		for src: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var copy := MeshInstance3D.new()
			copy.mesh = src.mesh
			copy.material_override = _xray
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.top_level = true
			copy.extra_cull_margin = 2.0
			add_child(copy)
			if src.skin != null:
				copy.skin = src.skin
				var bones := src.get_node_or_null(src.skeleton)
				if bones != null:
					copy.skeleton = copy.get_path_to(bones)
			_shades.append([copy, src])
	_lens = MeshInstance3D.new()
	_lens.mesh = Lib.quad()
	_lens.material_override = Lib.material("esper_lens", {"noise_tex": Lib.noise("soft"), "color": Vector3(TINT.r, TINT.g, TINT.b), "size": 4.0, "radius": 0.0})
	(_lens.material_override as ShaderMaterial).render_priority = 5
	_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lens.scale = Vector3.ONE * 4.0
	_lens.visible = false
	add_child(_lens)
	_waves = Waves.new()
	_waves.tint = TINT
	add_child(_waves)
	_halo = Aura.at(self, PackedVector3Array([Vector3.ZERO]), {"tint": TINT, "pad": 0.34, "amp": 0.05, "jag": 0.3, "teeth": 9.0, "ring_reach": 0.4, "priority": 0})
	var spark := sprite(2, Color(3.2, 2.2, 2.8), 0.1)
	spark.position = _esper.head_pos() + Vector3(0, -0.1, 0.0)
	over(0.25, 0.22, func(k: float) -> void:
		spark.scale = Vector3.ONE * lerpf(0.2, 1.2, ease_out(k))
		param(spark, "color", Color(3.2, 2.2, 2.8, 1.0 - k * k)))
	at(0.5, spark.queue_free)
	at(0.3, func() -> void: _waves.send(_esper.head_pos(), Vector3(-1.5, 1.05, WALL_Z), 0.5, 0.3, 0.15))
	at(OPEN, _ring)
	at(FOUND, _found)
	at(FOUND + 0.12, _ring)


func _ring() -> void:
	_rings[_ring_n % 3] = age
	_ring_n += 1


# 見つけた：隠れていた人がびくっとする
func _found() -> void:
	_ring()
	_halo.ring(age)
	_hider.set_face("shock")
	_hider.play("flinch", 0.05, true)
	_esper.set_face("happy")
	at(age + 0.8, func() -> void: _hider.play("crouch_idle", 0.3))


func _gaze(t: float) -> Vector2:
	var i := 0
	while i < GAZE.size() - 2 and t >= float(GAZE[i + 1][0]):
		i += 1
	var k := Stage.ease_io((t - float(GAZE[i][0])) / (float(GAZE[i + 1][0]) - float(GAZE[i][0])))
	return (GAZE[i][1] as Vector2).lerp(GAZE[i + 1][1], k)


func _tick(_delta: float) -> void:
	_waves.tick(age)
	for pair: Array in _shades:
		(pair[0] as MeshInstance3D).global_transform = (pair[1] as MeshInstance3D).global_transform
	var gaze := _gaze(age)
	# 窓：まぶたのように縦に開く。見つけた時に少し広がる。閉じる時は縦につぶれ、横の線になって左右へ抜ける
	var opened := clampf((age - OPEN) / 0.28, 0.0, 1.0)
	var shut := clampf((age - SHUT) / 0.2, 0.0, 1.0)
	var squash := (ease_out(opened) + 0.15 * sin(opened * PI)) * (1.0 - shut * shut)
	var radius := 0.95 * ease_out(clampf((age - OPEN) / 0.2, 0.0, 1.0)) * (1.0 + 0.12 * clampf(1.0 - absf(age - FOUND - 0.1) / 0.2, 0.0, 1.0))
	var line := clampf((age - SHUT - 0.2) / 0.16, 0.0, 1.0)
	_lens.visible = age >= OPEN and line < 1.0
	_lens.position = Vector3(gaze.x, gaze.y, WALL_Z + 0.06)
	var m := _lens.material_override as ShaderMaterial
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("squash", squash)
	m.set_shader_parameter("phase", age * 1.6)
	m.set_shader_parameter("boil", floorf(age * 12.0) / 12.0 * 0.8)
	m.set_shader_parameter("line", line)
	m.set_shader_parameter("rings", Vector3((age - _rings[0]) / 0.7, (age - _rings[1]) / 0.7, (age - _rings[2]) / 0.7))
	_xray.set_shader_parameter("lens_center", Vector2(global_position.x + gaze.x, global_position.y + gaze.y))
	_xray.set_shader_parameter("lens_radius", radius if _lens.visible and squash > 0.03 else 0.0)
	_xray.set_shader_parameter("lens_squash", squash)
	_xray.set_shader_parameter("phase", floorf(age * 12.0) * 0.37)
	# 能力者：窓のほうを見る。額のまわりに輪
	var head: Vector3 = _esper.head_pos() - Vector3(0, 0.3, 0)
	var done := age - (SHUT + 0.3)
	_halo.move(PackedVector3Array([head]))
	_halo.p("grip", head - Vector3(0, 0.5, 0))
	_halo.p("reveal", lerpf(0.0, 1.6, ease_out(clampf((age - 0.2) / 0.25, 0.0, 1.0))))
	_halo.p("drain", lerpf(-0.3, 1.6, clampf(done / 0.35, 0.0, 1.0)) if done >= 0.0 else -1.0)
	_halo.visible = done < 0.45
	_halo.place(age, 0.3)
	_esper.rotation.y = atan2(gaze.x - _esper.position.x, WALL_Z - _esper.position.z)
