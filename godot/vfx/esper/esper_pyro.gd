extends "res://vfx/vfx_base.gd"
# 超能力：パイロキネシス（発火能力）。念で熱し、発火させ、その炎を手もとへ引き寄せて火球にし、投げる。
# 参考：『炎の少女チャーリー』（見つめた物が熱を持ち、燃え上がる）、『鋼の錬金術師』マスタング（離れた所へ火を走らせる）、
#       『NARUTO』などの火球（手もとで育てて放つ）。炎と飛び道具は、このゲームで好評だった部品（vfx_fire / vfx_projectile）を使う。
# 火は能力者が「出す」のではなく、物が「熱せられて燃える」。だから最初に見えるのは火ではなく、熱（ゆらぎ・煙・焦げ）。
#
# 素材：        熱（念で送る）→ 炎（箱馬が燃える）→ 火球（炎を集めた物）→ 爆ぜる火と煙
# どこから来る： 能力者の額と手から念波が箱馬へ。熱は、箱馬の中から外へ出る
# 先に動く部分： 輪郭のゆらぎ（紫 → 橙へ色が変わる）と、細い煙
# 遅れて追う部分：焦げ（色が沈む）→ 炎 → 引き寄せられる火の筋（手もとへ弧を描く）→ 手もとの火球が育つ
# 形の変化：     0.0  額に火花。念波が箱馬へ飛ぶ
#                0.4  箱馬の輪郭がゆらぐ。色が紫から橙へ。細い煙が立ち、箱馬が焦げていく
#                1.5  発火。輪郭の膜は波紋になって抜け、炎が立つ
#                2.4  炎を引く。火の筋が4本、時間をずらして手もとへ弧を描いて飛ぶ。手もとに火球が育つ
#                3.4  元の炎は燃え尽きる（引き抜かれた）。箱馬には焦げと煙が残る
#                3.8  火球を投げる。立て看板の役者に当たり、爆ぜる。看板が倒れ、焦げて、小さく燃える
# 終わり：
#   箱馬の膜   … 発火の瞬間に、波紋になって外へ広がる
#   箱馬の炎   … 引き抜かれて細り、根元から消える（vfx_fire の消え方）。煙は上へ流れて薄れる
#   火の筋     … 手もとの火球へ飛び込む（当たらずに吸われる）
#   火球       … 投げられて飛び去り、着弾で爆ぜる。爆ぜた火は煙に変わる（vfx_explosion の消え方）
#   看板の火   … 小さく燃えて、根元から消える

const Stage := preload("res://vfx/esper/esper_stage.gd")
const Aura := preload("res://vfx/esper/esper_aura.gd")
const Waves := preload("res://vfx/esper/esper_waves.gd")
const Fire := preload("res://vfx/vfx_fire.gd")
const Smoke := preload("res://vfx/vfx_smoke.gd")
const Shot := preload("res://vfx/vfx_projectile.gd")
const Explosion := preload("res://vfx/vfx_explosion.gd")
const Puffs := preload("res://vfx/vfx_toon_puffs.gd")

const ESPER := Vector3(-3.6, 0.0, 0.7)
const FUEL := Vector3(0.2, 0.0, 0.4)           # 燃やす箱馬
const MARK := Vector3(3.9, 0.0, -0.5)          # 的（立て看板の役者）
const HEAT := 0.4
const IGNITE := 1.5
const PULL := 2.4
const THROW := 3.8
const VIOLET := Color(0.5, 0.3, 1.0)
const EMBER := Color(1.0, 0.42, 0.1)

var _esper: Node3D
var _waves: Node3D
var _fuel: Node3D
var _mark: Node3D
var _aura: MeshInstance3D
var _hands: Array = []
var _char: StandardMaterial3D          # 箱馬の焦げ（上塗り）
var _char_mark: StandardMaterial3D     # 看板の焦げ
var _fire: Node3D
var _smoke: Node3D
var _ball: Node3D                      # 手もとの火球
var _ball_size := 0.0
var _next_wave := 0.05
var _hit := -1.0
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = origin
	fx.start()
	return fx


func start() -> void:
	life = 7.8
	_rng.seed = 23
	_esper = Stage.figure(self, "04", ESPER, Vector3.RIGHT, "carry_idle")
	_esper.set_face("angry")
	_fuel = Stage.prop(self, "box", FUEL, 0.5)
	_mark = Stage.prop(self, "standin", MARK, -PI * 0.5)
	_char = _scorch(_fuel)
	_char_mark = _scorch(_mark)
	_waves = Waves.new()
	_waves.tint = VIOLET
	add_child(_waves)
	_waves.arrived.connect(func(_at: Vector3) -> void: _aura.ring(age))
	_aura = Aura.around(self, _fuel, {"tint": VIOLET, "jag": 0.35, "amp": 0.06, "rise": 1.4, "warp": 2.4, "ring_reach": 0.7, "ring_width": 0.02})
	_aura.visible = false
	for i in 2:
		_hands.append(Aura.at(self, PackedVector3Array([ESPER]), {"tint": VIOLET, "pad": 0.06, "amp": 0.04, "teeth": 22.0, "ring_reach": 0.14, "in_front": false, "priority": 0}))
	var spark := sprite(2, Color(3.2, 2.2, 1.4), 0.1)
	spark.position = Stage.brow(_esper)
	over(0.05, 0.22, func(k: float) -> void:
		spark.scale = Vector3.ONE * lerpf(0.2, 1.1, ease_out(k))
		param(spark, "color", Color(3.2, 2.2, 1.4, 1.0 - k * k)))
	at(0.3, spark.queue_free)
	at(HEAT + 0.35, _wisp_smoke)
	at(IGNITE, _ignite)
	at(PULL, func() -> void: _esper.play("grab", 0.1, true))
	for n in 4:
		at(PULL + 0.1 + n * 0.22, _draw_fire)
	at(PULL + 1.0, _burn_out)
	at(THROW - 0.15, func() -> void: _esper.play("grab", 0.05, true))
	at(THROW, _throw)
	at(THROW + 1.4, _relax)


# 元の炎は、引き抜かれて燃え尽きる
func _burn_out() -> void:
	if is_instance_valid(_fire):
		_fire.extinguish()


func _relax() -> void:
	_esper.play("idle", 0.3)
	_esper.set_face("happy")


# 当たった：爆ぜて、看板に小さく火が残る
func _on_hit(pos: Vector3, _dir: Vector3) -> void:
	_hit = age
	Explosion.spawn(self, pos, 1.0, 1.0, false)
	Fire.spawn(self, to_global(MARK + Vector3(0.5, 0.05, 0)), 0.8, 1.6)


# 焦げ：黒い上塗りを、だんだん濃くする
func _scorch(target: Node3D) -> StandardMaterial3D:
	var coat := StandardMaterial3D.new()
	coat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	coat.albedo_color = Color(0.05, 0.03, 0.02, 0.0)
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = coat
	return coat


func _top(target: Node3D) -> Vector3:
	var size: Vector3 = target.get_meta("size")
	return target.global_transform * (target.get_meta("mid") as Vector3) + Vector3(0, size.y * 0.5, 0)


# 熱せられて、細い煙が立つ（発火の前ぶれ）
func _wisp_smoke() -> void:
	var plan: Array = []
	for j in 7:
		plan.append([j * 0.14, Vector3(_rng.randf_range(-0.3, 0.3), 1.0, _rng.randf_range(-0.3, 0.3)), 0.25, _rng.randf_range(0.16, 0.3), 0.9])
	var smoke: Node3D = Puffs.new()
	add_child(smoke)
	smoke.global_position = _top(_fuel)
	smoke.rise = 1.1
	smoke.start(plan, 1.0, Color.WHITE)
	smoke.recolor(Vector3(0.62, 0.6, 0.6), Vector3(0.34, 0.32, 0.33), Vector3(0.12, 0.11, 0.12))


func _ignite() -> void:
	_fire = Fire.spawn(self, to_global(FUEL + Vector3(0, 0.12, 0)), 1.5, -1.0)
	_smoke = Smoke.spawn(self, _top(_fuel) + Vector3(0, 0.9, 0), 0.9, 2.6, true)
	for n in 2:
		at(age + n * 0.1, func() -> void: _aura.ring(age))
	var flash := sprite(2, Color(8.0, 5.0, 2.0), 0.6)
	flash.position = _top(_fuel)
	var born := age
	over(age, 0.12, func(k: float) -> void:
		flash.scale = Vector3.ONE * lerpf(0.6, 2.2, k)
		param(flash, "color", Color(8.0, 5.0, 2.0, 1.0 - k)))
	at(born + 0.13, flash.queue_free)


# 手もとの、火球を育てる場所
func _palm() -> Vector3:
	return Stage.hands_mid(_esper) + Vector3(0.35, 0.45, 0.0)


# 炎を引く：箱馬の炎から、火の筋が手もとへ弧を描いて飛ぶ（当たらずに、火球へ吸われる）
func _draw_fire() -> void:
	var from := _top(_fuel) + Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.3, 0.9), _rng.randf_range(-0.2, 0.2))
	var shot: Node3D = Shot.fire(self, from, _palm(), {
		"palette": "fire", "travel": 0.42, "buildup": 0.0, "ease": "in", "hit": false, "size": 0.55,
		"arc": Vector3(0, _rng.randf_range(0.9, 1.6), _rng.randf_range(-1.2, 1.2)),
	})
	at(age + 0.42, func() -> void: _ball_size += 0.25)
	if _ball == null:
		_build_ball()
	shot.add_to_group("vfx")


func _build_ball() -> void:
	_ball = Node3D.new()
	add_child(_ball)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var shell := MeshInstance3D.new()
	shell.mesh = ball
	shell.material_override = Lib.material("orb", {"noise_texture": Lib.noise("soft"), "color": Color(7, 2.0, 0.25), "speed": 2.2, "cut": 0.36})
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.rotation.x = -PI * 0.5        # 炎の舌を上へ流す
	_ball.add_child(shell)
	var core := MeshInstance3D.new()
	core.mesh = Lib.quad()
	core.material_override = Lib.material("glow", {"shape": 0, "color": Color(10, 8.5, 5), "billboard": true})
	core.scale = Vector3.ONE * 0.55
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 4.0
	light.light_energy = 2.0
	_ball.add_child(light)
	_ball.scale = Vector3.ONE * 0.05


func _throw() -> void:
	if _ball == null:
		return
	var from := _ball.global_position
	_ball.visible = false
	var shot: Node3D = Shot.fire(self, from, to_global(MARK + Vector3(0, 1.0, 0)), {
		"palette": "fire", "travel": 0.5, "buildup": 0.0, "ease": "in", "size": 1.25, "arc": Vector3(0, 1.3, 0.6),
	})
	shot.impacted.connect(_on_hit)


func _tick(_delta: float) -> void:
	_waves.tick(age)
	var heat := clampf((age - HEAT) / (IGNITE - HEAT), 0.0, 1.0)
	# 念波：熱している間だけ
	if age >= _next_wave and age < IGNITE - 0.15:
		_next_wave = age + 0.34
		_waves.send(Stage.hands_mid(_esper), _fuel.global_transform * (_fuel.get_meta("mid") as Vector3), 0.6, 0.3, 0.1)
		for glow: MeshInstance3D in _hands:
			glow.ring(age)
	# 箱馬の膜：紫 → 橙へ。発火で、中から抜けて波紋だけになる
	var since := age - HEAT
	var burst := age - IGNITE
	_aura.visible = since >= 0.0 and burst < 1.0
	if _aura.visible:
		var hue := VIOLET.lerp(EMBER, smoothstep(0.15, 0.85, heat))
		_aura.p("color", Vector3(hue.r, hue.g, hue.b) * 0.95)
		_aura.p("color_core", Vector3(hue.r, hue.g, hue.b).lerp(Vector3(1.0, 0.95, 0.8), 0.6) * lerpf(1.2, 1.6, heat))
		_aura.p("grip", _fuel.global_transform * (_fuel.get_meta("mid") as Vector3))
		_aura.p("reveal", lerpf(0.0, 3.0, ease_out(clampf(since / 0.3, 0.0, 1.0))))
		_aura.p("drain", lerpf(-0.3, 3.0, clampf(burst / 0.25, 0.0, 1.0)) if burst >= 0.0 else -1.0)
		_aura.p("amp", lerpf(0.05, 0.16, heat * heat))
		_aura.place(age, heat)
	_char.albedo_color.a = lerpf(0.0, 0.5, smoothstep(0.3, 1.0, heat)) + 0.3 * clampf((age - IGNITE) / 1.5, 0.0, 1.0)
	# 手：熱している間は紫、炎を引いてからは橙
	var warm := clampf((age - PULL) / 0.4, 0.0, 1.0)
	var done := age - (THROW + 0.3)
	for i in 2:
		var glow: MeshInstance3D = _hands[i]
		var at_hand := Stage.hand(_esper, "L" if i == 0 else "R")
		var hue := VIOLET.lerp(EMBER, warm)
		glow.move(PackedVector3Array([at_hand]))
		glow.p("color", Vector3(hue.r, hue.g, hue.b) * 0.95)
		glow.p("grip", at_hand - Vector3.RIGHT * 0.12)
		glow.p("reveal", lerpf(0.0, 0.6, ease_out(clampf(age / 0.15, 0.0, 1.0))))
		glow.p("drain", lerpf(-0.3, 0.6, clampf(done / 0.25, 0.0, 1.0)) if done >= 0.0 else -1.0)
		glow.visible = done < 0.3
		glow.place(age, 0.5)
	# 火球：火の筋が届くたびに育つ。手もとで小さく揺れる
	if _ball != null and _ball.visible:
		_ball.global_position = _palm() + Vector3(0, sin(age * 5.0) * 0.03, 0)
		var want := 0.12 + 0.62 * minf(_ball_size, 1.0)
		_ball.scale = _ball.scale.lerp(Vector3.ONE * want, 0.18)
	# 看板：当たったら後ろへ倒れ、焦げる
	if _hit >= 0.0:
		var fall := clampf((age - _hit) / 0.45, 0.0, 1.0)
		_mark.rotation.z = -lerpf(0.0, PI * 0.5, fall * fall)
		_char_mark.albedo_color.a = lerpf(0.0, 0.55, clampf((age - _hit) / 0.3, 0.0, 1.0))
