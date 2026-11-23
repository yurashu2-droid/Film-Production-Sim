extends Node
## 遠征先の備品。倉庫・スタジオ・屋外それぞれの候補から3点を選び、到着時だけ出す。
const MovieProp := preload("res://scripts/production_movie_prop.gd")
const EVENT := "site_props_layout"
const CANDIDATES := [
	["scrap_broom", "scrap_travel_suitcase", "scrap_first_aid_case", "scrap_park_bench", "scrap_lens_case"],
	["scrap_travel_suitcase", "scrap_director_chair", "scrap_bounce_reflector", "scrap_lens_case", "scrap_makeup_case"],
	["scrap_broom", "scrap_watering_can", "scrap_first_aid_case", "scrap_direction_signpost", "scrap_park_bench"],
]
# 搬入口と会社の機材置き場、撮影範囲の外にある、各現場の使える床。
const SPOTS := [
	[Vector2(14.55, -3.45), Vector2(15.75, -1.64), Vector2(15.0, 0.25)],
	[Vector2(-6.85, -2.50), Vector2(-7.80, -0.63), Vector2(-6.75, 1.30)],
	[Vector2(14.05, -1.0), Vector2(15.80, -0.68), Vector2(14.87, -3.04)],
]

var game: Node
var _pool: Dictionary[String, RigidBody3D] = {}
var _active: Array[int] = []
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	# 他の仕組みが作る小道具のIDを保ったまま、全員の末尾に同じ順で登録する。
	game.startup_ready.connect(_make_pool, CONNECT_ONE_SHOT)


func _make_pool() -> void:
	_rng.randomize()
	for candidates: Array in CANDIDATES:
		for kind: String in candidates:
			if _pool.has(kind):
				continue
			var prop := MovieProp.new()
			prop.build_model(kind)
			game.stage._register(prop, Vector3(_pool.size() * 3.0, -60.0, 0), 0.0)
			prop.set_absent(true)
			_pool[kind] = prop


func hook_events() -> Array:
	return [EVENT]


func hook_event(_name: String, args: Array) -> void:
	var states: Dictionary = args[0]
	_active.clear()
	for prop: RigidBody3D in _pool.values():
		if not states.has(prop.pid):
			prop.set_absent(true)
			continue
		_active.append(prop.pid)
		prop.set_absent(prop.stored_in != 0)
		if Net.is_host():
			prop.restore(states[prop.pid])
		else:
			prop.apply_state(states[prop.pid], true)
			prop.apply_state(states[prop.pid])


func hook_core_event(name: String, _args: Array) -> void:
	if name == "absent":
		# 発注更新は品目全体の表示を戻すため、現地に出していない予備だけは再びしまう。
		for prop: RigidBody3D in _pool.values():
			if prop.pid not in _active:
				prop.set_absent(true)


func hook_production_applied() -> void:
	if not Net.is_host() or _pool.is_empty() or not _active.is_empty():
		return
	var flow: Node = game.production
	if flow.phase != 4 or flow.shoots_home():
		return
	var site: int = flow.site_index()
	var candidates: Array = CANDIDATES[site].duplicate()
	var states := {}
	for spot: Vector2 in SPOTS[site]:
		var prop := _pool[candidates.pop_at(_rng.randi_range(0, candidates.size() - 1))]
		var floor_y: float = prop.half.y - prop.center.y + 0.015
		states[prop.pid] = [Vector3(spot.x, floor_y, spot.y),
				Quaternion(Vector3.UP, _rng.randf_range(-0.45, 0.45)), false]
	game.host_ev(EVENT, [states])


func hook_return_office() -> void:
	if not _active.is_empty():
		game.host_ev(EVENT, [{}])


func hook_sync(who: int) -> void:
	var states := {}
	for pid: int in _active:
		states[pid] = game.props[pid].get_state()
	game.ev.rpc_id(who, EVENT, [states])
