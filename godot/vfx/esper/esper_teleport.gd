extends "res://vfx/vfx_base.gd"
# 超能力：テレポーテーション（瞬間移動）。体が縦の一本線に畳まれて消え、別の場所で線が開いて現れる。続けて2回跳ぶ。
# 参考：『ドラゴンボール』の瞬間移動（「シュン」と線を残して消える）、『X-MEN』ナイトクローラー（消えた所へ空気が流れ込む）、
#       映画『ジャンパー』（跳んだ跡に、空間の傷が少しのあいだ残る）。
# 体を粒にばらしたり、薄れさせたりしない。空間を「畳む・開く」として見せる。
#
# 素材：        畳まれる空間（体は、念の色の平たい影になって線になる）と、流れ込む・押し出される空気（土ぼこり）
# どこから来る： 能力者の額から。額に火花 → 頭から足へオーラが包む
# 先に動く部分： 体の幅（横から畳まれて線になる）
# 遅れて追う部分：線（上下へ抜ける）／流れ込む土ぼこり（消えた所へ寄る）／跡に残る空間の傷（上から閉じる）
# 形の変化（1回ぶん）：
#   0.00 額に火花。オーラが頭から足へ包み、足もとの土ぼこりが体へ寄りはじめる
#   0.26 体が念の色の影になり、横から畳まれて縦の線になる（3コマ）
#   0.38 線が、まん中から上下へ抜ける。跡に、ゆがみの傷が残る
#   0.55 行き先：まん中から上下へ線が走る
#   0.63 線が横に開いて体が現れる（行きすぎて、戻る）。足もとから土ぼこりの輪、輪郭から波紋
#   0.9〜 影の色が体から抜け、オーラが足から頭へ抜ける
# 終わり：
#   消えた側の線 … まん中から上下の端へ抜ける（縮めない）
#   空間の傷     … 上から下へ閉じる。ゆがみが残り、波紋1本になって広がる
#   現れた側のオーラ … 足から頭へ抜ける。波紋は細って切れる
#   土ぼこり     … 連番の絵が欠けて消える

const Stage := preload("res://vfx/esper/esper_stage.gd")
const Aura := preload("res://vfx/esper/esper_aura.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")
const Ribbon := preload("res://vfx/vfx_ribbon.gd")

const TINT := Color(0.35, 0.75, 1.0)
const SPOTS := [Vector3(-3.4, 0, 0.9), Vector3(2.9, 0, -0.7), Vector3(-0.3, 0, 2.0)]
const JUMPS := [0.7, 2.7]             # 跳びはじめる時刻
const FOLD := 0.26                    # 畳みはじめるまで
const LINE := 0.38                    # 線だけになるまで
const LAND := 0.55                    # 行き先に線が走りはじめるまで
const OPEN := 0.63                    # 開きはじめるまで

var _esper: Node3D
var _aura: MeshInstance3D
var _tone: StandardMaterial3D          # 体を念の色の影にする上塗り
var _lines: Array = []                 # 縦の線：[上半分, 下半分]（消える側・現れる側で使い回す）
var _scars: Array = []                 # 空間の傷：[オーラ, 生まれた時刻]
var _tall := 1.7
var _wide := 1.0                       # いまの体の幅（1＝ふつう。畳むと 0.05）
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = origin
	fx.start()
	return fx


func start() -> void:
	life = 5.6
	_rng.seed = 7
	_esper = Stage.figure(self, "09", SPOTS[0], SPOTS[1] - SPOTS[0], "idle")
	_tall = float(_esper.height) + 0.1
	_tone = StandardMaterial3D.new()
	_tone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tone.albedo_color = Color(TINT.r * 0.9 + 0.1, TINT.g * 0.9 + 0.1, TINT.b, 0.0)
	for mesh: MeshInstance3D in _esper.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _tone
	_aura = Aura.at(self, PackedVector3Array([SPOTS[0]]), {"tint": TINT, "pad": 0.38, "jag": 0.5, "amp": 0.09, "warp": 1.4, "ring_reach": 0.7, "ring_width": 0.02})
	_aura.visible = false
	for i in 2:
		var line: MeshInstance3D = Ribbon.new()
		line.material_override = Lib.material("psychic_thread", {
			"noise_tex": Lib.noise("soft"), "seed": 0.3 + i * 0.4, "width": 0.13, "cut": 0.02, "stretch": 0.5,
			"color": Vector3(TINT.r, TINT.g, TINT.b), "color_core": Vector3(1.3, 1.35, 1.4), "opacity": 0.95, "head": 0.0,
		})
		line.visible = false
		add_child(line)
		_lines.append(line)
	for n in JUMPS.size():
		var t: float = JUMPS[n]
		var from: Vector3 = SPOTS[n]
		var to: Vector3 = SPOTS[n + 1]
		at(t, func() -> void: _spark(from))
		at(t + 0.02, func() -> void: _draw_in(from))
		at(t + LINE, func() -> void: _leave(from))
		at(t + LAND, func() -> void: _move(to))
		at(t + OPEN, func() -> void: _arrive(to))


# 行き先へ移す（見えていない間に）。現れる時は、手前（見ている側）を向く
func _move(to: Vector3) -> void:
	_esper.position = to
	_esper.rotation.y = atan2(-to.x, 6.0 - to.z)


func _spark(from: Vector3) -> void:
	var flash := sprite(2, Color(2.2, 3.0, 3.4), 0.1)
	flash.position = from + Vector3(0, _tall * 0.86, 0) + _esper.global_basis.z.normalized() * 0.3
	var born := age
	over(age, 0.2, func(k: float) -> void:
		flash.scale = Vector3.ONE * lerpf(0.2, 1.0, ease_out(k))
		param(flash, "color", Color(2.2, 3.0, 3.4, 1.0 - k * k)))
	at(born + 0.22, flash.queue_free)


# 消える前：足もとの土ぼこりが、体へ寄る（空気が吸い込まれる）
func _draw_in(from: Vector3) -> void:
	for j in 7:
		var a := j * TAU / 7.0 + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var far := _rng.randf_range(1.1, 1.6)
		var dust: Node3D = Puffs.spawn(self, to_global(from + out * far), [[_rng.randf_range(0.0, 0.12), -out + Vector3(0, 0.25, 0), far * 0.85, _rng.randf_range(0.26, 0.4), 0.42]], 1.0)
		dust.rise = 0.0
		dust.recolor(Vector3(0.9, 0.97, 1.0), Vector3(0.55, 0.7, 0.8), Vector3(0.22, 0.36, 0.48))


# 線だけになった：線はまん中から上下へ抜け、跡に空間の傷が残る
func _leave(from: Vector3) -> void:
	var mid := from + Vector3(0, _tall * 0.5, 0)
	var scar: MeshInstance3D = Aura.at(self, PackedVector3Array([mid + Vector3(0, _tall * 0.42, 0), mid - Vector3(0, _tall * 0.42, 0)]),
		{"tint": TINT, "pad": 0.03, "band": 0.01, "amp": 0.035, "jag": 0.2, "teeth": 14.0, "rise": 0.0, "split": 0.02, "warp": 2.2, "ring_reach": 0.9, "ring_width": 0.018})
	scar.p("grip", mid + Vector3(0, _tall * 0.5, 0))
	scar.p("reveal", 9.0)
	_scars.append([scar, age])
	scar.ring(age)


# 現れた：足もとから土ぼこりの輪、輪郭から波紋
func _arrive(to: Vector3) -> void:
	var plan: Array = []
	for j in 10:
		var a := j * TAU / 10.0 + _rng.randf_range(-0.25, 0.25)
		plan.append([_rng.randf_range(0.0, 0.05), Vector3(cos(a), 0.14, sin(a)), _rng.randf_range(0.9, 1.5), _rng.randf_range(0.34, 0.55), _rng.randf_range(0.5, 0.75)])
	var dust: Node3D = Puffs.spawn(self, to_global(to), plan, 1.0)
	dust.recolor(Vector3(0.9, 0.97, 1.0), Vector3(0.55, 0.7, 0.8), Vector3(0.22, 0.36, 0.48))
	_aura.ring(age)
	at(age + 0.1, func() -> void: _aura.ring(age))
	_esper.play("flinch", 0.05, true)
	at(age + 0.7, func() -> void: _esper.play("idle", 0.25))


func _tick(_delta: float) -> void:
	# いまの跳びの番号と、その中での時刻
	var n := -1
	for i in JUMPS.size():
		if age >= float(JUMPS[i]):
			n = i
	var t := age - float(JUMPS[n]) if n >= 0 else -1.0
	var frame := floorf(t * 12.0) / 12.0           # 畳む・開くはコマ打ち
	var wide := 1.0
	var tall := 1.0
	var shade := 0.0
	var shown := true
	if n >= 0:
		if t < FOLD:
			shade = 0.0
		elif t < LINE:
			var k := clampf((frame - FOLD) / (LINE - FOLD), 0.0, 1.0)
			wide = lerpf(1.0, 0.05, k)
			tall = lerpf(1.0, 1.22, k)
			shade = clampf(k * 2.0, 0.0, 1.0)
		elif t < OPEN:
			shown = false
		else:
			var k := clampf((t - OPEN) / 0.28, 0.0, 1.0)
			# 開く：行きすぎて、戻る
			wide = lerpf(0.05, 1.0, 1.0 - pow(1.0 - k, 3.0)) + 0.22 * sin(k * PI) * (1.0 - k)
			tall = lerpf(1.22, 1.0, k)
			shade = 1.0 - smoothstep(0.25, 1.0, clampf((t - OPEN) / 0.5, 0.0, 1.0))
	_esper.visible = shown
	_esper.scale = Vector3(wide, tall, wide)
	_wide = wide
	_tone.albedo_color.a = shade
	_place_aura(n, t)
	_place_lines(n, t)
	_place_scars()


func _place_aura(n: int, t: float) -> void:
	# オーラ：跳ぶ前に頭から足へ包む。現れた後は、足から頭へ抜ける
	_aura.visible = n >= 0 and _esper.visible and t < OPEN + 1.1
	if not _aura.visible:
		return
	var feet := _esper.global_position
	var head := feet + Vector3(0, _tall, 0)
	_aura.move(PackedVector3Array([feet + Vector3(0, 0.34, 0), head - Vector3(0, 0.3, 0)]))
	_aura.p("pad", 0.4 * maxf(_wide, 0.06))
	if t < LINE:
		_aura.p("grip", head)
		_aura.p("reveal", lerpf(0.0, _tall * 1.6, ease_out(clampf(t / 0.22, 0.0, 1.0))))
		_aura.p("drain", -1.0)
	else:
		var gone := t - (OPEN + 0.45)
		_aura.p("grip", feet)
		_aura.p("reveal", 9.0)
		_aura.p("drain", lerpf(-0.3, _tall * 1.6, clampf(gone / 0.45, 0.0, 1.0)) if gone >= 0.0 else -1.0)
	_aura.p("amp", lerpf(0.09, 0.2, clampf(1.0 - absf(t - OPEN - 0.1) / 0.25, 0.0, 1.0)))
	_aura.place(age, 0.8)


# 縦の線：消える側は「まん中から上下へ抜ける」、現れる側は「まん中から上下へ走る」
func _place_lines(n: int, t: float) -> void:
	var leaving := n >= 0 and t >= LINE - 0.04 and t < LINE + 0.16
	var landing := n >= 0 and t >= LAND and t < OPEN + 0.08
	for i in 2:
		var line: MeshInstance3D = _lines[i]
		line.visible = leaving or landing
		if not line.visible:
			continue
		var base: Vector3 = SPOTS[n] if leaving else SPOTS[n + 1]
		var mid := base + Vector3(0, _tall * 0.52, 0)
		var end := mid + Vector3(0, (_tall * 0.62) * (1.0 if i == 0 else -1.0), 0)
		var points := PackedVector3Array()
		for j in 8:
			points.append(mid.lerp(end, j / 7.0))
		line.draw(points)
		if leaving:
			param(line, "head", 1.0)
			param(line, "tail", ease_out(clampf((t - LINE) / 0.14, 0.0, 1.0)) * 0.99)
		else:
			param(line, "head", ease_out(clampf((t - LAND) / 0.07, 0.0, 1.0)))
			param(line, "tail", ease_out(clampf((t - OPEN) / 0.07, 0.0, 1.0)) * 0.99)
		param(line, "phase", age * 2.0)


func _place_scars() -> void:
	var i := 0
	while i < _scars.size():
		var scar: MeshInstance3D = _scars[i][0]
		var since: float = age - float(_scars[i][1])
		if since > 1.5:
			scar.queue_free()
			_scars.remove_at(i)
			continue
		i += 1
		# 上から下へ閉じる。閉じ切る時に、波紋をもう1本
		scar.p("drain", lerpf(-0.2, _tall * 1.3, clampf((since - 0.18) / 0.45, 0.0, 1.0)))
		if since > 0.5 and not scar.has_meta("last"):
			scar.set_meta("last", true)
			scar.ring(age)
		scar.place(age, 0.6)
