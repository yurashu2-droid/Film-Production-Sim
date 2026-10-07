extends "res://scripts/main.gd"
const Flow := preload("res://scripts/production_flow.gd")
const ProductionHud := preload("res://scripts/production_hud.gd")
var production: Node
var production_hud: CanvasLayer
var _legacy_mode := false

func _ready() -> void:
	for flag in ["--autotest","--failtest","--nettest","--faceshot","--gearshot","--legacy"]:
		if flag in OS.get_cmdline_user_args():
			_legacy_mode = true
	super._ready()
	if _legacy_mode:
		return
	production = Flow.new()
	production.name = "Production"
	add_child(production)
	production.setup(self)
	production_hud = ProductionHud.new()
	production_hud.game = self
	add_child(production_hud)
	production_hud.build()
	if "--productionnettest" in OS.get_cmdline_user_args():
		var test: Node = load("res://tests/productionnettest.gd").new()
		test.game = self
		add_child(test)

func _input(event: InputEvent) -> void:
	if production == null or not event is InputEventKey or not event.pressed or event.echo or ui_blocking() or local_player() == null:
		return
	var me: Node = local_player()
	if event.physical_keycode == KEY_F:
		if production.phase == 2 and me.held != 0 and me.global_position.distance_to(Flow.HOME_TRUCK) < 4.5:
			h_load_truck.rpc_id(1,me.held)
			get_viewport().set_input_as_handled()
		elif me.target and me.target.has_method("set_active"):
			h_prop_action.rpc_id(1,me.target.pid)
			get_viewport().set_input_as_handled()
		elif me.held != 0 and props[me.held].has_method("set_active"):
			h_prop_action.rpc_id(1,me.held)
			get_viewport().set_input_as_handled()
		elif production.phase == 2 and me.global_position.distance_to(Flow.HOME_TRUCK) < 4.0 and me.held == 0:
			h_depart.rpc_id(1)
			get_viewport().set_input_as_handled()

@rpc("any_peer","call_local","reliable")
func h_load_truck(pid: int) -> void:
	if not Net.is_host() or not production or production.phase != 2:
		return
	var me: Node = players.get(Net.sender())
	var prop: Node = props.get(pid)
	if me == null or prop == null or prop.holder != Net.sender() or me.global_position.distance_to(Flow.HOME_TRUCK) > 4.5:
		return
	host_release(prop)
	if prop.rider_of != 0:
		host_unload(prop)
	host_load(prop,truck)
	host_ev("toast",[prop.label+" を積んだ！ 高く積めば、だいたい載る。",0])

@rpc("any_peer","call_local","reliable")
func h_prop_action(pid: int) -> void:
	if not Net.is_host() or not production or production.phase not in [0,2,4] or replaying:
		return
	var me: Node = players.get(Net.sender())
	var prop: Node = props.get(pid)
	if me == null or prop == null or prop.absent or not prop.has_method("set_active") or prop.holder not in [0,Net.sender()]:
		return
	if me.global_position.distance_to(prop.center_global()) > Player.REACH:
		return
	host_ev("production_prop",[pid,not prop.active])
	host_ev("sfx",["thump",prop.global_position])

@rpc("authority","call_local","reliable")
func ev(n: String, a: Array) -> void:
	if n == "production_prop":
		if props.has(a[0]) and props[a[0]].has_method("set_active"):
			props[a[0]].set_active(a[1])
	else:
		super.ev(n,a)

@rpc("any_peer","call_local","reliable")
func h_accept_job(index: int) -> void:
	if Net.is_host() and production:
		production.accept(index)

@rpc("any_peer","call_local","reliable")
func h_depart() -> void:
	if Net.is_host() and production:
		production.depart()

@rpc("any_peer","call_local","reliable")
func h_return_office() -> void:
	if Net.is_host() and production:
		production.return_office()

@rpc("any_peer", "call_remote", "reliable")
func h_hello() -> void:
	super.h_hello()
	if Net.is_host() and production:
		h_production_hello()

@rpc("any_peer","call_remote","reliable")
func h_production_hello() -> void:
	if Net.is_host() and production:
		production_sync.rpc_id(Net.sender(),production.snapshot())
		var point: Vector3 = Flow.HOME_TRUCK if production.phase in [2,3] else (SPAWN if production.phase in [4,5] else Flow.Office.SPAWN_POINT)
		production_move.rpc(point,0.0,Net.sender())

@rpc("authority","call_local","reliable")
func production_sync(data: Dictionary) -> void:
	if production:
		production.apply(data)

@rpc("authority","call_local","reliable")
func production_move(point: Vector3, yaw: float, only_peer: int = 0) -> void:
	var i := 0
	for player: Node in players.values():
		if only_peer != 0 and player.peer_id != only_peer:
			continue
		player._net.clear()
		player.global_position = point + Vector3(float(i)*0.8,0,0)
		player.velocity = Vector3.ZERO
		player.aim_yaw = yaw
		player.vis.rotation.y = yaw + PI
		player.aim_pitch = -0.18
		player._motion = ""
		player._run_requested = false
		player.vis.play("idle",0.0,true)
		i += 1
	if production:
		_grab_mouse(production.phase in [2,4])

@rpc("any_peer","call_local","reliable")
func h_order_set(id: String, count: int) -> void:
	if production:
		var next: Dictionary = order.duplicate()
		for opt: Dictionary in OPTIONS:
			if opt["id"] == id:
				next[id] = clampi(count,0,int(opt["max"]))
		if int(next.get("fx",0)) == 0:
			next["refill"] = 0
		if order_cost(next) > production.wallet:
			ev.rpc_id(Net.sender(),"toast",["会社の残金が足りない。廃材は無料で使える",1])
			return
	super.h_order_set(id,count)

@rpc("any_peer","call_local","reliable")
func h_order_confirm() -> void:
	if production and (production.phase != 1 or order_cost() > production.wallet):
		return
	var before := state
	super.h_order_confirm()
	if production and Net.is_host() and before == S.ORDER and state == S.PREP:
		production.pack()

func _take_or_cut(who: int) -> void:
	if production and (production.phase != 4 or production.expired):
		ev.rpc_id(who,"toast",["撮影は現場に着いてから。期限後は撮れたテイクを納品しよう",1])
		return
	super._take_or_cut(who)

@rpc("any_peer","call_local","reliable")
func h_retake() -> void:
	if production and production.expired:
		return
	super.h_retake()

@rpc("any_peer","call_local","reliable")
func h_deliver(index: int) -> void:
	var valid := Net.is_host() and state == S.RESULT and index >= 0 and index < takes.size()
	super.h_deliver(index)
	if production and valid:
		production.settle(index)

@rpc("any_peer","call_local","reliable")
func h_next() -> void:
	if production:
		if Net.is_host():
			production.return_office()
	else:
		super.h_next()

func _order_bbcode() -> String:
	var text := super._order_bbcode()
	if production:
		text = "[b]" + production.job()["title"] + "[/b]　／　" + production.job()["location"] + "\n会社の残金 %d コイン　（道具は最大600コインまで）\n\n" % production.wallet + text
	return text


func set_character_menu(on: bool) -> void:
	super.set_character_menu(on)
	if production:
		hud.root.visible = true

@rpc("any_peer","call_local","reliable")
func h_sample() -> void:
	if production and "--productiontest" not in OS.get_cmdline_user_args():
		ev.rpc_id(Net.sender(),"toast",["見本セットは撮影だけモードで確認できる。現場では持ち込んだ道具で作ろう",0])
		return
	super.h_sample()


func _unhandled_input(event: InputEvent) -> void:
	if production and production.phase == 0 and not character_open and not help_open and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			h_accept_job.rpc_id(1,event.physical_keycode-KEY_1)
			return
	super._unhandled_input(event)
	if production:
		hud.root.visible = true
