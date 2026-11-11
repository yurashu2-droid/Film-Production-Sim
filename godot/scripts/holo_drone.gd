extends Node3D
## 講師バズ山を映す、小型ドローン（features/day1_guide.gd が使う）。
## 2026-11-11：ホログラムが一人で滑って動くのは変・矢印と長い棒の印も変（ユーザー）なので、作り直した。
##   ・ドローンが先に飛んで行き、下向きの投影機が、床に講師の像を映す（像は、少し遅れてついて来る。動いている間は、像が乱れる）
##   ・目当て（次に使う物・行く場所）は、ドローンの首振りライトが照らす：光の筒と、床の光の輪（輪が外から内へ寄る）。
##     矢印と棒は無い。遠くからは、浮いているドローンと光の筒で場所が分かる
##   参考：舞台のフォロースポット（人が操る追いかけ照明）／通販番組の安い空撮ドローン
## 映画には映らない（制作班にだけ見える層）。当たり判定は無い
const CREW_LAYER := 1 << 11
const BLUE := Color(0.3, 0.7, 1.0)
const HOVER := 1.95                  # 浮く高さ（床から）
const SPEED := 7.5                   # 飛ぶ速さ（m/秒）
const POOL_R := 0.62                 # 目当てを照らす、床の光の輪の半径
const BODY_SCALE := 1.5              # 機体の大きさ（遠くからでも見えるよう、おもちゃより大きめ）
const CONE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float power = 0.5;
void fragment() {
	// 光の筒：ふちは薄く、真ん中を通して見ると濃い。根元（上）が明るく、床へ向かって薄れる。細かいちりが、ゆっくり流れる
	float facing = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	float along = mix(1.0, 0.25, UV.y);
	float dust = 0.82 + 0.18 * sin(UV.y * 38.0 - TIME * 2.2 + UV.x * 12.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(power * facing * along * dust, 0.0, 1.0);
}
"""
const POOL_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float power = 1.0;
void fragment() {
	// 床の光：やわらかい円と、ふちの輪。もう1本の輪が、外から内へ寄ってくる（「ここ」）
	float r = length(UV - vec2(0.5)) * 2.0;
	float disc = smoothstep(1.0, 0.2, r) * 0.22;
	float rim = smoothstep(0.07, 0.0, abs(r - 0.9)) * 0.85;
	float k = fract(TIME * 0.55);
	float pull = smoothstep(0.06, 0.0, abs(r - mix(0.9, 0.25, k))) * (1.0 - k) * 0.8;
	ALBEDO = tint.rgb;
	ALPHA = clamp((disc + rim + pull) * power, 0.0, 1.0) * step(r, 1.0);
}
"""

var moving := 0.0                    # 0＝止まっている 〜 1＝飛んでいる（像の乱れに使う）
var _body: Node3D
var _rotors: Array[Node3D] = []
var _lamp: Node3D                    # 首振りライトの付け根
var _led: MeshInstance3D
var _throw: MeshInstance3D           # 講師を映す光の筒（真下）
var _spot: MeshInstance3D            # 目当てを照らす光の筒
var _pool: MeshInstance3D            # 目当ての床の光
var _goal := Vector3.INF
var _aim := Vector3.INF
var _aim_k := 0.0
var _t := 0.0


func _ready() -> void:
	top_level = true
	_build()


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.layers = CREW_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _flat(color: Color, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color * energy
	return m


func _build() -> void:
	_body = Node3D.new()
	_body.scale = Vector3.ONE * BODY_SCALE
	add_child(_body)
	var shell := _flat(Color(0.93, 0.92, 0.88), 0.45)
	var dark := _flat(Color(0.16, 0.16, 0.18))
	var red := _flat(Color(0.86, 0.17, 0.13), 0.5)
	# 胴：安い白いプラスチックの丸い箱。腹に赤い帯、前に黒い目（カメラ）
	var hull := CapsuleMesh.new()
	hull.radius = 0.085
	hull.height = 0.34
	var hull_mi := _mesh(_body, hull, shell)
	hull_mi.rotation.x = PI * 0.5
	var belt := CylinderMesh.new()
	belt.top_radius = 0.089
	belt.bottom_radius = 0.089
	belt.height = 0.07
	var belt_mi := _mesh(_body, belt, red)
	belt_mi.rotation.x = PI * 0.5
	var eye := SphereMesh.new()
	eye.radius = 0.035
	eye.height = 0.07
	_mesh(_body, eye, dark, Vector3(0, 0.0, 0.165))
	# 腕4本と、回る羽根
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var tip := Vector3(sx * 0.23, 0.03, sz * 0.19)
			var arm := BoxMesh.new()
			arm.size = Vector3(0.035, 0.022, tip.length())
			var arm_mi := _mesh(_body, arm, dark, tip * 0.5)
			arm_mi.rotation.y = atan2(tip.x, tip.z)
			var motor := CylinderMesh.new()
			motor.top_radius = 0.026
			motor.bottom_radius = 0.03
			motor.height = 0.05
			_mesh(_body, motor, shell, tip + Vector3(0, 0.02, 0))
			var hub := Node3D.new()
			hub.position = tip + Vector3(0, 0.052, 0)
			_body.add_child(hub)
			var blade := BoxMesh.new()
			blade.size = Vector3(0.26, 0.004, 0.026)
			_mesh(hub, blade, dark)
			# 回っている羽根のぼけ（うすい円盤）
			var blur := CylinderMesh.new()
			blur.top_radius = 0.13
			blur.bottom_radius = 0.13
			blur.height = 0.003
			var haze := StandardMaterial3D.new()
			haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			haze.albedo_color = Color(0.2, 0.2, 0.22, 0.22)
			_mesh(hub, blur, haze)
			_rotors.append(hub)
	# 足（そり）
	for sx: float in [-1.0, 1.0]:
		var skid := BoxMesh.new()
		skid.size = Vector3(0.014, 0.014, 0.26)
		_mesh(_body, skid, dark, Vector3(sx * 0.1, -0.13, 0))
		for sz: float in [-1.0, 1.0]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.012, 0.07, 0.012)
			_mesh(_body, leg, dark, Vector3(sx * 0.1, -0.095, sz * 0.09))
	# 腹の投影機（青く光る）と、首振りライト
	var lens := SphereMesh.new()
	lens.radius = 0.05
	lens.height = 0.06
	_mesh(_body, lens, _glow(BLUE, 2.4), Vector3(0, -0.085, 0.0))
	_lamp = Node3D.new()
	_lamp.position = Vector3(0, -0.075, 0.12)
	_body.add_child(_lamp)
	var can := CylinderMesh.new()
	can.top_radius = 0.028
	can.bottom_radius = 0.04
	can.height = 0.07
	_mesh(_lamp, can, dark, Vector3(0, -0.03, 0))
	var bulb := SphereMesh.new()
	bulb.radius = 0.034
	bulb.height = 0.04
	_mesh(_lamp, bulb, _glow(Color(0.75, 0.92, 1.0), 2.6), Vector3(0, -0.07, 0))
	# 尻の赤いランプ（ちかちか）
	var dot := SphereMesh.new()
	dot.radius = 0.016
	dot.height = 0.032
	_led = _mesh(_body, dot, _glow(Color(1.0, 0.2, 0.15), 3.0), Vector3(0, 0.03, -0.17))
	# 光の筒と、床の光（どれも、世界の向きのまま置く）
	_throw = _cone(0.03, 0.34, 0.16)
	_spot = _cone(0.04, POOL_R, 0.62)
	var quad := PlaneMesh.new()
	quad.size = Vector2(POOL_R * 2.0, POOL_R * 2.0)
	var pool_mat := ShaderMaterial.new()
	var ps := Shader.new()
	ps.code = POOL_SHADER
	pool_mat.shader = ps
	_pool = _mesh(self, quad, pool_mat)
	_pool.top_level = true
	_pool.visible = false


func _cone(top: float, bottom: float, power: float) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = 1.0
	shape.radial_segments = 28
	shape.rings = 1
	shape.cap_top = false
	shape.cap_bottom = false
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CONE_SHADER
	mat.shader = sh
	mat.set_shader_parameter("power", power)
	var mi := _mesh(self, shape, mat)
	mi.top_level = true
	mi.visible = false
	return mi


# その場所（床）の上へ飛んで行く。now：すぐ、そこに居る
func fly_to(floor_at: Vector3, now: bool = false) -> void:
	_goal = floor_at + Vector3(0, HOVER, 0)
	if now or not is_inside_tree():
		global_position = _goal
		moving = 0.0


# 目当て（床の場所。Vector3.INF なら、照らさない）
func aim(at: Vector3) -> void:
	_aim = at


# ドローンの真下の床（講師の像が立つ所）
func under() -> Vector3:
	return Vector3(global_position.x, global_position.y - HOVER, global_position.z)


func arrived() -> bool:
	return _goal == Vector3.INF or global_position.distance_to(_goal) < 0.25


func _process(delta: float) -> void:
	_t += delta
	var vel := Vector3.ZERO
	if _goal != Vector3.INF:
		var to := _goal - global_position
		var dist := to.length()
		if dist > 0.01:
			# 近づくほど、ゆっくり（止まりぎわに、少し行き過ぎない）
			var step := minf(dist, SPEED * delta * clampf(dist / 1.2, 0.18, 1.0))
			vel = to / dist * (step / maxf(delta, 0.0001))
			global_position += to / dist * step
	moving = lerpf(moving, clampf(vel.length() / SPEED * 1.6, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	# 浮いている揺れ・進む向きへ傾く・羽根が回る
	_body.position = Vector3(0, sin(_t * 2.3) * 0.035 + sin(_t * 5.1) * 0.008, 0)
	var flat := Vector3(vel.x, 0, vel.z)
	if flat.length() > 0.4:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(flat.x, flat.z), clampf(delta * 6.0, 0.0, 1.0))
	_body.rotation.x = lerpf(_body.rotation.x, clampf(flat.length() / SPEED, 0.0, 1.0) * 0.42, clampf(delta * 6.0, 0.0, 1.0))
	_body.rotation.z = sin(_t * 1.7) * 0.03
	for i in _rotors.size():
		_rotors[i].rotation.y += delta * (46.0 + 6.0 * float(i % 2)) * (1.0 if i % 2 == 0 else -1.0)
	_led.visible = fmod(_t, 1.1) < 0.16
	# 講師を映す光の筒：腹の投影機から、真下の床へ
	var lens: Vector3 = _body.global_transform * Vector3(0, -0.11, 0)
	_place_cone(_throw, lens, under() + Vector3(0, 0.02, 0))
	_throw.visible = visible
	(_throw.material_override as ShaderMaterial).set_shader_parameter("power", 0.16 * (1.0 - 0.55 * moving))
	# 目当てを照らす：首振りライトから、光の筒と床の光
	var want := 1.0 if _aim != Vector3.INF and visible else 0.0
	_aim_k = lerpf(_aim_k, want, clampf(delta * 7.0, 0.0, 1.0))
	var lit := _aim_k > 0.02 and _aim != Vector3.INF
	_spot.visible = lit
	_pool.visible = lit
	if lit:
		var from: Vector3 = _lamp.global_transform * Vector3(0, -0.08, 0)
		var floor_at := Vector3(_aim.x, 0.03, _aim.z)
		_place_cone(_spot, from, floor_at)
		(_spot.material_override as ShaderMaterial).set_shader_parameter("power", 0.62 * _aim_k)
		_pool.global_transform = Transform3D(Basis.IDENTITY, floor_at + Vector3(0, 0.01, 0))
		(_pool.material_override as ShaderMaterial).set_shader_parameter("power", _aim_k)
		# ライトの口（下向きの −Y）を、目当てへ向ける
		var d := (floor_at - _lamp.global_position).normalized()
		_lamp.look_at(_lamp.global_position + d, Vector3.FORWARD if absf(d.y) > 0.98 else Vector3.UP)
		_lamp.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# 光の筒を、細い口（from）から広い口（to）へ渡す
func _place_cone(cone: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var d := from - to
	var l := d.length()
	if l < 0.05:
		cone.visible = false
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	cone.global_transform = Transform3D(Basis(x, y * l, z), (from + to) * 0.5)
