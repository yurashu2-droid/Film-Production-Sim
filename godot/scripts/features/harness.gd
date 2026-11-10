extends Node
## ハーネス（吊り具）：人に着ける帯。ハーネスに結んだロープは、着けた人を引く（ロープ・滑車は features/contraptions.gd）。
## 画面の窓や数字は使わない。着ける・結ぶ・重りを落とす・引っぱる・焼き切る、で人が上がる・ぶら下がる・落ちる。
##   ・会社の備品（仕掛けの部品の隣に2つ）。床に置いてある間は、ふつうの物（ロープも結べる）
##   ・着ける：ハーネスを持って F。人（仲間・雇った役者）を見ていれば、その人に着せる。見ていなければ、自分が着る
##   ・外す：手ぶらで、着けている人を見て左クリック。自分のは、真下を見て左クリック。ハーネスは、その人の前に落ちる
##   ・結ぶ：ロープの束を持って、着けている人を見て F（自分のは、真下を見て F）。背中の輪に結ぶ（contraptions.gd の h_tie）
##   ・人の重さは、ロープから見て PERSON_MASS（現場の物は軽い作り物なので、人も軽く数える）。
##     10kg までの物では上がらない。サンドバッグ（12kg）1つで、ゆっくり上がる。台車・壁のセット（20〜40kg）だと、勢いよく上がる。
##     持って歩ける物に結んだ端は、持った人が歩けば、そのまま引ける（力の上限は無い）
##   ・床に立っている人は、引く力が体の重さを超えるまで浮かない。横へは、少しの力では引きずられない
##   ・滑車の真下まで上がりきると、そこで止まる（背中の輪は、滑車の 1m 下まで。重りは、途中でぶら下がったままになる）
## 着けている人は、ホストが決めて全員に送る（"harness"。本番中は記録に残り、見返しでも着けている）。
## 体を動かすのは、その体を動かしている画面（自分の体は自分の画面・雇った役者はホスト）。引く力は、どの画面でも同じ式で出す
const Prop := preload("res://scripts/prop.gd")

const HOME := [[Vector3(70.15, 0.05, 19.6), 0.3], [Vector3(69.45, 0.05, 19.65), -0.3]]
const PERSON_MASS := 6.5             # ロープから見た、人の重さ（kg）。落ちる速さが物より速い（16 と 9.8）ので、物の 10.6kg と釣り合う
const GRAVITY := 16.0                # 人が落ちる速さ（player.gd・actor.gd と同じ）
const GRIP := 0.1                    # 床に立っている人が、1コマにこれより弱い横の引きには動かない（m/秒）
const STRETCH_MAX := 0.8             # ロープがこれより伸びたら、体を直に寄せる
const JAM := 1.0                     # 背中の輪は、滑車（ロープの次の点）に、これより近くへは引き寄せられない（頭がつかえる）
const RING_Y := 1.15                 # 背中の輪の高さ（足もとから）。胴の骨が無いキャラの値
const BASE_UP := 0.19                # 腰の帯の高さ（胴の骨の付け根から。m）
const TALL := 0.30                   # 腰の帯から、胸の帯までの高さ（m）
const LOOK_REACH := 3.4              # 着せる・外す相手までの距離
const LOOK_RADIUS := 0.38
const DOWN_PITCH := -1.0             # これより下を見ていたら「自分のハーネス」を見ている
const BELT := Color(0.95, 0.47, 0.10)
const BELT_R := 0.27                 # 帯の輪の半径（体の太さ）

var game: Node
var parts: Array = []                # ハーネス（物）
var worn: Dictionary = {}            # 着けているハーネス：物のID → 着けている人（正＝参加者の番号 / 負＝−(役の番号+1)）
var _before_take := {}
var _live := {}
var _playback := false
var _looks: Dictionary = {}          # 体に付けた見た目：物のID → [帯, 着けている人]
var _fits: Dictionary = {}           # キャラの種類 → [腰の横の半径, 腰の前後, 胸の横, 胸の前後, 背中の輪の高さ]（m）


func setup() -> void:
	for row: Array in HOME:
		parts.append(_spawn(row[0], float(row[1])))
	if Net.is_host() and game.production != null:
		for p: RigidBody3D in parts:
			game.production._home_layout[p.pid] = p.get_state()


func _spawn(pos: Vector3, yaw: float) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "harness"
	p.label = "ハーネス（吊り具）"
	p.mass = 1.0
	var root := Node3D.new()
	var model := build()
	model.position.y = 0.05
	root.add_child(model)
	p.visual = root
	p.add_child(root)
	var box: AABB = game.stage.merged_aabb(root)
	p.center = box.get_center()
	p.half = box.size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	game.stage._shape(p, box.get_center(), box.size * 0.97, false)
	return game.stage._register(p, pos, yaw)


# ハーネスの形（m）。原点は腰の帯の真ん中。＋Z が体の前、−Z が背中。
# waist・chest：腰と胸の帯の半径（x＝横、y＝前後）。体つきに合わせて変える
static func build(waist: Vector2 = Vector2(BELT_R, BELT_R), chest: Vector2 = Vector2(BELT_R, BELT_R)) -> Node3D:
	var root := Node3D.new()
	var web := StandardMaterial3D.new()
	web.albedo_color = BELT
	web.roughness = 0.85
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.16, 0.18)
	dark.roughness = 0.7
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.74, 0.78)
	steel.metallic = 0.7
	steel.roughness = 0.35
	for k in 2:
		var around: Vector2 = waist if k == 0 else chest
		var belt := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.98
		ring.outer_radius = 1.0
		ring.rings = 24
		ring.ring_segments = 6
		belt.mesh = ring
		belt.material_override = web
		# 輪は半径1で作って、横と前後へ別々に伸ばす（帯の太さは、どの体つきでも同じに見えるよう、高さで出す）
		belt.scale = Vector3(around.x + 0.02, 4.0, around.y + 0.02)
		belt.position.y = TALL * float(k)
		root.add_child(belt)
	# 腰と胸の帯をつなぐ、縦の帯（前2本・後ろ2本）
	for side: float in [-1.0, 1.0]:
		for face: float in [-1.0, 1.0]:
			var low := Vector3(side * waist.x * 0.42, 0.0, face * waist.y * 0.9)
			var high := Vector3(side * chest.x * 0.42, TALL, face * chest.y * 0.9)
			var strap := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.055, low.distance_to(high) + 0.04, 0.02)
			strap.mesh = b
			strap.material_override = web
			var up := (high - low).normalized()
			var across := Vector3.RIGHT
			strap.transform = Transform3D(Basis(across, up, across.cross(up).normalized()).orthonormalized(), (low + high) * 0.5)
			root.add_child(strap)
	# 背中の板と、ロープを結ぶ輪
	var plate := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.16, 0.16, 0.03)
	plate.mesh = pb
	plate.material_override = dark
	plate.position = Vector3(0, TALL - 0.08, -chest.y - 0.01)
	root.add_child(plate)
	var eye := MeshInstance3D.new()
	var et := TorusMesh.new()
	et.inner_radius = 0.035
	et.outer_radius = 0.055
	et.rings = 12
	et.ring_segments = 6
	eye.mesh = et
	eye.material_override = steel
	eye.rotation.z = PI * 0.5
	eye.position = Vector3(0, TALL, -chest.y - 0.045)
	root.add_child(eye)
	# 前の留め金
	var buckle := MeshInstance3D.new()
	var kb := BoxMesh.new()
	kb.size = Vector3(0.09, 0.07, 0.03)
	buckle.mesh = kb
	buckle.material_override = steel
	buckle.position = Vector3(0, 0.0, waist.y + 0.015)
	root.add_child(buckle)
	return root


# ---- 人 ----

# 番号から体へ（正＝参加者 / 負＝雇った役者）
func body_of(who: int) -> Node3D:
	if who > 0:
		return game.players.get(who)
	var i := -who - 1
	return game.actors[i] if who < 0 and i < (game.actors as Array).size() else null


func harness_of(who: int) -> int:
	for pid: int in worn:
		if int(worn[pid]) == who:
			return pid
	return 0


# ハーネスを着けられる人 [[番号, 体], ...]
func _people() -> Array:
	var out: Array = []
	for id: int in game.players:
		var pl: Node3D = game.players[id]
		if pl != null and not pl.vehicle_riding():
			out.append([id, pl])
	for i in (game.actors as Array).size():
		var a: Node3D = game.actors[i]
		if a != null and str(a.grade) != "none" and a.stand_in == null and (a.vis as Node3D).visible:
			out.append([-(i + 1), a])
	return out


func _flat(body: Node3D) -> bool:
	if body.has_method("is_flat"):
		return body.is_flat()
	return float(body.get("down")) > 0.0


# 背中の輪の場所（ロープの端）
func attach_at(pid: int) -> Vector3:
	var body := body_of(int(worn.get(pid, 0)))
	if body == null:
		var p: Node3D = game.props.get(pid)
		return p.global_position if p != null else Vector3.ZERO
	if _flat(body):
		return body.global_position + Vector3(0, 0.3, 0)
	var size := fit(body.vis)
	var back: Vector3 = -(body.vis as Node3D).global_basis.z
	back.y = 0.0
	return body.global_position + Vector3(0, float(size[4]), 0) + back.normalized() * (float(size[3]) + 0.05)


# そのキャラの胴の太さ [腰の横の半径, 腰の前後, 胸の横, 胸の前後, 背中の輪の高さ]（m）。
# キャラごとに体つきが大きく違う（ロボット・ドレス）ので、胴の骨（BODY）に付いた頂点のうち、
# 帯を巻く高さにある物の広がりを測る。キャラの種類ごとに1回だけ
func fit(vis: Node3D) -> Array:
	var tag := str(vis.get("tag"))
	if _fits.has(tag):
		return _fits[tag]
	var out := [BELT_R, BELT_R, BELT_R, BELT_R, RING_Y]
	var skel: Skeleton3D = vis.get("skel")
	var bone := skel.find_bone("BODY") if skel != null else -1
	if bone >= 0:
		var rest: Transform3D = skel.get_bone_global_rest(bone)
		var s := float(vis.SCALE)
		var y0 := rest.origin.y + (BASE_UP - 0.07) / s
		var y1 := rest.origin.y + (BASE_UP + TALL + 0.07) / s
		var mid := (y0 + y1) * 0.5
		var wide := [0.0, 0.0, 0.0, 0.0]
		for mesh: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null or mesh.mesh == null:
				continue
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null or vertices.is_empty():
					continue
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var influences := bones.size() / vertices.size()
				for i in vertices.size():
					var top := -1
					var most := 0.0
					for j in influences:
						if weights[i * influences + j] > most:
							most = weights[i * influences + j]
							top = bones[i * influences + j]
					if top < 0:
						continue
					var named := mesh.skin.get_bind_name(top)
					if (skel.find_bone(named) if named != "" else mesh.skin.get_bind_bone(top)) != bone:
						continue
					var p: Vector3 = rest * (mesh.skin.get_bind_pose(top) * vertices[i])
					if p.y < y0 or p.y > y1:
						continue
					var k := 0 if p.y < mid else 2
					wide[k] = maxf(wide[k], absf(p.x))
					wide[k + 1] = maxf(wide[k + 1], absf(p.z))
		if float(wide.min()) > 0.05:
			out = [wide[0] * s + 0.012, wide[1] * s + 0.012, wide[2] * s + 0.012, wide[3] * s + 0.012, rest.origin.y * s + BASE_UP + TALL]
	_fits[tag] = out
	return out


# ロープが引ける体（引けないときは null：カメラを操作している・車に乗っている・出番を待っている役者）
func pull_body(pid: int) -> CharacterBody3D:
	var who := int(worn.get(pid, 0))
	var body := body_of(who)
	if body == null:
		return null
	if who > 0:
		return null if int(body.operating) != 0 or body.vehicle_riding() else body as CharacterBody3D
	if bool(body.playback) or body.stand_in != null or str(body.grade) == "none" or int(body.st) == int(body.St.STANDBY):
		return null
	return body as CharacterBody3D


# その体を、この画面が動かしているか（自分の体・ホストの雇った役者）
func owns(body: Node) -> bool:
	if body.get("is_local") != null:
		return bool(body.is_local)
	return multiplayer.is_server() and not bool(body.playback)


# ロープが体を引く（速さの変化 dv）。dir はロープの向き、over はロープの伸び、seg は背中の輪からロープの次の点（滑車）までの長さ。
# 動かすのは、その体を動かしている画面だけ
func tug(body: CharacterBody3D, dv: Vector3, dir: Vector3, over: float, seg: float = INF) -> void:
	if not owns(body):
		return
	if seg < JAM and dir.length() > 0.01:
		# 上がりきった：それ以上は引き寄せない。離れていく（落ちる）のを止めるだけ
		var n := dir.normalized()
		dv = n * clampf(-body.velocity.dot(n), 0.0, maxf(dv.dot(n), 0.0))
		over = 0.0
	if body.is_on_floor():
		# 立っている人：体の重さを超えた分だけ浮く。横は、少しの力では引きずられない
		if dv.y > 0.0:
			dv.y = maxf(0.0, dv.y - GRAVITY / float(Engine.physics_ticks_per_second))
		var side := Vector3(dv.x, 0.0, dv.z)
		var l := side.length()
		side = side * (maxf(0.0, l - GRIP) / l) if l > 0.0001 else Vector3.ZERO
		dv = Vector3(side.x, dv.y, side.z)
	body.velocity += dv
	if over > STRETCH_MAX and dir.length() > 0.01:
		body.move_and_collide(dir.normalized() * minf(over - STRETCH_MAX, 0.5))


# ---- 自分の操作 ----

func _usable() -> bool:
	return game.production != null and not game.replaying and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE]


# 見ている人の番号（いなければ 0）。only_worn：ハーネスを着けている人だけ
func looked(me: Node, only_worn: bool) -> int:
	var cam: Camera3D = me.get("cam")
	if cam == null or int(me.operating) != 0:
		return 0
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var far := LOOK_REACH + from.distance_to((me as Node3D).global_position) + 1.0     # 後ろからの視点は、カメラが体より遠い
	var best := 0
	var best_t := INF
	for row: Array in _people():
		var body: Node3D = row[1]
		if body == me or (only_worn and harness_of(int(row[0])) == 0):
			continue
		var feet: Vector3 = body.global_position
		if (me as Node3D).global_position.distance_to(feet) > LOOK_REACH:
			continue
		for k in 7:
			var q: Vector3 = feet + Vector3(0, 0.2 + 0.23 * float(k), 0)
			var t: float = (q - from).dot(dir)
			if t <= 0.0 or t > far or t >= best_t:
				continue
			if (from + dir * t).distance_to(q) < LOOK_RADIUS:
				best = int(row[0])
				best_t = t
	if best == 0:
		return 0
	# あいだに壁・物があれば、見えていない
	var space := (me as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * maxf(best_t - 0.4, 0.05), 1 | 2)
	q.exclude = [(me as CollisionObject3D).get_rid()]
	if not space.intersect_ray(q).is_empty():
		return 0
	return best


# 見ているハーネス（着けている人を見ている・真下を見て自分の）。無ければ 0。ロープを結ぶ先（contraptions.gd）
func aimed_harness(me: Node) -> int:
	var who := looked(me, true)
	if who != 0:
		return harness_of(who)
	if float(me.aim_pitch) <= DOWN_PITCH:
		return harness_of(int(me.peer_id))
	return 0


# いま F（click なら左クリック）を押すと起きること。関係なければ {}
func action(me: Node, click: bool) -> Dictionary:
	if me == null or int(me.operating) != 0 or not _usable():
		return {}
	var held: Node = game.props.get(me.held) if int(me.held) != 0 else null
	if not click:
		if held == null or str(held.kind) != "harness":
			return {}
		var to := looked(me, false)
		var other := to != 0
		if not other:
			to = int(me.peer_id)
		return {"do": "full" if harness_of(to) != 0 else "wear", "pid": int(held.pid), "who": to, "other": other}
	if held != null:
		return {}
	var who := looked(me, true)
	if who != 0:
		return {"do": "strip", "pid": harness_of(who), "who": who, "other": true}
	var mine := harness_of(int(me.peer_id))
	if mine != 0 and float(me.aim_pitch) <= DOWN_PITCH and me.target == null:
		return {"do": "strip", "pid": mine, "who": int(me.peer_id), "other": false}
	return {}


func hook_f(me: Node) -> bool:
	var act := action(me, false)
	match str(act.get("do", "")):
		"wear":
			h_wear.rpc_id(1, int(act["pid"]), int(act["who"]))
		"full":
			game.hud.show_toast("もう、ハーネスを着けている", game.hud.YELLOW)
		_:
			return false
	return true


func hook_click(me: Node) -> bool:
	var act := action(me, true)
	if str(act.get("do", "")) != "strip":
		return false
	h_strip.rpc_id(1, int(act["pid"]))
	return true


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	var act := action(me, false)
	if str(act.get("do", "")) == "wear":
		var put: String = "\n" + str(game.hold_hint())
		if bool(act["other"]):
			return {"label": "人", "keys_all": "F ハーネスを着せる" + put}
		return {"keys_all": "F ハーネスを着る（人を見て F なら、その人に着せる）" + put}
	act = action(me, true)
	if str(act.get("do", "")) == "strip":
		return {"label": "ハーネス", "keys_all": "左クリック ハーネスを外す" if bool(act["other"]) else "左クリック ハーネスを脱ぐ"}
	return {}


# ---- ホスト：決める ----

func _host_ok() -> bool:
	return Net.is_host() and not _playback and _usable()


func _say(who: int, text: String, bad: bool = false) -> void:
	if who > 0:
		game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])


@rpc("any_peer", "call_local", "reliable")
func h_wear(pid: int, who: int) -> void:
	var from := Net.sender()
	var p: RigidBody3D = game.props.get(pid)
	var body := body_of(who)
	var me: Node3D = game.players.get(from)
	if not _host_ok() or p == null or str(p.kind) != "harness" or int(p.holder) != from or worn.has(pid) or body == null or me == null:
		return
	if harness_of(who) != 0:
		return
	if who != from and me.global_position.distance_to(body.global_position) > LOOK_REACH + 1.5:
		return
	game.host_release(p)
	host_wear(p, who)
	if who == from:
		_say(from, "ハーネスを着た。ロープの束を持って、真下を見て F で、背中の輪に結ぶ（真下を見て左クリックで脱ぐ）")
	else:
		_say(from, "ハーネスを着せた。ロープの束を持って、その人を見て F で結ぶ（手ぶらで見て左クリックで外す）")
		_say(who, "ハーネスを着せられた（真下を見て左クリックで脱ぐ）")


# ハーネスを着せる（ホスト）
func host_wear(p: RigidBody3D, who: int) -> void:
	worn[p.pid] = who
	_park(p)
	var body := body_of(who)
	game.host_ev("sfx", ["fix", body.global_position + Vector3(0, 1.0, 0)])
	_changed()


@rpc("any_peer", "call_local", "reliable")
func h_strip(pid: int) -> void:
	var from := Net.sender()
	var me: Node3D = game.players.get(from)
	if not _host_ok() or not worn.has(pid) or me == null:
		return
	var who := int(worn[pid])
	var body := body_of(who)
	if who != from and body != null and me.global_position.distance_to(body.global_position) > LOOK_REACH + 1.5:
		return
	host_strip(pid)
	if who != from:
		_say(who, "ハーネスを外された")


# ハーネスを外す（ホスト）。その人の前に落ちる
func host_strip(pid: int) -> void:
	var p: RigidBody3D = game.props.get(pid)
	var body := body_of(int(worn.get(pid, 0)))
	worn.erase(pid)
	if p != null:
		p.set_absent(false)
		var at: Vector3 = p.global_position
		var yaw := 0.0
		if body != null:
			var front: Vector3 = (body.vis as Node3D).global_basis.z
			front.y = 0.0
			at = body.global_position + Vector3(0, 0.9, 0) + front.normalized() * 0.45
			yaw = atan2(front.x, front.z)
		elif at.y < -20.0 and game.production != null:
			at = (game.production._home_layout.get(pid, [at]) as Array)[0]
		p.restore([at, Quaternion(Vector3.UP, yaw), false])
		p.sleeping = false
		game.host_ev("sfx", ["unfix", at])
	_changed()


# 着けている間、ハーネスの物は現場に無い扱い（見えない・当たらない）。ホストは、待機場所へ停める
func _park(p: RigidBody3D) -> void:
	p.set_absent(true)
	if Net.is_host():
		p.linear_velocity = Vector3.ZERO
		p.angular_velocity = Vector3.ZERO
		p.global_position = Vector3(float(p.pid) * 3.0, -60.0, 6.0)


func _physics_process(_delta: float) -> void:
	if game == null or game.production == null:
		return
	for pid: int in worn.keys():
		var p: RigidBody3D = game.props.get(pid)
		if p == null:
			continue
		if not p.absent:
			_park(p)          # ほかの仕組みが「現場にある」に戻したら、もう一度しまう（"absent" の合図など）
		if Net.is_host() and not _playback and not game.replaying and body_of(int(worn[pid])) == null:
			host_strip(pid)   # 着けていた人が、いなくなった


# ---- 同期と記録（"harness" の合図） ----

func _changed() -> void:
	game.host_ev("harness", [worn.duplicate()])
	_dress_all()


func hook_events() -> Array:
	return ["harness"]


func hook_rec_events() -> Array:
	return ["harness"]


func hook_event(n: String, a: Array) -> void:
	if n == "harness" and (not Net.is_host() or _playback or game.replaying):
		_apply(a[0])


func _apply(data: Dictionary) -> void:
	worn = data.duplicate()
	for p: RigidBody3D in parts:
		if worn.has(p.pid):
			_park(p)
		elif p.absent and int(p.stored_in) == 0:
			p.set_absent(false)
	_dress_all()


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "harness", [worn.duplicate()])


func hook_take_ready() -> void:
	_before_take = worn.duplicate()


func hook_take_start() -> void:
	game._rec_events.append([0.0, "harness", [worn.duplicate()]])


func hook_retake() -> void:
	if Net.is_host():
		_apply(_before_take)
		game.host_ev("harness", [worn.duplicate()])


func hook_playback(on: bool) -> void:
	if on:
		_live = worn.duplicate()
		_playback = true
	else:
		_playback = false
		_apply(_live)
		game.host_ev("harness", [worn.duplicate()])


# 帰社：全員、脱ぐ（物は置き場所へ戻る。production_flow.gd）
func hook_return_office() -> void:
	if not Net.is_host():
		return
	_apply({})
	game.host_ev("harness", [{}])


# ---- 全員の画面：見た目 ----

func _process(_delta: float) -> void:
	if game == null:
		return
	# 体の見た目が作り直された（キャラを替えた）ときは、帯を付け直す
	for pid: int in worn:
		var row: Array = _looks.get(pid, [])
		if row.is_empty() or not is_instance_valid(row[0]):
			_dress_all()
			return


func _dress_all() -> void:
	for pid: int in _looks.keys():
		var row: Array = _looks[pid]
		if not is_instance_valid(row[0]) or int(worn.get(pid, 0)) != int(row[1]):
			if is_instance_valid(row[0]):
				(row[0] as Node).queue_free()
			_looks.erase(pid)
	for pid: int in worn:
		if _looks.has(pid):
			continue
		var body := body_of(int(worn[pid]))
		if body != null and body.get("vis") != null:
			_looks[pid] = [_dress(body.vis), int(worn[pid])]


# 体に、帯を付ける。胴の骨（BODY）について動く。骨が無いキャラは、体の真ん中に付ける
func _dress(vis: Node3D) -> Node3D:
	var skel: Skeleton3D = vis.get("skel")
	var bone := skel.find_bone("BODY") if skel != null else -1
	var size := fit(vis)
	var model := build(Vector2(size[0], size[1]), Vector2(size[2], size[3]))
	if bone < 0:
		model.position = Vector3(0, 0.75, 0)
		vis.add_child(model)
		return model
	var rack := BoneAttachment3D.new()
	rack.bone_name = "BODY"
	skel.add_child(rack)
	var rest: Transform3D = skel.get_bone_global_rest(bone)
	var unit: float = 1.0 / float(vis.SCALE)          # キャラの素材は縮めて使っているので、その分を戻す
	model.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * unit), Vector3(0, rest.origin.y + BASE_UP * unit, 0))
	rack.add_child(model)
	return rack
