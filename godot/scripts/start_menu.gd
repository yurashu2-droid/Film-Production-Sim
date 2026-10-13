extends Node
# 接続を先に決め、ゲームは一度だけ生成する。
const GAME_SCENE := preload("res://production_game.tscn")
const UI := preload("res://scripts/ui/ui_theme.gd")
const TitleSet := preload("res://scripts/title_set.gd")
const StartTransition := preload("res://scripts/start_transition.gd")
var _transition: CanvasLayer
const StartupResources := preload("res://scripts/startup_resources.gd")
var _startup_resources: Node
var _startup_poll_paused := false
var game_node: Node
var solo_button: Button
var host_button: Button
var join_button: Button
var address_input: LineEdit
var _canvas: CanvasLayer
var _stage: Control
var _diorama: SubViewportContainer
var _diorama_view: SubViewport
var _film_set: Node3D
var _root: Control
var _hits: Array[Button] = []
var _logo: Control
var _stamp: Control
var _status_panel: Control
var _cards: Array[Control] = []
var _intro_done := false
var _busy := false
var _joining := false
var _returning := false
var _elapsed := 0.0

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and not argument.begins_with("--menutest"):
			_launch(false)
			return
	_build()
	_transition = StartTransition.new()
	add_child(_transition)
	_startup_resources = StartupResources.new()
	add_child(_startup_resources)
	Net.joined_host.connect(_joined)
	Net.join_failed.connect(_join_failed)
	multiplayer.server_disconnected.connect(_host_closed)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--menutest="):
			var test: Node = load("res://tests/startmenutest.gd").new()
			test.menu = self
			test.role = argument.get_slice("=",1)
			add_child(test)

func _build() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme(20)
	_canvas.add_child(root)
	_root = root

	# 画面いっぱいの撮影現場（3D）。メニューのケースもこの中に置いてある
	_diorama = SubViewportContainer.new()
	_diorama.stretch = true
	_diorama.set_anchors_preset(Control.PRESET_FULL_RECT)
	_diorama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_diorama)
	_diorama_view = SubViewport.new()
	_diorama_view.own_world_3d = true
	_diorama_view.msaa_3d = Viewport.MSAA_4X
	_diorama_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_diorama.add_child(_diorama_view)
	_film_set = TitleSet.new()
	_diorama_view.add_child(_film_set)
	_film_set.build()

	# 四隅を落とし、フィルムの粒を薄く載せる
	root.add_child(_overlay("""
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.38, 0.86, d) * 0.62);
}"""))
	root.add_child(_overlay("""
shader_type canvas_item;
void fragment() {
	vec2 p = floor(UV * vec2(960.0, 540.0)) + floor(TIME * 24.0) * 7.31;
	float n = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(n), 0.045);
}"""))

	# 題名（2D）。左上の暗い所に置く
	var column := VBoxContainer.new()
	column.position = Vector2(LEFT, 92)
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	_stage = column
	var mark := _Mark.new()
	mark.custom_minimum_size = Vector2(0, 18)
	column.add_child(mark)
	column.add_child(_gap(26))
	var title := UI.label("格安アクション\n映画制作班", 80, UI.CLAP_WHITE, "display")
	title.add_theme_constant_override("line_spacing", -14)
	column.add_child(title)

	# 入口は3つ。見た目は3Dの機材ケースで、その上に見えないボタンを重ねて押せるようにする
	solo_button = _hit_button("ひとりで遊ぶ", 0)
	solo_button.pressed.connect(_solo)
	host_button = _hit_button("友達を招く（ホスト）", 1)
	host_button.pressed.connect(_host)
	join_button = _hit_button("友達の会社へ", 2)
	join_button.pressed.connect(_join)
	address_input = LineEdit.new()
	address_input.placeholder_text = "友達のIPアドレス"
	_style_slot(address_input)
	address_input.text_submitted.connect(func(_text: String): _join())
	root.add_child(address_input)

	_film_set.set_case_note("同じネットワークの友達と、最大4人で撮影できる。")

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_canvas.visibility_changed.connect(func() -> void:
		_diorama_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _canvas.visible else SubViewport.UPDATE_DISABLED
		_film_set.set_process(_canvas.visible)
		if _canvas.visible and _intro_done:
			_intro())
	root.resized.connect(_layout.call_deferred)
	_layout.call_deferred()
	_intro()


const LEFT := 112.0
const CASE_TOP := 492.0
const CASE_W := 440.0
const CASE_H := 68.0
const SLOT_W := 252.0        # 3段目のケースの、IPアドレスを書く窓の幅


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _overlay(code: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	return rect


# ケースの上に重ねる、見えないボタン。文字と見た目は3D側が受け持つ
func _hit_button(text: String, index: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	for style: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.7)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	b.add_theme_stylebox_override("focus", focus)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0, 0, 0, 0))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func() -> void:
		_film_set.set_hover(index, true)
		if not b.disabled:
			Sfx.play("ui_select" if Sfx.has_sound("ui_select") else "pickup", null, -10.0))
	b.mouse_exited.connect(func() -> void: _film_set.set_hover(index, b.has_focus()))
	b.focus_entered.connect(func() -> void: _film_set.set_hover(index, true))
	b.focus_exited.connect(func() -> void: _film_set.set_hover(index, false))
	b.pressed.connect(func() -> void: Sfx.play("fix", null, -10.0))
	_root.add_child(b)
	_hits.append(b)
	return b


# ケースにはめ込んだ、書き込み用の窓
func _style_slot(e: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.022, 0.028, 0.92)
	normal.border_color = Color(1, 1, 1, 0.16)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 14
	normal.content_margin_right = 10
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = UI.TAPE
	e.add_theme_stylebox_override("normal", normal)
	e.add_theme_stylebox_override("focus", focus)
	e.add_theme_stylebox_override("read_only", normal)
	e.add_theme_color_override("font_color", UI.CLAP_WHITE)
	e.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.42))
	e.add_theme_color_override("caret_color", UI.TAPE)
	e.add_theme_font_override("font", UI.fnt("body"))
	e.add_theme_font_size_override("font_size", 19)


# 画面の大きさに合わせて、3Dのケースを「ボタンを置きたい場所」へ並べ直す
func _layout() -> void:
	if _film_set == null or not is_instance_valid(_film_set) or _root.size.x < 10.0:
		return
	var rects: Array = []
	for k in 3:
		rects.append(Rect2(LEFT, CASE_TOP + CASE_H * k, CASE_W, CASE_H))
	var join_x: float = (SLOT_W + 12.0 + (CASE_W - SLOT_W - 12.0) * 0.5) / CASE_W
	_film_set.layout_cases(rects, ["primary", "dark", "dark"], ["ひとりで遊ぶ", "友達を招く（ホスト）", "友達の会社へ"], [0.5, 0.5, join_x])
	_place_hits()


func _place_hits() -> void:
	if _film_set == null or _film_set.cases.size() < 3:
		return
	for k in 3:
		var r: Rect2 = _film_set.case_rect(k)
		if k == 2:
			var slot := Rect2(r.position + Vector2(10, 10), Vector2(SLOT_W - 10.0, r.size.y - 20.0))
			address_input.position = slot.position
			address_input.size = slot.size
			r = Rect2(r.position.x + SLOT_W + 6.0, r.position.y, r.size.x - SLOT_W - 6.0, r.size.y)
		_hits[k].position = r.position
		_hits[k].size = r.size


func _intro() -> void:
	_intro_done = true
	_stage.modulate.a = 0.0
	_diorama.modulate = Color(0, 0, 0, 1)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_diorama, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stage, "modulate:a", 1.0, 0.3).set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_busy(on: bool) -> void:
	_busy = on
	if _film_set != null:
		_film_set.enabled = not on
	solo_button.disabled = on
	host_button.disabled = on
	join_button.disabled = on
	address_input.editable = not on

func _solo() -> void:
	if _busy or game_node != null:
		return
	_set_busy(true)
	_transition.begin()
	await _prepare_resources()
	_launch(false)

func _host() -> void:
	if _busy or game_node != null:
		return
	_set_busy(true)
	_transition.begin()
	await _prepare_resources()
	_launch(false, true)

func _join() -> void:
	if _busy or game_node != null:
		return
	var address := address_input.text.strip_edges()
	if not address.is_valid_ip_address():
		_film_set.set_case_note("IPアドレスを確かめてください。例：192.168.1.10")
		return
	_set_busy(true)
	_transition.begin()
	await _prepare_resources()
	_joining = true
	_elapsed = 0.0
	_film_set.set_case_note("友達の会社につないでいます…")
	if Net.join(address) != OK:
		_join_failed()

func _process(delta: float) -> void:
	if _film_set != null and _canvas != null and _canvas.visible:
		_place_hits()
		if _root.size.x > 10.0:
			_film_set.set_mouse((_root.get_local_mouse_position() / _root.size - Vector2(0.5, 0.5)) * 2.0)
	if _joining:
		_elapsed += delta
		if _elapsed >= 12.0:
			_join_failed()

func _joined() -> void:
	if not _joining or game_node != null:
		return
	_joining = false
	_launch.call_deferred(true)

func _join_failed() -> void:
	if _joining and game_node == null:
		_reset_connection("つながりませんでした。友達が会社を開いているか、IPアドレスを確かめて再試行してください。")

func _reset_connection(message: String) -> void:
	_joining = false
	_transition.cancel()
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.mode = "solo"
	_set_busy(false)
	_film_set.set_case_note(message)

func _prepare_resources() -> void:
	if _startup_resources != null and not _startup_resources.is_prepared:
		_film_set.set_case_note("機材を準備しています…")
		await _startup_resources.completed
	_film_set.set_case_note("撮影班、入室準備中…")

func _launch(send_hello: bool, host_requested: bool = false) -> void:
	if _returning or game_node != null:
		return
	if _canvas != null:
		if not _transition.active:
			return
		if not _transition.covered:
			await _transition.occluded
		if _returning or not _transition.active or game_node != null:
			return
	game_node = GAME_SCENE.instantiate()
	game_node.name = "Game"
	if _canvas != null:
		game_node.startup_incremental = true
		game_node.process_mode = Node.PROCESS_MODE_DISABLED
		# 分割生成中のゲームへのRPC配送を待たせ、完成後にまとめて受け取る。
		if Net.mode == "client" and get_tree().multiplayer_poll:
			get_tree().multiplayer_poll = false
			_startup_poll_paused = true
		game_node.startup_ready.connect(_finish_launch.bind(send_hello, host_requested), CONNECT_ONE_SHOT)
	add_child(game_node)
	if _canvas == null and send_hello:
		game_node.h_hello.rpc_id(1)

func _finish_launch(send_hello: bool, host_requested: bool) -> void:
	var launching_game: Node = game_node
	if not _transition.covered:
		await _transition.occluded
	if _returning or not _transition.active or not is_instance_valid(launching_game) or game_node != launching_game:
		return
	_resume_network_poll()
	# Gameの準備と画面の被覆が両方済んでから、接続を受け付ける。
	if host_requested and Net.host() != OK:
		return_to_menu("会社を開けませんでした。もう一度試してください。")
		return
	launching_game.input_locked = true
	launching_game.process_mode = Node.PROCESS_MODE_INHERIT
	_canvas.visible = false
	if send_hello:
		launching_game.h_hello.rpc_id(1)
	# 初めてのゲーム画面を板の裏で描き、白抜けのフレームを出さない。
	for frame in 2:
		await get_tree().process_frame
	if _returning or not is_instance_valid(launching_game) or game_node != launching_game:
		return
	await _transition.reveal()
	if is_instance_valid(launching_game) and game_node == launching_game:
		launching_game.input_locked = false

func _resume_network_poll() -> void:
	if _startup_poll_paused:
		get_tree().multiplayer_poll = true
		_startup_poll_paused = false


func _host_closed() -> void:
	if Net.mode == "client" and game_node != null:
		return_to_menu("ホストの会社が閉じました。再参加するか、ひとりで撮影を続けよう。")


func return_to_menu(message: String = "会社を閉じました。次の制作班を選んでください。") -> void:
	if _returning:
		return
	# CLI runs keep their original lifecycle, including network verification scripts.
	if _canvas == null:
		get_tree().quit()
		return
	_returning = true
	_transition.cancel()
	_resume_network_poll()
	_set_busy(true)
	_joining = false
	var old_game: Node = game_node
	if is_instance_valid(old_game):
		old_game.process_mode = Node.PROCESS_MODE_DISABLED
		_disconnect_game_signals(old_game)
		old_game.queue_free()
	Sfx.silence_all()
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.mode = "solo"
	while is_instance_valid(old_game):
		await get_tree().process_frame
	game_node = null
	_canvas.visible = true
	_film_set.set_case_note(message)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_returning = false
	_set_busy(false)


func _disconnect_game_signals(old_game: Node) -> void:
	for source: Node in [Net,Sfx]:
		for signal_data: Dictionary in source.get_signal_list():
			var signal_name: StringName = signal_data["name"]
			for connection: Dictionary in source.get_signal_connection_list(signal_name):
				var callback: Callable = connection["callable"]
				var target: Object = callback.get_object()
				if target is Node and (target == old_game or old_game.is_ancestor_of(target)):
					source.disconnect(signal_name,callback)


func host_addresses() -> Array[String]:
	var addresses: Array[String] = []
	for address: String in IP.get_local_addresses():
		if address.contains(":") or not address.is_valid_ip_address() or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if not address in addresses:
			addresses.append(address)
	return addresses


# 題名の上に置く、カチンコの縞の短い帯。この画面で縞を使うのはここだけ
class _Mark extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		ui.draw_stripes(self, Rect2(0, 0, 168, size.y), ui.INK, ui.CLAP_WHITE, 34.0)
