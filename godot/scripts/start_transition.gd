extends CanvasLayer
# タイトルとGameのどちらにも属さない、実物のカチンコによるワイプ。
signal occluded
signal finished

const MODEL := preload("res://assets/props/P051_clapperboard.glb")
const ENTER_TIME := 0.65
const CLAP_TIME := 0.075
const EXIT_TIME := 0.72
const SHUT := -0.22
var active := false
var covered := false
var view: SubViewport
var rig: Node3D
var stick: Node3D
var _slate: MeshInstance3D
var _keep_proportions: Array[Node3D] = []
var _screen: Control
var _phase := ""
var _time := 0.0
var _sounded := false

func _ready() -> void:
	layer = 100
	_screen = SubViewportContainer.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.stretch = true
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	view = SubViewport.new()
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	_screen.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 2.0
	camera.position.z = 10.0
	view.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.79, 0.85, 1.0)
	environment.environment.ambient_light_energy = 0.7
	view.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -25, 0)
	light.light_energy = 1.2
	view.add_child(light)
	rig = Node3D.new()
	view.add_child(rig)
	var model: Node3D = MODEL.instantiate()
	model.position.y = -0.11
	rig.add_child(model)
	var model_root: Node3D = model.get_child(0)
	stick = Node3D.new()
	stick.position = Vector3(-0.15, 0.235, 0)
	model_root.add_child(stick)
	for n: Node in model_root.get_children():
		var nm := String(n.name)
		var top := nm.contains("clapper_top")
		for odd: String in ["stripe_005", "stripe_007", "stripe_009", "stripe_011", "stripe_013"]:
			top = top or nm.contains(odd)
		if nm.contains("slate_001") and n is MeshInstance3D:
			_slate = n
		if n is Node3D and (nm.contains("hinge_pin") or nm.contains("header_") or nm.contains("numbers_") or nm.contains("footer_")):
			_keep_proportions.append(n)
		if top and n is Node3D:
			# 元モデルは中心で傾けてあるので、蝶番回転で閉じた時の厚みを合わせる。
			n.position.y += 0.014
			n.reparent(stick, true)
	# 初回だけGPUへ送っておく。待機中は描画・処理を止める。
	visible = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	set_process(false)

func begin() -> void:
	cancel()
	active = true
	covered = false
	_sounded = false
	_phase = "enter"
	_time = 0.0
	stick.rotation.z = 0.0
	visible = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	_enter_pose(0.0)

func reveal() -> void:
	if not active or not covered:
		return
	_phase = "exit"
	_time = 0.0
	await finished

func cancel() -> void:
	var was_active := active
	active = false
	covered = false
	_phase = ""
	visible = false
	if view != null:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
	if was_active:
		occluded.emit()
		finished.emit()

func _process(delta: float) -> void:
	_time += delta
	match _phase:
		"enter":
			_enter_pose(minf(_time / ENTER_TIME, 1.0))
			if _time >= ENTER_TIME:
				_phase = "clap"
				_time = 0.0
		"clap":
			_frame_pose()
			stick.rotation.z = lerpf(0.0, SHUT, pow(minf(_time / CLAP_TIME, 1.0), 2.0))
			if _time >= CLAP_TIME:
				_sounded = true
				Sfx.play("clap", null, -4.0)
				covered = true
				_phase = "hold"
				_time = 0.0
				# 打った直後にGameを用意し、板の裏で描く。
				occluded.emit()
		"hold":
			_frame_pose(sin(_time * 2.5) * 0.003)
		"exit":
			_exit_pose(minf(_time / EXIT_TIME, 1.0))
			if _time >= EXIT_TIME:
				active = false
				covered = false
				visible = false
				view.render_target_update_mode = SubViewport.UPDATE_DISABLED
				set_process(false)
				finished.emit()

func _frame_scale() -> Vector3:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	# 拍子木の左右には余白を残す。黒板だけ広げて画面を覆う。
	return Vector3(aspect * 2.0 * 0.91 / 0.31, 5.0, 6.0)

func _extend_board(amount: float) -> void:
	_slate.scale = Vector3(1.0, 1.0, 1.0).lerp(Vector3(1.2, 0.70 / 0.22, 1.0), amount)
	_slate.position.y = lerpf(0.11, 0.04, amount)

func _pose(point: Vector2, amount: Vector3, turn: Vector3, extension: float) -> void:
	rig.position = Vector3(point.x, point.y, 0)
	rig.scale = amount
	rig.rotation = turn
	_extend_board(extension)
	# 横長の板でも文字と蝶番の丸さは引き伸ばさない。
	for detail: Node3D in _keep_proportions:
		detail.scale.x = amount.y / amount.x

func _frame_pose(breathe: float = 0.0) -> void:
	_pose(Vector2(0, -0.30 + breathe), _frame_scale(), Vector3.ZERO, 1.0)

func _enter_pose(t: float) -> void:
	if t < 0.56:
		var k := 1.0 - pow(1.0 - t / 0.56, 3.0)
		_pose(Vector2(-2.3, -1.9).lerp(Vector2(-0.25, -0.5), k), Vector3.ONE * lerpf(4.0, 5.6, k), Vector3(0.08, -0.5, 0.32).lerp(Vector3(0, 0.10, -0.08), k), 0.0)
	else:
		var k := smoothstep(0.56, 1.0, t)
		_pose(Vector2(-0.25, -0.5).lerp(Vector2(0, -0.30), k), (Vector3.ONE * 5.6).lerp(_frame_scale(), k), Vector3(0, 0.10, -0.08).lerp(Vector3.ZERO, k), k)

func _exit_pose(t: float) -> void:
	# ゲームが裏で描けたら、開く動きと右へ抜ける動きを同時に始める。
	stick.rotation.z = lerpf(SHUT, 0.0, smoothstep(0.02, 0.55, t))
	var shrink := 1.0 - pow(1.0 - t, 3.0)
	var drift := t * t
	var aspect := get_viewport().get_visible_rect().size.aspect()
	_pose(Vector2(0, -0.30).lerp(Vector2(aspect + 1.4, -0.35), drift), _frame_scale().lerp(Vector3.ONE * 5.0, shrink), Vector3.ZERO.lerp(Vector3(0.06, -0.4, -0.08), drift), 1.0 - smoothstep(0.0, 0.65, t))
