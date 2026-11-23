extends RefCounted
## 段ボール箱：置き場・箱を取る・詰める・出す・こぼれる・中身の札。
## cargo_kit.gd（運ぶ道具の入口）が作って持つ。外からは game.cargo_kit.〜 で呼ぶ（cargo_kit.gd が、ここへ渡す）。
##   ・段ボール置き場：箱は最初にまとめて作って奥にしまっておき（物のIDを全員でそろえるため）、置き場に数個ずつ出す。
##     持っていかれて空いた所には、次の箱が出る。山を見て F で、手に1箱もらうこともできる。事務所へ戻ると全部ここへ戻る
##   ・箱詰め：物を持って、開いた箱を見て F。または、開いた箱の中へ手で置く・落とす（中で落ち着いたら中身になる）。
##     入れた物は箱の中身になり（prop.gd の stored_in）、箱ごと1つの荷物として運べる。
##     入る量は、数ではなく、箱の内側の実際の広さで決まる（carton_pack.gd）。中身は、箱の中に実寸で積んで見せる。
##     口から少しはみ出す所までは押し込める。はみ出していると、ふたが閉まらず、道中の段差でこぼれ落ちることがある。
##     中身そのものは現場に無い物と同じ扱い（判定に数えない）で、箱の中には写しと、同じ大きさの当たりを置く。
##     手ぶらで、中身のある開いた箱を見て F：見ている物（無ければ、いちばん上の物）を取り出して手に持つ
## 決めるのはホストだけ。箱の中身と並び方は、cargo_kit.gd が "kit" の合図で全員へ配る。
## 置き場の奥にしまってある箱は、今日は出ていない廃材と同じ一覧（production_flow.gd の stash）に入れておく
const Carton := preload("res://scripts/carton.gd")
const Prop := preload("res://scripts/prop.gd")
const FilmCamera := preload("res://scripts/film_camera.gd")
const Pack := preload("res://scripts/carton_pack.gd")
const Look := preload("res://scripts/production_look.gd")

# ---- 段ボール置き場 ----
const CARTON_COUNT := 16                      # 箱の総数（撮影だけモードからある4個を含む）
const SHOWN := 4                              # 置き場に出しておく数（持っていかれたら、次の箱を出す）
const YARD := Rect2(69.6, 18.4, 4.2, 3.0)     # 置き場（x, z, 幅, 奥行き）。軽トラの西どなり、廃材置き場との間
# 置き場の北西の角からの位置（x, z）
const SLOTS := [Vector2(2.15, 0.75), Vector2(3.5, 0.75), Vector2(2.15, 2.25), Vector2(3.5, 2.25)]
const PILE_AT := Vector2(0.72, 1.85)          # 段ボールの山
const ROPE_AT := Vector2(0.72, 0.42)          # ロープ
# ---- 箱詰め ----
# 入る量は、箱の内側の広さと、物の実際の大きさで決まる（carton_pack.gd）。数や段階では数えない
const SPILL_CHANCE := 0.5                     # 道中の段差1回で、口からはみ出した物がこぼれ落ちる見込み
const DROP_EVERY := 6                         # 箱の中へ手で置いた物を調べる間隔（コマ）
const DROP_REST := 3                          # 続けてこの回数、箱の中で止まっていたら、中身になる
const GEAR := ["camera", "spot", "clapper", "cue_card", "monitor"]      # 会社の機材（機材置き場から、いっしょに運ばれる）
const OWN_F := ["cue_card", "clapper", "script", "carton", "glue", "rope", "hair_cord"]   # 持って F に別の使い道がある物
const REACH_MORE := 0.8                       # 箱や荷台の物へ手を伸ばせる距離（Player.REACH に足す）

var kit: Node                                 # cargo_kit.gd（入口）
var game: Node:
	get:
		return kit.game
var flow: Node:
	get:
		return kit.flow
var rng: RandomNumberGenerator:               # 結び目のゆるみと同じ乱数（cargo_kit.gd が持つ）
	get:
		return kit.rng
var ropes: RefCounted:                        # 荷台のロープ（cargo_lash.gd）
	get:
		return kit.ropes
var reels: RefCounted:                        # ひもの束（cargo_coils.gd）
	get:
		return kit.reels
var cartons: Array = []                       # 段ボール箱（物のIDの小さい順）
var pile: RigidBody3D
var contents: Dictionary = {}                 # 箱の物のID → 中身の物のID（入れた順）
var lay: Dictionary = {}                      # 箱の物のID → {中身の物のID → 箱から見た置き方（Transform3D。実寸で積んだ場所と向き）}
var _tick := 0.0
var _slots := {}                              # 置ける場所の計算の控え（[箱, 物] → 結果）。中身が変わったら捨てる
var _alone := {}                              # 空の箱になら入る物か（物の種類 → 入る・入らない）
var _resting := {}                            # 箱の中に手で置かれて、止まっている物（物のID → 続けて止まっていた回数）
var _drop_in := 0
var _spill_seen := 0
var spill_chance := SPILL_CHANCE                # 確認では、0（こぼれない）や 1（必ずこぼれる）にできる


func _at(local: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(YARD.position.x + local.x, y, YARD.position.y + local.y)


# ---- 段ボール置き場 ----


# 置き場の奥にしまってある箱（まだ出していない箱）
func reserve() -> Array:
	var out: Array = []
	for box: RigidBody3D in cartons:
		if box.absent and box.stored_in == 0 and box.pid in flow.stash:
			out.append(box)
	return out


# 奥から1箱出す（ホスト）。もう無ければ null
func _issue() -> RigidBody3D:
	var left: Array = reserve()
	if left.is_empty():
		return null
	var box: RigidBody3D = left[0]
	var hidden: Array = (flow.stash as Array).duplicate()
	hidden.erase(box.pid)
	game.host_ev("stash", [hidden])
	box.set_fixed(false)
	if not box.opened:
		game.host_ev("carton", [box.pid, true])
	return box


# 空いている置き場所へ、奥の箱を出す（ホスト）
func host_refill() -> void:
	if not Net.is_host():
		return
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for slot: Vector2 in SLOTS:
		if reserve().is_empty():
			return
		var at: Vector3 = _at(slot, 0.05)
		# 物や人が居る場所には出さない
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 0.6, 1.0)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.45, 0))
		query.collision_mask = Prop.L_PROP | Prop.L_CHAR
		if not space.intersect_shape(query, 1).is_empty():
			continue
		var taken := false
		for box: RigidBody3D in cartons:
			if not box.absent and Vector2(box.global_position.x - at.x, box.global_position.z - at.z).length() < 0.6:
				taken = true
		if taken:
			continue
		var fresh: RigidBody3D = _issue()
		var state: Array = fresh.get_state()
		state[0] = at
		state[1] = Quaternion.IDENTITY
		state[2] = false
		fresh.restore(state)


# 全部の箱を置き場の奥へ戻し、中身を出し、ロープを巻き戻す（ホスト。会社を始めるときと、事務所へ戻るとき）。
# 出した中身の置き場所は、このあとの帰社の処理が元の場所へ戻す
func host_reset() -> void:
	if not Net.is_host():
		return
	ropes.host_clear_lashes(true)
	contents = {}
	lay = {}
	kit._broadcast()
	var hidden: Array = (flow.stash as Array).duplicate()
	for box: RigidBody3D in cartons:
		flow._let_go(box)
		box.set_fixed(false)
		if not box.opened:
			game.host_ev("carton", [box.pid, true])
		if box.pid not in hidden:
			hidden.append(box.pid)
	game.host_ev("stash", [hidden])
	for box: RigidBody3D in cartons:
		box.linear_velocity = Vector3.ZERO
		box.angular_velocity = Vector3.ZERO
		box.global_position = Vector3(float(box.pid) * 3.0, -60.0, 0.0)


# 山を見て F：手に1箱もらう
@rpc("any_peer", "call_local", "reliable")
func h_take_carton() -> void:
	if not kit._host_ok():
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	if pl == null or game._held_by(who) != null or pl.operating != 0:
		return
	if pl.global_position.distance_to(pile.center_global()) > game.Player.REACH + 1.5:
		return
	var box: RigidBody3D = _issue()
	if box == null:
		kit._say(who, "段ボール箱は、もう無い（全部で %d箱）。使い終わった箱を使い回そう" % cartons.size(), true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	_hand_over(box, who)
	kit._say(who, "段ボール箱を出した（置き場の残り %d箱）" % reserve().size(), false)


# ---- 箱詰め ----


# 箱の中身（入れた順の物）
func box_items(box: Node) -> Array:
	var out: Array = []
	for pid: int in contents.get(box.pid, []):
		if game.props.has(pid):
			out.append(game.props[pid])
	return out


# 箱の中での、その物の置き方（箱から見た場所と向き）
func slot_of(box_pid: int, pid: int) -> Transform3D:
	return (lay.get(box_pid, {}) as Dictionary).get(pid, Transform3D.IDENTITY)


# 箱の中の物が占めている範囲（箱から見た箱形）の一覧。入れた順
func blocks(box: Node) -> Array:
	var out: Array = []
	for item: Node3D in box_items(box):
		out.append(Pack.box_of(slot_of(box.pid, item.pid), item.center, item.half))
	return out


# いちばん高い中身が、箱の口からどれだけ出ているか（m。負なら口より下。空なら、箱の深さの分だけ負）
func box_over(box: Node) -> float:
	var top: float = box.room.position.y
	for block: AABB in blocks(box):
		top = maxf(top, block.end.y)
	return top - box.room.end.y


# 中身が口からはみ出していて、ふたが閉まらないか
func lid_blocked(box: Node) -> bool:
	return box_over(box) > Pack.LID_GIVE


# その物を、その箱のどこに置けるか。{"xf": 置き方, "over": 口からはみ出す高さ}。置けなければ {}
func slot_for(item: Node3D, box: Node) -> Dictionary:
	var key := [box.pid, item.pid]
	if not _slots.has(key):
		_slots[key] = Pack.find(box.room, Pack.heights(box.room, blocks(box)), item.center, item.half)
	return _slots[key]


# 空の箱になら入る大きさか
func fits_alone(item: Node3D) -> bool:
	if not _alone.has(item.kind):
		var room: AABB = (cartons[0] as Node).room
		_alone[item.kind] = not Pack.find(room, Pack.heights(room, []), item.center, item.half).is_empty()
	return _alone[item.kind]


# 中身・並び方が変わった：置ける場所の計算の控えを捨てる
func _changed() -> void:
	_slots.clear()


# 箱の中身に足す（ホスト）
func _store(box_pid: int, item_pid: int, xf: Transform3D) -> void:
	if not contents.has(box_pid):
		contents[box_pid] = []
	(contents[box_pid] as Array).append(item_pid)
	if not lay.has(box_pid):
		lay[box_pid] = {}
	lay[box_pid][item_pid] = xf
	_changed()


# 箱の中身から外す。残りは、下へ詰め直す（下の物が抜けたら、上の物が落ちる）
func _take_out(box_pid: int, item_pid: int) -> void:
	var list: Array = contents.get(box_pid, [])
	list.erase(item_pid)
	if lay.has(box_pid):
		(lay[box_pid] as Dictionary).erase(item_pid)
	if list.is_empty():
		contents.erase(box_pid)
		lay.erase(box_pid)
	else:
		_settle(box_pid)
	_changed()


func _settle(box_pid: int) -> void:
	var box: Node = game.props.get(box_pid)
	if box == null:
		return
	var rows: Array = []
	var items: Array = box_items(box)
	for item: Node3D in items:
		rows.append([slot_of(box_pid, item.pid), item.center, item.half])
	var placed: Array = Pack.settle(box.room, rows)
	for k in items.size():
		lay[box_pid][items[k].pid] = placed[k]


# 置き方の届いていない中身に、置き場所を決める（古い記録や、借りるのをやめた物が抜けたあとの備え。
# 全員が同じ計算をするので、同じ並びになる）。もう置けない物は、いちばん上に載せる
func _fill_lay() -> void:
	for box_pid: int in contents:
		var box: Node = game.props.get(box_pid)
		if box == null or not ("room" in box):
			continue
		if not lay.has(box_pid):
			lay[box_pid] = {}
		var known: Dictionary = lay[box_pid]
		var placed: Array = []
		var late: Array = []
		for item: Node3D in box_items(box):
			if known.has(item.pid):
				placed.append(Pack.box_of(known[item.pid], item.center, item.half))
			else:
				late.append(item)
		for item: Node3D in late:
			var slot: Dictionary = Pack.find(box.room, Pack.heights(box.room, placed), item.center, item.half)
			var xf := Transform3D.IDENTITY
			if slot.is_empty():
				var top: float = box.room.position.y
				for block: AABB in placed:
					top = maxf(top, block.end.y)
				xf.origin = Vector3(box.room.get_center().x, top + item.half.y, box.room.get_center().z) - item.center
			else:
				xf = slot["xf"]
			known[item.pid] = xf
			placed.append(Pack.box_of(xf, item.center, item.half))
		for pid: int in known.keys():
			if pid not in (contents[box_pid] as Array):
				known.erase(pid)
	for box_pid: int in lay.keys():
		if not contents.has(box_pid):
			lay.erase(box_pid)


# いちばん上にある中身（物のID）。空なら 0
func top_item(box: Node) -> int:
	var best := 0
	var height := -INF
	for item: Node3D in box_items(box):
		var top: float = Pack.box_of(slot_of(box.pid, item.pid), item.center, item.half).end.y
		if top >= height - 0.001:
			height = top
			best = item.pid
	return best


# 視線の先にある中身（物のID）。どれも見ていなければ、いちばん上の物
func aim_item(me: Node, box: Node) -> int:
	var view: Array = kit._view(me)
	if not view.is_empty():
		var inv: Transform3D = box.global_transform.affine_inverse()
		var from: Vector3 = inv * (view[0] as Vector3)
		var dir: Vector3 = inv.basis * (view[1] as Vector3)
		var best := 0
		var near := INF
		for item: Node3D in box_items(box):
			var hit: Variant = Pack.box_of(slot_of(box.pid, item.pid), item.center, item.half).intersects_ray(from, dir)
			if hit is Vector3 and (hit as Vector3).distance_to(from) < near:
				near = (hit as Vector3).distance_to(from)
				best = item.pid
		if best != 0:
			return best
	return top_item(box)


# 短い名前（かっこ書きの説明は外す）
func _short(prop: Node) -> String:
	return str(prop.label).get_slice("（", 0).get_slice("・", 0) if prop.kind != "carton" else str(prop.label).get_slice("（", 0)


# 中身の名前を並べる：「ゴムの魚・クリームパイ」（同じ名前は1回だけ。数は書かない。箱の中を見れば分かる）
func _names(box: Node, most: int = 99) -> String:
	var order: Array = []
	for item: Node in box_items(box):
		var title := _short(item)
		if title not in order:
			order.append(title)
	var shown: String = "・".join(order.slice(0, most))
	return shown + " など" if order.size() > most else shown


# 画面に出す中身：「中身：ゴムの魚・クリームパイ」。空なら ""
func box_note(box: Node) -> String:
	if box_items(box).is_empty():
		return ""
	return "中身：%s" % _names(box)


# その物を、箱に入れてはいけない理由（""＝入れてよい物）。箱の空き具合は見ない
func pack_ban(item: Node3D) -> String:
	if item.kind == "carton":
		return "箱の中に、箱は入れられない"
	if item.kind in GEAR:
		return "会社の機材は箱に入れない（機材置き場から、いっしょに運ばれる）"
	if item.kind == "script":
		return "台本は箱に入れない（持って行くか、荷台に積む）"
	if item.kind == "standin":
		return "等身大パネルは箱に入らない"
	if item.kind == "fx":
		return "爆弾は箱に入れない"
	if item.kind == "mark":
		return "立ち位置の印は箱に入れない"
	if item.kind in ["glue", "rope", "hair_cord"]:
		return "道具は箱に入れない"
	if item.fixed:
		return "固定してある物は入れられない"
	if game.adhesive != null:
		for pair: Dictionary in game.adhesive.pairs:
			if pair.a == item.pid or pair.b == item.pid:
				return "接着剤が付いている物は入れられない"
	if item.immovable or item.rolls or item.deck_top >= 0.0 or not fits_alone(item):
		return "%s は大きすぎて箱に入らない" % _short(item)
	return ""


# その物を、その箱に入れられない理由（""＝入れられる）
func pack_problem(item: Node3D, box: Node) -> String:
	var ban := pack_ban(item)
	if ban != "":
		return ban
	if not box.opened:
		return "箱が閉じている（手ぶらで箱を見て F で開く）"
	if slot_for(item, box).is_empty():
		return "もう入らない"
	return ""


# 物を持って、開いた箱を見て F：箱に入れる
@rpc("any_peer", "call_local", "reliable")
func h_pack(item_pid: int, box_pid: int) -> void:
	if not kit._host_ok():
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	var item: RigidBody3D = game.props.get(item_pid)
	var box: RigidBody3D = game.props.get(box_pid)
	if pl == null or item == null or box == null or item.holder != who or item.absent:
		return
	if box.kind != "carton" or box.absent or box == item:
		return
	if pl.global_position.distance_to(box.center_global()) > game.Player.REACH + REACH_MORE:
		return
	var why := pack_problem(item, box)
	if why != "":
		kit._say(who, why, true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	# 手から離して（荷台には載せない）、箱の中身にする
	item.set_holder(0)
	game._reset_hold_controls(pl)
	pl.hold_revision += 1
	game.host_ev("hold", [who, 0, {"revision": pl.hold_revision}])
	if item.rider_of != 0:
		game.host_unload(item)
	var slot: Dictionary = slot_for(item, box)
	_store(box_pid, item_pid, slot["xf"])
	kit._broadcast()
	game.host_ev("sfx", ["load", box.global_position])
	if float(slot["over"]) > Pack.LID_GIVE:
		kit._say(who, "%s を箱に押し込んだ。口からはみ出している（ふたは閉まらない）" % _short(item), false)
	else:
		kit._say(who, "%s を箱に入れた" % _short(item), false)


# 手ぶらで、中身のある開いた箱を見て F：見ている物（item_pid。0 や、もう無い物なら、いちばん上の物）を取り出して手に持つ
@rpc("any_peer", "call_local", "reliable")
func h_unpack(box_pid: int, item_pid: int = 0) -> void:
	if not kit._host_ok():
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	var box: RigidBody3D = game.props.get(box_pid)
	if pl == null or box == null or box.kind != "carton" or box.absent or game._held_by(who) != null or pl.operating != 0:
		return
	if box.holder != who and pl.global_position.distance_to(box.center_global()) > game.Player.REACH + REACH_MORE:
		return
	var list: Array = contents.get(box_pid, [])
	if list.is_empty():
		return
	if not box.opened:
		kit._say(who, "箱が閉じている（F で開く）", true)
		return
	if item_pid not in list:
		item_pid = top_item(box)
	_take_out(box_pid, item_pid)
	kit._broadcast()
	var item: RigidBody3D = game.props.get(item_pid)
	if item == null:
		return
	_hand_over(item, who)
	kit._say(who, "%s を箱から出した" % _short(item), false)


# その人の手元へ出して、持たせる（ホスト）
func _hand_over(prop: RigidBody3D, who: int) -> void:
	var pl: CharacterBody3D = game.players.get(who)
	if pl == null:
		return
	game._reset_hold_controls(pl)
	var carry: Array = game._carry_target(pl, prop)
	var facing := Basis.from_euler(Vector3(float(carry[3]), float(carry[1]), 0.0))
	var origin: Vector3 = (carry[0] as Vector3) - facing * prop.center
	# 足元の床より下には出さない
	var bottom: float = (Transform3D(facing, origin) * AABB(prop.center - prop.half, prop.half * 2.0)).position.y
	origin.y += maxf(0.0, pl.global_position.y + 0.05 - bottom)
	var state: Array = prop.get_state()
	state[0] = origin
	state[1] = Quaternion(facing.orthonormalized())
	state[2] = false
	prop.restore(state)
	prop.set_holder(who)
	prop.grab_time = Time.get_ticks_msec() / 1000.0
	pl.hold_revision += 1
	game.host_ev("hold", [who, prop.pid, game._hold_snapshot(pl, prop)])
	game.host_ev("sfx", ["pickup", prop.global_position])


# 開いた箱の中へ、手で置いた・落とした物を、中身にする（ホスト）。箱の内側で止まって、少したったら入る。
# 置いた場所と向き（まっすぐにそろえる）のまま、下に積んである物の上に載る。
# 入れてはいけない物・はみ出しすぎる物は、そのまま（箱の中や上に載っているだけ。運べば、こぼれる）
func _host_drop_in() -> void:
	if not kit._host_ok() or game.state != game.S.PREP:
		_resting.clear()
		return
	var open: Array = []
	for box: RigidBody3D in cartons:
		if not box.absent and box.opened and box.open_amount > 0.9 and box.global_basis.y.y > 0.85:
			open.append([box, box.global_transform.affine_inverse()])
	var seen := {}
	if not open.is_empty():
		for prop: RigidBody3D in game.props.values():
			if prop.absent or prop.holder != 0 or prop.fixed or prop.immovable or prop.rolls or prop.kind == "carton":
				continue
			for row: Array in open:
				var box: RigidBody3D = row[0]
				var room: AABB = box.room
				var c: Vector3 = (row[1] as Transform3D) * prop.center_global()
				if c.x < room.position.x or c.x > room.end.x or c.z < room.position.z or c.z > room.end.z or c.y < room.position.y - 0.05 or c.y > room.end.y + 0.6:
					continue
				if (prop.linear_velocity - box.linear_velocity).length() > 0.25 or prop.angular_velocity.length() > 1.0 or pack_ban(prop) != "":
					break
				var count: int = int(_resting.get(prop.pid, 0)) + 1
				if count >= DROP_REST:
					# 入らなかった物は、しばらくしてから調べ直す
					count = 0 if _drop_into(prop, box, row[1]) else -40
				if count != 0:
					seen[prop.pid] = count
				break
	_resting = seen


func _drop_into(prop: RigidBody3D, box: RigidBody3D, inv: Transform3D) -> bool:
	var rel: Transform3D = inv * prop.global_transform
	var facing: Basis = Pack.snap(rel.basis.orthonormalized())
	var slot: Dictionary = Pack.drop(box.room, Pack.heights(box.room, blocks(box)), facing, prop.center, prop.half, rel * prop.center)
	if slot.is_empty():
		return false
	if prop.rider_of != 0:
		game.host_unload(prop)
	_store(box.pid, prop.pid, slot["xf"])
	kit._broadcast()
	game.host_ev("sfx", ["load", box.global_position])
	return true


# 道中の段差：口からはみ出している物は、こぼれ落ちることがある（ホスト）。
# こぼれた物は、箱の中にあった場所から、はね上がって外へ出る（荷台に残るか、道に落ちるかは、物理しだい）
func _host_spill() -> void:
	var out: Array = []           # [箱, 物, こぼれる前の場所（世界）]
	var riding: Array = flow.cargo(false)
	for box: RigidBody3D in cartons:
		# 揺れるのは、軽トラで運ばれている箱だけ
		if box.absent or not contents.has(box.pid) or box.pid not in riding:
			continue
		for item: Node3D in box_items(box):
			var xf: Transform3D = slot_of(box.pid, item.pid)
			if Pack.box_of(xf, item.center, item.half).end.y > box.room.end.y + Pack.LID_GIVE and rng.randf() < spill_chance:
				out.append([box, item, box.global_transform * xf])
	if out.is_empty():
		return
	for row: Array in out:
		_take_out(row[0].pid, row[1].pid)
	kit._broadcast()
	for row: Array in out:
		var box: RigidBody3D = row[0]
		var item: RigidBody3D = row[1]
		var world: Transform3D = row[2]
		item.restore([world.origin + box.global_basis.y * 0.06, Quaternion(world.basis.orthonormalized()), false])
		item._launch = [box.linear_velocity + ropes._truck_vel + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(1.6, 2.6), rng.randf_range(-1.2, 1.2)), Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), rng.randf_range(-3, 3))]
		item.sleeping = false
		game.host_ev("sfx", ["bump", world.origin])


# 借りるのをやめた物が箱に入ったままなら、箱から外す（ホスト）
func _purge() -> void:
	if contents.is_empty():
		return
	var gone: Array = game._absent_kinds()
	var changed := false
	for box_pid: int in contents.keys():
		var kept: Array = []
		for pid: int in contents[box_pid]:
			if game.props.has(pid) and game.props[pid].kind not in gone:
				kept.append(pid)
		if kept.size() != (contents[box_pid] as Array).size():
			changed = true
			if kept.is_empty():
				contents.erase(box_pid)
			else:
				contents[box_pid] = kept
	if changed:
		_fill_lay()
		for box_pid: int in contents:
			_settle(box_pid)
		_changed()
		kit._broadcast()
		# 箱から外れた物は、借りていない物として消し直す
		game.ev.rpc("absent", [gone])


# ---- 同期と記録 ----


# 撮り直し：テイクを始める前の中身に戻す（ホスト。物の置き場所は、このあと main.gd が戻す）
func host_restore(data: Dictionary) -> void:
	if not Net.is_host() or data.is_empty():
		return
	var boxes: Dictionary = data.get("boxes", {})
	for box_pid: int in boxes:
		for pid: int in boxes[box_pid]:
			var item: RigidBody3D = game.props.get(pid)
			if item != null and item.holder != 0:
				game.host_release(item)
	contents = boxes.duplicate(true)
	lay = (data.get("lay", {}) as Dictionary).duplicate(true)
	_fill_lay()
	kit._broadcast()


# ---- 見た目 ----


# 箱の中身の見た目（実寸で積んだ写しと、同じ大きさの当たり）と、重さを作り直す
func _show_boxes() -> void:
	for box: RigidBody3D in cartons:
		var rows: Array = []
		var weight: float = box.empty_mass
		for item: Node3D in box_items(box):
			rows.append([item, slot_of(box.pid, item.pid)])
			weight += item.mass
		box.show_contents(rows)
		if not is_equal_approx(box.mass, weight):
			box.mass = weight


# 箱の中身の短い一覧：「ゴムの魚・クリームパイ・紙の王冠 など」。名前は3つまで（狙ったときの名前の横に出す。cargo_kit.gd の hud_view）
func _tag(box: Node) -> String:
	return _names(box, 3)


# 段ボールの山：閉じた箱を積んだ見た目。動かせない。見て F で、手に1箱もらえる
func _build_pile() -> void:
	pile = Prop.new()
	pile.kind = "carton_pile"
	pile.label = "段ボールの山"
	pile.mass = 80.0
	pile.immovable = true
	pile.hold_min = 3.0
	var size := Vector3(1.2, 1.5, 1.95)
	pile.center = Vector3(0, size.y * 0.5, 0)
	pile.half = size * 0.5
	pile.visual = Node3D.new()
	pile.add_child(pile.visual)
	var scale: float = float(game.stage.DEFS["carton"]["scale"])
	var k: float = scale / Carton.BASE_SCALE
	var tall: float = 0.57 * k                # 閉じた箱の高さ
	# 木のパレットの上に、下の段2箱・上の段1箱
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.48, 0.31)
	wood.roughness = 0.9
	for z: float in [-0.8, 0.0, 0.8]:
		_pile_box(Vector3(0, 0.05, z), Vector3(1.2, 0.1, 0.16), wood)
	for x: float in [-0.5, 0.0, 0.5]:
		_pile_box(Vector3(x, 0.115, 0), Vector3(0.14, 0.03, 1.9), wood)
	for row: Array in [[Vector3(0, 0.13, -0.47), 0.03], [Vector3(0, 0.13, 0.47), -0.04], [Vector3(0.02, 0.13 + tall, 0.02), 0.16]]:
		var model: Node3D = Carton.closed_model(scale)
		model.position = row[0]
		model.rotation.y = row[1]
		pile.visual.add_child(model)
	# たたんだ段ボールの束を、山に立てかける
	var flat := StandardMaterial3D.new()
	flat.albedo_color = Color(0.74, 0.60, 0.42)
	flat.roughness = 1.0
	for i in 4:
		var sheet := _pile_box(Vector3(0.0, 0.52, -0.99 - 0.035 * i), Vector3(1.0, 0.8, 0.028), flat)
		sheet.rotation.x = -0.14
	# 札：北東（軽トラと、廃材置き場からの通り道のほう）へ向ける
	var post := _pile_box(Vector3(-0.5, 1.2, 0.86), Vector3(0.07, 2.4, 0.07), wood)
	post.name = "SignPost"
	var board := _pile_box(Vector3(-0.47, 2.2, 0.83), Vector3(1.8, 0.62, 0.04), flat)
	board.rotation.y = PI * 0.75
	# 札の絵（段ボール箱）。文字は書かず、札の表にぴったり貼る
	Look.picto(board, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0208)), "box", Vector2(0.52, 0.52))
	for shape: Array in [[Vector3(0, 0.13 + tall * 0.5, 0), Vector3(1.1, tall, 1.8)], [Vector3(0, 0.13 + tall * 1.5, 0), Vector3(1.1, tall, 0.85)], [Vector3(0, 0.065, 0), Vector3(1.2, 0.13, 1.9)]]:
		var collider := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = shape[1]
		collider.shape = solid
		collider.position = shape[0]
		pile.add_child(collider)
	game.stage._register(pile, _at(PILE_AT), 0.0)
	pile.set_fixed(true)


func _pile_box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	pile.visual.add_child(part)
	return part


# 置き場の地面：黄色い囲い（地面に文字は書かない）
func _build_yard() -> void:
	var root := Node3D.new()
	root.name = "CartonYard"
	kit.add_child(root)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("e0b43a")
	paint.roughness = 0.9
	var a: Vector2 = YARD.position
	var b: Vector2 = YARD.end
	for edge: Array in [[Vector2(a.x, a.y), Vector2(b.x, a.y)], [Vector2(a.x, b.y), Vector2(b.x, b.y)], [Vector2(a.x, a.y), Vector2(a.x, b.y)], [Vector2(b.x, a.y), Vector2(b.x, b.y)]]:
		var line := MeshInstance3D.new()
		var strip := BoxMesh.new()
		var from: Vector2 = edge[0]
		var to: Vector2 = edge[1]
		strip.size = Vector3(maxf(absf(to.x - from.x), 0.12) + 0.12, 0.01, maxf(absf(to.y - from.y), 0.12))
		line.mesh = strip
		line.material_override = paint
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.position = Vector3((from.x + to.x) * 0.5, 0.022, (from.y + to.y) * 0.5)
		root.add_child(line)


# ---- cargo_kit.gd から呼ばれる入口 ----


# 箱を集めて、足りない分を作る（全員の画面で同じ順に。物のIDがそろう）
func collect_cartons() -> void:
	for prop: RigidBody3D in game.props.values():
		if prop.kind == "carton":
			cartons.append(prop)
	# 足りない分の箱は、待機場所（地面の下）に作っておく
	for i in maxi(0, CARTON_COUNT - cartons.size()):
		cartons.append(game.stage.spawn("carton", Vector3(float(game.props.size() + 1) * 3.0, -60.0, 30.0)))
	cartons.sort_custom(func(a: Node, b: Node) -> bool: return a.pid < b.pid)


# 毎コマ（ホストだけ。ロープの計算のあと）：手で置いた物を中身にする・道中でこぼす・片づけ・置き場に箱を足す
func host_physics(delta: float) -> void:
	_drop_in -= 1
	if _drop_in <= 0:
		_drop_in = DROP_EVERY
		_host_drop_in()
	if flow.phase == 3 and int(flow._bumped) > _spill_seen:
		_host_spill()
	_spill_seen = int(flow._bumped)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_purge()
	if flow.phase in [0, 2] and game.state == game.S.PREP:
		host_refill()


# 箱の中身の一覧を受け取って、画面に反映する（全員）
func apply(data: Dictionary) -> void:
	contents = {}
	lay = {}
	var boxes: Dictionary = data.get("boxes", {})
	for box_pid: int in boxes:
		contents[box_pid] = (boxes[box_pid] as Array).duplicate()
	var lays: Dictionary = data.get("lay", {})
	for box_pid: int in lays:
		lay[box_pid] = (lays[box_pid] as Dictionary).duplicate()
	_fill_lay()
	_changed()
	var keeper := {}
	for box_pid: int in contents:
		for pid: int in contents[box_pid]:
			keeper[pid] = box_pid
	for prop: RigidBody3D in game.props.values():
		var want: int = int(keeper.get(prop.pid, 0))
		if want != 0:
			if prop.stored_in != want:
				prop.set_stored(want)
		elif prop.stored_in > 0:
			# 箱から出た。人の体にしまってある物（負の値）には触らない
			prop.set_stored(0)
	_show_boxes()


# F：物を持っている（束・はさみ以外）。開いた箱を見ていれば、入れる
func act_holding(held: Node3D, target: Node3D) -> Dictionary:
	if target != null and target.kind == "carton" and not target.absent and target.opened and held.kind not in OWN_F:
		return {"do": "pack", "target": target, "why": pack_problem(held, target)}
	return {}


# F：手ぶら。山を見ていれば1箱もらう、箱を見ていれば取り出す・開け閉め
func act_free(me: Node, target: Node3D) -> Dictionary:
	if target == null:
		return {}
	if target == pile:
		return {"do": "take", "target": pile, "why": "" if not reserve().is_empty() else "もう無い"}
	if target.kind == "carton" and not target.absent:
		if target.opened and not box_items(target).is_empty():
			# 見ている物を取り出す（輪で、どれかを示す）
			var pick: int = aim_item(me, target)
			var block: AABB = Pack.box_of(slot_of(target.pid, pick), game.props[pick].center, game.props[pick].half)
			return {"do": "unpack", "target": target, "item": pick, "point": target.global_transform * (block.get_center() + Vector3(0, block.size.y * 0.5, 0)), "why": ""}
		# 怪獣役にした箱は、F で倒す・起こすが先（production_main.gd）
		if target.holder == 0 and not game.is_action_prop(target):
			return {"do": "lid", "target": target, "why": ""}
	return {}


# 画面の案内（箱の側）。act＝cargo_kit.gd の f_action の結果。out に足す
func hud_for(act: Dictionary, held: Node3D, target: Node3D, out: Dictionary) -> void:
	var why: String = str(act.get("why", ""))
	match str(act["do"]):
		"pack":
			var target_name: String = _short(target)
			if why == "":
				var poke: bool = float(slot_for(held, target)["over"]) > Pack.LID_GIVE
				out["tail"] = "　→ %s　[F] %s" % [target_name, "箱に押し込む（口からはみ出す）" if poke else "箱に入れる"]
				out["keys"] = "F 箱に押し込む（はみ出すと、ふたが閉まらない。道中でこぼれるかも）" if poke else "F 箱に入れる（箱の中へ手で置いても入る。箱ごと運べる）"
			else:
				out["tail"] = "　→ %s：%s" % [target_name, why]
				out["keys"] = why
		"unpack":
			var pick: Node = game.props[int(act["item"])]
			out["drop"] = ["　F：閉じる", "　F：開く", "　[F] 閉じる", "　[F] 開く", "（固定中）"]
			out["tail"] = "　[F] %s を取り出す" % _short(pick)
			out["keys"] = "F %s を取り出す（見ている物）／ %s" % [_short(pick), "中身がはみ出していて、ふたは閉まらない" if lid_blocked(target) else "箱ごと持って F で閉じる"]
		"lid":
			out["keys"] = "F 箱を%s ／ 物を持って、開いた箱を見て F で箱に入れる" % ("閉じる" if target.opened else "開く")
		"take":
			out["drop"] = ["（固定中）"]
			out["tail"] = "（置き場の残り %d箱）　[F] 1箱もらう" % reserve().size() if why == "" else "（もう無い。使い終わった箱を使い回そう）"
			out["keys"] = "F 段ボール箱を1箱出す（残り %d箱）" % reserve().size() if why == "" else "段ボール箱は、もう無い"
