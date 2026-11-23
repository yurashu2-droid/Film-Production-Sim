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
const HOVER_LOOP := 3.0               # 浮いている揺れが、ひと回りする秒数
const SPEED := 7.5                   # 飛ぶ速さ（m/秒）
const POOL_R := 0.62                 # 目当てを照らす、床の光の輪の半径
const BODY_SCALE := 1.0              # 機体の大きさ（羽根の囲いまで入れて、幅 72cm ほど）
const MODEL := "res://assets/gear/drone/guide_drone.glb"
const EYE := Vector3(0, 0.012, 0.25)          # カメラの目の先（機体の中の場所）。目当てを照らす光は、ここから出る
const PROJECTOR := Vector3(0, -0.1, -0.05)    # 腹の投影機（講師を映す光が出る所）
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
var _throw: MeshInstance3D           # 講師を映す光の筒（真下）
var _spot: MeshInstance3D            # 目当てを照らす光の筒
var _pool: MeshInstance3D            # 目当ての床の光
var _goal := Vector3.INF
var _aim := Vector3.INF
var _aim_k := 0.0
var _t := 0.0
var _yaw := 0.0                      # 機体の向き（首ふりの揺れを足す前）
var _lean := 0.0                     # 進む向きへの傾き（揺れを足す前）


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
	# 機体：ユーザーが Blender で作ったモデル（もとは 遊び場/drone_bot/out/drone_pop.blend。書き出しの手順は assets/gear/drone/SOURCE.md）。
	# 前（大きなカメラの目）が +Z。羽根 4 つ（blades_0〜3）だけ別の物で、回す
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	_body.add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.layers = CREW_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var hub := model.find_child("blades_%d" % i, true, false) as Node3D
		if hub == null:
			continue
		# 回っている羽根のぼけ（うすい円盤）
		var blur := CylinderMesh.new()
		blur.top_radius = 0.092
		blur.bottom_radius = 0.092
		blur.height = 0.003
		var haze := StandardMaterial3D.new()
		haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		haze.albedo_color = Color(1.0, 0.8, 0.3, 0.22)
		_mesh(hub, blur, haze, Vector3(0, 0.004, 0))
		_rotors.append(hub)
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
	# 浮いている揺れ：ユーザーが Blender で付けた動きと同じ式（遊び場/drone_bot/drone_pop.py の hover。3 秒でひと回り）。
	#   横へ 3cm・前後へ 2cm・上下へ 3cm（上下だけ 2 倍の速さ）、前後に 4 度・左右に 5 度かしぎ、首を 9 度ふる。
	#   飛んでいる間は、揺れを小さくする（進む向きへの傾きのほうを見せる）
	var ph := TAU * _t / HOVER_LOOP
	var calm := 1.0 - 0.7 * moving
	_body.position = Vector3(0.03 * sin(ph), 0.03 * sin(2.0 * ph + 0.7), -0.02 * sin(ph + 1.3)) * calm
	var flat := Vector3(vel.x, 0, vel.z)
	if flat.length() > 0.4:
		_yaw = lerp_angle(_yaw, atan2(flat.x, flat.z), clampf(delta * 6.0, 0.0, 1.0))
	elif _aim != Vector3.INF:
		# 止まっている間は、カメラの目を目当てへ向ける
		var see := _aim - global_position
		if Vector2(see.x, see.z).length() > 0.3:
			_yaw = lerp_angle(_yaw, atan2(see.x, see.z), clampf(delta * 4.0, 0.0, 1.0))
	_lean = lerpf(_lean, clampf(flat.length() / SPEED, 0.0, 1.0) * 0.42, clampf(delta * 6.0, 0.0, 1.0))
	_body.rotation = Vector3(_lean - deg_to_rad(4.0) * cos(ph + 1.3) * calm, _yaw + deg_to_rad(9.0) * sin(ph) * calm, deg_to_rad(5.0) * cos(ph) * calm)
	for i in _rotors.size():
		_rotors[i].rotate_object_local(Vector3.UP, delta * (46.0 + 6.0 * float(i % 2)) * (1.0 if i % 2 == 0 else -1.0))
	# 講師を映す光の筒：腹の投影機から、真下の床へ
	var lens: Vector3 = _body.global_transform * PROJECTOR
	_place_cone(_throw, lens, under() + Vector3(0, 0.02, 0))
	_throw.visible = visible
	(_throw.material_override as ShaderMaterial).set_shader_parameter("power", 0.16 * (1.0 - 0.55 * moving))
	# 目当てを照らす：カメラの目から、光の筒と床の光
	var want := 1.0 if _aim != Vector3.INF and visible else 0.0
	_aim_k = lerpf(_aim_k, want, clampf(delta * 7.0, 0.0, 1.0))
	var lit := _aim_k > 0.02 and _aim != Vector3.INF
	_spot.visible = lit
	_pool.visible = lit
	if lit:
		var from: Vector3 = _body.global_transform * EYE
		var floor_at := Vector3(_aim.x, 0.03, _aim.z)
		_place_cone(_spot, from, floor_at)
		(_spot.material_override as ShaderMaterial).set_shader_parameter("power", 0.62 * _aim_k)
		_pool.global_transform = Transform3D(Basis.IDENTITY, floor_at + Vector3(0, 0.01, 0))
		(_pool.material_override as ShaderMaterial).set_shader_parameter("power", _aim_k)


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
