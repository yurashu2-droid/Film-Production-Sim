extends "res://vfx/vfx_base.gd"
# 超能力：サイコキネシス（念動力）の凝った版「念動・乱舞」。周りの物が一斉に浮き、渦になり、固まり、放たれる。
# 参考：『AKIRA』『モブサイコ100』（まわりの物が次々に浮き上がり、能力者を中心に回る）、『CONTROL』のランチ（引き寄せて、固めて、撃ち出す）。
# 念力は見えない力なので、力そのものは描かない。浮く物・輪郭のオーラ・念波・押された土ぼこりで見せる。
#
# 素材：        念（見えない力）と、それに動かされる小道具・土ぼこり
# どこから来る： 能力者の額と両手から。念波の弧が物の群れへ飛ぶ
# 先に動く部分： 物の震え（浮く前に、床の上で小刻みに震える）→ 手前の物から順に浮く
# 遅れて追う部分：浮いた跡の土ぼこり（床に輪になって広がる）／物の後ろに引く筋（通ってきた道すじ）／オーラのなびき
# 形の変化：     0.0  額に「ピキーン」。物が震えはじめる
#                0.5  手前から順に浮く（1つずつ 0.09 秒ずれる）。床に土ぼこりの輪。輪郭がオーラに包まれる
#                1.5  渦になる。まん中に念の芯。回るほど速く、通った道すじに筋が残る
#                3.5  固まる。渦がしぼみ、物どうしが1つのオーラに包まれて震える
#                4.3  放つ。まとまりが弾け、物が扇に開いて飛ぶ。足もとから土ぼこりの列、放った所に波紋
# 終わり：
#   物         … 飛び去る（画面の外へ）。オーラは、飛びながら後ろへ抜ける
#   まとまりのオーラ … 放った瞬間にギザギザに弾け、波紋3本になって広がり、細って切れる
#   念の芯     … 放つ時に波紋へ変わって広がる
#   筋         … 物の後ろに引かれたまま、後ろの端から先へ消える
#   土ぼこり   … 連番の絵が欠けて消える（煙玉）
#   手と額     … 供給を止め、手首の側から抜ける

const Stage := preload("res://vfx/esper/esper_stage.gd")
const Aura := preload("res://vfx/esper/esper_aura.gd")
const Waves := preload("res://vfx/esper/esper_waves.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const Ribbon := preload("res://vfx/vfx_ribbon.gd")

const ESPER := Vector3(-3.6, 0.0, 0.6)
const HUB := Vector3(0.5, 2.3, 0.3)           # 渦のまん中
const LIFT := 0.5
const SWIRL := 1.5
const PACK := 3.5
const THROW := 4.3
const TINT := Color(0.5, 0.3, 1.0)
# [小道具, 床の上の場所, 向き]
const ITEMS := [
	["can", Vector3(-1.5, 0, 0.3), 0.3], ["box", Vector3(-0.9, 0, 1.6), 0.4], ["bag", Vector3(-0.6, 0, -1.1), 5.0],
	["basket", Vector3(0.5, 0, -0.6), 1.2], ["reel", Vector3(0.9, 0, 1.9), 1.0], ["fish", Vector3(1.6, 0, 0.9), 2.0],
	["phone", Vector3(2.2, 0, -0.9), 4.0], ["tape", Vector3(2.8, 0, 0.6), 0.5],
]

var _esper: Node3D
var _waves: Node3D
var _things: Array = []          # [物, オーラ, 筋, 通った場所の列, 床の場所, 回る軸, 震えの種, 浮いたか]
var _hands: Array = []           # 両手のオーラ
var _hub: MeshInstance3D         # 念の芯
var _pack: MeshInstance3D        # まとまりのオーラ
var _next_wave := 0.3
var _frame := -1
var _shake := Vector3.ZERO
var _thrown := false
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = origin
	fx.start()
	return fx


func start() -> void:
	life = 6.6
	_rng.seed = 41
	_esper = Stage.figure(self, "03", ESPER, Vector3.RIGHT, "carry_idle")
	_waves = Waves.new()
	_waves.tint = TINT
	_waves.zig = 0.4
	add_child(_waves)
	_waves.arrived.connect(func(_at: Vector3) -> void: _hub.ring(age))
	for row: Array in ITEMS:
		var node: Node3D = Stage.prop(self, row[0], row[1], row[2])
		var aura: MeshInstance3D = Aura.around(self, node, {"tint": TINT})
		aura.visible = false
		var trail: MeshInstance3D = Ribbon.new()
		trail.material_override = Lib.material("psychic_thread", {
			"noise_tex": Lib.noise("soft"), "seed": _rng.randf(), "width": 0.07, "cut": 0.12, "stretch": 0.6,
			"color": Vector3(0.6, 0.42, 1.0), "color_core": Vector3(1.15, 1.1, 1.3), "opacity": 0.0,
		})
		add_child(trail)
		_things.append([node, aura, trail, PackedVector3Array(), node.position, Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), _rng.randf() * 10.0, false])
	for i in 2:
		var glow: MeshInstance3D = Aura.at(self, PackedVector3Array([ESPER]), {"tint": TINT, "pad": 0.06, "amp": 0.04, "teeth": 22.0, "ring_reach": 0.14, "in_front": false, "priority": 0})
		glow.ring_sec = 0.4
		_hands.append(glow)
	_hub = Aura.at(self, PackedVector3Array([HUB]), {"tint": TINT, "pad": 0.05, "amp": 0.05, "jag": 0.8, "teeth": 26.0, "ring_reach": 0.42, "ring_width": 0.016, "warp": 1.4})
	_hub.visible = false
	_pack = Aura.at(self, PackedVector3Array([HUB]), {"tint": TINT, "pad": 0.3, "amp": 0.2, "jag": 0.85, "teeth": 7.0, "rise": 0.2, "split": 0.02, "ring_reach": 2.2, "ring_width": 0.035, "warp": 1.0, "priority": 0})
	_pack.ring_sec = 0.9
	_pack.visible = false
	# 額の「ピキーン」
	var spark := sprite(2, Color(2.6, 2.3, 3.2), 0.1)
	spark.position = Stage.brow(_esper)
	over(0.05, 0.22, func(k: float) -> void:
		spark.scale = Vector3.ONE * lerpf(0.2, 1.1, ease_out(k))
		param(spark, "color", Color(2.6, 2.3, 3.2, 1.0 - k * k)))
	at(0.3, spark.queue_free)
	at(THROW - 0.12, func() -> void: _esper.play("grab", 0.06, true))
	at(THROW, _release)
	at(THROW + 1.1, func() -> void: _esper.play("idle", 0.3))


# その物の、時刻 t での場所と向き
func _where(i: int, t: float) -> Transform3D:
	var row: Array = _things[i]
	var home: Vector3 = row[4]
	var spin_axis: Vector3 = row[5]
	var begin := LIFT + i * 0.09
	var hover := home + Vector3(0, 0.9 + 0.22 * (i % 3), 0)
	var turn := Basis(Vector3.UP, float(ITEMS[i][2]))
	if t < begin:
		return Transform3D(turn, home)
	var up := clampf((t - begin) / 0.8, 0.0, 1.0)
	# 浮く：はじめ速く、行きすぎて少し戻る
	var rise := 1.0 - pow(1.0 - up, 3.0) + 0.12 * sin(up * PI) * (1.0 - up)
	var pos := home.lerp(hover, rise) + Vector3(0, sin(t * 2.3 + i) * 0.04, 0)
	var tumble := (t - begin) * 0.7
	if t >= SWIRL:
		var s := t - SWIRL
		var angle := i * TAU / ITEMS.size() + 1.1 * s + 0.75 * s * s
		var wide := 1.75
		if t >= PACK:
			wide = lerpf(1.75, 0.42, pow(clampf((t - PACK) / (THROW - PACK), 0.0, 1.0), 1.6))
		# 渦の面は、少し手前へ倒す（真横から見ても輪に見える）
		var ring := Basis(Vector3.RIGHT, 0.38) * Vector3(cos(angle), 0.22 * sin(angle * 2.0 + i), sin(angle)) * wide
		pos = pos.lerp(HUB + ring, Stage.ease_io(s / 0.9))
		tumble += s * (1.4 + 0.5 * s)
	return Transform3D(turn * Basis(spin_axis, tumble), pos)


func _tick(delta: float) -> void:
	_waves.tick(age)
	var frame := int(age * 12.0)
	if frame != _frame:
		_frame = frame
		_shake = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 1), _rng.randf_range(-1, 1))
	var centers := PackedVector3Array()
	var pull := clampf((age - PACK) / (THROW - PACK), 0.0, 1.0)
	for i in _things.size():
		var row: Array = _things[i]
		var node: Node3D = row[0]
		var aura: MeshInstance3D = row[1]
		var begin := LIFT + i * 0.09
		var before := node.position
		if not _thrown:
			var xf := _where(i, age)
			# 浮く前は床の上で震え、固まる時も震える
			var tremble := 0.0
			if age < begin:
				tremble = 0.012 * smoothstep(0.1, begin, age)
			elif age >= PACK:
				tremble = 0.03 * pull
			xf.origin += Vector3(_shake.x, absf(_shake.y), _shake.z).rotated(Vector3.UP, row[6]) * tremble
			node.transform = xf
			if age >= begin and not row[7]:
				row[7] = true
				_lift_dust(row[4], node)
		else:
			_fly(i, delta)
		var speed := (node.position - before) / maxf(delta, 0.0001)
		# オーラ：浮く少し前に、下から包む。飛んだ後は、後ろへ抜ける
		var since := age - (begin - 0.12)
		aura.visible = since >= 0.0 and node.visible
		if aura.visible:
			var mid: Vector3 = node.global_transform * (node.get_meta("mid") as Vector3)
			var gone := age - (THROW + 0.25 + i * 0.03)
			aura.p("grip", mid - (Vector3.UP if gone < 0.0 else -speed.normalized()) * aura.radius)
			aura.p("reveal", lerpf(0.0, aura.radius * 3.0 + 1.0, ease_out(clampf(since / 0.35, 0.0, 1.0))))
			aura.p("drain", lerpf(-0.3, aura.radius * 3.0 + 1.0, clampf(gone / 0.3, 0.0, 1.0)) if gone >= 0.0 else -1.0)
			aura.p("trail_world", speed.limit_length(6.0) / 6.0)
			aura.p("amp", lerpf(0.06, 0.16, clampf(speed.length() / 8.0, 0.0, 1.0)))
			aura.place(age, clampf(speed.length() / 5.0, 0.0, 1.0))
		_trail(row, node, speed.length())
		if node.visible:
			centers.append(node.global_transform * (node.get_meta("mid") as Vector3))
	_place_esper()
	_place_hub(centers, pull)


# 通ってきた道すじに、筋を引く（速い時だけ）
func _trail(row: Array, node: Node3D, speed: float) -> void:
	var past: PackedVector3Array = row[3]
	var mid: Vector3 = node.global_transform * (node.get_meta("mid") as Vector3)
	past.insert(0, mid)
	if past.size() > 16:
		past.resize(16)
	row[3] = past
	var trail: MeshInstance3D = row[2]
	var show := clampf((speed - 1.5) / 4.0, 0.0, 1.0)
	trail.visible = show > 0.01 and past.size() >= 4 and node.visible
	if trail.visible:
		trail.draw(past)
		param(trail, "opacity", 0.8 * show)
		param(trail, "phase", -age * 1.5)
		param(trail, "width", lerpf(0.05, 0.11, show))


func _place_esper() -> void:
	var done := age - (THROW + 0.5)
	for i in 2:
		var glow: MeshInstance3D = _hands[i]
		var at_hand := Stage.hand(_esper, "L" if i == 0 else "R")
		glow.move(PackedVector3Array([at_hand]))
		glow.p("grip", at_hand - Vector3.RIGHT * 0.12)
		glow.p("reveal", lerpf(0.0, 0.6, ease_out(clampf(age / 0.15, 0.0, 1.0))))
		glow.p("drain", lerpf(-0.3, 0.6, clampf(done / 0.25, 0.0, 1.0)) if done >= 0.0 else -1.0)
		glow.visible = done < 0.3
		glow.place(age, 0.5)
	# 念波：浮かせている間はゆっくり、固める時は速く
	if age >= _next_wave and age < THROW - 0.1:
		_next_wave = age + (0.22 if age >= PACK else 0.42)
		_waves.send(Stage.hands_mid(_esper), HUB, 0.9, 0.34, 0.1)
		for glow: MeshInstance3D in _hands:
			glow.ring(age)


# 念の芯と、まとまりのオーラ
func _place_hub(centers: PackedVector3Array, pull: float) -> void:
	var grown := clampf((age - SWIRL) / 0.8, 0.0, 1.0)
	_hub.visible = age >= SWIRL - 0.1 and age < THROW
	if _hub.visible:
		_hub.p("pad", lerpf(0.03, 0.13, grown) + 0.1 * pull)
		_hub.p("reveal", 3.0)
		_hub.place(age, 0.4 + 0.6 * pull)
	# まとまり：固まりはじめたら、物ぜんぶを1つの輪郭で包む。放った後は、その場に残って波紋になる
	var since := age - (PACK + 0.25)
	var after := age - THROW
	_pack.visible = since >= 0.0 and after < 1.3
	if not _pack.visible:
		return
	if after < 0.0 and not centers.is_empty():
		_pack.move(centers)
		_pack.p("grip", HUB)
		_pack.p("reveal", lerpf(0.0, 4.0, ease_out(clampf(since / 0.3, 0.0, 1.0))))
		_pack.p("amp", lerpf(0.12, 0.3, pull))
		_pack.p("split", lerpf(0.012, 0.03, pull))
	elif after >= 0.0:
		# 放った：2コマだけ大きくギザギザに弾け、あとは中から抜けて波紋だけが残る
		_pack.p("amp", 0.55 if after < 0.14 else 0.3)
		_pack.p("drain", lerpf(-0.3, 4.0, clampf((after - 0.1) / 0.22, 0.0, 1.0)))
	_pack.place(age, 1.0)


# 浮いた跡：床に土ぼこりの輪
func _lift_dust(home: Vector3, node: Node3D) -> void:
	var size: Vector3 = node.get_meta("size")
	var wide := maxf(size.x, size.z)
	var plan: Array = []
	for j in 6:
		var a := j * TAU / 6.0 + _rng.randf_range(-0.3, 0.3)
		plan.append([_rng.randf_range(0.0, 0.08), Vector3(cos(a), 0.12, sin(a)), wide * 0.5 + _rng.randf_range(0.25, 0.45), _rng.randf_range(0.22, 0.36), _rng.randf_range(0.45, 0.7)])
	var dust: Node3D = Puffs.spawn(self, to_global(home), plan, 1.0)
	dust.recolor(Vector3(0.92, 0.9, 1.0), Vector3(0.6, 0.56, 0.74), Vector3(0.3, 0.26, 0.42))


# 放つ：まとまりが弾ける。放った所に波紋、足もとに土ぼこりの列
func _release() -> void:
	_thrown = true
	for i in _things.size():
		var row: Array = _things[i]
		var node: Node3D = row[0]
		# 扇に開いて飛ぶ：まん中からの向きを少し残す
		var out: Vector3 = (node.position - HUB).normalized()
		var aim := (Vector3(1.0, 0.06, 0.0) + out * 0.3).normalized()
		row.append(aim * _rng.randf_range(13.0, 16.5))
	for n in 3:
		at(THROW + 0.06 + n * 0.09, func() -> void: _pack.ring(age))
	_hub.ring(age)
	var floor_point := to_global(Vector3(HUB.x, 0.0, HUB.z))
	var burst: Array = []
	for j in 12:
		var a := j * TAU / 12.0 + _rng.randf_range(-0.2, 0.2)
		burst.append([_rng.randf_range(0.0, 0.06), Vector3(cos(a), 0.1, sin(a)), _rng.randf_range(1.1, 1.8), _rng.randf_range(0.4, 0.65), _rng.randf_range(0.55, 0.85)])
	# 飛んだ先へ、足もとから順に巻き上がる列
	for j in 9:
		burst.append([0.05 + j * 0.035, Vector3(1.0 + j * 0.9, 0.5, _rng.randf_range(-0.5, 0.5)).normalized(), 1.0 + j * 0.95, _rng.randf_range(0.5, 0.8), _rng.randf_range(0.5, 0.75)])
	var dust: Node3D = Puffs.spawn(self, floor_point, burst, 1.0)
	dust.recolor(Vector3(0.92, 0.9, 1.0), Vector3(0.6, 0.56, 0.74), Vector3(0.3, 0.26, 0.42))


func _fly(i: int, delta: float) -> void:
	var row: Array = _things[i]
	var node: Node3D = row[0]
	if not node.visible or age < THROW + i * 0.03:
		return
	var velocity: Vector3 = row[8]
	velocity.y -= 3.0 * delta
	row[8] = velocity
	node.position += velocity * delta
	node.rotate(row[5], 9.0 * delta)
	if node.position.x > 11.0:
		node.visible = false
