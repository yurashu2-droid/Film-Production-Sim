extends "res://scripts/main.gd"
const Flow := preload("res://scripts/production_flow.gd")
const ProductionHud := preload("res://scripts/production_hud.gd")
const ProductionPing := preload("res://scripts/production_ping.gd")
const ProductionExport := preload("res://scripts/production_export.gd")
var production_export: Node
var production_ping: CanvasLayer
var _ping_last: Dictionary = {}
var _ping_local_next := 0.0
var production: Node
var production_hud: CanvasLayer
var _legacy_mode := false
var _crew_epoch := 0

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
	production_ping = ProductionPing.new()
	production_ping.game = self
	add_child(production_ping)
	production_export = ProductionExport.new()
	production_export.game = self
	add_child(production_export)
	if "--productionnettest" in OS.get_cmdline_user_args():
		var test: Node = load("res://tests/productionnettest.gd").new()
		test.game = self
		add_child(test)

func _input(event: InputEvent) -> void:
	if production_export != null and not production_export.last_saved.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_O and not character_open and not help_open:
		production_export.open_saved()
		get_viewport().set_input_as_handled()
		return
	if production_export != null and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P and state == S.RESULT and not character_open and not help_open:
		production_export.begin()
		get_viewport().set_input_as_handled()
		return
	if production != null and not ui_blocking() and local_player() != null:
		var ping_key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V
		var ping_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE
		if (ping_key or ping_mouse) and _ping_phase_allowed():
			var now := Time.get_ticks_msec()/1000.0
			if now < _ping_local_next:
				return
			_ping_local_next = now + 0.7
			var me: Node = local_player()
			var camera: Camera3D = film.view_cam if me.operating == film.pid else me.cam
			h_ping.rpc_id(1,camera.global_position,-camera.global_basis.z)
			get_viewport().set_input_as_handled()
			return
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
	move_crew(point,player.aim_yaw,who)
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
		if n == "state" and production_export != null:
			production_export.replay_state_changed(state)

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
		var point: Vector3 = Flow.HOME_TRUCK + Vector3(-3,0.1,1) if production.phase in [2,3] else (SPAWN if production.phase in [4,5] else Flow.Office.SPAWN_POINT)
		point = _open_join_point(point,Net.sender())
		production_move.rpc(point,0.0,Net.sender(),_crew_epoch)


func _open_join_point(base: Vector3, joining: int) -> Vector3:
	# 途中参加でIDの並びが変わっても、既に立っている仲間を押さない。
	for offset in [Vector3.ZERO,Vector3(-1.2,0,0),Vector3(1.2,0,0),Vector3(0,0,1.2),Vector3(-1.2,0,1.2),Vector3(1.2,0,1.2)]:
		var point: Vector3 = base + offset
		var occupied := false
		for peer_id in players:
			if peer_id == joining: continue
			var other: Vector3 = players[peer_id].global_position
			if Vector2(other.x-point.x,other.z-point.z).length() < 0.8:
				occupied = true
				break
		if not occupied: return point
	return base

@rpc("authority","call_local","reliable")
func production_sync(data: Dictionary) -> void:
	if production:
		production.apply(data)

@rpc("authority","call_local","reliable")
func production_move(point: Vector3, yaw: float, only_peer: int = 0, epoch: int = -1) -> void:
	if epoch >= 0:
		_crew_epoch = epoch
	# 接続順によるDictionaryの並びの違いで、仲間と同じ場所に出ないようにする。
	var member_ids := players.keys()
	member_ids.sort()
	for i in member_ids.size():
		var player: Node = players[member_ids[i]]
		if only_peer != 0 and player.peer_id != only_peer:
			continue
		player._net.clear()
		player.global_position = point if only_peer != 0 else point + Vector3(float(i)*0.8,0,0)
		player.velocity = Vector3.ZERO
		player.aim_yaw = yaw
		player.vis.rotation.y = yaw + PI
		player.aim_pitch = -0.18
		player._motion = ""
		player._run_requested = false
		player.vis.play("idle",0.0,true)
	if production:
		_grab_mouse(production.phase in [2,4])


func move_crew(point: Vector3, yaw: float, only_peer: int = 0) -> void:
	_crew_epoch += 1
	production_move.rpc(point,yaw,only_peer,_crew_epoch)


func send_player_state(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String) -> void:
	if _legacy_mode:
		super.send_player_state(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name)
	else:
		rx_production_player.rpc(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name,_crew_epoch)


@rpc("any_peer","call_remote","unreliable_ordered")
func rx_production_player(pos: Vector3, body_yaw: float, a_yaw: float, a_pitch: float, h_dist: float, h_yaw: float, h_pitch: float, anim_name: String, epoch: int) -> void:
	# 車移動前の遅延パケットを到着後のプレイヤー位置へ適用しない。
	if epoch == _crew_epoch:
		super.rx_player(pos,body_yaw,a_yaw,a_pitch,h_dist,h_yaw,h_pitch,anim_name)

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
	if production and state == S.RESULT and not takes.is_empty():
		var comments: Array[String] = production.notes.observations(takes[selected].get("extras",{}))
		if not comments.is_empty():
			text = text.replace("[color=#ffdb59][R][/color]", "[color=#efbf6b]NG日誌[/color]\n" + "\n".join(comments) + "\n\n[color=#ffdb59][R][/color]")
	if production and state == S.RESULT and not takes.is_empty():
		text += "\n[color=#ffdb59][P][/color] 見返して8コマ保存（画像・一覧PNG）\n保存先：ユーザーデータの film_stills フォルダ"
		if production_export != null and not production_export.last_saved.is_empty():
			text += "\n[color=#ffdb59][O][/color] 保存した8コマのフォルダを開く"
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


func _ping_phase_allowed() -> bool:
	return production != null and production.phase in [0,2,4] and state in [S.PREP,S.COUNTDOWN,S.TAKE] and not replaying and not production.expired


@rpc("any_peer","call_local","reliable")
func h_ping(from: Vector3, direction: Vector3) -> void:
	if not Net.is_host() or production_ping == null or not _ping_phase_allowed():
		return
	var who := Net.sender()
	var player: Node = players.get(who)
	if player == null or not from.is_finite() or not direction.is_finite() or direction.length_squared() < 0.9 or direction.length_squared() > 1.1:
		return
	var origin: Vector3 = film.lens.global_position if player.operating == film.pid else player.global_position + Vector3(0,1.85,0)
	if origin.distance_to(from) > 6.0:
		return
	var now := Time.get_ticks_msec()/1000.0
	if now - float(_ping_last.get(who,-10.0)) < 0.7:
		return
	var query := PhysicsRayQueryParameters3D.create(from,from+direction.normalized()*30.0,1|2|4|16)
	var excluded: Array[RID] = [player.get_rid()]
	if player.held != 0 and props.has(player.held):
		excluded.append(props[player.held].get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_ping_last[who] = now
	var name_of_sender := "制作班"
	for member: Array in _roster:
		if member[0] == who:
			name_of_sender = PLAYER_NAMES[member[1]]
			break
	var item_name := "ここ！"
	var collider: Object = hit["collider"]
	if collider is Node and "pid" in collider and props.has(collider.pid):
		item_name = collider.label
	production_ping_event.rpc(who,hit["position"],name_of_sender+"："+item_name)


@rpc("authority","call_local","reliable")
func production_ping_event(sender: int, point: Vector3, text: String) -> void:
	if production_ping != null:
		production_ping.show_ping(sender,point,text)


@rpc("any_peer","call_local","reliable")
func h_export_replay(index: int, token: int) -> void:
	if not Net.is_host():
		return
	var who := Net.sender()
	var allowed: bool = production != null and production.phase == 4 and players.has(who) and state == S.RESULT and index >= 0 and index < _take_data.size()
	if allowed:
		allowed = (_take_data[index]["frames"] as Array).size() >= 2
	if allowed:
		super.h_replay(index)
		allowed = state == S.REPLAY
	export_ready.rpc_id(who,allowed,token)


@rpc("authority","call_local","reliable")
func export_ready(success: bool, token: int) -> void:
	if production_export != null:
		production_export.accept_reply(success,token)
