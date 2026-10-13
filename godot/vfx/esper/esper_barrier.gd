extends "res://vfx/vfx_base.gd"
# 超能力：サイコバリア（念の壁）。見えない半球が能力者を包み、飛んできた物を弾く。当たった所から六角の波紋が走る。
# 参考：『新世紀エヴァンゲリオン』のA.T.フィールド（当たった所にだけ多角形の波紋が出る、ふだんは見えない壁）、
#       『モブサイコ100』のバリア（半球で受け、最後に押し返す）、SF のシールド（六角の板が順に光る）。
# 壁そのものは見せない。見えるのは「当たった所」と、床との継ぎ目だけ。だから、何度も物を当てて形を分からせる。
#
# 素材：        念の壁（見えない半球）と、当たって弾かれる小道具・土ぼこり
# どこから来る： 能力者の両手から。頭の上から床へ向かって、六角の波が一度走って張られる
# 先に動く部分： 当たった点の閃き（1〜2コマ）
# 遅れて追う部分：六角の波紋（当たった点から、板が順に光りながら走る）／弾かれた物（跳ね返って落ちる）
# 形の変化：     0.3  張る。てっぺんから床へ、六角の波が走る
#                0.9〜2.1  物が1つずつ当たる（右・左・手前）。そのたびに、当たった所から波紋
#                2.7〜3.0  3つ続けて当たる。波紋が重なる
#                3.9  重い砂袋。壁ぜんたいの六角が浮かび上がり、能力者がよろける
#                4.7  押し返す。壁が外へ広がり、六角の板ごとに千切れて消える。床から土ぼこりの輪
# 終わり：
#   波紋       … 当たった点から壁を伝って走り切り、薄れる（戻らない）
#   壁         … 外へ広がりながら、板ごとに千切れて消える（縮めない）
#   弾かれた物 … 床に落ちて止まる（そのまま残る）
#   手の膜     … 手首の側から抜ける

const Stage := preload("res://vfx/esper/esper_stage.gd")
const Aura := preload("res://vfx/esper/esper_aura.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")

const CENTER := Vector3(0.0, 0.0, 0.4)
const RADIUS := 2.1
const RAISE := 0.3
const PUSH := 4.7
const TINT := Color(0.3, 0.95, 0.55)
# [小道具, 飛んでくる元, 当たる時刻, 当たる向き（中心から）]
const THROWS := [
	["fish", Vector3(6.5, 3.2, 1.0), 0.9, Vector3(0.8, 0.5, 0.3)],
	["can", Vector3(-6.5, 2.6, 0.2), 1.5, Vector3(-0.85, 0.45, 0.25)],
	["tape", Vector3(1.5, 3.8, 7.5), 2.1, Vector3(0.2, 0.5, 0.85)],
	["phone", Vector3(6.8, 1.4, 0.2), 2.7, Vector3(0.93, 0.28, 0.2)],
	["reel", Vector3(-5.5, 4.8, 1.5), 2.85, Vector3(-0.5, 0.78, 0.35)],
	["basket", Vector3(0.8, 6.5, 5.5), 3.0, Vector3(0.1, 0.8, 0.58)],
	["bag", Vector3(7.5, 3.4, 1.2), 3.9, Vector3(0.82, 0.48, 0.3)],
]
const FLIGHT := 0.5                    # 飛んでくる時間

var _esper: Node3D
var _dome: MeshInstance3D
var _mat: ShaderMaterial
var _hits: Array = []                  # [向き, 当たった時刻]（6つまで）
var _things: Array = []                # [物, 当たった後の速さ, 当たったか, 床に着いたか, 回る軸]
var _hands: Array = []
var _strain := 0.0
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = origin
	fx.start()
	return fx


func start() -> void:
	life = 6.8
	_rng.seed = 5
	_esper = Stage.figure(self, "02", CENTER, Vector3(0.6, 0, 1.0), "carry_idle")
	_esper.set_face("angry")
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 1.0
	ball.is_hemisphere = true
	ball.radial_segments = 48
	ball.rings = 16
	_dome = MeshInstance3D.new()
	_dome.mesh = ball
	_mat = Lib.material("esper_dome", {
		"noise_tex": Lib.noise("soft"), "color": Vector3(TINT.r, TINT.g, TINT.b), "color_core": Vector3(1.15, 1.35, 1.2),
	})
	_dome.material_override = _mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.position = CENTER
	_dome.scale = Vector3.ONE * RADIUS
	_dome.visible = false
	add_child(_dome)
	for i in 2:
		_hands.append(Aura.at(self, PackedVector3Array([CENTER]), {"tint": TINT, "pad": 0.06, "amp": 0.04, "teeth": 22.0, "ring_reach": 0.14, "in_front": false, "priority": 0}))
	for row: Array in THROWS:
		var node: Node3D = Stage.prop(self, row[0], Vector3.ZERO)
		node.visible = false
		_things.append([node, Vector3.ZERO, false, false, Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()])
	at(RAISE, func() -> void: _strike(Vector3.UP, 0.25))
	at(3.9, func() -> void: _esper.play("flinch", 0.05, true))
	at(4.45, func() -> void: _esper.play("grab", 0.08, true))
	at(PUSH, _push)
	at(PUSH + 1.0, _relax)


func _relax() -> void:
	_esper.play("idle", 0.3)
	_esper.set_face("happy")


# 壁に当たった：その向きから波紋を走らせる
func _strike(toward: Vector3, power: float) -> void:
	_dome.visible = true
	_hits.append([toward.normalized(), age])
	if _hits.size() > 6:
		_hits.pop_front()
	_strain = maxf(_strain, power)
	for glow: MeshInstance3D in _hands:
		glow.ring(age)
	if toward == Vector3.UP:
		return
	var point := CENTER + toward.normalized() * RADIUS
	var flash := sprite(2, Color(2.4, 3.4, 2.8), 0.3)
	flash.position = point
	var born := age
	over(age, 0.12, func(k: float) -> void:
		flash.scale = Vector3.ONE * lerpf(0.3, 1.1 + power, k)
		param(flash, "color", Color(2.4, 3.4, 2.8, 1.0 - k)))
	at(born + 0.13, flash.queue_free)


# 押し返す：壁が外へ広がって千切れる。床から土ぼこりの輪
func _push() -> void:
	_strain = 1.0
	var plan: Array = []
	for j in 16:
		var a := j * TAU / 16.0 + _rng.randf_range(-0.15, 0.15)
		plan.append([_rng.randf_range(0.0, 0.08), Vector3(cos(a), 0.08, sin(a)), _rng.randf_range(2.6, 3.6), _rng.randf_range(0.45, 0.75), _rng.randf_range(0.6, 0.9)])
	var dust: Node3D = Puffs.spawn(self, to_global(CENTER), plan, 1.0)
	dust.recolor(Vector3(0.9, 1.0, 0.94), Vector3(0.55, 0.72, 0.62), Vector3(0.22, 0.4, 0.3))


func _tick(delta: float) -> void:
	# 飛んでくる物：当たるまでは弧を描いて飛び、当たったら跳ね返って床に落ちる
	for i in _things.size():
		var row: Array = _things[i]
		var node: Node3D = row[0]
		var from: Vector3 = THROWS[i][1]
		var when: float = THROWS[i][2]
		var toward: Vector3 = (THROWS[i][3] as Vector3).normalized()
		var point := CENTER + toward * (RADIUS + 0.12)
		var rest: float = node.get_meta("rest")
		if age < when - FLIGHT:
			continue
		node.visible = true
		if age < when:
			var k := (age - (when - FLIGHT)) / FLIGHT
			node.position = from.lerp(point, k) + Vector3(0, sin(k * PI) * 0.5, 0)
			node.rotate(row[4], 8.0 * delta)
		elif not row[2]:
			row[2] = true
			node.position = point
			var speed := (point - from) / FLIGHT
			# 壁の面で跳ね返る（勢いは落ちる）
			row[1] = (speed - 2.0 * speed.dot(toward) * toward) * 0.35 + toward * 2.2
			_strike(toward, 0.75 if THROWS[i][0] == "bag" else 0.3)
		elif not row[3]:
			var velocity: Vector3 = row[1]
			velocity.y -= 12.0 * delta
			row[1] = velocity
			node.position += velocity * delta
			node.rotate(row[4], 5.0 * delta)
			if node.position.y <= rest:
				node.position.y = rest
				row[3] = true
	# 壁
	_strain = move_toward(_strain, 0.0, delta * 1.3)
	var gone := clampf((age - PUSH) / 0.55, 0.0, 1.0)
	if _dome.visible:
		var list := PackedVector4Array()
		for n in 6:
			if n < _hits.size():
				var dir: Vector3 = _hits[n][0]
				list.append(Vector4(dir.x, dir.y, dir.z, age - float(_hits[n][1])))
			else:
				list.append(Vector4(0, 1, 0, -1.0))
		_mat.set_shader_parameter("hits", list)
		_mat.set_shader_parameter("strain", _strain * 0.75)
		_mat.set_shader_parameter("tear", gone)
		_dome.scale = Vector3.ONE * RADIUS * lerpf(1.0, 2.0, ease_out(gone))
		if gone >= 1.0:
			_dome.visible = false
	# 手
	var done := age - (PUSH + 0.4)
	for i in 2:
		var glow: MeshInstance3D = _hands[i]
		var at_hand := Stage.hand(_esper, "L" if i == 0 else "R")
		glow.move(PackedVector3Array([at_hand]))
		glow.p("grip", at_hand - _esper.global_basis.z.normalized() * 0.12)
		glow.p("reveal", lerpf(0.0, 0.6, ease_out(clampf(age / 0.15, 0.0, 1.0))))
		glow.p("drain", lerpf(-0.3, 0.6, clampf(done / 0.25, 0.0, 1.0)) if done >= 0.0 else -1.0)
		glow.visible = done < 0.3
		glow.place(age, _strain)
