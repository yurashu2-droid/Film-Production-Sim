extends Control
# ペイント画面の描く面。左ドラッグした点を、絵のピクセル座標にして知らせる。
signal point_drawn(point: Vector2, first: bool)
signal stroke_finished
var texture: Texture2D
var resolution := Vector2i(1024,724)   # 描いている絵の大きさ（開くたびに editor が入れる）
var drawing := false

func _draw() -> void:
	if texture: draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed
		if drawing:
			point_drawn.emit(event.position/size*Vector2(resolution),true)
		else:
			stroke_finished.emit()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			point_drawn.emit(event.position.clamp(Vector2.ZERO,size)/size*Vector2(resolution),false)
		else:
			drawing = false
			stroke_finished.emit()
		accept_event()
