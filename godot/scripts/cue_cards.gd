extends Node
# 絵を描ける物（カンペ・等身大パネル）の管理。筆の命令はホストが確かめてから全員へ配る。
const Card := preload("res://scripts/cue_card.gd")
const StandIn := preload("res://scripts/standin_panel.gd")
const Editor := preload("res://scripts/cue_card_editor.gd")
# カンペの色（黒・赤・青と、消しゴムの白）
const CARD_COLORS := [["黒", Color.BLACK], ["赤", Color.RED], ["青", Color.BLUE], ["消しゴム", Color.WHITE]]
# 等身大パネルの絵の具。ホストは、ここにある色だけ受け付ける
const PANEL_COLORS := [
	["黒", Color("15151a")], ["灰", Color("8a8d94")], ["白", Color("ffffff")], ["茶", Color("7a4a24")], ["肌", Color("f1c9a5")],
	["赤", Color("d8362b")], ["橙", Color("f08a24")], ["黄", Color("f5d132")], ["黄緑", Color("86c540")], ["緑", Color("2e8b4a")],
	["水色", Color("58c2ea")], ["青", Color("2a5fd0")], ["紫", Color("7a4bc0")], ["桃", Color("f08fb4")],
]
const PANEL_REACH := 4.5      # 等身大パネルは、立てたまま近くから描ける
var game: Node
var card: RigidBody3D
var panel: RigidBody3D
var boards: Dictionary = {}   # 物のID → 描ける物
var editor: CanvasLayer

func setup() -> void:
	card = Card.new()
	card.build()
	_register(card,game.production.HOME_TRUCK+Vector3(-2.1,0.06,2.6),0.0)
	# 等身大パネルは軽トラの北西。前を広く空けて立てておく（正面は南向き）
	panel = StandIn.new()
	panel.build()
	_register(panel,game.production.HOME_TRUCK+Vector3(-5.8,0.06,-4.6),0.0)
	editor = Editor.new()
	editor.name = "CueCardPaint"
	editor.cards = self
	add_child(editor)

func _register(board: RigidBody3D, at: Vector3, yaw: float) -> void:
	board.ink_restored.connect(_sync_restored_ink.bind(board))
	game.stage._register(board,at,yaw)
	game.production._home_layout[board.pid] = board.get_state()
	boards[board.pid] = board

# その人がいま描ける物（持っているカンペ・パネル、または狙っている等身大パネル）
func board_for(player: Node) -> RigidBody3D:
	if player == null:
		return null
	if boards.has(player.held):
		return boards[player.held]
	if player.held == 0 and player.target == panel and allowed(panel.pid,player.peer_id):
		return panel
	return null

func allowed(pid: int, who: int) -> bool:
	var board: RigidBody3D = boards.get(pid)
	if board == null or board.absent or game.replaying or game.input_locked or game.state not in [game.S.PREP,game.S.COUNTDOWN,game.S.TAKE]:
		return false
	if board.holder == who:
		return true
	var player: Node3D = game.players.get(who)
	return board == panel and board.holder == 0 and player != null and player.global_position.distance_to(board.center_global()) <= PANEL_REACH

func _known_color(color: Color) -> bool:
	for item: Array in CARD_COLORS + PANEL_COLORS:
		if color.is_equal_approx(item[1]):
			return true
	return false

@rpc("any_peer","call_local","reliable")
func h_draw(pid: int, points: PackedVector2Array, color: Color, radius: float) -> void:
	if not Net.is_host() or not allowed(pid,Net.sender()) or points.is_empty() or points.size() > 32: return
	if not _known_color(color): return
	var board: RigidBody3D = boards[pid]
	var clean := PackedVector2Array()
	for point in points:
		if not is_finite(point.x) or not is_finite(point.y): return
		clean.append(point.clamp(Vector2.ZERO,Vector2(board.res-Vector2i.ONE)))
	rx_draw.rpc(pid,clean,color,clampf(radius,2,48),board.revision+1)

@rpc("authority","call_local","reliable")
func rx_draw(pid: int, points: PackedVector2Array, color: Color, radius: float, version: int) -> void:
	var board: RigidBody3D = boards.get(pid)
	if board == null: return
	for i in points.size():
		board.draw_line(points[maxi(0,i-1)],points[i],color,radius,false)
	board._refresh()
	board.revision = version

@rpc("any_peer","call_local","reliable")
func h_clear(pid: int) -> void:
	if Net.is_host() and allowed(pid,Net.sender()):
		rx_fill.rpc(pid,Color.WHITE,boards[pid].revision+1)

# 面をまるごと1色で塗る（等身大パネルの下塗り）
@rpc("any_peer","call_local","reliable")
func h_fill(pid: int, color: Color) -> void:
	if Net.is_host() and allowed(pid,Net.sender()) and _known_color(color):
		rx_fill.rpc(pid,color,boards[pid].revision+1)

@rpc("authority","call_local","reliable")
func rx_fill(pid: int, color: Color, version: int) -> void:
	var board: RigidBody3D = boards.get(pid)
	if board == null: return
	board.fill_ink(color)
	board.revision = version

# 用意された見本の絵を貼る（等身大パネルだけ）
@rpc("any_peer","call_local","reliable")
func h_preset(pid: int, id: String) -> void:
	if Net.is_host() and pid == panel.pid and allowed(pid,Net.sender()) and StandIn.PRESETS.has(id):
		rx_preset.rpc(pid,id,panel.revision+1)

@rpc("authority","call_local","reliable")
func rx_preset(pid: int, id: String, version: int) -> void:
	if pid != panel.pid: return
	panel.paste_preset(id)
	panel.revision = version

func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id():
		for pid: int in boards:
			rx_snapshot.rpc_id(who,pid,boards[pid].get_state())

@rpc("authority","call_remote","reliable")
func rx_snapshot(pid: int, state: Array) -> void:
	if boards.has(pid):
		boards[pid]._apply_extra(state)

func _sync_restored_ink(board: RigidBody3D) -> void:
	if Net.is_host() and Net.has_peers(): rx_snapshot.rpc(board.pid,board.get_state())


# ---- 登録（feature_hooks.gd）。決まった名前の関数を持っていると、中心の側が呼ぶ ----

# カンペ・等身大パネルに書く画面を開いている間の操作
func hook_input(event: InputEvent) -> bool:
	return editor.handle_input(event)


# F：カンペを持っていれば、書く。等身大パネルは、立てたまま見て F で描く（持っている間は、積む・置くが先）
func hook_f(me: Node) -> bool:
	if me.held == card.pid:
		editor.open_card()
		return true
	if me.held == 0 and me.target == panel and board_for(me) != null:
		editor.open_board(panel)
		return true
	return false
