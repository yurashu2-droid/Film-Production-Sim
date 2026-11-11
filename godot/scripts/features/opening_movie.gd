extends Node
## 1日目の最初のムービー（docs/production/tutorial-cm.md）：怪しい情報商材の広告のパロディ。約20秒。
##   「あなたの会社、バズってますか？」→ 成功者の声（段ボールの豪邸）→「今なら100万コイン！」→ 購入のボタンを押す → 暗転。
##   終わると、いつものゲームの画面（事務所の前）になり、少しして宅配の箱が落ちてくる（features/delivery_box.gd）。
## 役目は「なぜ箱が届くのか・なぜお金が無いのか」を先に見せること。操作は教えない（教えるのは、そのあとの講師）。
## 動画ファイルではなく、ゲームの中の物（キャラ・段ボール箱）とカメラで組む。自分だけの小さな世界（SubViewport）に並べて、
## 事務所に置いてある古いブラウン管テレビ（粗大ごみ置き場のテレビと同じ作り）の画面に映す（2026-11-12 ユーザーの案）。
##   ・流している間は、テレビの画面が視界いっぱいになる所にカメラを置く（走査線・にじみ・たる型のゆがみ。左右は黒い帯）
##   ・終わると（飛ばしても）、ぱっと切り替えず、カメラが引いていって「テレビの画面だった」と分かり、そのまま自分の視点につながる
##   ・テレビは、いつも事務所に置いてある（全員の画面。当たり判定あり。物としては持てない）。流し終えると、砂嵐になって、消える
##   ・流すのは、会社を開いた人（ホスト・ひとり遊び）の画面だけ。あとから入った人には流さない
##   ・流れている間は動けない（game.input_locked）。Enter・Space・Esc・クリックで、いつでも飛ばせる
##   ・ふつうに遊ぶときの1日目だけ（自動確認の中では流さない。確認は start() で始める）。倒産してやり直すときは、流さない
const CastVisual := preload("res://scripts/cast_visual.gd")
const Carton := preload("res://scripts/carton.gd")
const LAYER := 60                    # ゲームの画面の案内より上、タイトルからの切り替え（100）より下
# 場面（始まる秒・名前）。最後の "black" が終わると、ムービーも終わる
const SHOTS := [[0.0, "hook"], [5.0, "voice"], [10.5, "price"], [15.5, "buy"], [20.0, "black"]]
const END_SEC := 21.0
const PRESENTER := "06"              # 講師バズ山（宅配の箱から出てくる講師と同じ顔）
const WINNER := "01"                 # 成功者 Aさん（仮名）
const YELLOW := Color(1.0, 0.88, 0.2)
const RED := Color(0.9, 0.16, 0.12)
const INK := Color(0.12, 0.08, 0.05)
const CARDBOARD := Color(0.72, 0.55, 0.36)
const Look := preload("res://scripts/production_look.gd")
const Dump := preload("res://scripts/dump_dressing.gd")
const TV_AT := Vector3(70.75, 0.0, 3.5)      # テレビを置く所（事務所の中。起きた所から見て、左前。体の陰にならない所）
const TV_YAW := 0.23                         # 画面が、起きた所の後ろの視点のほうを向く
const TV_STAND := 0.36                       # テレビを載せる木箱の高さ
const GLASS := Vector2(0.46, 0.34)           # 画面のガラスの大きさ（dump_dressing.gd の crt_tv と同じ）
const GLASS_AT := Vector3(0.0, 0.33, 0.243)  # 画面のガラスのまん中（テレビから見て）
const PULL_SEC := 1.5                        # カメラが引いていく秒数
const SNOW_SEC := 5.0                        # 流し終えてから、砂嵐が出ている秒数
const CRT_SHADER := """shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D pic : source_color, filter_linear, repeat_disable;
uniform float mode = 0.0;      // 0＝消えている / 1＝番組 / 2＝砂嵐
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	// たる型のゆがみ（ガラスのふくらみ）
	vec2 c = UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	vec2 uv = (c * (1.0 + 0.09 * r2) / 1.09) * 0.5 + 0.5;
	vec3 col = vec3(0.03, 0.045, 0.045);
	if (mode > 1.5) {
		float n = rnd(floor(uv * vec2(240.0, 180.0)) + floor(TIME * 24.0) * 7.3);
		col = vec3(0.12 + 0.75 * n);
	} else if (mode > 0.5) {
		// 色のずれ（赤と青を、左右へ少しずらす）
		col.r = texture(pic, uv + vec2(0.003, 0.0)).r;
		col.g = texture(pic, uv).g;
		col.b = texture(pic, uv - vec2(0.003, 0.0)).b;
		col = (col - 0.5) * 1.1 + 0.52;
		col *= vec3(1.04, 1.0, 0.93);
		col += (rnd(uv * 400.0 + TIME) - 0.5) * 0.05;
	}
	if (mode > 0.5) {
		// 走査線・ゆっくり流れる明るい帯・四隅の暗さ
		col *= 0.8 + 0.2 * pow(sin(uv.y * 240.0 * 3.14159), 2.0);
		col *= 1.0 + 0.06 * sin(uv.y * 6.0 - TIME * 2.4);
		col *= clamp(1.12 - 0.42 * r2, 0.0, 1.0);
	}
	// 角の丸み
	vec2 q = abs(c) - vec2(0.80);
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float corner = smoothstep(0.2, 0.17, edge);
	ALBEDO = col * corner;
}
"""

var game: Node
var playing := false
var t := 0.0                         # 流し始めてからの秒数
var shot := ""                       # いまの場面の名前
var _held := true                    # タイトルからの切り替えが済むのを待っている
var _layer: CanvasLayer
var _bg: ColorRect
var _box: SubViewportContainer
var _view: SubViewport
var _cam: Camera3D
var _host3d: Node3D
var _presenter: Node3D
var _winner: Node3D
var _mansion: Node3D
var _ui: Control
var _groups := {}                    # 場面の名前 → その場面の字や絵（Control）
var _size := Vector2(1280, 720)
var _k := 1.0                        # 字の大きさの倍率（画面の高さ 720 を 1 とする）
var _burst: Node2D
var _cursor: Node2D
var _button: Panel
var _clicked := false
var _wave_t := 0.0
var tv: Node3D                       # 事務所のテレビ（いつも置いてある）
var _glass: MeshInstance3D           # 画面のガラス
var _crt: ShaderMaterial
var _screen: SubViewport             # 番組の絵（4:3）
var _world: SubViewport              # テレビの前のカメラが見た絵（ゲームの世界を、もう1つの窓で描く）
var _pull: Camera3D
var _bars: Array[ColorRect] = []     # 流している間、左右を隠す黒い帯
var _pulling := false                # カメラが引いている途中
var _pull_t := 0.0
var _from := Transform3D.IDENTITY
var _snow := 0.0                     # 砂嵐の残り秒数


func setup() -> void:
	_build_tv()
	var flow: Node = game.production
	# 会社を開いた人の、ふつうに遊ぶ1日目の始まりだけ。倒産してやり直す会社（家賃を払った事がある・評判が動いた）は除く
	if flow != null and bool(flow.daily) and int(flow.day) <= 1 and int(flow.phase) == 0 and Net.is_host() and not bool(flow.get("bankrupt")):
		start()


# ムービーを始める（確認では、ここを呼ぶ）
func start() -> void:
	if playing:
		return
	_build()
	playing = true
	_held = true
	t = 0.0
	shot = ""
	_clicked = false
	_layer.visible = true
	_enter("hook")


func _process(delta: float) -> void:
	if not playing:
		return
	_fit()
	if _held:
		# タイトルからの切り替えが画面を覆っている間は、始めない（最初の絵のまま待つ）
		if not bool(game.get("startup_complete")) or bool(game.get("input_locked")):
			return
		_held = false
		game.input_locked = true
		shot = ""              # 最初の場面の字の出方を、ここからやり直す
	# 動けない印は、依頼の状態が届くたびに戻される（production_flow.gd）ので、流している間は毎コマ立て直す
	game.input_locked = true
	t += delta
	var now := ""
	for row: Array in SHOTS:
		if t >= float(row[0]):
			now = str(row[1])
	if _pulling:
		_pull_step(delta)
		return
	if now != shot:
		_enter(now)
	_animate(delta)
	if t >= END_SEC:
		finish()


func _input(event: InputEvent) -> void:
	if not playing or _held or _pulling:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo:
		skip = (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]
	elif event is InputEventMouseButton and event.pressed:
		skip = (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventJoypadButton and event.pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		finish()


# ムービーを終える（最後まで流れた・飛ばした）。ゲームの画面へ戻して、動けるようにする
func finish() -> void:
	if not playing or _pulling:
		return
	var me: Node = game.local_player()
	if _held or me == null or not (me.get("cam") is Camera3D) or DisplayServer.get_name() == "headless":
		_done()
		return
	# カメラが引いていく。テレビは、番組を映したまま
	_pulling = true
	_pull_t = 0.0
	_from = _pull.global_transform


# 引き終えた（か、引かずに終える）：ゲームの画面へ戻して、動けるようにする。テレビは砂嵐になる
func _done() -> void:
	playing = false
	_pulling = false
	shot = ""
	if not _held:
		game.input_locked = false
	_snow = SNOW_SEC
	_crt.set_shader_parameter("mode", 2.0)
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_groups = {}


func _pull_step(delta: float) -> void:
	var me: Node = game.local_player()
	var goal: Camera3D = me.cam if me != null else null
	if goal == null:
		_done()
		return
	_pull_t += delta / PULL_SEC
	var k := clampf(_pull_t, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	_pull.global_transform = _from.interpolate_with(goal.global_transform, e)
	_pull.fov = goal.fov
	for bar: ColorRect in _bars:
		bar.modulate.a = 1.0 - clampf(k * 3.0, 0.0, 1.0)
	(_layer.get_node("SkipHint") as CanvasItem).modulate.a = 1.0 - clampf(k * 4.0, 0.0, 1.0)
	if k >= 1.0:
		_done()


# 流している間のカメラ：テレビの画面が、視界の高さいっぱいになる所
func _fit() -> void:
	var real: Vector2 = get_viewport().get_visible_rect().size
	_world.size = Vector2i(real)
	var me: Node = game.local_player()
	var centre: Vector3 = _glass.global_position
	if me != null and not _pulling and me.get("cam") is Camera3D:
		_pull.fov = (me.cam as Camera3D).fov
	if not _pulling:
		var out: Vector3 = _glass.global_basis.z.normalized()
		var dist := (GLASS.y * 0.5) / tan(deg_to_rad(_pull.fov) * 0.5)
		_pull.global_transform = Transform3D(Basis.IDENTITY, centre + out * dist).looking_at(centre, Vector3.UP)
	# 左右の黒い帯（画面は 4:3。その外に、テレビの箱が見えないように）
	var side := maxf(0.0, (real.x - real.y * GLASS.x / GLASS.y) * 0.5) + 2.0
	_bars[0].size = Vector2(side, real.y)
	_bars[1].position = Vector2(real.x - side, 0.0)
	_bars[1].size = Vector2(side, real.y)


# 事務所のテレビ（木箱の上）。全員の画面に、いつも置いてある。物の番号は使わない（持てない・当たり判定だけ）
func _build_tv() -> void:
	tv = Node3D.new()
	tv.name = "OfficeTv"
	game.add_child(tv)
	tv.global_transform = Transform3D(Basis(Vector3.UP, TV_YAW), TV_AT)
	var b := Look.Batch.new()
	b.xf = Transform3D.IDENTITY
	var crate := Transform3D(Basis.IDENTITY, Vector3(0, TV_STAND * 0.5, -0.02))
	b.box(Look.mat("wood", Color("8a6a48")), crate, Vector3(0.74, TV_STAND, 0.5), Look.Batch.ALL)
	b.solid(crate, Vector3(0.74, TV_STAND, 0.5))
	Dump.crt_tv(b, Transform3D(Basis.IDENTITY, Vector3(0, TV_STAND, 0)), false)
	b.build(tv, "OfficeTvBody")
	_glass = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = GLASS
	_glass.mesh = quad
	var sh := Shader.new()
	sh.code = CRT_SHADER
	_crt = ShaderMaterial.new()
	_crt.shader = sh
	_glass.material_override = _crt
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tv.add_child(_glass)
	_glass.position = GLASS_AT + Vector3(0, TV_STAND, 0)


func _physics_process(delta: float) -> void:
	# 流し終えたあとの砂嵐は、しばらくすると消える
	if _snow > 0.0:
		_snow -= delta
		if _snow <= 0.0 and not playing:
			_crt.set_shader_parameter("mode", 0.0)


# ---- 組み立て ----

func _build() -> void:
	if _layer != null:
		_layer.queue_free()
	_groups = {}
	# 番組の絵は、960x720（4:3）の画面として組んで、テレビの画面に映す
	_size = Vector2(960, 720)
	_k = 0.8                  # もとは横長（1280x720）で組んだ字。4:3 に収まるよう、少し小さくする
	_layer = CanvasLayer.new()
	_layer.name = "OpeningMovieScreen"
	_layer.layer = LAYER
	add_child(_layer)
	_screen = SubViewport.new()
	_screen.size = Vector2i(_size)
	_screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_layer.add_child(_screen)
	_crt.set_shader_parameter("pic", _screen.get_texture())
	_crt.set_shader_parameter("mode", 1.0)
	_snow = 0.0
	# テレビの前のカメラが見た絵を、画面いっぱいに出す（ゲームの世界を、もう1つの窓で描く。案内の札は、この下に隠れる）
	_world = SubViewport.new()
	_world.world_3d = game.get_viewport().find_world_3d()
	_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_layer.add_child(_world)
	_pull = Camera3D.new()
	_world.add_child(_pull)
	_pull.current = true
	var shown := TextureRect.new()
	shown.texture = _world.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(shown)
	_bars = []
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.025)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
		_bars.append(bar)
	_pulling = false
	# 通販番組のような、明るい色の背景
	_bg = ColorRect.new()
	_bg.color = Color(1.0, 0.72, 0.2)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_bg)
	var rays := Node2D.new()
	rays.position = _size * 0.5
	rays.name = "Rays"
	_bg.add_child(rays)
	for i in 14:
		var a := TAU * float(i) / 14.0
		var wedge := Polygon2D.new()
		wedge.polygon = PackedVector2Array([Vector2.ZERO, Vector2(cos(a - 0.11), sin(a - 0.11)) * 2400.0, Vector2(cos(a + 0.11), sin(a + 0.11)) * 2400.0])
		wedge.color = Color(1, 1, 1, 0.16)
		rays.add_child(wedge)
	# キャラと段ボールの豪邸を並べる、自分だけの小さな世界
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_box.add_child(_view)
	_host3d = Node3D.new()
	_view.add_child(_host3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.9)
	e.ambient_light_energy = 0.75
	env.environment = e
	_host3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0.0)
	sun.light_energy = 1.1
	_host3d.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_host3d.add_child(_cam)
	_presenter = _person(PRESENTER)
	_winner = _person(WINNER)
	_mansion = _build_mansion()
	_host3d.add_child(_mansion)
	# 字と絵（場面ごとの組）
	_ui = Control.new()
	_ui.size = _size
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_ui)
	_build_hook()
	_build_voice()
	_build_price()
	_build_buy()
	_build_black()
	# 飛ばし方の案内は、テレビの外（画面の右下。小さく、ふち無し）
	var skip := Label.new()
	skip.name = "SkipHint"
	skip.text = "Enter・クリックで とばす"
	skip.add_theme_font_override("font", game.font)
	skip.add_theme_font_size_override("font_size", 15)
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -22
	skip.offset_bottom = -16
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(skip)


func _person(tag: String) -> Node3D:
	var root := Node3D.new()
	_host3d.add_child(root)
	var vis: Node3D = CastVisual.new()
	vis.name = "Look"
	root.add_child(vis)
	vis.setup(tag)
	return root


# 段ボールの豪邸：箱を5つ積んで、板の屋根と、描いた玄関
func _build_mansion() -> Node3D:
	var root := Node3D.new()
	root.name = "Mansion"
	var w := 0.98
	var h := 0.72
	for spec: Array in [[-w, 0.0], [0.0, 0.0], [w, 0.0], [-w * 0.5, h], [w * 0.5, h]]:
		var carton: Node3D = Carton.closed_model(2.3)
		carton.position = Vector3(float(spec[0]), float(spec[1]), 0.0)
		root.add_child(carton)
	var board := StandardMaterial3D.new()
	board.albedo_color = CARDBOARD
	board.roughness = 0.95
	board.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0, 1.0]:
		var roof := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.35, 0.9)
		roof.mesh = q
		roof.material_override = board
		roof.position = Vector3(side * 0.56, h * 2.0 + 0.36, 0.0)
		roof.transform.basis = Basis(Vector3(0, 0, 1), side * -0.6) * Basis(Vector3(1, 0, 0), -PI * 0.5)
		root.add_child(roof)
	var door := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.34, 0.52)
	door.mesh = dq
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.13, 0.08)
	door.material_override = dark
	door.position = Vector3(0.0, 0.27, 0.37)
	root.add_child(door)
	return root


# ---- 字と絵の部品 ----

# 画面の (cx, cy)（0〜1）を真ん中にした字
func _text(parent: Node, words: String, font_size: int, color: Color, outline: Color, at: Vector2, outline_px: int = 8) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_override("font", game.font)
	label.add_theme_font_size_override("font_size", int(font_size * _k))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", int(outline_px * _k))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := words.count("\n") + 1
	label.size = Vector2(_size.x, font_size * _k * 1.45 * lines)
	label.position = Vector2((at.x - 0.5) * _size.x, at.y * _size.y - label.size.y * 0.5)
	label.pivot_offset = label.size * 0.5
	parent.add_child(label)
	return label


# ぎざぎざの丸（通販番組の「衝撃！」の札・背景の光の筋）
func _starburst(radius: float, points: int, color: Color, depth: float = 0.22) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := radius * (1.0 if i % 2 == 0 else 1.0 - depth)
		var a := TAU * float(i) / float(points * 2)
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	poly.color = color
	return poly


func _group(gname: String) -> Control:
	var g := Control.new()
	g.name = gname
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.visible = false
	_ui.add_child(g)
	_groups[gname] = g
	return g


# 帯（字の下に敷く色の板）
func _band(parent: Node, at: Vector2, size: Vector2, color: Color, tilt: float = 0.0) -> ColorRect:
	var band := ColorRect.new()
	band.color = color
	band.size = size * _size
	band.position = at * _size - band.size * 0.5
	band.pivot_offset = band.size * 0.5
	band.rotation = tilt
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(band)
	return band


func _build_hook() -> void:
	var g := _group("hook")
	_band(g, Vector2(0.5, 0.19), Vector2(1.1, 0.27), RED, -0.02)
	_text(g, "あなたの会社、\nバズってますか？", 62, YELLOW, INK, Vector2(0.5, 0.19), 14).name = "Title"
	_burst = _starburst(86.0 * _k, 14, YELLOW)
	_burst.position = Vector2(0.12, 0.47) * _size
	g.add_child(_burst)
	var shock := _text(_burst, "衝撃！", 34, RED, Color.WHITE, Vector2(0.5, 0.5), 6)
	shock.position = -shock.size * 0.5
	_band(g, Vector2(0.73, 0.8), Vector2(0.42, 0.09), INK)
	_text(g, "バズの伝道師　講師 バズ山", 26, Color.WHITE, INK, Vector2(0.73, 0.8), 0)


func _build_voice() -> void:
	var g := _group("voice")
	_band(g, Vector2(0.17, 0.1), Vector2(0.3, 0.11), RED, -0.03)
	_text(g, "成功者の声", 40, Color.WHITE, INK, Vector2(0.17, 0.1), 8)
	_band(g, Vector2(0.5, 0.8), Vector2(0.86, 0.15), Color(1, 1, 1, 0.94))
	_text(g, "「この教材で、段ボールの豪邸が建ちました」", 34, INK, Color.WHITE, Vector2(0.5, 0.775), 0).name = "Quote"
	_text(g, "元・会社員　Aさん（仮名）", 22, RED, Color.WHITE, Vector2(0.5, 0.845), 0)
	_text(g, "※個人の感想です", 15, INK, Color(1, 1, 1, 0.8), Vector2(0.88, 0.9), 3)


func _build_price() -> void:
	var g := _group("price")
	_text(g, "通常 300万コイン", 40, Color(0.35, 0.3, 0.25), Color.WHITE, Vector2(0.64, 0.2), 6).name = "Was"
	var strike := _band(g, Vector2(0.64, 0.2), Vector2(0.36, 0.012), RED, -0.06)
	strike.name = "Strike"
	var now := _starburst(210.0 * _k, 18, RED)
	now.name = "NowBurst"
	now.position = Vector2(0.64, 0.5) * _size
	g.add_child(now)
	var words := _text(now, "今なら\n100万コイン！", 50, YELLOW, INK, Vector2(0.5, 0.5), 12)
	words.position = -words.size * 0.5
	_text(g, "※効果には個人差があります。たぶん", 15, INK, Color(1, 1, 1, 0.8), Vector2(0.8, 0.9), 3)


func _build_buy() -> void:
	var g := _group("buy")
	var page := _band(g, Vector2(0.5, 0.5), Vector2(1.0, 1.0), Color(0.95, 0.95, 0.93))
	page.name = "Page"
	_band(g, Vector2(0.5, 0.06), Vector2(1.0, 0.12), Color(0.2, 0.22, 0.28))
	_text(g, "バズ山ストア　ご注文の確認", 24, Color.WHITE, INK, Vector2(0.22, 0.06), 0)
	_band(g, Vector2(0.5, 0.45), Vector2(0.62, 0.52), Color.WHITE)
	_text(g, "絶対バズる！\n会社紹介動画メソッド", 38, INK, Color.WHITE, Vector2(0.5, 0.3), 0)
	_text(g, "（DVD・投影機つき）", 20, Color(0.4, 0.4, 0.4), Color.WHITE, Vector2(0.5, 0.41), 0)
	_text(g, "1,000,000 コイン（代金引換）", 34, RED, Color.WHITE, Vector2(0.5, 0.5), 0)
	_button = Panel.new()
	_button.name = "BuyButton"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.68, 0.32)
	style.set_corner_radius_all(int(14 * _k))
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = int(8 * _k)
	_button.add_theme_stylebox_override("panel", style)
	_button.size = Vector2(0.3, 0.11) * _size
	_button.position = Vector2(0.5, 0.63) * _size - _button.size * 0.5
	_button.pivot_offset = _button.size * 0.5
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(_button)
	var buy := _text(_button, "購入する", 36, Color.WHITE, Color(0.08, 0.3, 0.14), Vector2(0.5, 0.5), 6)
	buy.position = (_button.size - buy.size) * 0.5
	var thanks := _text(g, "ご注文、ありがとうございます！", 44, RED, Color.WHITE, Vector2(0.5, 0.82), 10)
	thanks.name = "Thanks"
	thanks.visible = false
	# マウスの矢印（白い矢印に黒いふち）
	_cursor = Node2D.new()
	_cursor.name = "Cursor"
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(0, 30), Vector2(8, 23), Vector2(14, 36), Vector2(19, 34), Vector2(13, 21), Vector2(23, 21)])
	var fill := Polygon2D.new()
	fill.polygon = shape
	fill.color = Color.WHITE
	_cursor.add_child(fill)
	var edge := Line2D.new()
	edge.points = shape
	edge.closed = true
	edge.width = 2.5
	edge.default_color = Color.BLACK
	_cursor.add_child(edge)
	_cursor.scale = Vector2.ONE * 1.6 * _k
	g.add_child(_cursor)


func _build_black() -> void:
	var g := _group("black")
	_band(g, Vector2(0.5, 0.5), Vector2(1.0, 1.0), Color.BLACK)


# ---- 場面の切り替えと動き ----

func _pop(node: CanvasItem, delay: float = 0.0, sec: float = 0.28) -> void:
	node.scale = Vector2.ONE * 0.2
	node.modulate.a = 0.0
	if not is_inside_tree():
		node.scale = Vector2.ONE
		node.modulate.a = 1.0
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, sec).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, sec * 0.5).set_delay(delay)


func _enter(next: String) -> void:
	shot = next
	for gname: String in _groups:
		(_groups[gname] as Control).visible = gname == next
	var g: Control = _groups.get(next)
	_box.visible = next in ["hook", "voice", "price"]
	_bg.color = Color(1.0, 0.72, 0.2) if next != "voice" else Color(0.55, 0.82, 1.0)
	_presenter.visible = next in ["hook", "price"]
	_winner.visible = next == "voice"
	_mansion.visible = next == "voice"
	match next:
		"hook":
			_presenter.position = Vector3(1.0, 0.0, 0.0)
			_presenter.rotation.y = -0.3
			_cam.position = Vector3(0.0, 1.8, 5.4)
			_cam.rotation = Vector3.ZERO
			_wave(_presenter, "ORDER")
			_pop(g.get_node("Title"), 0.15)
			_pop(_burst, 0.9)
			Sfx.play("whoosh", null, -6.0)
		"voice":
			_winner.position = Vector3(1.45, 0.0, 0.9)
			_winner.rotation.y = -0.45
			_mansion.position = Vector3(-0.75, 0.0, -0.6)
			_mansion.rotation.y = 0.28
			_cam.position = Vector3(0.2, 1.5, 5.6)
			_cam.rotation = Vector3(-0.05, 0.0, 0.0)
			_wave(_winner, "GREETING")
			_pop(g.get_node("Quote"), 0.6)
			Sfx.play("ui_select", null, -4.0)
		"price":
			_presenter.position = Vector3(-1.35, 0.0, 0.0)
			_presenter.rotation.y = 0.35
			_cam.position = Vector3(0.0, 1.45, 4.9)
			_cam.rotation = Vector3.ZERO
			_wave(_presenter, "ORDER")
			_pop(g.get_node("Was"), 0.1)
			var strike: ColorRect = g.get_node("Strike")
			strike.scale = Vector2(0.0, 1.0)
			if is_inside_tree():
				create_tween().tween_property(strike, "scale:x", 1.0, 0.25).set_delay(1.0)
			else:
				strike.scale = Vector2.ONE
			_pop(g.get_node("NowBurst"), 1.6, 0.35)
			Sfx.play("whoosh", null, -6.0)
			if is_inside_tree():
				create_tween().tween_callback(Sfx.play.bind("success_fanfare", null, -6.0)).set_delay(1.6)
		"buy":
			_cursor.position = Vector2(0.86, 0.9) * _size
			_button.scale = Vector2.ONE
			(g.get_node("Thanks") as Label).visible = false
			_clicked = false
			Sfx.play("ui_open", null, -4.0)
		"black":
			Sfx.play("ui_back", null, -6.0)


# あいさつの動きを、少しおきに繰り返す（1回で止まる動きなので）
func _wave(person: Node3D, anim: String) -> void:
	var vis: Node = person.get_node("Look")
	vis.play(anim, 0.15, true)
	vis.set_face("happy")
	_wave_t = 0.0


func _animate(delta: float) -> void:
	var start := 0.0
	for row: Array in SHOTS:
		if str(row[1]) == shot:
			start = float(row[0])
	var local := t - start
	(_bg.get_node("Rays") as Node2D).rotation += delta * 0.2
	match shot:
		"hook", "price":
			_wave_t += delta
			if _wave_t > 2.6:
				_wave(_presenter, "ORDER")
			if shot == "hook":
				_burst.rotation = 0.12 * sin(t * 5.0)
			else:
				var now: Node2D = _groups["price"].get_node("NowBurst")
				if local > 2.0:
					now.rotation = 0.05 * sin(t * 6.0)
			_cam.position.z -= delta * 0.05          # ゆっくり寄る
		"voice":
			_wave_t += delta
			if _wave_t > 2.8:
				_wave(_winner, "GREETING")
			_cam.position.x += delta * 0.06
		"buy":
			# 矢印が、右下からボタンへ動いて、押す
			var from := Vector2(0.86, 0.9) * _size
			var to := Vector2(0.53, 0.64) * _size
			var k := smoothstep(0.0, 1.0, clampf((local - 0.5) / 1.7, 0.0, 1.0))
			_cursor.position = from.lerp(to, k) + Vector2(0.0, -30.0 * _k * sin(k * PI))
			if local >= 2.6 and not _clicked:
				_clicked = true
				_button.scale = Vector2.ONE * 0.92
				(_button.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.13, 0.5, 0.22)
				Sfx.play("ui_press", null, 0.0)
				Sfx.play("ui_ok", null, -4.0)
			if local >= 2.85 and _clicked:
				_button.scale = Vector2.ONE
				var thanks: Label = _groups["buy"].get_node("Thanks")
				if not thanks.visible:
					thanks.visible = true
					_pop(thanks)
