extends CanvasLayer
# プレイヤー画面の指示札。3D世界や撮影用SubViewportには何も追加しない。
const LIFETIME := 5.0
var game: Node
var markers: Dictionary = {}
var _root: Control

func _ready() -> void:
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

func show_ping(sender: int, point: Vector3, text: String) -> void:
	if markers.has(sender):
		markers[sender]["panel"].queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10,0.085,0.06,0.94)
	style.border_color = Color("efbf6b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel",style)
	var label := Label.new()
	label.text = "◆ " + text
	label.add_theme_font_override("font",game.font)
	label.add_theme_font_size_override("font_size",19)
	label.add_theme_color_override("font_color",Color("ffe4a8"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_root.add_child(panel)
	markers[sender] = {"position":point,"text":text,"until":Time.get_ticks_msec()/1000.0+LIFETIME,"panel":panel}
	Sfx.play("ui_ok",null,-12.0)

func snapshot() -> Dictionary:
	var result := {}
	for sender: int in markers:
		result[sender] = {"position":markers[sender]["position"],"text":markers[sender]["text"]}
	return result

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()/1000.0
	var me: Node = game.local_player()
	var camera: Camera3D = me.cam if me != null else null
	var allowed: bool = game.production.phase in [0,2,4] and not game.ui_blocking() and not game.replaying
	# カメラ操作中の全面映像にも指示札を重ねない。
	if me != null and me.operating == game.film.pid:
		allowed = false
	for sender: int in markers.keys():
		var marker: Dictionary = markers[sender]
		var panel: PanelContainer = marker["panel"]
		if now >= marker["until"] or not game.players.has(sender):
			panel.queue_free()
			markers.erase(sender)
			continue
		panel.visible = false
		if not allowed or camera == null or camera.is_position_behind(marker["position"]):
			continue
		var screen: Vector2 = camera.unproject_position(marker["position"])
		var bounds := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
		if not bounds.has_point(screen):
			continue
		panel.position = screen + Vector2(-panel.size.x/2.0,-panel.size.y-12.0)
		panel.visible = true
