extends Control
## 依頼の掲示板の壁（3D）：ひだのある赤いビロードの布に、依頼のポスターを上の一辺だけ留めて吊るす。下ほど、ぴらぴら揺れる。
##   ・ポスターの絵は 2D で作って（production_hud.gd の _job_card と同じ中身）、小さな画面に描いて 3D の板に貼る
##   ・押せる所は、揺れるポスターの四隅を画面に写して、毎コマ追いかける（透明の押し札）
##   ・マウスを乗せたポスターは、少し手前に出て、大きく揺れる
## ゲームの世界とは別の小さな3Dの場（own_world_3d）で描く。カチンコ（clapper_overlay.gd）と同じ作り
signal picked(index: int)

const POSTER_PX := Vector2i(236, 372)      # ポスターの絵の大きさ（2D）
const POSTER_M := Vector2(1.18, 1.86)      # 3D でのポスターの大きさ（m）
const GAP := 0.32

var make_poster: Callable                  # (index) -> Control：ポスターの絵（2D）を作る
var _view: SubViewport
var _box: SubViewportContainer
var _cam: Camera3D
var _posters := []                         # [{index, mesh, mat, vp, button, hover}]
var _shown: Array = []
var _t := 0.0
var _rig: Node3D                           # カメラと照明（横に動いて、長い壁を見て回る）
var _cloth: MeshInstance3D
var _first := 0                            # いま画面の左端に見えているポスターの番号
const VISIBLE := 4                         # 一度に見える枚数

const SWAY := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D poster : source_color, filter_linear_mipmap;
uniform float phase = 0.0;
uniform float amp = 0.02;
uniform float lift = 0.0;
varying float drop;
void vertex() {
	// UV.y：0＝上の留めた辺、1＝下。下ほど大きく、前後に揺れる（少しねじれも入れる）
	drop = UV.y;
	float d = UV.y * UV.y;
	float w = sin(TIME * 2.1 + phase + UV.y * 2.2) * amp + sin(TIME * 3.7 + phase * 1.7 + UV.x * 3.0) * amp * 0.35;
	VERTEX.z += w * d * 9.0 + lift * d;
	VERTEX.x += sin(TIME * 1.3 + phase) * amp * d * 2.0;
}
void fragment() {
	vec4 c = texture(poster, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.25;
	// 下の端ほど、少し影（布から離れて、反っている感じ）
	ALBEDO *= mix(1.0, 0.86, drop * drop);
}
"""

const VELVET := """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.42, 0.04, 0.06);
uniform vec3 sheen : source_color = vec3(0.95, 0.3, 0.32);
void vertex() {
	// ひだ：横方向の、太さの違う波を重ねる。上は布を吊った所なので、ひだを少し詰める
	float f = sin(VERTEX.x * 3.1) * 0.09 + sin(VERTEX.x * 7.3 + 1.3) * 0.035 + sin(VERTEX.x * 1.2 + TIME * 0.25) * 0.05;
	VERTEX.z += f;
	NORMAL = normalize(vec3(-(cos(VERTEX.x * 3.1) * 0.28 + cos(VERTEX.x * 7.3 + 1.3) * 0.26 + cos(VERTEX.x * 1.2 + TIME * 0.25) * 0.06), 0.0, 1.0));
}
void fragment() {
	// ビロード：正面は暗く、斜めになる所ほど明るい（毛足が光をはね返す）
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = base;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = sheen * rim * 0.35;
}
"""


func _ready() -> void:
	clip_contents = true
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_box.add_child(_view)
	_rig = Node3D.new()
	_view.add_child(_rig)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0, float(VISIBLE) * POSTER_M.x * 1.05 + float(VISIBLE - 1) * GAP + 2.0)
	_cam.fov = 30.0
	_rig.add_child(_cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1a0507")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.85, 0.8)
	env.environment.ambient_light_energy = 0.35
	_view.add_child(env)
	# 上からのスポット（ポスターを照らす）と、正面からの弱い光
	for x: float in [-2.4, 0.0, 2.4]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 3.2, 2.6)
		spot.look_at_from_position(spot.position, Vector3(x, -0.2, 0), Vector3.UP)
		spot.spot_angle = 34.0
		spot.spot_range = 9.0
		spot.light_energy = 3.2
		spot.light_color = Color(1.0, 0.9, 0.75)
		spot.shadow_enabled = true
		_rig.add_child(spot)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.15, 0.0, 0)
	fill.light_energy = 0.35
	_view.add_child(fill)
	# 布
	var cloth := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 7.0)
	plane.orientation = PlaneMesh.FACE_Z
	plane.subdivide_width = 160
	plane.subdivide_depth = 4
	cloth.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = VELVET
	cloth.material_override = mat
	cloth.position = Vector3(0, 0, -0.25)
	_view.add_child(cloth)
	_cloth = cloth


# きょう出ている依頼（index の並び）。変わったときだけ作り直す（作り直したら true）
func show_jobs(indices: Array) -> bool:
	if indices == _shown:
		return false
	_shown = indices.duplicate()
	for p: Dictionary in _posters:
		(p.mesh as Node).queue_free()
		(p.vp as Node).queue_free()
		(p.button as Node).queue_free()
	_posters.clear()
	var n := indices.size()
	var total := float(n) * POSTER_M.x + float(maxi(0, n - 1)) * GAP
	for i in n:
		var index: int = indices[i]
		var vp := SubViewport.new()
		vp.size = POSTER_PX
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var art: Control = make_poster.call(index)
		art.size = Vector2(POSTER_PX)
		vp.add_child(art)
		var mesh := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = POSTER_M
		quad.orientation = PlaneMesh.FACE_Z
		quad.subdivide_width = 6
		quad.subdivide_depth = 18
		mesh.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = SWAY
		mat.set_shader_parameter("poster", vp.get_texture())
		mat.set_shader_parameter("phase", float(i) * 1.9 + 0.4)
		mesh.material_override = mat
		# 上の辺を留める位置。PlaneMesh の UV.y は上が 0
		var x := -total * 0.5 + POSTER_M.x * 0.5 + float(i) * (POSTER_M.x + GAP)
		mesh.position = Vector3(x, 0.05, 0.0)
		mesh.rotation.z = deg_to_rad(float((index * 37) % 5 - 2) * 0.8)
		_view.add_child(mesh)
		# 上の一辺を留める木の桟
		var batten := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(POSTER_M.x + 0.08, 0.07, 0.05)
		batten.mesh = bar
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("5a3a22")
		wood.roughness = 0.8
		batten.material_override = wood
		batten.position = Vector3(0, POSTER_M.y * 0.5 + 0.02, 0.02)
		mesh.add_child(batten)
		# 押し札（透明。揺れるポスターに合わせて動かす）
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.pressed.connect(func(): picked.emit(index))
		add_child(button)
		var entry := {"index": index, "mesh": mesh, "mat": mat, "vp": vp, "button": button, "hover": 0.0}
		button.mouse_entered.connect(func(): entry["over"] = true)
		button.mouse_exited.connect(func(): entry["over"] = false)
		_posters.append(entry)
	# 布は、ポスターの列より左右に広く。最初は左端から見る
	(_cloth.mesh as PlaneMesh).size = Vector2(total + 8.0, 7.0)
	(_cloth.mesh as PlaneMesh).subdivide_width = int((total + 8.0) * 12.0)
	_first = 0
	_rig.position.x = _view_x()
	return true


# 見て回る：dir ＝ −1（左へ）・+1（右へ）。端では止まる
func pan(dir: int) -> void:
	_first = clampi(_first + dir * VISIBLE, 0, maxi(0, _shown.size() - VISIBLE))


func can_pan(dir: int) -> bool:
	return (_first > 0) if dir < 0 else (_first + VISIBLE < _shown.size())


func _view_x() -> float:
	var n := _shown.size()
	var total := float(n) * POSTER_M.x + float(maxi(0, n - 1)) * GAP
	var shown := mini(n, VISIBLE)
	var left := -total * 0.5 + float(_first) * (POSTER_M.x + GAP)
	return left + (float(shown) * POSTER_M.x + float(maxi(0, shown - 1)) * GAP) * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			pan(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			pan(-1)
			accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_rig.position.x = lerpf(_rig.position.x, _view_x(), 1.0 - exp(-delta * 7.0))
	# 引き：見える枚数のポスターが、横いっぱい（少し余白）に入る距離。縦も入りきるように
	if size.y > 0.0:
		var shown := mini(_shown.size(), VISIBLE)
		var span := float(shown) * POSTER_M.x + float(maxi(0, shown - 1)) * GAP + 0.9
		var half_v := tan(deg_to_rad(_cam.fov * 0.5))
		_cam.position.z = maxf((span * 0.5) / (half_v * size.x / size.y), (POSTER_M.y + 0.7) * 0.5 / half_v)
	for p: Dictionary in _posters:
		var over: bool = p.get("over", false)
		p["hover"] = move_toward(float(p["hover"]), 1.0 if over else 0.0, delta * 5.0)
		var h: float = p["hover"]
		var mat: ShaderMaterial = p["mat"]
		mat.set_shader_parameter("amp", lerpf(0.012, 0.032, h))
		mat.set_shader_parameter("lift", h * 0.18)
		var mesh: MeshInstance3D = p["mesh"]
		mesh.position.z = h * 0.22
		# 押し札：ポスターの四隅を画面に写した範囲
		var t: Transform3D = mesh.global_transform
		var corners := [Vector3(-POSTER_M.x * 0.5, POSTER_M.y * 0.5, 0), Vector3(POSTER_M.x * 0.5, POSTER_M.y * 0.5, 0),
			Vector3(-POSTER_M.x * 0.5, -POSTER_M.y * 0.5, 0), Vector3(POSTER_M.x * 0.5, -POSTER_M.y * 0.5, 0)]
		var r := Rect2()
		for k in corners.size():
			var at: Vector2 = _cam.unproject_position(t * (corners[k] as Vector3))
			r = Rect2(at, Vector2.ZERO) if k == 0 else r.expand(at)
		var b: Button = p["button"]
		b.position = r.position
		b.size = r.size
