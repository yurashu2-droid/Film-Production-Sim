extends "res://vfx/vfx_base.gd"
# 超能力：テレパシー（念話）。頭から頭へ、思念の波がつながり、「考えの泡」が相手へ渡って、相手の頭の上で開く。
# 参考：漫画の「考えの吹き出し」（小さな泡が連なって、大きな雲の吹き出しになる）、『機動戦士ガンダム』のニュータイプの閃き
#       （額の「ピキーン」）、『X-MEN』プロフェッサーX（こめかみから波が相手へ届く）。
# 声ではなく「考えていること」が渡るので、渡る物は絵で見せる：送る側が思い浮かべた魚が、相手の頭の上に現れる。
#
# 素材：        思念（波）と、考えの泡（やわらかい塊）
# どこから来る： 送る人の額から。相手の額へ
# 先に動く部分： 波の先頭（額から相手へ伸びる）
# 遅れて追う部分：波の上を進む山（うねりのかたまりが相手へ流れる）／泡の列（小さい泡が先、大きい泡が後から）
# 形の変化：     0.1  額に「ピキーン」。頭のまわりに念の輪
#                0.3  波が相手の額へ伸びる（二本が逆向きにうねる）
#                0.7  考えの泡が、波の上を1つずつ渡る（だんだん大きく）
#                1.7  相手の頭の上で、泡が雲の吹き出しに開く。中に魚。相手が驚く
#                3.0  相手から、小さな波が返る（分かった、の合図）。送った人が笑う
#                4.0  波が、送る人の側から相手へ流れ切る。吹き出しが、波紋になって弾ける
# 終わり：
#   波       … 供給を止め、送る人の側から相手へ流れ切る（戻らない）
#   渡る泡   … 相手の頭の上の吹き出しに飛び込む
#   吹き出し … ふちから波紋になって広がり、中身ごと弾ける（中の魚は、弾けた瞬間に消える）
#   頭の輪   … あごの側から頭の上へ抜ける

const Stage := preload("res://vfx/esper/esper_stage.gd")
const Aura := preload("res://vfx/esper/esper_aura.gd")
const Waves := preload("res://vfx/esper/esper_waves.gd")
const Ribbon := preload("res://vfx/vfx_ribbon.gd")

const SENDER := Vector3(-3.3, 0.0, 0.8)
const LISTENER := Vector3(3.1, 0.0, 0.3)
const LINK := 0.3
const BUBBLES := 0.7
const OPEN := 1.7
const REPLY := 3.0
const CLOSE := 4.0
const VIOLET := Color(0.5, 0.3, 1.0)
const PINK := Color(1.0, 0.42, 0.72)

var _a: Node3D
var _b: Node3D
var _waves: Node3D
var _links: Array = []            # うねる波2本
var _halo_a: MeshInstance3D
var _halo_b: MeshInstance3D
var _dots: Array = []             # 渡る泡：[オーラ, 出る時刻, 大きさ]
var _cloud: MeshInstance3D        # 相手の頭の上の吹き出し
var _thought: Node3D              # 吹き出しの中の魚
var _popped := false


static func spawn(parent: Node, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = origin
	fx.start()
	return fx


func start() -> void:
	life = 6.2
	_a = Stage.figure(self, "03", SENDER, Vector3.RIGHT, "idle")
	_b = Stage.figure(self, "01", LISTENER, Vector3.LEFT, "idle")
	_waves = Waves.new()
	_waves.tint = PINK
	_waves.shown = 0.9
	add_child(_waves)
	_waves.arrived.connect(func(_at: Vector3) -> void: _halo_a.ring(age))
	for i in 2:
		var line: MeshInstance3D = Ribbon.new()
		line.material_override = Lib.material("psychic_thread", {
			"noise_tex": Lib.noise("soft"), "seed": 0.2 + i * 0.5, "width": 0.07 - i * 0.02, "cut": 0.05, "stretch": 1.2,
			"color": Vector3(0.55, 0.36, 1.0) if i == 0 else Vector3(0.35, 0.8, 1.0), "color_core": Vector3(1.25, 1.2, 1.4), "opacity": 0.9, "head": 0.0,
		})
		add_child(line)
		_links.append(line)
	_halo_a = Aura.at(self, PackedVector3Array([SENDER]), {"tint": VIOLET, "pad": 0.36, "amp": 0.05, "jag": 0.3, "teeth": 9.0, "ring_reach": 0.4, "priority": 0})
	_halo_b = Aura.at(self, PackedVector3Array([LISTENER]), {"tint": PINK, "pad": 0.36, "amp": 0.05, "jag": 0.3, "teeth": 9.0, "ring_reach": 0.4, "priority": 0})
	_halo_b.visible = false
	for n in 4:
		var dot: MeshInstance3D = Aura.at(self, PackedVector3Array([SENDER]), {"tint": VIOLET, "pad": 0.05, "band": 0.012, "amp": 0.012, "jag": 0.0, "split": 0.0, "ring_gain": 0.0, "warp": 0.0})
		dot.visible = false
		_dots.append([dot, BUBBLES + n * 0.2, 0.06 + n * 0.035])
	_cloud = Aura.at(self, PackedVector3Array([LISTENER]), {"tint": VIOLET, "pad": 0.3, "band": 0.02, "amp": 0.05, "jag": 0.0, "rise": 0.0, "split": 0.008, "ring_reach": 0.8, "ring_width": 0.02, "warp": 0.3})
	_cloud.visible = false
	_thought = Stage.prop(self, "fish", Vector3.ZERO)
	_thought.visible = false
	var spark := sprite(2, Color(2.6, 2.3, 3.2), 0.1)
	spark.position = Stage.brow(_a)
	over(0.1, 0.22, func(k: float) -> void:
		spark.scale = Vector3.ONE * lerpf(0.2, 1.1, ease_out(k))
		param(spark, "color", Color(2.6, 2.3, 3.2, 1.0 - k * k)))
	at(0.34, spark.queue_free)
	at(0.12, func() -> void: _halo_a.ring(age))
	at(LINK + 0.35, _reach)
	at(OPEN, _open)
	at(REPLY, _answer)
	at(REPLY + 0.5, func() -> void: _a.set_face("happy"))
	at(CLOSE + 0.25, _pop)


# 波が届いた：相手の頭にも輪が出る
func _reach() -> void:
	_halo_b.visible = true
	_halo_b.ring(age)


func _open() -> void:
	_b.set_face("surprised")
	_b.play("flinch", 0.05, true)
	_cloud.ring(age)
	at(age + 0.8, func() -> void: _b.play("idle", 0.3))


# 相手からの返事：小さな波が返る
func _answer() -> void:
	_b.set_face("happy")
	_waves.send(Stage.brow(_b), Stage.brow(_a), 0.35, 0.5, 0.25)
	_halo_b.ring(age)


func _pop() -> void:
	_popped = true
	_thought.visible = false
	for n in 3:
		at(age + n * 0.07, func() -> void: _cloud.ring(age))


# 額から額への道すじ（少し上へふくらむ）
func _way(k: float) -> Vector3:
	var from := Stage.brow(_a)
	var to := Stage.brow(_b)
	return from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.35, 0)


# 相手の頭の上（吹き出しの場所）
func _above() -> Vector3:
	return _b.head_pos() + Vector3(-0.2, 0.75, 0.0)


func _tick(_delta: float) -> void:
	_waves.tick(age)
	var head := ease_out(clampf((age - LINK) / 0.35, 0.0, 1.0))
	var tail := clampf((age - CLOSE) / 0.3, 0.0, 1.0)
	# うねる波2本：逆向きにうねり、山のかたまりが相手へ流れる
	for i in 2:
		var line: MeshInstance3D = _links[i]
		line.visible = age >= LINK and tail < 1.0
		if not line.visible:
			continue
		var points := PackedVector3Array()
		for j in 40:
			var k := j / 39.0
			var packet := 0.35 + 0.65 * pow(maxf(sin((k * 2.2 - age * 0.9) * PI), 0.0), 2.0)
			var swing := sin(k * 26.0 - age * 9.0) * 0.17 * packet * sin(k * PI) * (1.0 if i == 0 else -1.0)
			points.append(_way(k) + Vector3(0, swing, swing * 0.6))
		line.draw(points)
		param(line, "head", head)
		param(line, "tail", tail * 0.99)
		param(line, "phase", age * 1.2)
	# 頭の輪：あごの側から包み、最後は頭の上へ抜ける
	var done := age - (CLOSE + 0.5)
	for pair: Array in [[_halo_a, _a, 0.0], [_halo_b, _b, LINK + 0.35]]:
		var halo: MeshInstance3D = pair[0]
		var who: Node3D = pair[1]
		var mid: Vector3 = who.head_pos() - Vector3(0, 0.3, 0)
		halo.move(PackedVector3Array([mid]))
		halo.p("grip", mid - Vector3(0, 0.5, 0))
		halo.p("reveal", lerpf(0.0, 1.6, ease_out(clampf((age - float(pair[2]) - 0.05) / 0.25, 0.0, 1.0))))
		halo.p("drain", lerpf(-0.3, 1.6, clampf(done / 0.35, 0.0, 1.0)) if done >= 0.0 else -1.0)
		halo.visible = halo.visible and done < 0.45
		halo.place(age, 0.3)
	# 渡る泡：波の上を、小さい泡から順に渡る。相手の頭の上の吹き出しへ飛び込む
	var above := _above()
	for row: Array in _dots:
		var dot: MeshInstance3D = row[0]
		var k: float = (age - float(row[1])) / 0.95
		dot.visible = k > 0.0 and k < 1.0
		if not dot.visible:
			continue
		var e := Stage.ease_io(k)
		var on_way := _way(minf(e * 1.15, 1.0)) + Vector3(0, 0.3 + 0.25 * sin(k * PI), 0)
		var at_point := on_way.lerp(above, smoothstep(0.75, 1.0, k))
		dot.move(PackedVector3Array([at_point]))
		dot.p("pad", float(row[2]) * (0.6 + 0.4 * sin(minf(k * 6.0, 1.0) * PI * 0.5)))
		dot.p("reveal", 3.0)
		dot.place(age, 0.2)
	# 吹き出し：下から開く。弾ける時は、中から抜けて波紋だけになる
	var since := age - OPEN
	_cloud.visible = since >= -0.05 and age < CLOSE + 1.2
	if _cloud.visible:
		var bob := Vector3(0, sin(age * 2.2) * 0.03, 0)
		_cloud.move(PackedVector3Array([above + bob + Vector3(-0.3, -0.05, 0), above + bob + Vector3(0.3, -0.05, 0), above + bob + Vector3(0.0, 0.2, 0), above + bob + Vector3(-0.15, -0.2, 0)]))
		_cloud.p("grip", above - Vector3(0, 0.6, 0) if not _popped else above)
		_cloud.p("reveal", lerpf(0.0, 2.4, ease_out(clampf(since / 0.3, 0.0, 1.0))))
		_cloud.p("drain", lerpf(-0.2, 2.4, clampf((age - CLOSE - 0.25) / 0.2, 0.0, 1.0)) if _popped else -1.0)
		_cloud.place(age, 0.25)
		# 中の魚：開き切ってから、ぽんと現れる（行きすぎて戻る）
		var shown := clampf((since - 0.22) / 0.25, 0.0, 1.0)
		_thought.visible = shown > 0.0 and not _popped
		if _thought.visible:
			var size: Vector3 = _thought.get_meta("size")
			var fit := 0.62 / maxf(size.x, maxf(size.y, size.z))
			_thought.scale = Vector3.ONE * fit * (ease_out(shown) + 0.25 * sin(shown * PI))
			_thought.global_position = above + bob - Vector3(0, float(_thought.get_meta("rest")) * fit * 0.5, 0) + Vector3(0, 0, 0.1)
			_thought.rotation = Vector3(0.2 * sin(age * 1.7), age * 1.4, 0.0)
