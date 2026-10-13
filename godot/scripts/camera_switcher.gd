extends Node
const FilmCamera := preload("res://scripts/film_camera.gd")
const Monitor := preload("res://scripts/production_monitor_prop.gd")
const PREVIEW_SIZE := Vector2i(480,270)
var game: Node
var cameras: Array[Node] = []
var monitor: Node
var active_pid := 0
var operator_peer := 0

func setup() -> void:
	cameras.append(game.film)
	game.film.label = "撮影カメラ A"
	monitor = game.production.get("monitor_prop") if "monitor_prop" in game.production else null
	if monitor == null:
		monitor = Monitor.new()
		monitor.build_model()
		game.stage._register(monitor,game.production.HOME_TRUCK+Vector3(-3,0.05,3.6),PI*0.5)
		if "_home_layout" in game.production:
			game.production._home_layout[monitor.pid] = monitor.get_state()
	for i in range(1,3):
		var extra := FilmCamera.new()
		extra.build()
		extra.label = "撮影カメラ " + ["A","B","C"][i]
		# 荷台には載せない。会社の機材置き場に並べる（production_flow.gd の stage_gear() が置き直す）
		var home: Array = game.production.gear_home("camera",i)
		game.stage._register(extra,home[0],home[1])
		cameras.append(extra)
		if "_home_layout" in game.production:
			game.production._home_layout[extra.pid] = extra.get_state()
	active_pid = game.film.pid
	monitor.attach(camera().view)
	Net.peer_left.connect(_peer_left)

func camera() -> Node:
	return game.props.get(active_pid,game.film)

func index() -> int:
	return cameras.find(camera())

func nearby(player: Node3D) -> bool:
	if player == null or monitor.absent: return false
	if game.production.has_method("near_monitor"):
		return game.production.near_monitor(player)
	return player.global_position.distance_to(monitor.global_position) < 3.4

func allowed() -> bool:
	return game.production.phase in [2,4] and game.state in [game.S.PREP,game.S.COUNTDOWN,game.S.TAKE] and not game.replaying and not game.production.expired

func request_control(who: int, on: bool) -> void:
	if not Net.is_host(): return
	if not on and operator_peer == who:
		operator_peer = 0
		_sync()
	elif on and operator_peer in [0,who] and allowed() and nearby(game.players.get(who)):
		operator_peer = who
		_sync()

func request_cut(who: int, which: int) -> void:
	if not controls(who): return
	if which < 0 or which >= cameras.size() or cameras[which].absent: return
	var pid: int = cameras[which].pid
	if pid != active_pid:
		game.host_ev("camera_program",[pid])

func controls(who: int) -> bool:
	return Net.is_host() and who == operator_peer and allowed() and nearby(game.players.get(who))

func select(pid: int) -> void:
	if not cameras.any(func(c): return c.pid == pid): return
	active_pid = pid
	monitor.attach(camera().view)
	_refresh_views()

func state() -> Array:
	return [active_pid,operator_peer]

@rpc("authority","call_remote","reliable")
func receive(data: Array) -> void:
	if data.size() < 2: return
	select(int(data[0]))
	operator_peer = int(data[1])

func _sync() -> void:
	if Net.has_peers(): receive.rpc(state())

func _peer_left(who: int) -> void:
	if Net.is_host() and operator_peer == who:
		operator_peer = 0
		_sync()

func state_changed() -> void:
	if Net.is_host() and operator_peer != 0 and not allowed():
		operator_peer = 0
		_sync()
	_refresh_views()

# カメラ3台と確認用モニターは荷台へは積まない（荷台が埋まり、ほかの荷物が上に積み上がってしまう）。
# 会社では機材置き場に並び、現場へは production_flow.gd が搬入口のそばへ出す。
func _process(_delta: float) -> void:
	if Net.is_host() and operator_peer != 0 and (not allowed() or not nearby(game.players.get(operator_peer))):
		operator_peer = 0
		_sync()
	_refresh_views()

func _refresh_views() -> void:
	var showing: bool = game.production.phase in [2,4]
	for c: Node in cameras:
		var size: Vector2i = c.VIEW_SIZE if c.pid == active_pid else PREVIEW_SIZE
		# 撮影係自身のファインダーも十分な解像度で保つ。
		var me: Node = game.local_player()
		if me != null and me.operating == c.pid: size = c.VIEW_SIZE
		if c.view.size != size: c.view.size = size
		c.view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing or c.operator != 0 else SubViewport.UPDATE_DISABLED
		c.tally.visible = c.pid == active_pid and game.state == game.S.TAKE
	monitor.set_on_air(index(),game.state == game.S.TAKE)
