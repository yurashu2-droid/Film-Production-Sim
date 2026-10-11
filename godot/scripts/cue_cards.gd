extends Node
const Card := preload("res://scripts/cue_card.gd")
const Editor := preload("res://scripts/cue_card_editor.gd")
var game: Node
var card: RigidBody3D
var editor: CanvasLayer

func setup() -> void:
	card = Card.new()
	card.build()
	card.ink_restored.connect(_sync_restored_ink)
	game.stage._register(card,game.production.HOME_TRUCK+Vector3(-2.1,0.06,2.6),0.0)
	game.production._home_layout[card.pid] = card.get_state()
	editor = Editor.new()
	editor.name = "CueCardPaint"
	editor.cards = self
	add_child(editor)

func allowed(pid: int, who: int) -> bool:
	return pid == card.pid and card.holder == who and not game.replaying and not game.input_locked and game.state in [game.S.PREP,game.S.COUNTDOWN,game.S.TAKE]

@rpc("any_peer","call_local","reliable")
func h_draw(pid: int, points: PackedVector2Array, color: Color, radius: float) -> void:
	if not Net.is_host() or not allowed(pid,Net.sender()) or points.is_empty() or points.size() > 32: return
	if not color.is_equal_approx(Color.BLACK) and not color.is_equal_approx(Color.RED) and not color.is_equal_approx(Color.BLUE) and not color.is_equal_approx(Color.WHITE): return
	var clean := PackedVector2Array()
	for point in points:
		if not is_finite(point.x) or not is_finite(point.y): return
		clean.append(point.clamp(Vector2.ZERO,Vector2(Card.RESOLUTION-Vector2i.ONE)))
	rx_draw.rpc(pid,clean,color,clampf(radius,2,24),card.revision+1)

@rpc("authority","call_local","reliable")
func rx_draw(pid: int, points: PackedVector2Array, color: Color, radius: float, version: int) -> void:
	if pid != card.pid: return
	for i in points.size():
		card.draw_line(points[maxi(0,i-1)],points[i],color,radius,false)
	card._refresh()
	card.revision = version

@rpc("any_peer","call_local","reliable")
func h_clear(pid: int) -> void:
	if Net.is_host() and allowed(pid,Net.sender()):
		rx_clear.rpc(pid,card.revision+1)

@rpc("authority","call_local","reliable")
func rx_clear(pid: int, version: int) -> void:
	if pid != card.pid: return
	card.clear_ink()
	card.revision = version

func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id(): rx_snapshot.rpc_id(who,card.get_state())

@rpc("authority","call_remote","reliable")
func rx_snapshot(state: Array) -> void:
	card._apply_extra(state)

func _sync_restored_ink() -> void:
	if Net.is_host() and Net.has_peers(): rx_snapshot.rpc(card.get_state())
