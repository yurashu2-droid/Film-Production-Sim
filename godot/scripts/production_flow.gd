extends Node
const Office := preload("res://scripts/production_office.gd")
const Assets := preload("res://scripts/production_assets.gd")
const Location := preload("res://scripts/production_location.gd")
const ProductionProp := preload("res://scripts/production_prop.gd")
const MovieProp := preload("res://scripts/production_movie_prop.gd")
const Notes := preload("res://scripts/production_notes.gd")
const JOBS := [
	{"title":"月下の城と大爆発", "location":"倉庫", "description":"廃材で城を作り、告白 → 背後の爆発 → 再会を撮る。見えない裏側は節約していい。"},
	{"title":"スタジオで月下の城", "location":"室内スタジオ", "description":"狭い貸しスタジオで大作を撮る。機材を通し、光と構図を工夫しよう。"},
	{"title":"青空の下でも夜の城", "location":"野外", "description":"屋外ロケを夜の城に見せる。画角の外はただの空き地でも、映れば映画だ。"}
]
const HOME_TRUCK := Vector3(80, 0, 18)
const SITE_TRUCK := Vector3(16.3, 0, 6.5)
const OFFSET := HOME_TRUCK - SITE_TRUCK
var game: Node
var phase := 0
var wallet := 600
var lease_left := 600.0
var expired := false
var chosen_job := 0
var trip_time := 0.0
var last_payment := 0
var expenses := 0
var last_flubs: Array[String] = []
var notes: RefCounted
var bonus_progress := ""
const BONUS_TITLES := ["一発OKで撮り切る", "スタッフ映り込み0.5秒以内", "月を合計2秒映す"]
var _sync := 0.0
var _notice := 0
var _loaded: Array[int] = []
var _home_layout := {}
var _configured_job := -1
var _site_root: Node3D
var _office_root: Node3D
var _trip_camera: Camera3D
var _original_walls: Array[StaticBody3D] = []
var _warnings := [120.0, 60.0, 30.0]
var _world_environment: Environment

func setup(owner_game: Node) -> void:
	game = owner_game
	notes = Notes.new()
	notes.game = game
	for item in [["lift_cart",Vector3(68,0,18)],["cleaning_cart",Vector3(66,0,18)]]:
		var cart: Node = ProductionProp.new()
		cart.build_model(item[0])
		game.stage._register(cart,item[1]-OFFSET,0.0)
	for item in [["dragon_skull",Vector3(51,0.05,17)],["witch_cauldron",Vector3(54,0.05,19)]]:
		var prop: Node = MovieProp.new()
		prop.build_model(item[0])
		game.stage._register(prop,item[1]-OFFSET,0.0)
	_office_root = Office.build(game, game.font)
	var decor := Assets.decorate(_office_root, "office")
	decor.position = Vector3(74, 0, -4)
	for child in game.stage.get_children():
		if child is WorldEnvironment:
			_world_environment = child.environment
			var sky_material := ProceduralSkyMaterial.new()
			sky_material.sky_top_color = Color("638ca9")
			sky_material.sky_horizon_color = Color("c0d0c8")
			sky_material.ground_horizon_color = Color("a6a99d")
			sky_material.ground_bottom_color = Color("626b61")
			var sky := Sky.new()
			sky.sky_material = sky_material
			_world_environment.sky = sky
			_world_environment.background_mode = Environment.BG_SKY
		if child is StaticBody3D and child.position.y > 0.1:
			_original_walls.append(child)
	_trip_camera = Camera3D.new()
	_trip_camera.fov = 70
	game.add_child(_trip_camera)
	if Net.is_host():
		for pid: int in game.props:
			var prop: Node = game.props[pid]
			if prop.kind != "mark":
				_move(prop, prop.global_position + OFFSET)
			_home_layout[pid] = prop.get_state()
		game._set_state(game.S.PREP)
		game.production_sync.rpc(snapshot())
		game.production_move.rpc(Office.SPAWN_POINT, 0.0)
		game._grab_mouse(false)

func job() -> Dictionary:
	return JOBS[chosen_job]

func snapshot() -> Dictionary:
	return {"phase":phase,"wallet":wallet,"lease_left":lease_left,"expired":expired,"chosen_job":chosen_job,"trip_time":trip_time,"last_payment":last_payment,"expenses":expenses,"last_flubs":last_flubs,"bonus_progress":bonus_progress}

func apply(data: Dictionary) -> void:
	var old := phase
	phase = int(data["phase"])
	wallet = int(data["wallet"])
	lease_left = float(data["lease_left"])
	expired = bool(data["expired"])
	chosen_job = int(data["chosen_job"])
	trip_time = float(data["trip_time"])
	last_payment = int(data["last_payment"])
	expenses = int(data["expenses"])
	last_flubs.assign(data["last_flubs"])
	bonus_progress = str(data.get("bonus_progress",""))
	# 事務所・買い物・積み込み・移動中は撮影映像を表示しない。
	game.film.view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if phase in [4,5] else SubViewport.UPDATE_DISABLED
	if phase in [4,5] and (_site_root == null or _configured_job != chosen_job):
		_configure_site()
	game.hud.root.visible = true
	game.input_locked = phase == 3
	if phase != 3 and _trip_camera.current and game.local_player():
		game.local_player().cam.make_current()
	if old != phase:
		game._grab_mouse(phase in [2,4])

func accept(index: int) -> void:
	if phase != 0 or index < 0 or index >= JOBS.size():
		return
	chosen_job = index
	phase = 1
	expired = false
	lease_left = 600.0
	expenses = 0
	last_payment = 0
	last_flubs.clear()
	notes.reset()
	bonus_progress = ""
	game.order = {}
	game.takes = []
	game._take_data = []
	game.selected = 0
	game.host_ev("order", [game.order])
	game.host_ev("takes", [[],0])
	game._set_state(game.S.ORDER)
	game.production_sync.rpc(snapshot())

func pack() -> void:
	expenses = game.order_cost()
	wallet -= expenses
	# Existing order placement puts large rentals in the original bay; bring them to the company yard.
	for prop: Node in game.props.values():
		if prop.absent or prop.kind == "mark" or prop.kind == "truck":
			continue
		if prop.rider_of == game.truck.pid:
			continue
		if prop.global_position.x < 30.0:
			_move(prop, prop.global_position + OFFSET)
	phase = 2
	game.production_sync.rpc(snapshot())
	game.host_ev("toast", ["積んだ物だけ持っていける。廃材も忘れずに！ 全員軽トラへ",0])

func cargo() -> Array[int]:
	var result: Array[int] = []
	var held_ids: Array[int] = []
	for player: Node in game.players.values():
		if player.held != 0:
			held_ids.append(player.held)
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.absent or prop.kind in ["truck","mark"]:
			continue
		var carrier: int = prop.rider_of
		var seen := 0
		while carrier != 0 and seen < game.props.size():
			if carrier == game.truck.pid:
				result.append(pid)
				break
			var parent_prop: Node = game.props.get(carrier)
			carrier = parent_prop.rider_of if parent_prop else 0
			seen += 1
		if (prop.holder != 0 or pid in held_ids) and not pid in result:
			result.append(pid)
	return result

func crew_ready() -> String:
	var count := 0
	for player: Node3D in game.players.values():
		if player.global_position.distance_to(HOME_TRUCK) < 9.0:
			count += 1
	return "軽トラのそば　%d / %d 人" % [count,game.players.size()]

func can_depart() -> bool:
	if phase != 2:
		return false
	for player: Node3D in game.players.values():
		if player.global_position.distance_to(HOME_TRUCK) >= 9.0:
			return false
	var packed := cargo()
	return game.film.pid in packed and game.clapper.pid in packed

func loadout_status() -> String:
	var ids := cargo()
	var lines: Array[String] = []
	for prop: Node in [game.film,game.clapper,game.spots[0],game.spots[1]]:
		lines.append(("✔ " if prop.pid in ids else "□ ") + prop.label)
	var extra := {}
	for pid in ids:
		var prop: Node = game.props[pid]
		if prop.kind not in ["camera","clapper","spot"]:
			extra[prop.label] = int(extra.get(prop.label,0)) + 1
	var kinds: Array = ids.map(func(pid): return game.props[pid].kind)
	var castle := ids.any(func(pid): return "castle" in game.props[pid].tags)
	var height := kinds.any(func(kind): return kind in ["balcony","riser","carton","applebox"])
	var blast := "fx" in kinds or "boomflat" in kinds
	lines.append("")
	lines.append(("✔ " if castle else "□ ") + "城の見た目：廃板・書割など")
	lines.append(("✔ " if height else "□ ") + "高い足場：足場・バルコニーなど")
	lines.append(("✔ " if blast else "□ ") + "爆発：効果機 or 無料の爆炎書割")
	for label in extra:
		lines.append("・%s ×%d" % [label,extra[label]])
	return "\n".join(lines)

func depart() -> void:
	if not can_depart():
		game.host_ev("toast", ["カメラとカチンコを積み、全員が軽トラのそばへ集まろう",1])
		return
	_loaded = cargo()
	for pid in _loaded:
		var prop: Node = game.props[pid]
		if prop.holder != 0:
			game.host_release(prop)
			game._set_rider(prop,game.truck,game.truck.global_transform.affine_inverse()*prop.global_transform)
	phase = 3
	trip_time = 0.0
	game.production_sync.rpc(snapshot())
	game.production_move.rpc(HOME_TRUCK + Vector3(-1.0,1.0,0), -PI/2)

func _physics_process(delta: float) -> void:
	if phase == 3:
		_trip_camera.global_position = game.truck.global_position + Vector3(-4.8,2.8,-4.8)
		_trip_camera.look_at(game.truck.global_position + Vector3(0,0.8,0))
		_trip_camera.make_current()
	if not Net.is_host():
		return
	if phase == 3:
		trip_time += delta
		_move(game.truck, HOME_TRUCK + Vector3(0,0,minf(trip_time,8.0)*5.0))
		if trip_time >= 8.0:
			arrive()
	elif phase == 4 and not expired and game.state != game.S.DELIVERED:
		if game.state == game.S.TAKE:
			notes.tick(delta)
			bonus_progress = "映り込み %.1f秒" % notes.crew_seconds if chosen_job == 1 else ("月 %.1f / 2秒" % notes.moon_seconds if chosen_job == 2 else "最初のテイク" if game.takes.is_empty() else "撮り直し中")
		lease_left = maxf(0.0,lease_left - delta)
		if _notice < _warnings.size() and lease_left <= _warnings[_notice]:
			game.host_ev("toast", ["スタジオ返却まで %d秒！" % int(_warnings[_notice]),0])
			_notice += 1
		if lease_left <= 0.0:
			expire()
	_sync -= delta
	if _sync <= 0.0:
		_sync = 0.5
		game.production_sync.rpc(snapshot())

func arrive() -> void:
	# Use cargo's relation to the truck; preserve stacked dollies and boxes.
	var shift: Vector3 = SITE_TRUCK - game.truck.global_position
	_move(game.truck, SITE_TRUCK)
	for pid in _loaded:
		_move(game.props[pid], game.props[pid].global_position + shift)
	phase = 4
	lease_left = 600.0
	_notice = 0
	game._set_state(game.S.PREP)
	game.production_sync.rpc(snapshot())
	game.production_move.rpc(game.SPAWN, -PI/2)
	game.host_ev("toast", ["スタジオ返却まで10分！ まず荷下ろし。Tabで操作確認",0])

func expire() -> void:
	expired = true
	if game.replaying:
		game._end_replay()
	if game.state == game.S.TAKE:
		game._cut()
	elif game.takes.is_empty():
		game._begin_take()
		game._cut()
	else:
		game._set_state(game.S.RESULT)
	game.production_sync.rpc(snapshot())
	game.host_ev("toast", ["管理人『次の予約が入ってるよ！』 いまあるテイクを選んで納品しよう",1])

func settle(index: int) -> void:
	var passed: Array = game.takes[index]["passed"]
	var count := passed.count(true)
	last_payment = take_fee(index)
	var extras: Dictionary = game.takes[index].get("extras",{})
	wallet += last_payment
	last_flubs.clear()
	last_flubs.append("追加注文『%s』：%s" % [BONUS_TITLES[chosen_job],"達成！ +150コイン" if extras.get("bonus_ok",false) else "今回は未達"])
	last_flubs.append_array(notes.observations(extras))
	for result: Dictionary in game.takes[index]["results"]:
		if not result["ok"]:
			last_flubs.append(str(result["title"]) + "：" + str(result["detail"]))
	if count == 3:
		last_flubs.append("依頼主『これをこの予算で？ 次も頼むよ！』")
	elif count == 0:
		last_flubs.append("依頼主『予告編の素材としては…味がある』")
	phase = 5
	game.production_sync.rpc(snapshot())
	game.host_ev("toast",["納品完了！ %dコイン。事務所に帰って次の一本へ" % last_payment,0])
	game._grab_mouse(false)

func take_fee(index: int) -> int:
	var take: Dictionary = game.takes[index]
	var count: int = take["passed"].count(true)
	return 150 + count * 250 + (300 if count == 3 else 0) + (150 if take.get("extras",{}).get("bonus_ok",false) else 0)

func bonus_status() -> String:
	var text: String = "追加注文 +150コイン：" + BONUS_TITLES[chosen_job]
	if game.state in [game.S.RESULT,game.S.REPLAY] and not game.takes.is_empty():
		var extra: Dictionary = game.takes[game.selected].get("extras",{})
		return text + ("　✔ 達成" if extra.get("bonus_ok",false) else "　未達") + "\n納品料見込み：%dコイン" % take_fee(game.selected)
	if game.state == game.S.TAKE:
		return text + "　" + bonus_progress
	return text + "（本編3場面の成立も必要）"

func return_office() -> void:
	if phase != 5:
		return
	for prop: Node in game.props.values():
		if prop.holder != 0:
			game.host_release(prop)
		if prop.rider_of != 0:
			game.host_unload(prop)
		if "operator" in prop and prop.operator != 0:
			game._stop_operating(prop)
		if _home_layout.has(prop.pid):
			prop.restore(_home_layout[prop.pid])
	game.order = {}
	game._apply_order()
	_move(game.truck,HOME_TRUCK)
	# All company and free props return to their initial yard positions; rental selection is next job's choice.
	for pid in _home_layout:
		var prop: Node = game.props[pid]
		if prop.kind != "mark" and not prop.absent and prop.rider_of == 0:
			_move(prop, _home_layout[pid][0])
	phase = 0
	game._set_state(game.S.PREP)
	game.production_sync.rpc(snapshot())
	game.production_move.rpc(Office.SPAWN_POINT, 0.0)

func _move(prop: Node3D, pos: Vector3) -> void:
	var carrier: int = prop.rider_of
	var local: Transform3D = prop.ride_local
	var state: Array = prop.get_state()
	state[0] = pos
	prop.restore(state)
	if carrier != 0 and game.props.has(carrier):
		game._set_rider(prop,game.props[carrier],local)

func _configure_site() -> void:
	_configured_job = chosen_job
	if _site_root:
		_site_root.queue_free()
	_site_root = Node3D.new()
	_site_root.name = "JobLocation"
	game.add_child(_site_root)
	for wall in _original_walls:
		wall.visible = chosen_job == 0
		for collider in wall.get_children():
			if collider is CollisionShape3D:
				collider.set_deferred("disabled",chosen_job != 0)
	if chosen_job == 1:
		var studio := Assets.decorate(_site_root,"studio")
		studio.position = Vector3(0,0,-2)
	elif chosen_job == 2:
		var yard := Assets.decorate(_site_root,"yard")
		yard.position = Vector3(8,0,-6)
		var label := Label3D.new()
		label.text = "空き地ロケ　／　10分だけ貸切"
		label.font = game.font
		label.font_size = 90
		label.position = Vector3(0,3.0,-10.0)
		_site_root.add_child(label)
	Location.build(_site_root,game.font,chosen_job)

