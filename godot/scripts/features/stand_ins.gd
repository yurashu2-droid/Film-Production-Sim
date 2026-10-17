extends Node
## 役に入る（兼任）：台本の役者 A・B を、班の誰か（プレイヤー）か等身大パネルが演じる。
##   ・役に入るのは Y（見立てと同じキー。準備中だけ）。何も狙っていない・持っていないときの Y で、自分が A → B → やめる。
##     等身大パネルを狙って（持って）Y：A → B → 物の役の見立てへ戻る（城・怪獣など）
##   ・役に入った人には、役の色のたすきが掛かる（映画にも映る衣装）。頭の上には、班にだけ見える「役者A」の札
##   ・役に入っている間、NPC の役者は姿を消して、その人に付いていく（actor.gd の stand_in）。
##     判定・場面の進め方・試写会は、その人の位置と動きで数える。役に入った人は「映り込み」に数えない（production_notes.gd）
##   ・誰も入っていない役は、発注（電話）で雇った役者が演じる。ベテラン（高い・確実）か、劇団の新人（安い・出遅れる・通り過ぎる・
##     転ぶ・せりふで固まる。actor.gd）。雇わなければ、その役は誰も演じない（NPC の役者は姿を消す）。
##     自動確認の中だけは、ベテランが無料で付く（今までの確認が、NPC の役者の動きを前提にしているため。flow.daily が false のとき）
## 決めるのはホスト（h_cast_actor）。誰が何の役かは、"stand_in" の合図で全員へ配る
const CREW_LAYER := 1 << 11
const ROLE_NAMES := ["A", "B", "C", "D"]          # 役者は台本ごとに最大4人。何人かは台本の "cast"（production_beats.gd の cast_count）
const SASH := [Color("e8768f"), Color("4f8fd1"), Color("6fca7f"), Color("f2a64a")]     # 役の印の色（A＝桃・B＝青・C＝緑・D＝橙）とそろえる
const REACH := 3.8 + 2.0                            # 等身大パネルに役を付けられる距離（見立てと同じ。player.gd の REACH ＋ 2m）

var game: Node
var holders: Array = [["", 0], ["", 0], ["", 0], ["", 0]]     # 役ごとに [種類（"player"・"prop"・""）, 番号（プレイヤーの番号・物のID）]
var _marks := {}                            # 役に入っている人・物 → [たすき, 札]
var plan: Array = ["pro", "pro", "none", "none"]     # 役ごとに、誰が演じるか（"stand"・"pro"・"rookie"・"none"。全員の画面）


# この台本の役者の人数（役は A から順に、この数まで）
func _cast_n() -> int:
	return int(game.beats.cast_count()) if game.get("beats") != null else 2


# ---- 役を決める（ホスト） ----

@rpc("any_peer", "call_local", "reliable")
func h_cast_actor(kind: String, ref: int, role: int) -> void:
	if not Net.is_host() or game.production == null or int(game.production.phase) not in [2, 4] or game.state != game.S.PREP:
		return
	var who: int = Net.sender()
	if kind == "player" and ref != who:
		return                        # 自分の役だけを決められる
	if kind == "prop":
		var me: Node = game.players.get(who)
		var panel: Node = game.props.get(ref)
		if me == null or panel == null or panel.kind != "standin" or panel.absent:
			return
		if panel.holder != who and me.reach_base().distance_to(panel.center_global()) > REACH:
			return
	var table: Array = holders.duplicate(true)
	for i in table.size():
		if str(table[i][0]) == kind and int(table[i][1]) == ref:
			table[i] = ["", 0]        # 前の役から抜ける
	if role >= 0 and role < mini(table.size(), _cast_n()):
		table[role] = [kind, ref]     # その役にいた人は、役から外れる
	game.host_ev("stand_in", [table])


# 役に入っているか（-1＝入っていない / 0＝A / 1＝B）
func role_of(kind: String, ref: int) -> int:
	for i in holders.size():
		if str(holders[i][0]) == kind and int(holders[i][1]) == ref:
			return i
	return -1


# ---- 全員の画面：役に入った人に、役者を付ける ----

func hook_events() -> Array:
	return ["stand_in", "actor_plan"]


func hook_event(n: String, a: Array) -> void:
	if n == "stand_in":
		_apply(a[0])
	elif n == "actor_plan":
		plan = (a[0] as Array).duplicate()
		for i in mini(plan.size(), (game.actors as Array).size()):
			game.actors[i].set_grade(str(plan[i]))


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "stand_in", [holders])
		game.ev.rpc_id(who, "actor_plan", [plan])


# 誰が演じるかを、役に入った人と、決めた発注（雇った役者）から決める（ホスト）
func _physics_process(_delta: float) -> void:
	if not Net.is_host() or game.production == null or (game.actors as Array).size() < 2:
		return
	var want := plan_now()
	if want != plan:
		game.host_ev("actor_plan", [want])


func plan_now() -> Array:
	var flow: Node = game.production
	var pros := int(flow.ordered.get("actor_pro", 0))
	var rookies := int(flow.ordered.get("actor_new", 0))
	if not bool(flow.daily):
		pros = _cast_n()                # 自動確認の中：ベテランが無料で付く
	var out: Array = []
	for i in holders.size():
		if i >= _cast_n():
			out.append("none")          # この台本に無い役
		elif str(holders[i][0]) != "":
			out.append("stand")
		elif pros > 0:
			out.append("pro")
			pros -= 1
		elif rookies > 0:
			out.append("rookie")
			rookies -= 1
		else:
			out.append("none")
	return out


# 帰社したら、みんな役から抜ける（次の依頼で、また決める）
func hook_return_office() -> void:
	if Net.is_host():
		game.host_ev("stand_in", [[["", 0], ["", 0], ["", 0], ["", 0]]])


func _apply(table: Array) -> void:
	var me: Node = game.local_player()
	var mine_before: int = role_of("player", int(me.peer_id)) if me != null else -1
	holders = table.duplicate(true)
	for i in mini(holders.size(), (game.actors as Array).size()):
		var body: Node3D = _resolve(str(holders[i][0]), int(holders[i][1]))
		var actor: Node = game.actors[i]
		if actor.stand_in != body:
			actor.set_stand_in(body)
	_refresh_marks()
	var mine: int = role_of("player", int(me.peer_id)) if me != null else -1
	if mine != mine_before and game.get("hud") != null:
		if mine >= 0:
			game.hud.show_toast("役者%sに入った。台本の %s のせりふと動きを演じる（もう一度 Y で、ほかの役・やめる）" % [ROLE_NAMES[mine], ROLE_NAMES[mine]], game.hud.GREEN, 3.4)
		else:
			game.hud.show_toast("役から抜けた（裏方にもどる）", game.hud.YELLOW)


func _resolve(kind: String, ref: int) -> Node3D:
	match kind:
		"player":
			return game.players.get(ref)
		"prop":
			var p: Node = game.props.get(ref)
			return p if p != null and not p.absent else null
	return null


# たすきと札を付け直す（役から抜けた人・物からは外す）
func _refresh_marks() -> void:
	var want := {}
	for i in holders.size():
		var body: Node3D = _resolve(str(holders[i][0]), int(holders[i][1]))
		if body != null:
			want[body] = i
	for body: Object in _marks.keys():
		if not want.has(body) or not is_instance_valid(body) or not is_instance_valid(_marks[body][0]) or int(_marks[body][2]) != int(want.get(body, -1)):
			for n: Variant in (_marks[body] as Array).slice(0, 2):
				if n is Node and is_instance_valid(n):
					(n as Node).queue_free()
			_marks.erase(body)
	for body: Node3D in want:
		if not _marks.has(body):
			_marks[body] = _wear(body, int(want[body]))


# 役の色のたすき（体の前を斜めに）と、班にだけ見える札
func _wear(body: Node3D, role: int) -> Array:
	var holder: Node3D = body.get("vis") if body.get("vis") is Node3D else body
	var sash := MeshInstance3D.new()
	sash.name = "RoleSash"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 1.0, 0.035)
	sash.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SASH[role]
	mat.roughness = 0.85
	sash.material_override = mat
	holder.add_child(sash)
	var chest: Vector3 = holder.chest_pos() if holder.has_method("chest_pos") else body.global_position + Vector3(0, 1.1, 0)
	var front: Vector3 = holder.global_basis.z.normalized()
	sash.global_position = chest + front * 0.2
	sash.global_rotation = holder.global_rotation
	sash.rotate_object_local(Vector3.FORWARD, 0.75)
	var tag := Label3D.new()
	tag.name = "RoleTag"
	tag.text = "役者%s" % ROLE_NAMES[role]
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = SASH[role].lightened(0.2)
	tag.outline_size = 10
	tag.layers = CREW_LAYER
	holder.add_child(tag)
	tag.global_position = body.global_position + Vector3(0, 2.45, 0)
	return [sash, tag, role]


# ---- 自分の操作：Y ----

func hook_key(event: InputEvent, me: Node) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Y):
		return false
	if game.production == null or int(game.production.phase) not in [2, 4] or game.state != game.S.PREP:
		return false
	var subject: Node = game.props.get(me.held) if me.held != 0 else me.target
	if subject == null:
		# 自分：入っていない → A → B → やめる
		var now: int = role_of("player", int(me.peer_id))
		h_cast_actor.rpc_id(1, "player", int(me.peer_id), now + 1 if now < _cast_n() - 1 else -1)
		return true
	if subject.kind == "standin":
		var now: int = role_of("prop", int(subject.pid))
		if now == _cast_n() - 1:
			# B のあとは、役者の役をやめて、物の役の見立て（城・怪獣など）へ。この Y は見立てにも回す
			h_cast_actor.rpc_id(1, "prop", int(subject.pid), -1)
			return false
		if now >= 0 or str(game.production.role_of(subject)) == "":
			h_cast_actor.rpc_id(1, "prop", int(subject.pid), now + 1)
			return true
	return false


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	if game.production == null or int(game.production.phase) not in [2, 4] or game.state != game.S.PREP:
		return {}
	if me.held == 0 and me.target == null:
		var now: int = role_of("player", int(me.peer_id))
		return {"keys": "Y %s" % ("役をやめる" if now >= _cast_n() - 1 else "役者%sになる" % ROLE_NAMES[now + 1])}
	var subject: Node = game.props.get(me.held) if me.held != 0 else me.target
	if subject != null and subject.kind == "standin":
		var now: int = role_of("prop", int(subject.pid))
		if now >= 0:
			return {"tail": "　（役者%s）" % ROLE_NAMES[now]}
	return {}
