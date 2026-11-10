extends Node
## スロー光線（2026-11-10 ユーザーの案）：手で持って向ける光線。浴びている物と人だけが、ゆっくりになる。
## カメラの設定でスローにするのではなく、現場で誰かが狙う道具（狙いがずれる・仲間を巻き込む、が起きる）。
##   ・会社の備品（懐中電灯の形。夜用フィルターの隣）。持って F で、出す・止める。置いたままでも出続ける（頭のほうへ出る）
##   ・浴びている物と人には、時計の目盛りと針・少し前の姿のコマ（残像）・浮くほこりが出る（フィルムにも映る）。
##     見た目は vfx/vfx_slow_field.gd。出している間は、懐中電灯の頭が光る
##   ・届く範囲は、うすい円すいと、その中をゆっくり流れるほこりで見える（制作班にだけ。フィルムには映らない）。
##     持っているだけ（まだ出していない）の間も、円すいがうすく出る（どこへ向いているかの下見）
##   ・物（落ちる物・転がる岩・爆風で飛ぶ物・投げた物）：速さが 0.3 倍になり、落ち方もゆっくりになる。光線から出ると、元の速さに戻る
##   ・人（制作班・雇った役者）：歩く・跳ぶ・落ちるが 0.3 倍になり、体の動きもゆっくりになる
##   ・持っている人自身と、誰かが持っている物・固定した物には効かない
## 誰が浴びているかは、ホストが決めて全員に送る（本番中は記録に残り、見返しでも光が出る）。
## 物の速さを変えるのはホスト。自分の体を遅くするのは、各自の画面（自分の体は、自分の画面で動かしているため）
const Prop := preload("res://scripts/prop.gd")
const MODEL := "res://assets/production/scrap/P016_flashlight_rebuilt.glb"
const HOME_AT := Vector3(68.9, 0.05, 19.95)
const LENGTH := 0.42                 # 懐中電灯の長さ（この長さになるように、素材を拡大縮小する）
const SLOW := 0.3                    # 浴びている間の速さの倍率
const RANGE := 9.0                   # 光線の届く距離
const HALF_ANGLE := 0.17             # 光線の広がり（ラジアン。約10度）
const JOLT := 3.0                    # 浴びている物の速さが1コマでこれより変わったら（爆風・ぶつかった）、その分もゆっくりにする
const SlowField := preload("res://vfx/vfx_slow_field.gd")

var game: Node
var ray: RigidBody3D
var on := false                      # 光線を出しているか
var props_in: Array = []             # 浴びている物（物のID）
var players_in: Array = []           # 浴びている制作班（プレイヤーの番号）
var actors_in: Array = []            # 浴びている役者（役の番号）
var beam_override: Array = []        # 確認用：[出どころ, 向き] を決め打ちにする
var _axis := Vector3.FORWARD         # 懐中電灯の頭の向き（物から見て）
var _lens: MeshInstance3D
var _slowed := {}                    # ゆっくりにしてある物（物のID → 前のコマの速さ）（ホスト）
var _prev := {}                      # ゆっくりにしている人 → 前のコマの場所
var _anim_slow := {}                 # 体の動きをゆっくりにしてある人（見た目）
var _fx: Node3D                      # 見た目（vfx/vfx_slow_field.gd）


func setup() -> void:
	process_physics_priority = 60      # 人と物が動いたあとで、遅くする
	var p: RigidBody3D = Prop.new()
	p.kind = "slowray"
	p.label = "スロー光線（懐中電灯）"
	p.mass = 0.6
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	var raw: AABB = game.stage.merged_aabb(model)
	var long_axis := raw.size.max_axis_index()
	var scale_by := LENGTH / maxf(raw.size[long_axis], 0.001)
	model.scale = Vector3.ONE * scale_by
	p.visual = model
	p.add_child(model)
	var box := AABB(raw.position * scale_by, raw.size * scale_by)
	p.center = box.get_center()
	p.half = box.size * 0.5
	p.hold_min = maxf(1.0, p.half.length() + 0.8)
	game.stage._shape(p, box.get_center(), box.size * 0.97, false)
	ray = game.stage._register(p, HOME_AT, 0.4)
	_axis = Vector3.ZERO
	_axis[long_axis] = _head_side(model, long_axis, raw)
	# 出している間だけ光る、頭の所の小さな玉
	_lens = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.045
	ball.height = 0.09
	_lens.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.75, 0.65, 1.0)
	_lens.material_override = glow
	_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lens.position = p.center + _axis * (p.half[long_axis] - 0.02)
	_lens.visible = false
	ray.add_child(_lens)
	_fx = SlowField.new()
	_fx.name = "SlowField"
	game.add_child(_fx)
	# 見た目の型：project.godot の vfx/slow_ray_style（無ければ clock）。起動の引数 --slow-style=psychic でも替えられる
	var look := str(ProjectSettings.get_setting("vfx/slow_ray_style", "clock"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--slow-style="):
			look = arg.get_slice("=", 1)
	_fx.setup(RANGE, HALF_ANGLE, look)
	if Net.is_host() and game.production != null:
		game.production._home_layout[ray.pid] = ray.get_state()


# 懐中電灯の頭（太いほう）が、長い軸のどちら側か（+1 か -1）。頭は太いので、形の点は頭のほうに多く寄っている
func _head_side(model: Node3D, axis: int, box: AABB) -> float:
	var sum := 0.0
	var count := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var node: Node3D = mi
		while node != null and node != model:
			xf = node.transform * xf
			node = node.get_parent() as Node3D
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# 太さで重みを付ける（軸から遠い点ほど、頭の縁）
			for v: Vector3 in verts:
				var p: Vector3 = xf * v
				var off: Vector3 = p - box.get_center()
				var along: float = off[axis]
				off[axis] = 0.0
				sum += along * off.length()
				count += 1
	return 1.0 if count == 0 or sum >= 0.0 else -1.0


# ---- 自分の操作 ----

func _mine(me: Node) -> bool:
	return ray != null and (int(me.held) == int(ray.pid) or (int(me.held) == 0 and me.target == ray))


func hook_f(me: Node) -> bool:
	if not _mine(me):
		return false
	h_switch.rpc_id(1)
	return true


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	if ray == null:
		return {}
	var words := "F スロー光線を%s（向けた物と人が、ゆっくりになる）" % ("止める" if on else "出す")
	if int(me.held) == int(ray.pid):
		return {"keys_all": words + "\n" + str(game.hold_hint())}
	if int(me.held) == 0 and me.target == ray:
		return {"keys": words}
	return {}


@rpc("any_peer", "call_local", "reliable")
func h_switch() -> void:
	if not Net.is_host() or game.replaying or ray == null or ray.absent:
		return
	var who := Net.sender()
	var pl: Node = game.players.get(who)
	if pl == null or (int(ray.holder) != who and int(ray.holder) != 0):
		return
	game.host_ev("slow_on", [not on])


# ---- 光線 ----

# 光線の [出どころ, 向き]。出していなければ、空
func beam() -> Array:
	return aim() if on else []


# 懐中電灯が向いている [出どころ, 向き]（出していなくても）。しまってあれば、空
func aim() -> Array:
	if ray == null or ray.absent:
		return []
	if not beam_override.is_empty():
		return beam_override
	var at: Vector3 = ray.center_global()
	var holder: Node3D = game.players.get(int(ray.holder)) as Node3D
	if holder != null:
		# 持っている間は、持っている人の頭から、懐中電灯のほうへ（持った物は、視線の先にある）
		var from: Vector3 = holder.vis.head_pos()
		var d: Vector3 = at - from
		if d.length() > 0.2:
			return [at, d.normalized()]
	return [at, (ray.global_transform.basis * _axis).normalized()]


# その場所の真下の床の高さ（届く範囲を床に映すため）。床が見つからなければ、足もとの高さとして 1m 下
func _floor_under(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3(0.0, -8.0, 0.0), 1)
	query.exclude = [ray.get_rid()]
	var holder: Node3D = game.players.get(int(ray.holder)) as Node3D
	if holder != null:
		query.exclude = [ray.get_rid(), (holder as CollisionObject3D).get_rid()]
	var hit: Dictionary = ray.get_world_3d().direct_space_state.intersect_ray(query)
	# 物の上ではなく、床の高さがほしい：物（RigidBody）に当たったら、その下の床を探さずに、いまの床の見当（0）へ
	if hit.is_empty() or hit["collider"] is RigidBody3D:
		return minf(at.y - 1.0, 0.0) if hit.is_empty() else 0.0
	return float((hit["position"] as Vector3).y)


func _in_beam(b: Array, point: Vector3) -> bool:
	var d: Vector3 = point - (b[0] as Vector3)
	var dist := d.length()
	if dist > RANGE or dist < 0.35:
		return false
	return (b[1] as Vector3).angle_to(d) <= HALF_ANGLE


# ---- 誰が浴びているか（ホスト）----

func _physics_process(_delta: float) -> void:
	if ray == null or game.production == null:
		return
	_lens.visible = on
	if Net.is_host() and not game.replaying:
		_host_scan()
	_slow_people()
	# 届く範囲（制作班だけ）：出している間と、誰かが持っている間（うすく）
	var showing: bool = on or int(ray.holder) != 0
	var where: Array = aim() if showing else []
	_fx.cone(where, 1.0 if on else 0.3, _floor_under(where[0]) if not where.is_empty() else 0.0)


func _host_scan() -> void:
	var b := beam()
	var props: Array = []
	var players: Array = []
	var actors: Array = []
	if not b.is_empty():
		for p: Variant in game.props.values():
			var body := p as RigidBody3D
			if body == null or body == ray or bool(body.absent) or int(body.holder) != 0 or body.freeze:
				continue
			if _in_beam(b, body.center_global()):
				props.append(int(body.pid))
		for id: Variant in (game.players as Dictionary).keys():
			var pl: Node3D = game.players[id] as Node3D
			if pl == null or int(id) == int(ray.holder):
				continue
			if _in_beam(b, pl.global_position + Vector3(0.0, 0.9, 0.0)):
				players.append(int(id))
		for a: Variant in game.actors:
			var actor := a as Node3D
			if actor == null or not actor.visible or (actor.has_method("present") and not bool(actor.present())):
				continue
			if _in_beam(b, actor.global_position + Vector3(0.0, 0.9, 0.0)):
				actors.append(int(actor.aid))
	props.sort()
	players.sort()
	actors.sort()
	_slow_props(props)
	if props != props_in or players != players_in or actors != actors_in:
		game.host_ev("slow_set", [props, players, actors])


# 物の速さ（ホスト）：浴びた瞬間に 0.3 倍、落ち方も同じ見え方になるように重力を弱める。出たら戻す
func _slow_props(now: Array) -> void:
	for pid: int in now:
		var body: RigidBody3D = game.props.get(pid) as RigidBody3D
		if body == null:
			continue
		if not _slowed.has(pid):
			body.linear_velocity *= SLOW
			body.angular_velocity *= SLOW
		else:
			# 浴びている間に、爆風やぶつかりで急に速くなった分も、ゆっくりにする
			var before: Vector3 = _slowed[pid]
			var jolt: Vector3 = body.linear_velocity - before
			if jolt.length() > JOLT:
				body.linear_velocity = before + jolt * SLOW
		body.gravity_scale = SLOW * SLOW
		_slowed[pid] = body.linear_velocity
	for pid: int in _slowed.keys():
		if pid in now:
			continue
		_slowed.erase(pid)
		var body: RigidBody3D = game.props.get(pid) as RigidBody3D
		if body == null or int(body.holder) != 0 or body.freeze:
			continue            # 誰かが持った・固定した：その仕組みに任せる
		body.linear_velocity /= SLOW
		body.angular_velocity /= SLOW
		body.gravity_scale = 1.0


# 人の速さ：動いた分を、前のコマの場所から 0.3 倍に引き戻す。自分の体は自分の画面で、役者はホストで
func _slow_people() -> void:
	var live := {}
	if not game.replaying and int(game.state) != int(game.S.REPLAY):
		var me: Node3D = game.local_player() as Node3D
		if me != null and int(me.peer_id) in players_in:
			live[me] = true
		if Net.is_host():
			for a: Variant in game.actors:
				var actor := a as Node3D
				if actor != null and int(actor.aid) in actors_in:
					live[actor] = true
	for body: Node3D in live:
		if _prev.has(body):
			var from: Vector3 = _prev[body]
			body.global_position = from + (body.global_position - from) * SLOW
		_prev[body] = body.global_position
	for body: Variant in _prev.keys():
		if not live.has(body):
			_prev.erase(body)
	# 体の動き（見た目）も、ゆっくりに（全員の画面）
	var slow_now := {}
	for id: Variant in players_in:
		var pl: Node = game.players.get(int(id))
		if pl != null:
			slow_now[pl] = true
	for a: Variant in game.actors:
		if a != null and int(a.aid) in actors_in:
			slow_now[a] = true
	for body: Variant in slow_now:
		if not _anim_slow.has(body):
			_anim_slow[body] = true
			_anim_speed(body, SLOW)
	for body: Variant in _anim_slow.keys():
		if not slow_now.has(body):
			_anim_slow.erase(body)
			if is_instance_valid(body):
				_anim_speed(body, 1.0)


func _anim_speed(body: Node, speed: float) -> void:
	var vis: Node = body.get("vis")
	if vis != null and vis.get("anim") != null:
		(vis.anim as AnimationPlayer).speed_scale = speed


# ---- 全員の画面 ----

func hook_events() -> Array:
	return ["slow_on", "slow_set"]


func hook_rec_events() -> Array:
	return ["slow_on", "slow_set"]


func hook_event(n: String, a: Array) -> void:
	match n:
		"slow_on":
			on = bool(a[0])
			Sfx.play("ui_select" if on else "ui_back", ray.global_position if ray != null else null, -6.0)
		"slow_set":
			props_in = (a[0] as Array).duplicate()
			players_in = (a[1] as Array).duplicate()
			actors_in = (a[2] as Array).duplicate()
			_sync_auras()


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "slow_on", [on])
		game.ev.rpc_id(who, "slow_set", [props_in, players_in, actors_in])


func hook_return_office() -> void:
	if Net.is_host() and on:
		game.host_ev("slow_on", [false])


# 浴びている物と人を、見た目（目盛り・コマの残像・ほこり）へ渡す
func _sync_auras() -> void:
	var want := {}
	for pid: Variant in props_in:
		var body: Node3D = game.props.get(int(pid)) as Node3D
		if body != null:
			want[body] = [body.center as Vector3, clampf((body.half as Vector3).length() * 1.35, 0.4, 2.6), body.get("visual")]
	for id: Variant in players_in:
		var pl: Node3D = game.players.get(int(id)) as Node3D
		if pl != null:
			want[pl] = [Vector3(0.0, 0.95, 0.0), 1.2, null]
	for a: Variant in game.actors:
		if a != null and int(a.aid) in actors_in:
			want[a] = [Vector3(0.0, 0.95, 0.0), 1.2, null]
	_fx.sync(want)
