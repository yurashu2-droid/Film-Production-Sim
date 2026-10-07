extends Node
# 接続を先に決め、ゲームは一度だけ生成する。
const GAME_SCENE := preload("res://production_game.tscn")
var game_node: Node
var solo_button: Button
var host_button: Button
var join_button: Button
var address_input: LineEdit
var status: Label
var _canvas: CanvasLayer
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
	_canvas.add_child(root)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic UI","Meiryo","Noto Sans CJK JP","sans-serif"])
	theme.default_font = font
	theme.default_font_size = 23
	root.theme = theme
	var background := ColorRect.new()
	background.color = Color("24221d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310,-260)
	panel.custom_minimum_size = Vector2(620,520)
	root.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("393127")
	style.set_corner_radius_all(16)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel",style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",16)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "格安アクション映画制作班"
	title.add_theme_font_size_override("font_size",31)
	title.add_theme_color_override("font_color",Color("efbf6b"))
	rows.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "今日も、安くて派手な一本を。"
	rows.add_child(subtitle)
	solo_button = _button("ひとりで遊ぶ",rows)
	solo_button.pressed.connect(_solo)
	host_button = _button("友達を招く（ホスト）",rows)
	host_button.pressed.connect(_host)
	var note := Label.new()
	note.text = "友達には、このパソコンのIPアドレスを伝えよう。"
	note.add_theme_font_size_override("font_size",18)
	rows.add_child(note)
	address_input = LineEdit.new()
	address_input.placeholder_text = "友達のIPアドレス（例：192.168.1.10）"
	address_input.custom_minimum_size.y = 48
	address_input.text_submitted.connect(func(_text: String): _join())
	rows.add_child(address_input)
	join_button = _button("友達の会社へ",rows)
	join_button.pressed.connect(_join)
	status = Label.new()
	status.custom_minimum_size = Vector2(540,52)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",19)
	status.add_theme_color_override("font_color",Color("e9cda0"))
	status.text = "1〜4人の制作班で、撮影へ出かけよう。"
	rows.add_child(status)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _button(text: String, rows: VBoxContainer) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	rows.add_child(button)
	return button

func _set_busy(on: bool) -> void:
	_busy = on
	solo_button.disabled = on
	host_button.disabled = on
	join_button.disabled = on
	address_input.editable = not on

func _solo() -> void:
	if _busy or game_node != null:
		return
	_set_busy(true)
	_launch(false)

func _host() -> void:
	if _busy or game_node != null:
		return
	_set_busy(true)
	if Net.host() != OK:
		_reset_connection("会社を開けませんでした。もう一度試してください。")
		return
	_launch(false)

func _join() -> void:
	if _busy or game_node != null:
		return
	var address := address_input.text.strip_edges()
	if not address.is_valid_ip_address():
		status.text = "IPアドレスを確かめてください。例：192.168.1.10"
		return
	_set_busy(true)
	_joining = true
	_elapsed = 0.0
	status.text = "友達の会社につないでいます…"
	if Net.join(address) != OK:
		_join_failed()

func _process(delta: float) -> void:
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
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.mode = "solo"
	_set_busy(false)
	status.text = message

func _launch(send_hello: bool) -> void:
	if _returning or game_node != null:
		return
	game_node = GAME_SCENE.instantiate()
	game_node.name = "Game"
	add_child(game_node)
	if _canvas != null:
		_canvas.visible = false
	if send_hello:
		game_node.h_hello.rpc_id(1)


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
	status.text = message
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
