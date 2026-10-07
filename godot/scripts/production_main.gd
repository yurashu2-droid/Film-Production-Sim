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
		elif me.held != 0 and is_action_prop(props[me.held]):
			h_prop_action.rpc_id(1,me.held)
			get_viewport().set_input_as_handled()
		elif is_action_prop(me.target):
			h_prop_action.rpc_id(1,me.target.pid)
			get_viewport().set_input_as_handled()
		elif production.phase == 2 and me.global_position.distance_to(Flow.HOME_TRUCK) < 4.0 and me.held == 0:
			h_depart.rpc_id(1)
			get_viewport().set_input_as_handled()

func is_action_prop(prop: Node) -> bool:
	return prop != null and prop.has_method("set_active") and (not prop.has_method("can_activate") or prop.can_activate())

func prop_action_hint(prop: Node) -> String:
	if prop.kind == "dragon_skull":
		return "口を閉じる" if prop.active else "口を開く"
	if prop.kind == "cleaning_cart":
		return "絞り機を動かす"
	return "下げる" if prop.active else "上げる"

func _recovery_point() -> Vector3:
	if production.phase in [0,1]:
		return Flow.Office.SPAWN_POINT + Vector3(0,0.9,0)
	if production.phase == 2:
		return Flow.HOME_TRUCK + Vector3(-3,1,1)
	if production.phase == 3:
		return truck.global_position + Vector3(-3,1,0)
	return SPAWN + Vector3(0,0.9,0)

func recover_player(player: Node3D) -> void:
	if not production:
		super.recover_player(player)
		return
	player.global_position = _recovery_point()
	player.velocity = Vector3.ZERO
	h_recover_crew.rpc_id(1)

@rpc("any_peer","call_local","reliable")
func h_recover_crew() -> void:
	if not Net.is_host() or not production or replaying:
		return
	var who := Net.sender()
	var player: Node = players.get(who)
	if player == null:
		return
	var point := _recovery_point()
	production_move.rpc(point,player.aim_yaw,who)
	var prop := _held_by(who)
	if prop:
		var saved: Array = prop.get_state()
		saved[0] = point + player.flat_forward() * 2.2
		prop.restore(saved)
		prop.set_holder(who)
		prop.grab_time = Time.get_ticks_msec() / 1000.0
	host_ev("toast",["場外に落ちた制作班を回収。撮影は続行です！",0])

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
	if me == null or prop == null or prop.absent or not is_action_prop(prop) or prop.holder not in [0,Net.sender()]:
		return
	if prop.holder != Net.sender() and me.global_position.distance_to(prop.center_global()) > Player.REACH:
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

func _begin_take() -> void:
	if production:
		production.notes.reset()
		production.bonus_progress = ""
	super._begin_take()

func _cut() -> void:
	var extras := {}
	if production:
		extras = production.notes.finish(production.chosen_job,takes.size(),judge.passed())
	super._cut()
	if production:
		takes[-1]["extras"] = extras
		host_ev("takes",[takes,selected])

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
		text = text.replace("この内容で現場へ","この内容で積み込みへ")
		text = "[b]" + production.job()["title"] + "[/b]　／　" + production.job()["location"] + "\n会社の残金 %d コイン　（道具は最大600コインまで）\n追加注文 +150コイン：" % production.wallet + production.BONUS_TITLES[production.chosen_job] + "\n\n" + text
	return text

func panel_bbcode() -> String:
	var text := super.panel_bbcode()
	if production and production.expired and state == S.RESULT and takes.size() < MAX_TAKES:
		text = text.replace("[color=#ffdb59][Space][/color] 撮り直す（あと%d回）" % (MAX_TAKES-takes.size()),"借り時間終了・撮り直し不可")
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
